# Realistic Livestock Adjustments

A Farming Simulator 2025 mod that provides some adjustments to the [Realistic Livestock](https://github.com/Arrow-kb/FS25_RealisticLivestock) mod.

> [!CAUTION]
> This adjustment mod can break any time FS25, the Realistic Livestock mod or this mod is updated. Really, it can crash your game at any time. Do not install this if you care about your savegame. Use at your own risk!

## Overview

This mod changes the Realistic Livestock experience by adding:
- Automatically updating genetic information as part of the animal names
- Sorting animals by genetics in selection UIs. "Better" animals appear first.
- Disease status indicators in animal names (D=infected, T=treating, I=immune, C=carrier)
- Changes to the pregnancy system to generate more varied offspring
  - Randomized father selection from eligible candidates
  - Alternative genetic calculations for offspring traits, allowing for a wider range of potential outcomes

## Requirements

- FS25_RealisticLivestock mod (required dependency)

## Features

### Animal Name Display
- Automatically adds genetic information to animal names
- **Configurable display formats**:
  - **Short format**: `[85]` (overall genetics 00-99, default)
  - **Long format**: `[85-85:73:99:97]` (overall + individual traits)
- **Configurable position**:
  - **Prefix**: `[85] Animal Name` (default)
  - **Postfix**: `Animal Name [85]`
- **Disease status indicators** (shown when animal has diseases):
  - `D` = infected (not being treated) - e.g., `[D-85]`
  - `T` = being treated - e.g., `[T-85]`
  - `I` = immune (cured with immunity) - e.g., `[I-85]`
  - `C` = carrier (not infected) - e.g., `[C-85]`
- Compatible with dealer, farm, and trailer animal interfaces + in-game menu

### Pregnancy System
- Randomized father selection from eligible candidates, instead of the first available
- Alternative genetic calculations for offspring traits
  - Allowing for a wider range of potential outcomes
  - Uses the average of both parents' traits as a baseline for calculations and standard deviation for variation
  - Offspring traits can be lower or higher than parents, allowing for more genetic diversity
  - Fine-tune if you want to adjust the level of genetic variation

## Configuration

### Settings File

The mod creates a configurable settings file in your savegame folder:
- **Location**: `Documents/My Games/FarmingSimulator2025/savegameX/rla_settings.xml`
- **Auto-created**: File is created automatically with default settings on first run
- **Live reload**: Changes can be applied without restarting using console commands

### Available Settings

#### geneticsPosition
- `"prefix"` - Shows genetics before animal name: `[85] Animal Name` (default)
- `"postfix"` - Shows genetics after animal name: `Animal Name [85]`

#### geneticsFormat  
- `"short"` - Shows only overall quality: `[85]` (default)
- `"long"` - Shows detailed traits: `[85-85:73:99:97]`

### Example Settings File

```xml
<?xml version="1.0" encoding="utf-8" standalone="no" ?>
<settings comment="RLA Settings: geneticsPosition=[prefix|postfix], geneticsFormat=[short|long]">
    <animalNameOverride geneticsPosition="prefix" geneticsFormat="short" />
</settings>
```

### Console Commands

Use these in-game console commands to manage settings:
- `rlaShowSettings` - Display current settings
- `rlaReloadSettings` - Reload settings from file (apply changes)
- `rlaSaveSettings` - Manually save settings to file
- `rlaTestPath` - Show settings file path

### Helper Files

The mod also creates `rla_settings_info.txt` in your savegame folder with usage instructions.

## Development Status

**Status**: Early Development - Use at your own risk!

⚠️ **Warning**: This mod can fail at any time. Do not use in important save games.
