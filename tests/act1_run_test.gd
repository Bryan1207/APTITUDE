extends SceneTree
## Engine-only Milestone 2 regression tests.
const RunScript = preload("res://scripts/act1_run.gd")
const CombatScript = preload("res://scripts/combat_engine.gd")
const CharacterArt = preload("res://scripts/character_art.gd")

var failures: int = 0

func _initialize() -> void:
    _test_seeded_map_and_boss()
    _test_topology_across_seeds()
    _test_route_and_rewards()
    _test_passives()
    _test_character_sprite_safe_frames()
    _test_scaling_and_persistence()
    if failures == 0:
        print("PASS: Act 1 map, passives and encounter persistence")
    else:
        push_error("FAIL: %d Act 1 tests" % failures)
    quit(1 if failures > 0 else 0)

func _check(value: bool, description: String) -> void:
    if value:
        print("OK: " + description)
    else:
        failures += 1
        push_error("FAIL: " + description)

func _test_seeded_map_and_boss() -> void:
    var first: AptitudeAct1Run = RunScript.new()
    var second: AptitudeAct1Run = RunScript.new()
    first.start_new("carlos", 60, 47625)
    second.start_new("carlos", 60, 47625)
    _check(first.floors.size() == 15, "15 encounter floors generated")
    _check(first.available_nodes().size() == 3, "all three starting paths available")
    _check(first.boss["kind"] == "boss" and first.boss["floor"] == 15, "mandatory boss occupies floor 16")
    var expected: Array = []
    for level in range(15):
        var row: Array = first.floors[level]
        _check(row.size() == 3 if level == 0 else (row.size() >= 2 and row.size() <= 5),
            "floor %d has a valid variable node count" % (level + 1))
        for node in row:
            expected.append("%s:%s:%s" % [node["id"], node["kind"], node["next"]])
            var target_floor: int = level + 1
            for target_id in node["next"]:
                _check(first.node_by_id(str(target_id))["floor"] == target_floor,
                    "edge advances exactly one floor")
    var actual: Array = []
    for row in second.floors:
        for node in row:
            actual.append("%s:%s:%s" % [node["id"], node["kind"], node["next"]])
    _check(expected == actual, "map generation reproduces with same seed")
    _check(first.available_nodes()[0]["id"] == first.floors[0][0]["id"],
        "first starting lane selectable")

func _test_topology_across_seeds() -> void:
    var variety: Dictionary = {}
    var tested: int = 0
    for trial in range(1, 31):
        var run: AptitudeAct1Run = RunScript.new()
        run.start_new("manny", 60, trial * 9317)
        for level in range(15):
            var nodes: Array = run.floors[level]
            variety[nodes.size()] = true
            for node in nodes:
                var links: Array = node["next"]
                _check(not links.is_empty(), "every node advances toward boss")
                for target in links:
                    _check(run.node_by_id(str(target))["floor"] == level + 1,
                        "edges do not skip encounter floors")
        for level in range(1, 15):
            var previous: Array = run.floors[level - 1]
            var reached: Dictionary = {}
            for node in previous:
                for next_id in node["next"]:
                    reached[str(next_id)] = true
            for node in run.floors[level]:
                _check(reached.has(str(node["id"])),
                    "each generated node has an incoming connection")
        tested += 1
    _check(tested == 30 and variety.size() >= 3,
        "30 seeds produce connected maps with variable floor densities")

func _test_route_and_rewards() -> void:
    var run: AptitudeAct1Run = RunScript.new()
    run.start_new("bryan", 60, 401)
    _check(not run.choose_node("alextron_boss"), "boss cannot be entered on floor 1")
    _check(not run.choose_node("does_not_exist"), "invalid map ID rejected")
    var total_nodes: int = 0
    while run.current_floor < 14 and total_nodes < 15:
        var available: Array = run.available_nodes()
        _check(not available.is_empty(), "at least one reachable path remains")
        var node: Dictionary = available[0]
        _check(run.choose_node(str(node["id"])), "connected node accepted")
        total_nodes += 1
        _check(not run.choose_node(str(node["id"])), "cannot select multiple nodes on one floor")
        match run.state:
            "battle":
                _check(run.finish_battle(44, 60, run.coins + 25, true), "battle win recorded")
                _check(run.state == "reward", "normal/elite win requires a reward choice")
                _check(run.claim_reward("attack"), "reward choice adds a card")
            "event":
                _check(run.resolve_node("salvage"), "event choice resolves")
            "rest":
                _check(run.resolve_node("heal"), "rest choice resolves")
            "shop":
                _check(run.resolve_node("leave"), "shop exit resolves")
            _:
                _check(false, "unexpected map kind")
        _check(run.state == "map", "encounter returns to map")
    _check(run.current_floor == 14, "15 encounters visited before boss")
    _check(run.available_nodes().size() == 1, "only mandatory boss available after floor 15")
    _check(not run.choose_node("00_1"), "backtracking rejected")
    _check(run.choose_node("alextron_boss"), "boss can be selected from final floor")
    _check(run.state == "battle" and run.encounter_id() == "alextron_boss", "boss uses dedicated encounter")
    _check(run.finish_battle(24, 60, run.coins + 25, true), "boss victory recorded")
    _check(run.state == "complete", "boss victory completes Act 1")
    _check(run.available_nodes().is_empty(), "no Act 2 route is unlocked prematurely")
    _check(run.visited.size() == 16, "run visited exactly 15 locations plus boss")

