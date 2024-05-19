local require = require(script.Parent.loader).load(script)

local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local CommandPalette = require("CommandPalette")
local Maid = require("Maid")
local PlayerGuiUtils = require("PlayerGuiUtils")
local Rx = require("Rx")
local SpringObject = require("SpringObject")
local UIPaddingUtils = require("UIPaddingUtils")
local ValueObject = require("ValueObject")
local VisualizerHeader = require("VisualizerHeader")
local VisualizerListView = require("VisualizerListView")

local DrawVisualizer = setmetatable({}, BasicPane)
DrawVisualizer.ClassName = "DrawVisualizer"
DrawVisualizer.__index = DrawVisualizer

function DrawVisualizer.new(isHoarcekat: boolean)
	local self = setmetatable(BasicPane.new(), DrawVisualizer)

	self:_createScreenGui()

	self._maid._flash = Maid.new()
	self._flashMap = {}

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.new()))
	self._currentObjects = self._maid:Add(ValueObject.new(nil))
	self._isFocused = self._maid:Add(ValueObject.new(false))
	self._objectIndex = self._maid:Add(ValueObject.new(1))
	self._propertiesVisible = self._maid:Add(ValueObject.new(false))
	self._rootInstance = self._maid:Add(ValueObject.new(nil))
	self._targetSearchEnabled = self._maid:Add(ValueObject.new(false))
	self._hoverTarget = self._maid:Add(ValueObject.new(nil))

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._maid:GiveTask(self._objectIndex.Changed:Connect(function()
		local objects = self._currentObjects.Value
		local index = self._objectIndex.Value

		if not objects or index == 0 then
			self._hoverTarget.Value = nil
			return
		end

		if objects[index] then
			self._hoverTarget.Value = objects[index]
		else
			self._hoverTarget.Value = nil
		end
	end))

	self._maid:GiveTask(self._targetSearchEnabled.Changed:Connect(function()
		local isEnabled = self._targetSearchEnabled.Value

		self._objectIndex.Value = 1

		if self._targetButton then
			self._targetButton:SetIsChoosen(isEnabled)

			if not isEnabled then
				self:SetTargetSearchEnabled(false)
				self:_flashInstances()
			end
		end
	end))

	self._maid:GiveTask(self._rootInstance.Changed:Connect(function()
		if not self._rootInstance.Value then
			return
		end

		self:_flashInstances(self._rootInstance.Value)
	end))

	self._maid:GiveTask(self._hoverTarget.Changed:Connect(function()
		if self._currentObjects.Value then
			self:_flashInstances(self._currentObjects.Value)
		else
			self:_flashInstances(self._hoverTarget.Value, 0)
		end
	end))

	self._maid:GiveTask(self._currentObjects:Observe():Subscribe(function(objects)
		local index = self._objectIndex.Value

		if not objects then
			self._objectIndex.Value = 1
			self._hoverTarget.Value = nil
			self:_flashInstances(nil)
			return
		end

		if objects[index] then
			self._hoverTarget.Value = objects[index]
		end

		self:_flashInstances(objects)
	end))

	self._header = self._maid:Add(VisualizerHeader.new())
	self._maid:GiveTask(self._header.ButtonActivated:Connect(function(buttonName: string, button)
		if buttonName == "parent" then
			self:_moveUpOneParent()
		elseif buttonName == "target" then
			if not self._targetButton then
				self._targetButton = button
			end

			self:SetTargetSearchEnabled(not self._targetSearchEnabled.Value)
		elseif buttonName == "properties" then
			self:InspectInstance(self._rootInstance.Value)
		end
	end))

	self._list = self._maid:Add(VisualizerListView.new())

	self._maid:GiveTask(self._list.InstancePicked:Connect(function(instance: Instance?)
		self:SetRootInstance(instance)
	end))

	self._maid:GiveTask(self._list.InstanceInspected:Connect(function(instance: Instance?)
		self:InspectInstance(instance)
	end))

	self._maid:GiveTask(self._list.InstanceHovered:Connect(function(instance: Instance?)
		self:_flashInstances(instance)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisibleTarget.Value = isVisible and 1 or 0

		self._header:SetVisible(isVisible, doNotAnimate)
		self._list:SetVisible(isVisible, doNotAnimate)
	end))

	self:_listenForInput()

	if not isHoarcekat then
		self:SetTargetSearchEnabled(true)
	end

	return self
end

function DrawVisualizer:SetIsFocused(isFocused: boolean)
	self._isFocused.Value = isFocused
end

function DrawVisualizer:ObserveRootInstance()
	return self._rootInstance:Observe()
end

function DrawVisualizer:SetTargetSearchEnabled(isEnabled: boolean)
	self._targetSearchEnabled.Value = isEnabled
end

function DrawVisualizer:SetRootInstance(instance: Instance)
	self._rootInstance.Value = instance

	if not instance then
		self._maid._current = nil
		return
	end
end

