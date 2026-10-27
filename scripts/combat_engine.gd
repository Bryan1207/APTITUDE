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
			"weak":0, "vulnerable":0, "plating":0, "focus":0,
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
			"weak":0, "vulnerable":0, "strength":0,
			"damage":target_damage, "next_move":{}})
	active_hero = str(party[0]["id"])
	_prepare_enemy_intents()
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
	if str(card.get("hero", hero_id)) != hero_id:
		return "This card belongs to another hero"
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
		# Every effect can override the card's main target (e.g. hit an enemy,
		# then draw a card for the caster). Global accepted-action FIFO remains intact.
		var resolved: Dictionary = effect.duplicate(true)
		var effect_type: String = str(effect.get("target", target_type))
		var targets: Array = []
		match effect_type:
			"self": targets = [hero]
			"ally": targets = [hero_by_id(target_id)]
			"all_allies":
				for teammate in party:
					if int(teammate["hp"]) > 0:
						targets.append(teammate)
			"enemy": targets = [_enemy_by_id(target_id)]
		if str(effect["op"]) == "damage":
			var base_damage: int = int(effect["value"])
			if str(card["type"]) == "attack":
				base_damage += int(hero["strength"])
				if int(hero.get("weak", 0)) > 0:
					base_damage = maxi(0, roundi(float(base_damage) * 0.75))
			var hit_count: int = maxi(1, int(effect.get("hits", 1)))
			for index in range(hit_count):
				var attack_value: int = base_damage
				if str(card["type"]) == "attack" and passives_enabled_for_hero(hero) and hero_id == "carlos" and not bool(hero["first_attack_used"]) and index == 0:
					attack_value += 1
				for target in targets:
					if target.is_empty() or int(target.get("hp", 0)) <= 0:
						continue
					_apply_effect({"op":"damage", "value":attack_value}, target)
		else:
			for target in targets:
				if target.is_empty():
					continue
				_apply_effect(resolved, target)
	if str(card["type"]) == "attack":
		hero["first_attack_used"] = true
	# Power cards are one-use for the entire encounter and do not recycle.
	if str(card["type"]) == "power":
		hero["powers_played"].append(card_id)
		hero["exhaust"].append(card_id)
	elif bool(card.get("exhaust", false)) or card_id == "carlos_quick_reload":
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
			if int(target.get("vulnerable", 0)) > 0:
				amount = maxi(0, roundi(float(amount) * 1.5))
			var absorbed: int = mini(amount, int(target["block"]))
			target["block"] = int(target["block"]) - absorbed
			target["hp"] = maxi(0, int(target["hp"]) - (amount - absorbed))
		"block": target["block"] = int(target["block"]) + amount
		"heal": target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + amount)
		"draw": _draw(target, amount)
		"strength": target["strength"] = int(target["strength"]) + amount
		"weak", "vulnerable", "plating", "focus":
			target[str(effect["op"])] = int(target.get(str(effect["op"]), 0)) + amount

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
	# A repeated Done request is a no-op. In a shared player phase it
	# must not append duplicate log entries or broadcast a false change.
	if hero.is_empty() or bool(hero["done"]) or int(hero["hp"]) <= 0:
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

## Fixed, telegraphed machine patterns. Original Roboduck (and the reserved
## prototype boss) retain their established attack-every-turn behavior.
func _prepare_enemy_intents() -> void:
	for enemy in enemies:
		var definition: Dictionary = enemy_defs[str(enemy["type_id"])]
		var pattern: Array = definition.get("moves", [])
		if pattern.is_empty():
			enemy["next_move"] = {"kind":"attack", "power":1.0, "hits":1}
		else:
			enemy["next_move"] = (pattern[(round_number - 1) % pattern.size()] as Dictionary).duplicate(true)

