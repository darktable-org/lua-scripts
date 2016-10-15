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

local libPlugin = {}

libPlugin.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License"},
  Name = [[libPlugin - functions used by plugin_manager and for building plugin scripts]],
  Synopsis = [[local lp = require "lib/libPlugin"]],
  Description = [[libPlugin contains the widgets and routines used by plugin_manager to provide 
    plugin management.  Some of the functions, such as do_export() and build_image_table() may be
    useful in other scripts.]],
  License = [[This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.]],
  functions = {}
}

local dt = require "darktable"
local log = require "lib/libLog"

local dtutils = require "lib/dtutils"
local dtfileutils = require "lib/dtutils.file"

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
    log.msg(log.debug, "libPlugin.format_combobox:", "value is " .. self.value)
    if string.match(self.value, "JPEG") then
      -- set visible widget to non visible
      -- set jpeg_slider to visible
      log.msg(log.debug, "libPlugin.format_combobox:", "took JPEG")
      libPlugin.format[4] = nil
      libPlugin.format[4] = libPlugin.jpeg_slider
    elseif string.match(self.value, "PNG") then
      log.msg(log.debug, "libPlugin.format_combobox:", "took PNG")
      libPlugin.format[4] = nil
      libPlugin.format[4] = libPlugin.png_bit_depth

      -- set png option to true
    elseif string.match(self.value, "TIFF") then
      log.msg(log.debug, "libPlugin.format_combobox:", "took TIFF")
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
    log.msg(log.debug, "libPlugin.button:", "image count is " .. cnt)

    -- make sure there is enough images
    if plugins[libPlugin.processor_combobox.value].DtPluginMinImages <= cnt then

      -- export the images
      local success = libPlugin.do_export(img_table, export_format, libPlugin.height.text, libPlugin.width.text, libPlugin.upscale.value)

      -- call the processor
      log.msg(log.debug,  "libPlugin.button: ",processor_cmds[libPlugin.processor_combobox.value])
      processor_cmds[libPlugin.processor_combobox.value](img_table, plugins[libPlugin.processor_combobox.value])
    else
      log.msg(log.error, "libPlugin.button:", "Insufficient images selected, " .. plugins[libPlugin.processor_combobox.value].DtPluginMinImages .. " required")
    end
  end
}

--[[
  NAME
    register_processor_lib - build and install the external processor gui

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.register_processor_lib(name_table)
      name_table - table - a table of processor names (strings)

  DESCRIPTION
    register_processor_lib registers the lib that creates the lightroom module for
    the external processors.  The name_table passed to the function contains the 
    names of all the processors that are available.  A combobox contains the choices
    or processors.  When a processor is selected, the corresponding widget is displayed
    and the appropriate exporter choices are displayed.  Once all the choices are made,
    pressing the "Process" button causes the image(s) to be exported and the processor 
    started.

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[register_processor_lib - build and install the external processor gui]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.register_processor_lib(name_table)
      name_table - table - a table of processor names (strings)]],
  Description = [[register_processor_lib registers the lib that creates the lightroom module for
    the external processors.  The name_table passed to the function contains the 
    names of all the processors that are available.  A combobox contains the choices
    or processors.  When a processor is selected, the corresponding widget is displayed
    and the appropriate exporter choices are displayed.  Once all the choices are made,
    pressing the "Process" button causes the image(s) to be exported and the processor 
    started.]],
}

function libPlugin.register_processor_lib(name_table)

  log.msg(log.info, "name_table length is ", #name_table)

  -- since we don't know how many processors are going to be present at startup, we just put
  -- a placeholder in the combobox and load the correct values later

  -- TODO: rewrite the callback to use a stack widget and just active the appropriate one

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
      dtutils.update_combobox_choices(libPlugin.format_combobox, supported_formats)
    end
  }

  -- load the processor combobox with the activated processors
  -- work around for bug #11184
  dtutils.update_combobox_choices(libPlugin.processor_combobox, name_table)

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
    create_data_dir - create the specified directory to contain artifacts

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.create_data_dir(dir)
      dir - string - the directory to create

  DESCRIPTION
    create_data_dir creates a directory to hold artifact data produced by the plugin

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[create_data_dir - create the specified directory to contain artifacts]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.create_data_dir(dir)
      dir - string - the directory to create]],
  Description = [[create_data_dir creates a directory to hold artifact data produced by the plugin]],
}

function libPlugin.create_data_dir(dir)
  if not dtfileutils.check_if_file_exists(dir) then
    os.execute("mkdir -p '" .. dir .. "'")
  end
end

