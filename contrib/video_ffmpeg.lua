--[[Timelapse video plugin based on ffmpeg for darktable 2.4.X and 2.6.X

  copyright (c) 2018, 2019  Dominik Markiewicz
  
  darktable is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.
  
  darktable is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.
  
  You should have received a copy of the GNU General Public License
  along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[About this plugin
This plugin will add the new export module "video ffmpeg".
   
----REQUIRED SOFTWARE----
ffmpeg

----USAGE----
1. Go to Lighttable 
2. Select images you want to use as a video ffmpeg frames
3. In image export module select "video ffmpeg"
4. Configure you video settings
5. Export

----WARNING----
This script has been tested under Linux only
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "video_ffmpeg") 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("video ffmpeg"),
  purpose = _("timelapse video plugin based on ffmpeg"),
  author = "Dominik Markiewicz",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contib/video_ffmpeg"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local MODULE_NAME = "video_ffmpeg"

local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

---- DECLARATIONS

local resolutions = {
  ["QVGA"] = {
    ["label"] = "QVGA 320x240 (4:3)",
    ["w"] = 320,
    ["h"] = 240
  },
  ["HVGA"] = {
    ["label"] = "HVGA 480x320 (3:2)",
    ["w"] = 480,
    ["h"] = 320
  },
  ["VGA"] = {
    ["label"] = "VGA 640x480 (4:3)",
    ["w"] = 640,
    ["h"] = 480
  },
  ["HDTV 720p"] = {
    ["label"] = "HDTV 720p 1280x720 (16:9)",
    ["w"] = 1280,
    ["h"] = 720
  },
  ["HDTV 1080p"] = {
    ["label"] = "HDTV 1080p 1920x1080 (16:9)",
    ["w"] = 1920,
    ["h"] = 1080
  },
  ["Cinema TV"] = {
    ["label"] = "Cinema TV 2560x1080 (21:9)",
    ["w"] = 2560,
    ["h"] = 1080
  },
  ["2K"] = {
    ["label"] = "2K 2048x1152 (16:9)",
    ["w"] = 2048,
    ["h"] = 1152
  },
  ["4K"] = {
    ["label"] = "4K 4096x2304 (16:9)",
    ["w"] = 4096,
    ["h"] = 2304
  }
}

local framerates = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "15", "16", "23.98", "24", "25", "29,97", "30", "48", "50", "59.94", "60", "120", "240", "300"}

local formats = {
  ["AVI"] = {
    ["extension"] = "avi",
    ["codecs"] = {"mpeg4", "h263p", "h264", "mpeg2video", "hevc", "vp9"}
  },
  ["Matroska"] = {
    ["extension"] = "mkv",
    ["codecs"] = {"h264", "h263p", "mpeg4", "mpeg2video", "hevc", "vp9"}
  },
  ["WebM"] = {
    ["extension"] = "webm",
    ["codecs"] = {"vp9", "h263p", "h264", "mpeg4", "mpeg2video", "hevc"}
  },
  ["MP4"] = {
    ["extension"] = "mp4",
    ["codecs"] = {"h264", "h263p", "mpeg4", "mpeg2video"}
  },
  ["QuickTime"] = {
    ["extension"] = "mov",
    ["codecs"] = {"h264", "h263p", "mpeg4", "mpeg2video"}
  }
}

local res_list = {}
for i, v in pairs(resolutions) do
  table.insert(res_list, v["label"])
end

table.sort(res_list)

-- inital fulfill list of all available formats 
local format_list = {}
for i,v in pairs(formats) do
  table.insert(format_list, i)
end
table.sort(format_list)

-- initial fulfill list of all available codecs for the first (default if nothig saved yet) format
-- if format was changed and stored in preferences, this list will be replaced by one matching selected format
local codec_list = formats[format_list[1]]["codecs"]
table.sort(codec_list)

local function extract_resolution(description)
  for _, v in pairs(resolutions) do
    if v["label"] == description then
      return v["w"].."x"..v["h"]
    end
  end
  return "100x100"
end

---- GENERIC UTILS

local function replace_combobox_elements(combobox, new_items, to_select)
  if to_select == nil then
    to_select = combobox.value
  end

  to_select_idx = 1
  for i , name in ipairs(new_items) do
    if name == to_select then
      to_select_idx = i
      break
    end
  end

  local old_elements_count = #combobox
  for i, name in ipairs(new_items) do
    combobox[i] = name
  end
  if old_elements_count > #new_items then
    for j = old_elements_count, #new_items + 1, -1 do
      combobox[j] = nil
    end
  end

  combobox.value = to_select_idx
end

--[[
This function allow to format string by substitute tokens like `{label}` by value provided in `symbols` table
  ex:
```lua
  format_string("I like {bananas} and {potatos}. {bananas}!", {["bananas"]: "darktable", ["potatos"]: "lua"}) 
  -> "I like darktable and lua. darktable!"
```

I you want to preserve given currly braces, you need to escape it by backslash like so:
```lua
  format_string("it preserve \\{label\\} but substitute {label}", {["label"]: "this"}) 
  -> "It preserve {label} but substitute "
```
--]]
local function format_string(label, symbols)
  local es1, es2 = "\u{ffe0}", "\u{ffe1}" -- for simplicity, just some strange utf characters 
  local result = label:gsub("\\{", es1):gsub("\\}", es2)
  for s,v in pairs(symbols) do
    result = result:gsub("{"..s.."}", v)
  end
  return result:gsub(es1, "{"):gsub(es2, "}")
end

-----  COMPONENTS

local function combobox_pref_read(name, all_values)
  local value = dt.preferences.read(MODULE_NAME, name, "string")
  for i,v in pairs(all_values) do
    if v == value then return i end
  end
  return 1
end

local function combobox_pref_write(name)
  local writer = function(widget)
    dt.preferences.write(MODULE_NAME, name, "string", widget.value)
  end
  return writer
end

local function string_pref_read(name, default)
  local value = dt.preferences.read(MODULE_NAME, name, "string")
  if value ~= nil and value ~= "" then return value end
  return default
end

local function string_pref_write(name, widget_attribute)
  widget_attribute = widget_attribute or "value"
  local writer = function(widget)
    dt.preferences.write(MODULE_NAME, name, "string", widget[widget_attribute])
  end
  return writer
end

local framerates_selector = dt.new_widget("combobox"){
  label = _("frame rate"),
  tooltip = _("select frame rate of output video"),
  value = combobox_pref_read("framerate", framerates),
  changed_callback = combobox_pref_write("framerate"), 
  table.unpack(framerates)
}

local res_selector = dt.new_widget("combobox"){
  label = _("resolution"),
  tooltip = _("select resolution of output video"),
  value = combobox_pref_read("resolution", res_list),
  changed_callback = combobox_pref_write("resolution"),
  table.unpack(res_list)
}

local codec_selector = dt.new_widget("combobox"){
  label = _("codec"),
  tooltip = _("select codec"),
  value = combobox_pref_read("codec", codec_list),
  changed_callback = combobox_pref_write("codec"),
  table.unpack(codec_list)
}

local format_selector = dt.new_widget("combobox"){
  label = _("format container"),
  tooltip = _("select format of output video"),
  value = combobox_pref_read("format", format_list),
  changed_callback = function(widget)
    combobox_pref_write("format")(widget)
    codec_list = formats[widget.value]["codecs"]
    table.sort(codec_list)
    replace_combobox_elements(codec_selector, codec_list)
  end,
  table.unpack(format_list)
}

local destination_label = dt.new_widget("section_label"){
  label = _("output file destination"),
  tooltip = _("settings of output file destination and name")
}

local defaultVideoDir = ''
if dt.configuration.running_os == "windows" then
  defaultVideoDir = os.getenv("USERPROFILE")..PS .."videos"
elseif dt.configuration.running_os == "macos" then
  defaultVideoDir =  os.getenv("HOME")..PS.."Videos"
else
  local handle = io.popen("xdg-user-dir VIDEOS")
  defaultVideoDir = handle:read()
  handle:close()
end

local output_directory_chooser = dt.new_widget("file_chooser_button"){
  title = _("select export path"),
  is_directory = true,
  tooltip =_("select the target directory for the timelapse. \nthe filename is created automatically."),
  value = string_pref_read("export_path", defaultVideoDir),
  changed_callback = string_pref_write("export_path")
}

local auto_output_directory_btn = dt.new_widget("check_button") {
  label = "",
  tooltip = _("if selected, output video will be placed in the same directory as first of selected images"),
  value = not dt.preferences.read(MODULE_NAME, "not_auto_output_directory", "bool"), -- reverse, for true as default
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "not_auto_output_directory", "bool",  not widget.value)
    output_directory_chooser.sensitive = not output_directory_chooser.sensitive 
  end
}

