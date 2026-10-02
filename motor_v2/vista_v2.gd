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
## Sentido de la marcha -> ángulo respecto del rumbo (+ = a su izquierda) y
## el clip en cinta que anda así. 0 es adelante: lo elige _andar_de.
const ANGULO_DE_SENTIDO := {0: 0.0, 1: PI * 0.5, -1: -PI * 0.5, 2: PI}
const CLIP_DE_SENTIDO := {1: "Correr_Costado_Izq", -1: "Correr_Costado_Der", 2: "Correr_Espaldas"}
## Para no cambiar de clip a cada rato cerca de 45°.
const HISTERESIS_SENTIDO := deg_to_rad(10.0)
## Qué tan rápido gira el modelo hacia el rumbo que muestra. Más rápido que
## el giro_rapido del cuerpo: solo tapa el salto de 90° al cambiar de sentido.
const GIRO_MODELO_RAD_S := 4.0 * PI
## Clips de una vez (docs/motor_v2.md, etapa 2). Sale con Arranque el que
## arranca de parado buscando al menos la rapidez de Correr: el que sale
## caminando o trotando no se tira como un velocista.
const ARRANQUE_DESDE_MS := VistaCancha3D.ANDAR_TROTA_HASTA_MS
## Gira con Giro_90 o Giro_180 el que está quieto y le falta girar esto o más;
## desde GIRO_180_DESDE, media vuelta.
const GIRO_DESDE := deg_to_rad(60.0)
## Ajuste de cuerpo (etapa 6): el motor deja tocar la pelota con la frente o
## con las manos aunque el punto del clip quede a unos decímetros (cabecea
## hasta toque.cabeza_hasta, 1,8 m, con la frente del chibi a 0,97 m; el
## arquero ataja hasta arquero.tolerancia_max_m y salto_estirada_m). La vista
## lleva el modelo entero para que ese punto llegue a la pelota en el
## contacto: salta y se estira. Sin esto el cabezazo y la atajada se veían
## errados aunque el motor los contara. Empieza AJUSTE_CUERPO_ANTES_SEG antes
## del contacto y se suelta AJUSTE_CUERPO_DESPUES_SEG después.
const AJUSTE_CUERPO_ANTES_SEG := 0.3
const AJUSTE_CUERPO_DESPUES_SEG := 0.35
## Lo más que sube y lo más que se corre en el piso.
const AJUSTE_CUERPO_SUBE_M := 0.9
const AJUSTE_CUERPO_PISO_M := 0.6
## Clip -> [segundo del contacto, [anclas]] de los que tocan con la frente o
## con las manos.
var _contacto_cuerpo := {}
## Lo que se corrió cada uno en el contacto (ver _ajustar_cuerpo).
var _corrido := {}
## Frenada: cuánto de más puede faltar para parar sobre lo que da la rapidez
## (v² / 2·frenada) y seguir siendo una frenada. La rampa de a pasos del cuerpo
## deja hasta v·dt/2 de diferencia (6 cm a 7 m/s).
const FRENADA_HOLGURA_M := 0.25
## Frenada: si el clip no avanza durante este tiempo con el cuerpo andando a
## más que esto, deja la frenada y vuelve a los loops de andar.
const FRENADA_TRABADA_SEG := 0.05
const FRENADA_TRABADA_MS := 0.3
const GIRO_180_DESDE := deg_to_rad(135.0)
## Media vuelta corriendo: el objetivo queda a esto o más de la carrera. El
## cuerpo la da frenando en línea recta (Cuerpo::_moverse, giro_acel).
const MEDIA_VUELTA_DESDE := deg_to_rad(150.0)

## Ajuste de pie (etapa 3): el pie va a la pelota en los últimos
## AJUSTE_ANTES_SEG antes del cuadro de contacto y la suelta en
## AJUSTE_DESPUES_SEG. Hacia la pelota el modelo gira a lo sumo
## giro_alcance_rad (data/fisica_v2.json), lo mismo que el motor le deja
## estirar el pie hacia un costado.
const AJUSTE_ANTES_SEG := 0.15
const AJUSTE_DESPUES_SEG := 0.1

