class_name SpritesPartido
extends RefCounted

## Sprites del partido, generados por código (no hay asset pack). Viven
## acá y no en ui/pixel_art.gd para que la vista nueva sea independiente
## de la actual: si más adelante entran PNG de verdad, este es el único
## archivo a reemplazar.
##
## Los jugadores son billboards: se proyecta su posición al piso, pero el
## sprite se dibuja siempre vertical y sin deformar.

const TRANSPARENTE := Color(0, 0, 0, 0)
const PIEL := Color(0.95, 0.78, 0.62)
const PIEL_OSCURA := Color(0.80, 0.63, 0.48)
const PELO := Color(0.22, 0.14, 0.08)
const SHORT := Color(0.13, 0.13, 0.16)
const MEDIAS := Color(0.90, 0.90, 0.92)
const BOTIN := Color(0.06, 0.06, 0.06)

## 12x20 — chibi de espaldas. Más grande que el sprite viejo (8x14) para
## que a este zoom se distinga la camiseta y la postura.
const JUGADOR := [
	"....HHHH....",
	"...HHHHHH...",
	"..HSSSSSSH..",
	"..HSSSSSSH..",
	"...SSSSSS...",
	"....dSSd....",
	"..bJJJJJJb..",
	".bJJJJJJJJb.",
	".bJJJJJJJJb.",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"..JJJJJJJJ..",
	"...DDDDDD...",
	"...DDDDDD...",
	"...DD..DD...",
	"...MM..MM...",
	"...MM..MM...",
	"..BBB..BBB..",
	"..BBB..BBB..",
	"............",
]

## 8x8 — pelota.
const PELOTA := [
	"..WWWW..",
	".WWWWWW.",
	"WWWKKWWW",
	"WWKKKKWW",
	"WWKKKKWW",
	"WWWKKWWW",
	".WWWWWW.",
	"..WWWW..",
]

static var _cache: Dictionary = {}


## Sprite de jugador con la camiseta del club. Se cachea por color: en
## cancha hay dos equipos, o sea dos texturas, no 22.
static func jugador(color_camiseta: Color) -> ImageTexture:
	var clave := "j_%s" % color_camiseta.to_html(false)
	if _cache.has(clave):
		return _cache[clave]
	var borde := color_camiseta.darkened(0.35)
	var tex := _construir(JUGADOR, {
		".": TRANSPARENTE, "H": PELO, "S": PIEL, "d": PIEL_OSCURA,
		"J": color_camiseta, "b": borde, "D": SHORT, "M": MEDIAS, "B": BOTIN,
	})
	_cache[clave] = tex
	return tex


static func pelota() -> ImageTexture:
	if _cache.has("pelota"):
		return _cache["pelota"]
	var tex := _construir(PELOTA, {
		".": TRANSPARENTE, "W": Color(0.97, 0.97, 0.97), "K": Color(0.10, 0.10, 0.10),
	})
	_cache["pelota"] = tex
	return tex


## Sombra elíptica con bordes suaves. Es lo que ancla al jugador al piso
## y, en la pelota, lo que comunica que está en el aire.
static func sombra() -> ImageTexture:
	if _cache.has("sombra"):
		return _cache["sombra"]
	var ancho := 32
	var alto := 16
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	var cx := (ancho - 1) / 2.0
	var cy := (alto - 1) / 2.0
	for py in range(alto):
		for px in range(ancho):
			var dx := (px - cx) / cx
			var dy := (py - cy) / cy
			var d: float = sqrt(dx * dx + dy * dy)
			var a: float = clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(px, py, Color(0, 0, 0, a * a * 0.62))
	var tex := ImageTexture.create_from_image(img)
	_cache["sombra"] = tex
	return tex


static func _construir(filas: Array, paleta: Dictionary) -> ImageTexture:
	var alto := filas.size()
	var ancho: int = filas[0].length()
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	for y in range(alto):
		var fila: String = filas[y]
		for x in range(ancho):
			img.set_pixel(x, y, paleta[fila[x]])
	return ImageTexture.create_from_image(img)
