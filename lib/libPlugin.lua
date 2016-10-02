--[[
  This file is part of darktable,
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

libPlugin = {}

local dt = require "darktable"
local log = require "lib/libLog"

require "lib/dtutils"

-- put the plugin_manager widgets here to prevent namespace pollution

libPlugin.placeholder = dt.new_widget("separator"){}

-- format options container
-- TODO: read the value from saved preferences 

libPlugin.jpeg_slider = dt.new_widget("slider"){
  label = "quality",
  sensitive = true,
  soft_min = 5,      -- The soft minimum value for the slider, the slider can't go beyond this point
  soft_max = 100,     -- The soft maximum value for the slider, the slider can't go beyond this point
  hard_min = 5,       -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
  hard_max = 100,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
  value = 90          -- The current value of the slider
}

-- TODO: read the value from saved preferences 

libPlugin.png_bit_depth = dt.new_widget("combobox"){
  label = "bit depth",
  value = 1, 8, 16,
}

-- TODO: read the value from saved preferences 

libPlugin.tif_bit_depth = dt.new_widget("combobox"){
  label = "bit depth",
  value = 1, 8, 16, 32,
}

-- TODO: read the value from saved preferences 

libPlugin.tif_compression = dt.new_widget("combobox"){
  label = "compression",
  value = 1, "uncompressed", "deflate", "deflate with predictor", "deflate with predictor (float)",
}

libPlugin.tif_widget = dt.new_widget("box"){
  orientation = "vertical",
  libPlugin.tif_bit_depth,
  libPlugin.tif_compression,
}

-- TODO: read the value from saved preferences 
-- TODO: add more formats

libPlugin.format_combobox = dt.new_widget("combobox"){
  label = "file format",
  value = 1, "JPEG (8-bit)", "PNG (8/16-bit)", "TIFF (8/16/32-bit)",
  changed_callback = function(self)
    log.msg(log.debug, "value is " .. self.value)
    if string.match(self.value, "JPEG") then
      -- set visible widget to non visible
      -- set jpeg_slider to visible
      log.msg(log.debug, "took JPEG")
      libPlugin.format[4] = nil
      libPlugin.format[4] = libPlugin.jpeg_slider
    elseif string.match(self.value, "PNG") then
      log.msg(log.debug, "took PNG")
      libPlugin.format[4] = nil
      libPlugin.format[4] = libPlugin.png_bit_depth

      -- set png option to true
    elseif string.match(self.value, "TIFF") then
      log.msg(log.debug, "took TIFF")
      libPlugin.format[4] = nil
      libPlugin.format[4] = libPlugin.tif_widget
      -- set tiff option to true
    end
  end
}


libPlugin.format = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("label"){ label = "Format Options" },
  dt.new_widget("separator"){},
  libPlugin.format_combobox,
  libPlugin.jpeg_slider,
}

-- TODO: read the value from saved preferences 

libPlugin.height = dt.new_widget("entry"){
  tooltip = "height",
  text = "0",
}

libPlugin.height_box = dt.new_widget("box"){    -- TODO: refresh processor combobox

  orientation = "horizontal",
  dt.new_widget("label"){ label = "Height" },
  libPlugin.height,
}

-- TODO: read the value from saved preferences 

libPlugin.width = dt.new_widget("entry"){
  tooltip = "width",
  text = "0",
}

libPlugin.width_box = dt.new_widget("box"){
  orientation = "horizontal",
  dt.new_widget("label"){ label = "Width " },
  libPlugin.width,
}

-- TODO: read the value from saved preferences 

libPlugin.upscale = dt.new_widget("combobox"){
  label = "upscale",
  value = 1, "no", "yes",
}

libPlugin.global = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("label"){ label = "Global Options" },
  dt.new_widget("separator"){},
  dt.new_widget("label"){ label = "Max Size" },
  libPlugin.height_box,
  libPlugin.width_box,
  libPlugin.upscale,
}

-- execute button
-- TODO: save the values from the various widgets when process is pressed

