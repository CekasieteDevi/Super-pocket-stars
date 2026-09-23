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
const TICKS_POR_SEGUNDO := 1.0 / MotorEspacial.TICK_SEG

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
var _coreografia := CoreografiaPartido.new()
var _recorridas_oficiales: Dictionary = {}
var posicion := 0.0
var velocidad := 1.0
var pausado := false

var color_local := Color.WHITE
var color_visitante := Color.WHITE
var color_short_local: Color = Color.TRANSPARENT
var color_short_visitante: Color = Color.TRANSPARENT
## El arquero va de otro color, como en la cancha: con los 22 de dos
## colores no había forma de saber cuál de los del fondo era el arquero.
var color_arquero_local := Color.WHITE
var color_arquero_visitante := Color.WHITE
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

## Cuánto dura el parpadeo negro del corte de juego. Corto a propósito:
## es un golpe, no una transición.
const SEG_PARPADEO := 0.35

var _relato_restante := 0.0
var _relato_total := 1.0
var _festejo_restante := 0.0
var _festejo_total := 1.0
var _idx_narrado := 0
var _parpadeo_restante := 0.0
## Fotograma que se sostiene durante el festejo, o -1. Es EL del gol: el
## motor deja la pelota en la red y recién unos ticks después manda a
## todos al círculo central (ver MotorEspacial._festejar_gol), así que ese
## fotograma tiene la pelota adentro del arco, a los 22 donde estaban y el
## marcador ya actualizado.
var _idx_congelado := -1
var _idx_corte_camara := -1

## Cuántos van al banderín, goleador incluido. Con dos parece un abrazo
## casual; con cuatro ya se lee como el grupo que sale a festejar.
const FESTEJANTES := 4

## Tope de la carrera al banderín, en segundos de partido. Un gol desde
## afuera del área deja al goleador a 40 m del córner: a velocidad punta
## son casi seis segundos y el festejo tapaba el partido. Pasado el tope,
## corren más rápido en vez de tardar más. Con 3,2 s un goleador a 36 m
## corría a 11 m/s y se veía acelerado; con 4 s queda en 9 m/s.
const SEG_CARRERA_MAX := 4.0

## Cuánto saltan juntos en el banderín después de llegar.
const SEG_ABRAZO := 1.4

## Cuánto adentro de la cancha queda el goleador respecto del banderín.
## Parado justo en la esquina, el sprite tapa el banderín que se dibuja ahí.
## Con 1,6 m los de atrás del grupo quedaban pisando la línea de fondo en
## el laboratorio "festejo_banderin".
const RETIRO_BANDERIN_M := 2.5

## Lugares de los compañeros alrededor del goleador, en metros hacia el
## centro de la cancha (x hacia el medio, y hacia adentro del lateral).
## Con 1,4 m de separación los cuatro sprites se fundían en una mancha.
## La y va más separada porque la proyección la aplasta a la mitad.
const LUGARES_FESTEJO := [Vector2(2.2, 0.2), Vector2(0.6, 2.8), Vector2(2.8, 3.0), Vector2(4.4, 1.0)]

## clave -> {"desde": Vector2, "hasta": Vector2, "vel": float}. Vacío si el
## gol no arma festejo en el banderín (no se encontró al goleador).
var _festejo_grupo: Dictionary = {}
## Duración del festejo en segundos de PARTIDO. _festejo_total es la misma
## duración ya dividida por la velocidad elegida.
var _festejo_duracion := 0.0
## Clave del que metió el gol: es a quien sigue la cámara en el festejo.
var _festejo_goleador := -1


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
		tabla_nombres: Dictionary = {}, estado_cancha: String = "regular",
		short_local: Color = Color.TRANSPARENT,
		short_visitante: Color = Color.TRANSPARENT,
		abreviacion_local: String = "", abreviacion_visitante: String = "",
		identidad_local: Dictionary = {}, identidad_visitante: Dictionary = {}) -> void:
	fotogramas = lista
	_coreografia.configurar(lista, DURACION_ACCION)
	_recorridas_oficiales = OficialesPartido.preparar(lista)
	color_local = c_local
	color_visitante = c_visitante
	# TRANSPARENT = pantalon por defecto, que es lo que usan los clubes que
	# no eligieron nada (ver match/sprites_partido.gd).
	color_short_local = short_local
	color_short_visitante = short_visitante
	var arqueros := ColoresClub.arqueros(c_local, c_visitante)
	color_arquero_local = arqueros[0]
	color_arquero_visitante = arqueros[1]
	nombres = tabla_nombres
	vista.estado_cancha = estado_cancha
	hud.nombre_local = nombre_local
	hud.nombre_visitante = nombre_visitante
	hud.nombre_local_marcador = abreviacion_local
	hud.nombre_visitante_marcador = abreviacion_visitante
	hud.color_local = c_local
	hud.color_visitante = c_visitante
	hud.configurar_identidades(identidad_local, identidad_visitante)
	posicion = 0.0
	pausado = false
	_terminado = false
	_relato_restante = 0.0
	_festejo_restante = 0.0
	_parpadeo_restante = 0.0
	_idx_congelado = -1
	_festejo_grupo.clear()
	_idx_narrado = 0
	hud.relato = ""
	hud.festejo = 0.0
	if not fotogramas.is_empty():
		_preparar_sprites()
		_mostrar(0, 0.0)
		var f: Dictionary = fotogramas[0]
		vista.camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), size)


