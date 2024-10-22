--[[
    This file is part of darktable,
    copyright (c) 2019 Bill Ferguson <wpferguson@gmail.com>

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
    panels_demo - an example script demonstrating how to contol panel visibility

    panels_demo is an example script showing how to control panel visibility.  It cycles
    through the panels hiding them one by one, then showing them one by one, then 
    hiding all, then showing all.  Finally, the original panel visibility is restored.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * none

    USAGE
    * require this script from your main lua file

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- V E R S I O N  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - -

du.check_min_api_version("7.0.0", "panels_demo") 

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    -- nothing to destroy
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "panels_demo"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- T R A N S L A T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -
local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - -

-- alias dt.control.sleep to sleep
local sleep = dt.control.sleep

local panels = {"DT_UI_PANEL_CENTER_TOP",     -- center top panel
                "DT_UI_PANEL_CENTER_BOTTOM",  -- center bottom panel 
                "DT_UI_PANEL_TOP",            -- complete top panel
                "DT_UI_PANEL_LEFT",           -- left panel 
                "DT_UI_PANEL_RIGHT",          -- right panel 
                "DT_UI_PANEL_BOTTOM"}         -- complete bottom panel

local panel_status = {}

-- save panel visibility

for i = 1,#panels do
  panel_status[i] = dt.gui.panel_visible(panels[i])
end

-- show all just in case

dt.gui.panel_show_all()

-- hide center_top, center_bottom, left, top, right, bottom in order

dt.print(_("hiding all panels, one at a time"))
sleep(1500)

for i = 1, #panels do
  dt.print(string.format(_("hiding %s"), panels[i]))
  dt.gui.panel_hide(panels[i])
  sleep(1500)
end

-- display left, then top, then right, then bottom

  dt.print(_("make panels visible, one at a time"))
  sleep(1500)

  for i = #panels, 1, -1 do
    dt.print(string.format(_("showing %s"), panels[i]))
    dt.gui.panel_show(panels[i])
    sleep(1500)
  end

-- hide all

dt.print(_("hiding all panels"))
sleep(1500)

dt.gui.panel_hide_all()
sleep(1500)

-- show all

dt.print(_("showing all panels"))
sleep(1500)

dt.gui.panel_show_all()
sleep(1500)

-- restore

dt.print(_("restoring panels to starting configuration"))
for i = 1, #panels do
  if panel_status[i] then
    dt.gui.panel_show(panels[i])
  else
    dt.gui.panel_hide(panels[i])
  end
end

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("panels demo"),
  purpose = _("example demonstrating how to contol panel visibility"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/panels_demo"
}

script_data.destroy = destroy

return script_data
