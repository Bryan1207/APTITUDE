extends SceneTree

# Run from project root:
# godot --headless --path . --script res://tests/simple_cards_test.gd
# The tests are engine-only; manual GUI test checks drag/drop and yellow pulse.
const CombatScript = preload("res://scripts/combat_engine.gd")
var failures: int = 0

func _initialize() -> void:
	_test_card_data()
	_test_power_strength_and_fifo()
	_test_power_can_buff_ally()
	_test_skill_targeting_rules()
	_test_shared_enemy_attacks()
	_test_dead_enemy_does_not_attack()
	_test_four_player_limit_and_combined_duo()
	_test_encounter_templates_and_distinct_spawns()
	if failures == 0:
		print("PASS: simple card / shared damage tests")
	else:
		push_error("FAIL: %d simple card / shared damage tests" % failures)
	quit(1 if failures > 0 else 0)

func _check(condition: bool, title: String) -> void:
	if condition:
		print("OK: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)

func _test_card_data() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	_check(game.cards.size() == 27, "three basic cards plus 24 distinct hero cards")
	_check(game.cards.has("attack") and game.cards.has("block") and game.cards.has("demon"), "three named cards")
	for card_id in ["attack", "block", "demon"]:
		var card: Dictionary = game.cards[card_id]
		_check(int(card["card_value"]) == 1, card_id + " card value is 1")
	for hero_id in ["bryan", "carlos", "manny", "cristian_hb"]:
		var hero_def: Dictionary = game.heroes[hero_id]
		var deck: Array = hero_def["starter_deck"]
		_check(deck.size() == 10, hero_id + " has 10-card deck")
		_check(deck.count("attack") == 5 and deck.count("block") == 4 and deck.count("demon") == 1, hero_id + " has 5/4/1 composition")

func _test_power_strength_and_fifo() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	var bryan: Dictionary = game.hero_by_id("bryan")
	var carlos: Dictionary = game.hero_by_id("carlos")
	var scout: Dictionary = game.enemies[0]
	var starting_hp: int = int(scout["hp"])
	# Force exact test cards into hand so shuffled order does not affect outcomes.
	bryan["hand"].insert(0, "demon")
	var initial_seq: int = game.next_sequence
	_check(game.submit_card("bryan", 0, "not_a_hero") != "", "invalid Demon target rejected")
	_check(int(bryan["energy"]) == 3 and game.next_sequence == initial_seq, "rejection is free and not queued")
	_check(game.submit_card("bryan", 0, "bryan") == "", "Demon can target its own hero")
	_check(int(bryan["strength"]) == 1, "Demon adds one Strength")
	_check(bryan["exhaust"].has("demon") and not bryan["discard"].has("demon"), "Demon exhausts rather than discards")
	_check(game.next_sequence == initial_seq + 1, "Demon takes one FIFO sequence")
	# Try submitting an artificial second copy of the power; no effect/cost.
	bryan["hand"].insert(0, "demon")
	var before_energy: int = int(bryan["energy"])
	var before_seq: int = game.next_sequence
	_check(game.submit_card("bryan", 0, "carlos") != "", "Demon cannot be played a second time")
	_check(int(bryan["energy"]) == before_energy and game.next_sequence == before_seq, "duplicate power not charged or queued")
	bryan["hand"].remove_at(0)
	bryan["hand"].insert(0, "attack")
	_check(game.submit_card("bryan", 0, "roboduck_1") == "", "Bryan can attack selected scout")
	_check(int(scout["hp"]) == starting_hp - 2, "Attack deals 1 base plus Bryan's 1 Strength")
	carlos["hand"].insert(0, "block")
	var denied_seq: int = game.next_sequence
	var denied_energy: int = int(carlos["energy"])
	_check(game.submit_card("carlos", 0, "bryan") != "", "Carlos cannot Block Bryan")
	_check(game.next_sequence == denied_seq and int(carlos["energy"]) == denied_energy, "invalid ally Block does not consume energy or queue")
	_check(game.submit_card("carlos", 0, "carlos") == "", "Carlos can Block himself")
	_check(int(bryan["block"]) == 0 and int(carlos["block"]) == 1, "Block affects only its caster")
	_check(game.next_sequence == initial_seq + 3, "actions resolve in global submission order")
	_check(int(game.hero_by_id("cristian_hb")["strength"]) == 0, "Strength is not a teamwide buff")

func _test_power_can_buff_ally() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	var carlos: Dictionary = game.hero_by_id("carlos")
	var manny: Dictionary = game.hero_by_id("manny")
	carlos["hand"].insert(0, "demon")
	_check(game.submit_card("carlos", 0, "manny") == "", "Demon can be dragged onto an ally")
	_check(int(manny["strength"]) == 1 and int(carlos["strength"]) == 0, "selected ally gets Strength, not the caster")
	var scout: Dictionary = game.enemies[0]
	var old_hp: int = int(scout["hp"])
	manny["hand"].insert(0, "attack")
	_check(game.submit_card("manny", 0, "roboduck_1") == "", "buffed ally can attack")
	_check(int(scout["hp"]) == old_hp - 2, "buffed ally's Attack adds Strength")

func _test_skill_targeting_rules() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	var bryan: Dictionary = game.hero_by_id("bryan")
	var carlos: Dictionary = game.hero_by_id("carlos")
	_check(game.card_target_type(game.cards["block"]) == "self", "Block target is explicitly self")
	_check(game.card_target_type(game.cards["demon"]) == "ally", "Demon explicitly permits self or allies")
	# Future skill cards may opt in to ally/team targeting.
	var self_card: Dictionary = {"id":"test_self", "name":"Test Self", "type":"skill", "cost":0,
		"effects":[{"op":"block", "value":3}]}
	game.cards["test_self"] = self_card
	bryan["hand"].insert(0,"test_self")
	_check(game.card_target_type(self_card) == "self", "unspecified Skill defaults to self")
	_check(game.submit_card("bryan",0,"carlos") != "", "default Skill cannot target teammate")
	_check(game.submit_card("bryan",0,"bryan") == "", "default Skill can target self")
	_check(int(bryan["block"]) == 3 and int(carlos["block"]) == 0, "default Skill protects only owner")
	var ally_card: Dictionary = {"id":"test_ally", "name":"Test Ally", "type":"skill", "cost":0, "target":"ally",
		"effects":[{"op":"block", "value":2}]}
	game.cards["test_ally"] = ally_card
	bryan["hand"].insert(0,"test_ally")
	_check(game.submit_card("bryan",0,"carlos") == "", "explicit ally Skill may target a teammate")
	_check(int(carlos["block"]) == 2, "explicit ally Skill protects selected teammate")
	var team_card: Dictionary = {"id":"test_team", "name":"Test Team", "type":"skill", "cost":0, "target":"all_allies",
		"effects":[{"op":"block", "value":1}]}
	game.cards["test_team"] = team_card
	bryan["hand"].insert(0,"test_team")
	_check(game.submit_card("bryan",0,"bryan") == "", "explicit all_allies Skill may be cast on party")
	for hero in game.party:
		_check(int(hero["block"]) >= 1, str(hero["id"]) + " receives team Block")

func _test_shared_enemy_attacks() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	# One Roboduck attacks for 6 damage each hero.
	game.hero_by_id("bryan")["block"] = 6
	game.hero_by_id("manny")["strength"] = 1
	for hero_id in ["bryan", "carlos", "manny"]:
		game.mark_done(hero_id)
	_check(game.round_number == 1 and int(game.hero_by_id("cristian_hb")["hp"]) == 60, "enemy phase waits for all heroes")
	game.mark_done("cristian_hb")
	_check(game.round_number == 2, "enemy phase advances to next round")
	_check(int(game.hero_by_id("bryan")["hp"]) == 60, "Bryan's 6 Block absorbs Roboduck's 6 damage")
	for hero_id in ["carlos", "manny", "cristian_hb"]:
		_check(int(game.hero_by_id(hero_id)["hp"]) == 54, hero_id + " takes Roboduck's 6 damage")
	_check(int(game.hero_by_id("bryan")["block"]) == 0, "remaining Block resets at round start")
	_check(int(game.hero_by_id("manny")["strength"]) == 1, "Power Strength persists to next round")
	for hero in game.party:
		_check(int(hero["energy"]) == 3, str(hero["id"]) + " regains energy")

func _test_dead_enemy_does_not_attack() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	game.enemies[0]["hp"] = 0
	for hero_id in ["bryan", "carlos", "manny", "cristian_hb"]:
		game.mark_done(hero_id)
	for hero in game.party:
		_check(int(hero["hp"]) == 60, str(hero["id"]) + " takes no damage from a defeated Roboduck")
	_check(int(game.enemies[0]["hp"]) == 0, "defeated Roboduck stays defeated")

func _test_four_player_limit_and_combined_duo() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	game.start(["bryan", "carlos", "manny", "cristian_hb"])
	_check(game.party.size() == 4, "the active roster contains exactly four heroes")
	game.start(["bryan", "carlos", "cristian_hb"])
	_check(game.party.size() == 3 and not game.hero_by_id("cristian_hb").is_empty(), "Cristian & HB remain playable as a single unit in three-player party")

func _test_encounter_templates_and_distinct_spawns() -> void:
	var game: AptitudeCombatEngine = CombatScript.new()
	_check(game.encounter_id == "city_intro", "initial encounter is the single-Roboduck intro")
	_check(game.enemies.size() == 1 and int(game.enemies[0]["hp"]) == 15, "Roboduck starts at 15 HP")
	_check(int(game.enemies[0]["damage"]) == 6, "Roboduck attacks all heroes for 6")
	_check(game.battlefield_background == "res://art/backgrounds/alextron_ruins.jpg", "encounter selects city wallpaper")
	game.start(["bryan", "carlos", "manny", "cristian_hb"], "city_duo_test")
	_check(game.enemies.size() == 2, "encounter template can spawn two Roboducks")
	_check(str(game.enemies[0]["id"]) != str(game.enemies[1]["id"]), "spawn instances have distinct target IDs")
	var carlos: Dictionary = game.hero_by_id("carlos")
	carlos["hand"].insert(0, "attack")
	_check(game.submit_card("carlos", 0, "roboduck_2") == "", "can target second Roboduck")
	_check(int(game.enemies[0]["hp"]) == 15 and int(game.enemies[1]["hp"]) == 14, "one Roboduck can be damaged without affecting the other")
	game.enemies[0]["hp"] = 0
	game.select_hero("manny")
	_check(int(game.enemies[0]["hp"]) == 0 and int(game.enemies[1]["hp"]) == 14, "switching heroes preserves both instance HP values")
	for hero_id in ["bryan", "carlos", "manny", "cristian_hb"]:
		game.mark_done(hero_id)
	for hero in game.party:
		_check(int(hero["hp"]) == 54, "only surviving Roboduck hits " + str(hero["id"]))
	game.start(["bryan"], "city_trio_test")
	_check(game.enemies.size() == 3 and str(game.enemies[2]["id"]) == "roboduck_3", "three Roboducks spawn uniquely from one definition")
