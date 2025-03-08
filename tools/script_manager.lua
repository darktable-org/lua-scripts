--[[
  This file is part of darktable,
  copyright (c) 2018, 2020, 2023, 2024 Bill Ferguson <wpferguson@gmail.com>
  
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
    script_manager.lua - a tool for managing the darktable lua scripts

    script_manager is designed to be called from the users luarc file and used to
    manage the lua scripts.

    On startup script_manager scans the lua scripts directory to see what scripts are present.
    Scripts are sorted by 'folder' based on what sub-directory they are in.  With no 
    additional script repositories iinstalled, the folders are contrib, examples, official
    and tools.  When a folder is selected the buttons show the script name and whether the
    script is started or stopped.  The button is a toggle, so if the script is stopped click 
    the button to start it and vice versa.

    Features

    * the number of script buttons shown can be changed to any number between 5 and 20.  The 
      default is 10 buttons.  This can be changed in the configuration action.

    * additional repositories of scripts may be installed using from the install/update action.

    * installed scripts can be updated from the install/update action.  This includes extra
      repositories that have been installed.

    * the scripts can be disabled if desired from the install/update action.  This can only
      be reversed manually.  To enable the "Disable Scripts" button, check the checkbox to
      endable it.  This is to prevent accidentally disabling the scripts.  Click the 
      "Disable Scripts" button and the luarc file is renamed to luarc.disable.  If at
      a later time you want to enable the scripts again, simply rename the luarc.disabled 
      file to luarc and the scripts will run.

]]


local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
local debug = require "darktable.debug"

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- api check

-- du.check_min_api_version("9.3.0", "script_manager")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- script_manager required API version
local SM_API_VER_REQD <const> = "9.3.0"

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

local MODULE <const> = "script_manager"

local MIN_BUTTONS_PER_PAGE <const> = 5
local MAX_BUTTONS_PER_PAGE <const> = 20
local DEFAULT_BUTTONS_PER_PAGE <const> = 10

local DEFAULT_LOG_LEVEL <const> = log.warn

local LUA_DIR <const> = dt.configuration.config_dir .. PS .. "lua"
local LUA_SCRIPT_REPO <const> = "https://github.com/darktable-org/lua-scripts.git"

local LUA_API_VER <const> = "API-" .. dt.configuration.api_version_string

-- local POWER_ICON = dt.configuration.config_dir .. "/lua/data/data/icons/power.png"
local POWER_ICON <const> = dt.configuration.config_dir .. "/lua/data/icons/path20.png"
local BLANK_ICON <const> = dt.configuration.config_dir .. "/lua/data/icons/blank20.png"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "check_update", "bool",
  _("check for updated scripts on start up"), 
  _("automatically update scripts to correct version"), 
  true)

local check_for_updates = dt.preferences.read(MODULE, "check_update", "bool")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

local old_log_level = log.log_level()

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local script_manager = {}
local sm = script_manager

sm.executables = {}
sm.executables.git = df.check_if_bin_exists("git")

sm.module_installed = false
sm.event_registered = false

-- set up tables to contain all the widgets and choices

sm.widgets = {}
sm.folders = {}
sm.translated_folders = {}

-- set log level for functions

sm.log_level = DEFAULT_LOG_LEVEL

--[[

  sm.scripts is a table of tables for containing the scripts
  It is organized as into folder (folder) subtables containing
  each script definition, which is a table

  sm.scripts-
            |
            - folder------------|
            |                     - script
            - folder----|       |
                          - script|
                          |       - script
                          - script|

  and a script table looks like

  name          the name of the script file without the lua extension
  path          folder (folder), path separator, path, name without the lua extension
  doc           the header comments from the script to be used as a tooltip
  script_name   the folder, path separator, and name without the lua extension
  running       true if running, false if not, hidden if running but the 
                lib/storage/action for the script is hidden
  has_lib       true if it creates a module
  lib_name      name of the created lib
  has_storage   true if it creates a storage (exporter)
  storage_name  name of the exporter (in the exporter storage menu)
  has_action    true if it creates an action
  action_name   name on the button
  has_select    true if it creates a select
  select_name   name on the button
  has_event     true if it creates an event handler
  event_type    type of event, shortcut, post-xxx, pre-xxx
  callback      name of the callback routine
  initialized   all of the above data has been retreived and set.  If the 
                script is unloaded and reloaded we don't have to reparse the file

]]

sm.scripts = {}
sm.start_queue = {}
sm.page_status = {}
sm.page_status.num_buttons = DEFAULT_BUTTONS_PER_PAGE
sm.page_status.buttons_created = 0
sm.page_status.current_page = 0
sm.page_status.folder = ""

-- installed script repositories
sm.installed_repositories = {
  {name = "lua-scripts", directory = LUA_DIR},
}


-- don't let it run until everything is in place
sm.run = false

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-------------------
-- helper functions
-------------------

local function set_log_level(level)
  local old_log_level = log.log_level()
  log.log_level(level)
  return old_log_level
end

local function restore_log_level(level)
  log.log_level(level)
end

local function pref_read(name, pref_type)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "name is " .. name .. " and type is " .. pref_type)

  local val = dt.preferences.read(MODULE, name, pref_type)

  log.msg(log.debug, "read value " .. tostring(val))

  restore_log_level(old_log_level)
  return val
end

local function pref_write(name, pref_type, value)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "writing value " .. tostring(value) .. " for name " .. name)

  dt.preferences.write(MODULE, name, pref_type, value)

  restore_log_level(old_log_level)
end

----------------
-- git interface
----------------

