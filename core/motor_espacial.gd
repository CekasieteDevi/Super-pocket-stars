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

## Con el juego detenido nadie corre: se acomodan trotando. Además de que
## es lo que se ve en una cancha, sirve para que el reacomodo se lea como
## un movimiento y no como un salto de un fotograma al otro.
const FACTOR_TROTE_PARADO := 0.45

## Medio ancho del arco (7,32 m reglamentarios). Lo usa el remate para
## saber dónde termina la portería y dónde empieza el afuera.
const ARCO_MEDIO_ANCHO := 3.66

## Metros extra que cubre un arquero tirándose, por encima de lo que
## alcanza a correr mientras la pelota viaja.
const ALCANCE_ESTIRADA := 2.0

## Cuántos ticks queda detenido el juego según lo que se cobró. Un tick
## son 0,25 s, así que 10 ticks son 2,5 segundos de reloj de partido: lo
## suficiente para que se vea que el juego paró y que la gente se acomoda,
## sin que aburra a x1.
const TICKS_DETENIDO := {"falta": 8, "corner": 10, "gol": 10, "saque_inicial": 4}

## Cuánto le achica el margen de error de desmarque el rasgo Enfocado.
## No es cero: hasta el delantero más atento se va alguna vez, y ponerlo
## en cero convertiría al rasgo en una inmunidad, que no es lo que dice
## el GDD.
const FACTOR_OFFSIDE_ENFOCADO := 0.2

## Metros de gracia al juzgar la infracción para el que tiene Enfocado.
## Ver el comentario en _lanzar_pase: es el desmarque cronometrado que no
## entra en un tick de 0,25 s, no una excepción al reglamento.
const TOLERANCIA_OFFSIDE_ENFOCADO := 1.6

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


# ---------------------------------------------------------------------------
# Acciones físicas (dato de animación, no de simulación)
# ---------------------------------------------------------------------------

## Actos físicos que la vista puede animar. NADA del motor los lee: son un
## canal aparte de los eventos semánticos, porque los eventos no sirven
## para animar. Un pase se registra como evento cuando LLEGA (o cuando lo
## cortan), y para animar la patada hace falta saberlo cuando SALE; y el
## evento trae el ROL del que la jugó, no su clave, así que no alcanza
## para saber a cuál de los 22 mover.
const ACCION_PATEA := "patea"
const ACCION_BARRIDA := "barrida"
const ACCION_VUELA := "vuela"


## Registra que `clave` hizo `accion` en el tick actual. Solo cuesta algo
## cuando se están generando fotogramas: en el resto de la liga, que
## simula sin animación, es un `return` inmediato.
static func _accion(estado: Dictionary, clave: int, accion: String) -> void:
	if not bool(estado.get("con_fotogramas", false)):
		return
	if clave == -1:
		return
	estado["acciones_tick"].append({"clave": clave, "accion": accion})


static func _clave_arquero(estado: Dictionary, es_local: bool) -> int:
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == es_local and e["rol"] == "ARQ":
			return id
	return -1


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
## `jugador` define el ALCANCE: hasta dónde le da para patear. Un jugador
## de tiro flojo solo ve chance cerca del área — más lejos la utilidad de
## rematar se le cae a cero y prefiere seguir metiéndose o pasarla, que es
## lo que hace un jugador limitado en la vida real. Uno de tiro alto sí
## valora el remate de media distancia. Sin esto, un media 20 evaluaba
## pegarle desde 25 metros exactamente igual que un crack (medido: 23% de
## sus remates salían desde más de 20m).
static func factor_geometria(pos: Vector2, equipo_local: bool, jugador: Dictionary = {}) -> float:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(equipo_local)
	var dist := pos.distance_to(arco)
	var dx: float = maxf(absf(arco.x - pos.x), 1.0)
	var dy: float = absf(pos.y)
	var rango: float = float(f["rango_tiro_medio"])
	if not jugador.is_empty():
		rango = _por_atributo(jugador, "tiro", f["rango_tiro_malo"], f["rango_tiro_bueno"])
	var f_dist: float = clampf(1.0 - (dist - 5.0) / rango, 0.0, 1.0)
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


## Con qué atributo ejecuta un pase este jugador. Un jugador de campo usa
## `pases`; el arquero usa los suyos, que hasta ahora no los leía nadie:
## `pies` para la salida corta (jugar desde el fondo) y `golpe` para el
## saque largo. Así un arquero con buen pie saca jugando y uno que solo
## tiene pierna revienta la pelota — y de eso depende que el saque de arco
## termine en un compañero o en un rival.
static func atributo_pase(jugador: Dictionary, distancia: float) -> String:
	if jugador.get("posicion", "") != "ARQ":
		return "pases"
	return "golpe" if distancia > float(pesos()["fisica"]["dist_saque_largo"]) else "pies"


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
			# Se copia acá para no tener que buscar el dict del jugador en
			# cada tick solo para medir el desmarque (ver offside).
			"inteligencia": float(j["atributos"]["inteligencia"]),
			# Enfocado (§6): "no se va en offside". No se modela como
			# inteligencia extra —eso le mejoraría también la lectura del
			# pase— sino como un factor propio sobre el margen de error al
			# medir el desmarque.
			# Enfocado corrige DOS cosas distintas: dónde se para (margen)
			# y cuándo arranca el desmarque (tolerancia).
			"margen_offside": FACTOR_OFFSIDE_ENFOCADO if Personalidad.tiene(j, "Enfocado") else 1.0,
			"tolerancia_offside": TOLERANCIA_OFFSIDE_ENFOCADO if Personalidad.tiene(j, "Enfocado") else 0.0,
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
		# Ver _accion: actos físicos del tick en curso, para la animación.
		"con_fotogramas": false,
		"acciones_tick": [],
		"robo_cooldown": {},
		"robos": {"intentos": 0, "ganados": 0},
		"gambetas": {"home": {"intentos": 0, "ganadas": 0}, "away": {"intentos": 0, "ganadas": 0}},
		"paredes": {},
		"centros": {},
		"reinicios": {},
		"cooldown": {},
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
	var geo := factor_geometria(pos, es_local, jugador)
	if geo > float(f["geometria_minima_tiro"]):
		var wt: Dictionary = w["tiro"]
		var u_tiro: float = wt["base"] + wt["geometria"] * geo
		if Personalidad.tiene(jugador, "Egoista"):
			u_tiro *= float(sesgos["egoista_tiro"])
		opciones.append({
			"tipo": "tiro", "utilidad": u_tiro,
			"detalle": {"geometria": geo},
		})

	# --- Despeje ------------------------------------------------------
	# Metido en tu campo y con gente encima: reventarla arriba y lejos. A
	# diferencia del pelotazo no busca a nadie — es sacarla de la zona de
	# peligro, y por eso no pide ningún atributo técnico.
	if mi_valor <= float(f["zona_despeje"]) and presion >= float(f["presion_despeje"]):
		var wd: Dictionary = w["despeje"]
		opciones.append({
			"tipo": "despeje",
			"utilidad": wd["base"] + wd["presion"] * presion + wd["zona"] * (1.0 - mi_valor),
			"detalle": {"presion": presion, "mi_valor": mi_valor},
		})

	# --- Gambetear al rival que le tapa el camino ---------------------
	# A diferencia de conducir (llevarla y ver qué pasa), acá ELIGE ir
	# contra un rival puntual. Solo aparece si hay alguien a quien encarar:
	# gambetear al aire no significa nada.
	# Encarar hay que SABER hacerlo: por debajo de este control la opción
	# ni aparece, igual que el pase al hueco con la visión. Sin el umbral,
	# un jugador de control 30 encaraba más seguido que uno de 60 —
	# elegía gambeta por descarte, porque sus otras opciones eran peores
	# todavía, y la perdía casi siempre.
	# Quién le tapa el camino: lo necesitan TANTO la gambeta como la pared,
	# así que se calcula aparte del umbral de gambetear. Atarlo al umbral
	# dejaba la pared exigiendo `control` 50 sin querer — justo al revés,
	# porque la pared es el recurso del que NO puede pasarlo por sí solo.
	var rival_delante := _rival_a_encarar(estado, pos, es_local)
	var sabe_gambetear: bool = float(jugador["atributos"]["control"]) >= float(f["control_minimo_gambeta"])
	var rival_a_encarar := rival_delante if sabe_gambetear else -1
	if rival_a_encarar != -1:
		var wg: Dictionary = w["gambeta"]
		var e_rival: Dictionary = estado["jugadores"][rival_a_encarar]
		# Lo que decide encarar no es lo bueno que sos, sino si a ESE lo
		# podés pasar: pesa la diferencia entre tu control y su quite. Con
		# la utilidad mirando solo el control propio, un jugador de control
		# 30 igual encaraba 20-30 veces por partido y las perdía todas,
		# porque sus otras opciones eran peores todavía.
		var eq_rival := _equipo_de(estado, not es_local)
		var rival_dict := _dict_jugador(estado, eq_rival, e_rival["jugador_id"])
		var quite_rival: float = float(rival_dict["atributos"]["quite"]) if not rival_dict.is_empty() else 50.0
		var ventaja: float = clampf(
			(float(jugador["atributos"]["control"]) - quite_rival) / 100.0 + 0.5, 0.0, 1.0)
		var u_gambeta: float = wg["base"] \
			+ wg["habilidad"] * ventaja * ventaja \
			+ wg["progreso"] * (1.0 - mi_valor) \
			- wg["presion"] * presion
		opciones.append({
			"tipo": "gambeta", "utilidad": u_gambeta, "objetivo_id": rival_a_encarar,
			"detalle": {"rival": e_rival["rol"], "presion": presion},
		})

	# --- Pasar a cada compañero alcanzable ----------------------------
	var wp: Dictionary = w["pase"]
	# Hasta dónde llega su pase: un central de división 10 no cambia el
	# frente de juego de 45 metros. El arquero se mide por `golpe`, que es
	# lo que define hasta dónde le llega el saque.
	var attr_alcance := "golpe" if jugador.get("posicion", "") == "ARQ" else "pases"
	var max_dist: float = _por_atributo(jugador, attr_alcance, f["max_dist_pase_malo"], f["max_dist_pase_bueno"])
	var sesgo_pase: float = float(sesgos["creador_pase"]) if Personalidad.tiene(jugador, "Creador") else 1.0
	# El pase al hueco hay que VERLO: si el jugador no tiene la visión, la
	# opción ni le aparece. Es lo que separa a un armador de un jugador que
	# solo la toca al de al lado.
	var wh: Dictionary = w["pase_hueco"]
	# El pelotazo llega tan lejos como la pierna del que la pega, no como
	# su técnica: por eso un equipo malo igual lo tiene disponible.
	var wl: Dictionary = w["pase_largo"]
	var max_largo: float = _por_atributo(jugador, "fuerza", f["max_pelotazo_debil"], f["max_pelotazo_fuerte"])
	# La pared la habilita `pases`, y ese mismo atributo define su tamaño:
	# el que la toca mejor puede jugarla con un compañero más lejos y salir
	# a recibirla más adelante.
	# Centrar: hay que estar abierto y adelantado, y saber pegarle. Usa
	# `centros`, que existía en el GDD y no lo leía nadie.
	var puede_centrar: bool = float(jugador["atributos"]["centros"]) >= float(f["centros_minimo"]) \
		and absf(pos.y) >= float(f["banda_para_centrar"]) \
		and valor_posicion(pos, es_local) >= float(f["avance_para_centrar"])
	var wpa: Dictionary = w["pared"]
	var pases_jugador: float = float(jugador["atributos"]["pases"])
	var sabe_pared: bool = pases_jugador >= float(f["pases_minimo_pared"])
	var dist_max_muro: float = _por_atributo(jugador, "pases", f["pared_muro_cerca"], f["pared_muro_lejos"])
	var avance_pared: float = _por_atributo(jugador, "pases", f["pared_avance_min"], f["pared_avance_max"])
	var vision_jugador: float = float(jugador["atributos"]["vision"])
	var umbral_vision: float = float(f["vision_minima_hueco"])
	var ve_el_hueco: bool = vision_jugador >= umbral_vision
	var factor_vision: float = 1.0 + float(f["hueco_por_vision"]) \
		* clampf((vision_jugador - umbral_vision) / maxf(100.0 - umbral_vision, 1.0), 0.0, 1.0)
	for id in estado["jugadores"]:
		var comp: Dictionary = estado["jugadores"][id]
		if comp["equipo_local"] != es_local or id == poseedor["clave"]:
			continue
		var dist: float = pos.distance_to(comp["pos"])
		if dist < 2.0:
			continue

		# --- Pelotazo ------------------------------------------------
		# Para los que están MÁS LEJOS de lo que llega un pase normal. No
		# hace falta ser buen pasador: el alcance sale de `fuerza`, así
		# que un equipo limitado que no puede salir jugando igual la
		# puede reventar hacia adelante. Que sea de baja efectividad sale
		# solo del motor: una pelota que viaja mucho es más fácil de leer
		# (ver lectura_pase_largo en _gana_intercepcion).
		if dist > max_dist:
			if dist > max_largo or progreso_hacia(comp, pos, es_local) <= 0.0:
				continue
			var u_largo: float = wl["base"] \
				+ wl["progreso"] * (valor_posicion(comp["pos"], es_local) - mi_valor) \
				+ wl["presion"] * presion \
				+ wl["salida"] * (1.0 - mi_valor)
			opciones.append({
				"tipo": "pase_largo", "utilidad": u_largo, "objetivo_id": id,
				"detalle": {"dist": dist, "presion": presion},
			})
			continue
		var progreso: float = valor_posicion(comp["pos"], es_local) - mi_valor
		var riesgo := riesgo_linea(estado, pos, comp["pos"], es_local)
		var u_pase: float = wp["base"] \
			+ wp["progreso"] * progreso \
			+ wp["seguridad"] * (1.0 - riesgo) \
			- wp["distancia"] * (dist / max_dist)
		opciones.append({
			"tipo": "pase", "utilidad": u_pase, "objetivo_id": id,
			"detalle": {"progreso": progreso, "riesgo": riesgo, "dist": dist},
		})

		# --- Centro --------------------------------------------------
		# Desde la banda y adelantado, colgarla al área. Vuela por encima
		# de todos (ver altura_max), así que no se corta en el camino: se
		# define en el duelo aéreo al caer.
		if puede_centrar and _en_el_area(comp["pos"], es_local):
			var wce: Dictionary = w["centro"]
			var u_centro: float = wce["base"] \
				+ wce["punteria"] * (float(jugador["atributos"]["centros"]) / 100.0) \
				+ wce["progreso"] * (valor_posicion(comp["pos"], es_local) - mi_valor)
			opciones.append({
				"tipo": "centro", "utilidad": u_centro, "objetivo_id": id,
				"detalle": {"centros": jugador["atributos"]["centros"]},
			})

		# --- Pared ---------------------------------------------------
		# Se la da al compañero y sale corriendo a recibirla del otro lado
		# del que lo marca. Son DOS pases encadenados, así que hay dos
		# chances de que se la corten: por eso es una jugada de los que
		# saben pasar, no de cualquiera.
		if sabe_pared and dist <= dist_max_muro and rival_delante != -1:
			var retorno := _punto_retorno_pared(pos, es_local, avance_pared)
			var riesgo_muro := riesgo_linea(estado, pos, comp["pos"], es_local)
			var u_pared: float = wpa["base"] \
				+ wpa["progreso"] * (valor_posicion(retorno, es_local) - mi_valor) \
				+ wpa["seguridad"] * (1.0 - riesgo_muro)
			opciones.append({
				"tipo": "pared", "utilidad": u_pared, "objetivo_id": id, "punto": retorno,
				"detalle": {"riesgo_muro": riesgo_muro, "avance": avance_pared},
			})

		# --- Pase al hueco -------------------------------------------
		# No va a los pies: va al espacio POR DELANTE del compañero, que
		# tiene que salir a buscarlo. Rompe la línea de fondo rival, pero
		# la pelota viaja más y por una zona más disputada, así que la
		# chance de que la corten es bastante mayor.
		if not ve_el_hueco:
			continue
		var punto := _punto_al_hueco(comp, es_local)
		var dist_hueco: float = pos.distance_to(punto)
		if dist_hueco > max_dist:
			continue
		var progreso_hueco: float = valor_posicion(punto, es_local) - mi_valor
		var riesgo_hueco := riesgo_linea(estado, pos, punto, es_local)
		var u_hueco: float = wh["base"] \
			+ wh["progreso"] * progreso_hueco \
			+ wh["seguridad"] * (1.0 - riesgo_hueco) \
			- wh["distancia"] * (dist_hueco / max_dist)
		# La visión no solo HABILITA el hueco: cuanta más tiene, más lo ve
		# y más lo intenta. Con el umbral solo, un jugador de visión 90
		# tiraba exactamente los mismos huecos que uno de 46.
		u_hueco *= sesgo_pase * factor_vision
		opciones.append({
			"tipo": "pase_hueco", "utilidad": u_hueco, "objetivo_id": id, "punto": punto,
			"detalle": {"progreso": progreso_hueco, "riesgo": riesgo_hueco, "dist": dist_hueco},
		})

	_aplicar_pie_preferido(estado, opciones, poseedor, jugador, es_local,
		float(sesgos["pie_preferido_penalizacion"]))
	return opciones


