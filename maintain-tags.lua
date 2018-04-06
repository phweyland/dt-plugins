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
local updatedcombobox = true
local comboboxcount = 0

local function updatetagslist(cbox)
  if locked == true then
    dt.print_log("Attempt to reenter: "..tostring(comboboxcount)..";text entered: "..cbox.value)
    return
  end
  comboboxcount = comboboxcount + 1
  dt.print_log("Enter count: "..tostring(comboboxcount))
  locked = true
  local nbentries = #cbox
  local entry = cbox.value
  local index = cbox.selected
  local maxentries = 50
  
  if not entry then
    updatedcombobox = false
    dt.print_log("No entry")
  elseif updatedcombobox then
    updatedcombobox = false
    dt.print_log("Enter again after change")
  else
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
      dt.print_log("Tag not found: "..tostring(entry))
      dt.print ("Tag not found: "..tostring(entry))
    else
      dt.print_log("Nb of tags found: "..tostring(i-1))
      if index ~= 0 then
        new_tag.text = cbox[1]
      end
      --clear rest of the list
      if (nbentries > i) and (i > 1) then
        for j = nbentries, i, -1 do
          cbox[j] = nil
        end
      end
      updatedcombobox = true
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
  if combobox.value == '' then
    dt.print ("Old tag can't be empty")
    return
  end
  if new_tag.text == '' then
    dt.print ("New tag can't be empty")
    return
  end
  
  local Count = 0

  -- Check if old tag exists
  local ot = dt.tags.find (combobox.value)
  if not ot then
    dt.print ("Old tag does not exist")
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
  dt.print ("Renamed tags for " .. Count .. " images")
  combobox.editable = true
  new_tag.editable = true
end

local function maintain_reset(widget)
  local items = #dt.tags
  dt.print_log("number of tags: "..tostring(items))
  new_tag.text = ''
  combobox[1] = defaulttagentry
  combobox.value = 1
end

local function show_orphan_tags(widget)
  local list = ""
  for _,tag in ipairs(dt.tags) do
    if not string.find(tag.name, "|")
    then
      if list ~= "" then
        list = list.."\n"
      end
      -- Count images for tag
      local count = 0
      for i,image in ipairs(dt.database) do
        local tags = image:get_tags ()
        for _,t in ipairs (tags) do
          if t.name == tag.name then
            count = count + 1
          end
        end
      end
      list = list..tag.name.." ["..tostring(count).." images]"
    end
  end
  if list == ""
  then dt.print("no single tag")
  else dt.print(list)
  end
end

local function delete_orphan_tags(widget)
  local count = 0
  for _,tag in ipairs(dt.tags) do
    if not string.find(tag.name, "|")
    then
      dt.print_log("deleted tag: "..tag.name)
      dt.tags.delete(tag)
      count = count + 1
    end
  end
  dt.print(tostring(count).." deleted tag")
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

