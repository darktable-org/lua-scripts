--[[
  get_lib_manpages.lua - retrieve the included library documentation and output it as man pages

  Copyright (c) 2016, Bill Ferguson
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local libname = nil

dt.configuration.check_version(...,{3,0,0})

local function output_man(d)
  local parts = du.split(d[d.Sections[1]], " - ")
  if not libname then
    libname = parts[1]
  end
  local fname = "/tmp/" .. parts[1] .. ".3"
  local mf = io.open(fname, "w")
  if mf then
    mf:write(".TH " .. string.upper(parts[1]) .. " 3 \"\" \"\" \"Darktable " .. libname .. " functions\"\n")
    for _,section in pairs(d.Sections) do
      if d[section] then
        mf:write(".SH " .. string.upper(string.gsub(section, "_", " ")) .. "\n")
        mf:write(d[section] .. "\n")
      end
    end
    mf:close()
    os.execute("groff -man " .. fname .. " | ps2pdf - " .. fname .. ".pdf")
  else
    log.msg(log.error, "Can't open file " .. fname .. "for writing")
  end
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
      if doc then
        output_man(doc)
        for _,fdoc in pairs(doc.functions) do

          -- print the documentation for each of the functions
          output_man(fdoc)
        end
      end
    end
  end
  libname = nil
end

