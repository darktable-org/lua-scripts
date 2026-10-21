--[[
  This file is part of darktable,
  copyright (c) 2024 Giorgio Massussi
  copyright (c) 2026 Colin Holzman

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
IMMICH
Upload selection to an Immich server

USAGE
This plugin allows you to upload selected photos to an Immich server (https://immich.app/)
Each image is tracked with darktable tags so re-exporting is safe and cheap:
* an "immich|asset|<id>" tag remembers the uploaded asset id for that image
* an "immich|change|<timestamp>" tag remembers the darktable change timestamp at export time
If an image's change timestamp still matches the cached tag and "Skip unchanged" is
enabled, the export is skipped locally without contacting the Immich server at all.
Otherwise the plugin looks up the cached asset on the server; if it no longer exists
there, or has been trashed, it is treated as gone and the image is uploaded fresh.
When the cached asset is still present, the "Re-export Behavior" option controls what
happens to it: delete/trash it, stack the new upload with it, both, or leave it alone
and upload the image as a new, separate asset.

Album assignment is controlled by the "Album mode" option:
* No album: exported assets are not added to any album
* Custom / Copy existing + Custom: assets are added to the album named in the "Album Title" field
* Copy albums from existing asset: assets are added to whatever albums the previous
  version of the asset already belonged to on the server
* Use Album Title: same as Custom, using the "Album Title" field as the album name
The "Album Title" field is prefilled with the folder name of the exported image when
a title-based mode is selected, but can be edited freely.

In the lua options you must specify:
* the hostname of the server immich
* an api key generated in the Account settings - API Keys menu of the immich server
The lua options also let you set the defaults for "Album mode", "Skip unchanged", and
"Re-export Behavior" shown above, so the export panel opens with your preferred choices.
An "Immich debug logging" option is also available there to log every request/response
to the darktable debug log, which is useful when troubleshooting a failed upload.

API KEY PERMISSIONS
When creating the API key on the Immich server, grant it these permissions:
* asset.read       - look up a previously uploaded asset's status
* asset.upload     - upload exported images
* asset.update     - required by the server when stacking a new upload with an existing asset
* asset.delete     - delete/trash the previous asset when "Re-export Behavior" removes it
* album.read       - find existing albums by name, and look up an asset's albums
* album.create     - create the album when it doesn't already exist
* albumAsset.create - add uploaded assets to an album
* stack.create     - stack a new upload with an existing asset

INSTALL
* install luasec, cjson, and luasocket for darktable's Lua version (currently 5.4) on your system
* if darktable can't find them (common on macOS/Windows, where it bundles its own
  Lua), set the "immich: Lua module install prefix" preference in the lua options
  to the folder containing share/lua/<ver> and lib/lua/<ver>, then restart

]]
local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local log = require "lib/dtutils.log"

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- forward declaration so store_image() (defined above its widget) resolves this
-- as an upvalue rather than a nil global
local title_widget
local album_mode_widget
local album_title_row_widget
local existing_asset_action_widget
local skip_unchanged_widget
local prefill_title_widget_from_images

local ALBUM_MODE_NONE = 1
local ALBUM_MODE_TITLE = 2
local ALBUM_MODE_COPY_EXISTING = 3
local ALBUM_MODE_COPY_AND_TITLE = 4
local ALBUM_MODE_USE_ALBUM_TITLE = 5

local EXISTING_ASSET_ACTION_DELETE = 1
local EXISTING_ASSET_ACTION_STACK = 2
local EXISTING_ASSET_ACTION_DELETE_AND_STACK = 3
local EXISTING_ASSET_ACTION_UPLOAD_NEW = 4

-- Shared between the combobox widgets and the "default value" preferences below,
-- so the option order only needs to be maintained in one place.
local ALBUM_MODE_LABELS = {
  _("No album"),
  _("Custom"),
  _("Copy albums from existing asset"),
  _("Copy existing + Custom"),
  _("Use Album Title"),
}
local EXISTING_ASSET_ACTION_LABELS = {
  _("Delete/Trash existing asset on server"),
  _("Stack with existing asset"),
  _("Delete/Trash & Stack"),
  _("Upload as new image"),
}

local function index_of_label(labels, label)
  for i,candidate in ipairs(labels) do
    if candidate == label then
      return i
    end
  end
  return nil
end

-- Immich requires a deviceId on every uploaded asset, but we no longer use it to
-- look up previously uploaded assets -- that's handled entirely by the local
-- "immich|asset|..." / "immich|change|..." darktable tags -- so a fixed value is fine.
local IMMICH_DEVICE_ID = "darktable"

