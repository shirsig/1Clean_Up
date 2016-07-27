local Clean_Up = CreateFrame('Frame')
Clean_Up:SetScript('OnUpdate', function()
	this:UPDATE()
end)
Clean_Up:SetScript('OnEvent', function()
	this[event](this)
end)
Clean_Up:RegisterEvent('ADDON_LOADED')

Clean_Up_Position = nil
Clean_Up_Reversed = false
Clean_Up_Assignments = {}

Clean_Up.BAGS = {0, 1, 2, 3, 4}
Clean_Up.BANK = {-1, 5, 6, 7, 8, 9, 10}

Clean_Up.CONTAINER_CLASSES = {
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

Clean_Up.ITEM_CLASSES = { GetAuctionItemClasses() }

function Clean_Up:ItemClassKey(itemClass)
	for i, class in self.ITEM_CLASSES do
		if itemClass == class then
			return i
		end
	end
	return 0
end

function Clean_Up:ItemSubClassKey(itemClass, itemSubClass)
	for i, SubClass in { GetAuctionItemSubClasses(self:ItemClassKey(itemClass)) } do
		if itemSubClass == SubClass then
			return i
		end
	end
	return 0
end

function Clean_Up:ItemSlotKey(itemClass, itemSubClass, itemSlot)
	for i, slot in { GetAuctionInvTypes(self:ItemClassKey(itemClass), self:ItemSubClassKey(itemSubClass)) } do
		if itemSlot == slot then
			return i
		end
	end
	return 0
end

function Clean_Up:ADDON_LOADED()
	if arg1 ~= 'Clean_Up' then
		return
	end

	self:RegisterEvent('MERCHANT_SHOW')
	self:RegisterEvent('MERCHANT_CLOSED')

	self.MOUNT = self:Set(
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

	self.SPECIAL = self:Set(5462, 17696, 17117, 13347, 13289, 11511)

	self.KEY = self:Set(9240, 17191, 13544, 12324, 16309, 12384, 20402)

	self.TOOL = self:Set(7005, 12709, 19727, 5956, 2901, 6219, 10498, 6218, 6339, 11130, 11145, 16207, 9149, 15846, 6256, 6365, 6367)

	self:CreateMinimapButton()
	self:SetupHooks()
	self:SetupSlash()

	CreateFrame('GameTooltip', 'Clean_Up_Tooltip', nil, 'GameTooltipTemplate')
end

function Clean_Up:UPDATE()
	if self.state == 'sell' then
		if self:SellTrash() then
			return
		end

		self:CreateModel()
		self.state = 'stack&sort'
	end

	if self.state == 'stack&sort' then
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
					if self:Move(candidate.bag, candidate.slot, target.bag, target.slot) then
						break
					end
				end
			end
		end

		for srcPos, srcModel in self.model do
			for dstPos, dstModel in self.model do
				if (srcPos ~= dstPos) and srcModel.key == dstModel.key and srcModel.count < srcModel.stack and dstModel.count < dstModel.stack then
					self:Move(srcModel.bag, srcModel.slot, dstModel.bag, dstModel.slot)
				end
			end
		end

		if not incomplete then
			self.state = nil
		end
	end
end

function Clean_Up:MERCHANT_SHOW()
	self.atMerchant = true
end

function Clean_Up:MERCHANT_CLOSED()
	self.atMerchant = false
end

function Clean_Up:InventoryIDToContainerID(id)
end

function Clean_Up:ItemKey(link, charges)
	return link..(charges > 1 and charges or '')
end

function Clean_Up:SetupHooks()
	local orig_PickupContainerItem = PickupContainerItem
	function PickupContainerItem(container, slot)
		if IsAltKeyDown() then
			local link = GetContainerItemLink(container, slot)
			if link then
				local key = self:ItemKey(link, self:TooltipInfo(container, slot))
				Clean_Up_Assignments[container..':'..slot] = key
				self:Log(container..':'..slot..' assigned to '..key)
			end
		else
			orig_PickupContainerItem(container, slot)
		end
	end

	local orig_UseContainerItem = UseContainerItem
	function UseContainerItem(container, slot, onSelf)
		if IsAltKeyDown() then
			if Clean_Up_Assignments[container..':'..slot] then
				Clean_Up_Assignments[container..':'..slot] = nil
				self:Log(container..':'..slot..' freed')
			end
		else
			orig_UseContainerItem(container, slot, onSelf)
		end
	end
end

function Clean_Up:SetupSlash()
  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		self:Go(self.BAGS)
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		self:Go(self.BANK)
	end

    SLASH_CLEANUPREVERSE1 = '/cleanupreverse'
    function SlashCmdList.CLEANUPREVERSE(arg)
        Clean_Up_Reversed = not Clean_Up_Reversed
        self:Log('Sort order: '..(Clean_Up_Reversed and 'Reversed' or 'Standard'))
	end
end

function Clean_Up:CreateMinimapButton()
	local button = CreateFrame('Button', nil, Minimap)
	if Clean_Up_Position then
		button:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', unpack(Clean_Up_Position))
	else
		button:SetPoint('CENTER', 0, 0)
		Clean_Up_Position = {button:GetCenter()}
	end
	button:SetFrameStrata('LOW')
	button:SetScale(1.3)
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:SetToplevel(true)
	button:SetWidth(32)
	button:SetHeight(32)
	button:SetNormalTexture(button:CreateTexture())
	SetPortraitToTexture(button:GetNormalTexture(), [[Interface\AddOns\Clean_Up\INV_Pet_Broom]])
	button:GetNormalTexture():ClearAllPoints()
	button:GetNormalTexture():SetTexCoord(0, 1, 0.06, 1.06)
	button:GetNormalTexture():SetPoint('CENTER', 0, 1)
	button:GetNormalTexture():SetWidth(21)
	button:GetNormalTexture():SetHeight(21)
	button:SetPushedTexture(button:CreateTexture())
	SetPortraitToTexture(button:GetPushedTexture(), [[Interface\AddOns\Clean_Up\INV_Pet_Broom]])
	button:GetPushedTexture():SetTexCoord(-0.03, 0.97, 0.01, 1.01)
	button:GetPushedTexture():SetVertexColor(0.8, 0.8, 0.8)
	button:GetPushedTexture():ClearAllPoints()
	button:GetPushedTexture():SetPoint('CENTER', 0, 1)
	button:GetPushedTexture():SetWidth(21)
	button:GetPushedTexture():SetHeight(21)
	button:SetHighlightTexture([[Interface\Minimap\UI-Minimap-ZoomButton-Highlight]])
	button:RegisterForDrag('LeftButton')
	button:SetScript('OnDragStart', function()
		this:StartMoving()
	end)
	button:SetScript('OnDragStop', function()
		this:StopMovingOrSizing()
		Clean_Up_Position = {this:GetCenter()}
	end)
	button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	button:SetScript('OnClick', function()
		if arg1 == 'LeftButton' then
			self:Go(self.BAGS)
		elseif arg1 == 'RightButton' then
			self:Go(self.BANK)
		end
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine('Clean Up')
		GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..'<Left Click> '..FONT_COLOR_CODE_CLOSE..'Bags')
		GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR_CODE..'<Right Click> '..FONT_COLOR_CODE_CLOSE..'Bank')
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

function Clean_Up:Set(...)
	local set = {}
	for i=1,arg.n do
		set[arg[i]] = true
	end
	return set
end

function Clean_Up:MultiLT(xs, ys)
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

function Clean_Up:GetModel(bag, slot)
	return self.model[bag..':'..slot]
end

function Clean_Up:SetModel(bag, slot, model)
	if model.count == 0 then
		model.key = {}
	end
	self.model[bag..':'..slot] = model
end

function Clean_Up:Move(srcBag, srcSlot, dstBag, dstSlot)
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

function Clean_Up:TooltipInfo(bag, slot)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	Clean_Up_Tooltip:SetOwner(self, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if bag == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(slot))
	else
		Clean_Up_Tooltip:SetBagItem(bag, slot)
	end

	local charges, usable, soulbound, conjured
	for i=1,30 do
		local leftText = getglobal('Clean_Up_TooltipTextLeft'..i):GetText() or ''

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

function Clean_Up:CreateModel()
 	
 	self.model = {}
	for _, bagGroup in self.bagGroups do

		local itemMap = {}
		for bag, slot in self:ContainerIterator(bagGroup) do

			local link = GetContainerItemLink(bag, slot)
			
			if link then

				local _, _, itemID = strfind(link, 'item:(%d+)')
				itemID = tonumber(itemID)
				
				local itemName, _, itemRarity, itemMinLevel, itemClass, itemSubClass, itemStack, itemEquipLoc = GetItemInfo(itemID)
				local _, count = GetContainerItemInfo(bag, slot)
				
				local charges, usable, soulbound, conjured = self:TooltipInfo(bag, slot)

				local sortKey = {}

				-- hearthstone
				if itemID == 6948 then
					tinsert(sortKey, 1)

				-- mounts
				elseif self.MOUNT[itemID] then
					tinsert(sortKey, 2)

				-- special items
				elseif self.SPECIAL[itemID] then
					tinsert(sortKey, 3)

				-- key items
				elseif self.KEY[itemID] then
					tinsert(sortKey, 4)

				-- tools
				elseif self.TOOL[itemID] then
					tinsert(sortKey, 5)

				-- conjured items
				elseif conjured then
					tinsert(sortKey, 13)

				-- soulbound items
				elseif soulbound then
					tinsert(sortKey, 6)

				-- reagents
				elseif itemClass == self.ITEM_CLASSES[9] then
					tinsert(sortKey, 7)

				-- quest items
				elseif tooltipLine2 and tooltipLine2 == ITEM_BIND_QUEST then
					tinsert(sortKey, 9)

				-- consumables
				elseif usable and itemClass ~= self.ITEM_CLASSES[1] and itemClass ~= self.ITEM_CLASSES[2] and itemClass ~= self.ITEM_CLASSES[8] or itemClass == self.ITEM_CLASSES[4] then
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
				
				tinsert(sortKey, self:ItemClassKey(itemClass))
				tinsert(sortKey, self:ItemSlotKey(itemClass, itemSubClass, itemEquipLoc))
				tinsert(sortKey, self:ItemSubClassKey(itemClass, itemSubClass))
				tinsert(sortKey, itemName)
				tinsert(sortKey, 1/charges)

				local key = self:ItemKey(link, charges)

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
		
		local items = {}
		for _, item in itemMap do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:MultiLT(a.sortKey, b.sortKey) end)
		
		self.targets = {}

		for bag, slot in self:ContainerIterator(bagGroup, not Clean_Up_Reversed) do
			local key = Clean_Up_Assignments[bag..':'..slot]
			if key then
				local item = itemMap[key]
				if item and item.count > 0 then

					self.targets[bag..':'..slot] = {
						key = item.key,
						bag = bag,
						slot = slot,
						count = min(item.count, item.stack),
					}
					item.count = item.count - min(item.count, item.stack)
				end			
			end
		end

		local positions = self:ContainerIterator(bagGroup, not Clean_Up_Reversed)

		for _, item in items do
			while item.count > 0 do
				local bag, slot = positions()
				
				if not self.targets[bag..':'..slot] then
					self.targets[bag..':'..slot] = {
						key = item.key,
						bag = bag,
						slot = slot,
						count = min(item.count, item.stack),
					}
					item.count = item.count - min(item.count, item.stack)
				end
	        end
	    end
	end