local function get_repo_status(repo)
  local old_log_level = set_log_level(sm.log_level)

  local p = io.popen("cd " .. repo .. CS .. "git status")

  if p then
    local data = p:read("*a")
    p:close()
    return data
  end

  log.msg(log.error, "unable to get status of " .. repo)
  restore_log_level(old_log_level)
  return nil
end

local function get_current_repo_branch(repo)
  local old_log_level = set_log_level(sm.log_level)

  local branch = nil

  local p = io.popen("cd " .. repo .. CS .. "git branch --all")

  if p then
    local data = p:read("*a")
    p:close()
    local branches = du.split(data, "\n")
    for _, b in ipairs(branches) do
      log.msg(log.debug, "branch for testing is " .. b)
      branch = string.match(b, "^%* (.-)$")

      if branch then
        log.msg(log.info, "current repo branch is " .. branch)
        return branch
      end

    end
  end

  if not branch then
    log.msg(log.error, "no current branch detected in repo_data")
  end

  restore_log_level(old_log_level)
  return nil
end

local function get_repo_branches(repo)
  local old_log_level = set_log_level(sm.log_level)

  local branches = {}
  local p = io.popen("cd " .. repo .. CS .. "git pull --all" .. CS .. "git branch --all")

  if p then
    local data = p:read("*a")
    p:close()
    log.msg(log.debug, "data is \n" .. data)
    local branch_data = du.split(data, "\n")
    for _, line in ipairs(branch_data) do
      log.msg(log.debug, "line is  " .. line)
      local branch = string.gsub(line, "%s+remotes/%a+/", "")
      if string.match(branch, "API") then
        log.msg(log.info, "found branch - " .. branch)
        table.insert(branches, branch)
      end
    end
  end

  restore_log_level(old_log_level)
  return branches 
end

local function is_repo_clean(repo_data)
  local old_log_level = set_log_level(sm.log_level)

  if string.match(repo_data, "\n%s-%a.-%a:%s-%a%g-\n") then
    log.msg(log.info, "repo is dirty")
    return false
  else
    log.msg(log.info, "repo is clean")
    return true
  end

  restore_log_level(old_log_level)
end

local function checkout_repo_branch(repo, branch)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.info, "checkout out branch " .. branch .. " from repository " .. repo)

  os.execute("cd " .. repo .. CS .. "git checkout " .. branch)

  restore_log_level(old_log_level)
end

--------------------
-- utility functions
--------------------

local function update_combobox_choices(combobox, choice_table, selected)
  local old_log_level = set_log_level(sm.log_level)

  local items = #combobox
  local choices = #choice_table

  for i, name in ipairs(choice_table) do 
    combobox[i] = name
  end

  if choices < items then
    for j = items, choices + 1, -1 do
      combobox[j] = nil
    end
  end

  if not selected then
    selected = 1
  end

  combobox.value = selected
  restore_log_level(old_log_level)
end

local function string_trim(str)
  local old_log_level = set_log_level(sm.log_level)

  local result = string.gsub(str, "^%s+", "") -- trim leading spaces
  result = string.gsub(result, "%s+$", "")    -- trim trailing spaces
  result = string.gsub(result, ",?%s+%-%-.+$", "") -- trim trailing comma and comments

  restore_log_level(old_log_level)
  return result
end

local function string_dequote(str)
  return string.gsub(str, "['\"]", "")
end

local function string_dei18n(str)
  return string.match(str, "%_%((.+)%)")
end

local function string_chop(str)
  return str:sub(1, -2)
end

------------------
-- script handling
------------------

local function is_folder_known(folder_table, name)
  local match = false

  for _, folder_name in ipairs(folder_table) do
    if name == folder_name then
      match = true
    end
  end

  return match
end

local function find_translated_name(folder)
  local translated_name = nil

  if folder == "contrib" then
    translated_name = _("contributed")
  elseif folder == "examples" then
    translated_name = _("examples")
  elseif folder == "official" then
    translated_name = _("official")
  elseif folder == "tools" then
    translated_name = _("tools")
  else
    translated_name = _(folder) -- in case we get lucky and the string got translated elsewhere
  end

  return translated_name
end

local function add_script_folder(folder)
  local old_log_level = set_log_level(sm.log_level)

  if #sm.folders == 0 or not is_folder_known(sm.folders, folder) then
    table.insert(sm.folders, folder)
    table.insert(sm.translated_folders, find_translated_name(folder))
    sm.scripts[folder] = {}
    log.msg(log.debug, "created folder " .. folder)
  end

  restore_log_level(old_log_level)
end

