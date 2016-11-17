--[[
  GIMP plugin configuration data

  copyright (c) 2016 Bill Ferguson

]]

return {
  DtPlugins = {
    {
      DtPluginName = "Edit with GIMP",
      DtPluginPreference = "gimp",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Caveats"},
        Name = "Edit with GIMP",
        Usage = [[Activate the plugin.
                select an image or images for editing with GIMP
                in the processor combobox select 'Edit with GIMP'
                select the format and bit depth for the exported image
                Press Process
                Edit the image with GIMP then save the changes with File->Overwrite
                Exit GIMP
                The edited image will be imported and grouped with the original image]],
        License = "GPL Version 2",
        Caveats = "Developed and tested on Ubuntu 14.04 LTS with darktable 2.0.3 and GIMP 2.9.3 (development version with > 8 bit color)\n",
      },
      DtVersionRequired = {"3.0.0", "4.0.0"},
      DtPluginDataDir = "plugin-data/gimp",
      DtPluginExecutablesRequired = {
        "gimp",
      },
      DtPluginIsA = {
        processor = true,
        shortcut = false,
        action = false,
        storage = false,
        lib = false,
      },
      DtPluginInputFormats = {
        raw = false,
        jpg = true,
        png = true,
        tif = true,
      },
      DtPluginMinImages = 1,
      DtPluginProcessorWidget = nil,
      DtPluginActivate = {
        DtPluginRegisterProcessor = "plugins/GIMP/gimp_processor_cmd.lua",
      },
      DtPluginDeactivate = {
          DtPluginUnregisterProcessor = nil
      },
    },
  },
}
