local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Rx = require("Rx")
local Signal = require("Signal")
local Table = require("Table")
local ValueObject = require("ValueObject")
local VisualizerControlButton = require("VisualizerControlButton")

local VisualizerControls = setmetatable({}, BasicPane)
VisualizerControls.ClassName = "VisualizerControls"
VisualizerControls.__index = VisualizerControls

function VisualizerControls.new()
	local self = setmetatable(BasicPane.new(), VisualizerControls)

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self.ButtonActivated = self._maid:Add(Signal.new())

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	self:_createButtons()

	return self
end

function VisualizerControls:_createButtons()
	self._buttons = {}

	self._targetButton = VisualizerControlButton.new("target")
	self._targetButton:SetLayoutOrder(1)
	self._targetButton:SetText("choose target")
	self._targetButton:SetToggleBehavior(true)
	self._maid:GiveTask(self._targetButton)
	self._maid:GiveTask(self._targetButton.Activated:Connect(function(...)
		self.ButtonActivated:Fire(...)
	end))

	self._parentButton = self._maid:Add(VisualizerControlButton.new("parent"))
	self._parentButton:SetLayoutOrder(2)
	self._parentButton:SetText("up one parent")
	self._maid:GiveTask(self._parentButton.Activated:Connect(function(...)
		self.ButtonActivated:Fire(...)
	end))

	self._propertiesButton = self._maid:Add(VisualizerControlButton.new("properties"))
	self._propertiesButton:SetLayoutOrder(3)
	self._propertiesButton:SetText("view properties")
	self._propertiesButton:SetToggleBehavior(true)
	self._maid:GiveTask(self._propertiesButton.Activated:Connect(function(...)
		self.ButtonActivated:Fire(...)
	end))

	self._buttons[self._targetButton] = true
	self._buttons[self._parentButton] = true
	self._buttons[self._propertiesButton] = true

	self._buttonMap = {
		self._targetButton,
		self._parentButton,
		self._propertiesButton
	}

	self._buttonCount = self._maid:Add(ValueObject.new(3))

	self._buttonsEnabled = self._maid:Add(ValueObject.new(Table.copy(self._buttons)))
end

function VisualizerControls:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 35, 1)

	local transparency = Blend.Computed(percentVisible, function(percent)
		local itemCount = math.max(1, #self._buttonMap)

		for index, button in ipairs(self._buttonMap) do
			local progress = (index - 1) / itemCount + 1e-1
			button:SetVisible(progress <= percent)
		end

		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "VisualizerControls";
		Parent = props.Parent;

		AnchorPoint = Vector2.new(0, 1);
		BackgroundColor3 = Color3.fromRGB(43, 43, 43);
		BackgroundTransparency = transparency;
		ClipsDescendants = true;
		Position = UDim2.fromScale(0, 1);
		Size = UDim2.fromScale(1, 0.667);

		[Blend.Children] = {
			Blend.New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal;
				HorizontalAlignment = Enum.HorizontalAlignment.Center;
				Padding = UDim.new(0, 1);
				SortOrder = Enum.SortOrder.LayoutOrder;
				VerticalAlignment = Enum.VerticalAlignment.Center;
			};

			Blend.ComputedPairs(self._buttonsEnabled, function(button)
				return button:Render({
					AbsoluteRootSize = props.AbsoluteRootSize;
					ButtonCount = self._buttonCount;
					RootInstance = props.RootInstance;
					Parent = props.Parent;
				})
			end);
		};
	};
end

return VisualizerControls

