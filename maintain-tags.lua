--[[
Maintain tags

AUTHOR
Philippe Weyland
Reused from Sebastian Witt (se.witt@gmx.net) rename-tags plugin

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "maintain-tags"

USAGE
* In lighttable there is a new entry: 'maintain tags'
* Start enter existing tag name
*  - A combobox displays relevant tags
*  - Select the tag to be rename, this pre-fill the new tag name
*  - Modify the tag name as needed
*  - "rename" (the old tag gets deleted as tag.name is not writable!)
* "show single tags" and "show orphan tags" gives the option to delete some of them
*  - The list is shown in a big text
*  - Navigate as needed through the list ("start", "previous", "next" & "end")
*  - Copy the tags to be deleted and past them into the "tags to be deleted" big text
*  - When the list is ok, "delete tags"
* Widget "reset" clears widget data

LICENSE
GPLv2

]]

local dt = require "darktable"
-- rename GUI entries
local defaultcombobox = "enter tag name"
local locked = false
local comboboxcount = 0
local new_tag = dt.new_widget("entry") { text = "", tooltip = "enter new tag name" }

local function updatetagslist(cbox)
  if locked == true then
    dt.print_log("attempt to reenter: "..tostring(comboboxcount)..";text entered: "..cbox.value)
    return
  end
  comboboxcount = comboboxcount + 1
  dt.print_log("enter count: "..tostring(comboboxcount))
  locked = true
  local nbentries = #cbox
  local entry = cbox.value
  local index = cbox.selected
  local maxentries = 50
  
  if not entry then
    dt.print_log("no entry")
  elseif entry == defaultcombobox then
    dt.print_log("select default text") 
  elseif index ~= 0 then
    new_tag.text = entry
    dt.print_log("tag choosen: "..entry)
  else  -- user entered a text
    dt.print_log("text entered: "..tostring(entry).."; ".."number of entries: "..tostring(nbentries).."; selected: "..tostring(index))
    -- add matching entries
    local pattern = string.gsub(entry,"([%(%)%.%%%-%+%*%?%$%^])","%%%1")
    dt.print_log("pattern: "..pattern)
    i=1
    for _,tag in ipairs(dt.tags) do
      matchingstring = string.match(tag.name:upper(),pattern:upper())
      if not (string.sub(tag.name, 1, string.len("darktable|")) == "darktable|") and matchingstring
      then
        dt.print_log("add tag["..tostring(i).."]: "..tag.name)
        cbox[i] = tag.name
        i=i+1
      end
      if i > maxentries then break end
    end
    if i == 1 -- no match
    then
--      cbox[1] = defaultcombobox
      dt.print_log("tag not found: "..tostring(entry))
      dt.print ("tag not found: "..tostring(entry))
    else
      dt.print_log("nb of tags found: "..tostring(i-1))
      --clear rest of the list
      if (nbentries > i) and (i > 1) then
        for j = nbentries, i, -1 do
          cbox[j] = nil
        end
      end
      cbox.value = 1
    end
  end
  locked = false
end

-- GUI entries
local combobox = dt.new_widget("combobox"){
  label = "old tag",
  tooltip = "start enter tag name",
  editable = true,
  changed_callback = function (self)
    updatetagslist(self)
  end,
  value = 1,
  defaultcombobox
  }

-- This function does the renaming
local function rename_tags(widget)
  -- If entries are empty, return
  if combobox.value == "" then
    dt.print ("old tag can't be empty")
    return
  end
  if new_tag.text == "" then
    dt.print ("new tag can't be empty")
    return
  end
    -- Check if old tag exists
  local ot = dt.tags.find(combobox.value)
  if not ot then
    dt.print ("old tag does not exist")
    return
  end
  combobox.editable = false
  new_tag.editable = false
-- Check if new tag exists
  local nt = dt.tags.find(new_tag.text)
  if not nt then  -- doesn't exist