local destination_box = dt.new_widget("box") {
  orientation = "horizontal",
  auto_output_directory_btn,
  output_directory_chooser
}

local override_output_cb = dt.new_widget("check_button"){
  label = _("override output file on conflict"),
  tooltip = _("if checked, in case of file name conflict, the file will be overwritten"),
  value = dt.preferences.read(MODULE_NAME, "override_output", "bool"),
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "override_output", "bool",  widget.value)
  end
}

local filename_entry = dt.new_widget("entry"){
  tooltip = _("enter output file name without extension.\n\n".. 
    "You can use some placeholders:\n"..
    "- {time} - time in format HH-mm-ss\n"..
    "- {date} - date in foramt YYYY-mm-dd\n"..
    "- {first_file} - name of first input file\n"..
    "- {last_file} - name of last last_file"
    ),
  text = string_pref_read("filename_entry","timelapse_{date}_{time}"),
 -- changed_callback = string_pref_write("filename_entry", "text") -- Not imlemented yet
}

local output_box = dt.new_widget("box"){
  orientation="vertical",
  destination_label,
  override_output_cb,
  destination_box,
  filename_entry,
}

local open_after_export_cb = dt.new_widget("check_button"){
  label = _(" open after export"),
  tooltip = _("open video file after successful export"),
  value = dt.preferences.read(MODULE_NAME, "open_after_export", "bool"),
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "open_after_export", "bool",  widget.value)
  end
}

