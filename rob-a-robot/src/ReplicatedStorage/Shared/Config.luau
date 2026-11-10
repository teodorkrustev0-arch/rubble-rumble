--[[
	Config  (ModuleScript)
	Location: ReplicatedStorage > Shared > Config

	Every number you might want to tweak lives here, so you can balance the
	game without touching the logic. Both the server and the client read it.
	(The client only uses it to DISPLAY things. The server never asks the
	client what anything costs.)
]]

local Config = {}

-- Economy -------------------------------------------------------------------
Config.StartingCoins = 200 -- coins a brand new player starts with
Config.PassiveIncome = 1 -- coins per second everyone earns (stops soft-locks at 0 coins)
Config.SetBonus = 2 -- earnings multiplier when all 5 parts share one set

-- Players and bases ---------------------------------------------------------
Config.DefaultWalkSpeed = 16
Config.MaxPads = 3 -- build pads that physically exist in every base

-- Conveyor ------------------------------------------------------------------
Config.Conveyor = {
	SpawnInterval = 2, -- seconds between new parts
	Speed = 6, -- studs per second along the belt
	MaxItems = 40, -- safety cap on parts on the belt at once
	BuyDistance = 18, -- how close (studs) you must be to buy
}

-- Building ------------------------------------------------------------------
Config.Build = {
	PlaceDistance = 14, -- how close you must stand to a pad to place a part
}

-- Stealing ------------------------------------------------------------------
Config.Steal = {
	HoldTime = 3, -- seconds to hold the steal prompt
	MaxReach = 16, -- server-side distance check when a steal completes
	CarryWalkSpeed = 9, -- walk speed while carrying loot
	CarrySpeedPerUpgrade = 1.5, -- extra carry speed per "Turbo Boots" level
	TagDistance = 6, -- owner this close to the thief = caught
}

-- Base lock -----------------------------------------------------------------
Config.Lock = {
	Duration = 30, -- seconds the base stays locked
	DurationPerUpgrade = 10, -- extra seconds per "Stronger Lock" level
	Cooldown = 60, -- seconds after the lock ENDS before it can be used again
}

-- Guard bots (step 2) -------------------------------------------------------
Config.Guard = {
	Speed = 7, -- studs per second
	SightRadius = 14, -- guards walk toward intruders closer than this
	PushRadius = 6, -- intruders closer than this get thrown out
	PushCooldown = 5, -- seconds a guard needs to recharge after a push
}

-- Server events (step 3) ----------------------------------------------------
Config.Events = {
	Interval = 600, -- seconds between events (set to 30 while testing!)
	PowerSurge = { Duration = 120, Multiplier = 2 },
	JunkStorm = {
		Count = 12, -- parts that fall from the sky
		Area = 110, -- half-size of the square they land in (studs)
		Lifetime = 90, -- seconds before uncollected junk disappears
		MinRarity = 2, -- 2 = Rare or better (index into PartCatalog.Rarities)
	},
}

-- Saving (step 4) -----------------------------------------------------------
Config.Saving = {
	StoreName = "RobARobot_v1", -- change the name to wipe everyone's data
	AutosaveInterval = 120,
}

-- Shop ----------------------------------------------------------------------
-- Every shop item is an "upgrade level" stored in profile.Upgrades[Key].
-- Prices[1] is the price of level 1, Prices[2] of level 2, and so on.
-- The number of prices is the maximum level.
Config.Shop = {
	{
		Key = "Guards",
		Name = "Guard Bot",
		Desc = "Patrols your base and throws intruders out.",
		Prices = { 500, 2000, 6000 },
	},
	{
		Key = "Pads",
		Name = "Extra Build Pad",
		Desc = "Unlocks another build pad for one more robot.",
		Prices = { 1500, 8000 },
	},
	{
		Key = "CarrySpeed",
		Name = "Turbo Boots",
		Desc = "Walk faster while carrying stolen loot.",
		Prices = { 400, 1200, 3600 },
	},
	{
		Key = "LockTime",
		Name = "Stronger Lock",
		Desc = "Your base lock lasts 10 seconds longer.",
		Prices = { 600, 1800, 5000 },
	},
}

return Config
