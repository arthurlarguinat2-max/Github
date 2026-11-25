## On-demand management sheet. The text updates in place while the action buttons
## stay pressable and the scroll position is preserved.
extends PanelContainer

var hud
var title := Label.new()
var detail := Label.new()
var actions := VBoxContainer.new()
var scroll := ScrollContainer.new()
var mode := ""
var resource := "food"
var target := -1
var quantity := 6
var contract_good := "grain"
var contract_lots := 1
var _shown_transfer := {}
var _buttons := {}
var _used: Array = []


func setup(owner_hud) -> void:
	hud = owner_hud
	add_theme_stylebox_override("panel", hud.Design.panel(hud.PANEL_BG, 28, 14))
	var column := VBoxContainer.new()
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(title)
	var close: Button = hud._icon_button("", "×", Vector2(44,44))
	close.pressed.connect(hud._close_sheets)
	header.add_child(close)
	scroll.custom_minimum_size.y = 248
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(detail)
	content.add_child(actions)
	hide()


func open(page: String, res: String = "food", cell: int = -1) -> void:
	quantity = 6
	mode = page
	resource = res
	target = cell
	scroll.scroll_vertical = 0
	hud._end_placement()
	hud._show_sheet(self)
	refresh()


func action(key: String, text: String, callback: Callable) -> void:
	_used.append(key)
	if not _buttons.has(key):
		var btn := Button.new()
		btn.custom_minimum_size.y = 44
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.pressed.connect(callback)
		actions.add_child(btn)
		_buttons[key] = btn
	_buttons[key].text = text
	actions.move_child(_buttons[key], _used.size() - 1)


func refresh() -> void:
	var eco = GameState.sim.economy
	_used.clear()
	match mode:
		"reserve": _reserve(eco)
		"farm": _farm(eco)
		"policy": _policy(eco)
		"order": _order(eco)
		"contract": _contracts(eco)
		"canal": _canal(eco)
		"recipes": _recipes(eco)
		"bronze": _bronze(eco)
		"chapters": _chapters(eco)
		"market": _market(eco)
		"trade_rules": _trade_rules(eco)
		"priority": _priority(eco)
		"plans": _plans(eco)
		"voice": _voice(eco)
	for key in _buttons.keys():
		if key not in _used:
			actions.remove_child(_buttons[key])
			_buttons[key].queue_free()
			_buttons.erase(key)


func _site(eco, cell: int) -> String:
	return "%s · %d" % [tr(eco.def_of(cell).name_key), cell + 1]


func _res(id: String) -> String:
	return tr(hud._res_key(id))


func _forecast(eco, priority: int) -> Dictionary:
	return eco.forecast(priority, 1.0 / GameState.sim.ticks_per_day)


