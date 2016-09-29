return {
  DtPlugins = {
    {
      DtPluginName = "Enfuse HDR",
      DtPluginPreference = "enfuse_hdr",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Notes"},
        Name = "Enfuse HDR",
        Usage = "Activate the plugin.\n" ..
                "\tselect the bracketed images to use for the hdr\n" ..
                "\tadjust exposure-mu to change the brightness of the output image\n" ..
                "\tselect bit depth of the output image\n" ..
                "\tif align_image_stack is installed, an option to align the images is\n" ..
                "\t available.  Unless you shot your images from a rock steady tripod you \n" ..
                "\t should probably select this. \n" ..
                "\tchoose the format and bit depth of the export\n" ..
                "\tPress Process\n" ..
                "\tthe resulting tif image will be imported.  The filename will consist of the\n" ..
                "\t  individual filenames combined with hdr, i.e. 7D_1234-7D_1235-7D_1236-hdr.tif\n",
        License = "GPL Version 2",
        Notes = "You might want to specify a smaller size, jpg, and 8 bit output to test\n" ..
                "\tthe hdr output until you find the right combination, then export at full\n" ..
                "\tresolution with the desired format and depth."
      },
      DtVersionRequired = {"3.0.0"},
      DtPluginDataDir = nil,
      DtPluginExecutablesRequired = {
        "enfuse",
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
      DtPluginProcessorWidget = "plugins/enfuse/enfuse_hdr_widget.lua",
      DtPluginActivate = {
        DtPluginRegisterProcessor = "plugins/enfuse/enfuse_hdr_processor_cmd.lua",
      },
      DtPluginDeactivate = {
          DtPluginUnregisterProcessor = nil
      },
    },
    {
      DtPluginName = "Enfuse Focus Stack",
      DtPluginPreference = "enfuse_focus_stack",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Notes"},
        Name = "Enfuse Focus Stack",
        Usage = "Activate the plugin.\n" ..
                "\tselect the focus stack images that need to be combined\n" ..
                "\tselect bit depth of the output image\n" ..
                "\tif align_image_stack is installed, an option to align the images is\n" ..
                "\t  available.  Unless you shot your images from a rock steady tripod you\n" ..
                "\t  should probably select this.\n" ..
                "\tchoose the format and bit depth of the export\n" ..
                "\tPress Export\n" ..
                "\tthe resulting tif image will be imported.  The filename will consist of the\n" ..
                "\t  first and last filenames combined with stack, i.e. 7D_1234-7D_1236-stack.tif\n" ..
                "\tgray projector, contrast window size, and contrast edge scale can be adjusted\n" ..
                "\t  to fine tune the output as explained in Pat David's blog post\n" ..
                "\t  http://blog.patdavid.net/2013/01/focus-stacking-macro-photos-enfuse.html\n",
        License = "GPL Version 2",
        Notes = "You might want to specify a smaller size, jpg, and 8 bit to test\n" ..
                "\tthe stack output until you find the right combination, then export at full\n" ..
                "\tresolution with the desired format and depth.",
      },
      DtVersionRequired = {"3.0.0"},
      DtPluginDataDir = nil,
      DtPluginExecutablesRequired = {
        "enfuse",
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
      DtPluginProcessorWidget = "plugins/enfuse/enfuse_focus_stack_widget.lua",
      DtPluginActivate = {
        DtPluginRegisterProcessor = "plugins/enfuse/enfuse_focus_stack_processor_cmd.lua",
      },
      DtPluginDeactivate = {
          DtPluginUnregisterProcessor = nil
      },
    },
  }
}
