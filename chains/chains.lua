--[[
* Chains displays current skillchains for the active target.
* It is based on the skillchains addon by Ivaar for Ashita v3.
*
* Several functions are leveraged from LuAshitacast by Thorny
* ParseActionPacket function is leveraged from timers by The Mystic
*
* Chains is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Chains is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name     = 'chains';
addon.author   = 'Sippius, Ivaar, and NerfOnline';
addon.version  = '0.85d-Pre-release';
addon.desc     = 'Display current skillchain options.';

require('common');
local ffi = require('ffi');
local chat = require('chat');
local imgui = require('imgui');
local settings = require('settings');
local skills = require('skills');
local pets = require('pets');

local function ApplyFontScale(scale)
    imgui.PushFont(imgui.GetFont(), imgui.GetFontSize() * scale)
end

local function UnapplyFontScale()
    imgui.PopFont()
end

--=============================================================================
-- Addon Variables
--=============================================================================
local default_settings = T{
    position_x = 100,
    position_y = 100,
    font_scale = 1.0,
    direction = 'top', -- 'top' (top-down) or 'bottom' (bottom-up)
    ability = false, -- require Chain Affinity, Azure Lore, or Immanence
    smn = true, -- require the matching avatar to be summoned
    bst = true, -- require the matching jug pet to be out
    pup = true, -- require the matching automaton frame to be out
    display = T{
        color = true,
        pet = true,
        spell = true,
        weapon = true,
    },
};

local chains = T{
    settings = settings.load(default_settings),
    editor = false, -- settings window from /chains, which also shows the preview
    previewTarget = nil,
    position = nil,
    lastWindowHeight = 0,

    forceAeonic = 0, -- set from 0 to 3
    forceImmanence = false, -- boolean
    forceAffinity = false, -- boolean
};

-- store player ID
-- * capture on init
local playerID;

-- store list of valid player/pet skills
-- * capture bluskill on every GetSkillchains call (set spells can change anytime)
-- * capture wepskill on 0xAC packet or first GetSkillchains call
-- * capture petskill on every GetSkillchains call (summoned avatar can change anytime)
-- * capture schskill on load
local actionTable = T{
    schskill = skills.immanence,
};

-- store per player buff information
-- * player/buff added through action packet
-- * buff deleted through action packet when used or through presentevent on timeout
-- * player deleted through present event when no buff active
local playerTable = T{
};

-- store per target information on properties and duration
-- * target added through action packet
-- * target deleted through present event on timeout
local targetTable = T{
};

-- static information on skillchains
local chainInfo = T{
    Radiance = T{level = 4, burst = T{'Fire','Wind','Lightning','Light'}},
    Umbra    = T{level = 4, burst = T{'Earth','Ice','Water','Dark'}},
    Light    = T{level = 3, burst = T{'Fire','Wind','Lightning','Light'},
        aeonic = T{level = 4, skillchain = 'Radiance'},
        Light  = T{level = 4, skillchain = 'Light'},
    },
    Darkness = T{level = 3, burst = T{'Earth','Ice','Water','Dark'},
        aeonic   = T{level = 4, skillchain = 'Umbra'},
        Darkness = T{level = 4, skillchain = 'Darkness'},
    },
    Gravitation = T{level = 2, burst = T{'Earth','Dark'},
        Distortion    = T{level = 3, skillchain = 'Darkness'},
        Fragmentation = T{level = 2, skillchain = 'Fragmentation'},
    },
    Fragmentation = T{level = 2, burst = T{'Wind','Lightning'},
        Fusion     = T{level = 3, skillchain = 'Light'},
        Distortion = T{level = 2, skillchain = 'Distortion'},
    },
    Distortion = T{level = 2, burst = T{'Ice','Water'},
        Gravitation = T{level = 3, skillchain = 'Darkness'},
        Fusion      = T{level = 2, skillchain = 'Fusion'},
    },
    Fusion = T{level = 2, burst = T{'Fire','Light'},
        Fragmentation = T{level = 3, skillchain = 'Light'},
        Gravitation   = T{level = 2, skillchain = 'Gravitation'},
    },
    Compression = T{level = 1, burst = T{'Darkness'},
        Transfixion = T{level = 1, skillchain = 'Transfixion'},
        Detonation  = T{level = 1, skillchain = 'Detonation'},
    },
    Liquefaction = T{level = 1, burst = T{'Fire'},
        Impaction = T{level = 2, skillchain = 'Fusion'},
        Scission  = T{level = 1, skillchain = 'Scission'},
    },
    Induration = T{level = 1, burst = T{'Ice'},
        Reverberation = T{level = 2, skillchain = 'Fragmentation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
        Impaction     = T{level = 1, skillchain = 'Impaction'},
    },
    Reverberation = T{level = 1, burst = T{'Water'},
        Induration = T{level = 1, skillchain = 'Induration'},
        Impaction  = T{level = 1, skillchain = 'Impaction'},
    },
    Transfixion = T{level = 1, burst = T{'Light'},
        Scission      = T{level = 2, skillchain = 'Distortion'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
    },
    Scission = T{level = 1, burst = T{'Earth'},
        Liquefaction  = T{level = 1, skillchain = 'Liquefaction'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Detonation    = T{level = 1, skillchain = 'Detonation'},
    },
    Detonation = T{level = 1, burst = T{'Wind'},
        Compression = T{level = 2, skillchain = 'Gravitation'},
        Scission    = T{level = 1, skillchain = 'Scission'},
    },
    Impaction = T{level = 1, burst = T{'Lightning'},
        Liquefaction = T{level = 1, skillchain = 'Liquefaction'},
        Detonation   = T{level = 1, skillchain = 'Detonation'},
    },
};

-- IMGUI RGB color format {red, green, blue, alpha}
local colors = {};           -- Color codes by Sammeh
colors.Light =         { 1.0, 1.0, 1.0, 1.0 }; --'0xFFFFFFFF';
colors.Dark =          { 0.0, 0.0, 0.8, 1.0 }; --'0x0000CCFF';
colors.Ice =           { 0.0, 1.0, 1.0, 1.0 }; --'0x00FFFFFF';
colors.Water =         { 0.0, 1.0, 1.0, 1.0 }; --'0x00FFFFFF';
colors.Earth =         { 0.6, 0.5, 0.0, 1.0 }; --'0x997600FF';
colors.Wind =          { 0.4, 1.0, 0.4, 1.0 }; --'0x66FF66FF';
colors.Fire =          { 1.0, 0.0, 0.0, 1.0 }; --'0xFF0000FF';
colors.Lightning =     { 1.0, 0.0, 1.0, 1.0 }; --'0xFF00FFFF';
colors.Gravitation =   { 0.4, 0.2, 0.0, 1.0 }; --'0x663300FF';
colors.Fragmentation = { 1.0, 0.6, 1.0, 1.0 }; --'0xFA9CF7FF';
colors.Fusion =        { 1.0, 0.4, 0.4, 1.0 }; --'0xFF6666FF';
colors.Distortion =    { 0.2, 0.6, 1.0, 1.0 }; --'0x3399FFFF';
colors.Darkness =      colors.Dark;
colors.Umbra =         colors.Dark;
colors.Compression =   colors.Dark;
colors.Radiance =      colors.Light;
colors.Transfixion =   colors.Light;
colors.Induration =    colors.Ice;
colors.Reverberation = colors.Water;
colors.Scission =      colors.Earth;
colors.Detonation =    colors.Wind;
colors.Liquefaction =  colors.Fire;
colors.Impaction =     colors.Lightning;
colors.Ready =         { 1.0, 1.0, 1.0, 1.0 };
colors.Unavailable =   { 0.65, 0.65, 0.65, 1.0 };

local statusID = {
    AL  = 163, -- Azure Lore
    CA  = 164, -- Chain Affinity
    AM1 = 270, -- Aftermath: Lv.1
    AM2 = 271, -- Aftermath: Lv.2
    AM3 = 272, -- Aftermath: Lv.3
    IM  = 470  -- Immanence
};

local MessageTypes = T{
    2,   -- '<caster> casts <spell>. <target> takes <amount> damage'
  --100, -- 'The <player> uses ..' -- Causes Super Jump to match as Spinning Axe if enabled
    110, -- '<user> uses <ability>. <target> takes <amount> damage.'
  --161, -- Additional effect: <number> HP drained from <target>.
  --162, -- Additional effect: <number> MP drained from <target>.
    185, -- 'player uses, target takes 10 damage. DEFAULT'
    187, -- '<user> uses <skill>. <amount> HP drained from <target>'
    317, -- 'The <player> uses .. <target> takes .. points of damage.'
  --529, -- '<user> uses <ability>. <target> is chainbound.',
    802  -- 'The <user> uses <skill>. <number> HP drained from <target>.'
}

local PetMessageTypes = T{
    110, -- '<user> uses <ability>. <target> takes <amount> damage.'
    317  -- 'The <player> uses .. <target> takes .. points of damage.'
};

local ChainBuffTypes = T{
    [statusID.AL] = { duration = 30 }, -- 40 with relic hands
    [statusID.CA] = { duration = 30 },
    [statusID.IM] = { duration = 60 }
};

local EquipSlotNames = T{
    [1] = 'Main',
    --[2] = 'Sub',
    [3] = 'Range',
    --[4] = 'Ammo',
    --[5] = 'Head',
    --[6] = 'Body',
    --[7] = 'Hands',
    --[8] = 'Legs',
    --[9] = 'Feet',
    --[10] = 'Neck',
    --[11] = 'Waist',
    --[12] = 'Ear1',
    --[13] = 'Ear2',
    --[14] = 'Ring1',
    --[15] = 'Ring2',
    --[16] = 'Back'
};

local SkillPropNames = T{
    [1] = 'Light',
    [2] = 'Darkness',
    [3] = 'Gravitation',
    [4] = 'Fragmentation',
    [5] = 'Distortion',
    [6] = 'Fusion',
    [7] = 'Compression',
    [8] = 'Liquefaction',
    [9] = 'Induration',
    [10] = 'Reverberation',
    [11] = 'Transfixion',
    [12] = 'Scission',
    [13] = 'Detonation',
    [14] = 'Impaction',
    [15] = 'Radiance',
    [16] = 'Umbra'
};

--=============================================================================
-- Registers a callback for the settings to monitor for character switches.
--=============================================================================
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        chains.settings = s;
    end

    -- Older settings files may be missing newer options.
    if chains.settings.display == nil then
        chains.settings.display = T{};
    end
    for key, value in pairs(default_settings) do
        if key ~= 'display' and chains.settings[key] == nil then
            chains.settings[key] = value;
        end
    end
    for key, value in pairs(default_settings.display) do
        if chains.settings.display[key] == nil then
            chains.settings.display[key] = value;
        end
    end

    settings.save();
end);

--=============================================================================
-- Return color format table
---@param t string Skillchain property
---@return table
--=============================================================================
-- based on code from skillchains by Ivaar
--=============================================================================
local function GetPropertyColor(t)
    if chains.settings.display.color then
        return colors[t]
    end
    return { 1.0, 1.0, 1.0, 1.0 };
end

--=============================================================================
-- Return count of requested buff. Return zero if buff is not active.
---@param matchBuff string Name of buff to check
---@return integer count 
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
local GetBuffCount = function(matchBuff)
    local count = 0;
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
    if (type(matchBuff) == 'string') then
        local matchText = string.lower(matchBuff);
        for _, buff in pairs(buffs) do
            local buffString = AshitaCore:GetResourceManager():GetString("buffs.names", buff);
            if (buffString ~= nil) and (string.lower(buffString) == matchText) then
                count = count + 1;
            end
        end
    elseif (type(matchBuff) == 'number') then
        for _, buff in pairs(buffs) do
            if (buff == matchBuff) then
                count = count + 1;
            end
        end
    end
    return count;
end

--=============================================================================
-- Return equipment data
---@return table equipTable Current equipment information
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
-- Combined gData.GetEquipment and gEquip.GetCurrentEquip
--=============================================================================
local GetEquipment = function()
    local inventoryManager = AshitaCore:GetMemoryManager():GetInventory();
    local equipTable = {};

    for k, v in pairs(EquipSlotNames) do
        local equippedItem = inventoryManager:GetEquippedItem(k - 1);
        local index = bit.band(equippedItem.Index, 0x00FF);
        local eqEntry = {};
        if (index == 0) then
            eqEntry.Container = 0;
            eqEntry.Item = nil;
        else
            eqEntry.Container = bit.band(equippedItem.Index, 0xFF00) / 256;
            eqEntry.Item = inventoryManager:GetContainerItem(eqEntry.Container, index);
            if (eqEntry.Item.Id == 0) or (eqEntry.Item.Count == 0) then
                eqEntry.Item = nil;
            end
        end
        if (type(eqEntry) == 'table') and (eqEntry.Item ~= nil) then
            local resource = AshitaCore:GetResourceManager():GetItemById(eqEntry.Item.Id);
            if (resource ~= nil) then
                local singleTable = {};
                singleTable.Container = eqEntry.Container;
                singleTable.Item = eqEntry.Item;
                singleTable.Name = resource.Name[1];
                singleTable.Resource = resource;
                equipTable[v] = singleTable;
            end
        end
    end

    return equipTable;
end

--=============================================================================
-- Return player data
---@return table playerTable Current player information
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
local GetPlayer = function()
    local playerTable = {};
    local pParty = AshitaCore:GetMemoryManager():GetParty();
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();

    local mainJob = pPlayer:GetMainJob();
    playerTable.MainJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mainJob);
    playerTable.MainJobLevel = pPlayer:GetJobLevel(mainJob);
    playerTable.MainJobSync = pPlayer:GetMainJobLevel();
    playerTable.Name = pParty:GetMemberName(0);

    local subJob = pPlayer:GetSubJob();
    playerTable.SubJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", subJob);
    playerTable.SubJobLevel = pPlayer:GetJobLevel(subJob);
    playerTable.SubJobSync = pPlayer:GetSubJobLevel();
    playerTable.TP = pParty:GetMemberTP(0);

    return playerTable;
end

--=============================================================================
-- Return table with current weaponskill data
---@return table skillTable Currently available weapon skills
--=============================================================================
local GetWeaponskills = function()
    local skillTable = T{};
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();

    for k,v in pairs(skills[3]) do
        if v and pPlayer:HasWeaponSkill(k) then
            skillTable:append(v);
        end
    end

    return skillTable;
end

--=============================================================================
-- Return the name of the player's currently summoned pet
---@return string|nil petName
--=============================================================================
local function GetCurrentPetName()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    local playerIndex = party:GetMemberTargetIndex(0);
    local petIndex = entity:GetPetTargetIndex(playerIndex);

    if petIndex == 0 then
        return nil;
    end

    return entity:GetName(petIndex);
end

--=============================================================================
-- Return true if a skill row has skillchain properties.
-- A row without them must not open a window.
---@param skill table|nil
---@return boolean
--=============================================================================
local function hasSkillchain(skill)
    return skill and skill.skillchain and skill.skillchain[1] ~= nil;
end

-- The client can cut a pet name off after 15 characters, so jugs are
-- looked up by the first 15 characters of the name.
local jugsByPrefix = {};
for name, jug in pairs(pets.jugs) do
    jugsByPrefix[name:sub(1, 15)] = jug;
end

--=============================================================================
-- Return the jug pet entry for a pet name.
---@param petName string|nil
---@return table|nil
--=============================================================================
local function FindJug(petName)
    return petName and jugsByPrefix[petName:sub(1, 15)] or nil;
end

--=============================================================================
-- Client job data buffer. Holds the BLU spell set, or the PUP head, frame,
-- and attachments. Based on blusets by Atom0s and PUPViewer.
-- offset stays nil if the signature isn't found (e.g. after a client update).
--=============================================================================
local jobData = {};
do
    local address = ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    if address ~= 0 then
        jobData.offset = ffi.cast('uint32_t*', address);
    end
end

-- Last PUP 0x044 packet values. The frame is used when the buffer can't be read.
-- The skills are the automaton's own, already capped by frame and PUP level.
local pupPacket = { frame = 0, melee = nil, ranged = nil };

--=============================================================================
-- Return the job data buffer as a table of bytes.
---@param count number
---@return table|nil
--=============================================================================
local function ReadJobData(count)
    if not jobData.offset then
        return nil;
    end
    local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then
        return nil;
    end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then
        return nil;
    end
    return ashita.memory.read_array((ptr + jobData.offset[0]) + 0x04, count);
end

--=============================================================================
-- Return the pets.frames entry for the equipped automaton frame.
-- The buffer only holds PUP data while PUP is the main job.
---@return table|nil frame
--=============================================================================
local function GetAutomatonFrame()
    local frameByte = pupPacket.frame;
    if AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == 18 then
        local data = ReadJobData(2);
        if data and data[2] and data[2] ~= 0 then
            frameByte = data[2];
        end
    end

    -- Frame item ids are 0x2000 plus the frame byte.
    for _, frame in pairs(pets.frames) do
        if frame.item == 0x2000 + frameByte then
            return frame;
        end
    end
    return nil;
end

--=============================================================================
-- Return the automaton's skill. Sharpshot uses ranged, the rest melee.
-- The player's own skill is only capped by main job level, so it runs too
-- high on /PUP. It is only used until the first 0x044 packet arrives.
---@param ranged boolean
---@return number
--=============================================================================
local function GetAutomatonSkill(ranged)
    local fromPacket = ranged and pupPacket.ranged or pupPacket.melee;
    if fromPacket then
        return fromPacket;
    end
    local skill = AshitaCore:GetMemoryManager():GetPlayer():GetCombatSkill(ranged and 23 or 22);
    return skill and skill:GetSkill() or 0;
end

-- BST and PUP rows are shared tables, so each list entry is a small copy
-- that remembers which pet move it came from.
local function PetAction(skill, id, kind)
    return { en = skill.en, skillchain = skill.skillchain, id = id, kind = kind };
end

--=============================================================================
-- Return whether the player has learned an avatar's summon spell
---@param avatar string
---@return boolean
--=============================================================================
local function HasAvatar(avatar)
    local spell = AshitaCore:GetResourceManager():GetSpellByName(avatar, 0);
    return spell ~= nil
        and AshitaCore:GetMemoryManager():GetPlayer():HasSpell(spell.Index);
end

--=============================================================================
-- Return available SMN pet skills based on ownership, level, and settings
---@return table skillTable Currently available pet skills
--=============================================================================
local function GetPetskills()
    local skillTable = T{};
    local player = GetPlayer();
    local smnLevel = player.MainJob == 'SMN' and player.MainJobSync
        or player.SubJob == 'SMN' and player.SubJobSync
        or 0;
    local currentPet = GetCurrentPetName();

    for _, skill in pairs(skills[13]) do
        local meetsLevel = skill.level ~= nil and smnLevel >= skill.level;
        local meetsSummonRequirement = not chains.settings.smn
            or currentPet == skill.avatar;

        -- HasAvatar is a name lookup, so it goes last
        if meetsLevel and meetsSummonRequirement and HasAvatar(skill.avatar) then
            skillTable:append(skill);
        end
    end

    return skillTable;
end

--=============================================================================
-- Return BST Ready moves. With /chains bst on, only the current jug's moves.
---@param currentJug table|nil From FindJug
---@return table skillTable
--=============================================================================
local function GetBstskills(currentJug)
    local skillTable = T{};
    if not skills.bst then
        return skillTable;
    end

    local jug = chains.settings.bst and (currentJug or {});

    for id, skill in pairs(skills.bst) do
        if hasSkillchain(skill) and (not jug or jug[id]) then
            skillTable:append(PetAction(skill, id, 'bst'));
        end
    end

    return skillTable;
end

--=============================================================================
-- Return automaton weaponskills the automaton has the skill to use.
-- With /chains pup on, only the equipped frame's weaponskills.
---@param currentFrame table|nil From GetAutomatonFrame
---@return table skillTable
--=============================================================================
local function GetPupskills(currentFrame)
    local skillTable = T{};
    if not skills.pup then
        return skillTable;
    end

    local frames = pets.frames;
    if chains.settings.pup then
        frames = { currentFrame };
    end

    local melee = GetAutomatonSkill(false);
    local ranged = GetAutomatonSkill(true);
    local added = {};

    for _, frame in pairs(frames) do
        local skillLevel = frame.ranged and ranged or melee;
        for id, required in pairs(frame) do
            local skill = skills.pup[id];
            if type(id) == 'number' and not added[id] and hasSkillchain(skill) and skillLevel >= required then
                skillTable:append(PetAction(skill, id, 'pup'));
                added[id] = true;
            end
        end
    end

    return skillTable;
end

--=============================================================================
-- Returns the table of current set BLU spells.
---@return table skillTable The current set BLU spells.
--=============================================================================
local function GetBluskills()
    local skillTable = T{};

    for _,v in pairs(ReadJobData(0x14) or {}) do
        if skills[4] and skills[4][v+512] then
            skillTable:append(skills[4][v+512]);
        end
    end

    return skillTable;
end

--=============================================================================
---Return current aftermath level
---@return integer
--=============================================================================
local GetAftermathLevel = function()
    return GetBuffCount(statusID.AM1) + 2*GetBuffCount(statusID.AM2) + 3*GetBuffCount(statusID.AM3) + chains.forceAeonic;
end

--=============================================================================
---Return action property table with aeonic property added
---@param action table Action information
---@param actor integer Actor ID
---@return table propertyTable Updated property table
--=============================================================================
local GetAeonicProperty = function(action, actor)
    local propertyTable = table.copy(action.skillchain);

    if action.aeonic and (action.weapon or chains.forceAeonic > 0) and actor == playerID and GetAftermathLevel()>0 then
        local main = GetEquipment().Main;
        local range = GetEquipment().Range;
        local validMain = action.weapon == (main and main.Name) or chains.forceAeonic > 0;
        local validRange = action.weapon == (range and range.Name);
        if validMain or validRange then
            table.insert(propertyTable,1,action.aeonic);
        end
    end

    return propertyTable;
end

--=============================================================================
-- Example closers for the settings preview.
-- One of each pet is assumed out. Turning that requirement off shows the other.
---@return table skillchains
--=============================================================================
local function GetPreviewSkillchains()
    local function row(skill, ready)
        return {
            outName = ('%-17s'):fmt(skill.en),
            outText = '>> Lv.2',
            outProp = skill.skillchain[1],
            ready = ready,
        };
    end

    local weapon = T{};
    local spell = T{};
    local pet = T{};
    local display = chains.settings.display;

    if display.weapon then
        weapon:append(row(skills[3][64], true)); -- Raging Axe
        weapon:append(row(skills[3][65], true)); -- Smash Axe
    end

    -- Ability on means the spells are listed, but not usable without the buff.
    if display.spell then
        local ready = not chains.settings.ability;
        spell:append(row(skills[4][643], ready)); -- Cannonball
        spell:append(row(skills[4][611], ready)); -- Disseverment
    end

    if display.pet then
        pet:append(row(skills[13][544], true)); -- Punch, Ifrit
        if not chains.settings.smn then
            pet:append(row(skills[13][592], false)); -- Claw, Garuda
        end

        -- Horizon has no jug pet data.
        if skills.bst then
            pet:append(row(skills.bst[3857], true)); -- Lamb Chop, Sheep Familiar
            if not chains.settings.bst then
                pet:append(row(skills.bst[3840], false)); -- Foot Kick, Hare Familiar
            end
        end

        pet:append(row(skills.pup[1942], true)); -- Arcuballista, Sharpshot
        if not chains.settings.pup then
            pet:append(row(skills.pup[1943], false)); -- Slapstick, Harlequin
        end
    end

    return T{ weapon = weapon, spell = spell, pet = pet };
end

--=============================================================================
-- Build a looping first-step target for the settings preview
---@return table
--=============================================================================
local function CreatePreviewTarget()
    local spinningAxe = skills[3][68];
    local delay = spinningAxe.delay or 3;
    return {
        en = spinningAxe.en,
        property = table.copy(spinningAxe.skillchain),
        ts = os.time(),
        dur = 7 + delay,
        wait = delay,
        step = 1,
    };
end

--=============================================================================
-- Return the pixel width of a text string using the current font
---@param text string
---@return number
--=============================================================================
local function GetTextWidth(text)
    local width = imgui.CalcTextSize(text);
    if type(width) == 'table' then
        return width[1] or width.x or 0;
    end
    return width or 0;
end

--=============================================================================
-- Draw a single line of text centered in the current window
---@param text string
--=============================================================================
local function DrawCenteredText(text)
    local textWidth = GetTextWidth(text);
    local windowWidth = imgui.GetWindowWidth();
    imgui.SetCursorPosX(math.max((windowWidth - textWidth) * 0.5, 0));
    imgui.Text(text);
end

-- One pixel down and right. The extra copies are only the neighboring pixels,
-- so the edge stays soft without spreading past the letter.
local titleShadow = { 0.0, 0.0, 0.0, 0.35 };
local titleShadowOffsets = {
    { 1, 1 },
    { 0, 1 }, { 2, 1 }, { 1, 0 }, { 1, 2 },
};

local function DrawTitle(text)
    local x, y = imgui.GetCursorPos();
    for _, off in ipairs(titleShadowOffsets) do
        imgui.SetCursorPos({ x + off[1], y + off[2] });
        imgui.TextColored(titleShadow, text);
    end
    imgui.SetCursorPos({ x, y });
    imgui.Text(text);
end

-- Closer groups in display order, with their section titles.
local function ChainSections(skillchains)
    return {
        { title = 'Weaponskills', group = skillchains.weapon },
        { title = 'Spells', group = skillchains.spell },
        { title = 'Pets', group = skillchains.pet },
    };
end

--=============================================================================
-- Draw the preview header/footer chrome
--=============================================================================
local function DrawPreviewChrome()
    DrawCenteredText('--- Chains Live Preview ---');
    DrawCenteredText('Click and Drag to Move Display');
end

--=============================================================================
-- Measure the widest content line to determine auto-fit window width
---@param targetEntry table
---@param skillchains table Grouped weapon, spell, and pet closers
---@param showChrome boolean
---@return number
--=============================================================================
local function MeasureChainWidth(targetEntry, skillchains, showChrome)
    local maxWidth = 0;

    local function consider(text)
        maxWidth = math.max(maxWidth, GetTextWidth(text));
    end

    -- Chrome lines (preview header/footer)
    if showChrome then
        consider('--- Chains Live Preview ---');
        consider('Click and Drag to Move Display');
    end

    -- Timer line (worst-case width)
    consider('Wait  99');
    consider('Go!   99');
    consider('Burst 99');

    -- Step line
    consider(('Step: %d >> %s'):fmt(targetEntry.step, targetEntry.en));

    -- Property/element line
    if targetEntry.bound then
        consider(('[Chainbound Lv.%d]'):fmt(targetEntry.bound));
    else
        local propWidth = GetTextWidth('[') + GetTextWidth(']');
        for k, v in pairs(targetEntry.property) do
            if k > 1 then propWidth = propWidth + GetTextWidth(', '); end
            propWidth = propWidth + GetTextWidth(v);
        end
        if targetEntry.step > 1 and chainInfo[targetEntry.property[1]] then
            propWidth = propWidth + GetTextWidth(' (') + GetTextWidth(')');
            for k, v in pairs(chainInfo[targetEntry.property[1]].burst) do
                if k > 1 then propWidth = propWidth + GetTextWidth(', '); end
                propWidth = propWidth + GetTextWidth(v);
            end
        end
        maxWidth = math.max(maxWidth, propWidth);
    end

    -- Section titles and closer lines
    for _, section in ipairs(ChainSections(skillchains)) do
        if #section.group > 0 then
            consider(section.title .. ' ');
            for _, v in pairs(section.group) do
                consider(v.outName .. v.outText .. ' ' .. v.outProp);
            end
        end
    end

    -- Add window padding
    local padding = 16;
    local style = imgui.GetStyle();
    if style and style.WindowPadding then
        padding = (style.WindowPadding.x or style.WindowPadding[1] or 8) * 2;
    end

    return maxWidth + padding;
end

--=============================================================================
-- Return formatted weapon, spell, and pet skillchain options
---@param target table Target skillchain state
---@return table skillchains Current options grouped by weapon, spell, and pet
--=============================================================================
local GetSkillchains = function(target)
    local weaponActions = T{};
    local spellActions = T{};
    local petActions = T{};
    local spellReady = true;

    local player = GetPlayer();
    local mainJob = player.MainJob;
    local subJob = player.SubJob;
    local isSMN = mainJob == 'SMN' or subJob == 'SMN';
    local isBST = mainJob == 'BST' or subJob == 'BST';
    local isPUP = mainJob == 'PUP' or subJob == 'PUP';
    local requireAbility = chains.settings.ability;
    local playerBuffs = playerTable[playerID];
    local schBuffActive = (playerBuffs and playerBuffs[statusID.IM])
        or chains.forceImmanence;
    local bluBuffActive = (playerBuffs and playerBuffs[statusID.AL])
        or (playerBuffs and playerBuffs[statusID.CA])
        or chains.forceAffinity;
    local enableSCH = mainJob == 'SCH' and (
        not requireAbility
        or schBuffActive
    );
    local enableBLU = mainJob == 'BLU' and (
        not requireAbility
        or bluBuffActive
    );
    if mainJob == 'BLU' then
        spellReady = not not bluBuffActive;
    elseif mainJob == 'SCH' then
        spellReady = not not schBuffActive;
    end
    local currentPet = (isSMN or isBST or isPUP) and GetCurrentPetName() or nil;
    local currentJug = isBST and FindJug(currentPet) or nil;
    local currentFrame = isPUP and GetAutomatonFrame() or nil;

    -- Create weaponskill table if it does not already exist
    -- Will update through incoming 0xAC packets
    if not actionTable.wepskill then
        actionTable.wepskill = GetWeaponskills();
    end

    -- Read the BLU spell set live since the player can change it at any time
    if enableBLU and chains.settings.display.spell then
        actionTable.bluskill = GetBluskills();
    end

    -- Initialize actions with weaponskills
    if chains.settings.display.weapon then
        weaponActions = weaponActions:extend(actionTable.wepskill);
    end

    -- Read SMN pet skills live for main or sub SMN
    if chains.settings.display.pet and isSMN then
        petActions = petActions:extend(GetPetskills());
    end

    -- Beastmaster closers stay in the pet group and out of weaponActions
    if chains.settings.display.pet and isBST then
        petActions = petActions:extend(GetBstskills(currentJug));
    end

    if chains.settings.display.pet and isPUP then
        petActions = petActions:extend(GetPupskills(currentFrame));
    end

    -- Spell closers
    if chains.settings.display.spell and enableBLU and actionTable.bluskill then
        spellActions = spellActions:extend(actionTable.bluskill);
    elseif chains.settings.display.spell and enableSCH and actionTable.schskill then
        spellActions = spellActions:extend(actionTable.schskill);
    end

    local function buildList(actions, ready)
        local chainTable = T{};
        local levelTable = T{{},{},{},{}};

        -- Search for valid skillchains and group them by resulting level
        for _, action in pairs(actions) do
            local actionProperty = GetAeonicProperty(action, playerID);

            for _, prop1 in pairs(target.property) do
                local match = nil;

                for _, prop2 in pairs(actionProperty) do
                    match = chainInfo[prop1][prop2];
                    if match then break; end
                end

                if match then
                    local checkAeonic = chainInfo[prop1].level == 3
                        and (target.step + GetAftermathLevel()) >= 4;
                    if checkAeonic and chainInfo[prop1].aeonic then
                        match = chainInfo[prop1].aeonic;
                    end

                    local isReady = ready;
                    if type(ready) == 'function' then
                        isReady = ready(action);
                    end

                    table.insert(levelTable[match.level], {
                        outName = ('%-17s'):fmt(action.en),
                        outText = ('>> Lv.%d'):fmt(match.level),
                        outProp = match.skillchain,
                        ready = not not isReady,
                    });
                    break;
                end
            end
        end

        -- Preserve the existing highest-to-lowest skillchain level order
        for level = 4, 1, -1 do
            for _, entry in pairs(levelTable[level]) do
                table.insert(chainTable, entry);
            end
        end

        return chainTable;
    end

    return T{
        weapon = buildList(weaponActions, true),
        spell = buildList(spellActions, spellReady),
        pet = buildList(petActions, function (action)
            if action.avatar then
                return currentPet == action.avatar;
            end
            if action.kind == 'bst' then
                return currentJug ~= nil and currentJug[action.id] ~= nil;
            end
            if action.kind == 'pup' then
                return currentPet ~= nil and currentFrame ~= nil and currentFrame[action.id] ~= nil;
            end
            return currentPet ~= nil;
        end),
    };
end

--=============================================================================
-- Draw the skillchain panel content
---@param targetEntry table   Current target skillchain state
---@param skillchains table   Precomputed weapon, spell, and pet closer groups
---@param showChrome boolean  Show preview header/footer
--=============================================================================
local function DrawChainContent(targetEntry, skillchains, showChrome)
    local now = os.time();
    local timediff = now - targetEntry.ts;
    local timer = targetEntry.dur - timediff;
    local bottomUp = chains.settings.direction == 'bottom';

    local function drawTimer()
        if not targetEntry.closed then
            if timediff < targetEntry.wait then
                imgui.TextColored({ 1.0, 0.0, 0.0, 1.0 }, ('Wait  %d'):fmt(targetEntry.wait - timediff));
            else
                imgui.TextColored({ 0.0, 1.0, 0.0, 1.0 }, ('Go!   %d'):fmt(timer));
            end
        else
            imgui.Text(('Burst %d'):fmt(timer));
        end
    end

    local function drawStep()
        imgui.Text(('Step: %d >> %s'):fmt(targetEntry.step, targetEntry.en));
    end

    local function drawElements()
        imgui.Text('[');
        imgui.SameLine();
        if targetEntry.bound then
            imgui.Text(('Chainbound Lv.%d'):fmt(targetEntry.bound));
        else
            for k, v in pairs(targetEntry.property) do
                if k > 1 then
                    imgui.SameLine(0, 0);
                    imgui.Text(',');
                    imgui.SameLine();
                end
                imgui.TextColored(GetPropertyColor(v), v);
            end
        end
        imgui.SameLine();
        imgui.Text(']');
        if targetEntry.step > 1 then
            imgui.SameLine();
            imgui.Text(' (');
            imgui.SameLine();
            for k, v in pairs(chainInfo[targetEntry.property[1]].burst) do
                if k > 1 then
                    imgui.SameLine(0, 0);
                    imgui.Text(',');
                    imgui.SameLine();
                end
                imgui.TextColored(GetPropertyColor(v), v);
            end
            imgui.SameLine();
            imgui.Text(')');
        end
    end

    local function drawClosers()
        if targetEntry.closed then return; end

        local function drawGroup(group)
            for _, v in pairs(group) do
                imgui.TextColored(v.ready and colors.Ready or colors.Unavailable, v.outName);
                imgui.SameLine(0, 0);
                imgui.Text(v.outText);
                imgui.SameLine();
                imgui.TextColored(GetPropertyColor(v.outProp), v.outProp);
            end
        end

        local firstGroup = true;
        for _, section in ipairs(ChainSections(skillchains)) do
            if #section.group > 0 then
                if not firstGroup then
                    imgui.Spacing();
                    imgui.Spacing();
                end
                DrawTitle(section.title);
                imgui.Separator();
                drawGroup(section.group);
                firstGroup = false;
            end
        end
    end

    -- Bottom-up: closers on top, timer on bottom (header above)
    -- Top-down: timer on top, closers on bottom (footer below)
    if bottomUp then
        if showChrome then
            DrawPreviewChrome();
            imgui.Separator();
        end
        drawClosers();
        imgui.Spacing();
        imgui.Separator();
        drawElements();
        drawStep();
        imgui.Separator();
        drawTimer();
    else
        drawTimer();
        imgui.Separator();
        drawStep();
        drawElements();
        imgui.Separator();
        imgui.Spacing();
        drawClosers();
        if showChrome then
            imgui.Separator();
            DrawPreviewChrome();
        end
    end
end

--=============================================================================
-- Reset stored skillchain lists for each active target
-- This would trigger on weapon, ability and pet changes
--=============================================================================
local function ResetSkillchains()
    for _,v in pairs(targetTable) do
        v.skillchains = nil;
    end
end

--=============================================================================
-- Return true if another player belongs to the player's alliance.
---@param id number ServerId
---@return boolean
--=============================================================================
local function isPlayerInAlliance(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty();

    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 and pParty:GetMemberServerId(i) == id then
            return true
        end
    end

    return false
end

--=============================================================================
-- Return true if a pet belongs to the player's alliance.
---@param id number ServerId
---@return boolean
--=============================================================================
local function isPetInAlliance(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty();
    local pEntity = AshitaCore:GetMemoryManager():GetEntity();

    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 then
            local playerIndex = pParty:GetMemberTargetIndex(i);
            local petIndex = pEntity:GetPetTargetIndex(playerIndex);
            if petIndex > 0 and pEntity:GetServerId(petIndex) == id then
                return true;
            end
        end
    end

    return false
end

--=============================================================================
-- Return the owner's main and sub job when id is an alliance member's pet.
---@param id number ServerId
---@return string|nil mainJob
---@return string|nil subJob
--=============================================================================
local function alliancePetOwnerJobs(id)
    local pParty = AshitaCore:GetMemoryManager():GetParty();
    local pEntity = AshitaCore:GetMemoryManager():GetEntity();
    local pResource = AshitaCore:GetResourceManager();

    for i = 0, 17 do
        if pParty:GetMemberIsActive(i) == 1 then
            local playerIndex = pParty:GetMemberTargetIndex(i);
            local petIndex = pEntity:GetPetTargetIndex(playerIndex);
            if petIndex > 0 and pEntity:GetServerId(petIndex) == id then
                local mainJob = pResource:GetString('jobs.names_abbr', pParty:GetMemberMainJob(i));
                local subJob = pResource:GetString('jobs.names_abbr', pParty:GetMemberSubJob(i));
                return mainJob, subJob;
            end
        end
    end

    return nil, nil;
end

--=============================================================================
-- Return true if an entity is an Automaton owned by an alliance PUP.
-- Automaton weaponskills arrive as action Type 11 (same as BST pets), so the
-- owner's job is what tells them apart.
---@param id number ServerId
---@return boolean
--=============================================================================
local function isAllianceAutomaton(id)
    return (alliancePetOwnerJobs(id)) == 'PUP';
end

--=============================================================================
-- Return the skills.bst row for a Ready move if it came from an alliance BST.
-- Horizon reports Ready as the player's action. Retail reports it from the pet.
---@param actor number ServerId
---@param skillId number
---@return table|nil
--=============================================================================
local function resolveBstSkill(actor, skillId)
    local row = skills.bst and skills.bst[skillId];
    if not hasSkillchain(row) then
        return nil;
    end

    local mainJob, subJob;
    if actor == playerID then
        local player = GetPlayer();
        mainJob, subJob = player.MainJob, player.SubJob;
    else
        mainJob, subJob = alliancePetOwnerJobs(actor);
    end

    if mainJob == 'BST' or subJob == 'BST' then
        return row;
    end
    return nil;
end

-- Property on this skill that closes the open window, if any.
local function bstCloserProperty(targetEntry, skill)
    if not targetEntry or targetEntry.closed or not skill.skillchain then
        return nil;
    end
    for _, openProp in pairs(targetEntry.property) do
        local info = chainInfo[openProp];
        if info then
            for _, prop in pairs(skill.skillchain) do
                if info[prop] then
                    return prop;
                end
            end
        end
    end
    return nil;
end

--=============================================================================
-- Print formatted error information
--=============================================================================
-- Copied from tHotBar by Thorny as part of ParseActionPacket
--=============================================================================
local function Error(text)
    local color = ('\30%c'):format(68);
    local highlighted = color .. string.gsub(text, '$H', '\30\01\30\02');
    highlighted = string.gsub(highlighted, '$R', '\30\01' .. color);
    print(chat.header(addon.name) .. highlighted .. '\30\01');
end

--=============================================================================
-- Return action packet data in a table format
---@param e table Incoming packet table
---@return table pendingActionPacket Parsed action packet table
--=============================================================================
-- Based on code from tHotBar by Thorny
-- https://github.com/Windower/Lua/blob/dev/addons/libs/packets/data.lua
-- https://github.com/Windower/Lua/blob/dev/addons/libs/packets/fields.lua
--=============================================================================
local function ParseActionPacket(e)
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;

    local function UnpackBits(length)
        if ((bitOffset + length) > maxLength) then
            maxLength = 0; --Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local pendingActionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;

    pendingActionPacket.UserId = UnpackBits(32);
    local targetCount = UnpackBits(6);
    bitOffset = bitOffset + 4; --Unknown 4 bits
    pendingActionPacket.Type = UnpackBits(4);
    pendingActionPacket.Id = UnpackBits(32); --{unknown[15:0], param[15:0]}
    bitOffset = bitOffset + 32; --Unknown 32 bits --{recast[31:0]}?

    pendingActionPacket.Targets = T{};
    for i = 1,targetCount do
        local target = T{};
        target.Id = UnpackBits(32);
        local actionCount = UnpackBits(4);
        target.Actions = T{};
        for j = 1,actionCount do
            local action = {};
            action.Reaction = UnpackBits(5);
            action.Animation = UnpackBits(12);
            action.SpecialEffect = UnpackBits(7);
            action.Knockback = UnpackBits(3);
            action.Param = UnpackBits(17);
            action.Message = UnpackBits(10);
            action.Flags = UnpackBits(31);

            local hasAdditionalEffect = (UnpackBits(1) == 1);
            if hasAdditionalEffect then
                local additionalEffect = {};
                additionalEffect.Damage = UnpackBits(10); --{effect[3:0],animation[5:0]}
                additionalEffect.Param = UnpackBits(17);
                additionalEffect.Message = UnpackBits(10);
                action.AdditionalEffect = additionalEffect;
            end

            local hasSpikesEffect = (UnpackBits(1) == 1);
            if hasSpikesEffect then
                local spikesEffect = {};
                spikesEffect.Damage = UnpackBits(10); --{effect[3:0],animation[5:0]}
                spikesEffect.Param = UnpackBits(14);
                spikesEffect.Message = UnpackBits(10);
                action.SpikesEffect = spikesEffect;
            end

            target.Actions:append(action);
        end
        pendingActionPacket.Targets:append(target);
    end

    if (maxLength == 0) then
        Error(string.format('Malformed action packet detected.  Type:$H%u$R User:$H%u$R Targets:$H%u$R', pendingActionPacket.Type, pendingActionPacket.UserId, #pendingActionPacket.Targets));
        pendingActionPacket.Targets = T{}; --Blank targets so that it doesn't register bad info later.
    end

    return pendingActionPacket;

end

--=============================================================================
-- event: load
-- desc: Event called when the addon is being loaded.
--=============================================================================
ashita.events.register('load', 'load_cb', function ()
    playerID = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
end);

--=============================================================================
-- event: unload
-- desc: Event called when the addon is being unloaded.
--=============================================================================
ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

--=============================================================================
-- event: packet_in
-- desc: Event called when the addon is processing incoming packets.
--=============================================================================
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    --[[ Valid Arguments
        e.id                 - (ReadOnly) The id of the packet.
        e.size               - (ReadOnly) The size of the packet.
        e.data               - (ReadOnly) The data of the packet.
        e.data_raw           - The raw data pointer of the packet. (Use with FFI.)
        e.data_modified      - The modified data.
        e.data_modified_raw  - The modified raw data. (Use with FFI.)
        e.chunk_size         - The size of the full packet chunk that contained the packet.
        e.chunk_data         - The data of the full packet chunk that contained the packet.
        e.chunk_data_raw     - The raw data pointer of the full packet chunk that contained the packet. (Use with FFI.)
        e.injected           - (ReadOnly) Flag that states if the packet was injected by Ashita or an addon/plugin.
        e.blocked            - Flag that states if the packet has been, or should be, blocked.
    --]]

    -- Action
    --[[ actionPacket.Type
        [1] = 'Melee attack',
        [2] = 'Ranged attack finish',
        [3] = 'Weapon Skill finish',
        [4] = 'Casting finish',
        [5] = 'Item finish',
        [6] = 'Job Ability',
        [7] = 'Weapon Skill start',
        [8] = 'Casting start',
        [9] = 'Item start',
        [11] = 'NPC TP finish', -- also BST jug pets / PUP automaton WS
        [12] = 'Ranged attack start',
        [13] = 'Avatar TP finish',
        [14] = 'Job Ability DNC',
        [15] = 'Job Ability RUN',
    --]]
    if e.id == 0x28 then

        -- Save a little bit of processing for packets that won't relate to SC..
        local actionType = ashita.bits.unpack_be(e.data_raw, 82, 4); -- byte: 0xA, bit: 0x2
        if not T{ 3, 4, 6, 11, 13, 14 }:contains(actionType) then
            return;
        end

        local actionPacket = ParseActionPacket(e);

        -- Only the primary target and action are parsed assuming that is all that apply
        local actor = actionPacket.UserId;
        local target = actionPacket.Targets[1];

        -- exit if target is nil due to corrupted packet
        if not target then
            return;
        end

        local targetAction = target.Actions[1];

        -- Overload packet type for pet actions (?)
        -- Prevents Weapon Bash from matching as an actionSkill
        -- Type 11 and pet damage messages remap to skills[13] for SMN pet skill IDs.
        -- Automaton WS live in skills.pup separated from NPC skills[11].
        local category = PetMessageTypes:contains(targetAction.Message) and 13 or actionPacket.Type;
        local skillId = bit.band(actionPacket.Id, 0xFFFF);

        -- capture valid action skill and added effect property if there is a match
        local actionSkill = skills[category] and skills[category][skillId];
        -- Type 11: a BST jug pet uses skills.bst only when that row skillchains.
        -- Otherwise NPC skills[11], then PUP automaton skills.pup.
        -- A server whose skills.bst rows have no properties still cannot open a window.
        local fromBst = false;
        if not actionSkill and actionPacket.Type == 11 then
            local bstSkill = resolveBstSkill(actor, skillId);
            if bstSkill then
                actionSkill = bstSkill;
                fromBst = true;
            else
                actionSkill = (skills[11] and skills[11][skillId]) or (skills.pup and skills.pup[skillId]);
            end
        end
        -- Type 14: SAM Konzen-ittai and DNC Wild Flourish
        -- Also accept Type 6 as a defensive fallback for nonstandard JA packaging
        if not actionSkill and T{ 6, 14 }:contains(actionPacket.Type) then
            actionSkill = skills[14] and skills[14][skillId];
        end
        local effectProperty = targetAction.AdditionalEffect and SkillPropNames[bit.band(targetAction.AdditionalEffect.Damage,0x3F)];
        if not effectProperty and fromBst then
            effectProperty = bstCloserProperty(targetTable[target.Id], actionSkill);
        end

        -- exit if actor is not in alliance
        if not (isPlayerInAlliance(actor) or isPetInAlliance(actor)) then
            return;
        end

        -- Check for valid action skill with valid added effect property - after first step
        if actionSkill and effectProperty then
            local step = (targetTable[target.Id] and targetTable[target.Id].step or 1) + 1
            local delay = actionSkill.delay or 3
            local level = chainInfo[effectProperty].level

            -- Check for Lv.3 -> Lv.3 and bump to Lv.4 for closure
            if level == 3 and targetTable[target.Id] and targetTable[target.Id].property[1] == effectProperty then
                level = 4;
            end
            local closed = level == 4;

            targetTable[target.Id] = {
                en=actionSkill.en,
                property={effectProperty},
                ts=os.time(),
                dur=8-step+delay,
                wait=delay,
                step=step,
                closed=closed,
            };

        -- Check for valid actor skill with valid message - generic first step (excluding chainbound)
        -- Include spells when SCH Immanence or BLU Azure Lore / Chain Affinity is active
        -- Immanence and Chain Affinity buff status cleared on use
        -- Allow alliance players (including Trusts), SMN pets (Type 13), and PUP automatons (Type 11).
        -- A BST jug opens a window only when skills.bst has skillchain properties.
        -- Other Type 11 pets stay refused so a move with no properties cannot start a chain.
        elseif actionSkill and hasSkillchain(actionSkill) and MessageTypes:contains(targetAction.Message)
            and (isPlayerInAlliance(actor) or actionPacket.Type == 13 or isAllianceAutomaton(actor)
                or fromBst)
            and (actionPacket.Type ~= 4 or (playerTable[actor])) then
            local delay = actionSkill.delay or 3
            targetTable[target.Id] = {
                en=actionSkill.en,
                property=GetAeonicProperty(actionSkill,actor),
                ts=os.time(),
                dur=7+delay,
                wait=delay,
                step=1,
            };

        -- Check for valid actor skill with chainbound message - chainbound first step
        -- Could be combined with previous first step check
        elseif actionSkill and (targetAction.Message == 529) then
            targetTable[target.Id] = {
                en=actionSkill.en,
                property=actionSkill.skillchain,
                ts=os.time(),
                dur=9,
                wait=2,
                step=1,
                bound=targetAction.Param,
            };
        end

        -- Clear out used spell abilities
        if actionSkill and actionPacket.Type == 4 and playerTable[actor] then
            local buffID = playerTable[actor][statusID.CA] and statusID.CA or playerTable[actor][statusID.IM] and statusID.IM;
            if buffID then
                playerTable[actor][buffID] = nil;
            end
        end

        -- Capture buff information for each player
        if actionPacket.Type == 6 and ChainBuffTypes:containskey(targetAction.Param) then
            playerTable[actor] = playerTable[actor] or {};
            playerTable[actor][targetAction.Param] = os.time() + ChainBuffTypes[targetAction.Param].duration;
        end

    -- PUP extended job data, sent for main or sub PUP
    -- 0x09 frame, 0x70 automaton melee skill, 0x74 automaton ranged skill
    elseif e.id == 0x044 and e.data:byte(0x04+1) == 18 and #e.data >= 0x78 then
        pupPacket.frame = e.data:byte(0x09+1);
        pupPacket.melee = struct.unpack('H', e.data, 0x70+1);
        pupPacket.ranged = struct.unpack('H', e.data, 0x74+1);

    -- Action Message - Clear buff when getting '206 - ${target}'s ${status} effect wears off'.
    --  only works to clear local player
    elseif e.id == 0x29 and struct.unpack('H', e.data, 0x18+1) == 206 and struct.unpack('I', e.data, 8+1) == playerID then
        local effect = struct.unpack('H', e.data, 0xC+1)
        if playerTable[playerID] and playerTable[playerID][effect] then
            playerTable[playerID][effect] = nil;
        end

    -- Character Abilities (Weaponskills)
    elseif e.id == 0x0AC then --and e.data:sub(5) ~= actionTable.lastAC then
        actionTable.wepskill = T{};

        -- Packet contains one bit per ability to indicate if the ability is available
        -- * Byte in packet = floor(abilityID / 8) + 1
        -- * Bit in byte = abilityID % 8
        -- Logic does the following:
        -- * extract byte
        -- * shift bits right to move relavent bit to bit[0]
        -- * mask upper bits and compare to 1 (or >0)
        -- * alt equation: bit.band(bit.rshift(data:byte(math.floor(k/8)+1),(k%8)),0x01) == 1

        -- Weaponskills
        local data = e.data:sub(5);
        for k,v in pairs(skills[3]) do
            if math.floor((data:byte(math.floor(k/8)+1)%2^(k%8+1))/2^(k%8)) == 1 then
                table.insert(actionTable.wepskill, v);
            end
        end

        -- Reset skillchains on all active targets
        ResetSkillchains();
    end

end);

--=============================================================================
-- Swap between top-down and bottom-up, keeping the window's anchor in place.
--=============================================================================
local function ToggleDirection()
    local height = chains.lastWindowHeight or 0;
    if chains.settings.direction == 'bottom' then
        chains.settings.direction = 'top';
        chains.settings.position_y = chains.settings.position_y - height;
    else
        chains.settings.direction = 'bottom';
        chains.settings.position_y = chains.settings.position_y + height;
    end
end

--=============================================================================
-- Move the window's top left corner back to 20, 20.
--=============================================================================
local function ResetPosition()
    chains.settings.position_x = 20;
    chains.settings.position_y = 20;
    if chains.settings.direction == 'bottom' then
        chains.settings.position_y = 20 + chains.lastWindowHeight;
    end
    chains.position = { x = 20, y = 20 };
end

-- Values the settings widgets edit. imgui needs them wrapped in tables.
local menu = {
    open = { true },
    scale = { 10 }, -- in tenths, so 10 is a scale of 1.0
    x = { 0 },
    y = { 0 },
    dragScale = nil, -- scale shown while the slider is held, saved on release
};

--=============================================================================
-- Open or close the settings window. The live preview shows while it's open.
---@param open boolean
--=============================================================================
local function SetMenu(open)
    if not open and menu.dragScale then
        chains.settings.font_scale = menu.dragScale;
        menu.dragScale = nil;
    end
    chains.editor = open;
    chains.previewTarget = nil;
end

--=============================================================================
-- Draw one checkbox bound to a boolean setting.
---@param label string
---@param tbl table
---@param key string
--=============================================================================
local function DrawToggle(label, tbl, key)
    local value = { tbl[key] and true or false };
    if imgui.Checkbox(label, value) then
        tbl[key] = value[1];
        settings.save();
    end
end

--=============================================================================
-- Settings window. Same options as the chat commands.
--=============================================================================
local function DrawSettings()
    if menu.dragScale and not imgui.IsMouseDown(0) then
        chains.settings.font_scale = menu.dragScale;
        menu.dragScale = nil;
        settings.save();
    end

    -- Pick up changes from commands or dragging while nothing is being edited.
    if not imgui.IsAnyItemActive() then
        menu.scale[1] = math.floor((chains.settings.font_scale or 1.0) * 10 + 0.5);
        menu.x[1] = math.floor(chains.settings.position_x + 0.5);
        menu.y[1] = math.floor(chains.settings.position_y + 0.5);
    end

    menu.open[1] = true;
    imgui.SetNextWindowPos({ chains.settings.editor_x or 20, chains.settings.editor_y or 20 }, ImGuiCond_Appearing);
    imgui.SetNextWindowSizeConstraints({ 220, -1 }, { FLT_MAX, FLT_MAX });

    local flags = bit.bor(ImGuiWindowFlags_AlwaysAutoResize, ImGuiWindowFlags_NoSavedSettings);
    if imgui.Begin('Chains', menu.open, flags) then
        imgui.Text('Display');
        DrawToggle('Colors', chains.settings.display, 'color');
        DrawToggle('Weaponskills', chains.settings.display, 'weapon');
        DrawToggle('Spells', chains.settings.display, 'spell');
        DrawToggle('Pets', chains.settings.display, 'pet');

        imgui.Spacing();
        if chains.settings.display.spell or chains.settings.display.pet then
            imgui.Text('Requirements');
            if chains.settings.display.spell then
                DrawToggle('Ability for spells', chains.settings, 'ability');
            end
            if chains.settings.display.pet then
                DrawToggle('Current avatar', chains.settings, 'smn');
                if skills.bst then
                    DrawToggle('Current jug pet', chains.settings, 'bst');
                end
                DrawToggle('Current automaton frame', chains.settings, 'pup');
            end
            imgui.Spacing();
        end

        imgui.Text('Window');
        local bottomUp = { chains.settings.direction == 'bottom' };
        if imgui.Checkbox('Layout direction', bottomUp) then
            ToggleDirection();
            settings.save();
        end

        -- An int slider in tenths so it can only land on 0.1 steps.
        if imgui.SliderInt('Scale', menu.scale, 5, 30, ('%.1f'):format(menu.scale[1] / 10)) then
            menu.dragScale = menu.scale[1] / 10;
        end

        -- Y is the top edge, or the bottom edge when laid out bottom-up.
        local movedX = imgui.InputInt('X', menu.x);
        local doneX = imgui.IsItemDeactivatedAfterEdit();
        local movedY = imgui.InputInt('Y', menu.y);
        local doneY = imgui.IsItemDeactivatedAfterEdit();
        if movedX or movedY then
            chains.settings.position_x = menu.x[1];
            chains.settings.position_y = menu.y[1];
            local top = menu.y[1];
            if chains.settings.direction == 'bottom' then
                top = top - chains.lastWindowHeight;
            end
            chains.position = { x = menu.x[1], y = top };
        end
        if doneX or doneY then
            settings.save();
        end

        if imgui.Button('Reset position') then
            ResetPosition();
            settings.save();
        end

        chains.settings.editor_x, chains.settings.editor_y = imgui.GetWindowPos();
    end
    imgui.End();

    if not menu.open[1] then
        SetMenu(false);
        settings.save();
    end
end

--=============================================================================
-- event: d3d_present
-- desc: Event called when the Direct3D device is presenting a scene.
--=============================================================================
ashita.events.register('d3d_present', 'present_cb', function ()

    -- Capture current time for comparison
    local now = os.time();

    -- Remove stale playerTable entries
    for pk,pv in pairs(playerTable) do
        for bk,bv in pairs(playerTable[pk]) do
            if now > bv then
                playerTable[pk][bk] = nil;
            end
        end
        if table.length(pv) == 0 then
            playerTable[pk] = nil;
        end
    end

    -- Remove stale targetTable entries
    for k,v in pairs(targetTable) do
        if v.ts and now-v.ts > v.dur then
            targetTable[k] = nil;
        end
    end

    -- UI
    local targetId = AshitaCore:GetMemoryManager():GetTarget():GetServerId(0);
    local render = targetId ~= nil and targetTable[targetId] and targetTable[targetId].dur-(now-targetTable[targetId].ts) > 0;

    -- Loop the preview while the settings window is open
    if chains.editor then
        if not chains.previewTarget then
            chains.previewTarget = CreatePreviewTarget();
        elseif now - chains.previewTarget.ts > chains.previewTarget.dur then
            chains.previewTarget.ts = now;
        end
    end

    if render or chains.editor or chains.position then
        local showChrome = false;
        local targetEntry = nil;
        local skillchains = nil;

        if render then
            targetEntry = targetTable[targetId];
            skillchains = targetEntry.closed
                and T{ weapon = T{}, spell = T{}, pet = T{} }
                or GetSkillchains(targetEntry);
        elseif chains.previewTarget then
            showChrome = true;
            targetEntry = chains.previewTarget;
            skillchains = GetPreviewSkillchains();
        end

        -- Window flags (no title bar, no resize handle, auto-fit height)
        -- Locked in place unless the settings window is open.
        local flags = bit.bor(
            ImGuiWindowFlags_NoDecoration,
            ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoSavedSettings,
            ImGuiWindowFlags_NoFocusOnAppearing,
            ImGuiWindowFlags_NoNav)
        if not chains.editor then
            flags = bit.bor(flags, ImGuiWindowFlags_NoMove);
        end

        -- Bottom-up: position_y stores the bottom edge; top-down: the top edge
        local bottomUp = chains.settings.direction == 'bottom';
        local movedByCommand = chains.position ~= nil;

        imgui.SetNextWindowBgAlpha(0.8);

        if movedByCommand then
            imgui.SetNextWindowPos({ chains.position.x, chains.position.y }, ImGuiCond_Always, { 0, 0 });
        else
            local startY = chains.settings.position_y;
            if bottomUp then
                startY = startY - chains.lastWindowHeight;
            end
            imgui.SetNextWindowPos({ chains.settings.position_x, startY }, ImGuiCond_Appearing, { 0, 0 });
        end

        -- Scale font and measure content width for auto-fit
        if targetEntry then
            ApplyFontScale(menu.dragScale or chains.settings.font_scale);
            local contentWidth = MeasureChainWidth(targetEntry, skillchains, showChrome);
            imgui.SetNextWindowSizeConstraints({ contentWidth, -1 }, { FLT_MAX, FLT_MAX });
        else
            imgui.SetNextWindowSizeConstraints({ -1, -1 }, { FLT_MAX, FLT_MAX });
        end

        if (imgui.Begin('chains', true, flags)) then
            -- Clear one-shot position override from /chains move or /chains reset
            chains.position = nil;

            local windowX, windowY = imgui.GetWindowPos();
            local _, windowHeight = imgui.GetWindowSize();
            local dragging = imgui.IsMouseDown(0) and (imgui.IsWindowFocused() or imgui.IsWindowHovered());

            -- Pin bottom edge when bottom-up so shrinking content doesn't shift the window down
            if bottomUp and not movedByCommand and not dragging then
                local anchoredY = chains.settings.position_y - windowHeight;
                if math.abs(anchoredY - windowY) > 0.5 then
                    imgui.SetWindowPos({ windowX, anchoredY });
                    windowY = anchoredY;
                end
            end

            if targetEntry then
                DrawChainContent(targetEntry, skillchains, showChrome);
            end

            -- Persist the anchor point each frame
            chains.lastWindowHeight = windowHeight;
            chains.settings.position_x = windowX;
            if bottomUp then
                chains.settings.position_y = windowY + windowHeight;
            else
                chains.settings.position_y = windowY;
            end
        end
        imgui.End();

        if targetEntry then
            UnapplyFontScale();
        end
    end

    if chains.editor then
        DrawSettings();
    end

end);

--=============================================================================
-- event: command
-- desc: Event called when the addon is processing a command.
--=============================================================================
ashita.events.register('command', 'command_cb', function (e)
    --[[ Valid Arguments
        e.mode       - (ReadOnly) The mode of the command.
        e.command    - (ReadOnly) The raw command string.
        e.injected   - (ReadOnly) Flag that states if the command was injected by Ashita or an addon/plugin.
        e.blocked    - Flag that states if the command has been, or should be, blocked.
    --]]

    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/chains')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    --========================================================================
    -- Settings window and live preview
    --========================================================================
    if (#args == 1) then
        SetMenu(not chains.editor);
        local state = chains.editor and chat.success('Enabled') or chat.error('Disabled');
        print(chat.header(addon.name):append(chat.message('Chains settings menu is now: ')):append(state));
        return;
    end

    --========================================================================
    -- Help
    --========================================================================
    if (#args == 2) and args[2]:any('help', '?', 'commands') then
        local commandHelp = T{
            { '/chains', 'Open the settings window and the live preview.' },
            { '/chains color', 'Toggle colored skillchain properties.' },
            { '/chains weapon', 'Toggle weaponskill display.' },
            { '/chains pet', 'Toggle pet skill display.' },
            { '/chains spell', 'Toggle spell display.' },
            { '/chains ability', 'Toggle ability requirement for spell skill display.' },
            { '/chains smn', 'Toggles requirement for avatar to be summoned for pet skill display.' },
            { '/chains pup', 'Toggles requirement for the current automaton frame.' },
            { '/chains direction', 'Toggle top-down or bottom-up layout direction.' },
            { '/chains scale <n>', 'Set UI font and window scale.' },
            { '/chains move <x> <y>', 'Set window position.' },
            { '/chains reset', 'Reset window position.' },
        };
        if skills.bst then
            commandHelp:insert(8, { '/chains bst', 'Toggles requirement for the current jug pet.' });
        end
        commandHelp:ieach(function(entry)
            print(chat.header(addon.name)
                :append(chat.success(entry[1]))
                :append(chat.message(' - '))
                :append(chat.message(entry[2])));
        end);
        return;
    end

    --========================================================================
    -- Settings
    --========================================================================
    if (#args == 2) and chains.settings.display:containskey(args[2]) then
        chains.settings.display[args[2]] = not chains.settings.display[args[2]];
        local messages = T{
            color = 'Chains coloring is now: ',
            weapon = 'Chains weaponskills are now: ',
            pet = 'Chains pet skills are now: ',
            spell = 'Chains spells are now: ',
        };
        local state = chains.settings.display[args[2]] and chat.success('Enabled') or chat.error('Disabled');
        print(chat.header(addon.name):append(chat.message(messages[args[2]])):append(state));
    end

    local requirements = T{
        ability = 'Chains ability requirement is now: ',
        smn = 'Chains avatar summon requirement has been: ',
        bst = 'Chains jug pet requirement has been: ',
        pup = 'Chains automaton frame requirement has been: ',
    };
    if (#args == 2) and requirements:containskey(args[2]) then
        chains.settings[args[2]] = not chains.settings[args[2]];
        local state = chains.settings[args[2]] and chat.success('Enabled') or chat.error('Disabled');
        print(chat.header(addon.name):append(chat.message(requirements[args[2]])):append(state));
    end

    --========================================================================
    -- Window management
    --========================================================================
    if (#args == 2) and (args[2] == 'direction') then
        ToggleDirection();
        local direction = chains.settings.direction == 'bottom' and 'Bottom-Up' or 'Top-Down';
        print(chat.header(addon.name):append(chat.message('Chains direction has been set to: ')):append(chat.success(direction)));
    end

    if (#args == 3) and (args[2] == 'scale') then
        local scale = tonumber(args[3]);
        if not scale or scale <= 0 then
            print(chat.header(addon.name):append(chat.error('Usage: /chains scale <n>, e.g. /chains scale 1.2')));
            return;
        end
        chains.settings.font_scale = scale;
        print(chat.header(addon.name):append(chat.message('Chains font scale has been set to: ')):append(chat.success(tostring(scale))));
    end

    if (#args == 4) and (args[2] == 'move') then
        local x, y = tonumber(args[3]), tonumber(args[4]);
        if not x or not y then
            print(chat.header(addon.name):append(chat.error('Usage: /chains move <x> <y>')));
            return;
        end
        chains.position = { x = x, y = y };
        print(chat.header(addon.name):append(chat.message('Chains window has been moved to: ')):append(chat.success(('%s, %s'):fmt(x, y))));
    end

    if (#args == 2) and (args[2] == 'reset') then
        ResetPosition();
        print(chat.header(addon.name):append(chat.message('Chains window position has been reset.')));
    end

end);