local modules = script:WaitForChild("modules")
local loader = script.Parent:FindFirstChild("LoaderUtils", true).Parent

local require = require(loader).bootstrapPlugin(modules)

local Maid = require("Maid")
local Visualizer = require("Visualizer")
local VisualizerConstants = require("VisualizerConstants")

local function renderPane(plugin, target)
	local maid = Maid.new()

	local pane = Visualizer.new()
	maid:GiveTask(pane)
	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	pane:Show()

	return maid
end

local function initialize(plugin)
	local maid = Maid.new()

	local macro = plugin:CreatePluginAction(
		VisualizerConstants.ACTION_NAME,
		VisualizerConstants.ACTION_NAME,
		VisualizerConstants.ACTION_DESC,
		VisualizerConstants.PLUGIN_ICON,
		true
	)

	local toolbar = plugin:CreateToolbar(VisualizerConstants.TOOLBAR_LABEL)
	local toggleButton = toolbar:CreateButton(
		"drawVisualizer",
		VisualizerConstants.PLUGIN_NAME,
		VisualizerConstants.PLUGIN_ICON,
		VisualizerConstants.PLUGIN_DESC
	)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 0, 0)

	local target = plugin:CreateDockWidgetPluginGui(VisualizerConstants.PLUGIN_NAME, info)
	target.Name = VisualizerConstants.PLUGIN_NAME
	target.Title = VisualizerConstants.PLUGIN_NAME
	target.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function update()
		local isEnabled = target.Enabled

		toggleButton:SetActive(isEnabled)

		if isEnabled then
			maid._current = renderPane(plugin, target)
		else
			maid._current = nil
		end
	end

	maid:GiveTask(macro.Triggered:Connect(function()
		target.Enabled = not target.Enabled
	end))

	maid:GiveTask(toggleButton.Click:Connect(function()
		target.Enabled = not target.Enabled
	end))

	maid:GiveTask(target:GetPropertyChangedSignal("Enabled"):Connect(update))

	maid:GiveTask(plugin.Unloading:Connect(function()
		maid:Destroy()
	end))

	update()

	return maid
end

if plugin then
	initialize(plugin)
end
