--[[
  Steghide storage for darktable 

  copyright (c) 2016  Holger Klemm
  
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
Version 2.1


ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* steghide

USAGE
* require this file from your main luarc config file.

This plugin will add a new export storage calls Steghide JPEG export.
]]

local dt = require "darktable"
local gettext = dt.gettext

-- works only with darktable API version 4.0.0
dt.configuration.check_version(...,{4,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("steghideexport",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("steghideexport", msgid)
end




local check_button_selected_file = dt.new_widget("check_button")
{
    label = _('Use selected text file'), 
    value = true,
    tooltip =_('Default text file: ~/.config/darktable/steghide/steghide_default'),   
    reset_callback = function(self) 
       self.value = true 
    end
    
}


local check_button_usertext = dt.new_widget("check_button")
{
    label = _('Use user text line'), 
    value = false,
    tooltip =_('Embed the user text line'),  
    reset_callback = function(self) 
       self.value = false 
    end
    
}


local label_password = dt.new_widget("label")
{
      label = _('Password:'),
      ellipsize = "start",
      halign = "start",
      tooltip = _('Steghide requires a password')
}

local entrypassword = dt.new_widget("entry")
{
    text = "", 
    placeholder = _('Please enter a password'),
    is_password = false,
    editable = true,
    tooltip = _('Enter a password'),
    reset_callback = function(self) 
       self.text = "" 
    end
}


local label_usertext= dt.new_widget("label")
{
     label = _('User text line:'),
     ellipsize = "start",
     halign = "start"
}


local entrytext = dt.new_widget("entry")
{
    text = "", 
    sensitive = true,
    is_password = true,
    editable = true,
    tooltip = _('Enter the user text to embed'),
    reset_callback = function(self) 
       self.text = "" 
    end

}


local label_path = dt.new_widget("label")
{
     label = _('Target directory:'),
     ellipsize = "start",
     halign = "start"
}

local label_textfile= dt.new_widget("label")
{
     label = _('Selected text file:'),
     ellipsize = "start",
     halign = "start"
}

local label_enc= dt.new_widget("label")
{
     label = _('Encryption algorithm / mode:'),
     ellipsize = "start",
     halign = "start"
}


-- Target directory dialog
local file_chooser_button = dt.new_widget("file_chooser_button")
{
    title = _('Export Steghide JPEG'),  -- The title of the window when choosing a file
    is_directory = true             -- True if the file chooser button only allows directories to be selecte
}


-- Text file dialog
local textfile_chooser_button = dt.new_widget("file_chooser_button")
{
    title = _('Text file'),  -- The title of the window when choosing a file
    value = ".config/darktable/steghide/steghide_default",
    reset_callback = function(self) 
       self.value = ".config/darktable/steghide/steghide_default" 
    end
}


local selection = dt.gui.selection()
  local result = ""
  local array = {}
  for _,img in pairs(selection) do
    array[img.path] = true
  end
  for path in pairs(array) do
    if result == "" then
      result = path
    else
      result = result.."\n"..path
    end
  end
  file_chooser_button.value = result

local enc_combobox = dt.new_widget("combobox")
{
    label = "", 
    value = 15, "cast-128 cbc", "cast-128 cfb", "cast-128 ctr","cast-128 ecb","cast-128 ncfb","cast-128 nofb","cast-128 ofb","gost cbc","gost cfb","gost ctr","gost ecb","gost ncfb","gost nofb","gost ofb","rijndael-128 cbc","rijndael-128 cfb","rijndael-128 ctr","rijndael-128 ecb","rijndael-128 ncfb","rijndael-128 nofb","rijndael-128 ofb","twofish cbc","twofish cfb","twofish ctr","twofish ecb","twofish ncfb","twofish nofb","twofish ofb","arcfour stream","cast-256 cbc","cast-256 cfb","cast-256 ctr","cast-256 ecb","cast-256 ncfb","cast-256 nofb","cast-256 ofb","loki97 cbc","loki97 cfb","loki97 ctr","loki97 ecb","loki97 ncfb","loki97 nofb","loki97 ofb","rijndael-192 cbc","rijndael-192 cfb","rijndael-192 ctr","rijndael-192 ecb","rijndael-192 ncfb","rijndael-192 nofb","rijndael-192 ofb","saferplus cbc","saferplus cfb","saferplus ctr","saferplus ecb","saferplus ncfb","saferplus nofb","saferplus ofb","wake stream","des cbc","des cfb","des ctr","des ecb","des ncfb","des nofb","des ofb","rijndael-256 cbc","rijndael-256 cfb","rijndael-256 ctr","rijndael-256 ecb","rijndael-256 ncfb","rijndael-256 nofb","rijndael-256 ofb","serpent cbc","serpent cfb","serpent ctr","serpent ecb","serpent ncfb","serpent nofb","serpent ofb","xtea cbc","xtea cfb","xtea ctr","xtea ecb","xtea ncfb","xtea nofb","xtea ofb","blowfish cbc","blowfish cfb","blowfish ctr","blowfish ecb","blowfish ncfb","blowfish nofb","blowfish ofb","enigma stream","rc2 cbc","rc2 cfb","rc2 ctr","rc2 ecb","rc2 ncfb","rc2 nofb","rc2 ofb","tripledes cbc","tripledes cfb","tripledes ctr","tripledes ecb","tripledes ncfb","tripledes nofb","tripledes ofb",
    reset_callback = function(self) 
       self.value = 15 
    end
}  
  
  
local widget = dt.new_widget("box") {
    orientation = "vertical",
    check_button_selected_file,
    check_button_usertext,
    label_textfile,
    textfile_chooser_button,
    label_usertext,
    entrytext,
    label_password,
    entrypassword,
    label_enc,
    enc_combobox,
    label_path,
    file_chooser_button,    
}



local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
 --   dt.print_error("true checkIfBinExists: "..bin)
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end


  return ret
end



local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
  if (not (entrypassword.text == "")) then
  dt.print(_('Export JPEG to Steghide ')..tostring(number).."/"..tostring(total))
  else
  dt.print(_('ERROR: No password found'))    
  end    
end


encmode = enc_combobox.value

local function create_steghidefoto(storage, image_table, extra_data) --finalize
  if (not (checkIfBinExists("steghide"))) then
    dt.print(_('ERROR: Steghide not found. Please install steghide.'))
    dt.print_error(_('Steghide not found. Please install steghide.'))
    return
  end

  local steghide_executor = false
  if (checkIfBinExists("steghide")) then
    steghide_executor = true
  end

  
-- password check
steghidepassword = entrypassword.text
if steghidepassword =="" then
      dt.print(_('ERROR: No password found'))
else 
      dt.print(_('Will try to embed text'))

    -- textline check      
    if ((check_button_usertext.value) and (entrytext.text == "")) then
      dt.print(_('ERROR: No user text found'))
    else

  
      -- create text file      
          if ((check_button_selected_file.value) and (check_button_usertext.value)) then
               textline = entrytext.text
               default_file = io.open(textfile_chooser_button.value,"r")
               defaulttext = default_file:read("*a")
               combinetext = defaulttext.."\n\n"..textline
               combine_file = io.open("/tmp/steghide_combine", "w")
               combine_file:write(combinetext)
               io.close(combine_file)
               textfile = "/tmp/steghide_combine"  
           elseif (check_button_selected_file.value) then
               textfile = textfile_chooser_button.value
           elseif (check_button_usertext.value) then
               textline_file = io.open("/tmp/steghide_text_line", "w")
               textline_file:write(entrytext.text)
               io.close(textline_file)
               textfile = "/tmp/steghide_text_line"
           elseif ((textfile =="") or (textfile=="(None)")) then  
               dt.print(_('ERROR: No textfile created or selected'))
               return
           else
               dt.print(_('ERROR: No text file selected'))
               return
           end
           
           
     -- embed text with steghide
          local steghideStartCommand
           img_path = file_chooser_button.value
            if (steghide_executor) then
              if (textfile =="") then
                dt.print(_('ERROR: No textfile created or selected'))
                return  
               else   
              dt.print(_('Embeding text...'))
               for _,v in pairs(image_table) do
                 steghideStartCommand = "steghide --embed --encryption " ..encmode.. " --nochecksum -q -p " ..steghidepassword.. " -cf "..v.." -ef "..textfile 
                 dt.control.execute( steghideStartCommand)
                 moveFileCommand = "mv " ..v.. " "..img_path
                 dt.control.execute( moveFileCommand)
               end
               end
            else
              dt.print(_('ERROR: Embeding not working'))
            end
    end

  end

end


-- limit export to jpeg (8 bit)
local function support_format(storage, format)
  fmt = string.lower(format.name)
  if string.match(fmt,"jpeg%s%g8%sbit%g") == nil then
    return false
  else
    return true
  end   
end  



-- Register
dt.register_storage("module_steghide", _('Steghide JPEG Photo'), show_status, create_steghidefoto, support_format, nil, widget)

