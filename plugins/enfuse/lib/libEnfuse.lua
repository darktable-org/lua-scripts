require "lib/dtutils"
local dt = require "darktable"
local gettext = dt.gettext
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuse",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("enfuse", msgid)
end


libEnfuse = {}

-- assemble a list of the files to send to enfuse.  If desired, align the files first
function libEnfuse.build_response_file(image_table, will_align)

  -- create a temp response file
  local response_file = os.tmpname()
  local f = io.open(response_file, "w")
  if not f then
     os.remove(response_file)
    return nil
  end

  local cnt = 0

  -- do the alignment first, if requested
  if will_align then
    local align_img_list = ""
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      align_img_list = align_img_list .. " " .. dtutils.sanitize_filename(exp_img)
    end
    -- need at least 2 images to align
    if cnt > 1 then
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
    else
      libEnfuse.cleanup(response_file)
      dt.print(_("not enough suitable images selected, nothing to do for enfuse"))
      return nil
    end
  else
    -- add all filenames to the response file
    for img, exp_img in pairs(image_table) do
      cnt = cnt + 1
      f:write(exp_img .. "\n")
    end
    f:close()
  end

  -- export will happily export 0 images if none are selected and the export button is pressed
  -- and it doesn't make any sense to try and do an hdr or focus stack on only 1 image

  if cnt < 2 then
    libEnfuse.cleanup(response_file)
    dt.print(_("not enough suitable images selected, nothing to do for enfuse"))
    return nil
  else
    return response_file
  end
end

-- clean up after we've run or crashed
function libEnfuse.cleanup(res_file)
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

function libEnfuse.can_align()
  return dtutils.checkIfBinExists('align_image_stack')
end

function libEnfuse.get_enfuse_executable()
  return dtutils.checkIfBinExists('enfuse-mp') and "enfuse-mp" or "enfuse"
end

-- enfuse_hdr specific routines

libEnfuse.exposure_mu = dt.new_widget("slider")
{
  label = _("exposure-mu"),
  tooltip = _("center also known as MEAN of Gaussian weighting function (0 <= MEAN <= 1); default: 0.5"),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse", "exposure_mu", "float")
}

-- bit depth
libEnfuse.depth = dt.new_widget("combobox")
{
  label = _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfuse", "depth", "integer"), "8", "16", "32"
}

libEnfuse.hdr_align = dt.new_widget("check_button")
{
  label = _("Align Images"),
  value = false
}

function libEnfuse.create_hdr_widget()
  local hdr_widgets = {}
  hdr_widgets[1] = libEnfuse.exposure_mu
  hdr_widgets[2] = libEnfuse.depth

  if libEnfuse.can_align() then 
    hdr_widgets[3] = libEnfuse.hdr_align
  end

-- enclose the widgets in a box

  return dt.new_widget("box")                                                     -- widget
  {
    orientation = "vertical",
    table.unpack(hdr_widgets),
  }
end

libEnfuse.hdr_widget = libEnfuse.create_hdr_widget()

function libEnfuse.enfuse_hdr(image_table, plugin_data)
  -- remember exposure_mu
  local mu = libEnfuse.exposure_mu.value
  dt.preferences.write("enfuse", "exposure_mu", "float", mu)

  -- save the depth value
  dt.preferences.write("enfuse", "depth", "integer", libEnfuse.depth.value / 8)

  local will_align = false
  if libEnfuse.can_align() then
    will_align = libEnfuse.hdr_align.value
  end

  -- create a temp response file
  local response_file = libEnfuse.build_response_file(image_table, will_align)

  if response_file then
    local target_dir = dtutils.extract_collection_path(image_table)
    local img_list = dtutils.extract_image_list(image_table)
    local hdr_file_name = dtutils.makeOutputFileName(img_list)

    -- append hdr to the generated file name
    hdr_file_name = hdr_file_name .. "-hdr"

    local output_image = target_dir.."/" .. hdr_file_name .. ".tif"

    while dtutils.checkIfFileExists(output_image) do
      output_image = dtutils.filename_increment(output_image)
      -- limit to 99 more hdr attempts
      if string.match(dtutils.get_basename(output_image), "_(d-)$") == "99" then 
        break 
      end
    end

    local enfuse_executable = libEnfuse.get_enfuse_executable()

    -- call enfuse on the response file
    local command = enfuse_executable .. " --depth "..libEnfuse.depth.value.." --exposure-mu "..dtutils.fixSliderFloat(mu)
                    .." -o \""..output_image.."\" \"@"..response_file.."\""
    dt.print(_("Launching enfuse..."))
    if dt.control.execute(command) then
      dt.print(_("enfuse failed, see terminal output for details"))
      libEnfuse.cleanup(response_file)
      return
    end

    libEnfuse.cleanup(response_file)

    -- import resulting tiff
    local image = dt.database.import(output_image)

    -- tell the user that everything worked
    dt.print(_("enfuse was successful, resulting image was imported"))
    -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
    print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
  end
