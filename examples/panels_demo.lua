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

du.check_min_api_version("5.0.2", "panels_demo")  -- darktable 3.0

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "panels"
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- - - - - - - - - - - - - - - - - - - - - - - -
-- T R A N S L A T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - -
local gettext = dt.gettext
gettext.bindtextdomain(MODULE_NAME, dt.configuration.config_dir..PS.."lua"..PS.."locale"..PS)

local function _(msgid)
  return gettext.dgettext(MODULE_NAME, msgid)
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

dt.print(_("Hiding all panels, one at a tme"))
sleep(1500)

for i = 1, #panels do
  dt.print(_("Hiding " .. panels[i]))
  dt.gui.panel_hide(panels[i])
  sleep(1500)
end

-- display left, then top, then right, then bottom

  dt.print(_("Make panels visible, one at a time"))
  sleep(1500)

  for i = #panels, 1, -1 do
    dt.print(_("Showing " .. panels[i]))
    dt.gui.panel_show(panels[i])
    sleep(1500)
  end

-- hide all

dt.print(_("Hiding all panels"))
sleep(1500)

dt.gui.panel_hide_all()
sleep(1500)

-- show all

dt.print(_("Showing all panels"))
sleep(1500)

dt.gui.panel_show_all()
sleep(1500)

-- restore

dt.print(_("Restoring panels to starting configuration"))
for i = 1, #panels do
  if panel_status[i] then
    dt.gui.panel_show(panels[i])
  else
    dt.gui.panel_hide(panels[i])
  end
end
