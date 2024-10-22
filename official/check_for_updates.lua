--[[
    This file is part of darktable,
    copyright (c) 2015 Tobias Ellinghaus

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
CHECK FOR UPDATES
a simple script that will automatically look for newer releases on github and inform
when there is something. it will only check on startup and only once a week.

USAGE
* install luasec and cjson for Lua 5.4 on your system
* require this script from your main lua file
* restart darktable

]]

local dt = require "darktable"
local du = require "lib/dtutils"
local https = require "ssl.https"
local cjson = require "cjson"

du.check_min_api_version("2.0.0", "check_for_updates") 

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("check for updates"),
  purpose = _("check for newer darktable releases"),
  author = "Tobias Ellinghaus",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/check_for_updates"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- compare two version strings of the form "major.minor.patch"
-- returns -1, 0, 1 if the first version is smaller, equal, greater than the second version,
-- or nil if one or both are of the wrong format
-- strings like "release-1.2.3" and "1.2.3+456~gb00b5" are fine, too
local function parse_version(s)
  local rc = 0
  local major, minor, patch = s:match("(%d+)%.(%d+)%.(%d+)")
  if not major then
    patch = 0
    major, minor, rc = s:match("(%d+)%.(%d+)rc(%d+)")
  end
  if not major then
    patch = 0
    rc = 0
    major, minor = s:match("(%d+)%.(%d+)")
  end
  return tonumber(major), tonumber(minor), tonumber(patch), tonumber(rc)
end

local function compare_versions(a, b)
  local a_major, a_minor, a_patch, a_rc = parse_version(a)
  local b_major, b_minor, b_patch, b_rc = parse_version(b)

  if a_major and a_minor and a_patch and b_major and b_minor and b_patch then
    if a_major < b_major then return -1 end
    if a_major > b_major then return 1 end

    if a_minor < b_minor then return -1 end
    if a_minor > b_minor then return 1 end

    if a_patch < b_patch then return -1 end
    if a_patch > b_patch then return 1 end

    -- when rc == 0 then it's a proper release and newer than the rcs
    local m = math.max(a_rc, b_rc) + 1
    if a_rc == 0 then a_rc = m end
    if b_rc == 0 then b_rc = m end
    if a_rc < b_rc then return -1 end
    if a_rc > b_rc then return 1 end

    return 0
  else
    return
  end
end

local function destroy()
  -- nothing to destroy
end


-- local function test(a, b, r)
--   local cmp = compare_versions(a, b)
--   if(not cmp) then
--     print(a .. " ./. " .. b .. " => MALFORMED INPUT")
--   elseif(cmp == r) then
--     print(a .. " ./. " .. b .. " => PASSED")
--   else
--     print(a .. " ./. " .. b .. " => FAILED")
--   end
-- end
--
-- test("malformed", "1.0.0", 0)
-- test("2.0rc1+135~ge456b2b-dirty", "release-1.6.9", 1)
-- test("release-1.6.9", "2.0rc1+135~ge456b2b-dirty", -1)
-- test("2.0rc1+135~ge456b2b-dirty", "2.0rc2+135~ge456b2b-dirty", -1)
-- test("2.0rc2+135~ge456b2b-dirty", "2.0rc1+135~ge456b2b-dirty", 1)
-- test("2.0rc3+135~ge456b2b-dirty", "release-2.0", -1)
-- test("2.0rc3+135~ge456b2b-dirty", "release-2.0.0", -1)
-- test("1.0.0", "2.0.0", -1)
-- test("2.0.0", "1.0.0", 1)
-- test("3.0.0", "3.0.0", 0)


-- check stored timestamp and skip the check if the last time was not too long ago
-- for now we are assuming that os.time() returns seconds. that's not guaranteed but the case on many systems.
-- the reference date doesn't matter, as long as it's currently positive (we start with 0 the first time)
-- see http://lua-users.org/wiki/DateAndTime
local now = os.time()
local back_then = dt.preferences.read("check_for_updates", "timestamp", "integer")

-- check once a week
if now > (back_then + 60 * 60 * 24 * 7) then

  -- try to get the latest release's version from github and compare to what we are running
  -- see https://developer.github.com/v3/repos/releases/ for the api docs
  -- just ignore when anything fails and retry at some other time
  local result, error_code = https.request("https://api.github.com/repos/darktable-org/darktable/releases/latest")

  if error_code == 200 then
    local name = cjson.decode(result)["name"]  -- http://www.kyne.com.au/~mark/software/lua-cjson-manual.html
    if name then
      local cmp = compare_versions(name, dt.configuration.version)
      if cmp then
        if cmp > 0 then
          dt.print("there seems to be a newer release than what you are running. better update")
        end
        -- update timestamp to not check again for a while
        dt.preferences.write("check_for_updates", "timestamp", "integer", now)
      end
    end
  end

end

script_data.destroy = destroy
return script_data
