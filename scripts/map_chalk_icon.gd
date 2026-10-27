extends Control
## Reusable vector-drawn blueprint icons. No bitmap text or background artwork.
## Crossed SWORDS for normal fights; distressed white chalk for unexplored nodes.

var kind: String = "combat"
var active: bool = false
var visited: bool = false

const CHALK := Color("e8e7df")
const MUTED := Color("9ca9b6")
const MARKER := Color("f6d75c")
const RADIUS := 25.0

func _ink() -> Color:
    return MARKER if visited else (CHALK if active else MUTED)

func _stroke(from: Vector2, to: Vector2, ink: Color, width: float = 2.3) -> void:
    draw_line(from, to, ink, width, true)
    # Fine, offset secondary mark: looks like a dry chalk stroke, not neon.
    var ghost: Color = ink
    ghost.a *= 0.21
    draw_line(from + Vector2(0.8, 0.4), to + Vector2(0.8, 0.4), ghost, 1.0, true)

func _draw() -> void:
    var ink: Color = _ink()
    var c := Vector2(32, 32)
    draw_arc(c, RADIUS, 0.0, TAU, 72, ink, 2.3, true)
    var ghost: Color = ink
    ghost.a *= 0.23
    draw_arc(c + Vector2(0.8, -0.6), RADIUS + 1.2, 0.1, TAU - 0.2, 70, ghost, 0.9, true)
    if active and not visited:
        var edge: Color = MARKER
        edge.a = 0.53
        draw_arc(c, RADIUS + 3.0, 0.05, TAU - 0.05, 72, edge, 1.4, true)
    match kind:
        "combat": _swords(ink)
        "elite": _skull(ink)
        "event": _glyph("?", ink, 35)
        "shop": _glyph("$", ink, 31)
        "rest": _cross(ink)
        "boss": _crown(ink)

func _swords(ink: Color) -> void:
    # Two crossed swords: narrow blades, guards and handles.
    for reverse in [false, true]:
        var start := Vector2(18, 17) if not reverse else Vector2(46, 17)
        var tip := Vector2(46, 47) if not reverse else Vector2(18, 47)
        var sign: float = 1.0 if not reverse else -1.0
        _stroke(start, tip, ink, 2.5)
        var pommel: Vector2 = tip + Vector2(sign * 4.3, 4.0)
        _stroke(tip, pommel, ink, 2.7)
        var grip: Vector2 = tip - (tip - start).normalized() * 8.0
        _stroke(grip + Vector2(-5.0, 3.5), grip + Vector2(5.0, -3.5), ink, 2.0)
        _stroke(start, start + Vector2(sign * 1.5, 8.0), ink, 1.1)

func _skull(ink: Color) -> void:
    draw_arc(Vector2(32, 28), 11.0, PI * 0.88, PI * 2.12, 29, ink, 2.4, true)
    _stroke(Vector2(23, 30), Vector2(24, 42), ink, 2.1)
    _stroke(Vector2(41, 30), Vector2(40, 42), ink, 2.1)
    _stroke(Vector2(24, 42), Vector2(40, 42), ink, 2.1)
    draw_circle(Vector2(27.5, 31), 3.0, ink)
    draw_circle(Vector2(36.5, 31), 3.0, ink)
    _stroke(Vector2(30, 39), Vector2(34, 39), ink, 1.3)
    for x in [28.0,32.0,36.0]:
        _stroke(Vector2(x, 42), Vector2(x, 45), ink, 1.0)

func _glyph(letter: String, ink: Color, font_size: int) -> void:
    var font: Font = ThemeDB.fallback_font
    draw_string(font, Vector2(32, 43), letter,
        HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, ink)

func _cross(ink: Color) -> void:
    _stroke(Vector2(32, 19), Vector2(32, 45), ink, 6.0)
    _stroke(Vector2(19, 32), Vector2(45, 32), ink, 6.0)

func _crown(ink: Color) -> void:
    var shape := PackedVector2Array([
        Vector2(18, 26), Vector2(23, 43), Vector2(41, 43), Vector2(46, 26),
        Vector2(38, 33), Vector2(32, 22), Vector2(26, 33), Vector2(18, 26)])
    draw_polyline(shape, ink, 2.4, true)
    for point in [Vector2(18, 25), Vector2(32, 21), Vector2(46, 25)]:
        draw_circle(point, 2.4, ink)
    _stroke(Vector2(22, 46), Vector2(42, 46), ink, 2.2)
