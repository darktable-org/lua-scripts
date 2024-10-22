--[[
  This file is part of darktable,
  copyright (c) 2015 Jérémy Rosen & Pascal Obry
  edited 2016 Tejovanth N

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
SELECTION_TO_PDF
Generates a PDF file (via Latex) containing all selected images

ADDITIANAL SOFTWARE NEEDED FOR THIS SCRIPT
* a PDF-Viewer
* pdflatex (Latex)

USAGE
* require this file from your main lua config file:

This plugin will add a new exporter that will allow you to generate the pdf file

Plugin allows you to choose how many thumbnails you need per row


]]
local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("7.0.0", "selection_to_pdf")

local gettext = dt.gettext.gettext

local function _(msg)
  return gettext(msg)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("selection to PDF"),
  purpose = _("generate a pdf file of selected images"),
  author = "Jérémy Rosen & Pascal Obry",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/selection_to_pdf"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

dt.preferences.register
   ("selection_to_pdf","Open with","string",
    _("a pdf viewer"),
    _("can be an absolute pathname or the tool may be in the PATH"),
    "xdg-open")

local title_widget = dt.new_widget("entry") {
    placeholder = _("title")
}
local no_of_thumbs_widget = dt.new_widget("slider")
{
    label = _("thumbs per line"), 
    soft_min = 1,     -- The soft minimum value for the slider, the slider can't go beyond this point
    soft_max = 10,    -- The soft maximum value for the slider, the slider can't go beyond this point
    hard_min = 1,     -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
    hard_max = 10,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
    value = 4         -- The current value of the slider
}
local widget = dt.new_widget("box") {
    orientation = horizontal,
    dt.new_widget("label"){label = _("title:")},
    title_widget,
    dt.new_widget("label"){label = _("thumbnails per row:")},
    no_of_thumbs_widget
}

local ending = [[
\end{document}
]]


local filename =dt.configuration.tmp_dir.."/pdfout.tex"

local function my_write(latexfile,arg)
  local res,errmsg = latexfile:write(arg)
  if not res then
    error(errmsg)
  end
end

local function thumbnail(latexfile,i,image,file)
  local title
  if image.title == "" then
    title = image.filename
    if image.duplicate_index > 0 then
      title = title.."["..image.duplicate_index.."]"
    end

  else
    title = image.title
  end

  --  fact is that latex will get confused if the filename has multiple dots.
  --  so \includegraphics{file.01.jpg} wont work. We need to output the filename
  --  and extention separated, e.g: \includegraphics{{file.01}.jpg}
  local filenoext=string.gsub(file, "(.*)(%..*)", "%1")
  local ext=string.gsub(file, "(.*)(%..*)", "%2")
  my_write(latexfile,"\\begin{minipage}[b]{"..width.."\\textwidth}\n")
  my_write(latexfile,"\\includegraphics[width=\\textwidth]{{"..filenoext.."}"..ext.."}\\newline\n")
  my_write(latexfile,"\\centering{"..i..": \\verb|"..title.."|}\n")
  my_write(latexfile,"\\end{minipage}\\quad\n")
end

local function destroy()
  dt.print_log("destroying storage")
  dt.destroy_storage("export_pdf")
  dt.print_log("done destroying")
end

dt.register_storage("export_pdf", _("export thumbnails to pdf"),
    nil,
    function(storage,image_table)
      local my_title = title_widget.text
      if my_title == "" then
        my_title = "Title"
    end
    local thumbs_per_line = no_of_thumbs_widget.value
    thumbs_per_line = tonumber(thumbs_per_line)
    width = (1/thumbs_per_line) - 0.01

    local preamble = [[
    \documentclass[a4paper,10pt]{article}
    \usepackage{graphicx}
    \pagestyle{empty}
    \parindent0pt
    \usepackage{geometry}
    \geometry{a4paper,left=5mm,right=5mm, top=5mm, bottom=5mm}
    \begin{document}
    {\Large\bfseries ]]..my_title..[[} \\
    \bigskip\bigskip
    ]]

    local errmsg
    local latexfile
    latexfile,errmsg=io.open(filename,"w")
    if not latexfile then
        error(errmsg)
      end
      my_write(latexfile,preamble)
      local i = 1
      for img,file in pairs(image_table) do
         thumbnail(latexfile,i,img,file)
         if i % thumbs_per_line == 0  then
            my_write(latexfile,"\n\\bigskip\n")
         end
         i = i+1
      end
      my_write(latexfile,ending)
      latexfile:close()

      -- convert to PDF
      local dir=string.gsub(filename, "(.*/)(.*)", "%1")
      local locfile=string.gsub(filename, "(.*/)(.*)", "%2")
      local command = "pdflatex -halt-on-error -output-directory "..dir.." "..locfile
      local result = dt.control.execute(command)
      if result ~= 0 then
        dt.print(_("problem running pdflatex")) -- this one is probably usefull to the user
        error("Problem running "..command)
      end

      -- open the PDF
      local pdffile=string.gsub(filename, ".tex", ".pdf")
      command = dt.preferences.read("selection_to_pdf","Open with","string")
      command = command.." "..pdffile
      local result = dt.control.execute(command)
      if result ~= 0 then
        dt.print(_("problem running pdf viewer")) -- this one is probably usefull to the user
        error("Problem running "..command)
      end

      -- finally do some clean-up
      for img,file in pairs(image_table) do
         os.remove(file)
      end
    end,nil,nil,widget)

script_data.destroy = destroy

return script_data
--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
