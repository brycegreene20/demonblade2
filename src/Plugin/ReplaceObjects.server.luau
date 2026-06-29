-- Replace Objects — swap objects in the map with a chosen replacement

local Selection            = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

-- ── Widget ────────────────────────────────────────────────────────────────────
local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	true, false,
	240, 440, 200, 300
)
local widget  = plugin:CreateDockWidgetPluginGui("DemonBlade2ReplaceObjects", widgetInfo)
widget.Title  = "Replace Objects"

local toolbar = plugin:CreateToolbar("DemonBlade2")
local openBtn = toolbar:CreateButton(
	"Replace Objects",
	"Swap map objects with a chosen replacement, preserving position and rotation",
	"rbxassetid://6031068421"
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

local cy = 10

-- ── UI helpers ────────────────────────────────────────────────────────────────
local function sectionHeader(title)
	local f = Instance.new("Frame")
	f.Size             = UDim2.new(1, -16, 0, 22)
	f.Position         = UDim2.new(0, 8, 0, cy)
	f.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	f.BorderSizePixel  = 0
	f.Parent           = scroll
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -8, 1, 0)
	lbl.Position           = UDim2.new(0, 6, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = title
	lbl.TextColor3         = Color3.fromRGB(255, 200, 50)
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = f
	cy += 28
end

local function makeBtn(text, x, w, color, onClick)
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(0, w, 0, 28)
	b.Position         = UDim2.new(0, x, 0, cy)
	b.BackgroundColor3 = color or Color3.fromRGB(50, 95, 205)
	b.TextColor3       = Color3.new(1, 1, 1)
	b.Font             = Enum.Font.GothamBold
	b.TextSize         = 12
	b.Text             = text
	b.BorderSizePixel  = 0
	b.AutoButtonColor  = true
	b.Parent           = scroll
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function makeInfoLabel(defaultText)
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -16, 0, 18)
	lbl.Position           = UDim2.new(0, 8, 0, cy)
	lbl.BackgroundTransparency = 1
	lbl.Text               = defaultText
	lbl.TextColor3         = Color3.fromRGB(130, 130, 130)
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 11
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = scroll
	cy += 22
	return lbl
end

local toggleState = {}