## Sólo las poses y apariencias presentes en esta grabación, incluidos cambios.
## El primer uso de una animación no debe crear texturas desde _draw().
func _preparar_sprites() -> void:
	var jugadores := {}
	var cuadros := {}
	for f in fotogramas:
		for j in f["jugadores"]:
			var id := int(j["id"])
			var apariencia := "%d_%s_%d" % [id, str(j.get("rol", "")), int(j.get("numero", 0))]
			jugadores[apariencia] = j
			if not cuadros.has(id):
				cuadros[id] = {}
				for indice in range(8):
					cuadros[id][indice] = true
					cuadros[id][indice + 16] = true
				for indice in [24, 25, 40]:
					cuadros[id][indice] = true
				# Cualquiera puede terminar festejando en el banderín, no
				# solo el que tiene la acción de festejo en la grabación.
				for indice in AtlasJugadores.CLIPS["festeja"]:
					cuadros[id][indice] = true
		for a in f.get("acciones", []):
			var id := int(a["clave"])
			if not cuadros.has(id):
				continue
			for indice in AtlasJugadores.CLIPS.get(str(a["accion"]), []):
				cuadros[id][indice] = true
			if MotorEspacial.es_accion_regate(str(a["accion"])):
				var tipo_regate := MotorEspacial.tipo_regate_de_accion(str(a["accion"]))
				for indice in SpritesPartido.CLIPS_REGATE_ATLAS.get(tipo_regate, []):
					cuadros[id][indice] = true
		var lateral: Dictionary = f.get("lateral_preparacion", {})
		var ejecutor := int(lateral.get("clave", -1))
		if cuadros.has(ejecutor):
			for indice in AtlasJugadores.CLIPS["lateral_prepara"]:
				cuadros[ejecutor][indice] = true
	for apariencia in jugadores:
		var j: Dictionary = jugadores[apariencia]
		var id := int(j["id"])
		var jugador_id := int(j.get("jugador_id", id))
		var pantalon := color_short_local if j["equipo_local"] else color_short_visitante
		for indice in cuadros[id]:
			for espejo in [false, true]:
				AtlasJugadores.textura(indice, _color_de(j), pantalon,
					SpritesPartido.tono_pelo_de(jugador_id), espejo, int(j.get("numero", 0)),
					AtlasJugadores.estilo_de(jugador_id))
	# Los oficiales usan exactamente el atlas PNG de los jugadores. Preparar
	# sus carreras y poses quietas evita crear texturas dentro de _draw().
	var cuadros_oficiales := [24, 25]
	cuadros_oficiales.append_array(AtlasJugadores.CLIPS["lateral_prepara"])
	for indice in range(8):
		cuadros_oficiales.append(indice)
		cuadros_oficiales.append(indice + 16)
	for indice in cuadros_oficiales:
		for espejo in [false, true]:
			AtlasJugadores.textura(indice, OficialesPartido.COLOR_CAMISETA,
				OficialesPartido.COLOR_PANTALON, OficialesPartido.COLOR_PELO,
				espejo, 0, OficialesPartido.PEINADO)
	for i in range(12):
		SpritesPartido.pelota(i)


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
	_parpadeo_restante = 0.0
	_idx_congelado = -1
	_festejo_grupo.clear()
	_mostrar(fotogramas.size() - 1, 0.0)
	# El boton vive dentro del mismo evento de input que cambia la cancha.
	# Emitir terminado en diferido deja que ese evento termine y evita que la
	# UI tape el resumen justo cuando se salta al ultimo fotograma.
	call_deferred("_finalizar")


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
			# El festejo termina en el banderín y la grabación sigue con
			# todos donde estaban al entrar la pelota. Se corta directo al
			# saque del medio, como en la tele: sin el salto, el goleador
			# reaparecía en el área festejando otra vez solo.
			if not _festejo_grupo.is_empty():
				_festejo_grupo.clear()
				_parpadeo_restante = SEG_PARPADEO
				posicion = float(_fin_de_la_pausa(_idx_congelado))
			_idx_congelado = -1
	hud.festejo = _festejo_restante / _festejo_total if _festejo_restante > 0.0 else 0.0
	vista.euforia = hud.festejo
	if _parpadeo_restante > 0.0:
		_parpadeo_restante = maxf(_parpadeo_restante - delta, 0.0)
	hud.parpadeo = _parpadeo_restante / SEG_PARPADEO


## Mira los eventos del fotograma `idx` y prende lo que corresponda. Un
## solo tick puede traer varios eventos (una entrada fuerte emite tarjeta
## y falta), así que gana el más importante para el relato, pero la
## tarjeta se registra igual aunque no sea la que se narra.
func _narrar(idx: int) -> void:
	# El corte en seco lo marca el motor en el fotograma, no se deduce del
	# evento: la falta y el saque del medio lo disparan por caminos
	# distintos y el que manda es el mismo en los dos.
	if bool(fotogramas[idx].get("corte", false)):
		_parpadeo_restante = SEG_PARPADEO
	var lista: Array = fotogramas[idx].get("eventos", [])
	if lista.is_empty():
		return
	var mejor = null
	var mejor_peso := RelatoPartido.NADA
	for ev in lista:
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
		_festejo_goleador = int(_con_clave(mejor).get("clave", -1))
		_festejo_grupo = armar_festejo(fotogramas[idx], _festejo_goleador)
		_festejo_duracion = SEG_FESTEJO
		for clave in _festejo_grupo:
			var g: Dictionary = _festejo_grupo[clave]
			var carrera: float = (g["hasta"] - g["desde"]).length() / float(g["vel"])
			_festejo_duracion = maxf(_festejo_duracion, carrera + SEG_ABRAZO)
		_festejo_total = maxf(_festejo_duracion / maxf(velocidad, 1.0), 0.15)
		_festejo_restante = _festejo_total
		_idx_congelado = idx