libPlugin.button = dt.new_widget("button"){
  label = "Process",
  clicked_callback = function (_)

    -- get the gui parameters
    local export_format = libPlugin.format_combobox.value

    -- build the image table
    local img_table, cnt = libPlugin.build_image_table(dt.gui.action_images, export_format)
    log.msg(log.debug, "image count is " .. cnt)

    -- make sure there is enough images
    if plugins[libPlugin.processor_combobox.value].DtPluginMinImages <= cnt then

      -- export the images
      local success = libPlugin.do_export(img_table, export_format, libPlugin.height.text, libPlugin.width.text, libPlugin.upscale.value)

      -- call the processor
      log.msg(log.debug, processor_cmds[libPlugin.processor_combobox.value])
      processor_cmds[libPlugin.processor_combobox.value](img_table, plugins[libPlugin.processor_combobox.value])
    else
      log.msg(log.error, "Insufficient images selected, " .. plugins[libPlugin.processor_combobox.value].DtPluginMinImages .. " required")
    end
  end
}

--[[
  NAME
    libPlugin.register_processor_lib - build and install the external processor gui

  SYNOPSIS
    result = dtutils.split_filepath(path_string)
      filepath - path and filename

  DESCRIPTION
    split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table

  RETURN VALUE
    result - a table containing the path, filename, basename, and filetype

  ERRORS



]]

