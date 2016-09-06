--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Ellinghaus
    updated 2016 Bill Ferguson

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
    enfuse - export the selected images and run enfuse in one of two modes
    * Enfuse HDR - combine the exported images into a single HDR image
    * Enfuse Focus Stack - Combine a set of focus stack images into a single image

    USAGE
    * require this script from your main lua file
    * two new storage options are created, Enfuse HDR and Enfuse Focus Stack
    * Enfuse HDR
      * select the bracketed images to use for the hdr
      * adjust exposure mu to change the brightness of the output image
      * select bit depth of the output image
      * if align_image_stack is installed, an option to align the images is 
        available.  Unless you shot your images from a rock steady tripod you
        should probably select this.
      * choose the format and bit depth of the export
      * NOTE: You might want to specify a smaller size, jpg, and 8 bit to test
        the hdr output until you find the right combination, then export at full
        resolution with the desired format and depth.
      * click export
      * the resulting tif image will be imported.  The filename will consist of the
        individual filenames combined with hdr, i.e. 7D_1234-7D_1235-7D_1236-hdr.tif
    * Enfuse Focus Stack
      * select the focus stack images that need to be combined
      * select bit depth of the output image
      * if align_image_stack is installed, an option to align the images is 
        available.  Unless you shot your images from a rock steady tripod you
        should probably select this.
      * choose the format and bit depth of the export
      * NOTE: You might want to specify a smaller size, jpg, and 8 bit to test
        the stack output until you find the right combination, then export at full
        resolution with the desired format and depth.
      * click export
      * the resulting tif image will be imported.  The filename will consist of the
        first and last filenames combined with stack, i.e. 7D_1234-7D_1236-stack.tif
      * gray projector, contrast window size, and contrast edge scale can be adjusted
        to fine tune the output as explained in Pat David's blog post
        http://blog.patdavid.net/2013/01/focus-stacking-macro-photos-enfuse.html


    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * enfuse - http://enblend.sourceforge.net
    * align_image_stack - optional, part of hugin - http://hugin.sourceforge.net

    CAVEATS
    * No alignment is done on the images by default.  If align_image_stack is installed, an
      option to align the images is available.  Image alignment adds more time to the processing.
      Unless the images were taken using a rock steady tripod, aligning is recommended for best results.
    * Exporting 8 bit jpgs and specifying a 32 bit tif as output gives some interesting colors
    * Exporting 3 28MB raws to 16 bit tifs and specifying a 16 bit hdr tif takes 2+ minutes to 
      generate an hdr on a fast machine.  Focus stacking takes longer.  These numbers assume using 
      the single thread version of enfuse.  enfuse-mp gives much better results.

    CHANGES
    * 20160828 - Bill Ferguson 
      * Since enfuse can't process raw images, converted it to a storage so that raws can be converted
        and processed.  Named it Enfuse HDR
      * Added another storage to take advantage of enfuse's ability to process focus stack images
      * Fixed TODO - find a less stupid way to make sure the float value of exposure_mu gets turned into a string 
        with a decimal point instead of a comma in some languages
      * Fixed TODO - make the output filename unique so you can use it more than once per filmroll
      * Fixed TODO - export images that are not ldr and remove them afterwards
      * Removed TODO - save exposure-mu value when changed.  The value gets saved when the storage is executed.  It does not 
        get saved every time the slider is moved.  The slider api does not support a changed_callback.  The value is saved
        when Enfuse HDR runs.  I'm not sure there is any reason to save the slider value whenever it is changed and Enfuse HDR
        is not executed.
      * Added German message translations
      * Check for the multiprocessor version of enfuse and use it if installed.  On my system the mp version is 5 - 6 
        times faster (i7-6820HK CPU @ 2.70GHz)

    * 20160829 - Bill Ferguson
      * Added an option to align images using align_image_stack, part of the hugin project, if installed.
]]

local dt = require "darktable"
local gettext = dt.gettext
local enfuse_executable = "enfuse"

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuse",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("enfuse", msgid)
end