end

-- enfuse_focus_stack specific routines

-- bit depth
libEnfuse.stack_depth = dt.new_widget("combobox")
{
  label =  _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfusestack", "depth", "integer") or 2, "8", "16", "32"
}

-- align images
libEnfuse.stack_align = dt.new_widget("check_button")
{
  label = _("Align Images"),
  value = false
}

-- gray projector
libEnfuse.gray_projector = dt.new_widget("combobox")
{
  label =  _("gray projector"),
  tooltip = _("type of grayscale conversion, default = average"),
  value = 1, "average", "l-star"
}

-- contrast window
libEnfuse.contrast_window = dt.new_widget("combobox")
{
  label =  _("contrast window size"),
  tooltip = _("size of box used for contrast detection, >= 3, default 5"),
  value = 3, "3", "4", "5", "6", "7", "8", "9"
}

libEnfuse.contrast_edge = dt.new_widget("slider")
{
  label =  _("contrast edge scale"),
  tooltip = _("laplacian edge detection, 0 disables, >0 enables, .3 is a good starting value"),
  hard_min = 0,
  hard_max = 1,
  value = 0
}

-- enclose the widgets in a box

function libEnfuse.create_stack_widget()
  local stack_widgets = {}
  local widget_cnt = 1

  stack_widgets[widget_cnt] = libEnfuse.stack_depth
  widget_cnt = widget_cnt + 1

  if libEnfuse.can_align() then
    stack_widgets[widget_cnt] = libEnfuse.stack_align
    widget_cnt = widget_cnt + 1
  end
  stack_widgets[widget_cnt] = libEnfuse.gray_projector
  widget_cnt = widget_cnt + 1
  stack_widgets[widget_cnt] = libEnfuse.contrast_window
  widget_cnt = widget_cnt + 1
  stack_widgets[widget_cnt] = libEnfuse.contrast_edge

  return dt.new_widget("box")
        {
          orientation = "vertical",
          table.unpack(stack_widgets),
        }
end

libEnfuse.stack_widget = libEnfuse.create_stack_widget()

function libEnfuse.enfuse_stack(image_table, plugin_data)
  local stack_args = " --exposure-weight=0 --saturation-weight=0 --contrast-weight=1 --hard-mask "

  -- save the depth value
  dt.preferences.write("enfusestack", "depth", "integer", libEnfuse.stack_depth.value / 8)

  local will_align = false
  if libEnfuse.can_align() then
    will_align = libEnfuse.stack_align.value
  end

  -- create a temp response file
  local response_file = libEnfuse.build_response_file(image_table, will_align)

  if response_file then
    local target_dir = dtutils.extract_collection_path(image_table)
    local img_list = dtutils.extract_image_list(image_table)
    local stack_file_name = dtutils.makeOutputFileName(img_list)

    -- append hdr to the generated file name
    stack_file_name = stack_file_name .. "-stack"

    -- call enfuse on the response file
    local output_image = target_dir.."/" .. stack_file_name .. ".tif"

    while dtutils.checkIfFileExists(output_image) do
      output_image = dtutils.filename_increment(output_image)
      -- limit to 99 more hdr attempts
      if string.match(dtutils.get_basename(output_image), "_(d-)$") == "99" then 
        break 
      end
    end

    local enfuse_executable = libEnfuse.get_enfuse_executable()

    local command = enfuse_executable .. " --depth "..libEnfuse.stack_depth.value
                    ..stack_args.." --gray-projector="..libEnfuse.gray_projector.value
                    .." --contrast-window-size="..libEnfuse.contrast_window.value
                    .." --contrast-edge-scale="..dtutils.fixSliderFloat(libEnfuse.contrast_edge.value)
                    .." -o \""..output_image.."\" \"@"..response_file.."\""
    dt.print(_("Launching enfuse..."))
    if dt.control.execute(command) then
      dt.print(_("enfuse failed, see terminal output for details"))
      libEnfuse.cleanup(response_file)
      return
    end

    libEnfuse.cleanup(response_file)

    -- import resulting tiff
    local image = dt.database.import(output_image)

    -- tell the user that everything worked
    dt.print(_("enfuse was successful, resulting image was imported"))
    -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
    print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
  end
end


return libEnfuse
