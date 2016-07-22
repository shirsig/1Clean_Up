local cleanup = CreateFrame('Frame')
cleanup:SetScript('OnUpdate', function()
	this:UPDATE()
end)
cleanup:SetScript('OnEvent', function()
	this[event](this)
end)
cleanup:RegisterEvent('ADDON_LOADED')

cleanup_position = {1133, 533}

cleanup.BAGS = {0, 1, 2, 3, 4}
cleanup.BANK = {-1, 5, 6, 7, 8, 9, 10}

cleanup.CONTAINER_CLASSES = {
	
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

function cleanup:ADDON_LOADED()
	if arg1 ~= 'cleanup' then
		return
	end

	self:CreateMinimapButton()

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

  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		self:go(unpack(self.BAGS))
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		self:go(unpack(self.BANK))
	end

	CreateFrame('GameTooltip', 'cleanup_tooltip', nil, 'GameTooltipTemplate')
end

function cleanup:UPDATE()
	if self.running then

		local incomplete

		for targetPos, target in self.targets do
			local targetModel = self:GetModel(target.bag, target.slot)
			if targetModel.key ~= target.key or targetModel.count < target.count then
				local candidates = {}

				for srcPos, srcModel in self.model do
					local srcTarget = self.targets[srcPos]
					local canMoveSrc = not (srcTarget and srcModel.key == srcTarget.key and srcModel.count <= srcTarget.count)
					local canMoveToDst = srcPos ~= targetPos and srcModel.key == target.key
					if canMoveSrc and canMoveToDst then
						tinsert(candidates, {
							sortKey = abs(srcModel.count - target.count + (targetModel.key == target.key and targetModel.count or 0)),
							bag = srcModel.bag,
							slot = srcModel.slot,
						})
					end
				end

				sort(candidates, function(a, b) return a.sortKey < b.sortKey end)

				for _, candidate in candidates do
					incomplete = true
					if self:move(candidate.bag, candidate.slot, target.bag, target.slot) then
						break
					end
				end
			end
		end

		for srcPos, srcModel in self.model do
			for dstPos, dstModel in self.model do
				if (srcPos ~= dstPos) and srcModel.key == dstModel.key and srcModel.count < srcModel.stack and dstModel.count < dstModel.stack then
					self:move(srcModel.bag, srcModel.slot, dstModel.bag, dstModel.slot)
				end
			end
		end

		if not incomplete then
			self.running = false
		end
	end
end

function cleanup:CreateMinimapButton()
	local button = CreateFrame('Button', nil, Minimap)
	button:SetFrameStrata('LOW')
	button:SetScale(1.3)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:SetToplevel(true)
	button:SetWidth(32)
	button:SetHeight(32)
	button:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMLEFT', unpack(cleanup_position))
	button:SetNormalTexture(button:CreateTexture())
	SetPortraitToTexture(button:GetNormalTexture(), [[Interface\AddOns\cleanup\INV_Pet_Broom]])
	button:GetNormalTexture():ClearAllPoints()
	button:GetNormalTexture():SetTexCoord(0.05, 0.95, 0.05, 0.95)
	button:GetNormalTexture():SetPoint('CENTER', -1, 2)
	button:GetNormalTexture():SetWidth(21)
	button:GetNormalTexture():SetHeight(21)
	button:SetPushedTexture(button:CreateTexture())
	SetPortraitToTexture(button:GetPushedTexture(), [[Interface\AddOns\cleanup\INV_Pet_Broom]])
	button:GetPushedTexture():SetTexCoord(0.02, 0.92, 0, 0.90)
	button:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8)
	button:GetPushedTexture():ClearAllPoints()
	button:GetPushedTexture():SetPoint('CENTER', -1, 2)
	button:GetPushedTexture():SetWidth(21)
	button:GetPushedTexture():SetHeight(21)
	button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
	button:RegisterForDrag('LeftButton')
	button:SetScript('OnDragStart', function()
		this:StartMoving()
	end)
	button:SetScript('OnDragStop', function()
		this:StopMovingOrSizing()
		cleanup_position = {this:GetLeft(), this:GetBottom()}
	end)
	button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	button:SetScript('OnClick', function()
		if arg1 == 'LeftButton' then
			self:go(unpack(self.BAGS))
		elseif arg1 == 'RightButton' then
			self:go(unpack(self.BANK))
		end
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine('Clean Up')
		GameTooltip:AddLine('Left-Click: Bags', .8, .8, .8, 1)
		GameTooltip:AddLine('Right-Click: Bank', .8, .8, .8, 1)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	local border = button:CreateTexture(nil, 'OVERLAY')
	border:SetTexture([[Interface\Minimap\MiniMap-TrackingBorder]])
	border:SetWidth(52)
	border:SetHeight(52)
	border:SetPoint('TOPLEFT', 0, 0)
end

function cleanup:set(...)
	local set = {}
	for i=1,arg.n do
		set[arg[i]] = true
	end
	return set
end

function cleanup:multiLT(xs, ys)
	local i = 1
	while true do
		if xs[i] and ys[i] and xs[i] ~= ys[i] then
			return xs[i] < ys[i]
		elseif not xs[i] and ys[i] then
			return true
		elseif not ys[i] then
			return false
		end

		i = i + 1
	end
end

function cleanup:GetModel(bag, slot)
	return self.model[bag..':'..slot]
end

function cleanup:SetModel(bag, slot, model)
	if model.count == 0 then
		model.key = {}
	end
	self.model[bag..':'..slot] = model
end

function cleanup:move(srcBag, srcSlot, dstBag, dstSlot)
    local _, _, srcLocked = GetContainerItemInfo(srcBag, srcSlot)
    local _, _, dstLocked = GetContainerItemInfo(dstBag, dstSlot)
    
	if not srcLocked and not dstLocked then
		ClearCursor()
       	PickupContainerItem(srcBag, srcSlot)
		PickupContainerItem(dstBag, dstSlot)

	    local _, _, srcLocked = GetContainerItemInfo(srcBag, srcSlot)
	    local _, _, dstLocked = GetContainerItemInfo(dstBag, dstSlot)
    	if srcLocked or dstLocked then
			local srcModel = self:GetModel(srcBag, srcSlot)
			local dstModel = self:GetModel(dstBag, dstSlot)
			if srcModel.key == dstModel.key then
				local count = min(srcModel.count, dstModel.stack - dstModel.count)
				srcModel.count = srcModel.count - count
				self:SetModel(srcBag, srcSlot, srcModel)
				dstModel.count = dstModel.count + count
				self:SetModel(dstBag, dstSlot, dstModel)
			else
				srcModel.bag = dstBag
				srcModel.slot = dstSlot
				self:SetModel(dstBag, dstSlot, srcModel)
				dstModel.bag = srcBag
				dstModel.slot = srcSlot
				self:SetModel(srcBag, srcSlot, dstModel)
			end
		end

		return true
    end
end

function cleanup:tooltipInfo(bag, slot)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	cleanup_tooltip:SetOwner(self, ANCHOR_NONE)
	cleanup_tooltip:ClearLines()

	if bag == BANK_CONTAINER then
		cleanup_tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(slot))
	else
		cleanup_tooltip:SetBagItem(bag, slot)
	end

	local charges, usable, soulbound, conjured
	for i=1,30 do
		local leftText = getglobal('cleanup_tooltipTextLeft'..i):GetText() or ''

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

		if leftText == ITEM_CONJURED then
			conjured = true
		end
	end

	return charges or 1, usable, soulbound, conjured