-- thanks Tobias Jakobs for this function (taken from contrib/hugin.lua)
local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
    dt.print_error("true checkIfBinExists: "..bin)
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end
  return ret
end

-- take care of the case where a decimal point is replaced by a comma in some locales
local function fixSliderFloat(float_str)
  if string.match(float_str,"[,.]") then 
    local characteristic, mantissa = string.match(float_str, "(%d+)[,.](%d+)")
    float_str = characteristic .. '.' .. mantissa
  end
  return float_str
end

-- print status while exporting images
local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
end

-- is enfuse installed?
local enfuse_installed = checkIfBinExists("enfuse")

-- check for the parallel version and use it if it's installed
if enfuse_installed and checkIfBinExists("enfuse-mp") then
  dt.print_error(_("enfuse-mp executable found, using it"))
  enfuse_executable = "enfuse-mp"
end

-- check for align_image_stack so we can offer to align the images if desired
local can_align = checkIfBinExists("align_image_stack")

-- initialize exposure_mu value and depth setting in config to sane defaults (would be 0 otherwise)
if dt.preferences.read("enfuse", "depth", "integer") == 0 then
  dt.preferences.write("enfuse", "depth", "integer", 2)
  dt.preferences.write("enfuse", "exposure_mu", "float", 0.5)
end

if dt.preferences.read("enfusestack", "depth", "integer") == 0 then
  dt.preferences.write("enfusestack", "depth", "integer", 2)
end

-- set up some hdr widgets, initialized from config
local exposure_mu = dt.new_widget("slider")
{
  label = _("exposure mu"),
  tooltip = _("center also known as MEAN of Gaussian weighting function (0 <= MEAN <= 1); default: 0.5"),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse", "exposure_mu", "float")
}

local depth = dt.new_widget("combobox")
{
  label = _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfuse", "depth", "integer"), "8", "16", "32"
}

local hdr_align
local hdr_widget

if can_align then 
  hdr_align = dt.new_widget("check_button")
  {
    label = _("Align Images"),
    value = false
  }

  hdr_widget = dt.new_widget("box")                                                         -- widget
  {
    orientation = "vertical",
    exposure_mu,
    depth,
    hdr_align
  }
else
  hdr_widget = dt.new_widget("box")                                                         -- widget
  {
    orientation = "vertical",
    exposure_mu,
    depth
  }
end

-- set up focus stack widgets

local stack_depth = dt.new_widget("combobox")
{
  label =  _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfusestack", "depth", "integer") or 2, "8", "16", "32"
}

local gray_projector = dt.new_widget("combobox")
{
  label =  _("gray projector"),
  tooltip = _("type of grayscale conversion, default = average"),
  value = 1, "average", "l-star"
}

local contrast_window = dt.new_widget("combobox")
{
  label =  _("contrast window size"),
  tooltip = _("size of box used for contrast detection, >= 3, default 5"),
  value = 3, "3", "4", "5", "6", "7", "8", "9"
}

local contrast_edge = dt.new_widget("slider")
{
  label =  _("contrast edge scale"),
  tooltip = _("laplacian edge detection, 0 disables, >0 enables, .3 is a good starting value"),
  hard_min = 0,
  hard_max = 1,
  value = 0
}

local stack_align
local stack_widget

if can_align then
  stack_align = dt.new_widget("check_button")
  {
    label = _("Align Images"),
    value = false
  }

  stack_widget = dt.new_widget("box")
  {
    orientation = "vertical",
    stack_depth,
    stack_align,
    gray_projector,
    contrast_window,
    contrast_edge
  }
else
  stack_widget = dt.new_widget("box")
  {
    orientation = "vertical",
    stack_depth,
    gray_projector,
    contrast_window,
    contrast_edge
  }
end

local function split_filepath(str)
  local result = {}
  -- Thank you Tobias Jakobs for the awesome regular expression, which I tweaked a little
  result["path"], result["filename"], result["basename"], result["filetype"] = string.match(str, "(.-)(([^\\/]-)%.?([^%.\\/]*))$")
  return result
