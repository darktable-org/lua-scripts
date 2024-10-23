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
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local dtsys = require "lib/dtutils.system"

local PS = dt.configuration.running_os == "windows" and "\\" or "/"

local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "enfuse")

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("enfuse"),
  purpose = _("exposure blend images"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/enfuse"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local enf = {}
enf.event_registered = false
enf.module_installed = false
enf.lib_widgets = {}

local function install_module()
  if not enf.module_installed then
    dt.register_lib(
      "enfuse",                                                                    -- plugin name
      _("enfuse"),                                                                    -- name
      true,                                                                        -- expandable
      false,                                                                       -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
      dt.new_widget("box")                                                         -- widget
      {
        orientation = "vertical",
        sensitive = enfuse_installed,
        table.unpack(enf.lib_widgets)
      },
      nil,-- view_enter
      nil -- view_leave
    )
    enf.module_installed = true
  end
end

local function destroy()
  dt.gui.libs["enfuse"].visible = false
end

local function restart()
  dt.gui.libs["enfuse"].visible = true
end

-- add a new lib
-- is enfuse installed?
local enfuse_installed = df.check_if_bin_exists("enfuse")

if enfuse_installed then
  dt.print_log("found enfuse executable at " .. enfuse_installed)

  -- instance of DT tiff exporter
  local tiff_exporter = dt.new_format("tiff")
  tiff_exporter.bpp = 16
  tiff_exporter.max_height = 0
  tiff_exporter.max_width = 0

  -- check the version so that we can use the correct arguments

  local version = nil

  local p = io.popen(enfuse_installed .. " --version")
  local f = p:read("all")
  p:close()
  version = string.match(f, "enfuse (%d.%d)")
  dt.print_log("enfuse version is " .. version)


  -- initialize exposure_mu value and depth setting in config to sane defaults (would be 0 otherwise)
  if dt.preferences.read("enfuse", "depth", "integer") == 0 then
    dt.preferences.write("enfuse", "depth", "integer", 2)
    dt.preferences.write("enfuse", "exposure_mu", "float", 0.5)
    dt.preferences.write("enfuse", "exposure_optimum", "float", 0.5)
  end

  -- set up some widgets, initialized from config

  local exposure_mu = nil

  if version < "4.2" then
    exposure_mu = dt.new_widget("slider")
    {
      label = _("exposure mu"),
      tooltip = _("center also known as mean of gaussian weighting function (0 <= mean <= 1); default: 0.5"),
      hard_min = 0,
      hard_max = 1,
      value = dt.preferences.read("enfuse", "exposure_mu", "float")
    }
  else
    exposure_mu = dt.new_widget("slider")
    {
      label = _("exposure optimum"),
      tooltip = _("optimum exposure value, usually the maximum of the weighting function (0 <= optimum <=1); default 0.5"),
      hard_min = 0,
      hard_max = 1,
      value = dt.preferences.read("enfuse", "exposure_optimum", "float")
    }
  end
    
  local depth = dt.new_widget("combobox")
  {
    label = _("depth"),
    tooltip = _("the number of bits per channel of the output image"),
    value = dt.preferences.read("enfuse", "depth", "integer"),
    changed_callback = function(w) dt.preferences.write("enfuse", "depth", "integer", w.selected) end,
    "8", "16", "32"
  }

  local blend_colorspace = dt.new_widget("combobox")
  {
    label = _("blend colorspace"),
    tooltip = _("force blending in selected colorspace"),
    changed_callback = function(w) dt.preferences.write("enfuse", "blend_colorspace", "string", w.selected) end,
    "", "identity", "ciecam"
  }

  local enfuse_button = dt.new_widget("button")
  {
    label = enfuse_installed and _("run enfuse") or _("enfuse not installed"),
    clicked_callback = function ()
      -- remember exposure_mu
      -- TODO: find a way to save it whenever the value changes
      local mu = exposure_mu.value
      if version < "4.2" then
        dt.preferences.write("enfuse", "exposure-mu", "float", mu)
      else
        dt.preferences.write("enfuse", "exposure-optimum", "float", mu)
      end

      -- create a temp response file
      local response_file = os.tmpname()
      if dt.configuration.running_os == "windows" then
        response_file = dt.configuration.tmp_dir .. response_file -- windows os.tmpname() defaults to root directory
      end
      local f = io.open(response_file, "w")
      if not f then
        dt.print(string.format(_("error writing to '%s'"), response_file))
        os.remove(response_file)
        return
      end

      -- add all filenames to the response file
      local cnt = 0
      local n_skipped = 0
      local target_dir
      for i_, i in ipairs(dt.gui.action_images) do

        -- only use ldr files as enfuse can't open raws
        if i.is_ldr then
          cnt = cnt + 1
          f:write(i.path..PS..i.filename.."\n")
          target_dir = i.path

        -- alternatively raws will be exported as tiff
        elseif i.is_raw then
          local tmp_exported = os.tmpname()..".tif"
          if dt.configuration.running_os == "windows" then
            tmp_exported = dt.configuration.tmp_dir .. tmp_exported -- windows os.tmpname() defaults to root directory
          end
              dt.print(string.format(_("converting raw file '%s' to tiff..."), i.filename)) 
          tiff_exporter:write_image(i, tmp_exported, false)
          dt.print_log(string.format("raw file '%s' converted to '%s'", i.filename, tmp_exported))

          cnt = cnt + 1
          f:write(tmp_exported.."\n")
          target_dir = i.path
          
        -- other images will be skipped
        else
          dt.print(string.format(_("skipping %s..."), i.filename))
          n_skipped = n_skipped + 1
        end
      end
      f:close()
      -- bail out if there is nothing to do
      if cnt == 0 then
        dt.print(_("no suitable images selected, nothing to do for enfuse"))
        os.remove(response_file)
        return
      end

      if n_skipped > 0 then
        dt.print(string.format(_("%d image(s) skipped"), n_skipped))
      end

      -- call enfuse on the response file
      -- TODO: find something nicer
      local ugly_decimal_point_hack = string.gsub(string.format("%.04f", mu), ",", ".")
      local output_image_date = os.date("%Y%m%d%H%M%S")
      local output_image = target_dir.. PS .. "enfuse-"..output_image_date..".tif"
      local exposure_option = " --exposure-optimum "
      local blend_colorspace_option = ""
      if #blend_colorspace.value > 1 then
        blend_colorspace_option = " --blend-colorspace="..blend_colorspace.value
      end
      if version < "4.2" then
        exposure_option = " --exposure-mu "
      end
      local command = enfuse_installed.." --depth "..depth.value..exposure_option..ugly_decimal_point_hack
                      ..blend_colorspace_option
                      .." -o \""..output_image.."\" \"@"..response_file.."\""
      if dtsys.external_command( command) > 0 then
        dt.print(_("enfuse failed, see terminal output for details"))
        os.remove(response_file)
        return
      end

      -- remove the response file
      os.remove(response_file)

      -- import resulting tiff
      local image = dt.database.import(output_image)

      -- tell the user that everything worked
      dt.print(_("enfuse was successful, resulting image has been imported"))
      -- normally printing to stdout is bad, but we allow enfuse to show its output, so adding one extra line is ok
      print(string.format(_("enfuse: done, resulting image '%s' has been imported with id %d"), output_image, image.id))
    end
  }

  local lib_widgets = {}

  if not enfuse_installed then
    table.insert(enf.lib_widgets, df.executable_path_widget({"ffmpeg"}))
  end
  table.insert(enf.lib_widgets, exposure_mu)
  table.insert(enf.lib_widgets, depth)
  table.insert(enf.lib_widgets, blend_colorspace)
  table.insert(enf.lib_widgets, enfuse_button)

   
  -- ... and tell dt about it all
  if dt.gui.current_view().id == "lighttable" then
    install_module()
  else
    if not enf.event_registered then
      dt.register_event(
        "enfuse", "view-changed",
        function(event, old_view, new_view)
          if new_view.name == "lighttable" and old_view.name == "darkroom" then
            install_module()
           end
        end
      )
      enf.event_registered = true
    end
  end
else
  dt.print_error("enfuse executable not found")
  error("enfuse executable not found")
  dt.print(_("could not find enfuse executable, not loading enfuse exporter..."))
end

script_data.destroy = destroy
script_data.restart = restart
script_data.destroy_method = "hide"
script_data.show = restart

return script_data
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
