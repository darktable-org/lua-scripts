--[[
This file is part of darktable,
copyright (c) 2014 Jérémy Rosen

darktable is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

darktable is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
DEBUG HELPERS
A collection of helper functions to help debugging lua scripts.

require it as

dhelpers = require "official/debug-helpers"

Each function is documented in its own header


]]


local dt = require "darktable"
local io = require "io"
local table = require "table"
require "darktable.debug"
local log = require "lib/libLog"
local M = {} -- The actual content of the module

M.libdoc = {
  Sections = {"Name", "Synopsis", "Description", "License"},
  Name = [[dtutils.debug - debugging helpers used in developing darktable lua scripts]],
  Synopsis = [[local dd = require "lib/dtutils.debug"]],
  Description = [[dtutils.debug provides an interface to the darktable debugging routines.]],
  License = [[This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.]],
  functions = {}
}

--[[
  NAME
    tracepoint - print out a tracepoint and dump the arguments

  SYNOPSIS
    local dd = require "lib/dtutils.debug"

    local result = tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of

  DESCRIPTION
    tracepoint prints its name and dumps its parameters using
    dt.debug

  RETURN VALUE
    result - ... - the supplied argument list

]]

M.libdoc.functions[#M.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value"},
  Name = [[tracepoint - print out a tracepoint and dump the arguments]],
  Synopsis = [[local dd = require "lib/dtutils.debug"

    local result = tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of]],
  Description = [[tracepoint prints its name and dumps its parameters using
    dt.debug]],
  Return_Value = [[result - ... - the supplied argument list]],
}

function M.tracepoint(name,...)
  log.always(4, "*****  "..name.." ****")
  params = {...}
  print(dt.debug.dump(params,"parameters"))
  return ...;
end



--[[
  NAME
    new_tracepoint - create a function returning a tracepoint

  SYNOPSIS
    local dd = require "lib/dtutils.debug"

    local result = new_tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of


  DESCRIPTION
    A function that returns a tracepoint function with the given name
    This is mainly used to debug callbacks.

  RETURN VALUE
    result - function - a function that returns the result of a tracepoint

  EXAMPLE
    register_event(event, dd.new_tracepoint("hit callback"))

    will print the following each time the callback is called

    **** hit callback ****
    <all the callback's parameters dumped>

]]

M.libdoc.functions[#M.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description", "Return_Value", "Example"},
  Name = [[new_tracepoint - create a function returning a tracepoint]],
  Synopsis = [[local dd = require "lib/dtutils.debug"

    local result = new_tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of]],
  Description = [[A function that returns a tracepoint function with the given name
    This is mainly used to debug callbacks.]],
  Return_Value = [[result - function - a function that returns the result of a tracepoint]],
  Example = [[register_event(event, dd.new_tracepoint("hit callback"))

    will print the following each time the callback is called

    **** hit callback ****
    <all the callback's parameters dumped>]],
}

function M.new_tracepoint(name) 
  return function(...) return M.tracepoint(name,...) end
end


--[[
  NAME
    dprint - pass a variable to dt.debug.dump and print the results to stdout

  SYNOPSIS
    local dd = require "lib/dtutils.debug"

    dd.dprint(var)
      var - variable - any variable that you want to see the contents of

  DESCRIPTION
    Wrapper around debug.dump, will directly print to stdout,
    same calling convention
    
]]

M.libdoc.functions[#M.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[dprint - pass a variable to dt.debug.dump and print the results to stdout]],
  Synopsis = [[local dd = require "lib/dtutils.debug"

    dd.dprint(var)
      var - variable - any variable that you want to see the contents of]],
  Description = [[Wrapper around debug.dump, will directly print to stdout,
    same calling convention]],
}

function M.dprint(...)
  log.always(4, dt.debug.dump(...))
end

--[[
  NAME
    terse_dump - set dt.debug.known to shorten all image dumps to a single line

  SYNOPSIS
    local dd = require "lib/dtutils.debug"

    dd.terse_dump()

  DESCRIPTION
    terse_dump sets dt.debug.known to shorten all images to a single line.
    If you don't need to debug the content of images, this will avoid them flooding your logs
]]

M.libdoc.functions[#M.libdoc.functions + 1] = {
  Sections = {"Name", "Synopsis", "Description"},
  Name = [[terse_dump - set dt.debug.known to shorten all image dumps to a single line]],
  Synopsis = [[local dd = require "lib/dtutils.debug"

    dd.terse_dump()]],
  Description = [[terse_dump sets dt.debug.known to shorten all images to a single line.
    If you don't need to debug the content of images, this will avoid them flooding your logs]],
}

function M.terse_dump()
  for _,v in ipairs(dt.database) do
    dt.debug.known[v] = tostring(v)
  end
end



return M
-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
