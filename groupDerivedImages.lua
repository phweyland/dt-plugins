local dt = require "darktable"
-- local dbg = require "darktable.debug"

--[[
Tested with darktable 2.4.1 on Windows 10. Needs more work to run on Linux

Assume that derived images are stored in a sub-folder of master images.
Assume that derived images can come from external editors
	Group derived images to master ones
	(Re)Apply master images metadata to derived images
Available commands:
- set master: apply darktable|group|master tag to selected images
- group to master: group each selected image with its master image.
  A master image is recognized as follow:
    - belongs to parent folder of selected image
    - tagged as darktable|group|master
    - filename (without extension) included in selected image filename. Examples:
      20180315_BH.nef can be mater image of 20180315_BH.jpg or 20180315_BH-NVf.jpg
- update from master: copy master image's metadata to selected images, based on the following switches:
    - rate & color
    - metadata
    - GPS data
    - tags
- set leader: set the selected images as top of their group
- copy: copy selected image's metadata
- paste: paste copied metadata to selected images, based on previous switches.
- clear: clear selected images' metadata, based on previous switches.
]]

--[[  -- ZBS settings
-- So far I didn't succeed using ZeroBraneStudio with darktable.
package.cpath = "C:/Documents/Darktable/lua/luasocket/?.dll;"..package.cpath
package.path = package.path..";C:/Program Files (x86)/ZeroBraneStudio/lualibs/mobdebug/?.lua;C:/Program Files (x86)/ZeroBraneStudio/lualibs/?.lua"
require('mobdebug').start()
--dt.print(debug.getinfo(1,"S").source)
--debug.verbose=true
--require('mobdebug').checkcount = 1
--]]

local gettext = dt.gettext
dt.configuration.check_version(...,{2,0,0},{3,0,0},{4,0,0},{5,0,0})
-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("test",dt.configuration.config_dir.."/lua/locale/")

-- generic function on table
local function has_value (tab, val)
  for index, value in ipairs(tab) do
    if value == val then
      return index
    end
  end
  return nil
end

-- get film object for this path
local function getfilm(path)
	for _, film in ipairs(dt.films) do
		if film.path == path then
			return film
		end
	end
