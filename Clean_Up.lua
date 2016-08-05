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

	__:RegisterEvent('MERCHANT_SHOW')
	__:RegisterEvent('MERCHANT_CLOSED')

	__.CLASSES = {
		-- arrow
		{
			containers = {2101, 5439, 7278, 11362, 3573, 3605, 7371, 8217, 2662, 19319, 18714},
			items = __.Set(2512, 2515, 3030, 3464, 9399, 11285, 12654, 18042, 19316),
		},
		
		-- bullet
		{
			containers = {2102, 5441, 7279, 11363, 3574, 3604, 7372, 8218, 2663, 19320},
			items = __.Set(2516, 2519, 3033, 3465, 4960, 5568, 8067, 8068, 8069, 10512, 10513, 11284, 11630, 13377, 15997, 19317),
		},

		-- soul
		{
			containers = {22243, 22244, 21340, 21341, 21342},
			items = __.Set(6265),
		},

		-- ench
		{
			containers = {22246, 22248, 22249},
			items = __.Set(
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
			items = __.Set(765, 785, 2447, 2449, 2450, 2452, 2453, 3355, 3356, 3357, 3358, 3369, 3818, 3819, 3820, 3821, 4625, 8831, 8836, 8838, 8839, 8845, 8846, 13463, 13464, 13465, 13466, 13467, 13468),
		},
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

function __.SetupHooks()

	__.PickupContainerItem = PickupContainerItem
	function PickupContainerItem(...)
		local container, position = unpack(arg)
		if IsAltKeyDown() then
			for _, item in {__.Item(container, position)} do
				local slotKey = __.SlotKey(container, position)
				Clean_Up_Assignments[slotKey] = item
				__.Log(slotKey..' assigned to '..item)
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
				local count = min(src.state.count, __.MaxStack(dst.state.item) - dst.state.count)
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
				if src.state.item == dst.item
					and src ~= dst
					and not (src.item and src.state.item == src.item and src.state.count <= src.count)
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
		if src.state.item and src.state.count < __.MaxStack(src.state.item) then
			for _, dst in __.model do
				if dst ~= src and dst.state.item and dst.state.item == src.state.item and dst.state.count < __.MaxStack(dst.state.item) then
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
			local count = min(counts[item], __.MaxStack(item))
			slot.item = item
			slot.count = count
			counts[item] = counts[item] - count
			return true
		end
	end

	local function assignCustom()
		for _, slot in __.model do
			for _, item in {Clean_Up_Assignments[__.SlotKey(slot.container, slot.position)]} do
				if counts[item] then
					assign(slot, item)
				end
			end
		end
	end

	local function assignSpecial()
		for key, class in __.CLASSES do
			for _, slot in __.model do
				if slot.class == key and not slot.item then
					for _, item in items do
						if __.Class(item) == key and assign(slot, item) then
							break
						end
				    end
			    end
			end
		end
	end

	local function assignRemaining()
		for _, slot in __.model do
			if not slot.class and not slot.item then
				for _, item in items do
					if assign(slot, item) then
						break
					end
			    end
		    end
		end
	end

	function __.CreateModel()
		__.model = {}
		counts = {}

		for _, container in __.containers do
			local class = __.ContainerClass(container)
			for position=1,GetContainerNumSlots(container) do
				local slot = {container=container, position=position, class=class}
				local item = __.Item(container, position)
				if item then
					local _, count = GetContainerItemInfo(container, position)
					slot.state = {item=item, count=count}
					counts[item] = (counts[item] or 0) + count
				else
					slot.state = {}
				end
				insert(__.model, slot)
			end
		end
		items = {}
		for item, _ in counts do
			tinsert(items, item)
		end
		sort(items, function(a, b) return __.LT(__.SortKey(a), __.SortKey(b)) end)

		assignCustom()
		assignSpecial()
		assignRemaining()
	end
end

do
	local cache = {}
	function __.ContainerClass(container)
		if not cache[container] and container ~= 0 and container ~= BANK_CONTAINER then
			for _, name in {GetBagName(container)} do		
				for class, info in __.CLASSES do
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

	function __.Class(item)
		return cache[item].class
	end

	function __.MaxStack(item)
		return cache[item].stack
	end

	function __.SortKey(item)
		return cache[item].sortKey
	end

	function __.Item(container, position)
		for _, link in {GetContainerItemLink(container, position)} do
			local _, _, itemID, enchantID, suffixID, uniqueID = strfind(link, 'item:(%d+):(%d*):(%d*):(%d*)')
			itemID = tonumber(itemID)
			local _, _, quality, _, type, subType, stack, invType = GetItemInfo(itemID)
			local charges, usable, soulbound, quest, conjured = __.TooltipInfo(container, position)

			local key = format('%s:%s:%s:%s:%s:%s', itemID, enchantID, suffixID, uniqueID, charges, (soulbound and 1 or 0))

			if not cache[key] then

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
				elseif conjured then
					tinsert(sortKey, 13)

				-- soulbound items
				elseif soulbound then
					tinsert(sortKey, 6)

				-- reagents
				elseif type == __.ITEM_TYPES[9] then
					tinsert(sortKey, 7)

				-- quest items
				elseif quest then
					tinsert(sortKey, 9)

				-- consumables
				elseif usable and type ~= __.ITEM_TYPES[1] and type ~= __.ITEM_TYPES[2] and type ~= __.ITEM_TYPES[8] or type == __.ITEM_TYPES[4] then
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
				
				tinsert(sortKey, __.ItemTypeKey(type))
				tinsert(sortKey, __.ItemInvTypeKey(type, subType, invType))
				tinsert(sortKey, __.ItemSubTypeKey(type, subType))
				tinsert(sortKey, itemID)
				tinsert(sortKey, 1/charges)
				tinsert(sortKey, suffixID)
				tinsert(sortKey, enchantID)
				tinsert(sortKey, uniqueID)

				cache[key] = {
					stack = stack,
					sortKey = sortKey,
				}

				for class, info in __.CLASSES do
					if info.items[itemID] then
						cache[key].class = class
					end
				end
			end

			return key
		end
	end
end
