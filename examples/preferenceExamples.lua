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
dt.configuration.check_version(...,{2,0,1},{3,0,0},{4,0,0},{5,0,0})

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesString",  -- name
                        "string",                     -- type
                        "Example String",            -- label
                        "Example String Tooltip",    -- tooltip
                        "String")                     -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesString",  -- name
                        "bool",                       -- type
                        "Example Boolean",           -- label
                        "Example Boolean Tooltip",   -- tooltip
                        true)                         -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesString",  -- name
                        "integer",                    -- type
                        "Example Integer",           -- label
                        "Example Integer Tooltip",   -- tooltip
                        2,                            -- default
                        1,                            -- min
                        99)                           -- max

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesString",  -- name
                        "float",                      -- type
                        "Example Float",             -- label
                        "Example Float Tooltip",     -- tooltip
                        1.3,                          -- default
                        1,                            -- min
                        99,                           -- max
                        0.5)                          -- step

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "preferenceExamplesString",  -- name
                        "file",                       -- type
                        "Example File",              -- label
                        "Example File Tooltip",      -- tooltip
                        "")                           -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesString",  -- name
                        "directory",                  -- type
                        "Example Directory",         -- label
                        "Example Directory Tooltip", -- tooltip
                        "")                           -- default

dt.preferences.register("preferenceExamples",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "preferenceExamplesString",  -- name
                        "enum",                       -- type
                        "Example Enum",              -- label
                        "Example Enum Tooltip",      -- tooltip
                        "Enum 1",                     -- default
                        "Enum 1", "Enum 2")           -- values