func _reserve(eco) -> void:
	title.text = _res(resource)
	var flow := _forecast(eco, eco.preferred_cell)
	var made := 0.0
	var needs := float(flow.households.get(resource, 0))
	var sources := PackedStringArray()
	for cell in eco.building_cells():
		if resource == "food" and eco.building_at(cell) == "field" and eco.is_active(cell):
			action("farm%d" % cell, tr("S_FIELD_LINK") % (cell+1), open.bind("farm", "food", cell))
		var output := float(flow.outputs.get(cell, {}).get(resource, 0))
		var input := float(flow.inputs.get(cell, {}).get(resource, 0))
		made += output
		needs += input
		if output > 0 or input > 0:
			sources.append("%s   %s%s" % [_site(eco, cell), hud._format_signed(output-input), tr("PER_DAY")])
		if not eco.def_of(cell).get("produces", {}).has(resource):
			continue
		var reason := ""
		if not eco.is_active(cell):
			reason = tr("MG_SITE")
		elif float(flow.staffing.get(cell, 0)) == 0:
			reason = tr("MG_UNSTAFFED")
		elif flow.waiting.has(cell):
			reason = tr("MG_MISSING") % _res(flow.waiting[cell])
			if flow.waiting[cell] == "grain" and eco.seed_target > 0 and eco.stock("grain") > 0:
				reason = tr("POL_SEED_WAIT")
		elif eco.def_of(cell).has("extracts") and not eco.has_deposit(cell, eco.def_of(cell).extracts):
			reason = tr("BUILD_ERR_DEPOSIT")
		if reason != "":
			sources.append("%s · %s" % [_site(eco, cell), reason])
		if eco.is_active(cell):
			if eco.bronze_study == 0.0 and eco.def_of(cell).has("consumes"):
				action("order%d" % cell, tr("POL_ORDER_AT") % _site(eco,cell), open.bind("order",resource,cell))
			action("site%d:%s" % [cell, resource], tr("MG_PRIORITY_FOR") % _site(eco, cell), open.bind("priority", resource, cell))
	if float(flow.households.get(resource, 0)) > 0:
		sources.append("%s   %s%s" % [tr("TAB_PEOPLE"),hud._format_signed(-float(flow.households[resource])),tr("PER_DAY")])
	var net := float(flow.net.get(resource, 0))
	var trend := tr("MG_STABLE")
	if flow.unmet.has(resource):
		trend = tr("MG_SHORT") % float(flow.unmet[resource])
	elif net < -0.00001:
		trend = tr("MG_DAYS") % (eco.stock(resource) / -net)
	elif net > 0.00001:
		trend = tr("MG_RISING")
	if sources.is_empty():
		sources.append(tr("MG_NO_FLOW"))
	detail.text = tr("MG_LEDGER") % [eco.stock(resource),made,needs,hud._format_signed(net)] + "\n" + trend + "\n" + "\n".join(sources)
	if resource in ["food", "grain"]:
		action("policy"+resource, tr("POL_PANTRY" if resource == "food" else "POL_SEEDS"), open.bind("policy",resource))
	if resource == "food":
		var next: int = (eco.season_index()+1) % 4
		var outlook: Dictionary = eco.forecast(eco.preferred_cell, 1.0/GameState.sim.ticks_per_day, next)
		detail.text += "\n" + _calendar(eco) + "\n" + tr("S_FORECAST") % [tr(eco.SEASONS[next]), hud._format_signed(outlook.net.food - float(outlook.unmet.get("food", 0.0)))]
	action("resources", tr("MG_ALL"), open.bind("priority", resource, -1))


func _calendar(eco) -> String:
	var season: int = eco.season_index()
	return tr("S_CLOCK") % [tr(eco.SEASONS[season]), tr(eco.SEASONS[(season+1)%4]), eco.SEASON_DAYS - eco.elapsed_days % eco.SEASON_DAYS]


func _farm(eco) -> void:
	title.text = _site(eco, target)
	var crop: String = eco.recipe_choices.get(target, "grain")
	var def: Dictionary = eco.def_of(target)
	var lines := PackedStringArray([_calendar(eco), tr("S_FIELD") % tr("S_"+crop.to_upper()), tr("S_HELP"), tr("S_BASE")])
	var season: int = eco.season_index()
	for id in def.recipes:
		var recipe: Dictionary = def.recipes[id]
		var out: String = recipe.produces.keys()[0]
		var label := tr("S_" + str(id).to_upper())
		var rate: float = recipe.produces[out] * recipe.seasons[season]
		lines.append("%s · %.1f %s%s" % [label, rate, _res(out), tr("PER_DAY")])
		if id != crop:
			action("plant%d:%s" % [target,id], tr("S_PLANT") % label, _plant.bind(target,id))
	if eco.sowing.has(target):
		lines.append(tr("S_SOW") % float(eco.sowing[target]))
	if eco.workers_at(target) == 0:
		lines.append(tr("MG_UNSTAFFED"))
	action("canal%d" % target,tr("IR_TITLE"),open.bind("canal","food",target))
	action("staff%d" % target, tr("MG_PRIORITY_FOR") % _site(eco,target), open.bind("priority","food",target))
	action("seeds",tr("POL_SEEDS"),open.bind("policy","grain"))
	if eco.extra_plots.has(target):
		lines.append(tr("POL_PLANTED"))
	action("food_balance",tr("MG_SEE") % _res("food"),open.bind("reserve","food"))
	detail.text = "\n".join(lines)


