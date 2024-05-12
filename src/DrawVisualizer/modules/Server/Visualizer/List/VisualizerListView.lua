local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local Maid = require("Maid")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local Signal = require("Signal")
local Table = require("Table")
local ValueObject = require("ValueObject")
local VisualizerInstanceGroup = require("VisualizerInstanceGroup")

local VisualizerListView = setmetatable({}, BasicPane)
VisualizerListView.ClassName = "VisualizerListView"
VisualizerListView.__index = VisualizerListView

function VisualizerListView.new()
	local self = setmetatable(BasicPane.new(), VisualizerListView)

	self._groups = {}
	self._groupMap = {}

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))

	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.new()))
	self._contentHeight = self._maid:Add(ValueObject.new(0))
	self._currentGroup = self._maid:Add(ValueObject.new())
	self._groupObjects = self._maid:Add(ValueObject.new(Table.copy(self._groupMap)))

	self.InstanceHovered = self._maid:Add(Signal.new())
	self.InstancePicked = self._maid:Add(Signal.new())
	self.InstanceInspected = self._maid:Add(Signal.new())

	self._maid:GiveTask(self._currentGroup:Observe():Subscribe(function()
		--
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerListView:AddInstanceGroup(instanceGroup)
	if not instanceGroup then
		return
	end

	local maid = Maid.new()

	maid:GiveTask(instanceGroup)

	maid:GiveTask(instanceGroup.InstancePicked:Connect(function(instance: Instance?)
		self.InstancePicked:Fire(instance)
	end))

	maid:GiveTask(instanceGroup.InstanceInspected:Connect(function(instance: Instance?)
		self.InstanceInspected:Fire(instance)
	end))

	maid:GiveTask(instanceGroup.InstanceHovered:Connect(function(instance: Instance?)
		self.InstanceHovered:Fire(instance)
	end))

	table.insert(self._groups, instanceGroup)
	instanceGroup:SetLayoutOrder(#self._groups)

	self._maid[instanceGroup] = maid
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
		Name = "VisualizerListView";
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
				ScrollingEnabled = BasicPaneUtils.observeVisible(self);
				Size = UDim2.fromScale(1, 1);
				TopImage = scrollBarImage;
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar;

				[Blend.Instance] = function(contents)
					self.Contents = contents
				end;

				CanvasSize = Blend.Computed(self._contentHeight, function(height: number)
					return UDim2.fromOffset(0, height + 30)
				end);

				[Blend.Children] = {
					Blend.New "UIPadding" {
						PaddingLeft = UDim.new(0, 10);
						PaddingTop = UDim.new(0, 10);
						PaddingBottom = UDim.new(0, 10);

						PaddingRight = Blend.Computed(self._contentHeight, function(height: number)
							local size = self._absoluteSize.Value

							if height > size.Y then
								return UDim.new(10 / size.X, 0)
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

					props.RootInstance:ObserveBrio():Pipe({
						RxBrioUtils.map(function(instance)
							if not instance then
								if self._currentGroup then
									self._currentGroup:Destroy()
									self._currentGroup = nil
								end

								return
							end

							local depth = 0
							local group
							local createdGroup = false

							if self._currentGroup then
								local currentRoot = self._currentGroup:GetRootInstance()

								depth = self._currentGroup.StartingDepth

								if currentRoot then
									if currentRoot:IsDescendantOf(instance) then
										depth += 1

										self._currentGroup:IncrementDepth()

										group = VisualizerInstanceGroup.new(instance, depth - 1)
										group:AddObject(self._currentGroup, depth)
										group:SetRootInstance(instance)
										createdGroup = true
									else
										self._currentGroup:Destroy()
									end
								end
							end

							if not group then
								group = VisualizerInstanceGroup.new(instance)
								group:SetRootInstance(instance)
								createdGroup = true
							end

							if createdGroup then
								local maid = group._maid

								maid:GiveTask(group.InstancePicked:Connect(function(pickedInstance: Instance?)
									self.InstancePicked:Fire(pickedInstance)
								end))

								maid:GiveTask(group.InstanceInspected:Connect(function(inspectedInstance: Instance?)
									self.InstanceInspected:Fire(inspectedInstance)
								end))

								maid:GiveTask(group.InstanceHovered:Connect(function(hoverInstance: Instance?)
									self.InstanceHovered:Fire(hoverInstance)
								end))
							end

							self._currentGroup = group

							if self:IsVisible() then
								group:Show()
							end

							return group:Render({
								RootInstance = instance;
								Parent = props.Parent;
							})
						end);
					});

					-- Blend.ComputedPairs(self._groupObjects, function(group)
					-- 	return group:Render({
					-- 		Parent = props.Parent;
					-- 	})
					-- end);
				};
			};
		};
	};
end

return VisualizerListView
