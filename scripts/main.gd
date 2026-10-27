extends Control

# APTITUDE v0.9.5: native main-menu buttons with visible / clickable bounds identical.
# Card actions enter the authoritative live FIFO only on a valid drop.
const Combat = preload("res://scripts/combat_engine.gd")
const MenuFlow = preload("res://scripts/menu_flow.gd")
const Act1Run = preload("res://scripts/act1_run.gd")
const STAGE_W := 1600.0
const STAGE_H := 900.0

var combat = Combat.new()
var menu_flow
var run_state: AptitudeAct1Run = Act1Run.new()
var screen: String = "home"
var ui_root: Control
var drag_state: Dictionary = {}
var drag_preview: Panel
var target_panels: Dictionary = {} # "enemy:id" or "hero:id" -> Panel
var pulse_timer: float = 0.0
var overlay_screen: String = ""  # "deck" / "settings" / blank
var deck_focus_id: String = ""
# Audio player is attached to this scene, NOT the redrawn ui_root.
# Consequently neither scene changes nor overlay redraws restart the song.
var music_player: AudioStreamPlayer
var music_volume_percent: float = 50.0
var music_muted: bool = false
var volume_value_label: Label
var music_mute_button: Button
var fullscreen_enabled: bool = false
const CONFIG_PATH := "user://aptitude_settings.cfg"
const MUSIC_FILE := "res://audio/music-for-study--focus.mp3"

func _ready() -> void:
	menu_flow = MenuFlow.new(self)
	_load_preferences()
	_start_music()
	combat.changed.connect(_on_combat_changed)
	_redraw()

func _start_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	var track: AudioStream = load(MUSIC_FILE) as AudioStream
	if track == null:
		push_warning("Could not load background music: " + MUSIC_FILE)
		return
	# MP3 is imported as an AudioStreamMP3; its loop property prevents
	# playback stopping at the end of the approximately 3-minute track.
	if track is AudioStreamMP3:
		var mp3: AudioStreamMP3 = track as AudioStreamMP3
		mp3.loop = true
	music_player.stream = track
	_apply_music_volume()
	music_player.play()

func _apply_music_volume() -> void:
	if not is_instance_valid(music_player):
		return
	var gain: float = 0.0 if music_muted else music_volume_percent / 100.0
	music_player.volume_db = linear_to_db(maxf(gain, 0.0001)) if gain > 0.0 else -80.0

func _load_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		music_volume_percent = clampf(float(cfg.get_value("audio", "music_volume_percent", 50.0)), 0.0, 100.0)
		music_muted = bool(cfg.get_value("audio", "music_muted", false))
		fullscreen_enabled = bool(cfg.get_value("video", "fullscreen", false))
	if fullscreen_enabled:
		get_window().mode = Window.MODE_FULLSCREEN

func _save_preferences() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "music_volume_percent", music_volume_percent)
	cfg.set_value("audio", "music_muted", music_muted)
	cfg.set_value("video", "fullscreen", fullscreen_enabled)
	var err: Error = cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("Could not save settings: " + str(err))

func _set_music_volume(value: float) -> void:
	music_volume_percent = clampf(value, 0.0, 100.0)
	if music_volume_percent > 0.0:
		music_muted = false
	_apply_music_volume()
	_save_preferences()
	if is_instance_valid(volume_value_label):
		volume_value_label.text = "%d%%" % roundi(music_volume_percent)
	if is_instance_valid(music_mute_button):
		music_mute_button.text = "UNMUTE" if music_muted else "MUTE"

func _toggle_music_mute() -> void:
	music_muted = not music_muted
	_apply_music_volume()
	_save_preferences()
	_redraw()

func _begin_single_player() -> void:
	overlay_screen = ""
	screen = "battle"
	combat.start(["bryan", "carlos", "manny", "cristian_hb"])

func _begin_act1_run(hero_id: String) -> void:
	if not combat.heroes.has(hero_id):
		push_error("Cannot start Act 1 with an unknown hero: " + hero_id)
		return
	run_state.start_new(hero_id, int(combat.heroes[hero_id]["max_hp"]))
	overlay_screen = ""
	screen = "act1_map"
	_redraw()

func _enter_act1_node(id: String) -> void:
	if not run_state.choose_node(id):
		return
	overlay_screen = ""
	if run_state.state == "battle":
		# Solo: exactly one hero and one deck; Act 1 resources persist.
		screen = "battle"
		combat.start([run_state.hero_id], run_state.encounter_id(), run_state.combat_options())
	else:
		screen = "act1_" + run_state.state
		_redraw()

