-- DanceWithSource - Sacred Ground surface dispatcher (v19)
-- Add cursed surface
local MOD_TAG = "[DWS v46]"

local SACRED_MARK = "DWS_SACRED_GROUND_ZONE"
local CURSED_MARK = "DWS_CURSED_GROUND_ZONE"
local HEAL_1D4    = "DWS_SACRED_HEAL_1D4"
local HEAL_2D4    = "DWS_SACRED_HEAL_2D4"
local HEAL_2D6    = "DWS_SACRED_HEAL_2D6"
local HEAL_2D8    = "DWS_SACRED_HEAL_2D8"
local AURA_CURSED = "DWS_CURSED_GROUND_ZONE_AURA"
local AURA_SACRED = "DWS_SACRED_GROUND_ZONE_AURA"

-- 1 BG3 turn = 6s; poll = 2s -> 3 polls per turn
local POLL_INTERVAL_MS     = 2000
local POLLS_PER_TURN       = 3
local SACRED_DURATION      = 6     -- managed surface buff, refreshed while standing
local PERSIST_DURATION     = 18    -- poison resist / lightning: 3 turns, persists
local POISON_TURNS         = 3     -- poison regen ticks
local AGATHYS_DURATION     = 18    -- temp HP buff lasts 3 turns
local AGATHYS_CD_POLLS     = 9     -- cannot re-grant for 3 turns after it expires
local BLOODLUST_DURATION   = 6
local BLOOD_COOLDOWN       = 6
local HEAL_GUARD_MS        = 5500  -- min real-time gap between heals of same kind
local EMPTY_POLLS_TO_LIVE  = 2
local BATTERY_CHARGE_CD_MS = 600

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

local CursedSurfaceConversions = {
    ["SurfaceFire"]               = "DWS_CURSED_FIRE",
    ["SurfaceFireBlessed"]        = "DWS_CURSED_FIRE",
    ["SurfaceFireCursed"]         = "DWS_CURSED_FIRE",
    ["SurfaceHellfire"]           = "DWS_CURSED_FIRE",
    ["SurfaceOil"]                = "DWS_CURSED_OIL",
    ["SurfaceOilCloud"]           = "DWS_CURSED_OIL",
    ["SurfaceGrease"]             = "DWS_CURSED_OIL",
    ["SurfaceGreaseCloud"]        = "DWS_CURSED_OIL",
    ["SurfaceIce"]                = "DWS_CURSED_ICE",
    ["SurfaceIceThin"]            = "DWS_CURSED_ICE",
    ["SurfaceIceCloud"]           = "DWS_CURSED_ICE",
    ["SurfaceFrozen"]             = "DWS_CURSED_ICE",
    ["SurfaceWaterFrozen"]        = "DWS_CURSED_ICE",
    ["SurfaceWaterFrozenBlessed"] = "DWS_CURSED_ICE",
    ["SurfaceWaterFrozenCursed"]  = "DWS_CURSED_ICE",
    ["SurfacePoison"]             = "DWS_CURSED_POISON",
    ["SurfacePoisonBlessed"]      = "DWS_CURSED_POISON",
    ["SurfacePoisonCursed"]       = "DWS_CURSED_POISON",
    ["SurfacePoisonCloud"]        = "DWS_CURSED_POISON",
    ["SurfaceAcid"]               = "DWS_CURSED_ACID",
    ["SurfaceAcidBlessed"]        = "DWS_CURSED_ACID",
    ["SurfaceAcidCursed"]         = "DWS_CURSED_ACID",
    ["SurfaceAcidCloud"]          = "DWS_CURSED_ACID",
    ["SurfaceWater"]              = "DWS_CURSED_WATER",
    ["SurfaceWaterBlessed"]       = "DWS_CURSED_WATER",
    ["SurfaceWaterCursed"]        = "DWS_CURSED_WATER",
    ["SurfaceWaterCloud"]         = "DWS_CURSED_WATER",
    ["SurfaceBlood"]              = "DWS_CURSED_BLOOD",
    ["SurfaceBloodSilver"]        = "DWS_CURSED_BLOOD",
    ["SurfaceBloodElectrified"]   = "DWS_CURSED_BLOOD",
    ["SurfaceBloodCloud"]         = "DWS_CURSED_BLOOD",
}

local EnchantedConversions = {
    ["DWS_SACRED_ACID"] = {
        passive  = "DWS_ENH_SACRED_ACID",
        enhanced = "DWS_SACRED_ACID_ENH",  
    },
    ["DWS_SACRED_POISON"] = {
        passive  = "DWS_ENH_SACRED_POISON",
        enhanced = "DWS_SACRED_POISON_ENH",
    },
    ["DWS_SACRED_FIRE"] = {
        passive  = "DWS_ENH_SACRED_FIRE",
        enhanced = "DWS_SACRED_FIRE_ENH",
    },
    ["DWS_SACRED_OIL"] = {
        passive  = "DWS_ENH_SACRED_OIL",
        enhanced = "DWS_SACRED_OIL_ENH",
    },
    ["DWS_SACRED_ICE"] = {
        passive  = "DWS_ENH_SACRED_ICE",
        enhanced = "DWS_SACRED_ICE_ENH",
    },
    ["DWS_SACRED_CLEANSE_WATHER"] = {
        passive  = "DWS_ENH_SACRED_WATER",
        enhanced = "DWS_SACRED_WATER_ENH",
    },
    ["DWS_CURSED_FIRE"] = {
        passive  = "DWS_ENH_CURSED_FIRE", 
        enhanced = "DWS_CURSED_FIRE_ENH",
    },
    ["DWS_CURSED_ICE"]  = {
        passive  = "DWS_ENH_CURSED_ICE",
        enhanced = "DWS_CURSED_ICE_ENH",
    },
    ["DWS_CURSED_POISON"] = {
        passive  = "DWS_ENH_CURSED_POISON",
        enhanced = "DWS_CURSED_POISON_ENH",
    },
    ["DWS_CURSED_ACID"] = {
        passive  = "DWS_ENH_CURSED_ACID",
        enhanced = "DWS_CURSED_ACID_ENH",
    },
    ["DWS_CURSED_OIL"] = {
        passive  = "DWS_ENH_CURSED_OIL",
        enhanced = "DWS_CURSED_OIL_ENH"
    },
    ["DWS_CURSED_BLOOD"] = {
        passive  = "DWS_ENH_CURSED_BLOOD",
        enhanced = "DWS_CURSED_BLOOD_ENH",
    },
    ["DWS_CURSED_WATER"] = {
        passive  = "DWS_ENH_CURSED_WATER",
        enhanced = "DWS_CURSED_WATER_ENH",
    },
    ["DWS_CURSED_LIGHTNING"] = {
        passive  = "DWS_ENH_CURSED_LIGHTNING",
        enhanced = "DWS_CURSED_LIGHTNING_ENH",
    },
}

local SurfaceStatusTriggers = {
    ["BURNING"]         = "DWS_SACRED_FIRE",
    ["POISONED"]        = "DWS_SACRED_POISON",
    ["WET"]             = "DWS_SACRED_CLEANSE_WATHER",
    ["SHOCKED"]         = "DWS_SACRED_LIGHTNING",
    ["ELECTROCUTED"]    = "DWS_SACRED_LIGHTNING",
    ["SHOCKED_SURFACE"] = "DWS_SACRED_LIGHTNING",
}

local SHOCK_STATUS_NAMES = {
    "SHOCKED_SURFACE", "SHOCKED", "ELECTROCUTED", "ELECTRIFIED",
    "SURFACE_ELECTROCUTED", "WET_ELECTRIFIED",
}

-- Stripped when leaving the aura / at turn end if not refreshed this turn.
local ManagedSacred = {
    "DWS_SACRED_FIRE",
    "DWS_SACRED_FIRE_ENH",
    "DWS_SACRED_FIRE_CLOAK_1",
    "DWS_SACRED_FIRE_CLOAK_2",
    "DWS_SACRED_FIRE_CLOAK_3",
    "DWS_SACRED_CLEANSE_WATHER",
    "DWS_SACRED_OIL",
    "DWS_SACRED_OIL_ENH",
    "DWS_SACRED_OIL_BASTION_1",
    "DWS_SACRED_OIL_BASTION_2",
    "DWS_SACRED_OIL_BASTION_3",
    "DWS_SACRED_OIL_BASTION_4",
    "DWS_SACRED_OIL_BASTION_5",
    "DWS_SACRED_OIL_BASTION_6",
    "DWS_SACRED_ICE",
    "DWS_SACRED_ICE_ENH",
    "DWS_SACRED_ACID",
    "DWS_SACRED_BLOOD",
    "DWS_CURSED_FIRE",
    "DWS_CURSED_OIL",
    "DWS_CURSED_ICE",
    "DWS_CURSED_LIGHTNING",
    "DWS_CURSED_POISON",
    "DWS_CURSED_WATER",
    "DWS_CURSED_BLOOD",
    "DWS_CURSED_FIRE_ENH",
    "DWS_CURSED_ICE_ENH",
    "DWS_CURSED_POISON_ENH",
    "DWS_CURSED_ACID", 
    "DWS_CURSED_ACID_ENH",
    "DWS_CURSED_OIL_ENH",
    "DWS_CURSED_BLOOD_ENH",
    "DWS_CURSED_WATER_ENH",
    "DWS_CURSED_LIGHTNING_ENH",
    "DWS_SACRED_ACID_ENH",
    "DWS_SACRED_ACID_ENH_1",
    "DWS_SACRED_ACID_ENH_2",
    "DWS_SACRED_ACID_ENH_3",
    "DWS_SACRED_WATER_ENH_1",
    "DWS_SACRED_WATER_ENH_2",
    "DWS_SACRED_WATER_ENH_3",
}

