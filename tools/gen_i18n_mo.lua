--[[
    gen_18n_mo.lua - generate .mo files from .po files and put them in the correct place

    Copyright (C) 2016,2018 Bill Ferguson <wpferguson@gmail.com>

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
--[[
    gen_i18n_mo - generate translation files from the source and place them in the appropriate locale directory
    
    gen_i18n_mo finds all the .po files scattered throughout the script tree, compiles them into
    .mo files and places them in the correct locale directory for use by the gettext tools.

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"

du.check_min_api_version("5.0.0", "gen_I18n_mo")

local function destroy()
  -- nothing to destroy
end

-- figure out the path separator

local PS = dt.configuration.running_os == "windows" and "\\" or "/"

local LUA_DIR = dt.configuration.config_dir .. PS .. "lua" .. PS
local LOCALE_DIR = dt.configuration.config_dir .. PS .. "lua" .. PS .. "locale" .. PS

-- check if we have msgfmt

local msgfmt_executable = df.check_if_bin_exists("msgfmt")

if msgfmt_executable then

  -- find the .po files

  local find_cmd = "find -L " .. LUA_DIR .. " -name \\*.po -print"
  if dt.configuration.running_os == "windows" then
    find_cmd = "dir /b/s " .. LUA_DIR .. "\\*.po"
  end

  local output = io.popen(find_cmd)

  -- for each .po file....

  for line in output:lines() do
    local fname = df.get_filename(line)

    -- get the language used...  this depends on the file being named using
    -- the convention /..../lang/LC_MESSAGES/file.po where lang is de_DE, fr_FR, etc.

    local path_parts = du.split(line, PS)
    local lang  = path_parts[#path_parts - 2]

    -- ensure there is a destination directory for them

    local mkdir_cmd = "mkdir -p "
    if dt.configuration.running_os == "windows" then
      mkdir_cmd = "mkdir "
    end

    if not df.check_if_file_exists(LOCALE_DIR .. lang .. PS .. "LC_MESSAGES") then
      log.msg(log.info, "Creating locale", lang)
      os.execute(mkdir_cmd .. LOCALE_DIR .. lang .. PS .. "LC_MESSAGES")
    end

    -- generate the mo file

    fname = string.gsub(fname, ".po$", ".mo")
    log.msg(log.info, "Compiling translation to", fname)
    local result = os.execute(msgfmt_executable .. " -o " .. LOCALE_DIR .. lang .. PS .. "LC_MESSAGES" .. PS .. fname .. " " .. line)
  end
else
  log.msg(log.screen, "ERROR: msgfmt executable not found.  Please install or specifiy location in preferences.")
end
dt.preferences.register("executable_paths", "msgfmt",  -- name
  "file", -- type
  'gen_i18n_mo: msgfmt location', -- label
  'Install location of msgfmt. Requires restart to take effect.',  -- tooltip
  "msgfmt",  -- default
  dt.new_widget("file_chooser_button"){
    title = "Select msgfmt[.exe] file",
    value = "",
    is_directory = false,
  }
)

local script_data = {}
script_data.destroy = destroy

return script_data
