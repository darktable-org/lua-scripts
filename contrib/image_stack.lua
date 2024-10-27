--[[

    image_stack.lua - process a stack of images

    Copyright (C) 2018 Bill Ferguson <wpferguson@gmail.com>.
    Copyright (C) 2016,2017 Holger Klemm 

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
    image_stack - export a stack of images and process them, returning the result

    This script provides another storage (export target) for darktable.  Selected
    images are exported in the specified format to temporary storage.  The images are aligned
    if the user requests it. When the images are ready, imagemagick is launched and uses
    the selected evaluate-sequence operator to process the images.  The output file is written
    to a filename representing the imput files in the format specified by the user.  The resulting 
    image is imported into the film roll.  The source images can be tagged as part of the file 
    creation so that  a user can later find the contributing images.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * align_image_stack - http://www.hugin.org
    * imagemagick - http://www.imagemagick.org

    USAGE
    * require this script from your main lua file
    * select the images to process with image_stack
    * in the export dialog select "image stack" and select the format and bit depth for the
      exported image
    * Select whether the images need to be aligned.
    * Select the stack operator
    * Select the output format
    * Select whether to tag the source images used to create the resulting file
    * Specify executable locations if necessary
    * Press "export"
    * The resulting image will be imported

    NOTES
    Mean is a fairly quick operation.  On my machine (i7-6800K, 16G) it takes a few seconds.  Median, on the other hand
    takes approximately 10x longer to complete.  Processing 10 and 12 image stacks took over a minute.  I didn't test all
    the other functions, but the ones I did fell between Mean and Median performance wise.

    BUGS, COMMENTS, SUGGESTIONS
    * Send to Bill Ferguson, wpferguson@gmail.com

    CHANGES

    THANKS
    * Thanks to Pat David and his blog entry on blending images, https://patdavid.net/2013/05/noise-removal-in-photos-with-median_6.html
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext
local job = nil

-- path separator constant
local PS = dt.configuration.running_os == "windows" and "\\" or "/"

-- works with LUA API version 5.0.0
du.check_min_api_version("7.0.0", "image_stack") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("image stack"),
  purpose = _("process a stack of images"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/image_stack"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
--  GUI definitions
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

local label_align_options= dt.new_widget("section_label"){
  label = _('image align options')
}

local label_image_stack_options = dt.new_widget("section_label"){
  label = _("image stack options")
}

local label_executable_locations = dt.new_widget("section_label"){
  label = _("executable locations")
}

if not(dt.preferences.read("align_image_stack",  "initialized", "bool")) then
   dt.preferences.write("align_image_stack", "def_radial_distortion", "bool", false)      
   dt.preferences.write("align_image_stack", "def_optimize_field", "bool", false) 
   dt.preferences.write("align_image_stack", "def_optimize_image_center", "bool", true) 
   dt.preferences.write("align_image_stack", "def_auto_crop", "bool", true) 
   dt.preferences.write("align_image_stack", "def_distortion", "bool", true) 
   dt.preferences.write("align_image_stack", "def_grid_size", "integer", 5)
   dt.preferences.write("align_image_stack", "def_control_points", "integer", 8)
   dt.preferences.write("align_image_stack", "def_control_points_remove", "integer", 3)
   dt.preferences.write("align_image_stack", "def_correlation", "integer", 9)
   dt.preferences.write("align_image_stack",  "initialized", "bool", true) 
end

if not(dt.preferences.read("image_stack", "initialized", "bool")) then
  dt.preferences.write("image_stack", "align_images", "bool", true)
  dt.preferences.write("image_stack", "stack_function", "integer", 2)
  dt.preferences.write("image_stack", "output_format", "integer", 6)
  dt.preferences.write("image_stack", "tag_images", "bool", true)
  dt.preferences.write("image_stack", "initialized", "bool", true)
end

local chkbtn_will_align = dt.new_widget("check_button"){
  label = _('perform image alignment'),
  value = dt.preferences.read("image_stack", "align_images", "bool"),
  tooltip = _('align the image stack before processing')
}
  
local chkbtn_radial_distortion = dt.new_widget("check_button"){
  label = _('optimize radial distortion for all images'),
  value = dt.preferences.read("align_image_stack", "def_radial_distortion", "bool"),
  tooltip = _('optimize radial distortion for all images, \nexcept the first'),
}

local chkbtn_optimize_field = dt.new_widget("check_button"){
    label = _('optimize field of view for all images'), 
    value = dt.preferences.read("align_image_stack", "def_optimize_field", "bool"),
    tooltip =_('optimize field of view for all images, except the first. \nUseful for aligning focus stacks (DFF) with slightly \ndifferent magnification.'), 
}

local chkbtn_optimize_image_center = dt.new_widget("check_button"){
    label = _('optimize image center shift for all images'), 
    value = dt.preferences.read("align_image_stack", "def_optimize_image_center", "bool"),
    tooltip =_('optimize image center shift for all images, \nexcept the first.'),   
}

local chkbtn_auto_crop = dt.new_widget("check_button"){
    label = _('auto crop the image'), 
    value = dt.preferences.read("align_image_stack", "def_auto_crop", "bool"),
    tooltip =_('auto crop the image to the area covered by all images.'),   
}

local chkbtn_distortion = dt.new_widget("check_button"){
    label = _('load distortion from lens database'), 
    value = dt.preferences.read("align_image_stack", "def_distortion", "bool"),
    tooltip =_('try to load distortion information from lens database'),   
}

local cmbx_grid_size = dt.new_widget("combobox"){
    label = _('image grid size'), 
    tooltip =_('break image into a rectangular grid \nand attempt to find num control points in each section.\ndefault: (5x5)'),
    value = dt.preferences.read("align_image_stack", "def_grid_size", "integer"), --5
    "1", "2", "3","4","5","6","7","8","9",
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_grid_size", "integer")
    end
} 

local cmbx_control_points = dt.new_widget("combobox"){
    label = _('control points/grid'), 
    tooltip =_('number of control points (per grid, see option -g) \nto create between adjacent images \ndefault: (8).'),
    value = dt.preferences.read("align_image_stack", "def_control_points", "integer"),   --8, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",             
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_control_points", "integer")
    end
} 

local cmbx_control_points_remove = dt.new_widget("combobox"){
    label = _('remove control points with error'), 
    tooltip =_('remove all control points with an error higher \nthan num pixels \ndefault: (3)'),
    value = dt.preferences.read("align_image_stack", "def_control_points_remove", "integer"), --3, "1", "2", "3","4","5","6","7","8","9",
    "1", "2", "3","4","5","6","7","8","9",              
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_control_points_remove", "integer")
    end
} 

local cmbx_correlation  = dt.new_widget("combobox"){
    label = _('correlation threshold for control points'), 
    tooltip =_('correlation threshold for identifying \ncontrol points \ndefault: (0.9).'),
    value = dt.preferences.read("align_image_stack", "def_correlation", "integer"), --9, "0,1", "0,2", "0,3","0,4","0,5","0,6","0,7","0,8","0,9",
    "0.1", "0.2", "0.3","0.4","0.5","0.6","0.7","0.8","0.9","1.0",     
    reset_callback = function(self)
       self.value = dt.preferences.read("align_image_stack", "def_correlation", "integer")
    end
} 

local cmbx_stack_function = dt.new_widget("combobox"){
  label = _("select stack function"),
  tooltip = _("select function to be \napplied to image stack"),
  value = dt.preferences.read("image_stack", "stack_function", "integer"), "Mean", "Median", "Abs", "Add", "And", "Divide", "Max", "Min",
                                                                          "Or", "Subtract", "Sum", "Xor",
  reset_callback = function(self)
    self.value = dt.preferences.read("image_stack", "stack_function", "integer")
  end
}

local cmbx_output_format = dt.new_widget("combobox"){
  label = _("select output format"),
  tooltip = _("choose the format for the resulting image"),
  value = dt.preferences.read("image_stack", "output_format", "integer"), "EXR", "JPG", "PNG", "PNM", "PPM", "TIF",
  reset_callback = function(self)
    self.value = dt.preferences.read("image_stack", "output_format", "integer")
  end
}

local chkbtn_tag_source_file = dt.new_widget("check_button"){
  label = _("tag source images used?"),
  value = dt.preferences.read("image_stack", "tag_images", "bool"),
  tooltip = _("tag the source images used to create the output file?")
}

local image_stack_widget = dt.new_widget("box"){
  orientation = "vertical",
  label_align_options,
  chkbtn_will_align,
  chkbtn_radial_distortion,
  chkbtn_optimize_field,
  chkbtn_optimize_image_center,
  chkbtn_auto_crop,
  chkbtn_distortion,
  cmbx_grid_size,
  cmbx_control_points,
  cmbx_control_points_remove,
  cmbx_correlation,
  dt.new_widget("separator"){},
  dt.new_widget("separator"){},
  label_image_stack_options,
  cmbx_stack_function,
  cmbx_output_format,
  chkbtn_tag_source_file,
}

local executables = {"align_image_stack", "convert"}

if dt.configuration.running_os ~= "linux" then
  image_stack_widget[#image_stack_widget + 1] = df.executable_path_widget(executables)
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
--  local functions
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data)
    dt.print(string.format(_("export image %i/%i"), number, total))
end

-- read the gui and populate the align_image_stack arguments

local function get_align_image_stack_arguments()
  
  --Setup Align Image Stack Arguments--
  local align_args = ""
  if (chkbtn_radial_distortion.value) then align_args = align_args .. " -d" end
  if (chkbtn_optimize_field.value) then align_args = align_args .. " -m" end  
  if (chkbtn_optimize_image_center.value) then align_args = align_args .. " -i" end
  if (chkbtn_auto_crop.value) then align_args = align_args .. " -C" end     
  if (chkbtn_distortion.value) then align_args = align_args .. " --distortion" end

  dt.preferences.write("align_image_stack", "def_radial_distortion", "bool", chkbtn_radial_distortion.value)      
  dt.preferences.write("align_image_stack", "def_optimize_field", "bool", chkbtn_optimize_field.value) 
  dt.preferences.write("align_image_stack", "def_optimize_image_center", "bool", chkbtn_optimize_image_center.value) 
  dt.preferences.write("align_image_stack", "def_auto_crop", "bool", chkbtn_auto_crop.value) 
  dt.preferences.write("align_image_stack", "def_distortion", "bool", chkbtn_distortion.value) 

  align_args = align_args.." -g "..cmbx_grid_size.value
  align_args = align_args.." -c "..cmbx_control_points.value          
  align_args = align_args.." -t "..cmbx_control_points_remove.value
  align_args = align_args.." --corr="..cmbx_correlation.value

  dt.preferences.write("align_image_stack", "def_grid_size", "integer", cmbx_grid_size.selected)
  dt.preferences.write("align_image_stack", "def_control_points", "integer", cmbx_control_points.selected)
  dt.preferences.write("align_image_stack", "def_control_points_remove", "integer", cmbx_control_points_remove.selected)
  dt.preferences.write("align_image_stack", "def_correlation", "integer", cmbx_correlation.selected)

  if (dt.preferences.read("align_image_stack", "align_use_gpu", "bool")) then align_args = align_args .. " --gpu" end

  align_args = align_args .. " -a " .. dt.configuration.tmp_dir .. "/aligned_ "

  return align_args
end

-- extract, and sanitize, an image list from the supplied image table

local function extract_image_list(image_table)
  local img_list = ""
  local result = {}

  for img,expimg in pairs(image_table) do
    table.insert(result, expimg)
  end
  table.sort(result)
  for _,exp_img in ipairs(result) do
    img_list = img_list .. " " .. df.sanitize_filename(exp_img)
  end
  return img_list, #result
end

-- don't leave files laying around the operating system

local function cleanup(img_list)
  dt.print_log("image list is " .. img_list)
  files = du.split(img_list, " ")
  for _,f in ipairs(files) do
    f = string.gsub(f, '[\'\"]', "")
    os.remove(f)
  end
end

-- List files based on a search pattern.  This is cross platform compatible
-- but the windows version is recursive in order to get ls type listings.
-- Normally this shouldn't be a problem, but if you use this code just beware.
-- If you want to do it non recursively, then remove the /s argument from dir
-- and grab the path component from the search string and prepend it to the files
-- found.

local function list_files(search_string)
  local ls = "ls "
  local files = {}
  local dir_path = nil
  local count = 1

  if dt.configuration.running_os == "windows" then
    ls = "dir /b/s "
    search_string = string.gsub(search_string, "/", "\\\\")
  end

  local f = io.popen(ls .. search_string)
  if f then
    local found_file = f:read()
    while found_file do 
      files[count] = found_file
      count = count + 1
      found_file = f:read()
    end
    f:close()
  end
  return files
end

-- create a filename from a multi image set.  The image list is sorted, then
-- combined with first and last if more than 3 images or a - separated list
-- if three images or less.

local function make_output_filename(image_table)
  local images = {}
  local cnt = 1
  local max_distinct_names = 3
  local name_separator = "-"
  local outputFileName = nil
  local result = {}

  for img,expimg in pairs(image_table) do
    table.insert(result, expimg)
  end
  table.sort(result)
  for _,img in pairs(result) do
    images[cnt] = df.get_basename(img)
    cnt = cnt + 1
  end

  cnt = cnt - 1

  if cnt > 1 then
    if cnt > max_distinct_names then
      -- take the first and last
      outputFileName = images[1] .. name_separator .. images[cnt]
    else
      -- join them
      outputFileName = du.join(images, name_separator)
    end
  else
    -- return the single name
    outputFileName = images[cnt]
  end

  return outputFileName
end

-- get the path where the collection is stored

local function extract_collection_path(image_table)
  local collection_path = nil
  for i,_ in pairs(image_table) do
    collection_path = i.path
    break
  end
  return collection_path
end

-- copy an images database attributes to another image.  This only
-- copies what the database knows, not the actual exif data in the 
-- image itself.

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

local function stop_job()
  job.valid = false
end

local function destroy()
  dt.destroy_storage("module_image_stack")
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
--  main program
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

local function image_stack(storage, image_table, extra_data)

  local will_align = chkbtn_will_align.value
  local img_list, image_count = extract_image_list(image_table)
  local tmp_dir = dt.configuration.tmp_dir .. PS
  local stack_function = cmbx_stack_function.value
  local output_format = cmbx_output_format.value
  local tag_source = chkbtn_tag_source_file.value
  local tasks = 3

  if will_align then
    tasks = tasks + 1
  end

  if tag_source then
    tasks = tasks + 1
  end

  local percent_step = 1 / tasks

  -- update preferences
  dt.preferences.write("image_stack", "align_images", "bool", will_align)
  dt.preferences.write("image_stack", "stack_function", "integer", cmbx_stack_function.selected)
  dt.preferences.write("image_stack", "output_format", "integer", cmbx_output_format.selected)

  if image_count < 2 then
    dt.print(_("ERROR: at least 2 images required for image stacking, exiting..."))
    dt.print_error(image_count .. " image(s) selected, at least 2 required")
    return
  end

  job = dt.gui.create_job(_("image stack"), true, stop_job)
  job.percent = job.percent + percent_step

  -- align images if requested
  if will_align then
    local align_image_stack_executable = df.check_if_bin_exists("align_image_stack")
    if align_image_stack_executable then
      local align_args = get_align_image_stack_arguments()
      local align_image_stack_command = align_image_stack_executable .. align_args .. " " .. img_list
      dt.print_log(align_image_stack_command)
      dt.print(_("aligning images..."))
      local result = dtsys.external_command(align_image_stack_command)
      if result == 0 then
        dt.print(_("images aligned"))
        local files = list_files(tmp_dir .. "aligned_*")
        cleanup(img_list)
        img_list = extract_image_list(files)
        job.percent = job.percent + percent_step
      else
        dt.print(_("ERROR: image alignment failed"))
        dt.print_error("image alignment failed")
        cleanup(img_list)
        return
      end
    else
      dt.print(_("ERROR: align_image_stack not found"))
      dt.print_error("align_image_stack not found")
      cleanup(img_list)
      return
    end
  end

  -- stack images
  local output_filename = tmp_dir .. make_output_filename(image_table) .. "." .. string.lower(output_format)
  local convert_arguments = img_list .. " -evaluate-sequence " .. stack_function .. " " .. df.sanitize_filename(output_filename)
  local convert_executable = df.check_if_bin_exists("convert")
  -- tif images exported from darktable have private tiff tags embedded in them and convert complains about them
  local ignore_tif_tags = " -quiet -define tiff:ignore-tags=40965,42032,42033,42034,42036,18246,18249,36867,34864,34866 "
  if convert_executable then
    local convert_command = convert_executable .. ignore_tif_tags .. convert_arguments
    dt.print_log("convert command is " .. convert_command)
    dt.print(_("processing image stack"))
    local result = dtsys.external_command(convert_command)
    if result == 0 then
      dt.print(_("image stack processed"))
      cleanup(img_list)
      job.percent = job.percent + percent_step

      -- import image
      dt.print(_("importing result"))
      local film_roll_path = extract_collection_path(image_table)
      local import_filename = df.create_unique_filename(film_roll_path .. PS .. df.get_filename(output_filename))
      df.file_move(output_filename, import_filename)
      imported_image = dt.database.import(import_filename)
      local created_tag = dt.tags.create(_("created with|image_stack"))
      dt.tags.attach(created_tag, imported_image)
      -- all the images are the same except for time, so just copy the  attributes
      -- from the first
      for img,_ in pairs(image_table) do
        copy_image_attributes(img, imported_image)
        break
      end
      job.percent = job.percent + percent_step

      -- tag images if requested

      if tag_source then
        dt.print(_("tagging source images"))
        local source_tag = dt.tags.create(_("source file|" .. imported_image.filename))
        for img, _ in pairs(image_table) do 
          dt.tags.attach(source_tag, img)
        end
        job.percent = job.percent + percent_step
      end
    else
      dt.print(_("ERROR: image stack processing failed"))
      cleanup(img_list)
    end
  else
    dt.print(_("ERROR: convert executable not found"))
    dt.print_error("convert executable not found")
    cleanup(img_list)
  end
  job.valid = false
end

-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 
--  darktable integration
-- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register("align_image_stack", "align_use_gpu", -- name
  "bool",                                                     -- type
  _('align image stack: use GPU for remapping'),               -- label
  _('set the GPU remapping for image align'),                 -- tooltip
  false)

dt.register_storage("module_image_stack", _("image stack"), show_status, image_stack, nil, nil, image_stack_widget)

script_data.destroy = destroy

return script_data
