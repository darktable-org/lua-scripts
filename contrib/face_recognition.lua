--[[
  Face recognition for darktable

  Copyright (c) 2017  Sebastian Witt
   
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

--[[
face_recognition
Add a new storage option to send images to face_recognition.
Images are exported to darktable tmp dir first.
A directory with known faces must exist, the image name are the
tag names which will be used.
Multiple images for one face can exist, add a number to it, the
number will be removed from the tag, for example:
People|IknowYou1.jpg
People|IknowYou2.jpg
People|Another.jpg
People|Youtoo.jpg

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* https://github.com/ageitgey/face_recognition
* https://github.com/darktable-org/lua-scripts/tree/master/lib

USAGE
* require this file from your main luarc config file.

This plugin will add a new storage option and calls face_recognition after export.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

-- constants

local MODULE = "face_recognition"
local PS = dt.configuration.running_os == "windows" and '\\' or '/'
local OUTPUT = dt.configuration.tmp_dir .. PS .. "facerecognition.txt"

du.check_min_api_version("7.0.0", MODULE) 

local function _(msgid)
  return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("face recognition"),
  purpose = _("use facial recognition to tag images"),
  author = "Sebastian Witt",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/face_recognition"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- namespace

local fc = {}
fc.module_installed = false
fc.event_registered = false

local function build_image_table(images)
  local image_table = {}
  local file_extension = ""
  local tmp_dir = dt.configuration.tmp_dir .. PS
  local ff = fc.export_format.value
  local cnt = 0

  -- check for plugin-data and direct_edit and build image table accordingly

  if string.match(ff, "JPEG") then
    file_extension = ".jpg"
  elseif string.match(ff, "PNG") then
    file_extension = ".png"
  elseif string.match(ff, "TIFF") then
    file_extension = ".tif"
  end

  for _,img in ipairs(images) do
    if img ~= nil then
      image_table[tmp_dir .. df.get_basename(img.filename) .. file_extension] = img
      cnt = cnt + 1
    end
  end

  return image_table, cnt
end

local function stop_job(job)
  job.valid = false
end

local function do_export(img_tbl, images)
  local exporter = nil
  local upsize = false
  local ff = fc.export_format.value
  local height = dt.preferences.read(MODULE, "max_height", "integer")
  local width = dt.preferences.read(MODULE, "max_width", "integer")

  -- get the export format parameters
  if string.match(ff, "JPEG") then
    exporter = dt.new_format("jpeg")
    exporter.quality = 80
  elseif string.match(ff, "PNG") then
    exporter = dt.new_format("png")
    exporter.bpp = 8
  elseif string.match(ff, "TIFF") then
    exporter = dt.new_format("tiff")
    exporter.bpp = 8
  end
  exporter.max_height = height
  exporter.max_width = width

  -- export the images
  local job = dt.gui.create_job(_("export images"), true, stop_job)
  local exp_cnt = 0
  local percent_step = 1.0 / images
  job.percent = 0.0
  for export,img in pairs(img_tbl) do
    exp_cnt = exp_cnt + 1
    dt.print(string.format(_("exporting image %i of %i images"), exp_cnt, images))
    exporter:write_image(img, export, upsize)
    job.percent = job.percent + percent_step
  end
  job.valid = false

  -- return success, or not
  return true
end

local function save_preferences()
  dt.preferences.write(MODULE, "unknown_tag", "string", fc.unknown_tag.text)
  dt.preferences.write(MODULE, "no_persons_found_tag", "string", fc.no_persons_found_tag.text)
  dt.preferences.write(MODULE, "ignore_tags", "string", fc.ignore_tags.text)
  dt.preferences.write(MODULE, "category_tags", "string", fc.category_tags.text)
  dt.preferences.write(MODULE, "known_image_path", "directory", fc.known_image_path.value)
  local val = fc.tolerance.value
  val = string.gsub(tostring(val), ",", ".")
  dt.preferences.write(MODULE, "tolerance", "float", tonumber(val))
  dt.preferences.write(MODULE, "num_cores", "integer", fc.num_cores.value)
  dt.preferences.write(MODULE, "export_format", "integer", fc.export_format.selected)
  dt.preferences.write(MODULE, "max_width", "integer", tonumber(fc.width.text))
  dt.preferences.write(MODULE, "max_height", "integer", tonumber(fc.height.text))
end

local function reset_preferences()
  fc.unknown_tag.text = "unknown_person"
  fc.no_persons_found_tag.text = "no_persons_found"
  fc.ignore_tags.text = ""
  fc.category_tags.text = ""
  fc.known_image_path.value = dt.configuration.config_dir .. "/face_recognition"
  fc.tolerance.value = 0.6
  fc.num_cores.value = -1
  fc.export_format.selected = 1
  fc.width.text = 1000
  fc.height.text = 1000
  save_preferences()
end

-- Check if image has ignored tag attached
local function ignoreByTag (image, ignoreTags)
  local tags = image:get_tags ()
  local ignoreImage = false
  -- For each image tag
  for _,t in ipairs (tags) do
    -- Check if it contains a ignore tag
    for _,it in ipairs (ignoreTags) do
      if string.find (t.name, it, 1, true) then
        -- The image has ignored tag attached
        ignoreImage = true
        dt.print_log ("Face recognition: Ignored tag: " .. it .. " found in " .. image.id .. ":" .. t.name)
      end
    end
  end

  return ignoreImage
end

local function cleanup(img_list)
  for _, img in ipairs(img_list) do
    os.remove(img)
  end
  os.remove(OUTPUT)
end

local function face_recognition ()

  local bin_path = df.check_if_bin_exists("face_recognition")

  if not bin_path then
    dt.print(_("face recognition not found"))
    return
  end

  save_preferences()

  -- Get preferences
  local knownPath = dt.preferences.read(MODULE, "known_image_path", "directory")
  local nrCores = dt.preferences.read(MODULE, "num_cores", "integer")
  local ignoreTagString = dt.preferences.read(MODULE, "ignore_tags", "string")
  local categoryTagString = dt.preferences.read(MODULE, "category_tags", "string")
  local unknownTag = dt.preferences.read(MODULE, "unknown_tag", "string")
  local nonpersonsfoundTag = dt.preferences.read(MODULE, "no_persons_found_tag", "string")

  -- face_recognition uses -1 for all cores, we use 0 in preferences
  if nrCores < 1 then
    nrCores = -1
  end

  -- Split ignore tags (if any)
  ignoreTags = {}
  for tag in string.gmatch(ignoreTagString, '([^,]+)') do
    table.insert (ignoreTags, tag)
    dt.print_log ("Face recognition: Ignore tag: " .. tag)
  end

  -- list of exported images

  local image_table, cnt = build_image_table(dt.gui.action_images)

  if cnt > 0 then
    local success = do_export(image_table, cnt)
    if success then
      -- do the face recognition
      local img_list = {}

      for v,_ in pairs(image_table) do
        table.insert (img_list, v)
      end

      -- Get path of exported images
      local path = df.get_path (img_list[1])
      dt.print_log ("Face recognition: Path to known faces: " .. knownPath)
      dt.print_log ("Face recognition: Path to unknown images: " .. path)
      dt.print_log ("Face recognition: Tag used for unknown faces: " .. unknownTag)
      dt.print_log ("Face recognition: Tag used if non person is found: " .. nonpersonsfoundTag)
      os.setlocale("C")
      local tolerance = dt.preferences.read(MODULE, "tolerance", "float")

      local command = bin_path ..  " --cpus " .. nrCores .. " --tolerance " .. tolerance .. " " .. knownPath .. " " .. path .. " > " .. OUTPUT
      os.setlocale()
      dt.print_log("Face recognition: Running command: " .. command)
      dt.print(_("starting face recognition..."))

      dtsys.external_command(command)

      -- Open output file
      local f = io.open(OUTPUT, "rb")

      if not f then
        dt.print(_("face recognition failed"))
      else
        dt.print(_("face recognition finished"))
        f:close ()
      end

      -- Read output
      dt.print(_("processing results..."))
      local result = {}
      local tags_list = {}
      local tag_object = {}
      for line in io.lines(OUTPUT) do
        if not string.match(line, "^WARNING:") and line ~= "" and line ~= nil then
          local file, tag = string.match (line, "(.*),(.*)$")
          tag = string.gsub (tag, "%d*$", "")
          dt.print_log ("File:"..file .." Tag:".. tag)
          tag_object = {}
          if result[file] == nil then
            tag_object[tag] = true
            result[file] = tag_object
          else
            tag_object = result[file]
            tag_object[tag] = true
            result[file] = tag_object
          end
        end
      end

      -- Attach tags
      local result_index = 0
      for file,tags in pairs(result) do
        result_index = result_index +1
        -- Find image in table
        img = image_table[file]
        if img == nil then
          dt.print_log("Face recognition: Ignoring face recognition entry: " .. file)
        else
          for t,_ in pairs (tags) do
            -- Check if image is ignored
            if ignoreByTag (img, ignoreTags) then
              dt.print_log("Face recognition: Ignoring image with ID " .. img.id)
            else
              -- Check of unrecognized unknown_person
              if t == "unknown_person" then
                t = unknownTag
              end
              -- Check of unrecognized no_persons_found
              if t == "no_persons_found" then
                t = nonpersonsfoundTag
              end
              if t ~= "" and t ~= nil then
                if categoryTagString ~= "" and t ~= nonpersonsfoundTag then
                  t = categoryTagString .. "|" .. t
                end                  
                dt.print_log ("ImgId:" .. img.id .. " Tag:".. t)
                -- Create tag if it does not exist
                if tags_list[t] == nil then
                  tag = dt.tags.create (t)
                  tags_list[t] = tag
                else
                  tag = tags_list[t]
                end
                img:attach_tag (tag)
              end
            end
          end
        end
      end
      cleanup(img_list)
      dt.print_log("img_list cleaned-up")
      dt.print_log("face recognition complete")
      dt.print(_("face recognition complete"))
    else
      dt.print(_("image export failed"))
      return
    end
  else
    dt.print(_("no images selected"))
    return
  end
end

local function install_module()
  if not fc.module_installed then
    dt.register_lib(
      MODULE,     -- Module name
      _("face recognition"),     -- Visible name
      true,                -- expandable
      true,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 300}},   -- containers
      fc.widget,
      nil,-- view_enter
      nil -- view_leave
    )
    fc.module_installed = true
  end
end

local function destroy()
  dt.gui.libs[MODULE].visible = false
end

local function restart()
  dt.gui.libs[MODULE].visible = true
end

-- build the interface

fc.unknown_tag = dt.new_widget("entry"){
  text = dt.preferences.read(MODULE, "unknown_tag", "string"),
  tooltip = _("tag to be used for unknown person"),
  editable = true,
}

fc.no_persons_found_tag = dt.new_widget("entry"){
  text = dt.preferences.read(MODULE, "no_persons_found_tag", "string"),
  tooltip = _("tag to be used when no persons are found"),
  editable = true,
}

fc.ignore_tags = dt.new_widget("entry"){
  text = dt.preferences.read(MODULE, "ignore_tags", "string"),
  tooltip = _("tags of images to ignore"),
  editable = true,
}

fc.category_tags = dt.new_widget("entry"){
  text = dt.preferences.read(MODULE, "category_tags", "string"),
  tooltip = _("tag category"),
  editable = true,
}

fc.tolerance = dt.new_widget("slider"){
  label = _("tolerance"),
  tooltip = _("detection tolerance - 0.6 default - lower if too many faces detected"),
  soft_min = 0.0,
  hard_min = 0.0,
  soft_max = 1.0,
  soft_min = 1.0,
  step = 0.1,
  digits = 1,
  value = 0.0,
}

fc.num_cores = dt.new_widget("slider"){
  label = _("processor cores"),
  tooltip = _("number of processor cores to use, 0 for all"),
  soft_min = 0,
  soft_max = 16,
  hard_min = 0,
  hard_max = 64,
  step = 1,
  digits = 0,
  value = dt.preferences.read(MODULE, "num_cores", "integer"),
}

fc.known_image_path = dt.new_widget("file_chooser_button"){
  title = _("known image directory"),
  tooltip = _("face data directory"),
  value = dt.preferences.read(MODULE, "known_image_path", "directory"),
  is_directory = true,
  changed_callback = function(this)
    dt.preferences.write(MODULE, "known_image_path", "directory", this.value)
  end
}

fc.export_format = dt.new_widget("combobox"){
  label = _("export image format"),
  tooltip = _("format for exported images"),
  selected = dt.preferences.read(MODULE, "export_format", "integer"),
  changed_callback = function(this)
    dt.preferences.write(MODULE, "export_format", "integer", this.selected)
  end,
  "JPEG", "PNG", "TIFF",
}

fc.width = dt.new_widget("entry"){
  text = tostring(dt.preferences.read(MODULE, "max_width", "integer")),
  tooltip = _("maximum exported image width"),
  editable = true,
}

fc.height = dt.new_widget("entry"){
  text = tostring(dt.preferences.read(MODULE, "max_height", "integer")),
  tooltip = _("maximum exported image height"),
  editable = true,
}

fc.execute = dt.new_widget("button"){
  label = "detect faces",
  clicked_callback = function(this) 
    face_recognition()
  end
}

local widgets = {
  dt.new_widget("label"){ label = _("unknown person tag")},
  fc.unknown_tag,
  dt.new_widget("label"){ label = _("no persons found tag")},
  fc.no_persons_found_tag,
  dt.new_widget("label"){ label = _("tags of images to ignore")},
  fc.ignore_tags,
  dt.new_widget("label"){ label = _("tag category")},
  fc.category_tags,
  dt.new_widget("label"){ label = _("face data directory")},
  fc.known_image_path,
}

if dt.configuration.running_os == "windows" or dt.configuration.running_os == "macos" then
  table.insert(widgets, df.executable_path_widget({"face_recognition"}))
end
table.insert(widgets, dt.new_widget("section_label"){ label = _("processing options")})
table.insert(widgets, fc.tolerance)
table.insert(widgets, fc.num_cores)
table.insert(widgets, fc.export_format)
table.insert(widgets, dt.new_widget("box"){
  orientation = "horizontal",
  dt.new_widget("label"){ label = _("width")},
  fc.width,
})
table.insert(widgets, dt.new_widget("box"){
  orientation = "horizontal",
  dt.new_widget("label"){ label = _("height")},
  fc.height,
})
table.insert(widgets, fc.execute)

fc.widget = dt.new_widget("box"){
  orientation = vertical,
  reset_callback = function(this)
    reset_preferences()
  end,
  table.unpack(widgets),
}

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not fc.event_registered then
    dt.register_event(
      MODULE, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    fc.event_registered = true
  end
end

fc.tolerance.value = dt.preferences.read(MODULE, "tolerance", "float")

-- preferences

if not dt.preferences.read(MODULE, "initialized", "bool") then
  reset_preferences()
  save_preferences()
  dt.preferences.write(MODULE, "initialized", "bool", true)
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