func _canal(eco) -> void:
	title.text = tr("IR_TITLE")
	var lines := PackedStringArray([_site(eco,target)])
	if eco.antiquity_chapter() < 2:
		lines.append(tr("CH_LOCK") % tr("CH_2"))
	else:
		var connected: bool = eco.canals.has(target)
		var opened: bool = connected and eco.canals[target].open
		var sources: Array = []
		for cell in GameState.sim.planet.grid.neighbors[target]:
			if eco.valid_canal(target,cell):
				sources.append(cell)
		if sources.is_empty():
			lines.append(tr("IR_NEED"))
		else:
			var dt := 1.0 / GameState.sim.ticks_per_day
			var before: Dictionary = eco.forecast(eco.preferred_cell,dt,-1,target,false)
			var after: Dictionary = eco.forecast(eco.preferred_cell,dt,-1,target,true)
			var product: String = eco.def_of(target).produces.keys()[0]
			var extra := float(after.outputs.get(target,{}).get(product,0)) - float(before.outputs.get(target,{}).get(product,0))
			lines.append(tr("IR_PREVIEW") % [float(after.inputs.get(target,{}).get("water",0)), _res(product), hud._format_signed(extra)])
			lines.append(tr("IR_DRINK") % [hud._format_signed(after.net.water - float(after.unmet.get("water",0))),eco.stock("water")])
			if connected:
				lines.append(_site(eco,eco.canals[target].source) + " · " + tr("IR_OPEN" if opened else "IR_CLOSED"))
				action("valve%d%s" % [target,str(opened)], tr("IR_CLOSE" if opened else "IR_START"), _valve.bind(target,not opened))
			else:
				lines.append(tr("IR_BUILD") % hud._cost_text(eco.CANAL_COST))
				for cell in sources:
					var key := "connect%d:%d" % [target,cell]
					action(key,_site(eco,cell),_connect_canal.bind(target,cell))
					_buttons[key].disabled = not eco.can_afford(eco.CANAL_COST)
	detail.text = "\n".join(lines)
	action("backfarm%d" % target,tr("S_FARM"),open.bind("farm","food",target))


func _connect_canal(field: int, cell: int) -> void:
	GameState.sim.economy.connect_canal(field,cell)
	refresh()


func _valve(field: int, opened: bool) -> void:
	GameState.sim.economy.set_valve(field,opened)
	refresh()


func _plant(cell: int, crop: String) -> void:
	var eco = GameState.sim.economy
	if eco.select_recipe(cell,crop):
		eco.changed.emit()
	refresh()


