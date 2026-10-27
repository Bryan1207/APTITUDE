extends SceneTree
## New content integrity, card effects, enemy groups and CharacterDex resources.
const Combat = preload("res://scripts/combat_engine.gd")
const ActRun = preload("res://scripts/act1_run.gd")
const TradingCard = preload("res://scripts/trading_card.gd")
const HERO_IDS := ["bryan", "carlos", "manny", "cristian_hb"]
const TYPES := ["attack", "skill", "power"]
var failures: int = 0

func _initialize() -> void:
    _check_card_library()
    _check_cards_resolve()
    _check_enemy_bestiary()
    _test_enemy_debuff_lifecycle()
    _check_encounter_groups()
    _check_reward_pool()
    if failures == 0:
        print("PASS: 24 hero cards, eight enemies, themed scenes and CharacterDex data")
    else:
        push_error("FAIL: %d content assertions" % failures)
    quit(1 if failures > 0 else 0)

func _check(ok: bool, msg: String) -> void:
    if ok:
        print("OK: " + msg)
    else:
        failures += 1
        push_error("FAIL: " + msg)

func _read(path: String) -> Dictionary:
    var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return value if value is Dictionary else {}

func _check_card_library() -> void:
    var cards: Dictionary = _read("res://data/cards.json")
    _check(cards.size() == 27, "27 card definitions including 3 starter cards")
    for hero in HERO_IDS:
        var own: Array = []
        var counts: Dictionary = {"attack":0, "skill":0, "power":0}
        for id in cards:
            var c: Dictionary = cards[id]
            if str(c.get("hero", "")) != hero:
                continue
            own.append(id)
            counts[str(c["type"])] = int(counts.get(str(c["type"]), 0)) + 1
            _check(int(c["cost"]) >= 0 and int(c["cost"]) <= 2,
                "reasonable energy cost: " + str(id))
            _check(c.has("effects") and not (c["effects"] as Array).is_empty(),
                "usable effect data: " + str(id))
            _check(ResourceLoader.exists("res://art/cards/" + str(id) + ".svg"),
                "imported original card art exists: " + str(id))
        _check(own.size() == 6, hero + " has six original abilities")
        _check(int(counts["attack"]) == 3 and int(counts["skill"]) == 2
            and int(counts["power"]) == 1, hero + " has 3 attacks, 2 skills, 1 power")

func _check_cards_resolve() -> void:
    var game: AptitudeCombatEngine = Combat.new()
    var cards: Dictionary = game.cards
    for id in cards:
        var c: Dictionary = cards[id]
        var owner: String = str(c.get("hero", ""))
        if not HERO_IDS.has(owner):
            continue
        game.start([owner], "city_intro", {"apply_passives":true})
        var hero: Dictionary = game.hero_by_id(owner)
        hero["hand"].insert(0, id)
        var target: String = "roboduck_1" if str(c["target"]) == "enemy" else owner
        var starting_seq: int = game.next_sequence
        _check(game.submit_card(owner, 0, target) == "",
            "new card can be played: " + str(id))
        _check(game.next_sequence == starting_seq + 1,
            "new card is accepted exactly once in FIFO queue: " + str(id))
    game.start(["carlos"], "city_intro", {"apply_passives":true})
    var hero: Dictionary = game.hero_by_id("carlos")
    hero["hand"].insert(0, "carlos_nail_burst")
    var initial: int = int(game.enemies[0]["hp"])
    _check(game.submit_card("carlos", 0, "roboduck_1") == "",
        "Nail Burst accepted as attack")
    _check(int(game.enemies[0]["hp"]) == initial - 5,
        "Nail Burst hits twice and Carlos passive applies once")
    game.start(["bryan"], "city_intro")
    var bryan: Dictionary = game.hero_by_id("bryan")
    bryan["hand"].insert(0, "manny_punch_list")
    _check(game.submit_card("bryan", 0, "roboduck_1") != "",
        "hero cannot use another hero's exclusive card")
    game.start(["manny"], "city_intro")
    var manny: Dictionary = game.hero_by_id("manny")
    manny["hand"].insert(0, "manny_site_plan")
    _check(game.submit_card("manny", 0, "manny") == "", "Site Plan power resolves")
    _check(int(manny.get("plating", 0)) == 1 and int(manny.get("focus", 0)) == 1,
        "Site Plan grants both permanent effects")
    game.mark_done("manny")
    _check(int(manny["block"]) == 1 and manny["hand"].size() == 6,
        "permanent effects apply next turn")

func _check_enemy_bestiary() -> void:
    var enemies: Dictionary = _read("res://data/enemies.json")
    _check(enemies.size() >= 10, "eight new enemies plus Roboduck and untouched boss")
    var original: Dictionary = enemies["alextron_sentinel"]
    _check(int(original["hp"]) == 34 and int(original["damage"]) == 6
        and str(original["sprite"]) == "res://art/enemies/roboduck.png",
        "reserved boss remains unchanged")
    for id in enemies:
        var e: Dictionary = enemies[id]
        if ["roboduck", "alextron_sentinel"].has(id):
            continue
        _check(ResourceLoader.exists(str(e["sprite"])),
            "new machine has original imported art: " + str(id))
        _check((e["moves"] as Array).size() >= 2,
            "new enemy telegraphs a multi-turn behavior: " + str(id))
    _check(ResourceLoader.exists("res://art/backgrounds/yard_dusk.svg"),
        "scrapyard theme is imported")
    _check(ResourceLoader.exists("res://art/backgrounds/teslabot_factory.svg"),
        "teslabot factory theme is imported")

