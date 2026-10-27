class_name AptitudeCombatEngine
extends RefCounted

# Local authority now; identical submit_card() boundary can be hosted by server later.
# v0.7: encounter-driven enemy spawns; each instance gets a unique target ID.
# Accepted commands are serialized and executed immediately in global acceptance order.
signal changed
var heroes: Dictionary = {}
var cards: Dictionary = {}
var enemy_defs: Dictionary = {}
var encounters: Dictionary = {}
var encounter_id: String = "city_intro"
var battlefield_background: String = ""
var party: Array = []
var enemies: Array = []
var active_hero: String = "bryan"
var phase: String = "player"
var round_number: int = 1
var next_sequence: int = 1
var events: Array[String] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var revision: int = 0
var coins: int = 0

func _init() -> void:
	heroes = _read_json("res://data/heroes.json")
	cards = _read_json("res://data/cards.json")
	enemy_defs = _read_json("res://data/enemies.json")
	encounters = _read_json("res://data/encounters.json")
	rng.seed = 42817
	start(["bryan", "carlos", "manny", "cristian_hb"])

func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

# Starts a NEW encounter and intentionally resets all combat state.
# Only call this on an explicit New Run or Restart, never to select a hero.
# The roster has four gameplay slots: Cristian & HB share one combined unit.
func start(ids: Array, next_encounter_id: String = "city_intro", options: Dictionary = {}) -> void:
	var chosen: Array[String] = []
	for raw_id in ids:
		var hero_id: String = str(raw_id)
		if heroes.has(hero_id) and not chosen.has(hero_id):
			chosen.append(hero_id)
			if chosen.size() == 4:
				break
	if chosen.is_empty():
		push_error("Cannot start combat without at least one valid hero")
		return
	if not encounters.has(next_encounter_id):
		push_error("Unknown encounter: " + next_encounter_id)
		return
	encounter_id = next_encounter_id
	var encounter: Dictionary = encounters[encounter_id]
	battlefield_background = str(encounter.get("background", ""))
	party.clear()
	enemies.clear()
	events.clear()
	phase = "player"
	round_number = 1
	next_sequence = 1
	revision = 0
	coins = int(options.get("coins", 0))
	var passives_enabled: bool = bool(options.get("apply_passives", false))
	var single_player: bool = chosen.size() == 1
	for id in chosen:
		var definition: Dictionary = heroes[id]
		var deck: Array = definition["starter_deck"].duplicate()
		if single_player and options.has("deck"):
			deck = (options["deck"] as Array).duplicate()
		_shuffle(deck)
		var maximum_hp: int = int(options.get("hero_max_hp", definition["max_hp"])) if single_player else int(definition["max_hp"])
		var current_hp: int = clampi(int(options.get("hero_hp", maximum_hp)), 1, maximum_hp) if single_player else maximum_hp
		var starting_block: int = 0
		if passives_enabled and id == "bryan":
			starting_block = 1
		elif passives_enabled and id == "cristian_hb":
			starting_block = 2
		party.append({"id":id, "hp":current_hp, "max_hp":maximum_hp,
			"block":starting_block, "strength":0, "energy":int(definition["base_energy"]),
			"hand":[], "draw":deck, "discard":[], "exhaust":[], "powers_played":[], "done":false,
			"passives_enabled":passives_enabled, "first_attack_used":false})
	# Each spawn receives its own runtime instance ID. Reusing a definition
	# never shares HP or status between different physical enemies.
	var spawn_counts: Dictionary = {}
	for raw_type in encounter["enemies"]:
		var type_id: String = str(raw_type)
		if not enemy_defs.has(type_id):
			push_error("Unknown enemy type: " + type_id)
			continue
		spawn_counts[type_id] = int(spawn_counts.get(type_id, 0)) + 1
		var instance_id: String = "%s_%d" % [type_id, int(spawn_counts[type_id])]
		var e: Dictionary = enemy_defs[type_id]
		var target_hp: int = int(e["hp"])
		var target_damage: int = int(e["damage"])
		if bool(options.get("scale_for_party", false)):
			# Proportional solo-to-four-player challenge, opt-in for Act 1 runs.
			var team_size: int = chosen.size()
			target_hp = maxi(1, roundi(float(target_hp) * (0.60 + 0.13 * float(team_size - 1))))
			target_damage = maxi(1, roundi(float(target_damage) * (0.50 + 0.16 * float(team_size - 1))))
		enemies.append({"id":instance_id, "type_id":type_id,
			"hp":target_hp, "max_hp":target_hp, "block":0,
			"damage":target_damage})
	active_hero = str(party[0]["id"])
	for hero in party:
		var bonus_draw: int = 1 if passives_enabled and str(hero["id"]) == "manny" else 0
		_draw(hero, 5 + bonus_draw)
	log_line("%s: The robots approach. Shared player phase begins." % str(encounter["name"]))
	changed.emit()

