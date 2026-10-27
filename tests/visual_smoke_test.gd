extends SceneTree
## APTITUDE graphical smoke test (Godot 4.7.2, Compatibility renderer).
## Uses the real main scene and synthetic GUI mouse input. Does NOT alter game files.
##
## Run under a graphical display (Linux example):
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --resolution 1600x900 --script res://tests/visual_smoke_test.gd
##
## Screenshots: res://test-results/screenshots/*.png
## The host CI runner uploads these files as artifacts.

const SCENE_PATH := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://test-results/screenshots"
const SCREEN_SIZE := Vector2i(1600, 900)

var failures: int = 0
var game: Control

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = SCREEN_SIZE
    root.mode = Window.MODE_WINDOWED
    var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
    var result: Error = DirAccess.make_dir_recursive_absolute(absolute_dir)
    if result != OK:
        push_error("Cannot create screenshot directory: %s" % absolute_dir)
        quit(1)
        return

    var scene: PackedScene = load(SCENE_PATH) as PackedScene
    if scene == null:
        push_error("Could not load main scene")
        quit(1)
        return
    game = scene.instantiate() as Control
    root.add_child(game)
    await _frames(5)
    _check(str(game.get("screen")) == "home", "opens at Main Menu")
    await _capture("01_main_menu")

    # Main Menu -> Settings -> Back -> Play.
    await _click_named("SettingsMainMenuButton")
    _check(str(game.get("overlay_screen")) == "settings", "Main Menu settings opens")
    await _capture("02_main_settings")
    await _click_text("CLOSE")
    _check(str(game.get("overlay_screen")) == "", "Settings closes")
    await _click_named("PlayMainMenuButton")
    _check(str(game.get("screen")) == "play", "Play opens mode selection")
    await _capture("03_play_modes")
    _check(_find_named(game, "CustomModeButton") == null, "No Custom mode")

    # Single Player -> character selection. Continue disabled before choosing.
    await _click_named("SinglePlayerModeButton")
    _check(str(game.get("screen")) == "select", "Single Player leads to character selection")
    await _capture("04_character_selection")
    var continue_button: Button = _find_named(game, "ContinueSelectionButton") as Button
    _check(continue_button != null and continue_button.disabled, "Continue disabled until hero selected")

    # All four bio screens are generated from the same reusable layout and art library.
    for index in range(4):
        var id: String = ["bryan", "carlos", "manny", "cristian_hb"][index]
        var button_id: String = ["SelectHeroBryan", "SelectHeroCarlos", "SelectHeroManny", "SelectHeroCristianHb"][index]
        await _click_named(button_id)
        continue_button = _find_named(game, "ContinueSelectionButton") as Button
        _check(continue_button != null and not continue_button.disabled, "Hero selection enables Continue: " + id)
        await _click_named("ContinueSelectionButton")
        _check(str(game.get("screen")) == "bio", "Selected hero opens bio: " + id)
        var back_button: Control = _find_named(game, "BackFromBioButton")
        var confirm_button: Control = _find_named(game, "ConfirmHeroButton")
        _check(back_button != null and confirm_button != null, "Bio has Back and Confirm: " + id)
        _check(_count_buttons(game) == 2, "Bio contains exactly two buttons: " + id)
        await _capture("05_bio_" + id)
        await _click_named("BackFromBioButton")
        _check(str(game.get("screen")) == "select", "Bio Back returns to selection: " + id)

    # Confirm Bryan to the REAL randomized map, then enter a connected combat.
    await _click_named("SelectHeroBryan")
    await _click_named("ContinueSelectionButton")
    await _click_named("ConfirmHeroButton")
    _check(str(game.get("screen")) == "act1_map", "Single Player confirmation opens the real Act 1 map")
    var run: AptitudeAct1Run = game.get("run_state") as AptitudeAct1Run
    _check(run.floors.size() == 15 and run.available_nodes().size() == 3, "Act 1 has 15 floors and three starting paths")
    _check(run.hero_id == "bryan" and run.current_floor == -1, "chosen hero persists into new run")
    await _capture("06_act1_branching_map")
    var scroll: ScrollContainer = _find_named(game, "Act1MapScroll") as ScrollContainer
    _check(scroll != null and scroll.scroll_vertical > 0, "map initially scrolls to starting paths")
    if scroll != null:
        var previous_scroll: int = scroll.scroll_vertical
        scroll.scroll_vertical = 0
        await _frames(5)
        _check(scroll.scroll_vertical == 0, "map scrolls up to boss and future floors")
        await _capture("06_boss_map_top")
        scroll.scroll_vertical = previous_scroll
        await _frames(5)

    var first_fight: Dictionary = {}
    for node in run.available_nodes():
        if str(node["kind"]) == "combat":
            first_fight = node
            break
    _check(not first_fight.is_empty(), "opening paths include combat")
    if not first_fight.is_empty():
        await _click_named("MapNode" + str(first_fight["id"]).replace("_", ""))
    _check(str(game.get("screen")) == "battle", "clicking an available connected node starts combat")
    var combat: AptitudeCombatEngine = game.get("combat") as AptitudeCombatEngine
    _check(combat.party.size() == 1, "single-player combat has exactly one hero")
    _check(int(combat.hero_by_id("bryan")["block"]) == 1, "Bryan passive is active in solo combat")
    _check(int(combat.enemies[0]["max_hp"]) == 9, "solo encounter scales enemy health")
    await _capture("07_solo_combat")

    await _click_text("DECK (")
    _check(str(game.get("overlay_screen")) == "deck", "deck overlay still works")
    await _capture("08_deck_inventory")
    await _click_text("CLOSE")
    await _click_text("SETTINGS")
    _check(str(game.get("overlay_screen")) == "settings", "battle settings still works")
    await _capture("09_combat_settings")
    await _click_text("CLOSE")

    # Real card drag/drop: the solo hero damages a real enemy target.
    var hero: Dictionary = combat.hero_by_id("bryan")
    hero["hand"].insert(0, "attack")
    game.call("_redraw")
    await _frames(3)
    var count: int = mini(hero["hand"].size(), 7)
    var width: float = float(count) * 139.0 + float(maxi(0, count - 1)) * 12.0
    var card_center: Vector2 = Vector2(770.0 - width / 2.0 + 69.0, 760.0)
    var enemy_center := Vector2(1202.0, 465.0)
    var enemy_hp: int = int(combat.enemies[0]["hp"])
    await _mouse_move(card_center)
    _send_button(card_center, true)
    await _frames(2)
    _check(not (game.get("drag_state") as Dictionary).is_empty(), "card press begins drag")
    await _mouse_move(enemy_center)
    await _frames(3)
    await _capture("10_drag_targeting")
    _send_button(enemy_center, false)
    await _frames(3)
    _check(int(combat.enemies[0]["hp"]) == enemy_hp - 1, "Attack damages Roboduck")
    await _capture("11_after_card_play")

    # Test-only accelerated enemy defeat to verify run results and reward flow.
    combat.enemies[0]["hp"] = 0
    combat.call("_check_outcome")
    combat.changed.emit()
    await _frames(3)
    _check(str(game.get("screen")) == "act1_reward", "victory advances to reward selection")
    _check(run.coins == 25, "coins persist after fight")
    await _capture("12_victory_reward")
    await _click_named("RewardAttackButton")
    _check(str(game.get("screen")) == "act1_map", "reward returns to branching map")
    _check(run.deck.size() == 11, "chosen reward persists as eleventh card")
    _check(run.current_floor == 0, "map progress persists after battle")
    await _capture("13_map_after_reward")

    # Advance ONE real additional node so that both the chosen connection
    # and the nodes are visibly highlighted in yellow ink.
    var second_choices: Array = run.available_nodes()
    _check(not second_choices.is_empty(), "connected second-floor nodes are available")
    if not second_choices.is_empty():
        var second_id: String = str(second_choices[0]["id"])
        await _click_named("MapNode" + second_id.replace("_", ""))
        match run.state:
            "battle":
                for enemy in combat.enemies:
                    enemy["hp"] = 0
                combat.call("_check_outcome")
                combat.changed.emit()
                await _frames(3)
                await _click_named("RewardBlockButton")
            "event":
                await _click_named("EventSalvageButton")
            "shop":
                await _click_named("ShopLeaveButton")
            "rest":
                await _click_named("RestHealButton")
        _check(str(game.get("screen")) == "act1_map" and run.visited.size() == 2,
            "second floor completion highlights the selected route")
        await _capture("13_yellow_route_marker")

    # Exercise the three noncombat location screens and their real buttons.
    # Deterministic in-memory setups; map routing itself has separate engine tests.
    run.state = "event"
    game.set("screen", "act1_event")
    game.call("_redraw")
    await _frames(3)
    await _capture("14_event")
    var coins_before_event: int = run.coins
    await _click_named("EventSalvageButton")
    _check(str(game.get("screen")) == "act1_map" and run.coins == coins_before_event + 20,
        "event choice awards coins and returns to map")

    run.state = "shop"
    game.set("screen", "act1_shop")
    game.call("_redraw")
    await _frames(3)
    await _capture("14_shop")
    var coins_before_shop: int = run.coins
    await _click_named("ShopHealButton")
    _check(str(game.get("screen")) == "act1_map" and run.coins == coins_before_shop - 20,
        "shop purchase deducts cost and exits to map")

    run.state = "rest"
    game.set("screen", "act1_rest")
    game.call("_redraw")
    await _frames(3)
    await _capture("14_rest")
    var max_before_rest: int = run.max_hp
    await _click_named("RestUpgradeButton")
    _check(str(game.get("screen")) == "act1_map" and run.max_hp == max_before_rest + 5,
        "rest-site upgrade raises persistent maximum HP")

    # Test-only map fast-forward. Full 15-floor route legality is tested separately
    # in tests/act1_run_test.gd; this verifies boss screen routing and rendering.
    run.current_floor = 14
    run.current_node_id = "14_1"
    run.state = "map"
    game.call("_redraw")
    await _frames(3)
    _check(run.available_nodes().size() == 1, "boss is only available after floor 15")
    await _capture("14_boss_unlocked")
    await _click_named("MapNodealextronboss")
    _check(str(game.get("screen")) == "battle" and combat.party.size() == 1, "boss node launches solo boss encounter")
    _check(str(combat.enemies[0]["type_id"]) == "alextron_sentinel", "boss is a distinct enemy encounter")
    await _capture("15_boss_combat")
    combat.enemies[0]["hp"] = 0
    combat.call("_check_outcome")
    combat.changed.emit()
    await _frames(3)
    _check(str(game.get("screen")) == "act1_complete", "defeating boss completes Act 1")
    await _capture("16_act1_complete")
    await _click_named("CompleteReturnButton")
    _check(str(game.get("screen")) == "home", "Act 1 completion returns to main menu")

    # Inspect each of the remaining approved combat sprites at full resolution
    # so a future canvas/scale change can't silently chop another model.
    for hero_id in ["carlos", "manny", "cristian_hb"]:
        await _click_named("PlayMainMenuButton")
        await _click_named("SinglePlayerModeButton")
        var select_id: String = "SelectHeroCarlos" if hero_id == "carlos" else (
            "SelectHeroManny" if hero_id == "manny" else "SelectHeroCristianHb")
        await _click_named(select_id)
        await _click_named("ContinueSelectionButton")
        await _click_named("ConfirmHeroButton")
        var secondary_run: AptitudeAct1Run = game.get("run_state") as AptitudeAct1Run
        var choice: Dictionary = {}
        for node in secondary_run.available_nodes():
            if str(node["kind"]) == "combat":
                choice = node
                break
        _check(not choice.is_empty(), "combat starting path exists for " + hero_id)
        if not choice.is_empty():
            await _click_named("MapNode" + str(choice["id"]).replace("_", ""))
        _check(str(game.get("screen")) == "battle", "solo combat opens for " + hero_id)
        _check(combat.party.size() == 1 and str(combat.party[0]["id"]) == hero_id,
            "correct single hero in battle: " + hero_id)
        await _capture("18_sprite_" + hero_id)
        secondary_run.state = "inactive"
        game.set("screen", "home")
        game.call("_redraw")
        await _frames(4)

    # Multiplayer follows the same character select/bio flow but stays a placeholder.
    await _click_named("PlayMainMenuButton")
    await _click_named("MultiplayerModeButton")
    _check(str(game.get("screen")) == "select", "Multiplayer opens character selection")
    await _click_named("SelectHeroCristianHb")
    await _click_named("ContinueSelectionButton")
    _check(str(game.get("screen")) == "bio", "Multiplayer includes character bio")
    await _click_named("ConfirmHeroButton")
    _check(str(game.get("screen")) == "lobby", "Multiplayer opens lobby placeholder")
    await _capture("17_multiplayer_lobby")
    await _click_named("BackFromLobbyButton")
    _check(str(game.get("screen")) == "bio", "Lobby Back returns to character bio")

    if failures == 0:
        print("PASS: Act 1 menu, solo combat, rewards, boss and multiplayer placeholder screenshots")
    else:
        push_error("FAIL: %d graphical smoke assertions" % failures)
    quit(1 if failures > 0 else 0)