## Etapa 8: el estadio según la cancha del local
## (VistaCancha.nivel_estadio_desde_calidad). Qué partes del modelo
## (assets/3d/estadio.glb) no tiene cada nivel y cuánto se seca el pasto
## (0 = el verde del modelo, 1 = COLOR_PASTO_SECO). "" o un nivel que no está
## acá: el estadio entero.
const ESTADIO_SIN := {
	"potrero": ["Tribunas", "Torres_Luz", "Carteles"],
	"barrial": ["Tribunas", "Torres_Luz"],
	"regular": ["Torres_Luz"],
}
const PASTO_SECO := {"potrero": 0.5, "barrial": 0.35, "regular": 0.15}
const COLOR_PASTO_SECO := Color("9a8a4a")
const PARTES_ESTADIO := ["Tribunas", "Torres_Luz", "Carteles"]
const MATERIALES_PASTO := ["Cesped", "Cesped_2"]
var nivel_estadio := ""
var _estadio: Node3D
var _viewport: SubViewport
var _mundo_3d: Node3D
var _camara: Camera3D
var _pelota: Node3D
var _jugadores: Array[Jugador3D] = []
## Ciclos de andar que lleva cada uno (la fase) y su andar actual. Cada
## clip en cinta avanza un ciclo cada `metros` de data/acciones_v2.json: así
## el pie apoyado queda quieto en la cancha. Todos arrancan con el derecho
## pasando por debajo en la fase 0: cambiar de clip no cambia de pie.
var _ciclos := PackedFloat32Array()
var _metros_ciclo := {}
## Los clips en cinta de data/acciones_v2.json (loops y de una vez).
var _cinta := {}
## El clip de una vez que hace cada uno ({} = ninguno): tipo, clip, segundo
## del clip, metros recorridos y, en los giros, rumbo del principio y giro.
var _una_vez: Array[Dictionary] = []
var _frenada := 6.0
## Cambia de clip sin fundido en este cuadro. Los giros empiezan y terminan
## en la pose de Respirar pero con el modelo girado: fundiendo, la pose
## vieja (cadera girada en el esqueleto) y el modelo ya girado sumaban el
## giro dos veces y el pie barría 0,36 m en un cuadro.
var _sin_fundido := PackedByteArray()
## La rapidez del paso anterior de cada uno y cuánto la bajó (m/s²): la
## Frenada empieza solo si el cuerpo está frenando de verdad.
var _v_previa := PackedFloat32Array()
var _desacelera := PackedFloat32Array()
## Después de la media vuelta anda hacia adelante aunque el rumbo del cuerpo
## todavía mire atrás (ver _dibujar_jugadores).
var _adelante := PackedByteArray()
var _giro_acel := 12.0
## Hacia dónde anda cada uno respecto de adonde mira (una clave de
## ANGULO_DE_SENTIDO). Por debajo de rapidez_para_girar el cuerpo mira la
## jugada (Cuerpo::_girar) y anda de costado o para atrás: con Trotar
## desviado 1 rad el pie apoyado patinaba el 95% de lo que avanzaba.
var _sentido := PackedInt32Array()
## El rumbo que muestra cada modelo (ver _rumbo_mostrado).
var _rumbo_modelo := PackedFloat32Array()
var _rumbo_listo := false
## Los que entraron en `recomponer` y todavía no tienen rumbo de modelo.
var _sin_rumbo := {}
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
## Etapa 6: el árbitro (ArbitroV2). Se arma solo al dibujar un partido con
## reglas (el que tiene get_tarjeta).
var arbitro: ArbitroV2
## El último corte al saque que ya se dibujó (PartidoVistoV2.get_corte).
var _corte_visto := -1
## Cuánto se acerca la cámara (1 = el encuadre del partido). El laboratorio
## de reglas la acerca mientras el árbitro muestra la tarjeta: de lejos la
## tarjeta (13 × 18 cm) casi no se ve.
var acercamiento := 1.0
var _acercamiento_actual := 1.0
## Adónde mira la cámara en vez de la pelota (metros de la cancha), o null.
## El laboratorio de reglas lo usa para mostrar al que sale de la cancha.
var foco = null
## El arquero con la pelota en las manos (loop de 2 s).
const ANIM_SOSTIENE := "Arquero_Sostiene"
## Sin los 22 jugadores: el laboratorio de la pelota (etapa 1) solo la mira a ella.
var con_jugadores := true
## Cuántos y de qué equipo (etapa 3: el rondo y el partidito tienen 6 y 10,
## sin arqueros). Vacío: los 22 del partido, del 0 al 10 un equipo y el 0 y
## el 11 arqueros.
var equipos := PackedInt32Array()
## Etapa 5: 1 el que es arquero (get_arqueros de CanchitaV2Nativa). Vacío:
## con `equipos` vacío, el 0 y el 11; si no, nadie.
var arqueros := PackedInt32Array()
## Etapa 6: el id de cada uno (get_ids de CanchitaV2Nativa) para su cara y su
## peinado: el que entra en un cambio es otro. Vacío: de su lugar.
var ids := PackedInt32Array()
## Etapa 8: la ropa de cada uno, en el orden de `equipos`: {camiseta, short,
## pelo, numero}. Vacío (los laboratorios): los colores de prueba y el número
## según el orden.
var ropa: Array = []
## Clip -> [segundo del contacto, ancla] de los que tocan con el pie.
var _contacto_pie := {}
var _giro_alcance := 1.0
## Dibujando la canchita: los pies van a la pelota.
var _ajustar_pies := false


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
	_estadio = (load(ESCENA_ESTADIO) as PackedScene).instantiate()
	_mundo_3d.add_child(_estadio)
	Materiales3D.aplicar(_estadio, {}, ["Arco_Red"])
	Materiales3D.cortar_lado_camara(_estadio, ProyeccionPartido.MEDIO_ANCHO + VistaCancha3D.DETRAS_DE_BANDA_M,
		VistaCancha3D.MATERIALES_PISO)
	poner_estadio(nivel_estadio)
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
		_manchas = SombrasRedondas.new(_cantidad() + 1)
		_mundo_3d.add_child(_manchas)
	if not personajes_con_sombra_sol:
		_sin_sombra_sol(_pelota)
	if not con_jugadores:
		return
	var numero := [0, 0]
	for i in _cantidad():
		numero[_equipo(i)] += 1
		_jugadores.append(_crear_jugador(i, numero[_equipo(i)]))
		_andar.append("Respirar")
	_ciclos.resize(_cantidad())
	_sentido.resize(_cantidad())
	_rumbo_modelo.resize(_cantidad())
	_una_vez.resize(_cantidad())
	_sin_fundido.resize(_cantidad())
	_v_previa.resize(_cantidad())
	_desacelera.resize(_cantidad())
	_adelante.resize(_cantidad())
	_frenada = float(FisicaV2.parametros_cuerpo()["frenada"])
	_giro_acel = float(FisicaV2.parametros_cuerpo()["giro_acel"])
	var clips := FisicaV2.clips()
	_giro_alcance = float(FisicaV2.parametros_toque()["giro_alcance_rad"])
	for nombre in clips:
		var c: Dictionary = clips[nombre]
		if c["contacto"] != null and str(c["ancla"]) in ["Pie_R", "Pie_L"]:
			_contacto_pie[nombre] = [float(c["contacto"]) * float(c["duracion"]), str(c["ancla"])]
		if c["contacto"] != null and str(c["ancla"]) in ["Frente", "manos"]:
			_contacto_cuerpo[nombre] = [float(c["contacto"]) * float(c["duracion"]),
				["Mano_L", "Mano_R"] if str(c["ancla"]) == "manos" else ["Frente"]]
		if not c.has("metros"):
			continue
		_cinta[nombre] = c
		if c["bucle"]:
			_metros_ciclo[nombre] = float(c["metros"])


