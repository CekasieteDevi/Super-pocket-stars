extends SceneTree

## Captura cómo se ve la pelota que sale por la línea de fondo cerca del
## arco: unos fotogramas antes de frenar, el primero quieta y uno después.
## Con ventana (sin --headless):
##   godot --path . --script tests/_diag_captura_salida_fondo.gd -- <carpeta>

const SEED := 31415
const PARTIDOS := 8
const MAX_CAPTURAS := 6

var carpeta := ""
var vista: VistaPartido
var pendientes: Array = []   # [fotogramas, indice, nombre]
var cuadro := 0


func _initialize() -> void:
	carpeta = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(carpeta)
	_preparar.call_deferred()


func _preparar() -> void:
	root.size = Vector2i(1152, 648)
	vista = VistaPartido.new()
	root.add_child(vista)
	vista.size = Vector2(1152, 648)
	var casos := 0
	for p in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p
		var local := Team.generar("L", rng)
		var visita := Team.generar("V", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		var fotos: Array = r["fotogramas"]
		for i in range(2, fotos.size()):
			var a: Dictionary = fotos[i]["pelota"]
			var b: Dictionary = fotos[i - 1]["pelota"]
			var c: Dictionary = fotos[i - 2]["pelota"]
			var quieta := is_equal_approx(float(a["x"]), float(b["x"])) and is_equal_approx(float(a["y"]), float(b["y"]))
			var venia := not (is_equal_approx(float(b["x"]), float(c["x"])) and is_equal_approx(float(b["y"]), float(c["y"])))
			var hubo_gol: bool = fotos[i]["goles"] != fotos[maxi(0, i - 20)]["goles"]
			if quieta and venia and not hubo_gol and absf(float(a["x"])) > ProyeccionPartido.MEDIO_LARGO \
					and absf(float(a["y"])) < 12.0 and casos < MAX_CAPTURAS:
				print("caso %d: partido %d fotograma %d pelota (%.1f, %.1f)" % [casos, p, i, a["x"], a["y"]])
				for d in [-4, -2, 0, 3]:
					pendientes.append([fotos, i + d, "caso%d_%+d" % [casos, d], local, visita])
				casos += 1


func _process(_delta: float) -> bool:
	if vista == null:
		return false
	if pendientes.is_empty():
		return true
	var tarea: Array = pendientes[0]
	if cuadro == 0:
		if vista.fotogramas != tarea[0]:
			var colores := ColoresClub.par(tarea[3].nombre, tarea[4].nombre)
			vista.iniciar(tarea[0], colores[0], colores[1], "L", "V", {}, "regular")
			vista.pausado = true
		var f: Dictionary = tarea[0][tarea[1]]
		vista._mostrar(tarea[1], 0.0)
		vista.vista.camara.px_por_metro = CamaraPartido.PX_POR_METRO_AREA
		vista.vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), vista.size)
		vista.vista.camara.px_por_metro = CamaraPartido.PX_POR_METRO_AREA
		vista.vista.queue_redraw()
	cuadro += 1
	if cuadro < 3:
		return false
	root.get_texture().get_image().save_png("%s/%s.png" % [carpeta, tarea[2]])
	pendientes.pop_front()
	cuadro = 0
	return false
