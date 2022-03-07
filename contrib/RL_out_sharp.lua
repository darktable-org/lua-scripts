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
    * in lua preferences, select the GMic cli executable, and optionally
      select the exiftool cli executable
    * from "export selected", choose "RL output sharpen"
    * configure output path or folder
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

-- return data structure for script_manager

local script_data = {}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again

-- OS compatibility
local PS = dt.configuration.running_os == "windows" and  "\\"  or  "/"

-- translation
local gettext = dt.gettext
gettext.bindtextdomain(MODULE_NAME, dt.configuration.config_dir..PS.."lua"..PS.."locale"..PS)
local function _(msgid)
  return gettext.dgettext(MODULE_NAME, msgid)
end

-- initialize module preferences
if not dt.preferences.read(MODULE_NAME, "initialized", "bool") then
  dt.preferences.write(MODULE_NAME, "output_path", "string", "$(FILE_FOLDER)/darktable_exported/$(FILE_NAME)")
  dt.preferences.write(MODULE_NAME, "sigma", "string", "0.7")
  dt.preferences.write(MODULE_NAME, "iterations", "string", "10")
  dt.preferences.write(MODULE_NAME, "jpg_quality", "string", "95")
  dt.preferences.write(MODULE_NAME, "initialized", "bool", true)
end


-- namespace variable
local RL_out_sharp = {
  substitutes = {},
  placeholders = {"ROLL_NAME","FILE_FOLDER","FILE_NAME","FILE_EXTENSION","ID","VERSION","SEQUENCE","YEAR","MONTH","DAY",
                  "HOUR","MINUTE","SECOND","EXIF_YEAR","EXIF_MONTH","EXIF_DAY","EXIF_HOUR","EXIF_MINUTE","EXIF_SECOND",
                  "STARS","LABELS","MAKER","MODEL","TITLE","CREATOR","PUBLISHER","RIGHTS","USERNAME","PICTURES_FOLDER",
                  "HOME","DESKTOP","EXIF_ISO","EXIF_EXPOSURE","EXIF_EXPOSURE_BIAS","EXIF_APERTURE","EXIF_FOCUS_DISTANCE",
                  "EXIF_FOCAL_LENGTH","LONGITUDE","LATITUDE","ELEVATION","LENS","DESCRIPTION","EXIF_CROP"}
}

-- setup export ---------------------------------------------------------------
local function initialize(storage, img_format, image_table, high_quality, extra)
  local tmp_rl_name, new_name, run_cmd, result
  local input_file, output_file, options

  -- read parameters
  extra.gmic = dt.preferences.read(MODULE_NAME, "gmic_exe", "string")
  if extra.gmic == "" then
    dt.print(_("ERROR: GMic executable not configured"))
    -- not returning {} here as that can crash darktable if user clicks the export button repeatedly
  end
  extra.gmic = df.sanitize_filename(extra.gmic)

  extra.exiftool = dt.preferences.read(MODULE_NAME, "exiftool_exe", "string")
  if extra.exiftool == "" then
    dt.print(_("exiftool executable not configured"))
  else
    extra.exiftool = df.sanitize_filename(extra.exiftool)
  end

  -- since we cannot change the bpp, inform user
  if img_format.extension == "tif" and img_format.bpp ~= 16 and img_format.bpp ~= 8 then
    dt.print_log(_("ERROR: Please set TIFF bit depth to 8 or 16"))
    dt.print(_("ERROR: Please set TIFF bit depth to 8 or 16"))
    -- not returning {} here as that can crash darktable if user clicks the export button repeatedly
  end

  -- determine output path
  extra.output_folder = output_folder_selector.value
  extra.output_path = output_folder_path.text

  extra.sigma_str = string.gsub(string.format("%.2f", sigma_slider.value), ",", ".")
  extra.iterations_str = string.format("%.0f", iterations_slider.value)
  extra.jpg_quality_str = string.format("%.0f", jpg_quality_slider.value)

  -- save preferences
  dt.preferences.write(MODULE_NAME, "output_path", "string", extra.output_path)
  dt.preferences.write(MODULE_NAME, "sigma", "string", extra.sigma_str)
  dt.preferences.write(MODULE_NAME, "iterations", "string", extra.iterations_str)
  dt.preferences.write(MODULE_NAME, "jpg_quality", "string", extra.jpg_quality_str)

  extra.gmic_operation = " -deblur_richardsonlucy "..extra.sigma_str..","..extra.iterations_str..",1"
end


-- temp export formats: jpg and tif are supported -----------------------------
local function supported(storage, img_format)
  return (img_format.extension == "jpg") or (img_format.extension == "tif")
end