## Adónde va la pelota si elige esta opción, o null si la opción no manda
## la pelota a ningún lado concreto (conducir, gambeta, despeje).
static func _destino_de_opcion(estado: Dictionary, opcion: Dictionary, es_local: bool):
	var tipo := str(opcion["tipo"])
	if tipo == "tiro":
		return arco_rival(es_local)
	# El pase al hueco NO va a los pies del compañero sino al espacio por
	# delante, así que ahí manda el punto; en la pared, en cambio, `punto`
	# es adónde sale a correr ÉL y la pelota va al compañero.
	if tipo == "pase_hueco" and opcion.has("punto"):
		return opcion["punto"]
	if opcion.has("objetivo_id") and estado["jugadores"].has(int(opcion["objetivo_id"])):
		return estado["jugadores"][int(opcion["objetivo_id"])]["pos"]
	return null


## Pie preferido (§6): le cuesta jugar hacia el lado de su pie malo.
##
## Baja las GANAS, no la calidad de ejecución: es un sesgo de decisión
## como el resto de los rasgos que toca este motor (ver §4.1 del doc). Un
## diestro con el rasgo se la juega menos veces hacia su izquierda; si
## igual la juega, la pega tan bien como siempre.
##
## Se mide contra el eje transversal de la cancha orientado al ataque,
## que es la única referencia estable disponible: el motor no modela
## hacia dónde mira el cuerpo, así que "a su izquierda" tiene que salir
## del sentido en que ataca su equipo. Y se RESTA en vez de multiplicar
## porque las utilidades pueden ser negativas, y multiplicar una utilidad
## negativa por un factor menor a 1 la MEJORA.
## Cuánto de su lado malo tiene jugar hacia `destino`: 0 si va hacia su
## pie bueno, hasta 1 si cruza del todo hacia el malo. Devuelve 0 para
## cualquiera que no tenga el rasgo, así el resto del motor no paga nada
## por consultarlo.
##
## Se mide contra el eje transversal de la cancha orientado al ataque,
## que es la única referencia estable disponible: el motor no modela
## hacia dónde mira el cuerpo, así que "a su izquierda" tiene que salir
## del sentido en que ataca su equipo.
static func _cruce_al_pie_malo(jugador: Dictionary, desde: Vector2, destino: Vector2, es_local: bool) -> float:
	if not Personalidad.tiene(jugador, "Pie preferido"):
		return 0.0
	var d: Vector2 = destino - desde
	if d.length_squared() < 0.01:
		return 0.0
	var lateral: float = d.normalized().y * (1.0 if es_local else -1.0)
	if lateral * float(Personalidad.pie_preferido(jugador)) >= 0.0:
		return 0.0
	return absf(lateral)


## Cuánto le rinde el atributo técnico en una acción hacia `destino`. Es
## la CONTRACARA del sesgo de decisión: el jugador evita jugar hacia su
## lado malo, pero cuando no le queda otra, además la pega peor. Sin esta
## mitad el rasgo no costaba nada —esquivar el lado malo hasta le mejoraba
## el juego— y un rasgo negativo que no se paga no es un rasgo.
static func factor_pie(jugador: Dictionary, desde: Vector2, destino: Vector2, es_local: bool) -> float:
	var cruce := _cruce_al_pie_malo(jugador, desde, destino, es_local)
	if cruce <= 0.0:
		return 1.0
	return lerpf(1.0, float(pesos()["sesgos_personalidad"]["pie_preferido_ejecucion"]), cruce)


static func _aplicar_pie_preferido(estado: Dictionary, opciones: Array, poseedor: Dictionary,
		jugador: Dictionary, es_local: bool, penalizacion: float) -> void:
	if not Personalidad.tiene(jugador, "Pie preferido"):
		return
	for o in opciones:
		var destino = _destino_de_opcion(estado, o, es_local)
		if destino == null:
			continue
		var cruce := _cruce_al_pie_malo(jugador, poseedor["pos"], destino, es_local)
		if cruce > 0.0:
			o["utilidad"] -= penalizacion * cruce


## ¿A quién tiene enfrente para encarar? El rival más cercano que esté
## cerca Y entre él y el arco: no se gambetea a alguien que quedó atrás.
static func _rival_a_encarar(estado: Dictionary, pos: Vector2, es_local: bool) -> int:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(es_local)
	var dir_ataque := (arco - pos).normalized()
	var radio: float = f["radio_gambeta"]
	var mejor := -1
	var mejor_d: float = radio
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == es_local or e["rol"] == "ARQ":
			continue
		if _en_cooldown(estado, id):
			continue  # ya lo pasó, no hay a quién encarar
		var hacia: Vector2 = e["pos"] - pos
		var d: float = hacia.length()
		if d >= mejor_d or d < 0.5:
			continue
		# Tiene que estar DELANTE, no al costado ni atrás.
		if dir_ataque.dot(hacia.normalized()) < float(f["gambeta_cono_frontal"]):
			continue
		mejor_d = d
		mejor = id
	return mejor


