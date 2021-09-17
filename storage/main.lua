local chests			= { peripheral.find("ironchest:obsidian_chest") }
local monitor		   =   peripheral.find("monitor")

local inventory = {}

-- Util ---

function TableSize(tab)
	if tab == nil then
		return 0
	end
	local tabSize = 0
	for aTab, bTab in pairs(tab) do
		tabSize = tabSize + 1
	end
	return tabSize
end

function Ternary(cond, T, F)
	if cond then
		return T
	else
		return F
	end
end

Log(msg)
    print(msg)
end

Err(e)
    Log("ERROR!")
    Log(textutils.serialize(e))
    error(e)
end

--- Inventory file ---

function Save()
	local invFile = fs.open("inventory", "w")
	invFile.write(textutils.serialise(inventory))
	invFile.close()
end

function Load()
	local invFile = fs.open("inventory", "r")
	if invFile == nil then
		return
	end
	inventory = textutils.unserialise(invFile.readAll())
	invFile.close()
end

--- Inventory mapping ---

function MapInventory()
	inventory["items"] = {}
	for chestName, chest in pairs(chests) do
		Log("Mapping inventory: " .. tostring(chestName) .. " / " .. tostring(table.getn(chests)))
		local chestItems = chest.list()
		for slot = 1, chest.size() do
			--local item = chest.getItemDetail(slot)
			local item = chestItems[slot]
			if item == nil then
				SetSlot("", 0, chestName, slot)
			else
				SetSlot(item.name, item.count, chestName, slot)
			end
		end
	end
	Save()
	Log("Inventory mapped")
end

-- Get all locations of an item
function GetItemInv(itemName)
	if inventory["items"][itemName] == nil then
		inventory["items"][itemName] = {}
	end
	return inventory["items"][itemName]
end

-- Set a slot in the chests for where an item is
function SetSlot(name, count, chestName, slot)
    if count < 0 then
        Err({
            ["type"] = "Neg slot",
            ["itemName"] = name,
            ["itemCount"] = count,
            ["chestName"] = chestName,
            ["chestSlot"] = slot
        })
    end
    
	--set new value in items table
	GetItemInv(name)
	if inventory["items"][name][chestName] == nil then
		inventory["items"][name][chestName] = {}
	end
    
    if name ~= "" and count == 0 then
        inventory["items"][name][chestName][slot] = nil
        inventory["items"][""][chestName][slot] = 0
    else
	    inventory["items"][name][chestName][slot] = count
    end

	--Save()
end

--- Get free slots avaliable ---
function CountEmptySlots()
	if inventory.items[""] == nil then
		return 0
	end
	local emptySlotCount = 0
	for ecsn, ecs in pairs(inventory.items[""]) do
		for esn, es in pairs(ecs) do
			emptySlotCount = emptySlotCount + 1
		end
	end
	return emptySlotCount
end

--- IO ---

-- Take from outChest and store
function Store(fromChest, fromSlot, toMove)
	if CountEmptySlots() == 0 then
		Log("Inventory full")
		return 0
	end
	local item = peripheral.wrap(fromChest).getItemDetail(fromSlot)
	if item ~= nil then
		local totalMoved = 0
		local maxStackSize = peripheral.wrap(fromChest).getItemLimit(fromSlot)
		if toMove == nil then
			toMove = maxStackSize
		end
		toMove = math.min(item.count, toMove)
		Log("Storing " .. tostring(toMove) .. " " .. item.name)
        function StoreToSlot(slotItemName)
            local itemInv = GetItemInv(slotItemName)
            for chestName, chestSlots in pairs(itemInv) do
                for slot, count in pairs(chestSlots) do
                    if count < maxStackSize then
                        local moved = chests[chestName].pullItems(fromChest, fromSlot, toMove, slot)
                        toMove = toMove - moved
                        totalMoved = totalMoved + moved
                        if moved > 0 then
                            SetSlot(item.name, count + moved, chestName, slot)
                        end
                        if toMove == 0 then
                            return true
                        end
                        if toMove < 0 then
                            Err({
                                ["type"] = "Over move",
                                ["chestName"] = chestName,
                                ["slotName"] = slotName,
                                ["itemName"] = item.name,
                                ["slotItemName"] = slotItemName,
                                ["totalToMove"] = toMove,
                                ["fromChest"] = fromChest,
                                ["fromSlot"] = fromSlot
                            })
                        end
                    end
                end
            end
            return false
        end
        if StoreToSlot(item.name) then
		    return totalMoved
        elseif StoreToSlot("") then
            return totalMoved
        else
            Err({
                ["type"] = "Desync"
            })
        end
	end
	return 0
end

-- Get from storage to outChest by name
function Get(itemName, count, toChest, toSlot)
    Log("Getting " .. tostring(count) .. " " .. itemName)
	local totalMoved = 0
	local itemInv = GetItemInv(itemName)--gets all slots where this item should be from file
	for chestName, chestSlots in pairs(itemInv) do
		for slotName, slotCount in pairs(chestSlots) do
			local slotItemDetail = chests[chestName].getItemDetail(slotName)
			if slotItemDetail == nil or slotItemDetail.name ~= itemName or slotItemDetail.count ~= slotCount then
				Err({
					["type"] = "Slot desync",
					["chestName"] = chestName,
					["slotName"] = slotName,
					["expectedItemName"] = itemName,
					["expectedItemCount"] = slotCount,
					["actualItemName"] = Ternary(slotItemDetail == nil, "Air", slotItemDetail.name),
					["actualItemCount"] = Ternary(slotItemDetail == nil, 0, slotItemDetail.count),
				})
			end
			local moved = chests[chestName].pushItems(toChest, slotName, count - totalMoved, toSlot)
			totalMoved = totalMoved + moved
			--Log("Get item")
			--Log(itemName)
			if moved == 0 then
				--cant move any more as output slot full / diffrent item
				return totalMoved
			end
			SetSlot(itemName, slotCount - moved, chestName, slotName)
			if count == totalMoved then
				return totalMoved
			end
			if totalMoved > count then
				Err({
					["type"] = "Over move",
					["chestName"] = chestName,
					["slotName"] = slotName,
					["itemName"] = itemName,
					["totalToMove"] = count,
					["toChest"] = toChest,
					["toSlot"] = toSlot
				})
			end
		end
	end
	return 0
end

--- Queue ---

local Queue = {}

function Network()
	-- TODO
end

function ProcessQueue()
	-- TODO
end


MapInventory()
--Load()
--parallel.waitForAny(Network, ProcessQueue)
--Store("ironchest:gold_chest_0", 1)
--Get("minecraft:stick", 2, "ironchest:gold_chest_0", 5)
Save()