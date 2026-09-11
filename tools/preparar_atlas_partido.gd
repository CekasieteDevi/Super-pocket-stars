extends SceneTree

## Preparacion offline. Ejecutar al cambiar las hojas fuente.
const RUTA := "res://assets/partido/jugadores.png"
const CELDA := 64
const TOTAL_CUADROS := 64
const PEINADOS := ["puntas", "afro", "rapado", "atado"]
const RUTAS := [RUTA, "res://assets/partido/jugadores_afro.png", "res://assets/partido/jugadores_rapado.png", "res://assets/partido/jugadores_atado.png"]
const RUTAS_ACCIONES := ["res://assets/partido/recepcion_lateral.png", "res://assets/partido/recepcion_lateral_afro.png", "res://assets/partido/recepcion_lateral_rapado.png", "res://assets/partido/recepcion_lateral_atado.png"]
# Límites medidos en la hoja entregada; los vuelos son más anchos.
const FILAS := [0, 197, 386, 565, 734, 914, 1086]
const COLUMNAS_ARQUERO := [0, 178, 374, 582, 755, 916, 1098, 1275, 1448]

static var _fuentes := {}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/partido/preparados")
	for estilo in range(PEINADOS.size()):
		var hoja := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		hoja.fill(Color.TRANSPARENT)
		for indice in range(TOTAL_CUADROS):
			var img := _generar_base(indice, estilo)
			hoja.blit_rect(img, Rect2i(0, 0, CELDA, CELDA), Vector2i((indice % 8) * CELDA, (indice / 8) * CELDA))
		var error := hoja.save_png("res://assets/partido/preparados/%s.png" % PEINADOS[estilo])
		if error != OK:
			push_error("No se pudo guardar el atlas: %s" % PEINADOS[estilo])
			quit(1)
			return
	print("OK: cuatro atlas preparados, 256 cuadros")
	quit()

static func _generar_base(indice: int, estilo: int) -> Image:
	var ruta: String = RUTAS_ACCIONES[estilo] if indice >= 48 else RUTAS[estilo]
	if not _fuentes.has(ruta):
		var cargada := (load(ruta) as Texture2D).get_image()
		cargada.decompress()
		cargada.convert(Image.FORMAT_RGBA8)
		_fuentes[ruta] = cargada
	var fuente: Image = _fuentes[ruta]
	var columna := indice % 8
	var recorte: Image
	var factor: float
	if indice >= 48:
		var fila: int = (indice - 48) / 8
		var ancho: int = fuente.get_width() / 8
		var corte := roundi(fuente.get_height() * 0.545)
		var y0 := 0 if fila == 0 else corte
		var alto := corte if fila == 0 else fuente.get_height() - corte
		recorte = fuente.get_region(Rect2i(columna * ancho, y0, ancho, alto))
		factor = 0.16 * 2048.0 / fuente.get_width()
	else:
		var fila: int = indice / 8
		var sx := fuente.get_width() / 1448.0
		var sy := fuente.get_height() / 1086.0
		var x0: int = COLUMNAS_ARQUERO[columna] if fila == 5 else columna * 181
		var x1: int = COLUMNAS_ARQUERO[columna + 1] if fila == 5 else (columna + 1) * 181
		recorte = fuente.get_region(Rect2i(roundi(x0 * sx), roundi(FILAS[fila] * sy), roundi((x1 - x0) * sx), roundi((FILAS[fila + 1] - FILAS[fila]) * sy)))
		factor = 0.28 / sx
	_quitar_fondo_exterior(recorte)
	# Descartar halos semitransparentes antes de calcular el pivote.
	for y in range(recorte.get_height()):
		for x in range(recorte.get_width()):
			var c := recorte.get_pixel(x, y)
			c.a = 1.0 if c.a >= 0.7 else 0.0
			recorte.set_pixel(x, y, c)
	_aislar_personaje(recorte)
	var limites := recorte.get_used_rect()
	recorte = recorte.get_region(limites)
	recorte.resize(maxi(1, roundi(limites.size.x * factor)), maxi(1, roundi(limites.size.y * factor)), Image.INTERPOLATE_NEAREST)
	var img := Image.create(CELDA, CELDA, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	img.blit_rect(recorte, Rect2i(Vector2i.ZERO, recorte.get_size()), Vector2i((CELDA - recorte.get_width()) / 2, 58 - recorte.get_height()))
	return img


static func _quitar_fondo_exterior(img: Image) -> void:
	var ancho := img.get_width()
	var alto := img.get_height()
	# El croma magenta tambi?n se elimina de huecos cerrados entre brazos.
	for y in range(alto):
		for x in range(ancho):
			var c := img.get_pixel(x, y)
			if c.r > 0.5 and c.b > 0.5 and c.g < 0.35:
				img.set_pixel(x, y, Color.TRANSPARENT)
	var vistos := PackedByteArray()
	vistos.resize(ancho * alto)
	var cola := PackedInt32Array()
	for x in range(ancho):
		cola.append(x)
		cola.append((alto - 1) * ancho + x)
	for y in range(1, alto - 1):
		cola.append(y * ancho)
		cola.append(y * ancho + ancho - 1)
	var cursor := 0
	while cursor < cola.size():
		var id := cola[cursor]
		cursor += 1
		if vistos[id]:
			continue
		vistos[id] = 1
		var x := id % ancho
		var y: int = id / ancho
		var c := img.get_pixel(x, y)
		var fondo := c.a < 0.1 or (c.s < 0.18 and c.v > 0.4) or (c.r > 0.8 and c.b > 0.8 and c.g < 0.2)
		if not fondo:
			continue
		img.set_pixel(x, y, Color.TRANSPARENT)
		if x > 0: cola.append(id - 1)
		if x + 1 < ancho: cola.append(id + 1)
		if y > 0: cola.append(id - ancho)
		if y + 1 < alto: cola.append(id + ancho)


static func _aislar_personaje(img: Image) -> void:
	var ancho := img.get_width()
	var alto := img.get_height()
	var vistos := PackedByteArray()
	vistos.resize(ancho * alto)
	var mayor := PackedInt32Array()
	for inicio in range(ancho * alto):
		if vistos[inicio] or img.get_pixel(inicio % ancho, inicio / ancho).a == 0.0:
			continue
		var grupo := PackedInt32Array([inicio])
		vistos[inicio] = 1
		var cursor := 0
		while cursor < grupo.size():
			var id := grupo[cursor]
			cursor += 1
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var x := id % ancho + dx
					var y: int = id / ancho + dy
					if x < 0 or y < 0 or x >= ancho or y >= alto:
						continue
					var vecino := y * ancho + x
					if vistos[vecino] or img.get_pixel(x, y).a == 0.0:
						continue
					vistos[vecino] = 1
					grupo.append(vecino)
		if grupo.size() > mayor.size():
			mayor = grupo
	var limpio := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	limpio.fill(Color.TRANSPARENT)
	for id in mayor:
		limpio.set_pixel(id % ancho, id / ancho, img.get_pixel(id % ancho, id / ancho))
	img.copy_from(limpio)
