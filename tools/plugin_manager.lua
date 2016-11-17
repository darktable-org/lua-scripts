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
  * require this script from the luarc file
  * install some plugins in the $HOME/.config/darktable/lua/plugins

  CAVEATS
  * plugins must conform to the (as yet unwritten ;)) plugin specification

  BUGS, COMMENTS, SUGGESTIONS
  * Send to Bill Ferguson, wpferguson@gmail.com


]]
local dt = require "darktable"
local dtutils = require "lib/dtutils"
local dtfileutils = require "lib/dtutils.file"
local libPlugin = require "lib/libPlugin"
local log = require "lib/dtutils.log"

dt.configuration.check_version(...,{3,0,0},{4,0,0})

plugins = {}
processors = {}
processor_cmds = {}
processor_names = {}
plugin_widgets = {}
plugin_widget_cnt = 1
pmstartup = true

log.log_level(log.debug)

--[[
Plugin manager creates many widgets during startup, depending on the number of plugins.
Sometimes the garbage collector runs during widget creation and starts reaping widgets 
before they are used, resulting in crashes and an ugly run of error messages.  Therefore,
we turn off garbage collection during startup and re-enable it at the end of the script.
]]

collectgarbage("stop")

local plugin_path = dt.configuration.config_dir .. "/lua/plugins"

if not dtfileutils.check_if_file_exists(plugin_path) then
  -- no plugin directory, therefore nothing to do
  return
end

-- load the plugins
--local output = io.popen("cd "..plugin_path..";find . -maxdepth 1 -type d -print | sort")
local output = io.popen("cd "..plugin_path..";find . -maxdepth 1 -print | sort")
for line in output:lines() do
  local plugin = line:sub(3,-1)
  if plugin:len() > 1 then
    -- process it
    local plugin_data = "plugins/" .. plugin .. "/plugin-data"
    log.msg(log.debug, "plugin_data is " .. plugin_data)
    local plugin_data = require(plugin_data)
    for _,i in pairs(plugin_data.DtPlugins) do
      if libPlugin.check_api_version(i.DtVersionRequired) then
        log.msg(log.debug, "checked version and passed")
        plugins[i.DtPluginName] = i
        log.msg(log.debug, plugins[i.DtPluginName])
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

-- install the plugin manager
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

if #processor_names > 0 then
  log.msg(log.debug, "startup register processor")
  log.msg(log.info, "processor names are ", table.unpack(processor_names))
  libPlugin.register_processor_lib(processor_names)
  log.msg(log.debug, "done registering processors on startup")
else
  log.msg(log.warn, "No Processors Found")
end

pmstartup = false

-- restart the garbage collector now that we are done creating widgets

collectgarbage("restart")

