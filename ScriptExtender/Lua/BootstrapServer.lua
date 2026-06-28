-- DanceWithSource - Sacred Ground surface dispatcher (v16)
--
-- Per bug report 2026-06-28:
--   * Heals are 100% poll-driven (work in AND out of combat, no 4x stacking).
--       Fire:   instant 1d4 on entry + 1d4 every turn (~6s) while standing.
--       Water:  2d4 every turn (~6s) while standing.
--       Poison: 2d4 every turn for 3 turns; PERSISTS after leaving tile/aura.
--   * Poison & Lightning are PERSISTENT - not stripped on aura exit / turn end.
--   * Poison removes POISONED; Electrified removes shock; both re-applied while on tile.
--   * Ice Agathys cooldown = 3 turns (was 5); cooldown survives aura re-entry (no spam).
--   * Lightning grants real speed (ActionResourceMultiplier) + shock immunity.

local MOD_TAG = "[DWS v16]"

local SACRED_MARK = "DWS_SACRED_GROUND_ZONE"
local HEAL_1D4 = "DWS_SACRED_HEAL_1D4"
local HEAL_2D4 = "DWS_SACRED_HEAL_2D4"

-- 1 BG3 turn = 6s; poll = 2s -> 3 polls per turn
local POLL_INTERVAL_MS  = 2000
local POLLS_PER_TURN     = 3
local SACRED_DURATION    = 6     -- managed surface buff, refreshed while standing
local PERSIST_DURATION   = 18    -- poison resist / lightning: 3 turns, persists
local POISON_HEAL_POLLS  = 9     -- 3 turns of poison regen
local AGATHYS_DURATION   = 30
local AGATHYS_CD_POLLS   = 9     -- 3 turns
local BLOODLUST_DURATION = 6
local BLOOD_COOLDOWN     = 6

local SurfaceGroundConversions = {
    ["SurfaceFire"]               = "DWS_SACRED_FIRE",
    ["SurfaceFireBlessed"]        = "DWS_SACRED_FIRE",
    ["SurfaceFireCursed"]         = "DWS_SACRED_FIRE",
    ["SurfaceHellfire"]           = "DWS_SACRED_FIRE",
    ["SurfacePoison"]             = "DWS_SACRED_POISON",
    ["SurfacePoisonBlessed"]      = "DWS_SACRED_POISON",
    ["SurfacePoisonCursed"]       = "DWS_SACRED_POISON",
    ["SurfacePoisonCloud"]        = "DWS_SACRED_POISON",
    ["SurfaceWater"]              = "DWS_SACRED_CLEANSE_WATHER",
    ["SurfaceWaterBlessed"]       = "DWS_SACRED_CLEANSE_WATHER",
    ["SurfaceWaterCursed"]        = "DWS_SACRED_CLEANSE_WATHER",
    ["SurfaceWaterCloud"]         = "DWS_SACRED_CLEANSE_WATHER",
    ["SurfaceOil"]                = "DWS_SACRED_OIL",
    ["SurfaceOilCloud"]           = "DWS_SACRED_OIL",
    ["SurfaceGrease"]             = "DWS_SACRED_OIL",
    ["SurfaceGreaseCloud"]        = "DWS_SACRED_OIL",
    ["SurfaceIce"]                = "DWS_SACRED_ICE",
    ["SurfaceIceThin"]            = "DWS_SACRED_ICE",
    ["SurfaceIceCloud"]           = "DWS_SACRED_ICE",
    ["SurfaceFrozen"]             = "DWS_SACRED_ICE",
    ["SurfaceWaterFrozen"]        = "DWS_SACRED_ICE",
    ["SurfaceWaterFrozenBlessed"] = "DWS_SACRED_ICE",
    ["SurfaceWaterFrozenCursed"]  = "DWS_SACRED_ICE",
    ["SurfaceBlood"]              = "DWS_SACRED_BLOOD",
    ["SurfaceBloodSilver"]        = "DWS_SACRED_BLOOD",
    ["SurfaceBloodElectrified"]   = "DWS_SACRED_BLOOD",
    ["SurfaceBloodCloud"]         = "DWS_SACRED_BLOOD",
    ["SurfaceAcid"]               = "DWS_SACRED_ACID",
    ["SurfaceAcidBlessed"]        = "DWS_SACRED_ACID",
    ["SurfaceAcidCursed"]         = "DWS_SACRED_ACID",
    ["SurfaceAcidCloud"]          = "DWS_SACRED_ACID",
}

