--[[
    This file is part of darktable,
    Copyright 2016 by Tobias Jakobs.

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
darktable script to show how translations works

To create the .po file run:
xgettext -l lua gettextExample.lua

xgettext is not a lua tool, it knows (almost) nothing about Lua, and not 
enough to do a proper parsing. It takes a text file (In our case a Lua 
file) and recognises a few (language dependant) keyword in there.
It matches those keywords with internal description on how functions are 
called and creates the .po file accordingly. (For example, it knows that 
the first argument of gettext() is the translated string, but that it's 
the second argument for dgettext)
This is important because it means that if you use some neat Lua tricks
(like renaming functions) xgettext won't recognize those calls and won't 
extract the string to the .po file.
So, this is why we create a local variagle gettext = dt.gettext, so 
xgettext recognises gettext.gettext as a function but not dt.gettext.gettext

To create a .mo file run:
msgfmt -v gettextExample.po -o gettextExample.mo

USAGE
* require this script from your main lua file (Add 'require "gettextExample"' to luarc.)
* copy the script to: .config/darktable/lua/
* copy the gettextExample.mo to .config/darktable/lua/de_DE/LC_MESSAGES

You need to start darktable with the Lua debug option: darktable -d lua
$LANG must set to: de_DE

The script run on darktable startup and should output this three lines:

LUA ERROR Hello World!
LUA ERROR Bild
LUA ERROR Hallo Welt!

]] 
local dt = require "darktable"
dt.configuration.check_version(...,{3,0,0})

-- Not translated Text
dt.print_error("Hello World!")

local gettext = dt.gettext
-- Translate a string using the darktable textdomain
dt.print_error(gettext.gettext("image"))

-- Tell gettext where to find the .mo file translating messages for a particular domain
-- Translate a string using the specified textdomain
dt.print_error(gettext.dgettext("gettextExample", 'Hello World!'))
