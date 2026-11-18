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
		world.is_bonus_draft = false
		world.phase = &"levelup"
		world.offer = roll_choices(world)


static func _eligible_pool(world: SimWorld) -> Array[Dictionary]:
	var none_owned: Dictionary = {}
	for inst: ItemInstance in world.inventory:
		if String(world.catalog.item(inst.id).get("stack", "linear")) == "none":
			none_owned[inst.id] = true
	var unlocked_pool: Array[Dictionary] = []
	var fallback_pool: Array[Dictionary] = []
	for item_def: Dictionary in world.catalog.items:
		var id: String = String(item_def.get("id", ""))
		if id == "" or id == "philosophers-catalyst" or bool(item_def.get("secretVaultOnly", false)):
			continue
		if world.banished_items.has(id) or none_owned.has(id):
			continue
		fallback_pool.append(item_def)
		if world.unlocked_items.has(id):
			unlocked_pool.append(item_def)
	var pool: Array[Dictionary] = unlocked_pool if not unlocked_pool.is_empty() else fallback_pool
	pool.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return pool


static func roll_choices(world: SimWorld) -> Array[Dictionary]:
	var count: int = int(world.catalog.loop.get("levelChoices", 3))
	var pool: Array[Dictionary] = _eligible_pool(world)
	var picked: Array[Dictionary] = []
	var used: Dictionary = {}
	if world.locked_item_id != "":
		var locked_id: String = world.locked_item_id
		world.locked_item_id = ""
		for entry: Dictionary in pool:
			if String(entry.get("id", "")) == locked_id:
				picked.append(entry)
				used[locked_id] = true
				break
	var weights: Dictionary = DictUtil.d(world.catalog.loop, "rarityWeight")
	while picked.size() < count:
		var remaining: Array[Dictionary] = []
		for entry: Dictionary in pool:
			if not used.has(String(entry.get("id", ""))):
				remaining.append(entry)
		var item: Dictionary = _weighted_pick(remaining, weights, world.offer_rng)
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
	if world.is_bonus_draft:
		world.is_bonus_draft = false
	else:
		world.pending_levels = maxi(0, world.pending_levels - 1)
	if world.pending_levels > 0:
		world.offer = roll_choices(world)
		return true
	if world.pending_bonus_drafts > 0:
		world.is_bonus_draft = true
		world.pending_bonus_drafts -= 1
		world.offer = roll_choices(world)
		return true
	world.offer.clear()
	world.phase = &"victory" if world.won else &"play"
	return true


static func reroll_choices(world: SimWorld) -> bool:
	if world.phase != &"levelup" or world.rerolls_left <= 0:
		return false
	world.rerolls_left -= 1
	world.offer = roll_choices(world)
	return true


static func banish_choice(world: SimWorld, index: int) -> bool:
	if world.phase != &"levelup" or world.banishes_left <= 0:
		return false
	if index < 0 or index >= world.offer.size():
		return false
	var id: String = String(world.offer[index].get("id", ""))
	if id == "":
		return false
	world.banished_items[id] = true
	if world.locked_item_id == id:
		world.locked_item_id = ""
	world.banishes_left -= 1
	var used: Dictionary = {}
	for i: int in world.offer.size():
		if i == index:
			continue
		used[String(world.offer[i].get("id", ""))] = true
	var pool: Array[Dictionary] = _eligible_pool(world)
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in pool:
		if not used.has(String(entry.get("id", ""))):
			remaining.append(entry)
	var replacement: Dictionary = _weighted_pick(remaining, DictUtil.d(world.catalog.loop, "rarityWeight"), world.offer_rng)
	if not replacement.is_empty():
		world.offer[index] = replacement
	else:
		world.offer.remove_at(index)
	return true


static func toggle_lock_choice(world: SimWorld, index: int) -> bool:
	if world.phase != &"levelup" or world.offer.is_empty():
		return false
	if index < 0 or index >= world.offer.size():
		return false
	var id: String = String(world.offer[index].get("id", ""))
	if id == "":
		return false
	if world.locked_item_id == id:
		world.locked_item_id = ""
		world.locks_left += 1
		return true
	if world.locks_left <= 0:
		return false
	if world.locked_item_id == "":
		world.locks_left -= 1
	world.locked_item_id = id
	return true


static func open_bonus_draft_if_ready(world: SimWorld) -> bool:
	if world.pending_bonus_drafts <= 0 or world.phase != &"play":
		return false
	world.phase = &"levelup"
	world.is_bonus_draft = true
	world.pending_bonus_drafts -= 1
	world.offer = roll_choices(world)
	return true


static func grant_specific_item(world: SimWorld, id: String) -> void:
	if id == "" or world.catalog == null or not world.catalog.has_item(id):
		return
	_add_item(world, id)
	sync_stats(world)


static func sync_stats(world: SimWorld) -> void:
	var prev_max: float = world.player.max_hp
	world.stats = SimStats.resolve(world.survivor.get("stats", {}), world.inventory, world.catalog, world.tonic_buffer_hp)
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
