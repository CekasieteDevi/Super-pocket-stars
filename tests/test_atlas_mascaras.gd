extends SceneTree

## AtlasJugadores clasifica los píxeles una vez por cuadro y tiñe con esa
## máscara. Tiene que dar EXACTAMENTE la textura que daba el recorrido
## píxel por píxel de antes, que queda copiado acá como referencia.
## Correr con: godot --headless --script tests/test_atlas_mascaras.gd

const SEED := 7070

var fallos := 0


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casos := 0
	var distintos := 0
	# 20 y 25 llevan dorsal; 37 admite pantalón arriba; 40 a 43 no admiten.
	for indice in [0, 9, 20, 25, 30, 37, 40, 44, 58, 70]:
		for i in range(4):
			var camiseta := Color(rng.randf(), rng.randf(), rng.randf())
			var pantalon := Color.TRANSPARENT if i % 2 == 0 else Color(rng.randf(), rng.randf(), rng.randf())
			var pelo := Color(rng.randf(), rng.randf(), rng.randf())
			var estilo := rng.randi_range(0, AtlasJugadores.PEINADOS.size() - 1)
			var espejo := i >= 2
			var numero := rng.randi_range(1, 99)
			var nueva := AtlasJugadores.textura(indice, camiseta, pantalon, pelo, espejo, numero, estilo).get_image()
			var vieja := _referencia(indice, camiseta, pantalon, pelo, espejo, numero, estilo)
			casos += 1
			if nueva.get_data() != vieja.get_data():
				distintos += 1
	if distintos == 0:
		print("OK: %d texturas idénticas a las del recorrido píxel por píxel" % casos)
	else:
		print("FALLA: %d de %d texturas cambiaron" % [distintos, casos])
		fallos += 1
	print("FALLOS=%d" % fallos)
	quit()


## La versión anterior de AtlasJugadores.textura, sin caché.
func _referencia(indice: int, camiseta: Color, pantalon: Color, pelo: Color,
		espejo: bool, numero: int, peinado: int) -> Image:
	const CELDA := AtlasJugadores.CELDA
	var dorsal := numero if (indice >= 16 and indice < 24) or indice == 25 else 0
	var estilo := posmod(peinado, AtlasJugadores.PEINADOS.size())
	var ruta := "res://assets/partido/preparados/%s.png" % AtlasJugadores.PEINADOS[estilo]
	var hoja := (load(ruta) as Texture2D).get_image()
	hoja.decompress()
	hoja.convert(Image.FORMAT_RGBA8)
	var img := hoja.get_region(Rect2i((indice % 8) * CELDA, (indice / 8) * CELDA, CELDA, CELDA))
	for y in range(CELDA):
		for x in range(CELDA):
			var c := img.get_pixel(x, y)
			if c.a < 0.1:
				continue
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
	return img
