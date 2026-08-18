class_name VistaPartido
extends Control

## Reproduce los fotogramas que devuelve MotorEspacial. Es la única pieza
## de /match que sabe del motor: recibe la lista de fotogramas y la
## convierte en entidades para VistaCancha y Minimapa, que siguen sin
## saber nada de simulación.

signal terminado

## Ticks de juego por segundo real a x1. El motor simula a 0.25s por tick,
## así que 4 ticks/seg es TIEMPO REAL de fútbol: un pase tarda lo que
## tarda un pase.
const TICKS_POR_SEGUNDO := 4.0

## A 4 fotogramas por segundo hay que interpolar o se ve a saltos. Pero si
## dos fotogramas seguidos ponen a alguien más lejos que esto, es un salto
## de verdad (saque del medio tras un gol, un cambio, un tiro libre que
## reubica gente) y ahí se corta seco en vez de deslizarlo por la cancha.
const SALTO_MAXIMO_M := 12.0

var vista: VistaCancha
var minimapa: Minimapa
var hud: HudPartido

## clave del motor -> "MC Pérez". El fotograma trae la clave y el rol pero
## NO el apellido, así que la tabla la arma quien conoce los planteles
## (ver construir_nombres).
var nombres: Dictionary = {}

var fotogramas: Array = []
var posicion := 0.0
var velocidad := 1.0
var pausado := false

var color_local := Color.WHITE
var color_visitante := Color.WHITE
var _terminado := false

## Cuántos segundos REALES se sostiene el relato según la importancia del
## momento. En segundos reales y no en ticks, así el texto se puede leer
## igual a x1 que a x16 — a x16 el partido vuela pero el ojo no.
const SEG_RELATO := {
	RelatoPartido.MENOR: 2.0, RelatoPartido.NOTABLE: 3.0, RelatoPartido.MAXIMA: 4.0,
}

## El festejo FRENA la reproducción. Es la única pausa automática del
## partido y es a propósito: un gol tiene que cortar el ritmo, no pasar
## de largo. Se divide por la velocidad elegida, así a x16 dura un
## instante y no interrumpe a quien está apurando el partido.
const SEG_FESTEJO := 2.2

## Cuánto flota una tarjeta sobre el infractor, en segundos reales.
const SEG_TARJETA := 2.6

var _relato_restante := 0.0
var _relato_total := 1.0
var _festejo_restante := 0.0
var _festejo_total := 1.0
var _tarjetas: Array = []          # [{"clave": int, "restante": float}]
var _idx_narrado := 0
## Fotograma que se sostiene durante el festejo, o -1. Es el ANTERIOR al
## del gol: el motor manda a todos al círculo central en el mismo tick en
## que valida el gol, así que congelar el fotograma del gol muestra el
## saque del medio. Uno atrás todavía tiene la jugada.
var _idx_congelado := -1
## El marcador YA con el gol adentro. El fotograma congelado es el de
## antes, así que si el tanteador saliera de ahí el cartel diría "¡GOL!"
## arriba de un 0-0.
var _goles_festejo = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vista = VistaCancha.new()
	vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vista)
	minimapa = Minimapa.new()
	add_child(minimapa)
	hud = HudPartido.new()
	add_child(hud)
	hud.velocidad_pedida.connect(func(v: float): velocidad = v)
	hud.pausa_pedida.connect(func():
		pausado = not pausado
		hud.marcar_pausa(pausado))
	hud.saltar_pedido.connect(saltar_al_final)
	set_process(true)


## Tabla clave -> "ROL Apellido" para el cartel de quién tiene la pelota.
## Se arma acá y no en el motor porque es un dato de presentación: el motor
## no tiene por qué saber que alguien va a mostrar apellidos.
static func construir_nombres(local: Team, visitante: Team) -> Dictionary:
	var tabla := {}
	for par in [[local, true], [visitante, false]]:
		var equipo: Team = par[0]
		for j in equipo.todos_los_jugadores():
			tabla[MotorEspacial.clave_de(j["id"], par[1])] = "%s %s" % [j["posicion"], j["apellido"]]
	return tabla


