-- Will interact with storage and machine

local localName = "turtle_13"

local recipes = {
	["minecraft:torch"] = {
		{
			["in"] = {
				[1] = {
					["name"] = "minecraft:coal",
					["count"] = 1
				},
				[4] = {
					["name"] = "minecraft:stick",
					["count"] = 1
				}
			},
			["out"] = {
				["name"] = "minecraft:torch",
				["count"] = 4
			}
		},
		{
			["in"] = {
				[1] = {
					["name"] = "minecraft:charcoal",
					["count"] = 1
				},
				[4] = {
					["name"] = "minecraft:stick",
					["count"] = 1
				}
			},
			["out"] = {
				["name"] = "minecraft:torch",
				["count"] = 4
			}
		}
	}
}

function Store(chest, slot, count)
	print("Storing " .. tostring(count) .. " " .. chest .. " slot " .. tostring(slot))
	rednet.send(storageComputerID, {
		["action"] = "store",
		["instructionRef"] = "crafting",
		["chest"] = chest,
		["slot"] = slot,
		["count"] = count
	}, "inv")
	while true do
		local id, msg = rednet.receive("invResp")
		if id == storageComputerID then
			if msg["status"] == "success" then
				print("Stored " .. tostring(msg["moved"]) .. " " .. chest .. " slot " .. tostring(slot))
				return msg["moved"]
			else
				print("NOT Stored " .. chest .. " slot " .. tostring(slot) .. " - " .. msg["message"])
				return 0
			end
		end
		sleep(0)
	end
end

function Get(itemName, itemCount, chest, slot)
	print("Getting " .. tostring(itemCount) .. " " .. chest .. " slot " .. tostring(slot))
	rednet.send(storageComputerID, {
		["action"] = "get",
		["instructionRef"] = "crafting",
		["chest"] = chest,
		["slot"] = slot,
		["name"] = itemName,
		["count"] = itemCount
	}, "inv")
	while true do
		local id, msg = rednet.receive("invResp")
		if id == storageComputerID then
			if msg["status"] == "success" then
				print("Got " .. tostring(msg["moved"]) .. " " .. chest .. " slot " .. tostring(slot))
				return msg["moved"]
			else
				print("NOT Got " .. chest .. " slot " .. tostring(slot) .. " - " .. msg["message"])
				return 0
			end
		end
		sleep(0)
	end
end

function Count(itemName)
    while true do
        print("Getting count of: " .. itemName)
        rednet.send(storageComputerID, {
            ["action"] = "count",
            ["instructionRef"] = "crafting",
            ["name"] = itemName
        }, "inv")
        while true do
            local id, msg = rednet.receive("invResp", 2)
            if not id then
                print("Timed out")
                break
            end
            if id == storageComputerID then
                if msg["status"] == "success" then
                    print("Count: " .. tostring(msg["count"]))
                    return msg["count"]
                else
                    print("Get count failed: " .. msg["message"])
                    return 0
                end
            end
            sleep(0)
        end
        sleep(1)
    end
end

function Dump()
	for i = 1, 16 do
		while true do
			local ic = turtle.getItemCount(i)
			if ic > 0 then
				if Store(localName, i, ic) == ic then
					break
				end
				sleep(2)
			else
				break
			end
		end
	end
end

function CountMissingIngredients(recipe)
	local count = 0
	for k, v in pairs(recipe["in"]) do
		local inStorage = Count(v.name)
		if inStorage < v.count then
			count = count + (v.count - inStorage)
		end
	end
	return count
end

function GetMaxCanCraftAtOnce(recipe, count)
	--todo - will need to get max stack size from storage
	return 1
end

function CraftingTableToTurtleSlot(slot)
	if slot > 6 then
		return slot + 2
	elseif slot > 3 then
		return slot + 1
	else
		return slot
	end
end

function CraftRecipe(recipe, count, recursive)
	local retCount = 0
	local retMessage = nil
	
	local maxCanCraft = GetMaxCanCraftAtOnce(recipe, count)
	
	for k, v in pairs(recipe["in"]) do
		local inStorage = 0
		while true do
			inStorage = Count(v.name)
			if inStorage < v.count and recursive then
				local got, msg = CraftItem(v.name, v.count * maxCanCraft, recursive)
				if msg == "outOfRaw" then
					msg = "outOfRaw"
					break
				end
			else
				break
			end
		end
	end
	
	for k, v in pairs(recipe["in"]) do
		local got = Get(v.name, v.count * maxCanCraft, localName, CraftingTableToTurtleSlot(k))
	end
	
	turtle.craft()
	
	for i = 1, 16 do
		local item = turtle.getItemDetail(i)
		if item ~= nil and item.name == recipe.out.name then
			retCount = retCount + item.count
		end
	end
	
	Dump()
	
	if retCount < count and msg == nil then
		local got, msg = CraftRecipe(recipe, count - retCount, recursive)
		return retCount + got, msg
	end
	
	return retCount, retMessage
end

function CraftItem(itemName, count, recursive)
	print("Crafting item " .. itemName .. " x" .. tostring(itemCount))
	if recipes[itemName] == nil or recipes[itemName] == {} then
		return nil
	end
	
	local leastMissingRecipe = nil
	local leastMissingCount = nil
	for k, v in pairs(recipes[itemName]) do
		local missingCount = CountMissingIngredients(v)
		if leastMissingCount == nil or leastMissingCount > missingCount then
			leastMissingRecipe = v
			leastMissingCount = missingCount
		end
	end
	
	if leastMissingRecipe == nil then
		return nil
	end
	
	return CraftRecipe(leastMissingRecipe, count, recursive)
end

Dump()
CraftItem("minecraft:torch", 16, true)