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
    darkroom_demo - an example script demonstrating how to control image display in darkroom mode

    darkroom_demo is an example script showing how to control the currently displayed image in 
    darkroom mode using lua.

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

du.check_min_api_version("5.0.2", "darkroom_demo")  -- darktable 3.0

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
    -- nothing to destroy
end

-- - - - - - - - - - - - - - - - - - - - - - - -
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - -

local MODULE_NAME = "darkroom_demo"
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

-- save the configuration

local current_view = dt.gui.current_view()

-- check that there is an image selected, otherwise we can't activate darkroom viewe

local images = dt.gui.action_images
dt.print_log(#images .. " images selected")
if not images or #images == 0 then
  dt.print_log("no images selected, creating selection")
  dt.print_log("using image " .. dt.collection[1].filename)
  dt.gui.selection({dt.collection[1]})
end

-- enter darkroom view

dt.gui.current_view(dt.gui.views.darkroom)

local max_images = 10

dt.print(_("showing images, with a pause between each"))
sleep(1500)

-- display first 10 images of collection pausing for a second between each

for i, img in ipairs(dt.collection) do 
  dt.print(string.format(_("displaying image "), i))
  dt.gui.views.darkroom.display_image(img)
  sleep(1500)
  if i == max_images then
    break
  end
end

-- return to lighttable view

dt.print(_("restoring view"))
sleep(1500)
dt.gui.current_view(current_view)

-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to 
-- script_manager
local script_data = {}

script_data.metadata = {
  name = _("darkroom demo"),
  purpose = _("example demonstrating how to control image display in darkroom mode"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/darkroom_demo"
}

script_data.destroy = destroy

return script_data
