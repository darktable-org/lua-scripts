--[[
Create thumbnails plugin for darktable

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

--[[About this Plugin
This plugin adds the button 'create thumbnails' to 'selected image[s]' module of darktable's lighttable view.


----USAGE----
Click the 'create thumbnails' button in the 'selected image[s]' module to let the script create full sized previews of all selected images.

To create previews of all images of a collection:
Use CTRL+A to select all images of current collection and then press the button.
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("8.0.0", "create_thumbnails_button")

-- stop running thumbnail creation
local function stop_job(job)
    job.valid = false
end

-- return "1 image" if amount_of_images is 1 else "<amount_of_images> images"
local function image_count_to_text(amount_of_images)
    return amount_of_images .. " image" .. (amount_of_images == 1 and "" or "s")
end

-- print the given message to the user and log the given message
local function print_and_log(message)
    dt.print(message)
    dt.print_log(message)
end

-- add button to 'selected images' module
dt.gui.libs.image.register_action(
    "create_thumbnails_button",
    "create thumbnails",
    function(event, images)
        print_and_log("creating thumbnails for " .. image_count_to_text(#images) .. " ...")

        -- create a new progress_bar displayed in darktable.gui.libs.backgroundjobs
        job = dt.gui.create_job("creating thumbnails...", true, stop_job)

        for i, image in pairs(images) do
            -- generate all thumbnails, a max value of 8 means that also a full size preview image is created
            -- check only once if the mipmap cache directories exist 
            image:generate_cache(i == 1, 0, 8)
            
            -- update progress_bar
            job.percent = i / #images

            -- sleep for a short moment to give stop_job callback function a chance to run
            dt.control.sleep(10)

            -- stop early if darktable is shutdown or the cancle button of the progress bar is pressed
            if dt.control.ending or not job.valid then
                print_and_log("creating thumbnails canceled after processing " .. i .. "/" .. image_count_to_text(#images) .. "!")
                break
            end
        end

        -- if job was not canceled
        if(job.valid) then
            -- stop job and remove progress_bar from ui
            job.valid = false

            print_and_log("creating thumbnails for " ..  image_count_to_text(#images) .. " done!")
        end
    end,
    "create full sized previews of all selected images"
)

-- clean up function that is called when this module is getting disabled
local function destroy()
    dt.gui.libs.image.destroy_action("create_thumbnails_button")
end


local script_data = {}
script_data.destroy = destroy -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
return script_data