func _shuffle(deck: Array) -> void:
	for i in range(deck.size()-1, 0, -1):
		var j: int = rng.randi_range(0,i)
		var tmp = deck[i]
		deck[i]=deck[j]
		deck[j]=tmp

func _draw(hero: Dictionary, count: int) -> void:
	for i in range(count):
		if hero["draw"].is_empty():
			if hero["discard"].is_empty():
				return
			hero["draw"] = hero["discard"].duplicate()
			hero["discard"].clear()
			_shuffle(hero["draw"])
		if hero["hand"].size() >= 10:
			return
		hero["hand"].append(hero["draw"].pop_back())

func hero_by_id(id: String) -> Dictionary:
	for h in party:
		if h["id"] == id:
			return h
	return {}

# A Skill defaults to SELF. Only a card with explicit target="ally" or
# target="all_allies" can be played on a teammate / the entire team.
# The UI and the authoritative engine consult this same rule.
func card_target_type(card: Dictionary) -> String:
	if card.has("target"):
		return str(card["target"])
	if str(card.get("type", "")) == "skill":
		return "self"
	return "self" # safe default for future non-attack utility cards

func submit_card(hero_id: String, card_index: int, target_id: String) -> String:
	# This function is the ONLY authoritative entrypoint for card plays.
	if phase != "player":
		return "Not in player phase"
	var hero: Dictionary = hero_by_id(hero_id)
	if hero.is_empty() or hero["done"] or int(hero["hp"]) <= 0:
		return "Hero cannot act"
	if card_index < 0 or card_index >= hero["hand"].size():
		return "Card not in hand"
	var card_id: String = str(hero["hand"][card_index])
	if not cards.has(card_id):
		return "Unknown card"
	var card: Dictionary = cards[card_id]
	var cost: int = int(card["cost"])
	if cost > int(hero["energy"]):
		return "Not enough energy"
	var target_type: String = card_target_type(card)
	match target_type:
		"enemy":
			if not _enemy_alive(target_id):
				return "Choose a living enemy"
		"self":
			if target_id != hero_id:
				return "This card targets its owner"
		"ally", "all_allies":
			var chosen: Dictionary = hero_by_id(target_id)
			if chosen.is_empty() or int(chosen["hp"]) <= 0:
				return "Choose a living ally"
		_:
			return "Unsupported card target type"
	if str(card["type"]) == "power" and hero["powers_played"].has(card_id):
		return "Power already used this fight"
	var seq: int = next_sequence
	next_sequence += 1
	hero["energy"] = int(hero["energy"]) - cost
	hero["hand"].remove_at(card_index)
	# Global FIFO: requests are serialized at this authority boundary; each accepted
	# action resolves atomically before another accepted command is processed.
	log_line("#%d  %s → %s" % [seq, str(heroes[hero_id]["name"]), str(card["name"])])
	for effect in card["effects"]:
		# Strength boosts an ATTACK card's direct damage, never block/power.
		# Calculate at accepted-action execution time, so an earlier Demon
		# buff immediately affects later attacks in the same global FIFO.
		var resolved_effect: Dictionary = effect.duplicate(true)
		if str(card["type"]) == "attack" and str(effect["op"]) == "damage":
			resolved_effect["value"] = int(effect["value"]) + int(hero["strength"])
			if passives_enabled_for_hero(hero) and hero_id == "carlos" and not bool(hero["first_attack_used"]):
				resolved_effect["value"] = int(resolved_effect["value"]) + 1
		var targets: Array = []
		match target_type:
			"self": targets = [hero]
			"ally": targets = [hero_by_id(target_id)]
			"all_allies":
				for teammate in party:
					if int(teammate["hp"]) > 0:
						targets.append(teammate)
			"enemy": targets = [_enemy_by_id(target_id)]
		for target in targets:
			if target.is_empty():
				continue
			_apply_effect(resolved_effect, target)
	if str(card["type"]) == "attack":
		hero["first_attack_used"] = true
	# Power cards are one-use for the entire encounter and do not recycle.
	if str(card["type"]) == "power":
		hero["powers_played"].append(card_id)
		hero["exhaust"].append(card_id)
	else:
		hero["discard"].append(card_id)
	revision += 1
	_check_outcome()
	changed.emit()
	return ""

