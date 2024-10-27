--[[

    color_profile_manager.lua - manage external darktable color profiles

    Copyright (C) 2021 Bill Ferguson <wpferguson@gmail.com>.

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
    color_profile_manager - manage external darktable color profiles

    This script provides a tool to manage input and output external color
    profiles used by darktable.  Color profiles can be added or removed
    to/from the correct directories so that darktable can find and use
    them.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * None

    USAGE
    * require this script from your main lua file
    * select the input or output set of color profiles
    * a list of profiles is displayed.  Click the check box beside the
      profile name to select it for removal.  Click the "remove profile" 
      button to remove the profile.
    * use the file selector to select a color profile to add to the currently
      selected set (input or output)
    * click the "add profile" button to add the profile to the selected set

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com or raise an issue on 
      https://github.com/dakrtable-org/lua-scripts
]]
local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

du.check_min_api_version("7.0.0", "color_profile_manager")

-- - - - - - - - - - - - - - - - - - - - - - - -
-- L O C A L I Z A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "color_profile_manager"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"
local CS = dt.configuration.running_os == "windows" and "&" or ";"
local DIR_CMD = dt.configuration.running_os == "windows" and "dir /b" or "ls"
local COLOR_IN_DIR = dt.configuration.config_dir .. PS .. "color" .. PS .. "in"
local COLOR_OUT_DIR = dt.configuration.config_dir .. PS .. "color" .. PS .. "out"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- N A M E S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - -

local cpm = {}
cpm.widgets = {}
cpm.widgets.profile_box = dt.new_widget("box"){
  orientation = "vertical",
}
cpm.module_installed = false
cpm.event_registered = false
-- - - - - - - - - - - - - - - - - - - - - - - -
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -

local function check_for_directories()
  if not df.test_file(COLOR_IN_DIR, "d") then
    dt.print_log("didn't find " .. COLOR_IN_DIR)
    return false
  elseif not df.test_file(COLOR_OUT_DIR, "d") then
    dt.print_log("didn't find " .. COLOR_OUT_DIR)
    return false
  else
    dt.print_log("both directories exist")
    return true
  end
end

local function add_directories()
  df.mkdir(COLOR_IN_DIR)
  df.mkdir(COLOR_OUT_DIR)
end

local function list_profiles(dir)
  local files = {}
  local p = io.popen(DIR_CMD .. " " .. dir)
  if p then
    for line in p:lines() do
      table.insert(files, line)
    end
  end
  p:close()
  return files
end

local function add_profile(file, dir)
  df.file_copy(file, dir)
  dt.print(string.format(_("added color profile %s to %s"), file, dir))
  dt.print_log("color profile " .. file .. " added to " .. dir)
end

local function remove_profile(file, dir)
  os.remove(dir .. PS .. file)
  dt.print(string.format(_("removed color profile %s from %s"), file, dir))
  dt.print_log("color profile " .. file .. " removed from " .. dir)
end

local function clear_profile_box()
  for i = #cpm.widgets.profile_box, 1, -1 do
    cpm.widgets.profile_box[i] = nil 
  end
end

local function add_profile_callback()
  local  profile_dir = COLOR_IN_DIR
  if cpm.widgets.profile_set.selected == 2 then
    profile_dir = COLOR_OUT_DIR
  end

  local new_profile = cpm.widgets.profile_selector.value
  if string.lower(df.get_filetype(new_profile)) ~= "icm" and string.lower(df.get_filetype(new_profile)) ~= "icc" then
    dt.print(_("ERROR: color profile must be an icc or icm file"))
    dt.print_error(new_profile .. " selected and isn't an icc or icm file")
    return
  end

  -- set selector value to directory that new profile came from
  -- in case there are more
  cpm.widgets.profile_selector.value = df.get_path(cpm.widgets.profile_selector.value)
  add_profile(new_profile, profile_dir)
  local files = list_profiles(profile_dir)
  local widgets = {}

  local profile_ptr = 1
  for i, file in ipairs(files) do
    if #cpm.widgets.profile_box == 0 or cpm.widgets.profile_box[profile_ptr].label ~= file then
      table.insert(widgets, dt.new_widget("check_button"){value = false, label = file})
    else
      table.insert(widgets, cpm.widgets.profile_box[profile_ptr])
      profile_ptr = profile_ptr + 1
      if profile_ptr > #cpm.widgets.profile_box then
        profile_ptr = #cpm.widgets.profile_box
      end
    end
  end
  clear_profile_box()
  for _, widget in ipairs(widgets) do
    table.insert(cpm.widgets.profile_box, widget)
  end 
  if not cpm.widgets.remove_box.visible then
    cpm.widgets.remove_box.visible = true
  end
end

