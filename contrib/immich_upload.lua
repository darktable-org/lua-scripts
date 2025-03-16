--[[
    copyright (c) 2024 Guillaume Godin <godin.guillaume@gmail.com>

    This program is a free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
  immich_upload.lua - Immich storage for darktable

  Immich is a self-hosted photo management service that provides features similar to Google Photos.
  This script adds a new storage option to upload exported photos directly to an Immich server without keeping a local copy.
  It uses the immich-cli tool to upload the images. It has 2 configurable preferences:
  * Immich server URL (default: http://localhost:2283)
  * Immich API key (default: empty)
  The script will appear as "Immich Upload" in the export module storage list. It can be run in
  dry-run mode to test the upload without actually sending files.

  ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
  * immich-cli (https://immich.app/docs/features/command-line-interface/)

  USAGE
    -- Configuration
    1. Install immich-cli on your system
    2. Configure your Immich server URL and API key in darktable preferences
    3. The script will appear as "Immich Upload" in the export module storage list

    -- Uploading images
    1. Select images to export
    2. Choose "Immich Upload" as the storage option in the export module
    3. Optionally enter an album name
    4. Enable dry run mode if you want to test without uploading
    5. Start the export process

  BUGS, COMMENTS, SUGGESTIONS
  * Send to Guillaume Godin, godin.guillaume@gmail.com

  CHANGES
  * 2025-03-16 - Initial version
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

-- Module namespace for preferences
local namespace = 'module_immich'

-- Check minimum API version. This was only tested on darktable 5 with the 9.4.0 API.
du.check_min_api_version("9.4.0", "immich") 

-- Localization
local function _(msgid)
  return gettext(msgid)
end

-- Script metadata
local script_data = {}
script_data.metadata = {
  name = _("immich"),
  purpose = _("upload images to Immich server"),
  author = "your name",
  help = "https://github.com/immich-app/immich"
}

-- Check if immich-cli is available
local function check_immich_cli()
  local immich_cli = df.check_if_bin_exists("immich")
  log.msg(log.debug, "checking for immich-cli at: ", immich_cli)
  
  if not immich_cli then
    local err_msg = "immich-cli not found. Please install it first."
    log.msg(log.error, err_msg)
    dt.print(_(err_msg))
    return false
  end
  return true
end

-- Show export progress
local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  dt.print(string.format(_("exporting to Immich: %d / %d"), number, total))
end

-- Preferences namespace and keys
local PREF_SERVER_URL = "server_url"
local PREF_AUTH_TOKEN = "auth_token"

-- Set default preferences if they don't exist
if dt.preferences.read(namespace, PREF_SERVER_URL, "string") == nil then
  dt.preferences.write(namespace, PREF_SERVER_URL, "string", "http://localhost:2283")
end

if dt.preferences.read(namespace, PREF_AUTH_TOKEN, "string") == nil then
  dt.preferences.write(namespace, PREF_AUTH_TOKEN, "string", "")
end

-- Add preferences to Darktable's preferences dialog
dt.preferences.register(namespace,
  PREF_SERVER_URL,
  "string",
  _("Immich: Server URL"),
  _("The URL of your Immich server"),
  "http://localhost:2283"
)

dt.preferences.register(namespace,
  PREF_AUTH_TOKEN,
  "string",
  _("Immich: API Key"),
  _("Your Immich API key for authentication"),
  ""
)

-- Storage widget for export dialog
local album_name = ""  -- Will store the album name
local dry_run = false  -- Will store the dry-run state
local album_entry = nil  -- Will store reference to the entry widget

local immich_widget = dt.new_widget("box") {
  orientation = "vertical",
  
  dt.new_widget("entry"){
    tooltip = _("Enter album name (leave empty for no album)"),
    placeholder = _("Album name (optional)"),
    editable = true,
    text = album_name
  },

  dt.new_widget("check_button"){
    label = _("Dry run"),
    tooltip = _("Test the upload without actually sending files"),
    value = dry_run,
    clicked_callback = function(widget)
      dry_run = widget.value
      log.msg(log.debug, "dry run changed to: ", dry_run)
    end
  }
}

-- Store reference to entry widget for later use
album_entry = immich_widget[1]

-- Function to login to Immich
local function immich_login(server_url, auth_token)
  local login_command = string.format(
    "immich login %s %s",
    server_url,
    auth_token
  )
  
  log.msg(log.debug, "executing login command: ", login_command)
  
  local result = dtsys.external_command(login_command)
  if not result then
    local err_msg = "Failed to login to Immich"
    log.msg(log.error, err_msg)
    dt.print(_(err_msg))
    return false
  end
  
  log.msg(log.debug, "login successful")
  return true
end

-- Initialize function - called before export begins
local function initialize(storage, format, images, high_quality, extra_data)
  log.msg(log.debug, "initializing Immich export")
  
  -- Get settings
  local server_url = dt.preferences.read(namespace, PREF_SERVER_URL, "string")
  local auth_token = dt.preferences.read(namespace, PREF_AUTH_TOKEN, "string")
  
  log.msg(log.debug, "server URL: ", server_url)
  log.msg(log.debug, "auth token length: ", #auth_token)

  -- Validate settings
  if server_url == "" or auth_token == "" then
    local err_msg = "Please configure Immich server URL and API key in preferences"
    log.msg(log.error, err_msg)
    dt.print(_(err_msg))
    return nil
  end

  -- Check for immich-cli before attempting login
  if not check_immich_cli() then
    return nil
  end

  -- Try to login
  if not immich_login(server_url, auth_token) then
    return nil
  end

  -- Get current values from widgets
  album_name = album_entry.text  -- Get text directly from stored widget reference
  log.msg(log.debug, "got album name from widget: ", album_name)

  -- Store values in extra_data for use in store function
  extra_data.album_name = album_name
  extra_data.dry_run = dry_run
  
  log.msg(log.debug, "initialization complete. Album: ", album_name, " Dry run: ", dry_run)

  -- Return the images table unchanged
  return images
end

-- Add after the requires
local status_dir = dt.configuration.tmp_dir .. "/immich_status"
df.mkdir(status_dir)  -- Create status directory if it doesn't exist

-- Store function - called for each exported image
local function store(storage, image, format, filename, number, total, high_quality, extra_data)
  log.msg(log.debug, string.format("processing image %d/%d: %s", number, total, filename))
  
  -- Show progress
  dt.print(string.format(_("uploading to Immich: %d / %d"), number, total))

  -- Build base upload command
  local upload_command = "immich upload --delete --concurrency 1"
  
  -- Add dry-run if enabled
  if extra_data.dry_run then
    upload_command = upload_command .. " --dry-run"
    log.msg(log.debug, "dry run mode enabled")
  end

  -- Add album if specified
  if extra_data.album_name and extra_data.album_name ~= "" then
    upload_command = upload_command .. " --album-name \"" .. extra_data.album_name .. "\""
    log.msg(log.debug, "using album: ", extra_data.album_name)
  end

  -- Add filename
  upload_command = upload_command .. " \"" .. filename .. "\""
  
  -- Create a unique status file name
  local status_file = status_dir .. "/" .. df.get_basename(filename) .. ".status"
  
  -- Modify upload command to write status
  upload_command = string.format(
    "(%s && echo 'success' > '%s' || echo 'failed' > '%s') > /dev/null 2>&1 & disown",
    upload_command,
    status_file,
    status_file
  )
  
  -- Log the full command
  log.msg(log.debug, "executing command: ", upload_command)
  
  -- Execute upload
  local result = dtsys.external_command(upload_command)
  if not result then
    local err_msg = "Failed to launch upload: " .. filename
    log.msg(log.error, err_msg)
    dt.print(_(err_msg))
    return
  end
  
  -- Store status file path in extra_data for checking in finalize
  if not extra_data.status_files then
    extra_data.status_files = {}
  end
  extra_data.status_files[filename] = status_file
  
  log.msg(log.debug, "upload started for: ", filename)
  dt.print(_("Upload started for: " .. filename))
end

-- Modified finalize function to check upload status
local function finalize(storage, image_table, extra_data)
  if not extra_data.status_files then
    dt.print(_("No uploads were started"))
    return
  end

  -- Wait up to 5 seconds for uploads to complete
  local start_time = os.time()
  local wait_time = 5 
  
  local success_count = 0
  local failed_files = {}
  local pending_files = {}

  while (os.time() - start_time) < wait_time do
    pending_files = {}
    success_count = 0
    failed_files = {}

    -- Check status of each upload
    for filename, status_file in pairs(extra_data.status_files) do
      if df.check_if_file_exists(status_file) then
        local f = io.open(status_file, "r")
        if f then
          local status = f:read("*all")
          f:close()
          os.remove(status_file)
          
          if status:match("success") then
            success_count = success_count + 1
          else
            table.insert(failed_files, filename)
          end
        end
      else
        table.insert(pending_files, filename)
      end
    end

    -- If no pending files, we can stop waiting
    if #pending_files == 0 then
      break
    end
  end

  -- Report results
  local msg = string.format(
    "Upload complete: %d successful",
    success_count
  )
  
  if #failed_files > 0 then
    msg = msg .. string.format("\nFailed uploads: %d", #failed_files)
    for _, file in ipairs(failed_files) do
      log.msg(log.error, "Failed to upload: ", file)
    end
  end
  
  if #pending_files > 0 then
    msg = msg .. string.format("\nStill uploading: %d", #pending_files)
    for _, file in ipairs(pending_files) do
      log.msg(log.info, "Still uploading: ", file)
    end
  end

  log.msg(log.debug, msg)
  dt.print(_(msg))
  
  -- Clean up status directory if empty
  if #pending_files == 0 then
    os.remove(status_dir)
  end
end

-- Register the storage with the new functions
dt.register_storage(
  namespace,
  _("Immich Upload"),
  store,
  finalize,
  nil,
  initialize,
  immich_widget
)

-- Cleanup function
local function destroy()
  dt.destroy_storage(namespace)
end

script_data.destroy = destroy

return script_data 