## Muestra el estadio del nivel `nivel`: saca las tribunas, las torres o los
## carteles que ese nivel no tiene y seca el pasto.
func poner_estadio(nivel: String) -> void:
	nivel_estadio = nivel
	if _estadio == null:
		return
	var sin: Array = ESTADIO_SIN.get(nivel, [])
	for parte in PARTES_ESTADIO:
		var nodo := _estadio.find_child(parte, true, false) as Node3D
		if nodo != null:
			nodo.visible = not sin.has(parte)
	var seco := float(PASTO_SECO.get(nivel, 0.0))
	for nodo in _estadio.find_children("*", "MeshInstance3D", true, false):
		var mi := nodo as MeshInstance3D
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var original := mi.mesh.surface_get_material(i)
			if original != null and original.resource_name in MATERIALES_PASTO:
				var color := Materiales3D.color_de(original)
				mi.set_surface_override_material(i, Materiales3D.toon_compartido(original.resource_name,
					color.lerp(COLOR_PASTO_SECO, seco)))


## El modelo del jugador `i`, con su ropa, su cara y su peinado. `numero`: el
## que lleva si no hay `ropa` (los laboratorios).
func _crear_jugador(i: int, numero: int) -> Jugador3D:
	var arquero := _es_arquero(i)
	var equipo := _equipo(i)
	var p := Jugador3D.new(load(ESCENA_GOLERO if arquero else ESCENA_JUGADOR) as PackedScene)
	_mundo_3d.add_child(p)
	var id := i if equipo == 0 else 1000 + i
	if i < ids.size() and ids[i] >= 0:
		id = ids[i]
	if i < ropa.size():
		var r: Dictionary = ropa[i]
		p.colorear(r["camiseta"], r.get("short", Color.TRANSPARENT), r.get("pelo", Color("3b2618")))
		p.poner_numero(int(r.get("numero", numero)))
	else:
		var camiseta: Color = ColoresClub.par("Atlético Prueba", "Deportivo Banco")[equipo]
		if arquero:
			camiseta = Color("2f9e44") if equipo == 0 else Color("e8a33a")
		p.colorear(camiseta, Color(0, 0, 0, 0), Color("3b2618"))
		p.poner_numero(numero)
	p.poner_cara(Jugador3D.cara_de(id), Jugador3D.Gesto.NORMAL)
	if not arquero:
		p.poner_peinado(Jugador3D.peinado_de(id))
	if not personajes_con_sombra_sol:
		_sin_sombra_sol(p)
	return p


## Etapa 8: cambian los que están en la cancha (un cambio, un expulsado que
## termina de salir). Los que siguen conservan su modelo y lo que venían
## haciendo; solo se arma el modelo del que entra. Armar la vista entera
## (estadio y 22 modelos) trababa un cuadro 148 ms en el teléfono
## (motor_v2/banco_etapa8.gd). Hace falta `ids` para saber quién es quién.
func recomponer(equipos_n: PackedInt32Array, arqueros_n: PackedInt32Array, ids_n: PackedInt32Array, ropa_n: Array) -> void:
	var viejo := {}
	for i in mini(ids.size(), _jugadores.size()):
		viejo[ids[i]] = i
	var era_arquero := arqueros.duplicate()
	var jugadores_v := _jugadores.duplicate()
	var andar_v := _andar.duplicate()
	var una_vez_v := _una_vez.duplicate()
	var ciclos_v := _ciclos.duplicate()
	var sentido_v := _sentido.duplicate()
	var rumbo_v := _rumbo_modelo.duplicate()
	var v_previa_v := _v_previa.duplicate()
	var desacelera_v := _desacelera.duplicate()
	var adelante_v := _adelante.duplicate()
	equipos = equipos_n
	arqueros = arqueros_n
	ids = ids_n
	ropa = ropa_n
	var n := _cantidad()
	_jugadores.clear()
	_andar.clear()
	_una_vez.clear()
	for lista in [_ciclos, _sentido, _rumbo_modelo, _v_previa, _desacelera, _adelante, _sin_fundido]:
		lista.resize(n)
		lista.fill(0)
	_corrido.clear()
	_sin_rumbo.clear()
	var usados := {}
	for i in n:
		var k: int = viejo.get(ids[i], -1)
		# El que pasa a ser arquero (o deja de serlo) cambia de modelo.
		if k >= 0 and (k < era_arquero.size() and era_arquero[k] == 1) == _es_arquero(i):
			usados[k] = true
			_jugadores.append(jugadores_v[k])
			_andar.append(andar_v[k])
			_una_vez.append(una_vez_v[k])
			_ciclos[i] = ciclos_v[k]
			_sentido[i] = sentido_v[k]
			_rumbo_modelo[i] = rumbo_v[k]
			_v_previa[i] = v_previa_v[k]
			_desacelera[i] = desacelera_v[k]
			_adelante[i] = adelante_v[k]
		else:
			_jugadores.append(_crear_jugador(i, 0))
			_andar.append("Respirar")
			_una_vez.append({})
			# Aparece ya mirando adonde mira: sin el giro desde el rumbo 0.
			_sin_fundido[i] = 1
			_sin_rumbo[i] = true
	for k in jugadores_v.size():
		if not usados.has(k):
			(jugadores_v[k] as Node).queue_free()
	if _manchas != null:
		_manchas.queue_free()
		_manchas = SombrasRedondas.new(n + 1)
		_mundo_3d.add_child(_manchas)


func _cantidad() -> int:
	return MundoV2.JUGADORES if equipos.is_empty() else equipos.size()


func _equipo(i: int) -> int:
	return (0 if i < 11 else 1) if equipos.is_empty() else equipos[i]


func _es_arquero(i: int) -> bool:
	if not arqueros.is_empty():
		return i < arqueros.size() and arqueros[i] == 1
	return equipos.is_empty() and i % 11 == 0


