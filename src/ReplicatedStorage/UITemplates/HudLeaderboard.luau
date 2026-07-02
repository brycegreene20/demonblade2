
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILibrary = require(ReplicatedStorage.UITemplates.UILibrary)

local Fusion = UILibrary.Fusion
local Themer = UILibrary.Themer
local Util = UILibrary.Util
local CombineProps = UILibrary.CombineProps
local Children = UILibrary.Children
local _peek = UILibrary.peek

local GameTheme = UILibrary.GameTheme
local Pane = UILibrary.Pane
local _ElevatedPane = UILibrary.ElevatedPane
local ElevatedButton = UILibrary.ElevatedButton
local Widget = UILibrary.Widget
local Divider = UILibrary.Divider

local Scroller = require(UILibrary.OnyxUI.Components.Scroller)
local Components = table.clone(UILibrary.Components)
Components.Scroller = Scroller

local ICON_ASSETS = {
	Coins = "rbxassetid://85105246845773",
}

local SLAYER_ACCENT = Color3.fromHex("00F7FF")
local DEMON_ACCENT = Color3.fromHex("EF4444")
local WHITE = Color3.new(1, 1, 1)
local SUBTITLE_COLOR = Color3.fromHex("A8A29E")

local function abbreviate(n: number): string
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return tostring(n)
end

local function truncateName(name: string, maxLen: number): string
	if #name > maxLen then
		return string.sub(name, 1, maxLen - 1) .. "…"
	end
	return name
end

local SLAYER_DATA = {
	{ rank = 1, name = "ZenithBlade", bounty = 48200, title = "Hashira" },
	{ rank = 2, name = "SunBreather", bounty = 41500, title = "Hashira" },
	{ rank = 3, name = "FlameWarden", bounty = 35800, title = "Kinoe" },
	{ rank = 4, name = "ThunderClap", bounty = 29100, title = "Kinoe" },
	{ rank = 5, name = "MistWalkerXYZ", bounty = 24600, title = "Kinoto" },
	{ rank = 6, name = "WindCutter", bounty = 19300, title = "Kinoto" },
	{ rank = 7, name = "WaterFlow", bounty = 14700, title = "Tsuchinoe" },
	{ rank = 8, name = "StonePillar", bounty = 11200, title = "Tsuchinoe" },
	{ rank = 9, name = "SerpentFang", bounty = 8400, title = "Mizunoto" },
	{ rank = 10, name = "InsectBuzz", bounty = 5100, title = "Mizunoto" },
}

local _DEMON_DATA = {
	{ rank = 1, name = "MugenKizuki", bounty = 52700, title = "Upper Moon" },
	{ rank = 2, name = "BloodDemon", bounty = 44300, title = "Upper Moon" },
	{ rank = 3, name = "NightTerror", bounty = 37900, title = "Upper Moon" },
	{ rank = 4, name = "ShadowFiend", bounty = 31200, title = "Lower Moon" },
	{ rank = 5, name = "VoidHunger", bounty = 26800, title = "Lower Moon" },
	{ rank = 6, name = "CrimsonMaw", bounty = 21500, title = "Lower Moon" },
	{ rank = 7, name = "DarkPulse", bounty = 16900, title = "Demon" },
	{ rank = 8, name = "AbyssCrawl", bounty = 12300, title = "Demon" },
	{ rank = 9, name = "GrimReap", bounty = 8800, title = "Demon" },
	{ rank = 10, name = "FoulBreath", bounty = 4600, title = "Demon" },
}

local PLAYER_ENTRY = { rank = 47, name = "You", bounty = 1250, title = "Mizunoto" }

local function getRankColor(rank: number): Color3
	if rank == 1 then return Color3.fromHex("FFD700") end
	if rank == 2 then return Color3.fromHex("C0C0C0") end
	if rank == 3 then return Color3.fromHex("CD7F32") end
	return WHITE
end