func _priority(eco) -> void:
	title.text = tr("MG_WORK")
	if target < 0 or target not in eco.building_cells():
		detail.text = tr("MG_CHOOSE")
		for res in eco.BASE_RESOURCES:
			action("res"+res, _res(res), open.bind("reserve", res))
		for cell in eco.building_cells():
			if eco.is_active(cell) and int(eco.def_of(cell).get("workers", 0)) > 0:
				action("job%d" % cell, _site(eco, cell), open.bind("priority", resource, cell))
	else:
		var def: Dictionary = eco.def_of(target)
		var profession := str(def.get("profession", ""))
		var before := _forecast(eco, eco.preferred_cell)
		var after := _forecast(eco, target)
		var lines := PackedStringArray([_site(eco,target)])
		var name_of_job := tr(eco.professions.get(profession, {}).get("name_key", "TAB_PEOPLE"))
		if not eco.is_active(target):
			lines.append(tr("MG_SITE"))
		elif eco.trained_count(profession) == 0 or (float(after.staffing[target]) < 1.0 and float(after.staffing[target]) == float(before.staffing[target])):
			lines.append(tr("MG_NEED_JOB") % name_of_job if eco.trained_count(profession) == 0 else tr("MG_NO_MORE"))
			var reason: String = eco.can_train(profession)
			if reason == "":
				action("train"+profession, tr("MG_TRAIN") % name_of_job, _train.bind(profession))
			else:
				lines.append(tr(reason))
				action("people",tr("TAB_PEOPLE"),hud.show_people)
		elif float(after.staffing[target]) <= float(before.staffing[target]):
			lines.append(tr("MG_ALREADY"))
		else:
			_shown_transfer = after.staffing.duplicate()
			lines.append(tr("MG_ESTIMATE"))
			for cell in eco.building_cells():
				var workers := int(eco.def_of(cell).get("workers", 0))
				var delta := roundi((float(after.staffing[cell]) - float(before.staffing[cell])) * workers)
				if delta != 0:
					lines.append("%s · %s   %+d" % [_site(eco,cell), name_of_job,delta])
				var keys: Dictionary = eco.def_of(cell).get("produces", {})
				for res in keys:
					var amount := float(after.outputs.get(cell, {}).get(res,0)) - float(before.outputs.get(cell, {}).get(res,0))
					if absf(amount) > 0.00001:
						lines.append("%s · %s   %s%s" % [_site(eco,cell), _res(res), hud._format_signed(amount), tr("PER_DAY")])
			action("confirm%d:%s" % [target,resource],tr("MG_CONFIRM"), _apply_priority.bind(target))
		if eco.bronze_study == 0.0 and profession != "":
			var blocker: String = eco.apprentice_blocker(target)
			lines.append(tr("POL_LEARN_HELP"))
			if blocker == "":
				action("mentor%d" % target, tr("POL_LEARN") % name_of_job, _mentor.bind(target))
			elif eco.teaching(target):
				for student in eco.training:
					if int(student.get("mentor", -1)) == target:
						lines.append(tr("POL_LEARNING") % float(student.left))
			else:
				lines.append(tr(blocker))
		detail.text = "\n".join(lines)
	if eco.preferred_cell >= 0:
		detail.text += "\n" + tr("MG_FAVORED") % _site(eco,eco.preferred_cell)
		action("auto",tr("MG_AUTO"), _apply_priority.bind(-1))


func _train(profession: String) -> void:
	GameState.sim.economy.train(profession)
	refresh()


func _apply_priority(cell: int) -> void:
	var eco = GameState.sim.economy
	if cell >= 0 and (cell not in eco.building_cells() or not eco.is_active(cell)):
		refresh()
		return
	if cell >= 0 and _forecast(eco,cell).staffing != _shown_transfer:
		refresh()
		return
	eco.preferred_cell = cell
	eco._compute_staffing()
	open("reserve", resource)


func _offer_text(offer: Dictionary) -> String:
	return tr("TRADE_OFFER") % [offer.amount, _res(offer.sell), offer.receive, _res(offer.buy)]


func _market(eco) -> void:
	title.text = tr("MARKET")
	var lines := PackedStringArray()
	if eco.caravan_present():
		var visit: int = eco.caravan_visit()
		var offer: Dictionary = eco.caravan_offer(visit)
		lines.append(tr("TRADE_HERE"))
		if eco.last_trade == visit:
			lines.append(tr("TRADE_USED"))
		else:
			lines.append(_offer_text(offer))
			lines.append(tr("TRADE_LEFT") % [_res(offer.sell), eco.stock(offer.sell), eco.stock(offer.sell)-offer.amount])
			var needed: int = eco.planned_material(offer.sell)
			if needed > 0:
				lines.append(tr("TRADE_PLAN") % [needed, _res(offer.sell)])
			var why: String = eco.trade_blocker(visit)
			if why == "":
				action("trade%d" % visit, tr("TRADE_ACCEPT"), _accept_trade.bind(visit))
			else:
				lines.append(tr(why))
				if why == "TRADE_NEED":
					action("merchant",tr("TAB_PEOPLE"),hud.show_people)
	else:
		lines.append(tr("TRADE_AWAY") % (3 - eco.market_days % 3))
	if eco.last_trade >= 0:
		lines.append(tr("TRADE_LAST") % _offer_text(eco.caravan_offer(eco.last_trade)))
	detail.text = "\n".join(lines)
	action("contracts",tr("POL_CONTRACT"),open.bind("contract"))
	action("rules", tr("TRADE_RULES"), open.bind("trade_rules", "pots"))