## Las líneas de un rectángulo en el pasto (el cuadrado del rondo, la
## canchita del partidito), centrado en el medio de la cancha.
func marcar_rectangulo(medio_x: float, medio_z: float) -> void:
	var material := Materiales3D.toon(Color.WHITE)
	for lado in [[Vector3(0.0, 0.0, -medio_z), Vector2(medio_x * 2.0, 0.08)],
			[Vector3(0.0, 0.0, medio_z), Vector2(medio_x * 2.0, 0.08)],
			[Vector3(-medio_x, 0.0, 0.0), Vector2(0.08, medio_z * 2.0)],
			[Vector3(medio_x, 0.0, 0.0), Vector2(0.08, medio_z * 2.0)]]:
		var linea := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = lado[1]
		linea.mesh = plano
		linea.position = lado[0] + Vector3(0.0, 0.012, 0.0)
		linea.material_override = material
		linea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mundo_3d.add_child(linea)


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


## Sigue donde estaba `otra` (la cámara, el árbitro y el corte ya visto): el
## laboratorio de reglas arma la vista de nuevo cuando alguien entra o se va.
func seguir_de(otra: VistaV2) -> void:
	_centro = otra._centro
	_acercamiento_actual = otra._acercamiento_actual
	_corte_visto = otra._corte_visto
	if otra.arbitro != null:
		arbitro = ArbitroV2.new(_mundo_3d)
		arbitro.copiar_de(otra.arbitro)


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
## ninguna, anda según su velocidad real. Lo que busca cada cuerpo (rapidez,
## metros para parar, giro que falta) elige Arranque, Frenada y los giros.
## La cámara sigue a `foco`.
func dibujar_cuerpos(c: Object, alfa: float, delta: float, foco: Vector2) -> void:
	_poner_cuerpos(c, alfa, delta)
	_pelota.visible = false
	_mover_camara(foco, delta)


## La canchita de la etapa 3 (CanchitaV2Nativa): los cuerpos como
## dibujar_cuerpos, y la pelota con su giro. La cámara sigue a la pelota.
func dibujar_canchita(c: Object, alfa: float, delta: float) -> void:
	# Etapa 6: el corte al saque después de una tarjeta. La cámara salta a la
	# pelota y las poses no se funden con las de antes del corte.
	if c.has_method("get_corte") and c.get_corte() != _corte_visto:
		_corte_visto = c.get_corte()
		if _corte_visto >= 0:
			var en: Vector3 = c.get_pelota_pos()
			_centro = Vector2(en.x, en.z)
			_acercamiento_actual = acercamiento
			_sin_fundido.fill(1)
			for i in _una_vez.size():
				_una_vez[i] = {}
	# La pelota primero: los pies van adonde quedó dibujada.
	_pelota.visible = true
	dibujar_pelota(c.get_pelota_previa(), c.get_pelota_pos(), alfa, delta, c.get_pelota_giro())
	_ajustar_pies = true
	_poner_cuerpos(c, alfa, delta)
	_ajustar_pies = false
	# Etapa 6: el lateral va entre las manos del que saca hasta que la suelta.
	# El motor la lleva en el punto donde sale; dibujada ahí, las manos subían
	# sin la pelota.
	if c.has_method("get_tarjeta"):
		if arbitro == null:
			arbitro = ArbitroV2.new(_mundo_3d)
		var bola: Vector3 = c.get_pelota_pos()
		arbitro.dibujar(c.get_paso(), Vector2(bola.x, bola.z), c.get_tarjeta(), delta, c.get_parada())
	# En las manos (el lateral o el arquero que la agarró): se dibuja entre las
	# manos del modelo. El motor la lleva en un punto fijo delante del pecho;
	# dibujada ahí, con el arquero tirado en el piso la pelota flotaba.
	var saca: int = c.get_lateral_en_manos() if c.has_method("get_lateral_en_manos") else -1
	if saca < 0 and c.has_method("get_en_manos"):
		saca = c.get_en_manos()
	if saca >= 0 and saca < _cantidad():
		var p3 := _jugadores[saca]
		_pelota.global_position = (DetectorPatinaV2.ancla_de(p3, "Mano_L") + DetectorPatinaV2.ancla_de(p3, "Mano_R")) * 0.5


func _poner_cuerpos(c: Object, alfa: float, delta: float) -> void:
	var acciones := []
	var intenciones := []
	var en_manos: int = c.get_en_manos() if c.has_method("get_en_manos") else -1
	for i in _cantidad():
		# El tiempo de la acción es el del paso actual: se lo lleva al del
		# cuadro con lo que falta del paso (alfa).
		var accion: String = c.get_accion(i)
		if accion == "" and i == en_manos:
			# Etapa 5: el arquero que la agarró la tiene contra el pecho hasta
			# soltarla (el motor la lleva en sus manos).
			acciones.append([ANIM_SOSTIENE, fmod(_tiempo, 2.0)])
		else:
			acciones.append([accion, maxf(0.0, float(c.get_tiempo_accion(i)) - (1.0 - alfa) / 60.0)])
		intenciones.append([c.get_rapidez_buscada(i), c.get_metros_para_parar(i), c.get_giro_pendiente(i),
			c.get_rumbo_buscado(i)])
	_dibujar_jugadores(c.get_pos_previa(), c.get_pos(), c.get_rumbo(), c.get_rapidez(), acciones, alfa, delta,
		intenciones)


