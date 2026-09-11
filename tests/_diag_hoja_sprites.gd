extends SceneTree

## Hoja de contactos: dibuja todos los sprites de jugador en un PNG grande
## para poder mirarlos. No es un test, es una herramienta de inspección
## visual — por eso lleva el prefijo _diag_ y queda fuera de la regresión.
##
## Se corre con:
##   <godot> --path . --headless --script tests/_diag_hoja_sprites.gd

const ESCALA := 8
const MARGEN := 8
const FONDO := Color(0.18, 0.42, 0.20)  # verde cancha, para ver el recorte
const RUTA := "E:/IntelliJ/Super Pocket Stars/hoja_sprites.png"

const CAMISETA := Color(0.85, 0.15, 0.18)
const SHORT := Color(0.10, 0.10, 0.55)


func _init() -> void:
	var filas: Array = []

	# 1. Poses de a pie, en las 8 direcciones.
	for pose in [SpritesPartido.QUIETO, SpritesPartido.CORRE_A, SpritesPartido.CORRE_B,
			SpritesPartido.PATEA_ARMA, SpritesPartido.PATEA, SpritesPartido.CABECEA,
			SpritesPartido.BLOQUEA, SpritesPartido.CAE, SpritesPartido.CHILENA,
			SpritesPartido.VOLEA, SpritesPartido.RECUPERA]:
		var fila: Array = []
		for dir in range(8):
			fila.append(SpritesPartido.jugador(CAMISETA, dir, pose, SHORT))
		filas.append(fila)

	# 2. Sprites enteros: barrida a los dos lados, festejo, arquero.
	filas.append([
		SpritesPartido.jugador(CAMISETA, SpritesPartido.DERECHA, SpritesPartido.BARRIDA, SHORT),
		SpritesPartido.jugador(CAMISETA, SpritesPartido.IZQUIERDA, SpritesPartido.BARRIDA, SHORT),
		SpritesPartido.jugador(CAMISETA, SpritesPartido.ABAJO, SpritesPartido.FESTEJA, SHORT),
		SpritesPartido.arquero_volando(CAMISETA, false, SHORT),
		SpritesPartido.arquero_volando(CAMISETA, true, SHORT),
		SpritesPartido.pelota(),
	])

	# 3. Los seis peinados, de frente, de perfil y de espaldas.
	for dir in [SpritesPartido.ABAJO, SpritesPartido.DERECHA, SpritesPartido.ARRIBA]:
		var fila: Array = []
		for estilo in range(SpritesPartido.ESTILOS_PELO):
			fila.append(SpritesPartido.jugador(CAMISETA, dir, SpritesPartido.QUIETO, SHORT,
				estilo, SpritesPartido.TONOS_PELO[estilo % SpritesPartido.TONOS_PELO.size()]))
		filas.append(fila)

	# 4. Números de camiseta, de espaldas: un dígito y dos.
	var numeros: Array = []
	for n in [1, 7, 9, 10, 11, 23, 88, 90]:
		numeros.append(SpritesPartido.jugador(CAMISETA, SpritesPartido.ARRIBA,
			SpritesPartido.QUIETO, SHORT, SpritesPartido.PELO_CORTO, SpritesPartido.PELO, n))
	filas.append(numeros)

	# 5. El mismo número sobre camiseta clara: el dígito tiene que
	#    invertirse a negro o desaparece.
	var claros: Array = []
	for n in [4, 8, 16, 32]:
		claros.append(SpritesPartido.jugador(Color(0.95, 0.93, 0.20), SpritesPartido.ARRIBA_DER,
			SpritesPartido.QUIETO, Color(0.9, 0.9, 0.9), SpritesPartido.PELO_CALVO,
			SpritesPartido.TONOS_PELO[0], n))
	filas.append(claros)

	_guardar(filas, RUTA)
	print("OK: hoja escrita en %s" % RUTA)
	quit()


func _guardar(filas: Array, ruta: String) -> void:
	var an_celda := 0
	var al_celda := 0
	var columnas := 0
	for fila in filas:
		columnas = maxi(columnas, fila.size())
		for tex in fila:
			an_celda = maxi(an_celda, tex.get_width())
			al_celda = maxi(al_celda, tex.get_height())
	an_celda = an_celda * ESCALA + MARGEN
	al_celda = al_celda * ESCALA + MARGEN
	var img := Image.create(columnas * an_celda, filas.size() * al_celda, false, Image.FORMAT_RGBA8)
	img.fill(FONDO)
	for f in range(filas.size()):
		var fila: Array = filas[f]
		for c in range(fila.size()):
			var src: Image = fila[c].get_image()
			var ox := c * an_celda + MARGEN / 2
			# Alineado abajo: es como se apoyan en la cancha, y así se ve
			# que el que cabecea está más alto que el resto.
			var oy := (f + 1) * al_celda - MARGEN / 2 - src.get_height() * ESCALA
			for y in range(src.get_height()):
				for x in range(src.get_width()):
					var col := src.get_pixel(x, y)
					if col.a <= 0.0:
						continue
					for sy in range(ESCALA):
						for sx in range(ESCALA):
							img.set_pixel(ox + x * ESCALA + sx, oy + y * ESCALA + sy, col)
	img.save_png(ruta)
