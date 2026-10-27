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

    # Re-select Bryan and confirm to the Act 1 placeholder.
    await _click_named("SelectHeroBryan")
    await _click_named("ContinueSelectionButton")
    await _click_named("ConfirmHeroButton")
    _check(str(game.get("screen")) == "act1_map", "Single Player confirmation opens Act 1")
    await _capture("06_act1_map")

    # Return to Play, verify Multiplayer follows the same select/bio route.
    await _click_named("BackFromMapButton")
    await _click_named("BackFromSelectButton")
    _check(str(game.get("screen")) == "play", "Back returns to mode selection")
    await _click_named("MultiplayerModeButton")
    _check(str(game.get("screen")) == "select", "Multiplayer leads to character selection")
    await _click_named("SelectHeroCristianHb")
    await _click_named("ContinueSelectionButton")
    _check(str(game.get("screen")) == "bio", "Multiplayer also uses character bio")
    await _click_named("ConfirmHeroButton")
    _check(str(game.get("screen")) == "lobby", "Multiplayer confirmation opens lobby placeholder")
    await _capture("07_multiplayer_lobby")
    await _click_named("BackFromLobbyButton")
    _check(str(game.get("screen")) == "bio", "Lobby Back returns to bio")

    # Preserve accessibility and regression tests for the original four-hero prototype.
    await _click_named("BackFromBioButton")
    await _click_named("BackFromSelectButton")
    await _click_named("SinglePlayerModeButton")
    await _click_named("SelectHeroBryan")
    await _click_named("ContinueSelectionButton")
    await _click_named("ConfirmHeroButton")
    await _click_named("CombatPreviewButton")
    _check(str(game.get("screen")) == "battle", "Combat Preview launches legacy encounter")
    var combat: AptitudeCombatEngine = game.get("combat") as AptitudeCombatEngine
    _check(combat.party.size() == 4, "prototype encounter still has four heroes")
    await _capture("08_combat_preview")
    await _click_text("DECK (")
    _check(str(game.get("overlay_screen")) == "deck", "Deck overlay opens")
    await _capture("09_deck_inventory")
    await _click_text("CLOSE")
    await _click_text("SETTINGS")
    _check(str(game.get("overlay_screen")) == "settings", "Combat Settings opens")
    await _capture("10_combat_settings")
    await _click_text("CLOSE")

    # Test card dragging, enemy targeting and victory exactly as before.
    var hero: Dictionary = combat.hero_by_id("bryan")
    combat.select_hero("bryan")
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
    _check(not (game.get("drag_state") as Dictionary).is_empty(), "card press starts drag")
    await _mouse_move(enemy_center)
    await _frames(3)
    await _capture("11_drag_targeting")
    _send_button(enemy_center, false)
    await _frames(3)
    _check(int(combat.enemies[0]["hp"]) == enemy_hp - 1, "Attack dropped on Roboduck deals damage")
    await _capture("12_after_card_play")
    combat.enemies[0]["hp"] = 0
    combat.call("_check_outcome")
    combat.changed.emit()
    await _frames(3)
    _check(combat.phase == "victory", "victory state visible")
    await _capture("13_victory")

    if failures == 0:
        print("PASS: menu flow, character bios, interactive combat preview and screenshots")
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
