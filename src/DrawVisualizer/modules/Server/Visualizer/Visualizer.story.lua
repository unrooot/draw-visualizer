local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local Maid = require("Maid")
local Visualizer = require("Visualizer")

return function(target)
	target.Parent.Parent.Parent.BackgroundColor3 = Color3.fromRGB(75, 75, 75)

	local maid = Maid.new()

	local pane = Visualizer.new()
	local isListening = true

	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	pane:Show()

	pane:SetRootInstance(Selection:Get()[1])
	maid:GiveTask(Selection.SelectionChanged:Connect(function()
		if isListening then
			pane:SetRootInstance(Selection:Get()[1])
		end
	end))

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