## El goleador y sus compañeros más cercanos corren al banderín del córner
## más próximo, del lado del arco donde entró la pelota. Es solo vista: el
## motor no se entera, así que no mueve el balance ni la paridad.
static func armar_festejo(fotograma: Dictionary, clave_goleador: int) -> Dictionary:
	var goleador = null
	for j in fotograma["jugadores"]:
		if int(j["id"]) == clave_goleador:
			goleador = j
			break
	if goleador == null:
		return {}
	var pos_goleador := Vector2(goleador["x"], goleador["y"])
	var pelota := Vector2(fotograma["pelota"]["x"], fotograma["pelota"]["y"])
	# La pelota está en la red: su X dice qué arco. La Y del goleador dice
	# qué banderín le queda más cerca.
	var sx := 1.0 if pelota.x >= 0.0 else -1.0
	var sy := 1.0 if pos_goleador.y >= 0.0 else -1.0
	var hacia_adentro := Vector2(-sx, -sy)
	var destino := Vector2(sx * ProyeccionPartido.MEDIO_LARGO, sy * ProyeccionPartido.MEDIO_ANCHO) \
		+ hacia_adentro * RETIRO_BANDERIN_M

	var companeros: Array = []
	for j in fotograma["jugadores"]:
		if int(j["id"]) == clave_goleador or j["equipo_local"] != goleador["equipo_local"]:
			continue
		if str(j.get("rol", "")) == "ARQ":
			continue
		companeros.append(j)
	companeros.sort_custom(func(a, b):
		return pos_goleador.distance_squared_to(Vector2(a["x"], a["y"])) \
			< pos_goleador.distance_squared_to(Vector2(b["x"], b["y"])))

	# La misma velocidad punta que el motor le da al más rápido: más lento
	# se veía un trote, no la corrida del gol.
	var vel_punta := float(MotorEspacial.pesos()["fisica"]["vel_max"])
	var grupo := {}
	var lugares: Array = [Vector2.ZERO]
	for lugar in LUGARES_FESTEJO:
		lugares.append(Vector2(lugar.x * hacia_adentro.x, lugar.y * hacia_adentro.y))
	var elegidos: Array = [goleador]
	elegidos.append_array(companeros.slice(0, FESTEJANTES - 1))
	for i in elegidos.size():
		var j: Dictionary = elegidos[i]
		var desde := Vector2(j["x"], j["y"])
		var hasta: Vector2 = destino + lugares[i]
		var distancia := desde.distance_to(hasta)
		grupo[int(j["id"])] = {
			"desde": desde, "hasta": hasta,
			"vel": maxf(vel_punta, distancia / SEG_CARRERA_MAX),
		}
	return grupo


## Pisa la entidad de un jugador del grupo con su momento del festejo:
## corriendo al banderín o saltando ya en el banderín.
func _aplicar_festejo(ent: Dictionary, clave: int) -> void:
	var g: Dictionary = _festejo_grupo[clave]
	var tiempo: float = (1.0 - _festejo_restante / _festejo_total) * _festejo_duracion
	var desde: Vector2 = g["desde"]
	var hasta: Vector2 = g["hasta"]
	var distancia := desde.distance_to(hasta)
	var recorrido: float = minf(tiempo * float(g["vel"]), distancia)
	var jugador_id := int(clave)
	if recorrido < distancia:
		ent["pos"] = desde.move_toward(hasta, recorrido)
		ent["pose"] = SpritesPartido.CORRE_A
		ent["accion"] = ""
		ent["z"] = 0.0
		ent["direccion"] = _direccion(hasta - desde)
		# Misma cadencia de piernas que en juego (ver _mostrar).
		ent["fase_animacion"] = recorrido * 2.5 + posmod(jugador_id, 8)
		return
	# Desfasados por clave: los cuatro saltando al mismo tiempo parecían
	# un solo sprite repetido.
	var llegada: float = tiempo - distancia / float(g["vel"]) + posmod(jugador_id, 4) * 0.2
	ent["pos"] = hasta
	ent["pose"] = SpritesPartido.FESTEJA
	ent["accion"] = MotorEspacial.ACCION_FESTEJA
	ent["direccion"] = SpritesPartido.ABAJO
	ent["fase_animacion"] = fposmod(llegada / 0.8, 1.0)
	ent["z"] = absf(sin(llegada * 4.0 * PI)) * 0.45


## Primer fotograma después del gol en que el juego vuelve a correr o se
## reubica a los 22 para el saque. Los fotogramas viejos no traen
## "detenido": ahí no se salta nada.
func _fin_de_la_pausa(idx_gol: int) -> int:
	for i in range(idx_gol + 1, fotogramas.size()):
		var f: Dictionary = fotogramas[i]
		if not f.has("detenido"):
			return idx_gol
		if bool(f.get("corte", false)) or int(f["detenido"]) == 0:
			return i
	return idx_gol


## Dónde mirar durante el festejo: el medio del grupo, no la pelota en la red.
##
## Sigue al GOLEADOR, no al medio del grupo. Con el medio, los compañeros
## que arrancan lejos arrastraban la cámara y el goleador quedaba fuera de
## cuadro mientras se veía a otro corriendo.
func _centro_festejo() -> Vector2:
	var g: Dictionary = _festejo_grupo[_festejo_goleador]
	var tiempo: float = (1.0 - _festejo_restante / _festejo_total) * _festejo_duracion
	return (g["desde"] as Vector2).move_toward(g["hasta"], tiempo * float(g["vel"]))


