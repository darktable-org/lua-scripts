--[[
This file is part of darktable,
Copyright (c) 2014 Jérémy Rosen
Copyright (c) 2016 Bill Ferguson

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

dhelpers = require "lib/dtutils.debug"

Each function is documented in its own header


]]


local dt = require "darktable"
local io = require "io"
local table = require "table"
require "darktable.debug"
local log = require "lib/dtutils.log"
local M = {} -- The actual content of the module

M.libdoc = {
  Name = [[dtutils.debug]],
  Synopsis = [[debugging helpers used in developing darktable lua scripts]],
  Usage = [[local dd = require "lib/dtutils.debug"]],
  Description = [[dtutils.debug provides an interface to the darktable debugging routines.]],
  Return_Value = [[dd - library - the darktable lua debugging helpers]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = log.libdoc.License,
  Copyright = [[Copyright (c) 2014 Jérémy Rosen
Copyright (c) 2016 Bill Ferguson
]],
  functions = {}
}

M.libdoc.functions["tracepoint"] = {
  Name = [[tracepoint]],
  Synopsis = [[print out a tracepoint and dump the arguments]],
  Usage = [[local dd = require "lib/dtutils.debug"

    local result = tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of]],
  Description = [[tracepoint prints its name and dumps its parameters using
    dt.debug]],
  Return_Value = [[result - ... - the supplied argument list]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function M.tracepoint(name,...)
  log.msg(log.always, 4, "*****  "..name.." ****")
  params = {...}
  log.msg(log.always, 0, dt.debug.dump(params,"parameters"))
  return ...;
end

M.libdoc.functions["new_tracepoint"] = {
  Name = [[new_tracepoint]],
  Synopsis = [[create a function returning a tracepoint]],
  Usage = [[local dd = require "lib/dtutils.debug"

    local result = new_tracepoint(name, ...)
      name - string - the name of the tracepoint to print out
      ... - arguments - variables to dump the contents of]],
  Description = [[A function that returns a tracepoint function with the given name
    This is mainly used to debug callbacks.]],
  Return_Value = [[result - function - a function that returns the result of a tracepoint]],
  Limitations = [[]],
  Example = [[register_event(event, dd.new_tracepoint("hit callback"))

    will print the following each time the callback is called

    **** hit callback ****
    <all the callback's parameters dumped>]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function M.new_tracepoint(name) 
  return function(...) return M.tracepoint(name,...) end
end


M.libdoc.functions["dprint"] = {
  Name = [[dprint]],
  Synopsis = [[pass a variable to dt.debug.dump and print the results to stdout]],
  Usage = [[local dd = require "lib/dtutils.debug"

    dd.dprint(var)
      var - variable - any variable that you want to see the contents of]],
  Description = [[Wrapper around debug.dump, will directly print to stdout,
    same calling convention]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function M.dprint(...)
  log.msg(log.always, 4, dt.debug.dump(...))
end

M.libdoc.functions["terse_dump"] = {
  Name = [[terse_dump]],
  Synopsis = [[set dt.debug.known to shorten all image dumps to a single line]],
  Usage = [[local dd = require "lib/dtutils.debug"

    dd.terse_dump()]],
  Description = [[terse_dump sets dt.debug.known to shorten all images to a single line.
    If you don't need to debug the content of images, this will avoid them flooding your logs]],
  Return_Value = [[]],
  Limitations = [[]],
  Example = [[]],
  See_Also = [[]],
  Reference = [[]],
  License = [[]],
  Copyright = [[]],
}

function M.terse_dump()
  for _,v in ipairs(dt.database) do
    dt.debug.known[v] = tostring(v)
  end
end



return M
-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
