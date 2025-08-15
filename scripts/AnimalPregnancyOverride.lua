--
-- Animal Pregnancy Override for Realistic Livestock Adjustments
-- Overrides createPregnancy to
-- * select random eligible fathers instead of first available
-- * calculate child genetics using breed_offspring function
-- * breed_offspring function is more variable than original and enables
--   the childrens genetics to be higher and lower than the parents'
--
-- @author Ritter
-- @version 1.0.0.0
--

AnimalPregnancyOverride = {}
local AnimalPregnancyOverride_mt = Class(AnimalPregnancyOverride)

-- Store original functions for cleanup
AnimalPregnancyOverride.originalFunctions = {}

---Overrides the FS25_RealisticLivestock Animal createPregnancy function
---to use random father selection and improved genetic calculations
local function overrideCreatePregnancy()
    if _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal and _G.FS25_RealisticLivestock.Animal.createPregnancy then
        -- Store original function for cleanup
        AnimalPregnancyOverride.originalFunctions.animalCreatePregnancy = _G.FS25_RealisticLivestock.Animal
            .createPregnancy

        _G.FS25_RealisticLivestock.Animal.createPregnancy = function(self, childNum, month, year)
            RmUtils.logDebug(string.format("Animal.createPregnancy called for %s with childNum=%d, month=%d, year=%d",
                self.farmId .. " " .. self.uniqueId, childNum, month, year))
            local fertility = self.genetics.fertility

            -- Set pregnancy state
            self.isPregnant = true

            -- Default father (same as original)
            local father = {
                uniqueId = "-1",
                metabolism = 1.0,
                quality = 1.0,
                health = 1.0,
                fertility = 1.0,
                productivity = 1.0
            }

            local fatherSubTypeIndex
            local eligibleFathers = {}

            -- Collect all eligible fathers
            for _, animal in pairs(self.clusterSystem:getAnimals()) do
                if animal.gender == "male" then
                    -- Same compatibility checks as original
                    local isCompatible = true
                    if animal.subType == "BULL_WATERBUFFALO" and self.subType ~= "COW_WATERBUFFALO" then isCompatible = false end
                    if animal.subType == "RAM_GOAT" and self.subType ~= "GOAT" then isCompatible = false end
                    if self.subType == "COW_WATERBUFFALO" and animal.subType ~= "BULL_WATERBUFFALO" then isCompatible = false end
                    if self.subType == "GOAT" and animal.subType ~= "RAM_GOAT" then isCompatible = false end

                    if isCompatible then
                        -- Same age checks as original
                        local animalType = animal.animalTypeIndex
                        local animalSubType = animal:getSubType()
                        local maxFertilityMonth = (animalType == AnimalType.COW and 132) or
                            (animalType == AnimalType.SHEEP and 72) or (animalType == AnimalType.HORSE and 300) or
                            (animalType == AnimalType.CHICKEN and 1000) or (animalType == AnimalType.PIG and 48) or 120
                        maxFertilityMonth = maxFertilityMonth * animal.genetics.fertility

                        if animalSubType.reproductionMinAgeMonth ~= nil and animal:getAge() >= animalSubType.reproductionMinAgeMonth and animal:getAge() < maxFertilityMonth then
                            table.insert(eligibleFathers, animal)
                        end
                    end
                end
            end

            -- Select random father if any eligible ones found
            if #eligibleFathers > 0 then
                local randomIndex = math.random(1, #eligibleFathers)
                local selectedFather = eligibleFathers[randomIndex]

                -- Update father info with selected father's data
                fatherSubTypeIndex = selectedFather.subTypeIndex
                father.uniqueId = selectedFather.farmId .. " " .. selectedFather.uniqueId
                father.metabolism = selectedFather.genetics.metabolism
                father.quality = selectedFather.genetics.quality
                father.health = selectedFather.genetics.health
                father.fertility = selectedFather.genetics.fertility
                father.productivity = selectedFather.genetics.productivity

                RmUtils.logDebug(string.format("Selected random father %s from %d eligible males for %s",
                    selectedFather.farmId .. " " .. selectedFather.uniqueId,
                    #eligibleFathers,
                    self.farmId .. " " .. self.uniqueId))
            else
                RmUtils.logInfo(string.format("No eligible fathers found for %s, using default father",
                    self.farmId .. " " .. self.uniqueId))
            end

            -- Set up pregnancy with selected father (same structure as original)
            self.impregnatedBy = father
            self.reproduction = 0

            self:changeReproduction(self:getReproductionDelta())

            -- Get genetics for breeding calculations
            local genetics = self.genetics

            -- Create children with calculated genetics (same as original)
            local children = {}
            local hasMale, hasFemale = false, false

            for i = 1, childNum do
                local gender = math.random() >= 0.5 and "male" or "female"
                local subTypeIndex

                if fatherSubTypeIndex ~= nil and math.random() >= 0.5 then
                    subTypeIndex = fatherSubTypeIndex + (gender == "male" and 0 or -1)
                else
                    subTypeIndex = self.subTypeIndex + (gender == "male" and 1 or 0)
                end

                -- Create child with genetics (same as original Animal.new call)
                local child = _G.FS25_RealisticLivestock.Animal.new(-1, 100, 0, gender, subTypeIndex, 0, false, false,
                    false, nil, nil, self.farmId .. " " .. self.uniqueId, father.uniqueId)

                -- Calculate child genetics using breed_offspring function
                local metabolism = BreedingMath.breedOffspring(genetics.metabolism, father.metabolism,
                    { sd = BreedingMath.SD_CONST })
                local quality = BreedingMath.breedOffspring(genetics.quality, father.quality,
                    { sd = BreedingMath.SD_CONST })
                local healthGenetics = BreedingMath.breedOffspring(genetics.health, father.health,
                    { sd = BreedingMath.SD_CONST })

                local fertility = 0
                if math.random() > 0.001 then
                    fertility = BreedingMath.breedOffspring(genetics.fertility, father.fertility,
                        { sd = BreedingMath.SD_CONST })
                end

                local productivity = nil
                if genetics.productivity ~= nil and father.productivity ~= nil then
                    productivity = BreedingMath.breedOffspring(genetics.productivity, father.productivity,
                        { sd = BreedingMath.SD_CONST })
                end

                -- Set child genetics
                child:setGenetics({
                    ["metabolism"] = metabolism,
                    ["quality"] = quality,
                    ["health"] = healthGenetics,
                    ["fertility"] = fertility,
                    ["productivity"] = productivity
                })

                table.insert(children, child)

                if gender == "male" then
                    hasMale = true
                else
                    hasFemale = true
                end
            end

            -- Apply freemartin effect for cattle twins (same as original)
            if self.animalTypeIndex == AnimalType.COW and hasMale and hasFemale then
                for _, child in pairs(children) do
                    if child.gender == "female" and math.random() >= 0.03 then
                        child.genetics.fertility = 0
                    end
                end
            end

            -- Calculate pregnancy timing (matching original logic)
            local reproductionDuration = self:getSubType().reproductionDurationMonth

            if math.random() >= 0.99 then
                if math.random() >= 0.95 then
                    reproductionDuration = reproductionDuration + math.random() >= 0.75 and -2 or 2
                else
                    reproductionDuration = reproductionDuration + math.random() >= 0.85 and -1 or 1
                end
                reproductionDuration = math.max(reproductionDuration, 2)
            end

            local expectedYear = year + math.floor(reproductionDuration / 12)
            local expectedMonth = month + (reproductionDuration % 12)

            while expectedMonth > 12 do
                expectedMonth = expectedMonth - 12
                expectedYear = expectedYear + 1
            end

            local daysPerMonth = _G.RealisticLivestock and _G.RealisticLivestock.DAYS_PER_MONTH or {
                [1] = 31,
                [2] = 28,
                [3] = 31,
                [4] = 30,
                [5] = 31,
                [6] = 30,
                [7] = 31,
                [8] = 31,
                [9] = 30,
                [10] = 31,
                [11] = 30,
                [12] = 31
            }
            local expectedDay = math.random(1, daysPerMonth[expectedMonth])

            self.birthMonth = expectedMonth
            self.birthYear = expectedYear

            -- Store pregnancy data (same structure as original)
            self.pregnancy = {
                duration = reproductionDuration,
                expected = {
                    day = expectedDay,
                    month = self.birthMonth,
                    year = self.birthYear
                },
                pregnancies = children
            }

            RmUtils.logDebug(string.format("Pregnancy created for %s, due %d/%d with %d children",
                self.farmId .. " " .. self.uniqueId,
                self.birthMonth,
                self.birthYear,
                childNum))
        end

        RmUtils.logInfo("Animal.createPregnancy override applied for random father selection")
    else
        RmUtils.logWarning("Animal.createPregnancy not available for override")
    end
end

---Cleanup function to restore original functions
function AnimalPregnancyOverride.delete()
    -- Restore original Animal.createPregnancy function
    if AnimalPregnancyOverride.originalFunctions.animalCreatePregnancy and _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal then
        _G.FS25_RealisticLivestock.Animal.createPregnancy = AnimalPregnancyOverride.originalFunctions
            .animalCreatePregnancy
        RmUtils.logInfo("Animal.createPregnancy function restored")
    end
end

-- Apply the override
overrideCreatePregnancy()