func iniciar(lista: Array, c_local: Color, c_visitante: Color,
		nombre_local: String = "", nombre_visitante: String = "",
		tabla_nombres: Dictionary = {}, estado_cancha: String = "regular") -> void:
	fotogramas = lista
	color_local = c_local
	color_visitante = c_visitante
	nombres = tabla_nombres
	vista.estado_cancha = estado_cancha
	hud.nombre_local = nombre_local
	hud.nombre_visitante = nombre_visitante
	hud.color_local = c_local
	hud.color_visitante = c_visitante
	posicion = 0.0
	pausado = false
	_terminado = false
	_relato_restante = 0.0
	_festejo_restante = 0.0
	_idx_congelado = -1
	_goles_festejo = null
	_tarjetas.clear()
	_idx_narrado = 0
	hud.relato = ""
	hud.festejo = 0.0
	if not fotogramas.is_empty():
		_mostrar(0, 0.0)
		var f: Dictionary = fotogramas[0]
		vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), size)


## Salta al final SIN renderizar los fotogramas del medio: es un salto de
## índice, no una reproducción acelerada.
func saltar_al_final() -> void:
	if fotogramas.is_empty():
		_finalizar()
		return
	# Saltar no narra ni festeja: se va al resultado, no se reproduce en
	# acelerado. Por eso _idx_narrado se adelanta sin pasar por _narrar.
	posicion = float(fotogramas.size() - 1)
	_idx_narrado = fotogramas.size() - 1
	_relato_restante = 0.0
	_festejo_restante = 0.0
	_idx_congelado = -1
	_goles_festejo = null
	_tarjetas.clear()
	_mostrar(fotogramas.size() - 1, 0.0)
	_finalizar()


func _process(delta: float) -> void:
	# Con el panel oculto el partido NO corre. Godot sigue llamando
	# _process en un nodo invisible, así que sin esto el partido seguía
	# jugándose de fondo mientras el usuario está en otra pantalla y al
	# volver ya estaba terminado.
	if not is_visible_in_tree() or _terminado or fotogramas.is_empty():
		return
	if pausado:
		return
	# En pausa no corre NADA, ni el relato: si alguien para el partido es
	# justamente para leer lo que pasó. El festejo sí congela la
	# reproducción pero deja correr los efectos, que es lo que le permite
	# terminarse solo.
	_avanzar_efectos(delta)
	if _festejo_restante <= 0.0:
		posicion += delta * TICKS_POR_SEGUNDO * velocidad
	var idx: int = mini(int(posicion), fotogramas.size() - 1)
	while _idx_narrado < idx:
		_idx_narrado += 1
		_narrar(_idx_narrado)
	if _idx_congelado != -1:
		idx = _idx_congelado
	_mostrar(idx, 0.0 if _idx_congelado != -1 else posicion - float(idx))
	_seguir_camara(idx, delta)
	if int(posicion) >= fotogramas.size() - 1:
		_finalizar()


## Los temporizadores de relato, festejo y tarjetas corren en segundos
## REALES, sin multiplicar por la velocidad: son tiempo de lectura, no
## tiempo de partido.
func _avanzar_efectos(delta: float) -> void:
	if _relato_restante > 0.0:
		_relato_restante = maxf(_relato_restante - delta, 0.0)
		# Se desvanece solo en el último tramo, no durante toda la vida.
		hud.relato_alfa = clampf(_relato_restante / (_relato_total * 0.3), 0.0, 1.0)
		if _relato_restante == 0.0:
			hud.relato = ""
	if _festejo_restante > 0.0:
		_festejo_restante = maxf(_festejo_restante - delta, 0.0)
		if _festejo_restante == 0.0:
			_idx_congelado = -1
			_goles_festejo = null
	hud.festejo = _festejo_restante / _festejo_total if _festejo_restante > 0.0 else 0.0
	vista.euforia = hud.festejo
	var vivas: Array = []
	for t in _tarjetas:
		t["restante"] = float(t["restante"]) - delta
		if t["restante"] > 0.0:
			vivas.append(t)
	_tarjetas = vivas


## Mira los eventos del fotograma `idx` y prende lo que corresponda. Un
## solo tick puede traer varios eventos (una entrada fuerte emite tarjeta
## y falta), así que gana el más importante para el relato, pero la
## tarjeta se registra igual aunque no sea la que se narra.
func _narrar(idx: int) -> void:
	var lista: Array = fotogramas[idx].get("eventos", [])
	if lista.is_empty():
		return
	var mejor = null
	var mejor_peso := RelatoPartido.NADA
	for ev in lista:
		if str(ev.get("tipo", "")) == "tarjeta":
			_encolar_tarjeta(ev)
		var peso := RelatoPartido.importancia(ev)
		if peso > mejor_peso:
			mejor_peso = peso
			mejor = ev
	if mejor == null:
		return
	var texto := RelatoPartido.linea(_con_clave(mejor), nombres)
	if texto == "":
		return
	hud.relato = texto
	_relato_total = float(SEG_RELATO.get(mejor_peso, 2.0))
	_relato_restante = _relato_total
	hud.relato_alfa = 1.0
	if _es_gol(mejor):
		_festejo_total = maxf(SEG_FESTEJO / maxf(velocidad, 1.0), 0.15)
		_festejo_restante = _festejo_total
		_idx_congelado = maxi(idx - 1, 0)
		_goles_festejo = fotogramas[idx]["goles"]


