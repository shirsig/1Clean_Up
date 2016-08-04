local Clean_Up = CreateFrame('Frame')
Clean_Up:Hide()
Clean_Up:SetScript('OnUpdate', function()
	this:UPDATE()
end)
Clean_Up:SetScript('OnEvent', function()
	this[event](this)
end)
Clean_Up:RegisterEvent('ADDON_LOADED')

Clean_Up_Bags = {parent='ContainerFrame1', position={0, 0}}
Clean_Up_Bank = {parent='BankFrame', position={0, 0}}
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

Clean_Up.ITEM_CLASSES = {GetAuctionItemClasses()}

function Clean_Up:Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('[Clean Up] '..tostring(msg), 1, 1, 0)
end

function Clean_Up:Key(table, value)
	for k, v in table do
		if v == value then
			return k
		end
	end
end

function Clean_Up:ItemClassIndex(itemClass)
	return self:Key(self.ITEM_CLASSES, itemClass) or 0
end

function Clean_Up:ItemSubClassIndex(itemClass, itemSubClass)
	return self:Key({GetAuctionItemSubClasses(self:ItemClassKey(itemClass))}, itemClass) or 0
end

function Clean_Up:ItemInvTypeIndex(itemClass, itemSubClass, itemSlot)
	return self:Key({GetAuctionInvTypes(self:ItemClassKey(itemClass), self:ItemSubClassKey(itemSubClass))}, itemSlot) or 0
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

	if self.containers == self.BAGS then
		if self:SellTrash() then
			return
		end
	end

	if not self.slots then
		self:CreateModel()
	end

	if self:Sort() then
		Clean_Up:Hide()
	end

	self:Stack()
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
		self.containers = self.BAGS
		self:Go()
	end)
end

function Clean_Up:CreateBankButton()
	self.bankButton = self:CreateButton('Clean Up Bank', Clean_Up_Bank, function()
		self.containers = self.BANK
		self:Go()
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
			local source = self.model[srcSlot]
			local destination = self.model[dstSlot]
			if source.content.item == destination.content.item then
				local amount = min(source.content.amount, destination.content.capacity - destination.content.amount)
				source.content.amount = source.content.amount - amount
				self.model[srcSlot] = source
				destination.content.amount = destination.content.amount + amount
				self.model[dstSlot] = destination
			else
				source.content, destination.content = destination.content, source.content
			end
		end

		return true
    end
end

function Clean_Up:TooltipInfo(container, position)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	Clean_Up_Tooltip:SetOwner(self, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if container == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(position))
	else
		Clean_Up_Tooltip:SetBagItem(container, position)
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
		if model.content.amount == 0 then
			model.key = {}
		end
		rawset(self, tostring(slot), model)
	end,
	__index = function(self, slot)
		return rawget(self, tostring(slot))
	end,
}

local targets_mt = {
	__newindex = function(self, slot, task)
		rawset(self, tostring(slot), task)
	end,
	__index = function(self, slot)
		return rawget(self, tostring(slot))
	end,
}

function Clean_Up:Trash(container, position)
	for itemID in string.gfind(GetContainerItemLink(container, position) or '', 'item:(%d+)') do
		if ({GetItemInfo(itemID)})[3] == 0 then
			return true
		end
	end
end

function Clean_Up:SellTrash()
	local found
	if self.atMerchant then
		for _, container in self.BAGS do
			for position=1,GetContainerNumSlots(container) do
				if self:Trash(container, position) then
					found = true
					UseContainerItem(container, position)
				end
			end
		end
	end
	return found
end

function Clean_Up:Sort()
	local complete = true

	for _, task in self.tasks do
		if task.slot.content.item ~= task.item or task.slot.content.amount < task.amount then
			local candidates = {}

			for _, slot in self.task.slots do
				if not (self.tasks[slot] and slot.content.item == self.tasks[slot].item and slot.content.amount <= self.tasks[slot].amount)
						and slot ~= task.slot
						and slot.content.item == task.item
				then
					tinsert(candidates, {
						sortKey = abs(slot.content.amount - task.amount + (task.slot.content.item == task.item and task.slot.content.amount or 0)),
						slot = slot,
					})
				end
			end

			sort(candidates, function(a, b) return a.sortKey < b.sortKey end)

			for _, candidate in candidates do
				complete = false
				if self:Move(candidate.slot, task.slot) then
					break
				end
			end
		end
	end

	return complete
