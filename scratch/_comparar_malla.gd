extends SceneTree
## Foto de cerca de jugador y golero con la luz del partido, para comparar
## el GLB por partes con el unido. -- salida=ruta.png [jugador=res://..] [golero=res://..]
var _salida := "res://scratch/unida/foto.png"
var _rutas := {"jugador": "res://assets/3d/jugador.glb", "golero": "res://assets/3d/golero.glb"}
var _n := 0

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() != 2: continue
		if kv[0] == "salida": _salida = kv[1]
		else: _rutas[kv[0]] = kv[1]
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
	var piso := MeshInstance3D.new(); var plano := PlaneMesh.new(); plano.size = Vector2(30, 30)
	piso.mesh = plano; piso.material_override = Materiales3D.toon(Color("55ae42")); raiz.add_child(piso)
	var poses := [["jugador", "Quieto", 0.0, 0.0], ["jugador", "Patear_Corriendo", 0.35, 150.0],
		["golero", "Arquero_Sostiene", 0.2, 20.0], ["golero", "Agarrar", 0.4, -60.0]]
	var x := -2.4
	for p in poses:
		var j := Jugador3D.new(load(_rutas[p[0]]) as PackedScene)
		raiz.add_child(j)
		j.position = Vector3(x, 0, 0); x += 1.6
		j.rotation.y = deg_to_rad(p[3])
		j.colorear(Color("d8262c"), Color.TRANSPARENT, Color("84532f"))
		j.poner(p[1], p[2])
	var cam := Camera3D.new(); cam.fov = 40.0; raiz.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.2, 6.5), Vector3(0, 0.8, 0), Vector3.UP)
	cam.current = true
	process_frame.connect(_cuadro)

func _cuadro() -> void:
	_n += 1
	if _n == 10:
		root.get_texture().get_image().save_png(_salida)
		print("FOTO ", _salida)
		quit()
