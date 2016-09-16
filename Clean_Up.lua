local self = CreateFrame'Frame'
self:Hide()
self:SetScript('OnUpdate', function() this:UPDATE() end)
self:SetScript('OnEvent', function() this[event](this) end)
for _, event in { 'ADDON_LOADED', 'PLAYER_LOGIN', 'BAG_UPDATE', 'PLAYERBANKSLOTS_CHANGED', 'BANKFRAME_OPENED', 'BANKFRAME_CLOSED', 'MERCHANT_SHOW', 'MERCHANT_CLOSED' } do
	self:RegisterEvent(event)
end

local BAGS, BANK = 'BAGS', 'BANK'

Clean_Up_Settings = {
	reversed = false,
	assignments = {},
	BAGS = {},
	BANK = {},
}

local CONTAINERS = {
	BAGS = { 0, 1, 2, 3, 4 },
	BANK = { -1, 5, 6, 7, 8, 9, 10 },
}

local TOOLTIP = {
	BAGS = 'Clean Up Bags',
	BANK = 'Clean Up Bank',
}

local BUTTON = {}

self.ITEM_TYPES = { GetAuctionItemClasses() }

local bank2inv, inv2bank = {}, {}
for i = 1, 24 do
	bank2inv[i] = BankButtonIDToInvSlotID(i)
	inv2bank[BankButtonIDToInvSlotID(i)] = i
end

function self:present(...)
	local called
	return function()
		if not called then
			called = true
			return unpack(arg)
		end
	end
end

function self:ItemTypeKey(itemClass)
	return self:Key(self.ITEM_TYPES, itemClass) or 0
end

function self:ItemSubTypeKey(itemClass, itemSubClass)
	return self:Key({ GetAuctionItemSubClasses(self:ItemTypeKey(itemClass)) }, itemClass) or 0
end

function self:ItemInvTypeKey(itemClass, itemSubClass, itemSlot)
	return self:Key({ GetAuctionInvTypes(self:ItemTypeKey(itemClass), self:ItemSubTypeKey(itemSubClass)) }, itemSlot) or 0
end

