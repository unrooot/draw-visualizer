local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).bootstrapStory(script)

local UserInputService = game:GetService("UserInputService")

local Maid = require("Maid")
local DrawVisualizer = require("DrawVisualizer")

return function(target)
	local maid = Maid.new()

	local pane = DrawVisualizer.new(false)
	pane:SetIsFocused(true)
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