--[[
  NAME
    add_plugin_widget - add an activate/deactivate widget for a plugin

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.add_plugin_widget(req_name, plugin_state)
      req_name - table - plugin configuration data
      plugin_state - boolean - true if plugin is active, otherwise false

  DESCRIPTION
    add_plugin_widget creates the plugin activate/deactivate button for
    plugin_manager.

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[add_plugin_widget - add an activate/deactivate widget for a plugin]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.add_plugin_widget(req_name, plugin_state)
      req_name - table - plugin configuration data
      plugin_state - boolean - true if plugin is active, otherwise false]],
  Description = [[add_plugin_widget creates the plugin activate/deactivate button for
    plugin_manager.]],
}

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
    get_plugin_doc - returns the plugin documentation

  SYNOPSIS
    local lp = require "lib/libPlugin"

    local result = lp.get_plugin_doc(plugin)
      plugin - table - plugin configuration data

  DESCRIPTION
    get_plugin_doc gets the documentation from the plugin configuration data,
    assembles it, and returns it.  

  RETURN VALUE
    result - string(s) - the included plugin doc, otherwise a statement that no documentation is available

]]

-- get the script documentation, with some assumptions

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_plugin_doc - returns the plugin documentation]],
  Synopsis = [[local lp = require "lib/libPlugin"
    
    local result = lp.get_plugin_doc(plugin)
      plugin - table - plugin configuration data]],
  Description = [[get_plugin_doc gets the documentation from the plugin configuration data,
    assembles it, and returns it.]],
  Return_Value = [[result - string(s) - the included plugin doc, otherwise a statement that no documentation is available]],
}

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
    activate_plugin - add a plugin to the system

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.activate_plugin(plugin_data)
      plugin_data - table - plugin configuration data

  DESCRIPTION
    activate_plugin adds a plugin to the system so that it can be used

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[activate_plugin - add a plugin to the system]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.activate_plugin(plugin_data)
      plugin_data - table - plugin configuration data]],
  Description = [[activate_plugin adds a plugin to the system so that it can be used]],
}

function libPlugin.activate_plugin(plugin_data)
  local i = plugin_data
  if i.DtPluginIsA.processor then
    log.msg(log.debug, "in activate plugin adding processor")
    -- add it to the processors table 
    -- add the associated processor widget or placeholder if not
    processors[i.DtPluginName] = i.DtPluginProcessorWidget and dtutils.prequire(dtfileutils.chop_filetype(i.DtPluginProcessorWidget)) or libPlugin.placeholder
    log.msg(log.debug, i.DtPluginActivate.DtPluginRegisterProcessor)
    log.msg(log.debug, "Processor widget is ", processors[i.DtPluginName])
    processor_cmds[i.DtPluginName] = dtutils.prequire(dtfileutils.chop_filetype(i.DtPluginActivate.DtPluginRegisterProcessor))
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
        dtutils.update_combobox_choices(libPlugin.processor_combobox, processor_names)
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
    deactivate_plugin - remove a plugin from the system

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.deactivate_plugin(plugin_data)
      plugin_data - table - plugin configuration data

  DESCRIPTION
    deactivate_plugin removes a plugin from the system

  LIMITATIONS
    This works for any processor that doesn't have a widget associated with it
    such as GIMP or Hugin


]]

-- deactivate works for any processor that doesn't have a widget associated with it
-- such as GIMP or Hugin

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Limitations"},
  Name = [[deactivate_plugin - remove a plugin from the system]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.deactivate_plugin(plugin_data)
      plugin_data - table - plugin configuration data]],
  Description = [[deactivate_plugin removes a plugin from the system]],
  Limitations = [[This works for any processor that doesn't have a widget associated with it
    such as GIMP or Hugin]],
}

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
    dtutils.update_combobox_choices(libPlugin.processor_combobox, processor_names)
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
    start_plugin - execute the function to start the processor

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.start_plugin(method)
      method - function - a function to start the processor

  DESCRIPTION
    start_plugin executes the function to start the processor

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[start_plugin - execute the function to start the processor]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.start_plugin(method)
      method - function - a function to start the processor]],
  Description = [[start_plugin executes the function to start the processor]],
}

function libPlugin.start_plugin(method)
  if method then
    dtutils.prequire(dtfileutils.chop_filetype(method))
  end
end

--[[
  NAME
    stop_plugin - stop a processor plugin

  SYNOPSIS
    local lp = require "lib/libPlugin"

    lp.stop_plugin(method)
      method - function - a function to execute that stops the plugin

  DESCRIPTION
    this is really a placeholder since I'm not quite sure how to do this yet
    TODO: figure out how to stop a plugin  :D

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[stop_plugin - stop a processor plugin]],
  Synopsis = [[local lp = require "lib/libPlugin"

    lp.stop_plugin(method)
      method - function - a function to execute that stops the plugin]],
  Description = [[this is really a placeholder since I'm not quite sure how to do this yet
    TODO: figure out how to stop a plugin  :D]],
}

function libPlugin.stop_plugin(method)
  if method then
    dtutils.prequire(dtfileutils.chop_filetype(method))
  end
end

