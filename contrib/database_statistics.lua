--[[
    
    database_statistics.lua - Shows a darktable database statistic

    Copyright (C) 2016 Holger Klemm <http://www.multimedia4linux.de>.
    
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
VERSION 2.1
Works with darktable 2.0.X and 2.2.X
   
ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * sqlite3
    * rm
    * grep
    * wc
    * du

   USAGE
* require this script from your main lua file


* it creates a new database statistcs module

]]


local dt = require "darktable"
local gettext = dt.gettext
dt.configuration.check_version(...,{3,0,0},{4,0,0})

local count_discusage = "-"
local count_filmrolls = "-"
local count_images = "-"
local count_rating_0 = "-"
local count_rating_1 = "-"
local count_rating_2 = "-"
local count_rating_3 = "-"
local count_rating_4 = "-"
local count_rating_5 = "-"
local count_red = "-"
local count_yellow = "-"
local count_green = "-"
local count_blue = "-"
local count_magenta = "-"
local count_without = "-"

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("database_statistics",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("database_statistics", msgid)
end

local labeldiscusage = dt.new_widget("label")
{
     label = _('Disc usage:\t\t\t\t') .. count_discusage,
     ellipsize = "start",
     halign = "start"
}

local labelfilmrolls = dt.new_widget("label")
{
     label = _('Filmrolls:\t\t\t\t\t') .. count_filmrolls,
     ellipsize = "start",
     halign = "start"
}


local labelimages = dt.new_widget("label")
{
      label = _('Images:\t\t\t\t\t') .. count_images,
      ellipsize = "start",
      halign = "start",
}

local separator_1 = dt.new_widget("separator")
{}


local rating_1_label = dt.new_widget("label")
{ 
      label = _('Images with 1 star:\t\t\t') .. count_rating_1,
      ellipsize = "start",
      halign = "start",
}

local rating_2_label = dt.new_widget("label")
{ 
      label = _('Images with 2 stars:\t\t\t') .. count_rating_2,
      ellipsize = "start",
      halign = "start",
}

local rating_3_label = dt.new_widget("label")
{ 
      label = _('Images with 3 stars:\t\t\t') .. count_rating_3,
      ellipsize = "start",
      halign = "start",
}

local rating_4_label = dt.new_widget("label")
{ 
      label = _('Images with 4 stars:\t\t\t') .. count_rating_4,
      ellipsize = "start",
      halign = "start",
}

local rating_5_label = dt.new_widget("label")
{ 
      label = _('Images with 5 stars:\t\t\t') .. count_rating_5,
      ellipsize = "start",
      halign = "start",
}

local rating_0_label = dt.new_widget("label")
{ 
      label = _('Images without stars:\t\t') .. count_rating_0,
      ellipsize = "start",
      halign = "start",
}

local separator_2 = dt.new_widget("separator")
{}


local colorlabelred = dt.new_widget("label")
{ 
      label = _('Images with red labels:\t\t') .. count_red,
      ellipsize = "start",
      halign = "start",
}

local colorlabelyellow = dt.new_widget("label")
{
      label = _('Images with yellow labels:\t\t') .. count_yellow,
      ellipsize = "start",
      halign = "start",
}


local colorlabelgreen = dt.new_widget("label")
{
      label = _('Images with green labels:\t\t')  .. count_green,
      ellipsize = "start",
      halign = "start",
}

local colorlabelblue = dt.new_widget("label")
{
      label = _('Images with blue labels:\t\t') .. count_blue,
      ellipsize = "start",
      halign = "start",
}


local colorlabelmag = dt.new_widget("label")
{
      label = _('Images with magenta labels:\t') .. count_magenta,
      ellipsize = "start",
      halign = "start",
}

local nocolorlabels = dt.new_widget("label")
{
      label = _('Images without labels:\t\t') .. count_without,
      ellipsize = "start",
      halign = "start",
}


local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end
  return ret
end

local function checkIfDirExists(dir)
    local dir_found=io.open(dir, "r")
    if dir_found==nil then
        dt.print(_([[ERROR: Directory not found. Please check ]] ..dir))
        
    end
end



function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end
    
    
local function analyse_db()

-- Check installed software    
  if not (checkIfBinExists("sqlite3")) then
    dt.print(_("ERROR: sqlite3 not found! Please install sqlite3."))
   do return end
  elseif not (checkIfBinExists("rm")) then
    dt.print(_("ERROR: rm not found! Please install core utilities."))
   do return end
  elseif not (checkIfBinExists("grep")) then
    dt.print(_("ERROR: grep not found! Please install core utilities."))
    do return end
  elseif not (checkIfBinExists("wc")) then
    dt.print(_("ERROR: wc not found! Please install core utilities."))
    do return end
  elseif not (checkIfBinExists("du")) then
    dt.print(_("ERROR: du not found! Please install core utilities."))
    do return end
  else  
    dt.print(_('Analyze database. Please wait...'))
  end


-- Analyse xmp files    
    local counter=0
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_filmrolls' "SELECT COUNT (*) FROM (SELECT DISTINCT folder FROM film_rolls)";]]
    local file_filmrolls = io.open("/tmp/dt_filmrolls", "r")
    count_filmrolls = file_filmrolls:read()
    number_filmrolls = tonumber(count_filmrolls)
    file_filmrolls:close()
    
    local totaldiscusage=0
    local discusage=0
    local rating0=0
    local rating1=0
    local rating2=0
    local rating3=0
    local rating4=0
    local rating5=0
    local totalrating0=0
    local totalrating1=0
    local totalrating2=0
    local totalrating3=0
    local totalrating4=0
    local totalrating5=0
    
    
-- Calculate Rating
    while counter ~= number_filmrolls do
-- Input dir
        InputdirStartCommand = [[sqlite3 ~/.config/darktable/library.db "SELECT folder FROM film_rolls LIMIT ]] ..counter.. [[,1" > /tmp/dt_inputdir]]
        os.execute(InputdirStartCommand)  
        local file_inputdir = io.open("/tmp/dt_inputdir", "r")
        xinputdir = file_inputdir:read()
        inputdir='"'..xinputdir..'"'
        file_inputdir:close()
        os.execute[[rm /tmp/dt_inputdir]]
-- Check Inputdir  
        checkIfDirExists(xinputdir)        
-- Disc usage
        DiscusageStartCommand = [[du -s ]] ..inputdir.. [[ | cut -f1 > /tmp/dt_discusage]]
        os.execute(DiscusageStartCommand)
        local file_discusage = io.open("/tmp/dt_discusage", "r")
        discusage = tonumber(file_discusage:read())
        file_discusage:close()
        totaldiscusage=totaldiscusage + discusage
        os.execute[[rm /tmp/dt_discusage]]
        
-- Rating 0        
        Rating_0_StartCommand = [[grep -r -i 'Rating="0"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating0]]
        os.execute(Rating_0_StartCommand)
        local file_rating0 = io.open("/tmp/dt_rating0", "r")
        rating0 = tonumber(file_rating0:read())
        file_rating0:close()
        totalrating0=totalrating0 + rating0
        os.execute[[rm /tmp/dt_rating0]]

-- Rating 1  
        Rating_1_StartCommand = [[grep -r -i 'Rating="1"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating1]]
        os.execute(Rating_1_StartCommand)
        local file_rating1 = io.open("/tmp/dt_rating1", "r")
        rating1 = tonumber(file_rating1:read())
        file_rating1:close()
        totalrating1=totalrating1 + rating1
        os.execute[[rm /tmp/dt_rating1]]
-- Rating 2  
        Rating_2_StartCommand = [[grep -r -i 'Rating="2"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating2]]
        os.execute(Rating_2_StartCommand)
        local file_rating2 = io.open("/tmp/dt_rating2", "r")
        rating2 = tonumber(file_rating2:read())
        file_rating2:close()
        totalrating2=totalrating2 + rating2
        os.execute[[rm /tmp/dt_rating2]]
 -- Rating 3  
        Rating_3_StartCommand = [[grep -r -i 'Rating="3"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating3]]
        os.execute(Rating_3_StartCommand)
        local file_rating3 = io.open("/tmp/dt_rating3", "r")
        rating3 = tonumber(file_rating3:read())
        file_rating3:close()
        totalrating3=totalrating3 + rating3
        os.execute[[rm /tmp/dt_rating3]]
 -- Rating 4  
        Rating_4_StartCommand = [[grep -r -i 'Rating="4"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating4]]
        os.execute(Rating_4_StartCommand)
        local file_rating4 = io.open("/tmp/dt_rating4", "r")
        rating4 = tonumber(file_rating4:read())
        file_rating4:close()
        totalrating4=totalrating4 + rating4  
        os.execute[[rm /tmp/dt_rating4]]
  -- Rating 5  
        Rating_5_StartCommand = [[grep -r -i 'Rating="5"' ]] ..inputdir.. [[/*.xmp | wc -l > /tmp/dt_rating5]]
        os.execute(Rating_5_StartCommand)
        local file_rating5 = io.open("/tmp/dt_rating5", "r")
        rating5 = tonumber(file_rating5:read())
        file_rating5:close()
        totalrating5=totalrating5 + rating5           
        os.execute[[rm /tmp/dt_rating5]]
        counter = counter + 1
        xxx=round((100 / number_filmrolls * counter),0)
        finishedstr=tostring(xxx)
        dt.print(_('Analyzed ') ..finishedstr..('%')) 
    end    
        dt.print(_('Analyse finished')) 
-- Disc usage
        local totaldiscusage_gib = round((totaldiscusage / 1048576),1)
-- Convert to string    
        count_discusage = tostring(totaldiscusage_gib)
        count_rating_0 = tostring(totalrating0) 
        count_rating_1 = tostring(totalrating1) 
        count_rating_2 = tostring(totalrating2) 
        count_rating_3 = tostring(totalrating3) 
        count_rating_4 = tostring(totalrating4) 
        count_rating_5 = tostring(totalrating5)
    
    
-- Export database information
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_images' "SELECT COUNT (*) FROM (SELECT DISTINCT id FROM images)";]]
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_labelred' "SELECT COUNT (*) FROM color_labels WHERE COLOR = 0";]]
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_labelyellow' "SELECT COUNT (*) FROM color_labels WHERE COLOR = 1";]]
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_labelgreen' "SELECT COUNT (*) FROM color_labels WHERE COLOR = 2";]]
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_labelblue' "SELECT COUNT (*) FROM color_labels WHERE COLOR = 3";]]
    os.execute[[sqlite3 ~/.config/darktable/library.db '.output /tmp/dt_labelmagenta' "SELECT COUNT (*) FROM color_labels WHERE COLOR = 4";]]

-- Read files    
    local file_images = io.open("/tmp/dt_images", "r")
    count_images = file_images:read()
    file_images:close()    
    
    local file_red = io.open("/tmp/dt_labelred", "r")
    count_red = file_red:read()
    file_red:close()  
    
    local file_yellow = io.open("/tmp/dt_labelyellow", "r")
    count_yellow = file_yellow:read()
    file_yellow:close()    

    local file_green = io.open("/tmp/dt_labelgreen", "r")
    count_green = file_green:read()
    file_green:close()    

    local file_blue = io.open("/tmp/dt_labelblue", "r")
    count_blue = file_blue:read()
    file_blue:close()    
    
    local file_magenta = io.open("/tmp/dt_labelmagenta", "r")
    count_magenta = file_magenta:read()
    file_magenta:close()    
    
    count_without = count_images - count_red - count_yellow - count_green - count_blue - count_magenta
    
    labeldiscusage.label = _('Disc usage:\t\t\t\t') .. count_discusage.. " GiB"
    labelfilmrolls.label = _('Filmrolls:\t\t\t\t\t') .. count_filmrolls
    labelimages.label = _('Images:\t\t\t\t\t') .. count_images
    rating_0_label.label = _('Images without stars:\t\t') .. count_rating_0
    rating_1_label.label = _('Images with 1 star:\t\t\t') .. count_rating_1  
    rating_2_label.label = _('Images with 2 stars:\t\t\t') .. count_rating_2
    rating_3_label.label = _('Images with 3 stars:\t\t\t') .. count_rating_3
    rating_4_label.label = _('Images with 4 stars:\t\t\t') .. count_rating_4
    rating_5_label.label = _('Images with 5 stars:\t\t\t') .. count_rating_5
    colorlabelred.label = _('Images with red labels:\t\t') .. count_red
    colorlabelyellow.label = _('Images with yellow labels:\t\t') .. count_yellow
    colorlabelgreen.label = _('Images with green labels:\t\t')  .. count_green
    colorlabelblue.label = _('Images with blue labels:\t\t') .. count_blue
    colorlabelmag.label = _('Images with magenta labels:\t') .. count_magenta
    nocolorlabels.label = _('Images without labels:\t\t') .. count_without
 
-- Delete temp files    
    os.execute[[rm /tmp/dt_filmrolls /tmp/dt_images /tmp/dt_labelred /tmp/dt_labelyellow /tmp/dt_labelgreen /tmp/dt_labelblue /tmp/dt_labelmagenta]]
end

dt.register_lib(
  "database",     -- Module name
  (_('Database statistics')),     -- name
  true,                -- expandable
  false,               -- resetable
  {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER", 100}},   -- containers
  dt.new_widget("box") -- widget
  {
    labeldiscusage,
    labelfilmrolls,
    labelimages,
    separator_1,
    rating_1_label,
    rating_2_label,
    rating_3_label,
    rating_4_label,
    rating_5_label,
    rating_0_label,
    separator_2,
    colorlabelred,
    colorlabelyellow,
    colorlabelgreen,
    colorlabelblue,
    colorlabelmag,
    nocolorlabels,
     dt.new_widget("button")
    {
      label = _('Analyse database'),
      clicked_callback = analyse_db
    },

  },
  nil,-- view_enter
  nil -- view_leave
)

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;
