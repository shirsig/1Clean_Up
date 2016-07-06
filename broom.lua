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
	{['ids'] = {2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320}}, 
	
	-- quivers
	{['ids'] = {2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714}}, 

	-- enchanting bags
	{['ids'] = {22246, 22248, 22249}}, 

	-- soul bags
    {['ids'] = {22243, 22244, 21340, 21341, 21342}}, 

	-- herb bags
    {['ids'] = {22250, 22251, 22252}}, 
	
	-- generic bags
	['generic'] = {['ids'] = {}},
	
}

broom.mount = {
	
}

broom.special = {
	[5462] = true,
	[17696] = true,
	[17117] = true,
	[13347] = true,
	[13289] = true,
	[11511] = true,
	[20402] = true,
}

broom.key = {
	[9240] = true,
	[17191] = true,
	[13544] = true,
	[12324] = true,
	[16309] = true,
}

broom.tool = {
	[7005] = true,
	[12709] = true,
	[19727] = true,
	[5956] = true,
	[2901] = true,
	[6219] = true,
	[10498] = true,
	[6218] = true,
	[6339] = true,
	[11130] = true,
	[11145] = true,
	[16207] = true,
	[9149] = true,
	[15846] = true,	
	[6256] = true,
	[6365] = true,
	[6367] = true,
}

function broom:ADDON_LOADED()
	if arg1 ~= 'broom' then
		return
	end

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

function broom:partialStacks()

	local partialStacks = {}

	for _, bagClass in self.bagClasses do

		for _, bag in bagClass.bags do
		
			for slot=1, GetContainerNumSlots(bag) do

				local _, count = GetContainerItemInfo(bag, slot)

				local _, _, itemID = strfind(GetContainerItemLink(bag, slot) or '', 'item:(%d+)')
				
				if itemID then
				
					local newItem   = {}
					
					newItem.sortString = ''
					
					local _, _, _, _, _, _, maxStack = GetItemInfo(itemID)

					if count < maxStack then
						partialStacks[itemID] = partialStacks[itemID] or {}
						tinsert(partialStacks[itemID], {bag=bag, slot=slot})
					end
					
				end
				
			end
		end
	end

	return partialStacks
end

function broom:UPDATE()

	if self.state == 'stacking' then

		local incomplete

		for _, partialStacks in self:partialStacks() do

			incomplete = incomplete or getn(partialStacks) > 1

			while true do
				local src, dst
				for _, partialStack in partialStacks do

					local _, _, locked = GetContainerItemInfo(partialStack.bag, partialStack.slot)
					if not locked then
						if not src then
							src = partialStack
						elseif not dst then
							dst = partialStack
						end
					end

				end
				if dst then
					ClearCursor()
		           	PickupContainerItem(src.bag, src.slot)
					PickupContainerItem(dst.bag, dst.slot)					
				else
					break
				end
			end

		end

		if not incomplete then
			self:prepareSortingTasks()
			self.state = 'sorting'
		end

	end

	if self.state == 'sorting' then

		local incomplete

		for key, task in self.tasks do

			if not task.completed then

				incomplete = true

				local _, _, bag, slot = strfind(key, '(-?%d+):(%d+)')

		        local _, _, srcLocked = GetContainerItemInfo(bag, slot)
		        local _, _, dstLocked = GetContainerItemInfo(task.bag, task.slot)
		        
				if not srcLocked and not dstLocked then
				
					ClearCursor()
		           	PickupContainerItem(bag, slot)
					PickupContainerItem(task.bag, task.slot)

					local dstTask = self.tasks[task.bag..':'..task.slot]
					self.tasks[bag..':'..slot] = not (dstTask and dstTask.bag == bag and dstTask.slot == slot) and dstTask or {completed = true}
					self.tasks[task.bag..':'..task.slot] = {completed = true}

		        end
	        end
		end
		
		for _, task in self.tasks do
			if not task.completed then
				return
			end
		end
		self.state = nil

	end
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