-- Never auto-stripped; rely on their own duration.
local PersistentSacred = {
    ["DWS_SACRED_POISON"]         = true,
    ["DWS_SACRED_POISON_ENH"]     = true,
    ["DWS_SACRED_POISON_VITAL"]   = true,
    ["DWS_SACRED_POISON_STING_1"] = true,
    ["DWS_SACRED_POISON_STING_2"] = true,
    ["DWS_SACRED_POISON_STING_3"] = true,
    ["DWS_SACRED_POISON_SURGE_1"] = true,
    ["DWS_SACRED_POISON_SURGE_2"] = true,
    ["DWS_SACRED_POISON_SURGE_3"] = true,
    ["DWS_SACRED_POISON_GRACE_1"] = true,
    ["DWS_SACRED_POISON_GRACE_2"] = true,
    ["DWS_SACRED_POISON_GRACE_3"] = true,
    ["DWS_SACRED_POISON_CRASH"]   = true,
    ["DWS_SACRED_LIGHTNING"]      = true,
    ["DWS_SACRED_ICE_AGATHYS"]    = true,
    ["DWS_SACRED_ICE_AGATHYS_1"]  = true,
    ["DWS_SACRED_ICE_AGATHYS_2"]  = true,
    ["DWS_SACRED_ICE_AGATHYS_3"]  = true,
    ["DWS_SACRED_ICE_AGATHYS_4"]  = true,
    ["DWS_SACRED_BLOOD_LUST"]     = true,
    ["DWS_SACRED_BLOOD_CD"]       = true,
    ["DWS_CURSED_BLOOD_PULSE"]    = true,
}

local DamageFormuls = {
    ["DWS_CURSED_FIRE_ENH"]     = {
        damageType = "Fire",
        dieSides = 4, 
        baseDice = 1,
        levelPerDie = 4,
    },

    ["DWS_CURSED_POISON_STACK_ENH"] = {
        damageType = "Poison",
        maxStacks = 3,
        dieSidesBase = 4,
        dieSidesPerLevels = 4,
        dieSidesStep = 2,
        dieSidesMax = 8,
    },

    ["DWS_CURSED_ACID"] = {
        damageType = "Acid",
        dieSides = 4,
        baseDice = 1,
        levelPerDie = 4,
    },

    ["DWS_CURSED_BLOOD_PULSE_ENH"] = {
        damageType = "Necrotic",
        dieSides = 6,
        baseDice = 1,
        levelPerDie = 4,
        maxDice = 3,
    },

    ["DWS_CURSED_WATER_ENH"] = {
        damageType = "Necrotic",
        dieSides = 6,
        baseDice = 1,
        levelPerDie = 4,
        maxDice = 3,
    },

    ["DWS_CURSED_LIGHTNING_ENH"] = {
        damageType = "Lightning",
        dieSides = 4, 
        baseDice = 1,
        levelPerDie = 4,
        maxDice = 3,
    },
}

local POISON_ENH_DEBUFFS = { "SLOW", "STINKING_CLOUD", "POISONED" }

local POISON_ENH_BY_STACK = {
    [3] = "SLOW",
    [2] = "STINKING_CLOUD",
    [1] = "POISONED",
}

local FIRE_CLOAKS = {
    "DWS_SACRED_FIRE_CLOAK_1",
    "DWS_SACRED_FIRE_CLOAK_2",
    "DWS_SACRED_FIRE_CLOAK_3",
}

local OIL_BASTIONS = {
  [1] = "DWS_SACRED_OIL_BASTION_1",
  [2] = "DWS_SACRED_OIL_BASTION_2",
  [3] = "DWS_SACRED_OIL_BASTION_3",
  [4] = "DWS_SACRED_OIL_BASTION_4",
  [5] = "DWS_SACRED_OIL_BASTION_5",
  [6] = "DWS_SACRED_OIL_BASTION_6",
}

local ICE_AGATHYS = {
    "DWS_SACRED_ICE_AGATHYS_1",
    "DWS_SACRED_ICE_AGATHYS_2",
    "DWS_SACRED_ICE_AGATHYS_3",
    "DWS_SACRED_ICE_AGATHYS_4",
}

local POISON_STINGS = {
    "DWS_SACRED_POISON_STING_1",
    "DWS_SACRED_POISON_STING_2",
    "DWS_SACRED_POISON_STING_3",
}
local POISON_SURGES = {
    "DWS_SACRED_POISON_SURGE_1",
    "DWS_SACRED_POISON_SURGE_2",
    "DWS_SACRED_POISON_SURGE_3",
}
local POISON_GRACES = {
    "DWS_SACRED_POISON_GRACE_1",
    "DWS_SACRED_POISON_GRACE_2",
    "DWS_SACRED_POISON_GRACE_3",
}

local ACID_ENHS = {
    "DWS_SACRED_ACID_ENH_1",
    "DWS_SACRED_ACID_ENH_2",
    "DWS_SACRED_ACID_ENH_3",
}

local WATER_SACRED_BASE = "DWS_SACRED_CLEANSE_WATHER"
local WATER_ENH_PASSIVE = "DWS_ENH_SACRED_WATER"
local WATER_ENHS = {
    "DWS_SACRED_WATER_ENH_1",
    "DWS_SACRED_WATER_ENH_2",
    "DWS_SACRED_WATER_ENH_3",
}
local WATER_CLEANSE_SAVE_DC = 13
local WATER_RINSE_OK   = "DWS_SACRED_WATER_RINSE_OK"
local WATER_RINSE_FAIL = "DWS_SACRED_WATER_RINSE_FAIL"
local SACRED_WATER_BUFF_DURATION = 12   -- ~2 turns; refreshed while on tile

local WATER_CLEANSE_TIER1 = {
    "BLINDED", "FRIGHTENED", "SLOWED", "SILENCED", "MUTE", "RESTRAINED", "ENWEBBED", "ENTANGLED", "ENSNARED",
}
local WATER_CLEANSE_TIER2 = {
    "BURNING", "POISONED", "BLEEDING", "ACID", "FROSTBITTEN", "MAG_FROST",
}
local WATER_CLEANSE_TIER3 = {
    "BANE", "HEX", "HAG_RIDDEN", "REELING", "DAZED", "RADIATING_ORB",
}
local SACRED_ACID_CORRODE_LEGACY = "DWS_SACRED_ACID_CORRODE"
local SACRED_ACID_WARD_LEGACY = "DWS_SACRED_ACID_WARD"
local SACRED_ACID_CORRODE_TIERS = {
    "DWS_SACRED_ACID_CORRODE_1", "DWS_SACRED_ACID_CORRODE_2", "DWS_SACRED_ACID_CORRODE_3",
    "DWS_SACRED_ACID_CORRODE_4", "DWS_SACRED_ACID_CORRODE_5", "DWS_SACRED_ACID_CORRODE_6",
}
local SACRED_ACID_WARD_TIERS = {
    "DWS_SACRED_ACID_WARD_1", "DWS_SACRED_ACID_WARD_2", "DWS_SACRED_ACID_WARD_3",
    "DWS_SACRED_ACID_WARD_4", "DWS_SACRED_ACID_WARD_5", "DWS_SACRED_ACID_WARD_6",
}
local SACRED_ACID_CORRODE_CAP = 6
local SACRED_ACID_WARD_CAP = 6

local ACID_STACK_STATUS = "DWS_CURSED_ACID_STACK"
local ACID_ONHIT_COOLDOWN_MS = 600
local acidHitBusy = {}       -- swingKey / echoKey -> locked
local acidHitLastMs = {}     -- swingKey -> last proc ms
local acidHitLastAction = {} -- swingKey -> storyActionID
local batteryChargeLastMs = {}  -- dKey -> last ms

local pollCounter           = 0
local markedCharacters      = {}   -- key -> guid
local refreshedThisTurn     = {}   -- key -> { sacred -> true }
local lastLoggedSacred      = {}   -- key -> sacred|nil
local emptySurfacePolls     = {}   -- key -> poll empty
local unmappedSurfaceSeen   = {}   -- key -> { surface -> true }
local lastHealMs            = {}   -- key -> { kind -> monotonicMs }
local poisonHeal            = {}   -- key -> { guid=, turnsLeft=, pollAccum= }
local agathysCdUntil        = {}   -- key -> pollCounter deadline
local cursedBloodMarked     = {}   -- guidKey -> true, while standing in the cursed blood
local zoneOwner             = {}   -- victimKey -> casterGuid
local auraCaster            = {}   -- summonKey -> playerGuid
local poisonOwner           = {}   -- victimKey -> casterGuid
local acidStealLastSwing    = {}   -- swingKey -> storyActionID (one steal proc per action)
local sacredAcidCorrodeStacks = {} -- defenderKey -> stack count (1..6)
local sacredAcidWardStacks    = {} -- attackerKey -> stack count
local sacredAcidTierBusy    = false -- suppress StatusRemoved while swapping tiers
local waterCleansePending   = {}   -- key -> true: failed end-turn rinse save, remove 1 at next turn start
local waterBuffStatMissing  = {}   -- statusName -> true if Ext.Stats says stat absent (.pak)
local waterOocTurnPolls     = {}   -- key -> poll count toward virtual turn (realtime, no TurnEnded)
local tryHeal               -- forward declaration; defined after applyStatus / hpInfo

