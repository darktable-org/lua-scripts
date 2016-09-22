--[[
  This file is part of darktable,
  copyright (c) 2016 Bill Ferguson
  copyright (c) 2016 Tobias Jakobs
  copyright (c) 2014 Jérémy Rosen
  
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
  plugin_manager - a script to manage plugins

  plugin_manager ....

  ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
  * none

  USAGE

  CAVEATS

  BUGS, COMMENTS, SUGGESTIONS
  * Send to Bill Ferguson, wpferguson@gmail.com


]]
local dt = require "darktable"
require "lib/dtutils"
require "lib/libPlugin"
-- dtdb = require "darktable.debug"
-- dtdb.debug = true
-- print(dtdb.dump(_G, "Global Environment"))

dt.configuration.check_version(...,{3,0,0})

plugins = {}
processors = {}
processor_cmds = {}
processor_names = {}
plugin_widgets = {}
plugin_widget_cnt = 1
pmstartup = true

local plugin_path = dt.configuration.config_dir .. "/lua/plugins"

if not dtutils.checkIfFileExists(plugin_path) then
  -- no plugin directory, therefore nothing to do
  return
end

-- load the plugins
local output = io.popen("cd "..plugin_path..";find . -maxdepth 1 -type d -print | sort")
for line in output:lines() do
  local plugin = line:sub(3,-1)
  if plugin == "clear_GPS"  or plugin == "hugin" then
    -- process it
    local plugin_data = "plugins/" .. plugin .. "/plugin-data"
    print("plugin_data is " .. plugin_data)
    local plugin_data = require(plugin_data)
    for _,i in pairs(plugin_data.DtPlugins) do
      if libPlugin.check_api_version(i.DtVersionRequired) then
        print("checked version and passed")
        plugins[i.DtPluginName] = i
        print(plugins[i.DtPluginName])
        if dt.preferences.read("plugin_manager", i.DtPluginPreference, "bool") then
          libPlugin.activate_plugin(i)
          libPlugin.add_plugin_widget(i, true)
        else
          dt.preferences.write("plugin_manager", i.DtPluginPreference, "bool", false)
          libPlugin.add_plugin_widget(i, false)
        end
      else
        dt.print_error(plugin .. " not compatible with this version of darktable")
      end
    end
  else
    dt.print_error("Ignoring " .. plugin)
  end
end
-- install it
dt.register_lib(
  "Plugin Manager",     -- Module name
  "Plugin Manager",     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    orientation = "vertical",
    table.unpack(plugin_widgets),
  },
  nil,-- view_enter
  nil -- view_leave
)

-- Provide a home for the processor plugins that require exported images
-- the place for processors

if #processor_names > 0 then
  libPlugin.register_processor_lib(processor_names)
end
pmstartup = false

