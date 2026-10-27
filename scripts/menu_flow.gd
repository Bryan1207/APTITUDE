extends RefCounted
## Milestone 1 menu flow. Visual UI is code-driven; portraits and bio data are separate assets.
## No changes to the existing combat engine or approved battlefield artwork.

const BIOS_PATH := "res://data/character_bios.json"
const STAGE_SIZE := Vector2(1600, 900)
const HERO_ORDER := ["bryan", "carlos", "manny", "cristian_hb"]
const GOLD := Color("e9bd71")
const TEXT := Color("f2e9dc")
const MUTED := Color("b5bfca")
const NAVY := Color("111c29")

var host
var mode: String = "single"
var selected_id: String = ""
var bios: Dictionary = {}

func _init(main) -> void:
    host = main
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BIOS_PATH))
    if parsed is Dictionary:
        bios = parsed
    else:
        push_error("Character bio data is missing or invalid.")

func _go(destination: String) -> void:
    host.screen = destination
    host.overlay_screen = ""
    host._redraw()

func _start_mode(chosen_mode: String) -> void:
    mode = chosen_mode
    selected_id = ""
    _go("select")

func _select_hero(id: String) -> void:
    selected_id = id
    _go("select")

func _continue_selection() -> void:
    if selected_id != "" and bios.has(selected_id):
        _go("bio")

func _confirm_selection() -> void:
    if selected_id == "" or not bios.has(selected_id):
        return
    if mode == "single":
        host._begin_act1_run(selected_id)
    else:
        _go("lobby")

func _open_settings() -> void:
    host._open_overlay("settings")

func _start_combat_preview() -> void:
    # The old four-hero encounter is intentionally preserved for Milestone 2.
    # It is a sandbox, NOT the one-hero-per-player Act 1 run.
    host._begin_single_player()

func _add_label(parent: Control, msg: String, rect: Rect2, font_size: int = 22, color: Color = TEXT, center: bool = false) -> Label:
    var label := Label.new()
    label.text = msg
    label.position = rect.position
    label.size = rect.size
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.clip_text = true
    parent.add_child(label)
    return label

