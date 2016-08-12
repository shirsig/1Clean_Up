local self = CreateFrame('Frame')
self:Hide()
self:SetScript('OnUpdate', function()
	this:UPDATE()
end)
self:SetScript('OnEvent', function()
	this[event](this)
end)
self:RegisterEvent('ADDON_LOADED')
self:RegisterEvent('PLAYER_LOGIN')
self:RegisterEvent('MERCHANT_SHOW')
self:RegisterEvent('MERCHANT_CLOSED')

Clean_Up_Bags = {parent='ContainerFrame1', position={0, 0}}
Clean_Up_Bank = {parent='BankFrame', position={0, 0}}
Clean_Up_Reversed = false
Clean_Up_Assignments = {}

self.BAGS = {0, 1, 2, 3, 4}
self.BANK = {-1, 5, 6, 7, 8, 9, 10}

self.ITEM_TYPES = {GetAuctionItemClasses()}

function self:Present(value)
	return value ~= nil and {[value]=true} or {}
end

function self:ItemTypeKey(itemClass)
	return self:Key(self.ITEM_TYPES, itemClass) or 0
end

function self:ItemSubTypeKey(itemClass, itemSubClass)
	return self:Key({GetAuctionItemSubClasses(self:ItemTypeKey(itemClass))}, itemClass) or 0
end

function self:ItemInvTypeKey(itemClass, itemSubClass, itemSlot)
	return self:Key({GetAuctionInvTypes(self:ItemTypeKey(itemClass), self:ItemSubTypeKey(itemSubClass))}, itemSlot) or 0
end

function self.ADDON_LOADED()
	if arg1 ~= 'Clean_Up' then
		return
	end

	self.CLASSES = {
		-- arrow
		{
			containers = {2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714},
			items = self:Set(2512, 2515, 3030, 3464, 9399, 11285, 12654, 18042, 19316),
		},
		
		-- bullet
		{
			containers = {2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320},
			items = self:Set(2516, 2519, 3033, 3465, 4960, 5568, 8067, 8068, 8069, 10512, 10513, 11284, 11630, 13377, 15997, 19317),
		},

		-- soul
		{
			containers = {22243, 22244, 21340, 21341, 21342},
			items = self:Set(6265),
		},

		-- ench
		{
			containers = {22246, 22248, 22249},
			items = self:Set(
				-- dust
				10940, 11083, 11137, 11176, 16204,
				-- essence
				10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203,
				--shard
				10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344,
				-- crystal
				20725,
				--rod
				6218, 6339, 11130, 11145, 16207
			),
		},

		-- herb
		{
			containers = {22250, 22251, 22252},
			items = self:Set(765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3818, 3819, 3820, 3821, 4625, 8831, 8836, 8838, 8839, 8845, 8846, 13463, 13464, 13465, 13466, 13467, 13468),
		},
	}

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

	self:SetupSlash()

	CreateFrame('GameTooltip', 'Clean_Up_Tooltip', nil, 'GameTooltipTemplate')

	self:CreateButton('Bags')
	self:CreateButton('Bank')
end

function self:PLAYER_LOGIN()
	self.PickupContainerItem = PickupContainerItem
	function PickupContainerItem(...)
		local container, position = unpack(arg)
		if IsAltKeyDown() then
			for item in self.Present(self:Item(container, position)) do
				local slotKey = self:SlotKey(container, position)
				Clean_Up_Assignments[slotKey] = item
				self:Log(slotKey..' assigned to '..item)
			end
		else
			self.PickupContainerItem(unpack(arg))
		end
	end

    do
        local lastTime, lastX, lastY, lastSlot
		self.UseContainerItem = UseContainerItem
		function UseContainerItem(...)
			local container, position = unpack(arg)
			local slotKey = self:SlotKey(container, position)
			if IsAltKeyDown() then
				if Clean_Up_Assignments[slotKey] then
					Clean_Up_Assignments[slotKey] = nil
					self:Log(slotKey..' freed')
				end
			else
				local x, y = GetCursorPosition()
				if lastTime and GetTime() - lastTime < .5 and x == lastX and y == lastY and slotKey == lastSlot then
					last_time = nil

					local containers
					for _, bagsContainer in self.BAGS do
						if container == bagsContainer then
							containers = self.BAGS
							break
						end
					end
					containers = containers or self.BANK
					local link = GetContainerItemLink(container, position)
					for _, otherContainer in containers do
						for otherPosition=1,GetContainerNumSlots(otherContainer) do
							if not (otherContainer == container and otherPosition == position) and GetContainerItemLink(otherContainer, otherPosition) == link then
								arg[1], arg[2] = otherContainer, otherPosition
								self.UseContainerItem(unpack(arg))
							end
						end
					end
				else
					lastTime = GetTime()
                	lastX, lastY = x, y
                	lastSlot = slotKey
					self.UseContainerItem(unpack(arg))
				end
			end
		end
	end
end

function self:UPDATE()
	if self.containers == self.BAGS and not self.model then
		if self:SellTrash() then
			return
		end
	end

	if not self.model then
		self:CreateModel()
	end

	if self:Sort() then
		self:Hide()
	end

	self:Stack()
