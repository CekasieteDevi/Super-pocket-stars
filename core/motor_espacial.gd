class_name MotorEspacial
extends RefCounted

## Motor de partido ESPACIAL — MVP (ver docs/motor_espacial.md).
##
## A diferencia de MatchEngine (que sigue siendo el motor definitivo de
## todos los partidos que el jugador NO juega, y no se deprecia), acá hay
## coordenadas reales en una cancha de 105x68 metros: los 22 jugadores
## tienen posición y velocidad, se mueven cada tick, y el que tiene la
## pelota EVALÚA opciones y ELIGE una vía utility AI + softmax con
## temperatura, en vez de sortear un resultado abstracto por zona.
##
## Recorte del MVP (§7 del doc): solo 3 acciones para el poseedor
## (conducir / pasar a un compañero concreto / tirar), movimiento sin
## pelota por formación + atracción a la pelota, y sin
## cambios/lesiones/tarjetas todavía (ya existen en MatchEngine y se
## enganchan después sin rediseñar nada de acá).
##
## Sin nodos de Godot: todo Dictionary y Vector2, para poder simular un
## partido completo sin árbol de escena (decisión 1 del doc).

const PESOS_PATH := "res://data/utility_pesos.json"

## Decisión 2 del doc: 0.25s por tick.
const TICK_SEG := 0.25

## Un partido dura 2 minutos REALES por tiempo, jugados a velocidad real
## (la UI reproduce 4 fotogramas por segundo, o sea 1 seg de pantalla = 1
## seg de simulación). Eso son 480 ticks por tiempo.
##
## No se puede mostrar 90 minutos en 4 sin acelerar 22 veces, y a 22x un
## jugador que corre a 7 m/s se ve corriendo a 157: ilegible. Tampoco sirve
## acelerar solo el relleno (las jugadas importantes a velocidad real ya
## consumen los 4 minutos enteros) ni mostrar un resumen con cortes. La
## única salida que deja ver el partido COMPLETO, sin cortes y con
## movimiento creíble, es que el partido dure de verdad 4 minutos y que el
## reloj marque 0-90 como ficción — como en Pocket League Story, que es la
## referencia del GDD ("presentación por encima de profundidad").
##
## Costo asumido: al haber 4 minutos de juego en vez de 90, las llegadas
## son más seguidas que en un partido real. Se ve arcade, no televisado.
const TICKS_POR_MITAD := 480
const MINUTOS_MOSTRADOS_POR_MITAD := 45.0

## Cancha reglamentaria, origen en el centro. El equipo LOCAL ataca hacia
## +X (arco rival en +52.5), el visitante hacia -X.
const LARGO := 105.0
const ANCHO := 68.0
const MEDIO_LARGO := 52.5
const MEDIO_ANCHO := 34.0

## Posición base de cada rol para el equipo LOCAL (metros). El visitante
## usa las mismas espejadas en X. Sigue la formación real de
## Team.FORMACION: 1 ARQ, 2 DFC, 2 LAT, 2 MC, 1 MCO, 2 EXT, 1 DC.
const BASE_FORMACION := {
	"ARQ": [Vector2(-48.0, 0.0)],
	"DFC": [Vector2(-35.0, -9.0), Vector2(-35.0, 9.0)],
	"LAT": [Vector2(-30.0, -24.0), Vector2(-30.0, 24.0)],
	"MC": [Vector2(-14.0, -10.0), Vector2(-14.0, 10.0)],
	"MCO": [Vector2(-2.0, 0.0)],
	"EXT": [Vector2(8.0, -22.0), Vector2(8.0, 22.0)],
	"DC": [Vector2(14.0, 0.0)],
}

## Cuánto sigue cada línea a la pelota en X (0 = se queda en su base, 1 =
## la persigue del todo). Es el equivalente real del "empuje" que la
## animación aproximaba a ojo antes de que existieran coordenadas.
##
## Valores altos (0.5-0.75) hacen que el equipo entero se deslice casi 1:1
## con la pelota: cuando la pelota llegaba cerca de un arco, 8 o 9
## jugadores terminaban amontonados en el área chica y TODO el partido se
## jugaba a 5 metros del arco (mediana de remate 2.7m). Un equipo real
## comprime el espacio entre líneas, no se muda entero.
const ATRACCION_X := {
	"ARQ": 0.15, "DFC": 0.35, "LAT": 0.35, "MC": 0.45,
	"MCO": 0.50, "EXT": 0.50, "DC": 0.50,
}
## Lo mismo en Y, mucho más suave: el equipo se desplaza hacia el lado
## donde está la pelota, pero sin que los 11 se amontonen en un carril.
const ATRACCION_Y := {
	"ARQ": 0.10, "DFC": 0.30, "LAT": 0.25, "MC": 0.35,
	"MCO": 0.40, "EXT": 0.30, "DC": 0.35,
}

## Hasta dónde se para un jugador de campo. No es la línea de fondo
## (52.5) sino ~9 metros antes: si se permite llegar al fondo, defensores
## y delanteros se plantan DENTRO del área chica y todos los remates salen
## desde 3 metros. El que conduce sí puede pasar de acá (ver _conducir).
const LIMITE_X := 43.5

## Quiénes se meten detrás de la pelota cuando el equipo no la tiene. Los
## de arriba quedan afuera a propósito: son la salida del equipo.
const ROLES_QUE_REPLIEGAN := ["DFC", "LAT", "MC"]

## Los de arriba: atacando se paran en el hombro del último defensor rival
## (ver _objetivo_sin_pelota), que es de donde salen los goles.
const ROLES_QUE_ATACAN := ["MCO", "EXT", "DC"]

## estado["jugadores"] se indexa por CLAVE, no por jugador_id: los ids de
## jugador son únicos dentro de un club pero NO entre clubes (los dos
## equipos de un partido pueden tener un jugador con id 0), así que
## indexar por id hacía que un equipo pisara al otro. La clave del
## visitante se corre por este offset; el id real vive en
## EstadoJugador["jugador_id"].
const OFFSET_VISITANTE := 100000

static var _pesos_cache: Dictionary = {}


static func clave_de(jugador_id: int, es_local: bool) -> int:
	return jugador_id if es_local else jugador_id + OFFSET_VISITANTE


static func pesos() -> Dictionary:
	if _pesos_cache.is_empty():
		_pesos_cache = DataLoader.load_json(PESOS_PATH)
	return _pesos_cache


# ---------------------------------------------------------------------------
# Geometría
# ---------------------------------------------------------------------------

## Arco que ATACA este equipo.
static func arco_rival(equipo_local: bool) -> Vector2:
	return Vector2(MEDIO_LARGO, 0.0) if equipo_local else Vector2(-MEDIO_LARGO, 0.0)


## Arco que DEFIENDE este equipo.
static func arco_propio(equipo_local: bool) -> Vector2:
	return Vector2(-MEDIO_LARGO, 0.0) if equipo_local else Vector2(MEDIO_LARGO, 0.0)