local SurfaceStatusTriggers = {
    ["BURNING"]      = "DWS_SACRED_FIRE",
    ["POISONED"]     = "DWS_SACRED_POISON",
    ["WET"]          = "DWS_SACRED_CLEANSE_WATHER",
    ["SHOCKED"]      = "DWS_SACRED_LIGHTNING",
    ["ELECTROCUTED"] = "DWS_SACRED_LIGHTNING",
}

local SHOCK_STATUS_NAMES = {
    "SHOCKED", "ELECTROCUTED", "ELECTRIFIED", "SURFACE_ELECTROCUTED",
}

-- Stripped when leaving the aura / at turn end if not refreshed this turn.
local ManagedSacred = {
    "DWS_SACRED_FIRE",
    "DWS_SACRED_CLEANSE_WATHER",
    "DWS_SACRED_OIL",
    "DWS_SACRED_ICE",
    "DWS_SACRED_ACID",
    "DWS_SACRED_BLOOD",
}

-- Never auto-stripped; rely on their own duration.
local PersistentSacred = {
    ["DWS_SACRED_POISON"]       = true,
    ["DWS_SACRED_LIGHTNING"]    = true,
    ["DWS_SACRED_ICE_AGATHYS"]  = true,
    ["DWS_SACRED_BLOOD_LUST"]   = true,
    ["DWS_SACRED_BLOOD_CD"]     = true,
}

local pollCounter           = 0
local markedCharacters      = {}   -- key -> guid
local refreshedThisTurn     = {}   -- key -> { sacred -> true }
local lastLoggedSacred      = {}   -- key -> sacred|nil
local unmappedSurfaceSeen   = {}   -- key -> { surface -> true }
local healCadence           = {}   -- key -> { kind -> lastPoll }
local poisonHeal            = {}   -- key -> { guid=, until= }
local agathysCdUntil        = {}   -- key -> pollCounter deadline

Ext.Utils.Print(MOD_TAG .. " bootstrap loaded")

local function guidKey(guid) return tostring(guid) end

local function hasStatus(objectGuid, statusName)
    local r = Osi.HasActiveStatus(objectGuid, statusName)
    return r == 1 or r == true
end

local function safe(fn)
    if type(Osi) ~= "table" then return end
    local ok, err = pcall(fn)
    if not ok then
        Ext.Utils.Print(MOD_TAG .. " Osi error: " .. tostring(err))
    end
end

local function markRefreshed(guid, sacred)
    local key = guidKey(guid)
    refreshedThisTurn[key] = refreshedThisTurn[key] or {}
    refreshedThisTurn[key][sacred] = true
end

local function wasRefreshed(guid, sacred)
    local key = guidKey(guid)
    return refreshedThisTurn[key] and refreshedThisTurn[key][sacred]
end

local function isElectrifiedSurface(surfaceName)
    if not surfaceName then return false end
    return tostring(surfaceName):find("Electrified", 1, true) ~= nil
end

local function applyStatus(objectGuid, statusName, duration)
    Osi.ApplyStatus(objectGuid, statusName, duration, 1, objectGuid)
end

-- Heal "kind" once per turn (cadence) using an instant OnApply heal status.
local function periodicHeal(guid, kind, healStatus, forceNow)
    local key = guidKey(guid)
    healCadence[key] = healCadence[key] or {}
    local last = healCadence[key][kind]
    if forceNow or last == nil or (pollCounter - last) >= POLLS_PER_TURN then
        healCadence[key][kind] = pollCounter
        applyStatus(guid, healStatus, 1)
        return true
    end
    return false
end

local function stripShockStatuses(objectGuid)
    for _, s in ipairs(SHOCK_STATUS_NAMES) do
        if hasStatus(objectGuid, s) then Osi.RemoveStatus(objectGuid, s) end
    end
end

local function applyElectrifiedLightning(objectGuid)
    stripShockStatuses(objectGuid)
    applyStatus(objectGuid, "DWS_SACRED_LIGHTNING", PERSIST_DURATION)
    markRefreshed(objectGuid, "DWS_SACRED_LIGHTNING")
end

