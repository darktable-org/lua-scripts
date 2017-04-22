--[[
  Passport cropping guide for darktable

  copyright (c) 2017  Kåre Hampf
  
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
guides for cropping passport photos based on documents from the Finnish police
(https://www.poliisi.fi/instancedata/prime_product_julkaisu/intermin/embeds/poliisiwwwstructure/38462_Passikuvaohje_EN.pdf) describing passport photo dimensions of 47x36 mm and 500x653 px for digital biometric data stored in passports. They use ISO 19794-5 standard based on ICAO 9303 regulations which should also be compliant for all of Europe.

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "passport_guide"
* (optional) add the line:
  "plugins/darkroom/clipping/extra_aspect_ratios/passport 36x47mm=47:36"
  to $CONFIGDIR/darktablerc

USAGE
* when using the cropping tool, select "passport" as guide and if you added the line in yout rc
  select "passport 36x47mm" as aspect
]]

local dt = require "darktable"
local gettext = dt.gettext

dt.configuration.check_version(...,{2,0,0},{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("passport_guide",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
  return gettext.dgettext("passport_guide", msgid)
end

dt.guides.register_guide("passport",
-- draw
function(cairo, x, y, width, height, zoom_scale)
  local _width, _height

  -- get the max 36x47 rectangle
  local aspect_ratio = 47 / 36
  if width * aspect_ratio > height then
    _width = height / aspect_ratio
    _height = height
  else
    _width = width
    _height = width * aspect_ratio
  end

  cairo:save()

  cairo:translate(x + (width - _width) / 2, y + (height - _height) / 2)
  cairo:scale(_width / 36, _height / 47)

  -- the outer rectangle
  cairo:rectangle( 0, 0, 36, 47)

  -- vertical bars
  cairo:draw_line(16.5, 8, 16.5, 36)
  cairo:draw_line(19.5, 8, 19.5, 36)

  -- long horisontal bars
  cairo:draw_line(6, 4, 30, 4)
  cairo:draw_line(6, 40, 30, 40)

  -- short horisontal bars
  cairo:draw_line(9, 6, 27, 6)
  cairo:draw_line(9, 38, 27, 38)

  cairo:restore()
end,
-- gui
function()
  return dt.new_widget("label"){label = _("ISO 19794-5/ICAO 9309 passport"), halign = "start"}
end
)

-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on; hl Lua;
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
