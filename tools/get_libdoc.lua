--[[
  get_libdoc.lua - retrieve the included library documentation and output it

  Copyright (c) 2016, Bill Ferguson
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local dtsys = require "lib/dtutils.system"

du.check_min_api_version("3.0.0", "get_libdoc") 

local gettext = dt.gettext.gettext

local function _(msg)
    return gettext(msg)
end

local function destroy()
  -- nothing to destroy
end

local keys = {"Name", "Synopsis", "Usage", "Description", "Return_Value", "Limitations", 
              "Example", "See_Also", "Reference", "License", "Copyright"}

local function output_doc(d)
  for _,section in ipairs(keys) do
    if d[section]:len() > 0 then
      print(string.upper(string.gsub(section, "_", " ")))
      print("\t" .. d[section] .. "\n")
    end
  end
  print("\f")
end

-- find the libraries

local output = io.popen("cd "..dt.configuration.config_dir.."/lua/lib ;find . -name \\*.lua -print | sort")

-- loop through the libraries

for line in output:lines() do
  line = string.gsub(line, "/", ".")
  local lib_name = line:sub(3,-5)
  if lib_name:len() > 2 then
    lib_name = "lib/" .. lib_name
    local lib = require(lib_name)

    -- print the documentation for the library
    if lib.libdoc then
      local doc = lib.libdoc
      output_doc(doc)
      for _,fdoc in pairs(doc.functions) do

        -- print the documentation for each of the functions
        output_doc(fdoc)
      end
    end
  end
end

local script_data = {}

script_data.metadata = {
  name = _("get library docs"),
  purpose = _("retrieve and print the documentation to the console"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/tools/get_libdoc"
}

script_data.destroy = destroy

return script_data
