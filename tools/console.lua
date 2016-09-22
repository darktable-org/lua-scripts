dt = require "darktable"
function tellme(offset, story)
  local n,v
  for n,v in pairs(story) do
    if n ~= "loaded" and n ~= "_G" then
      io.write (offset .. n .. " " )
      print (v)
      if type(v) == "table" then
              tellme(offset .. "--> ",v)
      end
    end
  end
end

tellme("",_G)

-- print("trying known again....")

--tellme("",dtdb.known)

-- dt.print_error("Trying the debug functions... ")

-- dt.print_error("Dumping known")

-- tellme("", dtdb.known)

-- dt.print_error("Trying debug.dump")

-- print(dtdb.dump.known())

