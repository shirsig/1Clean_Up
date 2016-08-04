local Clean_Up = CreateFrame('Frame')
Clean_Up:SetScript('OnUpdate', function()
	this:UPDATE()
end)
Clean_Up:SetScript('OnEvent', function()
	this[event](this)
end)
Clean_Up:RegisterEvent('ADDON_LOADED')

Clean_Up_Bags = { parent='ContainerFrame1', position={0, 0} }
Clean_Up_Bank = { parent='BankFrame', position={0, 0} }
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

function Clean_Up:Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('[Clean Up] '..tostring(msg), 1, 1, 0)
end

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

	self:SetupHooks()
	self:SetupSlash()

	CreateFrame('GameTooltip', 'Clean_Up_Tooltip', nil, 'GameTooltipTemplate')
end

function Clean_Up:UPDATE()
	if not self.bagsButton and getglobal(Clean_Up_Bags.parent) then
		self:CreateBagsButton()
	end

	if not self.bankButton and getglobal(Clean_Up_Bank.parent) then
		self:CreateBankButton()
	end

	if self.state == 'sell' then
		if self:SellTrash() then
			return
		end

		self:CreateModel()
		self.state = 'stack&sort'
	end

	if self.state == 'stack&sort' then
		local incomplete

		for _, target in self.targets do
			local targetModel = self.model[target.slot]
			if targetModel.key ~= target.key or targetModel.count < target.count then
				local candidates = {}

				for _, srcModel in self.model do
					local srcTarget = self.targets[srcModel.slot]
					local canMoveSrc = not (srcTarget and srcModel.key == srcTarget.key and srcModel.count <= srcTarget.count)
					local canMoveToDst = srcModel.slot ~= target.slot and srcModel.key == target.key
					if canMoveSrc and canMoveToDst then
						tinsert(candidates, {
							sortKey = abs(srcModel.count - target.count + (targetModel.key == target.key and targetModel.count or 0)),
							slot = srcModel.slot,
						})
					end
				end

				sort(candidates, function(a, b) return a.sortKey < b.sortKey end)

				for _, candidate in candidates do
					incomplete = true
					if self:Move(candidate.slot, target.slot) then
						break
					end
				end
			end
		end

		for srcPos, srcModel in self.model do
			for dstPos, dstModel in self.model do
				if (srcPos ~= dstPos) and srcModel.key == dstModel.key and srcModel.count < srcModel.stack and dstModel.count < dstModel.stack then
					self:Move(srcModel.slot, dstModel.slot)
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

function Clean_Up:ItemKey(link, charges)
	return link..(charges > 1 and charges or '')
end

function Clean_Up:SlotKey(slot)
	return slot[1]..':'..slot[2]
end

function Clean_Up:SetupHooks()
	local orig_PickupContainerItem = PickupContainerItem
	function PickupContainerItem(...)
		local slot = self:Slot(arg[1], arg[2])
		if IsAltKeyDown() then
			for _, link in {GetContainerItemLink(unpack(slot))} do
				local key = self:ItemKey(link, self:TooltipInfo(slot))
				Clean_Up_Assignments[tostring(slot)] = key
				self:Log(slot..' assigned to '..key)
			end
		else
			orig_PickupContainerItem(unpack(arg))
		end
	end

	local orig_UseContainerItem = UseContainerItem
	function UseContainerItem(...)
		local slot = self:Slot(arg[1], arg[2])
		if IsAltKeyDown() then
			if Clean_Up_Assignments[tostring(slot)] then
				Clean_Up_Assignments[tostring(slot)] = nil
				self:Log(slot..' freed')
			end
		else
			orig_UseContainerItem(unpack(arg))
		end
	end
end

function Clean_Up:SetupSlash()
  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		Clean_Up_Bags = { parent=arg, position={0, 0} }
		self:Log('Bags-frame: '..arg)
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		Clean_Up_Bank = { parent=arg, position={0, 0} }
		self:Log('Bank-frame: '..arg)
	end

    SLASH_CLEANUPREVERSE1 = '/cleanupreverse'
    function SlashCmdList.CLEANUPREVERSE(arg)
        Clean_Up_Reversed = not Clean_Up_Reversed
        self:Log('Sort order: '..(Clean_Up_Reversed and 'Reversed' or 'Standard'))
	end