end
--get master image in parent directory
local function getmasterimage(filename,mfilm)
	local base = filename:match("(.-)%.[^%.]+$"):upper()
	local nbim = #mfilm
	local i = 0
	for _, im in ipairs(mfilm) do
		mbase = im.filename:match("(.-)%.[^%.]+$"):upper()
		if mbase == base:sub(1,#mbase) -- accept base longer than mbase
		then
      tags = im:get_tags()
      for _,tag in ipairs(tags) do
        if tag.name == "darktable|group|master"
        then return im end
      end
    end
		i = i + 1 -- to avoid an index issue on this list
		if i == nbim then return nil end
	end
	return nil
end
-- group selected images to master images
local function groupDerivedImages(images)
--  require('mobdebug').on()
	local list = {}
	local fi = 0
	local gi = 0
--	local message = ""
	for i,image in ipairs(images) do
		list[i] = {}
		list[i].image = image
		list[i].ppath = image.path:match("(.-)[\\/][^\\/]+$")
		list[i].mfilm = getfilm(list[i].ppath)
		if list[i].mfilm ~= nil then
			list[i].mimage = getmasterimage(image.filename, list[i].mfilm)
			if list[i].mimage ~= nil then
				list[i].mfilename = list[i].mimage.filename
				fi = fi + 1
			end
		end
  end
	dt.print("masters found "..tostring(fi))
	for _,image in pairs(list) do
	-- put the image in the group of the master image
		if image.mimage ~= nil then
			image.image:group_with(image.mimage)
			gi = gi + 1
      dt.print("masters found "..tostring(fi).." grouped "..tostring(gi))
    	dt.print_log("masters found "..tostring(fi).." grouped "..tostring(gi))
		end
--message = message.." "..image.image.filename.." -> ".. tostring(image.mfilename).."\n"
	end
--dt.print_log(message)
end

-- Metadata related data
local bRateColor = dt.new_widget("check_button")
  {label = " rate & color    ",
    value = dt.preferences.read("groupDerivedImages","copyRateColor","bool")}
local bMetadata = dt.new_widget("check_button")
  {label = " metadata",
    value = dt.preferences.read("groupDerivedImages","copyMetadata","bool")}
local bGPS = dt.new_widget("check_button")
  {label = " GPS data",
    value = dt.preferences.read("groupDerivedImages","copyGPS","bool")}
local bTags = dt.new_widget("check_button")
  {label = " tags",
    value = dt.preferences.read("groupDerivedImages","copyTags","bool")}

local function savepreference()
  dt.preferences.write("groupDerivedImages","copyRateColor","bool",bRateColor.value)
  dt.preferences.write("groupDerivedImages","copyMetadata","bool",bMetadata.value)
  dt.preferences.write("groupDerivedImages","copyGPS","bool",bGPS.value)
  dt.preferences.write("groupDerivedImages","copyTags","bool",bTags.value)
end

-- not a number
local NaN = 0/0

local have_data = false
local rating = 0
local red = false
local green = false
local yellow = false
local blue = false
local purple = false
local title = ""
local description = ""
local creator = ""
local publisher = ""
local rights = ""
local elevation = NaN
local latitude = NaN
local longitude = NaN
local tags = {}

local message1 = ""
local message2 = ""
local message3 = ""

-- copy Metadata from image
local function copyMetadata(image)
  if not image then
    have_data = false
  else
    have_data = true
    rating = image.rating
    red = image.red
    green = image.green
    yellow = image.yellow
    blue = image.blue
    purple = image.purple
    title = image.title
    description = image.description
    creator = image.creator
    publisher = image.publisher
    rights = image.rights
    elevation = image.elevation
    latitude = image.latitude
    longitude = image.longitude
    tags = {}
    for _, tag in ipairs(image:get_tags()) do
			if tag.name ~= nil then
	      if not (string.sub(tag.name, 1, string.len("darktable|")) == "darktable|") then
	        table.insert(tags, tag)
	      end
			else
				message2 = "Error - Nul tag detected on master image "
				dt.print_log(message2..image.filename)
			end
    end
  end
end
-- paste metadata to image
local function pasteMetadata(image)
  if have_data then
    if bRateColor.value then
      image.rating = rating
      image.red = red
      image.green = green
      image.yellow = yellow
      image.blue = blue
    end
    if bMetadata.value then
      image.title = title
      image.description = description
      image.creator = creator
      image.publisher = publisher
      image.rights = rights
    end
    if bGPS.value then
      image.elevation = elevation
      image.latitude = latitude
      image.longitude = longitude
    end
    if bTags.value then
      -- Clear unused old tags
      for _, tag in ipairs(image:get_tags()) do
				if tag.name ~= nil then
	        if not (string.sub(tag.name, 1, string.len("darktable|")) == "darktable|") then
						tagi = has_value(tags, tag)
						if tagi ~= nil then
							table.remove(tags, tagi) -- avoid to remove it and add it again later on
						else
	          	image:detach_tag(tag)
						end
	        end
				else
					message3= "Error - Nul tag detected on derived image "
					dt.print_log(message3..image.filename)
				end
      end
      -- add the remaining tags
      for _, tag in ipairs(tags) do
        image:attach_tag(tag)
      end
    end
  end
end

-- paste metadata to selected images
local function mpasteMetadata(images)
	local di = 0
  for _, image in ipairs(images) do
    pasteMetadata(image)
		di = di + 1
  end
	dt.print("pasted "..tostring(mi))
	dt.print_log("pasted "..tostring(mi))
end

-- check if the image is a master
local function isamaster(m)
	tags = m:get_tags()
	for _,tag in ipairs(tags) do
--dt.print_log("udpate image "..m.filename.." tagname "..tostring(tag.name))
		if tag.name ~= nil then
			if tag.name == "darktable|group|master" then
				return m
			end
		else
			message2 = "Error - Nul tag detected on master image "
			dt.print_log(message2..m.filename)
		end
	end
	return nil
end

-- function update derived metadata from master images
local function updateDerivedMetadata(images)
	local list = {}
	local di = 0
	local mi = 0
	local ci = 0
	for _,image in ipairs(images) do
		local pairimage = {}
		pairimage.image = image
		di = di + 1
    local members = image:get_group_members()
--message = "derived "..image.filename.." members "
--for _,m in ipairs(members) do message = message..m.filename.." " end
--dt.print_log(message)
		for _,m in ipairs(members) do
dt.print_log("member "..m.filename)
      if m ~= image then -- avoid itself
				if isamaster(m) then
					mi = mi + 1
					pairimage.mimage = m
dt.print_log("image to be copied "..pairimage.mimage.filename.." to "..pairimage.image.filename)
--					list[mi] = pairimage
					table.insert(list, pairimage)
					break
				end
			end
		end
  end
	dt.print("derived "..tostring(di).." master "..tostring(mi))
	dt.print_log("derived "..tostring(di).." master "..tostring(mi))
	message2 = ""
	message3 = ""
	for _,grp in ipairs(list) do
    if grp.mimage ~= nil then
      copyMetadata(grp.mimage)
      pasteMetadata(grp.image)
			ci = ci + 1
		end
		dt.print("derived "..tostring(di).." master "..tostring(mi).." copied "..tostring(ci).."\n"..message2..message3)
	end
  dt.print_log("copied "..tostring(ci))
end

-- set images as master
local function setMaster(images)
	local mi = 0
    -- Check if darktable|group|master tag exists
  local mt = dt.tags.find ("darktable|group|master")
  if not mt then
    mt = dt.tags.create ("darktable|group|master")
  end
  for _, image in ipairs(images) do
    image:attach_tag(mt)
		mi = mi + 1
    dt.print("set master "..tostring(mi))
  	dt.print_log("set master "..tostring(mi))
  end
end

-- set images as leader (top of group)
local function setLeader(images)
	local li = 0
  for _, image in ipairs(images) do
    image:make_group_leader()
		li = li + 1
    dt.print("set leader "..tostring(li))
  	dt.print_log("set leader "..tostring(li))
  end
end

-- clear image metadata
local function mclearMetadata(images)
	local di = 0
  if bRateColor.value then
    rating = 0
    red = false
    green = false
    yellow = false
    blue = false
    purple = false
  end
  if bMetadata.value then
    title = ""
    description = ""
    creator = ""
    publisher = ""
    rights = ""
  end
  if bGPS.value then
    elevation = NaN
    latitude = NaN
    longitude = NaN
  end
  if bTags.value then
    tags = {}
  end
  have_data = true
  for _, image in ipairs(images) do
    pasteMetadata(image)
		di = di + 1
  end
	dt.print("cleared "..tostring(di))
  have_data = false
end

-- buttons definition
local bsetmaster = dt.new_widget("button")
{
  label = "        set master       ",
  clicked_callback = function (_)
    setMaster(dt.gui.action_images)
  end
}
local bgrouptomaster = dt.new_widget("button")
{
  label = "      group to master    ",
  clicked_callback = function (_)
    groupDerivedImages(dt.gui.action_images)
  end
}
local bsetleader = dt.new_widget("button")
{
  label = "        set leader      ",
  clicked_callback = function (_)
    setLeader(dt.gui.action_images)
  end
}
local bupdatefrommaster = dt.new_widget("button")
{
	label = "   update from master   ",
  clicked_callback = function (_)
  	updateDerivedMetadata(dt.gui.action_images)
  end
}
local bcopymetadata = dt.new_widget("button")
{
  label = "        copy            ",
  clicked_callback = function (_)
    copyMetadata(dt.gui.action_images[1])
  end
}
local bpastemetadata = dt.new_widget("button")
{
  label = "        paste           ",
	clicked_callback = function (_)
    mpasteMetadata(dt.gui.action_images)
  end
}
local bclearmetadata = dt.new_widget("button")
{
  label = "        clear           ",
  clicked_callback = function (_)
    mclearMetadata(dt.gui.action_images)
  end
}

-- widget definition
if (dt.configuration.api_version_major >= 6) then
-- not tested and to be updated for version >= 6
  dt.print("´part to be completed")
  local section_label = dt.new_widget("section_label")
  {
    label = "MySectionLabel"
  }
  dt.register_lib(
    "GroupMetadataModule",     -- Module name
    "GroupMetadataModule",     -- name
    true,                -- expandable
    false,               -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
    dt.new_widget("box") -- widget
    {
      orientation = "vertical",
      section_label
    },
    nil,-- view_enter
    nil -- view_leave
  )
else
  dt.register_lib(
    "GroupMetadataModule",     -- Module name
    "group &amp; metadata",     -- name
    true,                -- expandable
    false,               -- resetable
    {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100}},   -- containers
    dt.new_widget("box") -- widget
    {
      orientation = "vertical",
      dt.new_widget("box") -- widget
      {
        orientation = "horizontal",
        bsetmaster,
        bgrouptomaster
      },
      dt.new_widget("separator"){},
			dt.new_widget("box") -- widget
      {
        orientation = "horizontal",
      	bupdatefrommaster,
				bsetleader
			},
      dt.new_widget("separator"){},
      dt.new_widget("box") -- widget
      {
        orientation = "horizontal",
        bcopymetadata,
        bpastemetadata,
        bclearmetadata
      },
      dt.new_widget("separator"){},
      dt.new_widget("box") -- widget
      {
       orientation = "horizontal",
        dt.new_widget("box") -- widget
        {
          orientation = "vertical",
          bRateColor,
          bMetadata,
        },
       dt.new_widget("box") -- widget
        {
          orientation = "vertical",
          bGPS,
          bTags
        }
      }
     },
    nil,-- view_enter
    nil -- view_leave
  )
