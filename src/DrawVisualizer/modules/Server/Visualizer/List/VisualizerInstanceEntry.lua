local require = require(script.Parent.loader).load(script)

local StudioService = game:GetService("StudioService")
local UserInputService = game:GetService("UserInputService")

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local Brio = require("Brio")
local ButtonHighlightModel = require("ButtonHighlightModel")
local Observable = require("Observable")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local INDENTATION_WIDTH = 30

local VisualizerInstanceEntry = setmetatable({}, BasicPane)
VisualizerInstanceEntry.ClassName = "VisualizerInstanceEntry"
VisualizerInstanceEntry.__index = VisualizerInstanceEntry

function VisualizerInstanceEntry.new()
	local self = setmetatable(BasicPane.new(), VisualizerInstanceEntry)

	self._percentCollapsedTarget = self._maid:Add(ValueObject.new(1))
	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self.Instance = self._maid:Add(ValueObject.new(nil))
	self.IsRootInstance = self._maid:Add(ValueObject.new(false))

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.new()))
	self._className = self._maid:Add(ValueObject.new(""))
	self._depth = self._maid:Add(ValueObject.new(0))
	self._descendantCount = self._maid:Add(ValueObject.new(0))
	self._iconData = self._maid:Add(ValueObject.new({}))
	self._isCollapsed = self._maid:Add(ValueObject.new(true))
	self._layoutOrder = self._maid:Add(ValueObject.new(0))

	self._maid:GiveTask(self._isCollapsed.Changed:Connect(function()
		self._percentCollapsedTarget.Value = self._isCollapsed.Value and 1 or 0
	end))

	self._maid:GiveTask(self._className.Changed:Connect(function()
		self._iconData.Value = StudioService:GetClassIcon(self._className.Value)
	end))

	self.Activated = self._maid:Add(Signal.new())
	self.InstanceHovered = self._maid:Add(Signal.new())
	self.InstanceInspected = self._maid:Add(Signal.new())
	self.InstancePicked = self._maid:Add(Signal.new())

	self._buttonModel = ButtonHighlightModel.new()

	self._maid:GiveTask(self._buttonModel:ObserveIsHighlighted():Subscribe(function(isHighlighted)
		if not isHighlighted then
			self:SetIsPressed(false)
		end

		self.InstanceHovered:Fire(isHighlighted)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerInstanceEntry:GetDepth()
	return self._depth.Value
end

function VisualizerInstanceEntry:SetDepth(depth: number)
	self._depth.Value = depth
end

function VisualizerInstanceEntry:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
end

function VisualizerInstanceEntry:SetCollapsed(isCollapsed: boolean)
	self._isCollapsed.Value = isCollapsed
end

function VisualizerInstanceEntry:SetInstance(instance: Instance)
	self.Instance.Value = instance
end

function VisualizerInstanceEntry:SetIsPressed(isPressed: boolean)
	self._buttonModel:SetKeyDown(isPressed)
end

function VisualizerInstanceEntry:SetIsHighlighted(isHighlighted: boolean)
	self._buttonModel._isHighlighted.Value = isHighlighted
end

function VisualizerInstanceEntry:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 1)

	local percentCollapsed = Blend.Spring(Blend.toPropertyObservable(self._percentCollapsedTarget):Pipe({
		Rx.startWith({1})
	}), 40, 0.9)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	local percentHighlighted = self._buttonModel:ObservePercentHighlighted()
	local percentPressed = Blend.Spring(self._buttonModel:ObservePercentPressedTarget(), 50, 0.8);

	local instanceData = self.Instance:Observe():Pipe({
		Rx.where(function(instance)
			return instance ~= nil
		end);

		Rx.switchMap(function(instance)
			local function getDescendantCount()
				return #instance:GetDescendants()
			end

			return Rx.combineLatest({
				AbsoluteSize = instance:IsA("GuiObject") and RxInstanceUtils.observeProperty(instance, "AbsoluteSize") or nil;
				ClassName = Rx.of(instance.ClassName);
				Name = RxInstanceUtils.observeProperty(instance, "Name");
				DescendantCount = Rx.merge({
					Rx.of(getDescendantCount());
					Rx.fromSignal(instance.DescendantAdded):Pipe({
						Rx.map(getDescendantCount);
					});
					Rx.fromSignal(instance.DescendantRemoving):Pipe({
						Rx.map(function()
							return getDescendantCount() - 1
						end)
					});
				});
			})
		end)
	})

	return Blend.New "Frame" {
		Name = "VisualizerInstanceEntry";
		BackgroundTransparency = 1;
		Size = UDim2.new(1, 0, 0, 30);
		Parent = props.Parent;

		LayoutOrder = Blend.Computed(self._layoutOrder, function(layoutOrder)
			return layoutOrder
		end);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
			Blend.New "ImageLabel" {
				Name = "guides";
				AnchorPoint = Vector2.new(0, 0.5);
				BackgroundTransparency = 1;
				Image = "rbxassetid://17499672765";
				ImageColor3 = Color3.fromRGB(255, 255, 255);
				Size = UDim2.new(0, 13, 1, 0);
				ZIndex = 1;

				ImageTransparency = Blend.Computed(transparency, function(percent)
					return 0.95 + percent
				end);

				Position = Blend.Computed(self._depth, function(depth: number)
					return UDim2.new(0, ((depth - 1) * INDENTATION_WIDTH) + 22, 0.5, 0);
				end);

				Visible = Blend.Computed(self._depth, function(depth: number)
					return depth ~= 0
				end);
			};

			Blend.New "Frame" {
				Name = "wrapper";
				AnchorPoint = Vector2.new(0.5, 0.5);
				BackgroundTransparency = 1;
				Position = UDim2.fromScale(0.5, 0.5);
				Size = UDim2.new(1, -10, 1, 0);
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
										return UDim.new(((depth * INDENTATION_WIDTH) / absoluteSize.X) + (10 / absoluteSize.X), 0)
									else
										return UDim.new(10 / absoluteSize.X, 0)
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
									return data.Image or ""
								end);

								ImageRectOffset = Blend.Computed(self._iconData, function(data)
									return data.ImageRectOffset or Vector2.new()
								end);

								ImageRectSize = Blend.Computed(self._iconData, function(data)
									return data.ImageRectSize or Vector2.new()
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
								AutomaticSize = Enum.AutomaticSize.X;
								BackgroundTransparency = 1;
								FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json");
								LayoutOrder = 2;
								TextSize = 16;
								RichText = true;
								Size = UDim2.fromScale(0, 1);
								TextTransparency = transparency;
								TextXAlignment = Enum.TextXAlignment.Left;

								Text = Blend.Computed(instanceData, function(data)
									local name = data.Name
									local descendantCount = data.DescendantCount
									local absoluteSize = data.AbsoluteSize

									local text = `<b>{name}</b>`

									if descendantCount and descendantCount > 0 then
										text = `<font family="rbxassetid://16658246179" color="#707070">({descendantCount})</font> ` .. text
									end

									if absoluteSize then
										local x, y = math.round(absoluteSize.X), math.round(absoluteSize.Y)
										text ..= ` <font color="#c59cf2" family="rbxassetid://16658246179" size="14">[{x} x {y}]</font>`
									end

									self._className.Value = data.ClassName
									self._descendantCount.Value = descendantCount

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
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						Position = UDim2.fromScale(0.5, 0.5);
						Size = UDim2.new(1, 10, 1, 0);
						Text = "";
						Visible = BasicPaneUtils.observeVisible(self);
						ZIndex = 5;

						[Blend.OnEvent "InputBegan"] = function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								local ctrlPressed = false

								for _, inputObject in UserInputService:GetKeysPressed() do
									if inputObject.KeyCode == Enum.KeyCode.LeftControl then
										ctrlPressed = true
									end
								end

								self.Activated:Fire(ctrlPressed)
							elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
								self.InstanceInspected:Fire(self.Instance.Value)
							elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
								self.InstancePicked:Fire(self.Instance.Value)
							end
						end;

						[Blend.Instance] = function(button)
							self._buttonModel:SetButton(button)
						end;
					};

					Blend.New "ImageLabel" {
						Name = "dropdown";
						AnchorPoint = Vector2.new(1, 0.5);
						BackgroundTransparency = 1;
						Image = "rbxassetid://6031091004";
						ImageColor3 = Color3.new(1, 1, 1);
						Position = UDim2.fromScale(1, 0.5);
						Size = UDim2.fromScale(1, 1);
						ZIndex = 5;

						ImageTransparency = Blend.Computed(transparency, percentCollapsed, percentHighlighted, function(percent, percentCollapse, percentHighlight)
							return 0.7 - ((1 - percentCollapse) * 0.4) - (percentHighlight * 0.3) + percent
						end);

						Rotation = Blend.Computed(percentCollapsed, function(percent: number)
							return percent * 180
						end);

						Visible = Blend.Computed(self._descendantCount, function(count: number)
							return count > 0
						end);

						[Blend.Children] = {
							Blend.New "UIAspectRatioConstraint" {
								AspectRatio = 1;
							};
						};
					};
				};
			};

			Blend.New "Frame" {
				Name = "tab";
				AnchorPoint = Vector2.new(0, 0.5);
				BackgroundColor3 = Color3.fromRGB(200, 200, 200);
				Position = UDim2.fromScale(0, 0.5);

				BackgroundTransparency = Blend.Computed(
					transparency,
					percentHighlighted,
					percentCollapsed,
					self._descendantCount,
					function(percent, percentHighlight, percentCollapse, count)
						if count == 0 then
							return 1
						end

						return 0.85 - (percentHighlight * 0.65) - ((1 - percentCollapse) * 0.2) + percent
					end
				);

				Size = Blend.Computed(percentHighlighted, percentPressed, function(percentHighlight, percentPress)
					return UDim2.new(0, 5 + (percentHighlight * 2) - (percentPress * 4), 1, 0);
				end);
			};

			Blend.New "Frame" {
				Name = "backing";
				AnchorPoint = Vector2.new(0.5, 0.5);
				Position = UDim2.fromScale(0.5, 0.5);
				Size = UDim2.fromScale(1, 1);
				ZIndex = 2;

				BackgroundTransparency = Blend.Computed(percentHighlighted, function(percent)
					return 1 - (0.1 * percent)
				end);
			};
		};
	};
end

return VisualizerInstanceEntry
