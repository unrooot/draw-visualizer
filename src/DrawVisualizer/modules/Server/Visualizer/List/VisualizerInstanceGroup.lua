local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Math = require("Math")
local Rx = require("Rx")
local Table = require("Table")
local ValueObject = require("ValueObject")
local VisualizerInstanceEntry = require("VisualizerInstanceEntry")

local VisualizerInstanceGroup = setmetatable({}, BasicPane)
VisualizerInstanceGroup.ClassName = "VisualizerInstanceGroup"
VisualizerInstanceGroup.__index = VisualizerInstanceGroup

function VisualizerInstanceGroup.new(rootInstance: Instance)
	local self = setmetatable(BasicPane.new(), VisualizerInstanceGroup)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._instances = {}
	self._instanceMap = {}

	self._instanceEntries = ValueObject.new(Table.copy(self._instanceMap))
	self._maid:GiveTask(self._instanceEntries)

	self._depth = ValueObject.new(0)
	self._maid:GiveTask(self._depth)

	self._layoutOrder = ValueObject.new(0)
	self._maid:GiveTask(self._layoutOrder)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self:_setupInstance(rootInstance)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function VisualizerInstanceGroup:AddObject(instanceObject: table, isRootInstance: boolean?)
	if not instanceObject then
		warn("[VisualizerInstanceGroup]: Must provide an instance group or entry!")
		return
	end

	table.insert(self._instances, instanceObject)
	instanceObject:SetLayoutOrder(#self._instances)

	if instanceObject.ClassName == "VisualizerInstanceEntry" then
		instanceObject.IsRootInstance.Value = isRootInstance
	end

	self._maid[instanceObject] = instanceObject
	self._instanceMap[instanceObject] = true
	self._instanceEntries.Value = Table.copy(self._instanceMap)
end

function VisualizerInstanceGroup:RemoveObject(instanceObject)
	if not instanceObject then
		warn("[VisualizerInstanceGroup]: Must provide an instance group or entry!")
		return
	end

	local index = table.find(self._instances, instanceObject)
	if index then
		table.remove(self._instances, index)
	end

	self._instanceMap[instanceObject] = nil
	self._maid[instanceObject] = nil
	self._instanceEntries.Value = Table.copy(self._instanceMap)
end

function VisualizerInstanceGroup:SetLayoutOrder(layoutOrder: number)
	self._layoutOrder.Value = layoutOrder
end

function VisualizerInstanceGroup:SetDepth(depth: number)
	self._depth.Value = depth
end

function VisualizerInstanceGroup:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.7)

	local transparency = Blend.Computed(percentVisible, function(percent)
		local itemCount = math.max(1, #self._instances)

		for index, entry in ipairs(self._instances) do
			local progress = (index - 1) / itemCount + 1e-1
			entry:SetVisible(progress <= percent)
		end

		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "InstanceGroup";
		AutomaticSize = Enum.AutomaticSize.Y;
		BackgroundTransparency = 1;
		Size = UDim2.fromScale(1, 0);
		Parent = props.Parent;

		LayoutOrder = Blend.Computed(self._layoutOrder, function(layoutOrder)
			return layoutOrder
		end);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
			Blend.New "UIPadding" {
				PaddingLeft = Blend.Computed(self._depth, self._absoluteSize, function(depth: number, absoluteSize: Vector2)
					if not depth then
						depth = 0
					end

					if depth > 0 then
						return UDim.new((depth * 30) / absoluteSize.X, 0)
					else
						return UDim.new()
					end
				end);
			};

			Blend.New "Frame" {
				Name = "wrapper";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 1);

				Position = Blend.Computed(transparency, function(percent)
					return UDim2.fromScale(Math.map(percent, 0, 1, 0, -0.3), 0)
				end);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Vertical;
						HorizontalAlignment = Enum.HorizontalAlignment.Center;
						Padding = UDim.new(0, 10);
						SortOrder = Enum.SortOrder.LayoutOrder;
						VerticalAlignment = Enum.VerticalAlignment.Center;
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

function VisualizerInstanceGroup:_setupInstance(rootInstance: Instance)
	local entry = VisualizerInstanceEntry.new()
	entry:SetInstance(rootInstance)
	entry:SetDepth(0)
	entry:SetLayoutOrder(1)

	self:AddObject(entry, true)

	local function createChildEntries(instance, currentDepth)
		if not currentDepth then
			currentDepth = 0
		end

		currentDepth += 1

		local group = VisualizerInstanceGroup.new(instance)
		group:SetDepth(currentDepth)
		self:AddObject(group)

		for _, v in instance:GetChildren() do
			local children = v:GetChildren()
			if #children > 1 then
				return createChildEntries(v, currentDepth + 1)
			elseif #children ~= 0 then
				local childEntry = VisualizerInstanceEntry.new()
				childEntry:SetInstance(v)
				childEntry:SetDepth(currentDepth)
				childEntry:SetLayoutOrder(1)

				return group:AddObject(childEntry)
			end
		end
	end

	for _, child in rootInstance:GetChildren() do
		createChildEntries(child)
	end
end

return VisualizerInstanceGroup
