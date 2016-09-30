local dt = require "darktable"

libLog = {}

libLog.debug = {"DEBUG:", false}
libLog.info = {"INFO:", false}
libLog.warn = {"WARN:", false}
libLog.error = {"ERROR:", true}
libLog.success = {"SUCCESS:", true}

function libLog.msg(level, message)
  if level[2] == true then
    if level[1] == "DEBUG:" then
      print(level[1], message)
    elseif level[1] == "INFO:" or level[1] == "WARN:" then
      dt.print_error(level[1], message)
    else
      dt.print(level[1], message)
    end
  end
end

function libLog.setLevel(level)
  level = level:lower()
  if string.match(level, "debug") then
    -- turn everything on
    libLog.debug[2] = true
    libLog.info[2] = true
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "info") then
    -- turn off debug and everything else on
    libLog.debug[2] = false
    libLog.info[2] = true
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "warn") then
    -- turn off debug and info and everything else on
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = true
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "error") or string.match("reset") then
    -- everything off except error and success
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = false
    libLog.error[2] = true
    libLog.success[2] = true
  elseif string.match(level, "success") then
    -- everything off except success
    libLog.debug[2] = false
    libLog.info[2] = false
    libLog.warn[2] = false
    libLog.error[2] = false
    libLog.success[2] = false
  else
    dt.print_error("No such log level " .. level)
  end
end


return libLog