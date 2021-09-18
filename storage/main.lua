-- wget https://raw.githubusercontent.com/BillBodkin/cc_inventory_2021/master/storage/main.lua storage.lua

local chests  = { peripheral.find("ironchest:obsidian_chest") }
local monitor =   peripheral.find("monitor")

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

function Log(msg)
    print(msg)
end

function Err(e)
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
    inventory["itemLimits"] = {}--max stack size per item type, interact with this via GetItemLimit(chestName, slot, itemName)
    inventory["partialStacks"] = {}--stacks that are not completly full or empty, should try to store or get from these first
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
    if itemName ~= "" then
        if inventory["partialStacks"][itemName] == nil then
            inventory["partialStacks"][itemName] = {}
        end
    end
    return inventory["items"][itemName]
end

function GetItemLimit(chestName, slot, itemName)
    if inventory["itemLimits"][itemName] == nil then
        if chests[chestName] ~= nil then
            inventory["itemLimits"][itemName] = chests[chestName].getItemLimit(slot)
        else
            inventory["itemLimits"][itemName] = peripheral.wrap(chestName).getItemLimit(slot)
        end
    end
    return inventory["itemLimits"][itemName]
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
    if name ~= "" then
        if inventory["partialStacks"][name][chestName] == nil then
            inventory["partialStacks"][name][chestName] = {}
        end
    end
    
    GetItemInv("")
    if inventory["items"][""][chestName] == nil then
        inventory["items"][""][chestName] = {}
    end
    
    if count == 0 then
        if name ~= "" then
            inventory["items"][name][chestName][slot] = nil
            inventory["partialStacks"][name][chestName][slot] = nil
        end
        inventory["items"][""][chestName][slot] = 0
    else
        inventory["items"][name][chestName][slot] = count
        inventory["items"][""][chestName][slot] = nil
        
        if name ~= "" then
            if count < GetItemLimit(chestName, slot, name) then
                inventory["partialStacks"][name][chestName][slot] = true
            else
                inventory["partialStacks"][name][chestName][slot] = nil
            end
        end
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
        local maxStackSize = GetItemLimit(fromChest, fromSlot, item.name)--peripheral.wrap(fromChest).getItemLimit(fromSlot)
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
            Log("Stored " .. tostring(totalMoved) .. " " .. item.name)
            return totalMoved
        elseif StoreToSlot("") then
            Log("Stored " .. tostring(totalMoved) .. " " .. item.name)
            return totalMoved
        else
            Err({
                ["type"] = "Desync"
            })
        end
    end
    Log("Was asked to store slot but is empty")
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
                Log("Got " .. tostring(totalMoved) .. " " .. itemName)
                return totalMoved
            end
            SetSlot(itemName, slotCount - moved, chestName, slotName)
            if count == totalMoved then
                Log("Got " .. tostring(totalMoved) .. " " .. itemName)
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
    Log("Got 0 " .. itemName)
    return 0
end

--- Queue ---

local Queue = {}

function Network()
    while true do
        local id, msg = rednet.receive("inv")
        msg["fromID"] = id
        table.insert(Queue, msg)
        sleep(0)
    end
end

function ProcessQueue()
    function ProcessItem(msg)
        if msg["action"] == "store" then
            if msg["chest"] == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Missing 'chest'"
                }, "invResp")
                return
            end
            if peripheral.wrap(msg["chest"]) == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Cant find 'chest'"
                }, "invResp")
                return
            end
            if msg["slot"] == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Missing 'slot'"
                }, "invResp")
                return
            end
            local moved = 0
            if msg["count"] == nil then
                moved = Store(msg["chest"], msg["slot"])
            else
                moved = Store(msg["chest"], msg["slot"], msg["count"])
            end
            rednet.send(msg["fromID"], {
                ["instructionRef"] = msg["instructionRef"],
                ["status"] = "success",
                ["moved"] = moved
            }, "invResp")
            return
        end
        if msg["action"] == "get" then
            if msg["name"] == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Missing 'name'"
                }, "invResp")
                return
            end
            if msg["chest"] == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Missing 'chest'"
                }, "invResp")
                return
            end
            if peripheral.wrap(msg["chest"]) == nil then
                rednet.send(msg["fromID"], {
                    ["instructionRef"] = msg["instructionRef"],
                    ["status"] = "fail",
                    ["message"] = "Cant find 'chest'"
                }, "invResp")
                return
            end
            if msg["count"] == nil then
                msg["count"] = 1
            end
            local moved = 0
            if msg["slot"] == nil then
                moved = Get(msg["name"], msg["count"], msg["chest"])
            else
                moved = Get(msg["name"], msg["count"], msg["chest"], msg["slot"])
            end
            rednet.send(msg["fromID"], {
                ["instructionRef"] = msg["instructionRef"],
                ["status"] = "success",
                ["moved"] = moved
            }, "invResp")
            return
        end
    end
    while true do
        if TableSize(Queue) > 0 then
            ProcessItem(table.remove(Queue))
            sleep(0)
        else
            sleep(0.1)
        end
    end
end

--- Run ---

MapInventory()
--Load()

rednet.open("back")--
parallel.waitForAny(Network, ProcessQueue)

Save()