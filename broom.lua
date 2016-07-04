local self = CreateFrame('Frame')
self:SetScript('OnEvent', function()
	this[event](this)
end)
self:SetScript('OnUpdate', function()
	this:UPDATE()
end)
self:RegisterEvent('ADDON_LOADED')

self.bagClasses = {
	
	-- ammo pouches
	{["keywords"] = {"ammo", "shot", "bandolier"}}, 
	
	-- quivers
	{["keywords"] = {"quiver", "lamina"}}, 

	-- enchanting bags
	{["keywords"] = {"enchant"}}, 

	-- soul bags
    {["keywords"] = {"felcloth", "soul"}}, 

	-- herb bags
    {["keywords"] = {"cenarius", "herb"}}, 
	
	-- generic bags
	["standard"] = {["keywords"] = {}},
	
}

self.permanent = {
	[7005] = true,
	[5956] = true,
	[2901] = true,
	[6256] = true,
	[6219] = true,
	[10498] = true,
	[6365] = true,
	[6367] = true,
	[11511] = true,
}

function self:ADDON_LOADED()
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

function self:partialStacks()

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

function self:UPDATE()

	if self.state == 'stacking' then

		local incomplete

		for _, partialStacks in self:partialStacks() do

			incomplete = incomplete or getn(partialStacks) > 1

			while true do
				local src, dst
				for _, partialStack in ipairs(partialStacks) do

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
			self:prepareSorting()
			self.state = 'sorting'
		end

	end

	if self.state == 'sorting' then

		local incomplete

		for key, task in self.tasks do

			if not task.completed then

				incomplete = true

				local _, _, srcBag, srcSlot = strfind(key, '(-?%d+):(%d+)')

		        local _, _, srcLocked = GetContainerItemInfo(srcBag, srcSlot)
		        local _, _, dstLocked = GetContainerItemInfo(task.dstBag, task.dstSlot)
		        
				if not srcLocked and not dstLocked then
				
					ClearCursor()
		           	PickupContainerItem(srcBag, srcSlot)
					PickupContainerItem(task.dstBag, task.dstSlot)

					if self.tasks[task.dstBag..':'..task.dstSlot] then
						self.tasks[srcBag..':'..srcSlot] = self.tasks[task.dstBag..':'..task.dstSlot]
						self.tasks[task.dstBag..':'..task.dstSlot] = {completed = true}
					end

					task.completed = true

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

function self:multiLT(xs, ys)
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

function self:prepareSorting()
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
					local tooltipLine2 = getglobal('broom_tooltipTextLeft2'):GetText()
					broom_tooltip:Hide()

					-- soulbound items
					if tooltipLine2 and tooltipLine2 == ITEM_SOULBOUND then
						tinsert(newItem.key, 1)
					
					-- permanent items
					elseif self.permanent[itemID] then
						tinsert(newItem.key, 1)

					-- reagents
					elseif itemType == 'Reagent' then
						tinsert(newItem.key, 2)

					-- consumable items
					elseif itemType == 'Consumable' then
						tinsert(newItem.key, 3)
					
					-- quest items
					elseif itemType == 'Quest' then
						tinsert(newItem.key, 4)

					-- trade goods
					elseif itemType == 'Trade Goods' then
						tinsert(newItem.key, 5)

					-- higher quality
					elseif itemRarity > 1 then
						tinsert(newItem.key, 6)

					-- common quality
					elseif itemRarity == 1 then
						tinsert(newItem.key, 7)

					-- junk
					elseif itemRarity == 0 then
						tinsert(newItem.key, 8)
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
					dstBag = bagClass.bags[bagIndex],
					dstSlot = slot,
				}
			end

	        slot = slot - 1
	
	    end
	
	end	
end

function self:go(...)

 	self.tasks = {}
	for _, bagClassData in self.bagClasses do
    	bagClassData.bags = {}
	end

	for i=1,arg.n do
	
		local bag = arg[i]

		if GetContainerNumSlots(bag) > 0 then

			local bagName = strlower(GetBagName(bag) or '')

			local assigned = false
			for _, bagClass in self.bagClasses do

				for _, keyword in bagClass.keywords do
				
					if strfind(bagName, keyword) then
					
						tinsert(bagClass.bags, bag)
						assigned = true
						break
						
					end
					
				end
				
			end
				
			if not assigned then
				
				tinsert(self.bagClasses['standard'].bags, bag)
					
			end

		end
	end

	self.state = 'stacking'
end