-- shamelessly copied the pattern-replacement functions from rename_images.lua
local function build_substitution_list(image, sequence, datetime, username, pic_folder, home, desktop)
 -- build the argument substitution list from each image
 -- local datetime = os.date("*t")
 local colorlabels = {}
 if image.red then table.insert(colorlabels, "red") end
 if image.yellow then table.insert(colorlabels, "yellow") end
 if image.green then table.insert(colorlabels, "green") end
 if image.blue then table.insert(colorlabels, "blue") end
 if image.purple then table.insert(colorlabels, "purple") end
 local labels = #colorlabels == 1 and colorlabels[1] or du.join(colorlabels, ",")
 local eyear,emon,eday,ehour,emin,esec = string.match(image.exif_datetime_taken, "(%d-):(%d-):(%d-) (%d-):(%d-):(%d-)$")
 local replacements = {image.film,
                       image.path,
                       df.get_filename(image.filename),
                       string.upper(df.get_filetype(image.filename)),
                       image.id,image.duplicate_index,
                       string.format("%04d", sequence),
                       datetime.year,
                       string.format("%02d", datetime.month),
                       string.format("%02d", datetime.day),
                       string.format("%02d", datetime.hour),
                       string.format("%02d", datetime.min),
                       string.format("%02d", datetime.sec),
                       eyear,
                       emon,
                       eday,
                       ehour,
                       emin,
                       esec,
                       image.rating,
                       labels,
                       image.exif_maker,
                       image.exif_model,
                       image.title,
                       image.creator,
                       image.publisher,
                       image.rights,
                       username,
                       pic_folder,
                       home,
                       desktop,
                       image.exif_iso,
                       image.exif_exposure,
                       image.exif_exposure_bias,
                       image.exif_aperture,
                       image.exif_focus_distance,
                       image.exif_focal_length,
                       image.longitude,
                       image.latitude,
                       image.elevation,
                       image.exif_lens,
                       image.description,
                       image.exif_crop
                     }

  for i=1,#RL_out_sharp.placeholders,1 do
	RL_out_sharp.substitutes[RL_out_sharp.placeholders[i]] = replacements[i]
  end
end

local function substitute_list(str)
  -- replace the substitution variables in a string
  for match in string.gmatch(str, "%$%(.-%)") do
    local var = string.match(match, "%$%((.-)%)")
    if RL_out_sharp.substitutes[var] then
      str = string.gsub(str, "%$%("..var.."%)", RL_out_sharp.substitutes[var])
    else
      dt.print_error(_("unrecognized variable " .. var))
      dt.print(_("unknown variable " .. var .. ", aborting..."))
      return -1
    end
  end
  return str
end

local function clear_substitute_list()
  for i=1,#RL_out_sharp.placeholders,1 do RL_out_sharp.substitutes[RL_out_sharp.placeholders[i]] = nil end
end



-- perform GMIC RL-decon on a single exported image ----------------------------------

local function store(storage, image, img_format, temp_name, img_num, total, hq, extra)
  if extra.gmic == "" then
    dt.print(_("ERROR: GMic executable not configured"))
    return
  end

  local tmp_rl_name, new_name, run_cmd, result
  local input_file, output_file, options

  new_name = extra.output_folder..PS..df.get_basename(temp_name)..".jpg"

  -- override output path/filename as needed
  if extra.output_path ~= "" then
    local output_path = extra.output_path
    local datetime = os.date("*t")

    build_substitution_list(image, img_num, datetime, USER, PICTURES, HOME, DESKTOP)
	  output_path = substitute_list(output_path)

	  if output_path == -1 then
	    dt.print(_("ERROR: unable to do variable substitution"))
	    return
	  end

    clear_substitute_list()
    new_name = df.get_path(output_path)..df.get_basename(output_path)..".jpg"
  end


  dt.print(_("Applying RL deconvolution to image ")..temp_name.." ...")

  -- work around GMIC's long/space filename problem by renaming/moving file later
  local tmp_rl_name = df.create_unique_filename(df.get_path(temp_name)..PS..df.get_basename(temp_name).."_rl.jpg")

  -- build the GMic command string
  input_file = df.sanitize_filename(temp_name)
  output_file = df.sanitize_filename(tmp_rl_name)
  options = " cut 0,255 round "

  if img_format.extension == "tif" then
    if img_format.bpp == 16 then
      options = " -/ 256"..options
    end

    if img_format.bpp == 32 then
      dt.print(_("ERROR: please set TIFF bit depth to 8 or 16"))
      return
    end
  end

  run_cmd = extra.gmic.." "..input_file..extra.gmic_operation..options.." -o "..output_file..","..extra.jpg_quality_str

  dt.print_log(run_cmd)

  result = dtsys.external_command(run_cmd)
  if result ~= 0 then
    dt.print(_("Error applying RL-deconvolution"))
    return
  end

  -- copy exif
  if extra.exiftool ~= "" then
    dt.print(_("copying EXIF to image: ")..temp_name.." ...")
    run_cmd = extra.exiftool.." -writeMode cg -TagsFromFile "..input_file.." -all:all -overwrite_original "..output_file

    result = dtsys.external_command(run_cmd)
    if result ~= 0 then
      dt.print(_("error copying exif"))
      return
    end
  end

  -- move the tmp file to final destination
  new_name = df.create_unique_filename(new_name)
  df.mkdir(df.sanitize_filename(df.get_path(new_name)))
  df.file_move(tmp_rl_name, new_name)

  -- delete temp image
  os.remove(temp_name)

  dt.print(_("finished exporting image ")..new_name)
