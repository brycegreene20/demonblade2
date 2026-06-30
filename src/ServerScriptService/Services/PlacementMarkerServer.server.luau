local MARKERS_FOLDER_NAME = "DemonBlade2Markers"

local markersFolder = workspace:FindFirstChild(MARKERS_FOLDER_NAME)
if markersFolder then
	local hiddenParts = 0
	for _, descendant in markersFolder:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			hiddenParts += 1
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = false
		end
	end
	print(("[PlacementMarkerServer] Hid %d placement marker part(s)"):format(hiddenParts))
end
