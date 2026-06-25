local UIController = {}

function UIController.init()
	-- Initialize all HUD elements (HP bar, stamina bar, etc.)
end

function UIController.updateHPBar(_currentHP, _maxHP)
	-- Update the HP bar fill and text
end

function UIController.updateStaminaBar(_currentStamina, _maxStamina)
	-- Update the stamina bar fill and text
end

function UIController.showDamageNumber(_position, _amount, _isCritical)
	-- Display a floating damage number at world position via BillboardGui
end

function UIController.showDeathScreen()
	-- Display death overlay with respawn countdown
end

function UIController.hideDeathScreen()
	-- Remove death overlay on respawn
end

function UIController.showCooldownIndicator(_skillName, _duration)
	-- Display a cooldown sweep for a skill/ability
end

return UIController