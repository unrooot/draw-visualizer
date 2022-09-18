local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Rx = require("Rx")
local Table = require("Table")
local UIPaddingUtils = require("UIPaddingUtils")
local ValueObject = require("ValueObject")

local VisualizerListView = setmetatable({}, BasicPane)
VisualizerListView.ClassName = "VisualizerListView"
VisualizerListView.__index = VisualizerListView

function VisualizerListView.new()
	local self = setmetatable(BasicPane.new(), VisualizerListView)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._contentHeight = ValueObject.new(0)
	self._maid:GiveTask(self._contentHeight)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._groups = {}
	self._groupMap = {}

	self._groupObjects = ValueObject.new(Table.copy(self._groupMap))
	self._maid:GiveTask(self._groupObjects)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerListView:AddInstanceGroup(instanceGroup)
	if not instanceGroup then
		return
	end

	table.insert(self._groups, instanceGroup)
	instanceGroup:SetLayoutOrder(#self._groups)

	self._maid[instanceGroup] = instanceGroup
	self._groupMap[instanceGroup] = true
	self._groupObjects.Value = Table.copy(self._groupMap)

	if self:IsVisible() then
		instanceGroup:Show()
	end
end

function VisualizerListView:RemoveInstanceGroup(instanceGroup)
	if not instanceGroup then
		return
	end

	local index = table.find(self._groups, instanceGroup)
	if index then
		table.remove(self._groups, index)
	end

	self._groupMap[instanceGroup] = nil
	self._maid[instanceGroup] = nil
	self._groupObjects.Value = Table.copy(self._groupMap)
end

function VisualizerListView:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.5)

	local transparency = Blend.Computed(percentVisible, function(percent)
		local itemCount = math.max(1, #self._groups)

		for index, group in ipairs(self._groups) do
			local progress = (index - 1) / itemCount + 1e-1
			group:SetVisible(progress <= percent)
		end

		return 1 - percent
	end)

	local rootSize = props.AbsoluteRootSize
	local scrollBarImage = "rbxasset://textures/ui/Scroll/scroll-middle.png"

	return Blend.New "Frame" {
		Name = "list";
		BackgroundTransparency = 1;
		Parent = props.Parent;

		Size = Blend.Computed(rootSize, function(size: Vector2)
			return UDim2.fromScale(1, (size.Y - 75) / size.Y)
		end);

		Position = Blend.Computed(rootSize, function(size: Vector2)
			return UDim2.fromScale(0, 75 / size.Y)
		end);

		[Blend.OnChange "AbsoluteSize"] = function(size: Vector2)
			self._absoluteSize.Value = size
		end;

		[Blend.Children] = {
			Blend.New "ScrollingFrame" {
				Name = "contents";
				BackgroundTransparency = 1;
				BottomImage = scrollBarImage;
				MidImage = scrollBarImage;
				ScrollBarImageTransparency = transparency;
				ScrollBarThickness = 10;
				ScrollingDirection = Enum.ScrollingDirection.Y;
				Size = UDim2.fromScale(1, 1);
				TopImage = scrollBarImage;
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar;

				[Blend.Instance] = function(contents)
					self.Contents = contents
				end;

				CanvasSize = Blend.Computed(self._contentHeight, function(height: number)
					return UDim2.fromOffset(0, height)
				end);

				[Blend.Children] = {
					Blend.New "UIPadding" {
						PaddingLeft = UDim.new(0, 15);
						PaddingTop = UDim.new(0, 15);
						PaddingBottom = UDim.new(0, 15);

						PaddingRight = Blend.Computed(self._contentHeight, function(height: number)
							local size = self._absoluteSize.Value

							if height > size.Y then
								return UDim.new(15 / size.X, 0)
							else
								return UDim.new(0, 15)
							end
						end);
					};

					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						SortOrder = Enum.SortOrder.LayoutOrder;
						VerticalAlignment = Enum.VerticalAlignment.Top;

						[Blend.OnChange "AbsoluteContentSize"] = function(contentSize)
							self._contentHeight.Value = contentSize.Y
						end;

						Padding = Blend.Computed(self._absoluteSize, self._contentHeight, function(size: Vector2, height: number)
							if height < size.Y then
								return UDim.new(15 / size.Y, 0)
							else
								return UDim.new(15 / height, 0)
							end
						end);
					};


					Blend.ComputedPairs(self._groupObjects, function(group)
						return group:Render({
							Parent = props.Parent;
						})
					end);
				};
			};
		};
	};
end

return VisualizerListView
