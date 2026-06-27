-- DanceWithSource - Sacred Ground surface dispatcher (v15)
--
-- Heal model (stats-driven, one StackId instance each -- no 3/2/1 stacks):
--   Fire:   instant 1d4 on BURNING + DWS_SACRED_REGEN_FIRE (StartTurn 1d4, refreshed on tile)
--   Water:  DWS_SACRED_REGEN_WATER (EndTurn 2d4, refreshed on tile)
--   Poison: DWS_SACRED_REGEN (StartTurn 1d4, 18s = 3 turns, refreshed while on tile)
-- Lightning: DWS_SACRED_LIGHTNING 18s haste (no AC ward), refreshed on electrified tile 

local MOD_TAG = "[DWS v15]"

local SACRED_MARK = "DWS_SACRED_GROUND_ZONE"
local HEAL_INSTANT_1D4 = "DWS_SACRED_HEAL_1D4"
local REGEN_FIRE   = "DWS_SACRED_REGEN_FIRE"
local REGEN_WATER  = "DWS_SACRED_REGEN_WATER"
local REGEN_POISON = "DWS_SACRED_REGEN"

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
    "SHOCKED",
    "ELECTROCUTED",
    "ELECTRIFIED",
    "SURFACE_ELECTROCUTED",
}

local ManagedSacred = {
    "DWS_SACRED_FIRE",
    "DWS_SACRED_POISON",
    "DWS_SACRED_CLEANSE_WATHER",
    "DWS_SACRED_OIL",
    "DWS_SACRED_ICE",
    "DWS_SACRED_BLOOD",
    "DWS_SACRED_LIGHTNING",
    "DWS_SACRED_ACID",
    "DWS_SACRED_ICE_AGATHYS",
    "DWS_SACRED_BLOOD_LUST",
    "DWS_SACRED_BLOOD_CD",
}

local TurnEndedExempt = {
    ["DWS_SACRED_ICE_AGATHYS"] = true,
    ["DWS_SACRED_BLOOD_LUST"]  = true,
    ["DWS_SACRED_BLOOD_CD"]    = true,
}

local SACRED_DURATION        = 6    -- 1 turn surface buff refresh
local LIGHTNING_DURATION     = 18   -- 3 turns haste
local POISON_REGEN_DURATION  = 18   -- 3 turns poison regen
local REGEN_TILE_DURATION    = 6    -- 1 turn, refreshed each poll while on tile
local POLL_INTERVAL_MS       = 2000
local AGATHYS_DURATION       = 30
local AGATHYS_COOLDOWN_POLLS = 15
local BLOODLUST_DURATION     = 6
local BLOOD_COOLDOWN         = 6

local pollCounter           = 0
local markedCharacters      = {}
local refreshedThisTurn     = {}
local lastLoggedSacred      = {}
local unmappedSurfaceSeen   = {}
local agathysCooldownUntil  = {}

Ext.Utils.Print(MOD_TAG .. " bootstrap loaded")

local function guidKey(guid)
    return tostring(guid)
end

local function hasStatus(objectGuid, statusName)
    local result = Osi.HasActiveStatus(objectGuid, statusName)
    return result == 1 or result == true
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

local function refreshRegenWhileOnTile(objectGuid, sacred)
    if sacred == "DWS_SACRED_FIRE" then
        applyStatus(objectGuid, REGEN_FIRE, REGEN_TILE_DURATION)
    elseif sacred == "DWS_SACRED_CLEANSE_WATHER" then
        applyStatus(objectGuid, REGEN_WATER, REGEN_TILE_DURATION)
    elseif sacred == "DWS_SACRED_POISON" then
        -- Same StackId -> one instance; re-apply resets duration to 18s
        applyStatus(objectGuid, REGEN_POISON, POISON_REGEN_DURATION)
    end
end

local function fireBurstHeal(objectGuid)
    applyStatus(objectGuid, HEAL_INSTANT_1D4, 0)
end

local function refreshSacred(objectGuid, sacred)
    applyStatus(objectGuid, sacred, SACRED_DURATION)
    markRefreshed(objectGuid, sacred)
    refreshRegenWhileOnTile(objectGuid, sacred)
end

local function stripShockStatuses(objectGuid)
    for _, statusName in ipairs(SHOCK_STATUS_NAMES) do
        if hasStatus(objectGuid, statusName) then
            Osi.RemoveStatus(objectGuid, statusName)
        end
    end
end

local function applyElectrifiedLightning(objectGuid)
    stripShockStatuses(objectGuid)
    applyStatus(objectGuid, "DWS_SACRED_LIGHTNING", LIGHTNING_DURATION)
    markRefreshed(objectGuid, "DWS_SACRED_LIGHTNING")
end

local function maybeGrantIceAgathys(objectGuid)
    local key = guidKey(objectGuid)
    if pollCounter < (agathysCooldownUntil[key] or 0) then return end

    applyStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS", AGATHYS_DURATION)
    agathysCooldownUntil[key] = pollCounter + AGATHYS_COOLDOWN_POLLS
    markRefreshed(objectGuid, "DWS_SACRED_ICE_AGATHYS")
    Ext.Utils.Print(MOD_TAG .. " ice agathys granted to " .. key)
end

