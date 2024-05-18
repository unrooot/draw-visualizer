local require = require(script.Parent.loader).load(script)

local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Brio = require("Brio")
local Maid = require("Maid")
local Math = require("Math")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local Table = require("Table")
local ValueObject = require("ValueObject")
local VisualizerConstants = require("VisualizerConstants")
local VisualizerInstanceEntry = require("VisualizerInstanceEntry")

local MAX_INSTANCE_DEPTH = VisualizerConstants.MAX_INSTANCE_DEPTH

local VisualizerInstanceGroup = setmetatable({}, BasicPane)
VisualizerInstanceGroup.ClassName = "VisualizerInstanceGroup"
VisualizerInstanceGroup.__index = VisualizerInstanceGroup

function VisualizerInstanceGroup.new(rootInstance: Instance, startingDepth: number?)
	local self = setmetatable(BasicPane.new(), VisualizerInstanceGroup)

	assert(rootInstance, "[VisualizerInstanceGroup]: Must provide a root instance!")

	self._instances = {}
	self._instanceMap = {}

	self.StartingDepth = self._maid:Add(ValueObject.new(startingDepth and startingDepth or 0))

	self._rootInstance = self._maid:Add(ValueObject.new(rootInstance))
	self._instanceEntries = self._maid:Add(ValueObject.new(Table.copy(self._instanceMap)))
	self._layoutOrder = self._maid:Add(ValueObject.new(0))
	self._absoluteSize = self._maid:Add(ValueObject.new(Vector2.new()))
	self._contentSize = self._maid:Add(ValueObject.new(Vector2.new()))
	self._isHovered = self._maid:Add(ValueObject.new(false))

	self._percentVisibleTarget = self._maid:Add(ValueObject.new(0))
	self._percentCollapsedTarget = self._maid:Add(ValueObject.new(1))

	self._maid._groups = Maid.new()

	self._collapsed = self._maid:Add(ValueObject.new(true))
	self._maid:GiveTask(self._collapsed.Changed:Connect(function()
		self._percentCollapsedTarget.Value = self._collapsed.Value and 1 or 0
	end))

	self.InstanceHovered = self._maid:Add(Signal.new())
	self.InstancePicked = self._maid:Add(Signal.new())
	self.InstanceInspected = self._maid:Add(Signal.new())

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerInstanceGroup:GetRootInstance()
	return self._rootInstance.Value
end