## `acciones[i]` = [clip, segundo]; "" o sin entrada = anda.
## `intenciones[i]` = [rapidez buscada, metros para parar, giro que falta,
## rumbo hacia el objetivo]; sin entrada no usa Arranque, Frenada, los giros
## ni la media vuelta.
func _dibujar_jugadores(pos_previa: PackedVector2Array, pos: PackedVector2Array, rumbo: PackedFloat32Array,
		rapidez: PackedFloat32Array, acciones: Array, alfa: float, delta: float, intenciones := []) -> void:
	_tiempo += delta
	for i in _cantidad():
		var p := pos_previa[i].lerp(pos[i], alfa)
		var p3 := _jugadores[i]
		p3.position = Vector3(p.x, 0.0, p.y)
		if _manchas != null:
			_manchas.poner_jugador(i, p3.position)
		var v: float = rapidez[i]
		if not is_equal_approx(v, _v_previa[i]):
			_desacelera[i] = (_v_previa[i] - v) / MundoV2.PASO_SEG
			_v_previa[i] = v
		var accion: String = acciones[i][0] if i < acciones.size() else ""
		var hace_gesto := accion != "" and p3.tiene(accion)
		var paso := pos[i] - pos_previa[i]
		if hace_gesto or v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS or paso.length_squared() < 1e-10:
			_sentido[i] = 0
		else:
			var relativo := wrapf(atan2(paso.x, paso.y) - rumbo[i], -PI, PI)
			_sentido[i] = _sentido_de(_sentido[i], relativo)
			var dando_vuelta: bool = not _una_vez[i].is_empty() and _una_vez[i]["tipo"] == "media_vuelta"
			if _adelante[i] or dando_vuelta:
				# Dando o recién dada la media vuelta: el rumbo del cuerpo
				# todavía gira hacia la carrera, pero el modelo ya mira adelante.
				if not dando_vuelta and absf(relativo) < PI * 0.25:
					_adelante[i] = 0
				else:
					_sentido[i] = 0
		if hace_gesto or v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS:
			_adelante[i] = 0
		if hace_gesto:
			_una_vez[i] = {}
		else:
			_corrido.erase(i)
		var una_vez := [] if hace_gesto else _una_vez_de(i, p3, v, paso, rumbo[i],
			intenciones[i] if i < intenciones.size() else [], delta)
		if una_vez.is_empty() or una_vez[2] == null:
			p3.rotation.y = _rumbo_mostrado(i, rumbo[i], paso, v, hace_gesto, delta)
		else:
			p3.rotation.y = una_vez[2]
		if hace_gesto:
			p3.poner(accion, float(acciones[i][1]), delta)
			if _ajustar_pies and _contacto_pie.has(accion):
				_ajustar_pie(p3, accion, float(acciones[i][1]))
			if _ajustar_pies and _contacto_cuerpo.has(accion):
				_ajustar_cuerpo(i, p3, accion, float(acciones[i][1]))
			p3.poner_cara(p3.cara, Jugador3D.Gesto.NORMAL, _tiempo)
			continue
		var fundido := -1.0 if _sin_fundido[i] else delta
		_sin_fundido[i] = 0
		if not una_vez.is_empty():
			p3.poner(una_vez[0], una_vez[1], fundido)
			p3.poner_cara(p3.cara, Jugador3D.Gesto.NORMAL, _tiempo)
			continue
		var anim := _andar_de(i, v)
		if _adelante[i] == 2:
			# Sale de la media vuelta a Correr en la fase en que la dejó (sin
			# fundido); si va más despacio, pasa a Trotar con el cambio de fase.
			anim = "Correr"
			_adelante[i] = 1
		if _sentido[i] != 0 and anim != VistaCancha3D.ANIM_QUIETO and anim != "Golero_Guardia" \
				and p3.tiene(CLIP_DE_SENTIDO[_sentido[i]]):
			anim = CLIP_DE_SENTIDO[_sentido[i]]
		var actual := p3._anim_actual
		if anim != actual and _metros_ciclo.has(anim) and _metros_ciclo.has(actual):
			# Entre dos loops en cinta cambia recién con un pie en el medio
			# de su apoyo (fase 0 o 0.5): ahí el pie apoyado está debajo
			# del cuerpo en los dos clips y el fundido no lo arrastra.
			var otra := _ciclos[i] + v * delta / float(_metros_ciclo[actual])
			if floorf(_ciclos[i] * 2.0) == floorf(otra * 2.0):
				anim = actual
		var tiempo: float
		if anim == VistaCancha3D.ANIM_QUIETO or anim == "Golero_Guardia":
			tiempo = fposmod(_tiempo + float(i) * 0.37, maxf(p3.duracion(anim), 0.01))
		else:
			_ciclos[i] += v * delta / float(_metros_ciclo.get(anim, VistaCancha3D.METROS_POR_CICLO))
			tiempo = fposmod(_ciclos[i], 1.0) * p3.duracion(anim)
		p3.poner(anim, tiempo, fundido)
		p3.poner_cara(p3.cara, Jugador3D.Gesto.NORMAL, _tiempo)


## Lleva el modelo entero para que la frente o las manos lleguen a la pelota
## en el contacto. Antes del contacto apunta a la pelota de ese cuadro;
## después se queda con lo que se había corrido y lo suelta de a poco.
func _ajustar_cuerpo(i: int, p3: Jugador3D, accion: String, segundo: float) -> void:
	var contacto: float = _contacto_cuerpo[accion][0]
	var peso := smoothstep(contacto - AJUSTE_CUERPO_ANTES_SEG, contacto, segundo) \
		* (1.0 - smoothstep(contacto, contacto + AJUSTE_CUERPO_DESPUES_SEG, segundo))
	if peso <= 0.0:
		return
	if segundo <= contacto or not _corrido.has(i):
		var punto := Vector3.ZERO
		for ancla in _contacto_cuerpo[accion][1]:
			punto += DetectorPatinaV2.ancla_de(p3, ancla)
		punto /= float((_contacto_cuerpo[accion][1] as Array).size())
		var falta := _pelota.position - punto
		var piso := Vector2(falta.x, falta.z).limit_length(AJUSTE_CUERPO_PISO_M)
		_corrido[i] = Vector3(piso.x, clampf(falta.y, 0.0, AJUSTE_CUERPO_SUBE_M), piso.y)
	p3.position += (_corrido[i] as Vector3) * peso


## Lleva el pie del gesto al borde de la pelota cerca del contacto: gira el
## modelo hacia ella (lo que el motor le deja estirar) y dobla la pierna. No
## mueve ni al jugador ni a la pelota.
func _ajustar_pie(p3: Jugador3D, accion: String, segundo: float) -> void:
	var contacto: float = _contacto_pie[accion][0]
	var peso := smoothstep(contacto - AJUSTE_ANTES_SEG, contacto, segundo) \
		* (1.0 - smoothstep(contacto, contacto + AJUSTE_DESPUES_SEG, segundo))
	if peso <= 0.0:
		return
	var bola := _pelota.position
	var hacia := Vector2(bola.x - p3.position.x, bola.z - p3.position.z)
	if hacia.length_squared() > 1e-6:
		var dif := clampf(wrapf(atan2(hacia.x, hacia.y) - p3.rotation.y, -PI, PI), -_giro_alcance, _giro_alcance)
		p3.rotation.y += dif * peso
	var ancla: String = _contacto_pie[accion][1]
	var pie := p3.ancla_de_pose(ancla)
	var radio := MundoV2.RADIO_PELOTA * VistaCancha3D.ESCALA_PELOTA
	var borde := bola + (pie - bola).normalized() * radio if pie.distance_to(bola) > 1e-4 else bola
	p3.llevar_pie(ancla, borde, peso)