end

function self:MERCHANT_SHOW()
	self.atMerchant = true
end

function self:MERCHANT_CLOSED()
	self.atMerchant = false
end

function self:Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..'[Clean Up] '..msg)
end

function self:Set(...)
	local t = {}
	for i=1,arg.n do
		t[arg[i]] = true
	end
	return t
end

function self:LT(a, b)
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

function self:Key(table, value)
	for k, v in table do
		if v == value then
			return k
		end
	end
end

function self:SlotKey(container, position)
	return container..':'..position
end

function self:SetupSlash()
  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		Clean_Up_Bags = {parent=arg, position={0, 0}}
		self:Log('Bags-frame: '..arg)
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		Clean_Up_Bank = {parent=arg, position={0, 0}}
		self:Log('Bank-frame: '..arg)
	end

    SLASH_CLEANUPREVERSE1 = '/cleanupreverse'
    function SlashCmdList.CLEANUPREVERSE(arg)
        Clean_Up_Reversed = not Clean_Up_Reversed
        self:Log('Sort order: '..(Clean_Up_Reversed and 'Reversed' or 'Standard'))
	end
end

function self:CreateButton(name)
	local settings = getglobal('Clean_Up_'..name)

	local button = CreateFrame('Button', nil, WorldFrame)
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
		if getglobal(settings.parent) then
			this:SetParent(getglobal(settings.parent))
			this:SetPoint('CENTER', unpack(settings.position))
			this:SetScript('OnUpdate', function()
				if IsAltKeyDown() ~= this.alt then
					this.alt = IsAltKeyDown()
					this:SetFrameLevel(this.alt and 129 or getglobal(settings.parent):GetFrameLevel() + 1)
				end
			end)
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
		local parentX, parentY = getglobal(settings.parent):GetCenter()
		settings.position = { x - parentX, y - parentY }
		this:ClearAllPoints()
		this:SetPoint('CENTER', unpack(settings.position))
	end)
	button:SetScript('OnClick', function()
		PlaySoundFile([[Interface\AddOns\Clean_Up\UI_BagSorting_01.ogg]])
		self.containers = self[strupper(name)]
		self:Go()
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine('Clean Up '..name)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	self[strlower(name)..'Button'] = button
end

function self:Move(src, dst)
    local _, _, srcLocked = GetContainerItemInfo(src.container, src.position)
    local _, _, dstLocked = GetContainerItemInfo(dst.container, dst.position)
    
	if not srcLocked and not dstLocked then
		ClearCursor()
       	PickupContainerItem(src.container, src.position)
		PickupContainerItem(dst.container, dst.position)

	    local _, _, srcLocked = GetContainerItemInfo(src.container, src.position)
	    local _, _, dstLocked = GetContainerItemInfo(dst.container, dst.position)
    	if srcLocked or dstLocked then
			if src.state.item == dst.state.item then
				local count = min(src.state.count, self:Info(dst.state.item).stack - dst.state.count)
				src.state.count = src.state.count - count
				dst.state.count = dst.state.count + count
				if src.count == 0 then
					src.state.item = nil
				end
			else
				src.state, dst.state = dst.state, src.state
			end
		end

		return true
    end
end

function self:TooltipInfo(container, position)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	Clean_Up_Tooltip:SetOwner(self, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if container == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(position))
	else
		Clean_Up_Tooltip:SetBagItem(container, position)
	end

	local charges, usable, soulbound, quest, conjured
	for i=1,Clean_Up_Tooltip:NumLines() do
		local text = getglobal('Clean_Up_TooltipTextLeft'..i):GetText()

		local _, _, chargeString = strfind(text, chargesPattern)
		if chargeString then
			charges = tonumber(chargeString)
		elseif strfind(text, '^'..ITEM_SPELL_TRIGGER_ONUSE) then
			usable = true
		elseif text == ITEM_SOULBOUND then
			soulbound = true
		elseif text == ITEM_BIND_QUEST then
			quest = true
		elseif text == ITEM_CONJURED then
			conjured = true
		end
	end

	return charges or 1, usable, soulbound, quest, conjured
end

function self:Trash(container, position)
	for itemID in string.gfind(GetContainerItemLink(container, position) or '', 'item:(%d+)') do
		if ({GetItemInfo(itemID)})[3] == 0 then
			return true
		end
	end
end

function self:SellTrash()
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

function self:Sort()
	local complete = true

	for _, dst in self.model do
		if dst.item and (dst.state.item ~= dst.item or dst.state.count < dst.count) then
			complete = false

			local sources, rank = {}, {}

			for _, src in self.model do
				if src.state.item == dst.item
					and src ~= dst
					and not (dst.state.item and src.class and src.class ~= self:Info(dst.state.item).class)
					and not (src.item and src.state.item == src.item and src.state.count <= src.count)
				then
					rank[src] = abs(src.state.count - dst.count + (dst.state.item == dst.item and dst.state.count or 0))
					tinsert(sources, src)
				end
			end

			sort(sources, function(a, b) return rank[a] < rank[b] end)

			for _, src in sources do
				if self:Move(src, dst) then
					break
				end
			end
		end
	end

	return complete
end

function self:Stack()
	for _, src in self.model do
		if src.state.item and src.state.count < self:Info(src.state.item).stack then
			for _, dst in self.model do
				if dst ~= src and dst.state.item and dst.state.item == src.state.item and dst.state.count < self:Info(dst.state.item).stack then
					self:Move(src, dst)
				end
			end
		end
	end
end

function self:Go()
	self.model = nil
	self:Show()
end

do
	local items, counts

	local function insert(t, v)
		if Clean_Up_Reversed then
			tinsert(t, v)
		else
			tinsert(t, 1, v)
		end
	end

	local function assign(slot, item)
		if counts[item] > 0 then
			local count = min(counts[item], self:Info(item).stack)
			slot.item = item
			slot.count = count
			counts[item] = counts[item] - count
			return true
		end
	end

	local function assignCustom()
		for _, slot in self.model do
			for item in self.Present(Clean_Up_Assignments[self:SlotKey(slot.container, slot.position)]) do
				if counts[item] then
					assign(slot, item)
				end
			end
		end
	end

	local function assignSpecial()
		for key, class in self.CLASSES do
			for _, slot in self.model do
				if slot.class == key and not slot.item then
					for _, item in items do
						if self:Info(item).class == key and assign(slot, item) then
							break
						end
				    end
			    end
			end
		end
	end

	local function assignRemaining()
		for _, slot in self.model do
			if not slot.class and not slot.item then
				for _, item in items do
					if assign(slot, item) then
						break
					end
			    end
		    end
		end
	end

	function self:CreateModel()
		self.model = {}
		counts = {}

		for _, container in self.containers do
			local class = self:Class(container)
			for position=1,GetContainerNumSlots(container) do
				local slot = {container=container, position=position, class=class}
				local item = self:Item(container, position)
				if item then
					local _, count = GetContainerItemInfo(container, position)
					slot.state = {item=item, count=count}
					counts[item] = (counts[item] or 0) + count
				else
					slot.state = {}
				end
				insert(self.model, slot)
			end
		end
		items = {}
		for item, _ in counts do
			tinsert(items, item)
		end
		sort(items, function(a, b) return self:LT(self:Info(a).sortKey, self:Info(b).sortKey) end)

		assignCustom()
		assignSpecial()
		assignRemaining()
	end
end

do
	local cache = {}
	function self:Class(container)
		if not cache[container] and container ~= 0 and container ~= BANK_CONTAINER then
			for name in self.Present(GetBagName(container)) do		
				for class, info in self.CLASSES do
					for _, itemID in info.containers do
						if name == GetItemInfo(itemID) then
							cache[container] = class
						end
					end	
				end
			end
		end
		return cache[container]
	end
end

do
	local cache = {}

	local mt = {__index=cache} 
	function self:Info(item)
		return setmetatable({}, mt)
	end

	function self:Item(container, position)
		for link in self.Present(GetContainerItemLink(container, position)) do
			local _, _, itemID, enchantID, suffixID, uniqueID = strfind(link, 'item:(%d+):(%d*):(%d*):(%d*)')
			itemID = tonumber(itemID)
			local _, _, quality, _, type, subType, stack, invType = GetItemInfo(itemID)
			local charges, usable, soulbound, quest, conjured = self:TooltipInfo(container, position)

			local key = format('%s:%s:%s:%s:%s:%s', itemID, enchantID, suffixID, uniqueID, charges, (soulbound and 1 or 0))

			if not cache[key] then

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
				elseif type == self.ITEM_TYPES[9] then
					tinsert(sortKey, 7)

				-- quest items
				elseif quest then
					tinsert(sortKey, 9)

				-- consumables
				elseif usable and type ~= self.ITEM_TYPES[1] and type ~= self.ITEM_TYPES[2] and type ~= self.ITEM_TYPES[8] or type == self.ITEM_TYPES[4] then
					tinsert(sortKey, 8)

				-- higher quality
				elseif quality > 1 then
					tinsert(sortKey, 10)

				-- common quality
				elseif quality == 1 then
					tinsert(sortKey, 11)

				-- junk
				elseif quality == 0 then
					tinsert(sortKey, 12)
				end
				
				tinsert(sortKey, self:ItemTypeKey(type))
				tinsert(sortKey, self:ItemInvTypeKey(type, subType, invType))
				tinsert(sortKey, self:ItemSubTypeKey(type, subType))
				tinsert(sortKey, itemID)
				tinsert(sortKey, 1/charges)
				tinsert(sortKey, suffixID)
				tinsert(sortKey, enchantID)
				tinsert(sortKey, uniqueID)

				cache[key] = {
					stack = stack,
					sortKey = sortKey,
				}

				for class, info in self.CLASSES do
					if info.items[itemID] then
						cache[key].class = class
					end
				end
			end

			return key
		end
	end
end