func _accept_trade(visit: int) -> void:
	GameState.sim.economy.trade(visit)
	refresh()


func _trade_rules(eco) -> void:
	title.text = tr("TRADE_RULES")
	var enabled: bool = eco.trade_auto.get(resource,false)
	detail.text = tr("TRADE_HINT") + "\n" + tr("TRADE_RULE") % [_res(resource), eco.trade_reserves.get(resource,0)] + "\n" + tr("TRADE_AUTO_ON" if enabled else "TRADE_AUTO_OFF")
	for offer in eco.TRADE_OFFERS:
		action("good"+offer.sell, _res(offer.sell), open.bind("trade_rules", offer.sell))
	action("less",tr("TRADE_LESS"),_reserve_change.bind(-5))
	_buttons.less.disabled = int(eco.trade_reserves.get(resource,0)) == 0
	action("more",tr("TRADE_MORE"),_reserve_change.bind(5))
	action("automate",tr("TRADE_AUTO"),_toggle_trade)
	action("market",tr("MARKET"),open.bind("market"))


func _reserve_change(amount: int) -> void:
	var eco = GameState.sim.economy
	eco.trade_reserves[resource] = maxi(0,int(eco.trade_reserves.get(resource,0))+amount)
	refresh()


func _toggle_trade() -> void:
	var eco = GameState.sim.economy
	eco.trade_auto[resource] = not eco.trade_auto.get(resource,false)
	refresh()


func _chapters(eco) -> void:
	title.text = tr("CH_PAGE")
	var chapter: int = eco.antiquity_chapter()
	var lines := PackedStringArray()
	for index in range(1,4):
		var mark := "✓ " if index < chapter else ("▸ " if index == chapter else "")
		lines.append(mark + tr("CH_%d" % index))
	if chapter == 0:
		lines.append(tr("CH_STONE"))
	elif chapter < 3:
		var next := chapter + 1
		var met: bool = not eco.bronze_equipment.is_empty() if next == 2 else eco.last_trade >= 0
		lines.append(tr("CH_NEXT") % tr("CH_%d" % next))
		lines.append(("✓ " if met else "○ ") + tr("CH_EQUIP" if next == 2 else "CH_DEAL"))
		if chapter == 2:
			lines.append(tr("CH_IRON_HINT"))
		var costs: Dictionary = eco.CHAPTER_COSTS[next]
		lines.append(tr("CH_COST") % hud._cost_text(costs))
		for res in costs:
			lines.append("%s · %d/%d" % [_res(res), floori(eco.stock(res)), costs[res]])
		action("advance%d" % next,tr("CH_IRON" if next == 2 else "CH_CHARTER"), _enter_chapter.bind(next))
		_buttons["advance%d" % next].disabled = not met or not eco.can_afford(costs)
	else:
		lines.append(tr("CH_CITIES_HINT"))
		for cell in eco.building_cells():
			if eco.building_at(cell) == "forum" and eco.is_active(cell):
				lines.append(tr("CH_FINISHED"))
				break
	detail.text = "\n".join(lines)
	action("work_bronze",tr("ANT_PAGE"),open.bind("bronze"))


func _enter_chapter(next: int) -> void:
	GameState.sim.economy.enter_chapter(next)
	hud._refresh_title()
	refresh()


