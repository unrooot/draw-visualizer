local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local ButtonHighlightModel = require("ButtonHighlightModel")
local Rx = require("Rx")
local Signal = require("Signal")
local UIPaddingUtils = require("UIPaddingUtils")
local ValueObject = require("ValueObject")

local VisualizerControlButton = setmetatable({}, BasicPane)
VisualizerControlButton.ClassName = "VisualizerControlButton"
VisualizerControlButton.__index = VisualizerControlButton

function VisualizerControlButton.new(buttonName: string)
	local self = setmetatable(BasicPane.new(), VisualizerControlButton)

	self.ButtonName = assert(buttonName, "[VisualizerControlButton]: Must provide a button name!")

	self.Activated = Signal.new()
	self._maid:GiveTask(self.Activated)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._isChoosen = ValueObject.new(false)
	self._maid:GiveTask(self._isChoosen)
	self._maid:GiveTask(self._isChoosen.Changed:Connect(function()
		self._buttonModel:SetIsChoosen(self._isChoosen.Value)
	end))

	self._text = ValueObject.new("")
	self._maid:GiveTask(self._text)

	self._layoutOrder = ValueObject.new(1)
	self._maid:GiveTask(self._layoutOrder)

	self._buttonModel = ButtonHighlightModel.new()
	self._maid:GiveTask(self._buttonModel)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerControlButton:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
end

function VisualizerControlButton:SetText(text: string)
	self._text.Value = text
end

function VisualizerControlButton:SetIsChoosen(isChoosen: boolean)
	self._isChoosen.Value = isChoosen
end

function VisualizerControlButton:SetToggleBehavior(isTogglable: boolean)
	self._isTogglable = isTogglable
end

function VisualizerControlButton:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.65)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	local percentHighlight = Blend.Computed(self._buttonModel:ObservePercentHighlighted(), function(percent)
		return percent
	end);

	local percentPress = Blend.Computed(self._buttonModel:ObservePercentPressed(), function(percent)
		return percent
	end);

	local percentChoose = Blend.Computed(self._buttonModel:ObservePercentChoosen(), function(percent)
		return percent
	end);

	local baseColor = Color3.fromRGB(72, 72, 72)

	return Blend.New "Frame" {
		Name = "ControlButton";
		BackgroundTransparency = 1;
		LayoutOrder = self._layoutOrder;

		Size = Blend.Computed(props.AbsoluteRootSize, function(size: Vector2)
			local buttonCount = props.ButtonCount.Value
			local paddingAmount = buttonCount > 1 and (1 / size.X) or 0
			local scaleWidth = (1 / buttonCount)

			return UDim2.new(scaleWidth - paddingAmount, 0, 1, 0)
		end);

		[Blend.Children] = {
			Blend.New "TextButton" {
				Name = "button";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);
				Text = "";
				Visible = BasicPaneUtils.observeVisible(self);
				ZIndex = 5;

				[Blend.OnEvent "Activated"] = function()
					self.Activated:Fire(self.ButtonName, self)
				end;

				[Blend.Instance] = function(button)
					self._buttonModel:SetButton(button)
				end;
			};

			Blend.New "Frame" {
				Name = "wrapper";
				AnchorPoint = Vector2.new(0.5, 0.5);
				BackgroundTransparency = transparency;
				Size = UDim2.fromScale(1, 1);

				BackgroundColor3 = Blend.Computed(percentHighlight, percentChoose, percentPress, function(highlight, choose, press)
					local percent = highlight + (choose / 2) + press

					return baseColor:Lerp(Color3.fromRGB(90, 90, 90), percent);
				end);

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(0.5, 0.5 + percent)
				end);

				[Blend.Children] = {
					UIPaddingUtils.fromUDim(UDim.new(0, 5));

					Blend.New "TextLabel" {
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxasset://fonts/families/Inconsolata.json", Enum.FontWeight.Medium, Enum.FontStyle.Normal);
						Size = UDim2.fromScale(1, 1);
						Text = self._text;
						TextColor3 = Color3.new(1, 1, 1);
						TextScaled = true;
						TextTransparency = transparency;

						[Blend.Children] = {
							Blend.New "UITextSizeConstraint" {
								MaxTextSize = 15;
							};
						};
					};
				};
			};
		};
	};
end

return VisualizerControlButton