--[[ unfortunately tag.name is not writable
    nt = ot
    nt.name = new_tag.text
--]]
  -- Create if it does not exists
    nt = dt.tags.create (new_tag.text)
  end
  dt.print_log ("transfer images to new tag")
  -- Transfer images from old to new tag
  if #ot ~= 0 then  -- iteration issue
    for i,image in ipairs(ot) do
      image:attach_tag(nt)
      if i == #ot then break end  -- iteration issue
    end
  end
  dt.print("renamed tag: "..combobox.value.." to: "..new_tag.text.." for "..#ot.." images")
  -- Delete old tag, this removes it from all images
  dt.tags.delete (ot)
  combobox.editable = true
  new_tag.editable = true
end

-- delete tags GUI
local listmaxtags = 30
local tagsshowndefaulttext = "list of tags"
local tagstobedeleteddefaulttext = "tags to be deleted"
local tagsshown = dt.new_widget("text_view") {
  text = tagsshowndefaulttext,
  editable = true,
  tooltip = "list of tags"
}
local tagsshownnb = 0
local tagsshownindex = 0
local tagstobedeleted = dt.new_widget("text_view") {
  text = tagstobedeleteddefaulttext,
  editable = true,
  tooltip = "paste here the tags to be deleted"
}
local tagsshownlist = {}
local icount = {}
local ticount = 0
-- display part of the tags
local function display_tags(part)
-- tagsshownindex = index in tagsshownlist of the first displayed tag
  if part == "start" then
    tagsshownindex = 1
  elseif part == "previous" then
    tagsshownindex = math.max(1, tagsshownindex - listmaxtags)
  elseif part == "next" then
    tagsshownindex = math.max(1, math.min(tagsshownindex + listmaxtags, #tagsshownlist - listmaxtags))
  elseif part == "end" then
    tagsshownindex = math.max(1, #tagsshownlist - listmaxtags)
  end
  tagsshownnb = math.min(#tagsshownlist, tagsshownindex + listmaxtags - 1)
  tagsshown.text = ""
  for i = tagsshownindex, tagsshownnb do
      tagsshown.text = tagsshown.text..tagsshownlist[i].name.."\n"
  end
end
-- show orphan tags (without image)
local function show_orphan_tags(widget)
  local count = 0
  local ntags = #dt.tags
  tagsshownlist = {}
  tagsshownnb = 0
  tagsshownindex = 0  
  tagsshown.text = ""
  
  for _,tag in ipairs(dt.tags) do
    if #tag == 0
    then
      table.insert(tagsshownlist, tag)
    end
    count = count + 1
    dt.print(tostring(count).."/"..tostring(ntags))
  end
  if tagsshownlist
  then
    tagsshownnb = 0
    for i,tag in ipairs(tagsshownlist) do
      dt.print_log("orphan tag "..tag.name)
    end
    display_tags("start")
    dt.print(tostring(#tagsshownlist).." orphan tags")
    dt.print_log(tostring(#tagsshownlist).." orphan tags")
  else
    dt.print("no orphan tag")
    dt.print_log("no orphan tag")
  end
end
-- show single tags (one level tag or keyword)
local function show_single_tags(widget)
  local count = 0
  local ntags = #dt.tags
  tagsshownlist = {}
  icount = {}
  ticount = 0
  tagsshownnb = 0
  tagsshownindex = 0
  tagsshown.text = ""
  
  for _,tag in ipairs(dt.tags) do
    if not string.find(tag.name, "|")
    then
      table.insert(tagsshownlist, tag)
      table.insert(icount,#tag)
      ticount = ticount + #tag
    end
    count = count + 1
    dt.print(tostring(count).."/"..tostring(ntags))
  end

  if tagsshownlist
  then
    for i,tag in ipairs(tagsshownlist) do
      dt.print_log("single tag "..tag.name.." ["..tostring(icount[i]).." images]")
    end
    display_tags("start")
    dt.print(tostring(#tagsshownlist).." tags for "..tostring(ticount).." images")
    dt.print_log(tostring(#tagsshownlist).." tags for "..tostring(ticount).." images")
  else
    dt.print("no single tag")
    dt.print_log("no single tag")
  end
end

-- delete tags in the list off tags to be deleted
local function delete_list_tags()
  local count = 0
  local icount = 0
  for line in string.gmatch(tagstobedeleted.text,'[^\r\n]+') do
    for _,tag in ipairs(dt.tags) do
      if tag.name == line
      then
        icount = icount + #tag
        dt.print_log("deleted tag: "..tag.name)
        dt.print("deleted tag: "..tag.name)
        tag:delete()
        count = count + 1
      end
    end
  end
  if count == 0
  then dt.print("no tag to delete")
  else dt.print(tostring(count).." deleted tag(s) for "..tostring(icount).." image(s)")
  end
  tagstobedeleted.text = tagstobedeleteddefaulttext
end
-- reset the widget data
local function maintain_reset(widget)
  locked = true
  dt.print_log("reset maintain tag widget")
  new_tag.text = ""
  combobox[1] = defaultcombobox
  combobox.value = 1
  if (#combobox > 1) then
    for j = #combobox, 2, -1 do
      combobox[j] = nil
    end
  end
  locked = false
  tagsshownlist = {}
  tagsshown.text = tagsshowndefaulttext
  tagsshownnb = 0
  tagsshownindex = 0
  tagstobedeleted.text = tagstobedeleteddefaulttext
end

local maintain_widget = dt.new_widget ("box") {
  orientation = "vertical",
  reset_callback = maintain_reset,
  combobox,
  dt.new_widget ("box") {
    orientation = "horizontal",
    dt.new_widget("label") { label = "new tag" },
    new_tag,
    dt.new_widget("button") {
      label = "   rename  ",
      tooltip = "rename old tag to new tag",
      clicked_callback = rename_tags
    }
  },
--  dt.new_widget("separator"){},
  dt.new_widget("label") { label = "------------------------------------------------------------------------------", halign = "start"},
  dt.new_widget ("box") {
    orientation = "horizontal",  
    dt.new_widget("button") {
      label = "   show single tags  ",
      tooltip = "show single level tags (no hierarchy)",
      clicked_callback = show_single_tags
    },
    dt.new_widget("button") {
      label = "   show orphan tags  ",
      tooltip = "show orphan tags (no image attached)",
      clicked_callback = show_orphan_tags
    }
  },
  dt.new_widget("separator"){},
  tagsshown,
  dt.new_widget ("box") {
    orientation = "horizontal",  
    dt.new_widget("button") {
      label = "    |<    ",
      tooltip = "start",
      clicked_callback = function() display_tags("start") end
    },
    dt.new_widget("button") {
      label = "    <    ",
      tooltip = "previous",
      clicked_callback = function() display_tags("previous") end
    },
    dt.new_widget("button") {
      label = "    >    ",
      tooltip = "next",
      clicked_callback = function() display_tags("next") end
    },
    dt.new_widget("button") {
      label = "    >|    ",
      tooltip = "end",
      clicked_callback = function() display_tags("end") end
    }
  },
  dt.new_widget("label") { label = "------------------------------------------------------------------------------", halign = "start"},
  tagstobedeleted,
  dt.new_widget("button") {
    label = "   delete tags  ",
    tooltip = "delete list of tags",
    clicked_callback = function() delete_list_tags() end
  }
}


dt.register_lib ("maintain_tags", "maintain tags", true, true, {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 20},}, maintain_widget, nil, nil)

