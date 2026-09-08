extends SceneTree

## Exporta las PLANTILLAS para dibujar los sprites a mano. Cada PNG trae
## los sprites de hoy, en su grilla, pintados con los colores MARCADORES
## (ver PALETA_MARCADORES): son colores planos e inconfundibles, no los
## finales, porque camiseta y pelo cambian de club en club y de jugador en
## jugador.
##
## El que dibuja abre el PNG, pinta encima respetando la grilla y la
## paleta, y lo devuelve. tests/_diag_importar_sprites.gd lo convierte de
## vuelta a las constantes de SpritesPartido.
##
## Se corre con:
##   <godot> --path . --headless --script tests/_diag_plantilla_sprites.gd

const CARPETA := "E:/IntelliJ/Super Pocket Stars/plantillas"

## Separador de 1 píxel entre celda y celda. El importador lo saltea. Está
## para que se vea dónde termina un sprite y empieza el siguiente: sin él
## la grilla se corre de a un píxel y nadie se da cuenta.
const SEPARADOR := Color8(255, 0, 255)

## Letra del sprite -> color con el que se dibuja en la plantilla. Los
## colores que en el juego son variables (camiseta, pelo, número) llevan
## un marcador saturado que no se confunde con nada.
const PALETA_MARCADORES := {
	"J": Color8(255, 0, 0),      # camiseta
	"b": Color8(139, 0, 0),      # camiseta en sombra: mangas y hombros
	"H": Color8(56, 36, 20),     # pelo
	"V": Color8(255, 255, 255),  # vincha
	"S": Color8(242, 199, 158),  # piel
	"d": Color8(204, 161, 122),  # piel en sombra: el cuello
	"o": Color8(31, 26, 26),     # ojo
	"D": Color8(0, 0, 255),      # short
	"M": Color8(230, 230, 235),  # medias
	"B": Color8(15, 15, 15),     # botín
	"N": Color8(255, 255, 0),    # número
	"P": Color8(0, 255, 0),      # polvo de la barrida
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(CARPETA)

	_hoja("cabezas", SpritesPartido.CABEZAS, SpritesPartido.CABEZAS.size())
	_hoja("peinados", _aplanar(SpritesPartido.PELOS), SpritesPartido.CABEZAS.size())
	_hoja("torsos", SpritesPartido.TORSOS, SpritesPartido.TORSOS.size())
	# Las piernas van en dos hojas porque no miden lo mismo: las del remate
	# son más anchas, la pierna estirada no entra en el ancho del cuerpo.
	_hoja("piernas", [
		SpritesPartido.PIERNAS[SpritesPartido.QUIETO],
		SpritesPartido.PIERNAS[SpritesPartido.CORRE_A],
		SpritesPartido.PIERNAS[SpritesPartido.CORRE_B],
		SpritesPartido.PIERNAS[SpritesPartido.CABECEA],
	], 4)
	_hoja("piernas_remate", [
		SpritesPartido.PIERNAS[SpritesPartido.PATEA_ARMA],
		SpritesPartido.PIERNAS[SpritesPartido.PATEA],
	], 2)
	_hoja("brazos_festejo", [SpritesPartido.BRAZOS_ARRIBA], 1)
	_hoja("barrida", [SpritesPartido.BARRIDA_TENDIDA], 1)
	_hoja("arquero_vuela", [SpritesPartido.ARQUERO_VUELA], 1)

	print("OK: plantillas en %s" % CARPETA)
	quit()


## Los peinados vienen anidados (estilo -> dirección). La hoja los pone en
## una grilla: una fila por estilo, una columna por dirección.
func _aplanar(estilos: Array) -> Array:
	var salida: Array = []
	for estilo in estilos:
		salida.append_array(estilo)
	return salida


## Escribe una hoja. `celdas` son los sprites en orden de lectura y
## `por_fila` cuántos entran en cada fila de la grilla.
func _hoja(nombre: String, celdas: Array, por_fila: int) -> void:
	var an: int = celdas[0][0].length()
	var al: int = celdas[0].size()
	var columnas: int = mini(por_fila, celdas.size())
	var filas: int = int(ceil(float(celdas.size()) / columnas))
	var img := Image.create(columnas * (an + 1) + 1, filas * (al + 1) + 1, false, Image.FORMAT_RGBA8)
	img.fill(SEPARADOR)
	for i in range(celdas.size()):
		var ox := 1 + (i % columnas) * (an + 1)
		var oy := 1 + int(i / columnas) * (al + 1)
		var sprite: Array = celdas[i]
		for y in range(sprite.size()):
			var fila: String = sprite[y]
			for x in range(fila.length()):
				var letra := fila[x]
				var col: Color = PALETA_MARCADORES.get(letra, Color(0, 0, 0, 0))
				img.set_pixel(ox + x, oy + y, col)
	var ruta := "%s/%s.png" % [CARPETA, nombre]
	img.save_png(ruta)
	print("  %s: %d celdas de %dx%d, grilla %dx%d" % [nombre, celdas.size(), an, al, columnas, filas])