## Qué tan buena es una posición para atacar: 1.0 pegado al arco rival,
## 0.0 en el arco propio. Es el término "progreso" de la utilidad (§4.1).
static func valor_posicion(pos: Vector2, equipo_local: bool) -> float:
	var arco := arco_rival(equipo_local)
	return clampf(1.0 - pos.distance_to(arco) / LARGO, 0.0, 1.0)


## §4.6 del doc: reemplaza a MatchEngine._resolver_destino, que solo
## miraba el atributo `tiro`. Un remate de 30 metros con ángulo cerrado
## ahora es peor que uno de frente al área chica aunque el atributo sea el
## mismo — que es justamente lo que antes no existía.
static func factor_geometria(pos: Vector2, equipo_local: bool) -> float:
	var arco := arco_rival(equipo_local)
	var dist := pos.distance_to(arco)
	var dx: float = maxf(absf(arco.x - pos.x), 1.0)
	var dy: float = absf(pos.y)
	var f_dist: float = clampf(1.0 - (dist - 5.0) / 30.0, 0.0, 1.0)
	var f_angulo: float = clampf(1.0 - (dy / dx) / 1.5, 0.0, 1.0)
	return f_dist * f_angulo


# ---------------------------------------------------------------------------
# Armado del estado inicial
# ---------------------------------------------------------------------------

## Interpola entre dos valores segun un atributo 0-100. Es la base de que
## el partido CAMBIE de aspecto con el nivel del plantel: en división 10 se
## ve lento y trabado, y con jugadores de élite se ve rápido y asociado.
static func _por_atributo(jugador: Dictionary, atributo: String, en_0: float, en_100: float) -> float:
	var v: float = clampf(float(jugador["atributos"][atributo]) / 100.0, 0.0, 1.0)
	return en_0 + v * (en_100 - en_0)


static func _vel_max(jugador: Dictionary) -> float:
	var f: Dictionary = pesos()["fisica"]
	return _por_atributo(jugador, "velocidad", f["vel_min"], f["vel_max"])


## Reparte los 11 de un equipo en los slots de BASE_FORMACION. Si un
## equipo viene con una composición rara (más de 2 DFC, por ejemplo,
## porque hubo cambios o rojas), los que no entran en ningún slot caen al
## slot 0 de su rol — nunca se pierde un jugador.
static func _armar_jugadores(equipo: Team, es_local: bool, estado: Dictionary) -> void:
	var usados := {}
	for j in equipo.jugadores_en_cancha():
		var rol: String = j["posicion"]
		var slots: Array = BASE_FORMACION.get(rol, BASE_FORMACION["MC"])
		var idx: int = usados.get(rol, 0)
		usados[rol] = idx + 1
		var base: Vector2 = slots[idx % slots.size()]
		if not es_local:
			base = Vector2(-base.x, base.y)
		estado["jugadores"][clave_de(j["id"], es_local)] = {
			"clave": clave_de(j["id"], es_local),
			"jugador_id": j["id"],
			"equipo_local": es_local,
			"rol": rol,
			"base": base,
			"pos": base,
			"vel": Vector2.ZERO,
			"objetivo": base,
			"vel_max": _vel_max(j),
		}


static func crear_estado(home: Team, away: Team, rng: RandomNumberGenerator) -> Dictionary:
	var estado := {
		"home": home, "away": away,
		"jugadores": {},
		"pelota": {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "poseedor_id": -1, "en_vuelo": false},
		"minuto": 0.0,
		"tick": 0,
		"rng": rng,
		"log": [],
		"goles_log": [],
		"eventos": [],
		"fotogramas": [],
		"robo_cooldown": {},
		"robos": {"intentos": 0, "ganados": 0},
		"pase_detalle": {"intentos": 0, "interceptado_vuelo": 0, "rival_llego_antes": 0, "fuera": 0},
		"linea_offside": {"local": LIMITE_X, "away": -LIMITE_X},
		"dist_tiros": [],
		"posesion_ticks": {"home": 0, "away": 0},
		"tiros": {"home": 0, "away": 0},
		"pases": {"home": 0, "away": 0},
		"decisiones": {},  # tipo -> cuántas veces se eligió (debug/§7)
	}
	_armar_jugadores(home, true, estado)
	_armar_jugadores(away, false, estado)
	return estado


# ---------------------------------------------------------------------------
# Presión (§4.3)
# ---------------------------------------------------------------------------

## Suma de la cercanía de los rivales, pesando más al que está entre el
## poseedor y el arco al que ataca (marca "de frente"). Devuelve un valor
## sin normalizar; usar presion_normalizada para 0..1.
static func presion_sobre(estado: Dictionary, pos: Vector2, equipo_local: bool) -> float:
	var p: Dictionary = pesos()["presion"]
	var radio: float = p["radio"]
	var arco := arco_rival(equipo_local)
	var dir_ataque := (arco - pos).normalized()
	var total := 0.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == equipo_local:
			continue
		var d: float = pos.distance_to(e["pos"])
		if d >= radio:
			continue
		var cercania: float = 1.0 - d / radio
		# ¿está del lado por el que quiero avanzar?
		var de_frente: float = maxf(0.0, dir_ataque.dot((e["pos"] - pos).normalized()))
		total += cercania * (1.0 + de_frente * (p["factor_frente"] - 1.0))
	return total


static func presion_normalizada(estado: Dictionary, pos: Vector2, equipo_local: bool) -> float:
	var p: Dictionary = pesos()["presion"]
	return clampf(presion_sobre(estado, pos, equipo_local) / float(p["normalizador"]), 0.0, 1.0)


## Cuánto riesgo tiene la línea de pase entre dos puntos: mira qué tan
## cerca pasa cada rival del segmento. 0 = despejada, 1 = tapada.
static func riesgo_linea(estado: Dictionary, desde: Vector2, hasta: Vector2, equipo_local: bool) -> float:
	var peor := 0.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == equipo_local:
			continue
		var d := _dist_a_segmento(e["pos"], desde, hasta)
		if d < 6.0:
			peor = maxf(peor, 1.0 - d / 6.0)
	return peor


