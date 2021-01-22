local dt = require "darktable"
local df = require "lib/dtutils.file"

local exiv2 = df.check_if_bin_exists("exiv2")

if not exiv2 then
  dt.print("exiv2 not found")
  error("exiv2 not found, exiting...")
end

local content = nil
local loaded_image = nil

local function callback(image, key)
  local result = "-"

  if(image == loaded_image) then
    local hfd = string.match(content, key .. "%s+ (.-)\n")
    if hfd then
      result = hfd
    end
  else
    local p = io.popen(exiv2 .. " -PEkt " .. image.path .. "/" .. image.filename)
    if p then
      content = p:read("*all")
      local hfd = string.match(content, key .. "%s+ (.-)\n")
      if hfd then
        result = hfd
      end
    end
    p:close()
    loaded_image = image
  end
  return result
end

local function callback_1(image)
  local result = callback(image, "Exif.NikonAf2.PhaseDetectAF")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "PhaseDetectAF",
  callback_1
)

local function callback_2(image)
  local result = callback(image, "Exif.Photo.SensingMethod")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "SensingMethod",
  callback_2
)


local function callback_3(image)
  local result = callback(image, "Exif.NikonLd3.FocusDistance")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "FocusDistance",
  callback_3
)


local function callback_4(image)
  local result = callback(image, "Exif.Photo.FocalLengthIn35mmFilm")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "FocalLengthIn35mmFilm",
  callback_4
)


local function callback_5(image)
  local result = callback(image, "Exif.Photo.ExposureMode")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "ExposureMode",
  callback_5
)

local function callback_6(image)
  local result = callback(image, "Exif.NikonLd3.FocusDistance")
  return result
end

dt.gui.libs.metadata_view.register_info(
  "FocusDistance bis",
  callback_6
)



dt.control.sleep(10000)
dt.gui.libs.metadata_view.destroy_info("SensingMethod")