func _bronze(eco) -> void:
	action("chapters",tr("CH_PAGE"),open.bind("chapters"))
	title.text = tr("ANT_AGE") if eco.first_ingot >= 1.0 else tr("ANT_PAGE")
	if eco.bronze_study != 0.0:
		var block: String = eco.study_blocker()
		detail.text = tr("ANT_INTRO") if eco.bronze_study < 0.0 else tr("ANT_STUDY") % hud._format_days(eco.bronze_study)
		if block != "":
			detail.text += "\n" + tr(block)
		if block == "ANT_SCHOLAR":
			action("scholars", tr("TAB_PEOPLE"), hud.show_people)
		elif block == "ANT_BOOKS":
			action("books", tr("MG_SEE") % _res("books"), open.bind("reserve", "books"))
		elif block == "" and eco.bronze_study < 0.0:
			action("study", tr("ANT_BEGIN"), _study)
	elif eco.first_ingot < 1.0:
		detail.text = tr("ANT_CAST") % floori(100.0 * eco.first_ingot)
		action("miners", tr("TAB_PEOPLE"), hud.show_people)
		for id in ["copper", "tin", "bronze"]:
			action("stock"+id, tr("MG_SEE") % _res(id), open.bind("reserve", id))
	else:
		detail.text = tr("ANT_TOOLS") % eco.stock("bronze")
		for sector in ["field", "quarry"]:
			var label := tr("ANT_FIELD") if sector == "field" else tr("ANT_QUARRY")
			if eco.bronze_equipment.has(sector):
				detail.text += "\n%s · %s" % [label, tr("ANT_DONE")]
			else:
				action("equip"+sector, label, _equip.bind(sector))
				_buttons["equip"+sector].disabled = not eco.can_afford(eco.EQUIPMENT_COST)


func _study() -> void:
	GameState.sim.economy.start_bronze_study()
	refresh()


func _equip(sector: String) -> void:
	GameState.sim.economy.equip_bronze(sector)
	refresh()


func _recipes(eco) -> void:
	var def: Dictionary = eco.def_of(target)
	title.text = _site(eco, target)
	var lines := PackedStringArray([tr("CRAFT_GUIDE")])
	if eco.bronze_study == 0.0:
		action("order%d" % target,tr("POL_ORDER"),open.bind("order",resource,target))
	var recipes: Dictionary = def.get("recipes", {})
	if recipes.is_empty() and def.has("produces"):
		recipes = {def.produces.keys()[0]: def}
	for id in recipes:
		var recipe: Dictionary = recipes[id]
		var formula := "%s → %s" % [hud._cost_text(recipe.consumes), hud._cost_text(recipe.produces)]
		if int(recipe.get("chapter",0)) > eco.antiquity_chapter():
			lines.append("%s · %s" % [formula, tr("CH_LOCK") % tr("CH_%d" % int(recipe.chapter))])
		elif def.produces.has(id):
			lines.append("%s · %s" % [tr("CRAFT_ACTIVE"), formula])
			action("output" + id, tr("MG_SEE") % _res(id), open.bind("reserve", id))
		else:
			action("craft%d:%s" % [target, id], formula, _change_recipe.bind(target, id))
	detail.text = "\n".join(lines)


func _change_recipe(cell: int, id: String) -> void:
	GameState.sim.economy.select_recipe(cell, id)
	refresh()


func _plans(eco) -> void:
	title.text = tr("MG_PLANS")
	var lines := PackedStringArray([tr("MG_CHARGE")])
	for i in eco.plans.size():
		var p: Dictionary = eco.plans[i]
		var label := "%s · %d" % [tr(eco.defs[p.id].name_key), int(p.cell)+1]
		var reason: String = eco.can_build(p.cell, p.id)
		var state := tr(reason) if reason != "" else tr("MG_READY")
		if reason == eco.ERR_COST:
			var short := PackedStringArray()
			for res in eco.defs[p.id].cost:
				var missing := ceili(float(eco.defs[p.id].cost[res]) - eco.stock(res))
				if missing > 0:
					short.append("%d %s" % [missing, _res(res)])
			state = tr("MG_MISSING") % ", ".join(short)
		if i > 0 and reason == "":
			state = tr("MG_AFTER")
		lines.append("%d. %s\n%s · %s" % [i+1,label,hud._cost_text(eco.defs[p.id].cost),state])
		action("cancel%d" % p.cell, tr("MG_REMOVE") % label, _cancel.bind(int(p.cell)))
	if eco.plans.size() == 2:
		action("swap",tr("MG_SWAP"), _swap)
	if eco.plans.size() < 2:
		action("add",tr("MG_ADD"), hud._open_build_sheet.bind(-1,true))
	if eco.plans.is_empty():
		lines.append(tr("MG_NO_PLAN"))
	detail.text = "\n".join(lines)


