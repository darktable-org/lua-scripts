--[[
  German passport photo cropping guide for darktable.
  Derived from the passport cropping guide by Kåre Hampf.

  copyright (c) 2017  Kåre Hampf
  copyright (c) 2024  Christian Sültrop
  
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
PASSPORT CROPPING GUIDE
Guides for cropping passport and ID card ("Personalausweis") photos based on the "Passbild-Schablone" 
from the German Federal Ministry of the Interior and Community. 
(https://www.bmi.bund.de/SharedDocs/downloads/DE/veroeffentlichungen/themen/moderne-verwaltung/ausweise/passbild-schablone-erwachsene.pdf?__blob=publicationFile&v=3) 

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "passport_guide_germany"
* (optional) add the line:
  "plugins/darkroom/clipping/extra_aspect_ratios/passport 35x45mm=45:35"
  to $CONFIGDIR/darktablerc

USAGE
* when using the cropping tool, select "Passport Photo Germany" as guide and if you added the line in yout rc
  select "passport 35x45mm" as aspect
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local gettext = dt.gettext.gettext

du.check_min_api_version("2.0.0", "passport_guide_germany") 

-- Tell gettext where to find the .mo file translating messages for a particular domain
local function _(msgid)
  return gettext(msgid)
end

local script_data = {}

script_data.metadata = {
  name = _("passport guide Germany"),
  purpose = _("guides for cropping passport and ID card (\"Personalausweis\") photos based on the \"Passbild-Schablone\" from the German Federal Ministry of the Interior and Community"),
  author = "menschmachine",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/passport_guide_germany"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

dt.guides.register_guide("Passport Photo Germany",
-- draw
function(cairo, x, y, width, height, zoom_scale)
  local _width, _height

  -- get the max 35x45 rectangle
  local aspect_ratio = 45 / 35
  if width * aspect_ratio > height then
    _width = height / aspect_ratio
    _height = height
  else
    _width = width
    _height = width * aspect_ratio
  end

  cairo:save()

  cairo:translate(x + (width - _width) / 2, y + (height - _height) / 2)
  cairo:scale(_width / 35, _height / 45)

  -- the outer rectangle
  cairo:rectangle( 0, 0, 35, 45)

  -- Nose position: The nose tip must be between these lines
  cairo:draw_line(15.5, 45, 15.5, 13)
  cairo:draw_line(35-15.5, 45, 35-15.5, 13)

  -- Face height
  -- optimum face height: The upper end of the head should be between these lines
  cairo:draw_line(0, 4, 35, 4)
  cairo:draw_line(0, 8, 35, 8)

  -- tolerated face height: The upper end of the head must not be below this line
  cairo:draw_line(6, 13, 30, 13)

  -- Eye area: The eyes must be between these lines
  cairo:draw_line(0, 13, 35, 13)
  cairo:draw_line(0, 23, 35, 23)

  -- Cheek line: The cheek must lie on this line
  cairo:draw_line(9, 45-5, 27, 45-5)

  cairo:restore()
end,
-- gui
function()
  return dt.new_widget("label"){label = _("Passport Photo Germany"), halign = "start"}
end
)

local function destroy()
  -- noting to destroy
end

script_data.destroy = destroy

return script_data

-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on; hl Lua;
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
