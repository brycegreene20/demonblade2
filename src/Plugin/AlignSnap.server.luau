-- Align & Snap — alignment, grid-snap, distribute, and floor-fill for Roblox Studio

local Selection            = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ── Widget ────────────────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true, false,
	240, 560, 200, 300
)
local widget     = plugin:CreateDockWidgetPluginGui("DemonBlade2AlignSnap", widgetInfo)
widget.Title     = "Align & Snap"

local toolbar  = plugin:CreateToolbar("DemonBlade2")
local openBtn  = toolbar:CreateButton(
	"Align & Snap",
	"Open alignment and floor-fill tools  |  align edges · snap to grid · fill floors",
	"rbxassetid://6031065699"
)
openBtn.Click:Connect(function() widget.Enabled = not widget.Enabled end)

-- ── Scroll root ───────────────────────────────────────────────────────────────
local scroll = Instance.new("ScrollingFrame")
scroll.Size                 = UDim2.new(1, 0, 1, 0)
scroll.BackgroundColor3     = Color3.fromRGB(36, 36, 36)
scroll.BorderSizePixel      = 0
scroll.ScrollBarThickness   = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 90, 90)
scroll.Parent               = widget

local cy = 10  -- running Y cursor

-- ── UI helpers ────────────────────────────────────────────────────────────────
local function sectionHeader(title)
	local f       = Instance.new("Frame")
	f.Size        = UDim2.new(1, -16, 0, 22)
	f.Position    = UDim2.new(0, 8, 0, cy)
	f.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	f.BorderSizePixel  = 0
	f.Parent      = scroll
	local lbl = Instance.new("TextLabel")
	lbl.Size      = UDim2.new(1, -8, 1, 0)
	lbl.Position  = UDim2.new(0, 6, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text      = title
	lbl.TextColor3 = Color3.fromRGB(255, 200, 50)
	lbl.Font      = Enum.Font.GothamBold
	lbl.TextSize  = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent    = f
	cy += 28
end

local function rowLabel(text, x, w)
	local l = Instance.new("TextLabel")
	l.Size               = UDim2.new(0, w, 0, 26)
	l.Position           = UDim2.new(0, x, 0, cy)
	l.BackgroundTransparency = 1
	l.Text               = text
	l.TextColor3         = Color3.fromRGB(170, 170, 170)
	l.Font               = Enum.Font.Gotham
	l.TextSize           = 12
	l.TextXAlignment     = Enum.TextXAlignment.Left
	l.TextYAlignment     = Enum.TextYAlignment.Center
	l.Parent             = scroll
	return l
end

local function makeBtn(text, x, w, color, onClick)
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, w, 0, 26)
	b.Position         = UDim2.new(0, x, 0, cy)
	b.BackgroundColor3 = color or Color3.fromRGB(50, 95, 205)
	b.TextColor3       = Color3.new(1, 1, 1)
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = 11
	b.Text             = text
	b.BorderSizePixel  = 0
	b.AutoButtonColor  = true
	b.Parent           = scroll
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function makeBox(x, w, placeholder, default)
	local box = Instance.new("TextBox")
	box.Size             = UDim2.new(0, w, 0, 26)
	box.Position         = UDim2.new(0, x, 0, cy)
	box.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	box.TextColor3       = Color3.new(1, 1, 1)
	box.PlaceholderText  = placeholder or ""
	box.Text             = default or ""
	box.Font             = Enum.Font.Gotham
	box.TextSize         = 12
	box.BorderSizePixel  = 0
	box.ClearTextOnFocus = false
	box.Parent           = scroll
	return box
end

local function nextRow(h) cy += (h or 30) end
local function gap(h)     cy += (h or 8)  end

-- ── Geometry helpers ──────────────────────────────────────────────────────────
local function getBBox(inst)
	if inst:IsA("Model") then
		return inst:GetBoundingBox()
	elseif inst:IsA("BasePart") then
		return inst.CFrame, inst.Size
	end
	return nil, nil
end

local function axVal(v3, ax)
	return ax == "X" and v3.X or ax == "Y" and v3.Y or v3.Z
end