func _cancel(cell: int) -> void:
	var plans: Array = GameState.sim.economy.plans
	for i in plans.size():
		if plans[i].cell == cell:
			plans.remove_at(i)
			break
	refresh()


func _swap() -> void:
	var plans: Array = GameState.sim.economy.plans
	if plans.size() == 2:
		plans.reverse()
	refresh()


func _voice(eco) -> void:
	title.text = tr("MG_VILLAGER")
	var flow := _forecast(eco,eco.preferred_cell)
	for cell in flow.waiting:
		var missing: String = flow.waiting[cell]
		detail.text = tr("MG_VOICE_INPUT") % [tr(eco.def_of(cell).name_key),_res(missing)]
		action("voice"+missing,tr("MG_SEE") % _res(missing),open.bind("reserve",missing))
		return
	for res in ["food","water"]:
		if flow.unmet.has(res) or (flow.net[res] < 0 and eco.stock(res) < -2.0 * flow.net[res]):
			detail.text = tr("MG_VOICE_LOW") % _res(res)
			action("voice"+res,tr("MG_SEE") % _res(res),open.bind("reserve",res))
			return
	detail.text = tr("MG_VOICE_WALK")
	action("visit",tr("TAB_TOWNHALL"),hud.show_townhall)


func _mentor(cell: int) -> void:
	GameState.sim.economy.apprentice(cell)
	refresh()


func _policy(eco) -> void:
	var food := resource == "food"
	title.text = tr("POL_PANTRY" if food else "POL_SEEDS")
	if food:
		detail.text = tr("POL_FLOOR") % [eco.pantry_days, eco.protected_stock("food"), eco.stock("food")]
		var next: int = (eco.season_index() + 1) % 4
		var days: int = eco.SEASON_DAYS - eco.elapsed_days % eco.SEASON_DAYS
		var flow := _forecast(eco, eco.preferred_cell)
		var net := float(flow.net.food) - float(flow.unmet.get("food", 0))
		detail.text += "\n" + tr("POL_OUTLOOK") % [tr(eco.SEASONS[next]), days, maxf(0, eco.stock("food") + days * net)]
		var earliest := INF
		var tick_days := 1.0 / float(GameState.sim.ticks_per_day)
		for cell in eco.building_cells():
			var staff := float(flow.staffing.get(cell, 0))
			if eco.building_at(cell) == "field" and eco.def_of(cell).produces.has("food") and staff > 0:
				earliest = minf(earliest, (floorf(float(eco.sowing.get(cell, 0)) / staff / tick_days) + 1.0) * tick_days)
		if is_inf(earliest):
			detail.text += "\n" + tr("POL_NO_HARVEST")
		else:
			detail.text += "\n" + tr("POL_HARVEST") % earliest
			if net < 0 and eco.stock("food") / -net < earliest:
				detail.text += "\n" + tr("POL_HARVEST_GAP") % (earliest - eco.stock("food") / -net)
		if net < 0 and eco.stock("food") / -net < days:
			detail.text += "\n" + tr("POL_GAP") % (days - eco.stock("food") / -net)
	else:
		detail.text = tr("POL_SEED_INFO") % [mini(eco.seed_target, floori(eco.stock("grain"))), eco.seed_target, eco.extra_plots.size()]
	for change in [-1, 1]:
		var step: int = change if food else change * eco.SEED_COST
		action("adjust%s%d" % [resource,step], "%+d" % step, _policy_change.bind(step))
	action("other"+resource,tr("POL_SEEDS" if food else "POL_PANTRY"),open.bind("policy","grain" if food else "food"))
	action("ledger"+resource,tr("MG_SEE") % _res(resource),open.bind("reserve",resource))


func _policy_change(step: int) -> void:
	var eco = GameState.sim.economy
	if resource == "food":
		eco.pantry_days = clampi(eco.pantry_days + step, 0, 30)
	else:
		eco.seed_target = clampi(eco.seed_target + step, 0, 400)
	refresh()


