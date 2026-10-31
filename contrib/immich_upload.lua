--[[
    copyright (c) 2024 Guillaume Godin <godin.guillaume@gmail.com>
    copyright (c) 2026 Colin Holzman <colin@holzman.ch>

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
  This script adds a new storage option that uploads exported photos to an Immich server using the
  immich command line interface (immich-cli). Because the upload is delegated to the CLI, the script
  stays compatible across Immich API versions as long as the installed CLI is kept up to date.

  It has these configurable preferences:
  * Immich server URL (default: http://localhost:2283)
  * Immich API key (default: empty)
  * immich-cli location (default: looked up on the PATH; set this if darktable can't find it,
    which is common on macOS/Windows where the GUI doesn't inherit your shell PATH)

  The script appears as "Immich Upload" in the export module storage list. A dry-run mode is
  available to test the upload without sending files.

  ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
  * immich-cli (https://immich.app/docs/features/command-line-interface/)

  USAGE
    -- Configuration
    1. Install immich-cli on your system
    2. Configure your Immich server URL and API key in darktable preferences
    3. If darktable reports it can't find immich-cli, set its location in the preferences too
    4. The script will appear as "Immich Upload" in the export module storage list

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
  * 2026-06-25 - Upload all images in a single batch from finalize() instead of launching a
                 detached background process per image (fixes the post-export crash and the
                 status-file race); add an immich-cli location preference; quote all shell
                 arguments; check command exit codes correctly.
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"
local dtsys = require "lib/dtutils.system"
local gettext = dt.gettext.gettext

-- Module namespace for preferences
local namespace = 'immich_upload'

-- Check minimum API version. This was only tested on darktable 5 with the 9.4.0 API.
du.check_min_api_version("9.4.0", "immich_upload")

-- Localization
local function _(msgid)
  return gettext(msgid)
end

-- Script metadata
local script_data = {}
script_data.metadata = {
  name = _("immich upload"),
  purpose = _("upload images to an Immich server with immich-cli"),
  author = "Colin Holzman",
  help = "https://immich.app/docs/features/command-line-interface/"
}

-- Preferences keys
local PREF_SERVER_URL = "server_url"
local PREF_AUTH_TOKEN = "auth_token"
local PREF_IMMICH_CLI = "immich_cli_path"
-- basename used when falling back to a PATH search
local IMMICH_EXECUTABLE = "immich"

-- Resolve the immich-cli binary: prefer the user-configured location, otherwise search the PATH
-- and the usual install dirs. Returns the resolved path, or false if it can't be found.
local function resolve_immich_cli()
  local configured = dt.preferences.read(namespace, PREF_IMMICH_CLI, "string")
  if configured and configured ~= "" then
    local found = df.check_if_bin_exists(configured)
    if found then return found end
  end
  return df.check_if_bin_exists(IMMICH_EXECUTABLE)
end

-- immich-cli is a Node script (#!/usr/bin/env node) that needs `node` on PATH, and node is
-- installed in the same directory as immich. A GUI-launched darktable can start with a minimal
-- PATH that excludes that directory -- notably on macOS (Dock/Finder strip the Homebrew path),
-- and possibly for npm-global/nvm installs on Linux -- so immich's shebang can't find node.
-- Return a POSIX shell prefix that prepends immich-cli's own directory to PATH; this covers both
-- macOS and Linux. Empty on Windows, whose GUI launches inherit the system PATH and whose shell
-- doesn't accept the `PATH=value command` syntax anyway, and empty when the binary has no
-- directory part (it was found on PATH already, so node almost certainly is too).
local function path_prefix(immich_cli)
  if dt.configuration.running_os == "windows" then
    return ""
  end
  local dir = df.get_path(immich_cli)
  if not dir or dir == "" then
    return ""
  end
  return "PATH=" .. df.sanitize_filename(dir) .. ':"$PATH" '
end

-- Add preferences to darktable's preferences dialog
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

-- The immich-cli location. A plain string field (rather than a file chooser) so darktable's
-- double-click-to-reset-to-default works. This is what lets users on macOS/Windows point
-- darktable at the CLI when it isn't on the GUI's PATH.
dt.preferences.register(namespace,
  PREF_IMMICH_CLI,
  "string",
  _("Immich: immich-cli location"),
  _("Path to the immich-cli executable, or just \"immich\" to search the PATH. Requires restart to take effect."),
  IMMICH_EXECUTABLE
)

-- Storage widget for the export dialog
local dry_run = false
local album_entry = dt.new_widget("entry"){
  tooltip = _("Enter album name (leave empty for no album)"),
  placeholder = _("Album name (optional)"),
  editable = true,
  text = ""
}

local immich_widget = dt.new_widget("box") {
  orientation = "vertical",
  album_entry,
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

-- Log in to Immich. immich-cli persists the credentials (auth.yml) so a single login here covers
-- the upload performed later in finalize().
local function immich_login(immich_cli, server_url, auth_token)
  local login_command = path_prefix(immich_cli) .. string.format("%s login %s %s",
    df.sanitize_filename(immich_cli),
    df.sanitize_filename(server_url),
    df.sanitize_filename(auth_token))

  log.msg(log.debug, "executing login command")

  if dtsys.external_command(login_command) ~= 0 then
    log.msg(log.error, "failed to login to Immich")
    return false
  end

  log.msg(log.debug, "login successful")
  return true
end

-- Initialize function - called before export begins
local function initialize(storage, format, images, high_quality, extra_data)
  log.msg(log.debug, "initializing Immich export")

  local server_url = dt.preferences.read(namespace, PREF_SERVER_URL, "string")
  local auth_token = dt.preferences.read(namespace, PREF_AUTH_TOKEN, "string")

  -- Validate settings. Errors are stashed in extra_data.error and surfaced in finalize(): a
  -- dt.print() here would be overwritten by darktable's own "no image to export" message that
  -- follows the empty return, leaving the user with a misleading "nothing to upload".
  if server_url == "" or auth_token == "" then
    log.msg(log.error, "server URL or API key not configured")
    extra_data.error = _("Immich: configure the server URL and API key in preferences")
    return {}
  end

  -- Locate immich-cli before attempting to log in
  local immich_cli = resolve_immich_cli()
  if not immich_cli then
    log.msg(log.error, "immich-cli not found")
    extra_data.error = _("Immich: immich-cli not found. Install it, or set its location in preferences, then restart.")
    return {}
  end

  -- Log in once for the whole export
  if not immich_login(immich_cli, server_url, auth_token) then
    extra_data.error = _("Immich: login failed. Check the server URL and API key.")
    return {}
  end

  -- Stash everything finalize() needs
  extra_data.immich_cli = immich_cli
  extra_data.album_name = album_entry.text
  extra_data.dry_run = dry_run

  log.msg(log.debug, "initialization complete. album: ", extra_data.album_name, " dry run: ", tostring(dry_run))

  return images
end

-- Store function - called for each exported image. The exported files persist until finalize(),
-- so here we only report progress; the actual upload is a single batch call in finalize().
local function store(storage, image, format, filename, number, total, high_quality, extra_data)
  dt.print(string.format(_("exporting for Immich: %d / %d"), number, total))
  log.msg(log.debug, string.format("exported image %d/%d: %s", number, total, filename))
end

-- Finalize function - upload every exported image in one immich-cli invocation
local function finalize(storage, image_table, extra_data)
  -- Surface any error stashed during initialize(). finalize() runs after darktable's own
  -- "no image to export" message, so printing here is what the user actually sees.
  if extra_data.error then
    dt.print(extra_data.error)
    return
  end

  -- Build the list of exported files (image_table maps image -> exported file path)
  local files = {}
  for _, exported in pairs(image_table) do
    files[#files + 1] = df.sanitize_filename(exported)
  end

  if #files == 0 then
    dt.print(_("Immich: no images were exported"))
    return
  end

  -- Assemble a single upload command
  local command = path_prefix(extra_data.immich_cli) .. df.sanitize_filename(extra_data.immich_cli) .. " upload"
  if extra_data.dry_run then
    command = command .. " --dry-run"
  end
  if extra_data.album_name and extra_data.album_name ~= "" then
    command = command .. " --album-name " .. df.sanitize_filename(extra_data.album_name)
  end
  command = command .. " " .. table.concat(files, " ")

  dt.print(string.format(_("uploading %d image(s) to Immich..."), #files))
  log.msg(log.debug, "executing upload command for ", #files, " file(s)")

  if dtsys.external_command(command) ~= 0 then
    log.msg(log.error, "immich-cli upload failed")
    dt.print(_("Immich: upload failed"))
    return
  end

  if extra_data.dry_run then
    dt.print(string.format(_("Immich dry run complete: %d image(s) checked"), #files))
  else
    dt.print(string.format(_("Immich upload complete: %d image(s) uploaded"), #files))
  end
end

-- Register the storage
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