function VisualizerInstanceGroup:AddObject(instanceEntry, depth: number)
	if not instanceEntry then
		return warn("[VisualizerInstanceGroup]: Must provide an instance group or entry!")
	end

	local className = instanceEntry.ClassName
	local instance = instanceEntry.Instance
	local layoutOrder

	if instance then
		instance = instance.Value
	end

	if self._maid[instance] then
		return
	end

	if className == self.ClassName then
		local depthBrio = self:_getBrioFromDepth(depth)

		if depthBrio:IsDead() then
			return
		end

		local groupCount = 0
		local groups = depthBrio:GetValue()

		instance = instanceEntry:GetRootInstance()

		groups.Value[instance] = instanceEntry

		for _ in groups do
			groupCount += 1
		end

		layoutOrder = groupCount
	end

	table.insert(self._instances, instanceEntry)
	instanceEntry:SetLayoutOrder(#self._instances)

	if instance == self._rootInstance.Value then
		layoutOrder = -1
	elseif instance:IsA("UIComponent") then
		layoutOrder = 0
	elseif not layoutOrder then
		layoutOrder = #self._instances
	end

	instanceEntry:SetLayoutOrder(layoutOrder)

	local maid = Maid.new()
	maid:GiveTask(instanceEntry)

	if className == "VisualizerInstanceEntry" then
		maid:GiveTask(instanceEntry.InstancePicked:Connect(function(pickedInstance)
			self.InstancePicked:Fire(pickedInstance)
		end))

		maid:GiveTask(instanceEntry.InstanceInspected:Connect(function(inspectedInstance)
			self.InstanceInspected:Fire(inspectedInstance)
		end))

		maid:GiveTask(instanceEntry:ObserveHovered():Subscribe(function(isHovered)
			if not isHovered then
				if self._hoverTarget and self._hoverTarget == instanceEntry then
					self._isHovered.Value = false
				end

				return
			end

			self._hoverTarget = instanceEntry

			for _, inputObject in UserInputService:GetKeysPressed() do
				if inputObject.KeyCode == Enum.KeyCode.LeftControl then
					Selection:Set({instance})
				end
			end

			self._isHovered.Value = isHovered
			self.InstanceHovered:Fire(isHovered and instance or nil)
		end))

		maid:GiveTask(instanceEntry.Activated:Connect(function(ctrlPressed: boolean)
			instance = instanceEntry.Instance.Value
			if not instance then
				return
			end

			if ctrlPressed then
				Selection:Set({instance})
				return
			end

			if #instance:GetChildren() > 0 then
				self._collapsed.Value = not self._collapsed.Value
				instanceEntry:SetCollapsed(self._collapsed.Value)
			end
		end))
	end

	self._maid[instance] = maid
	self._instanceMap[instanceEntry] = true
	self._instanceEntries.Value = Table.copy(self._instanceMap)

	if className == "VisualizerInstanceEntry" then
		instanceEntry.IsRootInstance.Value = instanceEntry == self._rootInstance.Value
		instanceEntry:SetDepth(depth)
	end

	return
end

function VisualizerInstanceGroup:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
end

function VisualizerInstanceGroup:_getBrioFromDepth(depth: number)
	if not depth or depth < 1 then
		return
	end

	if not self._maid._groups[depth] then
		self._maid._groups[depth] = Brio.new(ValueObject.new({}))
	end

	return self._maid._groups[depth]
end

function VisualizerInstanceGroup:_getGroupFromBrio(brio, instance: Instance, depth: number)
	if not instance then
		return self
	end

	if not brio or brio:IsDead() then
		return self
	end

	if #instance:GetChildren() == 0 then
		return self
	end

	local maid = Maid.new()
	local groups = brio:GetValue()
	local group = groups.Value[instance]

	if group then
		return group
	end

	group = VisualizerInstanceGroup.new(instance, depth)
	group:SetRootInstance(instance)

	groups.Value[instance] = group

	maid:GiveTask(group)

	maid:GiveTask(group.InstancePicked:Connect(function(pickedInstance: Instance?)
		self.InstancePicked:Fire(pickedInstance)
	end))

	maid:GiveTask(group.InstanceInspected:Connect(function(inspectedInstance: Instance?)
		self.InstanceInspected:Fire(inspectedInstance)
	end))

	maid:GiveTask(group.InstanceHovered:Connect(function(hoverInstance: Instance?)
		self.InstanceHovered:Fire(hoverInstance)
	end))

	brio:ToMaid():GiveTask(function()
		maid:Destroy()
	end)

	return group
end

function VisualizerInstanceGroup:_getDepth(baseInstance: Instance)
	local root = self._rootInstance.Value
	local parent = baseInstance
	local depth = self.StartingDepth.Value

	repeat
		if parent ~= root then
			depth += 1
		end

		parent = parent.Parent
	until
		parent == root or depth >= MAX_INSTANCE_DEPTH

	return depth
end

function VisualizerInstanceGroup:_createEntry(instance: Instance)
	assert(typeof(instance) == "Instance", "[VisualizerInstanceGroup]: Must provide an instance!")

	local entry = VisualizerInstanceEntry.new()
	entry:SetInstance(instance)

	return entry
end

function VisualizerInstanceGroup:IncrementDepth()
	self.StartingDepth.Value += 1

	for _, entry in self._instances do
		if entry.ClassName == "VisualizerInstanceEntry" then
			entry:SetDepth(entry:GetDepth() + 1)
		elseif entry.ClassName == "VisualizerInstanceGroup" then
			entry:IncrementDepth()
		end
	end
end

function VisualizerInstanceGroup:SetRootInstance(rootInstance)
	self._rootInstance.Value = rootInstance

	if not rootInstance then
		return
	end

	local descendantCount = #rootInstance:GetDescendants()

	if descendantCount >= MAX_INSTANCE_DEPTH then
		return warn(string.format("[VisualizerInstanceGroup]: Root instance exceeds max depth size (%d)!", descendantCount))
	end

	self._rootEntry = self:_createEntry(rootInstance)
	self:AddObject(self._rootEntry, self.StartingDepth.Value)

	self._maid:GiveTask(RxInstanceUtils.observeChildrenBrio(rootInstance, self._predicate)
		:Subscribe(function(brio)
			if brio:IsDead() then
				return
			end

			local instance = brio:GetValue()
			if not instance then
				return
			end

			if self._maid[instance] then
				return
			end

			local depth = self:_getDepth(instance)
			local depthBrio = self:_getBrioFromDepth(depth)
			local group = self:_getGroupFromBrio(depthBrio, instance, depth)

			local children = instance:GetChildren()

			if #children > 0 then
				if self ~= group then
					self:AddObject(group, depth)
				end
			else
				if not self._maid[instance] then
					group:AddObject(self:_createEntry(instance), depth)
				end
			end
		end))

	return
end

function VisualizerInstanceGroup._predicate(instance: Instance)
	return true
end

function VisualizerInstanceGroup:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.7)

	local percentCollapsed = Blend.Spring(Blend.toPropertyObservable(self._percentCollapsedTarget):Pipe({
		Rx.startWith({1})
	}), 30, 0.9)

	local transparency = Blend.Computed(percentVisible, function(percent)
		local itemCount = math.max(1, #self._instances)

		for index, entry in ipairs(self._instances) do
			local progress = (index - 1) / itemCount + 1e-2
			entry:SetVisible(progress <= percent)
		end

		return 1 - percent
	end)

	local groupStrokeTransparency = Blend.AccelTween(self._isHovered:Observe():Pipe({
		Rx.map(function(isHovered)
			return isHovered and 1 or 0
		end)
	}), 400)

	local rootInstanceHidden = self._rootInstance:Observe():Pipe({
		Rx.switchMap(function(instance)
			if not instance then
				return Rx.of(false)
			end

			local propertyName

			if instance:IsA("GuiObject") then
				propertyName = "Visible"
			elseif instance:IsA("UIStroke") or instance:IsA("UIGradient") then
				propertyName = "Enabled"
			end

			if not propertyName then
				return Rx.of(false)
			end

			return RxInstanceUtils.observeProperty(instance, propertyName):Pipe({
				Rx.map(function(visible)
					return not visible
				end);
			})
		end);
	});

	return Blend.New "Frame" {
		Name = "VisualizerInstanceGroup";
		Parent = props.Parent;

		BackgroundTransparency = Blend.Computed(groupStrokeTransparency, function(percent)
			return 1 - (percent * 0.04)
		end);

		BackgroundColor3 = Blend.Computed(rootInstanceHidden, function(isHidden)
			if isHidden then
				return Color3.new(0, 0, 0)
			else
				return Color3.new(1, 1, 1)
			end
		end);

		LayoutOrder = Blend.Computed(self._layoutOrder, function(layoutOrder)
			return layoutOrder
		end);

		Size = Blend.Computed(percentCollapsed, self._contentSize, function(percent: number, size: Vector2)
			return UDim2.new(1, 0, 0, Math.map(percent, 0, 1, 30, size.Y))
		end);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.OnEvent "InputBegan"] = function(input)
			if not self._isHovered.Value or not self._hoverTarget then
				return
			end

			if input.KeyCode == Enum.KeyCode.Space then
				self._rootEntry:SetIsPressed(true)
			elseif input.KeyCode == Enum.KeyCode.LeftShift then
				-- print(self.StartingDepth.Value)
			elseif input.KeyCode == Enum.KeyCode.LeftControl then
				Selection:Set({ self._hoverTarget.Instance.Value })
			elseif input.KeyCode == Enum.KeyCode.Tab then
				self.InstanceInspected:Fire(self._hoverTarget.Instance.Value)
			elseif input.KeyCode == Enum.KeyCode.V then
				self._hoverTarget:ToggleVisible()
			end
		end;

		[Blend.OnEvent "InputEnded"] = function(input)
			if not self._isHovered.Value then
				return
			end

			if input.KeyCode == Enum.KeyCode.Space then
				self._collapsed.Value = not self._collapsed.Value
				self._rootEntry:SetCollapsed(self._collapsed.Value)
				self._rootEntry:SetIsPressed(false)
			end
		end;

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "outline";
				AnchorPoint = Vector2.new(0.5, 0.5);
				BackgroundTransparency = 1;
				Position = UDim2.fromScale(0.5, 0.5);
				Size = UDim2.new(1, -6, 1, 0);

				Blend.New "UIStroke" {
					Thickness = 3;

					Color = Blend.Computed(rootInstanceHidden, function(isHidden)
						if isHidden then
							return Color3.new(0, 0, 0);
						else
							return Color3.new(1, 1, 1);
						end
					end);

					Transparency = Blend.Computed(groupStrokeTransparency, rootInstanceHidden, function(percent, isHidden)
						return 1 - (percent * (0.35 + (isHidden and 0.15 or 0)))
					end);
				};
			};

			Blend.New "Frame" {
				Name = "wrapper";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);

				ClipsDescendants = Blend.Computed(percentCollapsed, self._collapsed, function(percent: number)
					if percent < 0.98 then
						return true
					end

					return false
				end);

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(percent * -0.05, 0)
				end);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						Padding = UDim.new(0, 0);
						SortOrder = Enum.SortOrder.LayoutOrder;
						VerticalAlignment = Enum.VerticalAlignment.Top;

						[Blend.OnChange "AbsoluteContentSize"] = self._contentSize;
					};

					Blend.ComputedPairs(self._instanceEntries, function(instanceEntry)
						return instanceEntry:Render({
							Parent = props.Parent;
						})
					end);
				};
			};
		};

		Blend.New "ImageLabel" {
			Name = "alternatingColors";
			Size = UDim2.fromScale(1, 1);
			BackgroundTransparency = 1;
			Image = "rbxassetid://17468241397";
			ScaleType = Enum.ScaleType.Tile;
			TileSize = UDim2.new(1, 0, 0, 60);
			ZIndex = 0;

			Visible = Blend.Computed(self.StartingDepth, function(depth)
				return depth == 0
			end);

			ImageTransparency = Blend.Computed(transparency, function(percent)
				return 0.97 + percent
			end);
		};
	};
end

return VisualizerInstanceGroup