func _act1_resolve(choice: String) -> void:
	var resolved: bool = false
	if run_state.state == "reward":
		resolved = run_state.claim_reward(choice)
	else:
		resolved = run_state.resolve_node(choice)
	if resolved:
		screen = "act1_map"
		_redraw()

func _on_combat_changed() -> void:
	if run_state.state == "battle" and screen == "battle" and (combat.phase == "victory" or combat.phase == "defeat"):
		var hero: Dictionary = combat.hero_by_id(run_state.hero_id)
		var hero_hp: int = int(hero.get("hp", 0))
		var hero_max_hp: int = int(hero.get("max_hp", run_state.max_hp))
		run_state.finish_battle(hero_hp, hero_max_hp, combat.coins, combat.phase == "victory")
		match run_state.state:
			"reward": screen = "act1_reward"
			"complete": screen = "act1_complete"
			"defeat": screen = "act1_defeat"
	_redraw()

func _process(delta: float) -> void:
	if drag_state.is_empty():
		return
	pulse_timer += delta
	var mouse: Vector2 = get_global_mouse_position()
	if is_instance_valid(drag_preview):
		drag_preview.position = mouse - Vector2(70, 99)
	var hovered: String = _find_drop_target(mouse)
	var wave: float = (sin(pulse_timer * 7.5) + 1.0) * 0.5
	for key in target_panels:
		var tile: Panel = target_panels[key]
		if not is_instance_valid(tile):
			continue
		var style: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
		if _is_valid_target(str(key)):
			var bright: bool = str(key) == hovered
			style.border_color = Color("fff5a7") if bright else Color("ffd34b").lerp(Color("ffed9b"), wave)
			style.set_border_width_all(5 if bright else 3)
			style.shadow_color = Color(1.0, 0.75, 0.12, 0.38 + 0.32 * wave)
			style.shadow_size = 16 if bright else 7 + int(5.0 * wave)
		else:
			style.border_color = Color.TRANSPARENT
			style.set_border_width_all(0)
			style.shadow_size = 0

func _input(event: InputEvent) -> void:
	if overlay_screen != "":
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	if drag_state.is_empty():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(get_global_mouse_position())
		get_viewport().set_input_as_handled()

