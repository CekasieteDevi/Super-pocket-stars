extends SceneTree
## Dorsales del 3D (Jugador3D.poner_numero) en fila, de espalda, con la luz
## del partido. -- salida=ruta.png [lejos] [golero] [frente] [anim=Correr] [t=0.3]
## Camisetas oscuras y claras (número blanco / negro); el del 23, espejado.
var _salida := "res://scratch/dorsales/dorsales.png"
var _lejos := false
var _golero := false
var _atras := true
var _anim := "Quieto"
var _t := 0.0
var _n := 0

const PELOS := ["84532f", "2b1d14", "e0b35a", "5a3a22", "1c1410", "a8672e", "3b2a1e", "c98d3f", "2b1d14", "6b4226"]
const CAMISETAS := ["d8262c", "f4f4f0", "1b3f8f", "ffd400", "111111", "6cc4ee", "0f7a3a", "ff8c1a", "7a1f5c", "d8262c"]
const NUMEROS := [1, 10, 7, 23, 99, 4, 88, 11, 5, 17]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "salida" and kv.size() == 2: _salida = kv[1]
		elif kv[0] == "lejos": _lejos = true
		elif kv[0] == "golero": _golero = true
		elif kv[0] == "frente": _atras = false
		elif kv[0] == "anim" and kv.size() == 2: _anim = kv[1]
		elif kv[0] == "t" and kv.size() == 2: _t = float(kv[1])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_salida.get_base_dir()))
	var raiz := Node3D.new()
	root.add_child(raiz)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("8fd3ff")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	entorno.ambient_light_energy = 0.0
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = entorno; raiz.add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.78); sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 80.0
	raiz.add_child(sol)
	sol.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.75, -0.6), Vector3.UP)
	var piso := MeshInstance3D.new(); var plano := PlaneMesh.new(); plano.size = Vector2(60, 60)
	piso.mesh = plano; piso.material_override = Materiales3D.toon(Color("55ae42")); raiz.add_child(piso)
	var escena := load("res://assets/3d/golero.glb" if _golero else "res://assets/3d/jugador.glb") as PackedScene
	var paso := 1.25
	for k in Jugador3D.CANTIDAD_PEINADOS:
		var j := Jugador3D.new(escena)
		raiz.add_child(j)
		j.position = Vector3((k - 4.5) * paso, 0, 0)
		j.rotation.y = deg_to_rad(180.0 if _atras else 0.0)
		j.colorear(Color(CAMISETAS[k]), Color.TRANSPARENT, Color(PELOS[k]))
		j.poner_peinado(k)
		j.poner_cara(k, Jugador3D.Gesto.NORMAL)
		j.poner_numero(NUMEROS[k])
		j.espejado = k == 3
		j.poner(_anim, _t)
	var cam := Camera3D.new(); raiz.add_child(cam)
	if _lejos:
		cam.fov = 30.0
		cam.look_at_from_position(Vector3(0, 18, 38), Vector3(0, 0.8, 0), Vector3.UP)
	else:
		cam.fov = 30.0
		cam.look_at_from_position(Vector3(0, 1.6, 8.5), Vector3(0, 1.2, 0), Vector3.UP)
	cam.current = true
	process_frame.connect(_cuadro)


func _cuadro() -> void:
	_n += 1
	if _n == 10:
		root.get_texture().get_image().save_png(_salida)
		print("FOTO ", _salida)
		quit()
