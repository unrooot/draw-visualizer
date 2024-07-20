local require = require(script.Parent.loader).load(script)

local BasicPane = require("BasicPane")
local Blend = require("Blend")
local DataTypeConstants = require("DataTypeConstants")
local Rx = require("Rx")
local ValueObject = require("ValueObject")

local ResultEntry = setmetatable({}, BasicPane)
ResultEntry.ClassName = "ResultEntry"
ResultEntry.__index = ResultEntry

function ResultEntry.new()
	local self = setmetatable(BasicPane.new(), ResultEntry)

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._propertyName = ValueObject.new()
	self._maid:GiveTask(self._propertyName)

	self._dataCategory = ValueObject.new()
	self._maid:GiveTask(self._dataCategory)

	self._dataType = ValueObject.new()
	self._maid:GiveTask(self._dataType)

	self._propertyValue = ValueObject.new()
	self._maid:GiveTask(self._propertyValue)

	self._score = ValueObject.new(0)
	self._maid:GiveTask(self._score)
	self._maid:GiveTask(self._score:Observe():Subscribe(function(score)
		-- print(score)
	end))

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function ResultEntry:ObserveScore()
	return self._score:Observe()
end

function ResultEntry:SetScore(score: number)
	self._score.Value = score
end

function ResultEntry:SetDataType(dataCategory: string, dataType: string)
	if not dataCategory or not DataTypeConstants[dataCategory] then
		return warn(`[ResultEntry]: Invalid data category {dataCategory}!`)
	end

	self._dataCategory.Value = dataCategory
	self._dataType.Value = dataType
end

function ResultEntry:GetPropertyName()
	return self._propertyName.Value
end

function ResultEntry:SetPropertyName(propertyName: string)
	self._propertyName.Value = propertyName
end

function ResultEntry:SetPropertyValue(value: any)
	self._propertyValue.Value = value
end

function ResultEntry:Render(props)
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 30, 0.9)

	local percentAlpha = Blend.AccelTween(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 500)

	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	return Blend.New "Frame" {
		Name = "ResultEntryTemplate";
		BackgroundColor3 = Color3.fromRGB(50, 50, 50);
		BackgroundTransparency = 1;
		Size = UDim2.fromScale(1, 1);

		Visible = Blend.Computed(self._score, function(score)
			return score > 0
		end);

		LayoutOrder = Blend.Computed(self._score, function(score)
			return math.ceil(math.abs(score))
		end);

		[Blend.Children] = {
			Blend.New "UIPadding" {
				PaddingBottom = UDim.new(0.3, 0);
				PaddingLeft = UDim.new(0.022472, 0);
				PaddingRight = UDim.new(0.022472, 0);
				PaddingTop = UDim.new(0.3, 0);
			};

			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = 15.4;
			};

			Blend.New "UISizeConstraint" {
				MaxSize = Vector2.new(770, 50);
			};

			Blend.New "Frame" {
				Name = "propertyName";
				Size = UDim2.fromScale(0.65, 1);
				BackgroundTransparency = 1;

				Position = Blend.Computed(percentVisible, function(percent)
					return UDim2.fromScale(-(1 - percent), 0);
				end);

				[Blend.Children] = {
					Blend.New "UIListLayout" {
						FillDirection = Enum.FillDirection.Horizontal;
						Padding = UDim.new(0, 7);
						VerticalAlignment = Enum.VerticalAlignment.Center;
					};

					Blend.New "TextLabel" {
						Name = "label";
						AutomaticSize = Enum.AutomaticSize.X;
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json");
						LayoutOrder = 1;
						Size = UDim2.fromScale(0, 1);
						Text = self._propertyName;
						TextColor3 = Color3.fromRGB(200, 200, 200);
						TextScaled = true;
						TextTransparency = transparency;
						TextXAlignment = Enum.TextXAlignment.Left;

						[Blend.Children] = {
							Blend.New "UITextSizeConstraint" {
								MaxTextSize = Blend.Computed(props.Bounds, function(bounds)
									return (20 / 500) * bounds.Y
								end);
							};
						};
					};

					Blend.New "Frame" {
						Name = "dataType";
						AutomaticSize = Enum.AutomaticSize.X;
						BackgroundTransparency = transparency;
						LayoutOrder = 2;
						Size = UDim2.fromScale(0, 1.3);

						BackgroundColor3 = Blend.Computed(self._dataCategory, self._dataType, function(category, dataType)
							local color = DataTypeConstants[category][dataType]

							if not color then
								return Color3.fromRGB(255, 255, 255)
							end

							return color
						end);

						[Blend.Children] = {
							Blend.New "UICorner" {
								CornerRadius = UDim.new(0.3, 0);
							};

							Blend.New "UIPadding" {
								PaddingLeft = UDim.new(0, 5);
								PaddingRight = UDim.new(0, 5);
							};

							Blend.New "TextLabel" {
								Name = "label";
								AutomaticSize = Enum.AutomaticSize.X;
								BackgroundTransparency = 1;
								FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Heavy, Enum.FontStyle.Normal);
								Size = UDim2.fromScale(0, 1);
								Text = self._dataType;
								TextColor3 = Color3.fromRGB(70, 70, 70);
								TextScaled = true;
								TextTransparency = transparency;

								[Blend.Children] = {
									Blend.New "UITextSizeConstraint" {
										MaxTextSize = Blend.Computed(props.Bounds, function(bounds)
											return (15 / 500) * bounds.Y
										end);
									};
								};
							};
						};
					};
				};
			};

			Blend.New "Frame" {
				Name = "propertyValue";
				AnchorPoint = Vector2.new(1, 0.5);
				BackgroundColor3 = Color3.fromRGB(30, 30, 30);
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(0.327, 1.5);

				Position = Blend.Computed(percentVisible, function(percent)
					return UDim2.fromScale(1 + (1 - percent), 0.5);
				end);

				[Blend.Children] = {
					Blend.New "TextLabel" {
						Name = "label";
						AnchorPoint = Vector2.new(0.5, 0.5);
						BackgroundTransparency = 1;
						FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.Heavy, Enum.FontStyle.Normal);
						Position = UDim2.fromScale(0.5, 0.5);
						Size = UDim2.fromScale(1, 1);
						TextColor3 = Color3.fromRGB(255, 255, 255);
						TextScaled = true;
						TextTransparency = transparency;
						TextXAlignment = Enum.TextXAlignment.Right;

						Text = Blend.Computed(self._propertyValue, function(value)
							return tostring(value)
						end);

						[Blend.Children] = {
							Blend.New "UITextSizeConstraint" {
								MaxTextSize = 20;
							};
						};
					};
				};
			};
		};
	}
end

return ResultEntry
