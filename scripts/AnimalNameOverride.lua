--
-- Animal Name Override for Realistic Livestock Adjustments
-- Overrides animals name to display genetics information
--
-- @author Ritter
-- @version 1.2.0.2
--

AnimalNameOverride = {}
local AnimalNameOverride_mt = Class(AnimalNameOverride)

-- Constants for genetic value conversion (module-scoped)
AnimalNameOverride.GENETICS_MIN = 0.25
AnimalNameOverride.GENETICS_MAX = 1.75
AnimalNameOverride.DISPLAY_MIN = 0
AnimalNameOverride.DISPLAY_MAX = 99

-- Store original functions for cleanup
AnimalNameOverride.originalFunctions = {}

-- Reference to settings instance (will be set by main.lua)
AnimalNameOverride.settings = nil

---Constructs animal name with genetics quality information
---@param animal table The animal object containing genetics data
---@param context string Context identifier for logging purposes
---@param currentName string|nil Current animal name (optional)
---@return boolean Success status
local function setAnimalNameWithGenetics(animal, context, currentName)
    if not animal or not animal.genetics or not animal.genetics.quality then
        return false
    end

    ---Converts genetic value from 0.25-1.75 scale to 00-99 display scale (zero-padded)
    ---@param value number|nil Genetic value to convert
    ---@return string Formatted two-digit string
    local function scaleToNinetyNine(value)
        if not value then
            return "00"
        end

        local num = tonumber(value)
        if not num then
            return "00"
        end

        -- Clamp to valid genetic range
        num = math.min(AnimalNameOverride.GENETICS_MAX, math.max(AnimalNameOverride.GENETICS_MIN, num))

        -- Map genetic range to display range
        local range = AnimalNameOverride.GENETICS_MAX - AnimalNameOverride.GENETICS_MIN
        local scaled = math.floor((num - AnimalNameOverride.GENETICS_MIN) * (AnimalNameOverride.DISPLAY_MAX / range) +
            0.5)
        return string.format("%02d", scaled)
    end

    -- Calculate overall quality as average of all traits (before scaling)
    local traitValues = {
        tonumber(animal.genetics.health) or 0,
        tonumber(animal.genetics.fertility) or 0,
        tonumber(animal.genetics.quality) or 0,
        tonumber(animal.genetics.metabolism) or 0
    }

    if animal.genetics.productivity then
        table.insert(traitValues, tonumber(animal.genetics.productivity) or 0)
    end

    -- Calculate average
    local sum = 0
    for _, value in ipairs(traitValues) do
        sum = sum + value
    end
    local overallQuality = sum / #traitValues

    -- Build quality value from genetics traits
    local overallRating = scaleToNinetyNine(overallQuality)

    local detailTraits = {}
    -- Metabolism (always present)
    table.insert(detailTraits, scaleToNinetyNine(animal.genetics.metabolism))

    -- Health (always present)
    table.insert(detailTraits, scaleToNinetyNine(animal.genetics.health))

    -- Fertility (always present)
    table.insert(detailTraits, scaleToNinetyNine(animal.genetics.fertility))

    -- Quality (always present)
    table.insert(detailTraits, scaleToNinetyNine(animal.genetics.quality))

    -- Productivity (only for some animal types)
    if animal.genetics.productivity then
        table.insert(detailTraits, scaleToNinetyNine(animal.genetics.productivity))
    end

    -- Build quality value based on settings format
    local qualityValue
    if AnimalNameOverride.settings and AnimalNameOverride.settings:getGeneticsFormat() == "short" then
        qualityValue = overallRating
    else
        -- Default to long format
        qualityValue = string.format("%s-%s", overallRating, table.concat(detailTraits, ":"))
    end

    -- Get current name (use provided name or get it from animal)
    if not currentName then
        currentName = ""
        if animal.getName then
            currentName = animal:getName() or ""
        elseif animal.name then
            currentName = animal.name
        end
    end

    -- Remove existing genetics information from name (handles both prefix and postfix)
    local cleanName = currentName
    -- Remove patterns like "[85-85:73:99:97] " from beginning or " [85-85:73:99:97]" from end
    -- Pattern: [number] or [number-number:number:number:number] with optional spaces
    cleanName = string.gsub(cleanName, "^%[[%d]+[%-:]*[%d:]*%] ?", "")
    cleanName = string.gsub(cleanName, " ?%[[%d]+[%-:]*[%d:]*%]$", "")
    if cleanName ~= currentName then
        RmUtils.logTrace(string.format("Removed existing genetics from: '%s', clean name: '%s'", currentName, cleanName))
    end

    -- Add genetics information based on position setting
    local position = "prefix" -- default
    if AnimalNameOverride.settings then
        position = AnimalNameOverride.settings:getGeneticsPosition()
    end

    if cleanName ~= "" then
        if position == "postfix" then
            animal.name = string.format("%s [%s]", cleanName, qualityValue)
        else
            -- Default to prefix
            animal.name = string.format("[%s] %s", qualityValue, cleanName)
        end
    else
        animal.name = string.format("[%s]", qualityValue)
    end

    RmUtils.logTrace(string.format("Updated %s animal name to: '%s'", context, animal.name))
    return true
