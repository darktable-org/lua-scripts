--[[
  hugin plugin configuration data

  copyright (c) 2016 Bill Ferguson

]]
return {
  DtPlugins = {
    {
      DtPluginName = "Hugin Panorama",
      DtPluginPreference = "hugin",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License"},
        Name = "Hugin Panorama",
        Usage = [[Activate the plugin.
                Select the images to be used for the panorama
                Select Hugin Panorama from the exporter list
                Adjust the exported image settings to what you desire
                Press Process]],
        License = "GPL Version 2",
      },
      DtVersionRequired = {"2.0.0","3.0.0","4.0.0"},
      DtPluginDataDir = "plugin-data/hugin",
      DtPluginExecutablesRequired = {
        "hugin",
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
      DtPluginMinImages = 2,
      DtPluginProcessorWidget = nil,
      DtPluginActivate = {
        DtPluginRegisterProcessor = "plugins/hugin/hugin_processor_cmd.lua",
      },
      DtPluginDeactivate = {
          DtPluginUnregisterProcessor = nil
      },
    },
  }
}