end

function Clean_Up:CreateBagsButton()
	self.bagsButton = self:CreateButton('Clean Up Bags', Clean_Up_Bags, function()
		self:Go(self.BAGS)
	end)
end

function Clean_Up:CreateBankButton()
	self.bankButton = self:CreateButton('Clean Up Bank', Clean_Up_Bank, function()
		self:Go(self.BANK)
	end)
end

function Clean_Up:CreateButton(name, db, action)
	local button = CreateFrame('Button', nil, getglobal(db.parent))
	button:SetPoint('CENTER', unpack(db.position))
	button:SetMovable(true)
	button:SetClampedToScreen(true)
	button:SetToplevel(true)
	button:SetWidth(28)
	button:SetHeight(26)
	button:SetNormalTexture([[Interface\AddOns\Clean_Up\Bags]])
	button:GetNormalTexture():SetTexCoord(0.12109375, 0.23046875, 0.7265625, 0.9296875)
	button:SetPushedTexture([[Interface\AddOns\Clean_Up\Bags]])
	button:GetPushedTexture():SetTexCoord(0.00390625, 0.11328125, 0.7265625, 0.9296875)
	button:SetHighlightTexture([[Interface\Buttons\ButtonHilight-Square]])
	button:GetHighlightTexture():ClearAllPoints()
	button:GetHighlightTexture():SetWidth(24)
	button:GetHighlightTexture():SetHeight(23)
	button:GetHighlightTexture():SetPoint('CENTER', 0, 0)
	button:RegisterForDrag('LeftButton')
	button:SetScript('OnUpdate', function()
		if IsAltKeyDown() ~= this.alt then
			this.alt = IsAltKeyDown()
			this:SetFrameLevel(this.alt and 129 or getglobal(db.parent):GetFrameLevel() + 1)
		end
	end)
	button:SetScript('OnDragStart', function()
		if IsAltKeyDown() then
			this:StartMoving()
		end
	end)
	button:SetScript('OnDragStop', function()
		this:StopMovingOrSizing()
		local x, y = this:GetCenter()
		local parentX, parentY = getglobal(db.parent):GetCenter()
		db.position = { x - parentX, y - parentY }
		this:ClearAllPoints()
		this:SetPoint('CENTER', unpack(db.position))
	end)
	button:SetScript('OnClick', function()
		PlaySoundFile([[Interface\AddOns\Clean_Up\UI_BagSorting_01.ogg]])
		action()
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine(name)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	return button
end

function Clean_Up:Set(...)
	local t = {}
	for i=1,arg.n do
		t[arg[i]] = true
	end
	return t
end

function Clean_Up:LT(a, b)
	local i = 1
	while true do
		if a[i] and b[i] and a[i] ~= b[i] then
			return a[i] < b[i]
		elseif not a[i] and b[i] then
			return true
		elseif not b[i] then
			return false
		end
		i = i + 1
	end
end

function Clean_Up:Move(srcSlot, dstSlot)
    local _, _, srcLocked = GetContainerItemInfo(unpack(srcSlot))
    local _, _, dstLocked = GetContainerItemInfo(unpack(dstSlot))
    
	if not srcLocked and not dstLocked then
		ClearCursor()
       	PickupContainerItem(unpack(srcSlot))
		PickupContainerItem(unpack(dstSlot))

	    local _, _, srcLocked = GetContainerItemInfo(unpack(srcSlot))
	    local _, _, dstLocked = GetContainerItemInfo(unpack(dstSlot))
    	if srcLocked or dstLocked then
			local srcModel = self.model[srcSlot]
			local dstModel = self.model[dstSlot]
			if srcModel.key == dstModel.key then
				local count = min(srcModel.count, dstModel.stack - dstModel.count)
				srcModel.count = srcModel.count - count
				self.model[srcSlot] = srcModel
				dstModel.count = dstModel.count + count
				self.model[dstSlot] = dstModel
			else
				srcModel.slot = dstSlot
				self.model[dstSlot] = srcModel
				dstModel.slot = srcSlot
				self.model[srcSlot] = dstModel
			end
		end

		return true
    end
end

function Clean_Up:TooltipInfo(slot)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	Clean_Up_Tooltip:SetOwner(self, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if slot[1] == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(slot[2]))
	else
		Clean_Up_Tooltip:SetBagItem(unpack(slot))
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

local model_mt = {
	__newindex = function(self, slot, model)
		if model.count == 0 then
			model.key = {}
		end
		rawset(self, tostring(slot), model)
	end,
	__index = function(self, slot)
		return rawget(self, tostring(slot))
	end,
}

local targets_mt = {
	__newindex = function(self, slot, target)
		rawset(self, tostring(slot), target)
	end,
	__index = function(self, slot)
		return rawget(self, tostring(slot))
	end,
}

function Clean_Up:CreateModel()
 	
 	self.model = setmetatable({}, model_mt)

	for _, bagGroup in self.bagGroups do

		local itemMap = {}
		for _, slot in self:Slots(bagGroup) do

			local link = GetContainerItemLink(unpack(slot))
			
			if link then

				local _, _, itemID = strfind(link, 'item:(%d+)')
				itemID = tonumber(itemID)
				
				local itemName, _, itemRarity, itemMinLevel, itemClass, itemSubClass, itemStack, itemEquipLoc = GetItemInfo(itemID)
				local _, count = GetContainerItemInfo(unpack(slot))
				
				local charges, usable, soulbound, conjured = self:TooltipInfo(slot)

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

				self.model[slot] = {
					key = key,
					stack = itemStack,
					slot = slot,
					count = count,
				}
			else
				self.model[slot] = {
					key = {},
					slot = slot,
					count = 0,
				}
			end
		end
		
		local items = {}
		for _, item in itemMap do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:LT(a.sortKey, b.sortKey) end)

 		self.targets = setmetatable({}, targets_mt)

		for _, slot in self:Slots(bagGroup) do
			for _, key in {Clean_Up_Assignments[tostring(slot)]} do
				for _, item in {itemMap[key]} do
					if item.count > 0 then
						self.targets[slot] = {
							key = item.key,
							slot = slot,
							count = min(item.count, item.stack),
						}
						item.count = item.count - min(item.count, item.stack)
					end
				end	
			end
		end

		local slots = self:Slots(bagGroup)

		for _, item in items do
			while item.count > 0 do
				local slot = tremove(slots)
				
				if not self.targets[slot] then
					self.targets[slot] = {
						key = item.key,
						slot = slot,
						count = min(item.count, item.stack),
					}
					item.count = item.count - min(item.count, item.stack)
				end
	        end
	    end
	end
