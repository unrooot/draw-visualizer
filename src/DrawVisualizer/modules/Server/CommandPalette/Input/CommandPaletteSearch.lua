local require = require(script.Parent.loader).load(script)

local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")
local UserInputService = game:GetService("UserInputService")

local BasicPane = require("BasicPane")
local BasicPaneUtils = require("BasicPaneUtils")
local Blend = require("Blend")
local Rx = require("Rx")
local Signal = require("Signal")
local ValueObject = require("ValueObject")

local CommandPaletteSearch = setmetatable({}, BasicPane)
CommandPaletteSearch.ClassName = "CommandPaletteSearch"
CommandPaletteSearch.__index = CommandPaletteSearch

function CommandPaletteSearch.new()
	local self = setmetatable(BasicPane.new(), CommandPaletteSearch)

	self.EscapePressed = Signal.new()

	self._percentVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._percentVisibleTarget)

	self._input = ValueObject.new()
	self._maid:GiveTask(self._input)

	self._size = ValueObject.new(Vector2.new())
	self._maid:GiveTask(self._size)

	self._focused = ValueObject.new(false)
	self._maid:GiveTask(self._focused)
	self._maid:GiveTask(self._focused.Changed:Connect(function()
		local isFocused = self._focused.Value
		local input = self._input.Value

		if input then
			if isFocused then
				RunService.RenderStepped:Wait()
				input:CaptureFocus()
			else
				input:ReleaseFocus()
			end
		end
	end))

	self._placeholderVisibleTarget = ValueObject.new(0)
	self._maid:GiveTask(self._placeholderVisibleTarget)

	self._query = ValueObject.new()
	self._maid:GiveTask(self._query)
	self._maid:GiveTask(self._query:Observe():Subscribe(function(query)
		self._placeholderVisibleTarget.Value = query == "" and 1 or 0
	end))

	self._iconData = ValueObject.new({})
	self._maid:GiveTask(self._iconData)

	self._className = ValueObject.new("")
	self._maid:GiveTask(self._className)
	self._maid:GiveTask(self._className.Changed:Connect(function()
		self._iconData.Value = StudioService:GetClassIcon(self._className.Value)
	end))

	self:_listenForInput()

	self._maid:GiveTask(self.VisibleChanged:Connect(function(isVisible)
		local target = isVisible and 1 or 0

		if not isVisible then
			if self._input.Value then
				self._input.Value:ReleaseFocus()
			end
		end

		self._placeholderVisibleTarget.Value = target
		self._percentVisibleTarget.Value = isVisible and 1 or 0
	end))

	return self
end

function CommandPaletteSearch:SetInputFocused(isFocused: boolean)
	self._focused.Value = isFocused
end

function CommandPaletteSearch:SetClassName(className: string)
	self._className.Value = className
end

function CommandPaletteSearch:ObserveQuery()
	return self._query:Observe()
end

function CommandPaletteSearch:ObserveSize()
	return self._size:Observe()
end

function CommandPaletteSearch:_listenForInput()
	self._maid:GiveTask(UserInputService.InputBegan:Connect(function(input)
		if not UserInputService:GetFocusedTextBox() then
			return
		end

		--
	end))
end