end

---Adds genetics information to target items in animal screens
---@param self table The controller instance
---@param _ any Unused parameter from appended function
local function addGeneticsToTargetItems(self, _)
    if not self.targetItems then
        return
    end

    RmUtils.logDebug(string.format("Modifying %d target items with genetics info", #self.targetItems))

    for _, item in ipairs(self.targetItems) do
        local animal = item.animal or item.cluster
        setAnimalNameWithGenetics(animal, "target")
    end
end

---Adds genetics information to source items in animal screens
---@param self table The controller instance
---@param _ any Unused parameter from appended function
local function addGeneticsToSourceItems(self, _)
    if not self.sourceItems then
        return
    end

    RmUtils.logDebug(string.format("Modifying %d source items with genetics info", #self.sourceItems))

    for key, item in pairs(self.sourceItems) do
        RmUtils.logTrace(string.format("Processing source item %s: %s", tostring(key), tostring(item)))

        -- Check if this item is a nested table containing multiple animals
        if type(item) == "table" then
            -- Try to process as nested structure first
            for subKey, subItem in pairs(item) do
                if type(subKey) == "number" and type(subItem) == "table" then
                    RmUtils.logTrace(string.format("Processing nested animal %s: %s", tostring(subKey), tostring(subItem)))
                    local animal = subItem.animal or subItem.cluster or subItem
                    setAnimalNameWithGenetics(animal, "nested source")
                end
            end

            -- Also try to process the item itself (in case it's a direct animal)
            -- Note: Not sure if this is needed, but keeping for safety
            local animal = item.animal or item.cluster or item
            setAnimalNameWithGenetics(animal, "direct source")
        end
    end
end

---Overrides the FS25_RealisticLivestock Animal getName function to include genetics
local function overrideAnimalGetName()
    local realisticLivestock = _G.FS25_RealisticLivestock
    if not realisticLivestock or not realisticLivestock.Animal or not realisticLivestock.Animal.getName then
        RmUtils.logWarning("FS25_RealisticLivestock.Animal.getName not available for override")
        return
    end

    -- Store original function for cleanup
    AnimalNameOverride.originalFunctions.animalGetName = realisticLivestock.Animal.getName

    realisticLivestock.Animal.getName = function(self)
        -- Call original getName to get the base name
        local originalName = AnimalNameOverride.originalFunctions.animalGetName(self)

        -- Check if this animal has genetics and apply formatting
        if self.genetics and self.genetics.quality then
            -- Use our reusable function to set the name with genetics, passing the original name
            setAnimalNameWithGenetics(self, "getName", originalName)
            return self.name or originalName
        end

        return originalName
    end

    RmUtils.logInfo("FS25_RealisticLivestock.Animal.getName override applied successfully")
end

---Hooks genetics modification functions to animal screen controllers
---@param controllers table List of controller names to hook
---@param targetFunc function Function to append to initTargetItems
---@param sourceFunc function Function to append to initSourceItems
local function hookControllerFunctions(controllers, targetFunc, sourceFunc)
    for _, controllerName in ipairs(controllers) do
        local controller = _G[controllerName]
        if controller then
            -- Hook initTargetItems
            if controller.initTargetItems then
                controller.initTargetItems = Utils.appendedFunction(controller.initTargetItems, targetFunc)
                RmUtils.logInfo(string.format("%s.initTargetItems appended function applied successfully", controllerName))
            else
                RmUtils.logWarning(string.format("%s.initTargetItems not available", controllerName))
            end

            -- Hook initSourceItems
            if controller.initSourceItems then
                controller.initSourceItems = Utils.appendedFunction(controller.initSourceItems, sourceFunc)
                RmUtils.logInfo(string.format("%s.initSourceItems appended function applied successfully", controllerName))
            else
                RmUtils.logWarning(string.format("%s.initSourceItems not available", controllerName))
            end
        else
            RmUtils.logWarning(string.format("%s controller not found", controllerName))
        end
    end
end

-- List of animal screen controller classes to hook into
local ANIMAL_SCREEN_CONTROLLERS = {
    "AnimalScreenDealer",
    "AnimalScreenDealerFarm",
    "AnimalScreenDealerTrailer",
    "AnimalScreenTrailer",
    "AnimalScreenTrailerFarm"
}

-- Apply controller hooks
hookControllerFunctions(ANIMAL_SCREEN_CONTROLLERS, addGeneticsToTargetItems, addGeneticsToSourceItems)

---Cleanup function to restore original functions
function AnimalNameOverride.delete()
    -- Restore original Animal.getName function
    local originalFunc = AnimalNameOverride.originalFunctions.animalGetName
    local realisticLivestock = _G.FS25_RealisticLivestock

    if originalFunc and realisticLivestock and realisticLivestock.Animal then
        realisticLivestock.Animal.getName = originalFunc
        RmUtils.logInfo("Animal.getName function restored")
    end
end

---Applies the Animal getName override
function AnimalNameOverride.initialize()
    overrideAnimalGetName()
end

-- Override will be applied during RLAdjust initialization, not immediately
