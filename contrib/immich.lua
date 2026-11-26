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

local immich_metadata_key = "x-darktable-immich-sync:v1"

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

local sync_albums_widget
local on_conflict_widget
local sync_album_assets_check
local new_album_name_widget

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

local function upload_image(image,filename,device_id) 
  if not df.check_if_file_exists(filename) then
    filename = df.get_path(filename)..image.filename
  end
  dt.print_log(filename)
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

local function get_albums_root() 
  local albums_root = dt.preferences.read("immich","immich_server","string")
  albums_root = albums_root:gsub("^https?://", "") .. "|albums|"
  return albums_root
end

local function create_album_tag(album,albums_root) 
  local album_name = album.albumName
  if album.startDate ~= nil then 
    local date_prefix = string.gsub(string.sub(album.startDate,1,10),"%-","").." "
    album_name = string.gsub(album_name," %- ","|")
    album_name = albums_root..string.sub(album.startDate,1,4) .. "|" .. album_name .. " [" .. album.id .. "]"
    album_name = string.gsub(album_name, "|([^|]*)$", "|" .. date_prefix .. "%1")
  else 
    album_name = string.gsub(album_name," %- ","|")
    album_name = albums_root.. "|" .. album_name .. " [" .. album.id .. "]"
  end
  return dt.tags.create(album_name)
end

-- Synchronize albums and album assets with Immich server. Returns two tables: album_tags_by_id and albums_by_tag
-- read all albums from immich server
-- creates corresponding tags in dt
-- if sync_assets=true: 
-- - if immich version is < 3 migrate immich v2 deviceId/deviceAssetId to immich metadata (x-darktable-immich-sync:v1)
-- - add a darktable tag with immich id to the assets (darktable\plugins\immich\[immich_server]\uuid\[immich_id])
-- - attach album tag to all images in dt that are in immich albums and remove it from images that are not in immich album
local function sync_albums(device_id,sync_assets,albums_root) 
  local albumsmatch = "^"..albums_root
  local uuid_tag_match = "^darktable\\|plugins\\|immich\\|"..dt.preferences.read("immich","immich_server","string").."\\|uuid";
  local album_tags_by_id = {}
  local albums_by_tag = {}
  local count=4
  for i,tag in ipairs(dt.tags) do
    if string.match(tag.name,albumsmatch) then
      local album_id = string.match(tag.name,"%[([%w%-]+)%]")
      if album_id ~= nil then
        album_tags_by_id[album_id] = tag
      end
    end
  end

  local res_server_version,err_server_version = call_immich_api("GET","server/version")
  local v3 = res_server_version ~= nil and res_server_version.major ~= nil and res_server_version.major >= 3
  local v3_2 = v3 and res_server_version.minor >= 2

  dt.print_log("Immich server version: "..res_server_version.major.."."..res_server_version.minor)

  -- get albums from Immich server
  local res_albums, err_albums = call_immich_api("GET","albums")
 
  if err_albums == 200 then
    local remote_albums = {} -- table of remote albums by id
    local job = dt.gui.create_job (_("Synchronizing albums tags..."), true)
    -- for each remote album...
    for i,album in ipairs(res_albums) do
      job.percent = i/#res_albums
      remote_albums[album.id] = album
      -- check if we have a immich album tag for this album, if not create it
      album.tag = album_tags_by_id[album.id]
      if album.tag == nil then
        album.tag = create_album_tag(album.albumName,albums_root)
      end
      albums_by_tag[album.tag.name] = album

      -- if sync_assets is true...
      if sync_assets then
        -- get album assets from Immich server; use different API calls depending on Immich server version
        local album_assets = nil
        if v3_2 then
          -- v3.2 API call
          local res_asset_search, err_asset_search = call_immich_api("POST","search/metadata",{filter={albumIds={all={album.id}}}})
          if err_asset_search == 200 then 
            album_assets = res_asset_search.assets.items
          end
        elseif v3 then
          -- v3 API call
          local res_asset_search, err_asset_search = call_immich_api("POST","search/metadata",{albumIds={album.id}})
          if err_asset_search == 200 then 
            album_assets = res_asset_search.assets.items
          end
        else 
          -- v2 API call
          local res_album_assets, err_album_assets = call_immich_api("GET","albums/"..album.id.."/assets")
          if err_album_assets == 200 then 
            album_assets = res_album_assets
          end
        end
        -- get darktable images tagged with immich album tag
        local tag_images = dt.tags.get_tagged_images(album.tag)
        local tag_image_ids = {}
        for _,image in ipairs(tag_images) do
          tag_image_ids[tostring(image.id)] = image
        end
        if album_assets ~= nil then 
          -- for each asset in the immich album...
          for _,album_asset in ipairs(album_assets) do
            -- retrieve darktable image id from immich
            -- pre v3 assets have deviceAssetId, v3 assets don't have it, so we need to get the image id from the metadata
            local image_id = nil
            if album_asset.deviceId == device_id then
              image_id = tonumber(album_asset.deviceAssetId)
            elseif album_asset.deviceId == nil then 
              local res_metadata, err_metadata = call_immich_api("GET","assets/"..album_asset.id.."/metadata")
              for _,asset_metadata in ipairs(res_metadata) do
                if (asset_metadata.key == immich_metadata_key and asset_metadata.value.device_id == device_id) then
                  image_id = tonumber(asset_metadata.value.image_id)
                end
              end
            end
            -- get dt image corresponding to immich asset
            local image = dt.database.get_image(image_id)
            -- if exists an image with the same dt id as the immich asset...
            if image ~= nil then 
              -- if immich asset has deviceId (v2) update immich metadata (for v3 migration)
              if (album_asset.deviceId ~= nil) then
                dt.print_log("Updating metadata");
                local _, err_put_metadata = call_immich_api("PUT","assets/"..album_asset.id.."/metadata",{items={{key=immich_metadata_key,value={image_id=image.id,device_id=device_id}}}})
                dt.print_log(err_put_metadata);
              end 

              -- calc dt uuid tag corresponding to immich asset id
              local uuid_tag_name = string.format("darktable|plugins|immich|%s|uuid|%s", dt.preferences.read("immich","immich_server","string"), album_asset.id);
              -- remove other uuid immich tags from the image (if the imahe was created by cloning image in dt)
              dt.print_log(uuid_tag_name);
              local image_tags = dt.tags.get_tags(image);
              for i,tag in ipairs(image_tags) do
                if (tag.name ~= uuid_tag_name and string.match(tag.name,uuid_tag_match)) then
                  dt.tags.detach(tag,image);
                end
              end
              -- create new uuid immich tag and attach it to the image
              dt.print_log("Adding new tag")
              local uuid_tag = dt.tags.create(uuid_tag_name);
              dt.tags.attach(uuid_tag,image);
              count = count - 1;
              if (count == 0) then 
                job.valid = false
                return album_tags_by_id,albums_by_tag
              end 
            end

            -- Sync immich album tag 
            if tag_image_ids[image_id] == nil then
              -- if asset is in the immich album and in dt has no tag, then attach the tag
              if image ~= nil then
                dt.tags.attach(album.tag,image)
              end
            else
              -- if asset is in the immich album and in dt has the album tag, remove from the table
              tag_image_ids[album_asset.deviceAssetId] = nil
            end
          end
          -- now in the table tag_images_ids remains the assets that are in the dt but not in immich album 
          for image_id,image in pairs(tag_image_ids) do
            -- remove the tag from image in dt
            dt.tags.detach(album.tag,image)
          end
        end
      end
    end
    job.valid = false
  end

  return album_tags_by_id,albums_by_tag
