--
-- Animal Name Override for Realistic Livestock Adjustments
-- Overrides animals name to display genetics information
--
-- @author Ritter
-- @version 1.0.0.0
--

AnimalNameOverride = {}
local AnimalNameOverride_mt = Class(AnimalNameOverride)

-- Store original functions for cleanup
AnimalNameOverride.originalFunctions = {}

-- function to construct animal name with genetics quality
local function setAnimalNameWithGenetics(animal, context, currentName)
    if not animal or not animal.genetics or not animal.genetics.quality then
        return false
    end

    -- Function to convert 0.25-1.75 scale to 00-99 scale (zero-padded)
    local function scaleToNinetyNine(value)
        if not value then return "00" end
        local num = tonumber(value)
        if not num then return "00" end
        -- Convert 0.25-1.75 to 0-99 and round to nearest integer
        -- First clamp to valid range
        num = math.min(1.75, math.max(0.25, num))
        -- Map 0.25-1.75 range to 0-99
        local scaled = math.floor((num - 0.25) * (99 / (1.75 - 0.25)) + 0.5)
        return string.format("%02d", scaled)
    end

    -- Calculate overall quality as average of all traits (before scaling)
    local traitValues = {}
    table.insert(traitValues, tonumber(animal.genetics.health) or 0)
    table.insert(traitValues, tonumber(animal.genetics.fertility) or 0)
    table.insert(traitValues, tonumber(animal.genetics.quality) or 0)
    table.insert(traitValues, tonumber(animal.genetics.metabolism) or 0)

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

    local qualityValue = string.format("%s-%s", overallRating, table.concat(detailTraits, ":"))

    -- Get current name (use provided name or get it from animal)
    if not currentName then
        currentName = ""
        if animal.getName then
            currentName = animal:getName() or ""
        elseif animal.name then
            currentName = animal.name
        end
    end

    -- Remove existing [overallQuality:detailTraits] prefix if present
    local cleanName = currentName
    if string.find(currentName, "^%[") then
        -- Remove pattern like "[85-85:73:99:97] " from the beginning
        cleanName = string.gsub(currentName, "^%[[%d]+%-[%d%:]+%] ?", "")
        RmUtils.logTrace(string.format("Removed existing quality from: '%s', clean name: '%s'", currentName, cleanName))
    end

    -- Add new genetics quality
    if cleanName ~= "" then
        animal.name = string.format("[%s] %s", qualityValue, cleanName)
    else
        animal.name = string.format("[%s]", qualityValue)
    end

    RmUtils.logTrace(string.format("Updated %s animal name to: '%s'", context, animal.name))
    return true
end

-- Create a generic function to add genetics to target items
local function addGeneticsToTargetItems(self, _)
    if self.targetItems then
        RmUtils.logDebug(string.format("Modifying %d target items with genetics info", #self.targetItems))

        for _, item in ipairs(self.targetItems) do
            local animal = item.animal or item.cluster
            setAnimalNameWithGenetics(animal, "target")
        end
    end
end

-- Create a generic function to add genetics to source items
local function addGeneticsToSourceItems(self, _)
    if self.sourceItems then
        RmUtils.logDebug(string.format("Modifying %d source items with genetics info", #self.sourceItems))

        for key, item in pairs(self.sourceItems) do
            RmUtils.logTrace(string.format("Processing source item %s: %s", tostring(key), tostring(item)))

            -- Check if this item is a nested table containing multiple animals
            if type(item) == "table" then
                -- Try to process as nested structure first
                for subKey, subItem in pairs(item) do
                    if type(subKey) == "number" and type(subItem) == "table" then
                        RmUtils.logTrace(string.format("Processing nested animal %s: %s", tostring(subKey),
                            tostring(subItem)))
                        local animal = subItem.animal or subItem.cluster or subItem
                        setAnimalNameWithGenetics(animal, "nested source")
                    end
                end

                -- Also try to process the item itself (in case it's a direct animal)
                -- not sure if this is needed, but keeping for safety
                local animal = item.animal or item.cluster or item
                setAnimalNameWithGenetics(animal, "direct source")
            end
        end
    end
end

-- Override the FS25_RealisticLivestock Animal getName function
local function overrideAnimalGetName()
    if _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal and _G.FS25_RealisticLivestock.Animal.getName then
        -- Store original function for cleanup
        AnimalNameOverride.originalFunctions.animalGetName = _G.FS25_RealisticLivestock.Animal.getName

        _G.FS25_RealisticLivestock.Animal.getName = function(self)
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
    else
        RmUtils.logWarning("FS25_RealisticLivestock.Animal.getName not available for override")
    end
end

-- Utility function to hook genetics modification functions to animal screen controllers
local function hookControllerFunctions(controllers, targetFunc, sourceFunc)
    for _, controllerName in ipairs(controllers) do
        local controller = _G[controllerName]

        -- Hook initTargetItems
        if controller and controller.initTargetItems then
            controller.initTargetItems = Utils.appendedFunction(controller.initTargetItems, targetFunc)
            RmUtils.logInfo(string.format("%s.initTargetItems appended function applied successfully", controllerName))
        else
            RmUtils.logWarning(string.format("%s.initTargetItems not available", controllerName))
        end

        -- Hook initSourceItems
        if controller and controller.initSourceItems then
            controller.initSourceItems = Utils.appendedFunction(controller.initSourceItems, sourceFunc)
            RmUtils.logInfo(string.format("%s.initSourceItems appended function applied successfully", controllerName))
        else
            RmUtils.logWarning(string.format("%s.initSourceItems not available", controllerName))
        end
    end
end

-- Hook into all the different animal screen controller classes
local controllers = {
    "AnimalScreenDealer",
    "AnimalScreenDealerFarm",
    "AnimalScreenDealerTrailer",
    "AnimalScreenTrailer",
    "AnimalScreenTrailerFarm"
}

hookControllerFunctions(controllers, addGeneticsToTargetItems, addGeneticsToSourceItems)

-- Cleanup function to restore original functions
function AnimalNameOverride.delete()
    -- Restore original Animal.getName function
    if AnimalNameOverride.originalFunctions.animalGetName and _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal then
        _G.FS25_RealisticLivestock.Animal.getName = AnimalNameOverride.originalFunctions.animalGetName
        RmUtils.logInfo("Animal.getName function restored")
    end
end

-- Apply the Animal getName override
overrideAnimalGetName()
