class_name ArchivesContent
extends RefCounted

const ASH: Color = Color("a89890")
const PANEL: Color = Color("100d12e0")
const CARD: Color = Color("121015e0")
const BORDER: Color = Color("c4a35a59")
const LOCKED: Color = Color("3a322ccc")
const CARD_SIZE: Vector2 = Vector2(112, 148)
const CARD_ART: float = 64.0
const CARD_GAP: int = 8
const CARD_BORDER: Color = Color("4d4852")
const CARD_BG: Color = Color("1b181f")
const CARD_BG_ACTIVE: Color = Color("38231b")
const CARD_BG_UNSEEN: Color = Color("141016")
const CARD_GLOW: Color = Color("d48c4266")
const ART_WELL_BORDER: Color = Color(0.769, 0.639, 0.353, 0.24)
const UP: Color = Color("7dff9a")
const DOWN: Color = Color("ff7a6e")
const RARITY_BORDER: Dictionary = {
	"common": Color("7a7268"),
	"uncommon": Color("6888a6"),
	"rare": Color("e06a28"),
	"lunar": Color("62e0ff"),
}
const RARITY_TEXT: Dictionary = {
	"common": Color("d4b484"),
	"uncommon": Color("88c0d0"),
	"rare": Color("d4b46a"),
	"lunar": Color("62e0ff"),
}
const KIND_COLOR: Dictionary = {
	"chaser": Color("ff9988"),
	"ranged": Color("ffcc66"),
	"sniper": Color("c488ff"),
	"guardian": Color("ff6633"),
}


static func _app() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/App")


