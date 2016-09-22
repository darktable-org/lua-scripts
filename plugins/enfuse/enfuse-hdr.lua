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

-- initialize exposure_mu value and depth setting in config to sane defaults (would be 0 otherwise)
if dt.preferences.read("enfuse", "depth", "integer") == 0 then
  dt.preferences.write("enfuse", "depth", "integer", 2)
  dt.preferences.write("enfuse", "exposure_mu", "float", 0.5)
end

if dt.preferences.read("enfusestack", "depth", "integer") == 0 then
  dt.preferences.write("enfusestack", "depth", "integer", 2)
end

-- gather the widgets in a table since there could be 2 or 3

local hdr_widgets = {}

-- exposure-mu
local exposure_mu = dt.new_widget("slider")
{
  label = _("exposure-mu"),
  tooltip = _("center also known as MEAN of Gaussian weighting function (0 <= MEAN <= 1); default: 0.5"),
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse", "exposure_mu", "float")
}
hdr_widgets[1] = exposure_mu

-- bit depth
local depth = dt.new_widget("combobox")
{
  label = _("depth"),
  tooltip = _("output image bits per channel"),
  value = dt.preferences.read("enfuse", "depth", "integer"), "8", "16", "32"
}
hdr_widgets[2] = depth

if can_align then 
  hdr_align = dt.new_widget("check_button")
  {
    label = _("Align Images"),
    value = false
  }
  hdr_widgets[3] = hdr_align
end

-- enclose the widgets in a box

local hdr_widget = dt.new_widget("box")                                                     -- widget
{
  orientation = "vertical",
  table.unpack(hdr_widgets),
}

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
  local response_file = libenfuse.build_response_file(image_table, will_align)

  if response_file then
    local target_dir
    local hdr_file_name = ""
    for img, exp_img in pairs(image_table) do
      target_dir = img.path
      hdr_file_name = lib.get_basename(exp_img) .. '-' .. hdr_file_name
    end

    -- append hdr to the generated file name
    hdr_file_name = hdr_file_name .. "hdr"

    local output_image = target_dir.."/" .. hdr_file_name .. ".tif"

    while lib.checkIfFileExists(output_image) do
      output_image = lib.filename_increment(output_image)
      -- limit to 99 more hdr attempts
      if string.match(lib.get_basename(output_image), "_(d-)$") == "99" then 
        break 
      end
    end

    -- call enfuse on the response file
    local command = enfuse_executable .. " --depth "..depth.value.." --exposure-mu "..lib.fixSliderFloat(mu)
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

if enfuse_installed then
  dt.register_storage("module_enfusehdr", _("Enfuse HDR"), lib.show_status, enfuse_hdr, nil, nil, hdr_widget)
end
