local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local FilteredObservableListView = require("FilteredObservableListView")
local ObservableList = require("ObservableList")
local ResultEntry = require("ResultEntry")
local Rx = require("Rx")
local RxBrioUtils = require("RxBrioUtils")
local ValueObject = require("ValueObject")

local CommandPaletteResults = setmetatable({}, BasicPane)
CommandPaletteResults.ClassName = "CommandPaletteResults"
CommandPaletteResults.__index = CommandPaletteResults

function CommandPaletteResults.new()
	local self = setmetatable(BasicPane.new(), CommandPaletteResults)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._size = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._size)

	self._contentHeight = ValueObject.new(0)
	self._maid:GiveTask(self._contentHeight)

	self._results = ObservableList.new()
	self._maid:GiveTask(self._results)

	self._filteredResults = FilteredObservableListView.new(self._results, CommandPaletteResults._observeScore)
	self._maid:GiveTask(self._filteredResults)

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function CommandPaletteResults:GetResults()
	return self._results:GetList()
end

function CommandPaletteResults:ObserveResultsBrio()
	return self._results:ObserveItemsBrio()
end

function CommandPaletteResults:SetCurrentProperties(targetInstance, properties)
	for _, member in properties do
		local propertyName = member:GetName()
		local propertyValue = targetInstance[propertyName]

		local entry = ResultEntry.new()
		entry:SetDataType(member:GetRawData().ValueType.Category, typeof(propertyValue))
		entry:SetPropertyName(propertyName)
		entry:SetPropertyValue(propertyValue)
		self._maid:GiveTask(entry)

		self._results:Add(entry)
	end
end

function CommandPaletteResults:ObserveSize()
	return self._size:Observe()
end

function CommandPaletteResults._observeScore(entry)
	return entry:ObserveScore()
end

function CommandPaletteResults:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 50, 1)

	local percentAlpha = Blend.AccelTween(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 400)

	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	self._maid:GiveTask(Blend.Computed(percentVisible, function(percent)
		local results = self._results:GetList()
		local itemCount = #results

		for index, entry in results do
			local progress = (index - 1) / itemCount + 1e-5
			entry:SetVisible(progress <= percent)
		end
	end):Subscribe())

	return Blend.New "Frame" {
		Name = "CommandPaletteResults";
		BackgroundTransparency = 1;
		Position = UDim2.fromScale(0, 0.26);

		Size = Blend.Computed(percentVisible, function(percent)
			return UDim2.fromScale(1, percent * 0.74);
		end);

		[Blend.OnChange "AbsoluteSize"] = function(absoluteSize)
			self._size.Value = absoluteSize
		end;

		[Blend.Children] = {
			Blend.New "Frame" {
				Name = "container";
				Size = UDim2.fromScale(1, 1);
				BackgroundTransparency = 1;
				ZIndex = 2;

				[Blend.Children] = {
					Blend.New "UIPadding" {
						PaddingBottom = UDim.new(0.040541, 0);
						PaddingLeft = UDim.new(0.01875, 0);
						PaddingRight = UDim.new(0.01875, 0);
						PaddingTop = UDim.new(0.040541, 0);
					};

					Blend.New "Frame" {
						Name = "selectionBacking";
						BackgroundColor3 = Color3.fromRGB(50, 50, 50);

						BackgroundTransparency = Blend.Computed(transparency, function(percent)
							return 1 - ((1 - percent) * 0.3)
						end);

						Size = Blend.Computed(props.Bounds, function(bounds)
							return UDim2.new(1, 0, 0, (50 / 500) * bounds.Y)
						end);

						-- [Blend.Children] = {
						-- 	Blend.New "UICorner" {
						-- 		CornerRadius = UDim.new(0.177778, 0);
						-- 	};
						-- };
					};

					Blend.New "ScrollingFrame" {
						Name = "contents";
						Active = true;
						BackgroundTransparency = 1;
						BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
						ScrollBarImageColor3 = Color3.fromRGB(175, 175, 175);
						ScrollBarImageTransparency = transparency;
						ScrollBarThickness = 5;
						ScrollingDirection = Enum.ScrollingDirection.Y;
						ScrollingEnabled = BasicPaneUtils.observeVisible(self);
						Size = UDim2.fromScale(1, 1);
						TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png";
						ZIndex = 3;

						CanvasSize = Blend.Computed(self._contentHeight, function(height)
							return UDim2.fromOffset(0, height)
						end);

						[Blend.Children] = {
							Blend.New "UIListLayout" {
								HorizontalAlignment = Enum.HorizontalAlignment.Center;
								Padding = UDim.new(0.021, 0);

								-- [Blend.OnChange "AbsoluteContentSize"] = function(contentSize)
								-- 	self._contentHeight.Value = contentSize.Y
								-- end;
							};

							self._filteredResults:ObserveItemsBrio():Pipe({
								RxBrioUtils.map(function(entry)
									return entry:Render({
										Bounds = props.Bounds;
									})
								end)
							})
						};
					};
				};
			};
		};
	}
end

return CommandPaletteResults