local function withAxis(v3, ax, val)
	if ax == "X" then return Vector3.new(val, v3.Y, v3.Z) end
	if ax == "Y" then return Vector3.new(v3.X, val, v3.Z) end
	return Vector3.new(v3.X, v3.Y, val)
end

local function halfOn(sz, ax)
	return ax == "X" and sz.X / 2 or ax == "Y" and sz.Y / 2 or sz.Z / 2
end

local function moveInst(inst, newBboxCenter)
	if inst:IsA("Model") then
		local bboxCF, _ = inst:GetBoundingBox()
		local pivot      = inst:GetPivot()
		local offset     = pivot.Position - bboxCF.Position
		inst:PivotTo(CFrame.new(newBboxCenter + offset) * pivot.Rotation)
	elseif inst:IsA("BasePart") then
		inst.CFrame = CFrame.new(newBboxCenter) * inst.CFrame.Rotation
	end
end

-- ── Align ─────────────────────────────────────────────────────────────────────
local function alignAxis(ax, side)
	local sel = Selection:Get()
	if #sel < 2 then warn("[AlignSnap] Select 2 or more instances") return end

	local target, count = nil, 0
	for _, inst in sel do
		local cf, sz = getBBox(inst)
		if not cf then continue end
		local c    = cf.Position
		local half = halfOn(sz, ax)
		local v = side == "min" and axVal(c, ax) - half
		       or side == "max" and axVal(c, ax) + half
		       or axVal(c, ax)
		target = target and (side == "min" and math.min(target, v)
		                  or side == "max" and math.max(target, v)
		                  or target + v)
		       or v
		count += 1
	end
	if side == "center" and count > 0 then target /= count end

	ChangeHistoryService:SetWaypoint("Before Align")
	for _, inst in sel do
		local cf, sz = getBBox(inst)
		if not cf then continue end
		local half   = halfOn(sz, ax)
		local newC   = side == "min" and target + half
		            or side == "max" and target - half
		            or target
		moveInst(inst, withAxis(cf.Position, ax, newC))
	end
	ChangeHistoryService:SetWaypoint("After Align")
end