func _count_buttons(node: Node) -> int:
    var total: int = 1 if node is Button else 0
    for child in node.get_children():
        total += _count_buttons(child)
    return total

func _frames(count: int) -> void:
    for _i in range(count):
        await process_frame

func _check(condition: bool, label: String) -> void:
    if condition:
        print("OK: " + label)
    else:
        failures += 1
        push_error("FAIL: " + label)

func _find_named(parent: Node, wanted: String) -> Control:
    if parent.name == wanted and parent is Control:
        return parent as Control
    for child in parent.get_children():
        var result: Control = _find_named(child, wanted)
        if result != null:
            return result
    return null

func _find_button_prefix(parent: Node, prefix: String) -> Button:
    if parent is Button and (parent as Button).text.strip_edges().begins_with(prefix):
        return parent as Button
    for child in parent.get_children():
        var result: Button = _find_button_prefix(child, prefix)
        if result != null:
            return result
    return null

func _click_named(wanted: String) -> void:
    var b: Control = _find_named(game, wanted)
    _check(b != null, "control exists: " + wanted)
    if b != null:
        await _click_control(b)

func _click_text(prefix: String) -> void:
    var b: Button = _find_button_prefix(game, prefix)
    _check(b != null, "button exists: " + prefix)
    if b != null:
        await _click_control(b)

