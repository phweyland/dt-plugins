--[[
    Tested with darktable 2.4.1 on Windows 10. Needs more work to run on Linux

    fileondiskExif.lua - export images to a given folder and set Metadata
    using ExifTool. exported selected - "file on disk (Exif)":
      - darktable Metadata
      - GPS data
      - HierarchicalSubject
        - eliminate private tags (based on first level of tags declared as
        private in Preferences). Examples: people
        - eliminate first level of tags (considered as categories only local
        to dt). Examples: people, places, ...
      - Subject. From the previous list, establish the individuals tags list

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
    * in the export dialog select "file on disk (Exif)" and select the format and bit depth for the
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

local function setPrivateTags(privateTagsList)
  local privateTags = {}
  local i = 0
  while privateTagsList:len() > 0 and i < 100 do
    ptag = string.match(privateTagsList,"([^,]*),")
    if not ptag then -- last tag
      ptag = privateTagsList
      privateTagsList = ""
    end
    if privateTagsList ~= "" then
      privateTagsList = string.sub(privateTagsList,ptag:len()+2)
    end
    if ptag then
      table.insert(privateTags,ptag)
    end
    i = i + 1  -- not too sure to exit always properly
  end
  return privateTags
end

local privateTagsList = ""
local privateTags = {}

local function removeDuplicate(keywords)
  local i = 0
  local newKeywords = ""
  while keywords:len() > 0 and i < 100 do
    keyword = string.match(keywords,"([^,]*),")
    if not keyword then -- last keyword
      keyword = keywords
      keywords = ""
    end
    if keyword then
      if keywords ~= "" then
        keywords = string.sub(keywords,keyword:len()+3)
      end
      if newKeywords == ""
      then newKeywords = keyword
      else
        if not string.match(newKeywords,keyword) then
          if newKeywords ~= "" then
            newKeywords = newKeywords..", "
          end
          newKeywords = newKeywords..keyword
        end
      end
    end
--    dt.print_log("keys: "..tostring(keywords).." key: "..tostring(keyword).." nkeys: "..tostring(newKeywords))
    i = i + 1  -- not too sure to exit always properly
  end
  return newKeywords
end

-- not a number
local NaN = 0/0

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

local fileondiskExif_widget = dt.new_widget("box") -- widget
{
   orientation = "vertical",
   target_folderb
}

local function show_status(storage, image, format, filename,
  number, total, high_quality, extra_data)
    dt.print(string.format(_("Export Image %i/%i"), number, total))
    dt.print_log(string.format(_("Export Image %i/%i"), number, total).." "..filename)
end

local function ExifTool_metadata(storage, image_table, extra_data) --finalize

  privateTagsList = dt.preferences.read("prefExifTool","ExifPrivateTags","string")
  dt.print_log("ExifTool private tags: "..privateTagsList)
  if privateTagsList
  then privateTags = setPrivateTags(privateTagsList)
  else privatTags = {}
  end
  local ExifTool_executable = dt.preferences.read("prefExifTool","ExifTool","file")
  ExifTool_executable = df.check_if_bin_exists(ExifTool_executable)
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

  local ExifStartCommand
  for image,exported_image in pairs(image_table) do
    local myimage_name = target_folderb.value .. "\\" .. df.get_filename(exported_image)
    os.remove(myimage_name)  -- because overwriting screws the file
    local result = df.file_move(exported_image, myimage_name)
    dt.print_log(exported_image .. " moved to " .. myimage_name)
    if result then
      -- Tags => HierarchicalSubject
      HSubject = ""; Subject = ""
      for _, tag in ipairs(image:get_tags()) do
        if not (string.sub(tag.name, 1, string.len("darktable|")) == "darktable|") then
          local privateTag = false
          for _, ptag in ipairs(privateTags) do
--        dt.print_log("private: "..ptag.." "..tag.name)
            if (string.sub(tag.name, 1, string.len(ptag)) == ptag) then
              privateTag = true
              break
            end
          end
          if not privateTag then
            category = string.match(tag.name,"([^|]+)")
            hierarchicaltag = string.sub(tag.name,category:len()+2)
  --      dt.print_log(hierarchicaltag)
            --valid tag
            if HSubject ~= ""
            then HSubject = HSubject..", " end
            HSubject = HSubject..hierarchicaltag
--            dt.print_log("keywords: "..HSubject)
          end
        end
      end
      -- Tags => Subject
      dt.print_log("HierarchicalSubject: "..HSubject)
      Subject = removeDuplicate(string.gsub(HSubject,"|",", "))
      dt.print_log("Subject: "..Subject)
      -- Metadata
      local metadata = ""
      if image.title then
        metadata = metadata.." -XMP:Title=\""..image.title.."\""
      end
      if image.description then
        metadata = metadata.." -XMP:Description=\""..image.description.."\""
      end
      if image.publisher then
        metadata = metadata.." -XMP:Publisher=\""..image.publisher.."\""
      end
      if image.creator then
        metadata = metadata.." -XMP:Creator=\""..image.creator.."\""
      end
      if image.rights then
        metadata = metadata.." -XMP:Rights=\""..image.rights.."\""
      end
      dt.print_log("Metadata: "..metadata)
      -- GPS
      local GPSdata = ""
      if image.latitude then
        GPSdata = GPSdata.." -XMP:GPSLatitude=\""..image.latitude.."\""
      end
      if image.longitude then
        GPSdata = GPSdata.." -XMP:GPSLongitude=\""..image.longitude.."\""
      end
      if image.elevation then
        GPSdata = GPSdata.." -XMP:GPSAltitude=\""..image.elevation.."\""
      end
      dt.print_log("GPSdata: "..GPSdata)

            -- Run ExifTool
      ExifStartCommand = string.gsub(ExifTool_executable,"[\"]+","")
      ExifStartCommand = ExifStartCommand.." -@ "..string.gsub(ArgumentFile,"[\"|\']+","")
      if metadata ~= "" then
        ExifStartCommand = ExifStartCommand..metadata
      end
      if GPSdata ~= "" then
        ExifStartCommand = ExifStartCommand..GPSdata
      end
      if HSubject ~= "" then
        ExifStartCommand = ExifStartCommand.." -sep \", \" -XMP:HierarchicalSubject=\""..HSubject.."\""
        ExifStartCommand = ExifStartCommand.." -sep \", \" -XMP:Subject=\""..Subject.."\""
      end
      ExifStartCommand = ExifStartCommand.." "..myimage_name
      dt.print_log(ExifStartCommand)
      dt.control.execute(ExifStartCommand)
    end
  end
end

-- Register
dt.print_log("Target folder :"..tostring(target_folderb.value))

dt.preferences.register("prefExifTool",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "ExifPrivateTags",  -- name
                        "string",                       -- type
                        "ExifTool Private Tags",              -- label
                        "like \"people,archive\"",      -- tooltip
                        "")                           -- default
dt.print_log("ExifTool private tags :"..tostring(privateTagsList))

dt.preferences.register("prefExifTool",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "ExifArgFile",  -- name
                        "file",                       -- type
                        "ExifTool Argument file",              -- label
                        "",      -- tooltip
                        "")                           -- default
dt.print_log("ExifTool argument file :"..tostring(ArgumentFile))

if dt.configuration.running_os ~= "linux" then
  dt.preferences.register("prefExifTool",        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                          "ExifTool",  -- name
                          "file",                       -- type
                          "ExifTool executable",              -- label
                          "",      -- tooltip
                          "")                           -- default
end
dt.print_log("ExifTool executable :"..tostring(ExifTool_executable))

dt.register_storage("fileondiskExif", _("file on disk (exif)"), show_status, ExifTool_metadata, nil, nil, fileondiskExif_widget)
dt.print_log("register exiftool widget")

--
