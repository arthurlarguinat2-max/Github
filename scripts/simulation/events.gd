## Random events with choices (travelers, storms, harvests...).
## Pure logic; definitions come from data/events.json.
extends RefCounted


## Picks an event that fits the current state, or "" (weighted random).
static func pick(sim, events: Array, rng: RandomNumberGenerator) -> String:
	var candidates: Array = []
	var total := 0.0
	for ev in events:
		if sim.day() < int(ev.get("min_day", 0)):
			continue
		if sim.economy.population < int(ev.get("min_population", 0)):
			continue
		candidates.append(ev)
		total += float(ev.get("weight", 1))
	if candidates.is_empty():
		return ""
	var roll := rng.randf() * total
	for ev in candidates:
		roll -= float(ev.get("weight", 1))
		if roll <= 0.0:
			return str(ev.id)
	return str(candidates[-1].id)


static func find(events: Array, id: String) -> Dictionary:
	for ev in events:
		if str(ev.get("id", "")) == id:
			return ev
	return {}


## Applies the effects of a choice. Newcomers only arrive if there is room.
static func apply(sim, effects: Dictionary) -> void:
	var eco = sim.economy
	for key in effects:
		var value := float(effects[key])
		match str(key):
			"population":
				if value > 0.0:
					eco.population += mini(int(value), maxi(0, eco.housing() - eco.population))
				else:
					eco.population = maxi(0, eco.population + int(value))
			"happiness":
				eco.happiness = clampf(eco.happiness + value, 0.0, 100.0)
			"health":
				eco.health = clampf(eco.health + value, 0.0, 100.0)
			_:
				eco.stocks[key] = maxf(0.0, eco.stock(str(key)) + value)