func _click_control(control: Control) -> void:
    var rect: Rect2 = control.get_global_rect()
    var point: Vector2 = rect.get_center()
    _check(rect.size.x > 0 and rect.size.y > 0 and Rect2(Vector2.ZERO, Vector2(SCREEN_SIZE)).has_point(point),
        "button hit region inside viewport: " + control.name)
    await _mouse_move(point)
    _send_button(point, true)
    await _frames(2)
    _send_button(point, false)
    await _frames(3)

func _mouse_move(position: Vector2) -> void:
    Input.warp_mouse(position)
    var motion := InputEventMouseMotion.new()
    motion.position = position
    motion.global_position = position
    root.push_input(motion, true)
    await _frames(2)

func _send_button(position: Vector2, pressed: bool) -> void:
    var event := InputEventMouseButton.new()
    event.button_index = MOUSE_BUTTON_LEFT
    event.pressed = pressed
    event.position = position
    event.global_position = position
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
    root.push_input(event, true)

func _capture(stem: String) -> void:
    await _frames(3)
    await RenderingServer.frame_post_draw
    var image: Image = root.get_texture().get_image()
    var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join(stem + ".png"))
    _check(image != null and image.get_width() == SCREEN_SIZE.x and image.get_height() == SCREEN_SIZE.y,
        "rendered 1600x900 image: " + stem)
    if image == null or image.is_empty():
        return
    var error: Error = image.save_png(path)
    _check(error == OK, "saved screenshot: " + stem)
    if error == OK:
        var bytes: int = FileAccess.get_file_as_bytes(path).size()
        _check(bytes > 20000, "nontrivial rendered image: %s (%d bytes)" % [stem, bytes])
        print("SCREENSHOT: " + path)
