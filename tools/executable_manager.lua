--[[
  This file is part of darktable,
  copyright (c) 2018 Bill Ferguson
  
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
    executable_manager.lua - a tool for managing external executables used by darktable lua scripts

    executable_manager is a tool for managing the executable preferences stored in the darktablerc file.
    On startup the darktablerc file is scanned and a widget is built for each executable path.  The user
    can select the executable from a drop down list and then modify the settings as desired.

    Any changes made using executable_manager won't be saved in the darktablerc file until darktable exits, but
    the preference is updated when the change is made so scripts will pick up the changes without restarting
    darktable.

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

local PS = dt.configuration.running_os == "windows" and "\\" or "/"

local gettext = dt.gettext

gettext.bindtextdomain("executable_manager",dt.configuration.config_dir.."/lua/locale/")

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - 

local function _(msg)
    return gettext.dgettext("executable_manager", msg)
end

local function grep(file, pattern)

  local result = {}

  if dt.configuration.running_os == "windows" then
    -- use find to get the matches
    local command = "\\windows\\system32\\find.exe " .. "\"" .. pattern .. "\"" .. " " .. file
    local f = io.popen(command)
    local output = f:read("all")
    f:close()
    -- strip out the first line
    result = du.split(output, "\n")
    table.remove(result, 1)
  else
    -- use grep and just return the answers
    local command = "grep " .. pattern .. " " .. file
    local f = io.popen(command)
    local output = f:read("all")
    f:close()
    result = du.split(output, "\n")
  end
  return result
end

local function update_combobox_choices(combobox, choice_table, selected)
  local items = #combobox
  local choices = #choice_table
  for i, name in ipairs(choice_table) do 
    combobox[i] = name
  end
  if choices < items then
    for j = items, choices + 1, -1 do
      combobox[j] = nil
    end
  end
  combobox.value = selected
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N   P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - 

local exec_man = {} -- our own namespace

local DARKTABLERC = dt.configuration.config_dir .. PS .. "darktablerc"


-- grep the executable_paths statements out of the darktablerc file

local matches = grep(DARKTABLERC, "executable_paths")

-- check if we have something to manage and exit if not

if #matches == 0 then
  dt.print(_("No executable paths found, exiting..."))
  return
end

-- build a table of the path preferences

local exec_table = {}

for _,pref  in ipairs(matches) do
  local parts = du.split(pref, "=")
  local tmp = du.split(parts[1], PS)
  table.insert(exec_table, tmp[#tmp])
end

local executable_path_widgets = {}

for i,exec in ipairs(exec_table) do 
  executable_path_widgets[exec] = dt.new_widget("file_chooser_button"){
    title = _("select ") .. exec .. _(" executable"),
    value = df.get_executable_path_preference(exec),
    is_directory = false,
    changed_callback = function(self)
      if df.check_if_bin_exists(self.value) then
        df.set_executable_path_preference(exec, self.value)
      end
    end
  }
end

-- create a stack widget to hold the executable path widgets

exec_man.stack = dt.new_widget("stack"){}


-- create a combobox to for indexing into the stack of widgets

exec_man.selector = dt.new_widget("combobox"){
  label = "executable",
  tooltip = _("select executable to modify"),
  value = 1, "placeholder",
  changed_callback = function(self)
    for i,exec in ipairs(exec_table) do
      if self.value == exec then
        exec_man.stack.active = i
      end
    end
  end
}

-- loop through the tabke of path preferences and populate the widgets

for i,exec in ipairs(exec_table) do
  exec_man.stack[i] = dt.new_widget("box"){
    executable_path_widgets[exec],
    dt.new_widget("button"){
      label = "clear",
      tooltip = _("Clear path for ") .. exec,
      clicked_callback = function()
        df.set_executable_path_preference(exec, "")
        executable_path_widgets[exec].value = ""
      end
    }

  }
  df.executable_path_widget({exec})
end

update_combobox_choices(exec_man.selector, exec_table, 1)

-- register the lib


dt.register_lib(
  "executable_manager",     -- Module name
  "executable manager",     -- Visible name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    exec_man.selector,
    exec_man.stack,
  },
  nil,-- view_enter
  nil -- view_leave
)

