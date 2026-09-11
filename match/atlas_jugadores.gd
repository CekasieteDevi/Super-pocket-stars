class_name AtlasJugadores
extends RefCounted

## Cuadros preparados offline: ocho columnas y ocho filas por peinado.
## No recortar ni limpiar hojas fuente durante la reproducción.
const RUTA := "res://assets/partido/jugadores.png"
const CELDA := 64
const TOTAL_CUADROS := 64
const PEINADOS := ["puntas", "afro", "rapado", "atado"]
const CLIPS := {
	"pecho": [48, 49, 50, 51, 52, 53, 54, 55],
	"lateral_prepara": [56, 57, 58, 59],
	"lateral_manos": [60, 61, 62, 63],
	"patea": [8, 9, 10, 11, 12, 13, 14, 15],
	"barrida": [26, 26, 30, 31],
	"bloquea": [31, 27, 27, 30],
	"cae": [28, 29, 29, 30, 31],
	"cabecea": [32, 33, 34, 31],
	"volea": [32, 35, 35, 31],
	"chilena": [36, 37, 37, 38, 39],
	"vuela": [40, 41, 42, 42, 43],
	"festeja": [44, 45, 46, 45],
}
static var _fuentes := {}
static var _cache := {}
static var _bases := {}


static func cuadro(accion: String, fase: float, direccion: int, corriendo: bool,
		arquero: bool = false) -> int:
	if CLIPS.has(accion):
		var clip: Array = CLIPS[accion]
		return int(clip[mini(int(clampf(fase, 0.0, 1.0) * clip.size()), clip.size() - 1)])
	if corriendo:
		return (16 if direccion in [3, 4, 5] else 0) + posmod(int(fase), 8)
	if arquero:
		return 40
	return 25 if direccion in [3, 4, 5] else 24


static func textura(indice: int, camiseta: Color, pantalon: Color, pelo: Color,
		espejo: bool = false, numero: int = 0, peinado: int = 0) -> ImageTexture:
	var dorsal := numero if (indice >= 16 and indice < 24) or indice == 25 else 0
	var estilo := posmod(peinado, PEINADOS.size())
	var clave := "%d_%s_%s_%s_%s_%d_%d" % [indice, camiseta.to_html(), pantalon.to_html(), pelo.to_html(), espejo, dorsal, estilo]
	if _cache.has(clave):
		var existente: ImageTexture = _cache[clave]
		_cache.erase(clave)
		_cache[clave] = existente
		return existente
	var base_clave := "%d_%d" % [indice, estilo]
	var img: Image
	if _bases.has(base_clave):
		img = _bases[base_clave].duplicate()
	else:
		var ruta := "res://assets/partido/preparados/%s.png" % PEINADOS[estilo]
		if not _fuentes.has(estilo):
			var preparada := (load(ruta) as Texture2D).get_image()
			preparada.decompress()
			preparada.convert(Image.FORMAT_RGBA8)
			_fuentes[estilo] = preparada
		var hoja: Image = _fuentes[estilo]
		img = hoja.get_region(Rect2i((indice % 8) * CELDA, (indice / 8) * CELDA, CELDA, CELDA))
		_bases[base_clave] = img.duplicate()
	for y in range(CELDA):
		for x in range(CELDA):
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			# Máscaras cromáticas: conservar piel, contorno y brillos.
			if c.b > c.r * 1.35 and c.b > c.g * 1.1 and c.b > 0.18:
				var luz := clampf(c.v / 0.85, 0.25, 1.2)
				var tinte := camiseta * luz
				tinte.a = c.a
				img.set_pixel(x, y, tinte)
			elif pantalon.a > 0.0 and c.s < 0.18 and c.v > 0.72 and (y > 29 or indice in [37, 38]) and indice not in [40, 41, 42, 43]:
				var tinte := pantalon * c.v
				tinte.a = c.a
				img.set_pixel(x, y, tinte)
			elif c.r > c.g * 1.15 and c.g > c.b * 1.15 and c.v < 0.48:
				var tinte := pelo * clampf(c.v / 0.3, 0.45, 1.5)
				tinte.a = c.a
				img.set_pixel(x, y, tinte)
	if espejo:
		img.flip_x()
	# Estampar después del espejo mantiene legibles los dorsales.
	if dorsal > 0:
		var texto := str(clampi(dorsal, 1, 99))
		var dorsal_x := 32 - (texto.length() * 4 - 1) / 2
		var tinta := Color.WHITE if camiseta.get_luminance() < 0.55 else Color("18212c")
		for i in range(texto.length()):
			var digito: Array = SpritesPartido.DIGITOS[int(texto[i])]
			for y in range(5):
				for x in range(3):
					if digito[y][x] == "#":
						img.set_pixel(dorsal_x + i * 4 + x, 33 + y, tinta)
	var tex := ImageTexture.create_from_image(img)
	# Caché acotada para sesiones con muchos equipos.
	if _cache.size() >= 4096:
		_cache.erase(_cache.keys()[0])
	_cache[clave] = tex
	return tex


static func estilo_de(jugador_id: int) -> int:
	return posmod(jugador_id, PEINADOS.size())
