local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Rx = require("Rx")
local UIPaddingUtils = require("UIPaddingUtils")
local ValueObject = require("ValueObject")
local VisualizerControls = require("VisualizerControls")

local VisualizerHeader = setmetatable({}, BasicPane)
VisualizerHeader.ClassName = "VisualizerHeader"
VisualizerHeader.__index = VisualizerHeader

function VisualizerHeader.new()
	local self = setmetatable(BasicPane.new(), VisualizerHeader)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._buttons = VisualizerControls.new()
	self._maid:GiveTask(self._buttons)

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

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "header";
		BackgroundTransparency = 1;
		LayoutOrder = 1;

		Size = Blend.Computed(props.AbsoluteRootSize, function(size)
			return UDim2.fromScale(1, 75 / size.Y)
		end);

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "title";
				BackgroundColor3 = Color3.fromRGB(197, 156, 242);
				BackgroundTransparency = transparency;
				Size = UDim2.fromScale(1, 0.333);

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(-percent, 0)
				end);

				[Blend.Children] = {
					UIPaddingUtils.fromUDim(UDim.new(0, 5));

					Blend.New "TextLabel" {
						Name = "label";
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						Font = Enum.Font.GothamBold;
						Position = UDim2.fromScale(0.5, 0.5);
						Size = UDim2.fromScale(1, 1);
						Text = "draw visualizer";
						TextColor3 = Color3.new(1, 1, 1);
						TextScaled = true;
						TextTransparency = transparency;

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
				Parent = props.Parent;
			})
		};
	};
end

return VisualizerHeader

