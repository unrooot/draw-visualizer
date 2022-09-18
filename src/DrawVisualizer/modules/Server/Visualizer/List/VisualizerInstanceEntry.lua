local require = require(script.Parent.loader).load(script)

local StudioService = game:GetService("StudioService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local ButtonHighlightModel = require("ButtonHighlightModel")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local VisualizerInstanceEntry = setmetatable({}, BasicPane)
VisualizerInstanceEntry.ClassName = "VisualizerInstanceEntry"
VisualizerInstanceEntry.__index = VisualizerInstanceEntry

function VisualizerInstanceEntry.new()
	local self = setmetatable(BasicPane.new(), VisualizerInstanceEntry)

	self.IsRootInstance = ValueObject.new(false)
	self._maid:GiveTask(self.IsRootInstance)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._depth = ValueObject.new(0)
	self._maid:GiveTask(self._depth)

	self._childCount = ValueObject.new(0)
	self._maid:GiveTask(self._childCount)

	self._instanceName = ValueObject.new("")
	self._maid:GiveTask(self._instanceName)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._layoutOrder = ValueObject.new(0)
	self._maid:GiveTask(self._layoutOrder)

	self._className = ValueObject.new("")
	self._maid:GiveTask(self._className)
	self._maid:GiveTask(self._className.Changed:Connect(function()
		self._iconData.Value = StudioService:GetClassIcon(self._className.Value)
	end))

	self._iconData = ValueObject.new({})
	self._maid:GiveTask(self._iconData)

	self.Activated = Signal.new()
	self._maid:GiveTask(self.Activated)

	self._buttonModel = ButtonHighlightModel.new()
	self._maid:GiveTask(self._buttonModel)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerInstanceEntry:SetDepth(depth: number)
	self._depth.Value = depth
end

function VisualizerInstanceEntry:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
end

function VisualizerInstanceEntry:SetInstance(instance: Instance)
	self._instance = instance

	self._className.Value = instance.ClassName
	self._instanceName.Value = instance.Name
	self._childCount.Value = #instance:GetDescendants()

	if instance:IsA("GuiObject") then
		self._absoluteSize.Value = instance.AbsoluteSize
	end
end

function VisualizerInstanceEntry:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 1)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "InstanceEntry";
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 0, 30);
		Parent = props.Parent;

		LayoutOrder = Blend.Computed(self._layoutOrder, function(layoutOrder)
			return layoutOrder
		end);

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "wrapper";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);
				ZIndex = 3;

				[Blend.Children] = {
					Blend.New "Frame" {
						BackgroundTransparency = 1;
						Name = "container";
						Size = UDim2.fromScale(1, 1);

						[Blend.Children] = {
							Blend.New "UIListLayout" {
								FillDirection = Enum.FillDirection.Horizontal;
								HorizontalAlignment = Enum.HorizontalAlignment.Left;
								Padding = UDim.new(0, 5);
								SortOrder = Enum.SortOrder.LayoutOrder;
								VerticalAlignment = Enum.VerticalAlignment.Center;
							};

							Blend.New "UIPadding" {
								PaddingLeft = Blend.Computed(self._depth, self._absoluteSize, function(depth: number, absoluteSize: Vector2)
									if depth > 0 then
									return UDim.new((depth * 30) / absoluteSize.X, 0)
									else
										return UDim.new()
									end
								end);
							};

							Blend.New "ImageLabel" {
								Name = "icon";
								BackgroundTransparency = 1;
								ImageTransparency = transparency;
								LayoutOrder = 1;
								ScaleType = Enum.ScaleType.Slice;
								Size = UDim2.fromScale(1, 1);
								SliceCenter = Rect.new(0, 0, 16, 16);

								Image = Blend.Computed(self._iconData, function(data)
									return data.Image
								end);

								ImageRectOffset = Blend.Computed(self._iconData, function(data)
									return data.ImageRectOffset
								end);

								ImageRectSize = Blend.Computed(self._iconData, function(data)
									return data.ImageRectSize
								end);

								[Blend.Children] = {
									Blend.New "UIAspectRatioConstraint" {
										AspectRatio = 1;
									};

									Blend.New "UISizeConstraint" {
										MaxSize = Vector2.new(16, 16);
									};
								};
							};

							Blend.New "TextLabel" {
								Name = "label";
								BackgroundTransparency = 1;
								LayoutOrder = 2;
								RichText = true;
								Size = UDim2.fromScale(0.941, 1);
								TextScaled = true;
								TextTransparency = transparency;
								TextXAlignment = Enum.TextXAlignment.Left;

								Text = Blend.Computed(self._childCount, self._instanceName, self._absoluteSize, function(childCount, name, absoluteSize)
									local text = string.format("<font face=\"Gotham\" weight=\"Bold\">%s</font>", name)

									if childCount > 0 then
										text = string.format("<font color=\"#c8c8c8\">(%d)</font> ", childCount) .. text
									end

									if self._instance:IsA("GuiObject") then
										text ..= string.format(" <font color=\"#c59cf2\">[%d x %d]</font>", absoluteSize.X, absoluteSize.Y)
									end

									return text
								end);

								TextColor3 = Blend.Computed(self.IsRootInstance, function(isRootInstance)
									return isRootInstance and Color3.fromRGB(200, 200, 200) or Color3.fromRGB(175, 175, 175)
								end);

								[Blend.Children] = {
									Blend.New "UITextSizeConstraint" {
										MaxTextSize = 16;
									};
								};
							};
						};
					};

					Blend.New "TextButton" {
						Name = "button";
						BackgroundTransparency = 1;
						Size = UDim2.fromScale(0.96, 1);
						Text = "";
						ZIndex = 5;

						[Blend.OnEvent "Activated"] = function()
							self.Activated:Fire(self._instanceName.Value)
						end;

						[Blend.Instance] = function(button)
							self._buttonModel:SetButton(button)
						end;
					};

					Blend.New "ImageButton" {
						Name = "dropdown";
						AnchorPoint = Vector2.new(1, 0.5);
						BackgroundTransparency = 0.5;
						ImageTransparency = transparency;
						Position = UDim2.fromScale(1, 0.5);
						Size = UDim2.fromScale(1, 1);
						ZIndex = 5;

						[Blend.Children] = {
							Blend.New "UIAspectRatioConstraint" {
								AspectRatio = 1;
							};
						};
					};
				};
			};

			Blend.New "Frame" {
				Name = "backing";
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				Size = UDim2.new(1, 10, 1, 10);
				ZIndex = 1;

				BackgroundTransparency = Blend.Computed(self._buttonModel:ObservePercentHighlighted(), function(percent)
					return 1 - (0.15 * percent)
				end);
			};
		};
	};
end

return VisualizerInstanceEntry
