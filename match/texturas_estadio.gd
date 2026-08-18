class_name TexturasEstadio
extends RefCounted

## Texturas del decorado, generadas por código y cacheadas: césped,
## público y red del arco. Son TILEABLES y se dibujan con
## draw_colored_polygon + UV, así que la proyección las inclina sola y no
## hay que proyectar píxel por píxel.
##
## Igual que sprites_partido.gd, este es el único archivo a reemplazar si
## más adelante entran PNG de verdad.
##
## Todas son deterministas: usan una semilla fija, no el RNG del partido.
## Un público que cambiara de cara entre fotogramas titilaría, y el
## césped se vería como estática de TV.

const SEMILLA := 424242

static var _cache: Dictionary = {}


## Césped: variación sutil sobre el color base, con briznas verticales
## apenas insinuadas. La variación tiene que ser CHICA — a 22 px/metro un
## tile de 16 px mide menos de un metro, así que cualquier contraste se
## lee como ruido y no como pasto.
static func cesped(base: Color, aspereza: float) -> ImageTexture:
	var clave := "c_%s_%.2f" % [base.to_html(false), aspereza]
	if _cache.has(clave):
		return _cache[clave]
	var lado := 16
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	# Las briznas son CORTAS, de tres píxeles. Un tono compartido por la
	# columna entera parece razonable en el tile, pero al repetirlo cada
	# tres metros las columnas se empalman entre tiles y la cancha termina
	# rayada de punta a punta.
	var largo_brizna := 3
	for x in range(lado):
		var brizna: float = 0.0
		for y in range(lado):
			if y % largo_brizna == 0:
				brizna = rng.randf_range(-1.0, 1.0) * aspereza
			var d: float = brizna + rng.randf_range(-0.4, 0.4) * aspereza
			img.set_pixel(x, y, Color(
				clampf(base.r + d, 0.0, 1.0),
				clampf(base.g + d * 1.2, 0.0, 1.0),
				clampf(base.b + d * 0.6, 0.0, 1.0)))
	var tex := ImageTexture.create_from_image(img)
	_cache[clave] = tex
	return tex


## Público: filas de hinchas. Cada uno ocupa una celda de 6x6 y queda
## adentro de ella, que es lo que hace que el tile pegue con el de al
## lado sin costura visible. La celda tiene que dar unos 6-10 píxeles en
## pantalla al zoom de juego: más chico se lee como estática de TV, no
## como gente (ver METROS_TILE_PUBLICO en vista_cancha.gd).
const CELDA := 6
const FILAS := 8
const COLUMNAS := 8

## La camiseta del hincha sale de una paleta chica y APAGADA. Con colores
## libres y saturados la tribuna se ve como confeti; una multitud a la
## sombra de una tribuna es un mar de tonos oscuros con pocos puntos
## claros sueltos.
const TONOS_HINCHA := [
	Color(0.42, 0.17, 0.17), Color(0.16, 0.22, 0.40), Color(0.55, 0.53, 0.50),
	Color(0.20, 0.21, 0.24), Color(0.40, 0.35, 0.18), Color(0.19, 0.32, 0.22),
	Color(0.28, 0.19, 0.32), Color(0.24, 0.25, 0.28),
]
const PIEL_HINCHA := [
	Color(0.66, 0.53, 0.42), Color(0.50, 0.37, 0.27), Color(0.34, 0.24, 0.17),
]
const FONDO_TRIBUNA := Color(0.11, 0.12, 0.15)


static func publico() -> ImageTexture:
	if _cache.has("publico"):
		return _cache["publico"]
	var ancho := COLUMNAS * CELDA
	var img := Image.create(ancho, FILAS * CELDA, false, Image.FORMAT_RGBA8)
	img.fill(FONDO_TRIBUNA)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	for fila in range(FILAS):
		# Las filas impares van corridas media celda: sin eso quedan
		# columnas perfectas y se ve una grilla, no una tribuna.
		var corrimiento: int = CELDA / 2 if fila % 2 == 1 else 0
		for col in range(COLUMNAS):
			# Algún hueco: no hay estadio lleno hasta el último asiento.
			if rng.randf() < 0.10:
				continue
			var x0: int = (col * CELDA + corrimiento) % ancho
			var y0: int = fila * CELDA
			var cuerpo: Color = TONOS_HINCHA[rng.randi() % TONOS_HINCHA.size()]
			var piel: Color = PIEL_HINCHA[rng.randi() % PIEL_HINCHA.size()]
			# Cuerpo de 4x3 con la cabeza de 2x2 encima, todo dentro de la
			# celda para que el tile siga siendo tileable.
			for dx in range(4):
				for dy in range(3):
					img.set_pixel((x0 + 1 + dx) % ancho, y0 + 3 + dy, cuerpo)
			for dx in range(2):
				for dy in range(2):
					img.set_pixel((x0 + 2 + dx) % ancho, y0 + 1 + dy, piel)
	var tex := ImageTexture.create_from_image(img)
	_cache["publico"] = tex
	return tex


## Red: rombos blancos translúcidos sobre transparente. Va sobre un panel
## proyectado, así que la trama se inclina con el arco.
static func red() -> ImageTexture:
	if _cache.has("red"):
		return _cache["red"]
	var lado := 8
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hilo := Color(1, 1, 1, 0.42)
	for i in range(lado):
		img.set_pixel(i, i, hilo)
		img.set_pixel(i, (lado - 1 - i), hilo)
	var tex := ImageTexture.create_from_image(img)
	_cache["red"] = tex
	return tex
