local __ = CreateFrame('Frame')
__:Hide()
__:SetScript('OnUpdate', function()
	this.UPDATE()
end)
__:SetScript('OnEvent', function()
	this[event]()
end)
__:RegisterEvent('ADDON_LOADED')

Clean_Up_Bags = {parent='ContainerFrame1', position={0, 0}}
Clean_Up_Bank = {parent='BankFrame', position={0, 0}}
Clean_Up_Reversed = false
Clean_Up_Assignments = {}

__.BAGS = {0, 1, 2, 3, 4}
__.BANK = {-1, 5, 6, 7, 8, 9, 10}

__.ITEM_TYPES = {GetAuctionItemClasses()}

function __.ItemTypeKey(itemClass)
	return __.Key(__.ITEM_TYPES, itemClass) or 0
end

function __.ItemSubTypeKey(itemClass, itemSubClass)
	return __.Key({GetAuctionItemSubClasses(__.ItemTypeKey(itemClass))}, itemClass) or 0
end

function __.ItemInvTypeKey(itemClass, itemSubClass, itemSlot)
	return __.Key({GetAuctionInvTypes(__.ItemTypeKey(itemClass), __.ItemSubTypeKey(itemSubClass))}, itemSlot) or 0
end

function __.ADDON_LOADED()
	if arg1 ~= 'Clean_Up' then
		return
	end

	__:RegisterEvent('UI_ERROR_MESSAGE')
	__:RegisterEvent('MERCHANT_SHOW')
	__:RegisterEvent('MERCHANT_CLOSED')

	__.CLASSES = {
		-- arrow
		{
			containers = {2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320},
			items = __.Set(),
		},
		
		-- bullet
		{
			containers = {2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714},
			items = __.Set(),
		},

		-- soul
		{
			containers = {22243, 22244, 21340, 21341, 21342},
			items = __.Set(),
		},

		-- ench
		{
			containers = {22246, 22248, 22249},
			items = __.Set(),
		},

		-- herb
		{
			containers = {22250, 22251, 22252},
			items = __.Set(),
		},

		_ = {containers = {}, items = {}},
	}

	__.MOUNT = __.Set(
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

	__.SPECIAL = __.Set(5462, 17696, 17117, 13347, 13289, 11511)

	__.KEY = __.Set(9240, 17191, 13544, 12324, 16309, 12384, 20402)

	__.TOOL = __.Set(7005, 12709, 19727, 5956, 2901, 6219, 10498, 6218, 6339, 11130, 11145, 16207, 9149, 15846, 6256, 6365, 6367)

	__.SetupHooks()
	__.SetupSlash()

	CreateFrame('GameTooltip', 'Clean_Up_Tooltip', nil, 'GameTooltipTemplate')

	__.CreateButton('Bags')
	__.CreateButton('Bank')
end

function __.UPDATE()
	if __.containers == __.BAGS and not __.model then
		if __.SellTrash() then
			return
		end
	end

	if not __.model then
		__.CreateModel()
	end

	if __.Sort() then
		__:Hide()
	end

	__.Stack()
end

function __.UI_ERROR_MESSAGE()
	if self.Inbox_Opening then
		if arg1 == BAG_ITEM_CLASS_MISMATCH then
			__.Log('Invalid item assignment', 1, 0, 0)
			__:Hide()
		elseif arg1 == BAG_ERROR then
			__.Log('Unknown error', 1, 0, 0)
			__:Hide()
		end
	end
end

function __.MERCHANT_SHOW()
	__.atMerchant = true
end

function __.MERCHANT_CLOSED()
	__.atMerchant = false
end

function __.Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage('[Clean Up] '..tostring(msg), 1, 1, 0)
end

function __.Set(...)
	local t = {}
	for i=1,arg.n do
		t[arg[i]] = true
	end
	return t
end

function __.LT(a, b)
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

function __.Key(table, value)
	for k, v in table do
		if v == value then
			return k
		end
	end
end

function __.SlotKey(container, position)
	return container..':'..position
end

function __.ItemKey(container, position)
	for _, link in {GetContainerItemLink(container, position)} do
		return link..(__.TooltipInfo(container, position).charges or '')
	end
end

function __.SetupHooks()

	__.PickupContainerItem = PickupContainerItem
	function PickupContainerItem(...)
		local container, position = unpack(arg)
		if IsAltKeyDown() then
			for _, itemKey in {__.ItemKey(container, position)} do
				local slotKey = __.SlotKey(container, position)
				Clean_Up_Assignments[slotKey] = itemKey
				__.Log(slotKey..' assigned to '..itemKey)
			end
		else
			__.PickupContainerItem(unpack(arg))
		end
	end

	__.UseContainerItem = UseContainerItem
	function UseContainerItem(...)
		local container, position = unpack(arg)
		if IsAltKeyDown() then
			local slotKey = __.SlotKey(container, position)
			if Clean_Up_Assignments[slotKey] then
				Clean_Up_Assignments[slotKey] = nil
				__.Log(slotKey..' freed')
			end
		else
			__.UseContainerItem(unpack(arg))
		end
	end
end

function __.SetupSlash()
  	SLASH_CLEANUPBAGS1 = '/cleanupbags'
	function SlashCmdList.CLEANUPBAGS(arg)
		Clean_Up_Bags = {parent=arg, position={0, 0}}
		__.Log('Bags-frame: '..arg)
	end

	SLASH_CLEANUPBANK1 = '/cleanupbank'
	function SlashCmdList.CLEANUPBANK(arg)
		Clean_Up_Bank = {parent=arg, position={0, 0}}
		__.Log('Bank-frame: '..arg)
	end

    SLASH_CLEANUPREVERSE1 = '/cleanupreverse'
    function SlashCmdList.CLEANUPREVERSE(arg)
        Clean_Up_Reversed = not Clean_Up_Reversed
        __.Log('Sort order: '..(Clean_Up_Reversed and 'Reversed' or 'Standard'))
	end
end

function __.CreateButton(name)
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
		__.containers = __[strupper(name)]
		__.Go()
	end)
	button:SetScript('OnEnter', function()
		GameTooltip:SetOwner(this)
		GameTooltip:AddLine(name)
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	__[strlower(name)..'Button'] = button
end

function __.Move(src, dst)
    local _, _, srcLocked = GetContainerItemInfo(src())
    local _, _, dstLocked = GetContainerItemInfo(dst())
    
	if not srcLocked and not dstLocked then
		ClearCursor()
       	PickupContainerItem(src())
		PickupContainerItem(dst())

	    local _, _, srcLocked = GetContainerItemInfo(src())
	    local _, _, dstLocked = GetContainerItemInfo(dst())
    	if srcLocked or dstLocked then
			if src.state.item == dst.state.item then
				local count = min(src.state.count, dst.state.item.stack - dst.state.count)
				src.state.count = src.state.count - count
				dst.state.count = dst.state.count + count
				if src.count == 0 then
					src.state.item = {}
				end
			else
				src.state, dst.state = dst.state, src.state
			end
		end

		return true
    end
end

function __.TooltipInfo(container, position)
	local chargesPattern = '^'..gsub(gsub(ITEM_SPELL_CHARGES_P1, '%%d', '(%%d+)'), '%%%d+%$d', '(%%d+)')..'$'

	Clean_Up_Tooltip:SetOwner(__, ANCHOR_NONE)
	Clean_Up_Tooltip:ClearLines()

	if container == BANK_CONTAINER then
		Clean_Up_Tooltip:SetInventoryItem('player', BankButtonIDToInvSlotID(position))
	else
		Clean_Up_Tooltip:SetBagItem(container, position)
	end

	local charges, usable, soulbound, quest, conjured
	for i=1,Clean_Up_Tooltip:NumLines() do
		local text = getglobal('Clean_Up_TooltipTextLeft'..i):GetText() -- TODO

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

	return {
		charges = charges,
		usable = usable,
		soulbound = soulbound,
		quest = quest,
		conjured = conjured,
	}
end

function __.Trash(container, position)
	for itemID in string.gfind(GetContainerItemLink(container, position) or '', 'item:(%d+)') do
		if ({GetItemInfo(itemID)})[3] == 0 then
			return true
		end
	end
end

function __.SellTrash()
	local found
	if __.atMerchant then
		for _, container in __.BAGS do
			for position=1,GetContainerNumSlots(container) do
				if __.Trash(container, position) then
					found = true
					UseContainerItem(container, position)
				end
			end
		end
	end
	return found
end

function __.Sort()
	local complete = true

	for _, dst in __.model do
		if dst.item and (dst.state.item ~= dst.item or dst.state.item == dst.item and dst.state.count < dst.count) then
			complete = false

			local sources, rank = {}, {}

			for _, src in __.model do
				if not (src.item and src.state.item == src.item and src.state.count <= src.count)
						and src ~= dst
						and src.state.item == dst.item
				then
					rank[src] = abs(src.state.count - dst.count + (dst.state.item == dst.item and dst.state.count or 0))
					tinsert(sources, src)
				end
			end

			sort(sources, function(a, b) return rank[a] < rank[b] end)

			for _, src in sources do
				if __.Move(src, dst) then
					break
				end
			end
		end
	end

	return complete
end

function __.Stack()
	for _, src in __.model do
		if src.state.count < src.state.item.stack then
			for _, dst in __.model do
				if dst.state.count < dst.state.item.stack and src.state.item == dst.state.item and src ~= dst then
					__.Move(src, dst)
				end
			end
		end
	end
end

function __.Go()
	__.model = nil
	__:Show()
end

function __.Assign(slot, content)
	local count = min(content.count, content.item.stack)
	slot.item = content.item
	slot.count = count
	content.count = content.count - count
end

function __.CreateModel()
	__.model = {}
	local contents, groups = {}, {}
	for key in __.CLASSES do
    	groups[key] = {}
	end

	local function insert(t, v) if Clean_Up_Reversed then tinsert(t, v) else tinsert(t, 1, v) end end
	for _, container in __.containers do
		if GetContainerNumSlots(container) > 0 then -- TODO
			local group = groups[__.ClassKey(container)]
			for position=1,GetContainerNumSlots(container) do

				local slot = __.Slot(container, position)
				for _, itemKey in {__.ItemKey(container, position)} do
					contents[itemKey] = contents[itemKey] or {
						item = __.Item(container, position),
						count = 0,
					}
					local _, count = GetContainerItemInfo(container, position)
					contents[itemKey].count = contents[itemKey].count + count
					slot.state = {
						item = contents[itemKey].item,
						count = count,
					}
				end
				slot.state = slot.state or {item={stack=0}, count=0}
				insert(__.model, slot)
				insert(group, slot)
			end
		end
	end

	for _, slot in __.model do
		for _, itemKey in {Clean_Up_Assignments[__.SlotKey(slot())]} do
			for _, content in {contents[itemKey]} do
				__.Assign(slot, content)
				if content.count == 0 then
					contents[itemKey] = nil
				end
			end	
		end
	end

	local contents, temp = {}, contents
	for _, content in temp do
		tinsert(contents, content)
	end
	sort(contents, function(a, b) return __.LT(a.item.sortKey, b.item.sortKey) end)

	for _, slot in groups._ do
		if not contents[1] then
			break
		elseif not slot.item then
			__.Assign(slot, contents[1])
			if contents[1].count == 0 then
				tremove(contents, 1)
	        end
	    end
	end
end

do
	local cache = {}
	function __.ClassKey(container)
		if not cache[container] then
			for _, name in {container ~= 0 and GetBagName(container)} do			
				for key, class in __.CLASSES do
					for _, itemID in class.containers do
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
		__call = function(self, ...)
			return self.container, self.position
		end,		
	}

	function __.Slot(container, position)
		return setmetatable({
			container = container,
			position = position,
		}, slot_mt)
	end
