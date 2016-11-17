--[[
  enfuse plugins configuration data

  copyright (c) 2016 Bill Ferguson

]]
return {
  DtPlugins = {
    {
      DtPluginName = "Enfuse HDR",
      DtPluginPreference = "enfuse_hdr",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Notes"},
        Name = "Enfuse HDR",
        Usage = [[Activate the plugin
                select the bracketed images to use for the hdr
                adjust exposure-mu to change the brightness of the output image
                select bit depth of the output image
                if align_image_stack is installed, an option to align the images is
                 available.  Unless you shot your images from a rock steady tripod you
                 should probably select this. 
                choose the format and bit depth of the export
                Press Process
                the resulting tif image will be imported.  The filename will consist of the\n
                  individual filenames combined with hdr, i.e. 7D_1234-7D_1235-7D_1236-hdr.tif]],
        License = "GPL Version 2",
        Notes = [[You might want to specify a smaller size, jpg, and 8 bit output to test
                the hdr output until you find the right combination, then export at full
                resolution with the desired format and depth.]]
      },
      DtVersionRequired = {"3.0.0","4.0.0"},
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
      DtPluginMinImages = 2,
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
        Usage = [[Activate the plugin.
                select the focus stack images that need to be combined
                select bit depth of the output image
                if align_image_stack is installed, an option to align the images is
                  available.  Unless you shot your images from a rock steady tripod you
                  should probably select this.
                choose the format and bit depth of the export
                Press Export
                the resulting tif image will be imported.  The filename will consist of the
                  first and last filenames combined with stack, i.e. 7D_1234-7D_1236-stack.tif
                gray projector, contrast window size, and contrast edge scale can be adjusted
                  to fine tune the output as explained in Pat David's blog post
                  http://blog.patdavid.net/2013/01/focus-stacking-macro-photos-enfuse.html]],
        License = "GPL Version 2",
        Notes = [[You might want to specify a smaller size, jpg, and 8 bit to test
                the stack output until you find the right combination, then export at full
                resolution with the desired format and depth]],
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
      DtPluginMinImages = 2,
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
