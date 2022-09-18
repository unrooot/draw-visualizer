local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local Rx = require("Rx")
local ValueObject = require("ValueObject")
local VisualizerHeader = require("VisualizerHeader")
local VisualizerInstanceGroup = require("VisualizerInstanceGroup")
local VisualizerListView = require("VisualizerListView")

local Visualizer = setmetatable({}, BasicPane)
Visualizer.ClassName = "Visualizer"
Visualizer.__index = Visualizer

function Visualizer.new()
	local self = setmetatable(BasicPane.new(), Visualizer)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._absoluteSize = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._absoluteSize)

	self._header = VisualizerHeader.new()
	self._maid:GiveTask(self._header)

	self._list = VisualizerListView.new()
	self._maid:GiveTask(self._list)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible, doNotAnimate)
		self._percentVisibleTarget.Value = isVisible and 1 or 0

		self._header:SetVisible(isVisible, doNotAnimate)
		self._list:SetVisible(isVisible, doNotAnimate)
	end))

	return self
end

function Visualizer:SetRootInstance(instance: Instance)
	if not instance then
		self._maid._current = nil
		return
	end

	local group = VisualizerInstanceGroup.new(instance)

	self._list:AddInstanceGroup(group)

	self._maid._current = function()
		self._list:RemoveInstanceGroup(group)
	end
end

function Visualizer:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.9)

	local transparency = Blend.Computed(percentVisible, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "DrawVisualizer";
		Parent = props.Parent;
		BackgroundColor3 = Color3.fromRGB(39, 39, 39);
		BackgroundTransparency = transparency;
		Size = UDim2.fromScale(1, 1);

		[Blend.OnChange "AbsoluteSize"] = self._absoluteSize;

		[Blend.Children] = {
			self._header:Render({
				AbsoluteRootSize = self._absoluteSize;
				Parent = props.Parent;
			});

			self._list:Render({
				AbsoluteRootSize = self._absoluteSize;
				Parent = props.Parent;
			})
		};
	};
end

return Visualizer
