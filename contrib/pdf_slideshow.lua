--[[
  This file is part of darktable,
  copyright (c) 2017 Pascal Obry

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
Generates a PDF slideshow (via Latex) containing all selected images
one per slide.

ADDITIANAL SOFTWARE NEEDED FOR THIS SCRIPT
* a PDF-Viewer
* pdflatex (Latex)

USAGE
* require this file from your main lua config file:

This plugin will add a new exporter that will allow you to generate a pdf slideshow.
The interface will let you add:
   - a global title for the slideshow (prefix in all slide label)
   - a delay for the transition between each slide

Each slide will contain a single picture with a label at the bottom with the
format (all fields can be the empty string):

   <global title> / <image creator> / <image title>

]]
local dt = require "darktable"
require "official/yield"

local gettext = dt.gettext

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("pdf_slideshow",dt.configuration.config_dir.."/lua/")

local function _(msgid)
    return gettext.dgettext("pdf_slideshow", msgid)
end

dt.configuration.check_version(...,{4,0,0},{5,0,0})

dt.preferences.register
   ("pdf_slideshow","open with","string",
    _("a pdf viewer"),
    _("can be an absolute pathname or the tool may be in the PATH"),
    "xdg-open")

local title_widget = dt.new_widget("entry") {
    placeholder=_("slideshow title")
}
local delay_widget = dt.new_widget("slider")
{
    label = _("transition delay (s)"),
    soft_min = 1,     -- The soft minimum value for the slider, the slider can't go beyond this point
    soft_max = 20,    -- The soft maximum value for the slider, the slider can't go beyond this point
    hard_min = 1,     -- The hard minimum value for the slider, the user can't manually enter a value beyond this point
    hard_max = 60,    -- The hard maximum value for the slider, the user can't manually enter a value beyond this point
    value = 5,        -- The current value of the slider
    step = 1,
    digits = 0
}
local check_button_title = dt.new_widget("check_button")
{
    label = _('include image title'),
    value = true,
    tooltip = _('whether to include the image title (if defined) into the slide')
}
local check_button_author = dt.new_widget("check_button")
{
    label = _('include image author'),
    value = true,
    tooltip = _('whether to include the image author (if defined) into the slide')
}
local widget = dt.new_widget("box") {
    orientation=horizontal,
    dt.new_widget("label"){label = _("slideshow title")},
    title_widget,
    dt.new_widget("label"){label = ""},
    delay_widget,
    check_button_title,
    check_button_author
}

local ending = [[
\end{document}
]]

--  only jpeg files are supported by latex
local function support_format(storage, format)
  fmt = string.lower(format.name)
  if string.match(fmt,"jpeg") ~= nil and string.match(fmt,"2000") == nil then
    return true
  else
    return false
  end
end

local filename =dt.configuration.tmp_dir.."/pdfout.tex"

local function my_write(latexfile,arg)
  local res,errmsg = latexfile:write(arg)
  if not res then
    error(errmsg)
  end
end

local function slide(latexfile,i,image,file)
  local title = ""
  if title_widget.text ~= "" then
    title = title_widget.text
  end
  if check_button_author.value == true and image.creator ~= "" then
    if title ~= "" then
       title = title.." / "
    end
    title = title..image.creator
  end
  if check_button_title.value == true and image.title ~= "" then
    if title ~= "" then
       title = title.." / "
    end
    title = title..image.title
  end

  --  make sure there is no non-printable characters in the title
  title = string.gsub(title, "\n", "")
  title = string.gsub(title, "\r", "")
  title = string.gsub(title, "\t", "")

  local lfile = "slide"..i..".jpg"
  os.rename(file, lfile)

  --  fact is that latex will get confused if the filename has multiple dots.
  --  so \includegraphics{file.01.jpg} wont work. We need to output the filename
  --  and extention separated, e.g: \includegraphics{{file.01}.jpg}
  local filenoext=string.gsub(lfile, "(.*)(%..*)", "%1")
  local ext=string.gsub(lfile, "(.*)(%..*)", "%2")
  my_write(latexfile,"\\begin{minipage}[b]{0,99\\textwidth}\n")

  my_write(latexfile,"\\includegraphics[height=0.95\\textheight]{{"..filenoext.."}"..ext.."}\\newline\n")
  my_write(latexfile,"\\centering{{\\color{white}\\verb|"..title.."|}}\n")
  my_write(latexfile,"\\end{minipage}\\quad\n")
end

dt.register_storage("pdf_slideshow",_("pdf slideshow"),
    nil,
    function(storage,image_table)

    local preamble = [[
    \documentclass[a4paper,10pt,landscape]{beamer}
    \usetheme{default}
    \usepackage[utf8]{inputenc}
    \usepackage{graphicx}
    \usepackage[space]{grffile} % needed to support filename with spaces
    \pagestyle{empty}
    \parindent0pt
    \usepackage{geometry}
    \usepackage{color}
    \pagecolor{black!100}
    \color{white}
    \geometry{a4paper,landscape,left=5mm,right=5mm, top=5mm, bottom=5mm}
    \mode<presentation>
    \transduration{]]..delay_widget.value..[[}
    \setbeamertemplate{footline}{}
    \setbeamertemplate{headline}{}
    \setbeamertemplate{frametitle}{}
    \setbeamertemplate{navigation symbols}{}
    \setbeamercolor{background canvas}{fg=white,bg=black!100}
    \setbeamercolor{normal text}{fg=white}
    \hypersetup{pdfstartpage=1,pdfpagemode=FullScreen}
    \begin{document}
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
         slide(latexfile,i,img,file)
         my_write(latexfile,"\n\\bigskip\n")
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
        error(_("problem running ")..command)
      end

      -- open the PDF
      local pdffile=string.gsub(filename, ".tex", ".pdf")
      command = dt.preferences.read("pdf_slideshow","open with","string")
      command = command.." "..pdffile
      local result = dt.control.execute(command)
      if result ~= 0 then
        dt.print(_("problem running pdf viewer")) -- this one is probably usefull to the user
        error(_("problem running ")..command)
      end

      -- finally do some clean-up
      local i = 1
      for img,file in pairs(image_table) do
         local lfile = "slide"..i..".jpg"
         os.remove(lfile)
         i = i+1
      end
    end,
    support_format,
    nil,
    widget)

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
