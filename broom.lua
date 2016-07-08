local broom = CreateFrame('Frame')
broom:SetScript('OnEvent', function()
	this[event](this)
end)
broom:SetScript('OnUpdate', function()
	this:UPDATE()
end)
broom:RegisterEvent('ADDON_LOADED')

broom.bagClasses = {
	
	-- ammo pouches
	{2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320}, 
	
	-- quivers
	{2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714}, 

	-- enchanting bags
	{22246, 22248, 22249}, 

	-- soul bags
    {22243, 22244, 21340, 21341, 21342}, 

	-- herb bags
    {22250, 22251, 22252}, 

}

function broom:set(...)
	local set = {}
	for i=1,arg.n do
		set[arg[i]] = true
	end
	return set
end

function broom:multiLT(xs, ys)
	local i = 1
	while true do
		if xs[i] and ys[i] then
			if xs[i] < ys[i] then
				return true
			elseif xs[i] > ys[i] then
				return false
			end
		elseif not xs[i] and ys[i] then
			return true
		else
			return false
		end

		i = i + 1
	end
end

function broom:count(bag, slot, link, charges)
	if (not link or GetContainerItemLink(bag, slot) == link) and (not charges or charges == self:tooltipInfo(bag, slot)) then
		return ({GetContainerItemInfo(bag, slot)})[2] or 0
	end
	return 0
end

function broom:partialStack(bag, slot)
	local _, count = GetContainerItemInfo(bag, slot)	
	if count then
		local _, _, itemID = strfind(GetContainerItemLink(bag, slot), 'item:(%d+)')
		local _, _, _, _, _, _, stack = GetItemInfo(itemID)
		if count < stack then
			return true
		end
	end
end

function broom:move(srcBag, srcSlot, dstBag, dstSlot)
    local _, _, srcLocked = GetContainerItemInfo(srcBag, srcSlot)
    local _, _, dstLocked = GetContainerItemInfo(dstBag, dstSlot)
    
	if not srcLocked and not dstLocked then
		ClearCursor()
       	PickupContainerItem(srcBag, srcSlot)
		PickupContainerItem(dstBag, dstSlot)
		return true
    end
end

function broom:tooltipInfo(bag, slot)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	broom_tooltip:SetOwner(self, ANCHOR_NONE)
	broom_tooltip:ClearLines()
	broom_tooltip:SetBagItem(bag, slot)

	local charges, usable, soulbound
	for i=1,30 do
		local leftText = getglobal('broom_tooltipTextLeft'..i):GetText() or ''

		local _, _, chargeString = strfind(leftText, chargesPattern)
		if chargeString then
			charges = tonumber(chargeString)
		end

		if strfind(leftText, '^'..ITEM_SPELL_TRIGGER_ONUSE) then
			usable = true
		end

		if leftText == ITEM_SOULBOUND then
			soulbound = true
		end
	end

	return charges or 1, usable, soulbound
end

function broom:ADDON_LOADED()
	if arg1 ~= 'broom' then
		return
	end

	self.mount = self:set(

		-- rams
		5864, 5872, 5873, 18785, 18786, 18787, 18244, 19030, 13328, 13329,

		-- horses
		2411, 2414, 5655, 5656, 18778, 18776, 18777, 18241, 12353, 12354,

		-- sabers
		8629, 8631, 8632, 18766, 18767, 18902, 18242, 13086, 19902, 12302, 12303, 8628, 12326,

		-- mechanostriders
		8563, 8595, 13321, 13322, 18772, 18773, 18774, 18243, 13326, 13327,

		-- kodos
		15277, 15290, 18793, 18794, 18795, 18247, 15292, 15293,

		-- wolves
		1132, 5665, 5668, 18796, 18797, 18798, 18245, 12330, 12351,

		-- raptors
		8588, 8591, 8592, 18788, 18789, 18790, 18246, 19872, 8586, 13317,

		-- undead horses
		13331, 13332, 13333, 13334, 18791, 18248, 13335,

		-- qiraji battle tanks
		21218, 21321, 21323, 21324, 21176

	)

	self.special = self:set(5462, 17696, 17117, 13347, 13289, 11511)

	self.key = self:set(9240, 17191, 13544, 12324, 16309, 12384, 20402)

	self.tool = self:set(7005, 12709, 19727, 5956, 2901, 6219, 10498, 6218, 6339, 11130, 11145, 16207, 9149, 15846, 6256, 6365, 6367)

  	SLASH_BROOM1 = '/broom'
	function SlashCmdList.BROOM(arg)
		if arg == 'bags' then
			self:go(4, 3, 2, 1, 0)
		elseif arg == 'bank' then
			self:go(10, 9, 8, 7, 6, 5, -1)
		end
	end

	CreateFrame('GameTooltip', 'broom_tooltip', nil, 'GameTooltipTemplate')
end