Ext.Utils.Print(MOD_TAG .. " bootstrap loaded")

local function guidKey(guid)
    local s = tostring(guid or "")
    local uuid = s:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)")
    return uuid or s
end

local function hasStatus(objectGuid, statusName)
    local r = Osi.HasActiveStatus(objectGuid, statusName)
    return r == 1 or r == true
end

local function hasPassive(guid,passiveName)
    local r = Osi.HasPassive(guid,passiveName)
    return r == 1 or r == true
end

local function sacredAcidEnhForLevel(level)
    local tier = math.min(3, math.max(1, math.ceil((level or 1) / 4)))
    return ACID_ENHS[tier]
end

local function hasSacredAcidEnh(guid)
    for _, name in ipairs(ACID_ENHS) do
        if hasStatus(guid, name) then
            return true
        end
    end
    return false
end

-- Steal works while standing on acid ENH, or anywhere in the zone if acid enhancement is unlocked.
local function hasSacredAcidStealPrivilege(aGuid)
    if hasSacredAcidEnh(aGuid) then return true end
    if not hasStatus(aGuid, SACRED_MARK) then return false end
    local caster = zoneOwner[guidKey(aGuid)] or aGuid
    local entry = EnchantedConversions["DWS_SACRED_ACID"]
    return entry ~= nil and hasPassive(caster, entry.passive)
end

-- Must be before isStandingOnSacredWater (Lua locals are not visible above their definition).
local function isElectrifiedSurface(surfaceName)
    if not surfaceName then return false end
    return tostring(surfaceName):find("Electrified", 1, true) ~= nil
end

local function currentSacredOf(guid)
    local surfaceName = Osi.GetSurfaceGroundAt(guid)
    if not surfaceName or surfaceName == "" or tostring(surfaceName) == "SurfaceNone" then
        return nil
    end
    if isElectrifiedSurface(surfaceName) then return "DWS_SACRED_LIGHTNING" end
    return SurfaceGroundConversions[tostring(surfaceName)]
end

local function sacredWaterEnhForLevel(level)
    local tier = math.min(3, math.max(1, math.ceil((level or 1) / 4)))
    return WATER_ENHS[tier]
end

local function hasSacredWaterBuff(guid)
    if hasStatus(guid, WATER_SACRED_BASE) then return true end
    for _, name in ipairs(WATER_ENHS) do
        if hasStatus(guid, name) then return true end
    end
    return false
end

local function wasOnSacredWaterThisTurn(guid)
    local r = refreshedThisTurn[guidKey(guid)]
    if not r then return false end
    if r[WATER_SACRED_BASE] then return true end
    for _, name in ipairs(WATER_ENHS) do
        if r[name] then return true end
    end
    return false
end

local function isInSacredWaterZone(guid)
    if not hasStatus(guid, SACRED_MARK) then return false end
    if currentSacredOf(guid) == WATER_SACRED_BASE then return true end
    return wasOnSacredWaterThisTurn(guid)
end

-- Legacy name: effects use zone tile + sacred mark (buff may lag one frame or fail UI).
local function isStandingOnSacredWater(guid)
    return isInSacredWaterZone(guid)
end

local function sacredWaterCleanseLayerCount(casterLevel, hasWaterEnh)
    if not hasWaterEnh then return 1 end
    local lvl = casterLevel or 1
    if lvl >= 9 then return 3 end
    if lvl >= 6 then return 2 end
    return 1
end