end

local function migratev3(device_id,albums_root) 
  local albumsmatch = "^"..albums_root
  local uuid_tag_match = "^darktable\\|plugins\\|immich\\|"..dt.preferences.read("immich","immich_server","string").."\\|uuid";

  local job = dt.gui.create_job (_("Migrating images..."), true)
  local selected_images = dt.gui.selection()
  for i,image in ipairs(selected_images) do
    job.percent = i/#selected_images
    local res_search,err_search = call_immich_api("POST","search/metadata",{deviceId=device_id,deviceAssetId=tostring(image.id),size=1})
    if (err_search == 200) then 
      if (res_search.assets.count >= 1) then
        local asset_id = res_search.assets.items[1].id;
        dt.print_log("Updating metadata "..asset_id)
        local _, err_put_metadata = call_immich_api("PUT","assets/"..asset_id.."/metadata",{items={{key=immich_metadata_key,value={image_id=image.id,device_id=device_id}}}})
        dt.print_log(err_put_metadata);
        local uuid_tag_name = string.format("darktable|plugins|immich|%s|uuid|%s", dt.preferences.read("immich","immich_server","string"), asset_id);
        dt.print_log("Adding new tag "..uuid_tag_name)
        local uuid_tag = dt.tags.create(uuid_tag_name);
        dt.tags.attach(uuid_tag,image);
      end
    end
  end
  job.valid = false
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
    dt.print_error("Asset id not found");
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
      local res_search,err_search = call_immich_api("POST","search/metadata",{deviceId=extra_data.device_id,deviceAssetId=tostring(image.id),size=1,withDeleted=false})
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
    local album_id
    local image = dt.database.get_image(tonumber(image_id));
    if (image ~= nil) then 
      local tags = dt.tags.get_tags(image)
      -- Search album 
      for i,tag in ipairs(tags) do
        local album = extra_data.albums_by_tag[tag.name]
        if album ~= nil then
          local album_assets = extra_data.album_assets[album.id]
          if album_assets == nil then 
            album_assets = {}
            extra_data.album_assets[album.id] = album_assets 
          end
          table.insert(album_assets,asset_id)
        end
      end
    end
  end

  -- update albums assets from tags
  if extra_data.album_assets ~= nil then 
    for album_id,album_assets in pairs(extra_data.album_assets) do
      call_immich_api("PUT","albums/"..album_id.."/assets",{ids=album_assets})
    end
  end

  -- create new album and assign assets in immich, then create corresponding album tag and associate images
  local new_album
  if new_album_name_widget.text ~= nil and not string.match(new_album_name_widget.text,"^%s*$") then 
    dt.print_log(new_album_name_widget.text)
    local album_assets= {}
      for _,asset_id in pairs(extra_data.images_asset_id) do
        table.insert(album_assets,asset_id)
      end
      local res_create,err_create = call_immich_api("POST","albums",{albumName=new_album_name_widget.text,assetIds=album_assets})
      if err_create == 201 and res_create ~= nil then
        new_album_name_widget.text = ""
        local new_album_tag = create_album_tag(res_create,extra_data.albums_root)
        for image_id,_ in pairs(extra_data.images_asset_id) do
          local image = dt.database.get_image(tonumber(image_id));
          if (image ~= nil) then 
            dt.tags.attach(new_album_tag,image)
          end
        end
      end
  end

  if extra_data.error ~= nil then
    dt.print(extra_data.error)
  end
