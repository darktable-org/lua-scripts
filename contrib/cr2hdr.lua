--[[
    Copyright (C) 2015 Till Theato <theato@ttill.de>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
cr2hdr Magic Lantern Dual ISO processing.

This script automates the steps involved to process an image created
with the Magic Lantern Dual ISO module. Upon invoking the script with a
shortcut "cr2hdr" provided by Magic Lantern is run on the selected
images. The processed files are imported. They are also made group
leaders to hide the original files.

ADDITIANAL SOFTWARE NEEDED FOR THIS SCRIPT
* cr2hdr (sources can be obtained through the Magic Lantern repository)

USAGE
* require this script from your main lua file
* …
]]

local darktable = require "darktable"

-- Tested with darktable 1.6.2
darktable.configuration.check_version(...,{2,0,2})

local processed_files = {}
local job

function file_imported(event, image)
    local filename = image.path .. "/" .. image.filename
    if processed_files[filename] then
        image.make_group_leader(image)
        processed_files[filename] = nil
    end
end

function stop_conversion(job)
    job.valid = false
end

-- Source: http://lua-users.org/wiki/SplitJoin
function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function convert_image(image)
    if string.sub(image.filename, -3) == "CR2" then
        local filename = image.path .. "/" .. image.filename
        local handle = io.popen("cr2hdr " .. filename)
        local result = handle:read("*a")
        handle:close()
        local out_filename = string.gsub(filename, ".CR2", ".DNG")
        local file = io.open(out_filename)
        if file then
            file:close()
            processed_files[out_filename] = true
            darktable.database.import(out_filename)
        else
            result = lines(result)
            darktable.print_error(image.filename .. ": cr2hdr failed: " .. result[#result-1])
        end
    else
        darktable.print_error(image.filename .. " is not a Canon RAW.")
    end
end

function convert_action_images(shortcut)
    job = darktable.gui.create_job("Dual ISO conversion", true, stop_conversion)
    local images = darktable.gui.action_images
    for key,image in pairs(images) do
        if job.valid then
            job.percent = (key-1)/#images
            convert_image(image)
        else
            return
        end
    end
    job.valid = false
end

darktable.register_event("shortcut", convert_action_images, "Run cr2hdr (Magic Lantern DualISO converter) on ... images")
darktable.register_event("post-import-image", file_imported)