function self.ADDON_LOADED()
	if arg1 ~= '!Clean_Up' then
		return
	end

	self.MOUNT = self:set(
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

	self.SPECIAL = self:set(5462, 17696, 17117, 13347, 13289, 11511)

	self.KEY = self:set(9240, 17191, 13544, 12324, 16309, 12384, 20402)

	self.TOOL = self:set(7005, 12709, 19727, 5956, 2901, 6219, 10498, 6218, 6339, 11130, 11145, 16207, 9149, 15846, 6256, 6365, 6367)

	self.ENCHANTING_REAGENT = self:set(
		-- dust
		10940, 11083, 11137, 11176, 16204,
		-- essence
		10938, 10939, 10998, 11082, 11134, 11135, 11174, 11175, 16202, 16203,
		-- shard
		10978, 11084, 11138, 11139, 11177, 11178, 14343, 14344,
		-- crystal
		20725
	)

	self.CLASSES = {
		-- arrow
		{
			containers = { 2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714 },
			items = self:set(2512, 2515, 3030, 3464, 9399, 11285, 12654, 18042, 19316),
		},
		-- bullet
		{
			containers = { 2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320 },
			items = self:set(2516, 2519, 3033, 3465, 4960, 5568, 8067, 8068, 8069, 10512, 10513, 11284, 11630, 13377, 15997, 19317),
		},
		-- soul
		{
			containers = { 22243, 22244, 21340, 21341, 21342 },
			items = self:set(6265),
		},
		-- ench
		{
			containers = { 22246, 22248, 22249 },
			items = self:union(
				self.ENCHANTING_REAGENT,
				-- rods
				self:set(6218, 6339, 11130, 11145, 16207)
			),
		},
		-- herb
		{
			containers = { 22250, 22251, 22252 },
			items = self:set(765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3818, 3819, 3820, 3821, 4625, 8831, 8836, 8838, 8839, 8845, 8846, 13463, 13464, 13465, 13466, 13467, 13468),
		},
	}

	self:SetupSlash()

	CreateFrame('GameTooltip', 'Clean_Up_Tooltip', nil, 'GameTooltipTemplate')
	self:create_button_placer()
	self:create_button(BAGS)
	self:create_button(BANK)
end

function self:PLAYER_LOGIN()
	do
		local orig = PickupContainerItem
		function PickupContainerItem(...)
			local container, position = unpack(arg)
			if IsAltKeyDown() then
				for link in self:present(GetContainerItemLink(container, position)) do
					local slot_key = self:slot_key(container, position)
					Clean_Up_Settings.assignments[slot_key] = link
					self:print(slot_key .. ' assigned to ' .. link)
				end
			else
				orig(unpack(arg))
			end
		end
	end
    do
    	local orig = UseContainerItem
        local lastTime, lastSlot
		function UseContainerItem(...)
			local container, position = unpack(arg)
			local slot_key = self:slot_key(container, position)
			if IsAltKeyDown() then
				if Clean_Up_Settings.assignments[slot_key] then
					Clean_Up_Settings.assignments[slot_key] = nil
					self:print(slot_key .. ' freed')
				end
			else
				if lastTime and GetTime() - lastTime < .5 and slot == lastSlot then
					containers = self:set(unpack(CONTAINERS.BAGS))[container] and CONTAINERS.BAGS or CONTAINERS.BANK
					local link = GetContainerItemLink(container, position)
					for _, container in containers do
						for position = 1, GetContainerNumSlots(container) do
							if self:slot_key(container, position) ~= slot and GetContainerItemLink(container, position) == link then
								arg[1], arg[2] = container, position
								orig(unpack(arg))
							end
						end
					end
				end
				lastTime = GetTime()
            	lastSlot = slot
				orig(unpack(arg))
			end
		end
	end

	do
		local frame = GameTooltip
		while true do
			frame = EnumerateFrames(frame)
			if not frame then break end
			if frame.GetObjectType and frame:GetObjectType() == 'GameTooltip' then
				self:convert_tooltip(frame)
			end
		end
	end
	do
		local orig = CreateFrame
		function CreateFrame(...)
			local frame = orig(unpack(arg))
			if arg[1] == 'GameTooltip' then
				self:convert_tooltip(frame)
			end
			return frame
		end
	end

	self.key = BAGS
	self:sort()
end

function self:UPDATE()
	if self.key == BAGS and self.model then
		if self:vendor_step() then
			return
		end
	end

	if self:stack_step() then
		self:sort()
		self.container_updater:Show()
		self:Hide()
	end
end

function self:BAG_UPDATE()
	self.container_updater:Show()
end

function self:PLAYERBANKSLOTS_CHANGED()
	self.container_updater:Show()
end

function self:BANKFRAME_OPENED()
	self.at_bank = true
	self.key = BANK
	self:sort()
end

function self:BANKFRAME_CLOSED()
	self.at_bank = false
end

function self:MERCHANT_SHOW()
	self.atMerchant = true
end

function self:MERCHANT_CLOSED()
	self.atMerchant = false
end

function self:print(msg)
	DEFAULT_CHAT_FRAME:AddMessage(LIGHTYELLOW_FONT_COLOR_CODE..'[Clean Up] '..msg)
end

function self:set(...)
	local t = {}
	for i = 1, arg.n do
		t[arg[i]] = true
	end
	return t
end

function self:union(...)
	local t = {}
	for i = 1, arg.n do
		for k in arg[i] do
			t[k] = true
		end
	end
	return t
end

function self:lt(a, b)
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

function self:slot_key(container, position)
	return container..':'..position
end

function self:SetupSlash()
  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		self.button_placer.key = BAGS
		self.button_placer:Show()
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		self.button_placer.key = BANK
		self.button_placer:Show()
	end

    SLASH_CLEANUPREVERSE1 = '/cleanupreverse'
    function SlashCmdList.CLEANUPREVERSE(arg)
        Clean_Up_Settings.reversed = not Clean_Up_Settings.reversed
        self:print('Sort order: '..(Clean_Up_Settings.reversed and 'Reversed' or 'Standard'))
	end
end

function self:BrushButton(parent)
	local button = CreateFrame('Button', nil, parent)
	button:SetWidth(28)
	button:SetHeight(26)
	button:SetNormalTexture[[Interface\AddOns\!Clean_Up\Bags]]
	button:GetNormalTexture():SetTexCoord(.12109375, .23046875, .7265625, .9296875)
	button:SetPushedTexture[[Interface\AddOns\!Clean_Up\Bags]]
	button:GetPushedTexture():SetTexCoord(.00390625, .11328125, .7265625, .9296875)
	button:SetHighlightTexture[[Interface\Buttons\ButtonHilight-Square]]
	button:GetHighlightTexture():ClearAllPoints()
	button:GetHighlightTexture():SetPoint('CENTER', 0, 0)
	button:GetHighlightTexture():SetWidth(24)
	button:GetHighlightTexture():SetHeight(23)
	return button
end

function self:UpdateButton(key)
	local button, settings = BUTTON[key], Clean_Up_Settings[key]
	button:SetParent(settings.parent)
	button:SetPoint('CENTER', unpack(settings.position))
	button:Show()
end

function self:create_button(key)
	local settings = Clean_Up_Settings[key]
	local button = self:BrushButton()
	BUTTON[key] = button
	button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	button:SetScript('OnUpdate', function()
		if settings.parent and getglobal(settings.parent) then
			self:UpdateButton(key)
			this:SetScript('OnUpdate', nil)
		end
	end)
	button:SetScript('OnClick', function()
		if arg1 == 'LeftButton' then
			PlaySoundFile[[Interface\AddOns\!Clean_Up\UI_BagSorting_01.ogg]]
			self.key = key
			self:Show()
		elseif arg1 == 'RightButton' then
			self.key = key
			self:toggle_sorted_view()
		end
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine(TOOLTIP[key])
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
end

function self:create_button_placer()
	local frame = CreateFrame('Button', nil, UIParent)
	self.button_placer = frame
	frame:SetFrameStrata'FULLSCREEN_DIALOG'
	frame:SetAllPoints()
	frame:Hide()

	local escape_interceptor = CreateFrame('EditBox', nil, frame)
	escape_interceptor:SetScript('OnEscapePressed', function() frame:Hide() end)

	local button_preview = self:BrushButton(frame)
	button_preview:EnableMouse(false)
	button_preview:SetAlpha(.5)

	frame:SetScript('OnShow', function() escape_interceptor:SetFocus() end)
	frame:SetScript('OnClick', function() this:EnableMouse(false) end)
	frame:SetScript('OnUpdate', function()
		local scale, x, y = button_preview:GetEffectiveScale(), GetCursorPosition()
		button_preview:SetPoint('CENTER', UIParent, 'BOTTOMLEFT', x/scale, y/scale)
		if not this:IsMouseEnabled() and GetMouseFocus() then
			local parent = GetMouseFocus()
			local parentScale, parentX, parentY = parent:GetEffectiveScale(), parent:GetCenter()
			Clean_Up_Settings[this.key] = { parent=parent:GetName(), position={ x/parentScale - parentX, y/parentScale - parentY } }
			self:UpdateButton(this.key)
			this:EnableMouse(true)
			this:Hide()
		end
	end)
end

function self:tooltip_info(container, position)
	local chargesPattern = '^' .. gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)') .. '$'

	Clean_Up_Tooltip:SetOwner(self, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if container == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', bank2inv[position])
	else
		Clean_Up_Tooltip:SetBagItem(container, position)
	end

	local charges, usable, soulbound, quest, conjured
	for i = 1, Clean_Up_Tooltip:NumLines() do
		local text = getglobal('Clean_Up_TooltipTextLeft' .. i):GetText()

		local _, _, chargeString = strfind(text, chargesPattern)
		if chargeString then
			charges = tonumber(chargeString)
		elseif strfind(text, '^' .. ITEM_SPELL_TRIGGER_ONUSE) then
			usable = true
		elseif text == ITEM_SOULBOUND then
			soulbound = true
		elseif text == ITEM_BIND_QUEST then
			quest = true
		elseif text == ITEM_CONJURED then
			conjured = true
		end
	end

	return charges, usable, soulbound, quest, conjured
end

function self:Trash(container, position)
	for itemID in string.gfind(GetContainerItemLink(container, position) or '', 'item:(%d+)') do
		if ({GetItemInfo(itemID)})[3] == 0 then
			return true
		end
	end
end

function self:vendor_step()
	local found
	if self.atMerchant then
		for _, container in CONTAINERS.BAGS do
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

do
	local mapping = {
		BAGS = {},
		BANK = {},
	}

	local enabled = {
		BAGS = true,
		BANK = true,
	}

	local function resolve_position(container, position)
		local key = container .. ':' .. position
		for slot in self:present(enabled.BAGS and mapping.BAGS[key] or enabled.BANK and mapping.BANK[key] or nil) do
			return unpack(slot)
		end
		return container, position
	end

	for _, name in { 'GetContainerItemLink', 'GetContainerItemInfo', 'GetContainerItemCooldown', 'PickupContainerItem', 'SplitContainerItem', 'UseContainerItem' } do
		local orig = getglobal(name)
		setglobal(name, function(container, position, ...)
			container, position = resolve_position(container, position)
			return orig(container, position, unpack(arg))
		end)
	end

	for k, v in { Link='Link', Texture='Info', Cooldown='Cooldown' } do
		local inventory_name, container_name = 'GetInventoryItem' .. k, 'GetContainerItem' .. v
		local orig = getglobal(inventory_name)
		setglobal(inventory_name, function(unit, slot, ...)
			if inv2bank[slot] then
				return getglobal(container_name)(-1, inv2bank[slot])
			end
			return orig(unit, slot, unpack(arg))
		end)
	end

	function self:convert_tooltip(tt)
		local bag_orig, inv_orig = tt.SetBagItem, tt.SetInventoryItem
		local function bag_converted(self, container, position, ...)
			container, position = resolve_position(container, position)
			if container == BANK_CONTAINER then
				return inv_orig(self, 'player', bank2inv[position])
			else
				return bag_orig(self, container, position, unpack(arg))
			end
		end 
		tt.SetBagItem = bag_converted
		function tt:SetInventoryItem(unit, slot, ...)
			if inv2bank[slot] then
				return bag_converted(self, -1, inv2bank[slot])
			end
			return inv_orig(self, unit, slot, unpack(arg))
		end 
	end
	self:convert_tooltip(GameTooltip)

	function self:swap(slot1, slot2)
		if not enabled[self.key] then return end
		mapping[self.key][self:slot_key(unpack(slot1))], mapping[self.key][self:slot_key(unpack(slot2))] = { resolve_position(unpack(slot2)) }, { resolve_position(unpack(slot1)) }
	end

	function self:toggle_sorted_view()
		enabled[self.key] = not enabled[self.key]
		if enabled[self.key] then
			BUTTON[self.key]:GetNormalTexture():SetDesaturated(false)
			BUTTON[self.key]:GetPushedTexture():SetDesaturated(false)
			BUTTON[self.key]:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
		else
			BUTTON[self.key]:GetNormalTexture():SetDesaturated(true)
			BUTTON[self.key]:GetPushedTexture():SetDesaturated(true)
			BUTTON[self.key]:RegisterForClicks'RightButtonUp'
		end
		self.container_updater:Show()
	end
end

do
	local nop = function() end
	self.container_updater = CreateFrame'Frame'
	self.container_updater:SetScript('OnUpdate', function()
		this:Hide()

		local handlers = {}
		local frame = self
		while true do
			frame = EnumerateFrames(frame)
			if not frame then break end
			if frame.GetScript then
				handlers[frame] = frame:GetScript('OnEvent')
			end
		end

		event = 'BAG_UPDATE'
		for container = -1, 10 do
			arg1 = container
			for frame, handler in handlers do
				this = frame
				pcall(handler)
			end
		end

		if self.at_bank then
			event = 'PLAYERBANKSLOTS_CHANGED'
			this = BankFrame
			BankFrame_OnEvent()
			local frame = self
			for frame, handler in handlers do
				this = frame
				pcall(handler)
			end
		end
	end)
	self.container_updater:Hide()
end

function self:sort()
	local slots, item_slots = {}, {}

	for _, container in CONTAINERS[self.key] do
		local class = self:class(container)
		for position = 1, GetContainerNumSlots(container) do
			local slot = { container, position, class=class }
			if Clean_Up_Settings.reversed then tinsert(slots, slot) else tinsert(slots, 1, slot) end
			for item_info in self:present(self:info(container, position)) do
				slot.item = item_info
				tinsert(item_slots, slot)
			end
		end
	end

	sort(item_slots, function(a, b) return self:lt(a.item.sort_key, b.item.sort_key) end)

	local function fill(slot, src)
		self:swap(slot, src)
		src.item = slot.item
		for i = 1, getn(item_slots) do
			if item_slots[i] == slot then
				item_slots[i] = src
			end
		end
		slot.filled = true
	end

	for _, slot in slots do
		for link in self:present(Clean_Up_Settings.assignments[self:slot_key(unpack(slot))]) do
			for i, src in item_slots do
				if src.item.link == link then
					fill(slot, src)
					tremove(item_slots, i)
					break
				end
			end
		end
	end

	for key, class in self.CLASSES do
		for _, slot in slots do
			if slot.class == key and not slot.filled then
				for i, src in item_slots do
					if src.item.class == key then
						fill(slot, src)
						tremove(item_slots, i)
						break
					end
			    end
		    end
		end
	end

	for _, slot in slots do
		if not slot.filled then
			for src in self:present(tremove(item_slots, 1)) do
				fill(slot, src)
			end
		end
	end
end

function self:stack_step()
	local complete = true
	local partial_stacks = {}
	for _, container in CONTAINERS[self.key] do
		for position = 1, GetContainerNumSlots(container) do
			local name, count, locked = GetContainerItemInfo(container, position)
			local max_stack = self:max_stack(container, position)
			complete = complete and not locked
			if name and count < max_stack and not locked then
				complete = complete and not partial_stacks[name]
				partial_stacks[name] = partial_stacks[name] or {}
				tinsert(partial_stacks[name], {container, position})
			end
		end
	end
	for _, slots in partial_stacks do
		while true do
			local src, dst = tremove(slots), tremove(slots)
			if not (src and dst) then
				break
			end
			ClearCursor()
	       	PickupContainerItem(unpack(src))
			PickupContainerItem(unpack(dst))
		end
	end
	return complete
end

do
	local cache = {}
	function self:class(container)
		if not cache[container] and container ~= 0 and container ~= BANK_CONTAINER then
			for name in self:present(GetBagName(container)) do		
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

	function self:max_stack(bag, slot)
		local link = GetContainerItemLink(bag, slot)
		if link and not cache[link] then
			local _, _, itemID = strfind(link, 'item:(%d+)')
			cache[link] = ({GetItemInfo(itemID)})[7]
		end
		return link and cache[link]
	end
end

do
	local cache = {}

	function self:info(container, position)
		for link in self:present(GetContainerItemLink(container, position)) do
			local _, count = GetContainerItemInfo(container, position)
			local _, _, itemID, enchantID, suffixID, uniqueID = strfind(link, 'item:(%d+):(%d*):(%d*):(%d*)')
			itemID, enchantID, suffixID, uniqueID = tonumber(itemID), tonumber(enchantID), tonumber(suffixID), tonumber(uniqueID)
			local _, _, quality, _, type, subType, _, invType = GetItemInfo(itemID)
			local charges, usable, soulbound, quest, conjured = self:tooltip_info(container, position)

			local key = format('%s:%s:%s:%s:%s:%s', itemID, enchantID, suffixID, uniqueID, charges or count, (soulbound and 1 or 0))

			if not cache[key] then

				local sort_key = {}

				-- hearthstone
				if itemID == 6948 then
					tinsert(sort_key, 1)

				-- mounts
				elseif self.MOUNT[itemID] then
					tinsert(sort_key, 2)

				-- special items
				elseif self.SPECIAL[itemID] then
					tinsert(sort_key, 3)

				-- key items
				elseif self.KEY[itemID] then
					tinsert(sort_key, 4)

				-- tools
				elseif self.TOOL[itemID] then
					tinsert(sort_key, 5)

				-- conjured items
				elseif conjured then
					tinsert(sort_key, 13)

				-- soulbound items
				elseif soulbound then
					tinsert(sort_key, 6)

				-- enchanting reagents
				elseif self.ENCHANTING_REAGENT[itemID] then
					tinsert(sort_key, 7)

				-- other reagents
				elseif type == self.ITEM_TYPES[9] then
					tinsert(sort_key, 8)

				-- quest items
				elseif quest then
					tinsert(sort_key, 10)

				-- consumables
				elseif usable and type ~= self.ITEM_TYPES[1] and type ~= self.ITEM_TYPES[2] and type ~= self.ITEM_TYPES[8] or type == self.ITEM_TYPES[4] then
					tinsert(sort_key, 9)

				-- higher quality
				elseif quality > 1 then
					tinsert(sort_key, 11)

				-- common quality
				elseif quality == 1 then
					tinsert(sort_key, 12)

				-- junk
				elseif quality == 0 then
					tinsert(sort_key, 13)
				end

				tinsert(sort_key, self:ItemTypeKey(type))
				tinsert(sort_key, self:ItemInvTypeKey(type, subType, invType))
				tinsert(sort_key, self:ItemSubTypeKey(type, subType))
				tinsert(sort_key, -quality)
				tinsert(sort_key, itemID)
				tinsert(sort_key, -(charges or count))
				tinsert(sort_key, suffixID)
				tinsert(sort_key, enchantID)
				tinsert(sort_key, uniqueID)

				cache[key] = {
					link = link,
					sort_key = sort_key,
				}

				for class, info in self.CLASSES do
					if info.items[itemID] then
						cache[key].class = class
					end
				end
			end

			return cache[key]
		end
	end
end