## El clip de una vez de este cuadro: [clip, segundo, rumbo del modelo o
## null para el de siempre], o [] si anda con los loops. Cada clip avanza con
## lo que hace el cuerpo, no con el reloj: Arranque y Frenada con los metros
## recorridos (avance_m) y los giros con lo girado (giro_por_cuadro). Así el
## pie apoyado queda quieto aunque el cuerpo vaya a otro ritmo que el clip.
func _una_vez_de(i: int, p3: Jugador3D, v: float, paso: Vector2, rumbo: float, intencion: Array,
		delta: float) -> Array:
	var u: Dictionary = _una_vez[i]
	if u.is_empty():
		if intencion.is_empty():
			return []
		u = _empezar_una_vez(i, p3, v, paso, rumbo, intencion, delta)
		if u.is_empty():
			return []
		_una_vez[i] = u
	var c: Dictionary = _cinta[u["clip"]]
	var avance: Array = c["avance_m"]
	var dur := p3.duracion(u["clip"])
	u["metros"] = float(u["metros"]) + v * delta
	var sigue := true
	match u["tipo"]:
		"arranque":
			if float(u["metros"]) >= float(c["metros"]):
				# Terminó: Correr sigue desde la fase en que quedó el clip.
				_ciclos[i] = float(c["fase_final"]) \
					+ (float(u["metros"]) - float(c["metros"])) / float(_metros_ciclo["Correr"])
				_andar[i] = "Correr"
				_una_vez[i] = {}
				return []
			sigue = _sentido[i] == 0 and float(intencion[0]) >= ARRANQUE_DESDE_MS
			u["t"] = _segundo_de(avance, float(u["metros"]), dur)
		"frenada":
			# Los metros que faltan los da el cuerpo: sumando v·dt el clip
			# llegaba al final 6 cm antes de que el cuerpo parara.
			var parar := float(intencion[1])
			sigue = parar >= 0.0 and parar <= float(c["metros"]) - float(u["desde"]) + 0.3 and _sentido[i] == 0
			# Sigue frenando solo si va a parar: a esta rapidez le alcanzan los
			# metros que faltan. El que sigue a un objetivo que se mueve (una
			# marca, la pelota) lo tiene siempre a menos de un metro y no frena
			# nunca: quedaba con la pose de la frenada mientras el cuerpo
			# avanzaba a 2,4 m/s, el 14% del tiempo del partido, con el pie
			# patinando 1,45 m/s ("juegan en hielo").
			if sigue and parar > v * v / (2.0 * _frenada) + FRENADA_HOLGURA_M:
				sigue = false
			# Si el cerebro le acercó el objetivo, el cuerpo lo pasa frenando:
			# le faltan los metros que da su rapidez, no los del objetivo. Con
			# los del objetivo el clip llegaba al final con el cuerpo a 3 m/s.
			parar = maxf(parar, v * v / (2.0 * _frenada))
			u["metros"] = float(c["metros"]) - clampf(parar, 0.0, float(c["metros"]))
			if v > 0.05:
				var t_nuevo := maxf(float(u["t"]), _segundo_de(avance, float(u["metros"]), dur))
				# El clip no avanza y el cuerpo sí: no está frenando (sigue a
				# un objetivo que se le aleja). Era el 40% de los cuadros de
				# Frenada del partido, con el pie patinando 2,5 m/s.
				var trabado := t_nuevo <= float(u["t"]) + 1e-4 and v > FRENADA_TRABADA_MS
				u["trabado"] = float(u.get("trabado", 0.0)) + delta if trabado else 0.0
				if float(u["trabado"]) > FRENADA_TRABADA_SEG:
					sigue = false
				u["t"] = t_nuevo
			else:
				# Parado: el final (junta los pies) va con el reloj. Si ya tiene
				# que girar, deja el lugar al giro: juntando los pies con el
				# modelo girando, el pie patinaba (laboratorio: 0,48 m/s).
				u["t"] = float(u["t"]) + delta
				sigue = absf(float(intencion[2])) < GIRO_DESDE
		"giro":
			u["girado"] = float(u["girado"]) + wrapf(rumbo - float(u["rumbo_previo"]), -PI, PI)
			u["rumbo_previo"] = rumbo
			var parte := clampf(float(u["girado"]) / float(u["total"]), 0.0, 1.0)
			var por_grados := _segundo_de(u["tabla"], parte * absf(float(c["giro"])), dur)
			# Girado todo, termina de acomodar los pies con el reloj.
			u["t"] = float(u["t"]) + delta if parte >= 1.0 else maxf(float(u["t"]), por_grados)
			# Si ya giró todo y el cuerpo arranca, sale: los pies del final
			# están hechos en el lugar.
			sigue = v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS * 1.5 and (parte < 1.0 or v < 0.05)
		"media_vuelta":
			# Hasta pasar por 0 el cuerpo frena parejo (giro_acel): los metros
			# que le faltan para parar salen de su rapidez. Después suma lo
			# que anda al revés.
			var ida: Vector2 = u["ida"]
			if not u["volvio"] and paso.dot(ida) < 0.0:
				u["volvio"] = true
			var frenado := float(c["metros_frenado"])
			var recorrido: float
			if u["volvio"]:
				u["atras"] = float(u["atras"]) + v * delta
				recorrido = frenado + float(u["atras"])
			else:
				recorrido = frenado - minf(v * v / (2.0 * _giro_acel), frenado)
				# Si el objetivo deja de estar atrás antes de parar, no da la vuelta.
				sigue = intencion.size() > 3 and absf(wrapf(float(intencion[3]) - atan2(ida.x, ida.y), -PI, PI)) \
					> MEDIA_VUELTA_DESDE - deg_to_rad(30.0)
			u["t"] = maxf(float(u["t"]), _segundo_de(c["recorrido_m"], recorrido, dur))
			if float(u["t"]) >= dur:
				var sobra := recorrido - float((c["recorrido_m"] as Array)[-1])
				_terminar_una_vez(i, u, c, dur)
				# Sigue con Correr desde la fase en que quedó el clip, mirando
				# adonde corre.
				_ciclos[i] = float(c["fase_final"]) + maxf(sobra, 0.0) / float(_metros_ciclo["Correr"])
				_andar[i] = "Correr"
				_adelante[i] = 2
				return []
	if not sigue or float(u["t"]) >= dur:
		_terminar_una_vez(i, u, c, dur)
		return []
	var rumbo_fijo: Variant = float(u["rumbo0"]) if u["tipo"] in ["giro", "media_vuelta"] else null
	return [u["clip"], float(u["t"]), rumbo_fijo]