local function logIfChanged(guid, sacred)
    local key = guidKey(guid)
    if lastLoggedSacred[key] == sacred then return end
    lastLoggedSacred[key] = sacred
    if sacred then
        Ext.Utils.Print(MOD_TAG .. " " .. key .. " on surface -> " .. sacred)
    else
        Ext.Utils.Print(MOD_TAG .. " " .. key .. " left mapped surface")
    end
end

local function noteUnmappedSurface(guid, surfaceName)
    local key = guidKey(guid)
    unmappedSurfaceSeen[key] = unmappedSurfaceSeen[key] or {}
    if unmappedSurfaceSeen[key][surfaceName] then return end
    unmappedSurfaceSeen[key][surfaceName] = true
    Ext.Utils.Print(
        MOD_TAG .. " (new unmapped surface '" .. tostring(surfaceName) ..
        "' under " .. key .. ")"
    )
end

local function pollAndApplySurface(characterGuid)
    if not hasStatus(characterGuid, SACRED_MARK) then return end

    local surfaceName = Osi.GetSurfaceGroundAt(characterGuid)
    if not surfaceName or surfaceName == "" or tostring(surfaceName) == "SurfaceNone" then
        local key = guidKey(characterGuid)
        local previousSacred = lastLoggedSacred[key]

        logIfChanged(characterGuid, nil)
        return
    end

    if isElectrifiedSurface(surfaceName) then
        applyElectrifiedLightning(characterGuid)
        logIfChanged(characterGuid, "DWS_SACRED_LIGHTNING")
        return
    end

    local sacred = SurfaceGroundConversions[tostring(surfaceName)]
    if not sacred then
        noteUnmappedSurface(characterGuid, surfaceName)
        logIfChanged(characterGuid, nil)
        return
    end

    logIfChanged(characterGuid, sacred)
    refreshSacred(characterGuid, sacred)

    if sacred == "DWS_SACRED_FIRE" and previousSacred ~= "DWS_SACRED_FIRE" then
        fireBurstHeal(characterGuid)

    if sacred == "DWS_SACRED_ICE" then
        maybeGrantIceAgathys(characterGuid)
    end
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

        if statusName == "BURNING" then
            local surfaceName = Osi.GetSurfaceGroundAt(objectGuid)
            local fromSurface = SurfaceGroundConversions[tostring(surfaceName)]
            if fromSurface == "DWS_SACRED_FIRE" then
                Osi.RemoveStatus(objectGuid, statusName)
                return
            end
        end

        if statusName == "WET" then
            local surfaceName = Osi.GetSurfaceGroundAt(objectGuid)
            if isElectrifiedSurface(surfaceName) then return end
        end

        Osi.RemoveStatus(objectGuid, statusName)

        if sacred == "DWS_SACRED_LIGHTNING" then
            applyElectrifiedLightning(objectGuid)
        else
            refreshSacred(objectGuid, sacred)
            if sacred == "DWS_SACRED_FIRE" then
                fireBurstHeal(objectGuid)
            end
        end

        Ext.Utils.Print(
            MOD_TAG .. " " .. statusName .. " -> " .. sacred ..
            " on " .. guidKey(objectGuid)
        )
    end)
end

local function onStatusRemoved(objectGuid, statusName, _, _)
    if statusName ~= SACRED_MARK then return end

    local key = guidKey(objectGuid)
    markedCharacters[key]     = nil
    refreshedThisTurn[key]    = nil
    lastLoggedSacred[key]     = nil
    unmappedSurfaceSeen[key]  = nil
    agathysCooldownUntil[key] = nil
    -- REGEN_POISON / REGEN_FIRE / REGEN_WATER intentionally kept after aura exit

    safe(function()
        for _, sacred in ipairs(ManagedSacred) do
            if hasStatus(objectGuid, sacred) then
                Osi.RemoveStatus(objectGuid, sacred)
                Ext.Utils.Print(
                    MOD_TAG .. " aura ended -> stripped " .. sacred ..
                    " from " .. key
                )
            end
        end
    end)
end

local function onTurnStarted(characterGuid)
    safe(function()
        pollAndApplySurface(characterGuid)
        
        if wasRefreshed(characterGuid, "DWS_SACRED_POISON") then
            applyStatus(characterGuid, REGEN_POISON, POISON_REGEN_DURATION)
        end
    end)
end

local function onTurnEnded(characterGuid)
    safe(function()
        for _, sacred in ipairs(ManagedSacred) do
            if hasStatus(characterGuid, sacred)
               and not wasRefreshed(characterGuid, sacred)
               and not TurnEndedExempt[sacred] then
                Osi.RemoveStatus(characterGuid, sacred)
                Ext.Utils.Print(
                    MOD_TAG .. " turn end off-surface -> stripped " ..
                    sacred .. " from " .. guidKey(characterGuid)
                )
            end
        end
        -- Water EndTurn tick handled by REGEN_WATER status
        if wasRefreshed(characterGuid, "DWS_SACRED_CLEANSE_WATHER") then
            applyStatus(characterGuid, REGEN_WATER, REGEN_TILE_DURATION)
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

local function surfacePollTick()
    pollCounter = pollCounter + 1
    safe(function()
        for key, guid in pairs(markedCharacters) do
            if not hasStatus(guid, SACRED_MARK) then
                markedCharacters[key]    = nil
                lastLoggedSacred[key]    = nil
                unmappedSurfaceSeen[key] = nil
            else
                pollAndApplySurface(guid)
            end
        end
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