static func _es_gol(ev: Dictionary) -> bool:
	return str(ev.get("resultado", "")) == "gol" and str(ev.get("tipo", "")) in ["tiro_puerta", "penal"]


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
	# Solo la reubicación corta la interpolación. El silbato de una falta
	# también marca `corte`, pero conserva el movimiento hasta el contacto.
	if b != null and _es_reubicacion(b):
		b = null
	var destino := {}
	if b != null and t > 0.0:
		for j in b["jugadores"]:
			destino[j["id"]] = j

	var acciones := _coreografia.gestos(float(idx) + t, _acciones_activas(idx))
	var pa: Dictionary = a["pelota"]
	var balon_visual := _coreografia.pelota(idx, t)
	var pos_pelota: Vector2 = balon_visual["pos"]
	var z: float = float(balon_visual["z"])
	var offset_pelota: Vector2 = balon_visual["offset_px"]
	var contacto_planificado := bool(balon_visual["corregida"])

	var ents: Array = []
	var pelota_anclada := false
	var pelota_visible := true
	var anclaje_pelota := Vector2.ZERO
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
		var accion: Dictionary = acciones.get(j["id"], {})
		var pose: String = str(accion.get("pose", ""))
		if bool(accion.get("coreografiada", false)):
			pose = str(POSE_DE_ACCION.get(str(accion["accion"]), SpritesPartido.QUIETO))
		# Las posiciones grabadas por el motor son la trayectoria del partido.
		# Reconstruirla con otra fase provocaba saltos al superar un umbral.
		if pose.is_empty():
			var recorrido: float = float(j.get("recorrido", -1.0))
			if recorrido >= 0.0 and destino.has(j["id"]):
				recorrido = lerpf(recorrido, float(destino[j["id"]].get("recorrido", recorrido)), t)
			pose = _pose(avance, idx, recorrido, int(j["id"]))
		# El peinado y el dorsal son lo único que distingue a dos
		# jugadores del mismo equipo: con la camiseta sola, once sprites
		# idénticos corriendo no dejan seguir a nadie en particular.
		var jugador_id := int(j.get("jugador_id", j["id"]))
		var ent := {
			"tipo": "jugador", "z": 0.0, "pos": p,
			"color": _color_de(j),
			"color_short": color_short_local if j["equipo_local"] else color_short_visitante,
			"direccion": _direccion_de_jugador(j, avance),
			"pose": pose,
			"pelo": AtlasJugadores.estilo_de(jugador_id),
			"color_pelo": SpritesPartido.tono_pelo_de(jugador_id),
			"numero": int(j.get("numero", 0)),
		}
		ent["arquero"] = str(j.get("rol", "")) == "ARQ"
		ent["accion"] = str(accion.get("accion", ""))
		var metros: float = float(j.get("recorrido", -1.0))
		if metros >= 0.0 and destino.has(j["id"]):
			metros = lerpf(metros, float(destino[j["id"]].get("recorrido", metros)), t)
		ent["fase_animacion"] = metros * 2.5 + posmod(jugador_id, 8) if metros >= 0.0 else (idx + t) * 2.0
		if not accion.is_empty():
			ent["fase_animacion"] = (float(idx - int(accion["desde"])) + t) / float(DURACION_ACCION.get(ent["accion"], 1))
			if accion.has("fase"):
				ent["fase_animacion"] = float(accion["fase"])
			# La orientaci?n del contacto sigue la pelota, aunque el jugador est? quieto.
			var origen: Dictionary = fotogramas[int(accion["desde"])]
			var balon := Vector2(origen["pelota"]["x"], origen["pelota"]["y"])
			if MotorEspacial.es_accion_regate(ent["accion"]):
				var ejecutor := _jugador_en(origen, int(j["id"]))
				var rumbo := Vector2(float(ejecutor.get("regate_ox", ejecutor.get("ox", 1.0))),
					float(ejecutor.get("regate_oy", ejecutor.get("oy", 0.0))))
				if rumbo.length_squared() < 0.001:
					rumbo = Vector2.RIGHT
				ent["regate_orientacion"] = rumbo.normalized()
				ent["direccion"] = _direccion(rumbo)
				ent["regate_espejo"] = ProyeccionPartido.direccion_pantalla(rumbo).x < 0.0
				ent["fase_animacion"] = MotorEspacial.fase_regate(
					MotorEspacial.tipo_regate_de_accion(ent["accion"]), float(idx - int(accion["desde"])) + t)
			elif ent["accion"] == "chilena":
				# Fijar el remate al arco desde el inicio del gesto. Seguir la
				# pelota entrante o la posicion actual puede invertir la tijera.
				for ejecutor in origen["jugadores"]:
					if int(ejecutor["id"]) == int(j["id"]):
						var hacia_arco := MotorEspacial.arco_rival(bool(ejecutor["equipo_local"])) \
							- Vector2(float(ejecutor["x"]), float(ejecutor["y"]))
						ent["direccion"] = _direccion(hacia_arco)
						# El arte de chilena golpea hacia atras: espejo contrario
						# al de una patada frontal, para todos los peinados.
						ent["espejo"] = ProyeccionPartido.direccion_pantalla(hacia_arco).x > 0.0
						break
			else:
				ent["direccion"] = _direccion(balon - p)
			if accion.has("direccion_contacto"):
				var dir_contacto: Vector2 = accion["direccion_contacto"]
				ent["direccion"] = _direccion(dir_contacto)
				if ent["accion"] == "chilena":
					ent["espejo"] = ProyeccionPartido.direccion_pantalla(dir_contacto).x > 0.0
			if ent["accion"] in ["control_pie", "taco"]:
				# El taco conserva la orientacion corporal; la pelota sale por detras.
				for ejecutor in origen["jugadores"]:
					if int(ejecutor["id"]) == int(j["id"]):
						ent["direccion"] = _direccion(Vector2(float(ejecutor.get("ox", 1.0)), float(ejecutor.get("oy", 0.0))))
						break
			var fase := float(idx - int(accion["desde"])) + t
			if pose in [SpritesPartido.CABECEA, SpritesPartido.CHILENA, SpritesPartido.VOLEA, SpritesPartido.PALOMITA]:
				ent["z"] = sin(clampf(fase / 3.0, 0.0, 1.0) * PI) * 0.65
			elif pose == SpritesPartido.FESTEJA:
				ent["z"] = absf(sin(fase * PI)) * 0.45
			elif pose == SpritesPartido.VUELA:
				ent["z"] = sin(clampf(fase / 4.0, 0.0, 1.0) * PI) * 0.55
			if bool(accion.get("coreografiada", false)):
				ent["z"] = CoreografiaPartido.salto(str(ent["accion"]), float(ent["fase_animacion"]))
		if pose == SpritesPartido.VUELA:
			# Se tira hacia donde estaba la pelota cuando arrancó el
			# vuelo, medido EN PANTALLA: el sprite del arquero volando es
			# horizontal, así que lo único que puede expresar es a qué
			# costado se estiró.
			ent["espejo"] = _lado_del_vuelo(int(j["id"]), int(accion["desde"]))
		var lateral: Dictionary = a.get("lateral_preparacion", {})
		if int(lateral.get("clave", -1)) == int(j["id"]) and int(lateral.get("restante", 99)) <= 3 \
			and not bool(accion.get("coreografiada", false)):
			ent["accion"] = "lateral_prepara"
			ent["pose"] = "lateral_prepara"
			ent["fase_animacion"] = clampf((3.0 - float(lateral["restante"]) + t) / 3.0, 0.0, 0.999)
			ent["direccion"] = _direccion(Vector2(0, -signf(p.y)))
			pos_pelota = p
			z = lerpf(1.1, 2.1, minf(1.0, float(ent["fase_animacion"]) * 2.0))
			var manos := [Vector2(33, 35), Vector2(40, 29), Vector2(32, 10), Vector2(32, 16)]
			var cuadro_manos := mini(3, int(float(ent["fase_animacion"]) * 4.0))
			anclaje_pelota = manos[cuadro_manos] - Vector2(32, 58)
			if int(ent["direccion"]) in [5, 6, 7]:
				anclaje_pelota.x *= -1.0
			pelota_anclada = true
			if contacto_planificado:
				pos_pelota = balon_visual["pos"]
				z = float(balon_visual["z"])
				pelota_anclada = false
		if str(ent["accion"]) in ["pecho", MotorEspacial.ACCION_AGARRA] and int(pa.get("poseedor_id", -1)) == int(j["id"]) \
			and not contacto_planificado:
			pos_pelota = p
			var fase_manos := clampf(float(ent["fase_animacion"]), 0.0, 1.0)
			z = lerpf(1.25, 0.0, fase_manos) if ent["accion"] == "pecho" else 0.0
			anclaje_pelota = Vector2(7, lerpf(-25.0, -19.0, fase_manos))
			if ent["accion"] == MotorEspacial.ACCION_AGARRA and fase_manos >= 0.5:
				# Los cuadros finales ya traen la pelota entre los guantes.
				pelota_visible = false
			if int(ent["direccion"]) in [5, 6, 7]:
				anclaje_pelota.x *= -1.0
			pelota_anclada = true
		if str(ent["accion"]) == "control_pie" and int(pa.get("poseedor_id", -1)) == int(j["id"]) \
			and not contacto_planificado:
			var fase_control := clampf(float(ent["fase_animacion"]), 0.0, 1.0)
			pos_pelota = p
			z = lerpf(0.65, 0.0, fase_control)
			anclaje_pelota = Vector2(lerpf(12.0, 5.0, fase_control), lerpf(-13.0, 0.0, fase_control))
			if int(ent["direccion"]) in [5, 6, 7]:
				anclaje_pelota.x *= -1.0
			pelota_anclada = true
		if str(ent["accion"]) == MotorEspacial.ACCION_AGARRA \
			and int(pa.get("poseedor_id", -1)) == int(j["id"]) and float(ent["fase_animacion"]) >= 0.5:
			pelota_visible = false
		if MotorEspacial.es_accion_regate(str(ent["accion"])) \
				and int(pa.get("poseedor_id", -1)) == int(j["id"]):
			var trayectoria := _trayectoria_regate(
				MotorEspacial.tipo_regate_de_accion(str(ent["accion"])),
				float(ent["fase_animacion"]),
				ent["regate_orientacion"])
			# El ultimo intervalo enlaza con la pelota normal del siguiente tick.
			# Evita que vuelva de golpe al centro del cuerpo al terminar el gesto.
			var edad := float(idx - int(accion["desde"])) + t
			var duracion := float(DURACION_ACCION[ent["accion"]])
			var enlace := smoothstep(0.0, 1.0, clampf(edad - (duracion - 1.0), 0.0, 1.0))
			pos_pelota = (p + Vector2(trayectoria["offset"])).lerp(balon_visual["pos"], enlace)
			z = lerpf(float(trayectoria["altura"]), float(balon_visual["z"]), enlace)
			offset_pelota = Vector2(balon_visual["offset_px"]) * enlace
			pelota_anclada = false
		if _festejo_restante > 0.0 and _festejo_grupo.has(int(j["id"])):
			_aplicar_festejo(ent, int(j["id"]))
		ents.append(ent)

	# Árbitro, dos asistentes y cuarto árbitro. Sus objetivos salen del mismo
	# fotograma que los jugadores para que pausa y velocidades no los desfasen.
	ents.append_array(OficialesPartido.entidades(fotogramas, idx, t, _recorridas_oficiales))

	if pelota_visible:
		ents.append({"tipo": "pelota", "color": Color.WHITE, "z": z, "pos": pos_pelota,
			"giro": int((pos_pelota.x + pos_pelota.y * 0.73 + z) * 3.0),
			"anclada": pelota_anclada, "anclaje_px": anclaje_pelota, "offset_px": offset_pelota})

	vista.entidades = ents
	vista.queue_redraw()

	minimapa.position = size - minimapa.size - Vector2.ONE * Minimapa.MARGEN_PX
	minimapa.entidades = ents
	minimapa.encuadre = vista.camara.encuadre_metros(size)
	minimapa.queue_redraw()

	var g: Dictionary = a["goles"]
	hud.goles_local = int(g["home"])
	hud.goles_visitante = int(g["away"])
	hud.minuto = int(a["minuto"])
	hud.periodo = int(a.get("periodo", 1))
	var marcador_tanda = a.get("tanda", null)
	hud.tanda = marcador_tanda if marcador_tanda is Dictionary else {}
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
	"amague_centro": 3,
	"control_pie": 2, "taco": 2,
	"regate_croqueta": MotorEspacial.DURACION_REGATE_TICKS["croqueta"],
	"regate_bicicleta": MotorEspacial.DURACION_REGATE_TICKS["bicicleta"],
	"regate_globito": MotorEspacial.DURACION_REGATE_TICKS["globito"],
	"regate_elastica": MotorEspacial.DURACION_REGATE_TICKS["elastica"],
	"regate_ruleta": MotorEspacial.DURACION_REGATE_TICKS["ruleta"],
	"pecho": 3, "lateral_manos": 2,
	MotorEspacial.ACCION_AGARRA: 4, MotorEspacial.ACCION_SAQUE_ARCO: 4,
	"bloquea": 3, "cae": 5, "lesionado": 8, "chilena": 5, "volea": 3, "palomita": 4,
	MotorEspacial.ACCION_PATEA: 2,
	MotorEspacial.ACCION_CABECEA: 2,
	MotorEspacial.ACCION_BARRIDA: 3,
	MotorEspacial.ACCION_VUELA: 4,
	# El festejo dura lo que la pelota se queda en la red. Sale de la
	# constante del motor y no de un número acá: si el gol se detiene más
	# tiempo, el goleador tiene que seguir festejando, no plantarse.
	MotorEspacial.ACCION_FESTEJA: MotorEspacial.TICKS_DETENIDO["gol"],
}