--[[
  NAME
    check_api_version - check that the processor is compatible with the version of darktable

  SYNOPSIS
    local lp = require "lib/libPlugin"

    result = lp.check_api_version(ver_table)
      ver_table - table - a table of acceptable version strings

  DESCRIPTION
    dt.configuration_check causes a fatal error to incompatible scripts.  We need a slightly gentler response
    to prevent crashing the plugin manager.

  RETURN VALUE
    result - true if compatible, otherwise false

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[check_api_version - check that the processor is compatible with the version of darktable]],
  Synopsis = [[local lp = require "lib/libPlugin"

    result = lp.check_api_version(ver_table)
      ver_table - table - a table of acceptable version strings]],
  Description = [[dt.configuration_check causes a fatal error to incompatible scripts.  We need a slightly gentler response
    to prevent crashing the plugin manager.]],
  Return_Value = [[result - true if compatible, otherwise false]],
}

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
    build_image_table - build a table of images for the exporter

  SYNOPSIS
    local lp = require "lib/libPlugin"

    result, count = lp.build_image_table(images, ff)
      images - table - a table of the selected images (dt.gui.action_images)
      ff - export image format

  DESCRIPTION
    build_image_table creates an export filename for each of the selected images and
    pairs them in a table, which is returned.  The count of images is also returned
    so that it can be used to check if we have sufficient images to run the processor

  RETURN VALUE
    result - a table of dt_lua_image_t, export filepath pairs
    count - the number of images in the table

]]

-- build the image table

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[build_image_table - build a table of images for the exporter]],
  Synopsis = [[local lp = require "lib/libPlugin"

    result, count = lp.build_image_table(images, ff)
      images - table - a table of the selected images (dt.gui.action_images)
      ff - export image format]],
  Description = [[build_image_table creates an export filename for each of the selected images and
    pairs them in a table, which is returned.  The count of images is also returned
    so that it can be used to check if we have sufficient images to run the processor]],
  Return_Value = [[result - a table of dt_lua_image_t, export filepath pairs
    count - the number of images in the table]],
}

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
    log.msg(log.info, img.filename, " is ", tmp_dir .. dtfileutils.get_basename(img.filename) .. file_extension)
    image_table[img] = tmp_dir .. dtfileutils.get_basename(img.filename) .. file_extension
    cnt = cnt + 1
  end

  return image_table, cnt
end

--[[
  NAME
    do_export - export raw images to the requested format

  SYNOPSIS
    local lp = require "lib/libPlugin"

    local result = lp.do_export(img_tbl, ff, height, width, upscale)
      img_tbl - table - table of images to be exported, as produced by the exporter or libPlugin.build_image_table
      ff - string - format of the exported image
      height - number - maximum height of export, 0 for original size
      width - number - maximum width of export, 0 for original size
      upscale - boolean - permit upscaling

  DESCRIPTION
    do_export creates an exporter for the requested format, then populates it with specific and general settings.
    Once the exporter is created and configured, the images in the image table are exported.

  RETURN VALUE
    result - true for success

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[do_export - export raw images to the requested format]],
  Synopsis = [[local lp = require "lib/libPlugin"

    local result = lp.do_export(img_tbl, ff, height, width, upscale)
      img_tbl - table - table of images to be exported, as produced by the exporter or libPlugin.build_image_table
      ff - string - format of the exported image
      height - number - maximum height of export, 0 for original size
      width - number - maximum width of export, 0 for original size
      upscale - boolean - permit upscaling]],
  Description = [[do_export creates an exporter for the requested format, then populates it with specific and general settings.
    Once the exporter is created and configured, the images in the image table are exported.]],
  Return_Value = [[result - true for success]],
}

function libPlugin.do_export(img_tbl, ff, height, width, upscale)
  local exporter = nil
  local upsize = false

  -- get the export format parameters
  if string.match(ff, "JPEG") then
    exporter = dt.new_format("jpeg")
    log.msg(log.debug, "exporter type is " .. type(exporter))
    exporter.quality = math.floor(libPlugin.jpeg_slider.value)
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
    get_supported_formats - get the processor supported input formats

  SYNOPSIS
    local lp = require "lib/libPlugin"

    local result = lp.get_supported_formats(plugin_data)
      plugin_data - table - plugin configuration data

  DESCRIPTION
    Read the plugin_data.DtPluginInputFormats and return a table of the supported
    ones

  RETURN VALUE
    result - table - a table the strings for the format combobox

]]

libPlugin.libdoc.functions[#libPlugin.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[get_supported_formats - get the processor supported input formats]],
  Synopsis = [[local lp = require "lib/libPlugin"

    local result = lp.get_supported_formats(plugin_data)
      plugin_data - table - plugin configuration data]],
  Description = [[Read the plugin_data.DtPluginInputFormats and return a table of the supported
    ones]],
  Return_Value = [[result - table - a table the strings for the format combobox]],
}

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