## Resuelve una gambeta: `control`+`agilidad` del que encara contra
## `quite`+`agilidad` del que marca, con los bloques de siempre (así las
## habilidades de control como Bailarín o Cohete empujan solas). El que
## pierde queda pasado — reusa la misma penalización del quite, que es
## exactamente lo que hace una gambeta real: sacarte un hombre de encima
## por unos segundos.
static func _resolver_gambeta(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary, clave_rival: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var es_local: bool = poseedor["equipo_local"]
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var e_rival: Dictionary = estado["jugadores"][clave_rival]
	var defensor := _dict_jugador(estado, eq_d, e_rival["jugador_id"])
	if defensor.is_empty():
		return

	var minuto := _minuto_int(estado)
	var lado_g := "home" if es_local else "away"
	estado["gambetas"][lado_g]["intentos"] += 1
	# El que va a ser encarado se tira a cortarla.
	_accion(estado, clave_rival, ACCION_BARRIDA)

	var att_a: Dictionary = jugador["atributos"]
	var att_d: Dictionary = defensor["atributos"]
	var habilidad: float = float(att_a["control"]) * 0.7 + float(att_a["agilidad"]) * 0.3
	var marca: float = float(att_d["quite"]) * 0.7 + float(att_d["agilidad"]) * 0.3

	var ata := Duel.atributo_efectivo(habilidad, "tecnico", eq_a.resistencia_pct(jugador["id"]))
	var def := Duel.atributo_efectivo(marca, "defensivo", eq_d.resistencia_pct(defensor["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, jugador, "control", minuto, estado["rng"]),
		MatchEngine._bloques_equipo(eq_d, eq_a, defensor, "quite", minuto, estado["rng"]))
	# Encarar es exponerse: la falta se chequea igual que en un quite.
	_chequear_tarjeta_repetido(estado, defensor, eq_d, eq_a, minuto)

	if Duel.gana_atacante(res, estado["rng"]):
		estado["gambetas"][lado_g]["ganadas"] += 1
		# Se lo saca de encima: queda más allá del defensor, y el defensor
		# pasado unos segundos.
		var arco := arco_rival(es_local)
		var dir: Vector2 = (arco - poseedor["pos"]).normalized()
		var salida: Vector2 = e_rival["pos"] + dir * float(f["gambeta_avance"])
		poseedor["pos"] = Vector2(
			clampf(salida.x, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
			clampf(salida.y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
		_penalizar(estado, clave_rival, defensor)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "gambeta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "pasa",
		})
	else:
		_entregar_pelota(estado, clave_rival)
		_penalizar(estado, poseedor["clave"], jugador)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "gambeta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "pierde",
		})


## ¿Está dentro del área grande rival? (16,5m de fondo, 40,32m de ancho).
static func _en_el_area(punto: Vector2, es_local: bool) -> bool:
	var arco := arco_rival(es_local)
	return absf(arco.x - punto.x) <= 16.5 and absf(punto.y) <= 20.16


## Cuando cae un centro: se lo disputan por arriba. Ataca `cabezazo` +
## `salto`; defiende `salto` + `fuerza`. Y el arquero puede salir a
## descolgarla si cae cerca suyo, con `achique` — otro atributo del GDD
## que no leía nadie.
static func _resolver_centro(estado: Dictionary, punto: Vector2, ataca_local: bool, minuto: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	estado["centros"]["caidos"] = int(estado["centros"].get("caidos", 0)) + 1

	# El arquero primero: si cae en su zona, sale a descolgarla.
	var arq_clave := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != ataca_local and e["rol"] == "ARQ":
			arq_clave = id
			break
	if arq_clave != -1:
		var arq_e: Dictionary = estado["jugadores"][arq_clave]
		if punto.distance_to(arq_e["pos"]) <= float(f["radio_achique"]):
			var arq := eq_d.arquero()
			var chance: float = float(arq["atributos"]["achique"]) / 100.0 * float(f["achique_eficacia"])
			if rng.randf() < chance:
				estado["centros"]["descolgado"] = int(estado["centros"].get("descolgado", 0)) + 1
				_entregar_pelota(estado, arq_clave)
				estado["eventos"].append({
					"minuto": minuto, "tipo": "centro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
					"jugador_posicion": "ARQ", "resultado": "descuelga",
				})
				return

	var atacante := _mas_cercano_del_equipo(estado, punto, ataca_local)
	var defensor := _mas_cercano_del_equipo(estado, punto, not ataca_local)
	if atacante == -1:
		_pelota_fuera(estado, punto, ataca_local)
		return
	if defensor == -1:
		_entregar_pelota(estado, atacante)
		return

	var j_a := _dict_jugador(estado, eq_a, estado["jugadores"][atacante]["jugador_id"])
	var j_d := _dict_jugador(estado, eq_d, estado["jugadores"][defensor]["jugador_id"])
	if j_a.is_empty() or j_d.is_empty():
		_entregar_pelota(estado, atacante)
		return

	var ata: float = float(j_a["atributos"]["cabezazo"]) * 0.6 + float(j_a["atributos"]["salto"]) * 0.4
	var def: float = float(j_d["atributos"]["salto"]) * 0.5 + float(j_d["atributos"]["cabezazo"]) * 0.3 \
		+ float(j_d["atributos"]["fuerza"]) * 0.2
	var res := Duel.resolver(
		Duel.atributo_efectivo(ata, "tecnico", eq_a.resistencia_pct(j_a["id"])),
		Duel.atributo_efectivo(def, "fisico", eq_d.resistencia_pct(j_d["id"])),
		MatchEngine._bloques_equipo(eq_a, eq_d, j_a, "cabezazo", minuto, rng),
		MatchEngine._bloques_equipo(eq_d, eq_a, j_d, "salto", minuto, rng))

	if Duel.gana_atacante(res, rng):
		estado["centros"]["ganados"] = int(estado["centros"].get("ganados", 0)) + 1
		_entregar_pelota(estado, atacante)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "centro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": estado["jugadores"][atacante]["rol"], "resultado": "gana",
		})
		# Ganó de arriba dentro del área: cabecea al arco. Antes se
		# quedaba la pelota y seguía jugando, que es lo que hacía que un
		# centro ganado no terminara casi nunca en gol.
		if _en_el_area(punto, ataca_local):
			estado["centros"]["cabezazos"] = int(estado["centros"].get("cabezazos", 0)) + 1
			_resolver_tiro(estado, estado["jugadores"][atacante], j_a, "cabezazo")
	else:
		_entregar_pelota(estado, defensor)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "centro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": estado["jugadores"][defensor]["rol"], "resultado": "despeja",
		})


## Adónde sale a recibir el que juega la pared: por delante suyo, hacia el
## arco rival. La distancia la da su `pases` (ver avance_pared).
static func _punto_retorno_pared(desde: Vector2, es_local: bool, avance: float) -> Vector2:
	var dir: Vector2 = (arco_rival(es_local) - desde).normalized()
	return Vector2(
		clampf(desde.x + dir.x * avance, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0),
		clampf(desde.y + dir.y * avance, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0))


## Cuánto terreno gana mandarla a este compañero. Negativo = está más
## atrás que yo, o sea que el pelotazo no tendría sentido.
static func progreso_hacia(comp: Dictionary, desde: Vector2, es_local: bool) -> float:
	return valor_posicion(comp["pos"], es_local) - valor_posicion(desde, es_local)


## Adónde tirar el hueco: por delante del compañero, hacia el arco rival.
## Cuanto más rápido es el que lo va a buscar, más largo se lo puede tirar.
static func _punto_al_hueco(comp: Dictionary, es_local: bool) -> Vector2:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(es_local)
	var dir: Vector2 = (arco - comp["pos"]).normalized()
	var largo: float = float(f["hueco_min"]) + (float(f["hueco_max"]) - float(f["hueco_min"])) \
		* clampf((float(comp["vel_max"]) - float(f["vel_min"])) / maxf(float(f["vel_max"]) - float(f["vel_min"]), 0.01), 0.0, 1.0)
	return Vector2(
		clampf(comp["pos"].x + dir.x * largo, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0),
		clampf(comp["pos"].y + dir.y * largo, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0))


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
	# Metódico (§6): juega al libro. Con menos temperatura el softmax se
	# vuelve más determinista, o sea elige casi siempre la opción de mayor
	# utilidad en vez de probar cosas. Va sobre el valor ya calculado y no
	# sobre la base, así el rasgo también le come parte del nerviosismo
	# por presión — que es justamente lo que se supone que hace ser
	# metódico.
	if Personalidad.tiene(jugador, "Metodico"):
		valor *= float(t["factor_metodico"])
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
	var f: Dictionary = pesos()["fisica"]
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
		# Dónde se para respecto de la línea: el que mide bien el
		# desmarque se queda un metro detrás, el que no la calcula se pasa
		# y queda habilitando el offside. Este offset ES la fuente de los
		# offsides — con un "siempre un metro detrás" fijo, nadie se iba
		# nunca y la infracción no ocurría jamás.
		var intel: float = clampf(float(e.get("inteligencia", 50.0)) / 100.0, 0.0, 1.0)
		var offset: float = lerpf(float(f["offside_margen_torpe"]), -1.5, intel) * float(e.get("margen_offside", 1.0))
		if e["equipo_local"]:
			objetivo_x = maxf(objetivo_x, float(linea_ataque["local"]) + offset)
		else:
			objetivo_x = minf(objetivo_x, float(linea_ataque["away"]) - offset)

	# Mantenerse habilitado: nadie se adelanta al último defensor rival.
	# El offside como infracción queda fuera del MVP, pero la CONDUCTA de
	# no irse en offside no es opcional — sin ella los delanteros acampan
	# pegados al arco (x=50, el límite de cancha) y la mediana de remate
	# se va a 2.5 metros, o sea todos los goles desde adentro del área
	# chica. Es además mucho más barato que modelar la infracción.
	if rol != "ARQ":
		var linea: Dictionary = estado["linea_offside"]
		# Margen de error al medir el desmarque: un delantero inteligente
		# se queda al filo, uno limitado se pasa. Sin este margen nadie se
		# iba nunca en offside y la infracción no existiría en la práctica.
		var margen: float = float(f["offside_margen_torpe"]) \
			* (1.0 - clampf(float(e.get("inteligencia", 50.0)) / 100.0, 0.0, 1.0)) \
			* float(e.get("margen_offside", 1.0))
		if e["equipo_local"]:
			objetivo_x = minf(objetivo_x, float(linea["local"]) + margen)
		else:
			objetivo_x = maxf(objetivo_x, float(linea["away"]) - margen)

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


static func _mover_hacia(e: Dictionary, objetivo: Vector2, factor: float = 1.0) -> void:
	var delta: Vector2 = objetivo - e["pos"]
	var paso: float = e["vel_max"] * TICK_SEG * factor
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
	# En un saque del medio TODOS tienen que estar en su propia mitad. Las
	# posiciones base de los de arriba (EXT en x=8, DC en x=14) están en
	# campo rival —correctas durante el juego, no para un saque—, así que
	# hay que replegarlos: si no, se ve a tres rivales parados adentro de
	# tu campo antes de que la pelota se mueva.
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		var base: Vector2 = e["base"]
		var x: float = minf(base.x, -1.0) if e["equipo_local"] else maxf(base.x, 1.0)
		e["pos"] = Vector2(x, base.y)
		e["vel"] = Vector2.ZERO
	estado["pelota"]["pos"] = Vector2.ZERO
	estado["pelota"]["vel"] = Vector2.ZERO
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["es_remate"] = false
	estado["pelota"]["altura_max"] = 0.0
	estado["pelota"]["z"] = 0.0
	estado["pelota"]["ticks_con_pelota"] = 0
	# El saque del medio cancela cualquier balón parado pendiente: si un
	# tiempo termina con el juego detenido, el siguiente no puede arrancar
	# esperando una falta que ya no existe.
	estado["detenido"] = 0
	estado.erase("balon_parado")
	# la saca el MCO del equipo que corresponde
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == saca_local and e["rol"] == "MCO":
			estado["pelota"]["poseedor_id"] = id
			e["pos"] = Vector2.ZERO
			return
	estado["pelota"]["poseedor_id"] = -1


