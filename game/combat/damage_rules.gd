class_name DamageRules
extends RefCounted

const ACCEPTED: StringName = &"ACCEPTED"
const AMOUNT_INVALID: StringName = &"AMOUNT_INVALID"
const ALREADY_DEFEATED: StringName = &"ALREADY_DEFEATED"

static func plan(current_health: int, amount: int) -> Dictionary:
	if amount <= 0:
		return {"accepted": false, "reason": AMOUNT_INVALID}
	if current_health <= 0:
		return {"accepted": false, "reason": ALREADY_DEFEATED}
	var applied := mini(current_health, amount)
	return {"accepted": true, "reason": ACCEPTED, "applied": applied, "remaining": current_health - applied, "defeated": current_health <= amount}