const POSE_DE_ACCION := {
	"amague_centro": "amague_centro",
	"control_pie": "control_pie", "taco": "taco",
	"regate_croqueta": "regate_croqueta", "regate_bicicleta": "regate_bicicleta",
	"regate_globito": "regate_globito", "regate_elastica": "regate_elastica",
	"regate_ruleta": "regate_ruleta",
	"pecho": "pecho", "lateral_manos": "lateral_manos",
	MotorEspacial.ACCION_AGARRA: MotorEspacial.ACCION_AGARRA,
	MotorEspacial.ACCION_SAQUE_ARCO: MotorEspacial.ACCION_SAQUE_ARCO,
	"bloquea": SpritesPartido.BLOQUEA, "cae": SpritesPartido.CAE,
	"lesionado": SpritesPartido.CAE,
	"chilena": SpritesPartido.CHILENA, "volea": SpritesPartido.VOLEA,
	MotorEspacial.ACCION_PALOMITA: SpritesPartido.PALOMITA,
	MotorEspacial.ACCION_PATEA: SpritesPartido.PATEA,
	MotorEspacial.ACCION_CABECEA: SpritesPartido.CABECEA,
	MotorEspacial.ACCION_BARRIDA: SpritesPartido.BARRIDA,
	MotorEspacial.ACCION_VUELA: SpritesPartido.VUELA,
	MotorEspacial.ACCION_FESTEJA: SpritesPartido.FESTEJA,
}

