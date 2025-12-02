--
-- Settings management for Realistic Livestock Adjustments
-- Handles loading and saving configuration from savegame folder
--
-- @author Ritter
-- @version 1.2.0.2
--

Settings = {}
local Settings_mt = Class(Settings)

-- Module constants
Settings.FILENAME = "rla_settings.xml"
Settings.DEFAULT_GENETICS_POSITION = "prefix" -- "prefix" or "postfix"
Settings.DEFAULT_GENETICS_FORMAT = "short"    -- "short" or "long"
Settings.SORT_BY_GENETICS = true              -- Whether to sort animals by genetics in UI

---Creates a new Settings instance with default values
---@return table New Settings instance
function Settings.new()
    local self = setmetatable({}, Settings_mt)

    -- Default settings
    self.geneticsPosition = Settings.DEFAULT_GENETICS_POSITION
    self.geneticsFormat = Settings.DEFAULT_GENETICS_FORMAT
    self.sortByGenetics = Settings.SORT_BY_GENETICS
    self.settingsFile = nil

    return self
end

---Gets the full path to the settings file in the savegame folder
---@return string|nil Settings file path, or nil if no save game is active
function Settings:getSettingsFilePath()
    RmUtils.logDebug("Checking for savegame directory...")

    if not g_currentMission then
        RmUtils.logWarning("g_currentMission is nil")
        return nil
    end

    if not g_currentMission.missionInfo then
        RmUtils.logWarning("g_currentMission.missionInfo is nil")
        return nil
    end

    if not g_currentMission.missionInfo.savegameDirectory then
        RmUtils.logWarning("g_currentMission.missionInfo.savegameDirectory is nil")
        return nil
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    local filePath = savegameDir .. "/" .. Settings.FILENAME
    RmUtils.logDebug("Settings file path: " .. filePath)

    return filePath
end

---Loads settings from the XML file in savegame folder
---@return boolean True if loaded successfully, false otherwise
function Settings:loadFromXML()
    local filePath = self:getSettingsFilePath()
    if not filePath then
        RmUtils.logInfo("Using default settings (no savegame active)")
        return false
    end

    if not fileExists(filePath) then
        RmUtils.logInfo("Settings file not found, creating with defaults: " .. filePath)
        local saveSuccess = self:saveToXML()
        if not saveSuccess then
            RmUtils.logWarning("Failed to create default settings file, using in-memory defaults")
        end
        return saveSuccess
    end

    local xmlFile = XMLFile.load("settingsXML", filePath)
    if not xmlFile then
        RmUtils.logError("Failed to load settings file: " .. filePath)
        return false
    end

    -- Load genetics position setting
    local geneticsPosition = xmlFile:getString("settings.animalNameOverride#geneticsPosition")
    if geneticsPosition == "prefix" or geneticsPosition == "postfix" then
        self.geneticsPosition = geneticsPosition
        RmUtils.logDebug("Loaded genetics position: " .. geneticsPosition)
    else
        RmUtils.logWarning("Invalid genetics position in settings, using default: " .. self.geneticsPosition)
    end

    -- Load genetics format setting
    local geneticsFormat = xmlFile:getString("settings.animalNameOverride#geneticsFormat")
    if geneticsFormat == "short" or geneticsFormat == "long" then
        self.geneticsFormat = geneticsFormat
        RmUtils.logDebug("Loaded genetics format: " .. geneticsFormat)
    else
        RmUtils.logWarning("Invalid genetics format in settings, using default: " .. self.geneticsFormat)
    end

    -- Load sort by genetics setting
    local sortByGenetics = xmlFile:getBool("settings.animalNameOverride#sortByGenetics")
    if type(sortByGenetics) == "boolean" then
        self.sortByGenetics = sortByGenetics
        RmUtils.logDebug("Loaded sort by genetics: " .. tostring(sortByGenetics))
    else
        RmUtils.logWarning("Invalid sort by genetics in settings, using default: " .. tostring(self.sortByGenetics))
    end


    xmlFile:delete()
    RmUtils.logInfo("Settings loaded successfully from: " .. filePath)
    return true
end

---Saves current settings to XML file in savegame folder
---@return boolean True if saved successfully, false otherwise
function Settings:saveToXML()
    RmUtils.logDebug("Attempting to save settings...")

    local filePath = self:getSettingsFilePath()
    if not filePath then
        RmUtils.logWarning("Cannot save settings - no savegame active")
        return false
    end

    RmUtils.logDebug("Creating XML file at: " .. filePath)
    local xmlFile = XMLFile.create("settingsXML", filePath, "settings")
    if not xmlFile then
        RmUtils.logError("Failed to create settings file: " .. filePath)
        return false
    end

    RmUtils.logDebug("Setting XML values...")

    -- Save animal name override settings
    local success1 = xmlFile:setString("settings.animalNameOverride#geneticsPosition", self.geneticsPosition)
    local success2 = xmlFile:setString("settings.animalNameOverride#geneticsFormat", self.geneticsFormat)
    local success3 = xmlFile:setBool("settings.animalNameOverride#sortByGenetics", self.sortByGenetics)

    RmUtils.logDebug("Set genetics position: " ..
        tostring(success1) .. ", format: " .. tostring(success2) .. ", sort: " .. tostring(success3))

    -- Add brief comment to main element only
    xmlFile:setString("settings#comment", "RLA Settings: geneticsPosition=[prefix|postfix], geneticsFormat=[short|long]")

    RmUtils.logDebug("Saving XML file...")
    local saveResult = xmlFile:save()
    RmUtils.logDebug("Save result: " .. tostring(saveResult))

    xmlFile:delete()

    if saveResult then
        RmUtils.logInfo("Settings saved successfully to: " .. filePath)
        -- Create a more user-friendly version by writing a comment file
        self:writeReadableSettingsInfo(filePath)
        return true
    else
        RmUtils.logError("Failed to save settings file: " .. filePath)
        return false
    end
