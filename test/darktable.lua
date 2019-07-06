darktable = {
  personality = nil
}
darktable.configuration = {}
darktable.personalities = {
  windows = {
    tmp_dir = "C:\\windows\\temp",
    running_os = "windows",
  },
  linux = {
    tmp_dir = "/tmp",
    running_os = "linux"
  },
  macos = {
    tmp_dir = "/tmp",
    running_os = "macos"
  }
}
darktable.gettext = {}
function darktable.gettext.bindtextdomain(...)
  return
end

function darktable.gettext.dgettext(file, msgid)
  return msgid
end

darktable.preferences = {}

function darktable.preferences.read(modname, varname,  datatype)
  return(darktable.preferences[modname][varname][datatype] or nil)
end

function darktable.preferences.write(modname, varname, datatype, value)
  if not darktable.preferences[modname] then
    darktable.preferences[modname] = {}
  end
  if not darktable.preferences[modname][varname] then
    darktable.preferences[modname][varname] = {}
  end
  darktable.preferences[modname][varname][datatype] = value
  return
end

darktable.control = {}

function darktable.control.execute()
  return
end

package.path = package.path .. ";../?.lua"

function darktable.set_personality(os_name)
  darktable.personality = os_name
  for k,y in pairs(darktable.personalities[os_name]) do
    darktable.configuration[k] = y
  end
end

function darktable.get_personality()
  return darktable.personality
end

function darktable.print_log(str)
  print("LOG " .. str)
end

function darktable.print_error(str)
  print("ERROR: " .. str)
end

function darktable.print(str)
  print("SCREEN: " .. str)
end

return darktable