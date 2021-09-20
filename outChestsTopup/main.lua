--wget https://raw.githubusercontent.com/BillBodkin/cc_inventory_2021/master/outChestsTopup/main.lua outChestsTopup.lua

local storageComputerID = 18

rednet.open("back")

-- Will talk to interface
local outChests = {
	["ironchest:diamond_chest_1"] = {
		[1] = {
			["name"] = "minecraft:coal",
			["count"] = 64,
			["min"] = 32,
		}
	},
	["ironchest:diamond_chest_2"] = {
		[1] = {
			["name"] = "minecraft:cobblestone",
			["count"] = 64,
			["min"] = 32,
		}
	},
	["quark:variant_chest_0"] = {
		[1] = {
			["name"] = "minecraft:andesite",
			["count"] = 64,
			["min"] = 32,
		}
	},
	["quark:variant_chest_1"] = {--
		[1] = {
			["name"] = "minecraft:cobblestone",
			["count"] = 64,
			["min"] = 32,
		},
		[2] = {
			["name"] = "minecraft:diorite",
			["count"] = 64,
			["min"] = 32,
		}
	},
	["ironchest:diamond_chest_3"] = {
		[1] = {
			["name"] = "minecraft:cobblestone",
			["count"] = 64,
			["min"] = 32,
		},
		[2] = {
			["name"] = "minecraft:diorite",
			["count"] = 64,
			["min"] = 32,
		},
		[3] = {
			["name"] = "minecraft:granite",
			["count"] = 64,
			["min"] = 32,
		},
		[4] = {
			["name"] = "minecraft:dirt",
			["count"] = 64,
			["min"] = 32,
		}
	},
	["enderstorage:ender_chest_3"] = {
		[1] = {
			["name"] = "minecraft:coal",
			["count"] = 64,
			["min"] = 32,
		},
		["2-27"] = {
			["name"] = "",
			["count"] = 0
		}
	}
}

function Store(chest, slot, count)
	print("Storing " .. tostring(count) .. " " .. chest .. " slot " .. tostring(slot))
	rednet.send(storageComputerID, {
		["action"] = "store",
		["instructionRef"] = "outChestTopup",
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
		["instructionRef"] = "outChestTopup",
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

function DoChest(chestName, chestSlotsOri)
	local chest = peripheral.wrap(chestName)
	local chestSlots = {}
	for slot, item in pairs(chestSlotsOri) do
		if item.count == 0 then
			item.name = ""
		end
		if type(slot) == "number" then
			chestSlots[slot] = item
		elseif type(slot) == "string" then
			local a,b = slot:match("(.+)-(.+)")
			for i = tonumber(a), tonumber(b) do
				chestSlots[i] = item
			end
		end
	end
	for slot, item in pairs(chestSlots) do
		function DoSlot()
			local itemDetail = chest.getItemDetail(slot)
			if itemDetail ~= nil then
				--print("---")
				--print(slot)
				--print(itemDetail.name)
			end
			if (itemDetail == nil and item.name == "") or (itemDetail ~= nil and itemDetail.name == item.name and itemDetail.count == item.count) then
				--nothing to do
				--print("Do nothing")
				return
			elseif itemDetail ~= nil and (itemDetail.name ~= item.name or (itemDetail.count > item.count and (item.max == nil or itemDetail.count > item.max))) then
				--put away
				--print("Put away")
				if itemDetail.name ~= item.name then
					Store(chestName, slot, itemDetail.count)
					if item.name == "" then
						return
					end
				else
					Store(chestName, slot, itemDetail.count - item.count)
				end
				if item.name ~= "" then--dont rescan if not gonna put anything elser here after
					itemDetail = chest.getItemDetail(slot)--rescan
				end
			end
			
			if itemDetail == nil or (itemDetail.count < item.count and (item.min == nil or itemDetail.count < item.min)) then
				--print("Get")
				if itemDetail == nil then
					Get(item.name, item.count, chestName, slot)
				else
					Get(item.name, item.count - itemDetail.count, chestName, slot)
				end
			end
		end
		DoSlot()
	end
end

function Cycle()
	for chestName, chestSlotsOri in pairs(outChests) do
		DoChest(chestName, chestSlotsOri)
	end
end

while true do
	Cycle()
	sleep(0.2)
end