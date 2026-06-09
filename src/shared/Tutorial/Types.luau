export type BasicStep = {
	stepType: "Basic",
	title: string,
	description: string,
	objective: CFrame,
}

export type LeaderstatStep = {
	stepType: "Leaderstats",
	title: string,
	description: string,
	objective: CFrame,
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
