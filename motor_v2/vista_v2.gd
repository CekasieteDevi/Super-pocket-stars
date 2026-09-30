class_name VistaV2
extends Control

## Vista mínima del Motor V2 para la etapa 0 (docs/motor_v2.md, capa 6): el
## mismo estadio, luz, cámara y los mismos 22 Jugador3D que VistaCancha3D,
## pero leyendo el mundo en vez de fotogramas. Dibuja interpolando entre los
## dos últimos pasos y no mueve nada: solo pone posición, rumbo y la
## animación de andar según la velocidad real.
##
## Sirve para medir el costo de dibujo en el teléfono con la carga de un
## partido. La vista de verdad llega en la etapa 2.

const ESCENA_ESTADIO := VistaCancha3D.ESCENA_ESTADIO
const ESCENA_JUGADOR := VistaCancha3D.ESCENA_JUGADOR
const ESCENA_GOLERO := VistaCancha3D.ESCENA_GOLERO
const ESCENA_PELOTA := VistaCancha3D.ESCENA_PELOTA

var _viewport: SubViewport
var _mundo_3d: Node3D
var _camara: Camera3D
var _pelota: Node3D
var _jugadores: Array[Jugador3D] = []
## Metros recorridos por cada uno (fase del ciclo de andar) y su andar actual.
var _odometro := PackedFloat32Array()
var _andar: Array[String] = []
var _centro := Vector2.ZERO
var _tiempo := 0.0
## Perillas del banco (etapa 0) para ver qué pesa en el dibujo del teléfono.
var msaa := Viewport.MSAA_2X
var sombras := true
## Cortes de la sombra del sol: 4 es lo de VistaCancha3D (el modo por defecto).
var cortes_sombra := 4
## Manchas debajo de cada uno (SombrasRedondas) y si los personajes y la
## pelota proyectan la sombra del sol (con el sol prendido, el estadio sí).
var sombras_redondas := false
var personajes_con_sombra_sol := true
var _manchas: SombrasRedondas
var escala_3d := 1.0
## Sin los 22 jugadores: el laboratorio de la pelota (etapa 1) solo la mira a ella.
var con_jugadores := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(contenedor)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = msaa
	_viewport.scaling_3d_scale = escala_3d
	contenedor.add_child(_viewport)
	_mundo_3d = Node3D.new()
	_viewport.add_child(_mundo_3d)
	_armar_ambiente()
	var estadio: Node3D = (load(ESCENA_ESTADIO) as PackedScene).instantiate()
	_mundo_3d.add_child(estadio)
	Materiales3D.aplicar(estadio, {}, ["Arco_Red"])
	Materiales3D.cortar_lado_camara(estadio, ProyeccionPartido.MEDIO_ANCHO + VistaCancha3D.DETRAS_DE_BANDA_M,
		VistaCancha3D.MATERIALES_PISO)
	var fondo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(400.0, 400.0)
	fondo.mesh = plano
	fondo.position = Vector3(0.0, -0.05, 0.0)
	fondo.material_override = Materiales3D.toon(VistaCancha3D.COLOR_PISO_FONDO)
	_mundo_3d.add_child(fondo)
	_pelota = (load(ESCENA_PELOTA) as PackedScene).instantiate()
	_pelota.scale = Vector3.ONE * VistaCancha3D.ESCALA_PELOTA
	_mundo_3d.add_child(_pelota)
	Materiales3D.aplicar(_pelota)
	if sombras_redondas:
		_manchas = SombrasRedondas.new(MundoV2.JUGADORES + 1)
		_mundo_3d.add_child(_manchas)
	if not personajes_con_sombra_sol:
		_sin_sombra_sol(_pelota)
	if not con_jugadores:
		return
	var jugador := load(ESCENA_JUGADOR) as PackedScene
	var golero := load(ESCENA_GOLERO) as PackedScene
	var colores := ColoresClub.par("Atlético Prueba", "Deportivo Banco")
	for i in MundoV2.JUGADORES:
		var arquero := i % 11 == 0
		var p := Jugador3D.new(golero if arquero else jugador)
		_mundo_3d.add_child(p)
		var id := i if i < 11 else 1000 + i
		var camiseta: Color = colores[0 if i < 11 else 1]
		if arquero:
			camiseta = Color("2f9e44") if i < 11 else Color("e8a33a")
		p.colorear(camiseta, Color(0, 0, 0, 0), Color("3b2618"))
		p.poner_numero(i % 11 + 1)
		p.poner_cara(Jugador3D.cara_de(id), Jugador3D.Gesto.NORMAL)
		if not arquero:
			p.poner_peinado(Jugador3D.peinado_de(id))
		_jugadores.append(p)
		if not personajes_con_sombra_sol:
			_sin_sombra_sol(p)
		_andar.append("Respirar")
	_odometro.resize(MundoV2.JUGADORES)