local widgets_list = {}
if not df.check_if_bin_exists("ffmpeg") then
  table.insert(widgets_list, df.executable_path_widget({"ffmpeg"}))
end
table.insert(widgets_list, res_selector)
table.insert(widgets_list, framerates_selector)
table.insert(widgets_list, format_selector)
table.insert(widgets_list, codec_selector)
table.insert(widgets_list, output_box)
table.insert(widgets_list, open_after_export_cb)


local module_widget = dt.new_widget("box") {
  orientation = "vertical",
  table.unpack(widgets_list)
}

---- EXPORT & REGISTRATION

local function show_status(enf_storage, image, format, filename, number, total, high_quality, extra_data)
  dt.print(string.format(_("export %d / %d", number), total))   
end

local function init_export(storage, img_format, images, high_quality, extra_data)
  -- store filename preference here cause there is no changed_callback on entry yet
  string_pref_write("filename_entry", "text")(filename_entry)

  extra_data["images"] = images -- needed, to preserve images order
  extra_data["tmp_dir"] = dt.configuration.tmp_dir..PS..MODULE_NAME.."_"..os.time()
  extra_data["fps"] = framerates_selector.value
  extra_data["res"] = extract_resolution(res_selector.value)
  extra_data["codec"] = codec_selector.value
  extra_data["img_ext"] = "."..img_format.extension
  local override_output = override_output_cb.value
  local output_directory = auto_output_directory_btn.value and images[1].path or output_directory_chooser.value
  local filename_mappings = {
    date = os.date("%Y-%m-%d"),
    time = os.date("%H-%M-%S"),
    first_file = images[1].filename,
    last_file = images[#images].filename
  }
  local output_extension = "."..formats[format_selector.value]["extension"]
  local filename = format_string(filename_entry.text, filename_mappings)
  local path = output_directory..PS..filename..output_extension
  if not override_output then
    path = df.create_unique_filename(path)
  end

  extra_data["output_file"] = path
  extra_data["open_after_export"] = open_after_export_cb.value
end

local function export(extra_data)
  local ffmpeg_path = df.check_if_bin_exists("ffmpeg")
  if not ffmpeg_path then
    dt.print_error("ffmpeg not found")
    dt.print(_("ERROR - ffmpeg not found"))
    return
  end
  local dir = extra_data["tmp_dir"]
  local fps = extra_data["fps"]
  local res = extra_data["res"]
  local codec = extra_data["codec"]
  local img_ext = extra_data["img_ext"]
  local output_file = extra_data["output_file"]
  
  local dir_create_result = df.mkdir(df.sanitize_filename(df.get_path(output_file)))
  if dir_create_result ~= 0 then return dir_create_result end

  local cmd = ffmpeg_path.." -y -r "..fps.." -i "..dir..PS.."%d"..img_ext.." -s:v "..res.." -c:v "..codec.." -crf 18 -preset veryslow "..df.sanitize_filename(output_file)
  return dsys.external_command(cmd), output_file
end

local function finalize_export(storage, images_table, extra_data)
    local tmp_dir = extra_data["tmp_dir"]
    
    dt.print(_("prepare merge process"))
    
    local result = df.mkdir(df.sanitize_filename(tmp_dir))
    if result ~= 0 then dt.print(_("ERROR: cannot create temp directory")) end
    
    local images = extra_data["images"]
    -- rename all images to consecutive numbers
    for i, file in pairs(images) do
      local filename = images_table[file]
      dt.print_error(filename, file.filename)
      df.file_move(filename, tmp_dir .. PS .. i .. extra_data["img_ext"])
    end
    dt.print(_("start video building..."))
    local result, path = export(extra_data)
    if result ~= 0 then 
      dt.print(_("ERROR: cannot build image, see console for more info")) 
    else
      dt.print(_("SUCCESS"))
      if extra_data["open_after_export"] then
        dsys.launch_default_app(df.sanitize_filename(path))
      end
    end

    df.rmdir(df.sanitize_filename(tmp_dir))
end

-- script_manager integration

local function destroy()
  dt.destroy_storage("module_video_ffmpeg")
end

dt.register_storage(
  "module_video_ffmpeg", 
  _("video ffmpeg"), 
  show_status, 
  finalize_export,
  nil, 
  init_export, 
  module_widget
)

-- script_manager integration

script_data.destroy = destroy

return script_data