func _test_passives() -> void:
    var game: AptitudeCombatEngine = CombatScript.new()
    game.start(["bryan"], "city_intro", {"apply_passives":true})
    _check(game.party.size() == 1 and int(game.hero_by_id("bryan")["block"]) == 1,
        "Bryan Conduit Discipline starts with 1 Block")
    game.start(["cristian_hb"], "city_intro", {"apply_passives":true})
    _check(int(game.hero_by_id("cristian_hb")["block"]) == 2,
        "Cristian and HB Elevated Position starts with 2 Block")
    game.start(["manny"], "city_intro", {"apply_passives":true})
    _check(game.hero_by_id("manny")["hand"].size() == 6,
        "Manny Toolbox Talk starts with 6 cards")
    game.start(["carlos"], "city_intro", {"apply_passives":true})
    var carlos: Dictionary = game.hero_by_id("carlos")
    carlos["hand"].insert(0, "attack")
    var enemy_hp: int = int(game.enemies[0]["hp"])
    _check(game.submit_card("carlos", 0, "roboduck_1") == "", "Carlos first Attack accepted")
    _check(int(game.enemies[0]["hp"]) == enemy_hp - 2, "Carlos Nail Gunner gives +1 to first Attack")
    carlos["hand"].insert(0, "attack")
    _check(game.submit_card("carlos", 0, "roboduck_1") == "", "Carlos second Attack accepted")
    _check(int(game.enemies[0]["hp"]) == enemy_hp - 3, "second Attack does not repeat passive")

func _test_character_sprite_safe_frames() -> void:
    for id in ["bryan", "carlos", "manny", "cristian_hb"]:
        for filename in ["combat_sprite.png", "selection_portrait.png", "bio_art.png"]:
            var path: String = "res://art/characters/%s/%s" % [id, filename]
            var approved: Texture2D = load(path) as Texture2D
            var padded: Texture2D = CharacterArt.framed_texture(path)
            _check(approved != null and padded != null,
                "approved asset and framed asset exist: " + id + "/" + filename)
            if approved == null or padded == null:
                continue
            _check(padded.get_width() > approved.get_width()
                and padded.get_height() > approved.get_height(),
                "hero asset has non-destructive safe margins")
            var image: Image = padded.get_image()
            _check(image.get_pixel(0, 0).a < 0.01
                and image.get_pixel(image.get_width() - 1, image.get_height() - 1).a < 0.01,
                "transparent frame edges prevent image-frame clipping")

func _test_scaling_and_persistence() -> void:
    var game: AptitudeCombatEngine = CombatScript.new()
    var options: Dictionary = {"apply_passives":true, "scale_for_party":true,
        "hero_hp":37, "hero_max_hp":65, "coins":75,
        "deck":["attack","attack","block","demon","block","attack"]}
    game.start(["bryan"], "city_intro", options)
    _check(game.party.size() == 1, "solo run spawns only chosen hero")
    _check(int(game.hero_by_id("bryan")["hp"]) == 37 and int(game.hero_by_id("bryan")["max_hp"]) == 65,
        "health and maximum HP carry between floors")
    _check(game.coins == 75, "coins carry into encounter")
    var hero: Dictionary = game.hero_by_id("bryan")
    _check((hero["hand"] as Array).size() + (hero["draw"] as Array).size() == 6,
        "reward-modified deck carries into encounter")
    _check(int(game.enemies[0]["max_hp"]) == 9 and int(game.enemies[0]["damage"]) == 3,
        "single-hero enemies scale down from four-player template")
    _check(int(hero["block"]) == 1, "passive applies with restored health")
    game.start(["bryan", "carlos", "manny", "cristian_hb"])
    _check(int(game.enemies[0]["max_hp"]) == 15 and int(game.enemies[0]["damage"]) == 6,
        "original four-player prototype remains unchanged")
