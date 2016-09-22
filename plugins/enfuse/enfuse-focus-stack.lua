--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Ellinghaus
    copyright (c) 2016 Bill Ferguson

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

require "lib/dtutils"
require "pluins/enfuse/lib/libenfuse"

local lib = dtutils

local dt = require "darktable"
local gettext = dt.gettext
local enfuse_executable = "enfuse"

dt.configuration.check_version(...,{3,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuse",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("enfuse", msgid)
end

-- is enfuse installed?
local enfuse_installed = lib.checkIfBinExists("enfuse")

-- check for the parallel version and use it if it's installed
if enfuse_installed and lib.checkIfBinExists("enfuse-mp") then
  dt.print_error(_("enfuse-mp executable found, using it"))
  enfuse_executable = "enfuse-mp"
end

-- check for align_image_stack so we can offer to align the images if desired
local can_align = lib.checkIfBinExists("align_image_stack")

-- set up focus stack widgets

-- gather the widgets in a table since there could be 4 or 5

local stack_widgets = {}
local widget_cnt = 1

-- bit depth
local stack_depth = dt.new_widget("combobox")
{
  label =  _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfusestack", "depth", "integer") or 2, "8", "16", "32"
}
stack_widgets[widget_cnt] = stack_depth
widget_cnt = widget_cnt + 1

-- align images
if can_align then
  stack_align = dt.new_widget("check_button")
  {
    label = _("Align Images"),
    value = false
  }
  stack_widgets[widget_cnt] = stack_align
  widget_cnt = widget_cnt + 1
end

-- gray projector
local gray_projector = dt.new_widget("combobox")
{
  label =  _("gray projector"),
  tooltip = _("type of grayscale conversion, default = average"),
  value = 1, "average", "l-star"
}
stack_widgets[widget_cnt] = gray_projector
widget_cnt = widget_cnt + 1

-- contrast window
contrast_window = dt.new_widget("combobox")
{
  label =  _("contrast window size"),
  tooltip = _("size of box used for contrast detection, >= 3, default 5"),
  value = 3, "3", "4", "5", "6", "7", "8", "9"
}
stack_widgets[widget_cnt] = contrast_window
widget_cnt = widget_cnt + 1

local contrast_edge = dt.new_widget("slider")
{
  label =  _("contrast edge scale"),
  tooltip = _("laplacian edge detection, 0 disables, >0 enables, .3 is a good starting value"),
  hard_min = 0,
  hard_max = 1,
  value = 0
}
stack_widgets[widget_cnt] = contrast_edge

-- enclose the widgets in a box

local stack_widget = dt.new_widget("box")
{
  orientation = "vertical",
  table.unpack(stack_widgets),
}

local function enfuse_stack(storage, image_table, extra_data)
  local stack_args = " --exposure-weight=0 --saturation-weight=0 --contrast-weight=1 --hard-mask "

  -- save the depth value
  dt.preferences.write("enfusestack", "depth", "integer", stack_depth.value / 8)

  local will_align = false
  if can_align then
    will_align = stack_align.value
  end

  -- create a temp response file
  local response_file = libenfuse.build_response_file(image_table, will_align)

  if response_file then
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

    while lib.checkIfFileExists(output_image) do
      output_image = lib.filename_increment(output_image)
      -- limit to 99 more hdr attempts
      if string.match(lib.get_basename(output_image), "_(d-)$") == "99" then 
        break 
      end
    end

    local command = enfuse_executable .. " --depth "..depth.value
                    ..stack_args.." --gray-projector="..gray_projector.value
                    .." --contrast-window-size="..contrast_window.value
                    .." --contrast-edge-scale="..lib.fixSliderFloat(contrast_edge.value)
                    .." -o \""..output_image.."\" \"@"..response_file.."\""
    dt.print(_("Launching enfuse..."))
    if dt.control.execute(command) then
      dt.print(_("enfuse failed, see terminal output for details"))
      libenfuse.cleanup(response_file)
      return
    end

    libenfuse.cleanup(response_file)

    -- import resulting tiff
    local image = dt.database.import(output_image)

    -- tell the user that everything worked
    dt.print(_("enfuse was successful, resulting image was imported"))
    -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
    print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
  end
end

-- don't install the storage if the executable isn't present, since it would never work

if enfuse_installed then
  dt.register_storage("module_enfusestack", _("Enfuse Focus Stack"), show_status, enfuse_stack, nil, nil, stack_widget)
end