## Poses que se ven distintas en su PRIMER fotograma. El remate es el
## único: arma la pierna y recién después impacta. Con la pose de impacto
## sostenida dos ticks el remate parecía un jugador trabado.
const POSE_INICIAL_DE_ACCION := {
	MotorEspacial.ACCION_PATEA: SpritesPartido.PATEA_ARMA,
}

## clave -> {"pose": String, "desde": int}, para las acciones que siguen
## vigentes en el fotograma `idx`. Se calcula mirando hacia atrás en vez
## de guardar estado, así funciona igual reproduciendo, pausando o
## saltando a cualquier punto.
##
## `desde` es el fotograma en que arrancó la acción. Lo necesita el
## arquero: el costado al que se tira se decide cuando se tira y no se
## puede recalcular después (ver _mostrar).
func _acciones_activas(idx: int) -> Dictionary:
	var activas := {}
	var maximo := 0
	for d in DURACION_ACCION.values():
		maximo = maxi(maximo, int(d))
	for i in range(maxi(0, idx - maximo + 1), idx + 1):
		for a in fotogramas[i].get("acciones", []):
			var accion := str(a["accion"])
			if idx - i < int(DURACION_ACCION.get(accion, 1)):
				# Un replay viejo puede traer otro duelo dentro del regate.
				# Ese control no debe pisar los cuadros que todavía faltan.
				var anterior: Dictionary = activas.get(a["clave"], {})
				# Una lesión recién ocurrida manda sobre barrida o contacto del
				# mismo tick: el jugador tiene que verse caer, no desaparecer
				# dentro de otra pose.
				if not anterior.is_empty() and str(anterior.get("accion", "")) == "lesionado":
					continue
				if not anterior.is_empty() and MotorEspacial.es_accion_regate(str(anterior.get("accion", ""))):
					var edad_regate := idx - int(anterior["desde"])
					var fin_regate := int(DURACION_ACCION.get(str(anterior["accion"]), 1))
					if edad_regate < fin_regate:
						continue
				var pose: String = POSE_DE_ACCION.get(accion, SpritesPartido.QUIETO)
				if idx == i and POSE_INICIAL_DE_ACCION.has(accion):
					pose = POSE_INICIAL_DE_ACCION[accion]
				var edad := idx - i
				if accion in ["cae", "barrida", "chilena", "bloquea"] and edad == int(DURACION_ACCION[accion]) - 1:
					pose = SpritesPartido.RECUPERA
				if accion == "palomita" and edad == int(DURACION_ACCION[accion]) - 1:
					pose = SpritesPartido.PALOMITA_CAER
				if accion == "festeja" and edad % 3 == 1:
					pose = SpritesPartido.CABECEA
				activas[a["clave"]] = {"pose": pose, "desde": i, "accion": accion}
	return activas


