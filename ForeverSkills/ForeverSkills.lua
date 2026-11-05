-- ForeverSkills: automatic action bar upkeep for WoW Forever (interface 16001).
--   1. A newly learned spell goes into the first empty slot of a visible default bar.
--   2. A spell on a bar is swapped for the highest rank you know.
-- Bars cannot be edited in combat, so work is deferred until combat ends.

local ADDON = "ForeverSkills"
local DEBOUNCE = 0.5
local MAX_ACTION_SLOT = 180

-- Bars: { frame name, first slot }; fill order is decided by OrderedBars(). Frame names are the default Blizzard bars;
-- the main bar is always considered visible and uses page 1 (slots 1-12).
local BARS = {
	{ frame = nil,                  first = 1,   label = "Main bar" },
	{ frame = "MultiBarBottomLeft", first = 61,  label = "Bottom left bar" },
	{ frame = "MultiBarBottomRight", first = 49, label = "Bottom right bar" },
	{ frame = "MultiBarRight",      first = 25,  label = "Right bar" },
	{ frame = "MultiBarLeft",       first = 37,  label = "Right bar 2" },
	{ frame = "MultiBar5",          first = 145, label = "Action bar 5" },
	{ frame = "MultiBar6",          first = 157, label = "Action bar 6" },
	{ frame = "MultiBar7",          first = 169, label = "Action bar 7" },
}
local SLOTS_PER_BAR = 12

local function Print(msg)
	print("|cff33ccff" .. ADDON .. "|r: " .. msg)
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

local function BarVisible(bar)
	if not bar.frame then
		return true
	end
	local f = _G[bar.frame]
	return f ~= nil and f:IsShown()
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

-- Main bar first, then visible horizontal bars from the lowest on screen upward
-- (nearest the main bar first), then visible vertical bars in table order.
local function OrderedBars()
	local horizontal, vertical = {}, {}
	for _, bar in ipairs(BARS) do
		local f = bar.frame and _G[bar.frame]
		if f and BarVisible(bar) then
			local w, h, bottom = Val(f:GetWidth()), Val(f:GetHeight()), Val(f:GetBottom())
			if w and h and bottom and w > h then
				horizontal[#horizontal + 1] = { bar = bar, bottom = bottom }
			else
				vertical[#vertical + 1] = bar
			end
		end
	end
	table.sort(horizontal, function(a, b)
		return a.bottom < b.bottom
	end)
	local ordered = { BARS[1] }
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
		do
			for slot = bar.first, bar.first + SLOTS_PER_BAR - 1 do
				if not HasAction(slot) then
					return slot
				end
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
			if top and top ~= id and rankIDs[name][id] then
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

local function Update(reason)
	if InCombatLockdown() then
		ForeverSkills.pending = true
		return
	end
	ForeverSkills.pending = false

	local db = ForeverSkillsCharDB
	local known, best, rankIDs = ScanSpellbook()
	if not next(known) then
		return -- spellbook not loaded yet; a later SPELLS_CHANGED retries
	end

	-- First run on this character: record what is already known, place nothing.
	if not db.known then
		db.known = known
		Print("baseline recorded (" .. ForeverSkills.count(known) .. " spells). New spells will be placed from now on.")
		return
	end

	local savedNames = {}
	for _, name in pairs(db.known) do
		savedNames[name] = true
	end

	UpgradeRanks(best, rankIDs)

	for id, name in pairs(known) do
		-- New spell line only: a new rank of a spell you already had is handled by UpgradeRanks.
		if not db.known[id] and not savedNames[name] and not SpellOnAnyBar(id) then
			local slot = FirstEmptySlot()
			if slot and PlaceSpell(slot, id) then
				Print("placed " .. SpellLabel(id) .. " in slot " .. slot)
			else
				Print("no free action bar slot for " .. SpellLabel(id))
			end
		end
	end

	db.known = known
end

-- Manual catch-up: upgrade ranks, then place the best rank of every known spell
-- that has no rank on any bar yet. Unlike Update, this ignores the saved baseline.
local function Sync()
	if InCombatLockdown() then
		Print("can't change action bars in combat; try again afterwards.")
		return
	end
	local known, best, rankIDs = ScanSpellbook()
	if not next(known) then
		Print("spellbook not loaded yet; try again in a moment.")
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
		if not onBar[name] then
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
			Print("no free action bar slot for " .. SpellLabel(best[name]))
		end
	end

	ForeverSkillsCharDB.known = known
	Print(("sync done: %d upgraded, %d placed, %d without a free slot."):format(upgraded, placed, full))
end

-- Events and commands ----------------------------------------------------

ForeverSkills = { pending = false }

function ForeverSkills.count(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

local timer
local function Schedule(reason)
	if timer then
		timer:Cancel()
	end
	timer = C_Timer.NewTimer(DEBOUNCE, function()
		timer = nil
		Update(reason)
	end)
end

local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "SPELLS_CHANGED", "PLAYER_REGEN_ENABLED" }) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		ForeverSkillsCharDB = ForeverSkillsCharDB or {}
	end
	if event == "PLAYER_REGEN_ENABLED" and not ForeverSkills.pending then
		return
	end
	Schedule(event)
end)

SLASH_FOREVERSKILLS1 = "/fskills"
SlashCmdList.FOREVERSKILLS = function(arg)
	arg = (arg or ""):lower()
	if arg == "reset" then
		ForeverSkillsCharDB.known = nil
		Print("baseline cleared; it will be re-recorded on the next update.")
		Update("reset")
	elseif arg == "sync" then
		Sync()
	elseif arg == "debug" then
		local known, best = ScanSpellbook()
		Print(("known castable spells: %d, in combat: %s, pending: %s"):format(
			ForeverSkills.count(known), tostring(InCombatLockdown()), tostring(ForeverSkills.pending)))
		for _, bar in ipairs(BARS) do
			Print(("%s: visible=%s"):format(bar.label, tostring(BarVisible(bar))))
		end
		local order = {}
		for _, bar in ipairs(OrderedBars()) do
			order[#order + 1] = bar.label
		end
		Print("fill order: " .. table.concat(order, " > "))
		Print("first empty slot: " .. tostring(FirstEmptySlot()))
		Print("ranked spells with a known best rank: " .. ForeverSkills.count(best))
	else
		Print("/fskills sync | debug | reset")
		Update("manual")
	end
end
