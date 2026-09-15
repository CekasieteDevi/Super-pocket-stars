extends SceneTree

## Captura la cancha en varios encuadres y la guarda en PNG. Sirve para
## comparar el dibujo antes y después de tocar VistaCancha: se corre una
## vez con cada versión y se comparan los PNG con --comparar.
##   godot --path . --script tests/_diag_captura_cancha.gd -- <carpeta> [--comparar <otra>]

const SEED := 20260818
## [fotograma, centro de cámara, px por metro, estado de cancha]
const ENCUADRES := [
	[300, Vector2(0, 0), 22.0, "regular"],
	[450, Vector2(-40, -20), 15.0, "potrero"],
	[600, Vector2(45, 25), 26.0, "hibrido"],
	[700, Vector2(52, 0), 18.0, "regular"],
	[100, Vector2(-52, 30), 15.0, "regular"],
]

var vista: VistaPartido
var carpeta := ""
var otra := ""
var paso := 0
var cuadro := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	carpeta = args[0]
	if args.size() >= 3 and args[1] == "--comparar":
		otra = args[2]
	_preparar.call_deferred()


func _preparar() -> void:
	root.size = Vector2i(1152, 648)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var local := Team.generar("Local", rng)
	var visita := Team.generar("Visita", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)
	vista = VistaPartido.new()
	root.add_child(vista)
	vista.size = Vector2(1152, 648)
	var colores := ColoresClub.par(local.nombre, visita.nombre)
	vista.iniciar(r["fotogramas"], colores[0], colores[1], local.nombre, visita.nombre,
		VistaPartido.construir_nombres(local, visita), "regular")
	vista.pausado = true
	DirAccess.make_dir_recursive_absolute(carpeta)


func _process(_delta: float) -> bool:
	if vista == null:
		return false
	if paso >= ENCUADRES.size():
		return true
	var e: Array = ENCUADRES[paso]
	if cuadro == 0:
		vista.vista.estado_cancha = e[3]
		vista._mostrar(e[0], 0.0)
		vista.vista.camara.centro = e[1]
		vista.vista.camara.px_por_metro = e[2]
		vista.vista.queue_redraw()
	cuadro += 1
	# Dos cuadros: uno para que se dibuje y otro para que llegue a la textura.
	if cuadro < 3:
		return false
	var img := root.get_texture().get_image()
	var ruta := "%s/encuadre_%d.png" % [carpeta, paso]
	img.save_png(ruta)
	if otra != "":
		var ref := Image.load_from_file("%s/encuadre_%d.png" % [otra, paso])
		var distintos := 0
		var peor := 0.0
		var caja := Rect2i()
		var marcas := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var a := img.get_pixel(x, y)
				var b := ref.get_pixel(x, y)
				var d := maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
				marcas.set_pixel(x, y, Color.RED if d > 0.02 else a.darkened(0.6))
				if d > 0.02:
					caja = Rect2i(x, y, 1, 1) if distintos == 0 else caja.expand(Vector2i(x, y))
					distintos += 1
				peor = maxf(peor, d)
		marcas.save_png("%s/diferencia_%d.png" % [carpeta, paso])
		print("encuadre %d: %d píxeles distintos (%.3f%%), peor diferencia %.2f, zona %s" % [
			paso, distintos, 100.0 * distintos / float(img.get_width() * img.get_height()), peor, caja])
	paso += 1
	cuadro = 0
	return false
