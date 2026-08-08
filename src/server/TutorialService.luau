local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Tutorial.Config)

-- Create TutorialRemotes folder and RemoteEvents
local remotesFolder = ReplicatedStorage:FindFirstChild("TutorialRemotes")
if not remotesFolder then
	remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "TutorialRemotes"
	remotesFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = remotesFolder:FindFirstChild(name)
	if existing then
		return existing :: RemoteEvent
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	return remote
end

local stepChangedRemote: RemoteEvent = getOrCreateRemote("TutorialStepChanged")
local finishedRemote: RemoteEvent = getOrCreateRemote("TutorialFinished")
local stepCompletedRemote: RemoteEvent = getOrCreateRemote("TutorialStepCompleted")

local dataStore = DataStoreService:GetDataStore(Config.DataStoreName)

type PlayerState = {
	stepIndex: number,
	statWatcher: RBXScriptConnection?,
}

local playerState: { [Player]: PlayerState } = {}

local TutorialService = {}

local function applyStep(player: Player, stepIndex: number)
	local state = playerState[player]
	if not state then
		return
	end

	-- Disconnect any existing stat watcher before setting up the new step
	if state.statWatcher then
		state.statWatcher:Disconnect()
		state.statWatcher = nil
	end

	local step = Config.Steps[stepIndex]
	if not step then
		return
	end

	stepChangedRemote:FireClient(player, step, stepIndex, #Config.Steps)

	if step.stepType == "Leaderstats" then
		local leaderstatStep = step :: any

		local statFolder = player:WaitForChild("leaderstats", 10)
		if not statFolder then
			warn("[TutorialService] leaderstats not found for player:", player.Name)
			return
		end

		local statValue = statFolder:WaitForChild(leaderstatStep.statName, 10)
		if not statValue then
			warn("[TutorialService] leaderstats value not found:", leaderstatStep.statName)
			return
		end

		-- Auto-complete immediately if already at target
		if statValue.Value >= leaderstatStep.targetValue then
			TutorialService.CompleteStep(player)
			return
		end

		-- Watch for the stat reaching target
		state.statWatcher = statValue.Changed:Connect(function(newVal: number)
			if newVal >= leaderstatStep.targetValue then
				TutorialService.CompleteStep(player)
			end
		end)
	end
end

local function onPlayerAdded(player: Player)
	-- Wait for leaderstats before proceeding (gives game setup scripts time to create it)
	player:WaitForChild("leaderstats", 10)

	local key = Config.DataStoreKeyPrefix .. player.UserId
	local savedIndex = 1

	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)
	if success and type(result) == "number" then
		savedIndex = result
	end

	-- Player already completed all steps
	if savedIndex > #Config.Steps then
		finishedRemote:FireClient(player)
		return
	end

	playerState[player] = {
		stepIndex = 1,
		statWatcher = nil,
	}

	-- Reset leaderstats value to 0
	local statFolder = player:FindFirstChild("leaderstats")
	if statFolder then
		local goldValue = statFolder:FindFirstChild("Gold")
		if goldValue then
			(goldValue :: IntValue).Value = 0
		end
	end

	applyStep(player, 1)
end

local function onPlayerRemoving(player: Player)
	local state = playerState[player]
	if state then
		if state.statWatcher then
			state.statWatcher:Disconnect()
			state.statWatcher = nil
		end
		playerState[player] = nil
	end
end

-- Public API: call this from any server script to advance a Basic step
function TutorialService.CompleteStep(player: Player)
	local state = playerState[player]
	if not state then
		return
	end

	if state.statWatcher then
		state.statWatcher:Disconnect()
		state.statWatcher = nil
	end

	local newIndex = state.stepIndex + 1
	local key = Config.DataStoreKeyPrefix .. player.UserId

	pcall(function()
		dataStore:SetAsync(key, newIndex)
	end)

	if newIndex > #Config.Steps then
		finishedRemote:FireClient(player)
		playerState[player] = nil
		return
	end

	state.stepIndex = newIndex
	applyStep(player, newIndex)
end

-- Public API: resets the player back to step 1 and clears their saved progress
function TutorialService.ResetTutorial(player: Player)
	local state = playerState[player]
	if state and state.statWatcher then
		state.statWatcher:Disconnect()
		state.statWatcher = nil
	end

	local key = Config.DataStoreKeyPrefix .. player.UserId
	pcall(function()
		dataStore:SetAsync(key, 1)
	end)

	playerState[player] = {
		stepIndex = 1,
		statWatcher = nil,
	}

	-- Reset leaderstats value to 0
	local statFolder = player:FindFirstChild("leaderstats")
	if statFolder then
		local goldValue = statFolder:FindFirstChild("Gold")
		if goldValue then
			(goldValue :: IntValue).Value = 0
		end
	end

	applyStep(player, 1)
end

function TutorialService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Handle players who joined before Start() was called
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Handle GuiElement step completion (client fires when the target button is clicked)
	stepCompletedRemote.OnServerEvent:Connect(function(player)
		local state = playerState[player]
		if not state then
			return
		end

		local step = Config.Steps[state.stepIndex]
		if step and step.stepType == "GuiElement" then
			TutorialService.CompleteStep(player)
		end
	end)
end

return TutorialService
