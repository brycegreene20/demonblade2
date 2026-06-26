local ItemsModule = {}

ItemsModule.SCROLLS = {
	WaterBreathingScroll = {
		Id = "WaterBreathingScroll",
		Name = "Water Breathing Scroll",
		Style = "WaterBreathing",
		Faction = "Slayer",
		Icon = "📜",
		Description = "Ancient scroll teaching the Water Breathing style. Six forms of the water-god.",
		Rarity = "Common",
		Color = Color3.fromRGB(40, 140, 255),
	},
	FlameBreathingScroll = {
		Id = "FlameBreathingScroll",
		Name = "Flame Breathing Scroll",
		Style = "FlameBreathing",
		Faction = "Slayer",
		Icon = "📜",
		Description = "Rare scroll containing the secrets of Flame Breathing, passed down by the Rengoku family.",
		Rarity = "Rare",
		Color = Color3.fromRGB(255, 80, 20),
	},
	DemonArtFruit = {
		Id = "DemonArtFruit",
		Name = "Blood Demon Art Fruit",
		Style = "DemonArts",
		Faction = "Demon",
		Icon = "🍎",
		Description = "A cursed fruit that awakens Blood Demon Arts within the consumer.",
		Rarity = "Common",
		Color = Color3.fromRGB(180, 20, 40),
	},
	TemariDemonFruit = {
		Id = "TemariDemonFruit",
		Name = "Temari Demon Fruit",
		Style = "TemariDemonArts",
		Faction = "Demon",
		Icon = "🍊",
		Description = "A strange round fruit pulsing with demonic energy. Grants mastery of Temari Demon Arts.",
		Rarity = "Rare",
		Color = Color3.fromRGB(180, 60, 220),
	},
}

ItemsModule.STARTER_STYLE_ITEMS = {
	"WaterBreathingScroll",
	"FlameBreathingScroll",
	"DemonArtFruit",
	"TemariDemonFruit",
}

function ItemsModule.getScroll(scrollId)
	return ItemsModule.SCROLLS[scrollId]
end

function ItemsModule.getScrollByStyle(style)
	for _, scroll in ItemsModule.SCROLLS do
		if scroll.Style == style then
			return scroll
		end
	end
	return nil
end

function ItemsModule.getScrollsForFaction(faction)
	local result = {}
	for _, scroll in ItemsModule.SCROLLS do
		if scroll.Faction == faction then
			table.insert(result, scroll)
		end
	end
	return result
end

function ItemsModule.getAllScrolls()
	local result = {}
	for _, scroll in ItemsModule.SCROLLS do
		table.insert(result, scroll)
	end
	table.sort(result, function(a, b)
		return (a.Name or a.Id) < (b.Name or b.Id)
	end)
	return result
end

function ItemsModule.canEquipForFaction(scrollId, _faction)
	local scroll = ItemsModule.getScroll(scrollId)
	if not scroll then
		return false
	end

	-- Titles are independent from equipped scrolls/fruits. Keep this helper for
	-- older callers, but do not block cross-title build-craft.
	return true
end

function ItemsModule.hasItem(inventory, itemId)
	for _, id in inventory do
		if id == itemId then
			return true
		end
	end
	return false
end

return ItemsModule
