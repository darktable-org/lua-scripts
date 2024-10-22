--[[
    This file is part of darktable,
    copyright (c) 2023 Dirk Dittmar

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
Enable selection of non-existing images in the the currently worked on images, e.g. the ones selected by the collection module.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

-- module name
local MODULE = "select_non_existing"

du.check_min_api_version("9.1.0", MODULE)

-- figure out the path separator
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

local function stop_job(job)
    job.valid = false
end

local function select_nonexisting_images(event, images)
    local selection = {}

    local job = dt.gui.create_job(_("select non existing images"), true, stop_job)
    for key,image in ipairs(images) do
        if(job.valid) then
            job.percent = (key - 1)/#images
            local filepath = image.path..PS..image.filename
            local file_exists = df.test_file(filepath, "e")
            dt.print_log(filepath.." exists? => "..tostring(file_exists))
            if (not file_exists) then
                table.insert(selection, image)
            end
        else
            break
        end
    end    
    stop_job(job)
    
    return selection
end

local function destroy()
    dt.gui.libs.select.destroy_selection(MODULE)
end
  
dt.gui.libs.select.register_selection(
    MODULE,
    _("select non existing"),
    select_nonexisting_images,
    _("select all non-existing images in the current images"))

local script_data = {}

script_data.metadata = {
  name = _("select non existing"),
  purpose = _("enable selection of non-existing images"),
  author = "Dirk Dittmar",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/select_non_existing"
}

script_data.destroy = destroy
return script_data