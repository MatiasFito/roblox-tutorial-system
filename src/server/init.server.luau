local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TutorialService = require(ServerScriptService.Server.TutorialService)
TutorialService.Start()

-- ── Leaderstats setup ────────────────────────────────────────────────────────
-- Creates a "Gold" leaderstat for every player.
Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = 0
	gold.Parent = leaderstats
end)

-- ── Gold orb (ProximityPrompt) ────────────────────────────────────────────────
-- A glowing part in the world. Interacting with it awards 500 Gold.
local goldPart = Instance.new("Part")
goldPart.Name = "GoldOrb"
goldPart.Shape = Enum.PartType.Ball
goldPart.Size = Vector3.new(3, 3, 3)
goldPart.CFrame = CFrame.new(10, 1.5, 10) -- matches the Leaderstats step objective in Config
goldPart.Anchored = true
goldPart.CanCollide = false
goldPart.BrickColor = BrickColor.new("Bright yellow")
goldPart.Material = Enum.Material.Neon
goldPart.Parent = workspace

local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Collect"
prompt.ObjectText = "Gold Orb (+500)"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 10
prompt.Parent = goldPart

prompt.Triggered:Connect(function(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end
	local gold = leaderstats:FindFirstChild("Gold")
	if not gold then
		return
	end
	gold.Value += 500
end)

-- ── Reset orb (ProximityPrompt) ─────────────────────────────────────────────
-- A pink orb that resets the tutorial back to step 1 for the triggering player.
local resetPart = Instance.new("Part")
resetPart.Name = "ResetOrb"
resetPart.Shape = Enum.PartType.Ball
resetPart.Size = Vector3.new(3, 3, 3)
resetPart.CFrame = CFrame.new(-10, 1.5, 0)
resetPart.Anchored = true
resetPart.CanCollide = false
resetPart.BrickColor = BrickColor.new("Hot pink")
resetPart.Material = Enum.Material.Neon
resetPart.Parent = workspace

local resetPrompt = Instance.new("ProximityPrompt")
resetPrompt.ActionText = "Reset"
resetPrompt.ObjectText = "Tutorial Reset"
resetPrompt.HoldDuration = 1 -- hold to avoid accidental resets
resetPrompt.MaxActivationDistance = 10
resetPrompt.Parent = resetPart

resetPrompt.Triggered:Connect(function(player)
	TutorialService.ResetTutorial(player)
end)

-- ── Plot touch → complete Basic step ─────────────────────────────────────────
-- Example: complete the current tutorial step when a player steps on "plotPart"
-- Touched fires on the server, so TutorialService.CompleteStep can be called directly.
-- Replace workspace.Plot with however you reference the part in your game.
local plotPart = workspace.Plot
local debounce: { [Player]: boolean } = {} -- prevents the same player firing twice

plotPart.Touched:Connect(function(hit)
	-- Walk up the ancestry to handle accessories/wings whose parts are not
	-- direct children of the character model (hit.Parent may be an Accessory, etc.)
	local player: Player? = nil
	local ancestor = hit.Parent
	while ancestor and ancestor ~= workspace do
		player = Players:GetPlayerFromCharacter(ancestor)
		if player then
			break
		end
		ancestor = ancestor.Parent
	end
	if not player then
		return
	end
	if debounce[player] then
		return
	end

	debounce[player] = true
	TutorialService.CompleteStep(player)
	-- Clear debounce after a short delay so it can fire again if needed
	task.delay(2, function()
		debounce[player] = nil
	end)
end)