static func clear(node: Node) -> void:
	if node == null:
		return
	for child: Node in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func fill_howto(parent: Control, rec: ArchiveRecords, catalog: Catalog, vessel_id: String, on_vessel: Callable) -> void:
	parent.add_child(_banner("ui.archives.howto.banner.kicker", "ui.archives.howto.banner.title", "ui.archives.howto.banner.sub"))
	var controls := _panel()
	var controls_in := _inner(controls)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var title := _section_title(Loc.t("ui.archives.howto.controls"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var pills := HBoxContainer.new()
	pills.add_theme_constant_override("separation", 8)
	for surv: Dictionary in catalog.survivors:
		var sid: String = String(surv.get("id", ""))
		var unlocked: bool = bool(rec.check_unlock(surv.get("unlock", null), catalog).get("unlocked", true))
		var pill := _filter_pill(Loc.survivor_name(sid) if unlocked else "🔒 %s" % Loc.unseen(), sid == vessel_id, unlocked)
		if unlocked:
			pill.pressed.connect(func() -> void: on_vessel.call(sid))
		pills.add_child(pill)
	head.add_child(pills)
	controls_in.add_child(head)
	var survivor: Dictionary = catalog.survivor(vessel_id) if catalog.has_survivor(vessel_id) else catalog.survivor(String(catalog.world.get("defaultSurvivor", "runner")))
	controls_in.add_child(_controls_table(survivor))
	parent.add_child(controls)
	var beats := _panel()
	var beats_in := _inner(beats)
	beats_in.add_child(_section_title(Loc.t("ui.archives.howto.beats")))
	var grid := _cards_grid(2)
	for i: int in range(1, 5):
		grid.add_child(_info_card(Loc.t("ui.archives.howto.beat.%d.step" % i), Loc.t("ui.archives.howto.beat.%d.title" % i), Loc.t("ui.archives.howto.beat.%d.body" % i)))
	beats_in.add_child(grid)
	parent.add_child(beats)
	var props := _panel()
	var props_in := _inner(props)
	props_in.add_child(_section_title(Loc.t("ui.archives.howto.props")))
	var prop_grid := _cards_grid(2)
	var kinds: Array[String] = ["pillar", "hazard", "volatile", "elite"]
	for kind: String in kinds:
		prop_grid.add_child(_prop_card(kind))
	props_in.add_child(prop_grid)
	parent.add_child(props)


static func fill_lore(parent: Control, rec: ArchiveRecords, catalog: Catalog, sub: StringName, on_sub: Callable) -> void:
	parent.add_child(_banner("ui.archives.lore.banner.kicker", "ui.archives.lore.banner.title", "ui.archives.lore.banner.sub"))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	var subs: Array[StringName] = [&"work", &"vessels", &"chambers", &"exchange"]
	for id: StringName in subs:
		var pill := _filter_pill(Loc.t("ui.archives.lore.sub.%s" % String(id)), id == sub, true)
		var captured: StringName = id
		pill.pressed.connect(func() -> void: on_sub.call(captured))
		bar.add_child(pill)
	parent.add_child(bar)
	match String(sub):
		"work":
			parent.add_child(_great_work())
		"vessels":
			parent.add_child(_vessels_lore(rec, catalog))
		"chambers":
			parent.add_child(_chambers_lore(rec, catalog))
		_:
			parent.add_child(_exchange_lore())


static func fill_bestiary(grid: Control, dossier: Control, rec: ArchiveRecords, catalog: Catalog, filter: String, selected_id: String, on_filter: Callable, on_select: Callable) -> void:
	var bar := _filter_bar()
	var filters: Array[Array] = [
		["all", Loc.t("ui.archives.filter.all").replace("{n}", str(catalog.entities.size()))],
		["fodder", Loc.t("ui.archives.filter.denizens")],
		["boss", Loc.t("ui.archives.filter.guardians")],
	]
	for spec: Array in filters:
		var fid: String = String(spec[0])
		var pill := _filter_pill(String(spec[1]), fid == filter, true)
		pill.pressed.connect(func() -> void: on_filter.call(fid))
		bar.add_child(pill)
	grid.add_child(bar)
	var list: Array[Dictionary] = _filtered_entities(catalog, filter)
	if list.is_empty():
		return
	var selected: Dictionary = catalog.entity(selected_id) if catalog.has_entity(selected_id) else list[0]
	if not _list_has(list, String(selected.get("id", ""))):
		selected = list[0]
	var cards := _card_flow()
	for entity: Dictionary in list:
		var eid: String = String(entity.get("id", ""))
		cards.add_child(_entity_card(entity, rec, eid == String(selected.get("id", "")), on_select))
	grid.add_child(cards)
	_fill_entity_dossier(dossier, selected, rec, catalog)


static func fill_reliquary(grid: Control, dossier: Control, rec: ArchiveRecords, catalog: Catalog, rarity: String, selected_id: String, on_filter: Callable, on_select: Callable) -> void:
	var bar := _filter_bar()
	var filters: Array[Array] = [
		["all", Loc.t("ui.archives.filter.all").replace("{n}", str(catalog.items.size()))],
		["common", Loc.t("ui.archives.filter.common")],
		["uncommon", Loc.t("ui.archives.filter.uncommon")],
		["rare", Loc.t("ui.archives.filter.rare")],
		["lunar", Loc.t("ui.archives.filter.lunar")],
	]
	for spec: Array in filters:
		var fid: String = String(spec[0])
		var pill := _filter_pill(String(spec[1]), fid == rarity, true)
		pill.pressed.connect(func() -> void: on_filter.call(fid))
		bar.add_child(pill)
	grid.add_child(bar)
	var list: Array[Dictionary] = _filtered_items(catalog, rarity)
	if list.is_empty():
		return
	var selected: Dictionary = catalog.item(selected_id) if catalog.has_item(selected_id) else list[0]
	if not _list_has(list, String(selected.get("id", ""))):
		selected = list[0]
	var cards := _card_flow()
	for item: Dictionary in list:
		var iid: String = String(item.get("id", ""))
		cards.add_child(_item_card(item, rec, catalog, iid == String(selected.get("id", "")), on_select))
	grid.add_child(cards)
	_fill_item_dossier(dossier, selected, rec, catalog)


static func fill_ledger(parent: Control, rec: ArchiveRecords, catalog: Catalog, confirm_purge: bool, on_purge: Callable) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	var banner := _banner("ui.archives.ledger.banner.kicker", "ui.archives.ledger.banner.title", "ui.archives.ledger.banner.sub")
	banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(banner)
	var purge := Button.new()
	purge.text = Loc.t("ui.archives.purge_confirm") if confirm_purge else Loc.t("ui.archives.purge").to_upper()
	purge.custom_minimum_size = Vector2(180, 48)
	UiAtlas.apply_button_styles(purge, "btn-plaque")
	if confirm_purge:
		purge.add_theme_color_override("font_color", DOWN)
	purge.pressed.connect(func() -> void: on_purge.call())
	head.add_child(purge)
	parent.add_child(head)
	parent.add_child(_ledger_totals(rec, catalog))
	parent.add_child(_ledger_vessels(rec, catalog))
	parent.add_child(_ledger_history(rec, catalog))


static func _great_work() -> Control:
	var grid := _cards_grid(2)
	for i: int in range(1, 5):
		var card := _parchment()
		var inner := _inner(card)
		inner.add_child(_kicker(Loc.t("ui.archives.lore.work.%d.kicker" % i)))
		inner.add_child(_gold_title(Loc.t("ui.archives.lore.work.%d.title" % i)))
		inner.add_child(_body_label(Loc.t("ui.archives.lore.work.%d.p1" % i)))
		inner.add_child(_body_label(Loc.t("ui.archives.lore.work.%d.p2" % i)))
		grid.add_child(card)
	return grid


static func _vessels_lore(rec: ArchiveRecords, catalog: Catalog) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 16)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for surv: Dictionary in catalog.survivors:
		var sid: String = String(surv.get("id", ""))
		var state: Dictionary = rec.check_unlock(surv.get("unlock", null), catalog)
		var unlocked: bool = bool(state.get("unlocked", true))
		var panel := _panel()
		var panel_in := _inner(panel)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 18)
		var art := _art_box(96, 8)
		_mount_entity(art, sid, unlocked, false)
		top.add_child(art)
		var meta := VBoxContainer.new()
		meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kicker_text: String = Loc.t("ui.archives.lore.vessel.dossier").replace("{title}", Loc.survivor_title(sid).to_upper()) if unlocked else Loc.t("ui.archives.lore.vessel.sealed_kicker")
		meta.add_child(_kicker(kicker_text))
		meta.add_child(_name_label(Loc.survivor_name(sid).to_upper() if unlocked else Loc.unseen()))
		var lore_text: String = Loc.survivor_lore(sid)
		if not unlocked:
			lore_text = Loc.t("ui.archives.lore.vessel.sealed_req").replace("{label}", String(state.get("label", ""))).replace("{progress}", String(state.get("progress", "")))
		meta.add_child(_body_label(lore_text, not unlocked))
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 6)
		var s_rec: Dictionary = rec.survivor_record(sid)
		if unlocked:
			chips.add_child(_chip(Loc.t("ui.archives.chip.vitality"), Loc.t("ui.archives.chip.hp").replace("{n}", str(int(DictUtil.d(surv, "stats").get("maxHp", 0))))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.stride"), str(int(DictUtil.d(surv, "stats").get("speed", 0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.workings"), str(int(s_rec.get("runs", 0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.victories"), str(int(s_rec.get("victories", 0)))))
		else:
			chips.add_child(_chip(Loc.t("ui.archives.chip.vitality"), Loc.unseen()))
			chips.add_child(_chip(Loc.t("ui.archives.chip.stride"), Loc.unseen()))
			chips.add_child(_chip(Loc.t("ui.archives.chip.status"), Loc.t("ui.archives.chip.sealed").replace("{n}", String(state.get("progress", "")))))
		meta.add_child(chips)
		top.add_child(meta)
		panel_in.add_child(top)
		if unlocked:
			panel_in.add_child(_skills_grid(surv))
		holder.add_child(panel)
	return holder


static func _chambers_lore(rec: ArchiveRecords, catalog: Catalog) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 16)
	var stages: Array = DictUtil.a(catalog.loop, "stages")
	for i: int in stages.size():
		var stage: Dictionary = stages[i]
		var sid: String = String(stage.get("id", ""))
		var visits: int = int(DictUtil.d(rec.data, "stageVisits").get(sid, 0))
		var clears: int = int(DictUtil.d(rec.data, "stageClears").get(sid, 0))
		var visited: bool = rec.is_stage_visited(sid)
		var panel := _panel()
		var panel_in := _inner(panel)
		var head := HBoxContainer.new()
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kicker: String = Loc.stage_kicker(sid) if visited else Loc.t("ui.archives.lore.chamber.unseen_kicker").replace("{n}", str(i + 1))
		left.add_child(_kicker(kicker))
		var title: String = "%d. %s" % [i + 1, Loc.stage_name(sid).to_upper() if visited else Loc.unseen()]
		left.add_child(_name_label(title))
		head.add_child(left)
		var chips := HFlowContainer.new()
		if visited:
			chips.add_child(_chip(Loc.t("ui.archives.chip.visited"), str(visits)))
			chips.add_child(_chip(Loc.t("ui.archives.chip.cleared"), str(clears)))
		else:
			chips.add_child(_chip(Loc.t("ui.archives.chip.status"), Loc.t("ui.archives.lore.chamber.unencountered")))
		head.add_child(chips)
		panel_in.add_child(head)
		panel_in.add_child(_body_label(Loc.stage_lore(sid) if visited else Loc.t("ui.archives.lore.chamber.unseen_lore"), not visited))
		var details := _cards_grid(2)
		var denizens := _info_card(Loc.t("ui.archives.lore.chamber.denizens"), "", _denizen_line(stage, rec, catalog, visited))
		var props := _info_card(Loc.t("ui.archives.lore.chamber.props"), "", _prop_line(sid, visited))
		details.add_child(denizens)
		details.add_child(props)
		panel_in.add_child(details)
		holder.add_child(panel)
	return holder


static func _exchange_lore() -> Control:
	var grid := _cards_grid(2)
	var rarities: Array[String] = ["common", "uncommon", "rare", "lunar"]
	for rarity: String in rarities:
		var card := _info_card(rarity.to_upper(), Loc.t("ui.archives.lore.exchange.%s.title" % rarity), Loc.t("ui.archives.lore.exchange.%s.desc" % rarity))
		_tint_border(card, Color(RARITY_BORDER.get(rarity, UiAtlas.BRASS)))
		grid.add_child(card)
	return grid


static func _controls_table(survivor: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for col: String in ["ui.archives.howto.col.input", "ui.archives.howto.col.rite", "ui.archives.howto.col.effect"]:
		var th := _label(Loc.t(col), 12, UiAtlas.BRASS, UiAtlas.TYPE_MICRO)
		grid.add_child(th)
	var skills: Dictionary = DictUtil.d(survivor, "skills")
	var rows: Array[Array] = [
		["ui.archives.howto.row.move.key", "ui.archives.howto.row.move.rite", "ui.archives.howto.row.move.desc"],
		["ui.archives.howto.row.aim.key", "ui.archives.howto.row.aim.rite", "ui.archives.howto.row.aim.desc"],
	]
	var slots: Array[Array] = [
		["primary", "ui.archives.howto.row.primary", "I"],
		["secondary", "ui.archives.howto.row.secondary", "II"],
		["utility", "ui.archives.howto.row.utility", "III"],
		["special", "ui.archives.howto.row.special", "IV"],
	]
	var host: Node = _app()
	for slot: Array in slots:
		var skill_id: String = String(skills.get(String(slot[0]), ""))
		var prefix: String = String(slot[1])
		var numeral: String = String(slot[2])
		var rite: String = Loc.t("%s.fallback" % prefix)
		var desc: String = Loc.t("%s.desc" % prefix)
		if skill_id != "":
			rite = "%s (%s)" % [Loc.skill_name(skill_id), numeral]
			if host != null:
				var cd: int = int(host.catalog.skill(skill_id).get("cooldown", 0))
				if String(slot[0]) != "primary" and cd > 0:
					rite = "%s (%s · %ds)" % [Loc.skill_name(skill_id), numeral, cd]
			desc = Loc.skill_hook(skill_id)
		rows.append([prefix + ".key", rite, desc])
	rows.append(["ui.archives.howto.row.pick.key", "ui.archives.howto.row.pick.rite", "ui.archives.howto.row.pick.desc"])
	rows.append(["ui.archives.howto.row.channel.key", "ui.archives.howto.row.channel.rite", "ui.archives.howto.row.channel.desc"])
	rows.append(["ui.archives.howto.row.seal.key", "ui.archives.howto.row.seal.rite", "ui.archives.howto.row.seal.desc"])
	rows.append(["ui.archives.howto.row.pause.key", "ui.archives.howto.row.pause.rite", "ui.archives.howto.row.pause.desc"])
	for row: Array in rows:
		var key_text: String = Loc.t(String(row[0])) if String(row[0]).begins_with("ui.") else String(row[0])
		var rite_text: String = Loc.t(String(row[1])) if String(row[1]).begins_with("ui.") else String(row[1])
		var desc_text: String = Loc.t(String(row[2])) if String(row[2]).begins_with("ui.") else String(row[2])
		grid.add_child(_label(key_text, 14, UiAtlas.GOLD_MOLTEN))
		grid.add_child(_label(rite_text, 14, UiAtlas.PARCHMENT))
		var desc_l := _label(desc_text, 13, ASH)
		desc_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(desc_l)
	return grid


static func _skills_grid(surv: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skills: Dictionary = DictUtil.d(surv, "skills")
	var slots: Array[String] = ["primary", "secondary", "utility", "special"]
	for slot: String in slots:
		var skill_id: String = String(skills.get(slot, ""))
		if skill_id == "":
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _sb(Color("0c0a0db3"), BORDER, 1))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var icon_wrap := _art_box(44, 4)
		_mount_skill(icon_wrap, skill_id)
		row.add_child(icon_wrap)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := HBoxContainer.new()
		var name_l := _label(Loc.skill_name(skill_id), 14, UiAtlas.PARCHMENT)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var host: Node = _app()
		var cd: int = 0
		if host != null:
			cd = int(host.catalog.skill(skill_id).get("cooldown", 0))
		head.add_child(_label(Loc.t("ui.archives.skill.meta").replace("{slot}", Loc.t("ui.archives.skill.%s" % slot)).replace("{cd}", str(cd)), 11, ASH))
		body.add_child(head)
		body.add_child(_body_label(Loc.skill_hook(skill_id)))
		body.add_child(_body_label("\"%s\"" % Loc.skill_lore(skill_id), true))
		row.add_child(body)
		card.add_child(row)
		grid.add_child(card)
	return grid


static func _entity_card(entity: Dictionary, rec: ArchiveRecords, active: bool, on_select: Callable) -> Control:
	var eid: String = String(entity.get("id", ""))
	var seen: bool = rec.is_entity_seen(eid)
	var kills: int = int(DictUtil.d(rec.data, "entityKills").get(eid, 0))
	var has_lore: bool = rec.has_lore(eid)
	var card := Button.new()
	_setup_tile_card(card)
	card.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_select_card(card, active, seen, CARD_BORDER)
	var col := _tile_inner()
	var kind := _entity_kind(entity)
	var badge_color: Color = Color(KIND_COLOR.get(String(kind["key"]), UiAtlas.GOLD_MOLTEN)) if seen else ASH
	col.add_child(_role_badge(kind["label"].to_upper() if seen else Loc.unseen(), badge_color))
	var art := _art_well(CARD_ART, CARD_ART, 1)
	_mount_entity(art, eid, seen)
	col.add_child(art)
	col.add_child(_tile_line(Loc.entity_name(eid) if seen else Loc.unseen(), 11, UiAtlas.PARCHMENT, true))
	var tally: String = Loc.t("ui.archives.bestiary.unencountered")
	if seen:
		tally = Loc.t("ui.archives.bestiary.slain").replace("{n}", str(kills))
		if has_lore:
			tally += " · ☉"
	col.add_child(_tile_line(tally, 10, ASH, false))
	card.add_child(col)
	card.pressed.connect(func() -> void: on_select.call(eid))
	return card


static func _item_card(item: Dictionary, rec: ArchiveRecords, catalog: Catalog, active: bool, on_select: Callable) -> Control:
	var iid: String = String(item.get("id", ""))
	var picks: int = int(DictUtil.d(rec.data, "itemPicks").get(iid, 0))
	var seen: bool = picks > 0
	var unlocked: bool = bool(rec.check_unlock(item.get("unlock", null), catalog).get("unlocked", true))
	var rarity: String = String(item.get("rarity", "common"))
	var card := Button.new()
	_setup_tile_card(card)
	_style_select_card(card, active, seen, Color(RARITY_BORDER.get(rarity, CARD_BORDER)))
	var col := _tile_inner()
	col.add_child(_role_badge(rarity.to_upper(), Color(RARITY_TEXT.get(rarity, UiAtlas.GOLD_MOLTEN))))
	var art := _art_well(CARD_ART, CARD_ART, 1)
	_mount_item(art, iid, seen)
	col.add_child(art)
	col.add_child(_tile_line(Loc.item_name(iid) if seen else Loc.unseen(), 11, UiAtlas.PARCHMENT, true))
	var tally: String = Loc.t("ui.archives.reliquary.bound").replace("{n}", str(picks)) if seen else (Loc.t("ui.archives.bestiary.unencountered") if unlocked else Loc.t("ui.archives.reliquary.sealed"))
	col.add_child(_tile_line(tally, 10, ASH, false))
	card.add_child(col)
	card.pressed.connect(func() -> void: on_select.call(iid))
	return card


static func _fill_entity_dossier(root: Control, entity: Dictionary, rec: ArchiveRecords, catalog: Catalog) -> void:
	var eid: String = String(entity.get("id", ""))
	var kills: int = int(DictUtil.d(rec.data, "entityKills").get(eid, 0))
	var encounters: int = maxi(kills, int(DictUtil.d(rec.data, "entityEncounters").get(eid, 0)))
	var seen: bool = rec.is_entity_seen(eid)
	var has_lore: bool = rec.has_lore(eid)
	var header: String = Loc.t("ui.archives.bestiary.header.unseen")
	if seen:
		header = Loc.t("ui.archives.bestiary.header.boss") if String(entity.get("role", "")) == "boss" else Loc.t("ui.archives.bestiary.header.seen")
	root.add_child(_wrap(_kicker(header)))
	var name_l := _wrap(_name_label(Loc.entity_name(eid).to_upper() if seen else Loc.unseen()))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_l)
	var sub := _wrap(_label(Loc.entity_title(eid) if seen else Loc.t("ui.archives.bestiary.subtitle.unseen"), 12, UiAtlas.BRASS_BRIGHT))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)
	var pedestal := _art_well(0.0, 124.0, 2)
	_mount_entity(pedestal, eid, seen)
	root.add_child(pedestal)
	var strip := _chip_strip()
	strip.add_child(_chip(Loc.t("ui.archives.bestiary.encountered"), str(encounters)))
	strip.add_child(_chip(Loc.t("ui.archives.bestiary.slain_label"), str(kills)))
	strip.add_child(_chip(Loc.t("ui.archives.bestiary.treatise"), Loc.t("ui.archives.bestiary.recovered") if has_lore else Loc.t("ui.archives.bestiary.unrecovered")))
	root.add_child(strip)
	var lore: String = Loc.entity_lore(eid)
	var locked := false
	if not seen:
		lore = Loc.t("ui.archives.bestiary.lore.unseen")
		locked = true
	elif not has_lore:
		lore = Loc.t("ui.archives.bestiary.lore.no_treatise")
		locked = true
	root.add_child(_body_label(lore, locked))
	var kind := _entity_kind(entity)
	var habitats: String = _habitats(eid, rec, catalog)
	var stats := VBoxContainer.new()
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if seen:
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.vitality").replace("{n}", str(int(DictUtil.d(entity, "stats").get("maxHp", 0)))), 13, UiAtlas.PARCHMENT)))
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.chamber").replace("{n}", habitats), 13, UiAtlas.PARCHMENT)))
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.kind").replace("{n}", String(kind["label"]).to_upper()), 13, UiAtlas.PARCHMENT)))
	else:
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.vitality.unseen"), 13, ASH)))
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.chamber.unseen"), 13, ASH)))
		stats.add_child(_wrap(_label(Loc.t("ui.archives.bestiary.kind.unseen"), 13, ASH)))
	root.add_child(stats)
	root.add_child(_body_label(_behavior(entity, seen), not seen))


static func _fill_item_dossier(root: Control, item: Dictionary, rec: ArchiveRecords, catalog: Catalog) -> void:
	var iid: String = String(item.get("id", ""))
	var picks: int = int(DictUtil.d(rec.data, "itemPicks").get(iid, 0))
	var seen: bool = picks > 0
	var state: Dictionary = rec.check_unlock(item.get("unlock", null), catalog)
	var unlocked: bool = bool(state.get("unlocked", true))
	var rarity: String = String(item.get("rarity", "common"))
	var header: String = Loc.t("ui.archives.reliquary.header.seen").replace("{rarity}", rarity.to_upper())
	if not seen:
		header = Loc.t("ui.archives.reliquary.header.unbound") if unlocked else Loc.t("ui.archives.reliquary.header.sealed")
	root.add_child(_wrap(_kicker(header)))
	var name_l := _wrap(_name_label(Loc.item_name(iid).to_upper() if seen else Loc.unseen()))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(name_l)
	var pedestal := _art_well(0.0, 124.0, 2)
	_mount_item(pedestal, iid, seen)
	root.add_child(pedestal)
	var status: String = Loc.t("ui.archives.reliquary.status.bound") if seen else (Loc.t("ui.archives.reliquary.status.unbound") if unlocked else Loc.t("ui.archives.reliquary.status.sealed"))
	var strip := _chip_strip()
	strip.add_child(_chip(Loc.t("ui.archives.reliquary.times"), "×%d" % picks))
	strip.add_child(_chip(Loc.t("ui.archives.reliquary.status"), status))
	root.add_child(strip)
	var hooks := VBoxContainer.new()
	hooks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if seen:
		for hook_v: Variant in item.get("hooks", []):
			var formatted: Dictionary = _format_hook(hook_v)
			var line := _wrap(_label(String(formatted.get("text", "")).to_upper(), 13, UP if bool(formatted.get("up", true)) else DOWN))
			hooks.add_child(line)
	else:
		hooks.add_child(_wrap(_label(Loc.t("ui.archives.reliquary.hooks.hidden"), 13, DOWN)))
	root.add_child(hooks)
	var lore: String = Loc.item_lore(iid)
	var locked := false
	if seen:
		locked = false
	elif not unlocked:
		lore = Loc.t("ui.archives.reliquary.lore.sealed").replace("{label}", String(state.get("label", ""))).replace("{progress}", String(state.get("progress", "")))
		locked = true
	else:
		lore = Loc.t("ui.archives.reliquary.lore.unbound")
		locked = true
	root.add_child(_body_label(lore, locked))


static func _ledger_totals(rec: ArchiveRecords, catalog: Catalog) -> Control:
	var panel := _panel()
	var panel_in := _inner(panel)
	panel_in.add_child(_section_title(Loc.t("ui.archives.ledger.totals")))
	var grid := _cards_grid(2)
	var d: Dictionary = rec.data
	var runs: int = int(d.get("totalRuns", 0))
	var wins: int = int(d.get("victories", 0))
	var rate: String = "0%"
	if runs > 0:
		rate = "%d%%" % int(round(100.0 * float(wins) / float(runs)))
	var stages: Array = DictUtil.a(catalog.loop, "stages")
	var furthest_i: int = mini(int(d.get("furthestStageIndex", 0)), maxi(0, stages.size() - 1))
	var furthest: String = Loc.stage_name("cinder-yard")
	if furthest_i >= 0 and furthest_i < stages.size():
		furthest = Loc.stage_name(String(stages[furthest_i].get("id", "cinder-yard")))
	var fastest_v: Variant = d.get("fastestVictoryTime", null)
	var fastest: String = "—" if fastest_v == null else Loc.format_time(float(fastest_v))
	var metrics: Array[Array] = [
		[Loc.t("ui.archives.ledger.metric.runs"), str(runs), Loc.t("ui.archives.ledger.metric.runs.sub").replace("{wins}", str(wins)).replace("{defeats}", str(int(d.get("defeats", 0)))).replace("{abandons}", str(int(d.get("abandons", 0))))],
		[Loc.t("ui.archives.ledger.metric.rate"), rate, Loc.t("ui.archives.ledger.metric.rate.sub").replace("{n}", str(int(d.get("stagesCleared", 0))))],
		[Loc.t("ui.archives.ledger.metric.time"), Loc.format_time(float(d.get("totalPlayTime", 0.0))), Loc.t("ui.archives.ledger.metric.time.sub").replace("{n}", Loc.format_time(float(d.get("longestRunTime", 0.0))))],
		[Loc.t("ui.archives.ledger.metric.fastest"), fastest, Loc.t("ui.archives.ledger.metric.fastest.sub").replace("{n}", furthest)],
		[Loc.t("ui.archives.ledger.metric.kills"), str(int(d.get("totalKills", 0))), Loc.t("ui.archives.ledger.metric.kills.sub").replace("{fodder}", str(int(d.get("fodderKills", 0)))).replace("{elites}", str(int(d.get("eliteKills", 0)))).replace("{bosses}", str(int(d.get("bossKills", 0))))],
		[Loc.t("ui.archives.ledger.metric.most"), str(int(d.get("mostKillsInRun", 0))), Loc.t("ui.archives.ledger.metric.most.sub").replace("{n}", str(int(d.get("highestLevel", 1))))],
		[Loc.t("ui.archives.ledger.metric.dmg"), str(int(round(float(d.get("totalDamageDealt", 0.0))))), Loc.t("ui.archives.ledger.metric.dmg.sub").replace("{n}", str(int(round(float(d.get("mostDamageInRun", 0.0))))))],
		[Loc.t("ui.archives.ledger.metric.taken"), str(int(round(float(d.get("totalDamageTaken", 0.0))))), Loc.t("ui.archives.ledger.metric.taken.sub").replace("{n}", str(int(round(float(d.get("totalHealingDone", 0.0))))))],
		[Loc.t("ui.archives.ledger.metric.items"), str(int(d.get("totalItemsCollected", 0))), Loc.t("ui.archives.ledger.metric.items.sub").replace("{n}", str(int(d.get("totalGemsCollected", 0))))],
		[Loc.t("ui.archives.ledger.metric.levels"), str(int(d.get("totalLevelsGained", 0))), Loc.t("ui.archives.ledger.metric.levels.sub")],
	]
	for m: Array in metrics:
		grid.add_child(_metric_card(String(m[0]), String(m[1]), String(m[2])))
	panel_in.add_child(grid)
	return panel


static func _ledger_vessels(rec: ArchiveRecords, catalog: Catalog) -> Control:
	var panel := _panel()
	var panel_in := _inner(panel)
	panel_in.add_child(_section_title(Loc.t("ui.archives.ledger.vessels")))
	var grid := _cards_grid(2)
	for surv: Dictionary in catalog.survivors:
		var sid: String = String(surv.get("id", ""))
		var state: Dictionary = rec.check_unlock(surv.get("unlock", null), catalog)
		var unlocked: bool = bool(state.get("unlocked", true))
		var s_rec: Dictionary = rec.survivor_record(sid)
		var card := _panel()
		var card_in := _inner(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var art := _art_box(72, 6)
		_mount_entity(art, sid, unlocked, false)
		row.add_child(art)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.add_child(_kicker(Loc.survivor_title(sid).to_upper() if unlocked else Loc.t("ui.archives.lore.vessel.sealed_kicker")))
		copy.add_child(_gold_title(Loc.survivor_name(sid) if unlocked else Loc.unseen()))
		row.add_child(copy)
		card_in.add_child(row)
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		if unlocked:
			var fastest_v: Variant = s_rec.get("fastestVictory", null)
			chips.add_child(_chip(Loc.t("ui.archives.chip.workings"), str(int(s_rec.get("runs", 0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.victories"), str(int(s_rec.get("victories", 0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.slain"), str(int(s_rec.get("kills", 0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.best"), Loc.format_time(float(s_rec.get("bestTime", 0.0)))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.fastest"), "—" if fastest_v == null else Loc.format_time(float(fastest_v))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.peak"), Loc.t("ui.archives.chip.lv").replace("{n}", str(int(s_rec.get("highestLevel", 1))))))
		else:
			chips.add_child(_chip(Loc.t("ui.archives.chip.status"), Loc.t("ui.archives.chip.sealed").replace("{n}", String(state.get("progress", "")))))
			chips.add_child(_chip(Loc.t("ui.archives.chip.rite"), String(state.get("label", ""))))
		card_in.add_child(chips)
		grid.add_child(card)
	panel_in.add_child(grid)
	return panel


static func _ledger_history(rec: ArchiveRecords, catalog: Catalog) -> Control:
	var panel := _panel()
	var panel_in := _inner(panel)
	panel_in.add_child(_section_title(Loc.t("ui.archives.ledger.history")))
	var recent: Array = rec.data.get("recentRuns", [])
	if recent.is_empty():
		panel_in.add_child(_body_label(Loc.t("ui.archives.ledger.history.empty"), true))
		return panel
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for run_v: Variant in recent:
		if typeof(run_v) != TYPE_DICTIONARY:
			continue
		var run: Dictionary = run_v
		list.add_child(_history_row(run, catalog))
	panel_in.add_child(list)
	return panel


static func _history_row(run: Dictionary, catalog: Catalog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 48)
	var outcome: String = String(run.get("outcome", "defeat"))
	var badge := _label(Loc.t("ui.archives.ledger.outcome.%s" % outcome), 11, UiAtlas.GOLD_MOLTEN)
	badge.custom_minimum_size = Vector2(110, 0)
	row.add_child(badge)
	var summary := VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sid: String = String(run.get("survivorId", ""))
	var vessel: String = Loc.survivor_name(sid) if catalog.has_survivor(sid) else sid
	var cycle_bit: String = ""
	if run.has("cycleIndex"):
		cycle_bit = Loc.t("ui.archives.ledger.history.cycle").replace("{n}", SimRng.cycle_numeral(int(run.get("cycleIndex", 0))))
	var stage_id: String = String(run.get("stageId", ""))
	var stage_n: String = Loc.stage_name(stage_id) if stage_id != "" else String(run.get("stageName", ""))
	summary.add_child(_label(Loc.t("ui.archives.ledger.history.line").replace("{vessel}", vessel).replace("{cycle}", cycle_bit).replace("{stage}", stage_n), 14, UiAtlas.PARCHMENT))
	var seed_bit: String = ""
	var tag: String = String(run.get("seedTag", ""))
	if tag != "":
		seed_bit = " · %s" % tag
	summary.add_child(_label(Loc.t("ui.archives.ledger.history.sub").replace("{time}", Loc.format_time(float(run.get("runTime", 0.0)))).replace("{level}", str(int(run.get("level", 1)))).replace("{kills}", str(int(run.get("kills", 0)))).replace("{dmg}", str(int(round(float(run.get("damageDealt", 0.0)))))).replace("{seed}", seed_bit), 12, ASH))
	row.add_child(summary)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 4)
	for inst_v: Variant in run.get("items", []):
		if typeof(inst_v) != TYPE_DICTIONARY:
			continue
		var inst: Dictionary = inst_v
		var iid: String = String(inst.get("id", ""))
		if not catalog.has_item(iid):
			continue
		var chip := _art_box(24)
		chip.custom_minimum_size = Vector2(24, 24)
		_mount_item(chip, iid, true)
		var stacks: int = int(inst.get("stacks", 1))
		if stacks > 1:
			var n := _label("×%d" % stacks, 10, UiAtlas.GOLD_MOLTEN)
			chip.add_child(n)
		items.add_child(chip)
	row.add_child(items)
	return row


static func _denizen_line(stage: Dictionary, rec: ArchiveRecords, catalog: Catalog, visited: bool) -> String:
	if not visited:
		return Loc.t("ui.archives.lore.chamber.denizens.unseen")
	return Loc.t("ui.archives.lore.chamber.denizens.seen").replace("{hunts}", _seen_name(String(stage.get("fodder", "")), rec, catalog)).replace("{spits}", _optional_entity(String(stage.get("ranged", "")), rec, catalog)).replace("{lances}", _optional_entity(String(stage.get("sniper", "")), rec, catalog)).replace("{warden}", _seen_name(String(stage.get("elite", "")), rec, catalog)).replace("{guardian}", _seen_name(String(stage.get("boss", "")), rec, catalog))


static func _prop_line(stage_id: String, visited: bool) -> String:
	if not visited:
		return Loc.t("ui.archives.lore.chamber.props.unseen")
	return "%s. %s. %s." % [Loc.t("obstacle.%s.pillar" % stage_id), Loc.t("obstacle.%s.hazard" % stage_id), Loc.t("obstacle.%s.volatile" % stage_id)]


static func _seen_name(entity_id: String, rec: ArchiveRecords, catalog: Catalog) -> String:
	if entity_id == "" or not catalog.has_entity(entity_id):
		return Loc.t("ui.archives.lore.chamber.none")
	return Loc.entity_name(entity_id) if rec.is_entity_seen(entity_id) else Loc.unseen()


static func _optional_entity(entity_id: String, rec: ArchiveRecords, catalog: Catalog) -> String:
	if entity_id == "":
		return Loc.t("ui.archives.lore.chamber.none")
	return _seen_name(entity_id, rec, catalog)


static func _habitats(entity_id: String, rec: ArchiveRecords, catalog: Catalog) -> String:
	var hits: PackedStringArray = PackedStringArray()
	var stages: Array = DictUtil.a(catalog.loop, "stages")
	var all_stages := true
	for stage_v: Variant in stages:
		var st: Dictionary = stage_v
		if String(st.get("fodder", "")) == entity_id or String(st.get("ranged", "")) == entity_id or String(st.get("sniper", "")) == entity_id or String(st.get("elite", "")) == entity_id or String(st.get("boss", "")) == entity_id:
			var sid: String = String(st.get("id", ""))
			if rec.is_stage_visited(sid):
				hits.append(Loc.stage_name(sid))
			else:
				hits.append(Loc.unseen())
				all_stages = false
	if all_stages and hits.size() == stages.size() and stages.size() > 0:
		return Loc.t("ui.archives.bestiary.habitats.all")
	if hits.is_empty():
		return Loc.t("ui.archives.bestiary.habitats.rifts")
	return ", ".join(hits).to_upper()


static func _behavior(entity: Dictionary, seen: bool) -> String:
	if not seen:
		return Loc.t("ui.archives.bestiary.behavior.unseen")
	var ai: Dictionary = DictUtil.d(entity, "ai")
	var t: String = String(ai.get("type", ""))
	if t == "boss":
		var names: PackedStringArray = PackedStringArray()
		for atk_v: Variant in ai.get("attacks", []):
			if typeof(atk_v) != TYPE_DICTIONARY:
				continue
			var n: String = String((atk_v as Dictionary).get("name", ""))
			if n != "":
				names.append(n)
		var rites: String = Loc.t("ui.archives.bestiary.behavior.boss.rites").replace("{n}", ", ".join(names)) if names.size() > 0 else ""
		return rites + Loc.t("ui.archives.bestiary.behavior.boss")
	if t == "ranged":
		return Loc.t("ui.archives.bestiary.behavior.ranged")
	if t == "sniper":
		return Loc.t("ui.archives.bestiary.behavior.sniper")
	return Loc.t("ui.archives.bestiary.behavior.chaser")


static func _entity_kind(entity: Dictionary) -> Dictionary:
	var ai: Dictionary = DictUtil.d(entity, "ai")
	if String(entity.get("role", "")) == "boss" or String(ai.get("type", "")) == "boss":
		return {"key": "guardian", "label": Loc.t("ui.archives.kind.guardian")}
	if String(ai.get("type", "")) == "sniper":
		return {"key": "sniper", "label": Loc.t("ui.archives.kind.sniper")}
	if String(ai.get("type", "")) == "ranged":
		return {"key": "ranged", "label": Loc.t("ui.archives.kind.ranged")}
	return {"key": "chaser", "label": Loc.t("ui.archives.kind.chaser")}


static func _filtered_entities(catalog: Catalog, filter: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entity: Dictionary in catalog.entities:
		if filter == "boss" and String(entity.get("role", "")) != "boss":
			continue
		if filter == "fodder" and String(entity.get("role", "")) == "boss":
			continue
		out.append(entity)
	return out


static func _filtered_items(catalog: Catalog, rarity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in catalog.items:
		if rarity != "all" and String(item.get("rarity", "")) != rarity:
			continue
		out.append(item)
	return out


static func _list_has(list: Array[Dictionary], id: String) -> bool:
	for row: Dictionary in list:
		if String(row.get("id", "")) == id:
			return true
	return false


static func _format_hook(hook_v: Variant) -> Dictionary:
	if typeof(hook_v) != TYPE_DICTIONARY:
		return {"text": "", "up": true}
	var hook: Dictionary = hook_v
	var op: String = String(hook.get("op", ""))
	var value: float = float(hook.get("value", 0.0))
	var sign_s: String = "+" if value > 0.0 else ""
	if op == "on-kill":
		return {"text": Loc.t("ui.archives.hook.on_kill").replace("{sign}", sign_s).replace("{value}", str(int(value))), "up": value > 0.0}
	if op == "on-crit":
		return {"text": Loc.t("ui.archives.hook.on_crit").replace("{value}", str(value)), "up": true}
	var amount: String = "%s%d%%" % [sign_s, int(round(value * 100.0))] if op == "pct" else "%s%s" % [sign_s, str(value)]
	var stat: String = String(hook.get("stat", ""))
	var hurt: bool = stat == "radius" or stat == "cooldown"
	var up: bool = value < 0.0 if hurt else value > 0.0
	if is_zero_approx(value):
		up = true
	return {"text": "%s %s" % [amount, Loc.t("stat.%s" % stat)], "up": up}


static func _banner(kicker_key: String, title_key: String, sub_key: String) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 4)
	holder.add_child(_kicker(Loc.t(kicker_key)))
	var title := _label(Loc.t(title_key), UiAtlas.SIZE_DISPLAY_M, UiAtlas.PARCHMENT, UiAtlas.TYPE_DISPLAY)
	holder.add_child(title)
	holder.add_child(_body_label(Loc.t(sub_key)))
	return holder


static func _panel() -> PanelContainer:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _sb(PANEL, BORDER, 1, 16))
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.add_theme_constant_override("separation", 12)
	holder.add_child(inner)
	return holder


static func _parchment() -> PanelContainer:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _sb(Color("100d12e0"), BORDER, 1, 18))
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.add_theme_constant_override("separation", 8)
	holder.add_child(inner)
	return holder


static func _inner(panel: PanelContainer) -> VBoxContainer:
	return panel.get_node("Inner") as VBoxContainer


static func _info_card(kicker: String, title: String, body: String) -> Control:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _sb(CARD, BORDER, 1, 14))
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.add_child(_kicker(kicker))
	if title != "":
		inner.add_child(_gold_title(title))
	if body != "":
		inner.add_child(_body_label(body))
	holder.add_child(inner)
	return holder


static func _prop_card(kind: String) -> Control:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _sb(CARD, BORDER, 1, 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var art := _art_box(72)
	if kind == "elite":
		_mount_entity(art, "ember-chaser", true)
	else:
		var frame_id: String = "cinder-pillar" if kind == "pillar" else ("cinder-hazard-0" if kind == "hazard" else "cinder-volatile")
		var tex: Texture2D = UiAtlas.env_frame(frame_id)
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art.add_child(rect)
	row.add_child(art)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(_kicker(Loc.t("ui.archives.howto.prop.%s.kicker" % kind)))
	copy.add_child(_gold_title(Loc.t("ui.archives.howto.prop.%s.title" % kind)))
	copy.add_child(_body_label(Loc.t("ui.archives.howto.prop.%s.body" % kind)))
	row.add_child(copy)
	holder.add_child(row)
	return holder


static func _metric_card(label: String, value: String, hint: String) -> Control:
	var holder := PanelContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_stylebox_override("panel", _sb(CARD, BORDER, 1, 12))
	var inner := VBoxContainer.new()
	inner.add_child(_kicker(label))
	inner.add_child(_label(value, 22, UiAtlas.GOLD_MOLTEN))
	inner.add_child(_label(hint, 12, ASH))
	holder.add_child(inner)
	return holder


static func _cards_grid(cols: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid


static func _card_flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", CARD_GAP)
	flow.add_theme_constant_override("v_separation", CARD_GAP)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return flow


static func _filter_bar() -> HFlowContainer:
	var bar := HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 8)
	bar.add_theme_constant_override("v_separation", 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


static func _setup_tile_card(card: Button) -> void:
	card.custom_minimum_size = CARD_SIZE
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.clip_contents = true


static func _tile_inner() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8.0
	col.offset_top = 6.0
	col.offset_right = -8.0
	col.offset_bottom = -8.0
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	return col


static func _role_badge(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.custom_maximum_size = Vector2(96.0, 22.0)
	chip.clip_contents = true
	var border := Color(color, 0.4)
	var sb := _sb(Color("0a080ccc"), border, 1, 0)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	chip.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 9, color, UiAtlas.TYPE_MICRO)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_maximum_size = Vector2(84.0, 18.0)
	chip.add_child(l)
	return chip


static func _tile_line(text: String, size: int, color: Color, two_line: bool) -> Label:
	var l := _label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if two_line:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.custom_minimum_size.y = 32.0
	return l


static func _filter_pill(text: String, active: bool, enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = text.to_upper()
	btn.disabled = not enabled
	btn.custom_minimum_size = Vector2(0, 28)
	var bg := Color("42281c") if active else Color("100d12e6")
	var border := UiAtlas.GOLD_MOLTEN if active else Color("c4a35a52")
	var idle := _pill_sb(bg, border, active)
	var hover := _pill_sb(Color("2a221c"), UiAtlas.BRASS_BRIGHT, false)
	btn.add_theme_stylebox_override("normal", idle)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", _pill_sb(Color("42281c"), UiAtlas.GOLD_MOLTEN, true))
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	btn.add_theme_stylebox_override("disabled", _pill_sb(Color("141016"), Color("3a322c"), false))
	btn.add_theme_color_override("font_color", UiAtlas.PARCHMENT if active else ASH)
	btn.add_theme_color_override("font_hover_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_pressed_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_focus_color", UiAtlas.PARCHMENT)
	btn.add_theme_color_override("font_disabled_color", ASH)
	btn.add_theme_font_size_override("font_size", UiAtlas.SIZE_MICRO)
	var font: Font = UiAtlas.body_font()
	if font != null:
		btn.add_theme_font_override("font", font)
	return btn


static func _pill_sb(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var sb := _sb(bg, border, 1, 0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	if glow:
		sb.shadow_color = CARD_GLOW
		sb.shadow_size = 8
	return sb


static func _chip_strip() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	return row


static func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


static func _chip(label: String, value: String) -> Control:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 5)
	var bg := PanelContainer.new()
	bg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bg.add_theme_stylebox_override("panel", _sb(Color("0a080cd9"), BORDER, 1, 8))
	holder.add_child(_label("%s:" % label, 11, ASH))
	holder.add_child(_label(value, 11, UiAtlas.GOLD_MOLTEN))
	bg.add_child(holder)
	return bg


static func _art_box(side: float, inset: float = 0.0) -> Control:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(side, side)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.clip_contents = true
	box.add_theme_stylebox_override("panel", _sb(Color("120f14"), Color("8a6a3266"), 2, int(inset)))
	return box


static func _art_well(width: float, height: float, border_w: int) -> Control:
	var box := PanelContainer.new()
	box.clip_contents = true
	if width <= 0.0:
		box.custom_minimum_size = Vector2(0.0, height)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		box.custom_minimum_size = Vector2(width, height)
		box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var border: Color = UiAtlas.BRASS_DIM if border_w >= 2 else ART_WELL_BORDER
	var bg: Color = Color("141014") if border_w >= 2 else Color("100d12")
	box.add_theme_stylebox_override("panel", _sb(bg, border, border_w, 0))
	return box


static func _fit_tex() -> TextureRect:
	var rect := TextureRect.new()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rect.custom_minimum_size = Vector2.ZERO
	return rect


static func _mount_entity(box: Control, id: String, seen: bool, animated: bool = true) -> void:
	var rect := _fit_tex()
	rect.name = "Art"
	if animated and seen:
		rect.set_meta("archive_anim", id)
	rect.modulate = Color.WHITE if seen else Color(0.0, 0.0, 0.0, 1.0)
	var tex: Texture2D = UiAtlas.entity_frame(id, "idle", 0.0)
	if tex != null:
		rect.texture = tex
	box.add_child(rect)


static func _mount_item(box: Control, id: String, seen: bool) -> void:
	var rect := _fit_tex()
	rect.modulate = Color.WHITE if seen else Color(0.0, 0.0, 0.0, 1.0)
	var path: String = "res://assets/sprites/items/%s.png" % id
	if ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D
	box.add_child(rect)


static func _mount_skill(box: Control, id: String) -> void:
	var rect := _fit_tex()
	var path: String = "res://assets/sprites/skills/%s.png" % id
	if ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D
	box.add_child(rect)


static func _style_select_card(btn: Button, active: bool, seen: bool, idle_border: Color = CARD_BORDER) -> void:
	var border: Color = UiAtlas.GOLD_MOLTEN if active else idle_border
	var bg: Color = CARD_BG_ACTIVE if active else (CARD_BG if seen else CARD_BG_UNSEEN)
	var hover_border: Color = UiAtlas.GOLD_MOLTEN if active else UiAtlas.BRASS_BRIGHT
	var hover := _card_sb(Color("2a221c"), hover_border, active)
	btn.add_theme_stylebox_override("normal", _card_sb(bg, border, active))
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", _card_sb(CARD_BG_ACTIVE, UiAtlas.GOLD_MOLTEN, true))
	btn.add_theme_stylebox_override("focus", UiAtlas.empty_focus())
	btn.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
	btn.add_theme_color_override("font_focus_color", Color(0, 0, 0, 0))


static func _card_sb(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	var sb := _sb(bg, border, 2, 0)
	if glow:
		sb.shadow_color = CARD_GLOW
		sb.shadow_size = 8
		sb.shadow_offset = Vector2.ZERO
	return sb


static func _tint_border(node: Control, color: Color) -> void:
	if node is Button:
		var btn := node as Button
		for state: String in ["normal", "hover", "pressed", "focus"]:
			var sb := btn.get_theme_stylebox(state)
			if sb is StyleBoxFlat:
				var copy := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
				copy.border_color = color
				btn.add_theme_stylebox_override(state, copy)
		return
	if node is PanelContainer:
		var panel := node as PanelContainer
		var psb := panel.get_theme_stylebox("panel")
		if psb is StyleBoxFlat:
			var copy2 := (psb as StyleBoxFlat).duplicate() as StyleBoxFlat
			copy2.border_color = color
			panel.add_theme_stylebox_override("panel", copy2)


static func _section_title(text: String) -> Label:
	return _label(text, UiAtlas.SIZE_BODY, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_DISPLAY)


static func _kicker(text: String) -> Label:
	return _label(text.to_upper(), 10, UiAtlas.BRASS, UiAtlas.TYPE_MICRO)


static func _gold_title(text: String) -> Label:
	return _label(text, 17, UiAtlas.GOLD_MOLTEN, UiAtlas.TYPE_DISPLAY)


static func _name_label(text: String) -> Label:
	return _label(text, UiAtlas.SIZE_DISPLAY_S, UiAtlas.PARCHMENT, UiAtlas.TYPE_DISPLAY)


static func _body_label(text: String, locked: bool = false) -> Label:
	var l := _label(text, UiAtlas.SIZE_BODY, ASH if locked else UiAtlas.PARCHMENT, UiAtlas.TYPE_BODY)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _label(text: String, size: int, color: Color, role: StringName = &"") -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var resolved: StringName = role
	if resolved == &"":
		if size >= 16:
			resolved = UiAtlas.TYPE_DISPLAY
		elif size >= 13:
			resolved = UiAtlas.TYPE_META
		else:
			resolved = UiAtlas.TYPE_MICRO
	UiAtlas.apply_label(l, resolved, color, size)
	return l


static func _sb(bg: Color, border: Color, width: int, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = float(pad)
	sb.content_margin_right = float(pad)
	sb.content_margin_top = float(pad)
	sb.content_margin_bottom = float(pad)
	return sb