func passives_enabled_for_hero(hero: Dictionary) -> bool:
	return bool(hero.get("passives_enabled", false))

func _apply_effect(effect: Dictionary, target: Dictionary) -> void:
	var amount: int = int(effect["value"])
	match str(effect["op"]):
		"damage":
			var absorbed: int = min(amount, int(target["block"]))
			target["block"] = int(target["block"]) - absorbed
			target["hp"] = max(0,int(target["hp"]) - (amount - absorbed))
		"block": target["block"] = int(target["block"]) + amount
		"heal": target["hp"] = min(int(target["max_hp"]), int(target["hp"]) + amount)
		"draw": _draw(target, amount)
		"strength": target["strength"] = int(target["strength"]) + amount

func _enemy_by_id(id: String) -> Dictionary:
	for e in enemies:
		if e["id"] == id:
			return e
	return {}

func _enemy_alive(id: String) -> bool:
	var e: Dictionary = _enemy_by_id(id)
	return not e.is_empty() and int(e["hp"]) > 0

func select_hero(id: String) -> void:
	if not hero_by_id(id).is_empty():
		active_hero = id
		changed.emit()

func mark_done(hero_id: String) -> void:
	if phase != "player":
		return
	var hero: Dictionary = hero_by_id(hero_id)
	if hero.is_empty():
		return
	hero["done"] = true
	log_line(str(heroes[hero_id]["name"]) + " is Done")
	var everybody_done: bool = true
	for h in party:
		if int(h["hp"]) > 0 and not h["done"]:
			everybody_done = false
	if everybody_done:
		_enemy_phase()
	changed.emit()

func _enemy_phase() -> void:
	phase = "enemy"
	# Every surviving robot performs a party-wide attack. Each LIVING hero
	# separately takes the FULL listed damage; block is applied individually.
	# Defeated robots do nothing, and heroes who reach 0 HP stop being hit.
	for enemy in enemies:
		if int(enemy["hp"]) <= 0:
			continue
		var amount: int = int(enemy["damage"])
		var hit_count: int = 0
		for hero in party:
			if int(hero["hp"]) <= 0:
				continue
			_apply_effect({"op":"damage", "value":amount}, hero)
			hit_count += 1
		if hit_count == 0:
			break
		log_line(str(enemy_defs[enemy["type_id"]]["name"]) + " attacks all %d living heroes for %d each" % [hit_count, amount])
	_check_outcome()
	if phase == "victory" or phase == "defeat":
		return
	round_number += 1
	phase = "player"
	for hero in party:
		# Block is temporary; Power-granted Strength persists until encounter end.
		hero["block"] = 0
		hero["done"] = int(hero["hp"]) <= 0
		hero["energy"] = int(heroes[str(hero["id"])]["base_energy"])
		for card_id in hero["hand"]:
			hero["discard"].append(card_id)
		hero["hand"].clear()
		if int(hero["hp"]) > 0:
			_draw(hero, int(heroes[str(hero["id"])]["draw_count"]))
	log_line("Round %d begins" % round_number)

func _check_outcome() -> void:
	var all_dead: bool = true
	for enemy in enemies:
		if int(enemy["hp"]) > 0: all_dead = false
	if all_dead:
		phase = "victory"
		coins += 25
		log_line("Victory! +25 coins")
		return
	all_dead = true
	for hero in party:
		if int(hero["hp"]) > 0: all_dead = false
	if all_dead:
		phase = "defeat"
		log_line("Defeat")

func log_line(line: String) -> void:
	events.push_front(line)
	if events.size() > 8:
		events.resize(8)