static func _es_gol(ev: Dictionary) -> bool:
	return str(ev.get("resultado", "")) == "gol" and str(ev.get("tipo", "")) in ["tiro_puerta", "penal"]


func _encolar_tarjeta(ev: Dictionary) -> void:
	var clave := int(_con_clave(ev).get("clave", -1))
	if clave == -1:
		return
	_tarjetas.append({
		"clave": clave, "restante": SEG_TARJETA,
		"roja": str(ev.get("resultado", "")) != "amarilla",
	})


## Las tarjetas las emite MatchEngine, que es compartido con el motor
## abstracto y no sabe de claves espaciales: trae `jugador_id` y el
## NOMBRE del equipo. Acá se traduce a la clave, que es lo que usan la
## tabla de apellidos y las posiciones del fotograma.
func _con_clave(ev: Dictionary) -> Dictionary:
	if ev.has("clave") or not ev.has("jugador_id"):
		return ev
	var copia := ev.duplicate()
	copia["clave"] = MotorEspacial.clave_de(
		int(ev["jugador_id"]), str(ev.get("equipo", "")) == hud.nombre_local)
	return copia


func _finalizar() -> void:
	if _terminado:
		return
	_terminado = true
	terminado.emit()


## Arma las entidades del fotograma `idx` mezclado con el siguiente según
## `t`, y se las pasa a la cancha y al minimapa.
func _mostrar(idx: int, t: float) -> void:
	var a: Dictionary = fotogramas[idx]
	var b = fotogramas[idx + 1] if idx + 1 < fotogramas.size() else null
	var destino := {}
	if b != null and t > 0.0:
		for j in b["jugadores"]:
			destino[j["id"]] = j

	var acciones := _acciones_activas(idx)
	var pa: Dictionary = a["pelota"]
	var pos_pelota := Vector2(pa["x"], pa["y"])
	var z: float = float(pa.get("z", 0.0))
	if b != null and t > 0.0:
		var pb: Dictionary = b["pelota"]
		pos_pelota = _mezclar(pos_pelota, Vector2(pb["x"], pb["y"]), t)
		z = lerpf(z, float(pb.get("z", 0.0)), t)

	var ents: Array = []
	for j in a["jugadores"]:
		var p := Vector2(j["x"], j["y"])
		var avance := Vector2.ZERO
		if not destino.is_empty() and destino.has(j["id"]):
			var siguiente := Vector2(destino[j["id"]]["x"], destino[j["id"]]["y"])
			p = _mezclar(p, siguiente, t)
			avance = siguiente - Vector2(j["x"], j["y"])
		elif b != null:
			for jb in b["jugadores"]:
				if jb["id"] == j["id"]:
					avance = Vector2(jb["x"], jb["y"]) - Vector2(j["x"], j["y"])
					break
		# Lo que el jugador HIZO manda sobre lo que se mueve: si está
		# pateando o tirándose, esa pose gana a la de correr.
		var pose: String = str(acciones.get(j["id"], ""))
		if pose.is_empty():
			pose = _pose(avance, idx)
		var ent := {
			"tipo": "jugador", "z": 0.0, "pos": p,
			"color": color_local if j["equipo_local"] else color_visitante,
			"direccion": _direccion(avance),
			"pose": pose,
		}
		if pose == SpritesPartido.VUELA:
			# Se tira hacia donde está la pelota, medido EN PANTALLA: el
			# sprite del arquero volando es horizontal, así que lo único
			# que puede expresar es a qué costado se estiró.
			ent["espejo"] = ProyeccionPartido.direccion_pantalla(pos_pelota - p).x < 0.0
		ents.append(ent)

	ents.append({"tipo": "pelota", "color": Color.WHITE, "z": z, "pos": pos_pelota})

	# Las tarjetas siguen al infractor: se guardan por clave, no por
	# posición, así el cartelito acompaña al que la vio mientras camina.
	var flotando: Array = []
	for tar in _tarjetas:
		for j in a["jugadores"]:
			if j["id"] == tar["clave"]:
				flotando.append({
					"pos": Vector2(j["x"], j["y"]), "roja": tar["roja"],
					"avance": 1.0 - float(tar["restante"]) / SEG_TARJETA,
				})
				break
	vista.tarjetas = flotando

	vista.entidades = ents
	vista.queue_redraw()

	minimapa.position = size - minimapa.size - Vector2.ONE * Minimapa.MARGEN_PX
	minimapa.entidades = ents
	minimapa.encuadre = vista.camara.encuadre_metros(size)
	minimapa.queue_redraw()

	var g: Dictionary = _goles_festejo if _goles_festejo != null else a["goles"]
	hud.goles_local = int(g["home"])
	hud.goles_visitante = int(g["away"])
	hud.minuto = int(a["minuto"])
	var poseedor_id := int(pa.get("poseedor_id", -1))
	hud.poseedor = str(nombres.get(poseedor_id, "")) if poseedor_id != -1 else ""
	hud.queue_redraw()