local function get_script_metadata(script)
  local old_log_level = set_log_level(sm.log_level)
  -- set_log_level(log.debug)

  log.msg(log.debug, "processing metatdata for " .. script)

  local metadata_block = nil
  local metadata = {}

  f = io.open(LUA_DIR .. PS .. script .. ".lua")
  if f then
    -- slurp the file
    local content = f:read("*all")
    f:close()
    -- grab the script_data.metadata table
    metadata_block = string.match(content, "script_data%.metadata = %{\r?\n(.-)\r?\n%}")
  else
    log.msg(log.error, "cant read from " .. script)
  end

  if metadata_block then
    -- break up the lines into key value pairs
    local lines = du.split(metadata_block, "\n")
    log.msg(log.debug, "got " .. #lines .. " lines")
    for i = 1, #lines do
      log.msg(log.debug, "splitting line " .. lines[i])
      local parts = du.split(lines[i], " = ")
      parts[1] = string_trim(parts[1])
      parts[2] = string_trim(parts[2])
      log.msg(log.debug, "got value " .. parts[1] .. " and data " .. parts[2])
      if string.match(parts[2], "%_%(") then
        parts[2] = _(string_dequote(string_dei18n(parts[2])))
      else
        parts[2] = string_dequote(parts[2])
      end
      if string.match(parts[2], ",$") then
        parts[2] = string_chop(parts[2])
      end
      log.msg(log.debug, "parts 1 is " .. parts[1] .. " and parts 2 is " .. parts[2])
      metadata[parts[1]] = parts[2]
      log.msg(log.debug, "metadata " .. parts[1] .. " is " .. metadata[parts[1]])
    end
    log.msg(log.debug, "script data found for " .. metadata["name"])
  end

  restore_log_level(old_log_level)
  return metadata_block and metadata or nil
end

local function get_script_doc(script)
  local old_log_level = set_log_level(sm.log_level)
  local description = nil
  f = io.open(LUA_DIR .. PS .. script .. ".lua")
  if f then
    -- slurp the file
    local content = f:read("*all")
    f:close()
    -- assume that the second block comment is the documentation
    description = string.match(content, "%-%-%[%[.-%]%].-%-%-%[%[(.-)%]%]")
  else
    log.msg(log.error, "can't read from " .. script)
  end
  if description then
    restore_log_level(old_log_level)
    return description
  else
    restore_log_level(old_log_level)
    return _("no documentation available")
  end
end

local function activate(script)
  local old_log_level = set_log_level(sm.log_level)

  local status = nil -- status of start function
  local err = nil    -- error message returned if module doesn't start

  log.msg(log.info, "activating " .. script.name)

  if script.running == false then

    script_manager_running_script = script.name

    status, err = du.prequire(script.path)
    log.msg(log.debug, "prequire returned " .. tostring(status) .. " and for err " .. tostring(err))

    script_manager_running_script = nil

    if status then
      pref_write(script.script_name, "bool", true)
      log.msg(log.screen, _(string.format("loaded %s", script.script_name)))
      script.running = true

      if err ~= true then
        log.msg(log.debug, "got lib data")
        script.data = err
        if script.data.destroy_method and script.data.destroy_method == "hide" and script.data.show and dt.gui.current_view().id == "lighttable" then
          script.data.show()
        end
      else
        script.data = nil
      end

     else
      log.msg(log.screen, _(string.format("%s failed to load", script.script_name)))
      log.msg(log.error, "error loading " .. script.script_name)
      log.msg(log.error, "error message: " .. err)
    end

  else -- script is a lib and loaded but hidden and the user wants to reload
    script.data.restart()
    script.running = true
    status = true
    pref_write(script.script_name, "bool", true)
  end
  script_manager_running_script = "script_manager"

  restore_log_level(old_log_level)
  return status
end

local function deactivate(script)
  -- presently the lua api doesn't support unloading lib elements however, we
  --   can hide libs, so we just mark those as hidden and hide the gui
  --   can delete storages
  --   can delete actions
  --   can delete selects
  --   and mark them inactive for the next time darktable starts

  -- deactivate it....
  local old_log_level = set_log_level(sm.log_level)

  pref_write(script.script_name, "bool", false)

  if script.data then

    script.data.destroy()

    if script.data.destroy_method then
      if string.match(script.data.destroy_method, "hide") then
        script.running = "hidden"
      else
        package.loaded[script.script_name] = nil
        script.running = false
      end
    else
      package.loaded[script.script_name] = nil
      script.running = false
    end

    log.msg(log.info, "turned off " .. script.script_name)
    log.msg(log.screen, _(string.format("%s stopped", script.name)))

  else
    script.running = false

    log.msg(log.info, "setting " .. script.script_name .. " to not start")
    log.msg(log.screen, _(string.format("%s will not start when darktable is restarted", script.name)))
  end

  restore_log_level(old_log_level)
end

local function start_scripts()
  for _, script in ipairs(sm.start_queue) do
    activate(script)
    for i = 1, sm.page_status.num_buttons do
      local name = script.metadata and script.metadata.name or script.name
      if sm.widgets.labels[i].label == name then
        sm.widgets.buttons[i].name = "pb_on"
        break
      end
    end
  end
  sm.start_queue = {}
end

local function queue_script_to_start(script)
  table.insert(sm.start_queue, script)
end

local function add_script_name(name, path, folder)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "folder is " .. folder)
  log.msg(log.debug, "name is " .. name)

  local script = { 
    name = name, 
    path = folder .. "/" .. path .. name,
    running = false,
    doc = get_script_doc(folder .. "/" .. path .. name),
    metadata = get_script_metadata(folder .. "/" .. path .. name),
    script_name = folder .. "/" .. name,
    data = nil
  }

  table.insert(sm.scripts[folder], script)

  if pref_read(script.script_name, "bool") then
    queue_script_to_start(script)
  else
    pref_write(script.script_name, "bool", false)
  end

  restore_log_level(old_log_level)
end

local function process_script_data(script_file)
  local old_log_level = set_log_level(sm.log_level)

  -- the script file supplied is folder/filename.filetype
  -- the following pattern splits the string into folder, path, name, fileename, and filetype
  -- for example contrib/gimp.lua becomes
  -- folder - contrib
  -- path - 
  -- name - gimp.lua
  -- filename - gimp
  -- filetype - lua

  -- Thanks Tobias Jakobs for the awesome regulary expression

  local pattern = "(.-)/(.-)(([^\\/]-)%.?([^%.\\/]*))$"
  if dt.configuration.running_os == "windows" then
    -- change the path separator from / to \ for windows
    pattern = "(.-)\\(.-)(([^\\]-)%.?([^%.\\]*))$"
  end

  log.msg(log.info, "processing " .. script_file)

  -- add the script data
  local folder,path,name,filename,filetype = string.match(script_file, pattern)

  if folder and name and path then
    log.msg(log.debug, "folder is " .. folder)
    log.msg(log.debug, "name is " .. name)

    add_script_folder(folder)
    add_script_name(name, path, folder)
  end

  restore_log_level(old_log_level)
