local require = require(game:GetService("ServerScriptService"):FindFirstChild("LoaderUtils", true).Parent).load(script)

local UserInputService = game:GetService("UserInputService")

local Blend = require("Blend")
local CommandPalette = require("CommandPalette")
local Maid = require("Maid")

return function(target)
	local maid = Maid.new()

	Blend.New "TextLabel" {
		Size = UDim2.fromOffset(100, 50);
		Parent = target;
	}:Subscribe(function(targetFrame)
		local cmdPalette = CommandPalette.new(targetFrame)
		maid:GiveTask(cmdPalette)

		maid:GiveTask(cmdPalette.EscapePressed:Connect(function()
			cmdPalette:Hide()

			task.delay(0.5, function()
				cmdPalette:Show()
			end)
		end))

		maid:GiveTask(cmdPalette:Render({
			Parent = target;
		}):Subscribe())

		cmdPalette:Show()

		maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.V then
				cmdPalette:Toggle()
			end
		end))
	end)

	return function()
		maid:DoCleaning()
	end
end