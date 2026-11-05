-- ForeverSkills: automatic action bar upkeep for WoW Forever (interface 16001).
--   1. A newly learned spell goes into the first empty slot of a visible default bar.
--   2. A spell on a bar is swapped for the highest rank you know.
-- Bars cannot be edited in combat, so work is deferred until combat ends.

local ADDON = "ForeverSkills"
local DEBOUNCE = 0.5
local MAX_ACTION_SLOT = 180
local SLOTS_PER_BAR = 12
local BARTENDER_BARS = 10

-- { key, frame name, first slot }. Frame names are the default Blizzard bars;
-- the main bar is always considered visible and uses page 1 (slots 1-12).
local BARS = {
	{ key = "main", frame = nil,                  first = 1,   label = "Main bar", main = true },
	{ key = "bl",   frame = "MultiBarBottomLeft",  first = 61,  label = "Bottom left bar" },
	{ key = "br",   frame = "MultiBarBottomRight", first = 49,  label = "Bottom right bar" },
	{ key = "r",    frame = "MultiBarRight",       first = 25,  label = "Right bar" },
	{ key = "l",    frame = "MultiBarLeft",        first = 37,  label = "Right bar 2" },
	{ key = "b5",   frame = "MultiBar5",           first = 145, label = "Action bar 5" },
	{ key = "b6",   frame = "MultiBar6",           first = 157, label = "Action bar 6" },
	{ key = "b7",   frame = "MultiBar7",           first = 169, label = "Action bar 7" },
}

local ORDER_POSITION, ORDER_FIXED = 1, 2
local CHAT_ALL, CHAT_WARN = 1, 2 -- 3 is silent

local DEFAULTS = { autoPlace = true, autoUpgrade = true, fillOrder = ORDER_POSITION, chat = CHAT_ALL }

local db -- ForeverSkillsCharDB, set on ADDON_LOADED
local pending = false

local function Count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- level: "info" (placed/upgraded), "warn" (no free slot), "cmd" (answer to a command, always shown)
local function Print(msg, level)
	level = level or "info"
	local chat = db and db.chat or CHAT_ALL
	if level == "cmd" or (level == "warn" and chat <= CHAT_WARN) or (level == "info" and chat == CHAT_ALL) then
		print("|cff33ccff" .. ADDON .. "|r: " .. msg)
	end
end

-- Midnight-era APIs can hand back secret values that error on comparison.
local function Val(v)
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return v
end

local function SpellLabel(id)
	local link = C_Spell.GetSpellLink and Val(C_Spell.GetSpellLink(id))
	return link or Val(C_Spell.GetSpellName(id)) or ("spell #" .. id)
end

-- Spellbook scan ---------------------------------------------------------

-- Returns known[id] = name for every castable spell, best[name] = highest known
-- rank id, and rankIDs[name] = set of every known rank id of that name.
local function ScanSpellbook()
	local known, best, rankIDs = {}, {}, {}
	local bank = Enum.SpellBookSpellBank.Player
	local spellType = Enum.SpellBookItemType.Spell

	for line = 1, Val(C_SpellBook.GetNumSpellBookSkillLines()) or 0 do
		local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
		if lineInfo and not Val(lineInfo.offSpecID) then
			local offset, count = lineInfo.itemIndexOffset, lineInfo.numSpellBookItems
			for slot = offset + 1, offset + count do
				local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
				local id = item and Val(item.spellID)
				if id and item.itemType == spellType and not item.isPassive and not item.isOffSpec then
					local locked = C_LevelLink and C_LevelLink.IsSpellLocked and Val(C_LevelLink.IsSpellLocked(id))
					local name = Val(C_Spell.GetSpellName(id))
					if name and not locked and C_SpellBook.IsSpellKnown(id, bank) then
						known[id] = name
						rankIDs[name] = rankIDs[name] or {}
						rankIDs[name][id] = true
						if not Val(C_SpellBook.IsSpellBookItemLowRank(slot, bank)) then
							best[name] = id
						end
					end
				end
			end
		end
	end
	return known, best, rankIDs
end

-- Action bar helpers -----------------------------------------------------

local function DefaultBars()
	local list = {}
	for _, bar in ipairs(BARS) do
		list[#list + 1] = {
			key = bar.key,
			label = bar.label,
			first = bar.first,
			count = SLOTS_PER_BAR,
			frame = bar.frame and _G[bar.frame],
			main = bar.main,
			alwaysVisible = bar.main,
		}
	end
	return list
