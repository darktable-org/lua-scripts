--[[

    apply_camera_style.lua - apply camera style to matching images

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
    apply_camera_style - apply darktable camera style to matching images

    apply a camera style corresponding to the camera used to
    take the image to provide a starting point for editing that
    is similar to the SOOC jpeg.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    none

    USAGE
    start the script from script_manager

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

local MODULE <const> = "apply_camera_style"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir
local STYLE_PREFIX <const> = "_l10n_darktable|_l10n_camera styles|"
local MAKER = 3
local STYLE = 4

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("9.4.0", MODULE)   -- camera styles added to darktable 5.0


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

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
  name = _("apply camera style"),            -- name of script
  purpose = _("apply darktable camera style to matching images"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/development/lua.scripts.manual/scripts/official/apply_camera_style/"                   -- URL to help/documentation
}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local apply_camera_style = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

apply_camera_style.imported_images = {}
apply_camera_style.styles = {}
apply_camera_style.log_level = DEFAULT_LOG_LEVEL

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = apply_camera_style
local acs = apply_camera_style

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

-------------------
-- script functions
-------------------

local function process_pattern(pattern)

  local log_level = set_log_level(acs.log_level)

  pattern = string.lower(pattern)
  -- strip off series
  pattern = string.gsub(pattern, " series$", "?")
  -- match a character
  if string.match(pattern, "?$") then
    -- handle EOS R case
    pattern = string.gsub(pattern, "?", ".?")
  else
    pattern = string.gsub(pattern, "?", ".")
  end
  pattern = string.gsub(pattern, " ", " ?")
  -- escape dashes
  pattern = string.gsub(pattern, "%-", "%%-")
  -- make spaces optional
  pattern = string.gsub(pattern, " ", " ?")
  -- until we end up with a set, I'll defer set processing, i.e. [...]
  -- anchor the pattern to ensure we don't short match
  pattern = "^" .. pattern .. "$"

  restore_log_level(log_level)

  return pattern
end

local function process_set(pattern_set)

  local log_level = set_log_level(acs.log_level)

  local to_process = {}
  local processed = {}

  local base, set, tail

  if string.match(pattern_set, "]$") then
    base, set = string.match(pattern_set, "(.+)%[(.+)%]")
  else
    base, set, tail = string.match(pattern_set, "(.+)%[(.+)%](.+)")
  end

  log.msg(log.debug, "base is " .. base .. " and set is " .. set)

  to_process = du.split(set, ",")

  for _, item in ipairs(to_process) do
    local pat = base .. item
    if tail then
      pat = pat .. tail
    end
    table.insert(processed, process_pattern(pat))
  end

  restore_log_level(log_level)

  return processed
end

local function get_camera_styles()

  local log_level = set_log_level(acs.log_level)

  -- separate the styles into
  --
  -- acs.styles -
  --              maker -
  --                      styles {}
  --                      patterns {}

  for _, style in ipairs(dt.styles) do

    if string.match(style.name, STYLE_PREFIX) then
      log.msg(log.debug, "got " .. style.name)

      local parts = du.split(style.name, "|")
      parts[MAKER] = string.lower(parts[MAKER])
      log.msg(log.debug, "maker is " .. parts[MAKER])

      if not acs.styles[parts[MAKER]] then
        acs.styles[parts[MAKER]] = {}
        acs.styles[parts[MAKER]]["styles"] = {}
        acs.styles[parts[MAKER]]["patterns"] = {}
      end
      if parts[STYLE] then
        if not string.match(parts[STYLE], "]") then
          table.insert(acs.styles[parts[MAKER]].styles, style)
          local processed_pattern = process_pattern(parts[#parts])
          table.insert(acs.styles[parts[MAKER]].patterns, processed_pattern)
          log.msg(log.debug, "pattern for " .. style.name .. " is " .. processed_pattern)
        else
          local processed_patterns = process_set(parts[STYLE])
          for _, pat in ipairs(processed_patterns) do
            table.insert(acs.styles[parts[MAKER]].styles, style)
            table.insert(acs.styles[parts[MAKER]].patterns, pat)
            log.msg(log.debug, "pattern for " .. style.name .. " is " .. pat)
          end
        end
      end
    end
  end

  restore_log_level(log_level)

end

local function normalize_model(maker, model)

  local log_level = set_log_level(acs.log_level)

  model = string.lower(model)

  -- strip off the maker name
  if maker == "canon" then
    model = string.gsub(model, "canon ", "")
  elseif maker == "hasselblad" then
    model = string.gsub(model, "hasselblad ", "")
  elseif maker == "leica" then
    model = string.gsub(model, "leica ", "")
  elseif maker == "lg" then
    model = string.gsub(model, "lg ", "")
  elseif maker == "nikon" then
    model = string.gsub(model, "nikon ", "")
  elseif maker == "nokia" then
    model = string.gsub(model, "nokia ", "")
  elseif maker == "oneplus" then
    model = string.gsub(model, "oneplus ", "")
  elseif maker == "pentax" then
    model = string.gsub(model, "pentax ", "")
    model = string.gsub(model, "ricoh ", "")
  end

  restore_log_level(log_level)

  return model
end

local function normalize_maker(maker)

  local log_level = set_log_level(acs.log_level)

  maker = string.lower(maker)

  if string.match(maker, "^fujifilm") then
    maker = "fujifilm"
  elseif string.match(maker, "^hmd ") then
    maker = "nokia"
  elseif string.match(maker, "^leica") then
    maker = "leica"
  elseif string.match(maker, "^minolta") then
    maker = "minolta"
  elseif string.match(maker, "^nikon") then
    maker = "nikon"
  elseif string.match(maker, "^om ") then
    maker = "om system"
  elseif string.match(maker, "^olympus") then
    maker = "olympus"
  elseif string.match(maker, "^pentax") or string.match(maker, "^ricoh") then
    maker = "pentax"
  end

  restore_log_level(log_level)

  return maker
end

local function has_style_tag(image, tag_name)

  local log_level = set_log_level(acs.log_level)

  local result = false

  log.msg(log.debug, "looking for tag " .. tag_name)

  for _, tag in ipairs(image:get_tags()) do
    log.msg(log.debug, "checking against " .. tag.name)
    if tag.name == tag_name then
      log.msg(log.debug, "matched tag " .. tag_name)
      result = true
    end
  end

  restore_log_level(log_level)

  return result
end

local function mangle_model(model)

  local log_level = set_log_level(acs.log_level)

  if string.match(model, "eos") then
    log.msg(log.debug, "mangle model got " .. model)
    model = string.gsub(model, "r6m2", "r6 mark ii")
    model = string.gsub(model, "eos 350d digital", "eos kiss digital n")
    model = string.gsub(model, "eos 500d", "eos rebel t1")
    model = string.gsub(model, "eos 550d", "eos rebel t2")
    model = string.gsub(model, "eos 600d", "eos rebel t3i")
    model = string.gsub(model, "eos 650d", "eos rebel t4i")
    model = string.gsub(model, "eos 700d", "eos rebel t5")
    model = string.gsub(model, "eos 750d", "eos rebel t6i")
    model = string.gsub(model, "eos 760d", "eos rebel t6s")
    model = string.gsub(model, "eos 100d", "eos rebel t6")
    model = string.gsub(model, "eos 1100d", "eos rebel t3")
    model = string.gsub(model, "eos 1200d", "eos rebel t5")
    model = string.gsub(model, "eos 1300d", "eos rebel t6")
    model = string.gsub(model, "eos 2000d", "eos rebel t7")
    log.msg(log.debug, "mandle model returning " .. model)
  end

  restore_log_level(log_level)

  return model
end

local function stop_job()
  if acs.job then
    if acs.job.valid then
      acs.job.valid = false
    end
  end
end

local function apply_style_to_images(images)

  local log_level = set_log_level(acs.log_level)

  acs.job = dt.gui.create_job(_("applying camera styles to images"), true, stop_job)

  for count, image in ipairs(images) do
    local maker = normalize_maker(image.exif_maker)
    local model = normalize_model(maker, image.exif_model)
    model = mangle_model(model)
    log.msg(log.debug, "got maker " .. maker .. " and model " .. model .. " from image " .. image.filename)

    if acs.styles[maker] then
      local no_match = true
      for i, pattern in ipairs(acs.styles[maker].patterns) do
        if string.match(model, pattern) or 
           (i == #acs.styles[maker].patterns and string.match(pattern, "generic")) then
          local tag_name = "darktable|style|" .. acs.styles[maker].styles[i].name
          if not has_style_tag(image, tag_name) then
            image:apply_style(acs.styles[maker].styles[i])
            no_match = false
            log.msg(log.info, "applied style " .. acs.styles[maker].styles[i].name .. " to " .. image.filename)
          end
          log.log_level(loglevel)
          break
        end
      end
      if no_match then
        log.msg(log.info, "no style found for " .. maker .. " " .. model)
      end
    else
      log.msg(log.info, "no maker found for " .. image.filename)
    end
    if count % 10 == 0 then
      acs.job.percent = count / #images
    end
    if dt.control.ending then
      stop_job()
    end
  end

  stop_job()

  restore_log_level(log_level)

end

local function apply_camera_style(collection)

  local log_level = set_log_level(acs.log_level)

  local images = nil

  if collection == true then 
    images = dt.collection
    log.msg(log.info, "applying camera styles to collection")
  elseif collection == false then
    images = dt.gui.selection()
    if #images == 0 then
      images = dt.gui.action_images
    end
    log.msg(log.info, "applying camera styles to selection")
  end
  apply_style_to_images(images)

  restore_log_level(log_level)
  
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

get_camera_styles()

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "post-import-image")
  dt.destroy_event(MODULE, "post-import-film")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "shortcut",
  function(event, shortcut)
    apply_camera_style(true)
  end, _("apply darktable camera styles to collection")
)

dt.register_event(MODULE, "shortcut",
  function(event, shortcut)
    apply_camera_style(false)
  end, _("apply darktable camera styles to selection")
)

dt.register_event(MODULE, "post-import-image",
  function(event, image)
    if image.is_raw then
      table.insert(acs.imported_images, image)
    end
  end
)

dt.register_event(MODULE, "post-import-film",
  function(event, film)
    apply_style_to_images(acs.imported_images)
    acs.imported_images = {}
  end
)

return script_data
