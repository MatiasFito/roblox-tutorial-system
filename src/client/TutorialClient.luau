local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("Shared").Tutorial.Config)

-- Tween constants
local HIDDEN_POS = UDim2.new(0.5, 0, 0, -200)
local RESTING_POS = UDim2.new(0.5, 0, 0, 20)
local TWEEN_IN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TWEEN_OUT_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-- Module-level state
local isPanelVisible = false
local currentSeq = 0 -- Incremented on each showStep; stale coroutines bail out if their seq doesn't match
local statWatcher: RBXScriptConnection? = nil
local objectivePart: Part? = nil
local beamAttachment0: Attachment? = nil
local beam: Beam? = nil
local completionSoundRef: Sound? = nil

-- ──────────────────────────────────────────────────────────────────────────────
-- GUI
-- ──────────────────────────────────────────────────────────────────────────────

local function buildGui()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = LocalPlayer.PlayerGui

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(420, 120)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = HIDDEN_POS
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = panel

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 30)
	titleLabel.Position = UDim2.new(0, 0, 0, 0)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Top
	titleLabel.Text = ""
	titleLabel.Parent = panel

	-- Description
	local descLabel = Instance.new("TextLabel")
	descLabel.Name = "DescLabel"
	descLabel.Size = UDim2.new(1, 0, 0, 44)
	descLabel.Position = UDim2.fromOffset(0, 32)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 15
	descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	descLabel.BackgroundTransparency = 1
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextWrapped = true
	descLabel.Text = ""
	descLabel.Parent = panel

	-- Progress bar (Leaderstats steps only)
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Visible = false
	progressBar.Size = UDim2.new(1, 0, 0, 18)
	progressBar.Position = UDim2.fromOffset(0, 80)
	progressBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = panel

	local progressBarCorner = Instance.new("UICorner")
	progressBarCorner.CornerRadius = UDim.new(0, 6)
	progressBarCorner.Parent = progressBar

	local fillFrame = Instance.new("Frame")
	fillFrame.Name = "Fill"
	fillFrame.Size = UDim2.fromScale(0, 1)
	fillFrame.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
	fillFrame.BorderSizePixel = 0
	fillFrame.Parent = progressBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fillFrame

	local progressText = Instance.new("TextLabel")
	progressText.Name = "ProgressText"
	progressText.Size = UDim2.fromScale(1, 1)
	progressText.BackgroundTransparency = 1
	progressText.Font = Enum.Font.GothamBold
	progressText.TextSize = 12
	progressText.TextColor3 = Color3.new(1, 1, 1)
	progressText.ZIndex = 3
	progressText.Text = ""
	progressText.Parent = progressBar

	-- Optional completion sound
	local completionSound: Sound? = nil
	if Config.CompletionSoundId ~= nil then
		local sound = Instance.new("Sound")
		sound.Name = "CompletionSound"
		sound.SoundId = Config.CompletionSoundId
		sound.Volume = 1
		sound.Parent = panel
		completionSound = sound
	end

	return panel, titleLabel, descLabel, progressBar, fillFrame, progressText, completionSound
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Beam
-- ──────────────────────────────────────────────────────────────────────────────

