# 🌻 Adam And Eshaals Farm

A FarmVille-inspired Roblox experience with farming, interactive animals, a SimCity-style city builder, and Monopoly-style land ownership.

> Built with pure Lua + [Rojo](https://rojo.space). No paid assets required.

---

## Quick Start

### Prerequisites
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo CLI](https://github.com/rojo-rbx/rojo/releases) (v7.x) placed on your PATH
  *(prebuilt binary also works at `C:/Users/<you>/bin/rojo.exe`)*

### Build & Play
```bash
# From the project root:
rojo build default.project.json --output AdamAndEshaalsFarm.rbxlx
```
Open `AdamAndEshaalsFarm.rbxlx` in Roblox Studio, then press **F5** (Play).
Your avatar spawns on solid ground in front of the farm gate.

---

## World Layout

```
          [ Horse Paddock ]   [ Cow Pasture ]
  [ Goat ]  [ Sheep Pasture ]    [ Bull Paddock ]
[ Chickens ]  [ Duck Pond ]   [ Pig Pen ]
                                  [ Slaughterhouse ]  [ Barn ]
              ★ PLAYER FARM ★
        (Spawn → Gate → Plot Grid)
                              [ Hartley Farm ]  ← NPC farm
     [ Green Acres ] ↗               ↑
                         [ Sunny Fields ]

                                                  [ Adam & Eshaals City ] →
```

| Location | Position |
|----------|----------|
| Player spawn | X=0, Z=-28 |
| Player farm | X=0, Z=0 (5×5 plot grid) |
| Barn | X=30, Z=0 |
| Slaughterhouse | X=52, Z=-22 |
| NPC Farm 1 – Hartley | X=-55, Z=0 |
| NPC Farm 2 – Green Acres | X=-60, Z=55 |
| NPC Farm 3 – Sunny Fields | X=10, Z=78 |
| City Zone | X=65 onwards |

---

## Farming

### Plot Actions

Click any farm plot to open the action menu.

| Action | How | Result |
|--------|-----|--------|
| **Buy Seeds** | Open Shop → choose crop → Buy | Adds seeds to inventory |
| **Plant** | Select seed in toolbar → click empty plot | Starts growth timer |
| **Water** | Click a growing crop | Speeds up growth by 50% |
| **Harvest** | Click a ready (green) plot | Earns coins + XP |
| **Unlock Plot** | Click a locked (grey) plot | Costs coins, expands farm |

### Crops

| Crop | Grow Time | Seed Cost | Harvest Reward | Min Level |
|------|-----------|-----------|----------------|-----------|
| Strawberry | 1 min | 10c | 35c | 1 |
| Wheat | 2 min | 15c | 50c | 1 |
| Carrot | 3 min | 30c | 90c | 3 |
| Tomato | 4 min | 40c | 140c | 4 |
| Corn | 5 min | 50c | 180c | 5 |
| Sunflower | 6 min | 60c | 250c | 6 |
| Pumpkin | 8 min | 75c | 320c | 8 |
| Blueberry | 10 min | 100c | 450c | 10 |
| Watermelon | 15 min | 150c | 700c | 15 |
| Golden Crop | 30 min | 500c | 2500c | 20 |

> **Tip:** Crops wilt if left too long after ripening — harvest promptly!

---

## Animals

Eight animal species roam the farm in distinct zones. Walk up to any animal and watch for the **ProximityPrompt** bubble (press the displayed key).

### Interactions at a Glance

| Animal | Key E | Key F | Passive |
|--------|-------|-------|---------|
| **Cow** | 🥛 Milk (+25c, 5-min CD, 1.5s hold) | 🔪 Slaughter (+150c, 2s hold) | — |
| **Goat** | 🥛 Milk (+15c, 5-min CD) | 🐾 Lead to Slaughterhouse | — |
| **Sheep** | ✂ Shear Wool (+40c, 5-min CD, 2s hold) | 🐾 Lead to Slaughterhouse | — |
| **Pig** | — | 🐾 Lead to Slaughterhouse | — |
| **Chicken** | 🥚 Collect egg (+10c) | 🐾 Pick Up | Lays egg every ~3 min |
| **Duck** | 🦆 Collect egg (+15c) | 🐾 Pick Up | Lays egg every ~4 min |
| **Bull** | — | 🔪 Slaughter (+200c, 2s hold) | — |
| **Horse** | — | 🔪 Slaughter (+100c, 2s hold) | — |

### Slaughterhouse

The **🥩 Slaughterhouse** is the dark red building east of the barn (X=52, Z=-22).

**To use it:**
1. Walk up to a chicken, duck, pig, sheep, or goat.
2. Press **F** — you will carry small animals (chicken/duck) or lead larger ones (pig/sheep/goat) behind you.
3. Walk to the Slaughterhouse door.
4. Press **E** — hold for 1 second — to process the animal and collect coins.

> Large animals (cow, bull, horse) are slaughtered directly via their own **F** prompt — no carrying required.

All slaughtered animals **respawn automatically after 60 seconds**.

### Eggs

Chickens and ducks periodically drop egg parts on the ground near where they are standing. Walk up to a glowing white egg and press **E** to collect it for coins. Uncollected eggs disappear after 5 minutes.

---

## NPC Farms

Three computer-driven farms run automatically in the background and deposit earnings into the city treasury (shared among all players).

| Farm | Crop | Cycle | Revenue |
|------|------|-------|---------|
| Hartley Farm | Wheat | 90s | +120c |
| Green Acres | Corn | 120s | +180c |
| Sunny Fields | Tomatoes | 75s | +100c |

Watch the plot labels on each farm cycle through: **Empty → Planted → Sprouting → Growing → Ready! → Harvested!**

Treasury income is distributed to all online players every 60 seconds.

---

## City Builder

Walk **east** past the barn (~65 studs) to reach **Adam & Eshaals City** — a 10×10 grid of purchasable plots.

A dirt road connects the barn exit to the city entrance. Look for the blue **"Adam & Eshaals City"** sign.

### Mode Toggle

Press the **🏙 City Mode** button (bottom-centre of screen) to switch between Farm Mode and City Mode. In City Mode, clicking city plots opens the buy/build menus.

### Step 1 — Buy a Plot

Click any green **"Buy $500"** plot to open the purchase panel, then confirm. The plot turns yellow (owned, empty).

### Step 2 — Build on Your Plot

Click your owned plot to open the **Build Menu** with tabbed categories:

| Category | Buildings |
|----------|-----------|
| 🏠 Residential | Small House, Medium House, Apartment, Mansion |
| 🏪 Commercial | Shop, Market, Shopping Mall, Bank |
| 🏭 Industrial | Factory, Warehouse |
| 🚔 Services | Police Station, Fire Station, Hospital, School, University, Park, Stadium |
| ⚡ Infrastructure | Power Plant, Solar Farm, Water Tower, Road |
| 🌾 Farm | Greenhouse, Windmill, Grain Silo, **🥩 Slaughterhouse**, Animal Pen, Horse Stable |

Each building shows its **cost**, **income/min**, and stat effects (population, happiness, safety, power, water).

### Step 3 — Earn Income

Every **60 seconds**, each building automatically pays its income to the owning player. Keep an eye on the **City Stats** dashboard (top-right corner).

### City Stats Dashboard

| Stat | Meaning |
|------|---------|
| 👥 Population | Total residents in your city |
| 😊 Happiness | 0–100 — affects income multipliers |
| 🚔 Safety | Reduces crime (police/fire buildings) |
| ❤ Health | Hospital and park coverage |
| ⚡ Power | Net supply minus demand (go negative = unhappy) |
| 💧 Water | Net water supply (same rule) |
| 💰 Income | Total coins earned per minute from all buildings |

> **Warning:** If power or water goes negative, happiness drops fast! Build a Power Plant or Solar Farm early.

### Monopoly Rent

If another player clicks **your** plot, they pay you **5% of the building cost** as rent — just like Monopoly!

### Building Tips

- Build a **Park** first — cheapest happiness boost per coin.
- Always pair residential buildings with a **Power Plant** or **Solar Farm**.
- **Slaughterhouse** earns the most per minute (+250c) but hurts happiness and health — offset with a Hospital and Park nearby.
- **University** unlocks a research income bonus on top of education stats.
- A **Stadium** gives the biggest single happiness boost (+12) if you can afford it.

---

## Progression

| System | How to Earn XP / Level Up |
|--------|--------------------------|
| Farm | Each harvest gives XP. Higher-level crops give more. |
| Level gate | Some crops and city buildings require a minimum player level. |
| Coins | Earned from harvests, milking, shearing, eggs, slaughter, city income, and NPC treasury payouts. |
| Data | Progress is saved to Roblox DataStore automatically every few minutes and on leave. |

---

## Controls Summary

| Input | Action |
|-------|--------|
| **Click** plot | Plant / Water / Harvest / Unlock |
| **E** near animal | Milk, Shear, or Collect egg |
| **F** near animal | Pick Up / Lead / Slaughter |
| **E** at Slaughterhouse door | Process carried animal |
| **City Mode button** | Toggle city interaction |
| **Click city plot** | Buy land or open Build Menu |

---

## Project Structure

```
AdamAndEshaalsFarm/
├── default.project.json          Rojo project file
├── AdamAndEshaalsFarm.rbxlx      Built place file (open in Studio)
└── src/
    ├── ReplicatedStorage/
    │   └── GameModules/
    │       ├── GameData.lua       Crop definitions, XP table, config
    │       ├── GameConfig.lua     Tunable constants
    │       ├── CropData.lua       Crop helpers
    │       ├── AnimalData.lua     Animal definitions
    │       ├── BuildingData.lua   City building definitions + stats
    │       └── Remotes.lua        RemoteEvent module
    ├── ServerScriptService/
    │   ├── Main.server.lua        World builder, farm logic, _CoinAPI
    │   ├── AnimalManager.server.lua  Animal AI, interactions, eggs, slaughter
    │   ├── NPCFarmManager.server.lua 3 auto-cycling NPC farms
    │   ├── CityManager.server.lua    City grid, buildings, income, Monopoly rent
    │   ├── FarmManager.server.lua    Legacy farm action handlers
    │   ├── DataManager.server.lua    DataStore persistence
    │   ├── ShopManager.server.lua    Seed/item shop
    │   └── GameManager.server.lua    Misc game events
    └── StarterPlayer/
        └── StarterPlayerScripts/
            ├── ClientController.client.lua  Input handling
            ├── FarmUI.client.lua            Farm HUD, shop, toolbar
            └── CityUI.client.lua            City dashboard, build menu, toasts
```

---

## Development Notes

- **CharacterAutoLoads is disabled** in `default.project.json` so the server can build terrain before anyone spawns. It is re-enabled by `Main.server.lua` after `buildWorld()` completes.
- **`_CoinAPI`** — a `BindableFunction` in `ReplicatedStorage` created by `Main.server.lua`. All scripts (AnimalManager, CityManager) use it to add or deduct coins from the in-memory player data, ensuring DataStore consistency.
- **`CityRemotes`** — CityManager creates its own `Folder` in `ReplicatedStorage` (separate from the farm's `Remotes` folder) to avoid naming conflicts.
- **`_CityTreasuryAPI`** — a `BindableEvent` in `Workspace` created by `CityManager`. NPC farms fire it on each harvest to deposit revenue.

---

## Rebuilding After Code Changes

```bash
rojo build default.project.json --output AdamAndEshaalsFarm.rbxlx
```

Re-open the `.rbxlx` in Studio (or use `rojo serve` + the Studio plugin for live sync).

---

Made with love for Adam and Eshaal 🌻
