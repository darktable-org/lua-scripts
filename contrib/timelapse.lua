--[[Timelapse video plugin for darktable 2.4.X and 2.6.X

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
This plugin will add the new export module "timelapse".
   
----REQUIRED SOFTWARE----
ffmpeg

----USAGE----
1. Go to Lighttable 
2. Select images you want to use as a timelapse frames
3. In image export module select 'timelapse'
4. Configure you video settings
5. Export

----WARNING----
This script has been tested under Linux only
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
local dsys = require "lib/dtutils.system"
local gettext = dt.gettext

dt.configuration.check_version(...,{5,0,0})

local MODULE_NAME = 'timelapse'
gettext.bindtextdomain(MODULE_NAME, dt.configuration.config_dir..'/lua/')

local function _(msgid)
  return gettext.dgettext(MODULE_NAME, msgid)
end

local OS_PATH_SEPARATOR = dt.configuration.running_os == "windows" and  "\\"  or  "/"

---- DECLARATIONS

local resolutions = {
  ['QVGA'] = {
    ['label'] = 'QVGA 320x240 (4:3)',
    ['w'] = 320,
    ['h'] = 240
  },
  ['HVGA'] = {
    ['label'] = 'HVGA 480x320 (3:2)',
    ['w'] = 480,
    ['h'] = 320
  },
  ['VGA'] = {
    ['label'] = 'VGA 640x480 (4:3)',
    ['w'] = 640,
    ['h'] = 480
  },
  ['HDTV 720p'] = {
    ['label'] = 'HDTV 720p 1280x720 (16:9)',
    ['w'] = 1280,
    ['h'] = 720
  },
  ['HDTV 1080p'] = {
    ['label'] = 'HDTV 1080p 1920x1080 (16:9)',
    ['w'] = 1920,
    ['h'] = 1080
  },
  ['Cinema TV'] = {
    ['label'] = 'Cinema TV 2560x1080 (21:9)',
    ['w'] = 2560,
    ['h'] = 1080
  },
  ['2K'] = {
    ['label'] = '2K 2048x1152 (16:9)',
    ['w'] = 2048,
    ['h'] = 1152
  },
  ['4K'] = {
    ['label'] = '4K 4096x2304 (16:9)',
    ['w'] = 4096,
    ['h'] = 2304
  }
}

local framerates = {'15', '16', '23.98', '24', '25', '29,97', '30', '48', '50', '59.94', '60'}

local formats = {
  ['AVI'] = {
    ['extension'] = 'avi',
    ['codecs'] = {'mpeg4', 'h263p', 'h264', 'mpeg2video', 'hevc', 'vp9'}
  },
  ['Matroska'] = {
    ['extension'] = 'mkv',
    ['codecs'] = {'h264', 'h263p', 'mpeg4', 'mpeg2video', 'hevc', 'vp9'}
  },
  ['WebM'] = {
    ['extension'] = 'webm',
    ['codecs'] = {'vp9', 'h263p', 'h264', 'mpeg4', 'mpeg2video', 'hevc'}
  },
  ['MP4'] = {
    ['extension'] = 'mp4',
    ['codecs'] = {'h264', 'h263p', 'mpeg4', 'mpeg2video'}
  },
  ['QuickTime'] = {
    ['extension'] = 'mov',
    ['codecs'] = {'h264', 'h263p', 'mpeg4', 'mpeg2video'}
  }
}

res_list = {}
for i, v in pairs(resolutions) do
  table.insert(res_list, v['label'])
end

table.sort(res_list)

format_list = {}
for i,v in pairs(formats) do
  table.insert(format_list, i)
end

table.sort(format_list)

codec_list = formats['AVI']['codecs']
table.sort(codec_list)

local function extract_resolution(description)
  for _, v in pairs(resolutions) do
    if v['label'] == description then
      return v['w']..'x'..v['h']
    end
  end
  return '100x100'
end

---- ENSURE ffmpeg is INSTALLED

dt.print_log(MODULE_NAME .. " - Executable Path Preference: "..df.get_executable_path_preference("ffmpeg"))
local ffmpeg_path = df.check_if_bin_exists("ffmpeg")
if not ffmpeg_path then
  dt.print_error("ffmpeg not found")
  dt.print("ERROR - ffmpeg not found")
end

local ffmpeg_path_widget = df.executable_path_widget({'ffmpeg'})
dt.preferences.register("executable_paths", "ffmpeg",
  "file",
  MODULE_NAME .. ': ffmpeg location',
  'Install location of ffmpeg',
  "ffmpeg",
  ffmpeg_path_widget
)

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

local function format(label, symbols)
  local es1, es2 = "\u{ffe0}", "\u{ffe1}" -- for simplicity, just some strange utf characters 
  local result = label:gsub("\\{", es1):gsub("\\}", es2)
  for s,v in pairs(symbols) do
    result = result:gsub("{"..s.."}", v)
  end
  return result:gsub(es1, "{"):gsub(es2, "}")
end

local function open_file(filename) 
  local open_cmd = 'xdg-open'
  if (dt.configuration.running_os == 'windows') then
    open_cmd = 'start'
  elseif  (dt.configuration.running_os == 'macos') then
    open_cmd = 'open'
  end   
  return dsys.external_command(open_cmd..' '..df.sanitize_filename(filename))
end

local function mkdir(path) 
  local mkdir_cmd = dt.configuration.running_os == 'windows' and 'mkdir' or 'mkdir -p'
  return dsys.external_command(mkdir_cmd..' '..df.sanitize_filename(path))
end

local function rm(path)
  local rm_cmd = dt.configuration.running_os == 'windows' and 'rmdir /S /Q' or 'rm -r'
  return dsys.external_command(rm_cmd..' '..df.sanitize_filename(path))
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

local framerates_selector = dt.new_widget('combobox'){
  label = _('framerate'),
  tooltip = _('select framerate of output video'),
  value = combobox_pref_read("framerate", framerates),
  changed_callback = combobox_pref_write('framerate'), 
  table.unpack(framerates)
}

local res_selector = dt.new_widget('combobox'){
  label = _('resolution'),
  tooltip = _('select resolution of output video'),
  value = combobox_pref_read('resolution', res_list),
  changed_callback = combobox_pref_write('resolution'),
  table.unpack(res_list)
}

local codec_selector = dt.new_widget('combobox'){
  label = _('codec'),
  tooltip = _('select codec'),
  value = combobox_pref_read('codec', codec_list),
  changed_callback = combobox_pref_write('codec'),
  table.unpack(codec_list)
}

local format_selector = dt.new_widget('combobox'){
  label = _('format container'),
  tooltip = _('select format of output video'),
  value = combobox_pref_read('format', format_list),
  changed_callback = function(widget)
    combobox_pref_write('format')(widget)
    codec_list = formats[widget.value]['codecs']
    table.sort(codec_list)
    replace_combobox_elements(codec_selector, codec_list)
  end,
  table.unpack(format_list)
}

local destination_label = dt.new_widget('section_label'){
  label = _('output file destination'),
  tooltip = _('settings of output file destination and name')
}

local output_directory_chooser = dt.new_widget('file_chooser_button'){
  title = _('Select export path'),
  is_directory = true,
  tooltip =_('select the target directory for the timelapse. \nthe filename is created automatically.'),
  value = string_pref_read("export_path", os.getenv('HOME')),
  changed_callback = string_pref_write("export_path")
}

local auto_output_directory_btn = dt.new_widget('check_button') {
  label = '',
  tooltip = _('if selected, output video will be placed in the same directory as first of selected images'),
  value = not dt.preferences.read(MODULE_NAME, "not_auto_output_directory", "bool"), -- reverse, for true as default
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "not_auto_output_directory", "bool",  not widget.value)
    output_directory_chooser.sensitive = not output_directory_chooser.sensitive 
  end
}

local destination_box = dt.new_widget('box') {
  orientation = 'horizontal',
  auto_output_directory_btn,
  output_directory_chooser
}

local override_output_cb = dt.new_widget('check_button'){
  label = _('override output file on conflict'),
  tooltip = _('if checked, in case of file name conflict, the file will be overwritten'),
  value = dt.preferences.read(MODULE_NAME, "override_output", "bool"),
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "override_output", "bool",  widget.value)
  end
}

