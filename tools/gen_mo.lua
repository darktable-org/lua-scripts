--[[
  gen_mo.lua - generate .mo files from .po files and put them in the correct place

  Copyright (C) 2016 Bill Ferguson

  gen_mo finds all the .po files scattered throughout the script tree, compiles them into
  .mo files and places them in the correct locale directory for use by the gettext tools.

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/libLog"

local lua_dir = dt.configuration.config_dir .. "/lua/"
local locale_dir = dt.configuration.config_dir .. "/lua/locale/"

-- find the .po files

local output = io.popen("cd "..lua_dir..";find . -name \\*.po -print")

-- for each .po file....

for line in output:lines() do
  local fname = df.get_filename(line)

  -- get the language used...  this depends on the file being named using
  -- the convention /..../lang/LC_MESSAGES/file.po where lang is de_DE, fr_FR, etc.

  local path_parts = du.split(line, "/")
  local lang  = path_parts[#path_parts - 2]

  -- ensure there is a destination directory for them

  if not df.check_if_file_exists(locale_dir .. lang .. "/LC_MESSAGES") then
    log.msg(log.info, "Creating locale", lang)
    os.execute("mkdir -p " .. locale_dir .. lang .. "/LC_MESSAGES")
  end

  -- generate the mo file

  fname = string.gsub(fname, ".po$", ".mo")
  log.msg(log.info, "Compiling translation to", fname)
  local result = os.execute("msgfmt -o " .. locale_dir .. lang .. "/LC_MESSAGES/" .. fname .. " " .. lua_dir .. line)
end