static func _dist_a_segmento(punto: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var largo_sq := ab.length_squared()
	if largo_sq < 0.001:
		return punto.distance_to(a)
	var t: float = clampf((punto - a).dot(ab) / largo_sq, 0.0, 1.0)
	return punto.distance_to(a + ab * t)


# ---------------------------------------------------------------------------
# Decisión del poseedor (§4.1, §4.2)
# ---------------------------------------------------------------------------

## Arma las opciones candidatas con su utilidad. Cada opción es
## {"tipo", "utilidad", "objetivo_id"/"objetivo_pos"} — el desglose se
## conserva en "detalle" porque el harness de debug del MVP TIENE que
## poder mostrar por qué se eligió lo que se eligió (§7 del doc: si algo
## se ve raro hay que poder distinguir "arquitectura mal" de "T mal
## calibrada" mirando números, no adivinando).
static func evaluar_opciones(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary) -> Array:
	var w: Dictionary = pesos()
	var f: Dictionary = w["fisica"]
	var sesgos: Dictionary = w["sesgos_personalidad"]
	var es_local: bool = poseedor["equipo_local"]
	var pos: Vector2 = poseedor["pos"]
	var presion := presion_normalizada(estado, pos, es_local)
	var mi_valor := valor_posicion(pos, es_local)
	var opciones := []

	# --- Conducir -----------------------------------------------------
	var wc: Dictionary = w["conducir"]
	var u_conducir: float = wc["base"] + wc["espacio"] * (1.0 - presion) + wc["progreso"] * (1.0 - mi_valor)
	opciones.append({
		"tipo": "conducir", "utilidad": u_conducir,
		"detalle": {"presion": presion, "mi_valor": mi_valor},
	})

	# --- Tirar --------------------------------------------------------
	var geo := factor_geometria(pos, es_local)
	if geo > float(f["geometria_minima_tiro"]):
		var wt: Dictionary = w["tiro"]
		var u_tiro: float = wt["base"] + wt["geometria"] * geo
		if Personalidad.tiene(jugador, "Egoista"):
			u_tiro *= float(sesgos["egoista_tiro"])
		opciones.append({
			"tipo": "tiro", "utilidad": u_tiro,
			"detalle": {"geometria": geo},
		})

	# --- Pasar a cada compañero alcanzable ----------------------------
	var wp: Dictionary = w["pase"]
	# Hasta dónde llega su pase: un central de división 10 no cambia el
	# frente de juego de 45 metros.
	var max_dist: float = _por_atributo(jugador, "pases", f["max_dist_pase_malo"], f["max_dist_pase_bueno"])
	var sesgo_pase: float = float(sesgos["creador_pase"]) if Personalidad.tiene(jugador, "Creador") else 1.0
	for id in estado["jugadores"]:
		var comp: Dictionary = estado["jugadores"][id]
		if comp["equipo_local"] != es_local or id == poseedor["clave"]:
			continue
		var dist: float = pos.distance_to(comp["pos"])
		if dist > max_dist or dist < 2.0:
			continue
		var progreso: float = valor_posicion(comp["pos"], es_local) - mi_valor
		var riesgo := riesgo_linea(estado, pos, comp["pos"], es_local)
		var u_pase: float = wp["base"] \
			+ wp["progreso"] * progreso \
			+ wp["seguridad"] * (1.0 - riesgo) \
			- wp["distancia"] * (dist / max_dist)
		u_pase *= sesgo_pase
		opciones.append({
			"tipo": "pase", "utilidad": u_pase, "objetivo_id": id,
			"detalle": {"progreso": progreso, "riesgo": riesgo, "dist": dist},
		})

	return opciones


## §4.2: temperatura del softmax. Baja = decide bien y consistente; alta =
## más errático. Visión e inteligencia la bajan, la presión la sube — ahí
## está el "error humano" del encargo: un jugador limitado o presionado
## toma peores decisiones sin que el motor haga trampa.
static func temperatura(jugador: Dictionary, presion: float) -> float:
	var t: Dictionary = pesos()["temperatura"]
	var attrs: Dictionary = jugador["atributos"]
	var valor: float = float(t["base"]) \
		- float(t["k_vision"]) * (float(attrs["vision"]) / 100.0) \
		- float(t["k_inteligencia"]) * (float(attrs["inteligencia"]) / 100.0) \
		+ float(t["k_presion"]) * presion
	return clampf(valor, float(t["min"]), float(t["max"]))


## Softmax con temperatura sobre las utilidades. Se resta el máximo antes
## de exponenciar (truco estándar de estabilidad numérica: sin eso,
## utilidades altas divididas por una T chica desbordan exp()).
static func elegir_softmax(opciones: Array, temp: float, rng: RandomNumberGenerator) -> Dictionary:
	if opciones.size() == 1:
		return opciones[0]

	var max_u: float = -INF
	for o in opciones:
		max_u = maxf(max_u, o["utilidad"])

	var pesos_exp := []
	var suma := 0.0
	for o in opciones:
		var e: float = exp((o["utilidad"] - max_u) / temp)
		pesos_exp.append(e)
		suma += e

	var roll := rng.randf() * suma
	var acum := 0.0
	for i in range(opciones.size()):
		acum += pesos_exp[i]
		if roll <= acum:
			var elegida: Dictionary = opciones[i]
			elegida["probabilidad"] = pesos_exp[i] / suma
			return elegida
	return opciones[opciones.size() - 1]


# ---------------------------------------------------------------------------
# Movimiento
# ---------------------------------------------------------------------------

## §4.4: los 21 sin pelota se mueven con matemática de vectores barata —
## nada de utilidad ni softmax, tal como exige la restricción de
## rendimiento. La posición objetivo es su base de formación desplazada
## hacia donde está la pelota, con el peso de su rol; el estilo del equipo
## decide cuánto persigue la pelota cuando NO la tiene (Presión alta la va
## a buscar de verdad, Defensivo se repliega).
static func _objetivo_sin_pelota(estado: Dictionary, e: Dictionary, equipo: Team, tiene_pelota_mi_equipo: bool) -> Vector2:
	var pelota_pos: Vector2 = estado["pelota"]["pos"]
	var rol: String = e["rol"]
	var base: Vector2 = e["base"]
	var ax: float = ATRACCION_X.get(rol, 0.6)
	var ay: float = ATRACCION_Y.get(rol, 0.3)

	if not tiene_pelota_mi_equipo:
		# Estilos.retroceso_sin_pelota: negativo = presiona hacia adelante
		# en vez de replegarse. Acá deja de ser un ajuste visual y pasa a
		# mover al jugador de verdad.
		var retroceso: float = Estilos.retroceso_sin_pelota(equipo.estilo)
		ax *= clampf(1.0 - retroceso, 0.3, 1.6)

	var objetivo_x: float = clampf(base.x + pelota_pos.x * ax, -LIMITE_X, LIMITE_X)
	var objetivo_y: float = base.y + (pelota_pos.y - base.y) * ay

	# Marca del lado del arco: defendiendo, la línea de atrás y los
	# volantes centrales no se quedan por delante de la pelota. Sin esto
	# se quedan en su casillero de formación y un rival gambetea 80 metros
	# sin cruzarse con nadie hasta el área chica (medido: 32% de
	# conversión, todos los remates a quemarropa).
	#
	# Los de arriba (MCO/EXT/DC) NO se repliegan: si los 10 se meten
	# detrás de la pelota, cualquier pase hacia adelante atraviesa una
	# muralla de 10 y no se completa NINGUNO (medido: 1% de pases
	# completados contra el ~80% real). Quedan arriba como salida.
	if not tiene_pelota_mi_equipo and ROLES_QUE_REPLIEGAN.has(rol):
		if e["equipo_local"]:
			objetivo_x = minf(objetivo_x, pelota_pos.x + 1.0)
		else:
			objetivo_x = maxf(objetivo_x, pelota_pos.x - 1.0)

	# Atacando, los de arriba se paran EN EL HOMBRO del último defensor en
	# vez de quedarse en su casillero. Sin esto un 9 con la pelota en campo
	# rival se quedaba a 24 metros del arco pudiendo estar a 10, el equipo
	# nunca entraba al área y todos los remates salían de afuera (mediana
	# 23m, casi ningún gol).
	if tiene_pelota_mi_equipo and ROLES_QUE_ATACAN.has(rol):
		var linea_ataque: Dictionary = estado["linea_offside"]
		if e["equipo_local"]:
			objetivo_x = maxf(objetivo_x, float(linea_ataque["local"]) - 1.0)
		else:
			objetivo_x = minf(objetivo_x, float(linea_ataque["away"]) + 1.0)

	# Mantenerse habilitado: nadie se adelanta al último defensor rival.
	# El offside como infracción queda fuera del MVP, pero la CONDUCTA de
	# no irse en offside no es opcional — sin ella los delanteros acampan
	# pegados al arco (x=50, el límite de cancha) y la mediana de remate
	# se va a 2.5 metros, o sea todos los goles desde adentro del área
	# chica. Es además mucho más barato que modelar la infracción.
	if rol != "ARQ":
		var linea: Dictionary = estado["linea_offside"]
		if e["equipo_local"]:
			objetivo_x = minf(objetivo_x, float(linea["local"]))
		else:
			objetivo_x = maxf(objetivo_x, float(linea["away"]))

	return Vector2(objetivo_x, clampf(objetivo_y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))


## Hasta dónde puede adelantarse cada equipo sin quedar en offside: el
## último defensor rival (sin contar al arquero). Se calcula una vez por
## tick y lo leen los 22.
static func _calcular_linea_offside(estado: Dictionary) -> void:
	var tope_local: float = -INF   # último defensor AWAY (el de mayor x)
	var tope_away: float = INF     # último defensor LOCAL (el de menor x)
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["rol"] == "ARQ":
			continue
		if e["equipo_local"]:
			tope_away = minf(tope_away, e["pos"].x)
		else:
			tope_local = maxf(tope_local, e["pos"].x)
	# La pelota siempre habilita: si el balón está más adelantado que el
	# último defensor, se puede ir con él.
	var pelota_x: float = estado["pelota"]["pos"].x
	estado["linea_offside"] = {
		"local": maxf(tope_local if tope_local > -INF else LIMITE_X, pelota_x),
		"away": minf(tope_away if tope_away < INF else -LIMITE_X, pelota_x),
	}


static func _mover_hacia(e: Dictionary, objetivo: Vector2) -> void:
	var delta: Vector2 = objetivo - e["pos"]
	var paso: float = e["vel_max"] * TICK_SEG
	if delta.length() <= paso:
		e["pos"] = objetivo
		e["vel"] = Vector2.ZERO
	else:
		var dir := delta.normalized()
		e["pos"] = e["pos"] + dir * paso
		e["vel"] = dir * e["vel_max"]


# ---------------------------------------------------------------------------
# Ejecución de acciones
# ---------------------------------------------------------------------------

static func _equipo_de(estado: Dictionary, es_local: bool) -> Team:
	return estado["home"] if es_local else estado["away"]


static func _dict_jugador(estado: Dictionary, equipo: Team, jugador_id: int) -> Dictionary:
	for j in equipo.todos_los_jugadores():
		if j["id"] == jugador_id:
			return j
	return {}


static func _minuto_int(estado: Dictionary) -> int:
	return int(estado["minuto"]) + 1


## Reusa el duelo del GDD tal cual (§8.1/§8.5): Duel.resolver con los 4
## bloques que arma MatchEngine. El motor espacial cambia QUÉ se decide y
## DÓNDE pasa, no cómo se resuelve la calidad de una acción ya elegida —
## por eso el balance de modificadores sigue valiendo.
static func _duelo_simple(atacante: Dictionary, attr_a: String, eq_a: Team,
		defensor: Dictionary, attr_d: String, eq_d: Team, minuto: int,
		rng: RandomNumberGenerator) -> bool:
	var ata := Duel.atributo_efectivo(
		atacante["atributos"][attr_a], MatchEngine._grupo_de(attr_a), eq_a.resistencia_pct(atacante["id"]))
	var def := Duel.atributo_efectivo(
		defensor["atributos"][attr_d], MatchEngine._grupo_de(attr_d), eq_d.resistencia_pct(defensor["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, atacante, attr_a, minuto, rng),
		MatchEngine._bloques_equipo(eq_d, eq_a, defensor, attr_d, minuto, rng))
	var mult: float = float(pesos()["fisica"]["multiplicador_desgaste"])
	eq_a.desgastar(atacante["id"], atacante["atributos"]["energia"], mult)
	eq_d.desgastar(defensor["id"], defensor["atributos"]["energia"], mult)
	if rng.randf() < float(pesos()["fisica"]["prob_evento_fisico"]):
		MatchEngine._chequear_lesion(atacante, eq_a, rng)
		MatchEngine._chequear_lesion(defensor, eq_d, rng)
	return Duel.gana_atacante(res, rng)


## Saque del medio después de un gol (o al empezar cada tiempo).
static func _reiniciar_desde_medio(estado: Dictionary, saca_local: bool) -> void:
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		e["pos"] = e["base"]
		e["vel"] = Vector2.ZERO
	estado["pelota"]["pos"] = Vector2.ZERO
	estado["pelota"]["vel"] = Vector2.ZERO
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["ticks_con_pelota"] = 0
	# la saca el MCO del equipo que corresponde
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == saca_local and e["rol"] == "MCO":
			estado["pelota"]["poseedor_id"] = id
			e["pos"] = Vector2.ZERO
			return
	estado["pelota"]["poseedor_id"] = -1


static func _resolver_tiro(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary) -> void:
	var es_local: bool = poseedor["equipo_local"]
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var minuto := _minuto_int(estado)
	var geo := factor_geometria(poseedor["pos"], es_local)
	var clave := "home" if es_local else "away"
	estado["tiros"][clave] += 1
	estado["dist_tiros"].append(poseedor["pos"].distance_to(arco_rival(es_local)))

	# §4.6: el destino ya no depende solo del atributo, también de dónde
	# está parado el que remata. Calibrado contra un partido real: ~35% de
	# los remates van al arco, y de esos entra ~1 de cada 3.
	var r: Dictionary = pesos()["tiro_resolucion"]
	var calidad: float = float(jugador["atributos"]["tiro"]) / 100.0 * float(r["peso_atributo"]) + geo * float(r["peso_geometria"])
	var chance_porteria: float = clampf(float(r["porteria_base"]) + calidad * float(r["porteria_calidad"]), 0.05, 0.85)
	var chance_palo: float = float(r["palo"]) * calidad
	var roll := rng.randf()

	if roll > chance_porteria + chance_palo:
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "afuera",
		})
		_dar_pelota_al_arquero(estado, not es_local)
		return
	if roll > chance_porteria:
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "palo",
		})
		_dar_pelota_al_arquero(estado, not es_local)
		return

	# El remate se debilita según desde dónde salió: un tiro de 30 metros
	# con ángulo cerrado llega mucho más flojo al arquero que el mismo
	# jugador de frente al área chica. Y el arquero vale por el compuesto
	# del GDD §8.2 (reflejos×0.5 + estirada×0.3 + agarre×0.2), no solo
	# reflejos — usar un único atributo hacía el duelo demasiado fácil
	# para el atacante y disparaba la conversión al 18%.
	var arquero := eq_d.arquero()
	var arq_attrs: Dictionary = arquero["atributos"]
	var arquero_valor: float = arq_attrs["reflejos"] * 0.5 + arq_attrs["estirada"] * 0.3 + arq_attrs["agarre"] * 0.2
	var tiro_efectivo: float = float(jugador["atributos"]["tiro"]) * (float(r["fuerza_base"]) + (1.0 - float(r["fuerza_base"])) * geo)
	var ata := Duel.atributo_efectivo(tiro_efectivo, "tecnico", eq_a.resistencia_pct(jugador["id"]))
	var def := Duel.atributo_efectivo(arquero_valor, "tecnico", eq_d.resistencia_pct(arquero["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, jugador, "tiro", minuto, rng),
		MatchEngine._bloques_equipo(eq_d, eq_a, arquero, "reflejos", minuto, rng))
	var mult_tiro: float = float(pesos()["fisica"]["multiplicador_desgaste"])
	eq_a.desgastar(jugador["id"], jugador["atributos"]["energia"], mult_tiro)
	eq_d.desgastar(arquero["id"], arq_attrs["energia"], mult_tiro)
	var gol := Duel.gana_atacante(res, rng)
	estado["eventos"].append({
		"minuto": minuto, "tipo": "tiro_puerta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": poseedor["rol"], "resultado": "gol" if gol else "atajada",
	})
	var dist: float = poseedor["pos"].distance_to(arco_rival(es_local))
	if gol:
		eq_a.goles += 1
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre, "jugador_id": jugador["id"]})
		estado["log"].append("min %d - GOL de %s %s (%s) desde %.0f m" % [
			minuto, jugador["nombre"], jugador["apellido"], eq_a.nombre, dist])
		_reiniciar_desde_medio(estado, not es_local)
	else:
		estado["log"].append("min %d - %s (%s) remata desde %.0f m, ataja el arquero" % [
			minuto, poseedor["rol"], eq_a.nombre, dist])
		_dar_pelota_al_arquero(estado, not es_local)


