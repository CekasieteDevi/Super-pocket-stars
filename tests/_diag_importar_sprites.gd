extends SceneTree

## Lee las plantillas dibujadas a mano y las convierte de vuelta a las
## constantes de SpritesPartido. Es el camino inverso de
## tests/_diag_plantilla_sprites.gd: ese exporta el PNG para pintar, este
## trae el PNG pintado.
##
## No toca sprites_partido.gd: imprime el bloque de código listo para
## pegar. Pisar el archivo solo se hace a mano, mirando lo que entra.
##
## Cada píxel tiene que ser EXACTAMENTE uno de los colores marcadores, o
## transparente. Si hay un color que no está en la paleta, el script lo
## reporta con su posición y no inventa nada: un antialias o un degradé
## rompe el pixel art en silencio y es imposible de encontrar después.
##
## Se corre con:
##   <godot> --path . --headless --script tests/_diag_importar_sprites.gd

const CARPETA := "E:/IntelliJ/Super Pocket Stars/plantillas"

## Qué hoja trae qué, y con qué grilla. `por_fila` tiene que coincidir con
## el que usó la plantilla, o las celdas salen corridas.
const HOJAS := [
	{"nombre": "cabezas", "ancho": 12, "alto": 6, "por_fila": 5},
	{"nombre": "peinados", "ancho": 12, "alto": 5, "por_fila": 5},
	{"nombre": "torsos", "ancho": 12, "alto": 6, "por_fila": 5},
	{"nombre": "piernas", "ancho": 12, "alto": 8, "por_fila": 4},
	{"nombre": "piernas_remate", "ancho": 16, "alto": 8, "por_fila": 2},
	{"nombre": "brazos_festejo", "ancho": 12, "alto": 12, "por_fila": 1},
	{"nombre": "barrida", "ancho": 20, "alto": 12, "por_fila": 1},
	{"nombre": "arquero_vuela", "ancho": 20, "alto": 12, "por_fila": 1},
]

## Color marcador -> letra. Es el inverso de la paleta de la plantilla; se
## indexa por el color en hexadecimal porque comparar Color con == entre
## un PNG y una constante depende de la precisión del float.
const MARCADORES := {
	"ff0000": "J", "8b0000": "b", "382414": "H", "ffffff": "V",
	"f2c79e": "S", "cca17a": "d", "1f1a1a": "o", "0000ff": "D",
	"e6e6eb": "M", "0f0f0f": "B", "ffff00": "N", "00ff00": "P",
}

## El separador de la grilla. No es parte de ningún sprite.
const SEPARADOR := "ff00ff"


func _init() -> void:
	var errores := 0
	for hoja in HOJAS:
		errores += _leer(hoja)
	if errores > 0:
		print("FALLA: %d colores fuera de la paleta. Nada de esto sirve hasta arreglarlos." % errores)
	else:
		print("OK: todas las hojas entraron limpias.")
	quit()


func _leer(hoja: Dictionary) -> int:
	var ruta := "%s/%s.png" % [CARPETA, hoja["nombre"]]
	var img := Image.load_from_file(ruta)
	if img == null:
		print("FALTA: %s" % ruta)
		return 0
	var an: int = hoja["ancho"]
	var al: int = hoja["alto"]
	var por_fila: int = hoja["por_fila"]
	# De cuántas celdas es la hoja lo dice su propio tamaño: así una hoja
	# con un peinado más entra sin tocar la tabla de arriba.
	var columnas: int = int((img.get_width() - 1) / float(an + 1))
	var filas: int = int((img.get_height() - 1) / float(al + 1))
	columnas = mini(columnas, por_fila)

	print("\n# --- %s: %d x %d celdas de %dx%d" % [hoja["nombre"], columnas, filas, an, al])
	var errores := 0
	for f in range(filas):
		for c in range(columnas):
			var ox := 1 + c * (an + 1)
			var oy := 1 + f * (al + 1)
			var lineas: Array = []
			for y in range(al):
				var linea := ""
				for x in range(an):
					var col := img.get_pixel(ox + x, oy + y)
					if col.a < 0.5:
						linea += "."
						continue
					var hex := col.to_html(false)
					if hex == SEPARADOR:
						linea += "."
						continue
					if not MARCADORES.has(hex):
						print("# COLOR RARO #%s en %s celda (%d,%d) píxel (%d,%d)" % [
							hex, hoja["nombre"], c, f, x, y])
						errores += 1
						linea += "."
						continue
					linea += MARCADORES[hex]
				lineas.append(linea)
			_imprimir(lineas)
	return errores


## Imprime la celda como el literal de GDScript que va en el archivo, con
## tabulaciones: se pega tal cual, sin reformatear.
func _imprimir(lineas: Array) -> void:
	var partes: Array = []
	for l in lineas:
		partes.append("\"%s\"" % l)
	print("[\n\t%s,\n]" % ",\n\t".join(partes))
