--[[
  Richardson-Lucy output sharpening for darktable using GMic

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
  DESCRIPTION
    RL_out_sharp.lua - Richardson-Lucy output sharpening using GMic

    This script provides a new target storage "RL output sharpen". 
    Images exported will be sharpened using GMic (RL deblur algorithm)

  REQUIRED SOFTWARE
  GMic command line interface (CLI) https://gmic.eu/download.shtml
    
  USAGE
    * require this script from main lua file
    * in lua preferences, select the GMic cli executable
    * from "export selected", choose "RL output sharpen"
    * configure output folder 
    * configure RL parameters with sliders
    * configure temp files format and quality, jpg 8bpp (good quality) 
      and tif 16bpp (best quality) are supported
    * configure other export options (size, etc.)
    * export, images will be first exported in the temp format, then sharpened
    * sharpened images will be stored in jpg format in the output folder

  EXAMPLE
    set sigma = 0.7, iterations = 10, jpeg output quality = 95,
    to correct blur due to image resize for web usage

  CAVEATS
    MAC compatibility not tested
    Although Darktable can handle file names containing spaces, GMic cli cannot, 
      so if you want to use this script please make sure that your images do not
      have spaces in the file name and path
  
  BUGS, COMMENTS, SUGGESTIONS
    send to Marco Carrarini, marco.carrarini@gmail.com

  CHANGES
    * 20200308 - initial version
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

-- module name
local MODULE_NAME = "RL_out_sharp"

-- check API version
du.check_min_api_version("7.0.0", MODULE_NAME) 

-- translation
local gettext = dt.gettext.gettext

local function _(msgid)
  return gettext(msgid)
  end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("RL output sharpening"),
  purpose = _("Richardson-Lucy output sharpening using GMic"),
  author = "Marco Carrarini <marco.carrarini@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/RL_out_sharp"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- OS compatibility
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- initialize module preferences
if not dt.preferences.read(MODULE_NAME, "initialized", "bool") then
  dt.preferences.write(MODULE_NAME, "sigma", "string", "0.7")
  dt.preferences.write(MODULE_NAME, "iterations", "string", "10")
  dt.preferences.write(MODULE_NAME, "jpg_quality", "string", "95")
  dt.preferences.write(MODULE_NAME, "initialized", "bool", true)
end 

-- preserve original image metadata in the output image -----------------------
local function preserve_metadata(original, sharpened)
  local exiftool = df.check_if_bin_exists("exiftool")

  if exiftool then
    dtsys.external_command("exiftool -overwrite_original_in_place -tagsFromFile " .. original .. " " .. sharpened)
  else
    dt.print_log(MODULE_NAME .. " exiftool not found,  metadata not preserved")
  end
end


-- setup export ---------------------------------------------------------------
local function setup_export(storage, img_format, image_table, high_quality, extra_data)
  -- set 16bpp if format is tif
  if img_format.extension == "tif" then
    img_format.bpp = 16
    end
  end


-- temp export formats: jpg and tif are supported -----------------------------
local function supported(storage, img_format)
  return (img_format.extension == "jpg") or (img_format.extension == "tif")
  end


-- export and sharpen images --------------------------------------------------
local function export2RL(storage, image_table, extra_data) 

  local temp_name, new_name, run_cmd, result
  local input_file, output_file, options

  -- read parameters
  local gmic = dt.preferences.read(MODULE_NAME, "gmic_exe", "string")
  if gmic == "" then
    dt.print(_("GMic executable not configured"))
    return
    end
  gmic = df.sanitize_filename(gmic)
  local output_folder = output_folder_selector.value
  local sigma_str = string.gsub(string.format("%.2f", sigma_slider.value), ",", ".")
  local iterations_str = string.format("%.0f", iterations_slider.value)
  local jpg_quality_str = string.format("%.0f", jpg_quality_slider.value)

  -- save preferences
  dt.preferences.write(MODULE_NAME, "sigma", "string", sigma_str)
  dt.preferences.write(MODULE_NAME, "iterations", "string", iterations_str)
  dt.preferences.write(MODULE_NAME, "jpg_quality", "string", jpg_quality_str)

  local gmic_operation = " -deblur_richardsonlucy "..sigma_str..","..iterations_str..",1"
 
  local i = 0
  for image, temp_name in pairs(image_table) do

    i = i + 1
    dt.print(string.format(_("sharpening image %d ..."), i))
    -- create unique filename
    new_name = output_folder..PS..df.get_basename(temp_name)..".jpg"
    new_name = df.create_unique_filename(new_name)

    -- build the GMic command string
    input_file = df.sanitize_filename(temp_name)
    output_file = df.sanitize_filename(new_name)
    options = " cut 0,255 round "
    if df.get_filetype(temp_name) == "tif" then options = " -/ 256"..options end
        
    run_cmd = gmic.." "..input_file..gmic_operation..options.."o "..output_file..","..jpg_quality_str
    
    result = dtsys.external_command(run_cmd)
    if result ~= 0 then
      dt.print(_("sharpening error"))
      return
    end

    -- copy metadata from input_file to output_file
    preserve_metadata(input_file, output_file)

    -- delete temp image
    os.remove(temp_name) 

    end 
  
  dt.print(_("finished exporting"))
  end

  -- script_manager integration

  local function destroy()
    dt.destroy_storage("exp2RL")
  end

-- new widgets ----------------------------------------------------------------

output_folder_selector = dt.new_widget("file_chooser_button"){
  title = _("select output folder"),
  tooltip = _("select output folder"),
  value = dt.preferences.read(MODULE_NAME, "output_folder", "string"),
  is_directory = true,
  changed_callback = function(self)
    dt.preferences.write(MODULE_NAME, "output_folder", "string", self.value)
    end
  }

sigma_slider = dt.new_widget("slider"){
  label = _("sigma"),
  tooltip = _("controls the width of the blur that's applied"),
  soft_min = 0.3,
  soft_max = 2.0,
  hard_min = 0.0,
  hard_max = 3.0,
  step = 0.05,
  digits = 2,
  value = 1.0
  }

iterations_slider = dt.new_widget("slider"){
  label = _("iterations"),
  tooltip = _("increase for better sharpening, but slower"),
  soft_min = 0,
  soft_max = 100,
  hard_min = 0,
  hard_max = 100,
  step = 5,
  digits = 0,
  value = 10.0
  }

jpg_quality_slider = dt.new_widget("slider"){
  label = _("output jpg quality"),
  tooltip = _("quality of the output jpg file"),
  soft_min = 70,
  soft_max = 100,
  hard_min = 70,
  hard_max = 100,
  step = 2,
  digits = 0,
  value = 95.0
  }

local storage_widget = dt.new_widget("box"){
  orientation = "vertical",
  output_folder_selector,
  sigma_slider,
  iterations_slider,
  jpg_quality_slider
  }

-- register new storage -------------------------------------------------------
dt.register_storage("exp2RL", _("RL output sharpen"), nil, export2RL, supported, save_preferences, storage_widget)

-- register the new preferences -----------------------------------------------
dt.preferences.register(MODULE_NAME, "gmic_exe", "file", 
_("executable for GMic CLI"), 
_("select executable for GMic command line version")  , "")

-- set sliders to the last used value at startup ------------------------------
sigma_slider.value = dt.preferences.read(MODULE_NAME, "sigma", "float")
iterations_slider.value = dt.preferences.read(MODULE_NAME, "iterations", "float")
jpg_quality_slider.value = dt.preferences.read(MODULE_NAME, "jpg_quality", "float")

-- script_manager integration

script_data.destroy = destroy

return script_data

-- end of script --------------------------------------------------------------

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
