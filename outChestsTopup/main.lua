--wget https://raw.githubusercontent.com/BillBodkin/cc_inventory_2021/master/outChestsTopup/main.lua outChestsTopup.lua

-- Will talk to interface
local outChests = {
	["enderstorage:ender_chest_3"] = {
		[1] = {
			["name"] = "minecraft:coal",
			["count"] = 64
		},
		["2-26"] = {
			["name"] = "",
			["count"] = 0
		}
	}
}

function DoChest(chestName, chestSlotsOri)
	local chest = peripheral.wrap(chestName)
	local chestSlots = {}
	for slot, item in pairs(chestSlotsOri) do
		if type(slot) == "number" then
			chestSlots[slot] = item
		elseif type(slot) == "string" then
			local a,b = s:match("(.+)-(.+)")
			for i = tonumber(a), tonumber(b) do
				chestSlots[i] = item
			end
		end
	end
	print(textutils.serialise(chestSlots))
	for slot, item in pairs(chestSlots) do
		local itemDetail = chest.getItemDetail(slot)
		--if itemDetail == nil and 
	end
end

for chestName, chestSlotsOri in pairs(outChests) do
	DoChest(chestName, chestSlotsOri)
end