local function sacredWaterCleanseLists(layerCount)
    local out = {}
    if layerCount >= 3 then out[#out + 1] = WATER_CLEANSE_TIER1 end
    if layerCount >= 2 then out[#out + 1] = WATER_CLEANSE_TIER2 end
    out[#out + 1] = WATER_CLEANSE_TIER3
    return out
end

local function removeOneWaterCleanse(guid, layerCount)
    for _, list in ipairs(sacredWaterCleanseLists(layerCount)) do
        for _, statusName in ipairs(list) do
            if hasStatus(guid, statusName) then
                Osi.RemoveStatus(guid, statusName)
                return statusName
            end
        end
    end
    return nil
end

local function removeAllWaterCleanseInPool(guid, layerCount)
    local n = 0
    for _, list in ipairs(sacredWaterCleanseLists(layerCount)) do
        for _, statusName in ipairs(list) do
            if hasStatus(guid, statusName) then
                Osi.RemoveStatus(guid, statusName)
                n = n + 1
            end
        end
    end
    return n
end

local function constitutionModifier(guid)
    local score = Osi.GetAbility(guid, "Constitution")
    if type(score) ~= "number" then return 0 end
    return math.floor((score - 10) / 2)
end

local function constitutionSaveProficiency(guid)
    local level = Osi.GetLevel(guid) or 1
    local pb = 2 + math.floor((level - 1) / 4)
    local prof = 0
    pcall(function()
        local ent = Ext.Entity.Get(guid)
        local stats = ent and ent.Stats
        if not stats then return end
        if stats.SavingThrows and stats.SavingThrows.Constitution then
            prof = pb
            return
        end
        if stats.SavingThrowProficiency and stats.SavingThrowProficiency.Constitution then
            prof = pb
        end
    end)
    return prof
end

-- BG3 Osiris has no RollSavingThrow; use d20 + CON (Entity prof when available).
local function rollWaterCleanseSave(guid)
    local mod = constitutionModifier(guid)
    local prof = constitutionSaveProficiency(guid)
    local d20 = Ext.Utils.Random(1, 20)
    local total = d20 + mod + prof
    local success = total >= WATER_CLEANSE_SAVE_DC
    Ext.Utils.Print(MOD_TAG .. " water CON save roll d20=" .. tostring(d20)
        .. " mod=" .. tostring(mod) .. " prof=" .. tostring(prof)
        .. " total=" .. tostring(total) .. " vs DC" .. tostring(WATER_CLEANSE_SAVE_DC)
        .. " => " .. (success and "SUCCESS" or "FAIL") .. " on " .. guidKey(guid))
    return success
end

local function sacredWaterHealStatus(casterLevel, hasWaterEnh)
    if not hasWaterEnh then return HEAL_2D4 end
    local tier = math.min(3, math.max(1, math.ceil((casterLevel or 1) / 4)))
    if tier == 1 then return HEAL_2D4 end
    if tier == 2 then return HEAL_2D6 end
    return HEAL_2D8
end

local function sacredWaterCleanseContext(guid)
    local caster = zoneOwner[guidKey(guid)] or guid
    local level = Osi.GetLevel(caster) or 1
    local hasEnh = hasPassive(caster, WATER_ENH_PASSIVE)
    local layers = sacredWaterCleanseLayerCount(level, hasEnh)
    return level, hasEnh, layers
end

local function applySacredWaterRinseFromStat(guid, success)
    if not isInSacredWaterZone(guid) and not wasOnSacredWaterThisTurn(guid) then return end
    local _, _, layers = sacredWaterCleanseContext(guid)
    local key = guidKey(guid)
    if success then
        local n = removeAllWaterCleanseInPool(guid, layers)
        waterCleansePending[key] = nil
        Ext.Utils.Print(MOD_TAG .. " water buff rinse OK cleared=" .. tostring(n) .. " on " .. key)
    else
        waterCleansePending[key] = true
        Ext.Utils.Print(MOD_TAG .. " water buff rinse fail -> pending on " .. key)
    end
end

local function sacredWaterOnEnterCleanse(guid)
    if not isInSacredWaterZone(guid) then return end
    local _, _, layers = sacredWaterCleanseContext(guid)
    local removed = removeOneWaterCleanse(guid, layers)
    if removed then
        Ext.Utils.Print(MOD_TAG .. " water enter cleanse -1 " .. removed .. " on " .. guidKey(guid))
    else
        Ext.Utils.Print(MOD_TAG .. " water enter cleanse (no debuff in pool) layers="
            .. tostring(layers) .. " on " .. guidKey(guid))
    end
end

local function sacredWaterRinseCon(guid, contextLabel)
    local key = guidKey(guid)
    if not isStandingOnSacredWater(guid) then
        waterCleansePending[key] = nil
        if hasStatus(guid, SACRED_MARK) or markedCharacters[key] then
            Ext.Utils.Print(MOD_TAG .. " water " .. contextLabel .. " skip (not on water) tile="
                .. tostring(currentSacredOf(guid))
                .. " refreshedWater=" .. tostring(wasOnSacredWaterThisTurn(guid))
                .. " on " .. key)
        end
        return false
    end
    if hasSacredWaterBuff(guid) then
        Ext.Utils.Print(MOD_TAG .. " water " .. contextLabel
            .. " CON on buff EndTurn tick (TooltipSave); Lua roll skipped on " .. key)
        return true
    end
    Ext.Utils.Print(MOD_TAG .. " water " .. contextLabel .. " rinse (CON DC "
        .. tostring(WATER_CLEANSE_SAVE_DC) .. " Lua fallback) on " .. key)
    local _, _, layers = sacredWaterCleanseContext(guid)
    if rollWaterCleanseSave(guid) then
        local n = removeAllWaterCleanseInPool(guid, layers)
        waterCleansePending[key] = nil
        Ext.Utils.Print(MOD_TAG .. " water rinse save OK cleared=" .. tostring(n) .. " on " .. key)
    else
        waterCleansePending[key] = true
        Ext.Utils.Print(MOD_TAG .. " water rinse save fail pending " .. key)
    end
    return true
end

local function trySacredWaterTurnEnd(guid)
    local level, hasEnh, _ = sacredWaterCleanseContext(guid)
    if sacredWaterRinseCon(guid, "turn-end") then
        tryHeal(guid, "water", sacredWaterHealStatus(level, hasEnh))
    end
end

local function trySacredWaterTurnStartPending(guid)
    local key = guidKey(guid)
    if not waterCleansePending[key] then return end
    if not isStandingOnSacredWater(guid) then
        waterCleansePending[key] = nil
        return
    end
    local _, _, layers = sacredWaterCleanseContext(guid)
    local removed = removeOneWaterCleanse(guid, layers)
    waterCleansePending[key] = nil
    if removed then
        Ext.Utils.Print(MOD_TAG .. " water pending cleanse -1 " .. removed .. " on " .. key)
    end
end

local function previousEnchanced(guid,baseStatus) 
    local entry = EnchantedConversions[baseStatus]
    if entry == nil then
        return baseStatus
    end

    local caster = zoneOwner[guidKey(guid)] or guid
    if hasPassive(caster, entry.passive) then
        if baseStatus == "DWS_SACRED_ACID" then
            return sacredAcidEnhForLevel(Osi.GetLevel(caster) or 1)
        end
        if baseStatus == WATER_SACRED_BASE then
            return sacredWaterEnhForLevel(Osi.GetLevel(caster) or 1)
        end
        return entry.enhanced
    end
    return baseStatus
end

local function inCombat(guid)
    local r
    pcall(function() r = Osi.IsInCombat(guid) end)
    return r == 1 or r == true
end

-- Turn-based exploration has no combat, but still has turns — don't use realtime poll heals there.
local function inTurnBasedMode(guid)
    local r
    pcall(function() r = Osi.IsInForceTurnBasedMode(guid) end)
    return r == 1 or r == true
end

local function safe(fn)
    if type(Osi) ~= "table" then return end
    local ok, err = pcall(fn)
    if not ok then
        Ext.Utils.Print(MOD_TAG .. " Osi error: " .. tostring(err))
    end
end

local function getActiveZoneMark(guid)
    if hasStatus(guid, CURSED_MARK) then
        return CURSED_MARK, CursedSurfaceConversions
    end
    if hasStatus(guid, SACRED_MARK) then
        return SACRED_MARK, SurfaceGroundConversions
    end
    return nil, nil
end

local function hasAnyZoneMark(guid)
    return hasStatus(guid, SACRED_MARK) or hasStatus(guid, CURSED_MARK)
end

local function markRefreshed(guid, sacred)
    local key = guidKey(guid)
    refreshedThisTurn[key] = refreshedThisTurn[key] or {}
    refreshedThisTurn[key][sacred] = true
end

local function markSacredWaterPollRefresh(guid, statusName)
    markRefreshed(guid, statusName)
    markRefreshed(guid, WATER_SACRED_BASE)
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

local function noteMaybeLeftSurface(guid)
    local key = guidKey(guid)
    emptySurfacePolls[key] = (emptySurfacePolls[key] or 0) + 1
    if emptySurfacePolls[key] >= EMPTY_POLLS_TO_LIVE then
        logIfChanged(guid,nil)
    end
end

local function notStillOnSurface(guid)
    emptySurfacePolls[guidKey(guid)] = 0
end

local function wasRefreshed(guid, sacred)
    local key = guidKey(guid)
    return refreshedThisTurn[key] and refreshedThisTurn[key][sacred]
end

local function applyStatus(objectGuid, statusName, duration)
    Osi.ApplyStatus(objectGuid, statusName, duration, 1, objectGuid)
end

local function readStatusStacks(objectGuid, statusName)
    local turns = Osi.GetStatusTurns(objectGuid,statusName)
    if type(turns) == "number" and turns >= 1 then
        return math.floor(turns)
    end
    local life = Osi.GetStatusCurrentLifetime(objectGuid,statusName)
    if type(life) == "number" and life > 0 then
       return math.ceil(life / 6)
    end
    return 0
end

local function applyLayer(guid, list, want, durationTurns)
    for _, name in ipairs(list) do
        if name ~= want and hasStatus(guid, name) then
            Osi.RemoveStatus(guid, name)
        end
    end
    if want then
        applyStatus(guid, want, durationTurns or 1)
    end
end

local function clearMappedStatuses(objectGuid,statussesBystack)
    for _, statusName in pairs(statussesBystack) do
        if hasStatus(objectGuid, statusName) then
            Osi.RemoveStatus(objectGuid, statusName)
        end
    end
end

local function syncMappedStatuses(objectGuid,stackStatus,statussesBystack,effectDuration,debugName)

    local stacks = readStatusStacks(objectGuid,stackStatus)
    local wantedStatus = statussesBystack[stacks]
    Ext.Utils.Print( MOD_TAG .. " " .. debugName .. " sync stacks=" .. tostring(stacks) .. " want=" .. tostring(wantedStatus))
   
    for _, statusName in ipairs(statussesBystack) do
        if statusName ~= wantedStatus and hasStatus(objectGuid, statusName) then
            Osi.RemoveStatus(objectGuid, statusName)
        end
    end

    if  wantedStatus and not hasStatus(objectGuid, wantedStatus) then
        applyStatus(objectGuid, wantedStatus, effectDuration)
    end
end

local function syncSacredPoisonVital(guid)
    local caster = zoneOwner[guidKey(guid)] or guid
    local level = Osi.GetLevel(caster) or 1
    local stacks = readStatusStacks(guid, "DWS_SACRED_POISON_VITAL")
    local tier = math.min(3, math.max(1, math.ceil(level / 4)))

    if stacks < 1 then
        applyLayer(guid, POISON_STINGS, nil)
        applyLayer(guid, POISON_SURGES, nil)
        applyLayer(guid, POISON_GRACES, nil)
        return
    end

    local dur = stacks
    applyLayer(guid, POISON_STINGS, POISON_STINGS[tier], dur)
    applyLayer(guid, POISON_SURGES, stacks >= 2 and POISON_SURGES[tier] or nil, dur)
    applyLayer(guid, POISON_GRACES, stacks >= 3 and POISON_GRACES[tier] or nil, dur)
    Ext.Utils.Print(MOD_TAG .. " poison vital sync stacks=" .. tostring(stacks)
        .. " tier=" .. tostring(tier)
        .. " sting=" .. tostring(POISON_STINGS[tier])
        .. " on " .. guidKey(guid))
end

local function verifyStatsLoaded()
    if not Ext or not Ext.Stats or not Ext.Stats.Get then
        Ext.Utils.Print(MOD_TAG .. " cannot verify stats (Ext.Stats unavailable)")
        return
    end
    local required = {
        HEAL_1D4, HEAL_2D4, "DWS_SACRED_FIRE",
        "DWS_SACRED_FIRE_CLOAK_1", "DWS_SACRED_FIRE_CLOAK_2", "DWS_SACRED_FIRE_CLOAK_3",
        "DWS_SACRED_LIGHTNING", "DWS_SACRED_OIL", "DWS_SACRED_ICE",
        "DWS_SACRED_POISON_ENH", "DWS_SACRED_POISON_VITAL",
        "DWS_SACRED_POISON_STING_1", "DWS_SACRED_POISON_SURGE_1",
        "DWS_SACRED_POISON_GRACE_1", "DWS_SACRED_POISON_CRASH",
    }
    for _, name in ipairs(required) do
        local ok, stat = pcall(Ext.Stats.Get, name)
        if ok and stat then
            Ext.Utils.Print(MOD_TAG .. " stats OK: " .. name)
        else
            Ext.Utils.Print(MOD_TAG ..
                " !!! STATS MISSING: " .. name ..
                " -- .pak has OLD/NO stats. Re-publish + check Public/Stats in pak.")
            if name == WATER_SACRED_BASE
                or name == "DWS_SACRED_WATER_ENH_1"
                or name == "DWS_SACRED_WATER_ENH_2"
                or name == "DWS_SACRED_WATER_ENH_3" then
                waterBuffStatMissing[name] = true
            end
        end
    end
    for _, name in ipairs({
        WATER_SACRED_BASE,
        "DWS_SACRED_WATER_ENH_1",
        "DWS_SACRED_WATER_ENH_2",
        "DWS_SACRED_WATER_ENH_3",
        HEAL_2D6,
        HEAL_2D8,
        WATER_RINSE_OK,
        WATER_RINSE_FAIL,
    }) do
        if not waterBuffStatMissing[name] then
            local ok, stat = pcall(Ext.Stats.Get, name)
            if ok and stat then
                Ext.Utils.Print(MOD_TAG .. " stats OK: " .. name)
            else
                waterBuffStatMissing[name] = true
                Ext.Utils.Print(MOD_TAG ..
                    " !!! STATS MISSING: " .. name ..
                    " -- water buff/heal tier may not ApplyStatus. Re-publish mod.")
            end
        end
    end
    local okSting, sting = pcall(Ext.Stats.Get, "DWS_SACRED_POISON_STING_2")
    if okSting and sting and sting.Boosts then
        Ext.Utils.Print(MOD_TAG .. " STING_2 Boosts=" .. tostring(sting.Boosts))
    end
end

local function hpInfo(guid)
    local cur, max
    pcall(function() cur = Osi.GetHitpoints(guid) end)
    pcall(function() max = Osi.GetMaxHitpoints(guid) end)
    return tostring(cur) .. "/" .. tostring(max)
end

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

local function isCharacter(guid)
    local r
    pcall(function() r = Osi.IsCharacter(guid) end)
    return r == 1 or r == true
end

local function rollDice(count,sides)
    local total = 0
    for _ = 1, count do
        total = total + Ext.Utils.Random(1,sides)
    end
    return total
end

local function diceCount(level,cfg)
    return cfg.baseDice + math.floor(level / cfg.levelPerDie)
end

tryHeal = function(guid, kind, healStatus)
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

local function getTemporaryHp(guid)
    local ent = Ext.Entity.Get(guid)
    if not ent or not ent.Health then return 0 end
    return ent.Health.TemporaryHp or 0
end

local function hasTemporaryHp(guid)
    return getTemporaryHp(guid) > 0
end

local function stripShockStatuses(objectGuid)
    for _, s in ipairs(SHOCK_STATUS_NAMES) do
        if hasStatus(objectGuid, s) then Osi.RemoveStatus(objectGuid, s) end
    end
end

local function tryBattaryCharge(defender,damageType,damageAmount)
    if damageType ~= "Lightning" then return end
    if type(damageAmount) == "number" and damageAmount <= 0 then return end
    if hasStatus(defender,"DWS_CURSED_BATTERY_CD") then return end
    if not hasStatus(defender,"DWS_CURSED_BATTERY") and not hasStatus(defender,"DWS_CURSED_LIGHTNING_ENH") then return end
    local dKey = guidKey(defender)
    local now = Ext.Utils.MonotonicTime()
    local caster = zoneOwner[dKey] or defender
    if batteryChargeLastMs[dKey] and (now - batteryChargeLastMs[dKey]) < BATTERY_CHARGE_CD_MS then
        return
    end
    batteryChargeLastMs[dKey] = now

    local stack = readStatusStacks(defender,"DWS_CURSED_BATTERY")
    stack = stack + 1
    if stack >= 5 then
        Osi.RemoveStatus(defender,"DWS_CURSED_BATTERY")
        Osi.ApplyStatus(defender,"STUNNED",6,1,caster)
        Osi.ApplyStatus(defender,"DWS_CURSED_BATTERY_CD",12,1,caster)
        Ext.Utils.Print(MOD_TAG .. " battery OVERLOAD stun+CD on " .. dKey)
        return
    end
    Osi.ApplyStatus(defender,"DWS_CURSED_BATTERY",stack * 6,1,caster)
    Ext.Utils.Print(MOD_TAG .. " battery charge=" .. tostring(stack) .. " on " .. dKey)
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

local function startOrRefreshPoison(objectGuid, isNew)
    local key = guidKey(objectGuid)
    Osi.RemoveStatus(objectGuid, "POISONED")
    local status = previousEnchanced(objectGuid, "DWS_SACRED_POISON")

    applyStatus(objectGuid, status, PERSIST_DURATION)
    markRefreshed(objectGuid, status)

    if isNew and poisonHeal[key] == nil then
        poisonHeal[key] = { guid = objectGuid, turnsLeft = POISON_TURNS, pollAccum = 0 }
        tryHeal(objectGuid, "poison", HEAL_2D4)        -- instant tick on step (turn 1)
        poisonHeal[key].turnsLeft = POISON_TURNS - 1
        Ext.Utils.Print(MOD_TAG .. " poison regen (" .. POISON_TURNS .. " turns) on " .. key)
    end

    -- Safety net if STING expired before FreezeDuration fix / was stripped.
    if status == "DWS_SACRED_POISON_ENH" and hasStatus(objectGuid, "DWS_SACRED_POISON_VITAL") then
        local hasSting = false
        for _, n in ipairs(POISON_STINGS) do
            if hasStatus(objectGuid, n) then hasSting = true; break end
        end
        if not hasSting then
            syncSacredPoisonVital(objectGuid)
        end
    end
end

local function sacredFireCloakForLevel(level)
    local tier = math.min(3, 1 + math.floor((level or 1) / 6))
    return FIRE_CLOAKS[tier]
end

local function sacredOilBastionForLevel(level)
    local tier = math.min(6, math.max(1, math.ceil((level or 1) / 2)))
    return OIL_BASTIONS[tier]
end

local function sacredIceAgathysForLevel(level)
    local tier = math.min(4, math.max(1, math.ceil((level or 1) / 3)))
    return ICE_AGATHYS[tier]
end

local SACRED_TIER_EFFECTS = {
    ["DWS_SACRED_FIRE"] = {
        enhanced = "DWS_SACRED_FIRE_ENH",
        tiers = FIRE_CLOAKS,
        statusForLevel = sacredFireCloakForLevel,
        duration = 12,
        logTag = "sacred fire cloak",
    },
    ["DWS_SACRED_OIL"] = {
        enhanced = "DWS_SACRED_OIL_ENH",
        tiers = OIL_BASTIONS,
        statusForLevel = sacredOilBastionForLevel,
        duration = SACRED_DURATION,
        logTag = "sacred oil bastion",
    },
}

local function clearTierStatuses(guid, tiers)
    for _, name in ipairs(tiers) do
        if hasStatus(guid, name) then
            Osi.RemoveStatus(guid, name)
        end
    end
end

local function applySacredTierStatus(guid, tiers, statusForLevel, duration, logTag)
    local caster = zoneOwner[guidKey(guid)] or guid
    local level = Osi.GetLevel(caster) or 1
    local want = statusForLevel(level)

    for _, name in ipairs(tiers) do
        if name ~= want and hasStatus(guid, name) then
            Osi.RemoveStatus(guid, name)
        end
    end

    if hasStatus(guid, want) then
        markRefreshed(guid, want)
    else
        applyStatus(guid, want, duration)
        markRefreshed(guid, want)
        Ext.Utils.Print(MOD_TAG .. " " .. logTag .. " -> " .. want
            .. " lvl=" .. tostring(level) .. " on " .. guidKey(guid))
    end
end

local function refreshSacredTierEffect(guid, sacred, status)
    local cfg = SACRED_TIER_EFFECTS[sacred]
    if not cfg then return end

    if status == cfg.enhanced then
        applySacredTierStatus(
            guid,
            cfg.tiers,
            cfg.statusForLevel,
            cfg.duration,
            cfg.logTag
        )
    else
        clearTierStatuses(guid, cfg.tiers)
    end
end

local function hasAnyIceAgathys(guid)
    if hasStatus(guid, "DWS_SACRED_ICE_AGATHYS") then return true end
    for _, name in ipairs(ICE_AGATHYS) do
        if hasStatus(guid, name) then return true end
    end
    return false
end

local function clearIceAgathys(guid)
    if hasStatus(guid, "DWS_SACRED_ICE_AGATHYS") then
        Osi.RemoveStatus(guid, "DWS_SACRED_ICE_AGATHYS")
    end
    clearTierStatuses(guid, ICE_AGATHYS)
end

local function clearAgathysIfNoTempHp(guid)
    if getTemporaryHp(guid) > 0 then return end
    if not hasAnyIceAgathys(guid) then return end
    clearIceAgathys(guid)
    Ext.Utils.Print(MOD_TAG .. " ice agathys stripped (tempHP=0) on " .. guidKey(guid))
end

local function maybeGrantIceAgathys(objectGuid, enhOverride)
    local key = guidKey(objectGuid)
    local enh = enhOverride
    if enh == nil then
        enh = hasStatus(objectGuid, "DWS_SACRED_ICE_ENH")
    end
    local want = enh
        and sacredIceAgathysForLevel(Osi.GetLevel(zoneOwner[key] or objectGuid) or 1)
        or "DWS_SACRED_ICE_AGATHYS"

    if hasStatus(objectGuid, want) then return end

    local upgrading = enh and hasAnyIceAgathys(objectGuid)
        and not hasStatus(objectGuid, want)
    if not upgrading and hasAnyIceAgathys(objectGuid) then return end
    if not upgrading and pollCounter < (agathysCdUntil[key] or 0) then return end

    if upgrading then
        clearIceAgathys(objectGuid)
    end



    applyStatus(objectGuid, want, AGATHYS_DURATION)
    agathysCdUntil[key] = pollCounter + AGATHYS_CD_POLLS
    Ext.Utils.Print(MOD_TAG .. " ice agathys granted -> " .. want .. " on " .. key)
end

local function noteUnmappedSurface(guid, surfaceName)
    local key = guidKey(guid)
    unmappedSurfaceSeen[key] = unmappedSurfaceSeen[key] or {}
    if unmappedSurfaceSeen[key][surfaceName] then return end
    unmappedSurfaceSeen[key][surfaceName] = true
    Ext.Utils.Print(MOD_TAG .. " (new unmapped surface '" ..
        tostring(surfaceName) .. "' under " .. key .. ")")
end

local function applySurfaceEffect(guid, sacred, isNew)
    local status = previousEnchanced(guid, sacred)
    
    if sacred == "DWS_SACRED_POISON" then
        startOrRefreshPoison(guid, isNew)
        return
    end

    if sacred == "DWS_SACRED_LIGHTNING" then
        applyElectrifiedLightning(guid, isNew)
        return
    end

    if sacred == "DWS_SACRED_ACID" then
        if status ~= "DWS_SACRED_ACID" and hasStatus(guid, "DWS_SACRED_ACID") then
            Osi.RemoveStatus(guid, "DWS_SACRED_ACID")
        end
        for _, name in ipairs(ACID_ENHS) do
            if name ~= status and hasStatus(guid, name) then
                Osi.RemoveStatus(guid, name)
            end
        end
    end

    if sacred == WATER_SACRED_BASE then
        if status ~= WATER_SACRED_BASE and hasStatus(guid, WATER_SACRED_BASE) then
            Osi.RemoveStatus(guid, WATER_SACRED_BASE)
        end
        for _, name in ipairs(WATER_ENHS) do
            if name ~= status and hasStatus(guid, name) then
                Osi.RemoveStatus(guid, name)
            end
        end
    end

    if waterBuffStatMissing[status] then
        Ext.Utils.Print(MOD_TAG .. " water stat was missing at boot; still trying ApplyStatus " .. status)
    end

    if hasStatus(guid, status) then
        if sacred == WATER_SACRED_BASE then
            markSacredWaterPollRefresh(guid, status)
        else
            markRefreshed(guid, status)
        end
        if sacred == "DWS_CURSED_BLOOD" then
            local key = guidKey(guid)
            cursedBloodMarked[key] = {
                enh = (status == "DWS_CURSED_BLOOD_ENH"),
                caster = zoneOwner[key] or guid,
            }
        end
        refreshSacredTierEffect(guid, sacred, status)
        if sacred == "DWS_SACRED_ICE" then
            maybeGrantIceAgathys(guid, status == "DWS_SACRED_ICE_ENH")
        end
        if sacred == WATER_SACRED_BASE and isNew then
            sacredWaterOnEnterCleanse(guid)
        end
        return
    end

    if sacred == "DWS_CURSED_BLOOD" then
        local key = guidKey(guid)
        cursedBloodMarked[key] = {
            enh = (status == "DWS_CURSED_BLOOD_ENH"),
            caster = zoneOwner[key] or guid,
        }
    end

    local buffDuration = (sacred == WATER_SACRED_BASE) and SACRED_WATER_BUFF_DURATION or SACRED_DURATION
    applyStatus(guid, status, buffDuration)
    if sacred == WATER_SACRED_BASE then
        markSacredWaterPollRefresh(guid, status)
    else
        markRefreshed(guid, status)
    end
    refreshSacredTierEffect(guid, sacred, status)
    if sacred == WATER_SACRED_BASE then
        local statLoaded = false
        pcall(function()
            if Ext.Stats.Get(status) then statLoaded = true end
        end)
        Ext.Utils.Print(MOD_TAG .. " water buff apply " .. status
            .. " active=" .. tostring(hasStatus(guid, status))
            .. " statLoaded=" .. tostring(statLoaded)
            .. " on " .. guidKey(guid))
    end

    if status == "DWS_CURSED_OIL_ENH" and not hasStatus(guid, "DWS_CLUMSY") then
        local caster = zoneOwner[guidKey(guid)] or guid
        local level = Osi.GetLevel(caster) or 1
        local stack = 2 + math.floor(level / 4)
        Osi.ApplyStatus(guid, "DWS_CLUMSY", stack * 6, 1, caster)
        Ext.Utils.Print(MOD_TAG .. " oil ENH -> CLUMSY turns=" .. tostring(stack)
            .. " on " .. guidKey(guid))
    end

    if sacred == "DWS_SACRED_FIRE" then
        if isNew then tryHeal(guid, "fire", HEAL_1D4) end
    elseif sacred == WATER_SACRED_BASE then
        if isNew then sacredWaterOnEnterCleanse(guid) end
    elseif sacred == "DWS_SACRED_ICE" then
        maybeGrantIceAgathys(guid, status == "DWS_SACRED_ICE_ENH")
    end
end

local function pollAndApplySurface(characterGuid)
    local mark, conversions = getActiveZoneMark(characterGuid)
    if not mark then return end

    local surfaceName = Osi.GetSurfaceGroundAt(characterGuid)
    if not surfaceName or surfaceName == "" or tostring(surfaceName) == "SurfaceNone" then
        noteMaybeLeftSurface(characterGuid)
        return
    end

    if isElectrifiedSurface(surfaceName) then
        notStillOnSurface(characterGuid)
        local lightning = (conversions == SurfaceGroundConversions) 
            and "DWS_SACRED_LIGHTNING"
            or "DWS_CURSED_LIGHTNING"
        local isNew = logIfChanged(characterGuid, lightning)
        applySurfaceEffect(characterGuid, lightning, isNew)
        return
    end

    local effect = conversions[tostring(surfaceName)]
    if not effect then
        noteUnmappedSurface(characterGuid, surfaceName)
        noteMaybeLeftSurface(characterGuid)
        return
    end

    notStillOnSurface(characterGuid)
    local isNew = logIfChanged(characterGuid, effect)
    applySurfaceEffect(characterGuid, effect, isNew)
end

local function oocHeals(guid)
    -- Combat / force turn-based: heals only on TurnEnded / TurnStarted hooks.
    if inTurnBasedMode(guid) then return end

    local key = guidKey(guid)
    local sacred = currentSacredOf(guid)
    if sacred == "DWS_SACRED_FIRE" then
        tryHeal(guid, "fire", HEAL_1D4)
    end
    -- Sacred water: trySacredWaterTurnEnd on TurnEnded, TB TurnStarted, or OOC virtual turn poll.

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

local function onStatusApplied(objectGuid, statusName, causeGuid, _)
    if statusName == AURA_CURSED or statusName == AURA_SACRED then
        auraCaster[guidKey(objectGuid)] = causeGuid
        Ext.Utils.Print(MOD_TAG .. " aura on " .. guidKey(objectGuid) .. " caster=" .. tostring(causeGuid))
        return
    end

    if statusName == WATER_RINSE_OK or statusName == WATER_RINSE_FAIL then
        safe(function()
            Osi.RemoveStatus(objectGuid, statusName)
            applySacredWaterRinseFromStat(objectGuid, statusName == WATER_RINSE_OK)
        end)
        return
    end
    
    if statusName == SACRED_MARK or statusName == CURSED_MARK then
        local caster = auraCaster[guidKey(causeGuid)] or causeGuid
        markedCharacters[guidKey(objectGuid)] = objectGuid
        zoneOwner[guidKey(objectGuid)] = caster
        Ext.Utils.Print(MOD_TAG .. " mark on " .. guidKey(objectGuid) .. " zoneOwner=" .. tostring(caster))
        safe(function()
            if hasStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS_CD") then
                Osi.RemoveStatus(objectGuid, "DWS_SACRED_ICE_AGATHYS_CD")
            end
            pollAndApplySurface(objectGuid)
        end)
        return
    end

    if statusName == "DWS_CURSED_POISON_STACK_ENH" then
        local key = guidKey(objectGuid)
        poisonOwner[key] = zoneOwner[key] or poisonOwner[key] or causeGuid
        safe(function()
            syncMappedStatuses(objectGuid,"DWS_CURSED_POISON_STACK_ENH",POISON_ENH_BY_STACK,6,"poison ENH")
        end)
        return
    end

    if statusName == "DWS_SACRED_POISON_VITAL" then
        safe(function()
            syncSacredPoisonVital(objectGuid)
        end)
        return
    end

    if statusName == "DWS_CURSED_POISON_ENH_HIT" then
        safe(function()
            Osi.RemoveStatus(objectGuid, "DWS_CURSED_POISON_ENH_HIT")
            if not hasStatus(objectGuid, "DWS_CURSED_POISON_STACK_ENH") then return end
            local stacks = readStatusStacks(objectGuid,"DWS_CURSED_POISON_STACK_ENH")
            if stacks < 1 or stacks > 3 then
                Ext.Utils.Print(MOD_TAG .. " poison ENH HIT skipped bad stacks=" .. tostring(stacks))
                return
            end

            local cfg = DamageFormuls["DWS_CURSED_POISON_STACK_ENH"]
            local key = guidKey(objectGuid)
            local caster = poisonOwner[key] or zoneOwner[key] or objectGuid
            local level = Osi.GetLevel(caster) or 1
            local diceCount = cfg.maxStacks - stacks + 1
            local sides = math.min(cfg.dieSidesMax, cfg.dieSidesBase + cfg.dieSidesStep * math.floor(level / cfg.dieSidesPerLevels))
            local amount = rollDice(diceCount, sides)

            Osi.ApplyDamage(objectGuid, amount, cfg.damageType, caster)
            syncMappedStatuses(objectGuid,"DWS_CURSED_POISON_STACK_ENH",POISON_ENH_BY_STACK,6,"poison ENH")
            Ext.Utils.Print(MOD_TAG .. " poison ENH fail hit "
                .. tostring(diceCount) .. "d" .. tostring(sides)
                .. "=" .. tostring(amount) .. " stacks=" .. tostring(stacks))
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

local function stripLegacySacredAcidStatus(guid)
    if hasStatus(guid, SACRED_ACID_CORRODE_LEGACY) then
        Osi.RemoveStatus(guid, SACRED_ACID_CORRODE_LEGACY)
    end
    if hasStatus(guid, SACRED_ACID_WARD_LEGACY) then
        Osi.RemoveStatus(guid, SACRED_ACID_WARD_LEGACY)
    end
end

local function inferSacredAcidStacksFromTiers(guid, tierList, legacyName)
    for i = #tierList, 1, -1 do
        if hasStatus(guid, tierList[i]) then
            return i
        end
    end
    if legacyName and hasStatus(guid, legacyName) then
        return 1
    end
    return 0
end

local function currentSacredAcidStacks(guid, tierList, legacyName, trackTable)
    local key = guidKey(guid)
    local inferred = inferSacredAcidStacksFromTiers(guid, tierList, legacyName)
    local tracked = trackTable[key]
    local stacks = math.max(inferred, type(tracked) == "number" and tracked or 0)
    if stacks >= 1 then
        trackTable[key] = stacks
    elseif trackTable[key] then
        trackTable[key] = nil
    end
    return stacks
end

local function sacredAcidDurationTurns(stacks)
    return math.max(1, stacks) * 6
end

local function applySacredAcidStackStatus(targetGuid, tierList, legacyName, stacks, sourceGuid, trackTable)
    stacks = math.min(#tierList, math.max(1, stacks))
    local want = tierList[stacks]
    sacredAcidTierBusy = true
    stripLegacySacredAcidStatus(targetGuid)
    for _, name in ipairs(tierList) do
        if name ~= want and hasStatus(targetGuid, name) then
            Osi.RemoveStatus(targetGuid, name)
        end
    end
    if hasStatus(targetGuid, want) then
        Osi.RemoveStatus(targetGuid, want)
    end
    -- Osiris duration is seconds (6 = 1 turn). Stacks = turns remaining in UI; decay via Lua on TurnEnded.
    Osi.ApplyStatus(targetGuid, want, sacredAcidDurationTurns(stacks), 1, sourceGuid)
    trackTable[guidKey(targetGuid)] = stacks
    sacredAcidTierBusy = false
end

local function clearSacredAcidTiers(guid, tierList, legacyName, trackTable)
    sacredAcidTierBusy = true
    stripLegacySacredAcidStatus(guid)
    for _, name in ipairs(tierList) do
        if hasStatus(guid, name) then
            Osi.RemoveStatus(guid, name)
        end
    end
    trackTable[guidKey(guid)] = nil
    sacredAcidTierBusy = false
end

local function decaySacredAcidStacksOnTurnEnd(characterGuid)
    local key = guidKey(characterGuid)

    local c = sacredAcidCorrodeStacks[key]
    if not c or c < 1 then
        c = inferSacredAcidStacksFromTiers(characterGuid, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY)
    end
    if c >= 1 then
        local nextC = c - 1
        if nextC < 1 then
            clearSacredAcidTiers(characterGuid, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY, sacredAcidCorrodeStacks)
        else
            applySacredAcidStackStatus(characterGuid, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY,
                nextC, characterGuid, sacredAcidCorrodeStacks)
        end
    end

    local w = sacredAcidWardStacks[key]
    if not w or w < 1 then
        w = inferSacredAcidStacksFromTiers(characterGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY)
    end
    if w >= 1 then
        local nextW = w - 1
        if nextW < 1 then
            clearSacredAcidTiers(characterGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY, sacredAcidWardStacks)
        else
            applySacredAcidStackStatus(characterGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY,
                nextW, characterGuid, sacredAcidWardStacks)
        end
    end
end

local function trySacredAcidSteal(defender, aGuid, storyActionID)
    if not aGuid or aGuid == "" then return end
    if not hasSacredAcidStealPrivilege(aGuid) then return end

    local aKey = guidKey(aGuid)
    local dKey = guidKey(defender)
    local swingKey = aKey .. ">" .. dKey

    if storyActionID ~= nil and acidStealLastSwing[swingKey] == storyActionID then
        return
    end

    local c = currentSacredAcidStacks(defender, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY, sacredAcidCorrodeStacks)
    local w = currentSacredAcidStacks(aGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY, sacredAcidWardStacks)
    local canCorrode = c < SACRED_ACID_CORRODE_CAP
    local canWard = w < SACRED_ACID_WARD_CAP
    if not canCorrode and not canWard then
        return
    end

    local changed = false
    if canCorrode then
        c = c + 1
        applySacredAcidStackStatus(defender, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY, c, aGuid, sacredAcidCorrodeStacks)
        changed = true
    end
    if canWard then
        w = w + 1
        applySacredAcidStackStatus(aGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY, w, aGuid, sacredAcidWardStacks)
        changed = true
    end
    if not changed then return end

    if storyActionID ~= nil then
        acidStealLastSwing[swingKey] = storyActionID
    end
    Ext.Utils.Print(MOD_TAG .. " sacred acid steal corrode=" .. tostring(c) .. " ward=" .. tostring(w)
        .. " " .. aKey .. " -> " .. dKey)
end

local function onStatusRemoved(objectGuid, statusName, _, _)
    if statusName == "DWS_CURSED_POISON_STACK_ENH" then
        poisonOwner[guidKey(objectGuid)] = nil
        safe(function()
            clearMappedStatuses(objectGuid, POISON_ENH_BY_STACK)
        end)
        return
    end

    if statusName == "DWS_SACRED_POISON_VITAL" then 
        safe(function()
            clearMappedStatuses(objectGuid, POISON_STINGS)
            clearMappedStatuses(objectGuid, POISON_SURGES)
            clearMappedStatuses(objectGuid, POISON_GRACES)
            applyStatus(objectGuid, "DWS_SACRED_POISON_CRASH", 1)
        end)
        return
    end

    if statusName == SACRED_ACID_CORRODE_LEGACY or statusName == SACRED_ACID_WARD_LEGACY then
        return
    end
    for _, tier in ipairs(SACRED_ACID_CORRODE_TIERS) do
        if statusName == tier then
            if sacredAcidTierBusy then return end
            local key = guidKey(objectGuid)
            local inferred = inferSacredAcidStacksFromTiers(objectGuid, SACRED_ACID_CORRODE_TIERS, SACRED_ACID_CORRODE_LEGACY)
            if inferred >= 1 then
                sacredAcidCorrodeStacks[key] = inferred
            else
                sacredAcidCorrodeStacks[key] = nil
            end
            return
        end
    end
    for _, tier in ipairs(SACRED_ACID_WARD_TIERS) do
        if statusName == tier then
            if sacredAcidTierBusy then return end
            local key = guidKey(objectGuid)
            local inferred = inferSacredAcidStacksFromTiers(objectGuid, SACRED_ACID_WARD_TIERS, SACRED_ACID_WARD_LEGACY)
            if inferred >= 1 then
                sacredAcidWardStacks[key] = inferred
            else
                sacredAcidWardStacks[key] = nil
            end
            return
        end
    end

    if statusName ~= SACRED_MARK and statusName ~= CURSED_MARK then return end

    local key = guidKey(objectGuid)
    markedCharacters[key]    = nil
    refreshedThisTurn[key]   = nil
    lastLoggedSacred[key]    = nil
    unmappedSurfaceSeen[key] = nil
    lastHealMs[key]          = nil
    zoneOwner[key] = nil

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
    local key = guidKey(characterGuid)
    if markedCharacters[key] or hasStatus(characterGuid, SACRED_MARK) then
        Ext.Utils.Print(MOD_TAG .. " TurnStarted " .. key
            .. " combat=" .. tostring(inCombat(characterGuid))
            .. " forceTB=" .. tostring(inTurnBasedMode(characterGuid))
            .. " tile=" .. tostring(currentSacredOf(characterGuid))
            .. " refreshedWater=" .. tostring(wasOnSacredWaterThisTurn(characterGuid)))
    end

    safe(function()
        trySacredWaterTurnStartPending(characterGuid)
    end)

    -- TB exploration: TurnEnded often never fires; rinse at start of next turn (= end of last).
    safe(function()
        if inCombat(characterGuid) then return end
        if not inTurnBasedMode(characterGuid) then return end
        local level, hasEnh = sacredWaterCleanseContext(characterGuid)
        if sacredWaterRinseCon(characterGuid, "TB-explore-turn-start") then
            tryHeal(characterGuid, "water", sacredWaterHealStatus(level, hasEnh))
        end
    end)

    -- VITAL layers must refresh even after leaving the zone mark.
    if hasStatus(characterGuid, "DWS_SACRED_POISON_VITAL") then
        safe(function()
            syncSacredPoisonVital(characterGuid)
        end)
    end

    if not hasAnyZoneMark( characterGuid) then return end

    safe(function()
        local caster = zoneOwner[guidKey(characterGuid)] or characterGuid
        local level = Osi.GetLevel(caster) or 1
        local cfg = DamageFormuls["DWS_CURSED_FIRE_ENH"]
        local cursedAcidCfg = DamageFormuls["DWS_CURSED_ACID"]
        local dice = cfg.baseDice + math.floor(level / cfg.levelPerDie)
        local cursedAcidDice = cursedAcidCfg.baseDice + math.floor(level / cursedAcidCfg.levelPerDie)

        pollAndApplySurface(characterGuid)
        if hasStatus(characterGuid,"DWS_CURSED_ACID_ENH") then
            local amount = rollDice(cursedAcidDice,cursedAcidCfg.dieSides)
            Osi.ApplyDamage(characterGuid,amount,cursedAcidCfg.damageType,caster)
            Ext.Utils.Print(MOD_TAG .. " acid ENH tick " .. tostring(cursedAcidDice)
                .. "d" .. tostring(cursedAcidCfg.dieSides) .. "=" .. tostring(amount))
        end

        if hasStatus(characterGuid,"DWS_CURSED_FIRE_ENH") then
            local amount = rollDice(dice, cfg.dieSides)
            Osi.ApplyDamage(characterGuid, amount, cfg.damageType, caster)
            Ext.Utils.Print(MOD_TAG .. " fire ENH tick " .. tostring(dice) .. "d4 = " .. tostring(amount))
        end

        if hasStatus(characterGuid, "DWS_CURSED_WATER_ENH") then
            local waterCfg = DamageFormuls["DWS_CURSED_WATER_ENH"]
            local waterDice = math.min(waterCfg.maxDice, waterCfg.baseDice + math.floor(level / waterCfg.levelPerDie))
            local amount = rollDice(waterDice, waterCfg.dieSides)
            Osi.ApplyDamage(characterGuid, amount, waterCfg.damageType, caster)
            Ext.Utils.Print(MOD_TAG .. " water ENH tick " .. tostring(waterDice)
                .. "d6=" .. tostring(amount)
                .. " lvl=" .. tostring(level) .. " caster=" .. guidKey(caster))
        end
    
        if hasStatus(characterGuid, "DWS_CURSED_ICE_ENH") then 
            local stacks = 2 + math.floor(level / 6)
                Osi.ApplyStatus(characterGuid, "DWS_CURSED_ICE_STACK", stacks * 6, 1, caster)
                Ext.Utils.Print(MOD_TAG .. " ice ENH tick " .. tostring(stacks)
                    .. " after=" .. tostring(hasStatus(characterGuid, "DWS_CURSED_ICE_STACK")))
        end

        if hasStatus(characterGuid,"DWS_CURSED_OIL_ENH") and not hasStatus(characterGuid,"DWS_CLUMSY") then
            local stack = 2 + math.floor(level / 4)
            Osi.ApplyStatus(characterGuid, "DWS_CLUMSY", stack * 6, 1, caster)
            Ext.Utils.Print(MOD_TAG .. " oil ENH turn -> CLUMSY turns=" .. tostring(stack)
                .. " on " .. guidKey(characterGuid))
        end

        if hasStatus(characterGuid,"DWS_CURSED_LIGHTNING_ENH") then
            local LightningCfg = DamageFormuls["DWS_CURSED_LIGHTNING_ENH"]
            local boltDice = math.min(LightningCfg.maxDice, LightningCfg.baseDice + math.floor(level / LightningCfg.levelPerDie))
            local amount = rollDice(boltDice, LightningCfg.dieSides)
            Osi.ApplyDamage(characterGuid, amount, LightningCfg.damageType, caster)
            
            tryBattaryCharge(characterGuid, "Lightning", amount)
            Ext.Utils.Print(MOD_TAG .. " lightning ENH tick " .. tostring(boltDice)
                .. "d4=" .. tostring(amount))
        elseif hasStatus(characterGuid, "DWS_CURSED_LIGHTNING")
            and hasStatus(characterGuid, "DWS_CURSED_BATTERY") then
            
            tryBattaryCharge(characterGuid, "Lightning", 1)
        end

    
        if not hasStatus(characterGuid,SACRED_MARK) then return end

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

local function onAttackedBy(defender, attackerOwner, attacker, damageType, damageAmount, _damageCause, storyActionID)
    if type(damageAmount) == "number" and damageAmount <= 0 then return end

    clearAgathysIfNoTempHp(defender)
    tryBattaryCharge(defender, damageType, damageAmount)

    local aGuid = attacker
    if not aGuid or aGuid == "" then aGuid = attackerOwner end

    safe(function()
        trySacredAcidSteal(defender, aGuid, storyActionID)
    end)

    if damageType == "Acid" then return end
    if damageType == "Lightning" then return end

    local dKey = guidKey(defender)
    local aKey = guidKey(aGuid)
    local sKey = aKey .. ">" .. dKey
    local echoKey = "echo:" .. dKey

    if acidHitBusy[sKey] or acidHitBusy[echoKey] then return end

    local now = Ext.Utils.MonotonicTime()
    if acidHitLastMs[sKey] and (now - acidHitLastMs[sKey]) < ACID_ONHIT_COOLDOWN_MS then return end
    if storyActionID ~= nil and acidHitLastAction[sKey] == storyActionID then return end

    if not hasStatus(defender, ACID_STACK_STATUS) then return end
    if readStatusStacks(defender, ACID_STACK_STATUS) < 1 then return end

    local source = aGuid
    if not source or source == "" then
        source = zoneOwner[dKey] or defender
    end
    local caster = zoneOwner[dKey] or source
    local cfg = DamageFormuls["DWS_CURSED_ACID"]
    local level = Osi.GetLevel(caster) or 1
    local dice = diceCount(level, cfg)

    acidHitBusy[sKey] = true
    acidHitBusy[echoKey] = true
    acidHitLastMs[sKey] = now
    if storyActionID ~= nil then
        acidHitLastAction[sKey] = storyActionID
    end

    local amount = rollDice(dice, cfg.dieSides)
    pcall(function()
        Osi.ApplyDamage(defender, amount, cfg.damageType, source)
    end)
    Ext.Utils.Print(MOD_TAG .. " acid STACK on-hit lvl=" .. tostring(level)
        .. " " .. tostring(dice) .. "d" .. tostring(cfg.dieSides)
        .. "=" .. tostring(amount) .. " on " .. dKey)

    Ext.Timer.WaitFor(ACID_ONHIT_COOLDOWN_MS, function()
        acidHitBusy[sKey] = nil
        acidHitBusy[echoKey] = nil
    end)
end

local function onTurnEnded(characterGuid)
    local key = guidKey(characterGuid)
    if markedCharacters[key] or hasStatus(characterGuid, SACRED_MARK) then
        Ext.Utils.Print(MOD_TAG .. " TurnEnded " .. key
            .. " combat=" .. tostring(inCombat(characterGuid))
            .. " turnBased=" .. tostring(inTurnBasedMode(characterGuid))
            .. " tile=" .. tostring(currentSacredOf(characterGuid)))
    end

    safe(function()
        decaySacredAcidStacksOnTurnEnd(characterGuid)
    end)

    safe(function()
        -- TB exploration: CON rinse on TurnStarted; avoid double rinse here.
        if inCombat(characterGuid) or not inTurnBasedMode(characterGuid) then
            trySacredWaterTurnEnd(characterGuid)
        end
    end)

    if not hasAnyZoneMark(characterGuid) then return end
    safe(function()
        if not hasStatus(characterGuid,SACRED_MARK) then return end

        for _, sacred in ipairs(ManagedSacred) do
            if hasStatus(characterGuid, sacred)
            and not wasRefreshed(characterGuid, sacred)
            and not PersistentSacred[sacred] then
                Osi.RemoveStatus(characterGuid, sacred)
            end
            if sacred == "DWS_CURSED_BLOOD" then
                cursedBloodMarked[guidKey(characterGuid)] = nil
            end
        end
        refreshedThisTurn[guidKey(characterGuid)] = nil
    end)
end

local function onKilledBy(victim, _, attacker, _)
    Ext.Utils.Print(MOD_TAG .. " KilledBy fired victim=" .. guidKey(victim))
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

    safe(function()
        if not victim or victim == "" then return end
        local vKey = guidKey(victim)
        local markInfo = cursedBloodMarked[vKey]
        if not markInfo then
            Ext.Utils.Print(MOD_TAG .. "cursed blood skip (not in table)")
            return
        end

        local enh = type(markInfo) == "table" and markInfo.enh
        local caster = (type(markInfo) == "table" and markInfo.caster) or victim
        Ext.Utils.Print(MOD_TAG .. "cursed blood wave triggered enh=" .. tostring(enh))

        for key, guid in pairs(markedCharacters) do
            if guidKey(guid) ~= vKey and hasStatus(guid, CURSED_MARK) then
                if enh then
                    local cfg = DamageFormuls["DWS_CURSED_BLOOD_PULSE_ENH"]
                    local level = Osi.GetLevel(caster) or 1
                    local dice = math.min(cfg.maxDice, cfg.baseDice + math.floor(level / cfg.levelPerDie))
                    local amount = rollDice(dice, cfg.dieSides)
                    Osi.ApplyDamage(guid, amount, cfg.damageType, caster)
                    Osi.ApplyStatus(guid, "BLEEDING", 12, 1, caster)
                    Osi.ApplyStatus(guid, "BANE", 12, 1, caster)
                    Ext.Utils.Print(MOD_TAG .. " blood pulse ENH "
                        .. tostring(dice) .. "d6=" .. tostring(amount)
                        .. " +bleed+bane -> " .. guidKey(guid))
                else
                    applyStatus(guid, "DWS_CURSED_BLOOD_PULSE", 1)
                    Ext.Utils.Print(MOD_TAG .. " blood pulse -> " .. guidKey(guid))
                end
            end
        end

        cursedBloodMarked[vKey] = nil
    end)
end

local function surfacePollTick()
    pollCounter = pollCounter + 1
    safe(function()
        for key, guid in pairs(markedCharacters) do
            if not hasAnyZoneMark(guid) then
                markedCharacters[key]    = nil
                lastLoggedSacred[key]    = nil
                unmappedSurfaceSeen[key] = nil
                lastHealMs[key]          = nil
            else
                pollAndApplySurface(guid)
                if not inCombat(guid) and hasStatus(guid,SACRED_MARK) then
                    oocHeals(guid)
                    if not inTurnBasedMode(guid) and isStandingOnSacredWater(guid) then
                        waterOocTurnPolls[key] = (waterOocTurnPolls[key] or 0) + 1
                        if waterOocTurnPolls[key] >= POLLS_PER_TURN then
                            waterOocTurnPolls[key] = 0
                            trySacredWaterTurnStartPending(guid)
                            trySacredWaterTurnEnd(guid)
                        end
                    else
                        waterOocTurnPolls[key] = nil
                    end
                else
                    waterOocTurnPolls[key] = nil
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
    Ext.Osiris.RegisterListener("AttackedBy",    7, "after", onAttackedBy)
    Ext.Utils.Print(MOD_TAG .. " Osiris listeners installed")
end

installListeners()
verifyStatsLoaded()
Ext.Timer.WaitFor(POLL_INTERVAL_MS, surfacePollTick)
Ext.Utils.Print(MOD_TAG .. " surface poll timer armed (" .. POLL_INTERVAL_MS .. "ms)")