function broom:UPDATE()
	if self.running then

		local incomplete

		for _, target in self.targets do
			if self:count(target.bag, target.slot, target.link, target.charges) < target.count then
				local candidates = {}

				for _, bagGroup in self.bagGroups do
					for _, bag in bagGroup do
						for slot=1,GetContainerNumSlots(bag) do

							local link = GetContainerItemLink(bag, slot)
							local charges = self:tooltipInfo(bag, slot)
							local srcTarget = self.targets[bag..':'..slot]

							local canMoveSrc = not (srcTarget and link == srcTarget.link and charges == srcTarget.charges and self:count(bag, slot, link, charges) <= srcTarget.count)
							local canMoveToDst = target ~= srcTarget and link == target.link and charges == target.charges
							if canMoveSrc and canMoveToDst then
								tinsert(candidates, {
									key = abs(self:count(bag, slot) - target.count + self:count(target.bag, target.slot, link, charges)),
									bag = bag,
									slot = slot,
								})
							end

						end
					end
				end

				sort(candidates, function(a, b) return a.key < b.key end)

				for _, candidate in candidates do
					incomplete = true
					if self:move(candidate.bag, candidate.slot, target.bag, target.slot) then
						break
					end
				end
			end
		end

		for _, bagGroup in self.bagGroups do
			for _, srcBag in bagGroup do
				for srcSlot=1,GetContainerNumSlots(srcBag) do

					for _, bagGroup in self.bagGroups do
						for _, dstBag in bagGroup do
							for dstSlot=1,GetContainerNumSlots(dstBag) do

								if (srcBag ~= dstBag or srcSlot ~= dstSlot) and GetContainerItemLink(srcBag, srcSlot) == GetContainerItemLink(dstBag, dstSlot) and self:partialStack(srcBag, srcSlot) and self:partialStack(dstBag, dstSlot) then
									self:move(srcBag, srcSlot, dstBag, dstSlot)
								end

							end
						end
					end

				end
			end
		end

		if not incomplete then
			self.running = false
		end

	end
end

function broom:determineTargets()
 	
	for _, bagGroup in self.bagGroups do

		local itemMap = {}
		for _, bag in bagGroup do
			for slot=1,GetContainerNumSlots(bag) do

				local link = GetContainerItemLink(bag, slot)
				
				if link then

					local _, _, itemID = strfind(link, 'item:(%d+)')
					itemID = tonumber(itemID)
					
					local itemName, _, itemRarity, itemMinLevel, itemClass, itemSubclass, itemStack, itemEquipLoc = GetItemInfo(itemID)
					local _, count = GetContainerItemInfo(bag, slot)
					
					local charges, usable, soulbound = self:tooltipInfo(bag, slot)

					local key = {}
					local itemClasses = { GetAuctionItemClasses() }

					-- hearthstone
					if itemID == 6948 then
						tinsert(key, 1)

					-- mounts
					elseif self.mount[itemID] then
						tinsert(key, 2)

					-- special items
					elseif self.special[itemID] then
						tinsert(key, 3)

					-- key items
					elseif self.key[itemID] then
						tinsert(key, 4)

					-- tools
					elseif self.tool[itemID] then
						tinsert(key, 5)

					-- soulbound items
					elseif soulbound then
						tinsert(key, 6)

					-- reagents
					elseif itemClass == itemClasses[9] then
						tinsert(key, 7)

					-- quest items
					elseif tooltipLine2 and tooltipLine2 == ITEM_BIND_QUEST then
						tinsert(key, 9)

					-- consumables
					elseif usable and itemClass ~= itemClasses[1] and itemClass ~= itemClasses[2] and itemClass ~= itemClasses[8] or itemClass == itemClasses[4] then
						tinsert(key, 8)

					-- higher quality
					elseif itemRarity > 1 then
						tinsert(key, 10)

					-- common quality
					elseif itemRarity == 1 then
						tinsert(key, 11)

					-- junk
					elseif itemRarity == 0 then
						tinsert(key, 12)
					end
					
					tinsert(key, itemClass)
					tinsert(key, itemSubclass)
					tinsert(key, itemName)
					tinsert(key, 1/charges)

					itemMap[link..'#'..charges] = itemMap[link..'#'..charges] or {
						key = key,
						bag = bag,
						slot = slot,
						link = link,
						stack = itemStack,
						charges = charges,
						count = 0,
					}
					itemMap[link..'#'..charges].count = itemMap[link..'#'..charges].count + count
				end

			end
		end
		
		local items = {}
		for _, item in itemMap do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:multiLT(a.key, b.key) end)
		
		self.targets = {}

		local bagIndex = 0
		local slot = 0

		for i, item in items do

			while item.count > 0 do
				if slot < 1 then
					bagIndex = bagIndex + 1
					slot = GetContainerNumSlots(bagGroup[bagIndex])
				end
					
				self.targets[bagGroup[bagIndex]..':'..slot] = {
					bag = bagGroup[bagIndex],
					slot = slot,
					link = item.link,
					charges = item.charges,
					count = min(item.count, item.stack),
				}
				item.count = item.count - min(item.count, item.stack)

		        slot = slot - 1
	        end
	
	    end
	
	end

end

function broom:determineBagGroups(...)
	self.bagGroups = {}

	for key, bagClass in self.bagClasses do
    	self.bagGroups[key] = {}
	end
	self.bagGroups['generic'] = {}

	for i=1,arg.n do
	
		local bag = arg[i]

		if GetContainerNumSlots(bag) > 0 then

			local bagName = GetBagName(bag)

			local assigned = false
			for key, bagClass in self.bagClasses do
				for _, id in bagClass do
					if bagName == GetItemInfo(id) then
						tinsert(self.bagGroups[key], bag)
						assigned = true
						break	
					end		
				end	
			end
				
			if not assigned then
				tinsert(self.bagGroups['generic'], bag)
			end

		end
	end	
end

function broom:go(...)
	self:determineBagGroups(unpack(arg))
	self:determineTargets()
	self.running = true
end