static func _dar_pelota_al_arquero(estado: Dictionary, arquero_local: bool) -> void:
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == arquero_local and e["rol"] == "ARQ":
			estado["pelota"]["poseedor_id"] = id
			estado["pelota"]["pos"] = e["pos"]
			estado["pelota"]["vel"] = Vector2.ZERO
			estado["pelota"]["en_vuelo"] = false
			estado["pelota"]["ticks_con_pelota"] = 0
			return


## Un pase va A UN PUNTO (donde está el compañero al momento de pegarle),
## no en una dirección infinita: si no, con 18 m/s y ticks de 0.25s la
## pelota avanza 4.5m por tick, pasa de largo por encima del receptor
## (radio de control 1.6m) y se va del campo sin que nadie la toque.
static func _lanzar_pase(estado: Dictionary, poseedor: Dictionary, destino_id: int, jugador: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var destino: Dictionary = estado["jugadores"][destino_id]
	var dir: Vector2 = (destino["pos"] - poseedor["pos"]).normalized()
	var pelota: Dictionary = estado["pelota"]
	estado["pase_detalle"]["intentos"] += 1
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	# La pelota sale más fuerte cuanto mejor pega el que la toca: un pase
	# flojo tarda más en llegar y le da tiempo al rival a meterse.
	pelota["vel"] = dir * _por_atributo(jugador, "pases", f["vel_pase_min"], f["vel_pase_max"])
	pelota["pases_pasador"] = float(jugador["atributos"]["pases"])
	pelota["destino_pos"] = destino["pos"]
	pelota["destino_id"] = destino_id
	pelota["pasador_local"] = poseedor["equipo_local"]
	pelota["es_pase"] = true
	pelota["origen_pos"] = poseedor["pos"]


# ---------------------------------------------------------------------------
# Loop de tick (§3)
# ---------------------------------------------------------------------------

static func _tick(estado: Dictionary, con_fotogramas: bool) -> void:
	var pelota: Dictionary = estado["pelota"]
	var eventos_antes: int = estado["eventos"].size()

	# 1. Pelota en vuelo: avanza, y alguien puede controlarla o interceptarla.
	if pelota["en_vuelo"]:
		_avanzar_pelota(estado)
	# 2. Con poseedor: decide y ejecuta.
	elif pelota["poseedor_id"] != -1:
		_decidir_y_ejecutar(estado)

	# 3. Los que no tienen la pelota se reposicionan (barato).
	_calcular_linea_offside(estado)
	var poseedor_id: int = pelota["poseedor_id"]
	var pos_local: bool = true
	if poseedor_id != -1:
		pos_local = estado["jugadores"][poseedor_id]["equipo_local"]
		estado["posesion_ticks"]["home" if pos_local else "away"] += 1

	# El más cercano del equipo SIN la pelota va a buscarla de verdad, en
	# vez de quedarse en su casillero de formación. Sin esto los
	# defensores nunca llegan al radio de tackle y un atacante entra al
	# área caminando: el motor daba 60+ tiros por partido contra los ~25
	# de un partido real.
	# Con la pelota en el aire no hay poseedor, pero igual hay que saber
	# de qué equipo salen los que van a buscarla: se usa el que la jugó.
	# Asumir "local" en ese caso hacía que SOLO el visitante persiguiera
	# durante cada vuelo de pelota, y la posesión quedaba 29%-71%.
	var equipo_con_pelota: bool = pos_local
	if poseedor_id == -1:
		equipo_con_pelota = bool(pelota.get("pasador_local", true))
	var perseguidores := _perseguidores(estado, equipo_con_pelota)

	# El destinatario de un pase va a BUSCAR la pelota. Sin esto el pase
	# apunta a donde el compañero estaba al momento de pegarle, y como en
	# los ~4 ticks de vuelo ese compañero se corrió 7-9 metros, la pelota
	# llegaba a un lugar vacío y la agarraba el defensor más cercano: solo
	# el 1% de los pases se completaba, contra el ~80% de un partido real.
	var esperando := -1
	if pelota["en_vuelo"]:
		esperando = int(pelota.get("destino_id", -1))

	for id in estado["jugadores"]:
		if id == poseedor_id:
			continue
		var e: Dictionary = estado["jugadores"][id]
		if id == esperando:
			_mover_hacia(e, pelota.get("destino_pos", pelota["pos"]))
			continue
		if perseguidores.has(id):
			_mover_hacia(e, pelota["pos"])
			continue
		var equipo := _equipo_de(estado, e["equipo_local"])
		var mi_equipo_tiene: bool = poseedor_id != -1 and e["equipo_local"] == pos_local
		_mover_hacia(e, _objetivo_sin_pelota(estado, e, equipo, mi_equipo_tiene))

	# 4. Intento de robo: el rival más cercano al poseedor puede quitársela.
	if pelota["poseedor_id"] != -1:
		_intentar_robo(estado)

	# 5. La pelota sigue al poseedor.
	if pelota["poseedor_id"] != -1:
		pelota["pos"] = estado["jugadores"][pelota["poseedor_id"]]["pos"]
		pelota["ticks_con_pelota"] = int(pelota.get("ticks_con_pelota", 0)) + 1

	estado["tick"] += 1
	# El reloj MOSTRADO avanza 90 minutos a lo largo de los 960 ticks del
	# partido: es la ficción de "esto son 90 minutos". Todo lo que depende
	# del minuto (rasgos como Lento de arranque o Se apaga, el DT según el
	# marcador, las ventanas de cambio) lee este reloj, así que conserva
	# exactamente la semántica del GDD.
	estado["minuto"] += MINUTOS_MOSTRADOS_POR_MITAD / float(TICKS_POR_MITAD)
	# Cada 5 segundos de juego se saca de la cancha a los expulsados (una
	# roja puede caer en cualquier tick, no solo en una ventana de cambio).
	if estado["tick"] % 20 == 0:
		_sincronizar_cambios(estado)
	if con_fotogramas:
		var nuevo = null
		if estado["eventos"].size() > eventos_antes:
			nuevo = estado["eventos"][estado["eventos"].size() - 1]
		_push_fotograma(estado, nuevo)


static func _avanzar_pelota(estado: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var pelota: Dictionary = estado["pelota"]
	var pasador_local: bool = pelota.get("pasador_local", true)
	var minuto := _minuto_int(estado)
	var desde: Vector2 = pelota["pos"]
	var destino: Vector2 = pelota.get("destino_pos", desde)
	var paso: float = pelota["vel"].length() * TICK_SEG
	var restante: float = desde.distance_to(destino)
	var llego: bool = paso >= restante
	var hasta: Vector2 = destino if llego else desde + pelota["vel"].normalized() * paso
	pelota["pos"] = hasta

	# Intercepción: se mide contra el SEGMENTO recorrido este tick, no
	# contra el punto final — con pasos de ~4.5m, chequear solo el punto
	# final dejaría pasar la pelota "a través" de un defensor.
	#
	# El rival que está MARCANDO al pasador no intercepta: está a ~2m de
	# él, o sea automáticamente dentro del corredor de la línea de pase
	# apenas sale. Como casi siempre hay alguien encima, sin esta
	# excepción el que te presiona interceptaba el 96,5% de los pases y
	# no se completaba prácticamente ninguno. La pelota le sale de los
	# pies pasándolo; su oportunidad de robarla es el quite, no esto.
	var origen: Vector2 = pelota.get("origen_pos", desde)
	# Un pase preciso pasa entre líneas; uno flojo se lo comen. Sin esto la
	# intercepción era pura geometría y un gran pasador completaba
	# exactamente los mismos pases que uno malo.
	var calidad_pase: float = clampf(float(pelota.get("pases_pasador", 50.0)) / 100.0, 0.0, 1.0)
	var radio_inter: float = float(f["radio_intercepcion"]) * (float(f["intercepcion_pase_malo"]) - (float(f["intercepcion_pase_malo"]) - float(f["intercepcion_pase_bueno"])) * calidad_pase)
	var minimo_desde_origen: float = f["min_dist_intercepcion_origen"]
	var mejor_id := -1
	var mejor_d: float = radio_inter
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == pasador_local:
			continue
		if e["pos"].distance_to(origen) < minimo_desde_origen:
			continue
		var d := _dist_a_segmento(e["pos"], desde, hasta)
		if d < mejor_d:
			mejor_d = d
			mejor_id = id
	if mejor_id != -1:
		if bool(pelota.get("es_pase", false)):
			estado["pase_detalle"]["interceptado_vuelo"] += 1
		_entregar_pelota(estado, mejor_id)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "pase", "equipo": _equipo_de(estado, pasador_local).nombre,
			"rival": _equipo_de(estado, not pasador_local).nombre,
			"jugador_posicion": estado["jugadores"][mejor_id]["rol"], "resultado": "pierde",
		})
		return

	if not llego:
		return

	# La pelota llegó a destino: la toma el más cercano de cualquier
	# equipo (el receptor se movió un poco desde que salió el pase, y si
	# un defensor llegó antes, se la queda él).
	var receptor := _mas_cercano_a(estado, hasta)
	if receptor == -1:
		_dar_pelota_al_arquero(estado, not pasador_local)
		return
	var e_receptor: Dictionary = estado["jugadores"][receptor]
	_entregar_pelota(estado, receptor)
	if e_receptor["equipo_local"] == pasador_local:
		if bool(pelota.get("es_pase", false)):
			estado["pases"]["home" if pasador_local else "away"] += 1
		estado["eventos"].append({
			"minuto": minuto, "tipo": "pase", "equipo": _equipo_de(estado, pasador_local).nombre,
			"rival": _equipo_de(estado, not pasador_local).nombre,
			"jugador_posicion": e_receptor["rol"], "resultado": "avanza",
		})
	elif bool(pelota.get("es_pase", false)):
		estado["pase_detalle"]["rival_llego_antes"] += 1
		estado["eventos"].append({
			"minuto": minuto, "tipo": "pase", "equipo": _equipo_de(estado, pasador_local).nombre,
			"rival": _equipo_de(estado, not pasador_local).nombre,
			"jugador_posicion": e_receptor["rol"], "resultado": "pierde",
		})