end

local function finalize_zero_images(storage,images,extra_data)
  for i,image in ipairs(images) do
    if (extra_data.images_existence[tostring(image.id)]) then
      local res_search,err_search = call_immich_api("POST","search/metadata",{deviceId=extra_data.device_id,deviceAssetId=tostring(image.id),size=1})
      if (err_search == 200) then 
        if (res_search.assets.count >= 1) then
          extra_data.images_asset_id[tostring(image.id)] = res_search.assets.items[1].id;
        end
      end
    end
  end
  finalize(storage,nil,extra_data)
end

local function calc_device_id() 
  local device_id = dt.preferences.read("immich","immich_device_id","string")
  if device_id == nil then 
    device_id = "darktable"
  else
    device_id = "darktable_"..device_id
  end
  return device_id
end

local function initialize(storage,format,images,high_quality,extra_data)
  extra_data.device_id = calc_device_id()
  extra_data.albums_root = get_albums_root()
  extra_data.local_albums_by_id,extra_data.albums_by_tag = sync_albums(extra_data.device_id,false,extra_data.albums_root)
  
  local assets_ids = {}
  extra_data.images_existence = {}
  extra_data.album_assets = {}
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
  
  if (on_conflict_widget.selected == 1) then
    -- if onconflict == skip filter out existintgs images to next phase
    local images_to_export = {}
    for i,image in ipairs(images) do
      if (not extra_data.images_existence[tostring(image.id)]) then
        table.insert(images_to_export,image)
      end
    end
    if (#images_to_export == 0) then
      finalize_zero_images(storage,images,extra_data)
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
      finalize_zero_images(storage,images,extra_data)
    end
    return images_to_export
  end
  return nil
end

local function destroy()
  dt.destroy_storage("immich")
end

sync_albums_widget = dt.new_widget("button") {
  label = _("Synchronize Album tags"),
  clicked_callback = function() 
    sync_albums(calc_device_id(),sync_album_assets_check.value,get_albums_root())
  end,
  tooltip = _('Syncrhonize album tags with Immich'),
}
sync_album_assets_check = dt.new_widget('check_button'){
    label = _('Sync assets'),
    value = false,
    tooltip = _('Syncrhonize album assets with Immich'),
}
on_conflict_widget = dt.new_widget("combobox"){
  label = _("On conflict"),
  tooltip = _("What to do if the image has already been uploaded"),
  selected = 1,
  _("Skip image"),_("Update metadata"), _("Upload new version"), _("Upload new version, then delete previous"),
}
new_album_name_widget = dt.new_widget("entry"){
    tooltip = _("Create a new album in Immich and assign images to."),
    placeholder=_("Don't create new album")
}

dt.register_storage("immich",_("immich"),
    store_image,
    finalize,
    nil,
    initialize,
    dt.new_widget("box") {
      orientation="vertical",
      dt.new_widget("label"){label=_("New album title")},
      new_album_name_widget,
      on_conflict_widget,
      dt.new_widget("separator"){},
      dt.new_widget("box") {
        orientation="horizontal",
        sync_albums_widget,
        sync_album_assets_check
      },
      dt.new_widget("button") {
        label = _("Migrate to immich v3"),
        clicked_callback = function() 
          migratev3(calc_device_id(),get_albums_root())
        end,
        tooltip = _('Migrate images from Immich v2 to v3'),
      }
    })

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
