--
-- Realistic Livestock Adjustments
-- Main mod entry point
--
-- @author Ritter
-- @version 1.2.0.2
--

-- Load required dependencies
RLAdjust = {}
local RLAdjust_mt = Class(RLAdjust)

-- Module constants
RLAdjust.MOD_DIRECTORY = g_currentModDirectory
source(RLAdjust.MOD_DIRECTORY .. "scripts/RmUtils.lua")

-- Set logging prefix for the mod
RmUtils.setLogPrefix("[RLAdjust]")

source(RLAdjust.MOD_DIRECTORY .. "scripts/Settings.lua")
source(RLAdjust.MOD_DIRECTORY .. "scripts/BreedingMath.lua")
source(RLAdjust.MOD_DIRECTORY .. "scripts/AnimalNameOverride.lua")
source(RLAdjust.MOD_DIRECTORY .. "scripts/AnimalPregnancyOverride.lua")

---Creates a new RLAdjust instance
---@param customMt table|nil Optional custom metatable
---@return table New RLAdjust instance
function RLAdjust.new(customMt)
    local self = setmetatable({}, customMt or RLAdjust_mt)

    -- Initialize settings
    self.settings = Settings.new()

    return self
end

---Checks if FS25_RealisticLivestock.Animal is available
---@return boolean True if available, false otherwise
function RLAdjust:checkRealisticLivestockAnimal()
    RmUtils.logInfo("Checking for FS25_RealisticLivestock.Animal...")

    if _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal and _G.FS25_RealisticLivestock.Animal.getName then
        RmUtils.logInfo("FS25_RealisticLivestock.Animal.getName found")
        return true
    else
        RmUtils.logWarning("FS25_RealisticLivestock.Animal.getName not available")
        return false
    end
end

---Checks for available animal screen controllers
---@return boolean True if controllers found, false otherwise
function RLAdjust:checkAnimalScreenControllers()
    RmUtils.logInfo("Checking for animal screen controllers...")

    local controllers = { "AnimalScreenDealer", "AnimalScreenDealerFarm", "AnimalScreenDealerTrailer",
        "AnimalScreenTrailer", "AnimalScreenTrailerFarm" }
    local foundCount = 0

    for _, controllerName in ipairs(controllers) do
        if _G[controllerName] then
            foundCount = foundCount + 1
        end
    end

    if foundCount > 0 then
        RmUtils.logInfo(string.format("Found %d/%d animal screen controllers", foundCount, #controllers))
        return true
    else
        RmUtils.logWarning("No animal screen controllers found")
        return false
    end
end

---Initializes the mod and loads adjustments if dependencies are available
function RLAdjust:initialize()
    -- Load settings from savegame folder
    self.settings:loadFromXML()
    RmUtils.logInfo("Current " .. self.settings:getSummary())

    -- Pass settings reference to other modules
    AnimalNameOverride.settings = self.settings
    -- Check for required dependencies
    self.hasRealisticLivestockAnimal = self:checkRealisticLivestockAnimal()
    self.hasAnimalScreenControllers = self:checkAnimalScreenControllers()

    -- Load adjustments only if dependencies are available
    if self.hasRealisticLivestockAnimal then
        RmUtils.logInfo("Loading animal adjustments...")

        -- Apply overrides now that RealisticLivestock is confirmed loaded
        AnimalNameOverride.initialize()
        AnimalPregnancyOverride.initialize()

        if self.hasAnimalScreenControllers then
            RmUtils.logInfo("Animal screen controllers available for UI override")
        else
            RmUtils.logWarning("No animal screen controllers found - UI may not show genetics")
        end
    else
        RmUtils.logWarning("Missing FS25_RealisticLivestock.Animal, adjustments will not be loaded")
    end

    -- Add console commands
    self:setupConsoleCommands()
end

---Called when a map is loaded
---@param name string Map name
function RLAdjust:loadMap(name)
    RmUtils.logInfo(string.format("Loading map '%s'", name))
    self:initialize()
end

---Reloads settings from file (useful for runtime changes)
function RLAdjust:reloadSettings()
    if self.settings then
        self.settings:reload()
        AnimalNameOverride.settings = self.settings
        RmUtils.logInfo("Settings reloaded: " .. self.settings:getSummary())
    end
end

---Called when a map is unloaded, performs cleanup
function RLAdjust:deleteMap()
    RmUtils.logInfo("Unloading map")

    -- Cleanup overrides
    if AnimalNameOverride and AnimalNameOverride.delete then
        AnimalNameOverride.delete()
    end

    if AnimalPregnancyOverride and AnimalPregnancyOverride.delete then
        AnimalPregnancyOverride.delete()
    end

    -- Clear settings references
    AnimalNameOverride.settings = nil
end

---Sets up console commands for the mod
function RLAdjust:setupConsoleCommands()
    addConsoleCommand("rlaReloadSettings", "Reloads RL Adjust settings from file", "consoleCommandReloadSettings", self)
    addConsoleCommand("rlaShowSettings", "Shows current RL Adjust settings", "consoleCommandShowSettings", self)
    addConsoleCommand("rlaSaveSettings", "Manually saves RL Adjust settings to file", "consoleCommandSaveSettings", self)
    addConsoleCommand("rlaTestPath", "Shows the settings file path", "consoleCommandTestPath", self)
end

---Console command to reload settings
function RLAdjust:consoleCommandReloadSettings()
    self:reloadSettings()
    return "Settings reloaded successfully"
end

---Console command to show current settings
function RLAdjust:consoleCommandShowSettings()
    if self.settings then
        return self.settings:getSummary()
    else
        return "Settings not initialized"
    end
end

---Console command to manually save settings
function RLAdjust:consoleCommandSaveSettings()
    if self.settings then
        local success = self.settings:saveToXML()
        return success and "Settings saved successfully" or "Failed to save settings"
    else
        return "Settings not initialized"
    end
end

---Console command to test settings file path
function RLAdjust:consoleCommandTestPath()
    if self.settings then
        local path = self.settings:getSettingsFilePath()
        return path and ("Settings path: " .. path) or "No settings path available"
    else
        return "Settings not initialized"
    end
end

-- Global mod instance
g_rlAdjust = RLAdjust.new()

-- Mission event callbacks
Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
    g_rlAdjust:loadMap("Mission00")
end)

BaseMission.delete = Utils.prependedFunction(BaseMission.delete, function()
    g_rlAdjust:deleteMap()
end)

RmUtils.logInfo("Mod loaded successfully")