local function setupBeam(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return
	end

	if beamAttachment0 then
		beamAttachment0:Destroy()
		beamAttachment0 = nil
	end
	if beam then
		beam:Destroy()
		beam = nil
	end

	local att0 = Instance.new("Attachment")
	att0.Name = "TutorialBeamAtt0"
	att0.Parent = hrp
	beamAttachment0 = att0

	if objectivePart then
		local att1 = objectivePart:FindFirstChild("Attachment0") :: Attachment?
		if att1 then
			local newBeam = Instance.new("Beam")
			newBeam.Attachment0 = att0
			newBeam.Attachment1 = att1
			newBeam.Color = ColorSequence.new(Color3.fromRGB(0, 180, 0))
			newBeam.Brightness = 3
			newBeam.Texture = "rbxassetid://16848361091"
			newBeam.TextureSpeed = 6
			newBeam.Transparency = NumberSequence.new(0.5)
			newBeam.TextureLength = 1.5
			newBeam.TextureMode = Enum.TextureMode.Static
			newBeam.Width0 = 3
			newBeam.Width1 = 2
			newBeam.FaceCamera = true
			newBeam.Parent = workspace
			beam = newBeam
		end
	end
end

local function clearObjective()
	if objectivePart then
		objectivePart:Destroy()
		objectivePart = nil
	end
	if beam then
		beam:Destroy()
		beam = nil
	end
end

local function setObjective(cframe: CFrame?)
	clearObjective()
	if cframe == nil then
		return
	end

	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = cframe
	part.Name = "TutorialObjective"
	part.Parent = workspace

	local att1 = Instance.new("Attachment")
	att1.Name = "Attachment0"
	att1.Parent = part

	objectivePart = part

	-- Reconnect beam if character is already loaded
	if beamAttachment0 ~= nil then
		local char = LocalPlayer.Character
		if char then
			setupBeam(char)
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Tween helpers
-- ──────────────────────────────────────────────────────────────────────────────

local function tweenIn(panel: Frame)
	panel.Position = HIDDEN_POS
	TweenService:Create(panel, TWEEN_IN_INFO, { Position = RESTING_POS }):Play()
end

local function tweenOut(panel: Frame): Tween
	local t = TweenService:Create(panel, TWEEN_OUT_INFO, { Position = HIDDEN_POS })
	t:Play()
	return t
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Progress bar
-- ──────────────────────────────────────────────────────────────────────────────

local function updateProgress(fillFrame: Frame, progressText: TextLabel, current: number, target: number)
	local ratio = math.clamp(current / target, 0, 1)
	fillFrame.Size = UDim2.fromScale(ratio, 1)
	progressText.Text = current .. " / " .. target
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Step display logic
-- ──────────────────────────────────────────────────────────────────────────────

local function showStep(
	step: any,
	_stepIndex: number,
	_totalSteps: number,
	panel: Frame,
	titleLabel: TextLabel,
	descLabel: TextLabel,
	progressBar: Frame,
	fillFrame: Frame,
	progressText: TextLabel
)
	-- Disconnect any live stat watcher from the previous step
	if statWatcher then
		statWatcher:Disconnect()
		statWatcher = nil
	end

	-- Bump the sequence counter so any previous coroutine waiting on tween-out
	-- will detect it is stale and exit
	currentSeq += 1
	local seq = currentSeq

	task.spawn(function()
		-- If the panel is currently visible, slide it out first
		if isPanelVisible then
			if completionSoundRef then
				completionSoundRef:Play()
			end
			local t = tweenOut(panel)
			t.Completed:Wait()
			-- Bail if a newer step already took over while we were tweening
			if seq ~= currentSeq then
				return
			end
		end

		-- Update content
		titleLabel.Text = step.title
		descLabel.Text = step.description

		if step.stepType == "Leaderstats" then
			progressBar.Visible = true
			local statFolder = LocalPlayer:WaitForChild("leaderstats", 10)
			if statFolder then
				local statValue = statFolder:WaitForChild(step.statName, 10)
				if statValue then
					updateProgress(fillFrame, progressText, statValue.Value, step.targetValue)
					statWatcher = statValue.Changed:Connect(function(newVal: number)
						updateProgress(fillFrame, progressText, newVal, step.targetValue)
					end)
				end
			end
		else
			progressBar.Visible = false
		end

		setObjective(step.objective :: CFrame?)
		tweenIn(panel)
		isPanelVisible = true
	end)
end

local function onTutorialFinished(panel: Frame, completionSound: Sound?)
	if statWatcher then
		statWatcher:Disconnect()
		statWatcher = nil
	end

	currentSeq += 1

	task.spawn(function()
		-- Only play the sound if the panel was visible, meaning the tutorial was
		-- actively in progress this session. Avoids playing on login when the
		-- player already had all steps saved as complete.
		if completionSound and isPanelVisible then
			completionSound:Play()
		end
		if isPanelVisible then
			local t = tweenOut(panel)
			t.Completed:Wait()
		end
		isPanelVisible = false
		clearObjective()
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

local TutorialClient = {}

function TutorialClient.Start()
	local panel, titleLabel, descLabel, progressBar, fillFrame, progressText, completionSound = buildGui()
	completionSoundRef = completionSound

	-- Reconnect beam whenever character respawns
	LocalPlayer.CharacterAdded:Connect(function(char)
		setupBeam(char)
	end)
	if LocalPlayer.Character then
		setupBeam(LocalPlayer.Character)
	end

	local remotes = ReplicatedStorage:WaitForChild("TutorialRemotes")

	remotes:WaitForChild("TutorialStepChanged").OnClientEvent:Connect(function(step, idx, total)
		showStep(step, idx, total, panel, titleLabel, descLabel, progressBar, fillFrame, progressText)
	end)

	remotes:WaitForChild("TutorialFinished").OnClientEvent:Connect(function()
		onTutorialFinished(panel, completionSound)
	end)
end

return TutorialClient