function DrawVisualizer:InspectInstance(instance: Instance?)
	if not self._properties then
		return
	end

	self._propertiesVisible.Value = not self._propertiesVisible.Value

	local maid = Maid.new()

	local palette = maid:Add(CommandPalette.new(instance))

	maid:GiveTask(palette:Render({
		Position = UDim2.fromScale(0.5, 0);
		Size = UDim2.fromScale(1, 1);
		Parent = self._properties;
	}):Subscribe(function()
		palette:Show()
		palette:SetInputFocused(true)
	end))

	maid:GiveTask(self._propertiesVisible:Observe():Subscribe(function(isVisible)
		if not isVisible then
			palette:Hide()
			task.delay(0.5, function()
				maid:Destroy()
			end)
		end
	end))

	maid:GiveTask(palette.EscapePressed:Connect(function()
		self._propertiesVisible.Value = false
	end))
end

function DrawVisualizer:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.9)

	local percentPropertiesVisible = Blend.Spring(Blend.toPropertyObservable(self._propertiesVisible:Observe():Pipe({
		Rx.map(function(visible)
			return visible and 1 or 0
		end)
		})
	), 30, 0.9)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "DrawVisualizer";
		Parent = props.Parent;
		BackgroundColor3 = Color3.fromRGB(40, 40, 40);
		BackgroundTransparency = transparency;
		Size = UDim2.fromScale(1, 1);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "body";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);

				Position = Blend.Computed(percentPropertiesVisible, function(percent)
					return UDim2.fromScale(-percent, 0)
				end);

				[Blend.Children] = {
					self._header:Render({
						AbsoluteRootSize = self._absoluteSize;
						IsFocused = self._isFocused;
						RootInstance = self._rootInstance;
						TargetSearchEnabled = self._targetSearchEnabled;
						Parent = props.Parent;
					});

					self._list:Render({
						AbsoluteRootSize = self._absoluteSize;
						RootInstance = self._rootInstance;
						Parent = props.Parent;
					})
				};
			};

			Blend.New "Frame" {
				Name = "properties";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);

				Position = Blend.Computed(percentPropertiesVisible, function(percent)
					return UDim2.fromScale(1 - percent, 0)
				end);

				[Blend.Instance] = function(properties)
					self._properties = properties
				end;

				-- UIPaddingUtils.fromUDim(UDim.new(0, 25));

				[Blend.OnEvent "InputBegan"] = function(input)
					if input.KeyCode == Enum.KeyCode.Escape then
						self._propertiesVisible.Value = false
					end
				end;
			};
		};
	};
end

function DrawVisualizer:_moveUpOneParent()
	if self._rootInstance.Value then
		self:SetRootInstance(self._rootInstance.Value.Parent)
	end
end

function DrawVisualizer:_selectTarget(ctrlPressed: boolean)
	if self._targetSearchEnabled.Value then
		self:SetRootInstance(self._hoverTarget.Value)

		if ctrlPressed then
			Selection:Set({self._hoverTarget.Value})
		end
	end

	self._targetSearchEnabled.Value = false
	self:_flashInstances()
end

function DrawVisualizer:_updateTarget()
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
			self._currentObjects.Value = guis
		else
			self._currentObjects.Value = nil
		end
	end
end