## ¿Empieza un clip de una vez? Devuelve su estado o {}.
func _empezar_una_vez(i: int, p3: Jugador3D, v: float, paso: Vector2, rumbo: float, intencion: Array,
		delta: float) -> Dictionary:
	var buscada := float(intencion[0])
	var parar := float(intencion[1])
	var falta_girar := float(intencion[2])
	var actual := p3._anim_actual
	var quieto := actual == VistaCancha3D.ANIM_QUIETO or actual == "Golero_Guardia"
	var corre := actual in ["Correr", "Trotar"] and _sentido[i] == 0 and paso.length_squared() > 1e-12
	var hacia_objetivo := wrapf(float(intencion[3]) - atan2(paso.x, paso.y), -PI, PI) \
		if corre and intencion.size() > 3 else 0.0
	# Media vuelta: corriendo con el objetivo atrás, a los metros de parar
	# del clip. Entra cuando el paso de Correr pasa por el pie con que
	# empieza el clip (el derecho en _Izq, el izquierdo en _Der): si no,
	# fundía dos pasos distintos. Si ya viene más lento, entra enseguida y
	# el clip empieza más adelante.
	if corre and absf(hacia_objetivo) >= MEDIA_VUELTA_DESDE:
		var falta := v * v / (2.0 * _giro_acel)
		var fase := _ciclos[i]
		var fase_luego := fase + v * delta / float(_metros_ciclo.get(actual, VistaCancha3D.METROS_POR_CICLO))
		for lado in ["Izq", "Der"]:
			var clip: String = "Media_Vuelta_" + lado
			if not (p3.tiene(clip) and _cinta.has(clip)):
				continue
			var c: Dictionary = _cinta[clip]
			var frenado := float(c["metros_frenado"])
			if falta > frenado:
				break
			var f0 := float(c["fase_inicial"])
			var justo := floorf(fase - f0) != floorf(fase_luego - f0)
			if justo or (falta < frenado * 0.5 and (lado == "Izq") == (hacia_objetivo > 0.0)):
				return {"tipo": "media_vuelta", "clip": clip, "metros": 0.0, "rumbo0": _rumbo_modelo[i],
					"ida": paso.normalized(), "volvio": false, "atras": 0.0,
					"t": _segundo_de(c["recorrido_m"], frenado - falta, p3.duracion(clip))}
		return {}
	if v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS and absf(falta_girar) >= GIRO_DESDE:
		var clip := ("Giro_180_" if absf(falta_girar) >= GIRO_180_DESDE else "Giro_90_") \
			+ ("Izq" if falta_girar > 0.0 else "Der")
		if p3.tiene(clip) and _cinta.has(clip):
			var tabla := []
			for g in _cinta[clip]["giro_por_cuadro"]:
				tabla.append(absf(float(g)))
			_sin_fundido[i] = 1
			return {"tipo": "giro", "clip": clip, "t": 0.0, "metros": 0.0, "rumbo0": _rumbo_modelo[i],
				"rumbo_previo": rumbo, "girado": 0.0, "total": falta_girar, "tabla": tabla}
	if quieto and v > 0.05 and buscada >= ARRANQUE_DESDE_MS and paso.length_squared() > 1e-12 \
			and absf(wrapf(atan2(paso.x, paso.y) - rumbo, -PI, PI)) < PI * 0.25 and p3.tiene("Arranque"):
		return {"tipo": "arranque", "clip": "Arranque", "t": 0.0, "metros": 0.0}
	# Frenada: ya frenando (le quedan menos metros que los que tarda en
	# parar) y le quedan a lo sumo los del clip. Si quedan menos, el clip
	# arranca más adelante: el pie apoya donde el clip lo tiene a esos metros.
	# Y está bajando la rapidez: el que persigue a un objetivo que se mueve va
	# siempre a la distancia de frenado de él, sin frenar. Entraba a la Frenada
	# y quedaba con el clip quieto y el pie patinando.
	if corre and absf(hacia_objetivo) < PI / 3.0 and p3.tiene("Frenada") and parar >= 0.0 \
			and parar <= v * v / (2.0 * _frenada) + 0.05 and parar <= float(_cinta["Frenada"]["metros"]) \
			and _desacelera[i] >= 0.5 * _frenada:
		# Los metros que le faltan de verdad (ver "frenada" en _una_vez_de).
		var desde := float(_cinta["Frenada"]["metros"]) - minf(maxf(parar, v * v / (2.0 * _frenada)), float(_cinta["Frenada"]["metros"]))
		return {"tipo": "frenada", "clip": "Frenada", "metros": desde, "desde": desde,
			"t": _segundo_de(_cinta["Frenada"]["avance_m"], desde, p3.duracion("Frenada"))}
	return {}