func _order(eco) -> void:
	title.text = tr("POL_ORDER_AT") % _site(eco,target)
	var def: Dictionary = eco.def_of(target)
	var output: String = def.produces.keys()[0]
	var order: Dictionary = eco.orders.get(target, {})
	detail.text = tr("POL_AUTO") if order.is_empty() else tr("POL_TARGET_STATE" if order.kind == "target" else "POL_BATCH_STATE") % [float(order.amount), _res(output)]
	detail.text += "\n" + tr("POL_COST") % [quantity, _res(output), _input_cost(def, output, quantity, eco)]
	action("smaller", "−1", _quantity.bind(-1))
	action("larger", "+1", _quantity.bind(1))
	action("target%d" % target,tr("POL_TARGET") % quantity,_set_order.bind("target"))
	action("batch%d" % target,tr("POL_BATCH") % quantity,_set_order.bind("batch"))
	action("reset%d" % target,tr("POL_AUTO"),_set_order.bind("auto"))
	action("mentorpage%d" % target,tr("MG_WORK"),open.bind("priority",output,target))


func _input_cost(def: Dictionary, output: String, amount: int, eco) -> String:
	var parts := PackedStringArray()
	for res in def.consumes:
		var cost := amount * float(def.consumes[res]) / (float(def.produces[output]) * float(eco._perk_production(output)))
		parts.append("%.1f %s" % [cost, _res(res)])
	return ", ".join(parts)


func _quantity(step: int) -> void:
	quantity = clampi(quantity + step, 1, 100)
	refresh()


func _set_order(kind: String) -> void:
	GameState.sim.economy.set_order(target, kind, quantity)
	refresh()


func _contracts(eco) -> void:
	title.text = tr("POL_CONTRACT")
	var pending: bool = not eco.contract.is_empty()
	var good: String = eco.contract.res if pending else contract_good
	var units: int = int(eco.contract.amount) if pending else int(eco.CONTRACT_UNITS[good]) * contract_lots
	var reward: int = int(eco.contract.tools) if pending else 2 * contract_lots
	var days: int = int(eco.contract.due) - eco.elapsed_days if pending else 3
	var left: float = eco.stock(good) - units
	detail.text = tr("POL_OFFER") % [units,_res(good),reward,days,maxf(left,0),_res(good),eco.protected_stock(good)]
	var flow := _forecast(eco,eco.preferred_cell)
	var production := 0.0
	for output in flow.outputs.values():
		production += float(output.get(good, 0))
	if production > 0:
		detail.text += "\n" + tr("POL_WORK") % (units / production)
	else:
		detail.text += "\n" + tr("POL_IDLE")
	if good == "food" and eco.food_demand() > 0:
		detail.text += "\n" + tr("POL_COVER") % (maxf(left,0) / eco.food_demand())
	if pending:
		var why: String = eco.delivery_blocker()
		if why.is_empty():
			action("deliver",tr("POL_DELIVER"),_deliver)
		else:
			detail.text += "\n" + tr(why)
	elif eco.caravan_present() and eco.caravan_visit() != eco.contract_visit:
		for id in eco.CONTRACT_UNITS:
			action("offer"+id,_res(id),_choose_good.bind(id))
		action("lots",tr("POL_LOTS") % (3 - contract_lots),_change_lots)
		if eco.workers_at(eco.market_cell) > 0:
			action("sign%d" % eco.caravan_visit(),tr("POL_SIGN"),_sign.bind(eco.caravan_visit()))
		else:
			detail.text += "\n" + tr("TRADE_NEED")
	else:
		detail.text += "\n" + tr("POL_NEXT")
	action("backmarket",tr("MARKET"),open.bind("market"))


func _choose_good(id: String) -> void:
	contract_good = id
	refresh()


func _change_lots() -> void:
	contract_lots = 3 - contract_lots
	refresh()


func _sign(visit: int) -> void:
	GameState.sim.economy.sign_contract(visit,contract_good,contract_lots)
	refresh()


func _deliver() -> void:
	GameState.sim.economy.deliver_contract()
	refresh()