end

local function get_path(str)
  local parts = split_filepath(str)
  return parts["path"]
end

local function get_filename(str)
  local parts = split_filepath(str)
  return parts["filename"]
end

local function get_basename(str)
  local parts = split_filepath(str)
  return parts["basename"]
end

local function get_filetype(str)
  local parts = split_filepath(str)
  return parts["filetype"]
end

-- Thanks Tobias Jakobs for the idea and the correction
local function checkIfFileExists(filepath)
  local file = io.open(filepath,"r")
  local ret
  if file ~= nil then 
    io.close(file) 
    dt.print_error("true checkIfFileExists: "..filepath)
    ret = true
  else 
    dt.print_error(filepath.." not found")
    ret = false
  end
  return ret
end

local function filename_increment(filepath)

  -- break up the filepath into parts
  local path = get_path(filepath)
  local basename = get_basename(filepath)
  local filetype = get_filetype(filepath)

  -- check to see if we've incremented before
  local increment = string.match(basename, "_(%d-)$")

  if increment then
    -- we do 2 digit increments so make sure we didn't grab part of the filename
    if string.len(increment) > 2 then
      -- we got the filename so set the increment to 01
      increment = "01"
    else
      increment = string.format("%02d", tonumber(increment) + 1)
      basename = string.gsub(basename, "_(%d-)$", "")
    end
  else
    increment = "01"
  end
  local incremented_filepath = path .. basename .. "_" .. increment .. "." .. filetype

  dt.print_error("original file was " .. filepath)
  dt.print_error("incremented file is " .. incremented_filepath)

  return incremented_filepath
end

local function sanitize_filename(filepath)
  local path = get_path(filepath)
  local basename = get_basename(filepath)
  local filetype = get_filetype(filepath)

  local sanitized = string.gsub(basename, " ", "\\ ")

  return path .. sanitized .. "." .. filetype
end

-- assemble a list of the files to send to enfuse.  If desired, align the files first
local function build_response_file(image_table, will_align)

  -- create a temp response file
  local response_file = os.tmpname()
  local f = io.open(response_file, "w")
  if not f then
     os.remove(response_file)
    return
  end

  local cnt = 0

  -- do the alignment first, if requested
  if will_align then
    local align_img_list = ""
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      align_img_list = align_img_list .. " " .. sanitize_filename(exp_img)
    end
    if cnt > 0 then
      local align_command = "align_image_stack -m -a /tmp/OUT " .. align_img_list
      dt.print(_("Aligning images..."))
      if dt.control.execute(align_command) then
        dt.print(_("Image alignment failed"))
        os.remove(response_file)
        return nil
      else
        -- alignment succeeded, so we'll use the /tmp/OUTxxxx.tif files
        for _,exp_img in pairs(image_table) do
          os.remove(exp_img)
        end
        -- get a list of the /tmp/OUTxxxx.tif files and put it in the response file
        a = io.popen("ls /tmp/OUT*")
        if a then
          local aligned_file = a:read()
          while aligned_file do
            f:write(aligned_file .. "\n")
            aligned_file = a:read()
          end
          a:close()
          f:close()
        else
          dt.print(_("No aligned images found"))
          os.remove(response_file)
          return nil
        end
      end
    end
  else
    -- add all filenames to the response file
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      f:write(exp_img .. "\n")
    end
    f:close()
  end

  if cnt == 0 then
    os.remove(response_file)
    dt.print(_("no suitable images selected, nothing to do for enfuse"))
    return nil
  else
    return response_file
  end
end

-- clean up after we've run or crashed
local function cleanup(res_file)
  -- remove exported images
  local f = io.open(res_file)
  fname = f:read()
  while fname do
    os.remove(fname)
    fname = f:read()
  end
  f:close()
  
  -- remove the response file
  os.remove(res_file)
end



