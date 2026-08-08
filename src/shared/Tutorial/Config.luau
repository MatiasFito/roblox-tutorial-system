local Types = require(script.Parent.Types)
local Workspace = game:GetService("Workspace")
local Plot = Workspace:WaitForChild("Plot")

local config: Types.TutorialConfig = {
	-- Change DataStoreName and DataStoreKeyPrefix per project to isolate progress
	DataStoreName = "MyGame_TutorialProgress",
	DataStoreKeyPrefix = "tutorial_", -- Final key = prefix .. player.UserId

	-- Set to "rbxassetid://XXXX" to play a sound on step completion, or leave nil
	CompletionSoundId = "rbxassetid://94049811777092",

	Steps = {
		-- Example Basic step: completes when TutorialService.CompleteStep(player) is called
		{
			stepType = "Basic",
			title = "Buy Plot",
			description = "Step on the green button to purchase your plot.",
			objective = CFrame.new(Plot.Position), -- Replace with the actual position of the button
		} :: Types.BasicStep,

		-- Example Leaderstats step: auto-completes when leaderstats.Gold reaches 1000
		{
			stepType = "Leaderstats",
			title = "Reach 1000 Gold",
			description = "Collect gold around the map to reach 1000.",
			objective = CFrame.new(10, 0, 10), -- Replace with where gold can be found
			statName = "Gold",
			targetValue = 1000,
		} :: Types.LeaderstatStep,

		-- Example GuiElement step: completes when the player clicks the target button
		{
			stepType = "GuiElement",
			title = "Draw a Card",
			description = "Click the Draw button to draw a card from your deck.",
			targetElement = "StarterGui.MainHud.Recruit.Decks.Deck1.Draw", -- Absolute path starting at StarterGui
		} :: Types.GuiElementStep,
	},
}

return config