## Trayectoria corta de la pelota durante una técnica. El motor mantiene la
## posesión, pero la vista la separa de los pies para que cada toque se lea.
static func _trayectoria_regate(tipo: String, fase: float, orientacion: Vector2) -> Dictionary:
	var hacia := orientacion.normalized() if orientacion.length_squared() > 0.001 else Vector2.RIGHT
	var lateral := Vector2(-hacia.y, hacia.x)
	var f := clampf(fase, 0.0, 1.0)
	var offset := hacia * 0.35
	var altura := 0.0
	match tipo:
		"croqueta":
			# Misma curva que el cuerpo: entrada recta, toque lateral entre
			# pies y salida recta. La pelota queda siempre cerca del apoyo.
			if f < 0.30:
				offset = hacia * lerpf(0.22, 0.34, f / 0.30) + lateral * 0.28
			elif f < 0.66:
				var traslado := smoothstep(0.0, 1.0, (f - 0.30) / 0.36)
				offset = hacia * (0.34 + traslado * 0.08) + lateral * lerpf(0.28, -0.28, traslado)
			else:
				var salida := smoothstep(0.0, 1.0, (f - 0.66) / 0.34)
				offset = hacia * (0.42 + salida * 0.10) - lateral * 0.28
		"bicicleta":
			# La pelota queda quieta delante del pie mientras las piernas
			# pasan por encima. Recién en la salida la empuja el exterior
			# hacia el costado y adelante.
			var amagues := SpritesPartido.BICICLETA_INICIO_AMAGUES
			var inicio_salida := SpritesPartido.BICICLETA_INICIO_SALIDA
			if f < amagues:
				offset = hacia * lerpf(0.24, 0.38, f / amagues)
			elif f < inicio_salida:
				offset = hacia * 0.38
			else:
				var salida := smoothstep(0.0, 1.0, (f - inicio_salida) / (1.0 - inicio_salida))
				offset = hacia * (0.38 + salida * 0.55) - lateral * (0.30 * salida)
		"elastica":
			var lado := sin(f * PI * 2.0)
			offset = hacia * lerpf(0.30, 0.95, f) + lateral * lado * 0.85
		"globito":
			# Por arriba del rival mientras el jugador lo rodea: la pelota
			# se ubica respecto del cuerpo con la misma jugada que usa el
			# Laboratorio (SpritesPartido.globito).
			var g := SpritesPartido.globito(f)
			var rel: Vector2 = g["pelota"] - g["cuerpo"]
			offset = hacia * rel.x + lateral * rel.y
			altura = float(g["altura"])
		"ruleta":
			# La pelota gira alrededor de los pies junto con el dibujo (ver
			# SpritesPartido.ruleta). Antes daba una vuelta de 60 cm
			# mientras el jugador miraba siempre para el mismo lado.
			var r := SpritesPartido.ruleta(f)
			var rel_r: Vector2 = r["pelota"] - r["cuerpo"]
			offset = hacia * rel_r.x + lateral * rel_r.y
	return {"offset": offset, "altura": altura}


## A qué costado se tiró el arquero, EN PANTALLA. Se mide en el fotograma
## en que arrancó el vuelo y queda fijo mientras dura la pose. Antes se
## recalculaba en cada fotograma contra la pelota: cuando la pelota le
## quedaba en las manos el delta era cero, el signo se caía a false y el
## arquero se daba vuelta en el aire, en la mitad de la atajada.
func _lado_del_vuelo(clave: int, desde: int) -> bool:
	var f: Dictionary = fotogramas[desde]
	var pel := Vector2(f["pelota"]["x"], f["pelota"]["y"])
	for j in f["jugadores"]:
		if int(j["id"]) == clave:
			return ProyeccionPartido.direccion_pantalla(pel - Vector2(j["x"], j["y"])).x < 0.0
	return false


func _color_de(j: Dictionary) -> Color:
	if str(j.get("rol", "")) == "ARQ":
		return color_arquero_local if j["equipo_local"] else color_arquero_visitante
	return color_local if j["equipo_local"] else color_visitante