-- ... and tell dt about it all

local function enfuse_hdr(storage, image_table, extra_data)
  -- remember exposure_mu
  local mu = exposure_mu.value
  dt.preferences.write("enfuse", "exposure_mu", "float", mu)

  -- save the depth value
  dt.preferences.write("enfuse", "depth", "integer", depth.value / 8)

  local will_align = false
  if can_align then
    will_align = hdr_align.value
  end

  -- create a temp response file
  local response_file = build_response_file(image_table, will_align)

  local target_dir
  local hdr_file_name = ""
  for img, exp_img in pairs(image_table) do
    target_dir = img.path
    hdr_file_name = get_basename(exp_img) .. '-' .. hdr_file_name
  end

  -- append hdr to the generated file name
  hdr_file_name = hdr_file_name .. "hdr"

  local output_image = target_dir.."/" .. hdr_file_name .. ".tif"

  while checkIfFileExists(output_image) do
    output_image = filename_increment(output_image)
    -- limit to 99 more hdr attempts
    if string.match(get_basename(output_image), "_(d-)$") == "99" then 
      break 
    end
  end

  -- call enfuse on the response file
  local command = enfuse_executable .. " --depth "..depth.value.." --exposure-mu "..fixSliderFloat(mu)
                  .." -o \""..output_image.."\" \"@"..response_file.."\""
  dt.print(_("Launching enfuse..."))
  if dt.control.execute(command) then
    dt.print(_("enfuse failed, see terminal output for details"))
    cleanup(response_file)
    return
  end

  cleanup(response_file)

  -- import resulting tiff
  local image = dt.database.import(output_image)

  -- tell the user that everything worked
  dt.print(_("enfuse was successful, resulting image was imported"))
  -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
  print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
end

local function enfuse_stack(storage, image_table, extra_data)
  local stack_args = " --exposure-weight=0 --saturation-weight=0 --contrast-weight=1 --hard-mask "

  -- save the depth value
  dt.preferences.write("enfusestack", "depth", "integer", stack_depth.value / 8)

  local will_align = false
  if can_align then
    will_align = stack_align.value
  end

  -- create a temp response file
  local response_file = build_response_file(image_table, can_align)

  local target_dir
  local stack_file_name = ""
  local first = true
  local file_name = ""
  for img, exp_img in pairs(image_table) do
    target_dir = img.path
    filename = get_basename(exp_img)
    if first then
      stack_file_name = filename
      first = false
    end
  end

  -- append hdr to the generated file name
  stack_file_name = stack_file_name .. "-" .. filename .. "-stack"

  -- call enfuse on the response file
  local output_image = target_dir.."/" .. stack_file_name .. ".tif"

  while checkIfFileExists(output_image) do
    output_image = filename_increment(output_image)
    -- limit to 99 more hdr attempts
    if string.match(get_basename(output_image), "_(d-)$") == "99" then 
      break 
    end
  end

  local command = enfuse_executable .. " --depth "..depth.value
                  ..stack_args.." --gray-projector="..gray_projector.value
                  .." --contrast-window-size="..contrast_window.value
                  .." --contrast-edge-scale="..fixSliderFloat(contrast_edge.value)
                  .." -o \""..output_image.."\" \"@"..response_file.."\""
  dt.print(_("Launching enfuse..."))
  if dt.control.execute(command) then
    dt.print(_("enfuse failed, see terminal output for details"))
    cleanup(response_file)
    return
  end

  cleanup(response_file)

  -- import resulting tiff
  local image = dt.database.import(output_image)

  -- tell the user that everything worked
  dt.print(_("enfuse was successful, resulting image was imported"))
  -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
  print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
end

if enfuse_installed then
  dt.register_storage("module_enfusehdr", _("Enfuse HDR"), show_status, enfuse_hdr, nil, nil, hdr_widget)
  dt.register_storage("module_enfusestack", _("Enfuse Focus Stack"), show_status, enfuse_stack, nil, nil, stack_widget)
end