func _test_enemy_debuff_lifecycle() -> void:
    # Foreman's Weak should affect the NEXT player turn, not disappear
    # immediately after the enemy that applies it finishes attacking.
    var foreman: AptitudeCombatEngine = Combat.new()
    foreman.start(["bryan"], "teslabot_foreman", {"scale_for_party":true})
    var hero: Dictionary = foreman.hero_by_id("bryan")
    foreman.mark_done("bryan") # Round 1: charge; Round 2 intent is Weak.
    _check(foreman.enemy_intent_text(foreman.enemies[0]).contains("Weak 1"),
        "Foreman telegraphs its Weak effect and stack count")
    foreman.mark_done("bryan") # Round 2: apply Weak 1.
    _check(int(hero["weak"]) == 1,
        "machine-applied Weak survives to the next player turn")
    hero["hand"].insert(0, "bryan_conduit_jab")
    var before_enemy_hp: int = int(foreman.enemies[0]["hp"])
    _check(foreman.submit_card("bryan", 0, "foreman_droid_1") == "",
        "Weak hero can still play a legal attack")
    _check(int(foreman.enemies[0]["hp"]) == before_enemy_hp - 2,
        "Weak reduces Conduit Jab from 3 to 2 damage")
    foreman.mark_done("bryan") # Round 3: no new Weak applied.
    _check(int(hero["weak"]) == 0,
        "Weak expires after the affected player turn")

    # The Welder's windup is attack/debuff, guard, then heavy attack.
    # Two stacks let Vulnerable matter on its next damaging turn.
    var welder: AptitudeCombatEngine = Combat.new()
    welder.start(["bryan"], "yard_welders", {"scale_for_party":true})
    var target: Dictionary = welder.hero_by_id("bryan")
    _check(welder.enemy_intent_text(welder.enemies[0]).contains("Vuln 2"),
        "Welder telegraphs Vulnerable and its duration")
    welder.mark_done("bryan") # Round 1: debuff.
    _check(int(target["vulnerable"]) == 2,
        "newly applied Vulnerable persists into the next round")
    welder.mark_done("bryan") # Round 2: guard.
    _check(int(target["vulnerable"]) == 1,
        "Vulnerable ticks once after the intervening guard turn")
    var before_hero_hp: int = int(target["hp"])
    welder.mark_done("bryan") # Round 3: 4 base damage -> 6 with Vulnerable.
    _check(int(target["hp"]) == before_hero_hp - 6,
        "Welder's follow-up attack benefits from Vulnerable")
    _check(int(target["vulnerable"]) == 0,
        "Vulnerable expires after the damaging follow-up")

func _check_encounter_groups() -> void:
    var data: Dictionary = _read("res://data/encounters.json")
    var enemies: Dictionary = _read("res://data/enemies.json")
    for id in data:
        var enc: Dictionary = data[id]
        _check(ResourceLoader.exists(str(enc["background"])),
            "encounter has loadable scene wallpaper: " + str(id))
        for enemy_id in enc["enemies"]:
            _check(enemies.has(str(enemy_id)),
                "encounter references defined machine: " + str(enemy_id))
    var game: AptitudeCombatEngine = Combat.new()
    game.start(["bryan"], "teslabot_patrol", {"scale_for_party":true})
    _check(game.enemies.size() == 2, "teslabot factory spawns two distinct machines")
    _check(game.battlefield_background.ends_with("teslabot_factory.svg"),
        "teslabot encounter uses its own themed wallpaper")
    var scout: Dictionary = game.enemies[0]
    _check(game.enemy_intent_text(scout).begins_with("⚔"),
        "scout attack telegraphed before player acts")
    game.mark_done("bryan")
    _check(str(scout["next_move"].get("kind", "")) == "charge" or game.phase == "defeat",
        "next machine action updates after a turn")

func _check_reward_pool() -> void:
    var game: AptitudeAct1Run = ActRun.new()
    for owner in HERO_IDS:
        game.start_new(owner, 60, 55192)
        var choice: Dictionary = {}
        for node in game.available_nodes():
            if str(node["kind"]) == "combat":
                choice = node
                break
        _check(not choice.is_empty(), owner + " can choose opening combat")
        if choice.is_empty():
            continue
        _check(game.choose_node(str(choice["id"])), owner + " enters selected fight")
        _check(game.finish_battle(60, 60, 25, true), "rewards created after encounter")
        _check(game.reward_options.size() == 3, owner + " gets three unique reward offers")
        var pool: Array[String] = game.reward_options
        _check(pool[0] != pool[1] and pool[1] != pool[2],
            "no duplicate card choices for " + owner)
        for card_id in pool:
            var cards: Dictionary = _read("res://data/cards.json")
            _check(str(cards[card_id]["hero"]) == owner,
                "reward belongs to selected hero")
        var chosen_id: String = pool[0]
        _check(game.claim_reward(chosen_id) and game.deck.has(chosen_id),
            owner + " can permanently acquire a new unique card")
