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
			for i = tonumber(string.gmatch(slot, '([^-]+)')[1]), tonumber(string.gmatch(slot, '([^-]+)')[2]) do
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