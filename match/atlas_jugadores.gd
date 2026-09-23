class_name AtlasJugadores
extends RefCounted

## Cuadros preparados offline: ocho columnas y once filas por peinado.
## No recortar ni limpiar hojas fuente durante la reproducción.
const RUTA := "res://assets/partido/jugadores.png"
const CELDA := 64
const TOTAL_CUADROS := 84
const PEINADOS := ["puntas", "afro", "rapado", "atado", "mohicano", "rastas", "degrade", "vincha", "rodete", "raya", "trenzas",
	"rulos_cortos", "rulos_largos", "melena", "mullet", "flequillo", "jopo",
	"tupe", "hongo", "coleta", "cucurella", "doble_cresta"]
const CLIPS := {
	"pecho": [48, 49, 50, 51, 52, 53, 54, 55],
	"lateral_prepara": [56, 57, 58, 59],
	"lateral_manos": [60, 61, 62, 63],
	"patea": [8, 9, 10, 11, 12, 13, 14, 15],
	# Arma el golpe, lo cancela y recoge el pie para salir conduciendo.
	"amague_centro": [8, 9, 10, 9, 8, 68, 69, 71],
	"barrida": [26, 26, 30, 31],
	# Lesión: caída, apoyo torpe y recuperación. Reutiliza cuadros PNG del
	# atlas ya probado para que el gesto mantenga escala, piel y peinados.
	"lesionado": [28, 29, 30, 31, 31, 30, 29, 25],
	"bloquea": [31, 27, 27, 30],
	"cae": [28, 29, 29, 30, 31],
	"cabecea": [32, 33, 34, 31],
	"volea": [64, 65, 66, 67],
	"control_pie": [68, 69, 70, 71],
	"taco": [72, 73, 74, 75],
	"agarra": [76, 77, 78, 79],
	"saque_arco": [80, 81, 82, 83],
	# Impulso, tijera, contacto, caida y apoyo: poses propias en los 11 PNG.
	"chilena": [36, 37, 37, 38, 29, 30, 39],
	"vuela": [40, 41, 42, 42, 43],
	"festeja": [44, 45, 46, 45],
}
static var _fuentes := {}
static var _cache := {}
static var _bases := {}
static var _tenidas := {}


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
	# El teñido es lo caro y no depende del espejo ni del dorsal: la misma
	# camiseta mirando a cada lado sale de una sola pasada.
	var clave_tenida := "%d_%s_%s_%s_%d" % [indice, camiseta.to_html(), pantalon.to_html(), pelo.to_html(), estilo]
	var tenida: Image = _tenidas.get(clave_tenida)
	if tenida == null:
		var mascara := _mascara(indice, estilo)
		tenida = (mascara["img"] as Image).duplicate()
		_tenir(tenida, mascara["camiseta"], camiseta)
		if pantalon.a > 0.0:
			_tenir(tenida, mascara["pantalon"], pantalon)
		else:
			_tenir(tenida, mascara["pelo_sin_pantalon"], pelo)
		_tenir(tenida, mascara["pelo"], pelo)
		if _tenidas.size() >= 1024:
			_tenidas.erase(_tenidas.keys()[0])
		_tenidas[clave_tenida] = tenida
	var img: Image = tenida.duplicate()
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


