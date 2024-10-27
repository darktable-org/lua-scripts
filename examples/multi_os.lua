--[[
    This file is part of darktable,
    copyright (c) 2017,2018 Bill Ferguson <wpferguson@gmail.com>

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
    multi_os - an example script that runs on linux, MacOS, and Windows.

    multi_os is an example of how to write a script that will run on different
    operating systems.  It uses the lua-scripts libraries to lessen the amount
    of code that needs to be written, as well as gaining access to tested 
    cross-platform routines.  This script also performs a function that some 
    may find useful.  It creates a button in the lighttable selected images module
    that extracts the embedded jpeg image from a raw file, then imports it and groups
    it with the raw file.  A keyboard shortcut is also created.  A key combination can
    be assigned to the shortcut in the lua preferences and then the action can be invoked
    by hovering over the image and pressing the key combination.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * ufraw-batch - https://ufraw.sourceforge.net
                    MacOS - install with homebrew

    USAGE
    * require this script from your main lua file
    * start darktable, open prefreences, go to lua options 
      and update the executable location if you are running
      Windows or MacOS, then restart darktable.
    * select an image or images
    * click the button to extract the jpeg

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES
]]

--[[
    require "darktable" provides the interface to the darktable lua functions used to
    interact with darktable
]]

local dt = require "darktable"

--[[
    require "lib/..." provides access to functions that have been pulled from various 
    scripts and consolidated into libraries.  Using the libraries eliminates having to 
    recode common functions in every script.
]]

local du = require "lib/dtutils"  -- utilities
local df = require "lib/dtutils.file"   -- file utilities
local dtsys = require "lib/dtutils.system"  -- system utilities

--[[
    darktable is an international program, and it's user interface has been translated into
    many languages.  The lua API provides gettext which is a function that looks for and replaces
    strings with the translated equivalents based on locale.  Even if you don't provide the 
    translations, inserting this lays the groundwork for anyone who wants to translate the strings.
]]

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

--[[
    Check that the current api version is greater than or equal to the specified minimum.  If it's not
    then du.check_min_api_version will print an error to the log and return false.  If the minimum api is
    not met, then just refuse to load and return.  Optionally, you could print an error message to the 
    screen stating that you couldn't load because the minimum api version wasn't met.
]]

du.check_min_api_version("7.0.0", "multi_os") 

--[[
    copy_image_attributes is a local subroutine to copy image attributes in the database from the raw image
    to the extracted jpeg image.  Even though the subroutine could act on the variables in the main program 
    directly, passing them as arguments and using them in the subroutine is much safer.  
]]

local function copy_image_attributes(from, to, ...)
  local args = {...}
  if #args == 0 then
    args[1] = "all"
  end
  if args[1] == "all" then
    args[1] = "rating"
    args[2] = "colors"
    args[3] = "exif"
    args[4] = "meta"
    args[5] = "GPS"
  end
  for _,arg in ipairs(args) do
    if arg == "rating" then
      to.rating = from.rating
    elseif arg == "colors" then
      to.red = from.red
      to.blue = from.blue
      to.green = from.green
      to.yellow = from.yellow
      to.purple = from.purple
    elseif arg == "exif" then
      to.exif_maker = from.exif_maker
      to.exif_model = from.exif_model
      to.exif_lens = from.exif_lens
      to.exif_aperture = from.exif_aperture
      to.exif_exposure = from.exif_exposure
      to.exif_focal_length = from.exif_focal_length
      to.exif_iso = from.exif_iso
      to.exif_datetime_taken = from.exif_datetime_taken
      to.exif_focus_distance = from.exif_focus_distance
      to.exif_crop = from.exif_crop
    elseif arg == "GPS" then
      to.elevation = from.elevation
      to.longitude = from.longitude
      to.latitude = from.latitude
    elseif arg == "meta" then
      to.publisher = from.publisher
      to.title = from.title
      to.creator = from.creator
      to.rights = from.rights
      to.description = from.description
    else
      dt.print_error("Unrecognized option to copy_image_attributes: " .. arg)
    end
  end
end

--[[
    The main function called from the button or the shortcut.  It takes one or more raw files, passed
    in a table and extracts the embedded jpeg images
]]

