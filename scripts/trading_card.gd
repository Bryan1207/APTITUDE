extends Panel
## Shared trading-card asset template for Heroes, Machines and Ability cards.
## Layout is composed of actual controls so portraits, stats and art remain
## data-driven, separately replaceable, and reliably scaled at any resolution.
const CharacterArt = preload("res://scripts/character_art.gd")
var entry: Dictionary = {}
var category: String = "hero"

func configure(info: Dictionary, kind: String) -> void:
    entry = info.duplicate(true)
    category = kind
    if is_inside_tree():
        _build()

func _ready() -> void:
    _build()

func _text(parent: Control, value: String, pos: Vector2, bounds: Vector2, font_size: int, ink: Color, center: bool = false) -> Label:
    var label := Label.new()
    label.text = value
    label.position = pos
    label.size = bounds
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", ink)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _panel(parent: Control, pos: Vector2, bounds: Vector2, bg: Color, line: Color) -> Panel:
    var p := Panel.new()
    p.position = pos
    p.size = bounds
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = line
    style.set_border_width_all(2)
    style.set_corner_radius_all(7)
    p.add_theme_stylebox_override("panel", style)
    p.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(p)
    return p

func _build() -> void:
    for child in get_children():
        child.queue_free()
    size = Vector2(256, 380)
    custom_minimum_size = size
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var hue: Color = Color("87c9ef")
    if category == "hero":
        hue = Color(str(entry.get("accent", "#87c9ef")))
    elif category == "ability":
        var owner: String = str(entry.get("hero", ""))
        hue = Color("#61c5e8") if owner == "bryan" else (
            Color("#eda55b") if owner == "carlos" else (
            Color("#7cdb91") if owner == "manny" else Color("#c5a4f0")))
    else:
        hue = Color("#e7aa70") if str(entry.get("theme", "")) == "yard" else Color("#7bd6e9")
    var style := StyleBoxFlat.new()
    style.bg_color = Color("12202d")
    style.border_color = hue.darkened(0.2)
    style.set_border_width_all(4)
    style.set_corner_radius_all(12)
    add_theme_stylebox_override("panel", style)
    _panel(self, Vector2(8, 8), Vector2(240, 42), Color("273645"), hue)
    _text(self, str(entry.get("name", "UNKNOWN")), Vector2(15, 11), Vector2(226, 35),
        18, Color("fff2d9"), true)
    _panel(self, Vector2(12, 55), Vector2(232, 174), Color("1b2b39"), hue.darkened(0.4))
    var art_path: String = str(entry.get("art", ""))
    if ResourceLoader.exists(art_path):
        var portrait: Texture2D = CharacterArt.framed_texture(art_path) if category == "hero" else load(art_path) as Texture2D
        if portrait != null:
            var source: Vector2 = portrait.get_size()
            if source.x > 0.0 and source.y > 0.0:
                var sprite := Sprite2D.new()
                sprite.texture = portrait
                sprite.centered = true
                sprite.position = Vector2(128, 142)
                sprite.scale = Vector2.ONE * minf(216.0 / source.x, 165.0 / source.y)
                self.add_child(sprite)
    var info_line: String = ""
    if category == "hero":
        info_line = str(entry.get("role", "CREW MEMBER")).to_upper()
    elif category == "ability":
        info_line = "%s   /   %d ENERGY" % [str(entry.get("type", "")).to_upper(),
            int(entry.get("cost", 0))]
    else:
        info_line = ("ELITE  " if str(entry.get("enemy_type", "")) == "elite" else "MACHINE  ") + str(entry.get("theme", "FACTORY")).to_upper()
    _text(self, info_line, Vector2(18, 235), Vector2(218, 25), 14, hue, true)
    _panel(self, Vector2(13, 264), Vector2(230, 79), Color("0d1722"), Color("42596b"))
    var paragraph := RichTextLabel.new()
    paragraph.text = str(entry.get("description", ""))
    paragraph.position = Vector2(23, 271)
    paragraph.size = Vector2(212, 66)
    paragraph.scroll_active = false
    paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    paragraph.add_theme_font_size_override("normal_font_size", 12)
    paragraph.add_theme_color_override("default_color", Color("e1e7e8"))
    paragraph.mouse_filter = Control.MOUSE_FILTER_IGNORE
    self.add_child(paragraph)
    var foot: String = ""
    if category == "hero":
        foot = "HP %d   •   %s" % [int(entry.get("hp", 60)), str(entry.get("passive", "PASSIVE"))]
    elif category == "ability":
        foot = str(entry.get("rarity", "common")).to_upper() + "   •   " + str(entry.get("hero", "")).to_upper()
    else:
        foot = "HP %d    •    ATK %d" % [int(entry.get("hp", 0)), int(entry.get("damage", 0))]
    _text(self, foot, Vector2(14, 347), Vector2(228, 25), 13, hue, true)