local function remove_profile_callback()
  local widgets_to_keep = {}
  local profile_dir = COLOR_IN_DIR
  if cpm.widgets.profile_set.selected == 2 then
    profile_dir = COLOR_OUT_DIR
  end

  for _, widget in ipairs(cpm.widgets.profile_box) do
    if widget.value == true then
      remove_profile(widget.label, profile_dir)
    else
      table.insert(widgets_to_keep, widget)
    end
  end
  clear_profile_box()
  for _, widget in ipairs(widgets_to_keep) do
    table.insert(cpm.widgets.profile_box, widget)
  end
  if #cpm.widgets.profile_box == 0 then
    cpm.widgets.remove_box.visible = false
  else
    cpm.widgets.remove_box.visible = true
  end
end

local function list_profile_callback(choice)
  local list_dir = COLOR_IN_DIR
  if choice == 2 then
    list_dir = COLOR_OUT_DIR
  end

  local files = list_profiles(list_dir)

  if #files == 0 then
    cpm.widgets.remove_box.visible = false
  else
    cpm.widgets.remove_box.visible = true
  end

  clear_profile_box()

  for i, file in ipairs(files) do
     cpm.widgets.profile_box[i] = dt.new_widget("check_button"){value = false, label = file}
  end
end

local function install_module()
  if not cpm.module_installed then
    dt.register_lib(
      MODULE_NAME,     -- Module name
      _("color profile manager"),     -- Visible name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 0}},   -- containers
      cpm.widgets.main_widget,
      nil,-- view_enter
      nil -- view_leave
    )
    cpm.module_installed = true
    dt.control.sleep(500)
    if not cpm.initialized then
      cpm.widgets.profile_set.visible = false
      cpm.widgets.add_box.visible = false
      cpm.widgets.remove_box.visible = false
    else
      cpm.widgets.profile_set.selected = 1
    end
  end
end

local function destroy()
  dt.gui.libs[MODULE_NAME].visible = false
  return
end

local function restart()
  dt.gui.libs[MODULE_NAME].visible = true
  return
end
-- - - - - - - - - - - - - - - - - - - - - - - -
-- W I D G E T S
-- - - - - - - - - - - - - - - - - - - - - - - -

cpm.initialized = check_for_directories()
dt.print_log("cpm.initialized is " .. tostring(cpm.initialized))

if not cpm.initialized then
  dt.print_log("creating init_box")
  cpm.widgets.init_box = dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("button"){
      label = _("initialize color profiles"),
      tooltip = _("create the directory structure to contain the color profiles"),
      clicked_callback = function(this)
        add_directories()
        cpm.initialized = true
        cpm.widgets.profile_set.visible = true
        cpm.widgets.add_box.visible = true
        cpm.widgets.remove_box.visible = false
        cpm.widgets.init_box.visible = false
        cpm.widgets.profile_set.selected = 1
      end
    }
  }
end

cpm.widgets.profile_set = dt.new_widget("combobox"){
  label = _("select profile set"),
  tooltip = _("select input or output profiles"),
  visible = cpm.initialized and false or true,
  changed_callback = function(this)
    if cpm.initialized then
      list_profile_callback(this.selected)
    end
  end,
  _("input"), _("output"),
}

cpm.widgets.profile_selector = dt.new_widget("file_chooser_button"){
  title = _("select color profile to add"),
  tooltip = _("select the .icc or .icm file to add"),
  is_directory = false
}

cpm.widgets.add_box = dt.new_widget("box"){
  orientation = "vertical",
  visible = cpm.initialized and true or false,
  dt.new_widget("section_label"){label = _("add profile")},
  cpm.widgets.profile_selector,
  dt.new_widget("button"){
    label = _("add selected color profile"),
    tooltip = _("add selected file to profiles"),
    clicked_callback = function(this)
      add_profile_callback()
    end
  }
}

cpm.widgets.remove_box = dt.new_widget("box"){
  orientation = "vertical",
  visible = cpm.initialized and true or false,
  dt.new_widget("section_label"){label = _("remove profile")},
  cpm.widgets.profile_box,
  dt.new_widget("button"){
    label = _("remove selected profile(s)"),
    tooltip = _("remove the checked profile(s)"),
    clicked_callback = function(this)
      remove_profile_callback()
    end
  }
}

local main_widgets = {}

if not cpm.initialized then
  table.insert(main_widgets, cpm.widgets.init_box)
end
table.insert(main_widgets, cpm.widgets.profile_set)
table.insert(main_widgets, cpm.widgets.remove_box)
table.insert(main_widgets, cpm.widgets.add_box)

cpm.widgets.main_widget = dt.new_widget("box"){
  orientation = "vertical",
  table.unpack(main_widgets)
}

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not cpm.event_registered then
    dt.register_event(
      MODULE_NAME, "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    cpm.event_registered = true
  end
end

local script_data = {}

script_data.metadata = {
  name = _("color profile manager"),
  purpose = _("manage external darktable color profiles"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/color_profile_manager"
}

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data