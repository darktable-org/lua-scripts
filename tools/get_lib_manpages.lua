--[[
    get_lib_manpages.lua - retrieve the included library documentation and output it as man and pdf pages

    Copyright (c) 2016, 2018, Bill Ferguson <wpferguson@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local libname = nil
local dt_doc_dir = dt.configuration.config_dir .. "/lua/doc/"
local dt_man_dir = dt_doc_dir .. "man/3/"
local dt_pdf_dir = dt_doc_dir .. "pdf/3/"
local dt_man_dir_cat = dt_man_dir
local dt_pdf_dir_cat = dt_pdf_dir

dt.configuration.check_version(...,{5,0,0})

if du.check_os({"linux"}) then

  local keys = {"Name", "Synopsis", "Usage", "Description", "Return_Value", "Limitations", 
                "Example", "See_Also", "Reference", "License", "Copyright"}

  local function output_man(d)
    local name = d["Name"]
    if not libname then
      libname = name
    end
    local fname = dt_man_dir_cat .. name .. ".3"
    local pdfname = dt_pdf_dir_cat .. name .. ".3"
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
          os.execute("groff -man " .. fname .. " | ps2pdf - " .. pdfname .. ".pdf")
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

  if not df.check_if_file_exists(dt_man_dir) then
    dt.print_log("creating " .. dt_man_dir)
    os.execute("mkdir -p " .. dt_man_dir)
  end

  if not df.check_if_file_exists(dt_pdf_dir) then
    dt.print_log("creating " .. dt_man_dir)
    os.execute("mkdir -p " .. dt_pdf_dir)
  end

  -- loop through the libraries

  for line in output:lines() do
    line = string.gsub(line, "/", ".")
    local lib_name = line:sub(3,-5)
    if lib_name:len() > 2 then
      local cat = string.match(lib_name, ".+%.(.+)")
      if not cat then
        cat = lib_name
      end
      lib_name = "lib/" .. lib_name
      local lib = require(lib_name)

      -- print the documentation for the library
      if lib.libdoc then
        local doc = lib.libdoc
        if doc then
          dt_man_dir_cat = dt_man_dir
          dt_pdf_dir_cat = dt_pdf_dir
          output_man(doc)
          for _,fdoc in pairs(doc.functions) do
            dt_pdf_dir_cat = dt_pdf_dir .. cat .. "/"
            if not df.check_if_file_exists(dt_pdf_dir_cat) then
              os.execute("mkdir -p " .. dt_pdf_dir_cat)
            end
            dt_man_dir_cat = dt_man_dir .. cat .. "/"
            if not df.check_if_file_exists(dt_man_dir_cat) then
              os.execute("mkdir -p " .. dt_man_dir_cat)
            end

            -- print the documentation for each of the functions
            output_man(fdoc)
          end
        end
      end
    end
    libname = nil
  end
else
  dt.print("get_lib_manpages doesn't work on " .. dt.configuration.running_os)
end