func enemy_intent_text(enemy: Dictionary) -> String:
	if int(enemy["hp"]) <= 0:
		return ""
	var move: Dictionary = enemy.get("next_move", {})
	var kind: String = str(move.get("kind", "attack"))
	match kind:
		"guard": return "◆ +%d" % int(move.get("block", 3))
		"charge": return "↑ +%d" % int(move.get("strength", 1))
		_:
			var attack_damage: int = maxi(1, roundi(float(enemy["damage"]) * float(move.get("power", 1.0))))
			attack_damage += int(enemy.get("strength", 0))
			if int(enemy.get("weak", 0)) > 0:
				attack_damage = maxi(1, roundi(float(attack_damage) * 0.75))
			# The solo intent must match the actual damage dealt to its only
			# target. In co-op, each hero may have a different Vulnerable value.
			if party.size() == 1 and int(party[0].get("vulnerable", 0)) > 0:
				attack_damage = maxi(1, roundi(float(attack_damage) * 1.5))
			var hits: int = maxi(1, int(move.get("hits", 1)))
			var effect_note: String = ""
			if kind == "attack_weak":
				effect_note = " Weak %d" % int(move.get("status", 1))
			elif kind == "attack_vulnerable":
				effect_note = " Vuln %d" % int(move.get("status", 1))
			return "⚔ %d" % attack_damage + (" ×%d" % hits if hits > 1 else "") + effect_note

func _enemy_phase() -> void:
	phase = "enemy"
	# Tick only debuffs that were present before this enemy phase. Otherwise
	# a machine applying Weak or Vulnerable would clear its own effect before
	# the hero ever gets a chance to act or suffer the follow-up attack.
	var prior_hero_debuffs: Dictionary = {}
	for hero in party:
		prior_hero_debuffs[str(hero["id"])] = {
			"weak": int(hero.get("weak", 0)),
			"vulnerable": int(hero.get("vulnerable", 0))
		}
	for enemy in enemies:
		if int(enemy["hp"]) <= 0:
			continue
		# Guard is temporary protection for the following player turn,
		# not armor that silently accumulates across multiple rounds.
		# Clear the previous guard BEFORE resolving this enemy's move so
		# a new Guard action is still available to the next player phase.
		enemy["block"] = 0
		var move: Dictionary = enemy.get("next_move", {"kind":"attack"})
		var kind: String = str(move.get("kind", "attack"))
		var name: String = str(enemy_defs[str(enemy["type_id"])]["name"])
		match kind:
			"guard":
				enemy["block"] = int(enemy["block"]) + int(move.get("block", 3))
				log_line(name + " braces behind armor.")
			"charge":
				var strength: int = int(move.get("strength", 1))
				if bool(move.get("team", false)):
					for machine in enemies:
						if int(machine["hp"]) > 0:
							machine["strength"] = int(machine.get("strength", 0)) + strength
				else:
					enemy["strength"] = int(enemy["strength"]) + strength
				log_line(name + " charges up.")
			_:
				var amount: int = maxi(1, roundi(float(enemy["damage"]) * float(move.get("power", 1.0))))
				amount += int(enemy.get("strength", 0))
				if int(enemy.get("weak", 0)) > 0:
					amount = maxi(1, roundi(float(amount) * 0.75))
				var hits: int = maxi(1, int(move.get("hits", 1)))
				for hero in party:
					if int(hero["hp"]) <= 0:
						continue
					for _hit in range(hits):
						_apply_effect({"op":"damage","value":amount}, hero)
					if kind == "attack_weak":
						_apply_effect({"op":"weak", "value":int(move.get("status", 1))}, hero)
					elif kind == "attack_vulnerable":
						_apply_effect({"op":"vulnerable", "value":int(move.get("status", 1))}, hero)
				log_line("%s attacks for %d%s." % [name, amount, " x%d" % hits if hits > 1 else ""])
	_check_outcome()
	if phase == "victory" or phase == "defeat":
		return
	round_number += 1
	phase = "player"
	for enemy in enemies:
		enemy["weak"] = maxi(0, int(enemy.get("weak", 0)) - 1)
		enemy["vulnerable"] = maxi(0, int(enemy.get("vulnerable", 0)) - 1)
	_prepare_enemy_intents()
	for hero in party:
		hero["block"] = int(hero.get("plating", 0))
		hero["done"] = int(hero["hp"]) <= 0
		hero["energy"] = int(heroes[str(hero["id"])]["base_energy"])
		for card_id in hero["hand"]:
			hero["discard"].append(card_id)
		hero["hand"].clear()
		if int(hero["hp"]) > 0:
			_draw(hero, int(heroes[str(hero["id"])]["draw_count"]) + int(hero.get("focus", 0)))
		var previous: Dictionary = prior_hero_debuffs[str(hero["id"])]
		if int(previous["weak"]) > 0:
			hero["weak"] = maxi(0, int(hero.get("weak", 0)) - 1)
		if int(previous["vulnerable"]) > 0:
			hero["vulnerable"] = maxi(0, int(hero.get("vulnerable", 0)) - 1)
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
