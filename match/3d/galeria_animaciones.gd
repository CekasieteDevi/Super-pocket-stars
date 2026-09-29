class_name GaleriaAnimaciones3D
extends Node3D

## Banco de control de las animaciones de jugador en el motor real.
## Muestra cada animación en un chibi, con el salto que pone el motor en las
## aéreas y la pelota en los anclajes (lateral y pecho). Con `-- capturar`
## guarda cuatro capturas (0, 25, 50 y 75% de cada animación) en
## scratch/galeria_<n>.png y cierra. No lo llama nadie: se abre a mano.

const ANIMACIONES := [
	"Cabecear", "Volea", "Chilena", "Palomita", "Pecho",
	"Taco", "Amague", "Regate_Croqueta", "Regate_Bicicleta", "Regate_Ruleta",
	"Regate_Globito", "Regate_Elastica", "Barrida", "Bloquear", "Caer",
	"Lesionado", "Lateral_Prepara", "Lateral", "Festejar",
]

## Animación -> acción del motor, para pedirle el salto a CoreografiaPartido.
const AEREAS := {"Cabecear": "cabecea", "Volea": "volea", "Chilena": "chilena", "Palomita": "palomita"}
const COLUMNAS := 5
const SEPARACION := Vector2(3.4, 4.2)
const MOMENTOS := [0.0, 0.25, 0.5, 0.75]

var _modelos := {}
var _pelotas := {}
var _etiquetas := {}
var _capturar := false
var _momento := 0
var _cuadros_espera := 0
var _tiempo := 0.0


func _ready() -> void:
	_capturar = "capturar" in OS.get_cmdline_user_args()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("8fd3ff")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	entorno.ambient_light_energy = 0.0
	var we := WorldEnvironment.new(); we.environment = entorno; add_child(we)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.78); sol.shadow_enabled = true
	add_child(sol)
	sol.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.75, -0.6), Vector3.UP)
	var piso := MeshInstance3D.new(); var plano := PlaneMesh.new(); plano.size = Vector2(60, 60)
	piso.mesh = plano; piso.material_override = Materiales3D.toon(Color("55ae42")); add_child(piso)
	var escena: PackedScene = load(VistaCancha3D.ESCENA_JUGADOR)
	var escena_pelota: PackedScene = load(VistaCancha3D.ESCENA_PELOTA)
	for i in ANIMACIONES.size():
		var nombre: String = ANIMACIONES[i]
		var j := Jugador3D.new(escena)
		var col := i % COLUMNAS
		var fila := i / COLUMNAS
		j.position = Vector3((col - (COLUMNAS - 1) * 0.5) * SEPARACION.x, 0.0, (fila - 1.5) * SEPARACION.y)
		j.rotation.y = deg_to_rad(25.0)
		j.colorear(Color("d8262c"), Color.TRANSPARENT, Color("84532f"))
		add_child(j)
		_modelos[nombre] = j
		var e := Label3D.new(); e.text = nombre; e.font_size = 64; e.pixel_size = 0.004
		e.billboard = BaseMaterial3D.BILLBOARD_ENABLED; e.position = j.position + Vector3(0, 2.1, 0)
		e.outline_size = 12
		add_child(e)
		if nombre in ["Lateral_Prepara", "Lateral", "Pecho"]:
			var p := escena_pelota.instantiate() as Node3D
			p.scale = Vector3.ONE * VistaCancha3D.ESCALA_PELOTA
			Materiales3D.aplicar(p)
			add_child(p)
			_pelotas[nombre] = p
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH; cam.fov = 55.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 11.0, 19.0), Vector3(0, 0.6, 0.6), Vector3.UP)
	cam.current = true


func _process(delta: float) -> void:
	_tiempo += delta
	var fase: float = MOMENTOS[_momento] if _capturar else fposmod(_tiempo * 0.5, 1.0)
	for nombre in ANIMACIONES:
		var j: Jugador3D = _modelos[nombre]
		j.poner(nombre, fase * j.duracion(nombre))
		var base := j.position
		base.y = CoreografiaPartido.salto(AEREAS[nombre], fase) if AEREAS.has(nombre) else 0.0
		j.position = base
		if _pelotas.has(nombre):
			var frente := Vector3(sin(j.rotation.y), 0, cos(j.rotation.y))
			var radio := VistaCancha3D.RADIO_PELOTA * VistaCancha3D.ESCALA_PELOTA
			var punto := (j.ancla("Mano_L") + j.ancla("Mano_R")) * 0.5
			if nombre == "Pecho":
				punto = j.ancla("Pecho").lerp(j.global_position + Vector3(0, radio, 0) + frente * 0.4, fase)
			_pelotas[nombre].global_position = punto + frente * radio
	if not _capturar:
		return
	# Dos cuadros de espera para que el esqueleto y la sombra se actualicen.
	_cuadros_espera += 1
	if _cuadros_espera < 3:
		return
	_cuadros_espera = 0
	var imagen := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scratch"))
	imagen.save_png("res://scratch/galeria_%d.png" % _momento)
	print("[galeria] captura %d (fase %.2f)" % [_momento, fase])
	_momento += 1
	if _momento >= MOMENTOS.size():
		get_tree().quit()