function libPlugin.register_processor_lib(name_table)

  log.msg(log.info, "name_table length is ", #name_table)

  -- since we don't know how many processors are going to be present at startup, we just put
  -- a placeholder in the combobox and load the correct values later

  libPlugin.processor_combobox = dt.new_widget("combobox"){
    label = "processor",
    tooltip = "pick a processor",
--    value = 1, unpack(name_table), bug #11184
    value = 1, "placeholder",
    changed_callback = function(_)

      -- reset the processor widget
      libPlugin.processor[4] = nil

      -- set the processor widget to the appropriate one for the selected processor
      libPlugin.processor[4] = processors[libPlugin.processor_combobox.value]

      -- update the export formats to those allowed for the processor
      local supported_formats = libPlugin.get_supported_formats(plugins[libPlugin.processor_combobox.value])
      dtutils.updateComboboxChoices(libPlugin.format_combobox, supported_formats)
    end
  }

  -- load the processor combobox with the activated processors
  -- work around for bug #11184
  dtutils.updateComboboxChoices(libPlugin.processor_combobox, name_table)

  -- processor container

  libPlugin.processor = dt.new_widget("box"){
    orientation = "vertical",
    dt.new_widget("label"){ label = "Processor" },
    dt.new_widget("separator"){},
    libPlugin.processor_combobox,
    processors[processor_names[1]],
  }

  -- stick it all in a container and then register it
  dt.register_lib(
    "Processor",     -- Module name
    "external processing",     -- name
    true,                -- expandable
    false,               -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
    dt.new_widget("box") -- widget
    {
      orientation = "vertical",
      libPlugin.processor,
      libPlugin.format,
      libPlugin.global,
      libPlugin.button,
    },
    nil,-- view_enter
    nil -- view_leave
  )
end

--[[
  NAME
    libPlugin.create_data_dir - create the specified directory to contain artifacts

  SYNOPSIS
    libPlugin.create_data_dir(dir)
      dir - the directory to create

  DESCRIPTION
    create_data_dir creates a directory to hold artifact data produced by the plugin

  RETURN VALUE
    none

  ERRORS



]]

function libPlugin.create_data_dir(dir)
  if not dtutils.checkIfFileExists(dir) then
    os.execute("mkdir -p '" .. dir .. "'")
  end
end

--[[
  NAME
    libPlugin.add_plugin_widget - add an activate/deactivate widget for a plugin

  SYNOPSIS
    libPlugin.add_plugin_widget(req_name, plugin_state)
      req_name - plugin configuration data
      plugin_state - true if plugin is active, otherwise false

  DESCRIPTION
    split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table

  RETURN VALUE
    result - a table containing the path, filename, basename, and filetype

  ERRORS



]]

function libPlugin.add_plugin_widget(req_name, plugin_state)
  local button_text = ""
  if plugin_state then
    button_text = "Deactivate " .. req_name.DtPluginName
  else
    button_text = "Activate " .. req_name.DtPluginName
  end
  plugin_widgets[plugin_widget_cnt] = dt.new_widget("button")
  {
    label = button_text,
    tooltip = libPlugin.get_plugin_doc(req_name),
    clicked_callback = function (self)
      -- split the label into action and target
      local action, target = string.match(self.label, "(.-) (.+)")
      local i = plugins[target]
      -- load the script if it's not loaded
      if action == "Activate" then
        dt.preferences.write("plugin_manager", i.DtPluginPreference, "bool", true)
        dt.print_error("Loading " .. target)
        libPlugin.activate_plugin(i)
        self.label = "Deactivate " .. target
      else
        dt.preferences.write("plugin_manager", i.DtPluginPreference, "bool", false)
        -- ideally we would call a deactivate method provided by the script
        dt.print(target .. " will not be active when darktable is restarted")
        libPlugin.deactivate_plugin(i)
        self.label = "Activate " .. target
      end
    end
  }
  plugin_widget_cnt = plugin_widget_cnt + 1
end

--[[
  NAME
    libPlugin.get_plugin_doc - returns the plugin documentation

  SYNOPSIS
    result = libPlugin.get_plugin_doc(plugin)
      plugin - plugin configuration data

  DESCRIPTION
    get_plugin_doc gets the documentation from the plugin configuration data,
    assembles it, and returns it.  

  RETURN VALUE
    result - the included plugin doc, otherwise a statement that no documentation is available

  ERRORS



]]

-- get the script documentation, with some assumptions

function libPlugin.get_plugin_doc(plugin)
  local description = ""
  for _,section in pairs(plugin.DtPluginDoc.Sections) do
    description = description .. string.upper(section) .. "\n"
    description = description .. "\t" .. plugin.DtPluginDoc[section] .. "\n"
  end
  if description:len() == 0 then
    description = "No description available"
  end
  return description
end

--[[
  NAME
    libPlugin.activate_plugin - add a plugin to the system

  SYNOPSIS
    libPlugin.activate_plugin(plugin_data)
      plugin_data - plugin configuration data

  DESCRIPTION
    activate_plugin adds a plugin to the system so that it can be used

  RETURN VALUE
    none

  ERRORS



]]

function libPlugin.activate_plugin(plugin_data)
  local i = plugin_data
  if i.DtPluginIsA.processor then
    log.msg(log.debug, "in activate plugin adding processor")
    -- add it to the processors table 
    -- add the associated processor widget or placeholder if not
    processors[i.DtPluginName] = i.DtPluginProcessorWidget and dtutils.prequire(dtutils.chop_filetype(i.DtPluginProcessorWidget)) or libPlugin.placeholder
    log.msg(log.debug, i.DtPluginActivate.DtPluginRegisterProcessor)
    log.msg(log.debug, "Processor widget is ", processors[i.DtPluginName])
    processor_cmds[i.DtPluginName] = dtutils.prequire(dtutils.chop_filetype(i.DtPluginActivate.DtPluginRegisterProcessor))
    log.msg(log.debug, "Processor command is ", processor_cmds[i.DtPluginName])
    log.msg(log.debug, "Processor command is a ", type(processor_cmds[i.DtPluginName]))
    processor_names[#processor_names + 1] = i.DtPluginName
    log.msg(log.debug, "Added " .. i.DtPluginName .. " to processor_names")
    table.sort(processor_names)
    if not pmstartup then
      log.msg(log.debug, "after startup...")
      if #processor_names == 1 then
        -- the external processing widget wasn't created because there were no processors
        -- therefore, we need to create it
        log.msg(log.debug, "took ==1 branch")
        libPlugin.register_processor_lib(processor_names)
      else
        log.msg(log.debug, "took push branch")
        dtutils.updateComboboxChoices(libPlugin.processor_combobox, processor_names)
      end
    end
  end
  if i.DtPluginIsA.shortcut then
    libPlugin.start_plugin(i.DtPluginActivate.DtPluginRegisterShortcut)
  end
  if i.DtPluginIsA.action then
    libPlugin.start_plugin(i.DtPluginActivate.DtPluginRegisterAction)
  end
  if i.DtPluginIsA.storage then
    libPlugin.start_plugin(i.DtPluginActivate.DtPluginRegisterStorage)
  end
  if i.DtPluginIsA.lib then
    libPlugin.start_plugin(i.DtPluginActivate.DtPluginRegisterLib)
  end
end

--[[
  NAME
    libPlugin.deactivate_plugin - remove a plugin from the system

  SYNOPSIS
    libPlugin.deactivate_plugin(plugin_data)
      plugin_data - plugin configuration data

  DESCRIPTION
    deactivate_plugin removes a plugin from the system

  RETURN VALUE
    none

  CAVEATS
    This works for any processor that doesn't have a widget associated with it
    such as GIMP, Color Efex Pro 4, Hugin


]]

-- deactivate works for any processor that doesn't have a widget associated with it
-- such as GIMP, Color Efex Pro 4, Hugin

function libPlugin.deactivate_plugin(plugin_data)
  local i = plugin_data

  if i.DtPluginIsA.processor then
    -- set the plugin name to nil to remove it 
    processors[i.DtPluginName] = nil
    processor_cmds[i.DtPluginName] = nil
    for k,v in ipairs(processor_names) do
      if v == i.DtPluginName then
        table.remove(processor_names, k)
        break
      end
    end

    -- sort the remaining processors and reload the combobox
    -- TODO: handle the case where all the processors are dactivated...  oops...
    table.sort(processor_names)
    dtutils.updateComboboxChoices(libPlugin.processor_combobox, processor_names)
  end
  if i.DtPluginIsA.shortcut then
    libPlugin.stop_plugin(i.DtPluginDeactivate.DtPluginUnregisterShortcut)
  end
  if i.DtPluginIsA.action then
    libPlugin.stop_plugin(i.DtPluginDeactivate.DtPluginUnregisterAction)
  end
  if i.DtPluginIsA.storage then
    libPlugin.stop_plugin(i.DtPluginDeactivate.DtPluginUnregisterStorage)
  end
  if i.DtPluginIsA.lib then
    libPlugin.stop_plugin(i.DtPluginDeactivate.DtPluginUnregisterLib)
  end
end

--[[
  NAME
    libPlugin.start_plugin - execute the function to start the processor

  SYNOPSIS
    libPlugin.start_plugin(method)
      method - a function to start the processor

  DESCRIPTION
    start_plugin executes the function to start the processor

  RETURN VALUE
    none

  ERRORS



]]

function libPlugin.start_plugin(method)
  if method then
    dtutils.prequire(dtutils.chop_filetype(method))
  end
end

--[[
  NAME
    libPlugin.stop_plugin - stop a processor plugin

  SYNOPSIS
    libPlugin.stop_plugin(method)
      method - a function to execute that stops the plugin

  DESCRIPTION
    split_filepath splits a filepath into the path, filename, basename and filetype and puts
    that in a table

    this is really a placeholder since I'm not quite sure how to do this yet
    TODO: figure out how to stop a plugin  :D

  RETURN VALUE
    none

  ERRORS



]]

function libPlugin.stop_plugin(method)
  if method then
    dtutils.prequire(dtutils.chop_filetype(method))
  end
end

--[[
  NAME
    libPlugin.check_api_version - check that the processor is compatible with the version of darktable

  SYNOPSIS
    result = libPlugin.check_api_version(ver_table)
      ver_table - an table of acceptable version strings

  DESCRIPTION
    dt.configuration_check causes a fatal error to incompatible scripts.  We need a slightly gentler response
    to prevent crashing the plugin manager.

  RETURN VALUE
    result - true if compatible, otherwise false

  ERRORS



]]

function libPlugin.check_api_version(ver_table)
  local dtversion = tostring(dt.configuration.api_version_major) .. "." ..
                    tostring(dt.configuration.api_version_minor) .. "." ..
                    tostring(dt.configuration.api_version_patch)
  local match = nil
  for _,ver in pairs(ver_table) do
    if ver == dtversion then
      match = true
    end
  end
  return match
end

--[[
  NAME
    libPlugin.build_image_table - build a table of images for the exporter

  SYNOPSIS
    result, count = libPlugin.build_image_table(images, ff)
      images - a table of the selected images (dt.gui.action_images)
      ff - export image format

  DESCRIPTION
    build_image_table creates an export filename for each of the selected images and
    pairs them in a table, which is returned.  The count of images is also returned
    so that it can be used to check if we have sufficient images to run the processor

  RETURN VALUE
    result - a table of dt_lua_image_t, export filepath pairs
    count - the number of images in the table

  ERRORS



]]

-- build the image table

function libPlugin.build_image_table(images, ff)
  local image_table = {}
  local file_extension = ""
  local tmp_dir = dt.configuration.tmp_dir .. "/"
  local cnt = 0

  if string.match(ff, "JPEG") then
    file_extension = ".jpg"
  elseif string.match(ff, "PNG") then
    file_extension = ".png"
  elseif string.match(ff, "TIFF") then
    file_extension = ".tif"
  end

  for _,img in ipairs(images) do
    log.msg(log.info, img.filename, " is ", tmp_dir .. dtutils.get_basename(img.filename) .. file_extension)
    image_table[img] = tmp_dir .. dtutils.get_basename(img.filename) .. file_extension
    cnt = cnt + 1
  end

  return image_table, cnt
end

--[[
  NAME
    libPlugin.do_export - export raw images to the requested format

  SYNOPSIS
    result = libPlugin.do_export(img_tbl, ff, height, width, upscale)
      img_tbl - table of images to be exported, as produced by the exporter or libPlugin.by build_image_table
      ff - format of the exported image
      height - maximum height of export, 0 for original size
      width - maximum width of export, 0 for original size
      upscale - boolean, permit upscaling

  DESCRIPTION
    do_export creates an exporter for the requested format, then populates it with specific and general settings.
    Once the exporter is created and configured, the images in the image table are exported.

  RETURN VALUE
    result - true for success

  ERRORS



]]

function libPlugin.do_export(img_tbl, ff, height, width, upscale)
  local exporter = nil
  local upsize = false

  -- get the export format parameters
  if string.match(ff, "JPEG") then
    exporter = dt.new_format("jpeg")
    log.msg(log.debug, "exporter type is " .. type(exporter))
    exporter.quality = math.floor(dtutils.fixSliderFloat(libPlugin.jpeg_slider.value))
  elseif string.match(ff, "PNG") then
    exporter = dt.new_format("png")
    exporter.bpp = libPlugin.png_bit_depth.value
  elseif string.match(ff, "TIFF") then
    exporter = dt.new_format("tiff")
    exporter.bpp = libPlugin.tif_bit_depth.value
  end
  exporter.max_height = tonumber(height)
  exporter.max_width = tonumber(width)
  upsize = upscale == "yes" and true or false
  -- export the images
  for img,export in pairs(img_tbl) do
    log.msg(log.debug, "Image type is " .. type(img))
    exporter.write_image(exporter, img, export, upsize)
  end
  -- return success, or not
  return true
end

--[[
  NAME
    libPlugin.get_supported_formats - get the processor supported input formats

  SYNOPSIS
    result = libPlugin.get_supported_formats(plugin_data)
      plugin_data - plugin configuration data

  DESCRIPTION
    Read the plugin_data.DtPluginInputFormats and return a table of the supported
    ones

  RETURN VALUE
    result - a table the strings for the format combobox

  ERRORS



]]

function libPlugin.get_supported_formats(plugin_data)
  local formats = {}
  if plugin_data.DtPluginInputFormats.jpg then
    dtutils.push(formats, "JPEG (8-bit)")
  end
  if plugin_data.DtPluginInputFormats.png then
    dtutils.push(formats, "PNG (8/16-bit)")
  end
  if plugin_data.DtPluginInputFormats.tif then
    dtutils.push(formats, "TIFF (8/16/32-bit)")
  end
  return formats
end

return libPlugin