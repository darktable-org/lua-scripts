--[[
  harmonic artmature guide for darktable

  copyright (c) 2021  Hubert Kowalski
  
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
HARMONIC ARMATURE GUIDE
Harmonic Armature (also known as 14 line armature)

INSTALLATION
* copy this file in $CONFIGDIR/lua/contrib where CONFIGDIR is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "contrib/harmonic_armature_guide"

USAGE
* when using guides, select "harmonic armature" as guide
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local gettext = dt.gettext.gettext

du.check_min_api_version("2.0.0", "harmonic_armature_guide") 

local function _(msgid)
  return gettext(msgid)
end

local script_data = {}

script_data.metadata = {
  name = _("harmonic armature guide"),
  purpose = _("harmonic artmature guide"),
  author = "Hubert Kowalski",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/harmonic_armature_guide"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

dt.guides.register_guide("harmonic armature",
-- draw
function(cairo, x, y, width, height, zoom_scale)
  cairo:save()

  cairo:translate(x, y)
  cairo:scale(width, height)

  cairo:move_to(0,0)
  cairo:line_to(1, 0.5)
  cairo:line_to(0.5, 1)
  cairo:line_to(0,0)
  cairo:line_to(1, 1)
  cairo:line_to(0.5, 0)
  cairo:line_to(0, 0.5)
  cairo:line_to(1, 1)

  cairo:move_to(1, 0)
  cairo:line_to(0, 0.5)
  cairo:line_to(0.5, 1)
  cairo:line_to(1, 0)
  cairo:line_to(0, 1)
  cairo:line_to(0.5, 0)
  cairo:line_to(1, 0.5)
  cairo:line_to(0, 1)

  cairo:restore()
end,
-- gui
function()
  return dt.new_widget("label"){label = _("harmonic armature"), halign = "start"}
end
)

local function destroy()
  -- nothing to destroy
end

script_data.destroy = destroy

return script_data
