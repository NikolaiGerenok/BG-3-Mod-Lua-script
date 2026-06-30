-- DanceWithSource - Sacred Ground surface dispatcher (v18)
--
-- Per bug report 2026-06-30:
--   * Heals are now TURN-DRIVEN in combat (no more mid-turn spam):
--       Fire:   instant 1d4 on entry + 1d4 at START of each turn while standing.
--       Water:  2d4 at END of each turn while standing.
--       Poison: 2d4 for 3 turns (start of turn), PERSISTS after leaving tile/aura.
--     Out of combat (no turns) heals tick from the poll timer at ~1 per 6s.
--     A monotonic-time guard prevents any double-heal of the same kind.
--   * Ice Agathys no longer spams: temp HP is not re-granted while it is still
--     active, and a 3-turn cooldown gates re-grant afterwards.
--   * Ice now grants Advantage(AllSavingThrows) (covers saves + concentration).
--   * Lightning dumps the real shock status names on entry (diagnostic) and
--     strips them, then applies the speed/immunity buff.

local MOD_TAG = "[DWS v19]"

local SACRED_MARK = "DWS_SACRED_GROUND_ZONE"
local HEAL_1D4 = "DWS_SACRED_HEAL_1D4"
local HEAL_2D4 = "DWS_SACRED_HEAL_2D4"

-- 1 BG3 turn = 6s; poll = 2s -> 3 polls per turn
local POLL_INTERVAL_MS  = 2000
local POLLS_PER_TURN     = 3
local SACRED_DURATION    = 6     -- managed surface buff, refreshed while standing
local PERSIST_DURATION   = 18    -- poison resist / lightning: 3 turns, persists
local POISON_TURNS       = 3     -- poison regen ticks
local AGATHYS_DURATION   = 18    -- temp HP buff lasts 3 turns
local AGATHYS_CD_POLLS   = 9     -- cannot re-grant for 3 turns after it expires
local BLOODLUST_DURATION = 6
local BLOOD_COOLDOWN     = 6
local HEAL_GUARD_MS      = 5500  -- min real-time gap between heals of same kind

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
    ["BURNING"]        = "DWS_SACRED_FIRE",
    ["POISONED"]       = "DWS_SACRED_POISON",
    ["WET"]            = "DWS_SACRED_CLEANSE_WATHER",
    ["SHOCKED"]        = "DWS_SACRED_LIGHTNING",
    ["ELECTROCUTED"]   = "DWS_SACRED_LIGHTNING",
    ["SHOCKED_SURFACE"] = "DWS_SACRED_LIGHTNING",
}

