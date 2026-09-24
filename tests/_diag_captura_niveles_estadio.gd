extends SceneTree

## Captura los seis niveles de estadio con el mismo encuadre.
## Salida: scratch/niveles_estadio/<nivel>.png

const NIVELES := [
	"potrero",
	"barrial",
	"regular",
	"cuidado",
	"profesional",
	"elite",
]
const TAMANO := Vector2i(1152, 648)
const ZOOM := 10.0
const CARPETA_RES := "res://scratch/niveles_estadio"

var vista: VistaCancha
var paso := 0
var cuadros := 0


func _initialize() -> void:
	root.size = TAMANO
	vista = VistaCancha.new()
	root.add_child(vista)
	vista.size = Vector2(TAMANO)
	vista.camara.centro = Vector2.ZERO
	vista.camara.px_por_metro = ZOOM
	var carpeta_absoluta := ProjectSettings.globalize_path(CARPETA_RES)
	var error := DirAccess.make_dir_recursive_absolute(carpeta_absoluta)
	if error != OK:
		push_error("No se pudo crear %s: error %d" % [carpeta_absoluta, error])
		quit(error)


func _process(_delta: float) -> bool:
	if paso >= NIVELES.size():
		print("OK: seis niveles en res://scratch/niveles_estadio/")
		return true

	if cuadros == 0:
		vista.estado_cancha = NIVELES[paso]
		vista.queue_redraw()

	cuadros += 1
	if cuadros < 3:
		return false

	var imagen := root.get_texture().get_image()
	var ruta := "%s/%02d_%s.png" % [CARPETA_RES, paso + 1, NIVELES[paso]]
	var error := imagen.save_png(ruta)
	if error != OK:
		push_error("No se pudo guardar %s: error %d" % [ruta, error])
		return true
	print(ruta)
	paso += 1
	cuadros = 0
	return false
