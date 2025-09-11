--
-- Animal Pregnancy Override for Realistic Livestock Adjustments
-- Compatible with FS25_RealisticLivestock v1.2.0.2
--
-- Overrides createPregnancy to:
-- * Support new v1.2.0.2 features: artificial insemination, disease inheritance, castration checks
-- * Select random eligible fathers instead of first available (when no father specified)
-- * Calculate child genetics using advanced BreedingMath.breedOffspring function
-- * Enable offspring genetics to exceed or fall below parent ranges
-- * Maintain full compatibility with multiplayer networking events
--
-- @author Ritter
-- @version 1.2.0.2
--

AnimalPregnancyOverride = {}
local AnimalPregnancyOverride_mt = Class(AnimalPregnancyOverride)

-- Store original functions for cleanup
AnimalPregnancyOverride.originalFunctions = {}

---Overrides the FS25_RealisticLivestock Animal createPregnancy function
---to use random father selection when none set and improved genetic calculations
local function overrideCreatePregnancy()
    if _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal and _G.FS25_RealisticLivestock.Animal.createPregnancy then
        -- Store original function for cleanup
        AnimalPregnancyOverride.originalFunctions.animalCreatePregnancy = _G.FS25_RealisticLivestock.Animal
            .createPregnancy
            .createPregnancy

        _G.FS25_RealisticLivestock.Animal.createPregnancy = function(self, childNum, month, year, father)
            RmUtils.logDebug(string.format(
                "Animal.createPregnancy called for %s with childNum=%d, month=%d, year=%d, father=%s",
                self:getIdentifiers(), childNum, month, year,
                tostring(father and father.getIdentifiers and father:getIdentifiers() or "nil")))

            self.isPregnant = true

            if father == nil then
                -- Default father
                father = {
                    uniqueId = "-1",
                    metabolism = 1.0,
                    quality = 1.0,
                    health = 1.0,
                    fertility = 1.0,
                    productivity = 1.0
                }

                local fatherSubTypeIndex = nil
                local eligibleFathers = {}

                -- Collect all eligible fathers with v1.2.0.2 enhanced checks
                for _, animal in pairs(self.clusterSystem:getAnimals()) do
                    -- Enhanced breeding checks from v1.2.0.2 (Lua 5.1 compatible)
                    if animal.gender == "male" and not animal.isCastrated and animal.genetics.fertility > 0 and animal:getIdentifiers() ~= self.fatherId then
                        -- Species compatibility checks
                        local isCompatible = true
                        if animal.subType == "BULL_WATERBUFFALO" and self.subType ~= "COW_WATERBUFFALO" then
                            isCompatible = false
                        elseif animal.subType == "RAM_GOAT" and self.subType ~= "GOAT" then
                            isCompatible = false
                        elseif self.subType == "COW_WATERBUFFALO" and animal.subType ~= "BULL_WATERBUFFALO" then
                            isCompatible = false
                        elseif self.subType == "GOAT" and animal.subType ~= "RAM_GOAT" then
                            isCompatible = false
                        end

                        if isCompatible then
                            local animalType = animal.animalTypeIndex
                            local animalSubType = animal:getSubType()
                            local maxFertilityMonth = (animalType == AnimalType.COW and 132) or
                                (animalType == AnimalType.SHEEP and 72) or (animalType == AnimalType.HORSE and 300) or
                                (animalType == AnimalType.CHICKEN and 1000) or (animalType == AnimalType.PIG and 48) or
                                120
                            maxFertilityMonth = maxFertilityMonth * animal.genetics.fertility

                            if animalSubType.reproductionMinAgeMonth ~= nil and animal:getAge() >= animalSubType.reproductionMinAgeMonth and animal:getAge() < maxFertilityMonth then
                                table.insert(eligibleFathers, animal)
                            end
                        end
                    end
                end

                -- RANDOM SELECTION: Select random father instead of first eligible
                if #eligibleFathers > 0 then
                    local randomIndex = math.random(1, #eligibleFathers)
                    local selectedFather = eligibleFathers[randomIndex]

                    fatherSubTypeIndex = selectedFather.subTypeIndex
                    father.uniqueId = selectedFather:getIdentifiers()
                    father.metabolism = selectedFather.genetics.metabolism
                    father.quality = selectedFather.genetics.quality
                    father.health = selectedFather.genetics.health
                    father.fertility = selectedFather.genetics.fertility
                    father.productivity = selectedFather.genetics.productivity
                    father.animal = selectedFather

                    RmUtils.logDebug(string.format("Selected random father %s from %d eligible males for %s",
                        selectedFather:getIdentifiers(),
                        #eligibleFathers,
                        self:getIdentifiers()))
                else
                    RmUtils.logInfo(string.format("No eligible fathers found for %s, using default father",
                        self:getIdentifiers()))
                end
            end

            self.impregnatedBy = father
            self.reproduction = 0
            self:changeReproduction(self:getReproductionDelta())

            local genetics = self.genetics

            -- Disease inheritance system
            local mDiseases, fDiseases = self.diseases, father.animal ~= nil and father.animal.diseases or {}
            local diseases = {}

            for _, disease in pairs(mDiseases) do
                table.insert(diseases, { ["parent"] = father.animal, ["disease"] = disease })
            end

            for _, disease in pairs(fDiseases) do
                local hasDisease = false
                for _, mDisease in pairs(mDiseases) do
                    if mDisease.type.title == disease.type.title then
                        hasDisease = true
                        break
                    end
                end
                if not hasDisease then
                    table.insert(diseases, { ["parent"] = self, ["disease"] = disease })
                end
            end

            local children = {}
            local hasMale, hasFemale = false, false

            for _ = 1, childNum do
                local gender = math.random() >= 0.5 and "male" or "female"
                local subTypeIndex

                if fatherSubTypeIndex ~= nil and math.random() >= 0.5 then
                    subTypeIndex = fatherSubTypeIndex + (gender == "male" and 0 or -1)
                else
                    subTypeIndex = self.subTypeIndex + (gender == "male" and 1 or 0)
                end

                local child = _G.FS25_RealisticLivestock.Animal.new(-1, 100, 0, gender, subTypeIndex, 0, false, false,
                    false, nil, nil, self:getIdentifiers(), father.uniqueId)

                -- ADVANCED GENETICS: Use BreedingMath instead of simple random
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
                if genetics.productivity ~= nil then
                    productivity = BreedingMath.breedOffspring(genetics.productivity, father.productivity or 1,
                        { sd = BreedingMath.SD_CONST })
                end

                child:setGenetics({
                    ["metabolism"] = metabolism,
                    ["quality"] = quality,
                    ["health"] = healthGenetics,
                    ["fertility"] = fertility,
                    ["productivity"] = productivity
                })

                -- Disease inheritance
                for _, disease in pairs(diseases) do
                    disease.disease:affectReproduction(child, disease.parent)
                end

                table.insert(children, child)

                if gender == "male" then
                    hasMale = true
                else
                    hasFemale = true
                end
            end

            -- Freemartin effect for cattle twins
            if self.animalTypeIndex == AnimalType.COW and hasMale and hasFemale then
                for _, child in pairs(children) do
                    if child.gender == "female" and math.random() >= 0.03 then
                        child.genetics.fertility = 0
                    end
                end
            end

            -- Pregnancy timing calculation
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

            -- DAYS_PER_MONTH is not exported by FS25_RealisticLivestock, use standard calendar
            local daysPerMonth = {
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

            self.pregnancy = {
                ["duration"] = reproductionDuration,
                ["expected"] = {
                    ["day"] = expectedDay,
                    ["month"] = expectedMonth,
                    ["year"] = expectedYear
                },
                ["pregnancies"] = children
            }

            -- Network event broadcasting
            if g_server and _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.AnimalPregnancyEvent then
                g_server:broadcastEvent(_G.FS25_RealisticLivestock.AnimalPregnancyEvent.new(
                    self.clusterSystem ~= nil and self.clusterSystem.owner or nil, self))
            end

            RmUtils.logDebug(string.format("Pregnancy created for %s, due %d/%d with %d children",
                self:getIdentifiers(),
                expectedMonth,
                expectedYear,
                childNum))

            -- Broadcast pregnancy event (same as updated base version)
            if g_server ~= nil then
                g_server:broadcastEvent(_G.FS25_RealisticLivestock.AnimalPregnancyEvent.new(
                    self.clusterSystem ~= nil and self.clusterSystem.owner or nil, self))
            end
        end

        RmUtils.logInfo("Animal.createPregnancy override applied for random father selection")
    else
        RmUtils.logWarning("Animal.createPregnancy not available for override")
    end
end

---Applies the Animal createPregnancy override
function AnimalPregnancyOverride.initialize()
    overrideCreatePregnancy()
end

---Cleanup function to restore original functions
function AnimalPregnancyOverride.delete()
    -- Restore original Animal.createPregnancy function
    if AnimalPregnancyOverride.originalFunctions.animalCreatePregnancy and _G.FS25_RealisticLivestock and _G.FS25_RealisticLivestock.Animal then
        _G.FS25_RealisticLivestock.Animal.createPregnancy = AnimalPregnancyOverride.originalFunctions
            .animalCreatePregnancy
            .animalCreatePregnancy
        RmUtils.logInfo("Animal.createPregnancy function restored")
    end
end

-- Override will be applied during RLAdjust initialization, not immediately