## `attr_remate` permite rematar con otro atributo que no sea `tiro`: un
## cabezazo tras un centro se resuelve con `cabezazo`, no con el pie.
static func _resolver_tiro(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary, attr_remate: String = "tiro") -> void:
	var es_local: bool = poseedor["equipo_local"]
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var minuto := _minuto_int(estado)
	var geo := factor_geometria(poseedor["pos"], es_local, jugador)
	var clave := "home" if es_local else "away"
	# Un cabezazo no es una patada; por ahora no hay sprite propio, así que
	# se anima igual que un remate de pie.
	_accion(estado, int(poseedor["clave"]), ACCION_PATEA)
	estado["tiros"][clave] += 1
	estado["dist_tiros"].append(poseedor["pos"].distance_to(arco_rival(es_local)))

	# ¿Se cruza un defensor en el camino? Un remate bloqueado no llega
	# nunca al arquero, y muchas veces sale desviado al córner: es una de
	# las fuentes reales de córners.
	# Meterse en la línea del remate da la OPORTUNIDAD; que el bloqueo
	# salga o no lo decide un duelo (ver _gana_bloqueo), así que un
	# defensor flojo no le tapa el remate a un delantero de élite.
	# Un cabezazo no se bloquea con el cuerpo: viene por arriba y ya se
	# disputo en el duelo aereo.
	var bloqueador := -1 if attr_remate == "cabezazo" else _bloqueador_de_tiro(estado, poseedor["pos"], es_local)
	if bloqueador != -1 and _gana_bloqueo(estado, bloqueador, jugador, eq_a, eq_d, poseedor["pos"], es_local, minuto):
		_accion(estado, bloqueador, ACCION_BARRIDA)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "clave": poseedor["clave"], "resultado": "bloqueado",
		})
		_resolver_rebote(estado, estado["jugadores"][bloqueador]["pos"], not es_local)
		return

	# §4.6: el destino ya no depende solo del atributo, también de dónde
	# está parado el que remata. Calibrado contra un partido real: ~35% de
	# los remates van al arco, y de esos entra ~1 de cada 3.
	var r: Dictionary = pesos()["tiro_resolucion"]
	# Pie preferido: rematar cruzando hacia su lado malo le sale peor. Un
	# diestro abierto por la izquierda tiene el arco hacia su derecha, o
	# sea del lado bueno — el rasgo castiga la posición incómoda, no la
	# banda, que es como funciona de verdad.
	var f_pie := factor_pie(jugador, poseedor["pos"], arco_rival(es_local), es_local)
	var remate_efectivo: float = float(jugador["atributos"][attr_remate]) * f_pie
	var calidad: float = remate_efectivo / 100.0 * float(r["peso_atributo"]) + geo * float(r["peso_geometria"])
	var chance_porteria: float = clampf(float(r["porteria_base"]) + calidad * float(r["porteria_calidad"]), 0.05, 0.85)
	var chance_palo: float = float(r["palo"]) * calidad
	var roll := rng.randf()

	if roll > chance_porteria:
		_lanzar_remate(estado, poseedor, {
			"tipo": "afuera" if roll > chance_porteria + chance_palo else "palo",
			"es_local": es_local, "clave": poseedor["clave"], "rol": poseedor["rol"],
		})
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
	var tiro_efectivo: float = remate_efectivo * (float(r["fuerza_base"]) + (1.0 - float(r["fuerza_base"])) * geo)
	var ata := Duel.atributo_efectivo(tiro_efectivo, "tecnico", eq_a.resistencia_pct(jugador["id"]))
	var def := Duel.atributo_efectivo(arquero_valor, "tecnico", eq_d.resistencia_pct(arquero["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, jugador, attr_remate, minuto, rng),
		MatchEngine._bloques_equipo(eq_d, eq_a, arquero, "reflejos", minuto, rng))
	var mult_tiro: float = float(pesos()["fisica"]["multiplicador_desgaste"])
	eq_a.desgastar(jugador["id"], jugador["atributos"]["energia"], mult_tiro)
	eq_d.desgastar(arquero["id"], arq_attrs["energia"], mult_tiro)
	var gol := Duel.gana_atacante(res, rng)
	_lanzar_remate(estado, poseedor, {
		"tipo": "gol" if gol else "atajada",
		"es_local": es_local, "clave": poseedor["clave"], "rol": poseedor["rol"],
		"jugador": jugador, "agarre": float(arquero["atributos"]["agarre"]) / 100.0,
		"dist": poseedor["pos"].distance_to(arco_rival(es_local)),
	})


## El remate SALE y tarda en llegar. El resultado ya está decidido —lo
## decidió _resolver_tiro con sus duelos y sus tiradas— pero aplicarlo en
## el mismo tick hacía que el gol apareciera de la nada: no se veía la
## pelota yendo al arco, ni al arquero tirándose, ni el remate en sí.
## Todo el partido pasaba de "remata" a "sacan del medio" en 0,25 s.
##
## Ojo: esto ALARGA el partido en ticks muertos (unos 3 por remate, ~25
## remates), así que corre goles y pases hacia abajo. Es un costo
## aceptado a cambio de que la jugada más importante del juego se vea.
static func _lanzar_remate(estado: Dictionary, poseedor: Dictionary, datos: Dictionary) -> void:
	var rng: RandomNumberGenerator = estado["rng"]
	var es_local: bool = bool(datos["es_local"])
	var arco := arco_rival(es_local)
	var lado: float = 1.0 if arco.x > 0.0 else -1.0
	var tipo := str(datos["tipo"])

	# Hasta dónde llega el arquero mientras la pelota viaja. Es lo que
	# decide ADÓNDE va el remate: una atajada tiene que ir a un punto que
	# el arquero alcance, y un gol a uno que no. Antes el destino salía de
	# un randf() suelto y el arquero se quedaba clavado, así que la pelota
	# llegaba a la línea y después se teletransportaba a sus manos.
	var arq_clave := _clave_arquero(estado, not es_local)
	var arq_pos := Vector2(arco.x, 0.0)
	var alcance := 3.66
	if arq_clave != -1:
		var e_arq: Dictionary = estado["jugadores"][arq_clave]
		arq_pos = e_arq["pos"]
		var vel_remate: float = float(pesos()["fisica"]["vel_remate"])
		var ticks_vuelo: float = maxf(poseedor["pos"].distance_to(arco) / (vel_remate * TICK_SEG), 1.0)
		alcance = float(e_arq["vel_max"]) * TICK_SEG * ticks_vuelo + ALCANCE_ESTIRADA

	var y_destino := 0.0
	var altura := 0.9
	match tipo:
		"atajada":
			# Va a donde el arquero LLEGA: por eso la ataja.
			y_destino = clampf(rng.randf_range(-3.4, 3.4),
				arq_pos.y - alcance, arq_pos.y + alcance)
		"gol":
			# Va a donde NO llega. Si tiene el arco entero cubierto, se la
			# metieron igual y no hay adónde mandarla: se elige libre.
			y_destino = rng.randf_range(-3.0, 3.0)
			if alcance < 3.0:
				var izq: float = arq_pos.y - alcance
				var der: float = arq_pos.y + alcance
				if absf(-3.0 - izq) > absf(3.0 - der):
					y_destino = rng.randf_range(-3.0, minf(izq, -0.1))
				else:
					y_destino = rng.randf_range(maxf(der, 0.1), 3.0)
		"palo":
			y_destino = ARCO_MEDIO_ANCHO * (1.0 if rng.randf() < 0.5 else -1.0)
		_:
			# Afuera: o muy abierta o por arriba del travesaño.
			y_destino = rng.randf_range(4.5, 9.0) * (1.0 if rng.randf() < 0.5 else -1.0)
			altura = 3.4

	# La atajada termina DELANTE de la línea, que es donde están las manos
	# del arquero; todo lo demás termina adentro o pasando el arco.
	var x_destino: float = arco.x - lado * 0.8 if tipo == "atajada" else arco.x + lado * 1.2
	var destino := Vector2(x_destino,
		clampf(y_destino, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["es_pase"] = false
	pelota["es_centro"] = false
	pelota["es_remate"] = true
	pelota["remate"] = datos
	pelota["pos"] = poseedor["pos"]
	pelota["origen_pos"] = poseedor["pos"]
	pelota["destino_pos"] = destino
	pelota["destino_id"] = -1
	pelota["pasador_local"] = es_local
	pelota["altura_max"] = altura
	pelota["ticks_con_pelota"] = 0
	pelota.erase("pared_a")
	var dir: Vector2 = (destino - poseedor["pos"]).normalized()
	pelota["vel"] = dir * float(pesos()["fisica"]["vel_remate"])

	# El arquero se tira mientras la pelota viaja, no cuando ya entró, y
	# se MUEVE hacia la trayectoria (ver el paso 3 de _tick). En la
	# atajada llega justo; en el gol se estira y no alcanza.
	if tipo in ["gol", "atajada", "palo"] and arq_clave != -1:
		_accion(estado, arq_clave, ACCION_VUELA)
		datos["arquero"] = arq_clave
		datos["destino_arquero"] = destino


## Gol: la pelota se queda EN LA RED y los jugadores vuelven caminando al
## medio. Antes el gol y el saque del medio pasaban en el mismo tick, o
## sea que la pelota nunca llegaba a verse adentro del arco: se pasaba de
## "remata" a "los 22 en el círculo central" sin nada en el medio.
static func _festejar_gol(estado: Dictionary, saca_local: bool) -> void:
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = false
	pelota["vel"] = Vector2.ZERO
	pelota["es_remate"] = false
	pelota["altura_max"] = 0.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		var base: Vector2 = e["base"]
		# Mismas marcas que el saque del medio: todos en su propia mitad.
		e["marca"] = Vector2(minf(base.x, -1.0) if e["equipo_local"] else maxf(base.x, 1.0), base.y)
	estado["balon_parado"] = {"tipo": "saque_medio", "saca_local": saca_local}
	estado["detenido"] = int(TICKS_DETENIDO["gol"])


## Llegó: recién ahora se cuenta el gol, se reanuda o saca el arquero.
static func _aplicar_remate(estado: Dictionary, datos: Dictionary) -> void:
	if datos.is_empty():
		return
	var es_local: bool = bool(datos["es_local"])
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var minuto := _minuto_int(estado)
	var tipo := str(datos["tipo"])

	if tipo == "afuera" or tipo == "palo":
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": datos["rol"], "clave": datos["clave"], "resultado": tipo,
		})
		if tipo == "afuera":
			_dar_pelota_al_arquero(estado, not es_local, true)
		else:
			# Del palo suele salir rebote al córner.
			_desviar_afuera(estado, arco_rival(es_local), not es_local)
		return

	var gol: bool = tipo == "gol"
	estado["eventos"].append({
		"minuto": minuto, "tipo": "tiro_puerta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": datos["rol"], "clave": datos["clave"],
		"resultado": "gol" if gol else "atajada",
	})
	var jugador: Dictionary = datos.get("jugador", {})
	var dist: float = float(datos.get("dist", 0.0))
	if gol:
		eq_a.goles += 1
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre, "jugador_id": jugador.get("id", -1)})
		estado["log"].append("min %d - GOL de %s %s (%s) desde %.0f m" % [
			minuto, jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre, dist])
		_festejar_gol(estado, not es_local)
		return

	estado["log"].append("min %d - %s (%s) remata desde %.0f m, ataja el arquero" % [
		minuto, datos["rol"], eq_a.nombre, dist])
	# El arquero no siempre la retiene: si la manotea, sale al córner.
	# Cuanto mejor su agarre, más veces la queda.
	if rng.randf() > float(datos.get("agarre", 0.5)):
		_desviar_afuera(estado, arco_rival(es_local), not es_local)
	else:
		_dar_pelota_al_arquero(estado, not es_local)


## La pelota vuelve al arquero. Si es un SAQUE DE ARCO (la pelota salió
## por la línea de fondo) los rivales tienen que estar fuera del área,
## como manda la regla: sin eso quedaban parados adentro esperando el
## saque, y el 42% de las salidas del arquero terminaba en un rival.
## Cuando el arquero simplemente ataja, no se despeja el área.
static func _dar_pelota_al_arquero(estado: Dictionary, arquero_local: bool, saque_de_arco: bool = false) -> void:
	var arquero_clave := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == arquero_local and e["rol"] == "ARQ":
			arquero_clave = id
			break
	if arquero_clave == -1:
		return

	if saque_de_arco:
		_despejar_area(estado, arquero_local)
		estado["eventos"].append({
			"minuto": _minuto_int(estado), "tipo": "saque_arco",
			"equipo": _equipo_de(estado, arquero_local).nombre,
			"rival": _equipo_de(estado, not arquero_local).nombre,
			"jugador_posicion": "ARQ", "clave": arquero_clave, "resultado": "saque",
		})

	var arq: Dictionary = estado["jugadores"][arquero_clave]
	estado["pelota"]["poseedor_id"] = arquero_clave
	estado["pelota"]["pos"] = arq["pos"]
	estado["pelota"]["vel"] = Vector2.ZERO
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["ticks_con_pelota"] = 0


## La pelota se fue de la cancha. Decide qué se cobra según por dónde
## salió y quién la tocó último, igual que el reglamento:
##  - por el costado -> lateral para el que NO la tocó
##  - por el fondo, tocada por el que defiende ese arco -> córner
##  - por el fondo, tocada por el que ataca -> saque de arco
static func _pelota_fuera(estado: Dictionary, punto: Vector2, toco_local: bool) -> void:
	if absf(punto.y) >= MEDIO_ANCHO:
		_lateral(estado, punto, not toco_local)
		return
	# ¿De qué arco es esta línea de fondo? La de +x la defiende el visitante.
	var linea_del_local: bool = punto.x < 0.0
	if toco_local == linea_del_local:
		_saque_de_esquina(estado, not linea_del_local, punto.y >= 0.0)
	else:
		_dar_pelota_al_arquero(estado, linea_del_local, true)