static func _direccion_al_rival(jugador: Dictionary, p: Vector2, jugadores: Array) -> Vector2:
	var objetivo := Vector2.ZERO
	var mejor_distancia := INF
	for candidato in jugadores:
		if bool(candidato.get("equipo_local", false)) == bool(jugador.get("equipo_local", false)):
			continue
		var delta := Vector2(float(candidato["x"]), float(candidato["y"])) - p
		var distancia := delta.length_squared()
		if distancia < mejor_distancia:
			mejor_distancia = distancia
			objetivo = delta
	if mejor_distancia == INF:
		return Vector2(float(jugador.get("ox", 1.0)), float(jugador.get("oy", 0.0)))
	return objetivo


static func _jugador_en(fotograma: Dictionary, clave: int) -> Dictionary:
	for jugador in fotograma.get("jugadores", []):
		if int(jugador["id"]) == clave:
			return jugador
	return {}


static func _defensor_del_regate(fotograma: Dictionary, clave_ejecutor: int) -> int:
	var ejecutor := _jugador_en(fotograma, clave_ejecutor)
	if ejecutor.is_empty():
		return -1
	var mejor := -1
	var distancia := INF
	for candidato in fotograma.get("jugadores", []):
		if bool(candidato.get("equipo_local", false)) == bool(ejecutor.get("equipo_local", false)):
			continue
		var d := Vector2(float(candidato["x"]), float(candidato["y"])) \
			.distance_squared_to(Vector2(float(ejecutor["x"]), float(ejecutor["y"])))
		if d < distancia:
			distancia = d
			mejor = int(candidato["id"])
	return mejor

static func _direccion(avance: Vector2) -> int:
	if avance.length_squared() < 0.0004:
		return SpritesPartido.ABAJO
	return SpritesPartido.direccion_desde(ProyeccionPartido.direccion_pantalla(avance))


## Hacia donde dibujar al jugador. Corriendo manda el avance, como siempre.
## Quieto, la orientacion del motor (etapa 3): antes todos los quietos
## miraban a camara. Un fotograma viejo sin `ox`/`oy` sigue igual que antes.
static func _direccion_de_jugador(j: Dictionary, avance: Vector2) -> int:
	if avance.length() / MotorEspacial.TICK_SEG >= VELOCIDAD_CORRIENDO or not j.has("ox"):
		return _direccion(avance)
	return _direccion(Vector2(float(j["ox"]), float(j.get("oy", 0.0))))


static func _pose(avance: Vector2, idx: int, recorrido: float = -1.0, id: int = 0) -> String:
	if avance.length() / MotorEspacial.TICK_SEG < VELOCIDAD_CORRIENDO:
		return SpritesPartido.QUIETO
	# Las piernas siguen los metros recorridos: el que acelera aumenta la
	# cadencia, y los veintidos ya no cambian de pie al mismo tiempo.
	if recorrido >= 0.0:
		var paso := int(floor(recorrido / 1.6 + float(posmod(id, 7)) / 7.0))
		return SpritesPartido.CORRE_A if paso % 2 == 0 else SpritesPartido.CORRE_B
	return SpritesPartido.CORRE_A if (idx / TICKS_POR_ZANCADA) % 2 == 0 else SpritesPartido.CORRE_B


static func _mezclar(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a if a.distance_squared_to(b) > SALTO_MAXIMO_M * SALTO_MAXIMO_M else a.lerp(b, t)


## Compatibilidad: los partidos grabados antes de separar ambos conceptos
## solo traen `corte`, que siempre representaba también una reubicación.
static func _es_reubicacion(fotograma: Dictionary) -> bool:
	return bool(fotograma.get("reubicacion", fotograma.get("corte", false)))


## La cámara sigue la pelota. La velocidad se estima con el fotograma
## siguiente, que es lo que le permite anticipar hacia dónde va la jugada.
func _seguir_camara(idx: int, delta: float) -> void:
	var pa: Dictionary = fotogramas[idx]["pelota"]
	var actual := Vector2(pa["x"], pa["y"])
	# El fotograma puede pedir que se mire otra cosa: con un expulsado
	# yendose, la accion es el, no la pelota parada a treinta metros.
	var foco = fotogramas[idx].get("foco", null)
	if foco != null:
		actual = Vector2(float(foco["x"]), float(foco["y"]))
	var vel := Vector2.ZERO
	if _festejo_restante > 0.0 and not _festejo_grupo.is_empty():
		vista.camara.encuadrar_festejo()
		vista.camara.seguir(_centro_festejo(), Vector2.ZERO, size, delta)
		return
	if idx + 1 < fotogramas.size():
		var siguiente = fotogramas[idx + 1].get("foco", null)
		var destino := actual
		if foco != null and siguiente != null:
			destino = Vector2(float(siguiente["x"]), float(siguiente["y"]))
		elif foco == null:
			var pb: Dictionary = fotogramas[idx + 1]["pelota"]
			destino = Vector2(pb["x"], pb["y"])
		var d := destino - actual
		if d.length() < SALTO_MAXIMO_M:
			vel = d / MotorEspacial.TICK_SEG
	var en_area: bool = absf(actual.x) > ProyeccionPartido.MEDIO_LARGO - 16.5
	vista.camara.fijar_encuadre(en_area, _festejo_restante > 0.0)
	# En la reubicación la cancha cambia de golpe: la cámara salta con ella en vez
	# de barrer la cancha detrás de la pelota ya reubicada.
	if _es_reubicacion(fotogramas[idx]) and _idx_corte_camara != idx:
		_idx_corte_camara = idx
		vista.camara.saltar_a(actual, size)
		return
	vista.camara.seguir(actual, vel, size, delta)