-- The version (e.g. "5.4") of the Lua interpreter darktable is running -- bundled
-- on macOS/Windows, the system Lua on Linux. Derived from _VERSION rather than
-- hardcoded, so the search paths and user-facing messages keep working if
-- darktable's Lua changes.
local lua_version = _VERSION:match("(%d+%.%d+)") or "5.4"
local DEFAULT_LOG_LEVEL <const> = log.warn

local function set_log_level(level)
  local old_log_level = log.log_level()
  log.log_level(level)
  return old_log_level
end

local function restore_log_level(level)
  log.log_level(level)
end

local function image_can_skip_remote_work(image, skip_unchanged)
  if not skip_unchanged then
    return false
  end

  local cached_asset_id = nil
  local cached_change_marker = nil
  local tags = image:get_tags()
  if tags == nil then
    return false
  end

  for _,tag in ipairs(tags) do
    if tag ~= nil and tag.name ~= nil then
      if cached_asset_id == nil then
        cached_asset_id = tag.name:match("^immich%|asset%|(.-)$")
      end
      if cached_change_marker == nil then
        cached_change_marker = tag.name:match("^immich%|change%|(.-)$")
      end
      if cached_asset_id ~= nil and cached_change_marker ~= nil then
        break
      end
    end
  end

  if cached_asset_id == nil or cached_change_marker == nil then
    return false
  end

  return cached_change_marker == tostring(image.change_timestamp or "")
end

dt.preferences.register("immich", "immich_debug_logging", "bool",
  _("Immich debug logging"),
  _("Enable verbose debug messages for Immich uploads and album updates."),
  false)

log.log_level(DEFAULT_LOG_LEVEL)



