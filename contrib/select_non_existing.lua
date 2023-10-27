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
Enable selection of non existing images in the the currently worked on images, e.g. the ones selected by the collection module.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

du.check_min_api_version("9.1.0", "select_non_existing") 

local gettext = dt.gettext
gettext.bindtextdomain("select_non_existing", dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("select_non_existing", msgid)
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
            local filepath = image.path.."/"..image.filename
            local file_exists = df.test_file(filepath, "e")
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
    dt.gui.libs.select.destroy_selection("select_non_existing")
end
  
dt.gui.libs.select.register_selection(
    "select_non_existing",
    _("select non existing"),
    select_nonexisting_images,
    _("select all non existing images in the the currently worked on images"))

local script_data = {}
script_data.destroy = destroy
return script_data