## Velocidad (m/s) a partir de la cual se considera que está corriendo y
## no parado. Por debajo se queda en la pose quieta y no vibra.
const VELOCIDAD_CORRIENDO := 1.6

## Cada cuántos ticks alterna la zancada. A 4 ticks/seg, 2 ticks es un
## paso cada medio segundo: se lee sin marearse.
const TICKS_POR_ZANCADA := 2


## Cuántos ticks se sostiene cada acción. El motor la registra en UN tick
## (el instante en que patea o se tira), pero un tick son 250 ms: mostrar
## la pose un solo fotograma la deja como un parpadeo. Tirarse al piso
## dura más que pegarle a la pelota, y el arquero queda tendido.
const DURACION_ACCION := {
	MotorEspacial.ACCION_PATEA: 2,
	MotorEspacial.ACCION_BARRIDA: 3,
	MotorEspacial.ACCION_VUELA: 4,
}

const POSE_DE_ACCION := {
	MotorEspacial.ACCION_PATEA: SpritesPartido.PATEA,
	MotorEspacial.ACCION_BARRIDA: SpritesPartido.BARRIDA,
	MotorEspacial.ACCION_VUELA: SpritesPartido.VUELA,
}


## clave -> pose, para las acciones que siguen vigentes en el fotograma
## `idx`. Se calcula mirando hacia atrás en vez de guardar estado, así
## funciona igual reproduciendo, pausando o saltando a cualquier punto.
func _acciones_activas(idx: int) -> Dictionary:
	var activas := {}
	var maximo := 0
	for d in DURACION_ACCION.values():
		maximo = maxi(maximo, int(d))
	for i in range(maxi(0, idx - maximo + 1), idx + 1):
		for a in fotogramas[i].get("acciones", []):
			var accion := str(a["accion"])
			if idx - i < int(DURACION_ACCION.get(accion, 1)):
				activas[a["clave"]] = POSE_DE_ACCION.get(accion, SpritesPartido.QUIETO)
	return activas


static func _direccion(avance: Vector2) -> int:
	if avance.length_squared() < 0.0004:
		return SpritesPartido.ABAJO
	return SpritesPartido.direccion_desde(ProyeccionPartido.direccion_pantalla(avance))


static func _pose(avance: Vector2, idx: int) -> String:
	if avance.length() / MotorEspacial.TICK_SEG < VELOCIDAD_CORRIENDO:
		return SpritesPartido.QUIETO
	return SpritesPartido.CORRE_A if (idx / TICKS_POR_ZANCADA) % 2 == 0 else SpritesPartido.CORRE_B


static func _mezclar(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a if a.distance_squared_to(b) > SALTO_MAXIMO_M * SALTO_MAXIMO_M else a.lerp(b, t)


## La cámara sigue la pelota. La velocidad se estima con el fotograma
## siguiente, que es lo que le permite anticipar hacia dónde va la jugada.
func _seguir_camara(idx: int, delta: float) -> void:
	var pa: Dictionary = fotogramas[idx]["pelota"]
	var actual := Vector2(pa["x"], pa["y"])
	var vel := Vector2.ZERO
	if idx + 1 < fotogramas.size():
		var pb: Dictionary = fotogramas[idx + 1]["pelota"]
		var d := Vector2(pb["x"], pb["y"]) - actual
		if d.length() < SALTO_MAXIMO_M:
			vel = d / MotorEspacial.TICK_SEG
	var en_area: bool = absf(actual.x) > ProyeccionPartido.MEDIO_LARGO - 16.5
	vista.camara.fijar_encuadre(en_area, _festejo_restante > 0.0)
	vista.camara.seguir(actual, vel, size, delta)
