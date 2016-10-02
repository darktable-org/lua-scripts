--[[

    test-dtutils.lua - the start of a testing framework idea....

    copyright (c) 2016 Bill Ferguson

    TODO: Think this out a little better
]]

dt = require "darktable"
require "lib/dtutils"
du = dtutils

print(dtutils)
print(du)

dt.print_error("Testing lib/dtutils")

local pathstr = "/home/user/src/a.file.txt"

-- dtutils.split_filepath

local ans = du.split_filepath(pathstr)
if ans['path'] == "/home/user/src/" and
   ans['filename'] == "a.file.txt" and
   ans['basename'] == "a.file" and
   ans['filetype'] == "txt" then
   dt.print_error("split_filepath: OK")
else
  dt.print_error("split_filepath: Failed")
end

-- dtutils.get_path

local p = du.get_path(pathstr)
if p == "/home/user/src/" then
  dt.print_error("get_path: OK")
else
  dt.print_error("get_path: Failed")
end

-- dtutils.get_filename

p = du.get_filename(pathstr)
if p == "a.file.txt" then
  dt.print_error("get_filename: OK")
else
  dt.print_error("get_filename: Failed")
end

-- dtutils.get_basename

p = du.get_basename(pathstr)
if p == "a.file" then
  dt.print_error("get_basename: OK")
else
  dt.print_error("get_basename: Failed")
end

-- dtutils.get_filetype

p = du.get_filetype(pathstr)
if p == "txt" then
  dt.print_error("get_filetype: OK")
else
  dt.print_error("get_filetype: Failed")
end

-- checkIfBinExists

local a = dtutils.checkIfBinExists("cp")
local b = dtutils.checkIfBinExists("boguscp")
if a and not b then
  dt.print_error("checkIfBinExists: OK")
else
  dt.print_error("checkIfBinExists: Failed")
end

-- checkIfFileExists

a = du.checkIfFileExists("/tmp")
b = du.checkIfFileExists("/tmp.not")
if a and not b then
  dt.print_error("checkIfFileExists: OK")
else
  dt.print_error("checkIfFileExists: Failed")
end

-- filename_increment

a = du.filename_increment("/home/user/myfile.txt")
b = du.filename_increment("/home/user/myfile_57.txt")
if a == "/home/user/myfile_01.txt" and
   b == "/home/user/myfile_58.txt" then
  dt.print_error("increment_filename: OK")
else
  dt.print_error("increment_filename: Failed")
end

-- groupIfNotMember
  -- need the darktable database to test this....  It might be possible
  dt.print_error("can't test groupIfNotMember. Yet")

-- sanitize_filename

if du.sanitize_filename("/somepath/withaspace/to a file.txt") ==
  "/somepath/withaspace/to\\ a\\ file.txt" then
  dt.print_error("sanitize_filename: OK")
else
  dt.print_error("sanitize_filename: Failed")
end

-- show_status
  -- need the exporter running to test this
  dt.print_error("can't test show_status. Yet")