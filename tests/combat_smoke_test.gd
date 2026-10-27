extends SceneTree

# From a command prompt in this folder:
#   godot --headless --path . --script res://tests/combat_smoke_test.gd
# Tests the authoritative engine; GUI drag behavior requires manual Godot testing.
const CombatScript = preload("res://scripts/combat_engine.gd")
var failures := 0

func _initialize() -> void:
	var engine: AptitudeCombatEngine = CombatScript.new()
	engine.start(["bryan", "carlos", "manny", "cristian_hb"])
	_check(engine.party.size() == 4, "four heroes spawned")
	_check(int(hero_deck_count(engine,"bryan")) == 10, "starter deck has ten cards")
	_check(engine.enemies.size() == 1, "one Roboduck spawns in the intro")
	_check(int(engine.hero_by_id("bryan")["hp"]) == 60, "Bryan starts with 60 HP")
	# Locate a playable attack in Bryan's initial hand or force a known starter card.
	var hero: Dictionary = engine.hero_by_id("bryan")
	hero["hand"].insert(0, "attack")
	var starting_energy: int = int(hero["energy"])
	var enemy_start: int = int(engine.enemies[0]["hp"])
	var seq_start: int = engine.next_sequence
	var invalid: String = engine.submit_card("bryan", 0, "not_a_robot")
	_check(invalid != "", "invalid target rejected")
	_check(int(hero["energy"]) == starting_energy, "invalid target costs no energy")
	_check(int(engine.enemies[0]["hp"]) == enemy_start, "invalid target deals no damage")
	_check(engine.next_sequence == seq_start, "invalid target not queued")
	var accepted: String = engine.submit_card("bryan", 0, "roboduck_1")
	_check(accepted == "", "valid robot target accepted")
	_check(int(engine.enemies[0]["hp"]) == enemy_start - 1, "damage applied to selected robot")
	_check(int(hero["energy"]) == starting_energy - 1, "accepted card deducts energy")
	_check(engine.next_sequence == seq_start + 1, "accepted card consumes one FIFO sequence")
	# Block is SELF ONLY. Invalid attempts must not consume energy or FIFO slots.
	var ally: Dictionary = engine.hero_by_id("carlos")
	hero["hand"].insert(0, "block")
	var before_block: int = int(ally["block"])
	var before_energy: int = int(hero["energy"])
	var blocked_seq: int = engine.next_sequence
	var rejected: String = engine.submit_card("bryan", 0, "carlos")
	_check(rejected != "", "Block rejects another hero")
	_check(int(ally["block"]) == before_block, "ally not blocked by other hero's Block")
	_check(int(hero["energy"]) == before_energy and engine.next_sequence == blocked_seq, "invalid Block costs nothing and adds no action")
	_check(engine.submit_card("bryan", 0, "bryan") == "", "Block accepts only its owner")
	_check(int(hero["block"]) == 1, "caster gains own Block")
	_check(engine.next_sequence == seq_start + 2, "accepted actions maintain FIFO sequence")
	# Regression: viewing another hero must NEVER restore injured/defeated robots.
	var damage_preserved: int = int(engine.enemies[0]["hp"])
	# One-enemy encounter: use a second encounter to verify defeated instances.
	var preserved_sequence: int = engine.next_sequence
	engine.select_hero("carlos")
	_check(int(engine.enemies[0]["hp"]) == damage_preserved, "selecting another hero preserves robot damage")
	_check(int(engine.enemies[0]["hp"]) == damage_preserved, "hero switching cannot revive the active Roboduck")
	_check(engine.next_sequence == preserved_sequence, "selecting another hero does not reset FIFO sequence")
	_check(engine.active_hero == "carlos", "hero selection updates the active hand only")
	# Cristian & HB are a single selectable combined unit.
	var alternate: AptitudeCombatEngine = CombatScript.new()
	alternate.start(["bryan", "carlos", "manny", "cristian_hb"])
	_check(alternate.party.size() == 4, "Cristian & HB fill one party slot")
	_check(not alternate.hero_by_id("cristian_hb").is_empty(), "combined unit retains a playable deck")
	alternate.enemies[0]["hp"] = 0
	alternate.select_hero("cristian_hb")
	_check(int(alternate.enemies[0]["hp"]) == 0, "selecting the combined unit does not revive defeated enemies")
	# Duplicate IDs never create extra player slots.
	alternate.start(["bryan", "carlos", "manny", "cristian_hb"])
	_check(alternate.party.size() == 4, "combined roster uses four hero slots")
	_check(alternate.heroes.size() == 4, "four playable hero identities (including combined unit)")
	_check(int(alternate.hero_by_id("cristian_hb")["max_hp"]) == 60, "Cristian & HB share one 60 HP pool")
	alternate.start(["bryan", "bryan", "cristian_hb"])
	_check(alternate.party.size() == 2, "duplicate hero IDs cannot create extra players")
	if failures == 0:
		print("PASS: combat engine smoke checks")
	else:
		push_error("FAIL: %d combat smoke checks" % failures)
	quit(1 if failures else 0)

func _check(condition: bool, title: String) -> void:
	if condition:
		print("OK: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func hero_deck_count(engine: AptitudeCombatEngine, id: String) -> int:
	var definition: Dictionary = engine.heroes[id]
	return definition["starter_deck"].size()
