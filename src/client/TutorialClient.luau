local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")

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
local guiHighlight: ScreenGui? = nil
local guiHighlightConnections: { RBXScriptConnection } = {}
local stepCompletedRemote: RemoteEvent? = nil

-- ──────────────────────────────────────────────────────────────────────────────
-- GUI
-- ──────────────────────────────────────────────────────────────────────────────

local function ensureGui()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = playerGui:WaitForChild("TutorialGui") :: ScreenGui
	local panel = screenGui:WaitForChild("Panel") :: Frame
	local titleLabel = panel:WaitForChild("TitleLabel") :: TextLabel
	local descLabel = panel:WaitForChild("DescLabel") :: TextLabel
	local progressBar = panel:WaitForChild("ProgressBar") :: Frame
	local fillFrame = progressBar:WaitForChild("Fill") :: Frame
	local progressText = progressBar:WaitForChild("ProgressText") :: TextLabel
	local completionSound = panel:FindFirstChild("CompletionSound") :: Sound?

	-- Set the SoundId from Config if present
	if completionSound and Config.CompletionSoundId ~= nil then
		completionSound.SoundId = Config.CompletionSoundId
	end

	-- Start hidden
	panel.Position = HIDDEN_POS

	return panel, titleLabel, descLabel, progressBar, fillFrame, progressText, completionSound
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Beam
-- ──────────────────────────────────────────────────────────────────────────────

local function ensureBeam(character: Model)
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
			local beamTemplate = ReplicatedStorage:WaitForChild("TutorialSystem"):WaitForChild("Beam") :: Beam
			local newBeam = beamTemplate:Clone()
			newBeam.Attachment0 = att0
			newBeam.Attachment1 = att1
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
			ensureBeam(char)
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- GUI highlight (GuiElement steps)
-- ──────────────────────────────────────────────────────────────────────────────

local function resolveGuiElement(path: string): GuiButton?
	-- Path starts at StarterGui, e.g. "StarterGui.MainGui.Main.BuyButton"
	-- We navigate from PlayerGui (the cloned copy) instead
	local segments = string.split(path, ".")
	if #segments < 2 then
		return nil
	end

	local current: Instance? = LocalPlayer:WaitForChild("PlayerGui")
	for i = 2, #segments do
		if not current then
			return nil
		end
		current = current:WaitForChild(segments[i], 10)
	end

	return current :: GuiButton?
end

local function clearGuiHighlight()
	if guiHighlight then
		guiHighlight:Destroy()
		guiHighlight = nil
	end
	for _, conn in ipairs(guiHighlightConnections) do
		conn:Disconnect()
	end
	table.clear(guiHighlightConnections)
end

local function setupGuiHighlight(targetElementPath: string)
	clearGuiHighlight()

	local target = resolveGuiElement(targetElementPath)
	if not target then
		warn("[TutorialClient] Could not resolve GuiElement target:", targetElementPath)
		return
	end

	local template = ReplicatedStorage:WaitForChild("TutorialSystem"):WaitForChild("TutorialHighlight") :: ScreenGui
	local highlight = template:Clone()
	highlight.Parent = LocalPlayer:WaitForChild("PlayerGui")
	guiHighlight = highlight

	local top = highlight:WaitForChild("Top") :: Frame
	local bottom = highlight:WaitForChild("Bottom") :: Frame
	local left = highlight:WaitForChild("Left") :: Frame
	local right = highlight:WaitForChild("Right") :: Frame
	local border = highlight:WaitForChild("Border") :: Frame

	local function getTargetScreenPosition(): Vector2
		local absPos = target.AbsolutePosition
		local targetGui = target:FindFirstAncestorOfClass("ScreenGui") :: ScreenGui?
		if targetGui and not targetGui.IgnoreGuiInset then
			absPos = absPos + GuiService:GetGuiInset()
		end
		return absPos
	end

	local function positionOverlay()
		local absPos = getTargetScreenPosition()
		local absSize = target.AbsoluteSize
		local viewport = workspace.CurrentCamera :: Camera?
		if not viewport then
			return
		end
		local vpSize = viewport.ViewportSize

		-- Top dark frame
		top.Size = UDim2.fromOffset(vpSize.X, absPos.Y)
		top.Position = UDim2.fromOffset(0, 0)

		-- Bottom dark frame
		bottom.Size = UDim2.fromOffset(vpSize.X, vpSize.Y - (absPos.Y + absSize.Y))
		bottom.Position = UDim2.fromOffset(0, absPos.Y + absSize.Y)

		-- Left dark frame
		left.Size = UDim2.fromOffset(absPos.X, absSize.Y)
		left.Position = UDim2.fromOffset(0, absPos.Y)

		-- Right dark frame
		right.Size = UDim2.fromOffset(vpSize.X - (absPos.X + absSize.X), absSize.Y)
		right.Position = UDim2.fromOffset(absPos.X + absSize.X, absPos.Y)

		-- Lime green border around the target
		border.Size = UDim2.fromOffset(absSize.X, absSize.Y)
		border.Position = UDim2.fromOffset(absPos.X, absPos.Y)
	end

	positionOverlay()
	table.insert(guiHighlightConnections, target:GetPropertyChangedSignal("AbsolutePosition"):Connect(positionOverlay))
	table.insert(guiHighlightConnections, target:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionOverlay))

	-- Complete the step when the target button is clicked
	table.insert(
		guiHighlightConnections,
		target.Activated:Connect(function()
			if stepCompletedRemote then
				stepCompletedRemote:FireServer()
			end
		end)
	)
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
		elseif step.stepType == "GuiElement" then
			progressBar.Visible = false
			setupGuiHighlight(step.targetElement)
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
		clearGuiHighlight()
	end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

local TutorialClient = {}

function TutorialClient.Start()
	local panel, titleLabel, descLabel, progressBar, fillFrame, progressText, completionSound = ensureGui()
	completionSoundRef = completionSound

	-- Reconnect beam whenever character respawns
	LocalPlayer.CharacterAdded:Connect(function(char)
		ensureBeam(char)
	end)
	if LocalPlayer.Character then
		ensureBeam(LocalPlayer.Character)
	end

	local remotes = ReplicatedStorage:WaitForChild("TutorialRemotes")
	stepCompletedRemote = remotes:WaitForChild("TutorialStepCompleted") :: RemoteEvent

	remotes:WaitForChild("TutorialStepChanged").OnClientEvent:Connect(function(step, idx, total)
		showStep(step, idx, total, panel, titleLabel, descLabel, progressBar, fillFrame, progressText)
	end)

	remotes:WaitForChild("TutorialFinished").OnClientEvent:Connect(function()
		onTutorialFinished(panel, completionSound)
	end)
end

return TutorialClient