end

local function ensure_lib_in_search_path(line)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "line is " .. line)

  if string.match(line, ds.sanitize_lua(dt.configuration.config_dir .. PS .. "lua/lib")) then
    log.msg(log.debug, line .. " is already in search path, returning...")
    return
  end

  local pattern =  dt.configuration.running_os == "windows" and  "(.+)\\lib\\.+lua" or  "(.+)/lib/.+lua"
  local path = string.match(line, pattern)

  log.msg(log.debug, "extracted path is " .. path)
  log.msg(log.debug, "package.path is " .. package.path)

  if not string.match(package.path, ds.sanitize_lua(path)) then

    log.msg(log.debug, "path isn't in package.path, adding...")

    package.path = package.path .. ";" .. path .. "/?.lua"

    log.msg(log.debug, "new package.path is " .. package.path)
  end

  restore_log_level(old_log_level)
end

local function scan_scripts(script_dir)
  local old_log_level = set_log_level(sm.log_level)

  local script_count = 0
  local find_cmd = "find -L " .. script_dir .. " -name \\*.lua -print | sort"

  if dt.configuration.running_os == "windows" then
    find_cmd = "dir /b/s \"" .. script_dir .. "\\*.lua\" | sort"
  end

  log.msg(log.debug, "find command is " .. find_cmd)

  -- scan the scripts
  local output = io.popen(find_cmd)
  for line in output:lines() do
    log.msg(log.debug, "line is " .. line)
    local l = string.gsub(line, ds.sanitize_lua(LUA_DIR) .. PS, "")   -- strip the lua dir off
    local script_file = l:sub(1,-5)                                   -- strip off .lua\n
    if not string.match(script_file, "script_manager") then           -- let's not include ourself
      if not string.match(script_file, "plugins") then                -- skip plugins
        if not string.match(script_file, "lib" .. PS) then            -- let's not try and run libraries
          if not string.match(script_file, "%.git") then              -- don't match files in the .git directory
            process_script_data(script_file)
            script_count = script_count + 1
          end
        else
          ensure_lib_in_search_path(line)                             -- but let's make sure libraries can be found
        end
      end
    end
  end

  restore_log_level(old_log_level)
  return script_count
end

local function update_scripts()
  local old_log_level = set_log_level(sm.log_level)
  local result = false

  local git = sm.executables.git

  if not git then
    log.msg(log.screen, _("ERROR: git not found.  Install or specify the location of the git executable."))
    return
  end

  local git_command = "cd " .. LUA_DIR .. " " .. CS .. " " .. git .. " pull"
  log.msg(log.debug, "update git command is " .. git_command)

  if dt.configuration.running_os == "windows" then
    result = dtsys.windows_command(git_command)
  else
    result = os.execute(git_command)
  end

  if result == 0 then
    log.msg(log.screen, _("lua scripts successfully updated"))
  end

  restore_log_level(old_log_level)
  return result
end

--------------
-- UI handling
--------------

local function update_script_update_choices()
  local old_log_level = set_log_level(sm.log_level)

  local installs = {}
  local pref_string = ""

  for i, repo in ipairs(sm.installed_repositories) do
    table.insert(installs, repo.name)
    pref_string = pref_string .. i .. "," .. repo.name .. "," .. repo.directory .. ","
  end

  update_combobox_choices(sm.widgets.update_script_choices, installs, 1)

  log.msg(log.debug, "repo pref string is " .. pref_string)
  pref_write("installed_repos", "string", pref_string)

  restore_log_level(old_log_level)
end