## Lateral: la pone en juego el equipo al que se le concede, desde el
## punto por donde salió.
static func _lateral(estado: Dictionary, punto: Vector2, saca_local: bool) -> void:
	var pos := Vector2(clampf(punto.x, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
		clampf(punto.y, -MEDIO_ANCHO + 0.5, MEDIO_ANCHO - 0.5))
	var ejecutor := _mas_cercano_del_equipo(estado, pos, saca_local)
	if ejecutor == -1:
		_dar_pelota_al_arquero(estado, saca_local, true)
		return
	estado["jugadores"][ejecutor]["pos"] = pos
	_entregar_pelota(estado, ejecutor)
	estado["reinicios"]["lateral"] = int(estado["reinicios"].get("lateral", 0)) + 1
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "lateral",
		"equipo": _equipo_de(estado, saca_local).nombre,
		"rival": _equipo_de(estado, not saca_local).nombre,
		"jugador_posicion": estado["jugadores"][ejecutor]["rol"], "clave": ejecutor,
		"resultado": "saque",
	})


## Córner: pelota al banderín, la ejecuta el atacante más cercano, y los
## dos equipos se meten al área — que es lo que hace peligroso un córner.
static func _saque_de_esquina(estado: Dictionary, ataca_local: bool, lado_arriba: bool) -> void:
	var arco := arco_rival(ataca_local)
	var esquina := Vector2(arco.x - (1.0 if arco.x > 0.0 else -1.0),
		(MEDIO_ANCHO - 0.5) * (1.0 if lado_arriba else -1.0))
	var ejecutor := _elegir_ejecutor(estado, esquina, ataca_local, "corner")
	if ejecutor == -1:
		_dar_pelota_al_arquero(estado, not ataca_local, true)
		return
	estado["reinicios"]["corner"] = int(estado["reinicios"].get("corner", 0)) + 1
	# El córner también para el juego: antes los dos equipos aparecían de
	# golpe adentro del área y la pelota salía en el mismo tick. Ahora se
	# ve cómo suben.
	_detener_juego(estado, esquina, ataca_local, ejecutor, "corner", int(TICKS_DETENIDO["corner"]))
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "corner",
		"equipo": _equipo_de(estado, ataca_local).nombre,
		"rival": _equipo_de(estado, not ataca_local).nombre,
		"jugador_posicion": estado["jugadores"][ejecutor]["rol"], "clave": ejecutor,
		"resultado": "saque",
	})


