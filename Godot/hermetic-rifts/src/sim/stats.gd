class_name SimStats
extends RefCounted

const MIN_RADIUS_RATIO: float = 0.5
const MAX_RADIUS_RATIO: float = 2.0


static func resolve(base: Dictionary, inventory: Array[ItemInstance], catalog: Catalog) -> ResolvedStats:
	var add: Dictionary = _zero()
	var pct: Dictionary = _zero()
	for inst: ItemInstance in inventory:
		var def: Dictionary = catalog.item(inst.id)
		var stacks: int = 1 if String(def.get("stack", "linear")) == "none" else maxi(1, inst.stacks)
		for hook: Variant in def.get("hooks", []):
			var h: Dictionary = hook
			var op: String = String(h.get("op", ""))
			if op == "on-kill" or op == "on-crit":
				continue
			var stat: String = String(h.get("stat", ""))
			var amount: float = float(h.get("value", 0.0)) * float(stacks)
			if op == "add":
				add[stat] = float(add.get(stat, 0.0)) + amount
			elif op == "pct":
				pct[stat] = float(pct.get(stat, 0.0)) + amount
	var stats := ResolvedStats.new()
	var base_radius: float = float(base.get("radius", 14.0))
	if base_radius <= 0.0:
		base_radius = 14.0
	var raw_radius: float = (float(base.get("radius", 14.0)) + float(add.get("radius", 0.0))) * (1.0 + float(pct.get("radius", 0.0)))
	var min_radius: float = maxf(1.0, base_radius * MIN_RADIUS_RATIO)
	var max_radius: float = maxf(min_radius, base_radius * MAX_RADIUS_RATIO)
	stats.speed = (float(base.get("speed", 0.0)) + float(add.get("speed", 0.0))) * (1.0 + float(pct.get("speed", 0.0)))
	stats.max_hp = (float(base.get("maxHp", 0.0)) + float(add.get("maxHp", 0.0))) * (1.0 + float(pct.get("maxHp", 0.0)))
	stats.radius = clampf(raw_radius, min_radius, max_radius)
	stats.damage_mul = (1.0 + float(add.get("damage", 0.0))) * (1.0 + float(pct.get("damage", 0.0)))
	stats.cooldown_mul = (1.0 + float(add.get("cooldown", 0.0))) * (1.0 + float(pct.get("cooldown", 0.0)))
	stats.crit_chance = clampf(float(base.get("critChance", 0.05)) + float(add.get("critChance", 0.0)) + float(pct.get("critChance", 0.0)), 0.0, 1.0)
	stats.crit_mul = maxf(1.0, float(base.get("critDamage", 2.0)) + float(add.get("critDamage", 0.0)) + float(pct.get("critDamage", 0.0)))
	stats.armor = clampf(float(add.get("armor", 0.0)) + float(pct.get("armor", 0.0)), -1.0, 0.75)
	stats.hazard_resist = clampf(float(add.get("hazardResist", 0.0)) + float(pct.get("hazardResist", 0.0)), 0.0, 0.85)
	stats.hp_regen = maxf(0.0, float(add.get("hpRegen", 0.0)) * (1.0 + float(pct.get("hpRegen", 0.0))))
	stats.pickup_radius_mul = maxf(0.25, (1.0 + float(add.get("pickupRadius", 0.0))) * (1.0 + float(pct.get("pickupRadius", 0.0))))
	stats.xp_mul = maxf(0.1, (1.0 + float(add.get("xpGain", 0.0))) * (1.0 + float(pct.get("xpGain", 0.0))))
	stats.aoe_radius_mul = maxf(0.25, (1.0 + float(add.get("aoeRadius", 0.0))) * (1.0 + float(pct.get("aoeRadius", 0.0))))
	stats.proj_speed_mul = maxf(0.25, (1.0 + float(add.get("projSpeed", 0.0))) * (1.0 + float(pct.get("projSpeed", 0.0))))
	stats.control_duration_mul = maxf(0.25, (1.0 + float(add.get("controlDuration", 0.0))) * (1.0 + float(pct.get("controlDuration", 0.0))))
	stats.elite_damage_mul = maxf(0.25, (1.0 + float(add.get("eliteDamage", 0.0))) * (1.0 + float(pct.get("eliteDamage", 0.0))))
	return stats


static func on_kill_heal(inventory: Array[ItemInstance], catalog: Catalog) -> float:
	var heal: float = 0.0
	for inst: ItemInstance in inventory:
		var def: Dictionary = catalog.item(inst.id)
		var stacks: int = 1 if String(def.get("stack", "linear")) == "none" else maxi(1, inst.stacks)
		for hook: Variant in def.get("hooks", []):
			var h: Dictionary = hook
			if String(h.get("op", "")) == "on-kill" and String(h.get("stat", "")) == "hp":
				heal += float(h.get("value", 0.0)) * float(stacks)
	return heal


static func on_crit_cooldown_refund(inventory: Array[ItemInstance], catalog: Catalog) -> float:
	var refund: float = 0.0
	for inst: ItemInstance in inventory:
		var def: Dictionary = catalog.item(inst.id)
		var stacks: int = 1 if String(def.get("stack", "linear")) == "none" else maxi(1, inst.stacks)
		for hook: Variant in def.get("hooks", []):
			var h: Dictionary = hook
			if String(h.get("op", "")) == "on-crit" and String(h.get("stat", "")) == "cooldown":
				refund += float(h.get("value", 0.0)) * float(stacks)
	return refund


static func _zero() -> Dictionary:
	return {
		"speed": 0.0,
		"maxHp": 0.0,
		"radius": 0.0,
		"damage": 0.0,
		"cooldown": 0.0,
		"critChance": 0.0,
		"critDamage": 0.0,
		"armor": 0.0,
		"hazardResist": 0.0,
		"hpRegen": 0.0,
		"pickupRadius": 0.0,
		"xpGain": 0.0,
		"aoeRadius": 0.0,
		"projSpeed": 0.0,
		"controlDuration": 0.0,
		"eliteDamage": 0.0,
	}