end

function Clean_Up:CreateBagGroups(containers)
	self.bagGroups = {}

	for key, containerClass in self.CONTAINER_CLASSES do
    	self.bagGroups[key] = {}
	end
	self.bagGroups['generic'] = {}

	for _, bag in containers do
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
		for _, slot in self:Slots(Clean_Up.BAGS) do
			for id in string.gfind(GetContainerItemLink(unpack(slot)) or '', 'item:(%d+)') do
				local _, _, quality = GetItemInfo(id)
				if quality == 0 then
					found = true
					UseContainerItem(unpack(slot))
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

function Clean_Up:Slots(containers)
	local slots = {}
	for _, container in containers do
		for position=1,GetContainerNumSlots(container) do
			tinsert(slots, self:Slot(container, position))
		end
	end
	sort(slots)
	return slots
end

do
	local slot_mt = {
		__tostring = function(self)
			return self[1]..':'..self[2]
		end,
		__lt = function(a, b)
			if Clean_Up_Reversed then
				return Clean_Up:LT(b, a)
			else
				return Clean_Up:LT(a, b)
			end
		end,
		__eq = function(a, b)
			return a[1] == b[1] and a[2] == b[2]
		end,
	}

	function Clean_Up:Slot(container, position)
		return setmetatable({container, position}, slot_mt)
	end
end
