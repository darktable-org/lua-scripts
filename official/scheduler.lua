--[[

    scheduler.lua - provide scheduler services for multitasking

    Copyright (C) 2024 Bill Ferguson <wpferguson@gmail.com>.

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
    scheduler - provide scheduler services for multitasking

    scheduler implements a sinple first in first out (FIFO) scheduler 
    necessary for lua script multitasking.

    Scripts voluntarily yield to the scheduler and they are placed at 
    the end of the run queue.  The first item in the run queue is told
    to resume.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    start script from script_manager

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
-- local df = require "lib/dtutils.file"
-- local ds = require "lib/dtutils.string"
-- local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "scheduler"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir
local BROADCAST_MSG <const> = "broadcast"

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("9.4.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

dt.gettext.bindtextdomain(MODULE , dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("scheduler"),            -- name of script
  purpose = _("provide scheduler services for multitasking"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/scheduler/" -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local scheduler = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

scheduler.run_queue = {}
scheduler.message_queue = {}
scheduler.log_level = log.debug

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "target_time_slice_seconds", "float", 
  _("scheduler preferred time slice"), _("target time slice before interrupt"), 1.0, 0.1, 1.0, 0.1)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local sch = scheduler

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function remove_from_run_queue()

  log.log_level(sch.log_level)

  if #sch.run_queue > 0 then
    local module = sch.run_queue[1]
    local message = sch.message_queue[1]
    table.remove(sch.run_queue, 1)
    table.remove(sch.message_queue, 1)
    log.msg(log.info, "run queue length is " .. #sch.run_queue)
    log.msg(log.debug, "sending " .. message .. " to " .. module)
    dt.util.message(MODULE, module, message)
  else
    log.msg(log.warn, "run queue empty, nothing to resume")
  end
end

local function add_to_run_queue(module, message)

  log.log_level(sch.log_level)
  
  table.insert(sch.run_queue, module)
  table.insert(sch.message_queue, message)

  log.msg(log.info, "run queue length is " .. #sch.run_queue)

  dt.control.sleep(500)  -- allow time for waiting scripts to start

  remove_from_run_queue()
end

local function send_status(sender)
  dt.util.message(MODULE, sender, "running, queue length is " .. #sch.run_queue)
end


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.util.message(MODULE, BROADCAST_MSG, "starting")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  -- put things to destroy (events, storages, etc) here
  dt.util.message(MODULE, BROADCAST_MSG, "stopping")
  dt.destroy_event(MODULE, "inter-script-communication")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "inter-script-communication",
  function(event, sender,receiver, message)

    log.log_level(sch.log_level)

    if receiver == "scheduler" then
      log.msg(log.debug, "got message from " .. sender .. " to " .. receiver .. " with message " .. message)
      if string.match(message, "^yield") then
        log.msg(log.debug, "got message " .. message .. " from " .. sender)
        add_to_run_queue(sender, string.gsub(message, "yield", "resume"))
      elseif message == "status" then
        send_status(sender)
      elseif messages == "done" then
        -- do nothing
      else
        log.msg(log.warn, "unrecognized message " .. message)
      end
    end
  end
)

return script_data
