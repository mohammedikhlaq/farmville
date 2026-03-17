# Adam And Eshaals Farm

A FarmVille-inspired Roblox experience built with Lua.
Plant crops, tend animals, unlock plots, and grow the best farm!

---

## Setup (Roblox Studio)

### Option A – Manual (no tools required)

1. Open **Roblox Studio** and create a new **Baseplate** place.
2. For each script file below, create the corresponding instance in the
   Explorer panel and paste in the file contents:

| File | Roblox Location | Instance Type |
|------|----------------|---------------|
| `src/ReplicatedStorage/GameConfig.lua` | ReplicatedStorage > GameModules > GameConfig | ModuleScript |
| `src/ReplicatedStorage/CropData.lua` | ReplicatedStorage > GameModules > CropData | ModuleScript |
| `src/ReplicatedStorage/AnimalData.lua` | ReplicatedStorage > GameModules > AnimalData | ModuleScript |
| `src/ReplicatedStorage/Remotes.lua` | ReplicatedStorage > GameModules > Remotes | ModuleScript |
| `src/ServerScriptService/DataManager.server.lua` | ServerScriptService > DataManager | Script |
| `src/ServerScriptService/FarmManager.server.lua` | ServerScriptService > FarmManager | Script |
| `src/ServerScriptService/ShopManager.server.lua` | ServerScriptService > ShopManager | Script |
| `src/ServerScriptService/GameManager.server.lua` | ServerScriptService > GameManager | Script |
| `src/StarterPlayer/StarterPlayerScripts/ClientController.client.lua` | StarterPlayer > StarterPlayerScripts > ClientController | LocalScript |
| `src/StarterPlayer/StarterPlayerScripts/FarmUI.client.lua` | StarterPlayer > StarterPlayerScripts > FarmUI | LocalScript |

3. In ReplicatedStorage, create a **Folder** named `GameModules` and place
   all four ModuleScripts inside it.

### Option B – Rojo (recommended)

1. Install [Rojo](https://rojo.space) (VS Code extension + CLI).
2. Run `rojo serve` from this folder.
3. Connect in Roblox Studio via the Rojo plugin.

---

## Gameplay

| Action | How |
|--------|-----|
| **Plant** | Click the Shop toolbar button, select a seed, then click an empty plot |
| **Harvest** | Click a ready crop (green plot) |
| **Water** | Click the Water toolbar button, then click a growing crop |
| **Unlock plot** | Click a locked (grey) plot |
| **Buy seeds** | Open Shop, then Buy x1 or Buy x10 |
| **Check inventory** | Click the Inv button (top-right) |

### Crops (starter)

| Crop | Time | Cost | Reward | Level |
|------|------|------|--------|-------|
| Strawberry | 1 min | 10 | 35 | 1 |
| Wheat | 2 min | 15 | 50 | 1 |
| Carrot | 3 min | 30 | 90 | 3 |
| Tomato | 4 min | 40 | 140 | 4 |
| Corn | 5 min | 50 | 180 | 5 |
| Sunflower | 6 min | 60 | 250 | 6 |
| Pumpkin | 8 min | 75 | 320 | 8 |
| Blueberry | 10 min | 100 | 450 | 10 |
| Watermelon | 15 min | 150 | 700 | 15 |
| Golden Crop | 30 min | 500 | 2500 | 20 |

### Animals

| Animal | Cost | Product | Reward | Level |
|--------|------|---------|--------|-------|
| Chicken | 200 | Egg | 30 | 2 |
| Duck | 350 | Feather Down | 60 | 4 |
| Sheep | 450 | Wool | 70 | 7 |
| Cow | 500 | Milk | 80 | 5 |
| Pig | 600 | Truffle | 150 | 10 |

---

## Customising Assets

All `ImageId` and `SoundId` values are placeholders. Replace them with real
**free** asset IDs from the Roblox Creator Marketplace (Toolbox):

- **Toolbox > Audio** – search "farm", "harvest", "coins" for free sounds.
- **Toolbox > Decals/Images** – search crop names for free images.

---

## Architecture

```
ServerScriptService
  DataManager   – DataStore persistence, coin/XP helpers
  FarmManager   – Plot planting / watering / harvesting / wilting
  ShopManager   – Seed & animal purchases
  GameManager   – World setup, plot parts, player events

ReplicatedStorage > GameModules
  GameConfig    – All tunable constants
  CropData      – Crop definitions & helpers
  AnimalData    – Animal definitions & helpers
  Remotes       – RemoteEvent / RemoteFunction instances

StarterPlayerScripts
  ClientController – Plot click → remote fire, sound, visuals
  FarmUI           – All ScreenGui building & data-driven updates
```

---

## License

Free to use and modify for your Roblox experience.
Made with love for Adam and Eshaal.
