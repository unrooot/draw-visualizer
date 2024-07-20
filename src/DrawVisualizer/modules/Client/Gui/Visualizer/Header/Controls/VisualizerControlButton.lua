local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local ButtonHighlightModel = require("ButtonHighlightModel")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local VisualizerControlButton = setmetatable({}, BasicPane)
VisualizerControlButton.ClassName = "VisualizerControlButton"
VisualizerControlButton.__index = VisualizerControlButton

function VisualizerControlButton.new(buttonName: string)
	local self = setmetatable(BasicPane.new(), VisualizerControlButton)

	self.ButtonName = assert(buttonName, "[VisualizerControlButton]: Must provide a button name!")

	self.Activated = self._maid:Add(Signal.new())

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._isChoosen = self._maid:Add(ValueObject.new(false))

	self._maid:GiveTask(self._isChoosen.Changed:Connect(function()
		self._buttonModel:SetIsChoosen(self._isChoosen.Value)
	end))

	self._text = self._maid:Add(ValueObject.new(""))

	self._layoutOrder = self._maid:Add(ValueObject.new(1))

	self._buttonModel = self._maid:Add(ButtonHighlightModel.new())

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

	local percentHighlighted = Blend.Computed(self._buttonModel:ObservePercentHighlighted(), function(percent)
		return percent
	end);

	local percentPressed = Blend.Computed(self._buttonModel:ObservePercentPressed(), function(percent)
		return percent
	end);

	local percentChosen = Blend.Computed(self._buttonModel:ObservePercentChoosen(), function(percent)
		return percent
	end);

	local baseColor = Color3.fromRGB(65, 65, 65)

	return Blend.New "Frame" {
		Name = "VisualizerControlButton";
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

				BackgroundColor3 = Blend.Computed(percentHighlighted, percentChosen, percentPressed, function(percentHighlight, percentChose, percentPress)
					local percent = percentHighlight + percentChose + (percentPress * 0.5)

					return baseColor:Lerp(Color3.fromRGB(90, 90, 90), percent);
				end);

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(0.5, 0.5 + percent)
				end);

				[Blend.Children] = {
					Blend.New "TextLabel" {
						Name = "label";
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Medium, Enum.FontStyle.Normal);
						Position = UDim2.fromScale(0.5, 0.5);
						Text = self._text;
						TextScaled = true;
						TextTransparency = transparency;

						Size = Blend.Computed(self._text, function(text)
							-- @TODO: maybe dont do this
							-- hacky way to make the text scale at the same
							-- proportion... slightly cursed, probably will
							-- break when localized
							if text == "view properties" then
								return UDim2.fromScale(0.8, 0.35);
							else
								return UDim2.fromScale(0.693, 0.35);
							end
						end);

						TextColor3 = Blend.Computed(self._text, props.RootInstance, function(text, instance)
							if text == "choose target" then
								return Color3.new(1, 1, 1)
							end

							if instance then
								return Color3.new(1, 1, 1)
							else
								return Color3.fromRGB(100, 100, 100)
							end
						end);

						[Blend.Children] = {
							Blend.New "UITextSizeConstraint" {
								MaxTextSize = 13;
							};
						};
					};
				};
			};
		};
	};
end

return VisualizerControlButton
