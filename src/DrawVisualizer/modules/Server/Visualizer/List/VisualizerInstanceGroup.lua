local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Brio = require("Brio")
local Maid = require("Maid")
local Math = require("Math")
local Rx = require("Rx")
local RxInstanceUtils = require("RxInstanceUtils")
local Signal = require("Signal")
local Table = require("Table")
local ValueObject = require("ValueObject")
local VisualizerConstants = require("VisualizerConstants")
local VisualizerInstanceEntry = require("VisualizerInstanceEntry")

local MAX_DEPTH_SIZE = VisualizerConstants.MAX_DEPTH_SIZE

local VisualizerInstanceGroup = setmetatable({}, BasicPane)
VisualizerInstanceGroup.ClassName = "VisualizerInstanceGroup"
VisualizerInstanceGroup.__index = VisualizerInstanceGroup

function VisualizerInstanceGroup.new(rootInstance: Instance, startingDepth: number?)
	local self = setmetatable(BasicPane.new(), VisualizerInstanceGroup)

	self._rootInstance = assert(rootInstance, "[VisualizerInstanceGroup]: Root instance is needed!")
	self.Instance = self._rootInstance

	self._startingDepth = startingDepth or 0

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._percentCollapsedTarget = ValueObject.new(1)
	self._maid:GiveTask(self._percentCollapsedTarget)

	self._instances = {}
	self._instanceMap = {}

	self._maid._groups = Maid.new()

	self._instanceEntries = ValueObject.new(Table.copy(self._instanceMap))
	self._maid:GiveTask(self._instanceEntries)

	self._layoutOrder = ValueObject.new(0)
	self._maid:GiveTask(self._layoutOrder)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._contentSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._contentSize)

	self._collapsed = ValueObject.new(true)
	self._maid:GiveTask(self._collapsed)
	self._maid:GiveTask(self._collapsed.Changed:Connect(function()
		self._percentCollapsedTarget.Value = self._collapsed.Value and 1 or 0
	end))

	self.InstanceHovered = Signal.new()
	self._maid:GiveTask(self.InstanceHovered)

	self.InstancePicked = Signal.new()
	self._maid:GiveTask(self.InstancePicked)

	self.InstanceInspected = Signal.new()
	self._maid:GiveTask(self.InstanceInspected)

	self:_observeDescendants(rootInstance)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerInstanceGroup:AddObject(instanceObject: table, depth: number)
	if not instanceObject then
		return warn("[VisualizerInstanceGroup]: Must provide an instance group or entry!")
	end

	local className = instanceObject.ClassName
	local instance = instanceObject.Instance
	local layoutOrder

	if className == self.ClassName then
		local depthBrio = self:_getBrioFromDepth(depth)

		if depthBrio:IsDead() then
			return
		end

		local groupCount = 0
		local groups = depthBrio:GetValue()

		groups.Value[instanceObject.Instance] = instanceObject

		for _ in groups do
			groupCount += 1
		end

		layoutOrder = groupCount
	end

	table.insert(self._instances, instanceObject)
	instanceObject:SetLayoutOrder(#self._instances)

	if instance == self._rootInstance then
		layoutOrder = -1
	elseif instance:IsA("UIComponent") then
		layoutOrder = 0
	elseif not layoutOrder then
		layoutOrder = #self._instances
	end

	instanceObject:SetLayoutOrder(layoutOrder)

	local maid = Maid.new()
	maid:GiveTask(instanceObject)

	if className == "VisualizerInstanceEntry" then
		maid:GiveTask(instanceObject.InstancePicked:Connect(function(pickedInstance)
			self.InstancePicked:Fire(pickedInstance)
		end))

		maid:GiveTask(instanceObject.InstanceInspected:Connect(function(inspectedInstance)
			self.InstanceInspected:Fire(inspectedInstance)
		end))

		maid:GiveTask(instanceObject.InstanceHovered:Connect(function(isHovered: boolean)
			self.InstanceHovered:Fire(isHovered and instanceObject.Instance or nil)
		end))

		maid:GiveTask(instanceObject.Activated:Connect(function()
			instance = instanceObject.Instance
			if not instance then
				return
			end

			if #instance:GetChildren() > 0 then
				self._collapsed.Value = not self._collapsed.Value
				instanceObject:SetCollapsed(self._collapsed.Value)
			end
		end))
	end

	self._maid[instanceObject.Instance] = maid
	self._instanceMap[instanceObject] = true
	self._instanceEntries.Value = Table.copy(self._instanceMap)

	if className == "VisualizerInstanceEntry" then
		instanceObject.IsRootInstance.Value = instanceObject == self._rootInstance
		instanceObject:SetDepth(depth)
	end
end

function VisualizerInstanceGroup:RemoveObject(instanceObject: Instance?, depth: number)
	if not instanceObject then
		return
	elseif instanceObject.ClassName == self.ClassName and not depth then
		return warn("[VisualizerInstanceGroup]: Must provide depth when removing groups!")
	end

	if instanceObject.ClassName == self.ClassName then
		local brio = self._maid._groups[depth]
		if brio then
			if not brio:IsDead() then
				local valueObject = brio:GetValue()
				local groups = valueObject.Value

				if #groups == 1 and groups[1] == instanceObject then
					self._maid._groups[depth] = nil
				else
					local groupIndex = table.find(groups, instanceObject)
					if groupIndex then
						table.remove(groups, groupIndex)
					end

					valueObject.Value = groups
				end
			end
		end
	end

	self._maid[instanceObject.Instance] = nil
	self._instanceMap[instanceObject] = nil
	self._instanceEntries.Value = Table.copy(self._instanceMap)

	local index = table.find(self._instances, instanceObject)
	if index then
		table.remove(self._instances, index)
	end
end

function VisualizerInstanceGroup:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
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

	return Blend.New "Frame" {
		Name = "InstanceGroup";
		BackgroundTransparency = 1;
		Parent = props.Parent;

		LayoutOrder = Blend.Computed(self._layoutOrder, function(layoutOrder)
			return layoutOrder
		end);

		Size = Blend.Computed(percentCollapsed, self._contentSize, function(percent: number, size: Vector2)
			return UDim2.new(1, 0, 0, Math.map(percent, 0, 1, 30, size.Y))
		end);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
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
					return UDim2.fromScale(Math.map(percent, 0, 1, 0, -0.3), 0)
				end);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						Padding = UDim.new(0, 5);
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
	};
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

