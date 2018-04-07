--[[
Maintain tags

AUTHOR
Philippe Weyland
Reued from Sebastian Witt (se.witt@gmx.net) rename-tags plugin

INSTALLATION
* copy this file in $CONFIGDIR/lua/ where CONFIGDIR
is your darktable configuration directory
* add the following line in the file $CONFIGDIR/luarc
  require "maintain-tags"

USAGE
* In lighttable there is a new entry: 'maintain tags'
* Enter old tag (this one gets deleted!) - Enter new tag name - Rename
* Show single or oprhan tags and Delete

LICENSE
GPLv2

]]

local dt = require "darktable"
-- GUI entries
local new_tag = dt.new_widget("entry") { tooltip = "enter new tag name" }
local defaultcombobox = "enter tag name"
local locked = false
local comboboxcount = 0

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
end

-- This function does the renaming
local function rename_tags(widget)
  -- If entries are empty, return
  if combobox.value == '' then
    dt.print ("old tag can't be empty")
    return
  end
  if new_tag.text == '' then
    dt.print ("new tag can't be empty")
    return
  end
  
  local Count = 0

  -- Check if old tag exists
  local ot = dt.tags.find (combobox.value)
  if not ot then
    dt.print ("old tag does not exist")
    return
  end

  -- Show job
  local job = dt.gui.create_job ("Renaming tag", true)
  
  combobox.editable = false
  new_tag.editable = false

  -- Create if it does not exists
  local nt = dt.tags.create (new_tag.text)

  -- Search images for old tag
  dbcount = #dt.database
  for i,image in ipairs(dt.database) do
    -- Update progress bar
    job.percent = i / dbcount
    
    local tags = image:get_tags ()
    for _,t in ipairs (tags) do
      if t.name == combobox.value then
        -- Found it, attach new tag
        image:attach_tag (nt)
        Count = Count + 1
      end
    end
  end

  -- Delete old tag, this removes it from all images
  dt.tags.delete (ot)

  job.valid = false
  dt.print ("renamed tags for " .. Count .. " images")
  combobox.editable = true
  new_tag.editable = true
end


local function show_orphan_tags(widget)
  local single_tags = {}
  local icount = {}
  local ticount = 0
  local count = 0
  local nimages = #dt.database
  local ntags = #dt.tags
  
  for _,tag in ipairs(dt.tags) do
    if not string.find(tag.name, "|")
    then
      table.insert(single_tags, tag)
      table.insert(icount,0)
    end
    count = count + 1
    dt.print(tostring(count).."/"..tostring(ntags))
  end

  count = 0
  for _,image in ipairs(dt.database) do
    local iflag = false
    local tags = image:get_tags ()
    for _,tag in ipairs(tags) do 
      for i,stag in ipairs(single_tags) do 
        if tag.name == stag.name then
          icount[i] = icount[i] + 1
          iflag = true
        end         
      end
    end
    if iflag then ticount = ticount + 1 end
    count = count + 1
    dt.print(tostring(count).."/"..tostring(nimages))
  end  

  for i,tag in ipairs(single_tags) do
    dt.print_log(tag.name.." ["..tostring(icount[i]).." images]")
  end

  if single_tags
  then
    dt.print(tostring(#single_tags).." tags for "..tostring(ticount).." images")
    dt.print_log(tostring(#single_tags).." tags for "..tostring(ticount).." images")
  else
    dt.print("no single tag")
    dt.print_log("no single tag")
  end
end

local function delete_orphan_tags(widget)
  local count = 0
  local single_tags = {}
  
  for _,tag in ipairs(dt.tags) do
    if not string.find(tag.name, "|")
    then
      table.insert(single_tags, tag)
    end
  end
  for _,tag in pairs(single_tags) do
    local tag_name = tag.name
    tag:delete()
    dt.print_log("deleted tag: "..tag_name)
    count = count + 1 
  end
  if count == 0
  then dt.print("no tag to delete")
  else dt.print(tostring(count).." deleted tag(s)")
  end
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
  dt.new_widget("separator"){},
  dt.new_widget ("box") {
    orientation = "horizontal",  
    dt.new_widget("button") {
      label = "   show single tags  ",
      tooltip = "show single level tags (no hierarchy)",
      clicked_callback = show_orphan_tags
    },
    dt.new_widget("button") {
      label = "   delete single tags  ",
      tooltip = "delete single level tags (no hierarchy)",
      clicked_callback = delete_orphan_tags
    }
  }
}


dt.register_lib ("maintain_tags", "maintain tags", true, true, {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 20},}, maintain_widget, nil, nil)

