return {
  DtPlugins = {
    {
      DtPluginName = "Edit with GIMP",
      DtPluginPreference = "gimp",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Caveats"},
        Name = "Edit with GIMP",
        Usage = "Activate the plugin.\n" ..
                "\tselect an image or images for editing with GIMP\n" ..
                "\tin the processor combobox select 'Edit with GIMP'\n" ..
                "\tselect the format and bit depth for the exported image\n" ..
                "\tPress Process\n" ..
                "\tEdit the image with GIMP then save the changes with File->Overwrite\n" ..
                "\tExit GIMP\n" ..
                "\tThe edited image will be imported and grouped with the original image\n",
        License = "GPL Version 2",
        Caveats = "Developed and tested on Ubuntu 14.04 LTS with darktable 2.0.3 and GIMP 2.9.3 (development version with > 8 bit color)\n",
      },
      DtVersionRequired = {"3.0.0"},
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
