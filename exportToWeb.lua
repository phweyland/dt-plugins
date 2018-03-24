--[[

    exportToWeb.lua - export and remove unwanted Metadata

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
    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    * Exiftool

    USAGE
    * require this script from your main lua file
    * select an image or images to export
    * in the export dialog select "Export to Web" and select the format and bit depth for the
      exported image
    * Press "export"

    CHANGES
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext
local ExifTool_widget = nil

dt.configuration.check_version(...,{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("ExifTool",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("ExifTool", msgid)
end

--local ExifTool_executable = dt.preferences.read("prefExifTool","ExifTool","file")
local ArgumentFile = dt.preferences.read("prefExifTool","ExifArgFile","file")

local target_folderb = dt.new_widget("file_chooser_button")
{
    title = "target_folder",  -- The title of the window when choosing a file
    value = dt.preferences.read("prefExifTool","TargetFolder","directory"),                       -- The currently selected file
    is_directory = true,              -- True if the file chooser button only allows directories to be selecte
    changed_callback = function (self)
      dt.print_log("change target folder to :"..self.value)
      dt.preferences.write("prefExifTool","TargetFolder","directory",self.value)
    end
}

local executables = {"ExifTool"}
if dt.configuration.running_os ~= "linux" then
  ExifTool_widget = df.executable_path_widget(executables)
end

local exportToWeb_widget = dt.new_widget("box") -- widget
{
   orientation = "vertical",
   ExifTool_widget,
   target_folderb
}

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
    dt.print_log(string.format(_("Export Image %i/%i"), number, total).." "..filename)
end

local function ExifTool_metadata(storage, image_table, extra_data) --finalize

  --local ExifTool_executable = dt.preferences.read("prefExifTool","ExifTool","file")
  local ExifTool_executable = df.check_if_bin_exists("ExifTool")
  if not ExifTool_executable then
    dt.print(_("ExitTool not found, see preferences"))
    return
  end
  dt.print_log("ExifTool executable: "..ExifTool_executable)

  local ArgumentFile = dt.preferences.read("prefExifTool","ExifArgFile","file")
  ArgumentFile = df.check_if_bin_exists(ArgumentFile)
  if not ArgumentFile then
    dt.print(_("Argument file not found, see preferences"))
    return
  end
  dt.print_log("ExifTool argument file: "..ArgumentFile)
  --[[ doesn't work
  if (not string.match(ExifTool_executable, '.exe$') and not string.match(ExifTool_executable, '.EXE$')) and dt.configuration.running_os == "windows" then
    dt.print(_("ExitTool not executable, see preferences").." "..tostring(string.match(ExifTool_executable, ".exe$")))
    return
  end --]]
  local ExifStartCommand
  for image,exported_image in pairs(image_table) do
    local myimage_name = target_folderb.value .. "\\" .. df.get_filename(exported_image)
    os.remove(myimage_name)  -- because overwriting screws the file
    local result = df.file_move(exported_image, myimage_name)
    dt.print_log(exported_image .. " moved to " .. myimage_name)
    if result then
      ExifStartCommand = ExifTool_executable.." -@ "..string.gsub(ArgumentFile,"[\"|\']+","").." "..myimage_name
      dt.print_log(ExifStartCommand)
      dt.control.execute(ExifStartCommand)
    end
  end


end

-- Register
dt.print_log("Target folder :"..target_folderb.value)
--[[
if dt.configuration.running_os ~= "linux" then
  dt.preferences.register("prefExifTool",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                          "ExifTool",  -- name
                          "file",                       -- type
                          "Select ExifTool executable",              -- label
                          "",      -- tooltip
                          "")                           -- default
  dt.print_log("register exiftool executable")
end
dt.print_log("ExifTool executable :"..ExifTool_executable)
--]]
dt.preferences.register("prefExifTool",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "ExifArgFile",  -- name
                        "file",                       -- type
                        "Select ExifTool Argument file",              -- label
                        "",      -- tooltip
                        "")                           -- default
dt.print_log("register exiftool argument file")


dt.register_storage("exportToWeb", _("Export to Web"), show_status, ExifTool_metadata, nil, nil, exportToWeb_widget)
dt.print_log("register exiftool widget")

--