local function startOrRefreshPoison(objectGuid)
    local key = guidKey(objectGuid)
    Osi.RemoveStatus(objectGuid, "POISONED")
    applyStatus(objectGuid, "DWS_SACRED_POISON", PERSIST_DURATION)
    markRefreshed(objectGuid, "DWS_SACRED_POISON")

    local fresh = (poisonHeal[key] == nil)
    poisonHeal[key] = { guid = objectGuid, untilPoll = pollCounter + POISON_HEAL_POLLS }
    if fresh then
        periodicHeal(objectGuid, "poison", HEAL_2D4, true)
        Ext.Utils.Print(MOD_TAG .. " poison regen (3 turns) on " .. key)
    end
end

local function maybeGrantIceAgathys(objectGuid)
    local key = guidKey(objectGuid)
    if pollCounter < (agathysCdUntil[key] or 0) then return end
    applyStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS", AGATHYS_DURATION)
    agathysCdUntil[key] = pollCounter + AGATHYS_CD_POLLS
    markRefreshed(objectGuid, "DWS_SACRED_ICE_AGATHYS")
    Ext.Utils.Print(MOD_TAG .. " ice agathys granted to " .. key)
end

local function logIfChanged(guid, sacred)
    local key = guidKey(guid)
    if lastLoggedSacred[key] == sacred then return false end
    lastLoggedSacred[key] = sacred
    if sacred then
        Ext.Utils.Print(MOD_TAG .. " " .. key .. " on surface -> " .. sacred)
    else
        Ext.Utils.Print(MOD_TAG .. " " .. key .. " left mapped surface")
    end
    return true
end

local function noteUnmappedSurface(guid, surfaceName)
    local key = guidKey(guid)
    unmappedSurfaceSeen[key] = unmappedSurfaceSeen[key] or {}
    if unmappedSurfaceSeen[key][surfaceName] then return end
    unmappedSurfaceSeen[key][surfaceName] = true
    Ext.Utils.Print(MOD_TAG .. " (new unmapped surface '" ..
        tostring(surfaceName) .. "' under " .. key .. ")")
end

-- Apply the surface-specific buff while standing; drive per-turn heals.
local function applySurfaceEffect(guid, sacred, isNew)
    if sacred == "DWS_SACRED_POISON" then
        startOrRefreshPoison(guid)
        return
    end
    if sacred == "DWS_SACRED_LIGHTNING" then
        applyElectrifiedLightning(guid)
        return
    end

    applyStatus(guid, sacred, SACRED_DURATION)
    markRefreshed(guid, sacred)

    if sacred == "DWS_SACRED_FIRE" then
        periodicHeal(guid, "fire", HEAL_1D4, isNew)
    elseif sacred == "DWS_SACRED_CLEANSE_WATHER" then
        periodicHeal(guid, "water", HEAL_2D4, false)
    elseif sacred == "DWS_SACRED_ICE" then
        maybeGrantIceAgathys(guid)
    end
end

local function pollAndApplySurface(characterGuid)
    if not hasStatus(characterGuid, SACRED_MARK) then return end

    local surfaceName = Osi.GetSurfaceGroundAt(characterGuid)
    if not surfaceName or surfaceName == "" or tostring(surfaceName) == "SurfaceNone" then
        logIfChanged(characterGuid, nil)
        return
    end

    if isElectrifiedSurface(surfaceName) then
        local isNew = logIfChanged(characterGuid, "DWS_SACRED_LIGHTNING")
        applySurfaceEffect(characterGuid, "DWS_SACRED_LIGHTNING", isNew)
        return
    end

    local sacred = SurfaceGroundConversions[tostring(surfaceName)]
    if not sacred then
        noteUnmappedSurface(characterGuid, surfaceName)
        logIfChanged(characterGuid, nil)
        return
    end

    local isNew = logIfChanged(characterGuid, sacred)
    applySurfaceEffect(characterGuid, sacred, isNew)
end

local function onStatusApplied(objectGuid, statusName, _, _)
    if statusName == SACRED_MARK then
        markedCharacters[guidKey(objectGuid)] = objectGuid
        safe(function()
            if hasStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS_CD") then
                Osi.RemoveStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS_CD")
            end
            pollAndApplySurface(objectGuid)
        end)
        return
    end

    local sacred = SurfaceStatusTriggers[statusName]
    if not sacred then return end

    safe(function()
        if not hasStatus(objectGuid, SACRED_MARK) then return end

        if statusName == "WET" then
            local surfaceName = Osi.GetSurfaceGroundAt(objectGuid)
            if isElectrifiedSurface(surfaceName) then return end
        end

        Osi.RemoveStatus(objectGuid, statusName)
        local isNew = (lastLoggedSacred[guidKey(objectGuid)] ~= sacred)
        applySurfaceEffect(objectGuid, sacred, isNew)

        Ext.Utils.Print(MOD_TAG .. " " .. statusName .. " -> " .. sacred ..
            " on " .. guidKey(objectGuid))
    end)
