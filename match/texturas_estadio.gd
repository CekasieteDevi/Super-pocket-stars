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
	var lado := 32
	var img := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	# Paleta de cuatro tonos y grupos de briznas: p?xel ilustrado, sin ruido.
	img.fill(base)
	var sombra := base.darkened(aspereza * 2.8)
	var luz := base.lightened(aspereza * 1.8)
	for i in range(72):
		var x := rng.randi_range(0, lado - 1)
		var y := rng.randi_range(0, lado - 1)
		var c := sombra if i % 3 == 0 else luz
		img.set_pixel(x, y, c)
		img.set_pixel((x + 1) % lado, y, c)
		if i % 2 == 0:
			img.set_pixel((x + 1) % lado, (y + lado - 1) % lado, c)
	var tex := ImageTexture.create_from_image(img)
	_cache[clave] = tex
	return tex


## Público: filas de hinchas. Cada uno ocupa una celda de 6x6 y queda
## adentro de ella, que es lo que hace que el tile pegue con el de al
## lado sin costura visible. La celda tiene que dar unos 6-10 píxeles en
## pantalla al zoom de juego: más chico se lee como estática de TV, no
## como gente (ver METROS_TILE_PUBLICO en vista_cancha.gd).
const CELDA := 10
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
		img.fill_rect(Rect2i(0, fila * CELDA + 8, ancho, 2), Color("42444a"))
		# Las filas impares van corridas media celda: sin eso quedan
		# columnas perfectas y se ve una grilla, no una tribuna.
		var corrimiento: int = CELDA / 2 if fila % 2 == 1 else 0
		for col in range(COLUMNAS):
			var asiento_x := (col * CELDA + corrimiento) % ancho
			img.fill_rect(Rect2i(asiento_x + 2, fila * CELDA + 5, mini(6, ancho - asiento_x - 2), 3), Color("343e51"))
			# Algún hueco: no hay estadio lleno hasta el último asiento.
			if rng.randf() < 0.10:
				continue
			var x0: int = (col * CELDA + corrimiento) % ancho
			var y0: int = fila * CELDA
			var cuerpo: Color = TONOS_HINCHA[rng.randi() % TONOS_HINCHA.size()]
			var piel: Color = PIEL_HINCHA[rng.randi() % PIEL_HINCHA.size()]
			var pelo := Color("30231d") if rng.randf() < 0.7 else Color("957448")
			var pose := rng.randi_range(0, 3)
			# Siluetas: sentado, brazos arriba, bufanda y camiseta rayada.
			for dy in range(4):
				for dx in range(5):
					img.set_pixel((x0 + 2 + dx) % ancho, y0 + 4 + dy, cuerpo if dx < 3 else cuerpo.darkened(0.22))
			for dy in range(3):
				for dx in range(3):
					img.set_pixel((x0 + 3 + dx) % ancho, y0 + 1 + dy, pelo if dy == 0 else piel)
			for lado in [1, 7]:
				for dy in range(3):
					img.set_pixel((x0 + lado) % ancho, y0 + (2 if pose in [1, 2] else 5) + dy, piel)
			if pose == 2:
				for dx in range(7):
					img.set_pixel((x0 + 1 + dx) % ancho, y0 + 1, cuerpo.lightened(0.25) if dx % 2 == 0 else Color("b8b7ac"))
			elif pose == 3:
				for dy in range(3):
					img.set_pixel((x0 + 4) % ancho, y0 + 5 + dy, cuerpo.lightened(0.3))
			img.set_pixel((x0 + 3) % ancho, y0 + 8, Color("1b202b"))
			img.set_pixel((x0 + 6) % ancho, y0 + 8, Color("1b202b"))
	var tex := ImageTexture.create_from_image(img)
	_cache["publico"] = tex
	return tex


## Público de potrero: gente parada contra el alambrado, sin asientos ni
## filas de butacas. Se usa en los primeros niveles de infraestructura.
static func publico_parado() -> ImageTexture:
	if _cache.has("publico_parado"):
		return _cache["publico_parado"]
	var ancho := 80
	var alto := 32
	var img := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	img.fill(Color("171b23"))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA + 17
	for fila in range(2):
		var y0 := fila * 15
		for col in range(10):
			var x0 := col * 8 + (4 if fila == 1 else 0)
			if rng.randf() < 0.14:
				continue
			var camiseta: Color = TONOS_HINCHA[rng.randi() % TONOS_HINCHA.size()]
			var piel: Color = PIEL_HINCHA[rng.randi() % PIEL_HINCHA.size()]
			var pelo := Color("30231d") if rng.randf() < 0.72 else Color("957448")
			# Cabeza y torso, más altos que el hincha sentado.
			for dy in range(3):
				for dx in range(3):
					img.set_pixel((x0 + 2 + dx) % ancho, y0 + 1 + dy, pelo if dy == 0 else piel)
			for dy in range(7):
				for dx in range(4):
					img.set_pixel((x0 + 1 + dx) % ancho, y0 + 4 + dy,
						camiseta if dx < 3 else camiseta.darkened(0.18))
			if rng.randf() < 0.45:
				# Brazos levantados: gesto simple, legible a distancia.
				for dy in range(4):
					img.set_pixel((x0 + 0) % ancho, y0 + 3 + dy, piel)
					img.set_pixel((x0 + 5) % ancho, y0 + 3 + dy, piel)
			img.set_pixel((x0 + 2) % ancho, y0 + 11, Color("10141c"))
			img.set_pixel((x0 + 4) % ancho, y0 + 11, Color("10141c"))
	var tex := ImageTexture.create_from_image(img)
	_cache["publico_parado"] = tex
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
