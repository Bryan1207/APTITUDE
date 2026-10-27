class_name AptitudeCharacterArt
extends RefCounted

## Preserve the original approved transparent PNGs while giving every character
## an identical *safe canvas* for selection, biography and battlefield previews.
## Artwork isn't cropped, stretched, or regenerated. Frames are cached.
const SAFE_MARGIN := 0.0625
static var framed: Dictionary = {}
static var margins: Dictionary = {}

static func framed_texture(path: String) -> Texture2D:
    if framed.has(path):
        return framed[path] as Texture2D
    if not ResourceLoader.exists(path):
        return null
    var original: Texture2D = load(path) as Texture2D
    if original == null:
        return null
    var image: Image = original.get_image()
    if image == null or image.is_empty():
        return original
    if image.is_compressed():
        var error: Error = image.decompress()
        if error != OK:
            return original
    if image.get_format() != Image.FORMAT_RGBA8:
        image.convert(Image.FORMAT_RGBA8)
    var longest: int = maxi(image.get_width(), image.get_height())
    var margin: int = maxi(12, roundi(float(longest) * SAFE_MARGIN))
    var canvas: Image = Image.create_empty(image.get_width() + margin * 2,
        image.get_height() + margin * 2, false, Image.FORMAT_RGBA8)
    canvas.fill(Color(0, 0, 0, 0))
    canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()),
        Vector2i(margin, margin))
    var result: Texture2D = ImageTexture.create_from_image(canvas)
    framed[path] = result
    margins[path] = margin
    return result

static func margin_for(path: String) -> float:
    if not margins.has(path):
        framed_texture(path)
    return float(margins.get(path, 0))