end

function __.Item(container, position)
	local link = GetContainerItemLink(container, position)
	local itemID = tonumber(({strfind(link, 'item:(%d+)')})[3])

	local itemName, _, itemRarity, itemMinLevel, itemClass, itemSubClass, itemStack, itemEquipLoc = GetItemInfo(itemID)
	local tooltipInfo = __.TooltipInfo(container, position)

	local sortKey = {}

	-- hearthstone
	if itemID == 6948 then
		tinsert(sortKey, 1)

	-- mounts
	elseif __.MOUNT[itemID] then
		tinsert(sortKey, 2)

	-- special items
	elseif __.SPECIAL[itemID] then
		tinsert(sortKey, 3)

	-- key items
	elseif __.KEY[itemID] then
		tinsert(sortKey, 4)

	-- tools
	elseif __.TOOL[itemID] then
		tinsert(sortKey, 5)

	-- conjured items
	elseif tooltipInfo.conjured then
		tinsert(sortKey, 13)

	-- soulbound items
	elseif tooltipInfo.soulbound then
		tinsert(sortKey, 6)

	-- reagents
	elseif itemClass == __.ITEM_TYPES[9] then
		tinsert(sortKey, 7)

	-- quest items
	elseif tooltipInfo.quest then
		tinsert(sortKey, 9)

	-- consumables
	elseif tooltipInfo.usable and itemClass ~= __.ITEM_TYPES[1] and itemClass ~= __.ITEM_TYPES[2] and itemClass ~= __.ITEM_TYPES[8] or itemClass == __.ITEM_TYPES[4] then
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
	
	tinsert(sortKey, __.ItemTypeKey(itemClass))
	tinsert(sortKey, __.ItemInvTypeKey(itemClass, itemSubClass, itemEquipLoc))
	tinsert(sortKey, __.ItemSubTypeKey(itemClass, itemSubClass))
	tinsert(sortKey, itemName)
	tinsert(sortKey, 1/(tooltipInfo.charges or 1))

	return {
		sortKey = sortKey,
		stack = itemStack,
	}
end