function VisualizerInstanceGroup:_getGroupFromBrio(brio: table, instance: Instance, depth: number)
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
	local valueObject = brio:GetValue()
	local groups = valueObject.Value
	local group = groups[instance]

	if group then
		return group
	end

	group = VisualizerInstanceGroup.new(instance, depth)
	groups[instance] = group

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
	local root = self._rootInstance
	local parent = baseInstance
	local depth = self._startingDepth

	repeat
		if parent ~= root then
			depth += 1
		end

		parent = parent.Parent
	until
		parent == root or depth >= MAX_DEPTH_SIZE

	return depth
end

function VisualizerInstanceGroup:_createEntry(instance: Instance)
	assert(typeof(instance) == "Instance", "[VisualizerInstanceGroup]: Must provide an instance!")

	local entry = VisualizerInstanceEntry.new()
	entry:SetInstance(instance)

	return entry
end

function VisualizerInstanceGroup:_observeDescendants(baseInstance: Instance)
	local descendantCount = #baseInstance:GetDescendants()
	if descendantCount >= MAX_DEPTH_SIZE then
		return warn(string.format("[VisualizerInstanceGroup]: Root instance exceeds max depth size (%d)!", descendantCount))
	end

	self.RootEntry = self:_createEntry(baseInstance)
	self:AddObject(self.RootEntry, self._startingDepth)

	self._maid._current = RxInstanceUtils.observeChildrenBrio(baseInstance, self._predicate):Subscribe(function(brio: table)
		if brio:IsDead() then
			return
		end

		local instance = brio:GetValue()
		if not instance then
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
	end)
end

function VisualizerInstanceGroup._predicate(instance: Instance)
	return true
end

return VisualizerInstanceGroup
