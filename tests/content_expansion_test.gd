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
    _test_hb_signature_effects()
    _check_enemy_bestiary()
    _test_enemy_debuff_lifecycle()
    _test_enemy_guard_lifecycle()
    _check_encounter_groups()
    _check_reward_pool()
    if failures == 0:
        print("PASS: 30 hero cards, eight enemies, themed scenes and CharacterDex data")
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
    _check(cards.size() == 33, "33 card definitions including 3 starter cards")
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
        var is_duo: bool = hero == "cristian_hb"
        _check(own.size() == (12 if is_duo else 6),
            hero + " has the expected signature-card pool")
        _check(int(counts["attack"]) == (6 if is_duo else 3)
            and int(counts["skill"]) == (4 if is_duo else 2)
            and int(counts["power"]) == (2 if is_duo else 1),
            hero + " has a balanced 3/2/1 card mix per member")
        if is_duo:
            var members: Dictionary = {"Cristian":0, "HB":0}
            for card_id in own:
                var signature: String = str(cards[card_id].get("member", ""))
                _check(members.has(signature), "duo ability identifies its creator: " + card_id)
                if members.has(signature):
                    members[signature] = int(members[signature]) + 1
            _check(int(members["Cristian"]) == 6 and int(members["HB"]) == 6,
                "Cristian and HB each have six distinct playable cards in their shared slot")

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

func _test_hb_signature_effects() -> void:
    # Six additional HB cards use the same combined Cristian & HB slot.
    var game: AptitudeCombatEngine = Combat.new()
    var duo: Dictionary = {}
    var robot: Dictionary = {}
    var before_hp: int = 0

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    robot = game.enemies[0]
    duo["hand"].insert(0, "cristian_hb_impact_driver")
    before_hp = int(robot["hp"])
    _check(game.submit_card("cristian_hb", 0, "roboduck_1") == "",
        "HB Impact Driver is playable by the combined unit")
    _check(int(robot["hp"]) == before_hp - 4,
        "Impact Driver deals two separate 2-damage hits")

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    robot = game.enemies[0]
    duo["hand"].insert(0, "cristian_hb_hot_tap")
    _check(game.submit_card("cristian_hb", 0, "roboduck_1") == "",
        "HB Hot Tap is playable")
    _check(int(robot["hp"]) == int(robot["max_hp"]) - 3
        and int(robot["vulnerable"]) == 1,
        "Hot Tap damages and exposes the targeted robot")

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    robot = game.enemies[0]
    duo["hand"].insert(0, "cristian_hb_breaker_trip")
    _check(game.submit_card("cristian_hb", 0, "roboduck_1") == "",
        "HB Breaker Trip is playable")
    _check(int(robot["hp"]) == int(robot["max_hp"]) - 5
        and int(robot["weak"]) == 2,
        "Breaker Trip deals 5 and applies two Weak")

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    duo["hand"].insert(0, "cristian_hb_tie_off")
    _check(game.submit_card("cristian_hb", 0, "cristian_hb") == "",
        "HB Tie-Off is playable")
    _check(int(duo["block"]) == 5 and duo["hand"].size() == 7,
        "Tie-Off adds 3 Block on top of passive and draws two cards")

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    duo["hand"].insert(0, "cristian_hb_ground_clamp")
    _check(game.submit_card("cristian_hb", 0, "cristian_hb") == "",
        "HB Ground Clamp is playable")
    _check(int(duo["block"]) == 5 and int(duo["energy"]) == 3,
        "Ground Clamp grants 3 free Block")

    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    duo = game.hero_by_id("cristian_hb")
    duo["hand"].insert(0, "cristian_hb_power_bank")
    _check(game.submit_card("cristian_hb", 0, "cristian_hb") == "",
        "HB Power Bank is playable")
    _check(int(duo["strength"]) == 1 and int(duo["focus"]) == 1,
        "Power Bank grants Strength and lasting card draw")
    game.mark_done("cristian_hb")
    _check(duo["hand"].size() == 6 and int(duo["strength"]) == 1,
        "Power Bank's draw bonus applies on the next round")

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
    _check(welder.enemy_intent_text(welder.enemies[0]).contains("⚔ 6"),
        "solo intent includes Vulnerable: shows 6 damage, not misleading base 4")
    var before_hero_hp: int = int(target["hp"])
    welder.mark_done("bryan") # Round 3: 4 base damage -> 6 with Vulnerable.
    _check(int(target["hp"]) == before_hero_hp - 6,
        "Welder's follow-up attack benefits from Vulnerable")
    _check(int(target["vulnerable"]) == 0,
        "Vulnerable expires after the damaging follow-up")

func _test_enemy_guard_lifecycle() -> void:
    # Tesla Brute's round-2 guard must absorb hits in round 3, then expire
    # before its next move. Otherwise guard silently stacks forever.
    var game: AptitudeCombatEngine = Combat.new()
    game.start(["bryan"], "teslabot_brute_bay", {"scale_for_party":true})
    var brute: Dictionary = game.enemies[0]
    var hero: Dictionary = game.hero_by_id("bryan")
    game.mark_done("bryan") # Round 1: attack.
    game.mark_done("bryan") # Round 2: guard.
    _check(int(brute["block"]) == 5,
        "Tesla Brute guard provides five Block for the next player turn")
    var initial_hp: int = int(brute["hp"])
    hero["hand"].insert(0, "attack")
    _check(game.submit_card("bryan", 0, "teslabot_brute_1") == "",
        "starter attack can strike a guarded enemy")
    _check(int(brute["block"]) == 4 and int(brute["hp"]) == initial_hp,
        "guard absorbs damage without reducing machine HP")
    game.mark_done("bryan") # Round 3: attack, prior guard expires.
    _check(int(brute["block"]) == 0,
        "unused guard does not persist through the next enemy phase")
    game.mark_done("bryan") # Round 4: attack.
    game.mark_done("bryan") # Round 5: guard again.
    _check(int(brute["block"]) == 5,
        "later guard starts fresh rather than accumulating old armor")

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