static func _sin_sombra_sol(raiz: Node) -> void:
	for nodo in raiz.find_children("*", "GeometryInstance3D", true, false):
		(nodo as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _armar_ambiente() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("8fd3ff")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	entorno.ambient_light_energy = 0.0
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var mundo_entorno := WorldEnvironment.new()
	mundo_entorno.environment = entorno
	_mundo_3d.add_child(mundo_entorno)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.78)
	sol.light_energy = 1.0
	sol.shadow_enabled = sombras
	sol.directional_shadow_max_distance = 80.0
	sol.directional_shadow_mode = {1: DirectionalLight3D.SHADOW_ORTHOGONAL,
		2: DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS}.get(cortes_sombra, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	_mundo_3d.add_child(sol)
	sol.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.75, -0.6), Vector3.UP)
	_camara = Camera3D.new()
	_camara.keep_aspect = Camera3D.KEEP_WIDTH
	_camara.fov = VistaCancha3D.FOV_HORIZONTAL
	_camara.far = 400.0
	_mundo_3d.add_child(_camara)
	_camara.current = true


## `alfa`: cuánto del paso actual ya pasó (0 = el paso anterior, 1 = el actual).
func dibujar(m: MundoV2, alfa: float, delta: float) -> void:
	dibujar_estado(m.pos_previa, m.pos, m.rumbo, m.rapidez, m.pelota_previa, m.pelota_pos, alfa, delta)


## Lo mismo leyendo el mundo nativo (MundoV2Nativo, motor_v2/cpp).
func dibujar_nativo(m: Object, alfa: float, delta: float) -> void:
	dibujar_estado(m.get_pos_previa(), m.get_pos(), m.get_rumbo(), m.get_rapidez(),
		m.get_pelota_previa(), m.get_pelota_pos(), alfa, delta)


func dibujar_estado(pos_previa: PackedVector2Array, pos: PackedVector2Array, rumbo: PackedFloat32Array,
		rapidez: PackedFloat32Array, pelota_previa: Vector3, pelota: Vector3, alfa: float, delta: float) -> void:
	_dibujar_jugadores(pos_previa, pos, rumbo, rapidez, [], alfa, delta)
	dibujar_pelota(pelota_previa, pelota, alfa, delta)


## Los cuerpos de la etapa 2 (CuerposV2Nativos, 22 como en el partido) sin
## pelota: cada uno muestra su acción en el segundo en que va o, si no hace
## ninguna, anda según su velocidad real. La cámara sigue a `foco`.
func dibujar_cuerpos(c: Object, alfa: float, delta: float, foco: Vector2) -> void:
	var acciones := []
	for i in MundoV2.JUGADORES:
		# El tiempo de la acción es el del paso actual: se lo lleva al del
		# cuadro con lo que falta del paso (alfa).
		acciones.append([c.get_accion(i), maxf(0.0, float(c.get_tiempo_accion(i)) - (1.0 - alfa) / 60.0)])
	_dibujar_jugadores(c.get_pos_previa(), c.get_pos(), c.get_rumbo(), c.get_rapidez(), acciones, alfa, delta)
	_pelota.visible = false
	_mover_camara(foco, delta)