end


-- script_manager integration

local function destroy()
  dt.destroy_storage("exp2RL")
end






-- new widgets ----------------------------------------------------------------

output_folder_path = dt.new_widget("entry"){
  tooltip = _("$(ROLL_NAME) - film roll name\n") ..
            _("$(FILE_FOLDER) - image file folder\n") ..
            _("$(FILE_NAME) - image file name\n") ..
            _("$(FILE_EXTENSION) - image file extension\n") ..
            _("$(ID) - image id\n") ..
            _("$(VERSION) - version number\n") ..
            _("$(SEQUENCE) - sequence number of selection\n") ..
            _("$(YEAR) - current year\n") ..
            _("$(MONTH) - current month\n") ..
            _("$(DAY) - current day\n") ..
            _("$(HOUR) - current hour\n") ..
            _("$(MINUTE) - current minute\n") ..
            _("$(SECOND) - current second\n") ..
            _("$(EXIF_YEAR) - EXIF year\n") ..
            _("$(EXIF_MONTH) - EXIF month\n") ..
            _("$(EXIF_DAY) - EXIF day\n") ..
            _("$(EXIF_HOUR) - EXIF hour\n") ..
            _("$(EXIF_MINUTE) - EXIF minute\n") ..
            _("$(EXIF_SECOND) - EXIF seconds\n") ..
            _("$(EXIF_ISO) - EXIF ISO\n") ..
            _("$(EXIF_EXPOSURE) - EXIF exposure\n") ..
            _("$(EXIF_EXPOSURE_BIAS) - EXIF exposure bias\n") ..
            _("$(EXIF_APERTURE) - EXIF aperture\n") ..
            _("$(EXIF_FOCAL_LENGTH) - EXIF focal length\n") ..
            _("$(EXIF_FOCUS_DISTANCE) - EXIF focus distance\n") ..
            _("$(EXIF_CROP) - EXIF crop\n") ..
            _("$(LONGITUDE) - longitude\n") ..
            _("$(LATITUDE) - latitude\n") ..
            _("$(ELEVATION) - elevation\n") ..
            _("$(STARS) - star rating\n") ..
            _("$(LABELS) - color labels\n") ..
            _("$(MAKER) - camera maker\n") ..
            _("$(MODEL) - camera model\n") ..
            _("$(LENS) - lens\n") ..
            _("$(TITLE) - title from metadata\n") ..
            _("$(DESCRIPTION) - description from metadata\n") ..
            _("$(CREATOR) - creator from metadata\n") ..
            _("$(PUBLISHER) - publisher from metadata\n") ..
            _("$(RIGHTS) - rights from metadata\n") ..
            _("$(USERNAME) - username\n") ..
            _("$(PICTURES_FOLDER) - pictures folder\n") ..
            _("$(HOME) - user's home directory\n") ..
            _("$(DESKTOP) - desktop directory"),
  placeholder = _("leave blank to use the location selected below"),
  editable = true,
}


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
  output_folder_path,
  output_folder_selector,
  sigma_slider,
  iterations_slider,
  jpg_quality_slider
}

-- register new storage -------------------------------------------------------
dt.register_storage("exp2RL", _("RL output sharpen"), store, nil, supported, initialize, storage_widget)

-- register the new preferences -----------------------------------------------
dt.preferences.register(MODULE_NAME, "gmic_exe", "file",
_ ("executable for GMic CLI"),
_ ("select executable for GMic command line version"), "")

dt.preferences.register(MODULE_NAME, "exiftool_exe", "file",
_ ("executable for exiftool"),
_ ("select executable for GMic command line version"), "")

-- set output_folder_path to the last used value at startup ------------------
output_folder_path.text = dt.preferences.read(MODULE_NAME, "output_path", "string")

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
