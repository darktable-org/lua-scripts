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
local ds = require "lib/dtutils.string"

du.check_min_api_version("7.0.0", "rename_images") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- namespace variable
local rename = {
  presets = {},
  widgets = {},
}
rename.module_installed = false
rename.event_registered = false

-- script_manager integration
local script_data = {}

script_data.metadata = {
  name = _("rename images"),
  purpose = _("rename an image file or files"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/rename_images"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "rename_images"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local USER = os.getenv("USERNAME")
local HOME = os.getenv(dt.configuration.running_os == "windows" and "HOMEPATH" or "HOME")
local PICTURES = HOME .. PS .. dt.configuration.running_os == "windows" and _("My Pictures") or _("Pictures")
local DESKTOP = HOME .. PS .. "Desktop"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

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
    local first_image = images[1]
    local pattern = rename.widgets.pattern.text
    dt.preferences.write(MODULE_NAME, "pattern", "string", pattern)
    dt.print_log("pattern is " .. pattern)
    if string.len(pattern) > 0 then
      local datetime = os.date("*t")

      local job = dt.gui.create_job(_("renaming images"), true, stop_job)
      for i, image in ipairs(images) do
        if job.valid then
          job.percent = i / #images
          ds.build_substitute_list(image, i, pattern, USER, PICTURES, HOME, DESKTOP)
          local new_name = ds.substitute_list(pattern)
          if new_name == -1 then
            dt.print(_("unable to do variable substitution, exiting..."))
            stop_job(job)
            return
          end
          ds.clear_substitute_list()
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
      dt.gui.views.lighttable.set_image_visible(first_image)
      dt.print(string.format(_("renamed %d images"), #images))
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
  tooltip = ds.get_substitution_tooltip(),
  placeholder = _("enter pattern") .. "$(FILE_FOLDER)/$(FILE_NAME)",
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