end

-- Bartender4 bar N, button i sits on action slot (N-1)*12 + i, and a bar can have fewer than 12 buttons.
local function BartenderBars()
	local module = Bartender4 and Bartender4.GetModule and Bartender4:GetModule("ActionBars", true)
	if not (module and module.actionbars) then
		return nil
	end
	local list = {}
	for id = 1, BARTENDER_BARS do
		local frame = module.actionbars[id]
		if frame and frame.config and frame.config.enabled and frame.buttons and #frame.buttons > 0 then
			list[#list + 1] = {
				key = "bt4_" .. id,
				label = "Bartender bar " .. id,
				first = (id - 1) * 12 + 1,
				count = math.min(#frame.buttons, 12),
				frame = frame,
				main = id == 1,
			}
		end
	end
	return list
end

local function GetBars()
	return BartenderBars() or DefaultBars()
end

local function BarVisible(bar)
	return bar.alwaysVisible or (bar.frame ~= nil and bar.frame:IsShown())
end

local function SpellOnAnyBar(id)
	for slot = 1, MAX_ACTION_SLOT do
		local kind, actionID = GetActionInfo(slot)
		if Val(kind) == "spell" and Val(actionID) == id then
			return true
		end
	end
	return false
end

-- Bars that are visible and ticked in the settings, in fill order. By screen
-- position: main bar first, then horizontal bars from the lowest on screen
-- upward (nearest the main bar first), then vertical bars in table order.
local function OrderedBars()
	local usable = {}
	for _, bar in ipairs(GetBars()) do
		if db.bars[bar.key] and BarVisible(bar) then
			usable[#usable + 1] = bar
		end
	end
	if db.fillOrder == ORDER_FIXED then
		return usable
	end

	local main, horizontal, vertical = nil, {}, {}
	for _, bar in ipairs(usable) do
		if bar.main then
			main = bar
		else
			local f = bar.frame
			local w, h, bottom = Val(f:GetWidth()), Val(f:GetHeight()), Val(f:GetBottom())
			if w and h and bottom and w > h then
				horizontal[#horizontal + 1] = { bar = bar, bottom = bottom * f:GetEffectiveScale() }
			else
				vertical[#vertical + 1] = bar
			end
		end
	end
	table.sort(horizontal, function(a, b)
		return a.bottom < b.bottom
	end)

	local ordered = { main }
	for _, entry in ipairs(horizontal) do
		ordered[#ordered + 1] = entry.bar
	end
	for _, bar in ipairs(vertical) do
		ordered[#ordered + 1] = bar
	end
	return ordered
end

local function FirstEmptySlot()
	for _, bar in ipairs(OrderedBars()) do
		for slot = bar.first, bar.first + bar.count - 1 do
			if not HasAction(slot) then
				return slot
			end
		end
	end
end

local function PlaceSpell(slot, id)
	ClearCursor()
	C_Spell.PickupSpell(id)
	PlaceAction(slot)
	ClearCursor()
	return HasAction(slot)
end

-- Rank upgrades ----------------------------------------------------------

local function UpgradeRanks(best, rankIDs)
	local upgraded = 0
	for slot = 1, MAX_ACTION_SLOT do
		local kind, id = GetActionInfo(slot)
		id = Val(id)
		if Val(kind) == "spell" and id then
			local name = Val(C_Spell.GetSpellName(id))
			local top = name and best[name]
			if top and top ~= id and rankIDs[name][id] and not db.ignored[name] then
				if PlaceSpell(slot, top) then
					upgraded = upgraded + 1
					Print("upgraded " .. SpellLabel(top))
				end
			end
		end
	end
	return upgraded
end

-- Main pass --------------------------------------------------------------

local function Update()
	if InCombatLockdown() then
		pending = true
		return
	end
	pending = false

	local known, best, rankIDs = ScanSpellbook()
	if not next(known) then
		return -- spellbook not loaded yet; a later SPELLS_CHANGED retries
	end

	-- First run on this character: record what is already known, place nothing.
	if not db.known then
		db.known = known
		Print("baseline recorded (" .. Count(known) .. " spells). New spells will be placed from now on.")
		return
	end

	if db.autoUpgrade then
		UpgradeRanks(best, rankIDs)
	end

	if db.autoPlace then
		local savedNames = {}
		for _, name in pairs(db.known) do
			savedNames[name] = true
		end

		for id, name in pairs(known) do
			-- New spell line only: a new rank of a spell you already had is handled by UpgradeRanks.
			if not db.known[id] and not savedNames[name] and not db.ignored[name] and not SpellOnAnyBar(id) then
				local slot = FirstEmptySlot()
				if slot and PlaceSpell(slot, id) then
					Print("placed " .. SpellLabel(id) .. " in slot " .. slot)
				else
					Print("no free action bar slot for " .. SpellLabel(id), "warn")
				end
			end
		end
	end

	db.known = known
end

-- Manual catch-up: upgrade ranks, then place the best rank of every known spell
-- that has no rank on any bar yet. Unlike Update, this ignores the saved baseline.
local function Sync()
	if InCombatLockdown() then
		Print("can't change action bars in combat; try again afterwards.", "cmd")
		return
	end
	local known, best, rankIDs = ScanSpellbook()
	if not next(known) then
		Print("spellbook not loaded yet; try again in a moment.", "cmd")
		return
	end

	local upgraded = UpgradeRanks(best, rankIDs)

	local onBar = {}
	for slot = 1, MAX_ACTION_SLOT do
		local kind, id = GetActionInfo(slot)
		id = Val(id)
		if Val(kind) == "spell" and id and known[id] then
			onBar[known[id]] = true
		end
	end

	local names = {}
	for name in pairs(best) do
		if not onBar[name] and not db.ignored[name] then
			names[#names + 1] = name
		end
	end
	table.sort(names)

	local placed, full = 0, 0
	for _, name in ipairs(names) do
		local slot = FirstEmptySlot()
		if slot and PlaceSpell(slot, best[name]) then
			placed = placed + 1
		else
			full = full + 1
			Print("no free action bar slot for " .. SpellLabel(best[name]), "cmd")
		end
	end

	db.known = known
	Print(("sync done: %d upgraded, %d placed, %d without a free slot."):format(upgraded, placed, full), "cmd")
end

-- Settings ---------------------------------------------------------------

local settingsCategory

local function BuildIgnorePanel()
	local ROW = 26
	local panel = CreateFrame("Frame")
	panel.name = "Ignored spells"

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("Ignored spells")

	local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	desc:SetText("Ticked spells are never placed or rank-upgraded by ForeverSkills.")

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 16, -72)
	scroll:SetPoint("BOTTOMRIGHT", -36, 16)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(360, 1)
	scroll:SetScrollChild(content)

	local rows = {}
	local function GetRow(i)
		local row = rows[i]
		if not row then
			row = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
			row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(20, 20)
			row.icon:SetPoint("LEFT", row, "RIGHT", 2, 0)
			row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			row.label:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
			row:SetScript("OnClick", function(self)
				db.ignored[self.spellName] = self:GetChecked() and true or nil
			end)
			rows[i] = row
		end
		return row
	end

	panel:SetScript("OnShow", function()
		local _, best = ScanSpellbook()
		local names = {}
		for name in pairs(best) do
			names[#names + 1] = name
		end
		table.sort(names)
		for i, name in ipairs(names) do
			local row = GetRow(i)
			row.spellName = name
			row:SetChecked(db.ignored[name] and true or false)
			row.icon:SetTexture(C_Spell.GetSpellTexture(best[name]))
			row.label:SetText(name)
			row:Show()
		end
		for i = #names + 1, #rows do
			rows[i]:Hide()
		end
		content:SetHeight(math.max(1, #names * ROW))
	end)

	return panel
end

-- Bars offered as checkboxes: Bartender4's ten when it is installed, else the default Blizzard bars.
local function SettingsBars()
	if not Bartender4 then
		return BARS
	end
	local list = {}
	for id = 1, BARTENDER_BARS do
		list[id] = { key = "bt4_" .. id, label = "Bartender bar " .. id }
	end
	return list
end

local function BuildSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory(ADDON)

	local function Add(variable, tbl, key, label, default)
		return Settings.RegisterAddOnSetting(category, ADDON .. "_" .. variable, key, tbl, type(default), label, default)
	end
	local function Header(text)
		if layout and CreateSettingsListSectionHeaderInitializer then
			layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
		end
	end
	local function Check(variable, tbl, key, label, default, tip)
		Settings.CreateCheckbox(category, Add(variable, tbl, key, label, default), tip)
	end
	local function Dropdown(variable, key, label, default, tip, choices)
		Settings.CreateDropdown(category, Add(variable, db, key, label, default), function()
			local container = Settings.CreateControlTextContainer()
			for i, text in ipairs(choices) do
				container:Add(i, text)
			end
			return container:GetData()
		end, tip)
	end

	Header("Behaviour")
	Check("autoPlace", db, "autoPlace", "Place new spells", DEFAULTS.autoPlace,
		"Put a newly learned spell in the first empty slot of a visible bar.")
	Check("autoUpgrade", db, "autoUpgrade", "Upgrade spell ranks", DEFAULTS.autoUpgrade,
		"Replace lower ranks on your bars with the highest rank you know.")
	Dropdown("chat", "chat", "Chat messages", DEFAULTS.chat,
		"How much ForeverSkills says in chat. Command replies are always shown.",
		{ "Everything", "Warnings only", "Silent" })

	Header(Bartender4 and "Bars (Bartender4 detected)" or "Bars")
	Dropdown("fillOrder", "fillOrder", "Fill order", DEFAULTS.fillOrder,
		"Screen position fills the main bar, then the lowest bar upward. Fixed uses the order listed below.",
		{ "By screen position", "Fixed (list order)" })
	for _, bar in ipairs(SettingsBars()) do
		Check("bar_" .. bar.key, db.bars, bar.key, bar.label, true,
			"Allow new spells to be placed on this bar. Rank upgrades happen on any bar regardless.")
	end

	Settings.RegisterCanvasLayoutSubcategory(category, BuildIgnorePanel(), "Ignored spells")
	Settings.RegisterAddOnCategory(category)
	settingsCategory = category
end

local function OpenSettings()
	if InCombatLockdown() then
		Print("can't open settings in combat; try again afterwards.", "cmd")
	elseif settingsCategory then
		Settings.OpenToCategory(settingsCategory:GetID())
	else
		Print("settings panel is unavailable.", "cmd")
	end
end

local function InitDB()
	ForeverSkillsCharDB = ForeverSkillsCharDB or {}
	db = ForeverSkillsCharDB
	for key, value in pairs(DEFAULTS) do
		if db[key] == nil then
			db[key] = value
		end
	end
	db.bars = db.bars or {}
	for _, bar in ipairs(BARS) do
		if db.bars[bar.key] == nil then
			db.bars[bar.key] = true
		end
	end
	for id = 1, BARTENDER_BARS do
		if db.bars["bt4_" .. id] == nil then
			db.bars["bt4_" .. id] = true
		end
	end
	db.ignored = db.ignored or {}
end

-- Events and commands ----------------------------------------------------

local timer
local function Schedule()
	if timer then
		timer:Cancel()
	end
	timer = C_Timer.NewTimer(DEBOUNCE, function()
		timer = nil
		Update()
	end)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON then
			InitDB()
			local ok, err = pcall(BuildSettings)
			if not ok then
				Print("settings panel failed to load: " .. tostring(err), "cmd")
			end
		end
		return
	end
	if not db or (event == "PLAYER_REGEN_ENABLED" and not pending) then
		return
	end
	Schedule()
end)

SLASH_FOREVERSKILLS1 = "/fskills"
SLASH_FOREVERSKILLS2 = "/fskill"
SlashCmdList.FOREVERSKILLS = function(arg)
	arg = (arg or ""):lower()
	if arg == "" or arg == "options" or arg == "config" then
		OpenSettings()
	elseif arg == "sync" then
		Sync()
	elseif arg == "reset" then
		db.known = nil
		Print("baseline cleared; it will be re-recorded on the next update.", "cmd")
		Update()
	elseif arg == "debug" then
		local known, best = ScanSpellbook()
		Print(("known castable spells: %d, in combat: %s, pending: %s"):format(
			Count(known), tostring(InCombatLockdown()), tostring(pending)), "cmd")
		Print("bar source: " .. (BartenderBars() and "Bartender4" or "default Blizzard bars"), "cmd")
		for _, bar in ipairs(GetBars()) do
			Print(("%s: visible=%s, enabled=%s"):format(bar.label, tostring(BarVisible(bar)), tostring(db.bars[bar.key])), "cmd")
		end
		local order = {}
		for _, bar in ipairs(OrderedBars()) do
			order[#order + 1] = bar.label
		end
		Print("fill order: " .. table.concat(order, " > "), "cmd")
		Print("first empty slot: " .. tostring(FirstEmptySlot()), "cmd")
		Print("ranked spells with a known best rank: " .. Count(best) .. ", ignored: " .. Count(db.ignored), "cmd")
	else
		Print("/fskills (settings) | sync | debug | reset", "cmd")
	end
end