end

local function onStatusRemoved(objectGuid, statusName, _, _)
    if statusName ~= SACRED_MARK then return end

    local key = guidKey(objectGuid)
    markedCharacters[key]    = nil
    refreshedThisTurn[key]   = nil
    lastLoggedSacred[key]    = nil
    unmappedSurfaceSeen[key] = nil
    healCadence[key]         = nil
    -- poisonHeal / agathysCdUntil intentionally kept (persist after aura exit)

    safe(function()
        for _, sacred in ipairs(ManagedSacred) do
            if hasStatus(objectGuid, sacred) then
                Osi.RemoveStatus(objectGuid, sacred)
                Ext.Utils.Print(MOD_TAG .. " aura ended -> stripped " ..
                    sacred .. " from " .. key)
            end
        end
    end)
end

local function onTurnStarted(characterGuid)
    safe(function() pollAndApplySurface(characterGuid) end)
end

local function onTurnEnded(characterGuid)
    safe(function()
        for _, sacred in ipairs(ManagedSacred) do
            if hasStatus(characterGuid, sacred)
               and not wasRefreshed(characterGuid, sacred)
               and not PersistentSacred[sacred] then
                Osi.RemoveStatus(characterGuid, sacred)
            end
        end
        refreshedThisTurn[guidKey(characterGuid)] = nil
    end)
end

local function onKilledBy(_, _, attacker, _)
    safe(function()
        if not attacker or attacker == "" then return end
        if not hasStatus(attacker, SACRED_MARK)        then return end
        if not hasStatus(attacker, "DWS_SACRED_BLOOD") then return end
        if hasStatus(attacker, "DWS_SACRED_BLOOD_CD")  then return end

        applyStatus(attacker, "DWS_SACRED_BLOOD_LUST", BLOODLUST_DURATION)
        applyStatus(attacker, "DWS_SACRED_BLOOD_CD", BLOOD_COOLDOWN)
        markRefreshed(attacker, "DWS_SACRED_BLOOD_LUST")
        markRefreshed(attacker, "DWS_SACRED_BLOOD_CD")
        Ext.Utils.Print(MOD_TAG .. " bloodlust granted to " .. guidKey(attacker))
    end)
end

local function processPoisonHeals()
    for key, info in pairs(poisonHeal) do
        if pollCounter > info.untilPoll then
            poisonHeal[key] = nil
        else
            periodicHeal(info.guid, "poison", HEAL_2D4, false)
        end
    end
end

local function surfacePollTick()
    pollCounter = pollCounter + 1
    safe(function()
        for key, guid in pairs(markedCharacters) do
            if not hasStatus(guid, SACRED_MARK) then
                markedCharacters[key]    = nil
                lastLoggedSacred[key]    = nil
                unmappedSurfaceSeen[key] = nil
                healCadence[key]         = nil
            else
                pollAndApplySurface(guid)
            end
        end
        processPoisonHeals()
    end)
    Ext.Timer.WaitFor(POLL_INTERVAL_MS, surfacePollTick)
end

local function installListeners()
    Ext.Osiris.RegisterListener("StatusApplied", 4, "after", onStatusApplied)
    Ext.Osiris.RegisterListener("StatusRemoved", 4, "after", onStatusRemoved)
    Ext.Osiris.RegisterListener("TurnStarted",   1, "after", onTurnStarted)
    Ext.Osiris.RegisterListener("TurnEnded",     1, "after", onTurnEnded)
    Ext.Osiris.RegisterListener("KilledBy",      4, "after", onKilledBy)
    Ext.Utils.Print(MOD_TAG .. " Osiris listeners installed")
end

installListeners()
Ext.Timer.WaitFor(POLL_INTERVAL_MS, surfacePollTick)
Ext.Utils.Print(MOD_TAG .. " surface poll timer armed (" .. POLL_INTERVAL_MS .. "ms)")