local function CompactRow(Scope: any, Props: any)
	Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
	local Theme = Themer.Theme:now()

	local rank = Props.Rank or 1
	local playerName = Props.PlayerName or "Player"
	local bounty = Props.Bounty or 0
	local title = Props.Title or ""
	local isPlayer = Props.IsPlayer or false
	local accentColor: Color3 = Props.AccentColor or SLAYER_ACCENT
	local layoutOrder = Props.LayoutOrder or 0

	local nameColor: Color3 = if isPlayer then accentColor else getRankColor(rank)
	local displayName = if isPlayer then "You (#" .. tostring(rank) .. ")" else truncateName(playerName, 14)

	return Pane(Scope, {
		Size = UDim2.new(1, 0, 0, 46),
		LayoutOrder = layoutOrder,
		BackgroundTransparency = if isPlayer then 0.2 else 0.35,
		[Children] = {
			Scope:New "UIListLayout" {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = Scope:UDim(0, Theme.Padding["0.25"]),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			Scope:New "UIPadding" {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			},
			Scope:Text {
				Text = "#" .. tostring(rank),
				TextSize = Theme.TextSize["1"],
				TextColor3 = nameColor,
				Size = UDim2.fromOffset(34, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 1.5,
				},
			},
			Scope:Frame {
				Size = UDim2.new(1, -140, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
				List = {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					Padding = Scope:UDim(0, 1),
				},
				[Children] = {
					Scope:Text {
						Text = displayName,
						TextSize = Theme.TextSize["1"],
						TextColor3 = nameColor,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextXAlignment = Enum.TextXAlignment.Left,
						LayoutOrder = 1,
						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
						Stroke = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							LineJoinMode = Enum.LineJoinMode.Round,
							Thickness = 1.5,
						},
					},
					Scope:Text {
						Text = title,
						TextSize = Scope:Computed(function(use)
							return use(Theme.TextSize["1"]) * 0.75
						end),
						TextColor3 = SUBTITLE_COLOR,
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextTransparency = 0.3,
						LayoutOrder = 2,
						Stroke = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							LineJoinMode = Enum.LineJoinMode.Round,
							Thickness = 1,
						},
					},
				},
			},
			Scope:Frame {
				Size = UDim2.fromOffset(55, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
				List = {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = Scope:UDim(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				[Children] = {
					Scope:Image {
						Image = ICON_ASSETS.Coins,
						Size = UDim2.fromOffset(16, 16),
						BackgroundTransparency = 1,
						LayoutOrder = 1,
					},
					Scope:Text {
						Text = abbreviate(bounty),
						TextSize = Scope:Computed(function(use)
							return use(Theme.TextSize["1"]) * 0.85
						end),
						TextColor3 = Color3.fromHex("FFD700"),
						TextXAlignment = Enum.TextXAlignment.Right,
						LayoutOrder = 2,
						FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
						Stroke = {
							ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
							LineJoinMode = Enum.LineJoinMode.Round,
							Thickness = 1.5,
						},
					},
				},
			},
		},
	})
end

local function TabButton(Scope: any, Props: any)
	Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
	local Theme = Themer.Theme:now()

	local isActive = Props.IsActive or Scope:Value(false)
	local label = Props.Label or "Tab"
	local activeColor: Color3 = Props.ActiveColor or SLAYER_ACCENT
	local onActivate = Props.OnActivate

	return ElevatedButton(Scope, {
		Size = UDim2.new(0.5, -4, 0, 34),
		LayoutOrder = Props.LayoutOrder or 0,
		OnActivate = onActivate,
		ColorSequence = Scope:Computed(function(use)
			if use(isActive) then
				return ColorSequence.new(activeColor, activeColor:Lerp(Color3.new(0, 0, 0), 0.4))
			end
			return ColorSequence.new(Color3.fromHex("2A2A2A"), Color3.fromHex("1A1A1A"))
		end),
		[Children] = {
			Scope:Heading {
				Text = label,
				TextSize = Theme.TextSize["1"],
				Stroke = {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 2,
				},
			},
		},
	})
end

export type Props = {
	HeadingBanner: { Text: string? }?,
}

return function(Scope: any, Props: Props)
	return Themer.Theme:is(GameTheme):during(function()
		Scope = Fusion.innerScope(Scope, Fusion, Util, Components)
		local Theme = Themer.Theme:now()

		local activeTab = Scope:Value("Slayers")

		local slayerActive = Scope:Computed(function(use)
			return use(activeTab) == "Slayers"
		end)
		local demonActive = Scope:Computed(function(use)
			return use(activeTab) == "Demons"
		end)

		local contentChildren = {}

		for i, entry in ipairs(SLAYER_DATA) do
			table.insert(contentChildren, CompactRow(Scope, {
				Rank = entry.rank,
				PlayerName = entry.name,
				Bounty = entry.bounty,
				Title = entry.title,
				IsPlayer = false,
				AccentColor = SLAYER_ACCENT,
				LayoutOrder = i,
			}))
		end

		table.insert(contentChildren, Divider(Scope, {
			Text = "You",
			LayoutOrder = #SLAYER_DATA + 1,
		}))

		table.insert(contentChildren, CompactRow(Scope, {
			Rank = PLAYER_ENTRY.rank,
			PlayerName = PLAYER_ENTRY.name,
			Bounty = PLAYER_ENTRY.bounty,
			Title = PLAYER_ENTRY.title,
			IsPlayer = true,
			AccentColor = SLAYER_ACCENT,
			LayoutOrder = #SLAYER_DATA + 2,
		}))

		-- Widget sizing math:
		-- Tab row: 34px
		-- 10 rows at 38px + 4px gap each = 420px
		-- Divider: ~30px + Player row: 38px + gaps
		-- Scroller content ~ 510px, Scroller gets remaining space
		-- Content: tabs(34) + gap(8) + scroller(remaining)
		-- Need ~570px usable content
		-- Widget overhead: HeadingBanner(104) + content padding(32) + LemonadeTag(24) = 160
		-- Total: 570 + 160 + 30 buffer = 760
		return Widget(Scope, CombineProps(Props, {
			Name = "HudLeaderboard",
			Size = Scope:UDim2Offset(380, 800),
			HeadingBanner = {
				Text = "Leaderboard",
				TextSize = Theme.TextSize["1.5"],
				CloseButton = { Hidden = true },
			},
			HideTag = true,
			[Children] = {
				Scope:New "UIListLayout" {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					Padding = Scope:UDim(0, Theme.Padding["0.5"]),
					SortOrder = Enum.SortOrder.LayoutOrder,
				},
				Scope:Frame {
					Name = "Tabs",
					Size = UDim2.new(1, 0, 0, 34),
					LayoutOrder = 0,
					List = {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = Scope:UDim(0, Theme.Padding["0.5"]),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
					[Children] = {
						TabButton(Scope, {
							Label = "Slayers",
							ActiveColor = SLAYER_ACCENT,
							IsActive = slayerActive,
							LayoutOrder = 1,
							OnActivate = function()
								activeTab:set("Slayers")
							end,
						}),
						TabButton(Scope, {
							Label = "Demons",
							ActiveColor = DEMON_ACCENT,
							IsActive = demonActive,
							LayoutOrder = 2,
							OnActivate = function()
								activeTab:set("Demons")
							end,
						}),
					},
				},
				Pane(Scope, {
					Size = UDim2.new(1, 0, 1, -42),
					LayoutOrder = 1,
					[Children] = {
						Scope:Scroller {
							Size = UDim2.fromScale(1, 1),
							ScrollBarThickness = 0,
							ScrollBarImageTransparency = 1,
							Padding = {},
							List = {
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = Scope:UDim(0, Theme.Padding["0.25"]),
							},
							[Children] = contentChildren,
						},
					},
				}),
			},
		}))
	end)
end