local function makeToggle(text, defaultOn)
	local state = { on = defaultOn }
	toggleState[#toggleState + 1] = state
	local b = Instance.new("TextButton")
	b.Size             = UDim2.new(1, -16, 0, 26)
	b.Position         = UDim2.new(0, 8, 0, cy)
	b.BackgroundColor3 = Color3.fromRGB(48, 48, 48)
	b.TextColor3       = Color3.fromRGB(210, 210, 210)
	b.Font             = Enum.Font.Gotham
	b.TextSize         = 12
	b.TextXAlignment   = Enum.TextXAlignment.Left
	b.BorderSizePixel  = 0
	b.AutoButtonColor  = true
	b.Parent           = scroll
	local function refresh()
		b.Text = (state.on and "  ☑  " or "  ☐  ") .. text
		b.TextColor3 = state.on and Color3.fromRGB(220, 220, 220) or Color3.fromRGB(140, 140, 140)
	end
	refresh()
	b.MouseButton1Click:Connect(function()
		state.on = not state.on
		refresh()
	end)
	cy += 30
	return state
end

local function nextRow(h) cy += (h or 32) end
local function gap(h)     cy += (h or 8)  end

-- ── Geometry helpers ──────────────────────────────────────────────────────────
local function getPivotCF(inst)
	if inst:IsA("Model")    then return inst:GetPivot() end
	if inst:IsA("BasePart") then return inst.CFrame end
	return nil
end

local function getBBoxSize(inst)
	if inst:IsA("Model")    then local _, sz = inst:GetBoundingBox() return sz end
	if inst:IsA("BasePart") then return inst.Size end
	return nil
end

local function applyPivot(inst, cf)
	if inst:IsA("Model")    then inst:PivotTo(cf) end
	if inst:IsA("BasePart") then inst.CFrame = cf end
end

-- ── Replace logic ─────────────────────────────────────────────────────────────
local sourceObj = nil
local targetObj = nil
local sourceLbl = nil
local targetLbl = nil

local matchByNameState = nil
local matchSizeState   = nil

local function setSource()
	local sel = Selection:Get()
	if #sel == 0 then warn("[ReplaceObjects] Select an object to use as source") return end
	sourceObj = sel[1]
	if sourceLbl then
		sourceLbl.Text       = "✓ " .. sourceObj.Name
		sourceLbl.TextColor3 = Color3.fromRGB(255, 170, 60)
	end
end

local function setTarget()
	local sel = Selection:Get()
	if #sel == 0 then warn("[ReplaceObjects] Select an object to use as target") return end
	targetObj = sel[1]
	if targetLbl then
		targetLbl.Text       = "✓ " .. targetObj.Name
		targetLbl.TextColor3 = Color3.fromRGB(80, 210, 255)
	end
end

local function replaceOne(src, tgt, matchSize)
	local pivotCF = getPivotCF(src)
	local srcSize = getBBoxSize(src)
	if not pivotCF then return end

	local clone = tgt:Clone()
	clone.Parent = src.Parent or workspace

	if matchSize and srcSize then
		if clone:IsA("Model") then
			local cloneSz = getBBoxSize(clone)
			if cloneSz and cloneSz.X > 0 and cloneSz.Y > 0 and cloneSz.Z > 0 then
				local scale = (srcSize.X / cloneSz.X + srcSize.Y / cloneSz.Y + srcSize.Z / cloneSz.Z) / 3
				pcall(function() clone:ScaleTo(scale) end)
			end
		elseif clone:IsA("BasePart") then
			clone.Size = srcSize
		end
	end

	applyPivot(clone, pivotCF)
	src:Destroy()
end

local function doReplace()
	if not sourceObj then warn("[ReplaceObjects] Set a source object first") return end
	if not targetObj then warn("[ReplaceObjects] Set a target object first") return end
	if sourceObj == targetObj then warn("[ReplaceObjects] Source and target are the same") return end

	local matchByName = matchByNameState and matchByNameState.on
	local matchSize   = matchSizeState   and matchSizeState.on

	local targets = {}

	if matchByName then
		-- Collect all workspace descendants with the same name
		for _, inst in workspace:GetDescendants() do
			if inst.Name == sourceObj.Name
				and (inst:IsA("Model") or inst:IsA("BasePart"))
				and inst ~= targetObj then
				targets[#targets + 1] = inst
			end
		end
		if #targets == 0 then
			warn(('[ReplaceObjects] No instances named "%s" found in workspace'):format(sourceObj.Name))
			return
		end
	else
		-- Replace only selected instances that share the source name
		for _, inst in Selection:Get() do
			if inst ~= targetObj
				and (inst:IsA("Model") or inst:IsA("BasePart")) then
				targets[#targets + 1] = inst
			end
		end
		if #targets == 0 then
			warn("[ReplaceObjects] Nothing selected to replace (or you only selected the target)")
			return
		end
	end

	ChangeHistoryService:SetWaypoint("Before Replace Objects")
	local count = #targets
	for _, inst in targets do
		replaceOne(inst, targetObj, matchSize)
	end
	ChangeHistoryService:SetWaypoint("After Replace Objects")

	print(("[ReplaceObjects] Replaced %d instance(s) with '%s'"):format(count, targetObj.Name))
end

-- ── Build UI ──────────────────────────────────────────────────────────────────

-- SOURCE
sectionHeader("SOURCE  (object to replace)")
makeBtn("Set Source", 8, 210, Color3.fromRGB(160, 90, 20), setSource)
nextRow()
sourceLbl = makeInfoLabel("(select an object and click Set Source)")

gap(8)

-- TARGET
sectionHeader("TARGET  (replacement object)")
makeBtn("Set Target", 8, 210, Color3.fromRGB(30, 100, 160), setTarget)
nextRow()
targetLbl = makeInfoLabel("(select an object and click Set Target)")

gap(8)

-- OPTIONS
sectionHeader("OPTIONS")
matchByNameState = makeToggle("Replace ALL with same name in Workspace", true)
matchSizeState   = makeToggle("Match size of original", false)

gap(4)

-- REPLACE
makeBtn("REPLACE", 8, 210, Color3.fromRGB(160, 30, 30), doReplace)
nextRow()

local hintLbl = Instance.new("TextLabel")
hintLbl.Size               = UDim2.new(1, -16, 0, 32)
hintLbl.Position           = UDim2.new(0, 8, 0, cy)
hintLbl.BackgroundTransparency = 1
hintLbl.Text               = "Tip: turn off 'by name' to replace only\nyour current selection"
hintLbl.TextColor3         = Color3.fromRGB(110, 110, 110)
hintLbl.Font               = Enum.Font.Gotham
hintLbl.TextSize           = 11
hintLbl.TextXAlignment     = Enum.TextXAlignment.Left
hintLbl.TextWrapped        = true
hintLbl.Parent             = scroll
cy += 40

scroll.CanvasSize = UDim2.new(0, 0, 0, cy)