function broom:prepareSortingTasks()

 	self.tasks = {}
 	
	for _, bagClass in self.bagClasses do

		local items = {}
		local position = 0
		for _, bag in bagClass.bags do
		
			for slot=GetContainerNumSlots(bag),1,-1 do
				position = position + 1
				local _, _, itemID = strfind(GetContainerItemLink(bag, slot) or '', 'item:(%d+)')
				itemID = tonumber(itemID)
				
				if itemID then
					
					local itemName, itemLink, itemRarity, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemTexture = GetItemInfo(itemID)
					local _, count = GetContainerItemInfo(bag, slot)

					local newItem = { key = {}, name = itemName }
					
					broom_tooltip:SetOwner(self, ANCHOR_NONE)
					broom_tooltip:ClearLines()
					broom_tooltip:SetBagItem(bag, slot)
					local tooltipLine2 = broom_tooltipTextLeft2:GetText()
					local usable
					for i=1,30 do
						local left_text = getglobal('broom_tooltipTextLeft'..i):GetText() or ''

						local charges_pattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'
						local mount_pattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

						local _, _, charges = strfind(left_text, charges_pattern)
						if charges then
							count = charges
						end

						if strfind(left_text, '^'..ITEM_SPELL_TRIGGER_ONUSE) then
							usable = true
						end
					end

					local itemClasses = { GetAuctionItemClasses() }

					-- hearthstone
					if itemID == 6948 then
						tinsert(newItem.key, 1)

					-- mounts
					elseif self.mount[itemID] then
						tinsert(newItem.key, 2)

					-- special items
					elseif self.special[itemID] then
						tinsert(newItem.key, 3)

					-- key items
					elseif self.key[itemID] then
						tinsert(newItem.key, 4)

					-- tools
					elseif self.tool[itemID] then
						tinsert(newItem.key, 5)

					-- soulbound items
					elseif tooltipLine2 and tooltipLine2 == ITEM_SOULBOUND then
						tinsert(newItem.key, 6)

					-- reagents
					elseif itemType == itemClasses[9] then
						tinsert(newItem.key, 7)

					-- trade goods
					elseif itemType == itemClasses[5] then
						tinsert(newItem.key, 8)

					-- consumable items
					elseif itemType == itemClasses[4] then
						tinsert(newItem.key, 10)

					-- usable items
					elseif usable then
						tinsert(newItem.key, 9)
										
					-- quest items
					elseif tooltipLine2 and tooltipLine2 == ITEM_BIND_QUEST then
						tinsert(newItem.key, 11)

					-- higher quality
					elseif itemRarity > 1 then
						tinsert(newItem.key, 12)

					-- common quality
					elseif itemRarity == 1 then
						tinsert(newItem.key, 13)

					-- junk
					elseif itemRarity == 0 then
						tinsert(newItem.key, 13)
					end
					
					tinsert(newItem.key, itemType)
					tinsert(newItem.key, itemSubType)
					tinsert(newItem.key, itemName)
					tinsert(newItem.key, 1/count)
					tinsert(newItem.key, position)

					newItem.bag = bag
					newItem.slot = slot

					tinsert(items, newItem)
					
				end
				
			end
			
		end
		
		sort(items, function(a, b) return self:multiLT(a.key, b.key) end)
		
		local bagIndex = 0
		local slot = 0

		for i, item in items do

			if slot < 1 then
				bagIndex = bagIndex + 1
				slot = GetContainerNumSlots(bagClass.bags[bagIndex])
			end
				
			if item.bag ~= bagClass.bags[bagIndex] or item.slot ~= slot then
				self.tasks[item.bag..':'..item.slot] = {
					bag = bagClass.bags[bagIndex],
					slot = slot,
				}
			end

	        slot = slot - 1
	
	    end
	
	end	
end

function broom:go(...)

	for _, bagClassData in self.bagClasses do
    	bagClassData.bags = {}
	end

	for i=1,arg.n do
	
		local bag = arg[i]

		if GetContainerNumSlots(bag) > 0 then

			local bagName = GetBagName(bag)

			local assigned = false
			for _, bagClass in self.bagClasses do
				for _, id in bagClass.ids do
					if bagName == GetItemInfo(id) then
						tinsert(bagClass.bags, bag)
						assigned = true
						break	
					end		
				end	
			end
				
			if not assigned then
				tinsert(self.bagClasses['generic'].bags, bag)
			end

		end
	end

	self.state = 'stacking'
end