func _label(parent: Node, message: String, pos: Vector2, size: Vector2, font_size: int = 20, color: Color = Color.WHITE) -> Label:
	var l: Label = Label.new()
	l.text = message
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _panel(parent: Node, pos: Vector2, size: Vector2, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	panel.position = pos
	panel.size = size
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("616777")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _button(parent: Node, title: String, pos: Vector2, size: Vector2, callback: Callable, emphasized: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = title
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 18)
	if emphasized:
		b.add_theme_color_override("font_color", Color("ffe9ac"))
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _redraw() -> void:
	# A committed action changes combat state and recreates the controls.
	_cancel_drag(false)
	if is_instance_valid(ui_root):
		ui_root.queue_free()
	target_panels.clear()
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("111b24")
	bg.size = Vector2(STAGE_W, STAGE_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(bg)
	if screen == "battle":
		_draw_battle()
	else:
		menu_flow.draw(screen)
	if overlay_screen != "":
		_draw_overlay()

# MAIN MENU v0.9.5
# The original menu painting includes four pre-rendered buttons. Rather than
# ever matching invisible click rectangles to an image, mask those printed
# buttons with an opaque, dark industrial menu panel and render ONE set of
# actual Godot Button controls. Their visuals are their interactive hitboxes.
# Gameplay is a virtual 1600x900 stage, scaled to the OS window by canvas_items.
const MENU_PANEL_X := 1286.0
const MENU_PANEL_Y := 417.0
const MENU_PANEL_W := 294.0
const MENU_PANEL_H := 379.0

func _draw_home() -> void:
	var artwork: TextureRect = TextureRect.new()
	artwork.name = "MenuBackground"
	artwork.texture = load("res://art/title_background.png")
	artwork.position = Vector2.ZERO
	artwork.size = Vector2(STAGE_W, STAGE_H)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(artwork)

	# An opaque panel entirely covers the four obsolete painted buttons.
	# This keeps all approved key art intact outside the right-hand menu zone.
	var menu_panel: Panel = Panel.new()
	menu_panel.name = "MainMenuControls"
	menu_panel.position = Vector2(MENU_PANEL_X, MENU_PANEL_Y)
	menu_panel.size = Vector2(MENU_PANEL_W, MENU_PANEL_H)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color("0e131c")
	panel_style.border_color = Color("aa7a35")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(7)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.68)
	panel_style.shadow_size = 16
	menu_panel.add_theme_stylebox_override("panel", panel_style)
	ui_root.add_child(menu_panel)

	# 4 native buttons, using their own styled rectangles and built-in input.
	# Consistent spacing also guarantees no control can extend offscreen.
	_menu_button(menu_panel, "SinglePlayerMenuButton", "SINGLE PLAYER", "single", 18.0, _begin_single_player, true)
	_menu_button(menu_panel, "MultiplayerMenuButton", "MULTIPLAYER", "multi", 105.0, _show_multiplayer_notice)
	_menu_button(menu_panel, "SettingsMenuButton", "SETTINGS", "settings", 192.0, _open_overlay.bind("settings"))
	_menu_button(menu_panel, "QuitMenuButton", "QUIT", "quit", 279.0, func(): get_tree().quit())

func _show_multiplayer_notice() -> void:
	_open_overlay("multiplayer")

func _menu_button(parent: Control, node_name: String, title: String, icon_name: String, top: float, action: Callable, highlighted: bool = false) -> Button:
	var b: Button = Button.new()
	b.name = node_name
	b.position = Vector2(13, top)
	b.size = Vector2(MENU_PANEL_W - 26.0, 69)
	b.text = title
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.icon = load("res://art/ui/menu/" + icon_name + ".png")
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = true
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_color_override("font_color", Color("ffe5b1") if highlighted else Color("d7d9df"))
	b.add_theme_color_override("font_hover_color", Color("fff2d2"))
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_color_override("font_focus_color", Color("fff2d2"))

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color("171c25")
	normal.border_color = Color("dcaa44") if highlighted else Color("50545d")
	normal.set_border_width_all(2 if highlighted else 1)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 10
	normal.content_margin_right = 12
	var hovered: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hovered.bg_color = Color("3b301f")
	hovered.border_color = Color("ffe0a0")
	hovered.set_border_width_all(3)
	hovered.shadow_color = Color(1.0, 0.56, 0.11, 0.29)
	hovered.shadow_size = 5
	var pressed: StyleBoxFlat = hovered.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("644118")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hovered)
	b.add_theme_stylebox_override("focus", hovered)
	b.add_theme_stylebox_override("pressed", pressed)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _health_bar(parent: Node, position: Vector2, width: float, hp: int, max_hp: int) -> void:
	var bar_back: ColorRect = ColorRect.new()
	bar_back.position = position
	bar_back.size = Vector2(width, 11)
	bar_back.color = Color("131a22")
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar_back)
	var bar_fill: ColorRect = ColorRect.new()
	bar_fill.position = position + Vector2(2, 2)
	var fraction: float = clampf(float(hp) / float(maxi(1, max_hp)), 0.0, 1.0)
	bar_fill.size = Vector2((width - 4.0) * fraction, 7)
	bar_fill.color = Color("e94d53")
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar_fill)

func _unit_hitbox(pos: Vector2, size: Vector2, id: String) -> Panel:
	var hitbox: Panel = _panel(ui_root, pos, size, Color.TRANSPARENT)
	var style: StyleBoxFlat = hitbox.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.shadow_size = 0
	hitbox.mouse_filter = Control.MOUSE_FILTER_STOP
	# Border pulses for the entire clickable model region while a card is held.
	target_panels[id] = hitbox
	return hitbox

func _unit_sprite(parent: Node, resource_path: String, center: Vector2, max_size: Vector2, dimmed: bool = false) -> void:
	if resource_path == "" or not ResourceLoader.exists(resource_path):
		return
	var texture: Texture2D = load(resource_path) as Texture2D
	if texture == null:
		return
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var scale_factor: float = minf(max_size.x / source_size.x, max_size.y / source_size.y)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.scale = Vector2(scale_factor, scale_factor)
	# Centering the scaled sprite against a fixed ground baseline makes
	# different poses/asset resolutions line up without stretching or cropping.
	sprite.position = center - Vector2(0.0, source_size.y * scale_factor * 0.5)
	if dimmed:
		sprite.modulate.a = 0.38
	parent.add_child(sprite)