## Qué píxeles del cuadro son camiseta, pantalón y pelo, con el factor de
## luz de cada uno. Se clasifica UNA vez por cuadro y peinado: antes se
## recorrían los 4096 píxeles con get_pixel en cada textura, y preparar los
## sprites de un partido tardaba 340 ms en escritorio
## (tests/_diag_rendimiento_partido.gd), varios segundos en el celular.
##
## Cada lista es [índices de píxel, factor de luz, alfa]. `pantalon` y
## `pelo_sin_pantalon` son los mismos candidatos: si el club no eligió
## pantalón, esos píxeles caen a la regla del pelo, como antes.
static func _mascara(indice: int, estilo: int) -> Dictionary:
	var base_clave := "%d_%d" % [indice, estilo]
	if _bases.has(base_clave):
		return _bases[base_clave]
	if not _fuentes.has(estilo):
		var ruta := "res://assets/partido/preparados/%s.png" % PEINADOS[estilo]
		var preparada := (load(ruta) as Texture2D).get_image()
		preparada.decompress()
		preparada.convert(Image.FORMAT_RGBA8)
		_fuentes[estilo] = preparada
	var hoja: Image = _fuentes[estilo]
	# El atlas preparado ya contiene el peinado propio en todas las acciones,
	# incluidas las atajadas y los saques del arquero.
	var img := hoja.get_region(Rect2i((indice % 8) * CELDA,
		(indice / 8) * CELDA, CELDA, CELDA))
	# Van en variables sueltas y no dentro de un Array porque un
	# Packed*Array se COPIA al sacarlo de un contenedor, y el append se
	# perdería. Los factores van en 64 bits: en 32 el redondeo cambiaba un
	# nivel de color en casi todos los píxeles teñidos.
	# Las poses nuevas del arquero traen guantes y pelota blancos: no son
	# pantalón y deben quedar blancos aunque el club use otra tonalidad.
	var admite_pantalon: bool = indice not in [40, 41, 42, 43, 76, 77, 78, 79, 80, 81, 82, 83]
	var pix_camiseta := PackedInt32Array()
	var luz_camiseta := PackedFloat64Array()
	var alfa_camiseta := PackedFloat64Array()
	var pix_pantalon := PackedInt32Array()
	var luz_pantalon := PackedFloat64Array()
	var alfa_pantalon := PackedFloat64Array()
	var pix_pelo := PackedInt32Array()
	var luz_pelo := PackedFloat64Array()
	var alfa_pelo := PackedFloat64Array()
	var pix_pelo_sp := PackedInt32Array()
	var luz_pelo_sp := PackedFloat64Array()
	var alfa_pelo_sp := PackedFloat64Array()
	for y in range(CELDA):
		for x in range(CELDA):
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
			# Máscaras cromáticas: conservar piel, contorno y brillos.
			var pixel := y * CELDA + x
			var es_pelo := c.r > c.g * 1.15 and c.g > c.b * 1.15 and c.v < 0.48
			if c.b > c.r * 1.35 and c.b > c.g * 1.1 and c.b > 0.18:
				pix_camiseta.append(pixel)
				luz_camiseta.append(clampf(c.v / 0.85, 0.25, 1.2))
				alfa_camiseta.append(c.a)
			elif admite_pantalon and c.s < 0.18 and c.v > 0.72 and (y > 29 or indice in [37, 38]):
				pix_pantalon.append(pixel)
				luz_pantalon.append(c.v)
				alfa_pantalon.append(c.a)
				if es_pelo:
					pix_pelo_sp.append(pixel)
					luz_pelo_sp.append(clampf(c.v / 0.3, 0.45, 1.5))
					alfa_pelo_sp.append(c.a)
			elif es_pelo:
				pix_pelo.append(pixel)
				luz_pelo.append(clampf(c.v / 0.3, 0.45, 1.5))
				alfa_pelo.append(c.a)
	var listas := {
		"img": img,
		"camiseta": [pix_camiseta, luz_camiseta, alfa_camiseta],
		"pantalon": [pix_pantalon, luz_pantalon, alfa_pantalon],
		"pelo": [pix_pelo, luz_pelo, alfa_pelo],
		"pelo_sin_pantalon": [pix_pelo_sp, luz_pelo_sp, alfa_pelo_sp],
	}
	_bases[base_clave] = listas
	return listas


static func _es_pelo_pixel(c: Color) -> bool:
	# La piel sombreada también es rojiza. El límite de valor y verde evita
	# copiar brazos o piernas al buscar el pelo del cuadro de referencia.
	return c.a >= 0.7 and c.r > c.g * 1.15 and c.g > c.b * 1.15 \
		and c.v < 0.55 and c.g < 0.45


static func _caja_pelo(img: Image) -> Rect2i:
	var usado := Rect2i()
	var encontrado := false
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if not _es_pelo_pixel(img.get_pixel(x, y)):
				continue
			if not encontrado:
				usado = Rect2i(x, y, 1, 1)
				encontrado = true
			else:
				usado = usado.merge(Rect2i(x, y, 1, 1))
	return usado


## Copia la silueta de pelo del PNG de cada peinado sobre la cabeza del
## arquero. Solo se copian píxeles de pelo: cara, guantes y pelota quedan
## intactos. El contorno original queda debajo y mantiene el estilo del juego.
static func aplicar_peinado_accion(img: Image, estilo: int) -> void:
	if not _fuentes.has(estilo):
		var ruta := "res://assets/partido/preparados/%s.png" % PEINADOS[estilo]
		var preparada := (load(ruta) as Texture2D).get_image()
		preparada.decompress()
		preparada.convert(Image.FORMAT_RGBA8)
		_fuentes[estilo] = preparada
	var destino := _caja_pelo(img)
	if not destino.has_area():
		return
	var hoja: Image = _fuentes[estilo]
	var cabeza := hoja.get_region(Rect2i(0, 0, CELDA, CELDA))
	var origen := _caja_pelo(cabeza)
	if not origen.has_area():
		return
	# Un píxel de margen conserva los pelos laterales de estilos anchos sin
	# cambiar el tamaño del cuerpo ni el pivote de la animación.
	destino = Rect2i(0, 0, CELDA, CELDA).intersection(destino.grow(1))
	var pelo := cabeza.get_region(origen)
	pelo.resize(maxi(1, destino.size.x), maxi(1, destino.size.y), Image.INTERPOLATE_NEAREST)
	for y in range(pelo.get_height()):
		for x in range(pelo.get_width()):
			var c := pelo.get_pixel(x, y)
			if _es_pelo_pixel(c):
				img.set_pixel(destino.position.x + x, destino.position.y + y, c)


static func _tenir(img: Image, lista: Array, color: Color) -> void:
	var pixeles: PackedInt32Array = lista[0]
	var luces: PackedFloat64Array = lista[1]
	var alfas: PackedFloat64Array = lista[2]
	for i in range(pixeles.size()):
		var tinte := color * luces[i]
		tinte.a = alfas[i]
		img.set_pixel(pixeles[i] % CELDA, pixeles[i] / CELDA, tinte)


static func estilo_de(jugador_id: int) -> int:
	return posmod(jugador_id, PEINADOS.size())
