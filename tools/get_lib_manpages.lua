--[[
  get_lib_manpages.lua - retrieve the included library documentation and output it as man pages

  Copyright (c) 2016, Bill Ferguson
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local libname = nil

dt.configuration.check_version(...,{3,0,0})

local keys = {"Name", "Synopsis", "Usage", "Description", "Return_Value", "Limitations", 
              "Example", "See_Also", "Reference", "License", "Copyright"}

local function output_man(d)
  local name = d["Name"]
  if not libname then
    libname = name
  end
  local fname = "/tmp/" .. name .. ".3"
  local mf = io.open(fname, "w")
  if mf then
    mf:write(".TH " .. string.upper(name) .. " 3 \"\" \"\" \"Darktable " .. libname .. " functions\"\n")
    for _,section in ipairs(keys) do
      if d[section]:len() > 0 then
        mf:write(".SH " .. string.upper(string.gsub(section, "_", " ")) .. "\n")
        mf:write(d[section] .. "\n")
      end
    end
    mf:close()
    if df.check_if_bin_exists("groff") then
      if df.check_if_bin_exists("ps2pdf") then
        os.execute("groff -man " .. fname .. " | ps2pdf - " .. fname .. ".pdf")
      else
        log.msg(log.error, "Missing ps2pdf.  Can't generate pdf man pages.")
      end
    else
      log.msg(log.error, "Missing groff.  Can't generate pdf man pages.")
    end
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

