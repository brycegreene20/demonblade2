local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local _ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _LocalPlayer = Players.LocalPlayer
local InputModeValue = ReplicatedStorage:WaitForChild("InputMode")

local GAMEPAD_INPUT_TYPES = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local KEYBOARD_INPUT_TYPES = {
	[Enum.UserInputType.Keyboard] = true,
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseMovement] = true,
}

local function detectGamepadType()
	local mapped = UserInputService:GetStringForKeyCode(Enum.KeyCode.ButtonA)
	if mapped == "ButtonCross" then
		return "PlayStation"
	end
	return "Xbox"
end

local function updateInputMode(inputType)
	if GAMEPAD_INPUT_TYPES[inputType] then
		local gamepadType = detectGamepadType()
		if InputModeValue.Value ~= gamepadType then
			InputModeValue.Value = gamepadType
		end
	elseif KEYBOARD_INPUT_TYPES[inputType] then
		if InputModeValue.Value ~= "Keyboard" then
			InputModeValue.Value = "Keyboard"
		end
	end
end

UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
	updateInputMode(lastInputType)
end)

UserInputService.GamepadConnected:Connect(function()
	if GAMEPAD_INPUT_TYPES[UserInputService:GetLastInputType()] then
		local gamepadType = detectGamepadType()
		if InputModeValue.Value ~= gamepadType then
			InputModeValue.Value = gamepadType
		end
	end
end)

updateInputMode(UserInputService:GetLastInputType())

-- selene: allow(global_usage)
_G.InputMode = InputModeValue

print("[ControllerMapper] Loaded - InputMode: " .. InputModeValue.Value)