end

function Clean_Up:ContainerIterator(containers, reversed)
	local i, slot

	local function containerStart()
		return reversed and GetContainerNumSlots(containers[i]) or 1
	end

	local function containerFinished()
		if reversed then
			return slot < 1
		else
			return slot > GetContainerNumSlots(containers[i])
		end
	end

	local function next(i)
		return reversed and i - 1 or i + 1
	end

	local function nextPosition()
		slot = next(slot)
		if containerFinished() then
			i = next(i)
			slot = containers[i] and containerStart()
		end		
	end

	i = reversed and getn(containers) or 1
	slot = containers[i] and containerStart()

	return function()

		local current_container, current_slot = containers[i], slot

		if current_container then
			nextPosition()
			return current_container, current_slot
		end
	end
end

function Clean_Up:Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('[Clean Up] '..tostring(msg), 1, 1, 0)
end

function Clean_Up:CreateBagGroups(containers)
	self.bagGroups = {}

	for key, containerClass in self.CONTAINER_CLASSES do
    	self.bagGroups[key] = {}
	end
	self.bagGroups['generic'] = {}

	for _, bag in ipairs(containers) do
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

function Clean_Up:SellTrash()
	local found
	if self.atMerchant then
		for bag=0,4 do
			for slot=1,GetContainerNumSlots(bag) do
				for id in string.gfind(GetContainerItemLink(bag, slot) or '', 'item:(%d+)') do
					local _, _, quality = GetItemInfo(id)
					if quality == 0 then
						found = true
						UseContainerItem(bag, slot)
					end
				end
			end
		end
	end
	return found
end

function Clean_Up:Go(containers)
	self:CreateBagGroups(containers)
	if containers == self.BAGS then
		self.state = 'sell'
	elseif containers == self.BANK then
		self:CreateModel()
		self.state = 'stack&sort'
	end
end