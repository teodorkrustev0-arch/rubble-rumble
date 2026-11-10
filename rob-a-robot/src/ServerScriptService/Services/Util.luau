--[[
	Util  (ModuleScript)
	Location: ServerScriptService > Services > Util

	Small helpers shared by the server services.
]]

local CollectionService = game:GetService("CollectionService")

local Util = {}

-- Returns the player's HumanoidRootPart and Humanoid, but only if they are
-- alive. Returns nil otherwise.
function Util.GetRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil
end

-- Server-side distance check. Never assume a player is close just because
-- their client says they pressed a button.
function Util.IsNear(player, position, maxDistance)
	local root = Util.GetRoot(player)
	return root ~= nil and (root.Position - position).Magnitude <= maxDistance
end

-- Creates a ProximityPrompt.
-- props.Tag + props.OwnerUserId let the client hide prompts that are not
-- meant for it ("OwnerOnlyPrompt" / "NotOwnerPrompt"). That is only cosmetic:
-- the server still checks who triggered the prompt.
function Util.MakePrompt(parent, props)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = props.ActionText or "Use"
	prompt.ObjectText = props.ObjectText or ""
	prompt.HoldDuration = props.HoldDuration or 0
	prompt.KeyboardKeyCode = props.Key or Enum.KeyCode.E
	prompt.GamepadKeyCode = props.GamepadKey or Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = props.MaxDistance or 9
	prompt.RequiresLineOfSight = false
	if props.OwnerUserId ~= nil then
		prompt:SetAttribute("OwnerUserId", props.OwnerUserId)
	end
	if props.Tag then
		CollectionService:AddTag(prompt, props.Tag)
	end
	prompt.Parent = parent
	return prompt
end

-- Connects a hold-to-use prompt and ENFORCES the hold time on the server.
-- An exploiter can make their client claim the prompt finished instantly, so
-- we remember when the hold began and ignore triggers that come too early.
function Util.ConnectHold(prompt, onTriggered, onHoldBegan)
	local beganAt = {}
	prompt.PromptButtonHoldBegan:Connect(function(player)
		beganAt[player] = os.clock()
		if onHoldBegan then
			onHoldBegan(player)
		end
	end)
	prompt.Triggered:Connect(function(player)
		local started = beganAt[player]
		beganAt[player] = nil
		if not started or os.clock() - started < prompt.HoldDuration - 0.3 then
			return
		end
		onTriggered(player)
	end)
end

-- Returns a function that answers "is this player allowed to send another
-- request yet?". Used to stop clients from spamming RemoteEvents.
function Util.RateLimiter(seconds)
	local last = {} -- [UserId] = time of the last accepted request
	return function(player)
		local now = os.clock()
		local previous = last[player.UserId]
		if previous and now - previous < seconds then
			return false
		end
		last[player.UserId] = now
		return true
	end
end

return Util