func _draw_hero_unit(hero: Dictionary, center_x: float) -> void:
	var hero_id: String = str(hero["id"])
	var definition: Dictionary = combat.heroes[hero_id]
	var selected: bool = hero_id == str(combat.active_hero)
	# A transparent unit region replaces the old portrait panel entirely.
	# Ground baseline is 514 in the 1600x900 design space.
	var unit_x: float = center_x - 91.0
	var region: Panel = _unit_hitbox(Vector2(unit_x, 203), Vector2(182, 404), "hero:" + hero_id)
	region.gui_input.connect(_on_hero_input.bind(hero_id))
	var lift: bool = hero_id == "cristian_hb"
	var display_h: float = 267.0 if lift else 240.0
	_unit_sprite(region, str(definition.get("sprite", "")), Vector2(91.0, 311.0), Vector2(177.0, display_h), int(hero["hp"]) <= 0)
	var title: String = str(definition["name"]) + (" ✓" if bool(hero["done"]) else "")
	var name_color: Color = Color("ffd879") if selected else Color("f4f5f7")
	_label(region, title, Vector2(0, 318), Vector2(182, 26), 18 if lift else 20, name_color).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if selected:
		var highlight: ColorRect = ColorRect.new()
		highlight.position = Vector2(37, 344)
		highlight.size = Vector2(108, 3)
		highlight.color = Color("ffd36e")
		highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
		region.add_child(highlight)
	_health_bar(region, Vector2(20, 353), 142.0, int(hero["hp"]), int(hero["max_hp"]))
	_label(region, "%d / %d" % [int(hero["hp"]), int(hero["max_hp"])], Vector2(0, 365), Vector2(182, 23), 16, Color("fff8f4")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(region, "◆ %d    ✦ %d" % [int(hero["block"]), int(hero["strength"])], Vector2(0, 388), Vector2(182, 22), 14, Color("9ed8fa")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _draw_enemy_unit(enemy: Dictionary, index: int, enemy_count: int) -> void:
	var enemy_type: Dictionary = combat.enemy_defs[str(enemy["type_id"])]
	var alive: bool = int(enemy["hp"]) > 0
	var center_x: float = 1202.0
	if enemy_count == 2:
		center_x = 1090.0 + 226.0 * float(index)
	elif enemy_count == 3:
		center_x = 1014.0 + 171.0 * float(index)
	elif enemy_count >= 4:
		center_x = 980.0 + 135.0 * float(index)
	var width: float = 190.0 if enemy_count <= 3 else 138.0
	var region: Panel = _unit_hitbox(Vector2(center_x - width * 0.5, 272), Vector2(width, 334), "enemy:" + str(enemy["id"]))
	# Enemy attack intent is ABOVE the sprite, never in a card panel.
	var intent_text: String = "⚔ %d" % int(enemy["damage"]) if alive else ""
	_label(region, intent_text, Vector2(0, 44), Vector2(width, 34), 24, Color("ff545a")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Roboduck is half-height compared with the 240px humanoid heroes.
	var displayed_height: float = 122.0 if enemy_count < 4 else 108.0
	_unit_sprite(region, str(enemy_type.get("sprite", "")), Vector2(width * 0.5, 241.0), Vector2(width - 6.0, displayed_height), not alive)
	var full_name: String = str(enemy_type["name"])
	if enemy_count > 1:
		full_name += " #%d" % (index + 1)
	_label(region, full_name, Vector2(0, 248), Vector2(width, 27), 18, Color("f5f5f7")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_health_bar(region, Vector2(9, 277), width - 18.0, int(enemy["hp"]), int(enemy["max_hp"]))
	_label(region, "%d / %d" % [int(enemy["hp"]), int(enemy["max_hp"])], Vector2(0, 289), Vector2(width, 23), 16, Color("fff8f4")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(region, "◆ %d" % int(enemy["block"]) if alive else "DEFEATED", Vector2(0, 312), Vector2(width, 22), 14, Color("9ed8fa") if alive else Color("f5a2a2")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _draw_battle() -> void:
	# Minimal black-metal header: logo left, intentional empty center, utilities right.
	var header: Panel = _panel(ui_root, Vector2(8, 7), Vector2(1584, 70), Color("0b131f"))
	var header_style: StyleBoxFlat = header.get_theme_stylebox("panel") as StyleBoxFlat
	header_style.border_color = Color("3d5164")
	header_style.set_corner_radius_all(5)
	_image(header, "res://art/ui/aptitude_logo.png", Vector2(20, 9), Vector2(300, 54))
	# Current coin balance, followed by three empty potion slots.
	_image(header, "res://art/ui/coin.png", Vector2(1084, 15), Vector2(38, 38))
	_label(header, str(combat.coins), Vector2(1128, 20), Vector2(44, 35), 23, Color("f9e9c5"))
	if run_state.state == "battle":
		_label(header, "ACT 1  /  " + run_state.floor_label().to_upper(), Vector2(354, 18), Vector2(565, 43), 19, Color("e9bd71"))
	for i in range(3):
		var pot_slot: Panel = _panel(header, Vector2(1184 + i * 44, 17), Vector2(34, 37), Color("142030"))
		var pot_style: StyleBoxFlat = pot_slot.get_theme_stylebox("panel") as StyleBoxFlat
		pot_style.border_color = Color("465d72")
		pot_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var active_definition: Dictionary = combat.heroes[str(combat.active_hero)]
	var deck_count: int = run_state.deck.size() if run_state.state == "battle" else active_definition["starter_deck"].size()
	_hud_button(header, "DECK (%d)" % deck_count, Vector2(1326, 13), Vector2(132, 45), _open_overlay.bind("deck"), "res://art/ui/deck.png")
	_hud_button(header, "SETTINGS", Vector2(1464, 13), Vector2(113, 45), _open_overlay.bind("settings"), "res://art/ui/gear.png")

	var stage: Panel = _panel(ui_root, Vector2(20, 89), Vector2(1560, 545), Color("26323b"))
	var wallpaper_path: String = combat.battlefield_background
	if wallpaper_path != "" and ResourceLoader.exists(wallpaper_path):
		var backdrop: TextureRect = TextureRect.new()
		backdrop.texture = load(wallpaper_path)
		backdrop.position = Vector2(1, 1)
		backdrop.size = Vector2(1558, 543)
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(backdrop)
	var veil: ColorRect = ColorRect.new()
	veil.color = Color(0.03, 0.06, 0.09, 0.12)
	veil.size = Vector2(1558, 543)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(veil)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Battlefield slots: up to four heroes, with transparent hitboxes and
	# compact health/status UI underneath each model. Empty space in the middle.
	var hero_positions: Array[float] = [410.0] if combat.party.size() == 1 else [142.0, 340.0, 538.0, 736.0]
	for i in range(mini(combat.party.size(), 4)):
		_draw_hero_unit(combat.party[i], hero_positions[i])
	for i in range(combat.enemies.size()):
		_draw_enemy_unit(combat.enemies[i], i, combat.enemies.size())

	# Compact combat HUD: energy on the left, only the hand in the center,
	# End Turn on the right. Draw/discard/exhaust remain tracked in the engine.
	var footer: Panel = _panel(ui_root, Vector2(0, 641), Vector2(STAGE_W, 259), Color("101b2b"))
	var footer_style: StyleBoxFlat = footer.get_theme_stylebox("panel") as StyleBoxFlat
	footer_style.border_color = Color("33495d")
	_image(ui_root, "res://art/ui/energy_ring.png", Vector2(20, 688), Vector2(176, 176))
	var current: Dictionary = combat.hero_by_id(combat.active_hero)
	_label(ui_root, "%d/%d" % [int(current["energy"]), int(combat.heroes[current["id"]]["base_energy"])], Vector2(46, 737), Vector2(124, 53), 38, Color("fff2d2")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(ui_root, "ENERGY", Vector2(52, 788), Vector2(112, 25), 15, Color("ffda84")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hand: Array = current["hand"]
	var shown: int = mini(hand.size(), 7)
	var card_width: float = 139.0
	var gap: float = 12.0
	var hand_width: float = float(shown) * card_width + float(maxi(0, shown - 1)) * gap
	var start_x: float = 770.0 - hand_width * 0.5
	for i in range(shown):
		var card: Dictionary = combat.cards[str(hand[i])]
		var cx: float = start_x + float(i) * (card_width + gap)
		var usable: bool = not bool(current["done"]) and int(card["cost"]) <= int(current["energy"]) and combat.phase == "player" and (str(card["type"]) != "power" or not current["powers_played"].has(str(card["id"])))
		var card_tile: Panel = _draw_card(ui_root, card, Vector2(cx, 678), Vector2(card_width, 199), usable)
		if usable:
			card_tile.mouse_filter = Control.MOUSE_FILTER_STOP
			card_tile.gui_input.connect(_on_card_input.bind(i, str(current["id"])))
	if combat.phase == "player":
		_hud_button(ui_root, "END TURN", Vector2(1351, 746), Vector2(212, 71), _done, "", true)
	if bool(current["done"]):
		_label(ui_root, "Waiting for other heroes", Vector2(1330, 829), Vector2(252, 24), 14, Color("b0c5d4")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if combat.phase == "victory" or combat.phase == "defeat":
		var won: bool = combat.phase == "victory"
		_label(ui_root, "VICTORY — +25 COINS" if won else "DEFEAT — RETRY", Vector2(510, 185), Vector2(680, 67), 46, Color("86e1ab") if won else Color("ff8989"))

func _image(parent: Node, path: String, pos: Vector2, dimensions: Vector2) -> TextureRect:
	var img: TextureRect = TextureRect.new()
	img.position = pos
	img.size = dimensions
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(img)
	return img

func _hud_button(parent: Node, title: String, pos: Vector2, dimensions: Vector2, callback: Callable, icon_path: String = "", prominent: bool = false) -> Button:
	var b: Button = _button(parent, title, pos, dimensions, callback, prominent)
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color("202c3e") if prominent else Color("111c2a")
	normal.border_color = Color("718092") if prominent else Color("405269")
	normal.set_border_width_all(2 if prominent else 1)
	normal.set_corner_radius_all(7)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("34485d")
	hover.border_color = Color("d2a65d")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_font_size_override("font_size", 18 if prominent else 15)
	b.add_theme_color_override("font_color", Color("f7f5ee"))
	if icon_path != "":
		# Text gets padding from the icon without blocking button input.
		b.text = "      " + title
		_image(b, icon_path, Vector2(9, 8), Vector2(27, dimensions.y - 16))
	return b

func _card_art_path(card: Dictionary) -> String:
	match str(card["id"]):
		"attack": return "res://art/ui/attack.png"
		"block": return "res://art/ui/block.png"
		"demon": return "res://art/ui/demon.png"
	return "res://art/ui/deck.png"

func _card_description(card: Dictionary) -> String:
	# Layout-only condensed copy. The authoritative effects remain in cards.json.
	match str(card["id"]):
		"attack": return "Deal 1 + Strength damage to one enemy."
		"block": return "Gain 1 Block.\nSelf only."
		"demon": return "+1 Strength to self or ally for this fight. Exhaust."
	return str(card["description"])

func _draw_card(parent: Node, card: Dictionary, pos: Vector2, dimensions: Vector2, enabled: bool) -> Panel:
	var kind: String = str(card["type"])
	var accent: Color = Color("d85b5c") if kind == "attack" else (Color("4d9fd1") if kind == "skill" else Color("a97ae1"))
	var fill: Color = Color("38222d") if kind == "attack" else (Color("172f49") if kind == "skill" else Color("322543"))
	var tile: Panel = _panel(parent, pos, dimensions, fill if enabled else fill.darkened(0.42))
	var style: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = accent if enabled else Color("526072")
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	tile.clip_contents = true
	var top: ColorRect = ColorRect.new()
	top.position = Vector2(3, 3)
	top.size = Vector2(dimensions.x - 6, 34)
	top.color = accent.darkened(0.56)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(top)
	_label(tile, str(card["name"]), Vector2(39, 7), Vector2(dimensions.x - 47, 28), 17, Color("f8f4e9"))
	var cost: Panel = _panel(tile, Vector2(6, 5), Vector2(29, 29), Color("173e65"))
	var cost_style: StyleBoxFlat = cost.get_theme_stylebox("panel") as StyleBoxFlat
	cost_style.border_color = Color("87d9ff")
	cost_style.set_border_width_all(2)
	cost_style.set_corner_radius_all(16)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(cost, str(card["cost"]), Vector2(0, 0), Vector2(29, 27), 19, Color("ffffff")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_image(tile, _card_art_path(card), Vector2((dimensions.x - 63) * 0.5, 40), Vector2(63, 63))
	_label(tile, kind.to_upper(), Vector2(8, 103), Vector2(dimensions.x - 16, 17), 12, accent.lightened(0.43)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc: RichTextLabel = RichTextLabel.new()
	desc.bbcode_enabled = false
	desc.text = _card_description(card)
	desc.position = Vector2(10, 124)
	desc.size = Vector2(dimensions.x - 20, maxf(0.0, dimensions.y - 130.0))
	desc.custom_minimum_size = Vector2.ZERO
	desc.fit_content = false
	desc.scroll_active = false
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("normal_font_size", 13)
	desc.add_theme_color_override("default_color", Color("f1eae0"))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.clip_contents = true
	tile.add_child(desc)
	return tile

func _open_overlay(kind: String) -> void:
	_cancel_drag()
	overlay_screen = kind
	if kind == "deck":
		deck_focus_id = str(combat.active_hero)
	_redraw()

func _close_overlay() -> void:
	overlay_screen = ""
	_redraw()

func _switch_deck_hero(hero_id: String) -> void:
	deck_focus_id = hero_id
	_redraw()

func _toggle_fullscreen() -> void:
	fullscreen_enabled = not fullscreen_enabled
	get_window().mode = Window.MODE_FULLSCREEN if fullscreen_enabled else Window.MODE_WINDOWED
	_save_preferences()
	_redraw()

func _draw_overlay() -> void:
	# A visually modal layer. Closing it only redraws UI and never restarts combat.
	var layer: Control = Control.new()
	layer.size = Vector2(STAGE_W, STAGE_H)
	layer.z_index = 80
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(layer)
	var shade: ColorRect = ColorRect.new()
	shade.size = Vector2(STAGE_W, STAGE_H)
	shade.color = Color(0, 0, 0, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(shade)
	var is_deck: bool = overlay_screen == "deck"
	var modal: Panel = _panel(layer, Vector2(178, 123) if is_deck else Vector2(440, 193), Vector2(1244, 653) if is_deck else Vector2(720, 515), Color("111d2c"))
	var style: StyleBoxFlat = modal.get_theme_stylebox("panel") as StyleBoxFlat
	style.border_color = Color("73849c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(11)
	_hud_button(modal, "CLOSE  X", Vector2(modal.size.x - 153, 24), Vector2(128, 46), _close_overlay)
	if overlay_screen == "multiplayer":
		_label(modal, "MULTIPLAYER", Vector2(44, 43), Vector2(560, 58), 32, Color("ffcf84"))
		_label(modal, "Four-player online co-op is planned for a future build.", Vector2(44, 156), Vector2(630, 90), 20, Color("c4d2df"))
		_label(modal, "Single Player is ready for testing now.", Vector2(44, 251), Vector2(630, 52), 19, Color("acbecf"))
	elif is_deck:
		if deck_focus_id == "" or not combat.heroes.has(deck_focus_id):
			deck_focus_id = str(combat.active_hero)
		var hero_def: Dictionary = combat.heroes[deck_focus_id]
		var deck: Array = run_state.deck if run_state.state == "battle" and deck_focus_id == run_state.hero_id else hero_def["starter_deck"]
		_label(modal, "DECK INVENTORY", Vector2(38, 20), Vector2(560, 50), 30, Color("f9d18a"))
		_label(modal, str(hero_def["name"]) + "  •  %d cards" % deck.size(), Vector2(40, 75), Vector2(650, 32), 21, Color("bdcddb"))
		for i in range(combat.party.size()):
			var id: String = str(combat.party[i]["id"])
			var heroname: String = str(combat.heroes[id]["name"])
			var tab: Button = _hud_button(modal, heroname, Vector2(37 + i * 299, 124), Vector2(275, 45), _switch_deck_hero.bind(id))
			if id == deck_focus_id:
				tab.add_theme_color_override("font_color", Color("ffdb8b"))
		for i in range(deck.size()):
			var id: String = str(deck[i])
			if not combat.cards.has(id):
				continue
			var x: float = 106.0 + float(i % 5) * 210.0
			var y: float = 191.0 + float(i / 5) * 206.0
			var tile: Panel = _draw_card(modal, combat.cards[id], Vector2(x, y), Vector2(148, 190), true)
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label(modal, "All cards shown, including those currently in hand, draw, discard, or exhaust piles.", Vector2(76, 601), Vector2(1080, 25), 16, Color("9bb2c7"))
	else:
		_label(modal, "SETTINGS", Vector2(44, 37), Vector2(350, 54), 32, Color("ffcf84"))
		_label(modal, "Preferences are saved between game launches.", Vector2(45, 91), Vector2(610, 36), 18, Color("a9bfcd"))
		_label(modal, "Music Volume", Vector2(60, 158), Vector2(250, 38), 22)
		var slider: HSlider = HSlider.new()
		slider.position = Vector2(60, 212)
		slider.size = Vector2(435, 36)
		slider.min_value = 0.0
		slider.max_value = 100.0
		slider.step = 1.0
		slider.value = music_volume_percent
		slider.value_changed.connect(_set_music_volume)
		modal.add_child(slider)
		volume_value_label = _label(modal, "%d%%" % roundi(music_volume_percent), Vector2(519, 214), Vector2(78, 36), 21, Color("ffda84"))
		music_mute_button = _hud_button(modal, "UNMUTE" if music_muted else "MUTE", Vector2(60, 266), Vector2(148, 45), _toggle_music_mute)
		_label(modal, "Fullscreen", Vector2(60, 338), Vector2(240, 38), 22)
		_hud_button(modal, "ON" if fullscreen_enabled else "OFF", Vector2(415, 329), Vector2(192, 49), _toggle_fullscreen)
		_label(modal, "Music continues through menus and combat.", Vector2(60, 414), Vector2(610, 32), 16, Color("9bb2c7"))

func _on_hero_input(event: InputEvent, hero_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and drag_state.is_empty():
		combat.select_hero(hero_id)

func _on_card_input(event: InputEvent, index: int, hero_id: String) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	if not drag_state.is_empty():
		return
	var hero: Dictionary = combat.hero_by_id(hero_id)
	if hero.is_empty() or hero["done"] or index >= hero["hand"].size() or combat.phase != "player":
		return
	var card: Dictionary = combat.cards[str(hero["hand"][index])]
	if int(hero["energy"]) < int(card["cost"]):
		return
	if str(card["type"]) == "power" and hero["powers_played"].has(str(card["id"])):
		return
	drag_state = {"hero_id": hero_id, "card_index": index, "target_type": combat.card_target_type(card)}
	pulse_timer = 0.0
	drag_preview = _draw_card(ui_root, card, Vector2.ZERO, Vector2(139, 199), true)
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.modulate.a = 0.92
	drag_preview.z_index = 50
	drag_preview.position = get_global_mouse_position() - Vector2(70, 99)
	# The original card stays in hand. No energy or HP is changed until a valid drop.

func _is_valid_target(key: String) -> bool:
	if drag_state.is_empty():
		return false
	var target_type: String = str(drag_state["target_type"])
	if key.begins_with("enemy:"):
		if target_type != "enemy":
			return false
		var enemy_id: String = key.trim_prefix("enemy:")
		for enemy in combat.enemies:
			if str(enemy["id"]) == enemy_id:
				return int(enemy["hp"]) > 0
		return false
	if key.begins_with("hero:"):
		if target_type != "ally" and target_type != "self" and target_type != "all_allies":
			return false
		var hero_id: String = key.trim_prefix("hero:")
		for hero in combat.party:
			if str(hero["id"]) == hero_id and int(hero["hp"]) > 0:
				return target_type != "self" or hero_id == str(drag_state["hero_id"])
	return false

func _find_drop_target(point: Vector2) -> String:
	for key in target_panels:
		if not _is_valid_target(str(key)):
			continue
		var tile: Panel = target_panels[key]
		if is_instance_valid(tile) and tile.get_global_rect().has_point(point):
			return str(key)
	return ""

func _finish_drag(point: Vector2) -> void:
	var destination: String = _find_drop_target(point)
	if destination == "":
		_cancel_drag()
		return
	var command: Dictionary = drag_state.duplicate()
	_cancel_drag(false)
	var target_id: String = destination.substr(destination.find(":") + 1)
	var error: String = combat.submit_card(str(command["hero_id"]), int(command["card_index"]), target_id)
	if error != "":
		combat.log_line("Rejected: " + error)
		_redraw()

func _cancel_drag(reset_styles: bool = true) -> void:
	if is_instance_valid(drag_preview):
		drag_preview.queue_free()
	drag_preview = null
	drag_state.clear()
	if reset_styles:
		for key in target_panels:
			var tile: Panel = target_panels[key]
			if is_instance_valid(tile):
				var style: StyleBoxFlat = tile.get_theme_stylebox("panel") as StyleBoxFlat
				style.border_color = Color.TRANSPARENT
				style.set_border_width_all(0)
				style.shadow_size = 0

func _done() -> void:
	combat.mark_done(combat.active_hero)
	for hero in combat.party:
		if not hero["done"]:
			combat.select_hero(str(hero["id"]))
			break

func _restart() -> void:
	combat.start(combat.party.map(func(hero): return hero["id"]))

