local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local LuvColor3Utils = require("LuvColor3Utils")
local Rx = require("Rx")
local UIPaddingUtils = require("UIPaddingUtils")
local ValueObject = require("ValueObject")
local VisualizerControls = require("VisualizerControls")

local VisualizerHeader = setmetatable({}, BasicPane)
VisualizerHeader.ClassName = "VisualizerHeader"
VisualizerHeader.__index = VisualizerHeader

function VisualizerHeader.new()
	local self = setmetatable(BasicPane.new(), VisualizerHeader)

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._buttons = self._maid:Add(VisualizerControls.new())

	self.ButtonActivated = self._buttons.ButtonActivated

	self._focusedColor = Color3.fromRGB(197, 156, 242)
	self._inactiveColor = Color3.fromRGB(150, 150, 150)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
		self._buttons:SetVisible(isVisible, doNotAnimate)
	end))

	return self
end

function VisualizerHeader:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.9)

	local percentAlpha = Blend.AccelTween(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 400)

	local percentFocused = Blend.AccelTween(Blend.toPropertyObservable(props.IsFocused):Pipe({
		Rx.map(function(isFocused)
			return isFocused and 1 or 0
		end)
	}), 400)

	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	local backgroundColor = Blend.Computed(percentFocused, function(percent)
		return LuvColor3Utils.lerp(self._inactiveColor, self._focusedColor, percent)
	end)

	return Blend.New "Frame" {
		Name = "VisualizerHeader";
		BackgroundTransparency = 1;
		LayoutOrder = 1;

		Size = Blend.Computed(props.AbsoluteRootSize, function(size)
			return UDim2.fromScale(1, 75 / size.Y)
		end);

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "title";
				BackgroundTransparency = transparency;
				Size = UDim2.fromScale(1, 0.333);

				BackgroundColor3 = backgroundColor;

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(-percent, 0)
				end);

				[Blend.Children] = {
					UIPaddingUtils.fromUDim(UDim.new(0, 5));

					Blend.New "TextLabel" {
						Name = "label";
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal);
						Position = UDim2.fromScale(0.5, 0.5);
						Size = UDim2.fromScale(1, 1);
						Text = "draw visualizer";
						TextScaled = true;
						TextTransparency = transparency;

						TextColor3 = Blend.Computed(percentFocused, backgroundColor, function(percent, color)
							return LuvColor3Utils.darken(color, 0.75 - ((1 - percent) * 0.35))
						end);

						[Blend.Children] = {
							Blend.New "UITextSizeConstraint" {
								MaxTextSize = 25;
							};
						};
					};
				};
			};

			self._buttons:Render({
				AbsoluteRootSize = props.AbsoluteRootSize;
				RootInstance = props.RootInstance;
				Parent = props.Parent;
			})
		};
	};
end

return VisualizerHeader