func _add_text(parent: Control, msg: String, rect: Rect2, font_size: int = 19, color: Color = TEXT) -> RichTextLabel:
    var label := RichTextLabel.new()
    label.text = msg
    label.bbcode_enabled = false
    label.position = rect.position
    label.size = rect.size
    label.fit_content = false
    label.scroll_active = false
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("normal_font_size", font_size)
    label.add_theme_color_override("default_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _panel(parent: Control, rect: Rect2, color: Color, edge: Color = Color("47576a"), radius: int = 12) -> Panel:
    var panel := Panel.new()
    panel.position = rect.position
    panel.size = rect.size
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = edge
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    panel.add_theme_stylebox_override("panel", style)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(panel)
    return panel

func _button(parent: Control, node_name: String, title: String, rect: Rect2, callback: Callable, highlighted: bool = false, enabled: bool = true) -> Button:
    var button := Button.new()
    button.name = node_name
    button.position = rect.position
    button.size = rect.size
    button.text = title
    button.disabled = not enabled
    button.focus_mode = Control.FOCUS_ALL
    button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    button.add_theme_font_size_override("font_size", 23)
    button.add_theme_color_override("font_color", Color("ffe1a7") if highlighted else TEXT)
    button.add_theme_color_override("font_hover_color", Color("fff3d6"))
    button.add_theme_color_override("font_disabled_color", Color("727c88"))
    var base := StyleBoxFlat.new()
    base.bg_color = Color("45331d") if highlighted else Color("182635")
    base.border_color = GOLD if highlighted else Color("68798b")
    base.set_border_width_all(3 if highlighted else 2)
    base.set_corner_radius_all(9)
    var hover := base.duplicate() as StyleBoxFlat
    hover.bg_color = Color("63502e")
    hover.border_color = Color("ffe6af")
    var disabled_style := base.duplicate() as StyleBoxFlat
    disabled_style.bg_color = Color("1b222b")
    disabled_style.border_color = Color("454b53")
    button.add_theme_stylebox_override("normal", base)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("disabled", disabled_style)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _texture(parent: Control, path: String, rect: Rect2, cover: bool = false) -> void:
    if not ResourceLoader.exists(path):
        push_warning("Missing menu art: " + path)
        return
    var texture: Texture2D = load(path) as Texture2D
    if texture == null:
        push_warning("Invalid menu texture: " + path)
        return
    if cover:
        # Backdrops intentionally cover the 1600x900 viewport.
        var image := TextureRect.new()
        image.texture = texture
        image.position = rect.position
        image.size = rect.size
        image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        image.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(image)
        return
    # Sprite2D scaling is explicit and always fits, including transparent assets.
    # TextureRect's expansion/stretch combinations varied across Godot versions.
    var texture_size: Vector2 = texture.get_size()
    if texture_size.x <= 0.0 or texture_size.y <= 0.0:
        return
    var scale_factor: float = minf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
    var sprite := Sprite2D.new()
    sprite.texture = texture
    sprite.centered = true
    sprite.scale = Vector2.ONE * scale_factor
    sprite.position = rect.position + rect.size * 0.5
    parent.add_child(sprite)

func _screen_background() -> Control:
    var canvas: Control = host.ui_root
    _texture(canvas, "res://art/backgrounds/alextron_ruins.jpg", Rect2(Vector2.ZERO, STAGE_SIZE), true)
    var shade := ColorRect.new()
    shade.color = Color(0.035, 0.055, 0.09, 0.84)
    shade.size = STAGE_SIZE
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(shade)
    _texture(canvas, "res://art/ui/aptitude_logo.png", Rect2(52, 17, 430, 100))
    return canvas

func _header(parent: Control, headline: String, subtitle: String) -> void:
    _add_label(parent, headline, Rect2(280, 83, 1040, 86), 52, GOLD, true)
    _add_label(parent, subtitle, Rect2(300, 165, 1000, 43), 21, MUTED, true)

func _hero(id: String) -> Dictionary:
    return bios.get(id, {}) as Dictionary

func _hero_portrait(parent: Control, id: String, rect: Rect2, for_bio: bool = false) -> void:
    var file := "bio_art.png" if for_bio else "selection_portrait.png"
    _texture(parent, "res://art/characters/%s/%s" % [id, file], rect)

func draw(screen_name: String) -> void:
    match screen_name:
        "home": _draw_home()
        "play": _draw_play()
        "select": _draw_select()
        "bio": _draw_bio()
        "act1_map": _draw_act1_map()
        "act1_reward", "act1_rest", "act1_shop", "act1_event", "act1_complete", "act1_defeat": _draw_act1_action(screen_name)
        "lobby": _draw_lobby()

func _draw_home() -> void:
    var canvas: Control = host.ui_root
    _texture(canvas, "res://art/title_background.png", Rect2(Vector2.ZERO, STAGE_SIZE), true)
    # Original title art has painted buttons; cover their entire right-side strip.
    _panel(canvas, Rect2(1230, 385, 370, 465), Color("0d141e"), GOLD)
    _add_label(canvas, "MAIN MENU", Rect2(1248, 397, 340, 55), 29, GOLD, true)
    _button(canvas, "PlayMainMenuButton", "PLAY", Rect2(1252, 481, 323, 82), func(): _go("play"), true)
    _button(canvas, "SettingsMainMenuButton", "SETTINGS", Rect2(1252, 595, 323, 82), _open_settings)
    _button(canvas, "QuitMainMenuButton", "QUIT", Rect2(1252, 710, 323, 82), func(): host.get_tree().quit())

func _draw_play() -> void:
    var canvas := _screen_background()
    _header(canvas, "PLAY", "CHOOSE YOUR MODE")
    _mode_card(canvas, "SinglePlayerModeButton", "SINGLE PLAYER", "A solo run through The Construction Zone.", "Choose one hero, then plan your route to Alextron.", "res://art/ui/menu/single.png", Vector2(216, 255), "single")
    _mode_card(canvas, "MultiplayerModeButton", "MULTIPLAYER", "A cooperative run with your crew.", "Choose your hero and enter the future co-op lobby.", "res://art/ui/menu/multi.png", Vector2(836, 255), "multi")
    _button(canvas, "BackFromPlayButton", "BACK", Rect2(60, 793, 222, 65), func(): _go("home"))

func _mode_card(parent: Control, node_name: String, headline: String, sub: String, foot: String, art: String, position: Vector2, mode_choice: String) -> void:
    var rect := Rect2(position, Vector2(542, 457))
    _panel(parent, rect, Color("172330"), Color("bd9154"))
    _texture(parent, art, Rect2(position + Vector2(208, 56), Vector2(126, 112)))
    _add_label(parent, headline, Rect2(position + Vector2(23, 195), Vector2(496, 55)), 32, GOLD, true)
    _add_label(parent, sub, Rect2(position + Vector2(20, 275), Vector2(502, 42)), 18, TEXT, true)
    _add_label(parent, foot, Rect2(position + Vector2(15, 326), Vector2(512, 42)), 16, MUTED, true)
    _button(parent, node_name, "SELECT MODE", Rect2(position + Vector2(104, 385), Vector2(334, 57)), _start_mode.bind(mode_choice), true)

func _draw_select() -> void:
    var canvas := _screen_background()
    _header(canvas, "CHARACTER SELECT", "CHOOSE YOUR CREW MEMBER")
    for i in range(HERO_ORDER.size()):
        var id: String = HERO_ORDER[i]
        var hero: Dictionary = _hero(id)
        var pos := Vector2(74 + i * 372, 237)
        var is_selected := id == selected_id
        var frame := _panel(canvas, Rect2(pos, Vector2(336, 495)), Color("172433"), GOLD if is_selected else Color("607080"))
        if is_selected:
            var frame_style := frame.get_theme_stylebox("panel") as StyleBoxFlat
            frame_style.set_border_width_all(5)
        _hero_portrait(canvas, id, Rect2(pos + Vector2(14, 25), Vector2(308, 326)))
        _add_label(canvas, str(hero.get("name", id)), Rect2(pos + Vector2(7, 359), Vector2(322, 47)), 26, GOLD if is_selected else TEXT, true)
        _add_label(canvas, str(hero.get("trade", "")).to_upper(), Rect2(pos + Vector2(7, 409), Vector2(322, 26)), 15, MUTED, true)
        _button(canvas, "SelectHero" + id.to_pascal_case().replace("_", ""), "SELECTED" if is_selected else "SELECT", Rect2(pos + Vector2(54, 444), Vector2(228, 43)), _select_hero.bind(id), is_selected)
    _button(canvas, "BackFromSelectButton", "BACK", Rect2(61, 794, 218, 65), func(): _go("play"))
    _button(canvas, "ContinueSelectionButton", "CONTINUE", Rect2(1308, 794, 235, 65), _continue_selection, true, selected_id != "")

func _draw_bio() -> void:
    var canvas := _screen_background()
    var hero: Dictionary = _hero(selected_id)
    if hero.is_empty():
        _go("select")
        return
    _add_label(canvas, "CREW PROFILE", Rect2(78, 126, 650, 48), 22, GOLD)
    _add_label(canvas, str(hero.get("title", "")), Rect2(76, 175, 858, 72), 44, TEXT)
    _add_label(canvas, str(hero.get("trade", "")).to_upper(), Rect2(79, 250, 840, 33), 19, GOLD)
    _panel(canvas, Rect2(76, 310, 820, 125), Color("142333"), Color("4d6478"))
    _add_label(canvas, "STARTING HP", Rect2(104, 330, 230, 32), 18, MUTED)
    _add_label(canvas, "%d" % int(hero.get("starting_hp", 60)), Rect2(103, 364, 230, 54), 39, TEXT)
    _add_label(canvas, "ROLE", Rect2(389, 330, 405, 32), 18, MUTED)
    _add_label(canvas, str(hero.get("role", "")), Rect2(388, 369, 490, 44), 24, TEXT)
    _add_label(canvas, "BIOGRAPHY", Rect2(79, 454, 780, 38), 23, GOLD)
    _add_text(canvas, str(hero.get("bio", "")), Rect2(81, 500, 787, 115), 19)
    _add_label(canvas, "PASSIVE ABILITY  •  " + str(hero.get("passive_name", "")).to_upper(), Rect2(79, 636, 790, 38), 21, GOLD)
    _add_text(canvas, str(hero.get("passive_description", "")), Rect2(80, 683, 790, 64), 19)
    _panel(canvas, Rect2(961, 159, 548, 604), Color("182333"), Color("a78557"))
    _hero_portrait(canvas, selected_id, Rect2(974, 176, 522, 568), true)
    # Bio screen intentionally contains exactly TWO buttons (Back and Confirm).
    _button(canvas, "BackFromBioButton", "BACK", Rect2(61, 792, 221, 65), func(): _go("select"))
    _button(canvas, "ConfirmHeroButton", "CONFIRM", Rect2(1298, 792, 245, 65), _confirm_selection, true)

func _map_center(node: Dictionary) -> Vector2:
    if str(node["kind"]) == "boss":
        return Vector2(800, 238)
    return Vector2(499 + 301 * int(node["lane"]), 750 - 33 * int(node["floor"]))

func _map_button(parent: Control, node: Dictionary, available: bool, visited: bool) -> void:
    var point: Vector2 = _map_center(node)
    var kind: String = str(node["kind"])
    var btn := Button.new()
    btn.name = "MapNode" + str(node["id"]).replace("_", "")
    btn.position = point - Vector2(77, 14)
    btn.size = Vector2(154, 28)
    btn.text = kind.to_upper()
    btn.disabled = not available
    btn.focus_mode = Control.FOCUS_ALL if available else Control.FOCUS_NONE
    btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
    btn.add_theme_font_size_override("font_size", 13)
    btn.add_theme_color_override("font_color", Color("ffe9af"))
    btn.add_theme_color_override("font_disabled_color", Color("b1bfcc") if visited else Color("697a8d"))
    var box := StyleBoxFlat.new()
    box.bg_color = Color("554022") if available else (Color("283d40") if visited else Color("172838"))
    box.border_color = GOLD if available else (Color("6eab98") if visited else Color("485d71"))
    box.set_border_width_all(2 if available or visited else 1)
    box.set_corner_radius_all(7)
    var hover := box.duplicate() as StyleBoxFlat
    hover.bg_color = Color("826235")
    hover.border_color = Color("fff1c4")
    btn.add_theme_stylebox_override("normal", box)
    btn.add_theme_stylebox_override("disabled", box)
    btn.add_theme_stylebox_override("hover", hover)
    btn.add_theme_stylebox_override("pressed", hover)
    btn.add_theme_stylebox_override("focus", hover)
    btn.pressed.connect(_choose_node.bind(str(node["id"])))
    parent.add_child(btn)

func _choose_node(id: String) -> void:
    host._enter_act1_node(id)

func _draw_act1_map() -> void:
    var canvas := _screen_background()
    var run: AptitudeAct1Run = host.run_state
    _header(canvas, "ACT 1 — THE CONSTRUCTION ZONE", "15 FLOORS   •   CHOOSE A CONNECTED PATH   •   ALEXTRON AT THE TOP")
    _panel(canvas, Rect2(309, 214, 987, 567), Color("101f2e"), Color("a48351"))
    var available: Array = run.available_nodes()
    var available_ids: Array[String] = []
    for node in available:
        available_ids.append(str(node["id"]))
    # Draw connections beneath all clickable nodes.
    for row in run.floors:
        for node in row:
            var from: Vector2 = _map_center(node)
            for target_id in node["next"]:
                var next_node: Dictionary = run.node_by_id(str(target_id))
                if next_node.is_empty():
                    continue
                var connection := Line2D.new()
                connection.points = PackedVector2Array([from, _map_center(next_node)])
                connection.width = 1.5
                connection.default_color = Color("4b5e6e", 0.70)
                canvas.add_child(connection)
    for level in range(run.FLOOR_COUNT):
        var node_y: float = 750.0 - 33.0 * float(level)
        _add_label(canvas, "%02d" % (level + 1), Rect2(333, node_y - 12, 50, 24), 15, MUTED)
        for node in run.floors[level]:
            var id: String = str(node["id"])
            _map_button(canvas, node, available_ids.has(id), run.visited.has(id))
    _map_button(canvas, run.boss, available_ids.has(str(run.boss["id"])), run.visited.has(str(run.boss["id"])))
    # Run state shown beside the full map, rather than hiding the route.
    _panel(canvas, Rect2(1315, 244, 263, 456), Color("142636"), Color("65788a"))
    _add_label(canvas, "YOUR RUN", Rect2(1334, 264, 227, 48), 24, GOLD, true)
    var hero_def: Dictionary = _hero(run.hero_id)
    _add_label(canvas, str(hero_def.get("name", run.hero_id)), Rect2(1333, 329, 223, 40), 24, TEXT, true)
    _add_label(canvas, "HP: %d / %d" % [run.hp, run.max_hp], Rect2(1337, 399, 208, 42), 19, TEXT)
    _add_label(canvas, "COINS: %d" % run.coins, Rect2(1337, 455, 208, 42), 19, TEXT)
    _add_label(canvas, "DECK: %d CARDS" % run.deck.size(), Rect2(1337, 511, 213, 42), 19, TEXT)
    _add_label(canvas, run.floor_label().to_upper(), Rect2(1334, 583, 227, 45), 17, GOLD, true)
    _add_label(canvas, "MAP SEED: %d" % run.seed, Rect2(1337, 649, 230, 26), 13, MUTED)
    _add_label(canvas, "GLOWING NODES = AVAILABLE", Rect2(409, 786, 777, 37), 17, GOLD, true)
    _button(canvas, "ExitRunButton", "EXIT RUN", Rect2(55, 809, 211, 65), func(): _go("home"))

func _draw_act1_action(destination: String) -> void:
    var canvas := _screen_background()
    var run: AptitudeAct1Run = host.run_state
    _header(canvas, "ACT 1 — THE CONSTRUCTION ZONE", "YOUR PATH  •  " + run.floor_label().to_upper())
    _panel(canvas, Rect2(246, 230, 1108, 514), Color("142433"), Color("aa8453"))
    _add_label(canvas, "HP %d/%d  •  COINS %d  •  DECK %d" %
        [run.hp, run.max_hp, run.coins, run.deck.size()],
        Rect2(292, 269, 1024, 56), 24, MUTED, true)
    match destination:
        "act1_reward":
            _add_label(canvas, "COMBAT VICTORY", Rect2(347, 347, 922, 68), 43, GOLD, true)
            _add_label(canvas, "Choose one reward before returning to the map.", Rect2(347, 428, 922, 45), 21, TEXT, true)
            _button(canvas, "RewardAttackButton", "ADD ATTACK", Rect2(314, 554, 293, 72), _resolve_action.bind("attack"), true)
            _button(canvas, "RewardBlockButton", "ADD BLOCK", Rect2(655, 554, 293, 72), _resolve_action.bind("block"))
            _button(canvas, "RewardRepairButton", "REPAIR +8 HP", Rect2(995, 554, 293, 72), _resolve_action.bind("repair"))
        "act1_rest":
            _add_label(canvas, "REST SITE", Rect2(347, 347, 922, 68), 43, GOLD, true)
            _add_label(canvas, "Repair yourself or reinforce your maximum HP.", Rect2(347, 428, 922, 45), 21, TEXT, true)
            _button(canvas, "RestHealButton", "HEAL +12", Rect2(412, 550, 360, 73), _resolve_action.bind("heal"), true)
            _button(canvas, "RestUpgradeButton", "MAX HP +5", Rect2(827, 550, 360, 73), _resolve_action.bind("upgrade"))
        "act1_event":
            _add_label(canvas, "UNEXPECTED DISCOVERY", Rect2(347, 347, 922, 68), 43, GOLD, true)
            _add_label(canvas, "The crew finds a supply cache in the ruins.", Rect2(347, 428, 922, 45), 21, TEXT, true)
            _button(canvas, "EventSalvageButton", "SALVAGE +20 COINS", Rect2(410, 550, 368, 73), _resolve_action.bind("salvage"), true)
            _button(canvas, "EventRepairButton", "REPAIR +8 HP", Rect2(827, 550, 360, 73), _resolve_action.bind("repair"))
        "act1_shop":
            _add_label(canvas, "CONSTRUCTION SUPPLY DEPOT", Rect2(340, 347, 940, 68), 39, GOLD, true)
            _add_label(canvas, "Spend coins or continue to the next floor.", Rect2(347, 428, 922, 45), 21, TEXT, true)
            _button(canvas, "ShopHealButton", "HEAL +15   •   20", Rect2(303, 546, 302, 74),
                _resolve_action.bind("heal"), true, run.coins >= 20)
            _button(canvas, "ShopUpgradeButton", "MAX HP +5   •   30", Rect2(649, 546, 302, 74),
                _resolve_action.bind("upgrade"), false, run.coins >= 30)
            _button(canvas, "ShopLeaveButton", "LEAVE", Rect2(995, 546, 302, 74),
                _resolve_action.bind("leave"))
        "act1_complete":
            _add_label(canvas, "ALEXTRON SENTINEL DEFEATED", Rect2(302, 343, 1002, 80), 40, GOLD, true)
            _add_label(canvas, "ACT 1 COMPLETE", Rect2(353, 442, 896, 64), 35, TEXT, true)
            _add_label(canvas, "Act 2 is coming soon. Your run ends here for now.", Rect2(353, 510, 896, 54), 21, MUTED, true)
            _button(canvas, "CompleteReturnButton", "RETURN TO MAIN MENU",
                Rect2(581, 600, 441, 75), func(): _go("home"), true)
        "act1_defeat":
            _add_label(canvas, "RUN DEFEATED", Rect2(350, 354, 902, 77), 44, Color("f38b8d"), true)
            _add_label(canvas, "You reached " + run.floor_label() + " and cleared %d combats." %
                run.encounters_cleared, Rect2(345, 459, 916, 57), 23, MUTED, true)
            _button(canvas, "DefeatReturnButton", "RETURN TO MAIN MENU",
                Rect2(581, 600, 441, 75), func(): _go("home"), true)

func _resolve_action(choice: String) -> void:
    host._act1_resolve(choice)

func _draw_lobby() -> void:
    var canvas := _screen_background()
    _header(canvas, "MULTIPLAYER LOBBY", "COMING SOON")
    _panel(canvas, Rect2(311, 247, 978, 468), Color("162635"), Color("947a56"))
    _hero_portrait(canvas, selected_id, Rect2(368, 300, 284, 347), true)
    var hero: Dictionary = _hero(selected_id)
    _add_label(canvas, "HERO LOCKED IN", Rect2(694, 324, 523, 52), 28, GOLD)
    _add_label(canvas, str(hero.get("name", selected_id)), Rect2(693, 392, 523, 60), 35, TEXT)
    _add_text(canvas, "Co-op hosting, joining, and player slots will be available in the multiplayer milestone. Your selection is saved for this lobby preview.", Rect2(693, 487, 521, 133), 20, MUTED)
    _button(canvas, "BackFromLobbyButton", "BACK", Rect2(60, 792, 222, 65), func(): _go("bio"))