end

function cleanup:createModel()
 	
 	self.model = {}
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
					
					local charges, usable, soulbound, conjured = self:tooltipInfo(bag, slot)

					local sortKey = {}
					local itemClasses = { GetAuctionItemClasses() }

					-- hearthstone
					if itemID == 6948 then
						tinsert(sortKey, 1)

					-- mounts
					elseif self.mount[itemID] then
						tinsert(sortKey, 2)

					-- special items
					elseif self.special[itemID] then
						tinsert(sortKey, 3)

					-- key items
					elseif self.key[itemID] then
						tinsert(sortKey, 4)

					-- tools
					elseif self.tool[itemID] then
						tinsert(sortKey, 5)

					-- conjured items
					elseif conjured then
						tinsert(sortKey, 13)

					-- soulbound items
					elseif soulbound then
						tinsert(sortKey, 6)

					-- reagents
					elseif itemClass == itemClasses[9] then
						tinsert(sortKey, 7)

					-- quest items
					elseif tooltipLine2 and tooltipLine2 == ITEM_BIND_QUEST then
						tinsert(sortKey, 9)

					-- consumables
					elseif usable and itemClass ~= itemClasses[1] and itemClass ~= itemClasses[2] and itemClass ~= itemClasses[8] or itemClass == itemClasses[4] then
						tinsert(sortKey, 8)

					-- higher quality
					elseif itemRarity > 1 then
						tinsert(sortKey, 10)

					-- common quality
					elseif itemRarity == 1 then
						tinsert(sortKey, 11)

					-- junk
					elseif itemRarity == 0 then
						tinsert(sortKey, 12)
					end
					
					tinsert(sortKey, itemClass)
					tinsert(sortKey, itemSubclass)
					tinsert(sortKey, itemName)
					tinsert(sortKey, 1/charges)

					local key = link..'#'..charges

					itemMap[key] = itemMap[key] or {
						sortKey = sortKey,
						key = key,
						stack = itemStack,
						count = 0,
					}
					itemMap[key].count = itemMap[key].count + count

					self.model[bag..':'..slot] = {
						key = key,
						stack = itemStack,
						bag = bag,
						slot = slot,
						count = count,
					}
				else
					self.model[bag..':'..slot] = {
						key = {},
						bag = bag,
						slot = slot,
						count = 0,
					}
				end
			end
		end
		
		local items = {}
		for _, item in itemMap do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:multiLT(a.sortKey, b.sortKey) end)
		
		self.targets = {}

		local bagIndex = getn(bagGroup) + 1
		local slot = 0

		for _, item in items do
			while item.count > 0 do
				if slot < 1 then
					bagIndex = bagIndex - 1
					slot = GetContainerNumSlots(bagGroup[bagIndex])
				end
				
				self.targets[bagGroup[bagIndex]..':'..slot] = {
					key = item.key,
					bag = bagGroup[bagIndex],
					slot = slot,
					count = min(item.count, item.stack),
				}
				item.count = item.count - min(item.count, item.stack)

		        slot = slot - 1
	        end
	    end
	end
end

function cleanup:createBagGroups(...)
	self.bagGroups = {}

	for key, containerClass in self.CONTAINER_CLASSES do
    	self.bagGroups[key] = {}
	end
	self.bagGroups['generic'] = {}

	for i=1,arg.n do
	
		local bag = arg[i]

		if GetContainerNumSlots(bag) > 0 then

			local bagName = GetBagName(bag)

			local assigned = false
			if bagName then
				for key, containerClass in self.CONTAINER_CLASSES do
					for _, id in containerClass do
						if bagName == GetItemInfo(id) then
							tinsert(self.bagGroups[key], bag)
							assigned = true
							break	
						end		
					end	
				end
			end
				
			if not assigned then
				tinsert(self.bagGroups['generic'], bag)
			end
		end
	end	
end

function cleanup:go(...)
	self:createBagGroups(unpack(arg))
	self:createModel()
	self.running = true
end