local function scan_repositories()
  local old_log_level = set_log_level(sm.log_level)

  local script_count = 0
  local find_cmd = "find -L " .. LUA_DIR .. " -name \\*.git -print | sort"

  if dt.configuration.running_os == "windows" then
    find_cmd = "dir /b/s /a:d " .. LUA_DIR .. PS .. "*.git | sort"
  end

  log.msg(log.debug, "find command is " .. find_cmd)

  local output = io.popen(find_cmd)

  for line in output:lines() do
    local l = string.gsub(line, ds.sanitize_lua(LUA_DIR) .. PS, "")   -- strip the lua dir off
    local folder = string.match(l, "(.-)" .. PS)                        -- get everything to the first /

    if folder then                                                 -- if we have a folder (.git doesn't)

      log.msg(log.debug, "found folder " .. folder)

      if not string.match(folder, "plugins") and not string.match(folder, "%.git") then -- skip plugins

        if #sm.installed_repositories == 1 then
          log.msg(log.debug, "only 1 repo, adding " .. folder)
          table.insert(sm.installed_repositories, {name = folder, directory = LUA_DIR .. PS .. folder})
        else
          log.msg(log.debug, "more than 1 repo, we have to search the repos to make sure it's not there")
          local found = nil

          for _, repo in ipairs(sm.installed_repositories) do
            if string.match(repo.name, ds.sanitize_lua(folder)) then
              log.msg(log.debug, "matched " .. repo.name)
              found = true
              break
            end
          end

          if not found then
            table.insert(sm.installed_repositories, {name = folder, directory = LUA_DIR .. PS .. folder})
          end

        end
      end
    end
  end

  update_script_update_choices()

  restore_log_level(old_log_level)
end

local function install_scripts()
  local old_log_level = set_log_level(sm.log_level)

  local url = sm.widgets.script_url.text
  local folder = sm.widgets.new_folder.text

  if string.match(du.join(sm.folders, " "), ds.sanitize_lua(folder)) then
    log.msg(log.screen, _(string.format("folder %s is already in use. Please specify a different folder name.", folder)))
    log.msg(log.error, "folder " .. folder .. " already exists, returning...")
    restore_log_level(old_log_level)
    return
  end

  local result = false

  local git = sm.executables.git

  if not git then
    log.msg(log.screen, _("ERROR: git not found.  Install or specify the location of the git executable."))
    restore_log_level(old_log_level)
    return
  end

  local git_command = "cd " .. LUA_DIR .. " " .. CS .. " " .. git .. " clone " .. url .. " " .. folder
  log.msg(log.debug, "update git command is " .. git_command)

  if dt.configuration.running_os == "windows" then
    result = dtsys.windows_command(git_command)
  else
    result = dtsys.external_command(git_command)
  end

  log.msg(log.info, "result from import is " .. result)

  if result == 0 then
    local count = scan_scripts(LUA_DIR .. PS .. folder)

    if count > 0 then
      update_combobox_choices(sm.widgets.folder_selector, sm.folders, sm.widgets.folder_selector.selected)
      dt.print(_(string.format("scripts successfully installed into folder %s"), folder))
      table.insert(sm.installed_repositories, {name = folder, directory = LUA_DIR .. PS .. folder})
      update_script_update_choices()

      for i = 1, #sm.widgets.folder_selector do
        if string.match(sm.widgets.folder_selector[i], ds.sanitize_lua(folder)) then
          log.msg(log.debug, "setting folder selector to " .. i)
          sm.widgets.folder_selector.selected = i
          break
        end
        i = i + 1
      end

      log.msg(log.debug, "clearing text fields")
      sm.widgets.script_url.text = ""
      sm.widgets.new_folder.text = ""
      sm.widgets.main_menu.selected = 3
    else
      log.msg(log.screen, _("no scripts found to install"))
      log.msg(log.error, "scan_scripts returned " .. count .. " scripts found.  Not adding to folder_selector")
    end

  else
    log.msg(log.screen, _("failed to download scripts"))
  end

  restore_log_level(old_log_level)
  return result
end

local function clear_button(number)
  local old_log_level = set_log_level(sm.log_level)

  local button = sm.widgets.buttons[number]
  local label = sm.widgets.labels[number]

  button.image = BLANK_ICON
  button.tooltip = ""
  button.sensitive = false
  label.label = ""
  button.name = ""

  restore_log_level(old_log_level)
end

local function find_script(folder, name)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "looking for script " .. name .. " in folder " .. folder)

  for _, script in ipairs(sm.scripts[folder]) do
    if string.match(script.name, "^" .. ds.sanitize_lua(name) .. "$") then
      return script
    end
  end

  restore_log_level(old_log_level)
  return nil
end

local function populate_buttons(folder, first, last)
  local old_log_level = set_log_level(sm.log_level)

  log.msg(log.debug, "folder is " .. folder .. " and first is " .. first .. " and last is " .. last)

  local button_num = 1

  for i = first, last do
    local script = sm.scripts[folder][i]
    local button = sm.widgets.buttons[button_num]
    local label = sm.widgets.labels[button_num]

    if script.running == true then
      button.name = "pb_on"
    else
      button.name = "pb_off"
    end

    button.image = POWER_ICON
    label.label = script.metadata and script.metadata.name or script.name
    label.name = "pb_label"
    button.ellipsize = "end"
    button.sensitive = true
    label.tooltip = script.metadata and script.metadata.purpose or script.doc

    button.clicked_callback = function (this)
      local cb_script = script
      local state = nil
      if cb_script then 
        log.msg(log.debug, "found script " .. cb_script.name .. " with path " .. cb_script.path)
        if cb_script.running == true then
          log.msg(log.debug, "deactivating " .. cb_script.name .. " on " .. cb_script.path)
          deactivate(cb_script)
          this.name = "pb_off"
        else
          log.msg(log.debug, "activating " .. cb_script.name .. " on " .. script.path)
          local result = activate(cb_script)
          if result then
            this.name = "pb_on"
          end
        end
      end
    end

    button_num = button_num + 1
  end

  if button_num <= sm.page_status.num_buttons then
    for i = button_num, sm.page_status.num_buttons do
      clear_button(i)
    end
  end

  restore_log_level(old_log_level)
end

