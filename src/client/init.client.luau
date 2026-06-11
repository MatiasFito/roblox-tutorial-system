local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
local TutorialClient = require(PlayerScripts.Client.TutorialClient)
TutorialClient.Start()
