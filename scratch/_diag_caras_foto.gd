extends SceneTree
## Foto de frente de las 20 caras en el chibi, con un gesto (medición, no test).
## Uso: <godot> --path . --rendering-method gl_compatibility --rendering-driver opengl3
##   --script scratch/_diag_caras_foto.gd -- [gesto=0..4] [salida=ruta.png] [golero] [lejos]
const SEED := 0

var _cuadros := 0
var _salida := OS.get_environment("TEMP") + "/caras/foto.png"

func _init() -> void:
	var gesto := 0
	var escena := "res://assets/3d/jugador.glb"
	var lejos := false
	var desde := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("salida="):
			_salida = a.substr(7)
		elif a.begins_with("gesto="):
			gesto = int(a.substr(6))
		elif a == "golero":
			escena = "res://assets/3d/golero.glb"
		elif a.begins_with("desde="):
			desde = int(a.substr(6))
		elif a == "lejos":
			lejos = true
	var mundo := Node3D.new()
	root.add_child(mundo)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("8fd3ff")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = entorno
	mundo.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.78)
	mundo.add_child(sol)
	sol.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.75, -0.6), Vector3.UP)
	var pelos := [Color("5a3825"), Color("1c1410"), Color("e0b050"), Color("a0522d"), Color("84532f")]
	# desde=N: filas = caras N..N+3, columnas = los 5 gestos. Si no, las 20
	# caras con un gesto.
	for k in 20:
		var n := k if desde < 0 else desde + k / 5
		var g := gesto if desde < 0 else k % 5
		if n >= Jugador3D.CANTIDAD_CARAS:
			continue
		var j := Jugador3D.new(load(escena))
		mundo.add_child(j)
		j.position = Vector3((k % 5 - 2) * 1.0, -(k / 5) * 1.0, 0.0)
		j.colorear(Color("d62828"), Color.WHITE, pelos[n % pelos.size()])
		j.poner("Quieto", 0.0)
		j.poner_cara(n, g)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.2 if not lejos else 14.0
	mundo.add_child(cam)
	# Un poco de arriba, como la cámara del partido de cerca.
	cam.look_at_from_position(Vector3(0, -0.3 + 6.0 * 0.25, 6.0), Vector3(0, -0.3, 0), Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_cuadros += 1
	if _cuadros == 5:
		root.get_texture().get_image().save_png(_salida)
		return true
	return false
