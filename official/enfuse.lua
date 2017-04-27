--[[
    This file is part of darktable,
    copyright (c) 2016 Tobias Ellinghaus

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
RUN ENFUSE ON THE SELECTED IMAGES
This script uses enfuse to merge the selected images into one tonemapped image and imports the result.
It only works on ldr images (like, JPEG).

USAGE
* require this script from your main lua file
* it creates a new lighttable module

TODO
* remember the exposure_mu value in config when the slider is moved
* make the output filename unique so you can use it more than once per filmroll
* find a less stupid way to make sure the float value of exposure_mu gets turned into a string
  with a decimal point instead of a comma in some languages
* export images that are not ldr and remove them afterwards
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

dt.configuration.check_version(...,{3,0,0},{4,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("enfuse",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("enfuse", msgid)
end

-- add a new lib
-- is enfuse installed?
local enfuse_installed = df.check_if_bin_exists("enfuse")

-- initialize exposure_mu value and depth setting in config to sane defaults (would be 0 otherwise)
if dt.preferences.read("enfuse", "depth", "integer") == 0 then
  dt.preferences.write("enfuse", "depth", "integer", 2)
  dt.preferences.write("enfuse", "exposure_mu", "float", 0.5)
end

-- set up some widgets, initialized from config
local exposure_mu = dt.new_widget("slider")
{
  label = "exposure mu",
  tooltip = "center also known as MEAN of Gaussian weighting function (0 <= MEAN <= 1); default: 0.5",
  hard_min = 0,
  hard_max = 1,
  value = dt.preferences.read("enfuse", "exposure_mu", "float")
}

local depth = dt.new_widget("combobox")
{
  label = "depth",
  tooltip = "the number of bits per channel of the output image",
  value = dt.preferences.read("enfuse", "depth", "integer"),
  changed_callback = function(w) dt.preferences.write("enfuse", "depth", "integer", w.selected) end,
  "8", "16", "32"
}

-- ... and tell dt about it all
dt.register_lib(
  "enfuse",                                                                    -- plugin name
  "enfuse",                                                                    -- name
  true,                                                                        -- expandable
  false,                                                                       -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
  dt.new_widget("box")                                                         -- widget
  {
    orientation = "vertical",
    sensitive = enfuse_installed,
    exposure_mu,
    depth,
    dt.new_widget("button")
    {
      label = enfuse_installed and "run enfuse" or "enfuse not installed",
      clicked_callback = function (_)
        -- remember exposure_mu
        -- TODO: find a way to save it whenever the value changes
        local mu = exposure_mu.value
        dt.preferences.write("enfuse", "exposure_mu", "float", mu)

        -- create a temp response file
        local response_file = os.tmpname()
        local f = io.open(response_file, "w")
        if not f then
          dt.print("error writing to `"..response_file.."'")
          os.remove(response_file)
          return
        end

        -- add all filenames to the response file
        local cnt = 0
        local n_skipped = 0
        local target_dir
        for _, i in ipairs(dt.gui.action_images) do
          -- only use ldr files as enfuse can't open raws. alternatively we could export raws that we encounter
          if i.is_ldr then
            cnt = cnt + 1
            f:write(i.path.."/"..i.filename.."\n")
            target_dir = i.path
          else
            dt.print("skipping "..i.filename)
            n_skipped = n_skipped + 1
          end
        end
        f:close()
        -- bail out if there is nothing to do
        if cnt == 0 then
          dt.print("no suitable images selected, nothing to do for enfuse")
          os.remove(response_file)
          return
        end
        if n_skipped == 1 then
          dt.print(n_skipped.." image skipped")
        elseif n_skipped > 1 then
          dt.print(n_skipped.." images skipped")
        end

        -- call enfuse on the response file
        -- TODO: find something nicer
        local ugly_decimal_point_hack = string.gsub(string.format("%.04f", mu), ",", ".")
        -- TODO: make filename unique
        local output_image = target_dir.."/enfuse.tiff"
        local command = "enfuse --depth "..depth.value.." --exposure-mu "..ugly_decimal_point_hack
                        .." -o \""..output_image.."\" \"@"..response_file.."\""
        if dt.control.execute( command) > 0 then
          dt.print("enfuse failed, see terminal output for details")
          os.remove(response_file)
          return
        end

        -- remove the response file
        os.remove(response_file)

        -- import resulting tiff
        local image = dt.database.import(output_image)

        -- tell the user that everything worked
        dt.print("enfuse was successful, resulting image was imported")
        -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
        print("enfuse: done, resulting image '"..output_image.."' was imported with id "..image.id)
      end
    }
  },
  nil,-- view_enter
  nil -- view_leave
)

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