## `acciones[i]` = [clip, segundo]; "" o sin entrada = anda.
func _dibujar_jugadores(pos_previa: PackedVector2Array, pos: PackedVector2Array, rumbo: PackedFloat32Array,
		rapidez: PackedFloat32Array, acciones: Array, alfa: float, delta: float) -> void:
	_tiempo += delta
	for i in MundoV2.JUGADORES:
		var p := pos_previa[i].lerp(pos[i], alfa)
		var p3 := _jugadores[i]
		p3.position = Vector3(p.x, 0.0, p.y)
		if _manchas != null:
			_manchas.poner_jugador(i, p3.position)
		p3.rotation.y = rumbo[i]
		var v: float = rapidez[i]
		_odometro[i] += v * delta
		var accion: String = acciones[i][0] if i < acciones.size() else ""
		if accion != "" and p3.tiene(accion):
			p3.poner(accion, float(acciones[i][1]), delta)
			p3.poner_cara(p3.cara, Jugador3D.Gesto.NORMAL, _tiempo)
			continue
		var anim := _andar_de(i, v)
		var tiempo: float
		if anim == VistaCancha3D.ANIM_QUIETO or anim == "Golero_Guardia":
			tiempo = fposmod(_tiempo + float(i) * 0.37, maxf(p3.duracion(anim), 0.01))
		else:
			tiempo = fposmod(_odometro[i] / VistaCancha3D.METROS_POR_CICLO, 1.0) * p3.duracion(anim)
		p3.poner(anim, tiempo, delta)
		p3.poner_cara(p3.cara, Jugador3D.Gesto.NORMAL, _tiempo)


## `giro` (rad/s, del motor) hace girar el modelo: sin él no se ve el efecto.
func dibujar_pelota(pelota_previa: Vector3, pelota: Vector3, alfa: float, delta: float,
		giro := Vector3.ZERO) -> void:
	var bola := pelota_previa.lerp(pelota, alfa)
	if giro.length() > 0.01:
		_pelota.global_rotate(giro.normalized(), giro.length() * delta)
	# El modelo de la pelota se dibuja al doble (VistaCancha3D.ESCALA_PELOTA):
	# se levanta lo que crece el radio para que no se hunda en el piso.
	bola.y += MundoV2.RADIO_PELOTA * (VistaCancha3D.ESCALA_PELOTA - 1.0)
	_pelota.position = bola
	if _manchas != null:
		_manchas.poner_pelota(MundoV2.JUGADORES, bola)
	_mover_camara(Vector2(bola.x, bola.z), delta)


func _andar_de(i: int, v: float) -> String:
	if i % 11 == 0:
		return "Correr" if v > VistaCancha3D.ARQUERO_CORRE_MS else "Golero_Guardia"
	var nuevo := VistaCancha3D._andar(_andar[i], v)
	if v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS:
		nuevo = VistaCancha3D.ANIM_QUIETO
	elif nuevo == VistaCancha3D.ANIM_QUIETO:
		nuevo = "Caminar"
	_andar[i] = nuevo
	return nuevo


## El encuadre de VistaCancha3D (_mover_camara) con el zoom base, siguiendo
## a la pelota con suavizado.
func _mover_camara(bola: Vector2, delta: float) -> void:
	_centro = _centro.lerp(bola, clampf(delta * CamaraPartido.SUAVIZADO, 0.0, 1.0))
	var ancho_m: float = maxf(size.x, 1.0) / CamaraPartido.PX_POR_METRO_BASE / CamaraPartido3D.ACERCAMIENTO
	var distancia := ancho_m * 0.5 / tan(deg_to_rad(VistaCancha3D.FOV_HORIZONTAL) * 0.5)
	var limite_x: float = ProyeccionPartido.MEDIO_LARGO + CamaraPartido.MARGEN_M - ancho_m * 0.5
	var limite_y: float = ProyeccionPartido.MEDIO_ANCHO - CamaraPartido3D.MARGEN_LATERAL_M
	var c := Vector2(clampf(_centro.x, -limite_x, limite_x), clampf(_centro.y, -limite_y, limite_y))
	var objetivo := Vector3(c.x, 0.0, c.y)
	var e := deg_to_rad(VistaCancha3D.ELEVACION_CAMARA)
	_camara.position = objetivo + Vector3(0.0, sin(e), cos(e)) * distancia
	_camara.look_at(objetivo, Vector3.UP)