local filename_entry = dt.new_widget('entry'){
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


local output_box = dt.new_widget('box'){
  orientation='vertical',
  destination_label,
  override_output_cb,
  destination_box,
  filename_entry,
}

local open_after_export_cb = dt.new_widget('check_button'){
  label = _(' open after export'),
  tooltip = _('open video file after successful export'),
  value = dt.preferences.read(MODULE_NAME, "open_after_export", "bool"),
  clicked_callback = function (widget)
    dt.preferences.write(MODULE_NAME, "open_after_export", "bool",  widget.value)
  end
}

local module_widget = dt.new_widget('box') {
  orientation = 'vertical',
  res_selector,
  framerates_selector,
  format_selector,
  codec_selector,
  output_box,
  open_after_export_cb
}

---- EXPORT & REGISTRATION

local function support_format(storage, format)
  return true
end

local function init_export(storage, img_format, images, high_quality, extra_data)
  -- store filename preference here cause there is no changed_callback on entry yet
  string_pref_write("filename_entry", "text")(filename_entry)

  extra_data['images'] = images -- needed, to preserve images order
  extra_data['tmp_dir'] = dt.configuration.tmp_dir .. '/'..MODULE_NAME .. '_' .. os.time()
  extra_data['fps'] = framerates_selector.value
  extra_data['res'] = extract_resolution(res_selector.value)
  extra_data['codec'] = codec_selector.value
  extra_data['img_ext'] = '.'..img_format.extension
  local override_output = override_output_cb.value
  local output_directory = auto_output_directory_btn.value and images[1].path or output_directory_chooser.value
  local filename_mappings = {
    date = os.date("%Y-%m-%d"),
    time = os.date("%H-%M-%S"),
    first_file = images[1].filename,
    last_file = images[#images].filename
  }
  local output_extension = '.'..formats[format_selector.value]['extension']
  local filename = format(filename_entry.text, filename_mappings)
  local path = output_directory..OS_PATH_SEPARATOR..filename..output_extension
  if not override_output then
    path = df.create_unique_filename(path)
  end

  extra_data['output_file'] = path
  extra_data['open_after_export'] = open_after_export_cb.value
end

local function export(extra_data)
  local ffmpeg_path = df.check_if_bin_exists("ffmpeg")
  if not ffmpeg_path then
    dt.print_error("ffmpeg not found")
    dt.print("ERROR - ffmpeg not found")
    return
  end
  local dir = extra_data['tmp_dir']
  local fps = extra_data['fps']
  local res = extra_data['res']
  local codec = extra_data['codec']
  local img_ext = extra_data['img_ext']
  local output_file = extra_data['output_file']
  
  local dir_create_result = mkdir(df.get_path(output_file))
  if dir_create_result ~= 0 then return dir_create_result end

  local cmd = ffmpeg_path..' -y -r '..fps..' -i '..dir..OS_PATH_SEPARATOR..'%d'..img_ext..' -s:v '..res..' -c:v '..codec..' -crf 18 -preset veryslow '..df.sanitize_filename(output_file)
  return dsys.external_command(cmd), output_file
end

local function finalize_export(storage, images_table, extra_data)
    local tmp_dir = extra_data['tmp_dir']
    
    dt.print(_('prepare merge process'))
    
    local result = mkdir(tmp_dir)
    if result ~= 0 then dt.print(_('ERROR: cannot create temp directory')) end
    
    local images = extra_data['images']
    -- rename all images to consecutive numbers
    for i, file in pairs(images) do
      local filename = images_table[file]
      dt.print_error(filename, file.filename)
      df.file_move(filename, tmp_dir .. OS_PATH_SEPARATOR .. i .. extra_data['img_ext'])
    end
    dt.print('Start video building...')
    local result, path = export(extra_data)
    if result ~= 0 then 
      dt.print(_('ERROR: cannot build image, see console for more info')) 
    else
      dt.print(_('SUCCESS'))
      if extra_data['open_after_export'] then
        open_file(path)
      end
    end

    rm(tmp_dir)
end

dt.register_storage(
  'module_timelapse', 
  _(MODULE_NAME), 
  nil, 
  finalize_export,
  support_format, 
  init_export, 
  module_widget
)

