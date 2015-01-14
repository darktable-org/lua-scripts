--[[
Pentax lens fixes

Fixes EXIF lens description for:
- Tokina AT-X Pro AF 28-70mm f/2.8 (from "smc PENTAX-F 28-80mm F3.5-4.5")
- Sigma 30mm f/1.4 EX DC (from "Sigma Lens")

AUTHOR
Sebastian Witt (se.witt@gmx.net)

INSTALATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "pentax-lens-fix"

USAGE
* Assign shortcut in preferences =>lua
* Select images
* Use shortcut

LICENSE
GPLv2

]]

local darktable = require "darktable"
local debug = require "darktable.debug"

local function fix_lens_info (event, shortcut)
  darktable.print ("Fixing EXIF lens info...")
  local images = darktable.gui.action_images

  for _,v in pairs(images) do
    if (v.exif_lens == "smc PENTAX-F 28-80mm F3.5-4.5") then
      v.exif_lens = "Tokina AT-X Pro AF 28-70mm f/2.8"
    elseif (v.exif_maker == "PENTAX") and (v.exif_lens == "Sigma Lens") and (v.exif_focal_length == 30) then
      v.exif_lens = "Sigma 30mm f/1.4 EX DC"
    elseif (v.exif_lens == "Unknown (0x07d8)") then
      v.exif_lens = "smc PENTAX-DA L 55-300mm F4-5.8 ED"
    elseif (v.exif_lens == "Unknown (0x0804)") then
      v.exif_lens = "Sigma 50mm F1.4 EX DG HSM"
    end
  end
end

darktable.register_event ("shortcut", fix_lens_info, "Pentax: Fix Sigma and Tokina lens information")