local SHOCK_STATUS_NAMES = {
    "SHOCKED_SURFACE", "SHOCKED", "ELECTROCUTED", "ELECTRIFIED",
    "SURFACE_ELECTROCUTED", "WET_ELECTRIFIED",
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
local lastHealMs            = {}   -- key -> { kind -> monotonicMs }
local poisonHeal            = {}   -- key -> { guid=, turnsLeft=, pollAccum= }
local agathysCdUntil        = {}   -- key -> pollCounter deadline

Ext.Utils.Print(MOD_TAG .. " bootstrap loaded")

local function guidKey(guid) return tostring(guid) end

local function hasStatus(objectGuid, statusName)
    local r = Osi.HasActiveStatus(objectGuid, statusName)
    return r == 1 or r == true
end

local function inCombat(guid)
    local r
    pcall(function() r = Osi.IsInCombat(guid) end)
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

-- Mapped sacred status for the surface the character is currently standing on.
local function currentSacredOf(guid)
    local surfaceName = Osi.GetSurfaceGroundAt(guid)
    if not surfaceName or surfaceName == "" or tostring(surfaceName) == "SurfaceNone" then
        return nil
    end
    if isElectrifiedSurface(surfaceName) then return "DWS_SACRED_LIGHTNING" end
    return SurfaceGroundConversions[tostring(surfaceName)]
end

local function applyStatus(objectGuid, statusName, duration)
    Osi.ApplyStatus(objectGuid, statusName, duration, 1, objectGuid)
end

-- DEFINITIVE check: does the GAME actually know our statuses (= stats in .pak)?
local function verifyStatsLoaded()
    if not Ext or not Ext.Stats or not Ext.Stats.Get then
        Ext.Utils.Print(MOD_TAG .. " cannot verify stats (Ext.Stats unavailable)")
        return
    end
    local required = {
        HEAL_1D4, HEAL_2D4, "DWS_SACRED_FIRE",
        "DWS_SACRED_LIGHTNING", "DWS_SACRED_OIL", "DWS_SACRED_ICE",
    }
    for _, name in ipairs(required) do
        local ok, stat = pcall(Ext.Stats.Get, name)
        if ok and stat then
            Ext.Utils.Print(MOD_TAG .. " stats OK: " .. name)
        else
            Ext.Utils.Print(MOD_TAG ..
                " !!! STATS MISSING: " .. name ..
                " -- .pak has OLD/NO stats. Re-publish + check Public/Stats in pak.")
        end
    end
end

local function hpInfo(guid)
    local cur, max
    pcall(function() cur = Osi.GetHitpoints(guid) end)
    pcall(function() max = Osi.GetMaxHitpoints(guid) end)
    return tostring(cur) .. "/" .. tostring(max)
end

-- Best-effort dump of all active statuses (diagnostic for shock names).
local function dumpStatuses(guid)
    local out = {}
    pcall(function()
        local e = Ext.Entity.Get(guid)
        local sc = e and e.StatusContainer
        if sc and sc.Statuses then
            for _, name in pairs(sc.Statuses) do
                out[#out + 1] = tostring(name)
            end
        end
    end)
    if #out == 0 then return "(none/unavailable)" end
    return table.concat(out, ", ")
end

-- Apply an instant heal status, guarded so the same kind can't fire twice
-- within HEAL_GUARD_MS (prevents mid-turn spam / turn+poll overlap).
local function isCharacter(guid)
    local r
    pcall(function() r = Osi.IsCharacter(guid) end)
    return r == 1 or r == true
end

local function tryHeal(guid, kind, healStatus)
    if not isCharacter(guid) then return false end
    local key = guidKey(guid)
    lastHealMs[key] = lastHealMs[key] or {}
    local now  = Ext.Utils.MonotonicTime()
    local last = lastHealMs[key][kind]
    if last and (now - last) < HEAL_GUARD_MS then return false end
    lastHealMs[key][kind] = now

    local before = hpInfo(guid)
    local ok, err = pcall(applyStatus, guid, healStatus, 1)
    if ok then
        Ext.Utils.Print(MOD_TAG .. " heal " .. healStatus .. " (" .. kind ..
            ") HP " .. before .. " -> " .. key)
    else
        Ext.Utils.Print(MOD_TAG .. " heal FAILED " .. healStatus .. ": " .. tostring(err))
    end
    return ok
end

local function stripShockStatuses(objectGuid)
    for _, s in ipairs(SHOCK_STATUS_NAMES) do
        if hasStatus(objectGuid, s) then Osi.RemoveStatus(objectGuid, s) end
    end
end

local function applyElectrifiedLightning(objectGuid, isNew)
    if isNew then
        Ext.Utils.Print(MOD_TAG .. " [electrified] before: " .. dumpStatuses(objectGuid))
    end
    stripShockStatuses(objectGuid)
    applyStatus(objectGuid, "DWS_SACRED_LIGHTNING", PERSIST_DURATION)
    markRefreshed(objectGuid, "DWS_SACRED_LIGHTNING")
    if isNew then
        Ext.Utils.Print(MOD_TAG .. " [electrified] lightning active=" ..
            tostring(hasStatus(objectGuid, "DWS_SACRED_LIGHTNING")) ..
            " | after: " .. dumpStatuses(objectGuid))
    end
end

local function startOrRefreshPoison(objectGuid)
    local key = guidKey(objectGuid)
    Osi.RemoveStatus(objectGuid, "POISONED")
    applyStatus(objectGuid, "DWS_SACRED_POISON", PERSIST_DURATION)
    markRefreshed(objectGuid, "DWS_SACRED_POISON")

    if poisonHeal[key] == nil then
        poisonHeal[key] = { guid = objectGuid, turnsLeft = POISON_TURNS, pollAccum = 0 }
        tryHeal(objectGuid, "poison", HEAL_2D4)        -- instant tick on step (turn 1)
        poisonHeal[key].turnsLeft = POISON_TURNS - 1
        Ext.Utils.Print(MOD_TAG .. " poison regen (" .. POISON_TURNS .. " turns) on " .. key)
    end
end

local function maybeGrantIceAgathys(objectGuid)
    local key = guidKey(objectGuid)
    if hasStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS") then return end   -- still active, don't stack/spam
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

-- Apply the surface-specific buff while standing. Periodic heals are driven by
-- turn events / the OOC poll, NOT here (fire only gets its instant entry tick).
local function applySurfaceEffect(guid, sacred, isNew)
    if sacred == "DWS_SACRED_POISON" then
        startOrRefreshPoison(guid)
        return
    end
    if sacred == "DWS_SACRED_LIGHTNING" then
        applyElectrifiedLightning(guid, isNew)
        return
    end

    applyStatus(guid, sacred, SACRED_DURATION)
    markRefreshed(guid, sacred)

    if sacred == "DWS_SACRED_FIRE" then
        if isNew then tryHeal(guid, "fire", HEAL_1D4) end
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

-- Out-of-combat periodic heals (no turn events fire outside combat).
local function oocHeals(guid)
    local key = guidKey(guid)
    local sacred = currentSacredOf(guid)
    if sacred == "DWS_SACRED_FIRE" then
        tryHeal(guid, "fire", HEAL_1D4)
    elseif sacred == "DWS_SACRED_CLEANSE_WATHER" then
        tryHeal(guid, "water", HEAL_2D4)
    end

    local info = poisonHeal[key]
    if info and info.turnsLeft > 0 then
        info.pollAccum = (info.pollAccum or 0) + 1
        if info.pollAccum >= POLLS_PER_TURN then
            info.pollAccum = 0
            tryHeal(guid, "poison", HEAL_2D4)
            info.turnsLeft = info.turnsLeft - 1
            if info.turnsLeft <= 0 then poisonHeal[key] = nil end
        end
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
    lastHealMs[key]          = nil
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
    safe(function()
        pollAndApplySurface(characterGuid)

        local key = guidKey(characterGuid)
        if currentSacredOf(characterGuid) == "DWS_SACRED_FIRE" then
            tryHeal(characterGuid, "fire", HEAL_1D4)
        end

        local info = poisonHeal[key]
        if info and info.turnsLeft > 0 then
            tryHeal(characterGuid, "poison", HEAL_2D4)
            info.turnsLeft = info.turnsLeft - 1
            if info.turnsLeft <= 0 then poisonHeal[key] = nil end
        end
    end)
end

local function onTurnEnded(characterGuid)
    safe(function()
        if currentSacredOf(characterGuid) == "DWS_SACRED_CLEANSE_WATHER" then
            tryHeal(characterGuid, "water", HEAL_2D4)
        end

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

local function surfacePollTick()
    pollCounter = pollCounter + 1
    safe(function()
        for key, guid in pairs(markedCharacters) do
            if not hasStatus(guid, SACRED_MARK) then
                markedCharacters[key]    = nil
                lastLoggedSacred[key]    = nil
                unmappedSurfaceSeen[key] = nil
                lastHealMs[key]          = nil
            else
                pollAndApplySurface(guid)
                if not inCombat(guid) then
                    oocHeals(guid)
                end
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
verifyStatsLoaded()
Ext.Timer.WaitFor(POLL_INTERVAL_MS, surfacePollTick)
Ext.Utils.Print(MOD_TAG .. " surface poll timer armed (" .. POLL_INTERVAL_MS .. "ms)")