-- ── Distribute ────────────────────────────────────────────────────────────────
local function distribute(ax)
	local sel = Selection:Get()
	if #sel < 3 then warn("[AlignSnap] Select 3 or more instances") return end

	local items = {}
	for _, inst in sel do
		local cf, _ = getBBox(inst)
		if cf then items[#items + 1] = { inst = inst, v = axVal(cf.Position, ax) } end
	end
	table.sort(items, function(a, b) return a.v < b.v end)

	local first = items[1].v
	local step  = (items[#items].v - first) / (#items - 1)

	ChangeHistoryService:SetWaypoint("Before Distribute")
	for i, entry in items do
		local cf, _ = getBBox(entry.inst)
		if cf then moveInst(entry.inst, withAxis(cf.Position, ax, first + (i - 1) * step)) end
	end
	ChangeHistoryService:SetWaypoint("After Distribute")
end

-- ── Snap to grid ──────────────────────────────────────────────────────────────
local function snapToGrid(gridSize)
	local sel = Selection:Get()
	if #sel == 0 then warn("[AlignSnap] Nothing selected") return end
	local function snap(v) return math.round(v / gridSize) * gridSize end
	ChangeHistoryService:SetWaypoint("Before Grid Snap")
	for _, inst in sel do
		local cf, _ = getBBox(inst)
		if cf then
			local p = cf.Position
			moveInst(inst, Vector3.new(snap(p.X), snap(p.Y), snap(p.Z)))
		end
	end
	ChangeHistoryService:SetWaypoint("After Grid Snap")
end

-- ── Floor fill ────────────────────────────────────────────────────────────────
local floorTemplate = nil
local templateLabel = nil

local function setTemplate()
	local sel = Selection:Get()
	if #sel == 0 then warn("[AlignSnap] Select a tile to use as template") return end
	floorTemplate = sel[1]
	if templateLabel then
		templateLabel.Text       = "✓ " .. floorTemplate.Name
		templateLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
	end
end

local function fillFloor(cntXBox, cntZBox)
	if not floorTemplate or not floorTemplate.Parent then
		warn("[AlignSnap] Set a template first")
		return
	end
	local cx = math.max(1, math.floor(tonumber(cntXBox.Text) or 5))
	local cz = math.max(1, math.floor(tonumber(cntZBox.Text) or 5))

	local cf, sz = getBBox(floorTemplate)
	if not cf then warn("[AlignSnap] Could not read template bounding box") return end

	local origin = cf.Position

	ChangeHistoryService:SetWaypoint("Before Floor Fill")
	local folder  = Instance.new("Folder")
	folder.Name   = "FloorFill"
	folder.Parent = workspace

	for xi = 0, cx - 1 do
		for zi = 0, cz - 1 do
			if xi == 0 and zi == 0 then continue end
			local clone = floorTemplate:Clone()
			clone.Parent = folder
			moveInst(clone, Vector3.new(
				origin.X + xi * sz.X,
				origin.Y,
				origin.Z + zi * sz.Z
			))
		end
	end
	ChangeHistoryService:SetWaypoint("After Floor Fill")
	print(("[AlignSnap] Placed %d x %d tiles"):format(cx, cz))
end

-- ── Build UI ──────────────────────────────────────────────────────────────────

-- ALIGN
sectionHeader("ALIGN")

rowLabel("X :", 8, 24)
makeBtn("◄ Left",   34, 58, nil, function() alignAxis("X", "min")    end)
makeBtn("Center",   96, 58, nil, function() alignAxis("X", "center") end)
makeBtn("Right ►", 158, 58, nil, function() alignAxis("X", "max")    end)
nextRow()

rowLabel("Y :", 8, 24)
makeBtn("▼ Bot",   34, 58, nil, function() alignAxis("Y", "min")    end)
makeBtn("Middle",  96, 58, nil, function() alignAxis("Y", "center") end)
makeBtn("Top ▲",  158, 58, nil, function() alignAxis("Y", "max")    end)
nextRow()

rowLabel("Z :", 8, 24)
makeBtn("Front ◄",  34, 58, nil, function() alignAxis("Z", "min")    end)
makeBtn("Center",   96, 58, nil, function() alignAxis("Z", "center") end)
makeBtn("► Back",  158, 58, nil, function() alignAxis("Z", "max")    end)
nextRow()
gap(4)

makeBtn("Distribute X",   8, 107, Color3.fromRGB(80, 55, 160), function() distribute("X") end)
makeBtn("Distribute Z", 119, 107, Color3.fromRGB(80, 55, 160), function() distribute("Z") end)
nextRow()
gap(12)

-- SNAP TO GRID
sectionHeader("SNAP TO GRID")

rowLabel("Grid :", 8, 42)
local gridBox = makeBox(54, 58, "studs", "4")
makeBtn("Snap Selected", 116, 108, Color3.fromRGB(160, 90, 20), function()
	local g = tonumber(gridBox.Text)
	if not g or g <= 0 then warn("[AlignSnap] Enter a positive grid size") return end
	snapToGrid(g)
end)
nextRow()
gap(12)

-- FLOOR FILL
sectionHeader("FLOOR FILL")

makeBtn("1. Set Template", 8, 210, Color3.fromRGB(30, 110, 75), setTemplate)
nextRow()

templateLabel = Instance.new("TextLabel")
templateLabel.Size               = UDim2.new(1, -16, 0, 18)
templateLabel.Position           = UDim2.new(0, 8, 0, cy)
templateLabel.BackgroundTransparency = 1
templateLabel.Text               = "(no template — select a tile and click above)"
templateLabel.TextColor3         = Color3.fromRGB(130, 130, 130)
templateLabel.Font               = Enum.Font.Gotham
templateLabel.TextSize           = 11
templateLabel.TextXAlignment     = Enum.TextXAlignment.Left
templateLabel.Parent             = scroll
cy += 22

rowLabel("X tiles:", 8, 54)
local cntXBox = makeBox(66, 52, "#", "5")
rowLabel("Z tiles:", 124, 54)
local cntZBox = makeBox(182, 44, "#", "5")
nextRow()

makeBtn("2. Fill Floor", 8, 210, Color3.fromRGB(20, 140, 20), function()
	fillFloor(cntXBox, cntZBox)
end)
nextRow()
gap(16)

scroll.CanvasSize = UDim2.new(0, 0, 0, cy)