function DrawVisualizer:_flashInstances(instances: { GuiObject? })
	if not instances then
		for instance, maid in self._flashMap do
			maid:Destroy()
			self._flashMap[instance] = nil
		end

		return
	end

	if typeof(instances) == "Instance" then
		instances = { instances }
	end

	local flashed = {}

	local objectIndex = self._objectIndex.Value

	for index, instance in instances do
		if not instance:IsA("GuiObject") then
			continue
		end

		if self._maid._flash[instance] then
			flashed[instance] = true

			self._maid._flash[instance].Depth.Value = index - objectIndex

			continue
		end

		local flashMaid = Maid.new()

		self._flashMap[instance] = flashMaid
		flashed[instance] = true

		local flashTarget = flashMaid:Add(ValueObject.new(0.5))
		local visibleTarget = flashMaid:Add(ValueObject.new(1))

		local percentAlpha = Blend.AccelTween(visibleTarget:Observe(), 400):Pipe({
			Rx.map(function(percent)
				return 1 - percent
			end)
		})

		local percentFlash = flashMaid:Add(SpringObject.new(flashTarget, 25, 1))

		local position = instance.AbsolutePosition
		local size = instance.AbsoluteSize

		flashMaid.Depth = ValueObject.new(index)
		flashMaid:GiveTask(flashMaid.Depth.Changed:Connect(function()
			percentFlash:Impulse(30)
		end))

		local color = Blend.Computed(flashMaid.Depth:Observe(), function(depth)
			if depth % 3 == 0 then
				return Color3.fromRGB(200, 100, 100)
			elseif depth % 2 == 0 then
				return Color3.fromRGB(100, 200, 200)
			else
				return Color3.fromRGB(200, 200, 100)
			end
		end);

		local observable = Blend.New "Frame" {
			Name = "flash";
			BackgroundColor3 = color;
			Position = UDim2.fromOffset(position.X, position.Y);
			Size = UDim2.fromOffset(size.X, size.Y);
			Parent = self._effects;

			BackgroundTransparency = Blend.Computed(percentFlash, function(percent)
				return 1 - (percent * 0.4)
			end);

			Visible = Blend.Computed(flashMaid.Depth, function(depth)
				return depth >= 0
			end);

			ZIndex = Blend.Computed(flashMaid.Depth, function(depth)
				return 100 - depth
			end);

			Blend.New "UIStroke" {
				Color = color;

				Transparency = Blend.Computed(percentFlash, function(percent)
					return 1 - (percent * 0.6)
				end);
			};

			Blend.New "TextLabel" {
				Name = "depth";
				AutomaticSize = Enum.AutomaticSize.XY;
				BackgroundColor3 = color;
				FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
				Position = UDim2.fromOffset(-1, -10);
				TextColor3 = Color3.fromRGB(255, 255, 255);
				TextSize = 11;
				TextStrokeColor3 = Color3.fromRGB(65, 65, 65);
				TextXAlignment = Enum.TextXAlignment.Left;

				BackgroundTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.8)
				end);

				Text = Blend.Computed(flashMaid.Depth, function(depth)
					return depth
				end);

				TextTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.9)
				end);

				TextStrokeTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.2)
				end);

				Visible = Blend.Computed(flashMaid.Depth, function(depth)
					return depth >= 0
				end);

				Blend.New "UIPadding" {
					PaddingLeft = UDim.new(0, 5);
					PaddingRight = UDim.new(0, 5);
				};
			};

			Blend.New "TextLabel" {
				Name = "label";
				AnchorPoint = Vector2.new(1, 0);
				AutomaticSize = Enum.AutomaticSize.XY;
				BackgroundColor3 = color;
				BorderColor3 = Color3.fromRGB(27, 42, 53);
				FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
				Position = UDim2.new(1, 1, 1, 0);
				TextColor3 = Color3.fromRGB(255, 255, 255);
				TextSize = 11;
				TextStrokeColor3 = Color3.fromRGB(65, 65, 65);
				TextXAlignment = Enum.TextXAlignment.Right;

				BackgroundTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.8)
				end);

				Text = Blend.Computed(instance, function(guiObject)
					local size = guiObject.AbsoluteSize
					local x, y = math.floor(size.X * 10000 + 0.5) / 10000, math.floor(size.Y * 10000 + 0.5) / 10000

					return `{guiObject.Name} - {x}x{y}`
				end);

				TextTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.9)
				end);

				TextStrokeTransparency = Blend.Computed(percentAlpha, function(percent)
					return 1 - (percent * 0.2)
				end);

				Blend.New "UIPadding" {
					PaddingLeft = UDim.new(0, 5);
					PaddingRight = UDim.new(0, 5);
				};
			};
		}

		flashMaid:GiveTask(observable:Subscribe())

		visibleTarget.Value = 0

		self._maid._flash[instance] = flashMaid

		flashMaid:GiveTask(function()
			if self._maid._flash then
				self._maid._flash[instance] = nil
			end
		end)
	end

	for instance, maid in self._flashMap do
		if not flashed[instance] then
			maid:Destroy()
			self._flashMap[instance] = nil
		end
	end
end

function DrawVisualizer:_createScreenGui()
	self._maid:GiveTask(Blend.New "ScreenGui" {
		Name = "VisualizerEffects";
		DisplayOrder = 999;
		IgnoreGuiInset = true;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		Parent = CoreGui;
	}:Subscribe(function(screenGui)
		self._effects = screenGui
	end));
end

function DrawVisualizer:_listenForInput()
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		local keysPressed = UserInputService:GetKeysPressed()

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			local ctrlPressed = false

			for _, inputObject in keysPressed do
				if inputObject.KeyCode == Enum.KeyCode.LeftControl then
					ctrlPressed = true
				end
			end

			self:_selectTarget(ctrlPressed)
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				if self._targetSearchEnabled.Value then
					self._targetSearchEnabled.Value = false
				elseif self._propertiesVisible.Value then
					self._propertiesVisible.Value = false
				end
			elseif input.KeyCode == Enum.KeyCode.Tab then
				if self._targetSearchEnabled.Value then
					local objectIndex = self._objectIndex.Value
					local objects = self._currentObjects.Value
					local shiftPressed = false

					for _, inputObject in keysPressed do
						if inputObject.KeyCode == Enum.KeyCode.LeftShift then
							shiftPressed = true
						end
					end

					if objects then
						if not shiftPressed then
							if objectIndex + 1 <= #objects then
								self._objectIndex.Value += 1
							end
						else
							if objectIndex - 1 > 0 then
								self._objectIndex.Value -= 1
							end
						end
					end
				end
			elseif input.KeyCode == Enum.KeyCode.P then
				self:_moveUpOneParent()
			end
		end
	end))

	self._maid:GiveTask(UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		elseif input.UserInputType == Enum.UserInputType.Keyboard then
			for _, inputObject in UserInputService:GetKeysPressed() do
			end
		end
	end))

	self._maid:GiveTask(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			self:_updateTarget()
		end
	end))
end

return DrawVisualizer