end

---Gets the genetics position setting
---@return string "prefix" or "postfix"
function Settings:getGeneticsPosition()
    return self.geneticsPosition
end

---Gets the genetics format setting
---@return string "short" or "long"
function Settings:getGeneticsFormat()
    return self.geneticsFormat
end

---Gets the genetics sort setting
---@return boolean True if sorting by genetics is enabled
function Settings:getSortByGenetics()
    return self.sortByGenetics
end

---Sets the genetics position setting
---@param position string "prefix" or "postfix"
---@return boolean True if set successfully, false if invalid value
function Settings:setGeneticsPosition(position)
    if position == "prefix" or position == "postfix" then
        self.geneticsPosition = position
        RmUtils.logDebug("Genetics position set to: " .. position)
        return true
    else
        RmUtils.logWarning("Invalid genetics position: " .. tostring(position))
        return false
    end
end

---Sets the genetics format setting
---@param format string "short" or "long"
---@return boolean True if set successfully, false if invalid value
function Settings:setGeneticsFormat(format)
    if format == "short" or format == "long" then
        self.geneticsFormat = format
        RmUtils.logDebug("Genetics format set to: " .. format)
        return true
    else
        RmUtils.logWarning("Invalid genetics format: " .. tostring(format))
        return false
    end
end

---Sets the genetics sort setting
---@param sortByGenetics boolean True to enable sorting by genetics
---@return boolean True if set successfully, false if invalid value
function Settings:setSortByGenetics(sortByGenetics)
    if type(sortByGenetics) == "boolean" then
        self.sortByGenetics = sortByGenetics
        RmUtils.logDebug("Genetics sort set to: " .. tostring(sortByGenetics))
        return true
    else
        RmUtils.logWarning("Invalid genetics sort value: " .. tostring(sortByGenetics))
        return false
    end
end

---Reloads settings from file (useful for runtime changes)
---@return boolean True if reloaded successfully
function Settings:reload()
    RmUtils.logInfo("Reloading settings from file...")
    return self:loadFromXML()
end

---Gets a summary of current settings for debugging
---@return string Settings summary
function Settings:getSummary()
    return string.format("Settings: geneticsPosition=%s, geneticsFormat=%s, sortByGenetics=%s",
        self.geneticsPosition, self.geneticsFormat, self.sortByGenetics)
end

---Writes a readable settings info file next to the XML
---@param xmlPath string Path to the XML settings file
local function writeReadableSettingsInfo(self, xmlPath)
    local infoPath = string.gsub(xmlPath, ".xml$", "_info.txt")
    local file = io.open(infoPath, "w")

    if file then
        file:write("=== FS25 Realistic Livestock Adjustments Settings ===" .. "\n")
        file:write("" .. "\n")
        file:write("Edit the rla_settings.xml file to change these settings:" .. "\n")
        file:write("" .. "\n")
        file:write("geneticsPosition:" .. "\n")
        file:write("  - 'prefix': Shows genetics before name: [85] Animal Name" .. "\n")
        file:write("  - 'postfix': Shows genetics after name: Animal Name [85]" .. "\n")
        file:write("  Current: " .. self.geneticsPosition .. "\n")
        file:write("" .. "\n")
        file:write("geneticsFormat:" .. "\n")
        file:write("  - 'short': Shows overall quality only: [85]" .. "\n")
        file:write("  - 'long': Shows detailed traits: [85-85:73:99:97]" .. "\n")
        file:write("  Current: " .. self.geneticsFormat .. "\n")
        file:write("" .. "\n")
        file:write("sortByGenetics:" .. "\n")
        file:write("  - true: Sorts animals by genetics in selection UIs" .. "\n")
        file:write("  - false: Default sorting by name" .. "\n")
        file:write("  Current: " .. tostring(self.sortByGenetics) .. "\n")
        file:write("" .. "\n")
        file:write("After editing rla_settings.xml, use console command:" .. "\n")
        file:write("  rlaReloadSettings" .. "\n")
        file:write("" .. "\n")
        file:write("Example XML format:" .. "\n")
        file:write('<animalNameOverride geneticsPosition="prefix" geneticsFormat="short"/>' .. "\n")

        file:close()
    end
end

---Calls the local helper function
---@param xmlPath string Path to the XML settings file
function Settings:writeReadableSettingsInfo(xmlPath)
    writeReadableSettingsInfo(self, xmlPath)
end
