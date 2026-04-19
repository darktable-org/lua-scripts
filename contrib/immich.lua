--[[
  This file is part of darktable,
  copyright (c) 2024 Giorgio Massussi

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
This plugin allows you to upload selected photos to a Immich server (https://immich.app/)
Previously exported photos will be overwritten, using unique Dartable internal ids.

Photos uploaded for the first time are automatically added to an album. It is possible to specify the name of the album in the Album title field in the module options; in the absence of the title, the roll name will be used.
In the lua options you must specify:
* the hostname of the server immich
* an api key generated in the Account settings - API Keys menu of the immich server
* a unique id identiphing the Darktable instance; this id is used as the device id uploading photos to Immich

USAGE
* install luasec and cjson for Lua 5.4 on your system

]]
local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local cjson = require "cjson.safe"
local https = require "ssl.https"
local http = require "socket.http"
local ltn12 = require "ltn12"

du.check_min_api_version("7.0.0", "immich") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

dt.gettext.bindtextdomain("immich", dt.configuration.config_dir .."/lua/locale/")

local device_id = dt.preferences.read("immich","immich_device_id","string")
if device_id == nil or device_id == "" then 
  local uuid_template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  device_id = string.gsub(uuid_template, '[xy]', function (c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format('%x', v)
  end)
end

dt.preferences.register
   ("immich","immich_server","string",
    _("Immich server"),
    _("The url of the Immich server to upload"),
    "http://localhost:2283")

dt.preferences.register
   ("immich","immich_key","string",
    _("Immich API key"),
    _("A valid Immich API key"),
    "T38JGhBrVOiWCE4tZXMoGKWoe39IIj2G8KNrfy0Eg")

dt.preferences.register
   ("immich","immich_device_id","string",
    _("Immich Device ID"),
    _("A unique ID identifying this local Darktable installation"),
    device_id)

local title_widget = dt.new_widget("entry") {
    placeholder=_("Use roll name")
}
local on_conflict_widget = dt.new_widget("combobox"){
  label = _("On conflict"),
  tooltip = _("What to do if the image has already been uploaded"),
  selected = 1,
  _("Skip image"),_("Update metadata"), _("Upload new version"), _("Upload new version, then delete previous"),
}
local widget = dt.new_widget("box") {
    orientation=horizontal,
    dt.new_widget("label"){label = _("Album Title"), tooltip = _("Album title. If not specied roll name will be used") },
    title_widget,
    on_conflict_widget
}

local function call_immich_api(method,api,body,content_type) 
  local immichserver = dt.preferences.read("immich","immich_server","string")
  local client = string.find(immichserver,"^https") ~= nil and https or http
  local headers = { }
  headers["x-api-key"] = dt.preferences.read("immich","immich_key","string")
  local source = nil
  if body == nil then
  elseif (content_type == nil or content_type == "application/json") then
    headers["Content-Type"] = "application/json"
    source = cjson.encode(body)
    headers["Content-Length"] = string.len(source)
    source = ltn12.source.string(source)
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
  
  local res_table={}
  local res, err, response_headers = client.request{
    method=method,
    url=immichserver.."/api/"..api,
    headers=headers,
    source=source,
    sink=ltn12.sink.table(res_table)
  }
  if response_headers ~= nil and response_headers["content-type"] == "application/json; charset=utf-8" then
    return cjson.decode(table.concat(res_table)), err, response_headers
  end
  return table.concat(res_table), err, response_headers
end

local function iso_exif_datetime_taken(image) 
  local yr,mo,dy,h,m,s = string.match(image.exif_datetime_taken, "(%d-):(%d-):(%d-) (%d-):(%d-):(%d+)")
  return os.date("%Y-%m-%dT%H:%M:%S",os.time{year=yr, month=mo, day=dy, hour=h, min=m, sec=s})
end

local function replace_image(image,filename,device_id,asset_id) 
  local date = iso_exif_datetime_taken(image)
  local form_data = {
    deviceAssetId=tostring(image.id),
    deviceId=device_id,
    fileCreatedAt=date,
    fileModifiedAt=date,
    assetData={
      filename=df.get_filename(filename),
      file=io.open(filename)
    }
  }
  local res,err = call_immich_api("PUT","assets/"..asset_id.."/original",form_data,"multipart/form-data")
  if err == 200 then
    return asset_id
  end
  return nil
end

local function upload_image(image,filename,device_id) 
  local date = iso_exif_datetime_taken(image)
  local form_data = {
    deviceAssetId=tostring(image.id),
    deviceId=device_id,
    fileCreatedAt=date,
    fileModifiedAt=date,
    assetData={
      filename=df.get_filename(filename),
      file=io.open(filename)
    }
  }
  local res,err = call_immich_api("POST","assets",form_data,"multipart/form-data")
  if err == 201 then
    return res.id
  end
  return nil
end

local function store_image(storage,image,format,filename,number,total,high_quality,extra_data)
  local asset_id
  if (extra_data.images_existence[tostring(image.id)]) then
    local res_search,err_search = call_immich_api("POST","search/metadata",{deviceId=extra_data.device_id,deviceAssetId=tostring(image.id),size=1})
    if (err_search == 200) then 
      if (res_search.assets.count >= 1) then
        asset_id = res_search.assets.items[1].id;
        if (on_conflict_widget.selected == 2) then
          local res_assets,err_assets = call_immich_api("PUT","assets/"..asset_id,{
            rating=image.rating,
            latitude=image.latitude,
            longitude=image.longitude,
            dateTimeOriginal=iso_exif_datetime_taken(image)
          })
        elseif (on_conflict_widget.selected == 3) then
          asset_id = upload_image(image,filename,extra_data.device_id)
        elseif (on_conflict_widget.selected == 4) then
          local old_asset_id = res_search.assets.items[1].id;
          asset_id = upload_image(image,filename,extra_data.device_id)
          if asset_id ~= nil then 
            -- local res_copy,err_copy = call_immich_api("PUT","assets/copy",{ albums=true, favorite=true, sharedLinks=true, sidecar=true, sourceId=old_asset_id, targetId=asset_id,stack=true })
            local res_delete,err_delete = call_immich_api("DELETE","assets",{  ids={ old_asset_id } })
          end
        end
      else 
        asset_id = upload_image(image,filename,extra_data.device_id)
      end
    end
  else
    asset_id = upload_image(image,filename,extra_data.device_id)
  end

  if asset_id == nil then 
    dt.print:_error("Asset id not found");
    extra_data.error = "Error uploading some image"
    return
  end

  extra_data.images_asset_id[tostring(image.id)] = asset_id;

end

local function finalize(storage,image_table,extra_data)
  -- Updates metadata

  if (#extra_data.images_to_update_metadata > 0) then 
    local job = dt.gui.create_job (_("Updating metadata "), true)
    for i,image in ipairs(extra_data.images_to_update_metadata) do
      job.percent = i/#extra_data.images_to_update_metadata
      dt.print_log(tostring(job.percent))
      local res_search,err_search = call_immich_api("POST","search/metadata",{deviceId=extra_data.device_id,deviceAssetId=tostring(image.id),size=1})
      if (err_search == 200) then 
        if (res_search.assets.count >= 1) then
          local asset_id = res_search.assets.items[1].id;
          extra_data.images_asset_id[tostring(image.id)] = asset_id;
          local res_assets,err_assets = call_immich_api("PUT","assets/"..asset_id,{
            rating=image.rating,
            latitude=image.latitude,
            longitude=image.longitude,
            dateTimeOriginal=iso_exif_datetime_taken(image)
          })
        end
      end
    end
    job.valid = false
  end

  -- calc albums

  for image_id,asset_id in pairs(extra_data.images_asset_id) do
    local album_name = title_widget.text
    local image = dt.database.get_image(tonumber(image_id));
    if (image ~= nil) then 
      local tags = dt.tags.get_tags(image)

      -- Search album name in Album tag hierarchy
      if album_name == "" then
        for i,tag in ipairs(tags) do
          if string.match(tag.name,"^Album|") and not string.match(tag.name,"|thumbnail$") then
            album_name = tag.name
            album_name = album_name:gsub("|[%d_]+%s+", "|") -- Strip initial dates from segments
            album_name = album_name:gsub("|%d+|","|") -- Strip year segment
            album_name = album_name:gsub("^Album|", "") -- Strip Album| prefix
            album_name = album_name:gsub("|"," - ") -- Convert tag separator
          end
        end
      end

      -- If none get album name from roll name
      if album_name == "" then
        for w in string.gmatch(image.path,"[^/\\]+") do
          album_name = w
        end
      end

      -- Strip initial date from album name
      album_name = album_name:gsub("^[%d_]+%s+", "")

      -- image is the album thumbnail if
      -- has immich|albumThumbnail tag
      for i,tag in ipairs(tags) do
        if tag.name == "immich|albumThumbnail" then
          extra_data.album_thumbnail[album_name] = asset_id
        end
      end
      -- or has thumbnail tag in album tag hierarchy
      for i,tag in ipairs(tags) do
        if string.find(tag.name,"^Album|") ~= nil then
          for w in string.gmatch(tag.name,"[^|]+") do
            if w == "thumbnail" then
              extra_data.album_thumbnail[album_name] = asset_id
            end
          end
        end
      end

      dt.print_log("Album name: "..album_name)
      local album_assets = extra_data.album_assets[album_name]
      if album_assets == nil then 
        album_assets = {}
        extra_data.album_assets[album_name] = album_assets 
      end
      table.insert(album_assets,asset_id)
    end
  end

  -- create/update albums

  if extra_data.album_assets ~= nil then 
    for album_name,album_assets in pairs(extra_data.album_assets) do
      local album_id = extra_data.remote_albums[album_name]
      if album_id == nil then
        local res_create,err_create = call_immich_api("POST","albums",{albumName=album_name,assetIds=album_assets})
        if err_create == 201 and res_create ~= nil then
          album_id = res_create.id
        end
      else
        call_immich_api("PUT","albums/"..album_id.."/assets",{ids=album_assets})
      end
      if album_id ~= nil and extra_data.album_thumbnail[album_name] ~= nil then
        local res,err = call_immich_api("PATCH","albums/"..album_id,{albumThumbnailAssetId=extra_data.album_thumbnail[album_name]})
      end
    end
  end
  if extra_data.error ~= nil then
    dt.print(extra_data.error)
  end
end

local function initialize(storage,format,images,high_quality,extra_data)
  extra_data.device_id = dt.preferences.read("immich","immich_device_id","string")
  if extra_data.device_id == nil then 
    extra_data.device_id = "darktable"
  else
    extra_data.device_id = "darktable_"..extra_data.device_id
  end
  local assets_ids = {}
  extra_data.images_existence = {}
  extra_data.album_assets = {}
  extra_data.album_thumbnail = {}
  extra_data.remote_albums = {}
  extra_data.images_to_update_metadata = {}
  extra_data.images_asset_id = {}

  -- search wich images already exists in server

  for i,image in ipairs(images) do
    assets_ids[i] = tostring(image.id)
    extra_data.images_existence[tostring(image.id)] = false
  end

  local res,err = call_immich_api("POST","assets/exist",{deviceAssetIds = assets_ids,deviceId = extra_data.device_id})
  if (err ~= 200) then 
    if err == 401 then
      extra_data.error = "Authentication error. Check your Immich API key in LUA settings."
    elseif res ~= nil and res.message ~= nil then
      extra_data.error = res.message
    else 
      extra_data.error = "Error contacting Immich server: HTTP "..err
    end
    return {} 
  end
  if (res.existingIds ~= nil) then 
    for i,id in ipairs(res.existingIds) do
      extra_data.images_existence[id] = true
    end
  end
  
  local res_albums, err_albums = call_immich_api("GET","albums")
 
  if err_albums == 200 then
    for _,album in ipairs(res_albums) do
      extra_data.remote_albums[album.albumName] = album.id
    end
  end
  
  if (on_conflict_widget.selected == 1) then
    -- if onconflict == skip filter out existintgs images to next phase
    local images_to_export = {}
    for i,image in ipairs(images) do
      if (not extra_data.images_existence[tostring(image.id)]) then
        table.insert(images_to_export,image)
      end
    end
    return images_to_export
  elseif (on_conflict_widget.selected == 2) then
    -- if onconflict == update metadata build table of existing images
    local images_to_export = {}
    for i,image in ipairs(images) do
      if (extra_data.images_existence[tostring(image.id)]) then
        table.insert(extra_data.images_to_update_metadata,image)
      else
        table.insert(images_to_export,image)
      end
    end
    if (#images_to_export == 0) then
      finalize(storage,images_to_export,extra_data)
    end
    return images_to_export
  end

  return nil
end

local function destroy()
  dt.destroy_storage("immich")
end

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
  author = "Giorgio Massussi"
}

script_data.destroy = destroy -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