end

function Clean_Up:Stack()
	for _, src in self.slots do
		if src.content.amount < src.content.capacity then
			for _, dst in self.slot do
				if src ~= dst and src.content.item == dst.content.item and dst.content.amount < dst.content.capacity then
					self:Move(src, dst)
				end
			end
		end
	end
end

function Clean_Up:Go()
	if containers == self.BAGS then
		self.state = 'SELL_TRASH'
	elseif containers == self.BANK then
		self:CreateModel()
		self.state = 'STACK&SORT'
	end
	Clean_Up:Show()
end

function Clean_Up:CreateModel(containers)
	self.classes = {}
	for classKey in self.CONTAINER_CLASSES do
    	self.classes[classKey] = {items={}, slots={}}
	end
	self.classes._ = {}

	self.slots = {}

	self.items = {}

	for _, container in containers do

		if GetContainerNumSlots(container) > 0 then
			local class = self.classes[self:ContainerClassKey(container)]
			for position=1,GetContainerNumSlots(container) do
				local slot = self:Slot(container, position)
				tinsert(self.slots, slot)
				tinsert(class.slots, slot)
				class.items[slot.content.item] = class.items[slot.content.item] or {
					sortKey = sortKey,
					key = key,
					capacity = itemStack,
					amount = 0,
				}
				class.items[slot.content.item].amount = class.items[slot.content.item].amount + slot.content.amount
			end
		end
	end

	for _, class in self.classes do
		
		local items = {}
		for _, item in class.items do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:LT(a.sortKey, b.sortKey) end)

 		self.tasks = setmetatable({}, targets_mt)

		for _, slot in slots do
			for _, key in {Clean_Up_Assignments[tostring(slot)]} do
				for _, item in {itemMap[key]} do
					if item.amount > 0 then
						self.tasks[slot] = {
							key = item.key,
							slot = slot,
							amount = min(item.amount, item.capacity),
						}
						item.amount = item.amount - min(item.amount, item.capacity)
					end
				end	
			end
		end

		local slots = self:Slots(bagGroup) -- TODO

		for _, item in items do
			while item.amount > 0 do
				local slot = tremove(slots)
				
				if not self.tasks[slot] then
					self.tasks[slot] = {
						key = item.key,
						slot = slot,
						amount = min(item.amount, item.capacity),
					}
					item.amount = item.amount - min(item.amount, item.capacity)
				end
	        end
	    end
	end
end

do
	local cache = {}
	function Clean_Up:ContainerClassKey(container)
		if not cache[container] then
			for _, name in {container ~= 0 and GetBagName(container)} do			
				for key, containerClass in self.CONTAINER_CLASSES do
					for _, itemID in containerClass do
						if name == GetItemInfo(itemID) then
							cache[container] = key
						end
					end	
				end
				cache[container] = cache[container] or '_'
			end
		end
		return cache[container] or '_'
	end
end

do
	local slot_mt = {
		__tostring = function(self)
			return self.container..':'..self.position
		end,
		__call = function(self, ...)
			return return self.container, self.position
		end,		
	}

	function Clean_Up:Slot(container, position)
		return setmetatable({
			container = container,
			position = position,
			content = self:Content(container, position)
		}, slot_mt)
	end
end

function Clean_Up:Content(container, position)
	for link in {GetContainerItemLink(container, position)} do
		local _, _, itemID = strfind(link, 'item:(%d+)')
		itemID = tonumber(itemID)
		
		local itemName, _, itemRarity, itemMinLevel, itemClass, itemSubClass, itemStack, itemEquipLoc = GetItemInfo(itemID)
		local _, count = GetContainerItemInfo(container, position)
		
		local charges, usable, soulbound, conjured = self:TooltipInfo(container, position)

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

		return {
			sortKey = sortKey,
			item = self:ItemKey(link, charges),
			capacity = itemStack,
			amount = count,
		}
	end
end