function CommandPaletteSearch:Render()
	local percentVisible = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 40, 0.7)

	local percentAlpha = Blend.Spring(Blend.toPropertyObservable(self._percentVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 800)

	local transparency = Blend.Computed(percentAlpha, function(percent)
		return 1 - percent
	end)

	local percentPlaceholderVisible = Blend.Spring(Blend.toPropertyObservable(self._placeholderVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 45, 0.7)

	local percentPlaceholderAlpha = Blend.AccelTween(Blend.toPropertyObservable(self._placeholderVisibleTarget):Pipe({
		Rx.startWith({0})
	}), 800)

	local cornerSpring = Blend.Spring(self:ObserveQuery():Pipe({
		Rx.map(function(query)
			return query == "" and 1 or 0
		end)
	}), 40, 0.7)

	return Blend.New "Frame" {
		Name = "CommandPaletteSearch";
		Size = UDim2.fromScale(1, 1);
		BackgroundTransparency = 1;
		ZIndex = 2;

		[Blend.OnChange "AbsoluteSize"] = function(absoluteSize)
			self._size.Value = absoluteSize
		end;

		[Blend.Children] = {
			Blend.New "UISizeConstraint" {
				MaxSize = Vector2.new(800, 130);
			};

			Blend.New "UIAspectRatioConstraint" {
				AspectRatio = 6.153846;
			};

			Blend.New "Frame" {
				Name = "bar";
				BackgroundTransparency = 1;
				Size = UDim2.fromScale(1, 0.192);

				[Blend.Children] = {
					Blend.New "CanvasGroup" {
						Name = "wrapper";
						BackgroundColor3 = Color3.fromRGB(255, 255, 255);
						BackgroundTransparency = 1;
						GroupTransparency = transparency;
						Size = UDim2.fromScale(1, 1);

						[Blend.Children] = {
							Blend.New "Frame" {
								Name = "backing";
								BackgroundColor3 = Color3.fromRGB(197, 156, 242);
								Size = UDim2.fromScale(1, 1);

								[Blend.Children] = {
									Blend.New "UICorner" {
										CornerRadius = UDim.new(0.4, 0);
									};
								};
							};

							Blend.New "Frame" {
								Name = "cover";
							AnchorPoint = Vector2.new(0, 1);
								BackgroundColor3 = Color3.fromRGB(197, 156, 242);
								Position = UDim2.fromScale(0, 1);
								Size = UDim2.fromScale(1, 0.4);
								ZIndex = 2;
							};
						};
					}
				};
			};

			Blend.New "Frame" {
				Name = "body";
				BackgroundTransparency = transparency;
				BackgroundColor3 = Color3.fromRGB(35, 35, 35);
				Position = UDim2.fromScale(0, 0.192308);
				Size = UDim2.fromScale(1, 0.808);

				-- BackgroundTransparency = Blend.Computed(percentAlpha, function(percent)
				-- 	return 1 - (percent * 0.05);
				-- end);

				[Blend.Children] = {
					Blend.New "UICorner" {
						CornerRadius = Blend.Computed(cornerSpring, function(percent)
							return UDim.new(percent * 0.095, 0)
						end);
					};

					Blend.New "Frame" {
						Name = "container";
						Size = UDim2.fromScale(1, 1);
						BackgroundTransparency = 1;

						[Blend.Children] = {
							Blend.New "UIPadding" {
								PaddingBottom = UDim.new(0.286, 0);
								PaddingLeft = UDim.new(0.038, 0);
								PaddingRight = UDim.new(0.038, 0);
								PaddingTop = UDim.new(0.286, 0);
							};

							Blend.New "Frame" {
								Name = "contents";
								BackgroundTransparency = 1;
								ClipsDescendants = true;
								Position = UDim2.fromScale(0.08, 0);
								Size = UDim2.fromScale(0.92, 1);

								[Blend.Children] = {
									Blend.New "Frame" {
										Name = "placeholder";
										BackgroundTransparency = 1;
										Size = UDim2.fromScale(1, 1);
										ZIndex = 1;

										Position = Blend.Computed(percentPlaceholderVisible, function(percent)
											return UDim2.fromScale(-(1 - percent) * 0.15, 0)
										end);

										[Blend.Children] = {
											Blend.New "TextLabel" {
												Name = "title";
												AnchorPoint = Vector2.new(0, 0.5);
												BackgroundTransparency = 1;
												FontFace = Font.new("rbxassetid://11598289817", Enum.FontWeight.Heavy, Enum.FontStyle.Normal);
												Position = UDim2.fromScale(0, 0.5);
												Size = UDim2.fromScale(0.231, 0.644);
												Text = "type to search";
												TextColor3 = Color3.fromRGB(255, 255, 255);
												TextScaled = true;

												TextTransparency = Blend.Computed(percentPlaceholderAlpha, function(percent)
													return 1 - percent
												end);
											};

											Blend.New "TextLabel" {
												Name = "subtext";
												AnchorPoint = Vector2.new(0, 0.5);
												BackgroundTransparency = 1;
												FontFace = Font.new("rbxassetid://11598289817");
												Position = UDim2.fromScale(0.241, 0.5);
												Size = UDim2.fromScale(0.337, 0.51);
												Text = "filter properties & children";
												TextColor3 = Color3.fromRGB(154, 154, 154);
												TextScaled = true;

												TextTransparency = Blend.Computed(percentPlaceholderAlpha, function(percent)
													return 1 - percent
												end);
											};
										};
									};

									Blend.New "TextBox" {
										Name = "input";
										AnchorPoint = Vector2.new(0, 0.5);
										BackgroundTransparency = 1;
										FontFace = Font.new("rbxassetid://11598289817", Enum.FontWeight.Bold, Enum.FontStyle.Normal);
										Position = UDim2.fromScale(0, 0.5);
										Size = UDim2.fromScale(1, 0.644105);
										TextColor3 = Color3.fromRGB(255, 255, 255);
										TextScaled = true;
										TextTransparency = transparency;
										TextXAlignment = Enum.TextXAlignment.Left;

										[Blend.OnChange "Text"] = function(text)
											self._query.Value = text
										end;

										[Blend.Instance] = function(input)
											self._input.Value = input
										end;

										[Blend.OnEvent "FocusLost"] = function(enterPressed, inputObject)
											self:SetInputFocused(false)

											if not enterPressed then
												if inputObject.UserInputType == Enum.UserInputType.Keyboard then
													if inputObject.KeyCode == Enum.KeyCode.Escape then
														local input = self._input.Value

														if input then
															if self._query.Value == "" then
																self.EscapePressed:Fire()
															else
																input.Text = ""
																self:SetInputFocused(true)
															end
														end
													end
												end
											end
										end;
									};
								};
							};

							Blend.New "Frame" {
								Name = "search";
								BackgroundTransparency = 1;
								Size = UDim2.fromScale(1, 1);
								ZIndex = 3;

								[Blend.Children] = {
									Blend.New "UIAspectRatioConstraint" {
										AspectRatio = 1;
									};

									Blend.New "ImageLabel" {
										Name = "icon";
										AnchorPoint = Vector2.new(0.5, 0.5);
										BackgroundTransparency = 1;
										Image = "rbxassetid://6031154871";
										ImageColor3 = Color3.fromRGB(82, 82, 82);
										ImageTransparency = transparency;
										Position = UDim2.fromScale(0.5, 0.5);
										Size = UDim2.fromScale(1, 1);

										Rotation = Blend.Computed(percentVisible, function(percent)
											return -90 * (1 - percent)
										end);
									};
								};
							};

							Blend.New "Frame" {
								Name = "class";
								Position = UDim2.fromScale(1, 0);
								AnchorPoint = Vector2.new(1, 0);
								Size = UDim2.fromScale(1, 1);
								BackgroundTransparency = 1;

								[Blend.Children] = {
									Blend.New "UIAspectRatioConstraint" {
										AspectRatio = 1;
									};

									Blend.New "ImageLabel" {
										Name = "icon";
										AnchorPoint = Vector2.new(0.5, 0.5);
										BackgroundTransparency = 1;
										ImageTransparency = transparency;
										LayoutOrder = 1;
										Position = UDim2.fromScale(0.5, 0.5);
										ScaleType = Enum.ScaleType.Slice;
										Size = UDim2.fromScale(1, 1);
										SliceCenter = Rect.new(0, 0, 16, 16);

										Image = Blend.Computed(self._iconData, function(data)
											return data.Image
										end);

										ImageRectOffset = Blend.Computed(self._iconData, function(data)
											return data.ImageRectOffset
										end);

										ImageRectSize = Blend.Computed(self._iconData, function(data)
											return data.ImageRectSize
										end);

										[Blend.Children] = {
											Blend.New "UISizeConstraint" {
												MaxSize = Vector2.new(20, 20);
											};

											-- Blend.New "ImageLabel" {
											-- 	Name = "glow";
											-- 	AnchorPoint = Vector2.new(0.5, 0.5);
											-- 	BackgroundTransparency = 1;
											-- 	Image = "rbxassetid://6150493168";
											-- 	ImageColor3 = Color3.fromRGB(200, 200, 200);
											-- 	Position = UDim2.fromScale(0.5, 0.5);
											-- 	ScaleType = Enum.ScaleType.Slice;
											-- 	Size = UDim2.fromScale(2, 2);
											-- 	SliceCenter = Rect.new(Vector2.new(100, 100), Vector2.new(100, 100));
											-- 	SliceScale = 0.4;

											-- 	ImageTransparency = Blend.Computed(transparency, function(percent)
											-- 		return 0.75 + (percent * 0.25);
											-- 	end);
											-- };
										};
									};
								};
							};
						};
					};

					Blend.New "TextButton" {
						Name = "button";
						BackgroundColor3 = Color3.fromRGB(163, 162, 165);
						BackgroundTransparency = 1;
						Size = UDim2.fromScale(1, 1);
						TextColor3 = Color3.fromRGB(27, 42, 53);
						TextSize = 8;
						ZIndex = 5;

						Visible = Blend.Computed(percentPlaceholderVisible, BasicPaneUtils.observeVisible(self), self._focused, function(percent, isVisible, isFocused)
							if percent ~= 1 then
								return false
							end

							return isVisible and not isFocused
						end);

						[Blend.OnEvent "Activated"] = function()
							if self._input.Value then
								if not self._focused.Value then
									self._focused.Value = true
								end
							end
						end;
					};
				};
			};
		};
	};
end

return CommandPaletteSearch