end

-- register event set selected images as master
dt.register_event("shortcut",
	function(event, shortcut) setMaster(dt.gui.action_images) end,
	"g-set master"
)
-- register event set selected images as leader
dt.register_event("shortcut",
	function(event, shortcut) setLeader(dt.gui.action_images) end,
	"g-set leader"
)
-- register event group selected images to master
dt.register_event("shortcut",
	function(event, shortcut) groupDerivedImages(dt.gui.action_images) end,
	"g-group derived images"
)
-- register event copy master images metadata to selected images
dt.register_event("shortcut",
	function(event, shortcut) updateDerivedMetadata(dt.gui.action_images) end,
	"g-update derived metadata"
)
-- register event copy metadata from selected image
dt.register_event("shortcut",
  function(event, shortcut) copyMetadata(dt.gui.action_images[1]) end,
  "g-copy metadata"
)
-- register event paste metadata to selected images
dt.register_event("shortcut",
  function(event, shortcut) mpasteMetadata(dt.gui.action_images) end,
  "g-paste metadata"
)
-- register event clear metadata of selected images
dt.register_event("shortcut",
  function(event, shortcut) mclearMetadata(dt.gui.action_images) end,
  "g-clear metadata"
)

-- register exit event
dt.register_event(
  "exit",
  function() savepreference() end
)
