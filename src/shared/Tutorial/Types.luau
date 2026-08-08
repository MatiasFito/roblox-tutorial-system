export type BasicStep = {
	stepType: "Basic",
	title: string,
	description: string,
	objective: CFrame?, -- Optional: omit or set to nil for steps with no beam guidance
}

export type LeaderstatStep = {
	stepType: "Leaderstats",
	title: string,
	description: string,
	objective: CFrame?, -- Optional: omit or set to nil for steps with no beam guidance
	statName: string,
	targetValue: number,
}

export type GuiElementStep = {
	stepType: "GuiElement",
	title: string,
	description: string,
	objective: CFrame?, -- Optional: omit or set to nil for steps with no beam guidance
	targetElement: string, -- Absolute path starting at StarterGui, e.g. "StarterGui.MainGui.Main.BuyButton"
}

export type TutorialStep = BasicStep | LeaderstatStep | GuiElementStep

export type TutorialConfig = {
	DataStoreName: string,
	DataStoreKeyPrefix: string,
	CompletionSoundId: string?,
	Steps: { TutorialStep },
}

return {}
