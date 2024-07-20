local RunService = game:GetService("RunService")
local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local RxBrioUtils = require("RxBrioUtils")
local CommandPaletteResults = require("CommandPaletteResults")
local CommandPaletteSearch = require("CommandPaletteSearch")
local Fzy = require("Fzy")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local FZY_CONFIG = Fzy.createConfig()

local CommandPalette = setmetatable({}, BasicPane)
CommandPalette.ClassName = "CommandPalette"
CommandPalette.__index = CommandPalette

function CommandPalette.new(targetInstance)
	local self = setmetatable(BasicPane.new(), CommandPalette)

	self._targetInstance = assert(targetInstance, "Bad targetInstance")

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._propertyPromisesForClass = {}

	self._bounds = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._bounds)

	self._search = CommandPaletteSearch.new()
	self._search:SetClassName(targetInstance.ClassName)
	self._maid:GiveTask(self._search)

	self._searchScore = ValueObject.new()
	self._maid:GiveTask(self._searchScore)

	self._results = CommandPaletteResults.new(self._searchScore)
	self._maid:GiveTask(self._results)

	-- TODO: Is there a better way of doing this? Probably :V
	self._maid:GiveTask(self._search:ObserveQuery():Subscribe(function(query)
		if self:IsVisible() then
			self._results:SetVisible(query ~= "")
		end

		if query then
			query = string.gsub(query, "%s+", "")

			for _, entry in self._results:GetResults() do
				entry:SetScore(Fzy.score(FZY_CONFIG, query, entry:GetPropertyName()))
			end
		end
	end))

	self.EscapePressed = self._search.EscapePressed

	if not RunService:IsRunning() then
		local RobloxApiDump = require("RobloxApiDump")

		self._apiDump = RobloxApiDump.new()
		self._maid:GiveTask(self._apiDump)

		self:_promiseClassDump(targetInstance):Then(function(dump)
			self._results:SetCurrentProperties(self._targetInstance, dump)
		end)
	else
		print("api dump not available!")
	end

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._search:SetVisible(isVisible)

		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function CommandPalette:SetInputFocused(isFocused: boolean)
	self._search:SetInputFocused(isFocused)
end

function CommandPalette:_promiseClassDump(targetInstance)
	local className = targetInstance.ClassName

	if self._propertyPromisesForClass[className] then
		return self._propertyPromisesForClass[className]
	end

	self._propertyPromisesForClass[className] = self._maid:GivePromise(self._apiDump:PromiseClass(className))
		:Then(function(class)
			return class:PromiseProperties()
		end)
		:Then(function(allProperties)
			local valid = {}
			for _, property in allProperties do
				if not (property:IsHidden()
						or property:IsNotScriptable()
						or property:IsDeprecated()
						or property:IsWriteNotAccessibleSecurity()
						or property:IsReadNotAccessibleSecurity()
						or property:IsWriteLocalUserSecurity()
						or property:IsReadLocalUserSecurity())
					then

					table.insert(valid, property)
				end
			end

			return valid
		end)

	return self._propertyPromisesForClass[className]
end

function CommandPalette:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 40, 0.7)

	local percentAlpha = Blend.AccelTween(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 800)

	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	local percentResults = Blend.Spring(self._search:ObserveQuery():Pipe({
		Rx.defaultsTo(0);
		Rx.map(function(query)
			return query == "" and 0 or 1
		end);
	}), 50, 1)

	local searchSize = Blend.Spring(self._search:ObserveSize():Pipe({
		Rx.map(function(size)
			return size.Y
		end)
	}), 45, 0.9)

	local resultsSize = Blend.Computed(self._results:ObserveSize(), function(size)
		return size.Y
	end)

	return Blend.New "Frame" {
		Name = "UICommandPalette";
		AnchorPoint = Vector2.new(0.5, 0);
		BackgroundColor3 = Color3.fromRGB(23, 23, 23);
		Size = props.Size or UDim2.fromScale(0.9, 1);
		Parent = props.Parent;

		Position = props.Position or Blend.Computed(percentVisible, function(percent)
			return UDim2.fromScale(0.5, 0); --0.2 + ((1 - percent) * 0.1));
		end);

		BackgroundTransparency = Blend.Computed(transparency, function(percent)
			return 0.025 + percent
		end);

		[Blend.OnChange "AbsoluteSize"] = function(absoluteSize)
			self._bounds.Value = absoluteSize
		end;

		[Blend.Children] = {
			Blend.New "UISizeConstraint" {
				MaxSize = Vector2.new(800, 500);
			};

			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = Blend.Computed(percentResults, self._bounds, searchSize, resultsSize, function(percent, bounds, searchHeight, resultsHeight)
					return math.clamp((bounds.X / (searchHeight + (percent * resultsHeight))), 1.6, 6.154)
				end);
			};

			-- Blend.New "UIScale" {
			-- 	Scale = Blend.Computed(percentVisible, function(percent)
			-- 		return 1 - ((1 - percent) * 0.15)
			-- 	end);
			-- };

			Blend.New "UIStroke" {
				Color = Color3.fromRGB(255, 255, 255);

				Transparency = Blend.Computed(transparency, function(percent)
					return 0.9 + percent * 0.1
				end);
			};

			-- Blend.New "UICorner" {
			-- 	CornerRadius = Blend.Computed(self._bounds, function(bounds)
			-- 		return UDim.new(10 / bounds.Y, 0)
			-- 	end);
			-- };

			Blend.New "ImageLabel" {
				Name = "shadow";
				AnchorPoint = Vector2.new(0.5, 0.5);
				BackgroundTransparency = 1;
				Image = "rbxassetid://6150493168";
				ImageColor3 = Color3.fromRGB(0, 0, 0);
				Position = UDim2.fromScale(0.5, 0.5);
				ScaleType = Enum.ScaleType.Slice;
				Size = UDim2.fromScale(1.05, 1.08);
				SliceCenter = Rect.new(Vector2.new(100, 100), Vector2.new(100, 100));
				SliceScale = 0.3;

				ImageTransparency = Blend.Computed(transparency, function(percent)
					return 0.9 + (percent * 0.1)
				end);
			};

			self._search:Render();

			self._results:Render({
				Bounds = self._bounds;
			});
		};
	}
end

return CommandPalette