local function paginate(direction)
  local old_log_level = set_log_level(sm.log_level)

  local folder = sm.page_status.folder
  log.msg(log.debug, "folder is " .. folder)

  local num_scripts = #sm.scripts[folder]
  log.msg(log.debug, "num_scripts is " .. num_scripts)

  local max_pages = math.ceil(num_scripts / sm.page_status.num_buttons)

  local cur_page = sm.page_status.current_page
  log.msg(log.debug, "max pages is " .. max_pages)

  local buttons_needed = nil
  local first = nil
  local last = nil

  if direction == 0 then
    cur_page = cur_page - 1
    if cur_page < 1 then
      cur_page = 1
    end
  elseif direction == 1 then
    cur_page = cur_page + 1
    if cur_page > max_pages then
      cur_page = max_pages
    end
  else
    log.msg(log.debug, "took path 2")
    cur_page = 1
  end

  log.msg(log.debug, "cur_page is " .. cur_page .. " and max_pages is " .. max_pages)

  if cur_page == max_pages and cur_page == 1 then
    sm.widgets.page_forward.sensitive = false
    sm.widgets.page_back.sensitive = false
  elseif cur_page == max_pages then
    sm.widgets.page_forward.sensitive = false
    sm.widgets.page_back.sensitive = true
  elseif cur_page == 1 then
    sm.widgets.page_forward.sensitive = true
    sm.widgets.page_back.sensitive = false
  else
    sm.widgets.page_forward.sensitive = true
    sm.widgets.page_back.sensitive = true
  end

  sm.page_status.current_page = cur_page

  first = (cur_page * sm.page_status.num_buttons) - (sm.page_status.num_buttons - 1)

  if first + sm.page_status.num_buttons > num_scripts then
    last = num_scripts
  else
    last = first + sm.page_status.num_buttons - 1
  end

  sm.widgets.page_status.label = string.format(_("page %d of %d"), cur_page, max_pages)

  populate_buttons(folder, first, last)

  restore_log_level(old_log_level)
end

local function change_folder(folder)
  local old_log_level = set_log_level(sm.log_level)

  if not folder then
    log.msg(log.debug "setting folder to selector value " ..  sm.widgets.folder_selector.value)
    sm.page_status.folder = sm.widgets.folder_selector.value
  else
    log.msg(log.debug, "setting catgory to argument " .. folder)
    sm.page_status.folder = folder
  end

  paginate(2)

  restore_log_level(old_log_level)
end