local function extract_embedded_jpeg(images)

  --[[
      check if the executable exists, since we can't do anything without it.  check_if_bin_exists() 
      checks to see if there is a saved  executable location.  If not, it checks for the executable 
      in the user's path.  When it finds the executable, it returns the command to run it.
  ]]

  local ufraw_executable = df.check_if_bin_exists("ufraw-batch")
  if ufraw_executable then
    for _, image in ipairs(images) do
      if image.is_raw then
        local img_file = du.join({image.path, image.filename}, "/")

        --[[
            dtsys.external_command() is operating system aware and formats the command as necessary.  
            df.sanitize_filename() is used to quote the image filepath to protect from spaces.  It is also
            operating system aware and uses the corresponding quotes.
        ]]

        if dtsys.external_command(ufraw_executable .. " --silent --embedded-image " .. df.sanitize_filename(img_file)) then
          local jpg_img_file = df.chop_filetype(img_file) .. ".embedded.jpg"
          dt.print_log("jpg_img_file set to ", jpg_img_file) -- print a debugging message
          local myimage = dt.database.import(jpg_img_file)
          myimage:group_with(image.group_leader)
          copy_image_attributes(image, myimage, "all")

          --[[
              copy all of the tags except the darktable tags
          ]]

          for _,tag in pairs(dt.tags.get_tags(image)) do 
            if not (string.sub(tag.name,1,9) == "darktable") then
              dt.print_log("attaching tag")
              dt.tags.attach(tag,myimage)
            end
          end
        end
      else
        dt.print_error(image.filename .. " is not a raw file.  No image can be extracted") -- print debugging error message
        dt.print(string.format(_("%s is not a raw file, no image can be extracted"), image.filename)) -- print the error to the screen
      end
    end
  else
    dt.print_error("ufraw-batch not found.  Exiting...") -- print debugging error message
    dt.print("ufraw-batch not found, exiting...") -- print the error to the screen
  end
end

--[[
    script_manager integration to allow a script to be removed
    without restarting darktable
]] 

local function destroy()
    dt.destroy_event("multi_os", "shortcut") -- destroy the event since the callback will no longer be present
    dt.gui.libs.image.destroy_action("multi_os") -- remove the button from the selected images module
end
--[[
    Windows and MacOS don't place executables in the user's path so their location needs to be specified
    so that the script can find them. An exception to this is packages installed on MacOS with homebrew.  Those
    executables are put in /usr/local/bin.  These are saved as executable path preferences.  check_if_bin_exists()
    looks for the executable path preference for the executable.  If it doesn't find one, then the path is checked 
    to see if the executable is there.
]]

if dt.configuration.running_os ~= "linux" then
  local executable = "ufraw-batch"
  local ufraw_batch_path_widget = dt.new_widget("file_chooser_button"){
    title = string.format(_("select %s executable"), "ufraw-batch[.exe]"),
    value = df.get_executable_path_preference(executable),
    is_directory = false,
    changed_callback = function(self)
      if df.check_if_bin_exists(self.value) then
        df.set_executable_path_preference(executable, self.value)
      end
    end
  }
  dt.preferences.register("executable_paths", "ufraw-batch", -- name
    "file", -- type
    'multi_os: ufraw-batch ' .. _('location'),  -- label
    _('installed location of ufraw-batch, requires restart to take effect.'), -- tooltip
    "ufraw-batch", -- default
    ufraw_batch_path_widget
  )
end

--[[
    Add a button to the selected images module in lighttable
]]

dt.gui.libs.image.register_action(
  "multi_os", _("extract embedded jpeg"),
  function(event, images) extract_embedded_jpeg(images) end,
  _("extract embedded jpeg")
)
  
--[[
    Add a shortcut
]]

dt.register_event(
  "multi_os", "shortcut",
  function(event, shortcut) extract_embedded_jpeg(dt.gui.action_images) end,
  _("extract embedded jpeg")
)

--[[
    set the destroy routine so that script_manager can call it when
    it's time to destroy the script and then return the data to 
    script_manager
]]

local script_data = {}

script_data.metadata = {
  name = _("multi OS"),
  purpose = _("example module thet runs on different operating systems"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/multi_os"
}

script_data.destroy = destroy

return script_data
