class_name SimLevel
extends RefCounted


static func xp_for_level(xp_base: float, xp_growth: float, level: int) -> float:
	return roundf(xp_base * pow(xp_growth, float(level - 1)))


static func grant_xp(world: SimWorld, amount: float) -> void:
	if amount <= 0.0:
		return
	var loop: Dictionary = world.catalog.loop
	world.xp += amount
	while world.xp >= world.xp_need:
		world.xp -= world.xp_need
		world.level += 1
		world.pending_levels += 1
		world.xp_need = xp_for_level(float(loop.get("xpBase", 32.0)), float(loop.get("xpGrowth", 1.3)), world.level)
	if world.pending_levels > 0 and world.phase == &"play":
		world.phase = &"levelup"
		world.offer = roll_choices(world)


static func roll_choices(world: SimWorld) -> Array[Dictionary]:
	var count: int = int(world.catalog.loop.get("levelChoices", 3))
	var none_owned: Dictionary = {}
	for inst: ItemInstance in world.inventory:
		if String(world.catalog.item(inst.id).get("stack", "linear")) == "none":
			none_owned[inst.id] = true
	var unlocked_pool: Array[Dictionary] = []
	for item_def: Dictionary in world.catalog.items:
		var id: String = String(item_def.get("id", ""))
		if world.unlocked_items.has(id) and not none_owned.has(id):
			unlocked_pool.append(item_def)
	var pool: Array[Dictionary] = unlocked_pool
	if pool.is_empty():
		for item_def: Dictionary in world.catalog.items:
			if not none_owned.has(String(item_def.get("id", ""))):
				pool.append(item_def)
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	var picked: Array[Dictionary] = []
	var used: Dictionary = {}
	for _n: int in count:
		var remaining: Array[Dictionary] = []
		for entry: Dictionary in pool:
			if not used.has(String(entry.get("id", ""))):
				remaining.append(entry)
		var item: Dictionary = _weighted_pick(remaining, DictUtil.d(world.catalog.loop, "rarityWeight"), world.offer_rng)
		if item.is_empty():
			break
		used[String(item.get("id", ""))] = true
		picked.append(item)
	return picked


static func apply_choice(world: SimWorld, index: int) -> bool:
	if world.phase != &"levelup" or world.offer.is_empty():
		return false
	if index < 0 or index >= world.offer.size():
		return false
	var pick: Dictionary = world.offer[index]
	_add_item(world, String(pick.get("id", "")))
	sync_stats(world)
	world.pending_levels = maxi(0, world.pending_levels - 1)
	if world.pending_levels > 0:
		world.offer = roll_choices(world)
		return true
	world.offer.clear()
	world.phase = &"victory" if world.won else &"play"
	return true


static func sync_stats(world: SimWorld) -> void:
	var prev_max: float = world.player.max_hp
	world.stats = SimStats.resolve(world.survivor.get("stats", {}), world.inventory, world.catalog)
	var next_max: float = world.stats.max_hp
	world.player.max_hp = next_max
	world.player.radius = world.stats.radius
	world.player.speed = world.stats.speed
	world.player.hp = minf(next_max, maxf(1.0, world.player.hp + (next_max - prev_max)))


static func _add_item(world: SimWorld, id: String) -> void:
	var def: Dictionary = world.catalog.item(id)
	for inst: ItemInstance in world.inventory:
		if inst.id == id and String(def.get("stack", "linear")) == "linear":
			inst.stacks += 1
			return
	var exists: bool = false
	for inst: ItemInstance in world.inventory:
		if inst.id == id:
			exists = true
			break
	if not exists:
		world.inventory.append(ItemInstance.make(id, 1))


static func _weighted_pick(pool: Array[Dictionary], weights: Dictionary, rng: SimRng) -> Dictionary:
	if pool.is_empty():
		return {}
	var total: float = 0.0
	for item: Dictionary in pool:
		total += float(weights.get(String(item.get("rarity", "common")), 1.0))
	var roll: float = rng.next() * total
	for item: Dictionary in pool:
		roll -= float(weights.get(String(item.get("rarity", "common")), 1.0))
		if roll <= 0.0:
			return item
	return pool[pool.size() - 1]
