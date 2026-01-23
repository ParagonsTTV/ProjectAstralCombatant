-- Project: Astral Combatant (Paragon Arena Coach)
-- Made by Paragøn with assistance from Perplexity
-- Licensed under the MIT License

local ADDON_NAME = ...

-- Globals for UI bits so we can reference them across the file
PAC_ListFrame      = nil
PAC_HistoryFrame   = nil
PAC_MeterFrame     = nil
PAC_BreakdownFrame = nil

UpdateHistory = function() end
UpdateMeter   = function() end

local selectedRoundForBreakdown = nil
local PAC_BreakdownMode = "damage"  -- "damage", "healing", "control"
local PAC_BreakdownPlayer = nil     -- GUID or nil for "you"
local pac_CreatorIdentity = "Paragøn-Tichondrius"

-- =========================================
-- UI skin helper
-- =========================================

function PAC_ApplyPanelSkin(frame)
    if not frame then return end
    if frame.SetBackdrop then
        local theme = PAC_GetTheme()
        frame:SetBackdrop({
            bgFile   = "Interface\\FrameGeneral\\UI-Background-Marble",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile     = true, tileSize = 16, edgeSize = 12,
            insets   = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(0, 0, 0, 0.85)
        frame:SetBackdropBorderColor(theme.border.r, theme.border.g, theme.border.b, 1)
    end
end

-- =========================================
-- Helpers
-- =========================================

-- Shorten big numbers for on-frame display (87K, 450K, 2.3M)
local function PAC_AbbrevNumber(value)
    if not value then
        return "0"
    end

    local abs = math.abs(value)
    if abs >= 1000000000 then
        return string.format("%.1fB", value / 1000000000)
    elseif abs >= 1000000 then
        return string.format("%.1fM", value / 1000000)
    elseif abs >= 100000 then
        return string.format("%.0fK", value / 1000)
    elseif abs >= 1000 then
        return string.format("%.1fK", value / 1000)
    else
        return tostring(value)
    end
end

-- Mini meter view mode for Coach: "stats" (Offense/Sustain/Taken) or "cc" (Control)
PAC_METER_MODE = "stats"

local miniMeterTicker = nil

function PAC_SetMeterMode(mode)
    if mode ~= "stats" and mode ~= "cc" then
        mode = "stats"
    end

    PAC_METER_MODE = mode
    UpdateMeter()
end

local function PAC_StartMiniMeterTicker()
    if not C_Timer or not C_Timer.NewTicker then
        return
    end
    if miniMeterTicker then
        return
    end

    miniMeterTicker = C_Timer.NewTicker(0.5, function()
        if currentRound and currentRound.stats then
            UpdateMeter()
        end
    end)
end

    -- Clear meter text on new round
    if PAC_MeterFrame and PAC_MeterFrame.text then
        PAC_MeterFrame.text:SetText("PAC Live – " .. (mode or "?"))
    end

local function PACStopMiniMeterTicker()
    if miniMeterTicker then
        miniMeterTicker:Cancel()
        miniMeterTicker = nil
    end
end

-- PvP-relevant CC categories (for Control view and breakdown)
local PAC_TrackedCC = {
    -- Paladin (all specs)
    ["Hammer of Justice"] = "stun",
    ["Repentance"]        = "incap",
    ["Blinding Light"]    = "disorient",
    ["Shield of Virtue"]  = "silence",
    -- Mage (all specs)
    ["Polymorph"]         = "incap",
    ["Ring of Frost"]     = "root",
    -- Rogue (all specs)
    ["Sap"]               = "incap",
    ["Gouge"]             = "incap",
    ["Cheap Shot"]        = "stun",
    ["Kidney Shot"]       = "stun",
    -- Shaman (all specs)
    ["Hex"]               = "incap",
    ["Capacitor Totem"]   = "stun",
    -- Priest (all specs)
    ["Psychic Scream"]    = "disorient",
    ["Mind Control"]      = "incap",
    ["Chastise"]          = "stun",
    -- Hunter (all specs)
    ["Freezing Trap"]     = "incap",
    ["Intimidation"]      = "stun",
    ["Scatter Shot"]      = "disorient",
    ["Binding Shot"]      = "root",
    -- Warlock (all specs)
    ["Fear"]              = "disorient",
    ["Howl of Terror"]    = "disorient",
    ["Mortal Coil"]       = "horror",
    ["Shadowfury"]        = "stun",
    -- Warrior (all specs)
    ["Storm Bolt"]        = "stun",
    ["Shockwave"]         = "stun",
    ["Intimidating Shout"]= "disorient",
    -- Death Knight (all specs)
    ["Asphyxiate"]        = "stun",
    ["Blinding Sleet"]    = "disorient",
    -- Evoker (all specs)
    ["Sleep Walk"]        = "incap",
    ["Landslide"]         = "root",
    -- Druid (all specs)
    -- Cyclone, Mighty Bash etc. can be added later
}

local function PAC_GetCCCategory(spellName)
    return spellName and PAC_TrackedCC[spellName] or nil
end

-- =========================================
-- Config / debug flags
-- =========================================

-- Verbose logging toggle (kept off by default for performance)
local pacDebugVerbose = true

-- Show one-time load message in chat
local pacShowLoadMessage = true

local function PAC_Debug(msg)
    if not ParagonArenaCoachDB or not ParagonArenaCoachDB.debugEnabled then return end
    if not msg then return end
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[PAC]|r " .. tostring(msg))
    end
end

local function PAC_GetPlayerClassColor()
    local _, class = UnitClass("player")
    if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    -- Fallback neutral blue-ish for safety
    return 0.2, 0.6, 1.0
end

-- =========================================
-- Theme layer (class/race/faction-friendly)
-- =========================================

local PAC_Themes = {
    PALADIN = {
        BloodElf = {
            main    = { r = 0.78, g = 0.12, b = 0.24 }, -- deep red
            accent  = { r = 0.95, g = 0.80, b = 0.30 }, -- gold
            border  = { r = 0.80, g = 0.10, b = 0.10 }, -- darker red
        },
        Human = {
            main    = { r = 0.16, g = 0.32, b = 0.80 }, -- royal blue
            accent  = { r = 0.90, g = 0.78, b = 0.30 }, -- gold
            border  = { r = 0.20, g = 0.35, b = 0.80 }, -- deeper blue
        },
    },
}

function PAC_GetTheme()
    local _, class = UnitClass("player")
    local raceToken = select(2, UnitRace("player"))
    class = class or ""
    raceToken = raceToken or ""

    local classThemes = PAC_Themes[class] or {}
    local theme = classThemes[raceToken]

    if theme then
        return theme
    end

    -- Fallback: use generic class color with neutral border
    local r, g, b = PAC_GetPlayerClassColor()
    return {
        main   = { r = r, g = g, b = b },
        accent = { r = r, g = g, b = b },
        border = { r = 0.8, g = 0.8, b = 0.8 },
    }
end

-- =========================================
-- Saved variables and state
-- =========================================

ParagonArenaCoachDB = ParagonArenaCoachDB or {}
ParagonArenaCoachDB.rounds          = ParagonArenaCoachDB.rounds or {}
ParagonArenaCoachDB.coachNotes      = ParagonArenaCoachDB.coachNotes or {}
ParagonArenaCoachDB.messages        = ParagonArenaCoachDB.messages or {}
ParagonArenaCoachDB.positions       = ParagonArenaCoachDB.positions or {}
ParagonArenaCoachDB.locked          = ParagonArenaCoachDB.locked or false
ParagonArenaCoachDB.coachIcon       = ParagonArenaCoachDB.coachIcon or "portrait"
ParagonArenaCoachDB.talentNote      = ParagonArenaCoachDB.talentNote or ""
ParagonArenaCoachDB.coachProfileKey = ParagonArenaCoachDB.coachProfileKey or "prot_pal_main"
ParagonArenaCoachDB.enableAI        = (ParagonArenaCoachDB.enableAI == true)
ParagonArenaCoachDB.autoSendToCoach = (ParagonArenaCoachDB.autoSendToCoach == true)
-- PvP-first defaults: arenas/BGs on, PvE logging opt-in
ParagonArenaCoachDB.enablePvE        = (ParagonArenaCoachDB.enablePvE == true)
ParagonArenaCoachDB.pveMinDifficulty = ParagonArenaCoachDB.pveMinDifficulty or "none"
ParagonArenaCoachDB.pveBossOnly      = ParagonArenaCoachDB.pveBossOnly or false
-- Optional Debugger for those that want to help point out bugs
ParagonArenaCoachDB.debugEnabled = (ParagonArenaCoachDB.debugEnabled == true)

-- =========================================
-- Version flag / first-run splash
-- =========================================

local CURRENT_PAC_VERSION = "0.7.0"

ParagonArenaCoachDB.version = ParagonArenaCoachDB.version or ""
local pacNeedsWelcome = false
if ParagonArenaCoachDB.version ~= CURRENT_PAC_VERSION then
    ParagonArenaCoachDB.version = CURRENT_PAC_VERSION
    pacNeedsWelcome = true
end

function PAC_ShowWelcomeSplash()
    if PAC_WelcomeFrame then
        PAC_WelcomeFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "PAC_WelcomeFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 180)
    f:SetPoint("CENTER")
    PAC_ApplyPanelSkin(f)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("Project: Astral Combatant")

    local msg = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    msg:SetPoint("TOPLEFT", 16, -40)
    msg:SetPoint("TOPRIGHT", -16, -40)
    msg:SetJustifyH("LEFT")
    msg:SetText("Thank you for installing Project: Astral Combatant.\n\n" ..
        "Built by Paragøn(-Tichondrius) for PvP players who care about their own performance and learning from mistakes.\n\n" ..
        "Made by a passionate PvP tank, for everyone.\n\n" ..
        "You can drag the mini meter, lock/unlock it with the padlock button, and view other functions via Right Click.")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
end

-- =========================================
-- Coach profiles
-- =========================================

PAC_CoachProfiles = {
    prot_pal_main = {
        label  = "Paragøn-Tichondrius",
        header = "Project: Astral Duelist (Protection Paladin, TWW S3)",
        prompt = [[
<full prot_pal_main prompt text unchanged for brevity>]],
    },

    ret_pal = {
        label  = "Ret Pal – Gladiator",
        header = "Coach: Retribution Paladin Gladiator (TWW S3)",
        prompt = [[
<full ret_pal prompt text unchanged>]],
    },

    havoc_dh = {
        label  = "Havoc DH - Gladiator",
        header = "Coach: Havoc Demon Hunter Gladiator (TWW S3)",
        prompt = [[
<full havoc_dh prompt text unchanged>]],
    },
}

-- (Paste your original long prompts back into the three profiles above.)

local function PAC_GetCurrentCoachProfile()
    ParagonArenaCoachDB.coachProfileKey = ParagonArenaCoachDB.coachProfileKey or "prot_pal_main"
    local key = ParagonArenaCoachDB.coachProfileKey
    return PAC_CoachProfiles[key] or PAC_CoachProfiles.prot_pal_main
end

local function PAC_IncrementCoachUsage()
    ParagonArenaCoachDB.coachUsage = ParagonArenaCoachDB.coachUsage or {}
    local key = ParagonArenaCoachDB.coachProfileKey or "prot_pal_main"
    ParagonArenaCoachDB.coachUsage[key] = (ParagonArenaCoachDB.coachUsage[key] or 0) + 1
end

local PAC_CoachChatFrame = nil

local function PAC_UpdateCoachUsageLabel()
    if not PAC_CoachChatFrame or not PAC_CoachChatFrame.usageText then return end

    ParagonArenaCoachDB.coachUsage = ParagonArenaCoachDB.coachUsage or {}
    local key     = ParagonArenaCoachDB.coachProfileKey or "prot_pal_main"
    local profile = PAC_GetCurrentCoachProfile()
    local count   = ParagonArenaCoachDB.coachUsage[key] or 0

    PAC_CoachChatFrame.usageText:SetText(
        string.format("Coach: %s – Sessions: %d", profile.label or key, count)
    )
end

local function PAC_SavePosition(frame, key)
    if not frame or not key then return end
    ParagonArenaCoachDB.positions = ParagonArenaCoachDB.positions or {}

    local point, _, relPoint, x, y = frame:GetPoint()
    local w, h = frame:GetSize()

    ParagonArenaCoachDB.positions[key] = {
        point or "CENTER",
        relPoint or "CENTER",
        x or 0,
        y or 0,
        w or 380,
        h or 145,
    }
end

local function PAC_RestorePosition(frame, key, defaultPoint, defaultX, defaultY)
    if not frame or not key then return end
    ParagonArenaCoachDB.positions = ParagonArenaCoachDB.positions or {}
    local pos = ParagonArenaCoachDB.positions[key]

    frame:ClearAllPoints()
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
        if pos[5] and pos[6] then
            frame:SetSize(pos[5], pos[6])
        end
    else
        frame:SetPoint(defaultPoint, UIParent, defaultPoint, defaultX, defaultY)
        frame:SetSize(380, 145)
    end
end

local function PAC_ApplyLockStateToFrame(frame, key)
    if not frame then return end

    if ParagonArenaCoachDB.locked then
        frame:EnableMouse(false)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    else
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetMovable(true)
        frame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if key then
                PAC_SavePosition(self, key)
            end
        end)
    end
end

local function PAC_ApplyLockStateAll()
    PAC_ApplyLockStateToFrame(PAC_MeterFrame, "meter")
    PAC_ApplyLockStateToFrame(PAC_BreakdownFrame, "breakdown")
    PAC_ApplyLockStateToFrame(PAC_HistoryFrame, "history")
    PAC_ApplyLockStateToFrame(PAC_ListFrame, "list")
    PAC_ApplyLockStateToFrame(PAC_CoachChatFrame, "coachchat")
end

-- =========================================
-- Debug / frame state
-- =========================================

local currentRound       = nil
local duelActive         = false
local lastDamageEventTime = 0
local DUMMY_IDLE_TIMEOUT = 5  -- seconds out of combat before auto-ending Dummy

local function PAC_NewEmptyStats()
    return {
        damageDone   = 0,
        healingDone  = 0,
        damageTaken  = 0,
        healingTaken = 0,
        mitigated    = 0,

        dps = 0,
        hps = 0,

        cc         = 0,
        ccBreaks   = 0,
        interrupts = 0,

        spells          = {},
        ccByCat         = {},
        controlEvents   = {},
        interruptEvents = {},
    }
end

-- =========================================
-- Mode / spec helpers
-- =========================================

local function PAC_GetInstanceMode()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return nil
    end

    if instanceType == "arena" then
        return "Arena"
    elseif instanceType == "pvp" then
        return "Battleground"
    elseif instanceType == "party" then
        return "Dungeon"
    elseif instanceType == "raid" then
        return "Raid"
    elseif instanceType == "scenario" then
        return "Scenario"
    end
    return nil
end

local function PAC_IsPvPInstanceMode(mode)
    return mode == "Arena" or mode == "Battleground"
end

local function GetPlayerSpec()
    local specIndex = GetSpecialization()
    if not specIndex then return "Unknown" end
    local _, name = GetSpecializationInfo(specIndex)
    return name or "Unknown"
end

-- =========================================
-- Performance classification helpers
-- =========================================

local PAC_PerformanceHistory = PAC_PerformanceHistory or {}

local function PAC_GetPerfKeyForRound(src)
    if not src or not src.player then
        return "unknown:unknown:" .. (src.mode or "unknown")
    end
    local spec  = src.player.spec or "UnknownSpec"
    local class = src.player.class or "UnknownClass"
    local mode  = src.mode or "UnknownMode"
    return string.format("%s:%s:%s", class, spec, mode)
end

local function PAC_UpdatePerformanceHistory(src)
    if not src or not src.stats then return end

    local key = PAC_GetPerfKeyForRound(src)
    PAC_PerformanceHistory[key] = PAC_PerformanceHistory[key] or {
        count = 0,
        avgDPS = 0,
        avgHPS = 0,
        avgDeaths = 0,
    }

    local rec = PAC_PerformanceHistory[key]

    local dps = src.stats.dps or 0
    local hps = src.stats.hps or 0

    local deathsCount = 0
    if src.deaths then
        for _ in ipairs(src.deaths) do
            deathsCount = deathsCount + 1
        end
    end

    rec.count = rec.count + 1

    local c = rec.count
    rec.avgDPS    = ((rec.avgDPS * (c - 1)) + dps) / c
    rec.avgHPS    = ((rec.avgHPS * (c - 1)) + hps) / c
    rec.avgDeaths = ((rec.avgDeaths * (c - 1)) + deathsCount) / c
end

local function PAC_ClassifyPerformance(src)
    if not src or not src.stats then return "average" end

    local key = PAC_GetPerfKeyForRound(src)
    local rec = PAC_PerformanceHistory[key]

    local dps = src.stats.dps or 0
    local hps = src.stats.hps or 0

    local deathsCount = 0
    if src.deaths then
        for _ in ipairs(src.deaths) do
            deathsCount = deathsCount + 1
        end
    end

    if not rec or rec.count < 3 then
        if deathsCount >= 3 then
            return "below"
        elseif deathsCount == 0 and (dps > 0 or hps > 0) then
            return "exceeded"
        else
            return "average"
        end
    end

    local dpsRatio = (rec.avgDPS > 0) and (dps / rec.avgDPS) or 1
    local hpsRatio = (rec.avgHPS > 0) and (hps / rec.avgHPS) or 1
    local deathDiff = deathsCount - rec.avgDeaths

    if (dpsRatio <= 0.7 and hpsRatio <= 0.7) or deathDiff >= 2 then
        return "below"
    end

    if (dpsRatio >= 1.35 or hpsRatio >= 1.35) and deathDiff <= 0 then
        return "exceeded"
    end

    return "average"
end

local PAC_PerformanceTemplates = {
    below = "This game was below my usual standard for %s %s. I made noticeable mistakes and want you to highlight the highest-impact ones without sugarcoating, but keep the tone constructive so I can actually improve.",
    average = "This match felt roughly average for my current skill on %s %s. Please help me identify 2–3 specific habits that would move me from average to reliably solid.",
    exceeded = "This game went better than usual for my %s %s. I’d like you to point out what I did well and how to make this level of play more consistent without just saying \"keep it up\"."
}

local PAC_CreatorEasterEggLines = {
    -- Lore-ish
    "Astral imprint detected: this round comes from the originator of Project: Astral Combatant (" .. pac_CreatorIdentity .. ").",
    "A trace of astral ink lingers on this combat log; the Project: Astral Combatant author fought in this round (" .. pac_CreatorIdentity .. ").",
    "This engagement bears the astral mark of Project: Astral Combatant's original duelist/elite (" .. pac_CreatorIdentity .. ").",

    -- Playful
    "You just reviewed a round played by the original PAC author. Be gentle, senpai is watching.",
    "Author run detected; blame or praise here may end up in a future patch.",
    "The person getting coached this round is the actual PAC author. Nobody tell the forums.",
    "This round was forged in the Project: Astral Combatant lab by the original author.",

    -- Straightforward
    "Fun fact: you’re looking at a session from the person who wrote PAC (" .. pac_CreatorIdentity .. ").",
    "Hidden note: this round was played by the original PAC author.",
    "Behind-the-scenes: this is one of the author's own PAC test rounds.",

    -- AI-helper easter eggs
    "Somewhere in the astral combatant logs, an AI assistant is quietly taking notes on this round.",
    "Rumor says this round was co-designed by a tank and an AI arguing over cooldowns at 3 AM.",
}

-- Build a short, PvP-aware performance sentence based on existing stats
local function PAC_BuildPerformanceSummaryLine(src)
    if not src or not src.stats then
        return "No stats recorded for this round."
    end

    local mode = src.mode or "Unknown"
    local dur  = src.duration or 0
    local dps  = src.stats.dps or 0
    local hps  = src.stats.hps or 0

    if dur < 1 then dur = 1 end

    if mode == "Arena" or mode == "Battleground" or mode == "WorldPvP" then
        return string.format(
            "PvP round: %.0fs • Pressure %.0f DPS • Sustain %.0f HPS.",
            dur, dps, hps
        )
    else
        return string.format(
            "Round: %.0fs • Damage %.0f DPS • Healing %.0f HPS.",
            dur, dps, hps
        )
    end
end

local function PAC_GetPerfBadge(src)
    if not src or not src.stats then
        return "N/A", 0.7, 0.7, 0.7
    end

    local grade = PAC_ClassifyPerformance(src)  -- "below", "average", "exceeded"
    if grade == "below" then
        return "Below baseline", 0.9, 0.2, 0.2   -- red-ish
    elseif grade == "exceeded" then
        return "Above baseline", 0.2, 0.8, 0.3   -- green-ish
    else
        return "Baseline", 0.9, 0.8, 0.2         -- amber
    end
end

local function PAC_GetPlayerClassSpec(src)
    local specName  = src.player and src.player.spec or "Unknown Spec"
    local className = src.player and src.player.class or "Unknown Class"

    if className == "Unknown Class" and src.player and src.player.name and src.player.realm then
        if UnitExists("player") and UnitName("player") == src.player.name then
            local _, classTag = UnitClass("player")
            if classTag then
                className = classTag
            end
        end
    end

    return specName, className
end

local function EndCurrentRound(resultFlag)
    if not currentRound then return end

    local caller = debugstack and debugstack(2, 1, 0) or "unknown caller"
    PAC_Debug("DEBUG: EndCurrentRound(" .. tostring(resultFlag) .. ") from:\n" .. caller)

    currentRound.endTime = GetTime()
    currentRound.result  = resultFlag or currentRound.result or "unknown"

    local dur = (currentRound.endTime or currentRound.startTime or GetTime()) - (currentRound.startTime or GetTime())
    if dur < 1 then dur = 1 end
    currentRound.duration = dur

    local s = currentRound.stats or PAC_NewEmptyStats()
    currentRound.stats = s
    s.dps = (s.damageDone or 0) / dur
    s.hps = (s.healingDone or 0) / dur

    if currentRound.mode == "WorldPvP" and currentRound.attackers then
        local count = 0
        for _ in pairs(currentRound.attackers) do
            count = count + 1
        end
        currentRound.attackers_count = count
    end

    ParagonArenaCoachDB.rounds = ParagonArenaCoachDB.rounds or {}
    table.insert(ParagonArenaCoachDB.rounds, currentRound)

    PAC_Debug(string.format(
        "saved a round (%s, %s). DPS=%.0f, HPS=%.0f",
        currentRound.mode or "?",
        currentRound.result or "?",
        currentRound.stats and currentRound.stats.dps or 0,
        currentRound.stats and currentRound.stats.hps or 0
    ))

    if ParagonArenaCoachDB.autoSendToCoach then
        local summary = PAC_ComposeCoachSummary(currentRound)
        if summary then
            local npcComment = nil
            if not ParagonArenaCoachDB.enableAI then
                npcComment = PAC_NPCEvaluateRound(currentRound)
            end
            if npcComment and npcComment ~= "" then
                summary = summary .. "\n\n" .. npcComment
            end
            if PAC_CoachChatAppend then
                PAC_CoachChatAppend(summary)
                PAC_IncrementCoachUsage()
                PAC_UpdateCoachUsageLabel()
                PAC_Debug("Auto-sent round to PAC Coach Chat after end.")
            end
        end
    end

    currentRound = nil
    duelActive   = false
    PACStopMiniMeterTicker()
    UpdateMeter()
end

-- =========================================
-- Round lifecycle
-- =========================================

local function IsTrainingDummy(unit)
    if not UnitExists(unit) then return false end
    local name = UnitName(unit)
    if not name then return false end

    if name:find("Training Dummy") or name:find("PvP Training Dummy") then
        return true
    end
    return false
end

local function StartNewRound(mode)
    local now = GetTime()
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    local mapName = (mapInfo and mapInfo.name) or "Unknown"

    currentRound = {
        mode      = mode,
        map       = mapName,
        startTime = now,
        endTime   = nil,
        result    = "unknown",
        stats     = PAC_NewEmptyStats(),
        players   = {},
        deaths      = {},
        groupDeaths = {},
        cds_used    = {},
    }

    lastDamageEventTime = GetTime()
    PAC_Debug("started logging a " .. tostring(mode) .. " round on " .. tostring(mapName) .. ".")
    PAC_StartMiniMeterTicker()
    UpdateMeter()
end

-- shared helper to compose coach summary text (used by breakdown/meter/auto-send)
function PAC_ComposeCoachSummary(src)
    if not src or not src.stats then
        return nil
    end

    local profile     = PAC_GetCurrentCoachProfile()
    local coachHeader = profile.header or "Project: Astral Duelist"

    local lines = {}

    table.insert(lines, coachHeader)
    table.insert(lines, string.format(
        "Round @ %s - %s on %s (%s)",
        date("%H:%M", src.timestamp or time()),
        src.mode or "?",
        src.map  or "?",
        src.result or "unknown"
    ))

    -- PvP-aware one-liner using current stats
    table.insert(lines, PAC_BuildPerformanceSummaryLine(src))

    local dur   = src.duration or 0
    local dps   = src.stats.dps or 0
    local hps   = src.stats.hps or 0
    local kicks = src.stats.interrupts or 0

    table.insert(lines, string.format(
        "Dur: %.0fs | DPS: %.0f | HPS: %.0f | Kicks: %d",
        dur, dps, hps, kicks
    ))

ParagonArenaCoachDB.talentNote = ParagonArenaCoachDB.talentNote or ""
    if ParagonArenaCoachDB.talentNote ~= "" then
        table.insert(lines, "Talents/PvP talents (player-reported): " .. ParagonArenaCoachDB.talentNote)
    end

    if src.stats.spells then
        local tmp = {}
        for spell, bucket in pairs(src.stats.spells) do
            table.insert(tmp, { spell = spell, amount = bucket.total or 0 })
        end

        table.sort(tmp, function(a, b) return a.amount > b.amount end)
        table.insert(lines, "Top spells:")

        local total = src.stats.damageDone > 0 and src.stats.damageDone or 1
        local shown = 0
        local shownTotal = 0

        for _, entry in ipairs(tmp) do
            if shown >= 5 then break end
            local pct = (entry.amount / total) * 100
            table.insert(lines, string.format(
                " - %s: %.0f (%.1f%%)",
                entry.spell, entry.amount, pct
            ))
            shown = shown + 1
            shownTotal = shownTotal + entry.amount
        end

        local other = total - shownTotal
        if other > 0 and shown > 0 then
            local pct = (other / total) * 100
            table.insert(lines, string.format(
                " - Other: %.0f (%.1f%%)",
                other, pct
            ))
        end
    end

    -- Easter egg: shows a fun provenance note when this round was tagged by the author client
if src.creatorTag == "PAC_CREATOR" and PAC_CreatorEasterEggLines and #PAC_CreatorEasterEggLines > 0 then
    local idx = math.random(1, #PAC_CreatorEasterEggLines)
    table.insert(lines, "")
    table.insert(lines, PAC_CreatorEasterEggLines[idx])
end

    return table.concat(lines, "\n")
end

-- lightweight NPC-style evaluation: purely post-match, stats-based flavor
function PAC_NPCEvaluateRound(src)
    if not src or not src.stats then return nil end

    local stats = src.stats
    local dur   = src.duration or 0
    if dur < 1 then dur = 1 end

    local lines = {}

    if stats.interrupts == 0 and dur > 60 then
        table.insert(lines, "Coach: No kicks that round; look for at least 1–2 key stops on their big casts next time.")
    elseif stats.interrupts and stats.interrupts >= 3 then
        table.insert(lines, "Coach: Good use of interrupts; that kind of control stabilizes higher-rating games.")
    end

    local dmg  = stats.damageDone   or 0
    local hlg  = stats.healingDone  or 0
    local mit  = stats.mitigated    or 0
    local dmgT = stats.damageTaken  or 0

    if mit > 0 and dmgT > 0 then
        local ratio = mit / (mit + dmgT)
        if ratio > 0.3 then
            table.insert(lines, "Coach: Strong defensive trading; you prevented a noticeable chunk of incoming damage.")
        end
    end

    if dmg > 0 and hlg > 0 then
        table.insert(lines, "Coach: You contributed both damage and sustain—next step is tightening when you swap from hitting to stabilizing.")
    end

    if #lines == 0 then
        table.insert(lines, "Coach: Solid baseline round; focus on mapping enemy goes and your major CDs for the next one.")
    end

    return table.concat(lines, "\n")
end

-- Update a single bar on the mini meter
local function PAC_UpdateBar(bar, labelText, value, maxValue)
    if not bar then return end

    bar.value    = value or 0
    bar.maxValue = maxValue or 1

    local fraction = 0
    if bar.maxValue > 0 then
        fraction = math.max(0, math.min(1, bar.value / bar.maxValue))
    end

    bar:SetValue(fraction)

    if bar.label then
        bar.label:SetText(labelText or "")
    end

    if bar.valueText then
        bar.valueText:SetText(PAC_AbbrevNumber(bar.value))
    end
end

-- Per-round per-player row
local function PAC_GetOrCreateRoundPlayer(round, guid, name)
    if not round or not guid then
        return nil
    end

    round.players = round.players or {}
    local p = round.players[guid]
    if not p then
        p = {
            guid = guid,
            name = name or "Unknown",
            pvp_damage_done  = 0,
            pvp_healing_done = 0,
            pvp_damage_taken = 0,
        }
        round.players[guid] = p
    end
    return p
end

local function PAC_GetOrCreateSpellBucket(stats, spellName)
    if not stats or not spellName then return nil end

    stats.spells = stats.spells or {}
    local b = stats.spells[spellName]
    if not b then
        b = {
            total        = 0,
            hits         = 0,
            crits        = 0,
            nonCritTotal = 0,
            critTotal    = 0,
            maxHit       = 0,
            maxCrit      = 0,
        }
        stats.spells[spellName] = b
    end
    return b
end

-- =========================================
-- Tracked cooldowns
-- =========================================

local trackedCDs = {
    ["Divine Shield"]                    = true,
    ["Blessing of Protection"]           = true,
    ["Blessing of Spellwarding"]         = true,
    ["Ardent Defender"]                  = true,
    ["Guardian of Ancient Kings"]        = true,
    ["Shield of Vengeance"]              = true,
    ["Avenging Wrath"]                   = true,
    ["Guardian of the Forgotten Queen"]  = true,
    ["Searing Glare"]                    = true,
    ["Inquisition"]                      = true,
    ["Hammer of Justice"]                = true,
}

-- =========================================
-- Combat log (polled, Midnight-safe)
-- =========================================

local function OnCombatLogEvent()
    if type(CombatLogGetCurrentEventInfo) ~= "function" then
        return
    end

    local timestamp, event, hideCaster,
        srcGUID, srcName, srcFlags, srcRaidFlags,
        dstGUID, dstName, dstFlags, dstRaidFlags,
        spellId, spellName, spellSchool,
        amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing,
        extraSpellId, extraSpellName, extraSchool, auraType = CombatLogGetCurrentEventInfo()

    local playerGUID = UnitGUID("player")
    if not playerGUID then return end

    --------------------------------------------------
    -- Auto-start Dummy / World PvP (when no round yet)
    --------------------------------------------------
    if not currentRound then
        local hittingDummy = false
        if dstGUID and UnitGUID("target") == dstGUID and IsTrainingDummy("target") then
            hittingDummy = true
        end

        if srcGUID == playerGUID and hittingDummy then
            PAC_Debug("Auto-starting Dummy round from CLEU: " .. tostring(event))
            StartNewRound("Dummy")
            UpdateMeter()
            return
        end

        if not IsInInstance() and not duelActive and dstGUID == playerGUID then
            local isPlayer  = bit.band(srcFlags or 0, COMBATLOG_OBJECT_CONTROL_PLAYER) > 0
            local isHostile = bit.band(srcFlags or 0, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0
            if isPlayer and isHostile then
                StartNewRound("WorldPvP")
                currentRound.attackers = currentRound.attackers or {}
                currentRound.attackers[srcName or "Unknown"] = true
                UpdateMeter()
                return
            end
        end
        -- If we still have no round, nothing more to do for this CLEU
        if not currentRound then
            return
        end
    end

    --------------------------------------------------
    -- From here on, we know currentRound exists
    --------------------------------------------------
    local round = currentRound
    local stats = round.stats
    if not stats then return end

    -- New: cache these booleans once
    local isPlayerSrc = (srcGUID == playerGUID)
    local isPlayerDst = (dstGUID == playerGUID)

    -- DAMAGE DONE
    if event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" then
        if isPlayerSrc and amount and amount > 0 then
            stats.damageDone = (stats.damageDone or 0) + amount
            stats.lastDamageEventTime = GetTime()

            local label
            if event == "SWING_DAMAGE" then
                label = "Melee"
            else
                label = spellName or "Unknown"
            end

            local bucket = PAC_GetOrCreateSpellBucket(stats, label)
            if bucket then
                bucket.total = bucket.total + amount
                if critical then
                    bucket.crits     = bucket.crits + 1
                    bucket.critTotal = bucket.critTotal + amount
                    if amount > bucket.maxCrit then
                        bucket.maxCrit = amount
                    end
                else
                    bucket.hits         = bucket.hits + 1
                    bucket.nonCritTotal = bucket.nonCritTotal + amount
                    if amount > bucket.maxHit then
                        bucket.maxHit = amount
                    end
                end
            end

            local srcPlayer = PAC_GetOrCreateRoundPlayer(round, srcGUID, srcName)
            if srcPlayer then
                srcPlayer.pvp_damage_done = (srcPlayer.pvp_damage_done or 0) + amount
            end
        end
    end

    -- HEALING DONE
    if event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
        if isPlayerSrc and amount and amount > 0 then
            stats.healingDone = (stats.healingDone or 0) + amount

            local label = spellName or "Unknown"
            local bucket = PAC_GetOrCreateSpellBucket(stats, label)
            if bucket then
                bucket.total = bucket.total + amount
                if critical then
                    bucket.crits     = bucket.crits + 1
                    bucket.critTotal = bucket.critTotal + amount
                    if amount > bucket.maxCrit then
                        bucket.maxCrit = amount
                    end
                else
                    bucket.hits         = bucket.hits + 1
                    bucket.nonCritTotal = bucket.nonCritTotal + amount
                    if amount > bucket.maxHit then
                        bucket.maxHit = amount
                    end
                end
            end

            local srcPlayer = PAC_GetOrCreateRoundPlayer(round, srcGUID, srcName)
            if srcPlayer then
                srcPlayer.pvp_healing_done = (srcPlayer.pvp_healing_done or 0) + amount
            end
        end
    end

    -- DAMAGE / HEALING TAKEN
    if amount and amount > 0 then
        if event == "SWING_DAMAGE" or event == "SPELL_DAMAGE" or event == "RANGE_DAMAGE" then
            if isPlayerDst then
                stats.damageTaken = (stats.damageTaken or 0) + amount
                local dstPlayer = PAC_GetOrCreateRoundPlayer(round, dstGUID, dstName)
                if dstPlayer then
                    dstPlayer.pvp_damage_taken = (dstPlayer.pvp_damage_taken or 0) + amount
                end
            end
        elseif event == "SPELL_HEAL" or event == "SPELL_PERIODIC_HEAL" then
            if isPlayerDst then
                stats.healingTaken = (stats.healingTaken or 0) + amount
            end
        end
    end

    -- Deaths
    if event == "UNIT_DIED" then
        local t = GetTime() - (round.startTime or GetTime())
        if dstGUID == playerGUID then
            table.insert(round.deaths, { time = t, unit = "player" })
        else
            local isPlayer = bit.band(dstFlags or 0, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
            local inGroup  = bit.band(dstFlags or 0,
                COMBATLOG_OBJECT_AFFILIATION_PARTY +
                COMBATLOG_OBJECT_AFFILIATION_RAID
            ) > 0
            if isPlayer and inGroup then
                table.insert(round.groupDeaths, {
                    time = t,
                    name = dstName or "Unknown",
                })
            end
        end
    end

    -- CONTROL
    if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" then
        local cat = PAC_GetCCCategory(spellName)
        if cat and isPlayerSrc then
            stats.cc = (stats.cc or 0) + 1
            stats.ccByCat = stats.ccByCat or {}
            stats.ccByCat[cat] = (stats.ccByCat[cat] or 0) + 1

            stats.controlEvents = stats.controlEvents or {}
            table.insert(stats.controlEvents, {
                time     = timestamp,
                srcName  = srcName,
                dstName  = dstName,
                spell    = spellName,
                category = cat,
                event    = event,
            })

            local srcPlayer = PAC_GetOrCreateRoundPlayer(round, srcGUID, srcName)
            if srcPlayer then
                srcPlayer.pvp_cc_count = (srcPlayer.pvp_cc_count or 0) + 1
            end
        end
    elseif event == "SPELL_AURA_BROKEN" or event == "SPELL_AURA_BROKEN_SPELL" then
        local cat = PAC_GetCCCategory(spellName)
        if cat and isPlayerSrc then
            stats.ccBreaks = (stats.ccBreaks or 0) + 1
            stats.controlEvents = stats.controlEvents or {}
            table.insert(stats.controlEvents, {
                time     = timestamp,
                srcName  = srcName,
                dstName  = dstName,
                spell    = spellName,
                category = cat,
                event    = event,
            })
        end
    end

    -- INTERRUPTS
    if event == "SPELL_INTERRUPT" and isPlayerSrc and extraSpellName then
        stats.interrupts = (stats.interrupts or 0) + 1
        stats.interruptEvents = stats.interruptEvents or {}
        table.insert(stats.interruptEvents, {
            time        = timestamp,
            srcName     = srcName,
            dstName     = dstName,
            interrupt   = spellName,
            interrupted = extraSpellName,
        })

        local srcPlayer = PAC_GetOrCreateRoundPlayer(round, srcGUID, srcName)
        if srcPlayer then
            srcPlayer.pvp_interrupts = (srcPlayer.pvp_interrupts or 0) + 1
        end
    end

    -- TRACKED DEFENSIVE CDS
    if event == "SPELL_CAST_SUCCESS" and isPlayerSrc and spellName and trackedCDs[spellName] then
        round.cds_used = round.cds_used or {}
        table.insert(round.cds_used, {
            time    = timestamp,
            spell   = spellName,
            srcName = srcName,
        })
    end

    -- Dummy idle timeout
    if currentRound and currentRound.mode == "Dummy" and currentRound.stats then
        local now  = GetTime()
        local last = currentRound.stats.lastDamageEventTime or 0
        if last > 0 and (now - last) >= DUMMY_IDLE_TIMEOUT then
            EndCurrentRound("manual")
            PAC_Debug("Auto-ended Dummy round after idle timer.")
        end
    end
end

-- =========================================
-- Duel detection via system chat (Midnight-safe)
-- =========================================

local function PAC_InitDuelChat()
    -- handled by chat filter hook below
end

-- =========================================
-- Coach Chat frame
-- =========================================

local PAC_UpdateCoachIcon
local PAC_LastExportText = ""

local PAC_CoachRound = 0
local PAC_CoachSelector

function PAC_CoachChatClear()
    PAC_CreateCoachChatFrame()
    PAC_CoachRound = PAC_CoachRound + 1

    if PAC_CoachChatFrame.text then
        PAC_CoachChatFrame.text:SetText(("* Round %d – new notes *\n"):format(PAC_CoachRound))
    end
end

local function PAC_CoachChatAppend(text)
    if not text or text == "" then return end
    PAC_CreateCoachChatFrame()
    PAC_CoachChatFrame:Show()

    local current = PAC_CoachChatFrame.text:GetText() or ""
    if current == "" then
        PAC_CoachRound = PAC_CoachRound + 1
        current = ("Round %d notes:\n"):format(PAC_CoachRound)
    else
        current = current .. "\n"
    end

    PAC_CoachChatFrame.text:SetText(current .. text)

    C_Timer.After(0, function()
        local sf = PAC_CoachChatFrame.scrollFrame
        if sf then
            sf:SetVerticalScroll(sf:GetVerticalScrollRange() or 0)
        end
    end)

    PAC_UpdateCoachIcon()
end

function PAC_CreateCoachChatFrame()
    if PAC_CoachChatFrame then return end

    PAC_CoachChatFrame = CreateFrame("Frame", "PAC_CoachChatFrame", UIParent, "BackdropTemplate")
    PAC_CoachChatFrame:SetSize(320, 260)
    PAC_RestorePosition(PAC_CoachChatFrame, "coachchat", "CENTER", 300, 0)
    PAC_CoachChatFrame:SetMovable(true)
    PAC_CoachChatFrame:EnableMouse(true)
    PAC_CoachChatFrame:RegisterForDrag("LeftButton")
    PAC_CoachChatFrame:SetScript("OnDragStart", function(self)
        if self:IsMovable() and not ParagonArenaCoachDB.locked then
            self:StartMoving()
        end
    end)
    PAC_CoachChatFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PAC_SavePosition(self, "coachchat")
    end)

    PAC_ApplyPanelSkin(PAC_CoachChatFrame)

    local icon = PAC_CoachChatFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("TOPRIGHT", -30, -6)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    PAC_CoachChatFrame.icon = icon

    local title = PAC_CoachChatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("PAC Coach Chat")

    local usageText = PAC_CoachChatFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    usageText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    usageText:SetText("")
    PAC_CoachChatFrame.usageText = usageText

    local blurb = PAC_CoachChatFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    blurb:SetPoint("TOPLEFT", usageText, "BOTTOMLEFT", 0, -2)
    blurb:SetWidth(260)
    blurb:SetJustifyH("LEFT")
    blurb:SetText("Default: NPC-style post-match notes. Optional: enable AI coaching in Settings > AddOns > Project: Astral Combatant for deeper written reviews (no automation or predictions).")

    local close = CreateFrame("Button", nil, PAC_CoachChatFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local coachBtn = CreateFrame("Button", nil, PAC_CoachChatFrame, "UIPanelButtonTemplate")
    coachBtn:SetSize(80, 20)
    coachBtn:SetPoint("TOPLEFT", blurb, "BOTTOMLEFT", 0, -2)
    coachBtn:SetText("Coach...")

    local promptBtn = CreateFrame("Button", nil, PAC_CoachChatFrame, "UIPanelButtonTemplate")
    promptBtn:SetSize(80, 20)
    promptBtn:SetPoint("LEFT", coachBtn, "RIGHT", 4, 0)
    promptBtn:SetText("Prompt")

    local copyChatBtn = CreateFrame("Button", nil, PAC_CoachChatFrame, "UIPanelButtonTemplate")
    copyChatBtn:SetSize(80, 20)
    copyChatBtn:SetPoint("LEFT", promptBtn, "RIGHT", 4, 0)
    copyChatBtn:SetText("Copy chat")

    local clearBtn = CreateFrame("Button", nil, PAC_CoachChatFrame, "UIPanelButtonTemplate")
    clearBtn:SetSize(60, 20)
    clearBtn:SetPoint("LEFT", copyChatBtn, "RIGHT", 4, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        PAC_CoachChatClear()
    end)

    PAC_CoachChatFrame.coachBtn    = coachBtn
    PAC_CoachChatFrame.promptBtn   = promptBtn
    PAC_CoachChatFrame.copyChatBtn = copyChatBtn

    PAC_CoachChatFrame:HookScript("OnHide", function()
        if PAC_CoachSelector then
            PAC_CoachSelector:Hide()
        end
    end)

    -- Prompt viewer popup
    promptBtn:SetScript("OnClick", function()
        local profile = PAC_GetCurrentCoachProfile()
        local promptText = profile.prompt or "No prompt defined for this coach profile."

        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(420, 260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        PAC_ApplyPanelSkin(f)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
        title:SetText("Coach Prompt (" .. (profile.label or "Unknown") .. ")")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -26)
        scroll:SetPoint("BOTTOMRIGHT", -28, 36)

        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(370)
        eb:SetAutoFocus(true)
        eb:EnableMouse(true)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        scroll:SetScrollChild(eb)

        eb:SetText(promptText)
        eb:HighlightText()
        eb:SetCursorPosition(0)
        eb:SetFocus()

        local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        copyBtn:SetSize(80, 20)
        copyBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
        copyBtn:SetText("Copy")
        copyBtn:SetScript("OnClick", function()
            eb:HighlightText()
            eb:SetFocus()
        end)
    end)

    -- Copy Coach Chat popup
    copyChatBtn:SetScript("OnClick", function()
        local chatText = PAC_CoachChatFrame.text:GetText() or ""
        if chatText == "" then
            PAC_Debug("PAC Coach Chat is empty; nothing to copy.")
            return
        end

        local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        f:SetSize(420, 260)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        PAC_ApplyPanelSkin(f)

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -6)
        title:SetText("Copy Coach Chat")

        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 10, -26)
        scroll:SetPoint("BOTTOMRIGHT", -28, 36)

        local eb = CreateFrame("EditBox", nil, scroll)
        eb:SetMultiLine(true)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(370)
        eb:SetAutoFocus(true)
        eb:EnableMouse(true)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        scroll:SetScrollChild(eb)

        eb:SetText(chatText)
        eb:HighlightText()
        eb:SetCursorPosition(0)
        eb:SetFocus()

        local copyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        copyBtn:SetSize(80, 20)
        copyBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
        copyBtn:SetText("Copy")
        copyBtn:SetScript("OnClick", function()
            eb:HighlightText()
            eb:SetFocus()
        end)
    end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, PAC_CoachChatFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -90)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetWidth(260)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetText("PAC Coach Chat ready.\nUse the meter or Breakdown to send notes here.")

    PAC_CoachChatFrame.scrollFrame = scrollFrame
    PAC_CoachChatFrame.content     = content
    PAC_CoachChatFrame.text        = text

    coachBtn:SetScript("OnClick", function()
        if PAC_CoachSelector and PAC_CoachSelector:IsShown() then
            PAC_CoachSelector:Hide()
            return
        end

        if not PAC_CoachSelector then
            local selector = CreateFrame("Frame", nil, PAC_CoachChatFrame, "BackdropTemplate")
            selector:SetSize(220, 10)
            selector:SetPoint("TOPLEFT", coachBtn, "BOTTOMLEFT", 0, -2)
            PAC_ApplyPanelSkin(selector)
            selector:SetClampedToScreen(true)

            local stitle = selector:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            stitle:SetPoint("TOPLEFT", 8, -6)
            stitle:SetText("Select coach profile")

            selector.title = stitle
            selector.buttons = {}

            local y = -24
            for key, profile in pairs(PAC_CoachProfiles) do
                local btn = CreateFrame("Button", nil, selector, "UIPanelButtonTemplate")
                btn:SetSize(200, 18)
                btn:SetPoint("TOPLEFT", 10, y)
                btn:SetText(profile.label or key)

                btn:SetScript("OnClick", function()
                    ParagonArenaCoachDB.coachProfileKey = key
                    PAC_Debug("Selected coach profile: " .. (profile.label or key))
                    PAC_UpdateCoachUsageLabel()
                    selector:Hide()
                end)

                table.insert(selector.buttons, btn)
                y = y - 22
            end

            local totalHeight = -y + 10
            selector:SetHeight(totalHeight)

            local closeSel = CreateFrame("Button", nil, selector, "UIPanelCloseButton")
            closeSel:SetPoint("TOPRIGHT", -2, -2)

            PAC_CoachSelector = selector
        end

        PAC_CoachSelector:Show()
    end)

    PAC_UpdateCoachUsageLabel()
    PAC_UpdateCoachIcon()
    PAC_UpdateCoachAIButtons()
    PAC_CoachChatFrame:Hide()
end

function PAC_UpdateCoachIcon()
    if not PAC_CoachChatFrame or not PAC_CoachChatFrame.icon then return end
    local mode = ParagonArenaCoachDB.coachIcon or "portrait"

    if mode == "portrait" then
        PAC_CoachChatFrame.icon:SetTexture("Interface\\Icons\\Ability_Paladin_ShieldoftheTemplar")
    elseif mode == "astral" then
        PAC_CoachChatFrame.icon:SetTexture("Interface\\AddOns\\ProjectAstralCombatant\\Media\\coach_astral")
    elseif mode == "veteran" then
        PAC_CoachChatFrame.icon:SetTexture("Interface\\AddOns\\ProjectAstralCombatant\\Media\\coach_veteran")
    else
        PAC_CoachChatFrame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
end

function PAC_UpdateCoachAIButtons()
    if not PAC_CoachChatFrame
        or not PAC_CoachChatFrame.promptBtn
        or not PAC_CoachChatFrame.copyChatBtn then
        return
    end

    local aiOn = ParagonArenaCoachDB and ParagonArenaCoachDB.enableAI
    PAC_CoachChatFrame.promptBtn:SetEnabled(aiOn and true or false)
    PAC_CoachChatFrame.copyChatBtn:SetEnabled(aiOn and true or false)
end

-- =========================================
-- Breakdown frame
-- =========================================

function PAC_CreateBreakdownFrame()
    if PAC_BreakdownFrame then return end

    PAC_BreakdownFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    PAC_BreakdownFrame:SetSize(260, 220)
    PAC_RestorePosition(PAC_BreakdownFrame, "breakdown", "CENTER", 0, 0)
    PAC_BreakdownFrame:Hide()
    PAC_BreakdownFrame:SetMovable(true)
    PAC_ApplyPanelSkin(PAC_BreakdownFrame)
    PAC_ApplyLockStateToFrame(PAC_BreakdownFrame)
    PAC_BreakdownFrame:EnableMouse(true)
    PAC_BreakdownFrame:RegisterForDrag("LeftButton")
    PAC_BreakdownFrame:SetScript("OnDragStart", function(self)
        if not ParagonArenaCoachDB.locked then
            self:StartMoving()
        end
    end)
    PAC_BreakdownFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        PAC_SavePosition(self, "breakdown")
    end)

    PAC_BreakdownFrame:SetResizable(true)
    if PAC_BreakdownFrame.SetResizeBounds then
        PAC_BreakdownFrame:SetResizeBounds(160, 120, 600, 400)
    end

    local resize = CreateFrame("Button", nil, PAC_BreakdownFrame)
    resize:SetPoint("BOTTOMRIGHT", PAC_BreakdownFrame, "BOTTOMRIGHT", -2, 2)
    resize:SetSize(16, 16)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetHitRectInsets(-4, -4, -4, -4)
    resize:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not ParagonArenaCoachDB.locked then
            PAC_BreakdownFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function(self)
        PAC_BreakdownFrame:StopMovingOrSizing()
        PAC_SavePosition(PAC_BreakdownFrame, "breakdown")
    end)

    local title = PAC_BreakdownFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetText("PAC Breakdown")

    local sendBtn = CreateFrame("Button", nil, PAC_BreakdownFrame, "UIPanelButtonTemplate")
    sendBtn:SetSize(110, 20)
    sendBtn:SetPoint("TOPRIGHT", -30, -4)
    sendBtn:SetText("Send to Coach")

    local close = CreateFrame("Button", nil, PAC_BreakdownFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)

    local function MakeTab(xOffset, label, modeKey)
        local btn = CreateFrame("Button", nil, PAC_BreakdownFrame, "UIPanelButtonTemplate")
        btn:SetSize(70, 18)
        btn:SetPoint("TOPLEFT", PAC_BreakdownFrame, "TOPLEFT", xOffset, -26)
        btn:SetText(label)
        btn:SetScript("OnClick", function()
            PAC_BreakdownMode = modeKey
            UpdateBreakdown()
        end)
        return btn
    end

    PAC_BreakdownFrame.dmgTab  = MakeTab(10,  "Damage",  "damage")
    PAC_BreakdownFrame.hlgTab  = MakeTab(86,  "Healing", "healing")
    PAC_BreakdownFrame.ctrlTab = MakeTab(162, "Control", "control")

    local scrollFrame = CreateFrame("ScrollFrame", nil, PAC_BreakdownFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", -8, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    PAC_BreakdownFrame.scrollFrame = scrollFrame
    PAC_BreakdownFrame.content     = content

    sendBtn:SetScript("OnClick", function()
        PAC_SendCurrentRoundToCoachFromMeter()
    end)
end

function PAC_SendCurrentRoundToCoachFromMeter()
    if InCombatLockdown and InCombatLockdown() then
        PAC_Debug("Cannot send to Coach during combat. Try again after the round.")
        return
    end

    local src = selectedRoundForBreakdown or currentRound or ParagonArenaCoachDB.rounds[#ParagonArenaCoachDB.rounds]
    if not src or not src.stats then
        PAC_Debug("No round to send to Coach Chat from meter.")
        return
    end

    local summary = PAC_ComposeCoachSummary(src)
    if not summary then return end

    if not ParagonArenaCoachDB.enableAI then
        local npcComment = PAC_NPCEvaluateRound(src)
        if npcComment and npcComment ~= "" then
            summary = summary .. "\n\n" .. npcComment
        end
    end

    PAC_CoachChatAppend(summary)
    PAC_Debug("Sent round to PAC Coach Chat from meter (post-match review).")
end

function UpdateBreakdown()
    if not PAC_BreakdownFrame then return end

    local src = selectedRoundForBreakdown or currentRound or ParagonArenaCoachDB.rounds[#ParagonArenaCoachDB.rounds]
    if not src or not src.stats then
        if PAC_BreakdownFrame.content then
            PAC_BreakdownFrame.content:Hide()
        end
        return
    end

    local stats = src.stats
    local dur   = src.duration or 0
    if dur < 1 then dur = 1 end

    local dmg   = stats.damageDone   or 0
    local hlg   = stats.healingDone  or 0
    local dmgT  = stats.damageTaken  or 0
    local hlgT  = stats.healingTaken or 0
    local dps   = stats.dps or (dmg / dur)
    local hps   = stats.hps or (hlg / dur)
    local cc       = stats.cc        or 0
    local ccBreaks = stats.ccBreaks  or 0
    local kicks    = stats.interrupts or 0

    local parent  = PAC_BreakdownFrame.scrollFrame
    local content = PAC_BreakdownFrame.content
    if content then
        content:Hide()
    end
    content = CreateFrame("Frame", nil, parent)
    content:SetSize(1, 1)
    parent:SetScrollChild(content)
    PAC_BreakdownFrame.content = content

    local y = -4
    local lineHeight = 16

    local function AddLine(text)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 2, y)
        fs:SetWidth(380)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        y = y - lineHeight
    end

    AddLine(string.format(
        "%s - %s on %s (%.0fs)",
        src.result or "Unknown",
        src.mode   or "?",
        src.map    or "?",
        dur
    ))
    y = y - 4

    AddLine(string.format("Offense: %s dmg (%.0f DPS)",
        PAC_AbbrevNumber(dmg), dps))
    AddLine(string.format("Sustain: %s healing (%.0f HPS)",
        PAC_AbbrevNumber(hlg), hps))
    AddLine(string.format("Taken: %s dmg taken, %s healing taken",
        PAC_AbbrevNumber(dmgT), PAC_AbbrevNumber(hlgT)))
    y = y - 4

    AddLine(string.format("Control: CC %d, Breaks %d, Kicks %d",
        cc, ccBreaks, kicks))
    y = y - 8

    AddLine("Top spells")
    y = y - 4

    local list = {}

    if stats.spells and next(stats.spells) then
        for spell, bucket in pairs(stats.spells) do
            local include = true

            if PAC_BreakdownMode == "damage" then
                include = (bucket.nonCritTotal or 0) + (bucket.critTotal or 0) > 0
            elseif PAC_BreakdownMode == "healing" then
                include = (bucket.nonCritTotal or 0) + (bucket.critTotal or 0) > 0
            elseif PAC_BreakdownMode == "control" then
                include = false
            end

            if include then
                table.insert(list, {
                    spell   = spell,
                    total   = bucket.total        or 0,
                    hits    = bucket.hits         or 0,
                    crits   = bucket.crits        or 0,
                    nTotal  = bucket.nonCritTotal or 0,
                    cTotal  = bucket.critTotal    or 0,
                    maxHit  = bucket.maxHit       or 0,
                    maxCrit = bucket.maxCrit      or 0,
                })
            end
        end

        table.sort(list, function(a, b) return a.total > b.total end)

        AddLine(string.format(
            "%-24s %9s %5s %5s %9s %9s %9s %9s",
            "Spell", "Total", "H", "C", "NonCrit", "Crit", "MaxH", "MaxC"
        ))

        local shown = 0
        for _, row in ipairs(list) do
            if shown >= 12 then break end
            AddLine(string.format(
                "%-24s %9d %5d %5d %9d %9d %9d %9d",
                row.spell,
                row.total,
                row.hits,
                row.crits,
                row.nTotal,
                row.cTotal,
                row.maxHit,
                row.maxCrit
            ))
            shown = shown + 1
        end
    else
        AddLine("No spell data recorded for this round yet.")
    end

    content:SetHeight(-y + 10)
end

-- =========================================
-- Meter frame
-- =========================================

local function PAC_UpdateMeterModeButtons()
    if not PAC_MeterFrame or not PAC_MeterFrame.statsBtn or not PAC_MeterFrame.ccBtn then return end
    local statsBtn = PAC_MeterFrame.statsBtn
    local ccBtn    = PAC_MeterFrame.ccBtn

    local statsFS = statsBtn:GetFontString()
    local ccFS    = ccBtn:GetFontString()
    if not statsFS or not ccFS then return end

    if PAC_METER_MODE == "stats" then
        statsFS:SetTextColor(1, 1, 1)
        ccFS:SetTextColor(0.7, 0.7, 0.7)
    else
        statsFS:SetTextColor(0.7, 0.7, 0.7)
        ccFS:SetTextColor(1, 1, 1)
    end
end

local function PAC_CreateMeterFrame()
    if PAC_MeterFrame then return end

    PAC_MeterFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    PAC_MeterFrame:SetSize(380, 170)
    PAC_RestorePosition(PAC_MeterFrame, "meter", "TOPRIGHT", -50, -200)
    PAC_MeterFrame:Hide()

    PAC_MeterFrame:SetMovable(true)
    PAC_MeterFrame:SetResizable(true)
    PAC_MeterFrame:EnableMouse(true)
    if PAC_MeterFrame.SetResizeBounds then
        PAC_MeterFrame:SetResizeBounds(340, 140, 600, 260)
    end

    PAC_ApplyPanelSkin(PAC_MeterFrame)
    PAC_ApplyLockStateToFrame(PAC_MeterFrame)

    local theme = PAC_GetTheme()
    local m = theme.main
    local a = theme.accent

    PAC_MeterFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Project Astral Combatant", 1, 0.82, 0)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Impact", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("  Total damage + healing done this round.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Control", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("  Crowd control, breaks, and interrupts.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    PAC_MeterFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    -- Header
    local header = CreateFrame("Frame", nil, PAC_MeterFrame, "BackdropTemplate")
    header:SetPoint("TOPLEFT", PAC_MeterFrame, "TOPLEFT", 2, -2)
    header:SetPoint("TOPRIGHT", PAC_MeterFrame, "TOPRIGHT", -20, -2)
    header:SetHeight(18)

    header.tex = header:CreateTexture(nil, "BACKGROUND")
    header.tex:SetAllPoints(header)
    header.tex:SetColorTexture(m.r * 0.35, m.g * 0.35, m.b * 0.35, 0.9)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    title:SetPoint("LEFT", header, "LEFT", 4, 0)
    title:SetJustifyH("LEFT")
    title:SetText("Project: Astral – Combatant Meter")

    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function(self)
        if not ParagonArenaCoachDB.locked then
            PAC_MeterFrame:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function(self)
        PAC_MeterFrame:StopMovingOrSizing()
        PAC_SavePosition(PAC_MeterFrame, "meter")
    end)

    local dropdownMenu = CreateFrame("Frame", "PAC_MeterDropdown", UIParent, "UIDropDownMenuTemplate")

    local function PAC_MeterDropdown_Initialize(self, level)
        if not level then return end
        local info = UIDropDownMenu_CreateInfo()

        info.text = "View: Core"
        info.func = function()
            PAC_SetMeterMode("stats")
            PAC_UpdateMeterModeButtons()
            UpdateMeter()
        end
        info.checked = (PAC_METER_MODE == "stats")
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "View: Control"
        info.func = function()
            PAC_SetMeterMode("cc")
            PAC_UpdateMeterModeButtons()
            UpdateMeter()
        end
        info.checked = (PAC_METER_MODE == "cc")
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Open History"
        info.func = function()
            PAC_CreateHistoryFrame()
            PAC_UpdateHistory()
            PAC_HistoryFrame:Show()
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Open Rounds List"
        info.func = function()
            PAC_CreateListFrame()
            PAC_UpdateList()
            PAC_ListFrame:Show()
        end
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Send current round to Coach"
        info.func = function()
            PAC_SendCurrentRoundToCoachFromMeter()
        end
        UIDropDownMenu_AddButton(info, level)
    end

    UIDropDownMenu_Initialize(dropdownMenu, PAC_MeterDropdown_Initialize, "MENU")

    header:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            ToggleDropDownMenu(1, nil, dropdownMenu, "cursor", 0, 0)
        end
    end)

    local lockBtn = CreateFrame("Button", nil, header)
    lockBtn:SetSize(18, 18)
    lockBtn:SetPoint("RIGHT", header, "RIGHT", -22, 0)

    lockBtn.tex = lockBtn:CreateTexture(nil, "ARTWORK")
    lockBtn.tex:SetAllPoints()
    lockBtn:SetScale(1.5)

    local function PAC_UpdateLockIcon()
        if ParagonArenaCoachDB.locked then
            lockBtn.tex:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
        else
            lockBtn.tex:SetTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        end
    end

    lockBtn:SetScript("OnClick", function()
        ParagonArenaCoachDB.locked = not ParagonArenaCoachDB.locked
        PAC_ApplyLockStateToFrame(PAC_MeterFrame)
        PAC_SavePosition(PAC_MeterFrame, "meter")
        PAC_UpdateLockIcon()
        PAC_Debug("PAC frames lock state: " .. tostring(ParagonArenaCoachDB.locked))
    end)

    PAC_UpdateLockIcon()

    local close = CreateFrame("Button", nil, PAC_MeterFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", PAC_MeterFrame, "TOPRIGHT", -2, -2)
    close:SetScale(0.8)
    close:SetScript("OnClick", function() PAC_MeterFrame:Hide() end)

    -- Controls row
    local controls = CreateFrame("Frame", nil, PAC_MeterFrame)
    controls:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    controls:SetPoint("TOPRIGHT", PAC_MeterFrame, "TOPRIGHT", -2, -2)
    controls:SetHeight(18)

    local breakdownBtn = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    breakdownBtn:SetSize(18, 18)
    breakdownBtn:SetPoint("LEFT", controls, "LEFT", 2, 0)
    breakdownBtn:SetText("<")

    local sendBtn = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    sendBtn:SetSize(18, 18)
    sendBtn:SetPoint("LEFT", breakdownBtn, "RIGHT", 2, 0)
    sendBtn:SetText(">")

    PAC_MeterFrame.breakdownBtn = breakdownBtn
    PAC_MeterFrame.sendBtn      = sendBtn

    -- World PvP manual controls
    local wpvpStartBtn = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    wpvpStartBtn:SetSize(60, 16)
    wpvpStartBtn:SetPoint("LEFT", controls, "LEFT", 80, 0)
    wpvpStartBtn:SetText("Start WPvP")

    local wpvpEndBtn = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
    wpvpEndBtn:SetSize(50, 16)
    wpvpEndBtn:SetPoint("LEFT", wpvpStartBtn, "RIGHT", 2, 0)
    wpvpEndBtn:SetText("End")

    wpvpStartBtn:SetScript("OnClick", function()
        if currentRound then
            PAC_Debug("A round is already active; end it first if you want to restart.")
            return
        end
        StartNewRound("WorldPvP")
        PAC_Debug("Started WorldPvP round manually (button).")
        UpdateMeter()
    end)

    wpvpEndBtn:SetScript("OnClick", function()
        if currentRound then
            EndCurrentRound("manual")
            PAC_Debug("Ended current round manually (button).")
        else
            PAC_Debug("No active round to end.")
        end
    end)

    -- Body (single frame, with tooltip + bars + rows)
    local body = CreateFrame("Frame", nil, PAC_MeterFrame)
    body:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 2, -2)
    body:SetPoint("BOTTOMRIGHT", PAC_MeterFrame, "BOTTOMRIGHT", -2, 2)
    body:EnableMouse(true)

    body:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Project Astral Combatant", 1, 0.82, 0)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Impact", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("  Total damage + healing done this round.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Control", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("  Crowd control, breaks, and interrupts.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    body:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local bgTex = body:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints(body)
    bgTex:SetColorTexture(m.r * 0.15, m.g * 0.15, m.b * 0.15, 0.45)

    local bar = body:CreateTexture("PAC_MeterBar", "BORDER")
    bar:SetPoint("TOPLEFT", body, "TOPLEFT", 2, -2)
    bar:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, 2)
    bar:SetColorTexture(m.r, m.g, m.b, 0.22)
    PAC_MeterFrame.bar = bar

    local barButton = CreateFrame("Button", nil, body)
    barButton:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    barButton:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    barButton:SetScript("OnClick", function()
        PAC_CreateBreakdownFrame()
        local src = currentRound or ParagonArenaCoachDB.rounds[#ParagonArenaCoachDB.rounds]
        if not src then
            PAC_Debug("No rounds to show in Breakdown yet.")
            return
        end
        selectedRoundForBreakdown = src
        PAC_BreakdownFrame:Show()
        UpdateBreakdown()
    end)

    PAC_MeterFrame.text = body:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    PAC_MeterFrame.text:SetPoint("TOPLEFT", body, "TOPLEFT", 4, -4)
    PAC_MeterFrame.text:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -4)
    PAC_MeterFrame.text:SetJustifyH("LEFT")
	
	    -- Performance badge (top-right of body)
    PAC_MeterFrame.badge = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    PAC_MeterFrame.badge:SetPoint("TOPRIGHT", body, "TOPRIGHT", -4, -4)
    PAC_MeterFrame.badge:SetJustifyH("RIGHT")
    PAC_MeterFrame.badge:SetText("")

    local dmgBar = CreateFrame("StatusBar", nil, body)
    dmgBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    dmgBar:SetPoint("TOPLEFT", PAC_MeterFrame.text, "BOTTOMLEFT", 0, -4)
    dmgBar:SetPoint("TOPRIGHT", PAC_MeterFrame.text, "BOTTOMRIGHT", 0, -4)
    dmgBar:SetHeight(8)
    dmgBar:SetMinMaxValues(0, 1)
    dmgBar:SetValue(0)
    dmgBar:SetStatusBarColor(m.r, m.g, m.b, 0.85)
    PAC_MeterFrame.dmgBar = dmgBar

    local hlgBar = CreateFrame("StatusBar", nil, body)
    hlgBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    hlgBar:SetPoint("TOPLEFT", dmgBar, "BOTTOMLEFT", 0, -3)
    hlgBar:SetPoint("TOPRIGHT", dmgBar, "BOTTOMRIGHT", 0, -3)
    hlgBar:SetHeight(8)
    hlgBar:SetMinMaxValues(0, 1)
    hlgBar:SetValue(0)
    hlgBar:SetStatusBarColor(a.r, a.g, a.b, 0.5)
    PAC_MeterFrame.hlgBar = hlgBar

    PAC_MeterFrame.rows = PAC_MeterFrame.rows or {}

    local function CreateRow(index, anchorFrame, offsetY)
        local row = CreateFrame("StatusBar", nil, body, "BackdropTemplate")
        row:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
        row:SetMinMaxValues(0, 1)
        row:SetValue(0)
        row:SetHeight(16)
        row:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)
        row:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, offsetY)
        row:EnableMouse(true)

        row:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        row:SetBackdropColor(0, 0, 0, 0.60)

        local theme = PAC_GetTheme()
        local mm = theme.main
        row:SetBackdropBorderColor(mm.r, mm.g, mm.b, 0.85)

        local hl = row:CreateTexture(nil, "OVERLAY")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 0, 0.40)
        hl:Hide()
        row.highlight = hl

        row:SetScript("OnEnter", function(self)
            if self.highlight then self.highlight:Show() end
        end)
        row:SetScript("OnLeave", function(self)
            if self.highlight then self.highlight:Hide() end
        end)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", row, "LEFT", 6, 0)
        label:SetJustifyH("LEFT")

        local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        valueText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        valueText:SetJustifyH("RIGHT")

        row.label     = label
        row.valueText = valueText

        PAC_MeterFrame.rows[index] = row
    end

    CreateRow(1, hlgBar, -6)
    CreateRow(2, PAC_MeterFrame.rows[1], -6)

    for i, row in ipairs(PAC_MeterFrame.rows) do
        if i == 1 then
            row:SetStatusBarColor(1.0, 0.65, 0.0, 0.9)   -- Impact
        elseif i == 2 then
            row:SetStatusBarColor(0.2, 0.7, 1.0, 0.9)   -- Control
        else
            row:SetStatusBarColor(0.4, 0.4, 0.4, 0.3)
        end
    end

    local resize = CreateFrame("Button", nil, PAC_MeterFrame)
    resize:SetPoint("BOTTOMRIGHT", PAC_MeterFrame, "BOTTOMRIGHT", -2, 2)
    resize:SetSize(16, 16)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not ParagonArenaCoachDB.locked then
            self:GetParent():StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function(self)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        PAC_SavePosition(parent, "meter")
    end)

    breakdownBtn:SetScript("OnClick", function()
        PAC_CreateBreakdownFrame()
        PAC_BreakdownFrame:Show()
        UpdateBreakdown()
        PAC_Debug("PAC Breakdown opened from meter.")
    end)

    sendBtn:SetScript("OnClick", function()
        PAC_SendCurrentRoundToCoachFromMeter()
    end)

    PAC_UpdateMeterModeButtons()
