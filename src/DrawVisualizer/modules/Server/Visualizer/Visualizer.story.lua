local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local UserInputService = game:GetService("UserInputService")

local Maid = require("Maid")
local Visualizer = require("Visualizer")

return function(target)
	target.Parent.Parent.Parent.BackgroundColor3 = Color3.fromRGB(75, 75, 75)

	local maid = Maid.new()

	local pane = Visualizer.new()
	maid:GiveTask(pane)
	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	pane:Show()

	local isListening = true

	maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.V then
			pane:Toggle()
		elseif input.KeyCode == Enum.KeyCode.P then
			isListening = not isListening
		end
	end))

	return function()
		maid:DoCleaning()
	end
end
