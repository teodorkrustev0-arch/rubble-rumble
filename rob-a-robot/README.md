# Rob-a-Robot — Roblox Studio build guide

Build robots from conveyor parts, earn coins, and steal from other players' bases.

Everything is Luau. You do **not** need to model anything to get started: the scripts build a
map and the whole UI for you. Later you can edit the map or replace it with your own (see
[Building your own map](#building-your-own-map)).

> **Status:** every script passes a Luau syntax check, but it has **not been run inside Roblox
> Studio** (it was written outside Studio). Expect to fix a small thing or two on first Play —
> the Output window (View > Output) will show the script name and line number.

## Contents

1. [Where every script goes](#1-where-every-script-goes)
2. [Step 1 — the core game](#2-step-1--the-core-game-conveyor-buying-building-earning-stealing)
3. [Step 2 — guard bots](#3-step-2--guard-bots)
4. [Step 3 — server events](#4-step-3--server-events)
5. [Step 4 — saving](#5-step-4--saving)
6. [How to play](#how-to-play)
7. [Building your own map](#building-your-own-map)
8. [How cheating is prevented](#how-cheating-is-prevented)
9. [Tuning the game](#tuning-the-game)
10. [Known limits and ideas](#known-limits-and-ideas)

---

## 1. Where every script goes

The script type matters. In the Explorer, hover the parent, click **+** and pick the type shown.

```
ReplicatedStorage
└── Shared                (Folder)
    ├── Config            (ModuleScript)   src/ReplicatedStorage/Shared/Config.luau
    └── PartCatalog       (ModuleScript)   src/ReplicatedStorage/Shared/PartCatalog.luau

ServerScriptService
├── Main                  (Script)         src/ServerScriptService/Main.server.luau
└── Services              (Folder)
    ├── Net               (ModuleScript)   ┐
    ├── Util              (ModuleScript)   │
    ├── ItemVisuals       (ModuleScript)   │
    ├── PlayerData        (ModuleScript)   │
    ├── MapBuilder        (ModuleScript)   │  STEP 1
    ├── BaseService       (ModuleScript)   │  src/ServerScriptService/Services/<Name>.luau
    ├── RobotService      (ModuleScript)   │
    ├── ConveyorService   (ModuleScript)   │
    ├── StealService      (ModuleScript)   │
    ├── ShopService       (ModuleScript)   ┘
    ├── GuardService      (ModuleScript)   STEP 2
    ├── EventService      (ModuleScript)   STEP 3
    └── DataService       (ModuleScript)   STEP 4

StarterPlayer
└── StarterPlayerScripts
    └── ClientMain        (LocalScript)    src/StarterPlayerScripts/ClientMain.client.luau
```

Names must match **exactly** (capital letters included) — the scripts find each other by name.
`ReplicatedStorage > Remotes` is created automatically when the game runs; do not make it.

| Script | What it does |
| --- | --- |
| `Config` | Every number you can tune: prices, timers, speeds, shop items. |
| `PartCatalog` | The 5 slots, the rarities (colour, chance, price, income) and the sets. |
| `Main` | Starts everything; handles players joining and leaving. |
| `Net` | Creates the RemoteEvents; sends pop-up messages. |
| `Util` | Helpers: distance checks, prompts, rate limiting. |
| `ItemVisuals` | Turns a part into a coloured block with a name label. |
| `PlayerData` | Each player's coins, inventory, robots and upgrades (server memory). |
| `MapBuilder` | Builds the map (factory, conveyor, 8 bases, scenery) if `Workspace.Map` does not exist. |
| `BaseService` | Assigns bases, runs the lock button, knows who is inside a base. |
| `RobotService` | Placing/removing parts, drawing robots, paying coins every second. |
| `ConveyorService` | Spawns parts on the belt and sells them. |
| `StealService` | Stealing, carrying, getting caught, delivering. |
| `ShopService` | Sells guards and upgrades. |
| `GuardService` | Guard bots that patrol and throw intruders out. |
| `EventService` | Power Surge and Junk Storm every 10 minutes. |
| `DataService` | Saves and loads with DataStoreService. |
| `ClientMain` | The whole UI. Only displays things and sends requests. |

### Three ways to get the scripts into Studio

**A. By hand (works always).** Create each object from the tree above, open the matching file
from `src/`, copy everything, and paste it over the script's default contents.

**B. Installer (fastest, if your Studio accepts the paste).** Open `Installer.lua`, copy all of
it, paste it into the Command Bar (View > Command Bar) and press Enter. It creates all 17 scripts
in the right places. It installs all four steps at once — if you want to go step by step, delete
`GuardService`, `EventService` and `DataService` afterwards and add them back later. If the
Command Bar will not take such a long paste, use method A.

**C. Rojo (if you already use it).** `rojo serve` in this folder; `default.project.json` is set up.

---

## 2. Step 1 — the core game (conveyor, buying, building, earning, stealing)

1. **New place.** Roblox Studio > New > **Baseplate**.
2. **Max players.** Home > Game Settings > Places > (your place) > Configure Place > set
   **Maximum Visitors** to **8**. (Game Settings needs the place to be published first — you can
   do this later; a 9th player is simply kicked with a "server full" message.)
3. **Add the scripts** for Step 1: `Config`, `PartCatalog`, `Main`, the ten Step 1 modules in
   `Services`, and `ClientMain`.
4. **Press Play.** You should see:
   - a factory plaza with parts sliding along the conveyor, and 8 walled bases around it;
   - yourself spawning in a base with your name on the sign;
   - a coin counter on the left that goes up by 1 every second.
5. **Test with this checklist:**

   | Try this | Expected |
   | --- | --- |
   | Walk to the belt, press **E** on a part (or click it) | Coins go down, "Bought ..." message |
   | Press E on something you cannot afford | "Not enough coins" and nothing happens |
   | Open **Robots**, stand next to the blue pad in your base, press **Place** | The part appears on the pad |
   | Press Place while far from your pads | "Stand next to one of your build pads first" |
   | Place all 5 slots (Head, Body, Arms, Legs, Core) | "Robot online!", label shows `+N coins/s` |
   | Build with 5 parts of the same set | Label shows `FULL SET BONUS x2!` |

6. **Test stealing — you need 2 players.** Test tab > **Clients and Servers** > choose **2 Players**
   > **Start**. Two game windows open.
   - Player 1: build a robot (give yourself coins for testing by setting
     `Config.StartingCoins = 5000`).
   - Player 2: walk into Player 1's base. **Hold E** on a part for 3 seconds (one part) or
     **hold F** for 3 seconds (whole robot, only when it is complete).
   - Player 1 gets a red **ALERT** as soon as Player 2 starts holding, the robot shows `OFFLINE`.
   - Player 2 gets a glowing crate overhead and walks slowly. Reach your own base = the parts
     land in your inventory. If Player 1 touches Player 2 first, the parts snap back.
   - Player 1: press E on the **red button** (on the pedestal just inside your door) to lock the base. Player 2 is
     thrown out and cannot enter for 30 seconds. The lock then recharges for 60 seconds.
   - Open **Shop** and buy Turbo Boots / Extra Build Pad / Stronger Lock. (Guard Bot says it is
     not installed yet — that is Step 2.)

If something does not work, check View > **Output** for red text first.

---

## 3. Step 2 — guard bots

1. Add **`GuardService`** (ModuleScript) to `ServerScriptService > Services`.
2. Press Play. The Output should say `[Main] GuardService is installed.`
3. Buy **Guard Bot** in the shop (500 coins; up to 3). A robot guard appears in your base and
   wanders around.
4. With 2 players: walk into the guarded base. When you come within 14 studs the guard walks at
   you; within 6 studs it throws you out of the door, then needs 5 seconds to recharge.

Nothing else changes — `Main` detects the module and switches the feature on. Tune guards in
`Config.Guard`.

---

## 4. Step 3 — server events

1. Add **`EventService`** (ModuleScript) to `ServerScriptService > Services`.
2. **For testing**, set `Config.Events.Interval = 30` so you do not wait 10 minutes. Set it back
   to `600` when you are done.
3. Press Play and wait. One of these happens at random:
   - **Power Surge** — all robots earn x2 for 2 minutes. Your `+N / sec` doubles.
   - **Junk Storm** — 12 parts (Rare or better) fall from the sky. Press E on one to grab it for
     free. Uncollected junk disappears after 90 seconds.
   A purple banner at the bottom of the screen shows the event and a countdown.

---

## 5. Step 4 — saving

1. **Publish** the game: File > Publish to Roblox.
2. Home > Game Settings > **Security** > turn on **Enable Studio Access to API Services**
   (needed to test saving inside Studio).
3. Add **`DataService`** (ModuleScript) to `ServerScriptService > Services`.
4. Press Play, earn coins and build something, press Stop, press Play again. Your coins,
   inventory, robots (still on their pads), guards and upgrades are back.

What is saved: coins, inventory parts, robots on pads, shop upgrades (which includes guards).
Saves happen when you leave, every 2 minutes, and when the server shuts down.

If the Output says `Saving is OFF for this session`, step 1 or 2 above is missing. The game still
runs; it just starts fresh each time.

To wipe all test data, change `Config.Saving.StoreName` (for example to `"RobARobot_v2"`).

---

## How to play

| Action | How |
| --- | --- |
| Buy a part | Press **E** on it (or click it) at the conveyor |
| Build | **Robots** button > stand next to a pad in your base > **Place** |
| Take a part off | **Robots** button > **Remove** (you must be in your base) |
| Steal one part | In someone's base, **hold E** on the part for 3 seconds |
| Steal a whole robot | **Hold F** near a complete robot for 3 seconds |
| Deliver loot | Walk back into your own base |
| Catch a thief | Touch them (get within 6 studs) while they carry your parts |
| Lock your base | Press **E** on the red button by your door |
| Shop | **Shop** button |

Whole-robot stealing uses **F** instead of E on purpose: a robot already has five "hold E"
prompts (one per part), and Roblox only shows one prompt per key at a time.

Rarities (edit them in `PartCatalog`):

| Rarity | Colour | Spawn chance | Price | Coins/sec |
| --- | --- | --- | --- | --- |
| Common | grey | 60% | 25 | 1 |
| Rare | blue | 25% | 100 | 4 |
| Epic | purple | 10% | 400 | 12 |
| Legendary | gold | 4% | 1,500 | 40 |
| Mythic | red | 1% | 6,000 | 150 |

A robot earns the sum of its five parts, doubled if all five are from one set
(Pizza Bot, Ninja Bot, Space Bot, Pirate Bot). A robot with a missing part earns nothing.

---

## Building your own map

`MapBuilder` builds the full map for you: a factory plaza with the conveyor, a part dispenser
and a recycler, light arches, a title sign, 8 colour-coded bases, paths, trees and an outer wall.

By default it builds the map each time the game starts (only when `Workspace` has no model called
**`Map`**). To get the map as a **permanent model you can edit**:

1. Make sure the `MapBuilder` ModuleScript is in `ServerScriptService > Services`.
2. Do **not** press Play. Open View > **Command Bar** and run this one line:

   ```lua
   require(game.ServerScriptService.Services.MapBuilder).Build()
   ```

3. `Workspace > Map` appears. Save the place. From now on the game uses this map and you can
   move, recolour and decorate it by hand.

Everything inside a folder named **`Decor`** is decoration only — change or delete it freely.
Leave the other parts' names alone. You can keep or delete the default `Baseplate`; the map's
grass sits just above it. The builder also sets an early-evening look in `Lighting`.

To throw the map away and build a fresh one (hand edits are lost), run the same line ending in
`.Rebuild()`.

If you build from scratch, the scripts need exactly these names:

```
Workspace
└── Map                         (Model)
    ├── Factory                 (Model)
    │   └── Conveyor            (Model)
    │       ├── Belt            (Part)  the belt itself (looks only)
    │       ├── SpawnPoint      (Part)  parts appear here
    │       └── EndPoint        (Part)  parts disappear here
    └── Bases                   (Folder)
        ├── Base1               (Model)
        │   ├── Zone            (Part)
        │   ├── Door            (Part)
        │   ├── Entrance        (Part)
        │   ├── Spawn           (SpawnLocation)
        │   ├── LockButton      (Part)
        │   ├── Sign            (Part)  optional
        │   └── Pads            (Folder)
        │       ├── Pad1        (Part)
        │       ├── Pad2        (Part)
        │       └── Pad3        (Part)
        ├── Base2 ... Base8     (same children as Base1)
```

| Part | Rules |
| --- | --- |
| `SpawnPoint`, `EndPoint` | Anchored, invisible (Transparency 1), CanCollide off. Put them about 1.5 studs above the belt surface. Parts slide in a straight line from one to the other. |
| `Zone` | Anchored, invisible, CanCollide off. A box that fills the inside of the base; this is what "inside the base" means. Its **bottom must be at floor level** (guards use it). |
| `Door` | Anchored, **CanCollide off**. Shown as a red force field while locked. It is only a visual — the server throws intruders out. |
| `Entrance` | Anchored, invisible, CanCollide off. Place it **outside** the door, a few studs above the ground. Ejected intruders land here. Keep it outside the `Zone`. |
| `Spawn` | Must be a **SpawnLocation** with **Neutral** ticked. |
| `LockButton` | Any anchored part inside the base. The script adds the prompt. |
| `Sign` | Optional. Any TextLabel inside it (for example in a SurfaceGui) shows the owner's name. |
| `Pad1`–`Pad3` | Anchored, about 6 x 1 x 6. Robots stand on top, facing the pad's front (-Z). Keep them 10+ studs apart. All three must exist; pads 2 and 3 are unlocked in the shop. |

You can have fewer or more than 8 bases — one player per `Base` model. Do not put prompts,
ClickDetectors or scripts in the map yourself.

For real robot meshes instead of blocks, edit `ItemVisuals.CreatePiece` to clone your own model.

---

## How cheating is prevented

The rule: **the client asks, the server decides.**

- Coins, inventory and robots live only in `PlayerData` on the server. The client receives copies
  to display.
- The client can send exactly three requests, and each sends the minimum:
  `PlacePart(itemId)`, `RemovePart(padIndex, slot)`, `ShopBuy(key)`. It never sends a price, a
  coin amount or an item's rarity. Prices come from `Config`/`PartCatalog` on the server.
- Every request is type-checked, rate-limited, and checked against the player's real position.
- Buying and stealing use ProximityPrompts, which fire on the server. The server still re-checks
  the distance, and **times the 3-second hold itself** so a cheater cannot "finish" instantly.
- Buying a conveyor part has no waiting between "check coins" and "remove part", so two players
  cannot buy the same part.
- Locks and guards move players from the server, so walking through the door client-side does
  not help.
- While carrying loot, the server measures the thief's real speed. Moving far too fast several
  checks in a row returns the loot.
- Loaded save data is cleaned (`PlayerData` rebuilds it field by field), so a corrupt save
  cannot inject fake parts.

---

## Tuning the game

- **Numbers:** `Config` — starting coins, belt speed, steal time, lock time, guard strength,
  event timing, shop prices.
- **New set:** add a line to `Catalog.Sets` in `PartCatalog`, e.g.
  `{ Key = "Dino", Name = "Dino Bot" }`. Never rename a `Key` after players have saved data.
- **Rarities:** edit `Catalog.Rarities`. Keep the order cheapest to best.
- **New shop upgrade:** add an entry to `Config.Shop`, then read `profile.Upgrades.YourKey`
  wherever it should take effect. The shop UI and saving pick it up automatically.

---

## Known limits and ideas

- **No session locking in saves.** If a player joins a second server before the first finished
  saving, they can load slightly old data. For a big public game, switch `DataService` to a
  library such as ProfileStore.
- **Inventory is safe storage.** Only parts on pads can be stolen (and only parts on pads earn).
- **You cannot sell parts** yet — a "Sell for half price" button is a good first feature to add.
- **Guards float through obstacles**: they are simple server-moved models, not pathfinding NPCs.
- **Movement is only speed-checked while carrying.** General anti-teleport checks are not included.
- **No sounds or animations** — add them in `ClientMain` (for example an alarm sound when a
  notification of kind `"alarm"` arrives).