end

local function PAC_GetRoleMode()
    local mode = ParagonArenaCoachDB and ParagonArenaCoachDB.roleMode
    if mode == "TANK" or mode == "HEALER" or mode == "DPS" then
        return mode
    end
    return "DPS"
end

function UpdateMeter()
    if not PAC_MeterFrame then
        PAC_CreateMeterFrame()
    end

        local src = currentRound

    if not src or not src.stats then
        src = ParagonArenaCoachDB.rounds[#ParagonArenaCoachDB.rounds]
    end

    if not src or not src.stats then
        PAC_MeterFrame.text:SetText("PAC Idle\nNo rounds yet.")
        for _, row in ipairs(PAC_MeterFrame.rows or {}) do
            row:SetValue(0)
            if row.label then row.label:SetText("") end
            if row.valueText then row.valueText:SetText("") end
        end
        PAC_MeterFrame:Show()
        return
    end

    local dur
    if src == currentRound then
        dur = GetTime() - (src.startTime or GetTime())
    else
        dur = src.duration or 0
    end
    if dur < 1 then dur = 1 end

    local stats = src.stats
    local dmg   = stats.damageDone    or 0
    local hlg   = stats.healingDone   or 0
    local dmgT  = stats.damageTaken   or 0
    local hlgT  = stats.healingTaken  or 0
    local mit   = stats.mitigated     or 0
    local dps   = stats.dps or (dmg / dur)
    local hps   = stats.hps or (hlg / dur)
    local cc        = stats.cc        or 0
    local ccBreaks  = stats.ccBreaks  or 0
    local kicks     = stats.interrupts or 0

    local prefix = (src == currentRound) and "PAC Live" or "PAC Last Round"
    local mode   = PAC_METER_MODE or "stats"
    local role   = PAC_GetRoleMode()

    -- Performance badge update
    if PAC_MeterFrame.badge then
        local badgeText, br, bg, bb = PAC_GetPerfBadge(src)
        PAC_MeterFrame.badge:SetText(badgeText)
        PAC_MeterFrame.badge:SetTextColor(br, bg, bb)
    end

    PAC_MeterFrame.text:SetText(string.format(
        "%s – %s (%.0fs)\nImpact %s / %s  •  Control CC %d Br %d K %d",
        prefix,
        src.mode or "?",
        dur,
        PAC_AbbrevNumber(dmg),
        PAC_AbbrevNumber(hlg),
        cc, ccBreaks, kicks
    ))

    local rows = PAC_MeterFrame.rows or {}
    local r1, r2 = rows[1], rows[2]

    if r1 then r1:Show() end
    if r2 then r2:Show() end
    for i = 3, 5 do
        if rows[i] then rows[i]:Hide() end
    end

    if r1 then
        r1.label:SetText("Impact")
        r1.valueText:SetText(string.format(
            "Dmg %s  •  Hlg %s",
            PAC_AbbrevNumber(dmg),
            PAC_AbbrevNumber(hlg)
        ))
        local impactVal = dmg + hlg
        local maxVal = impactVal > 0 and impactVal or 1
        r1:SetMinMaxValues(0, maxVal)
        r1:SetValue(impactVal)
    end

    if r2 then
        r2.label:SetText("Control")
        r2.valueText:SetText(string.format(
            "CC %d  •  Br %d  •  K %d",
            cc, ccBreaks, kicks
        ))
        r2:SetMinMaxValues(0, 1)
        r2:SetValue(1)
    end

    PAC_MeterFrame:Show()
    PAC_UpdateMeterModeButtons()
end

-- =========================================
-- History frame
-- =========================================

function PAC_CreateHistoryFrame()
    if PAC_HistoryFrame then return end

    PAC_HistoryFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    PAC_HistoryFrame:SetSize(360, 260)
    PAC_HistoryFrame:SetPoint("CENTER")
    PAC_ApplyPanelSkin(PAC_HistoryFrame)
    PAC_HistoryFrame:Hide()

    local title = PAC_HistoryFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -10)
    title:SetText("PAC History")

    local scrollFrame = CreateFrame("ScrollFrame", nil, PAC_HistoryFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -36)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)
    PAC_HistoryFrame.scrollFrame = scrollFrame
    PAC_HistoryFrame.content     = content

    local close = CreateFrame("Button", nil, PAC_HistoryFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
end

function PAC_UpdateHistory()
    if not PAC_HistoryFrame then return end
    local content = PAC_HistoryFrame.content

    local parent = content:GetParent()
    content:Hide()
    content = CreateFrame("Frame", nil, parent)
    content:SetSize(480, 1)
    parent:SetScrollChild(content)
    PAC_HistoryFrame.content = content

    local lineHeight = 20
    local y          = -5

    for _, round in ipairs(ParagonArenaCoachDB.rounds) do
        local line = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetPoint("TOPLEFT", 2, y)
        line:SetWidth(320)
        line:SetJustifyH("LEFT")

        local dps      = (round.stats and round.stats.dps) or 0
        local hps      = (round.stats and round.stats.hps) or 0
        local duration = round.duration or 0

        line:SetText(string.format(
            "%s: %s on %s (%.0fs) %s | DPS:%s HPS:%s",
            date("%H:%M", round.timestamp or time()),
            round.mode or "?",
            round.map  or "?",
            duration,
            round.result or "unknown",
            PAC_AbbrevNumber(dps),
            PAC_AbbrevNumber(hps)
        ))

        y = y - lineHeight
    end

    content:SetHeight(-y + 10)
end

-- =========================================
-- List frame (rounds overview)
-- =========================================

function PAC_CreateListFrame()
    if PAC_ListFrame then return end

    PAC_ListFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    PAC_ListFrame:SetSize(260, 260)
    PAC_ListFrame:SetPoint("CENTER", 0, -40)
    PAC_ApplyPanelSkin(PAC_ListFrame)
    PAC_ListFrame:Hide()

    local title = PAC_ListFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -6)
    title:SetText("PAC Rounds")

    local scrollFrame = CreateFrame("ScrollFrame", nil, PAC_ListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -24)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)
    scrollFrame:SetScrollChild(content)

    PAC_ListFrame.scrollFrame = scrollFrame
    PAC_ListFrame.content     = content

    local close = CreateFrame("Button", nil, PAC_ListFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
end

function PAC_UpdateList()
    if not PAC_ListFrame then return end
    local content = PAC_ListFrame.content

    local parent = content:GetParent()
    content:Hide()
    content = CreateFrame("Frame", nil, parent)
    content:SetSize(1, 1)
    parent:SetScrollChild(content)
    PAC_ListFrame.content = content

    local lineHeight = 18
    local y          = -2

    for index, round in ipairs(ParagonArenaCoachDB.rounds) do
        local btn = CreateFrame("Button", nil, content)
        btn:SetPoint("TOPLEFT", 0, y)
        btn:SetSize(210, lineHeight)
        btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetAllPoints()
        text:SetJustifyH("LEFT")

        local dps = (round.stats and round.stats.dps) or 0
        local hps = (round.stats and round.stats.hps) or 0

        text:SetText(string.format(
            "%s %s %s |D:%s H:%s",
            date("%H:%M", round.timestamp or time()),
            round.mode or "?",
            round.map or "?",
            PAC_AbbrevNumber(dps),
            PAC_AbbrevNumber(hps)
        ))

        btn:SetScript("OnClick", function()
            selectedRoundForBreakdown = round
            PAC_CreateBreakdownFrame()
            PAC_BreakdownFrame:Show()
            UpdateBreakdown()
        end)

        y = y - lineHeight
    end

    content:SetHeight(-y + 4)
end

-- =========================================
-- Options panel (Dragonflight/TWW Settings API)
-- =========================================

local function PAC_CreateOptionsPanel()
    local panel = CreateFrame("Frame", "PAC_OptionsPanel", UIParent)
    panel.name = "Project: Astral Combatant"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Project: Astral Combatant")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(520)
    sub:SetJustifyH("LEFT")
    sub:SetText("Core settings for round logging and PvE integration. PAC is a post-match coach: it logs your rounds, then lets you review them manually or with optional NPC/AI commentary (no automation or predictions).")

    local pveCheck = CreateFrame("CheckButton", "PAC_Options_EnablePvE", panel, "InterfaceOptionsCheckButtonTemplate")
    pveCheck:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -2, -12)
    pveCheck.Text:SetText("Enable generalized PvE rounds (dungeons/raids)")
    pveCheck.tooltipText = "If checked, PAC will log supported PvE instances as rounds in addition to PvP."

    pveCheck:SetScript("OnClick", function(self)
        ParagonArenaCoachDB.enablePvE = self:GetChecked() and true or false
    end)

    local dd = CreateFrame("Frame", "PAC_Options_PvEMinDiff", panel, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", pveCheck, "BOTTOMLEFT", -15, -10)

    local ddLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    ddLabel:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 16, 3)
    ddLabel:SetText("Minimum PvE difficulty to log")

    local function GetDifficultyText(key)
        if key == "heroic" then
            return "Heroic+ only"
        elseif key == "mythic" then
            return "Mythic/+ and raids"
        elseif key == "raid" then
            return "Raids only"
        else
            return "Any difficulty"
        end
    end

    local function SetDifficulty(key)
        ParagonArenaCoachDB.pveMinDifficulty = key
        UIDropDownMenu_SetText(dd, GetDifficultyText(key))
    end

    UIDropDownMenu_Initialize(dd, function(self, level)
        local info

        info = UIDropDownMenu_CreateInfo()
        info.text = "Any difficulty"
        info.func = function() SetDifficulty("none") end
        info.checked = (ParagonArenaCoachDB.pveMinDifficulty == "none")
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Heroic+ only"
        info.func = function() SetDifficulty("heroic") end
        info.checked = (ParagonArenaCoachDB.pveMinDifficulty == "heroic")
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Mythic/+ and raids"
        info.func = function() SetDifficulty("mythic") end
        info.checked = (ParagonArenaCoachDB.pveMinDifficulty == "mythic")
        UIDropDownMenu_AddButton(info, level)

        info = UIDropDownMenu_CreateInfo()
        info.text = "Raids only"
        info.func = function() SetDifficulty("raid") end
        info.checked = (ParagonArenaCoachDB.pveMinDifficulty == "raid")
        UIDropDownMenu_AddButton(info, level)
    end)

    local bossCheck = CreateFrame("CheckButton", "PAC_Options_PvEBossOnly", panel, "InterfaceOptionsCheckButtonTemplate")
    bossCheck:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 15, -8)
    bossCheck.Text:SetText("Log boss pulls only (skip trash where possible)")
    bossCheck.tooltipText = "Helps keep rounds list focused on meaningful encounters."

    bossCheck:SetScript("OnClick", function(self)
        ParagonArenaCoachDB.pveBossOnly = self:GetChecked() and true or false
    end)

    local aiCheck = CreateFrame("CheckButton", "PAC_Options_EnableAI", panel, "InterfaceOptionsCheckButtonTemplate")
    aiCheck:SetPoint("TOPLEFT", bossCheck, "BOTTOMLEFT", 0, -12)
    aiCheck.Text:SetText("Enable AI Coaching (optional, text-only analysis)")
    aiCheck.tooltipText = "If checked, PAC will prepare summaries suitable for external AI analysis. PAC itself never automates combat or suggests abilities in real time."

    aiCheck:SetScript("OnClick", function(self)
        ParagonArenaCoachDB.enableAI = self:GetChecked() and true or false
        PAC_UpdateCoachAIButtons()
    end)

    local autoSendCheck = CreateFrame("CheckButton", "PAC_Options_AutoSend", panel, "InterfaceOptionsCheckButtonTemplate")
    autoSendCheck:SetPoint("TOPLEFT", aiCheck, "BOTTOMLEFT", 0, -8)
    autoSendCheck.Text:SetText("Auto-send last round to Coach Chat when it ends")
    autoSendCheck.tooltipText = "Accessibility option: when enabled, PAC automatically posts a round summary (and NPC notes if AI is disabled) after a round ends. Still post-match, never in-combat."

    autoSendCheck:SetScript("OnClick", function(self)
        ParagonArenaCoachDB.autoSendToCoach = self:GetChecked() and true or false
    end)

    panel:SetScript("OnShow", function()
        pveCheck:SetChecked(ParagonArenaCoachDB.enablePvE ~= false)
        UIDropDownMenu_SetText(dd, GetDifficultyText(ParagonArenaCoachDB.pveMinDifficulty or "none"))
        bossCheck:SetChecked(ParagonArenaCoachDB.pveBossOnly and true or false)
        aiCheck:SetChecked(ParagonArenaCoachDB.enableAI and true or false)
        autoSendCheck:SetChecked(ParagonArenaCoachDB.autoSendToCoach and true or false)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category, layout = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        category.ID = panel.name
        Settings.RegisterAddOnCategory(category)
    end
end

-- =========================================
-- Midnight-safe event integration (no combat RegisterEvent in main chunk)
-- =========================================

local pacHasInitialized = false

local function PAC_InitUI()
    PAC_CreateMeterFrame()
    PAC_MeterFrame:Show()
    PAC_CreateBreakdownFrame()
    PAC_CreateHistoryFrame()
    PAC_CreateListFrame()
    PAC_CreateCoachChatFrame()
    PAC_ApplyLockStateAll()
    PAC_CreateOptionsPanel()
end

local function PAC_SafeInitOnce()
    if pacHasInitialized then return end
    pacHasInitialized = true

    if pacShowLoadMessage then
        PAC_Debug("Project Astral Combatant loaded (Midnight-safe init).")
    end

    PAC_InitUI()

    if pacNeedsWelcome and PAC_ShowWelcomeSplash then
        if C_Timer and C_Timer.After then
            C_Timer.After(2, PAC_ShowWelcomeSplash)
        else
            PAC_ShowWelcomeSplash()
        end
    end
end

if C_Timer and C_Timer.After then
    C_Timer.After(0, PAC_SafeInitOnce)
else
    PAC_SafeInitOnce()
end

-- COMBAT_LOG polling (disabled: CombatLogGetCurrentEventInfo not available in this client)
local function PAC_CombatLogPollTick()
    -- Stub to avoid errors on clients where CombatLogGetCurrentEventInfo is nil.
end

--[[  If/when CombatLogGetCurrentEventInfo is available and Midnight rules are clarified,
      this ticker can be re-enabled and OnCombatLogEvent restored.
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(0.2, PAC_CombatLogPollTick)
end
]]

-- Zone / instance checks
local function PAC_ZoneCheckTick()
    local mode = PAC_GetInstanceMode()  -- "Arena","Battleground","Dungeon","Raid","Scenario", or nil

    if mode and not currentRound then
        if PAC_IsPvPInstanceMode(mode) then
            -- Always log Arenas/BGs
            StartNewRound(mode)
        elseif ParagonArenaCoachDB.enablePvE then
            -- Generalized PvE, opt‑in
            StartNewRound(mode)
        end

    elseif not mode and currentRound then
        -- Leaving an instance: end any instance-based round
        if PAC_IsPvPInstanceMode(currentRound.mode) or ParagonArenaCoachDB.enablePvE then
            EndCurrentRound("unknown")
        end
    end
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(5, PAC_ZoneCheckTick)
end

-- Duel detection via system messages
local function PAC_SystemMessageHook(_, msg)
    if not msg then return end

    if msg:find("has challenged you to a duel") then
        duelActive = true
        if not currentRound then
            StartNewRound("Duel")
        end
    elseif msg:find("wins the duel") or msg:find("wins the duel!") then
        if currentRound and currentRound.mode == "Duel" then
            EndCurrentRound("unknown")
        end
        duelActive = false
    end
end

if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", PAC_SystemMessageHook)
end

-- Combat end auto-end for WorldPvP
local function PAC_CombatEndCheckTick()
    if currentRound and currentRound.mode == "WorldPvP" then
        if not InCombatLockdown or not InCombatLockdown() then
            EndCurrentRound("unknown")
            PAC_Debug("Auto-ended WorldPvP round after leaving combat (timer).")
        end
    end
end

if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(4, PAC_CombatEndCheckTick)
end

-- =========================================
-- Slash commands
-- =========================================

local function PAC_AddCoachNote(text)
    if not text or text == "" then return end
    ParagonArenaCoachDB.coachNotes = ParagonArenaCoachDB.coachNotes or {}
    table.insert(ParagonArenaCoachDB.coachNotes, {
        ts   = time(),
        note = text,
    })
    PAC_Debug("Coach note saved: " .. text)
end

SLASH_PAC1 = "/pac"

SlashCmdList["PAC"] = function(msg)
    msg = msg or ""
    local cmd = string.match(msg, "^(%S+)") or ""
    cmd = string.lower(cmd)

    if cmd == "" then
        PAC_Debug("PAC loaded. Use /pac help for commands.")

    elseif cmd == "debug" then
        local sub = msg:match("^%S+%s+(%S+)")
        sub = sub and string.lower(sub) or ""

        if sub == "on" then
            ParagonArenaCoachDB.debugEnabled = true
            print("|cff66ccffPAC|r debug: |cff00ff00ON|r")
        elseif sub == "off" then
            ParagonArenaCoachDB.debugEnabled = false
            print("|cff66ccffPAC|r debug: |cffff0000OFF|r")
        else
            local state = ParagonArenaCoachDB.debugEnabled and "ON" or "OFF"
            print("|cff66ccffPAC|r debug is currently " .. state .. ". Use /pac debug on or /pac debug off.")
        end

    elseif cmd == "current" and currentRound then
        PAC_Debug("Current round mode=" .. tostring(currentRound.mode) ..
                  " result=" .. tostring(currentRound.result))

    elseif cmd == "toggle" then
        PAC_CreateMeterFrame()
        if PAC_MeterFrame:IsShown() then
            PAC_MeterFrame:Hide()
            PAC_Debug("PAC Meter hidden.")
        else
            UpdateMeter()
            PAC_Debug("PAC Meter shown.")
        end

    elseif cmd == "reset" then
        if currentRound then
            EndCurrentRound("manual")
            PAC_Debug("Manual round end.")
        else
            PAC_Debug("No active round to reset.")
        end

    elseif cmd == "history" then
        PAC_CreateHistoryFrame()
        PAC_HistoryFrame:Show()
        PAC_UpdateHistory()
        PAC_Debug("PAC History shown.")

    elseif cmd == "breakdown" then
        PAC_CreateBreakdownFrame()
        if PAC_BreakdownFrame:IsShown() then
            PAC_BreakdownFrame:Hide()
            PAC_Debug("PAC Breakdown hidden.")
        else
            PAC_BreakdownFrame:Show()
            UpdateBreakdown()
            PAC_Debug("PAC Breakdown shown.")
        end

    elseif cmd == "lock" then
        ParagonArenaCoachDB.locked = true
        PAC_ApplyLockStateAll()
        PAC_Debug("PAC frames locked.")

    elseif cmd == "unlock" then
        ParagonArenaCoachDB.locked = false
        PAC_ApplyLockStateAll()
        PAC_Debug("PAC frames unlocked.")

    elseif cmd == "note" then
        local noteText = msg:match("^%S+%s+(.+)$")
        if noteText and noteText ~= "" then
            PAC_AddCoachNote(noteText)
        else
            PAC_Debug("Usage: /pac note <text>")
        end

    elseif cmd == "notes" then
        ParagonArenaCoachDB.coachNotes = ParagonArenaCoachDB.coachNotes or {}
        if #ParagonArenaCoachDB.coachNotes == 0 then
            PAC_Debug("No coach notes saved yet.")
        else
            local last = ParagonArenaCoachDB.coachNotes[#ParagonArenaCoachDB.coachNotes]
            PAC_Debug(string.format("Last note @ %s: %s", date("%H:%M", last.ts), last.note))
        end

    elseif cmd == "coach" then
        PAC_CreateCoachChatFrame()
        if PAC_CoachChatFrame:IsShown() then
            PAC_CoachChatFrame:Hide()
            PAC_Debug("PAC Coach Chat hidden.")
        else
            PAC_CoachChatFrame:Show()
            PAC_Debug("PAC Coach Chat shown.")
        end

    elseif cmd == "list" then
        PAC_CreateListFrame()
        if PAC_ListFrame:IsShown() then
            PAC_ListFrame:Hide()
            PAC_Debug("PAC List hidden.")
        else
            PAC_ListFrame:Show()
            PAC_UpdateList()
            PAC_Debug("PAC List shown.")
        end

    elseif cmd == "clear" or cmd == "clearhistory" then
        ParagonArenaCoachDB.rounds = ParagonArenaCoachDB.rounds or {}
        local count = #ParagonArenaCoachDB.rounds
        wipe(ParagonArenaCoachDB.rounds)
        selectedRoundForBreakdown = nil
        if PAC_HistoryFrame and PAC_HistoryFrame:IsShown() then
            PAC_UpdateHistory()
        end
        if PAC_ListFrame and PAC_ListFrame:IsShown() then
            PAC_UpdateList()
        end
        PAC_Debug("Cleared " .. tostring(count) .. " stored rounds.")

    else
        PAC_Debug("PAC commands: debug on/off, current, toggle, reset, history, breakdown, list, lock, unlock, note, notes, coach, clear")
        print("PAC commands: /pac debug on|off, current, toggle, reset, history, breakdown, list, lock, unlock, note, notes, coach, clear")
    end
end
