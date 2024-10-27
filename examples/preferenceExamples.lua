--[[
    This file is part of darktable,
    Copyright 2014 by Tobias Jakobs.

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
darktable script to show the different preference types that are possible with Lua

USAGE
* require this script from your main lua file
]] 
local dt = require "darktable"
local du = require "lib/dtutils"

-- translation facilities

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

local script_data = {}

script_data.metadata = {
  name = _("preference examples"),
  purpose = _("example to show the different preference types that are possible"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/preferenceExamples"
}

du.check_min_api_version("2.0.1", "preferenceExamples") 


dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesString",  -- name
                        "string",                     -- type
                        _("example") .. " string",            -- label
                        _("example") .. " string " .. _("tooltip"),    -- tooltip
                        "String")                     -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesBool",  -- name
                        "bool",                       -- type
                        _("example") .. " boolean",           -- label
                        _("example") .. " boolean " .. _("tooltip"),   -- tooltip
                        true)                         -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesInteger",  -- name
                        "integer",                    -- type
                        _("example") .. " integer",           -- label
                        _("example") .. " integer " .. _("tooltip"),   -- tooltip
                        2,                            -- default
                        1,                            -- min
                        99)                           -- max

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesFloat",  -- name
                        "float",                      -- type
                        _("example") .. " float",             -- label
                        _("example") .. " float " .. _("tooltip"),     -- tooltip
                        1.3,                          -- default
                        1,                            -- min
                        99,                           -- max
                        0.5)                          -- step

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesFile",  -- name
                        "file",                       -- type
                        _("example") .. " file",              -- label
                        _("example") .. " file " .. _("tooltip"),      -- tooltip
                        "")                           -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesDirectory",  -- name
                        "directory",                  -- type
                        _("example") .. " directory",         -- label
                        _("example") .. " directory " .. _("tooltip"), -- tooltip
                        "")                           -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesEnum",  -- name
                        "enum",                       -- type
                        _("example") .. " enum",              -- label
                        _("example") .. " enum " .. _("tooltip"),      -- tooltip
                        "Enum 1",                     -- default
                        "Enum 1", "Enum 2")           -- values


local function destroy()
  -- nothing to destroy
end

script_data.destroy = destroy

return script_data
