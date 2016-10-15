--[[

    test-dtfileutils.lua - the start of a testing framework idea....

    copyright (c) 2016 Bill Ferguson

    TODO: Think this out a little better
]]

local dt = require "darktable"
local df = require "lib/dtfileutils"

print(dtfileutils)
print(df)

dt.print_error("Testing lib/dtfileutils")

-- checkIfBinExists

local a = dtfileutils.checkIfBinExists("cp")
local b = dtfileutils.checkIfBinExists("boguscp")
if a and not b then
  dt.print_error("checkIfBinExists: OK")
else
  dt.print_error("checkIfBinExists: Failed")
end

local pathstr = "/home/user/src/a.file.txt"

-- dtfileutils.split_filepath

local ans = df.split_filepath(pathstr)
if ans['path'] == "/home/user/src/" and
   ans['filename'] == "a.file.txt" and
   ans['basename'] == "a.file" and
   ans['filetype'] == "txt" then
   dt.print_error("split_filepath: OK")
else
  dt.print_error("split_filepath: Failed")
end

-- dtfileutils.get_path

local p = df.get_path(pathstr)
if p == "/home/user/src/" then
  dt.print_error("get_path: OK")
else
  dt.print_error("get_path: Failed")
end

-- dtfileutils.get_filename

p = df.get_filename(pathstr)
if p == "a.file.txt" then
  dt.print_error("get_filename: OK")
else
  dt.print_error("get_filename: Failed")
end

-- dtfileutils.get_basename

p = df.get_basename(pathstr)
if p == "a.file" then
  dt.print_error("get_basename: OK")
else
  dt.print_error("get_basename: Failed")
end

-- dtfileutils.get_filetype

p = df.get_filetype(pathstr)
if p == "txt" then
  dt.print_error("get_filetype: OK")
else
  dt.print_error("get_filetype: Failed")
end

-- checkIfFileExists

a = df.checkIfFileExists("/tmp")
b = df.checkIfFileExists("/tmp.not")
if a and not b then
  dt.print_error("checkIfFileExists: OK")
else
  dt.print_error("checkIfFileExists: Failed")
end

-- filename_increment

a = df.filename_increment("/home/user/myfile.txt")
b = df.filename_increment("/home/user/myfile_57.txt")
if a == "/home/user/myfile_01.txt" and
   b == "/home/user/myfile_58.txt" then
  dt.print_error("increment_filename: OK")
else
  dt.print_error("increment_filename: Failed")
end

-- sanitize_filename

if df.sanitize_filename("/somepath/withaspace/to a file.txt") ==
  "/somepath/withaspace/to\\ a\\ file.txt" then
  dt.print_error("sanitize_filename: OK")
else
  dt.print_error("sanitize_filename: Failed")
end

-- chop_filetype

if df.chop_filetype(pathstr) == "/home/user/src/a.file" then
  dt.print_error("chop_filetype: OK")
else
  dt.print_error("chop_filetype: Failed")
end

-- fileCopy



-- fileMove