## Deja al jugador listo para seguir con los loops.
func _terminar_una_vez(i: int, u: Dictionary, c: Dictionary, dur: float) -> void:
	match u["tipo"]:
		"giro", "media_vuelta":
			# El modelo queda girado lo que giró la cadera del clip; de ahí
			# _rumbo_mostrado lo lleva al rumbo del cuerpo.
			var tabla: Array = c["giro_por_cuadro"]
			var k := clampi(roundi(float(u["t"]) / dur * float(tabla.size() - 1)), 0, tabla.size() - 1)
			_rumbo_modelo[i] = wrapf(float(u["rumbo0"]) + deg_to_rad(float(tabla[k])), -PI, PI)
			_andar[i] = VistaCancha3D.ANIM_QUIETO
			_sin_fundido[i] = 1
		"frenada":
			_andar[i] = VistaCancha3D.ANIM_QUIETO
	_una_vez[i] = {}


## El segundo del clip en que `tabla` (un valor por cuadro, que no baja)
## llega a `valor`, interpolando entre cuadros.
static func _segundo_de(tabla: Array, valor: float, duracion: float) -> float:
	var por_cuadro := duracion / float(maxi(tabla.size() - 1, 1))
	for k in range(1, tabla.size()):
		var b := float(tabla[k])
		if b >= valor:
			var a := float(tabla[k - 1])
			return (float(k - 1) + (clampf((valor - a) / (b - a), 0.0, 1.0) if b > a else 1.0)) * por_cuadro
	return duracion


## Adelante (0), a su izquierda (1), a su derecha (-1) o de espaldas (2),
## según el ángulo `relativo` entre la marcha y el rumbo. Sigue en el que
## estaba mientras no se pase HISTERESIS_SENTIDO del borde.
static func _sentido_de(actual: int, relativo: float) -> int:
	if absf(wrapf(relativo - float(ANGULO_DE_SENTIDO[actual]), -PI, PI)) <= PI * 0.25 + HISTERESIS_SENTIDO:
		return actual
	var k := roundi(relativo / (PI * 0.5))
	return 2 if absi(k) == 2 else k


## El rumbo del modelo. Andando, el clip avanza justo hacia donde va el
## cuerpo: el modelo gira lo que falta (a lo sumo 45° más la histéresis)
## para que el pie apoyado no patine de costado. Llega girando, no de golpe.
func _rumbo_mostrado(i: int, rumbo: float, paso: Vector2, v: float, hace_gesto: bool, delta: float) -> float:
	var meta := rumbo
	if not hace_gesto and v >= VistaCancha3D.VELOCIDAD_PARA_PIERNAS and paso.length_squared() > 1e-10:
		meta = atan2(paso.x, paso.y) - float(ANGULO_DE_SENTIDO[_sentido[i]])
	if _sin_rumbo.has(i):
		_sin_rumbo.erase(i)
		_rumbo_modelo[i] = meta
		return meta
	if not _rumbo_listo:
		_rumbo_modelo[i] = meta
		_rumbo_listo = i == _cantidad() - 1
		return meta
	var dif := wrapf(meta - _rumbo_modelo[i], -PI, PI)
	var tope := GIRO_MODELO_RAD_S * delta
	_rumbo_modelo[i] = wrapf(_rumbo_modelo[i] + clampf(dif, -tope, tope), -PI, PI)
	return _rumbo_modelo[i]


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
		_manchas.poner_pelota(_cantidad(), bola)
	_mover_camara(Vector2(bola.x, bola.z), delta)


func _andar_de(i: int, v: float) -> String:
	if _es_arquero(i):
		return "Correr" if v > VistaCancha3D.ARQUERO_CORRE_MS else "Golero_Guardia"
	var nuevo := VistaCancha3D._andar(_andar[i], v)
	if v < VistaCancha3D.VELOCIDAD_PARA_PIERNAS:
		nuevo = VistaCancha3D.ANIM_QUIETO
	elif nuevo == VistaCancha3D.ANIM_QUIETO:
		nuevo = "Caminar"
	_andar[i] = nuevo
	return nuevo


## Etapa 8: el rectángulo de cancha (metros) que muestra la cámara, para el
## minimapa. Es el ancho que encuadra _mover_camara, con el alto que le toca
## por la forma de la pantalla.
func encuadre_metros() -> Rect2:
	var ancho_m: float = maxf(size.x, 1.0) / CamaraPartido.PX_POR_METRO_BASE / CamaraPartido3D.ACERCAMIENTO 		/ maxf(_acercamiento_actual, 0.01)
	var alto_m := ancho_m * maxf(size.y, 1.0) / maxf(size.x, 1.0)
	return Rect2(_centro - Vector2(ancho_m, alto_m) * 0.5, Vector2(ancho_m, alto_m))


## El encuadre de VistaCancha3D (_mover_camara) con el zoom base, siguiendo
## a la pelota con suavizado.
func _mover_camara(bola: Vector2, delta: float) -> void:
	var destino: Vector2 = foco if foco != null else bola
	_centro = _centro.lerp(destino, clampf(delta * CamaraPartido.SUAVIZADO, 0.0, 1.0))
	_acercamiento_actual = lerpf(_acercamiento_actual, acercamiento, clampf(delta * CamaraPartido.SUAVIZADO, 0.0, 1.0))
	var ancho_m: float = maxf(size.x, 1.0) / CamaraPartido.PX_POR_METRO_BASE / CamaraPartido3D.ACERCAMIENTO \
		/ _acercamiento_actual
	var distancia := ancho_m * 0.5 / tan(deg_to_rad(VistaCancha3D.FOV_HORIZONTAL) * 0.5)
	var limite_x: float = ProyeccionPartido.MEDIO_LARGO + CamaraPartido.MARGEN_M - ancho_m * 0.5
	var limite_y: float = ProyeccionPartido.MEDIO_ANCHO - CamaraPartido3D.MARGEN_LATERAL_M
	var c := Vector2(clampf(_centro.x, -limite_x, limite_x), clampf(_centro.y, -limite_y, limite_y))
	var objetivo := Vector3(c.x, 0.0, c.y)
	var e := deg_to_rad(VistaCancha3D.ELEVACION_CAMARA)
	_camara.position = objetivo + Vector3(0.0, sin(e), cos(e)) * distancia
	_camara.look_at(objetivo, Vector3.UP)