## Pelota dividida tras un quite: sale despedida unos metros hacia el
## lado del que defendía y la agarra el que llegue. `pasador_local` queda
## en el equipo que la PERDIÓ, así que para el que la quitó cuenta como
## intercepción (es decir, tiene ventaja para recuperarla, pero no es
## automático — puede quedar para cualquiera).
static func _soltar_pelota(estado: Dictionary, desde: Vector2, era_local: bool) -> void:
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var hacia_atras := -1.0 if era_local else 1.0
	var dir := Vector2(hacia_atras * rng.randf_range(0.3, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	var largo: float = rng.randf_range(float(f["rebote_min"]), float(f["rebote_max"]))
	var destino := Vector2(
		clampf(desde.x + dir.x * largo, -LIMITE_X, LIMITE_X),
		clampf(desde.y + dir.y * largo, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["pos"] = desde
	pelota["vel"] = (destino - desde).normalized() * float(f["vel_pelota_pase"]) * 0.6
	pelota["destino_pos"] = destino
	pelota["destino_id"] = -1
	pelota["pasador_local"] = era_local
	pelota["es_pase"] = false
	pelota["origen_pos"] = desde
	pelota["ticks_con_pelota"] = 0


## Sincroniza los 22 del estado espacial con quién está realmente en
## cancha según Team: entran los que ingresaron por un cambio, salen los
## sustituidos y los expulsados. Sin esto, un jugador que ya salió seguiría
## corriendo en la simulación y un expulsado jugaría igual.
static func _sincronizar_cambios(estado: Dictionary) -> void:
	for es_local in [true, false]:
		var equipo := _equipo_de(estado, es_local)
		var deben_estar := {}
		for j in equipo.jugadores_en_cancha():
			if equipo.expulsados_partido.has(j["id"]):
				continue
			deben_estar[clave_de(j["id"], es_local)] = j

		var libres := []  # posiciones que dejaron los que salieron
		for clave in estado["jugadores"].keys():
			var e: Dictionary = estado["jugadores"][clave]
			if e["equipo_local"] != es_local:
				continue
			if not deben_estar.has(clave):
				libres.append(e["pos"])
				if estado["pelota"]["poseedor_id"] == clave:
					_dar_pelota_al_arquero(estado, not es_local)
				estado["jugadores"].erase(clave)

		for clave in deben_estar:
			if estado["jugadores"].has(clave):
				continue
			var j: Dictionary = deben_estar[clave]
			var rol: String = j["posicion"]
			var slots: Array = BASE_FORMACION.get(rol, BASE_FORMACION["MC"])
			var base: Vector2 = slots[0]
			if not es_local:
				base = Vector2(-base.x, base.y)
			var pos: Vector2 = libres.pop_back() if not libres.is_empty() else base
			estado["jugadores"][clave] = {
				"clave": clave, "jugador_id": j["id"], "equipo_local": es_local,
				"rol": rol, "base": base, "pos": pos, "vel": Vector2.ZERO,
				"objetivo": base, "vel_max": _vel_max(j),
			}


static func _entregar_pelota(estado: Dictionary, clave: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = clave
	pelota["en_vuelo"] = false
	pelota["vel"] = Vector2.ZERO
	pelota["pos"] = estado["jugadores"][clave]["pos"]
	pelota["ticks_con_pelota"] = 0


## Quiénes del equipo que NO tiene la pelota salen a presionarla: los dos
## más cercanos, salvo el arquero (que no abandona el arco a perseguir).
## Con uno solo, el que conduce se lo saca de encima y sigue de largo.
static func _perseguidores(estado: Dictionary, equipo_con_pelota_local: bool) -> Array:
	var pelota_pos: Vector2 = estado["pelota"]["pos"]
	var p1 := -1
	var p2 := -1
	var d1: float = INF
	var d2: float = INF
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == equipo_con_pelota_local or e["rol"] == "ARQ":
			continue
		var d: float = pelota_pos.distance_to(e["pos"])
		if d < d1:
			d2 = d1
			p2 = p1
			d1 = d
			p1 = id
		elif d < d2:
			d2 = d
			p2 = id
	return [p1, p2]


static func _mas_cercano_a(estado: Dictionary, punto: Vector2) -> int:
	var mejor := -1
	var mejor_d: float = INF
	for id in estado["jugadores"]:
		var d: float = punto.distance_to(estado["jugadores"][id]["pos"])
		if d < mejor_d:
			mejor_d = d
			mejor = id
	return mejor


static func _decidir_y_ejecutar(estado: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var pelota: Dictionary = estado["pelota"]
	var poseedor: Dictionary = estado["jugadores"][pelota["poseedor_id"]]
	var es_local: bool = poseedor["equipo_local"]
	var equipo := _equipo_de(estado, es_local)
	var jugador := _dict_jugador(estado, equipo, poseedor["jugador_id"])
	if jugador.is_empty():
		return

	# El que lleva la pelota NO reconsidera 4 veces por segundo: conduce
	# un tramo y recién ahí vuelve a evaluar. Sin esto, una posesión larga
	# cerca del área acumulaba cientos de tiradas para "tirar" (278
	# remates por partido, contra los ~25 de un partido real).
	# Cuánto tarda en acomodarla antes de decidir: un jugador de buen
	# control la toca y sigue, uno malo la pelea y frena el juego. Es lo
	# que hace que una división 10 se vea trabada y un partido de élite
	# fluya.
	var ticks_control: int = int(round(_por_atributo(jugador, "control", f["ticks_control_malo"], f["ticks_control_bueno"])))
	ticks_control = maxi(ticks_control, 1)
	var ticks: int = int(pelota.get("ticks_con_pelota", 0))
	if ticks == 0 or ticks % ticks_control != 0:
		_conducir(estado, poseedor)
		return

	var opciones := evaluar_opciones(estado, poseedor, jugador)
	if opciones.is_empty():
		return
	var presion := presion_normalizada(estado, poseedor["pos"], es_local)
	var temp := temperatura(jugador, presion)
	var elegida := elegir_softmax(opciones, temp, estado["rng"])

	estado["decisiones"][elegida["tipo"]] = estado["decisiones"].get(elegida["tipo"], 0) + 1
	estado["ultima_decision"] = {
		"tipo": elegida["tipo"], "temperatura": temp, "presion": presion,
		"opciones": opciones, "jugador_rol": poseedor["rol"],
	}

	match elegida["tipo"]:
		"conducir":
			_conducir(estado, poseedor)
		"pase":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador)
		"tiro":
			_resolver_tiro(estado, poseedor, jugador)


## Avanzar con la pelota hacia el arco rival. Más lento que correr libre
## (avance_conducir < 1): si no, nadie alcanza nunca al que la lleva.
static func _conducir(estado: Dictionary, poseedor: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(poseedor["equipo_local"])
	var dir: Vector2 = (arco - poseedor["pos"]).normalized()
	var paso: float = poseedor["vel_max"] * TICK_SEG * float(f["avance_conducir"])
	var nueva: Vector2 = poseedor["pos"] + dir * paso
	# El que lleva la pelota sí puede meterse en el área (a diferencia de
	# los que se posicionan sin ella, ver LIMITE_X), pero no atravesar la
	# línea de fondo.
	poseedor["pos"] = Vector2(
		clampf(nueva.x, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
		clampf(nueva.y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))


static func _intentar_robo(estado: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var pelota: Dictionary = estado["pelota"]
	var poseedor: Dictionary = estado["jugadores"][pelota["poseedor_id"]]
	var es_local: bool = poseedor["equipo_local"]
	var radio: float = f["radio_tackle"]

	# El cooldown es de LA DISPUTA, no de cada defensor: una pelota se
	# disputa cada tanto, no cuatro veces por segundo por cada rival que
	# ande cerca. Con cooldown por jugador y 10 rivales alrededor salían
	# 9.026 quites por partido (un partido real tiene del orden de 40) y
	# la posesión cambiaba 5.000 veces: puro ping-pong, no fútbol.
	if estado["tick"] - int(estado.get("ultimo_robo_tick", -999)) < int(f["ticks_cooldown_robo"]):
		return

	var mejor_id := -1
	var mejor_dist: float = radio
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == es_local:
			continue
		var d: float = poseedor["pos"].distance_to(e["pos"])
		if d < mejor_dist:
			mejor_dist = d
			mejor_id = id
	if mejor_id == -1:
		return
	estado["ultimo_robo_tick"] = estado["tick"]
	estado["robos"]["intentos"] += 1

	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var jug_a := _dict_jugador(estado, eq_a, poseedor["jugador_id"])
	var jug_d := _dict_jugador(estado, eq_d, estado["jugadores"][mejor_id]["jugador_id"])
	if jug_a.is_empty() or jug_d.is_empty():
		return

	var minuto := _minuto_int(estado)
	# El poseedor defiende su pelota con `control` contra el `quite` del rival.
	var aguanta := _duelo_simple(jug_a, "control", eq_a, jug_d, "quite", eq_d, minuto, estado["rng"])
	# Mismas tarjetas que el motor abstracto: si el partido del jugador no
	# generara amarillas ni rojas, su equipo nunca tendría suspendidos
	# mientras el resto de la liga sí — un desbalance grave, no cosmético.
	#
	# Pero la FRECUENCIA hay que corregirla: este motor disputa la pelota
	# ~2.600 veces por partido contra los ~180 duelos del abstracto, donde
	# CHANCE_AMARILLA=0.02 está calibrado. Aplicado tal cual daban ~50
	# amarillas por partido y los equipos terminaban diezmados. Solo una
	# fracción chica de los quites se disputa con riesgo de falta.
	# CHANCE_AMARILLA (2%) está calibrado sobre los ~180 duelos por partido
	# del motor abstracto. Este motor disputa la pelota ~50 veces, así que
	# aplicado una vez por quite daría 1 amarilla por partido contra las
	# ~3,6 del resto de la liga, y el equipo del jugador juntaría muchas
	# menos suspensiones que sus rivales. Se chequea varias veces por
	# disputa para igualar la tasa por PARTIDO, que es lo que importa.
	for i in range(int(f["chequeos_tarjeta_por_quite"])):
		MatchEngine._chequear_tarjeta(jug_d, eq_d, eq_a, estado["rng"], estado["eventos"], minuto, true, estado["log"])
	if not aguanta:
		estado["robos"]["ganados"] += 1
		# La pelota queda SUELTA, no pasa limpia al que la quitó: si el
		# quite entregara posesión instantánea, atacante y defensor se la
		# roban mutuamente en el mismo metro cuadrado y el partido se
		# convierte en un ping-pong (medido: 340 goles en un partido).
		_soltar_pelota(estado, poseedor["pos"], es_local)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "gambeta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "pierde",
		})


static func _push_fotograma(estado: Dictionary, evento_del_tick = null) -> void:
	var jugadores := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		jugadores.append({
			"id": id, "x": e["pos"].x, "y": e["pos"].y,
			"equipo_local": e["equipo_local"], "rol": e["rol"],
		})
	estado["fotogramas"].append({
		"tick": estado["tick"],
		"minuto": estado["minuto"],
		"pelota": {
			"x": estado["pelota"]["pos"].x, "y": estado["pelota"]["pos"].y,
			"poseedor_id": estado["pelota"]["poseedor_id"],
		},
		"jugadores": jugadores,
		"decision": estado.get("ultima_decision", null),
		# El evento semántico que ocurrió EN ESTE tick (o null). Es lo que
		# le permite a la animación mostrar el relato y el marcador en el
		# momento exacto, sin tener que cruzar por minuto contra el array
		# de eventos, que tiene otra granularidad.
		"evento": evento_del_tick,
		"goles": {"home": estado["home"].goles, "away": estado["away"].goles},
	})


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Mismo shape de salida que MatchEngine.simular (goles_local,
## goles_visitante, log, goles_log, eventos) para que Liga/GameState/
## EstadisticasPartido/Objetivos/Fans no se enteren de que ahora hay
## coordenadas — más "fotogramas" y "stats", que solo consume la
## animación y el debug (decisión 4: arrays separados).
##
## con_fotogramas=false ahorra ~22 Dictionary por tick sin cambiar NADA
## del resultado (mismas decisiones, mismo RNG): es lo que se usa cuando
## el partido no se va a animar.
static func simular(home: Team, away: Team, rng: RandomNumberGenerator, con_fotogramas: bool = false) -> Dictionary:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false
	home.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	away.forma_partido = clamp(rng.randfn(0.0, 4.0), -10.0, 10.0)
	home.clima_partido = Clima.generar(rng)
	away.clima_partido = home.clima_partido
	home.arbitro_partido = Arbitro.generar(rng)
	away.arbitro_partido = home.arbitro_partido

	var estado := crear_estado(home, away, rng)

	# Mismas ventanas de cambio que MatchEngine (§8.7): entretiempo, 60' y
	# 75'. Se reusa _procesar_cambios sin tocarlo.
	var ventanas := [45, 60, 75]
	for mitad in range(2):
		_reiniciar_desde_medio(estado, mitad == 0)
		estado["minuto"] = MINUTOS_MOSTRADOS_POR_MITAD * mitad
		for t in range(TICKS_POR_MITAD):
			_tick(estado, con_fotogramas)
			if not ventanas.is_empty() and estado["minuto"] >= ventanas[0]:
				var minuto_ventana: int = ventanas.pop_front()
				MatchEngine._procesar_cambios(home, away, minuto_ventana, true, estado["log"], estado["eventos"])
				_sincronizar_cambios(estado)

	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": estado["log"],
		"goles_log": estado["goles_log"],
		"eventos": estado["eventos"],
		"fotogramas": estado["fotogramas"],
		"stats": {
			"ticks": estado["tick"],
			"posesion": estado["posesion_ticks"],
			"tiros": estado["tiros"],
			"dist_tiros": estado["dist_tiros"],
			"robos": estado["robos"],
			"pase_detalle": estado["pase_detalle"],
			"pases": estado["pases"],
			"decisiones": estado["decisiones"],
		},
	}