local function change_num_buttons()
  local old_log_level = set_log_level(sm.log_level)

  cur_buttons = sm.page_status.num_buttons
  new_buttons = sm.widgets.num_buttons.value

  pref_write("num_buttons", "integer", new_buttons)

  if new_buttons < cur_buttons then
    log.msg(log.debug, "took new is less than current branch")

    for i = 1, cur_buttons - new_buttons do
      table.remove(sm.widgets.scripts)
    end

    log.msg(log.debug, "finished removing widgets, now there are " .. #sm.widgets.buttons)
  elseif new_buttons > cur_buttons then
    log.msg(log.debug, "took new is greater than current branch")
    log.msg(log.debug, "number of scripts is " .. #sm.widgets.scripts)
    log.msg(log.debug, "number of buttons is " .. #sm.widgets.buttons)
    log.msg(log.debug, "number of labels is " .. #sm.widgets.labels)
    log.msg(log.debug, "number of boxes is " .. #sm.widgets.boxes)

    if new_buttons > sm.page_status.buttons_created then

      for i = sm.page_status.buttons_created + 1, new_buttons do
        log.msg(log.debug, "i is " .. i)
        table.insert(sm.widgets.buttons, dt.new_widget("button"){})
        log.msg(log.debug, "inserted new button")
        log.msg(log.debug, "number of buttons is " .. #sm.widgets.buttons)
        table.insert(sm.widgets.labels, dt.new_widget("label"){})
        log.msg(log.debug, "inserted new label")
        log.msg(log.debug, "number of labels is " .. #sm.widgets.labels)
        table.insert(sm.widgets.boxes, dt.new_widget("box"){ orientation = "horizontal", expand = false, fill = false, 
                                                       sm.widgets.buttons[i], sm.widgets.labels[i]})
        log.msg(log.debug, "inserted new box")
        sm.page_status.buttons_created = sm.page_status.buttons_created + 1
      end

    end

    log.msg(log.debug, "cur_buttons is " .. cur_buttons .. " and new_buttons is " .. new_buttons)
    log.msg(log.debug, #sm.widgets.buttons .. " buttons are available")

    for i = cur_buttons + 1, new_buttons do
      log.msg(log.debug, "inserting button " .. i .. " into scripts widget")
      table.insert(sm.widgets.scripts, sm.widgets.boxes[i])
    end

    log.msg(log.debug, "finished adding widgets, now there are " .. #sm.widgets.buttons)
  else -- no change
    log.msg(log.debug, "no change, just returning")
    return
  end

  sm.page_status.num_buttons = new_buttons
  log.msg(log.debug, "num_buttons set to " .. sm.page_status.num_buttons)
  paginate(2) -- force the buttons to repopulate
  sm.widgets.main_menu.selected = 3 -- jump back to start/stop scripts

  restore_log_level(old_log_level)
end

local function load_preferences()
  local old_log_level = set_log_level(sm.log_level)

  -- load the prefs and update settings
  -- update_script_choices

  local pref_string = pref_read("installed_repos", "string")
  local entries = du.split(pref_string, ",")

  while  #entries > 2 do
    local num = table.remove(entries, 1)
    local name = table.remove(entries, 1)
    local directory = table.remove(entries, 1)

    if not string.match(sm.installed_repositories[1].name, "^" .. ds.sanitize_lua(name) .. "$") then
      table.insert(sm.installed_repositories, {name = name, directory = directory})
    end

  end

  update_script_update_choices()
  log.msg(log.debug, "updated installed scripts")

  -- folder selector
  local val = pref_read("folder_selector", "integer")

  if val == 0 then
    val = 1
  end

  sm.widgets.folder_selector.selected = val
  sm.page_status.folder = sm.widgets.folder_selector.value
  log.msg(log.debug, "updated folder selector and set it to " .. sm.widgets.folder_selector.value)

  -- num_buttons
  local val = pref_read("num_buttons", "integer")

  if val == 0 then
    val = DEFAULT_BUTTONS_PER_PAGE
  end

  sm.widgets.num_buttons.value = val
  log.msg(log.debug, "set page buttons to " .. val)

  change_num_buttons()
  log.msg(log.debug, "paginated")

  -- main menu
  local val = pref_read("main_menu_action", "integer")
  log.msg(log.debug, "read " .. val .. " for main menu")

  if val == 0 then
    val = 3
  end

  sm.widgets.main_menu.selected = val
  log.msg(log.debug, "set main menu to val " .. val .. " which is " .. sm.widgets.main_menu.value)

  log.msg(log.debug, "set main menu to " .. sm.widgets.main_menu.value)

  restore_log_level(old_log_level)
end

local function install_module()
  local old_log_level = set_log_level(sm.log_level)

  if not sm.module_installed then
    dt.register_lib(
      "script_manager",     -- Module name
      _("scripts"),     -- Visible name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_BOTTOM", 100}},   -- containers
      sm.widgets.main_box,
      nil,-- view_enter
      nil -- view_leave
    )
    sm.module_installed = true
  end

  sm.run = true
  sm.use_color = pref_read("use_color", "bool")
  log.msg(log.debug, "set run to true, loading preferences")
  load_preferences()
  scan_repositories()
  start_scripts()

  restore_log_level(old_log_level)
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- ensure shortcuts module knows widgets belong to script_manager

script_manager_running_script = "script_manager"

if check_for_updates or SM_API_VER_REQD > dt.configuration.api_version_string then
  local repo_data = get_repo_status(LUA_DIR)
  local current_branch = get_current_repo_branch(LUA_DIR)
  local clean = is_repo_clean(repo_data)
  local repo = LUA_DIR

  if current_branch then

    if sm.executables.git and clean and 

      (current_branch == "master" or string.match(current_branch, "^API%-")) then -- only make changes to clean branches
      local branches = get_repo_branches(LUA_DIR)

      if current_branch ~= LUA_API_VER and current_branch ~= "master" then
        -- probably upgraded from an earlier api version so get back to master
        -- to use the latest version of script_manager to get the proper API
        checkout_repo_branch(repo, "master")
        log.msg(log.screen, _("lua API version reset, please restart darktable"))

      elseif LUA_API_VER == current_branch then
        -- do nothing, we are fine
        log.msg(log.debug, "took equal branch, doing nothing")

      elseif string.match(LUA_API_VER, "dev") then
        -- we are on a dev API version, so checkout the dev
        -- api version or checkout/stay on master
        log.msg(log.debug, "took the dev branch")
        local match = false

        for _, branch in ipairs(branches) do
          log.msg(log.debug, "checking branch " .. branch .. " against API " .. LUA_API_VER)
          if LUA_API_VER == branch then
            match = true
            log.msg(log.info, "checking out repo development branch " .. branch)
            checkout_repo_branch(repo, branch)
          end
        end

        if not match then
          if current_branch == "master" then
            log.msg(log.info, "staying on master, no dev branch yet")
          else
            log.msg(log.info, "no dev branch available, checking out master")
            checkout_repo_branch(repo, "master")
          end
        end

      elseif #branches > 0 and LUA_API_VER > branches[#branches] then
        log.msg(log.info, "no newer branches, staying on master")
        -- stay on master

      else
        -- checkout the appropriate branch for API version if it exists
        log.msg(log.info, "checking out the appropriate API branch")

        local match = false

        for _x, branch in ipairs(branches) do
          log.msg(log.debug, "checking branch " .. branch .. " against API " .. LUA_API_VER)

          if LUA_API_VER == branch then
            match = true
            log.msg(log.info, "checking out repo branch " .. branch)
            checkout_repo_branch(repo, branch)
            log.msg(log.screen, _("you must restart darktable to use the correct version of the lua scripts"))
            return
          end

        end

        if not match then
          log.msg(log.warn, "no matching branch found for " .. LUA_API_VER)
        end

      end
    end
  end
end

scan_scripts(LUA_DIR)
log.msg(log.debug, "finished processing scripts")


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- update the scripts

sm.widgets.update_script_choices = dt.new_widget("combobox"){
  label = _("scripts to update"),
  tooltip = _("select the scripts installation to update"),
  selected = 1,
  changed_callback = function(this)
    pref_write("update_script_choices", "integer", this.selected)
  end,
  "placeholder",
}

sm.widgets.update = dt.new_widget("button"){
  label = _("update scripts"),
  tooltip = _("update the lua scripts from the repository"),
  clicked_callback = function(this)
    update_scripts()
  end
}

-- add additional scripts

sm.widgets.script_url = dt.new_widget("entry"){
  text = "",
  placeholder = "https://<repository url>",
  tooltip = _("enter the URL of the git repository containing the scripts you wish to add")
}

sm.widgets.new_folder = dt.new_widget("entry"){
  text = "",
  placeholder = _("name of new folder"),
  tooltip = _("enter a folder name for the additional scripts")
}

sm.widgets.add_scripts = dt.new_widget("box"){
  orientation = vertical,
  dt.new_widget("label"){label = _("URL to download additional scripts from")},
  sm.widgets.script_url,
  dt.new_widget("label"){label = _("new folder to place scripts in")},
  sm.widgets.new_folder,
  dt.new_widget("button"){
    label = _("install additional scripts"),
    clicked_callback = function(this)
      install_scripts()
    end
  }
}

sm.widgets.allow_disable = dt.new_widget("check_button"){
  label = _('enable "disable scripts" button'),
  value = false,
  clicked_callback = function(this)
    if this.value == true then
      sm.widgets.disable_scripts.sensitive = true
    else
      sm.widgets.disable_scripts.sensitive = false
    end
  end,
}

sm.widgets.disable_scripts = dt.new_widget("button"){
  label = _("disable scripts"),
  sensitive = false,
  clicked_callback = function(this)
    local LUARC = dt.configuration.config_dir .. PS .. "luarc"
    df.file_move(LUARC, LUARC .. ".disabled")
    log.msg(log.info, "lua scripts disabled")
    log.msg(log.screen, _("lua scripts will not run the next time darktable is started"))
  end
}

sm.widgets.install_update = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("section_label"){label = " "},
  dt.new_widget("label"){label = " "},
  dt.new_widget("label"){label = _("update scripts")},
  dt.new_widget("label"){label = " "},
  sm.widgets.update_script_choices,
  sm.widgets.update,
  dt.new_widget("section_label"){label = "  "},
  dt.new_widget("label"){label = " "},
  dt.new_widget("label"){label = _("add more scripts")},
  dt.new_widget("label"){label = " "},
  sm.widgets.add_scripts,
  dt.new_widget("section_label"){label = " "},
  dt.new_widget("label"){label = " "},
  dt.new_widget("label"){label = _("disable scripts")},
  dt.new_widget("label"){label = " "},
  sm.widgets.allow_disable,
  sm.widgets.disable_scripts,
  dt.new_widget("label"){label = " "},
}

-- manage the scripts

sm.widgets.folder_selector = dt.new_widget("combobox"){
  label = _("folder"),
  tooltip = _( "select the script folder"),
  selected = 1,
  changed_callback = function(self)
    if sm.run then
      pref_write("folder_selector", "integer", self.selected)
      change_folder(sm.folders[self.selected])
    end
  end,
  table.unpack(sm.translated_folders),
}

-- a script "button" consists of:
--      a button to start and stop the script
--      a label that contains the name of the script
--      a horizontal box that contains the button and the label

sm.widgets.buttons ={}
sm.widgets.labels = {}
sm.widgets.boxes = {}

for i =1, DEFAULT_BUTTONS_PER_PAGE do 
  table.insert(sm.widgets.buttons, dt.new_widget("button"){})
  table.insert(sm.widgets.labels, dt.new_widget("label"){})
  table.insert(sm.widgets.boxes, dt.new_widget("box"){ orientation = "horizontal", expand = false, fill = false, 
                                                       sm.widgets.buttons[i], sm.widgets.labels[i]})
  sm.page_status.buttons_created = sm.page_status.buttons_created + 1
end

local page_back = "<"
local page_forward = ">"

sm.widgets.page_status = dt.new_widget("label"){label = _("page") .. ":"}

sm.widgets.page_back = dt.new_widget("button"){
  label = page_back,
  clicked_callback = function(this)
    if sm.run then 
      paginate(0)
    end
  end
}

sm.widgets.page_forward = dt.new_widget("button"){
  label = page_forward,
  clicked_callback = function(this)
    if sm.run then
      paginate(1)
    end
  end
}

sm.widgets.page_control = dt.new_widget("box"){
  orientation = "horizontal",
  sm.widgets.page_back,
  sm.widgets.page_status,
  sm.widgets.page_forward,
}

sm.widgets.scripts = dt.new_widget("box"){
  orientation = vertical,
  dt.new_widget("section_label"){label = " "},
  dt.new_widget("label"){label = " "},
  dt.new_widget("label"){label = _("scripts")},
  sm.widgets.folder_selector,
  sm.widgets.page_control,
  table.unpack(sm.widgets.boxes),
}

-- configure options

sm.widgets.num_buttons = dt.new_widget("slider"){
  label = _("scripts per page"),
  tooltip = _("select number of start/stop buttons to display"),
  soft_min = MIN_BUTTONS_PER_PAGE,
  hard_min = MIN_BUTTONS_PER_PAGE,
  soft_max = MAX_BUTTONS_PER_PAGE,
  hard_max = MAX_BUTTONS_PER_PAGE,
  step = 1,
  digits = 0,
  value = 10
}

sm.widgets.change_buttons = dt.new_widget("button"){
  label = _("change number of buttons"),
  clicked_callback = function(this)
    change_num_buttons()
  end
}

sm.widgets.configure = dt.new_widget("box"){
  orientation = "vertical",
  dt.new_widget("section_label"){label = " "},
  dt.new_widget("label"){label = " "},
  dt.new_widget("label"){label = _("configuration")},
  dt.new_widget("label"){label = " "},
  sm.widgets.num_buttons,
  dt.new_widget("label"){label = " "},
  sm.widgets.change_buttons,
  dt.new_widget("label"){label = " "},
}

-- stack for the options

sm.widgets.main_stack = dt.new_widget("stack"){
  sm.widgets.install_update,
  sm.widgets.configure,
  sm.widgets.scripts,
}

sm.widgets.main_stack.h_size_fixed = false
sm.widgets.main_stack.v_size_fixed = false

-- main menu

sm.widgets.main_menu = dt.new_widget("combobox"){
  label = _("action"),
  changed_callback = function(self)
    sm.widgets.main_stack.active = self.selected
    pref_write("main_menu_action", "integer", self.selected)
    log.msg(log.debug, "saved " .. self.selected .. " for main menu")
  end,
   _("install/update scripts"), _("configure"), _("start/stop scripts")
}

-- widget for module 

sm.widgets.main_box = dt.new_widget("box"){
  sm.widgets.main_menu,
  sm.widgets.main_stack
}

script_manager_running_script = nil

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not sm.event_registered then
    dt.register_event(
      "script_manager", "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
        end
      end
    )
    sm.event_registered = true
  end
end

