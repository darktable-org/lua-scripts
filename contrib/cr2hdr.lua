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

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* cr2hdr (sources can be obtained through the Magic Lantern repository)

USAGE
* require this script from your main lua file
* trigger conversion on selected/hovered images by shortcut (set shortcut in settings dialog)
* it is also possible to have the script run after importing a collection (optin, since it is not that fast)
]]

local darktable = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "cr2hdr") 

local gettext = darktable.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("cr2hdr"),
  purpose = _("process Magic Lantern dual ISO images"),
  author = "Till Theato <theato@ttill.de>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/cr2hdr"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local queue = {}
local processed_files = {}
local job

local function file_imported(event, image)
    local filename = image.path .. "/" .. image.filename
    if processed_files[filename] then
        image.make_group_leader(image)
        processed_files[filename] = false
    else
        if darktable.preferences.read("cr2hdr", "onimport", "bool") then
            table.insert(queue, image)
        end
    end
end

local function stop_conversion(job)
    job.valid = false
end

local function convert_image(image)
    if string.sub(image.filename, -3) == "CR2" then
        local filename = image.path .. "/" .. image.filename
        local result = darktable.control.execute( "cr2hdr " .. filename)
        local out_filename = string.gsub(filename, ".CR2", ".DNG")
        local file = io.open(out_filename)
        if file then
            file:close()
            processed_files[out_filename] = true
            darktable.database.import(out_filename)
        else
            darktable.print_error(filename .. ": cr2hdr failed.")
        end
    else
        darktable.print_error(image.filename .. " is not a Canon RAW.")
    end
end

local function convert_images()
    if next(queue) == nil then return end

    job = darktable.gui.create_job(_("dual ISO conversion"), true, stop_conversion)
    for key,image in pairs(queue) do
        if job.valid then
            job.percent = (key-1)/#queue
            convert_image(image)
        else
            break
        end
    end
    local success_count = 0
    for _ in pairs(processed_files) do success_count = success_count + 1 end
    darktable.print(string.format(_("dual ISO conversion successful on %d/%d images."), success_count, #queue))
    job.valid = false
    processed_files = {}
    queue = {}
end

local function film_imported(event, film)
    if darktable.preferences.read("cr2hdr", "onimport", "bool") then
        convert_images()
    end
end

local function convert_action_images(shortcut)
    queue = darktable.gui.action_images
    convert_images()
end

local function destroy()
    darktable.destroy_event("cr2hdr", "shortcut")
    darktable.destroy_event("cr2hdr", "post-import-image")
    darktable.destroy_event("cr2hdr", "post-import-film")
end

darktable.register_event("cr2hdr", "shortcut", 
    convert_action_images, _("run cr2hdr (Magic Lantern DualISO converter) on selected images"))
darktable.register_event("cr2hdr", "post-import-image", 
    file_imported)
darktable.register_event("cr2hdr", "post-import-film", 
    film_imported)

darktable.preferences.register("cr2hdr", "onimport", "bool", _("invoke on import"), _("if true then cr2hdr will try to proccess every file during importing\nwarning: cr2hdr is quite slow even in figuring out on whether the file is dual ISO or not."), false)

script_data.destroy = destroy 

return script_data
