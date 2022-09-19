local require = require(script.Parent.loader).load(script)

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Maid = require("Maid")
local PlayerGuiUtils = require("PlayerGuiUtils")
local Rx = require("Rx")
local ValueObject = require("ValueObject")
local VisualizerHeader = require("VisualizerHeader")
local VisualizerInstanceGroup = require("VisualizerInstanceGroup")
local VisualizerListView = require("VisualizerListView")

local Visualizer = setmetatable({}, BasicPane)
Visualizer.ClassName = "Visualizer"
Visualizer.__index = Visualizer

function Visualizer.new()
	local self = setmetatable(BasicPane.new(), Visualizer)

	self:_createScreenGui()

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._targetSearchEnabled = ValueObject.new(false)
	self._maid:GiveTask(self._targetSearchEnabled)
	self._maid:GiveTask(self._targetSearchEnabled.Changed:Connect(function()
		local isEnabled = self._targetSearchEnabled.Value
		if self._targetButton then
			self._targetButton:SetIsChoosen(isEnabled)

			if not isEnabled then
				self._targetSearchEnabled.Value = false
				self._maid._flash = nil
			end
		end
	end))

	self._rootInstance = ValueObject.new()
	self._maid:GiveTask(self._rootInstance)
	self._maid:GiveTask(self._rootInstance.Changed:Connect(function()
		self:_updateRootInstance()
	end))

	self._hoverTarget = ValueObject.new(self._rootInstance.Value)
	self._maid:GiveTask(self._hoverTarget)
	self._maid:GiveTask(self._hoverTarget.Changed:Connect(function()
		self:_flashInstance(self._hoverTarget.Value)
	end))

	self._header = VisualizerHeader.new()
	self._maid:GiveTask(self._header)
	self._maid:GiveTask(self._header.ButtonActivated:Connect(function(buttonName: string, button: table)
		if buttonName == "parent" then
			if self._rootInstance.Value then
				self:SetRootInstance(self._rootInstance.Value.Parent)
			end
		elseif buttonName == "target" then
			if not self._targetButton then
				self._targetButton = button
			end

			self._targetSearchEnabled.Value = not self._targetSearchEnabled.Value
		end
	end))

	self._list = VisualizerListView.new()
	self._maid:GiveTask(self._list)
	self._maid:GiveTask(self._list.InstanceHovered:Connect(function(instance: Instance?)
		self:_flashInstance(instance)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisibleTarget.Value = isVisible and 1 or 0

		self._header:SetVisible(isVisible, doNotAnimate)
		self._list:SetVisible(isVisible, doNotAnimate)
	end))

	self:_listenForInput()

	return self
end

function Visualizer:SetRootInstance(instance: Instance)
	self._rootInstance.Value = instance

	if not instance then
		self._maid._current = nil
		return
	end
end

function Visualizer:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.9)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "DrawVisualizer";
		Parent = props.Parent;
		BackgroundColor3 = Color3.fromRGB(39, 39, 39);
		BackgroundTransparency = transparency;
		Size = UDim2.fromScale(1, 1);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
			self._header:Render({
				AbsoluteRootSize = self._absoluteSize;
				Parent = props.Parent;
			});

			self._list:Render({
				AbsoluteRootSize = self._absoluteSize;
				Parent = props.Parent;
			})
		};
	};
end

function Visualizer:_selectTarget()
	if self._targetSearchEnabled.Value then
		self:SetRootInstance(self._hoverTarget.Value)
	end

	self._targetSearchEnabled.Value = false
	self._maid._flash = nil
end

function Visualizer:_updateTarget()
	if self._targetSearchEnabled.Value then
		local location = UserInputService:GetMouseLocation()
		local guis = StarterGui

		if RunService:IsRunning() then
			local playerGui = PlayerGuiUtils.getPlayerGui()
			if playerGui then
				guis = playerGui
			end
		end

		guis = guis:GetGuiObjectsAtPosition(location.X, location.Y)

		if guis and #guis > 0 then
			self._hoverTarget.Value = guis[1]
		else
			self._hoverTarget.Value = nil
		end
	end
end

function Visualizer:_flashInstance(instance: GuiObject?)
	if not instance then
		if self._maid._flash then
			self._maid._flash = nil
		end

		return
	elseif not instance:IsA("GuiObject") then
		return
	end

	local flashMaid = Maid.new()

	local flashTarget = ValueObject.new(0)
	flashMaid:GiveTask(flashTarget)

	local percentFlash = Blend.Spring(Blend.toPropertyObservable(flashTarget):Pipe({
		Rx.startWith({1})
		}), 10, 1)

	local position = instance.AbsolutePosition
	local size = instance.AbsoluteSize

	local observable = Blend.New "Frame" {
		BackgroundColor3 = Color3.fromRGB(200, 100, 100);
		Position = UDim2.fromOffset(position.X, position.Y);
		Size = UDim2.fromOffset(size.X, size.Y);

		BackgroundTransparency = Blend.Computed(percentFlash, function(percent)
			return 1 - (percent * 0.9)
		end);

		Parent = self._effects;
	};

	flashMaid:GiveTask(observable:Subscribe())

	self._maid._flash = flashMaid

	flashTarget.Value = 0.3
end

function Visualizer:_updateRootInstance()
	if not self._rootInstance.Value then
		return
	end

	local group = VisualizerInstanceGroup.new(self._rootInstance.Value)

	self._list:AddInstanceGroup(group)

	self._maid._current = function()
		if self._list and self._list.RemoveInstanceGroup then
			self._list:RemoveInstanceGroup(group)
		end
	end
end

function Visualizer:_createScreenGui()
	local observable = Blend.New "ScreenGui" {
		Name = "VisualizerEffects";
		DisplayOrder = 99999;
		IgnoreGuiInset = true;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		Parent = CoreGui;
	};

	self._effects = observable
	self._maid:GiveTask(observable:Subscribe())
end

function Visualizer:_listenForInput()
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_selectTarget()
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				if self._targetSearchEnabled.Value then
					self._targetSearchEnabled.Value = false
				end
			end
		end
	end))

	self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		end
	end))

	self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		end
	end))
end

return Visualizer
