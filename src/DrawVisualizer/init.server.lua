local modules = script:WaitForChild("modules")
local loader = script.Parent:FindFirstChild("LoaderUtils", true).Parent

local require = require(loader).bootstrapPlugin(modules)

local RunService = game:GetService("RunService")

local Blend = require("Blend")
local Maid = require("Maid")
local VisualizerConstants = require("VisualizerConstants")

local currentPane
local isInGame = RunService:IsRunning() and RunService:IsClient()

local function renderPane(target)
	local maid = Maid.new()

	local DrawVisualizer = require("DrawVisualizer")

	local pane = DrawVisualizer.new()
	maid:GiveTask(pane)
	maid:GiveTask(pane:Render({
		Parent = target;
	}):Subscribe())

	pane:Show()

	return maid, pane
end

local function createActions(plugin, target, maid)
	for key, data in VisualizerConstants.ACTIONS do
		local macro = plugin:CreatePluginAction(
			"[Draw Visualizer] " .. data.Name,
			"[Draw Visualizer] " .. data.Name,
			data.Description,
			VisualizerConstants.PLUGIN_ICON,
			true
		)

		maid:GiveTask(macro.Triggered:Connect(function()
			if not data.Action then
				return warn(string.format("[DrawVisualizer]: Action %q missing action function!", key))
			end

			if key == "Toggle" then
				data.Action(target)
			else
				data.Action(currentPane)
			end
		end))
	end
end

local function initialize(plugin)
	local maid = Maid.new()

	local pluginIcon = VisualizerConstants.PLUGIN_ICON

	local toolbar = plugin:CreateToolbar(VisualizerConstants.TOOLBAR_LABEL)
	local toggleButton = toolbar:CreateButton(
		"drawVisualizer",
		VisualizerConstants.PLUGIN_NAME,
		pluginIcon,
		VisualizerConstants.PLUGIN_DESC
	)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 0, 0)
	local target

	if not isInGame then
		target = plugin:CreateDockWidgetPluginGui(VisualizerConstants.PLUGIN_NAME, info)
		target.Name = VisualizerConstants.PLUGIN_NAME
		target.Title = VisualizerConstants.PLUGIN_NAME
		target.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	end

	local function update()
		local isEnabled = target.Enabled

		toggleButton:SetActive(isEnabled)

		if isEnabled then
			local paneMaid, pane = renderPane(target)

			currentPane = pane
			maid._current = paneMaid

			if isInGame then
			else
				paneMaid:GiveTask(target.WindowFocused:Connect(function()
					pane:SetIsFocused(true)
				end))

				paneMaid:GiveTask(target.WindowFocusReleased:Connect(function()
					pane:SetIsFocused(false)
				end))
			end

			paneMaid:GiveTask(pane:ObserveRootInstance():Subscribe(function(instance)
				if not instance then
					target.Title = VisualizerConstants.PLUGIN_NAME
				else
					local count = #instance:GetDescendants()

					if count > 0 then
						target.Title = `{VisualizerConstants.PLUGIN_NAME} - {instance.Name} ({count})`
					else
						target.Title = `{VisualizerConstants.PLUGIN_NAME} - {instance.Name}`
					end
				end
			end))
		else
			currentPane = nil
			maid._current = nil
		end
	end

	createActions(plugin, target, maid)

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