## La pelota sale desviada desde `desde`, tocada por el equipo `toco_local`.
## Busca el borde más cercano (costado o fondo) para que el reinicio caiga
## donde tiene sentido según dónde ocurrió la jugada.
## ¿El defensor que se metió en la línea llega a tapar el remate? Duelo
## `tiro` del que patea contra el bloqueo del defensor, que sale de
## `barrida` (tirarse a taparla) y `agilidad` (la reacción) — no hay un
## atributo "bloqueo" en el GDD, y esos dos son los que describen el gesto.
## Con los bloques A/B/C/D de siempre, así que personalidad y habilidades
## entran igual que en cualquier duelo.
##
## La distancia pesa: de lejos el defensor tiene tiempo de leer el remate y
## meter el cuerpo; a quemarropa le pasa por al lado antes de reaccionar.
static func _gana_bloqueo(estado: Dictionary, clave_def: int, rematador: Dictionary,
		eq_a: Team, eq_d: Team, pos_remate: Vector2, es_local: bool, minuto: int) -> bool:
	var f: Dictionary = pesos()["fisica"]
	var defensor := _dict_jugador(estado, eq_d, estado["jugadores"][clave_def]["jugador_id"])
	if defensor.is_empty():
		return false

	var attrs: Dictionary = defensor["atributos"]
	var bloqueo: float = float(attrs["barrida"]) * 0.6 + float(attrs["agilidad"]) * 0.4
	var dist: float = pos_remate.distance_to(arco_rival(es_local))
	var tiempo_para_reaccionar: float = clampf(dist / float(f["dist_bloqueo_comodo"]), 0.0, 1.0)
	bloqueo *= float(f["bloqueo_a_quemarropa"]) + (1.0 - float(f["bloqueo_a_quemarropa"])) * tiempo_para_reaccionar

	var ata := Duel.atributo_efectivo(
		float(rematador["atributos"]["tiro"]), "tecnico", eq_a.resistencia_pct(rematador["id"]))
	var def := Duel.atributo_efectivo(bloqueo, "defensivo", eq_d.resistencia_pct(defensor["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, rematador, "tiro", minuto, estado["rng"]),
		MatchEngine._bloques_equipo(eq_d, eq_a, defensor, "barrida", minuto, estado["rng"]))
	# gana_atacante = el remate pasa. Si el atacante pierde, lo bloquearon.
	return not Duel.gana_atacante(res, estado["rng"])


## Adónde va la pelota después de un bloqueo: afuera (córner o lateral),
## controlada por el que bloqueó, o rebotada a cualquier lado de la cancha
## para que la pelee el que llegue.
static func _resolver_rebote(estado: Dictionary, desde: Vector2, toco_local: bool) -> void:
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var roll := rng.randf()
	if roll < float(f["rebote_afuera"]):
		_desviar_afuera(estado, desde, toco_local)
		return
	if roll < float(f["rebote_afuera"]) + float(f["rebote_controlado"]):
		var suyo := _mas_cercano_del_equipo(estado, desde, toco_local)
		if suyo != -1:
			_entregar_pelota(estado, suyo)
			return
	# Rebote suelto: sale despedida y la agarra el que llegue.
	var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	var largo: float = rng.randf_range(float(f["rebote_largo_min"]), float(f["rebote_largo_max"]))
	var destino := Vector2(
		clampf(desde.x + dir.x * largo, -LIMITE_X, LIMITE_X),
		clampf(desde.y + dir.y * largo, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["pos"] = desde
	pelota["vel"] = (destino - desde).normalized() * float(f["vel_pase_min"])
	pelota["destino_pos"] = destino
	pelota["destino_id"] = -1
	pelota["pasador_local"] = toco_local
	pelota["es_pase"] = false
	pelota["origen_pos"] = desde
	pelota["ticks_con_pelota"] = 0


## ¿Hay un defensor metido en la línea del remate? Devuelve su clave, o -1.
## Es la misma idea que la intercepción de un pase, pero contra el camino
## al arco.
static func _bloqueador_de_tiro(estado: Dictionary, desde: Vector2, es_local: bool) -> int:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(es_local)
	var radio: float = f["radio_bloqueo_tiro"]
	var mejor := -1
	var mejor_d: float = radio
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == es_local or e["rol"] == "ARQ":
			continue
		# Un bloqueo se produce ENCIMA del que remata, no a veinte metros:
		# el defensor tiene que estar cerca y delante. Sin ese límite,
		# cualquiera parado en la línea al arco bloqueaba y los goles se
		# caían a 0.9 por partido.
		var dist_al_rematador: float = desde.distance_to(e["pos"])
		if dist_al_rematador > float(f["dist_max_bloqueo"]) or dist_al_rematador > desde.distance_to(arco):
			continue
		var d := _dist_a_segmento(e["pos"], desde, arco)
		if d < mejor_d:
			mejor_d = d
			mejor = id
	return mejor


static func _desviar_afuera(estado: Dictionary, desde: Vector2, toco_local: bool) -> void:
	var dist_costado: float = MEDIO_ANCHO - absf(desde.y)
	var dist_fondo: float = MEDIO_LARGO - absf(desde.x)
	var punto: Vector2
	if dist_costado <= dist_fondo:
		punto = Vector2(desde.x, MEDIO_ANCHO * signf(desde.y if desde.y != 0.0 else 1.0))
	else:
		punto = Vector2(MEDIO_LARGO * signf(desde.x if desde.x != 0.0 else 1.0), desde.y)
	_pelota_fuera(estado, punto, toco_local)


## El compañero mejor plantado dentro del área para cabecear un centro:
## el de mejor `cabezazo` de los que están ahí.
static func _mejor_en_el_area(estado: Dictionary, es_local: bool, excluir: int) -> int:
	var equipo := _equipo_de(estado, es_local)
	var mejor := -1
	var mejor_val: float = -1.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != es_local or id == excluir or e["rol"] == "ARQ":
			continue
		if not _en_el_area(e["pos"], es_local):
			continue
		var j := _dict_jugador(estado, equipo, e["jugador_id"])
		if j.is_empty():
			continue
		var val: float = float(j["atributos"]["cabezazo"]) * 0.6 + float(j["atributos"]["salto"]) * 0.4
		if val > mejor_val:
			mejor_val = val
			mejor = id
	return mejor


static func _mas_cercano_del_equipo(estado: Dictionary, punto: Vector2, es_local: bool) -> int:
	var mejor := -1
	var mejor_d: float = INF
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != es_local or e["rol"] == "ARQ":
			continue
		var d: float = punto.distance_to(e["pos"])
		if d < mejor_d:
			mejor_d = d
			mejor = id
	return mejor


## Saca a los rivales del área grande del que va a sacar (16,5m de fondo,
## 40,32m de ancho — medidas reglamentarias).
static func _despejar_area(estado: Dictionary, arquero_local: bool) -> void:
	var borde_x: float = -MEDIO_LARGO + 16.5 if arquero_local else MEDIO_LARGO - 16.5
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == arquero_local:
			continue
		var dentro: bool = (e["pos"].x < borde_x) if arquero_local else (e["pos"].x > borde_x)
		if dentro and absf(e["pos"].y) < 20.16:
			e["pos"] = Vector2(borde_x + (1.0 if arquero_local else -1.0), e["pos"].y)


## Un pase va A UN PUNTO (donde está el compañero al momento de pegarle),
## no en una dirección infinita: si no, con 18 m/s y ticks de 0.25s la
## pelota avanza 4.5m por tick, pasa de largo por encima del receptor
## (radio de control 1.6m) y se va del campo sin que nadie la toque.
## `punto` distinto de null = pase al hueco: la pelota no va a los pies del
## compañero sino al espacio por delante, y él sale a buscarla.
## `es_pelotazo` = la pega con la pierna, no con la técnica: el atributo
## que manda pasa a ser `fuerza`. Es lo que le permite a un jugador
## limitado mandarla lejos igual, a costa de que llegue mucho más
## interceptable.
static func _lanzar_pase(estado: Dictionary, poseedor: Dictionary, destino_id: int, jugador: Dictionary, punto = null, es_pelotazo: bool = false) -> void:
	var f: Dictionary = pesos()["fisica"]
	var destino: Dictionary = estado["jugadores"][destino_id]
	var objetivo: Vector2 = punto if punto != null else destino["pos"]
	var dir: Vector2 = (objetivo - poseedor["pos"]).normalized()
	var pelota: Dictionary = estado["pelota"]
	estado["pase_detalle"]["intentos"] += 1
	_accion(estado, int(poseedor["clave"]), ACCION_PATEA)
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	# La pelota sale más fuerte cuanto mejor pega el que la toca: un pase
	# flojo tarda más en llegar y le da tiempo al rival a meterse. En el
	# arquero el atributo que manda es el suyo (pies/golpe), no `pases`.
	var attr := "fuerza" if es_pelotazo else atributo_pase(jugador, poseedor["pos"].distance_to(objetivo))
	# Pie preferido: si la juega hacia su lado malo, le sale peor — pelota
	# más lenta y más fácil de leer para el que va a cortarla.
	var f_pie := factor_pie(jugador, poseedor["pos"], objetivo, poseedor["equipo_local"])
	pelota["vel"] = dir * _por_atributo(jugador, attr, f["vel_pase_min"], f["vel_pase_max"]) * f_pie
	pelota["pases_pasador"] = float(jugador["atributos"][attr]) * f_pie
	pelota["attr_pasador"] = attr
	pelota["pasador_id"] = int(jugador["id"])
	pelota["destino_pos"] = objetivo
	pelota["destino_id"] = destino_id
	pelota["pasador_local"] = poseedor["equipo_local"]
	pelota["es_pase"] = true
	pelota["origen_pos"] = poseedor["pos"]

	# Offside: se juzga la posición del receptor EN EL MOMENTO DEL PASE, no
	# cuando la recibe — por eso se marca acá y se cobra al llegar. La
	# línea ya incluye la posición de la pelota, así que estar más allá
	# significa estar por delante del último defensor Y de la pelota.
	var e_dest: Dictionary = estado["jugadores"][destino_id]
	var adelantado := false
	if e_dest["rol"] != "ARQ":
		var linea: Dictionary = estado["linea_offside"]
		# La tolerancia no es hacer trampa con el reglamento: el motor
		# juzga la posición en el tick del pase, o sea con 0,25 s de
		# grano, y un desmarque bien cronometrado es exactamente lo que
		# pasa DENTRO de ese cuarto de segundo — arranca habilitado y para
		# cuando la pelota sale ya está pasando. Esa sincronización es lo
		# que el rasgo Enfocado describe y es lo único que la resolución
		# del tick no puede representar sola.
		var tol: float = 0.2 + float(e_dest.get("tolerancia_offside", 0.0))
		if poseedor["equipo_local"]:
			adelantado = e_dest["pos"].x > float(linea["local"]) + tol
		else:
			adelantado = e_dest["pos"].x < float(linea["away"]) - tol
	pelota["offside"] = adelantado


# ---------------------------------------------------------------------------
# Loop de tick (§3)
# ---------------------------------------------------------------------------

static func _tick(estado: Dictionary, con_fotogramas: bool) -> void:
	var pelota: Dictionary = estado["pelota"]
	var eventos_antes: int = estado["eventos"].size()
	if con_fotogramas:
		estado["acciones_tick"] = []

	# 0. Juego detenido: falta cobrada, córner concedido. La pelota está
	# quieta en el punto y los jugadores CAMINAN a sus marcas. Antes esto
	# no existía y el balón parado se resolvía en el mismo tick en que se
	# cobraba: la falta no se veía nunca, la jugada seguía como si nada y
	# los jugadores aparecían teletransportados en sus posiciones.
	if int(estado.get("detenido", 0)) > 0:
		estado["detenido"] = int(estado["detenido"]) - 1
		for id in estado["jugadores"]:
			var e_p: Dictionary = estado["jugadores"][id]
			_mover_hacia(e_p, e_p.get("marca", e_p["pos"]), FACTOR_TROTE_PARADO)
		if int(estado["detenido"]) == 0:
			_ejecutar_balon_parado(estado)
		_cerrar_tick(estado, con_fotogramas, eventos_antes)
		return

	# 1. Pelota en vuelo: avanza, y alguien puede controlarla o interceptarla.
	if pelota["en_vuelo"]:
		_avanzar_pelota(estado)
	# 2. Con poseedor: decide y ejecuta.
	elif pelota["poseedor_id"] != -1:
		_decidir_y_ejecutar(estado)

	# El tick que PARÓ el juego (gol, falta, córner) no mueve a nadie más:
	# si no, el arquero que se acaba de tirar se levanta y trota a su
	# posición en el mismo fotograma en que entró la pelota.
	if int(estado.get("detenido", 0)) > 0:
		_cerrar_tick(estado, con_fotogramas, eventos_antes)
		return

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
	# El que jugó la pared sale corriendo a recibirla del otro lado, sin
	# esperar a que el muro se la devuelva.
	var corredor_pared: int = int(pelota.get("pared_a", -1))
	var arquero_al_remate := -1
	if bool(pelota.get("es_remate", false)):
		arquero_al_remate = int(pelota.get("remate", {}).get("arquero", -1))

	for id in estado["jugadores"]:
		if id == poseedor_id:
			continue
		var e: Dictionary = estado["jugadores"][id]
		if id == corredor_pared:
			_mover_hacia(e, pelota.get("pared_destino", pelota["pos"]))
			continue
		if id == esperando:
			_mover_hacia(e, pelota.get("destino_pos", pelota["pos"]))
			continue
		# El arquero sale a cruzarse en la trayectoria del remate. Sin
		# esto se quedaba parado y la pelota le aparecía en las manos.
		if id == arquero_al_remate:
			_mover_hacia(e, pelota["remate"]["destino_arquero"])
			continue
		if perseguidores.has(id):
			_mover_hacia(e, pelota["pos"])
			continue
		var equipo := _equipo_de(estado, e["equipo_local"])
		# Con la pelota EN EL AIRE no hay poseedor, pero el equipo que la
		# jugó sigue atacando: usar `poseedor_id != -1` hacía que durante
		# cada vuelo los dos equipos se replegaran como si hubieran
		# perdido la pelota. En un remate se veía clarísimo — pateaban al
		# arco y arrancaban a retroceder antes de saber si era gol.
		var mi_equipo_tiene: bool = e["equipo_local"] == equipo_con_pelota
		_mover_hacia(e, _objetivo_sin_pelota(estado, e, equipo, mi_equipo_tiene))

	# 4. Intento de robo: el rival más cercano al poseedor puede quitársela.
	# Salvo que este tick ya se haya resuelto una gambeta, que es el mismo
	# duelo visto desde el otro lado.
	if pelota["poseedor_id"] != -1 and int(estado.get("gambeta_este_tick", -1)) != estado["tick"]:
		_intentar_robo(estado)

	# 5. La pelota sigue al poseedor.
	if pelota["poseedor_id"] != -1:
		pelota["pos"] = estado["jugadores"][pelota["poseedor_id"]]["pos"]
		pelota["ticks_con_pelota"] = int(pelota.get("ticks_con_pelota", 0)) + 1

	_cerrar_tick(estado, con_fotogramas, eventos_antes)


## Cierre común de un tick: reloj, cambios y fotograma. Está factorizado
## porque el juego detenido hace un tick reducido pero tiene que avanzar
## el reloj y emitir su fotograma igual que cualquier otro.
static func _cerrar_tick(estado: Dictionary, con_fotogramas: bool, eventos_antes: int) -> void:
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
		# TODOS los eventos del tick, no solo el último: una entrada fuerte
		# emite la tarjeta y después la falta, y quedarse con el último
		# hacía desaparecer las tarjetas del relato.
		_push_fotograma(estado, estado["eventos"].slice(eventos_antes))


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
	# Altura: parábola simple según cuánto lleva recorrido. Los pases rasos
	# llevan altura_max 0, así que para ellos esto no cambia nada.
	var altura_max: float = float(pelota.get("altura_max", 0.0))
	var origen_z: Vector2 = pelota.get("origen_pos", desde)
	var total: float = origen_z.distance_to(destino)
	var avanzado: float = clampf(origen_z.distance_to(hasta) / maxf(total, 0.01), 0.0, 1.0)
	pelota["z"] = altura_max * 4.0 * avanzado * (1.0 - avanzado)

	# Un remate en vuelo no se intercepta ni se va afuera por el camino:
	# ya está resuelto (ver _lanzar_remate), lo único que falta es que
	# llegue. Es lo que hace que se VEA la pelota yendo al arco en vez de
	# que el gol aparezca de la nada.
	if bool(pelota.get("es_remate", false)):
		if llego:
			pelota["es_remate"] = false
			pelota["altura_max"] = 0.0
			pelota["z"] = 0.0
			_aplicar_remate(estado, pelota.get("remate", {}))
		return

	var origen: Vector2 = pelota.get("origen_pos", desde)
	# Un pase preciso pasa entre líneas; uno flojo se lo comen. Sin esto la
	# intercepción era pura geometría y un gran pasador completaba
	# exactamente los mismos pases que uno malo.
	var calidad_pase: float = clampf(float(pelota.get("pases_pasador", 50.0)) / 100.0, 0.0, 1.0)
	var radio_inter: float = float(f["radio_intercepcion"]) * (float(f["intercepcion_pase_malo"]) - (float(f["intercepcion_pase_malo"]) - float(f["intercepcion_pase_bueno"])) * calidad_pase)
	var minimo_desde_origen: float = f["min_dist_intercepcion_origen"]
	# Volando por encima de la cabeza no la agarra nadie: es lo que hace
	# que un centro sea un centro y no un pase raso con más recorrido.
	var mejor_id := -1
	var mejor_d: float = radio_inter
	if float(pelota.get("z", 0.0)) <= float(f["z_inalcanzable"]):
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
	# La geometría decide QUIÉN tiene la chance y qué tan buena es; el
	# DUELO decide si la corta. Antes esto era determinista: si entrabas en
	# el radio, la pelota era tuya, con lo cual un marcador con quite 95
	# interceptaba exactamente igual que uno con quite 20 — el único
	# atributo que contaba era el `pases` del que la pegó. No existe un
	# atributo "intercepción" en el GDD (los defensivos son quite y
	# barrida), así que se usa el mismo compuesto con que el GDD pondera a
	# un DFC: quite + inteligencia, o sea marca y lectura de juego.
	if mejor_id != -1 and bool(pelota.get("es_pase", false)):
		if not _gana_intercepcion(estado, mejor_id, mejor_d, radio_inter, pasador_local, minuto):
			mejor_id = -1

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
	# Un centro no lo "recibe" nadie de una: se disputa por arriba.
	if bool(pelota.get("es_centro", false)):
		pelota["es_centro"] = false
		pelota["altura_max"] = 0.0
		pelota["z"] = 0.0
		_resolver_centro(estado, hasta, bool(pelota.get("centro_de", pasador_local)), minuto)
		return

	var receptor := _mas_cercano_a(estado, hasta)
	if receptor == -1:
		_dar_pelota_al_arquero(estado, not pasador_local, true)
		return
	var e_receptor: Dictionary = estado["jugadores"][receptor]

	# Si esto era el primer pase de una pared y llegó a un compañero, el
	# muro NO se queda con la pelota: la devuelve de primera al que salió
	# corriendo. Esa devolución es un segundo pase, con su propio riesgo de
	# que la corten.
	var pared_a: int = int(pelota.get("pared_a", -1))
	if pared_a != -1 and e_receptor["equipo_local"] == pasador_local and estado["jugadores"].has(pared_a):
		var muro := _dict_jugador(estado, _equipo_de(estado, pasador_local), e_receptor["jugador_id"])
		pelota.erase("pared_a")
		if not muro.is_empty():
			estado["paredes"]["muro_ok"] = int(estado["paredes"].get("muro_ok", 0)) + 1
			_entregar_pelota(estado, receptor)
			_lanzar_pase(estado, e_receptor, pared_a, muro, pelota.get("pared_destino", null))
			return

	_entregar_pelota(estado, receptor)
	# Estaba adelantado cuando le pegaron y la recibió: offside. Tiro libre
	# para el que defiende, desde donde estaba.
	if bool(pelota.get("offside", false)) and receptor == int(pelota.get("destino_id", -1)) \
			and e_receptor["equipo_local"] == pasador_local:
		pelota["offside"] = false
		estado["offsides"] = int(estado.get("offsides", 0)) + 1
		estado["eventos"].append({
			"minuto": minuto, "tipo": "offside", "equipo": _equipo_de(estado, pasador_local).nombre,
			"rival": _equipo_de(estado, not pasador_local).nombre,
			"jugador_posicion": e_receptor["rol"], "clave": e_receptor["clave"], "resultado": "offside",
		})
		_tiro_libre(estado, hasta, not pasador_local, minuto)
		return

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


## NOTA: acá vivía _soltar_pelota, que tras un quite ganado mandaba la
## pelota a rebotar unos metros en vez de dársela al que la quitó. Era un
## parche para el loop de duelos, no fútbol: si le sacás la pelota a
## alguien, te la quedás en los pies. El loop se resuelve con la
## penalización por perder el duelo (ver _penalizar). Los rebotes en un
## quite ganado son una mecánica aparte, pendiente.


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


## ¿El defensor que se metió en la línea de pase llega a cortarla? Duelo
## `pases` del pasador contra `quite`+`inteligencia` del que intercepta,
## con los bloques A/B/C/D del GDD igual que cualquier otro duelo del
## motor. La cercanía a la trayectoria pesa: el que la roza tiene mucha
## menos chance que el que se le para justo en el camino.
static func _gana_intercepcion(estado: Dictionary, clave_def: int, dist: float, radio: float,
		pasador_local: bool, minuto: int) -> bool:
	var eq_pas := _equipo_de(estado, pasador_local)
	var eq_def := _equipo_de(estado, not pasador_local)
	var pasador := _dict_jugador(estado, eq_pas, int(estado["pelota"].get("pasador_id", -1)))
	var defensor := _dict_jugador(estado, eq_def, estado["jugadores"][clave_def]["jugador_id"])
	if pasador.is_empty() or defensor.is_empty():
		return true

	var f: Dictionary = pesos()["fisica"]
	var attrs: Dictionary = defensor["atributos"]
	var lectura: float = float(attrs["quite"]) * 0.6 + float(attrs["inteligencia"]) * 0.4
	# Centrado en la trayectoria = corte limpio; al borde del radio, apenas
	# la roza.
	var centralidad: float = 1.0 - clampf(dist / maxf(radio, 0.01), 0.0, 1.0)
	lectura *= 0.45 + 0.55 * centralidad
	# Cuanto más lejos viajó ya la pelota, más fácil de leer: un toque
	# corto y seco no se corta, un pase largo cruzando la cancha le da al
	# rival tiempo de sobra para medirlo y meter la pierna.
	var recorrido: float = float(estado["pelota"].get("origen_pos", Vector2.ZERO).distance_to(estado["pelota"]["pos"]))
	var largo: float = clampf(recorrido / float(f["recorrido_pase_largo"]), 0.0, 1.0)
	lectura *= float(f["lectura_pase_corto"]) + (float(f["lectura_pase_largo"]) - float(f["lectura_pase_corto"])) * largo

	# El atributo con el que se ejecutó el pase, que en el arquero es
	# `pies` o `golpe` y no `pases` (ver atributo_pase). Sin esto el duelo
	# de intercepción de un saque de arco se resolvía con el `pases` del
	# arquero, un número que en un arquero no significa nada, y la tasa de
	# saques completados no dependía de él.
	var attr_pas: String = str(estado["pelota"].get("attr_pasador", "pases"))
	var ata := Duel.atributo_efectivo(
		float(pasador["atributos"][attr_pas]), "tecnico", eq_pas.resistencia_pct(pasador["id"]))
	var def := Duel.atributo_efectivo(lectura, "defensivo", eq_def.resistencia_pct(defensor["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_pas, eq_def, pasador, "pases", minuto, estado["rng"]),
		MatchEngine._bloques_equipo(eq_def, eq_pas, defensor, "quite", minuto, estado["rng"]))
	# gana_atacante = el pase pasa. Si el atacante pierde, hay intercepción.
	return not Duel.gana_atacante(res, estado["rng"])


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
		if _en_cooldown(estado, id):
			continue  # quedó mal parado, no sale a perseguir todavía
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
		"pase_hueco":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, elegida["punto"])
		"pase_largo":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, null, true)
		"centro":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador)
			# Va por arriba: no se corta en el camino, se define al caer.
			estado["pelota"]["altura_max"] = float(f["altura_centro"])
			estado["pelota"]["es_centro"] = true
			estado["pelota"]["centro_de"] = es_local
			estado["centros"]["intentos"] = int(estado["centros"].get("intentos", 0)) + 1
		"pared":
			# Primer pase al muro. La devolución se dispara sola cuando el
			# muro la recibe (ver _avanzar_pelota), y mientras tanto el que
			# la jugó sale corriendo al punto de retorno.
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador)
			estado["pelota"]["pared_a"] = poseedor["clave"]
			estado["pelota"]["pared_destino"] = elegida["punto"]
			estado["paredes"]["intentos"] = int(estado["paredes"].get("intentos", 0)) + 1
		"despeje":
			_despejar(estado, poseedor, jugador)
		"gambeta":
			_resolver_gambeta(estado, poseedor, jugador, elegida["objetivo_id"])
			# La gambeta YA es el duelo por la pelota de este tick: si
			# además corriera el quite automático, la misma jugada se
			# resolvería dos veces.
			estado["gambeta_este_tick"] = estado["tick"]
		"tiro":
			_resolver_tiro(estado, poseedor, jugador)


## CHANCE_AMARILLA está calibrado sobre los ~180 duelos por partido del
## motor abstracto; este resuelve muchos menos, así que se tira varias
## veces por disputa para igualar la tasa por PARTIDO.
##
## Pero hay que CORTAR en la primera tarjeta: si no, el mismo jugador
## puede sacar dos amarillas en la misma entrada y quedar expulsado en el
## acto, que no existe en el fútbol. Con las tiradas encadenadas sin corte
## salían 1,10 rojas por partido contra las ~0,4 del motor abstracto.
static func _chequear_tarjeta_repetido(estado: Dictionary, defensor: Dictionary,
		eq_d: Team, eq_a: Team, minuto: int) -> void:
	var veces := int(pesos()["fisica"]["chequeos_tarjeta_por_quite"])
	for i in range(veces):
		var antes: int = estado["eventos"].size()
		MatchEngine._chequear_tarjeta(defensor, eq_d, eq_a, estado["rng"], estado["eventos"], minuto, true, estado["log"])
		if estado["eventos"].size() > antes:
			return  # ya cobró: una entrada, una tarjeta


## Deja a un jugador fuera de la disputa un rato: es la penalización por
## perder la pelota o por ir al quite y fallar. Sin esto, los mismos dos
## se enfrentan tick tras tick en el mismo metro cuadrado y el partido se
## vuelve un loop de duelos (la primera versión, que además entregaba
## posesión instantánea, terminó un partido 340-0).
##
## La habilidad Recuperación acorta esta espera: el jugador se rehace
## antes y vuelve a la jugada mientras el resto todavía está mal parado.
static func _penalizar(estado: Dictionary, clave: int, jugador: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var ticks: float = float(f["ticks_penalizacion_duelo"]) * Habilidades.factor_cooldown_recuperacion(jugador)
	estado["cooldown"][clave] = estado["tick"] + int(round(maxf(ticks, 1.0)))


static func _en_cooldown(estado: Dictionary, clave: int) -> bool:
	return estado["tick"] < int(estado["cooldown"].get(clave, -1))


## Se cobra la infracción: para el juego, se amonesta al infractor y se
## reanuda con tiro libre — o penal si fue adentro del área.
static func _cobrar_falta(estado: Dictionary, punto: Vector2, victima_local: bool,
		infractor: Dictionary, eq_infractor: Team, eq_victima: Team, minuto: int) -> void:
	estado["faltas"] = int(estado.get("faltas", 0)) + 1
	_chequear_tarjeta_repetido(estado, infractor, eq_infractor, eq_victima, minuto)
	estado["eventos"].append({
		"minuto": minuto, "tipo": "falta", "equipo": eq_infractor.nombre,
		"rival": eq_victima.nombre, "jugador_posicion": infractor["posicion"],
		"clave": clave_de(int(infractor["id"]), not victima_local), "resultado": "falta",
	})

	# ¿Adentro del área que defiende el infractor? Penal.
	var arco_infractor := arco_propio(not victima_local)
	if absf(arco_infractor.x - punto.x) <= 16.5 and absf(punto.y) <= 20.16:
		_cobrar_penal(estado, victima_local, minuto)
		return
	_tiro_libre(estado, punto, victima_local, minuto)


## Penal: lo patea el de mejor `tiro` del equipo, contra el arquero. Se
## resuelve con el mismo duelo de siempre pero con una ventaja grande para
## el pateador, que es lo que es un penal.
static func _cobrar_penal(estado: Dictionary, ataca_local: bool, minuto: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	estado["penales"] = int(estado.get("penales", 0)) + 1

	var pateador := {}
	for j in eq_a.jugadores_en_cancha():
		if pateador.is_empty() or j["atributos"]["tiro"] > pateador["atributos"]["tiro"]:
			pateador = j
	var arquero := eq_d.arquero()
	if pateador.is_empty() or arquero.is_empty():
		_dar_pelota_al_arquero(estado, not ataca_local, true)
		return

	var arq_attrs: Dictionary = arquero["atributos"]
	var valor_arq: float = arq_attrs["reflejos"] * 0.5 + arq_attrs["estirada"] * 0.3 + arq_attrs["agarre"] * 0.2
	# La ventaja del pateador incluye el bonus de personalidad de penales
	# que ya existía en Penales.gd (Pícaro, Clutch, Frágil mental).
	var ventaja: float = float(f["ventaja_penal"]) * (1.0 + Personalidad.bonus_penal(pateador))
	var res := Duel.resolver(
		Duel.atributo_efectivo(float(pateador["atributos"]["tiro"]) + ventaja, "tecnico", eq_a.resistencia_pct(pateador["id"])),
		Duel.atributo_efectivo(valor_arq, "tecnico", eq_d.resistencia_pct(arquero["id"])),
		MatchEngine._bloques_equipo(eq_a, eq_d, pateador, "tiro", minuto, estado["rng"]),
		MatchEngine._bloques_equipo(eq_d, eq_a, arquero, "reflejos", minuto, estado["rng"]))
	var gol := Duel.gana_atacante(res, estado["rng"])

	_accion(estado, clave_de(int(pateador["id"]), ataca_local), ACCION_PATEA)
	_accion(estado, clave_de(int(arquero["id"]), not ataca_local), ACCION_VUELA)
	estado["eventos"].append({
		"minuto": minuto, "tipo": "penal", "equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": pateador["posicion"],
		"clave": clave_de(int(pateador["id"]), ataca_local),
		"resultado": "gol" if gol else "atajado",
	})
	if gol:
		eq_a.goles += 1
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre, "jugador_id": pateador["id"]})
		estado["log"].append("min %d - PENAL: gol de %s %s (%s)" % [
			minuto, pateador["nombre"], pateador["apellido"], eq_a.nombre])
		_reiniciar_desde_medio(estado, not ataca_local)
	else:
		estado["log"].append("min %d - PENAL: lo ataja el arquero de %s" % [minuto, eq_d.nombre])
		_dar_pelota_al_arquero(estado, not ataca_local)


## Tiro libre: la pone el mejor ejecutante disponible, los rivales se
## alejan la distancia reglamentaria, y si está a tiro de arco se remata
## con `tiros_libres` — otro atributo del GDD que no leía nadie. Si está
## lejos o muy escorado, se cuelga al área.
static func _tiro_libre(estado: Dictionary, punto: Vector2, ataca_local: bool, _minuto: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var pos := Vector2(
		clampf(punto.x, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0),
		clampf(punto.y, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0))

	# Qué clase de tiro libre es lo decide DÓNDE fue la falta, y eso es lo
	# que después decide quién sube al área y quién se queda.
	var tipo := "corto"
	if factor_geometria(pos, ataca_local) >= float(f["geometria_minima_tiro_libre"]):
		tipo = "directo"
	elif pos.distance_to(arco_rival(ataca_local)) <= float(f["dist_libre_al_area"]):
		tipo = "centro"

	var ejecutor := _elegir_ejecutor(estado, pos, ataca_local, tipo)
	if ejecutor == -1:
		_dar_pelota_al_arquero(estado, ataca_local, true)
		return
	_detener_juego(estado, pos, ataca_local, ejecutor, tipo, int(TICKS_DETENIDO["falta"]))


## Quién la ejecuta. En el tiro libre directo manda `tiros_libres`; en el
## que se cuelga al área, `centros`; en el corto, el que está más cerca,
## que es lo que hace que el juego se reanude rápido.
static func _elegir_ejecutor(estado: Dictionary, pos: Vector2, ataca_local: bool, tipo: String) -> int:
	if tipo == "corto":
		return _mas_cercano_del_equipo(estado, pos, ataca_local)
	var atributo := "tiros_libres" if tipo == "directo" else "centros"
	var equipo := _equipo_de(estado, ataca_local)
	var mejor := -1.0
	var elegido := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != ataca_local or e["rol"] == "ARQ":
			continue
		var j := _dict_jugador(estado, equipo, e["jugador_id"])
		if j.is_empty():
			continue
		if float(j["atributos"][atributo]) > mejor:
			mejor = float(j["atributos"][atributo])
			elegido = id
	return elegido if elegido != -1 else _mas_cercano_del_equipo(estado, pos, ataca_local)


## Para el juego, deja la pelota en el punto y le da a cada uno su marca.
## Los jugadores NO se teletransportan: durante los ticks de pausa trotan
## hasta ahí (ver el paso 0 de _tick), así se ve cómo el área se llena.
static func _detener_juego(estado: Dictionary, pos: Vector2, ataca_local: bool,
		ejecutor: int, tipo: String, ticks: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	pelota["pos"] = pos
	pelota["vel"] = Vector2.ZERO
	pelota["en_vuelo"] = false
	pelota["poseedor_id"] = -1
	pelota["es_centro"] = false
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota.erase("pared_a")
	_marcar_posiciones(estado, pos, ataca_local, ejecutor, tipo)
	estado["balon_parado"] = {"tipo": tipo, "pos": pos, "ataca_local": ataca_local, "ejecutor": ejecutor}
	estado["detenido"] = ticks


## Adónde va cada uno mientras el juego está parado. Es la parte que hace
## que un tiro libre en zona rival se VEA distinto a uno en campo propio:
## en el que se cuelga al área suben los de arriba y baja toda la defensa
## rival, y en uno lejano cada uno vuelve a su casillero de formación.
static func _marcar_posiciones(estado: Dictionary, pos: Vector2, ataca_local: bool,
		ejecutor: int, tipo: String) -> void:
	var rng: RandomNumberGenerator = estado["rng"]
	var arco := arco_rival(ataca_local)
	var dentro_x: float = arco.x - (11.0 if arco.x > 0.0 else -11.0)
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if id == ejecutor:
			e["marca"] = pos
			continue
		if e["rol"] == "ARQ":
			e["marca"] = e["base"]
			continue

		if tipo == "centro" or tipo == "corner":
			# Sube el que ataca de arriba y baja TODA la defensa rival: es
			# el mismo reparto del córner, porque es la misma jugada.
			var sube: bool = ROLES_QUE_ATACAN.has(e["rol"]) if e["equipo_local"] == ataca_local else true
			if sube:
				e["marca"] = Vector2(dentro_x + rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0))
				continue
			e["marca"] = e["base"]
			continue

		if tipo == "directo" and e["equipo_local"] != ataca_local:
			# Barrera: los rivales que están encima se corren a la
			# distancia reglamentaria en vez de aparecer ya corridos.
			var d: float = pos.distance_to(e["pos"])
			e["marca"] = pos + (e["pos"] - pos).normalized() * 9.15 if d < 9.15 else e["pos"]
			continue
		e["marca"] = e["base"]


## Se reanuda: el ejecutor toca la pelota y la jugada arranca.
static func _ejecutar_balon_parado(estado: Dictionary) -> void:
	var bp: Dictionary = estado.get("balon_parado", {})
	estado.erase("balon_parado")
	if bp.is_empty():
		return
	if str(bp["tipo"]) == "saque_medio":
		_reiniciar_desde_medio(estado, bool(bp["saca_local"]))
		return
	if str(bp["tipo"]) == "saque_inicial":
		# La pelota ya está en el círculo con su ejecutor desde que se
		# armó la mitad: acá solo se anuncia que arrancó.
		estado["eventos"].append({
			"minuto": _minuto_int(estado), "tipo": "saque_inicial",
			"equipo": _equipo_de(estado, bool(bp["saca_local"])).nombre,
			"rival": _equipo_de(estado, not bool(bp["saca_local"])).nombre,
			"jugador_posicion": "", "resultado": str(bp["mitad"]),
		})
		return
	var ejecutor := int(bp["ejecutor"])
	if not estado["jugadores"].has(ejecutor):
		_dar_pelota_al_arquero(estado, not bool(bp["ataca_local"]), true)
		return
	var e_ej: Dictionary = estado["jugadores"][ejecutor]
	var ataca_local: bool = bool(bp["ataca_local"])
	e_ej["pos"] = bp["pos"]
	_entregar_pelota(estado, ejecutor)
	var equipo := _equipo_de(estado, ataca_local)
	var jugador := _dict_jugador(estado, equipo, e_ej["jugador_id"])
	if jugador.is_empty():
		return

	match str(bp["tipo"]):
		"directo":
			estado["libres_directos"] = int(estado.get("libres_directos", 0)) + 1
			_resolver_tiro(estado, e_ej, jugador, "tiros_libres")
		"centro", "corner":
			var objetivo := _mejor_en_el_area(estado, ataca_local, ejecutor)
			if objetivo == -1:
				return  # nadie llegó al área: sigue jugando en corto
			_lanzar_pase(estado, e_ej, objetivo, jugador)
			estado["pelota"]["altura_max"] = float(pesos()["fisica"]["altura_centro"])
			estado["pelota"]["es_centro"] = true
			estado["pelota"]["centro_de"] = ataca_local
			estado["centros"]["intentos"] = int(estado["centros"].get("intentos", 0)) + 1
		_:
			pass  # corto: la pone en juego y sigue el partido


## Reventarla arriba y lejos, sin destinatario: la agarra el que llegue.
## Va alta a propósito, así nadie la corta en el camino — un despeje se
## disputa donde cae, no en el medio.
static func _despejar(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var es_local: bool = poseedor["equipo_local"]
	var dir: Vector2 = (arco_rival(es_local) - poseedor["pos"]).normalized()
	var largo: float = _por_atributo(jugador, "fuerza", f["despeje_corto"], f["despeje_largo"])
	var destino := Vector2(
		clampf(poseedor["pos"].x + dir.x * largo, -LIMITE_X, LIMITE_X),
		clampf(poseedor["pos"].y + dir.y * largo + rng.randf_range(-10.0, 10.0),
			-MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))

	var pelota: Dictionary = estado["pelota"]
	_accion(estado, int(poseedor["clave"]), ACCION_PATEA)
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["pos"] = poseedor["pos"]
	pelota["vel"] = (destino - poseedor["pos"]).normalized() * float(f["vel_pase_max"])
	pelota["destino_pos"] = destino
	pelota["destino_id"] = -1
	pelota["pasador_local"] = es_local
	pelota["es_pase"] = false
	pelota["es_centro"] = false
	pelota["origen_pos"] = poseedor["pos"]
	pelota["altura_max"] = float(f["altura_despeje"])
	pelota["ticks_con_pelota"] = 0
	estado["despejes"] = int(estado.get("despejes", 0)) + 1


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

	# Al que acaba de ganar la pelota no se la disputan en el mismo
	# instante: tiene un momento para acomodarla. Sin esta gracia, apenas
	# uno la recuperaba ya lo estaba atacando el siguiente rival y salían
	# 118 quites por partido en vez de ~55.
	if int(pelota.get("ticks_con_pelota", 99)) < int(f["ticks_gracia_posesion"]):
		return

	var mejor_id := -1
	var mejor_dist: float = radio
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == es_local:
			continue
		if _en_cooldown(estado, id):
			continue  # todavía se está rehaciendo de la anterior
		var d: float = poseedor["pos"].distance_to(e["pos"])
		if d < mejor_dist:
			mejor_dist = d
			mejor_id = id
	if mejor_id == -1:
		return
	estado["robos"]["intentos"] += 1

	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var jug_a := _dict_jugador(estado, eq_a, poseedor["jugador_id"])
	var jug_d := _dict_jugador(estado, eq_d, estado["jugadores"][mejor_id]["jugador_id"])
	if jug_a.is_empty() or jug_d.is_empty():
		return

	var minuto := _minuto_int(estado)
	# Se tira al piso a quitarla, le salga o no.
	_accion(estado, mejor_id, ACCION_BARRIDA)
	# El poseedor defiende su pelota con `control` contra el `quite` del rival.
	var aguanta := _duelo_simple(jug_a, "control", eq_a, jug_d, "quite", eq_d, minuto, estado["rng"])

	# ¿Fue falta? Un quite fallado es la situación típica: llegó tarde. Las
	# TARJETAS cuelgan de acá, no del quite en sí — antes se amonestaba sin
	# que hubiera ninguna infracción, que era raro de ver.
	if not aguanta or estado["rng"].randf() < float(f["prob_falta_en_quite_ganado"]):
		if estado["rng"].randf() < float(f["prob_falta"]):
			# Sin cooldown al que hizo la falta: la infracción YA frenó la
			# jugada y devolvió la pelota. Dejarlo además fuera de juego
			# unos segundos era premiar dos veces al que la recibió, y
			# aplanaba la diferencia entre equipos buenos y malos (un
			# plantel flojo pasaba de 1,57 a 2,87 goles por partido).
			_cobrar_falta(estado, poseedor["pos"], es_local, jug_d, eq_d, eq_a, minuto)
			return
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
	# Quite resuelto como en el fútbol: o se la saca y se la queda en los
	# pies, o falla y el otro sigue con la pelota. Lo que evita el loop no
	# es que la pelota salga volando, sino que PERDER EL DUELO SE PAGA: el
	# que queda mal —el que la perdió, o el que fue a quitarla y no
	# pudo— arrastra un cooldown en el que no puede volver a ir por ella.
	# (Rebotes en un quite ganado: pendiente, ver docs.)
	# Un quite no siempre queda limpio: a veces la pelota sale desviada al
	# lateral o al córner. Es lo que hace que existan esos reinicios.
	if estado["rng"].randf() < float(f["prob_desvio_al_lateral"]):
		_penalizar(estado, poseedor["clave"], jug_a)
		_desviar_afuera(estado, poseedor["pos"], es_local)
		return

	if not aguanta:
		estado["robos"]["ganados"] += 1
		_entregar_pelota(estado, mejor_id)
		_penalizar(estado, poseedor["clave"], jug_a)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "gambeta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "pierde",
		})
	else:
		_penalizar(estado, mejor_id, jug_d)


static func _push_fotograma(estado: Dictionary, eventos_del_tick: Array = []) -> void:
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
			# Altura en metros: hoy la animación la ignora (dibuja en 2D),
			# pero sale del motor para poder mostrar el centro por arriba
			# cuando la UI lo soporte.
			"z": float(estado["pelota"].get("z", 0.0)),
			"poseedor_id": estado["pelota"]["poseedor_id"],
		},
		"jugadores": jugadores,
		"decision": estado.get("ultima_decision", null),
		# El evento semántico que ocurrió EN ESTE tick (o null). Es lo que
		# le permite a la animación mostrar el relato y el marcador en el
		# momento exacto, sin tener que cruzar por minuto contra el array
		# de eventos, que tiene otra granularidad.
		# El último evento del tick, que es lo que consume la vista vieja.
		"evento": eventos_del_tick[-1] if not eventos_del_tick.is_empty() else null,
		# Todos los del tick, en orden.
		"eventos": eventos_del_tick,
		# Actos físicos de este tick: [{"clave": int, "accion": "patea"}].
		# A diferencia de "evento", vienen con la clave del jugador, que es
		# lo que la vista necesita para animar al que corresponde.
		"acciones": estado["acciones_tick"],
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
	estado["con_fotogramas"] = con_fotogramas

	# Mismas ventanas de cambio que MatchEngine (§8.7): entretiempo, 60' y
	# 75'. Se reusa _procesar_cambios sin tocarlo.
	var ventanas := [45, 60, 75]
	for mitad in range(2):
		_reiniciar_desde_medio(estado, mitad == 0)
		estado["minuto"] = MINUTOS_MOSTRADOS_POR_MITAD * mitad
		# Un segundo quieto antes de poner la pelota en juego. La cámara
		# viene de otra parte de la cancha y salta al círculo central: sin
		# esta pausa el arranque de cada tiempo se ve como un tirón de
		# cámara y no se entiende qué pasó.
		estado["balon_parado"] = {
			"tipo": "saque_inicial", "saca_local": mitad == 0, "mitad": mitad + 1,
		}
		estado["detenido"] = int(TICKS_DETENIDO["saque_inicial"])
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
			"gambetas": estado["gambetas"],
			"paredes": estado["paredes"],
			"centros": estado["centros"],
			"despejes": estado.get("despejes", 0),
			"faltas": estado.get("faltas", 0),
			"penales": estado.get("penales", 0),
			"libres_directos": estado.get("libres_directos", 0),
			"offsides": estado.get("offsides", 0),
			"reinicios": estado["reinicios"],
			"cooldown_activos": estado["cooldown"].size(),
			"pase_detalle": estado["pase_detalle"],
			"pases": estado["pases"],
			"decisiones": estado["decisiones"],
		},
	}
