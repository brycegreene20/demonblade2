--[=[
	@class IconButton

	Compact elevated button with a centered icon and bottom label. The icon rotates on
	hover via a spring to create a subtle motion cue.

	Note: IconButton uses its own ElevatedButton (without ButtonContent UIListLayout)
	because it intentionally overflows text below the button edge with ClipsDescendants=false.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILibrary = require(ReplicatedStorage.UITemplates.UILibrary)

local Fusion = UILibrary.Fusion
local Themer = UILibrary.Themer
local Util = UILibrary.Util
local CombineProps = UILibrary.CombineProps
local Children = UILibrary.Children
local Components = UILibrary.Components

local GameTheme = UILibrary.GameTheme
local ElevatedPane = UILibrary.ElevatedPane

-- ============================================================
-- IconButton-specific ElevatedButton (no ButtonContent wrapper)
-- Uses loose children placement + ClipsDescendants=false for text overflow below button.
-- ============================================================

local function ElevatedButton(Scope, Props)
	Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
	local Theme = Themer.Theme:now()

	local children = Props[Children] or {}
	Props[Children] = nil

	local hovering = Scope:Value(false)
	local holding = Scope:Value(false)
	local rawScale = Scope:Spring(
		Scope:Computed(function(use)
			if use(holding) then
				return 0.85
			elseif use(hovering) then
				return 1.025
			else
				return 1
			end
		end),
		Scope:Computed(function(use)
			if use(holding) then
				return 10000
			else
				return 25
			end
		end),
		0.25
	)

	return Scope:BaseButton(CombineProps(Props, {
		Name = "ElevatedButton",
		Size = Scope:UDim2Offset(270, 50),
		BackgroundTransparency = 1,
		BackgroundColor3 = Theme.Colors.Base.Main,
		AutomaticSize = Enum.AutomaticSize.None,
		Hovering = hovering,
		Holding = holding,
		[Children] = {
			Scope:New "Frame" {
				Size = UDim2.fromScale(1, 1),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				BackgroundTransparency = 1,
				[Children] = {
					Scope:New "UIScale" {
						Scale = Scope:Computed(function(use)
							return math.round(use(rawScale) * 100) / 100
						end),
					},
					ElevatedPane(Scope, CombineProps(Props.ElevatedPane or {}, {
						Elevation = 4,
						Size = UDim2.fromScale(1, 1),
						Corner = { Radius = Scope:UDim(0, Theme.CornerRadius.Base) },
						ColorSequence = Props.ColorSequence,
						[Children] = {
							Scope:Frame {
								Size = UDim2.fromScale(1, 1),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								AutomaticSize = Enum.AutomaticSize.None,
								BackgroundTransparency = Scope:Spring(
									Scope:Computed(function(use)
										if use(holding) then
											return 0.5
										elseif use(hovering) then
											return 0.75
										else
											return 1
										end
									end),
									100
								),
							},
							children,
						},
					})),
				},
			},
		},
	}))
end

-- ============================================================
-- Main component
-- ============================================================

export type Props = {
	Image: string?,
	Text: string?,
	OnActivate: (() -> ())?,
}

type FusionScope = typeof(Fusion.scoped(Fusion))

return function(Scope: FusionScope, Props: Props)
	return Themer.Theme:is(GameTheme):during(function()
	Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
	local Theme = Themer.Theme:now()
	local rotation = Scope:Spring(Scope:Value(0), 20, 0.25)

	return ElevatedButton(Scope, CombineProps(Props, {
		Name = "IconButton",
		Size = Scope:UDim2Offset(100, 100),
		OnHover = function()
			rotation:setPosition(20)
		end,
		ClipsDescendants = false,
		[Children] = {
			Scope:New "Frame" {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 1),
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				[Children] = {
					Scope:Image {
						Image = Props.Image or "rbxassetid://82289229761446",
						BackgroundTransparency = 1,
						Size = UDim2.fromOffset(80, 80),
						Position = UDim2.fromScale(0.5, 0.5),
						Rotation = rotation,
						AnchorPoint = Vector2.new(0.5, 0.5),
					},
					Scope:Text {
						Position = Scope:UDim2(0.5, 0, 1, Theme.Padding["0.5"]),
						AnchorPoint = Vector2.new(0.5, 1),
						Size = UDim2.new(1, 0, 0, 25),
						AutomaticSize = Enum.AutomaticSize.None,
						TextXAlignment = Enum.TextXAlignment.Center,
						Text = Props.Text or "Shop",
						TextScaled = true,
						Rotation = 0.01,
						Stroke = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							Color = Color3.new(0, 0, 0),
							LineJoinMode = Enum.LineJoinMode.Round,
						},
					},
				},
			},
		},
	}))
	end)
end