-- Load optional deps defensively so a missing one yields an actionable message.
local missing = {}
local function need(modname, rock)
  local ok, mod = pcall(require, modname)
  if not ok then missing[#missing + 1] = string.format("'%s' (%s)", modname, rock) end
  return ok and mod or nil
end

local cjson = need("cjson.safe",  "lua-cjson")
local https = need("ssl.https",   "luasec")
local http  = need("socket.http", "luasocket")
local ltn12 = need("ltn12",       "luasocket")

du.check_min_api_version("7.0.0", "immich") 

local function call_immich_api(method,api,body,content_type) 
  local immichserver = dt.preferences.read("immich","immich_server","string") or ""
  if immichserver == "" then
    log.msg(log.debug, "missing Immich server URL (immich_server preference)")
    return nil, "missing_server_url", nil
  end

  local client = immichserver:match("^https") and https or http
  local headers = { }
  headers["x-api-key"] = dt.preferences.read("immich","immich_key","string") or ""
  local source = nil
  if body == nil then
  elseif (content_type == nil or content_type == "application/json") then
    headers["Content-Type"] = "application/json"
    local encoded, enc_err = cjson.encode(body)
    if not encoded then
      log.msg(log.debug, "JSON encode failed for /api/" .. tostring(api) .. ": " .. tostring(enc_err))
      return nil, "json_encode_failed", nil
    end
    headers["Content-Length"] = #encoded
    source = ltn12.source.string(encoded)
  elseif (content_type == "multipart/form-data") then 
    local boundary = "----DarktableImmichBoundary" .. math.random(1, 1e16)
    headers["Content-Type"] = "multipart/form-data; boundary="..boundary
    source = ltn12.source.empty()
    local content_length = 0
    for name,value in pairs(body) do 
      if (value.filename ~= nil) then 
        local form_data_table = {}
        if (content_length > 0) then
          table.insert(form_data_table,"")
        end
        table.insert(form_data_table, "--"..boundary)
        table.insert(form_data_table, "Content-Disposition: form-data; name=\""..name.."\"; filename=\"".. value.filename .. "\"")
        table.insert(form_data_table, "Content-Type: application/octet-stream")
        table.insert(form_data_table, "")
        table.insert(form_data_table, "")
        local form_data = table.concat(form_data_table, "\r\n")
        content_length = content_length+value.file:seek("end")+string.len(form_data)
        value.file:seek("set",0)
        source = ltn12.source.simplify(ltn12.source.cat(source,
          ltn12.source.string(form_data),
          ltn12.source.file(value.file)))
      else 
        local form_data_table = {}
        if (content_length > 0) then
          table.insert(form_data_table,"")
        end
        table.insert(form_data_table, "--"..boundary)
        table.insert(form_data_table, "Content-Disposition: form-data; name=\""..name.."\"")
        table.insert(form_data_table, "")
        table.insert(form_data_table, value)
        local form_data = table.concat(form_data_table, "\r\n")
        content_length = content_length+string.len(form_data)
        source = ltn12.source.cat(source,ltn12.source.string(form_data))
      end
    end
    content_length = content_length+6+string.len(boundary)
    source = ltn12.source.cat(source,ltn12.source.string("\r\n--"..boundary.."--"))
    headers["Content-Length"] = content_length
  end
  
  log.msg(log.debug, "request " .. method .. " /api/" .. api)
  local res_table={}
  local res, err, response_headers = client.request{
    method=method,
    url=immichserver.."/api/"..api,
    headers=headers,
    source=source,
    sink=ltn12.sink.table(res_table)
  }
  local body_text = table.concat(res_table)
  log.msg(log.debug, "response " .. tostring(err) .. " for /api/" .. api .. " -> " .. body_text)
  local ct = response_headers ~= nil and response_headers["content-type"] or ""
  if type(ct) == "string" and string.lower(ct):match("^application/json") then
    return cjson.decode(body_text), err, response_headers
  end
  return body_text, err, response_headers
end

local function url_encode(str)
  if str == nil then
    return ""
  end
  return (str:gsub("([^%w%-%_%.%~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- Looks up an album's id by its exact name; album names map to at most one
-- album, so there's nothing to look up more than once per name.
local function find_album_id_by_name(album_name)
  if album_name == nil or album_name == "" then
    return nil
  end

  local res_albums, err_albums = call_immich_api("GET", "albums?name=" .. url_encode(album_name))
  if err_albums ~= 200 or res_albums == nil or res_albums[1] == nil then
    log.msg(log.debug, "no existing album found named '" .. tostring(album_name) .. "' (HTTP " .. tostring(err_albums) .. ")")
    return nil
  end

  return res_albums[1].id
end

local function initialize(storage,format,images,high_quality,extra_data)
  local debug_enabled = dt.preferences.read("immich", "immich_debug_logging", "bool")
  extra_data.log_level = set_log_level(debug_enabled and log.debug or DEFAULT_LOG_LEVEL)

  if #missing > 0 then
    -- Stash the message for finalize: a dt.print here would be overwritten by
    -- darktable's own "no image to export" that follows the empty return.
    extra_data.error = string.format(_("immich: missing Lua libraries (luasocket, luasec, lua-cjson) for Lua %s — install them, set the 'Lua module install prefix' preference if needed, then restart"), lua_version)
    return {}   -- cancels the export
  end
  log.msg(log.debug, "initialize started for " .. tostring(#images) .. " images")
  extra_data.album_assets = {}
  extra_data.album_asset_updates = {}
  extra_data.existing_asset_action = existing_asset_action_widget ~= nil
      and existing_asset_action_widget.selected or EXISTING_ASSET_ACTION_STACK
  extra_data.skip_unchanged = skip_unchanged_widget == nil or skip_unchanged_widget.value
  extra_data.album_mode = album_mode_widget ~= nil and album_mode_widget.selected or ALBUM_MODE_NONE
  if extra_data.album_mode == ALBUM_MODE_TITLE
      or extra_data.album_mode == ALBUM_MODE_COPY_AND_TITLE then
    prefill_title_widget_from_images(images)
  end

  local all_images_skip_remote = #images > 0
  for _,image in ipairs(images) do
    if not image_can_skip_remote_work(image, extra_data.skip_unchanged) then
      all_images_skip_remote = false
      break
    end
  end
  if all_images_skip_remote then
    log.msg(log.debug, "all images matched local cache tags; skipping Immich auth and album lookups")
    return images
  end

  -- api-keys/me requires no specific permission (unlike auth/status, which needs "all"),
  -- so it validates the key and returns its granted permissions in one call.
  local key_res, key_err = call_immich_api("GET", "api-keys/me")
  if key_err == 403 then
    log.msg(log.debug, "authentication failed")
    extra_data.error = "Authentication error. Check your Immich API key in LUA settings."
    return {}
  elseif key_err ~= 200 then
    log.msg(log.debug, "authentication check returned HTTP " .. tostring(key_err))
    extra_data.error = "Error contacting Immich server: HTTP " .. key_err
    return {}
  end

  local granted_permissions = key_res ~= nil and key_res.permissions or nil
  local function has_permission(name)
    if granted_permissions == nil then
      return true -- couldn't read the permission list; don't block the export on that alone
    end
    for _,p in ipairs(granted_permissions) do
      if p == "all" or p == name then
        return true
      end
    end
    return false
  end

  -- Only require what this run's actual settings will use, not the full header list.
  local required_permissions = {"asset.read", "asset.upload"}
  if extra_data.existing_asset_action == EXISTING_ASSET_ACTION_DELETE
      or extra_data.existing_asset_action == EXISTING_ASSET_ACTION_DELETE_AND_STACK then
    table.insert(required_permissions, "asset.delete")
  end
  if extra_data.existing_asset_action == EXISTING_ASSET_ACTION_STACK
      or extra_data.existing_asset_action == EXISTING_ASSET_ACTION_DELETE_AND_STACK then
    table.insert(required_permissions, "asset.update")
    table.insert(required_permissions, "stack.create")
  end
  if extra_data.album_mode ~= ALBUM_MODE_NONE then
    table.insert(required_permissions, "album.read")
    table.insert(required_permissions, "album.create")
    table.insert(required_permissions, "albumAsset.create")
  end

  local missing_permissions = {}
  for _,permission in ipairs(required_permissions) do
    if not has_permission(permission) then
      table.insert(missing_permissions, permission)
    end
  end

  if #missing_permissions > 0 then
    local missing_list = table.concat(missing_permissions, ", ")
    log.msg(log.debug, "API key is missing required permission(s): " .. missing_list)
    extra_data.error = "Immich API key is missing required permission(s): " .. missing_list
        .. ". See the API KEY PERMISSIONS section in this script's header."
    return {}
  end

  return images
end

local function iso_exif_datetime_taken(image) 
  local exif = image ~= nil and image.exif_datetime_taken or nil
  if exif == nil or exif == "" then
    return os.date("!%Y-%m-%dT%H:%M:%S") .. "Z"
  end

  local yr,mo,dy,h,m,s = string.match(exif, "(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)")
  if yr == nil then
    return os.date("!%Y-%m-%dT%H:%M:%S") .. "Z"
  end

  local timestamp = os.time{year=yr, month=mo, day=dy, hour=h, min=m, sec=s}
  return os.date("!%Y-%m-%dT%H:%M:%S", timestamp) .. "Z"
end
local function get_asset_details(asset_id)
  if asset_id == nil or asset_id == "" then
    return nil, nil
  end

  local res_asset, err_asset = call_immich_api("GET", "assets/" .. tostring(asset_id))
  if err_asset ~= 200 or res_asset == nil then
    return nil, err_asset
  end

  return res_asset, err_asset
end

local function fetch_asset_album_ids(asset_id)
  local ids = {}
  if asset_id == nil or asset_id == "" then
    return ids
  end

  local res_albums, err_albums = call_immich_api("GET", "albums?assetId=" .. tostring(asset_id))
  if err_albums ~= 200 or res_albums == nil then
    log.msg(log.debug, "failed to look up albums for existing asset " .. tostring(asset_id) .. " with HTTP " .. tostring(err_albums))
    return ids
  end

  for _,album in ipairs(res_albums) do
    if album ~= nil and album.id ~= nil and album.id ~= "" then
      ids[#ids + 1] = album.id
    end
  end

  return ids
end

local function queue_asset_for_album_id(extra_data, album_id, asset_id)
  if album_id == nil or album_id == "" or asset_id == nil or asset_id == "" then
    return
  end

  local album_assets = extra_data.album_asset_updates[album_id]
  if album_assets == nil then
    album_assets = {}
    extra_data.album_asset_updates[album_id] = album_assets
  end
  table.insert(album_assets, asset_id)
end

local function basename_from_path(path)
  if path == nil or path == "" then
    return ""
  end

  local name = ""
  for part in string.gmatch(path, "[^/\\]+") do
    name = part
  end
  return name
end

local function default_album_name_from_images(images)
  if images == nil or #images == 0 then
    return ""
  end

  local first = images[1]
  if first == nil or first.path == nil then
    return ""
  end

  return basename_from_path(first.path)
end

prefill_title_widget_from_images = function(images)
  if title_widget == nil then
    return
  end

  if title_widget.text ~= nil and title_widget.text ~= "" then
    return
  end

  local default_name = default_album_name_from_images(images)
  if default_name ~= "" then
    title_widget.text = default_name
  end
end

local function prefill_title_widget_from_selection()
  local ok, action_images = pcall(function()
    return dt.gui.action_images
  end)
  if ok then
    prefill_title_widget_from_images(action_images)
  end
end

local function update_album_title_row_visibility()
  if album_title_row_widget == nil then
    return
  end

  local mode = album_mode_widget ~= nil and album_mode_widget.selected or ALBUM_MODE_NONE
  album_title_row_widget.visible = (mode == ALBUM_MODE_TITLE
      or mode == ALBUM_MODE_COPY_AND_TITLE)
  if album_title_row_widget.visible then
    prefill_title_widget_from_selection()
  end
end

local function upload_image(image,filename) 
  local date = iso_exif_datetime_taken(image)
  local f, open_err = io.open(filename, "rb")
  if f == nil then
    log.msg(log.debug, "failed to open export file '" .. tostring(filename) .. "': " .. tostring(open_err))
    return nil
  end
  local form_data = {
    deviceAssetId=tostring(image.id),
    deviceId=IMMICH_DEVICE_ID,
    fileCreatedAt=date,
    fileModifiedAt=date,
    assetData={
      filename=df.get_filename(filename),
      file=f
    }
  }
  log.msg(log.debug, "uploading new asset for image " .. tostring(image.id))
  local res,err = call_immich_api("POST","assets",form_data,"multipart/form-data")
  if err == 201 and res ~= nil then
    log.msg(log.debug, "upload succeeded with asset id " .. tostring(res.id))
    return res.id
  end
  return nil
end

local function delete_asset(asset_id)
  if asset_id == nil or asset_id == "" then
    return false
  end

  log.msg(log.debug, "deleting previous asset " .. tostring(asset_id))
  local _delete_res, delete_err = call_immich_api("DELETE", "assets", {ids={asset_id}, force=false})
  if delete_err == 200 or delete_err == 204 then
    log.msg(log.debug, "delete succeeded for asset " .. tostring(asset_id))
    return true
  end

  log.msg(log.debug, "delete failed for asset " .. tostring(asset_id) .. " with HTTP " .. tostring(delete_err))
  return false
end

local function create_stack_with_existing_asset(image,filename,existing_asset_id) 
  log.msg(log.debug, "uploading new asset for image " .. tostring(image.id) .. " and stacking with existing asset " .. tostring(existing_asset_id))
  local new_asset_id, upload_err = upload_image(image,filename)
  if new_asset_id == nil then
    log.msg(log.debug, "upload failed while preparing stack for image " .. tostring(image.id))
    return nil
  end

  local stack_res, stack_err = call_immich_api("POST","stacks",{assetIds={new_asset_id, existing_asset_id}})
  if stack_err == 201 then
    log.msg(log.debug, "created stack with primary asset " .. tostring(new_asset_id) .. " and existing asset " .. tostring(existing_asset_id))
    return new_asset_id
  end

  log.msg(log.debug, "stack creation failed for image " .. tostring(image.id) .. " with HTTP " .. tostring(stack_err))
  return new_asset_id
end

local function get_cached_asset_id(image)
  local tags = image.get_tags(image)
  if tags ~= nil then
    log.msg(log.debug, "checking tags for cached asset id on image " .. tostring(image.id))
    for _,tag in ipairs(tags) do
      if tag ~= nil and tag.name ~= nil then
        local asset_id = tag.name:match("^immich%|asset%|(.-)$")
        if asset_id ~= nil and asset_id ~= "" then
          log.msg(log.debug, "found cached asset id " .. tostring(asset_id) .. " in tag " .. tostring(tag.name))
          return asset_id
        end
      end
    end
  end

  local id = dt.preferences.read("immich", "asset_" .. tostring(image.id), "string")
  if id == nil or id == "" then
    log.msg(log.debug, "no cached asset id found in preferences for image " .. tostring(image.id))
    return nil
  end
  log.msg(log.debug, "found cached asset id " .. tostring(id) .. " in preferences for image " .. tostring(image.id))
  return id
end

local function get_cached_change_tag(image)
  local tags = image.get_tags(image)
  if tags ~= nil then
    log.msg(log.debug, "checking tags for cached change marker on image " .. tostring(image.id))
    for _,tag in ipairs(tags) do
      if tag ~= nil and tag.name ~= nil then
        local change_marker = tag.name:match("^immich%|change%|(.-)$")
        if change_marker ~= nil and change_marker ~= "" then
          log.msg(log.debug, "found cached change marker " .. tostring(change_marker) .. " in tag " .. tostring(tag.name))
          return change_marker
        end
      end
    end
  end

  return nil
end

local function set_cached_asset_id(image, asset_id)
  log.msg(log.debug, "writing cached asset id " .. tostring(asset_id) .. " for image " .. tostring(image.id))
  dt.preferences.write("immich", "asset_" .. tostring(image.id), "string", asset_id)

  local tag_name = "immich|asset|" .. tostring(asset_id)
  log.msg(log.debug, "ensuring tag " .. tostring(tag_name) .. " exists for image " .. tostring(image.id))
  local tag = dt.tags.find(tag_name)
  if tag == nil then
    tag = dt.tags.create(tag_name)
  end

  -- Keep only the latest Immich asset tag on the image.
  local tags = image.get_tags(image)
  if tags ~= nil then
    for _,existing_tag in ipairs(tags) do
      if existing_tag ~= nil and existing_tag.name ~= nil
          and existing_tag.name:match("^immich%|asset%|") ~= nil
          and existing_tag.name ~= tag_name then
        log.msg(log.debug, "detaching old tag " .. tostring(existing_tag.name) .. " from image " .. tostring(image.id))
        image:detach_tag(existing_tag)
      end
    end
  end

  if tag ~= nil then
    local already_attached = false
    if tags ~= nil then
      for _,existing_tag in ipairs(tags) do
        if existing_tag ~= nil and existing_tag.name == tag_name then
          already_attached = true
          break
        end
      end
    end
    if not already_attached then
      log.msg(log.debug, "attaching tag " .. tostring(tag_name) .. " to image " .. tostring(image.id))
      image:attach_tag(tag)
    else
      log.msg(log.debug, "tag " .. tostring(tag_name) .. " already attached to image " .. tostring(image.id))
    end
  else
    log.msg(log.debug, "could not create or find tag " .. tostring(tag_name) .. " for image " .. tostring(image.id))
  end
end

local function set_cached_change_tag(image, change_marker)
  if change_marker == nil or change_marker == "" then
    log.msg(log.debug, "no change marker available to cache for image " .. tostring(image.id))
    return
  end

  local tag_name = "immich|change|" .. tostring(change_marker)
  log.msg(log.debug, "ensuring change marker tag " .. tostring(tag_name) .. " exists for image " .. tostring(image.id))
  local tag = dt.tags.find(tag_name)
  if tag == nil then
    tag = dt.tags.create(tag_name)
  end

  local tags = image.get_tags(image)
  if tags ~= nil then
    for _,existing_tag in ipairs(tags) do
      if existing_tag ~= nil and existing_tag.name ~= nil
          and existing_tag.name:match("^immich%|change%|") ~= nil
          and existing_tag.name ~= tag_name then
        log.msg(log.debug, "detaching old change marker tag " .. tostring(existing_tag.name) .. " from image " .. tostring(image.id))
        image:detach_tag(existing_tag)
      end
    end
  end

  if tag ~= nil then
    local already_attached = false
    if tags ~= nil then
      for _,existing_tag in ipairs(tags) do
        if existing_tag ~= nil and existing_tag.name == tag_name then
          already_attached = true
          break
        end
      end
    end
    if not already_attached then
      log.msg(log.debug, "attaching change marker tag " .. tostring(tag_name) .. " to image " .. tostring(image.id))
      image:attach_tag(tag)
    else
      log.msg(log.debug, "change marker tag " .. tostring(tag_name) .. " already attached to image " .. tostring(image.id))
    end
  else
    log.msg(log.debug, "could not create or find change marker tag " .. tostring(tag_name) .. " for image " .. tostring(image.id))
  end
end

local function store_image(storage,image,format,filename,number,total,high_quality,extra_data)
  log.msg(log.debug, "storing image " .. tostring(image.id) .. " (" .. tostring(number) .. "/" .. tostring(total) .. ")")
  local asset_id = nil
  local replaced = false
  local existing_asset_action = extra_data.existing_asset_action or EXISTING_ASSET_ACTION_STACK
  local skip_unchanged = extra_data.skip_unchanged
  if skip_unchanged == nil then
    skip_unchanged = true
  end
  local cached_id = get_cached_asset_id(image)
  local cached_change_marker = get_cached_change_tag(image)
  local local_change_timestamp = tostring(image.change_timestamp or "")
  if skip_unchanged and cached_id ~= nil and cached_change_marker ~= nil and cached_change_marker == local_change_timestamp then
    log.msg(log.debug, "cached change marker matches local change timestamp for image " .. tostring(image.id) .. "; reusing cached asset id " .. tostring(cached_id) .. " without metadata lookup")
    asset_id = cached_id
    replaced = true
  end
  local existing_asset_id = nil
  local existing_asset = nil

  if asset_id == nil and cached_id ~= nil then
    log.msg(log.debug, "looking up cached asset id " .. tostring(cached_id) .. " for image " .. tostring(image.id))
    local asset_details, asset_err = get_asset_details(cached_id)
    if asset_details ~= nil then
      existing_asset_id = cached_id
      existing_asset = asset_details
    else
      log.msg(log.debug, "cached asset id " .. tostring(cached_id) .. " no longer exists on server (HTTP " .. tostring(asset_err) .. "); uploading new")
    end
  end

  if existing_asset_id ~= nil and existing_asset ~= nil and existing_asset.isTrashed == true then
    log.msg(log.debug, "existing remote asset is trashed; ignoring cached asset id " .. tostring(existing_asset_id) .. " and uploading a fresh copy")
    existing_asset_id = nil
    existing_asset = nil
  end

  local copied_album_ids = {}
  local requested_album_mode = extra_data.album_mode or ALBUM_MODE_NONE
  if existing_asset_id ~= nil and asset_id == nil
      and (requested_album_mode == ALBUM_MODE_COPY_EXISTING or requested_album_mode == ALBUM_MODE_COPY_AND_TITLE) then
    copied_album_ids = fetch_asset_album_ids(existing_asset_id)
    log.msg(log.debug, "found " .. tostring(#copied_album_ids) .. " album(s) on existing asset " .. tostring(existing_asset_id) .. " to copy for image " .. tostring(image.id))
  end

  if asset_id ~= nil then
    log.msg(log.debug, "using cached asset id " .. tostring(asset_id) .. " for image " .. tostring(image.id) .. "; skipping remote asset actions")
  elseif existing_asset_id ~= nil then
    if existing_asset_action == EXISTING_ASSET_ACTION_UPLOAD_NEW then
      log.msg(log.debug, "existing-asset action is upload as new image; uploading independent copy, leaving existing asset id " .. tostring(existing_asset_id) .. " untouched")
      asset_id = upload_image(image,filename)
    elseif existing_asset_action == EXISTING_ASSET_ACTION_DELETE then
      log.msg(log.debug, "existing-asset action is delete/trash; uploading replacement for existing asset id " .. tostring(existing_asset_id))
      asset_id = upload_image(image,filename)
      if asset_id ~= nil then
        delete_asset(existing_asset_id)
      end
    else
      local stacked_asset_id = create_stack_with_existing_asset(image,filename,existing_asset_id)
      if stacked_asset_id ~= nil then
        asset_id = stacked_asset_id
        replaced = false
        if existing_asset_action == EXISTING_ASSET_ACTION_DELETE_AND_STACK then
          log.msg(log.debug, "existing-asset action is delete-and-stack; deleting existing asset id " .. tostring(existing_asset_id) .. " after stacking")
          delete_asset(existing_asset_id)
        end
      else
        log.msg(log.debug, "stack creation failed for existing asset id " .. tostring(existing_asset_id) .. ", falling back to standalone upload")
        asset_id = upload_image(image,filename)
        replaced = false
        if asset_id ~= nil and existing_asset_action == EXISTING_ASSET_ACTION_DELETE_AND_STACK then
          log.msg(log.debug, "delete-and-stack fallback path; deleting existing asset id " .. tostring(existing_asset_id) .. " after standalone upload")
          delete_asset(existing_asset_id)
        end
      end
    end
  else
    log.msg(log.debug, "no existing remote asset found for image " .. tostring(image.id) .. ", uploading new")
    asset_id = upload_image(image,filename)
  end

  if asset_id == nil then 
    log.msg(log.debug, "upload failed for image " .. tostring(image.id))
    extra_data.error = "Error uploading some image"
    return
  end

  if not replaced then
    log.msg(log.debug, "caching asset id " .. tostring(asset_id) .. " for image " .. tostring(image.id))
    set_cached_change_tag(image, image.change_timestamp)
    set_cached_asset_id(image, asset_id)
  end

  if not replaced then
    local album_mode = extra_data.album_mode or ALBUM_MODE_NONE
    if album_mode == ALBUM_MODE_TITLE
        or album_mode == ALBUM_MODE_COPY_AND_TITLE
        or album_mode == ALBUM_MODE_USE_ALBUM_TITLE then
      local album_name
      if album_mode == ALBUM_MODE_USE_ALBUM_TITLE then
        -- Uses darktable's own folder name for the image rather than the manual
        -- title input box, which is hidden for this mode.
        album_name = basename_from_path(image.path)
      else
        album_name = title_widget.text or ""
      end
      if album_name == "" then
        log.msg(log.debug, "album mode requires an album name but none was available; skipping album assignment")
      else
        log.msg(log.debug, "album mode resolved album name '" .. tostring(album_name) .. "' for image " .. tostring(image.id))
        local album_assets = extra_data.album_assets[album_name]
        if album_assets == nil then
          album_assets = {}
          extra_data.album_assets[album_name] = album_assets
        end
        table.insert(album_assets,asset_id)
        log.msg(log.debug, "queued asset " .. tostring(asset_id) .. " for album " .. tostring(album_name))
      end
    end

    if album_mode == ALBUM_MODE_COPY_EXISTING or album_mode == ALBUM_MODE_COPY_AND_TITLE then
      if #copied_album_ids == 0 then
        log.msg(log.debug, "album copy mode selected but no albums found on existing asset for image " .. tostring(image.id))
      else
        for _,album_id in ipairs(copied_album_ids) do
          queue_asset_for_album_id(extra_data, album_id, asset_id)
          log.msg(log.debug, "queued asset " .. tostring(asset_id) .. " for existing album id " .. tostring(album_id))
        end
      end
    else
      log.msg(log.debug, "album mode is none; skipping album assignment for image " .. tostring(image.id))
    end
  end
end

local function finalize(storage,image_table,extra_data)
  if extra_data.album_assets ~= nil then 
    local album_count = 0
    for _ in pairs(extra_data.album_assets) do
      album_count = album_count + 1
    end
    log.msg(log.debug, "finalizing album updates for " .. tostring(album_count) .. " album(s)")
    for album_name,album_assets in pairs(extra_data.album_assets) do
      local album_id = find_album_id_by_name(album_name)
      if album_id == nil then
        log.msg(log.debug, "creating new album: " .. album_name)
        call_immich_api("POST","albums",{albumName=album_name,assetIds=album_assets})
      else
        log.msg(log.debug, "adding assets to album: "..album_name)
        call_immich_api("PUT","albums/"..album_id.."/assets",{ids=album_assets})
      end
    end
  end
  if extra_data.album_asset_updates ~= nil then
    local album_update_count = 0
    for _ in pairs(extra_data.album_asset_updates) do
      album_update_count = album_update_count + 1
    end
    log.msg(log.debug, "finalizing copy-to-existing-album updates for " .. tostring(album_update_count) .. " album(s)")
    for album_id,album_assets in pairs(extra_data.album_asset_updates) do
      log.msg(log.debug, "adding assets to existing album id: " .. tostring(album_id))
      call_immich_api("PUT","albums/"..album_id.."/assets",{ids=album_assets})
    end
  end
  if extra_data.error ~= nil then
    log.msg(log.debug, "finalizing with error: " .. tostring(extra_data.error))
    log.msg(log.error, extra_data.error)
  end
  restore_log_level(extra_data.log_level)
end

local function destroy()
  dt.destroy_storage("immich")
end

dt.preferences.register(
   "immich","immich_server","string",
    _("Immich server"),
    _("The url of the Immich server to upload"),
    "http://localhost:2283")

dt.preferences.register(
   "immich","immich_key","string",
    _("Immich API key"),
    _("A valid Immich API key"),
    "<your api key>")

dt.preferences.register(
   "immich","default_album_mode","enum",
    _("Default album mode"),
    _("Default value of the 'Album mode' export option."),
    ALBUM_MODE_LABELS[ALBUM_MODE_COPY_EXISTING],
    table.unpack(ALBUM_MODE_LABELS))

dt.preferences.register(
   "immich","default_skip_unchanged","bool",
    _("Default: Skip unchanged"),
    _("Default value of the 'Skip unchanged' export option."),
    true)

dt.preferences.register(
   "immich","default_existing_asset_action","enum",
    _("Default re-export behavior"),
    _("Default value of the 'Re-export Behavior' export option."),
    EXISTING_ASSET_ACTION_LABELS[EXISTING_ASSET_ACTION_DELETE_AND_STACK],
    table.unpack(EXISTING_ASSET_ACTION_LABELS))

local default_album_mode = index_of_label(ALBUM_MODE_LABELS,
    dt.preferences.read("immich", "default_album_mode", "enum")) or ALBUM_MODE_COPY_EXISTING
local default_existing_asset_action = index_of_label(EXISTING_ASSET_ACTION_LABELS,
    dt.preferences.read("immich", "default_existing_asset_action", "enum")) or EXISTING_ASSET_ACTION_DELETE_AND_STACK

title_widget = dt.new_widget("entry") {
    placeholder=_("No album")
}
album_mode_widget = dt.new_widget("combobox") {
  label = _("Album mode"),
  tooltip = _("Choose how exported assets are assigned to albums."),
  selected = default_album_mode,
  changed_callback = function(_)
    update_album_title_row_visibility()
  end,
  table.unpack(ALBUM_MODE_LABELS)
}
skip_unchanged_widget = dt.new_widget("check_button") {
  label = _("Skip unchanged"),
  tooltip = _("Skip contacting the Immich server entirely when an image hasn't changed since its last export."),
  value = dt.preferences.read("immich", "default_skip_unchanged", "bool")
}
existing_asset_action_widget = dt.new_widget("combobox") {
  label = _("Re-export Behavior"),
  tooltip = _("Choose what happens to the previous asset on the server when a changed image is re-exported."),
  selected = default_existing_asset_action,
  table.unpack(EXISTING_ASSET_ACTION_LABELS)
}
album_title_row_widget = dt.new_widget("box") {
    orientation=horizontal,
  dt.new_widget("label"){label = _("Album Title"), tooltip = _("Set the album title on Immich for the exported images.") },
    title_widget
}

local widget = dt.new_widget("box") {
  orientation=vertical,
  album_mode_widget,
  album_title_row_widget,
  skip_unchanged_widget,
  existing_asset_action_widget
}

update_album_title_row_visibility()

dt.register_storage("immich",_("immich"),
    store_image,
    finalize,
    nil,
    initialize,
    widget)

local script_data = {}

script_data.metadata = {
  name = "immich",
  purpose = _("upload all selected images to Immich server"),
  author = "Daniel N. Hansten"
}

script_data.destroy = destroy -- function to destroy the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them completely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
