--[[
  clear_GPS plugin configuration data

  copyright (c) 2016 Bill Ferguson

]]

return {
  DtPlugins = {
    {
      DtPluginName = "clear GPS data",
      DtPluginPreference = "clear_GPS_data",
      DtPluginDoc = {
        Sections = {"Name", "Usage", "License", "Contact"},
        Name = "clear GPS data",
        Usage = [[Activate the shortcut and/or action
                Select the images with GPS data that needs removed
                Use the shortcut or click the action to remove GPS data]],
        License = "GPL Version 2",
        Contact = "Bill Ferguson <wpferguson@gmail.com>"
      },
      DtVersionRequired = {"3.0.0"},
      DtPluginDataDir = nil,
      DtPluginIsA = {
        processor = false,
        shortcut = true,
        action = true,
        storage = false,
        lib = false,
      },
      DtPluginActivate = {
        DtPluginRegisterShortcut = "plugins/clear_GPS/clear_GPS_shortcut.lua",
        DtPluginRegisterAction = "plugins/clear_GPS/clear_GPS_action.lua",
      },
      DtPluginDeactivate = {
        DtPluginUnregisterShortcut = nil,
        DtPluginUnregisterAction = nil,
      },
    },
  }
}
