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

export type TutorialStep = BasicStep | LeaderstatStep

export type TutorialConfig = {
	DataStoreName: string,
	DataStoreKeyPrefix: string,
	CompletionSoundId: string?,
	Steps: { TutorialStep },
}

return {}
