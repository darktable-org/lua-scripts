--[[
  This file is part of darktable,
  copyright (c) 2015 Jérémy Rosen & Pascal Obry

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


]]
local dt = require "darktable"
dt.configuration.check_version(...,{2,0,0},{3,0,0})

dt.preferences.register
   ("selection_to_pdf","Open with","string",
    "a pdf viewer",
    "Can be an absolute pathname or the tool may be in the PATH",
    "xdg-open")

local title_widget = dt.new_widget("entry") {
  placeholder="Title"
}
local widget = dt.new_widget("box") {
  orientation=horizontal,
  dt.new_widget("label"){label = "Title:"},
  title_widget
}

local ending = [[
\end{document}
]]

local thumbs_per_line=4;
local width = 1/thumbs_per_line-0.01

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

dt.register_storage("export_pdf","Export thumbnails to pdf",
    nil,
    function(storage,image_table)
      local my_title = title_widget.text
      if my_title == "" then
        my_title = "Title"
      end
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
      local result = coroutine.yield("RUN_COMMAND",command)
      if result ~= 0 then
        dt.print("Problem running pdflatex") -- this one is probably usefull to the user
        error("Problem running "..command)
      end

      -- open the PDF
      local pdffile=string.gsub(filename, ".tex", ".pdf")
      command = dt.preferences.read("selection_to_pdf","Open with","string")
      command = command.." "..pdffile
      local result = coroutine.yield("RUN_COMMAND",command)
      if result ~= 0 then
        dt.print("Problem running pdf viewer") -- this one is probably usefull to the user
        error("Problem running "..command)
      end

      -- finally do some clean-up
      for img,file in pairs(image_table) do
         os.remove(file)
      end
    end,nil,nil,widget)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
