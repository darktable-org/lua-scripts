--[[

    rename.lua - rename image file(s)

    Copyright (C) 2020, 2021 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    rename - rename an image file or files

    This shortcut resets the GPS information to that contained within
    the image file.  If no GPS info is in the image file, the GPS data
    is cleared.

    USAGE
    * require this script from your luarc file or start it from script_manager
    * select an image or images
    * enter a renaming pattern
    * click the button to rename the files

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES

    TODO 
    * Add pattern builder
    * Add new name preview
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

du.check_min_api_version("7.0.0", "rename_images") 

local gettext = dt.gettext

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("rename_images",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("rename_images", msgid)
end

-- namespace variable
local rename = {
  presets = {},
  substitutes = {},
  placeholders = {"ROLL_NAME","FILE_FOLDER","FILE_NAME","FILE_EXTENSION","ID","VERSION","SEQUENCE","YEAR","MONTH","DAY",
                  "HOUR","MINUTE","SECOND","EXIF_YEAR","EXIF_MONTH","EXIF_DAY","EXIF_HOUR","EXIF_MINUTE","EXIF_SECOND",
                  "STARS","LABELS","MAKER","MODEL","TITLE","CREATOR","PUBLISHER","RIGHTS","USERNAME","PICTURES_FOLDER",
                  "HOME","DESKTOP","EXIF_ISO","EXIF_EXPOSURE","EXIF_EXPOSURE_BIAS","EXIF_APERTURE","EXIF_FOCUS_DISTANCE",
                  "EXIF_FOCAL_LENGTH","LONGITUDE","LATITUDE","ELEVATION","LENS","DESCRIPTION","EXIF_CROP"},
  widgets = {},
}
rename.module_installed = false
rename.event_registered = false

-- script_manager integration
local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again


-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "rename_images"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local USER = os.getenv("USERNAME")
local HOME = os.getenv(dt.configuration.running_os == "windows" and "HOMEPATH" or "HOME")
local PICTURES = HOME .. PS .. dt.configuration.running_os == "windows" and "My Pictures" or "Pictures"
local DESKTOP = HOME .. PS .. "Desktop"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

local function build_substitution_list(image, sequence, datetime, username, pic_folder, home, desktop)
 -- build the argument substitution list from each image
 -- local datetime = os.date("*t")
 local colorlabels = {}
 if image.red then table.insert(colorlabels, "red") end
 if image.yellow then table.insert(colorlabels, "yellow") end
 if image.green then table.insert(colorlabels, "green") end
 if image.blue then table.insert(colorlabels, "blue") end
 if image.purple then table.insert(colorlabels, "purple") end
 local labels = #colorlabels == 1 and colorlabels[1] or du.join(colorlabels, ",")
 local eyear,emon,eday,ehour,emin,esec = string.match(image.exif_datetime_taken, "(%d-):(%d-):(%d-) (%d-):(%d-):(%d-)$")
 local replacements = {image.film,
                       image.path,
                       df.get_filename(image.filename),
                       string.upper(df.get_filetype(image.filename)),
                       image.id,image.duplicate_index,
                       string.format("%04d", sequence),
                       datetime.year,
                       string.format("%02d", datetime.month),
                       string.format("%02d", datetime.day),
                       string.format("%02d", datetime.hour),
                       string.format("%02d", datetime.min),
                       string.format("%02d", datetime.sec),
                       eyear,
                       emon,
                       eday,
                       ehour,
                       emin,
                       esec,
                       image.rating,
                       labels,
                       image.exif_maker,
                       image.exif_model,
                       image.title,
                       image.creator,
                       image.publisher,
                       image.rights,
                       username,
                       pic_folder,
                       home,
                       desktop,
                       image.exif_iso,
                       image.exif_exposure,
                       image.exif_exposure_bias,
                       image.exif_aperture,
                       image.exif_focus_distance,
                       image.exif_focal_length,
                       image.longitude,
                       image.latitude,
                       image.elevation,
                       image.exif_lens,
                       image.description,
                       image.exif_crop
                     }

  for i=1,#rename.placeholders,1 do rename.substitutes[rename.placeholders[i]] = replacements[i] end
end

local function substitute_list(str)
  -- replace the substitution variables in a string
  for match in string.gmatch(str, "%$%(.-%)") do
    local var = string.match(match, "%$%((.-)%)")
    if rename.substitutes[var] then
      str = string.gsub(str, "%$%("..var.."%)", rename.substitutes[var])
    else
      dt.print_error(_("unrecognized variable " .. var))
      dt.print(_("unknown variable " .. var .. ", aborting..."))
      return -1
    end
  end
  return str
end

local function clear_substitute_list()
  for i=1,#rename.placeholders,1 do rename.substitutes[rename.placeholders[i]] = nil end
end

local function stop_job(job)
  job.valid = false
end

local function install_module()
  if not rename.module_installed then
    dt.register_lib(
      MODULE_NAME,
      _("rename images"),
      true,
      true,
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER",700}},
      dt.new_widget("box"){
        orientation = "vertical",
        rename.widgets.pattern,
        rename.widgets.button,
      },
      nil,
      nil
    )
    rename.module_installed = true
  end
end

local function destroy()
  dt.gui.libs[MODULE_NAME].visible = false
end

local function restart()
  dt.gui.libs[MODULE_NAME].visible = true
end  

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

local function do_rename(images)
  if #images > 0 then
    local pattern = rename.widgets.pattern.text
    dt.preferences.write(MODULE_NAME, "pattern", "string", pattern)
    dt.print_log(_("pattern is " .. pattern))
    if string.len(pattern) > 0 then
      local datetime = os.date("*t")

      local job = dt.gui.create_job(_("renaming images"), true, stop_job)
      for i, image in ipairs(images) do
        if job.valid then
          job.percent = i / #images
          build_substitution_list(image, i, datetime, USER, PICTURES, HOME, DESKTOP)
          local new_name = substitute_list(pattern)
          if new_name == -1 then
            dt.print(_("unable to do variable substitution, exiting..."))
            stop_job(job)
            return
          end
          clear_substitute_list()
          local args = {}
          local path = string.sub(df.get_path(new_name), 1, -2)
          if string.len(path) == 0 then
            path = image.path
          end
          local filename = df.get_filename(new_name)
          local filmname = image.path
          if path ~= image.path then
            if not df.check_if_file_exists(df.sanitize_filename(path)) then
              df.mkdir(df.sanitize_filename(path))
            end
            filmname = path
          end
          args[1] = dt.films.new(filmname)
          args[2] = image
          if filename ~= image.filename then
            args[3] = filename
          end
          dt.database.move_image(table.unpack(args))
        end
      end
      stop_job(job)
      local collect_rules = dt.gui.libs.collect.filter()
      dt.gui.libs.collect.filter(collect_rules)
      dt.print(_("renamed " .. #images .. " images"))
    else -- pattern length
      dt.print_error("no pattern supplied, returning...")
      dt.print(_("please enter the new name or pattern"))
    end
  else -- image count
    dt.print_error("no images selected, returning...")
    dt.print(_("please select some images and try again"))
  end
end

local function reset_callback()
  rename.widgets.pattern.text = ""
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- W I D G E T S
-- - - - - - - - - - - - - - - - - - - - - - - -

rename.widgets.pattern = dt.new_widget("entry"){
  tooltip = _("$(ROLL_NAME) - film roll name\n") .. 
            _("$(FILE_FOLDER) - image file folder\n") ..
            _("$(FILE_NAME) - image file name\n") ..
            _("$(FILE_EXTENSION) - image file extension\n") ..
            _("$(ID) - image id\n") ..
            _("$(VERSION) - version number\n") ..
            _("$(SEQUENCE) - sequence number of selection\n") ..
            _("$(YEAR) - current year\n") ..
            _("$(MONTH) - current month\n") ..
            _("$(DAY) - current day\n") ..
            _("$(HOUR) - current hour\n") ..
            _("$(MINUTE) - current minute\n") ..
            _("$(SECOND) - current second\n") ..
            _("$(EXIF_YEAR) - EXIF year\n") ..
            _("$(EXIF_MONTH) - EXIF month\n") ..
            _("$(EXIF_DAY) - EXIF day\n") ..
            _("$(EXIF_HOUR) - EXIF hour\n") ..
            _("$(EXIF_MINUTE) - EXIF minute\n") ..
            _("$(EXIF_SECOND) - EXIF seconds\n") ..
            _("$(EXIF_ISO) - EXIF ISO\n") ..
            _("$(EXIF_EXPOSURE) - EXIF exposure\n") ..
            _("$(EXIF_EXPOSURE_BIAS) - EXIF exposure bias\n") ..
            _("$(EXIF_APERTURE) - EXIF aperture\n") ..
            _("$(EXIF_FOCAL_LENGTH) - EXIF focal length\n") ..
            _("$(EXIF_FOCUS_DISTANCE) - EXIF focus distance\n") ..
            _("$(EXIF_CROP) - EXIF crop\n") ..
            _("$(LONGITUDE) - longitude\n") ..
            _("$(LATITUDE) - latitude\n") ..
            _("$(ELEVATION) - elevation\n") ..
            _("$(STARS) - star rating\n") ..
            _("$(LABELS) - color labels\n") ..
            _("$(MAKER) - camera maker\n") ..
            _("$(MODEL) - camera model\n") ..
            _("$(LENS) - lens\n") ..
            _("$(TITLE) - title from metadata\n") ..
            _("$(DESCRIPTION) - description from metadata\n") ..
            _("$(CREATOR) - creator from metadata\n") ..
            _("$(PUBLISHER) - publisher from metadata\n") ..
            _("$(RIGHTS) - rights from metadata\n") ..
            _("$(USERNAME) - username\n") ..
            _("$(PICTURES_FOLDER) - pictures folder\n") ..
            _("$(HOME) - user's home directory\n") ..
            _("$(DESKTOP) - desktop directory"),
  placeholder = _("enter pattern $(FILE_FOLDER)/$(FILE_NAME)"),
  text = ""
}

local pattern_pref = dt.preferences.read(MODULE_NAME, "pattern", "string")
if pattern_pref then
  rename.widgets.pattern.text = pattern_pref
end

rename.widgets.button = dt.new_widget("button"){
  label = _("rename"),
  clicked_callback = function(this)
    do_rename(dt.gui.action_images)
  end
}

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not rename.event_registered then
    dt.register_event(
      "rename_images", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    rename.event_registered = true
  end
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
