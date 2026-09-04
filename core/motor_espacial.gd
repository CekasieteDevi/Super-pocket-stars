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
## Casilleros de respaldo por puesto. La formación real vive en
## data/formaciones.json (ver core/formaciones.gd); esto solo se usa para
## ubicar a un suplente que entra cuando, por lo que sea, no quedó ningún
## slot libre que heredar.
const BASE_FORMACION := {
	"ARQ": [Vector2(-50.5, 0.0)],
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
##
## AL ARQUERO NO SE LE APLICA. Con este límite no podía retroceder más
## allá de 9 metros de su propia línea: literalmente no existía la
## posición "parado en el arco", y como su base estaba en −48 terminaba
## viviendo en el área grande. Un remate le entraba con el arquero dos
## metros por delante del arco, mirando.
const LIMITE_X := 43.5

## Lo que sí limita al arquero: no se mete adentro del arco ni se va más
## allá del borde del área grande. Entre esos dos extremos se mueve según
## dónde esté la pelota (ver ATRACCION_X), que es lo que le da el
## comportamiento de achicar cuando el juego está lejos y volver a la
## línea cuando la pelota se le viene encima.
## Cuánto se comprime la formación para que entre en la propia mitad en
## el saque del medio. La base más adelantada (el DC, en x=14) está a 66,5
## m del arco propio y tiene que caber en los 51,5 m de la mitad.
const COMPRESION_SAQUE := 0.775
const RADIO_CIRCULO := 9.15

const ARQUERO_X_MIN := 51.8
const ARQUERO_X_MAX := 36.0

## Quiénes se meten detrás de la pelota cuando el equipo no la tiene. Los
## de arriba quedan afuera a propósito: son la salida del equipo.
const ROLES_QUE_REPLIEGAN := ["DFC", "LAT", "MC"]

## Los de arriba, para la PELOTA PARADA: los que suman amenaza en el area
## en un corner propio y los que NO bajan a defender un tiro libre. Un
## enganche sube al corner y no se vuelve 28 metros porque le cobraron una
## falta a su equipo, asi que sigue contando aca.
const ROLES_QUE_ATACAN := ["MCO", "EXT", "DC"]

## Que pelotas paradas ubican a la gente de una vez, en vez de dejarla
## acomodarse trotando (ver _ubicar_para_el_balon_parado).
##
## Son las que EXIGEN que el jugador viaje: el corner y la falta que se
## cuelga al area mandan medio equipo treinta metros mas adelante, y el
## directo manda a dos o cuatro a esperar el rechazo. Trotando no
## llegaban. En un lateral, un saque de arco o una falta lejana que se
## juega corta nadie tiene que ir a ningun lado: el juego se reanuda donde
## estaba y ubicarlos ahi no arregla nada.
##
## No es una distincion de gusto, se midio (120 partidos,
## tests/_diag_goles_motores.gd). Ubicando TODAS las paradas, los 22
## quedan perfectamente ordenados en cada lateral y cada saque de arco,
## que son decenas por partido, y ese orden gratis favorece al equipo
## bueno: primera se iba a 2,92 goles por partido contra 2,59 del motor
## abstracto, y decima caia a 1,45. Limitado a esta lista queda en
## 1,63/2,11/2,50 contra 1,61/1,93/2,43 de antes del cambio, o sea que
## decima no se mueve y quinta se acerca al ancla.
##
## El directo entro despues y casi no mueve la aguja: son 0,30 por partido
## entre los dos equipos, contra 1,53 corners y 5,03 centros.
const TIPOS_QUE_SE_UBICAN := ["corner", "centro", "directo"]


## Quienes se paran EN EL HOMBRO del ultimo defensor cuando el equipo
## ataca (ver _objetivo_sin_pelota), que es de donde salen los goles.
##
## El MCO quedo AFUERA a proposito. Esperar adelantado sobre la linea de
## offside es de delantero, y con el adentro el enganche jugaba de segundo
## punta: se paraba al lado del 9 en vez de llegar al area desde atras.
## Ahora sube con SUBIDA_POR_ROL, que es llegar un momento despues — el
## unico rol que arranca por detras de la linea y termina adentro.
##
## Es una lista aparte de ROLES_QUE_ATACAN y no la misma con el MCO
## sacado: son dos preguntas distintas. Sacarlo de aquella le cambiaba
## tambien el corner y el tiro libre, que no es lo que se quiso.
const ROLES_EN_EL_HOMBRO := ["EXT", "DC"]

## Cuanto acompaña el ataque cada rol de atras, como fraccion del camino
## que le falta hasta la linea de la pelota. Los de arriba no estan porque
## ya se paran en el hombro del ultimo defensor.
##
## El volante central es el que mas sube: es el que da el pase y despues
## se quedaba clavado, que era el reporte. El central sube poco — alguien
## tiene que quedar por si la pierden.
## El MCO es el que mas sube de todos: no espera arriba como el 9, LLEGA
## al area desde atras cuando la jugada ya esta metida. Es el puesto que
## pediste y el motivo por el que salio de ROLES_EN_EL_HOMBRO.
const SUBIDA_POR_ROL := {
	"MCO": 0.95, "MC": 0.75, "LAT": 0.55, "DFC": 0.30,
}

## Lo unico que se puede hacer con la pelota estando acorralado en la
## propia area: sacarla de ahi. El remate entra porque un rechazo que
## salga disparado al arco rival tambien la saca, y no vale la pena
## prohibirlo — no va a elegirlo desde su propio campo.
const SALIDAS_DE_EMERGENCIA := ["despeje", "pase_largo", "tiro"]

## Con el juego detenido nadie corre: se acomodan trotando. Además de que
## es lo que se ve en una cancha, sirve para que el reacomodo se lea como
## un movimiento y no como un salto de un fotograma al otro.
const FACTOR_TROTE_PARADO := 0.45

## El expulsado se va CAMINANDO hasta el lateral, a la altura del medio de
## la cancha, y el juego no se reanuda hasta que sale. Antes desaparecia
## de un fotograma al otro: se veia la tarjeta y en el cuadro siguiente
## habia un jugador menos, sin que se entendiera quien se fue.
##
## Los tres factores pasan de largo el 1.0 —o sea, mas rapido que la
## velocidad tope del jugador— a proposito: el que sale y el que entra no
## estan jugando, y la salida a paso real se hacia larga de mirar (diez
## segundos con la pelota parada). Es una licencia de animacion, no una
## capacidad fisica que se use en el juego.
const FACTOR_CAMINA_EXPULSADO := 1.3

## El que ENTRA por un cambio no camina: entra al trote a ocupar su lugar.
const FACTOR_ENTRA_SUPLENTE := 1.8

## Y el que SALE por un cambio tampoco: se va al trote. Solo el expulsado
## camina, que ademas es como se ve en la cancha — uno se va rapido y sin
## drama y el otro se toma su tiempo.
const FACTOR_SALE_CAMBIADO := 2.0

## Por donde se sale y se entra: el lateral, a la altura de la mitad de la
## cancha. Es por donde salen y entran en el futbol de verdad, y tener un
## solo punto hace que se lea la escena — el que sale y el que entra se
## cruzan ahi.
static func _punto_de_salida(desde: Vector2) -> Vector2:
	var lado: float = 1.0 if desde.y >= 0.0 else -1.0
	return Vector2(0.0, lado * (MEDIO_ANCHO + 2.5))

## Tope de ticks caminando. Si por lo que sea no llega —lo empujaron
## fuera, quedo trabado— se lo saca igual: un partido no puede quedar
## detenido para siempre esperando a que alguien salga.
const TICKS_MAX_SALIENDO := 140

## Tope de ticks que se pueden reponer por entradas, salidas y esperas al
## pateador designado en una mitad. Es un seguro: sin el, un cambio que no
## termina nunca alargaria el partido sin fin.
##
## Subio de 200 a 400 al aparecer los roles. Esperar al pateador se
## descuenta del tiempo jugado, pero el reloj corre igual, y con 200 la
## mitad se cortaba por reloj antes de completar los minutos: medido, los
## goles bajaban de 2,14 a 2,01 y los corners de 1,38 a 1,21 por partido
## solo con asignar pateadores.
const TICKS_REPUESTOS_TOPE := 400

## El que va a ejecutar el balon parado se mueve MAS RAPIDO que el resto:
## los demas se acomodan, el va a buscar la pelota.
const FACTOR_CORRE_A_LA_PELOTA := 1.0

## Qué parte de la interrupción se pasa completamente quieto antes de que
## los jugadores empiecen a acomodarse. Es lo que hace que se LEA que el
## juego se cortó: con poco tiempo quieto, los 22 arrancan a trotar casi
## enseguida y desde afuera parece que la jugada nunca se detuvo.
const FRACCION_QUIETOS := 0.6

## Cuántos metros más allá de la línea sigue la pelota antes de darla por
## afuera. Frenarla justo encima de la cal no se lee como que salió.
const MARGEN_SALIDA := 3.0

## Medio ancho del arco (7,32 m reglamentarios). Lo usa el remate para
## saber dónde termina la portería y dónde empieza el afuera.
const ARCO_MEDIO_ANCHO := 3.66

## El area grande, en metros reglamentarios desde la linea de fondo y
## desde el centro del arco. Estaban escritos a mano dentro de
## _en_el_area; ahora los lee tambien el carril de banda, que gira hacia
## el arco justo "a la altura del area". Un solo lugar donde cambiarlos.
const AREA_LARGO := 16.5
const AREA_MEDIO_ANCHO := 20.16

## Metros extra que cubre un arquero tirándose, por encima de lo que
## alcanza a correr mientras la pelota viaja.
const ALCANCE_ESTIRADA := 2.0

## Cuántos ticks queda detenido el juego según lo que se cobró. Un tick
## son 0,25 s, así que 10 ticks son 2,5 segundos de reloj de partido: lo
## suficiente para que se vea que el juego paró y que la gente se acomoda,
## sin que aburra a x1.
## El penal es la pausa mas larga de todas a proposito: es el unico
## momento del partido en que todos se quedan quietos mirando a uno.
const TICKS_DETENIDO := {"falta": 14, "corner": 20, "gol": 10, "saque_inicial": 12,
	"lateral": 10, "saque_arco": 8, "penal": 20}

## Cuanto puede estirarse una mitad para terminar lo que quedo pendiente.
## Son 15 ticks = casi 4 minutos de reloj mostrado: alcanza para ejecutar
## un penal cobrado sobre la hora y su reanudacion.
const TICKS_DE_DESCUENTO := 15


## Hay una jugada sin terminar que no puede quedar en el aire: una pelota
## parada por ejecutar, o un remate viajando hacia el arco.
static func _hay_algo_sin_terminar(estado: Dictionary) -> bool:
	if estado.has("balon_parado"):
		return true
	if int(estado.get("detenido", 0)) > 0:
		return true
	return bool(estado["pelota"].get("es_remate", false))


## Dos segundos en los que NADIE se mueve, antes de acomodarse para el
## tiro libre. Es donde se ve la infraccion: el que la hizo parado donde
## la hizo, el otro en el piso, y la tarjeta si sale.
##
## Antes no existia: en el mismo tick de la falta se teletransportaba a
## los 22 a sus puestos de balon parado, asi que el infractor aparecia a
## veinte metros de la jugada y la amarilla salia sobre una cancha ya
## acomodada. No se entendia quien habia hecho que.
const TICKS_CONGELADO_FALTA := 8

## Lo mismo para el corner, mas corto: aca lo que hay que ver no es una
## infraccion sino de donde salio la pelota. Los segundos de "todos
## ubicados esperando el centro" salen del tiempo de acomodo, porque el
## que llega a su marca se queda parado.
const TICKS_CONGELADO_CORNER := 4

## Desde mas lejos que esto nadie va a buscar la pelota para ejecutar un
## corner o un centro: no llega caminando en lo que dura la pausa y
## terminaria apareciendo encima de la pelota de golpe.
const DIST_MAX_AL_EJECUTOR := 22.0

## Lo mismo, pero para el pateador que ELIGIO EL CLUB (ver core/roles.gd).
##
## El limite de arriba esta calibrado para lo que un jugador camina en la
## pausa normal, y con el rol de corners recien puesto se midio que no
## alcanzaba para nada: el designado esta a 64 metros del banderin de
## mediana —aun eligiendo al mejor centrador del once— porque el corner se
## arma en el instante en que sale la pelota, con todos donde los dejo la
## jugada. Llegaba el 10% de las veces, o sea que elegir pateador no
## servia.
##
## Al designado se lo espera: la pausa se estira lo que haga falta para
## que llegue trotando, igual que en la cancha se espera al que patea los
## corners. Mas lejos que esto la patea el que esta cerca, que tambien es
## lo que pasa de verdad cuando el especialista esta en la otra punta y el
## equipo quiere sacar rapido.
const DIST_MAX_EJECUTOR_DESIGNADO := 80.0

## Metros que cubre por tick el que va a buscar la pelota. Sale de la
## calibracion de arriba: 22 metros en los 20 ticks de pausa del corner.
const METROS_POR_TICK_EJECUTOR := 1.1

## Ticks de mas que se le dan encima del viaje, para que se lo vea llegar
## y acomodarse en vez de patear en el mismo tick en que pisa la pelota.
const TICKS_MARGEN_EJECUTOR := 4

## Desde mas lejos que esto no se llega a la barrera antes de que la
## pateen, asi que el que esta mas lejos no va: la barrera queda mas
## chica, igual que en una cancha.
const DIST_MAX_A_LA_BARRERA := 14.0

## El punto del penal: 11 m del arco.
const DIST_PENAL := 11.0

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


## §7.3: suma uso de un atributo. Se guarda por jugador_id porque es lo
## que persiste entre partidos; la clave espacial no le sirve a nadie
## fuera del partido.
static func _xp(estado: Dictionary, jugador_id: int, es_local: bool, atributo: String, cantidad: float = 1.0) -> void:
	var lado: String = "home" if es_local else "away"
	if not estado["xp"].has(lado):
		estado["xp"][lado] = {}
	var por_jugador: Dictionary = estado["xp"][lado]
	if not por_jugador.has(jugador_id):
		por_jugador[jugador_id] = {}
	var d: Dictionary = por_jugador[jugador_id]
	d[atributo] = float(d.get(atributo, 0.0)) + cantidad


## Lo mismo tomando la entidad del motor, que es lo que hay a mano en la
## mayoría de los sitios.
static func _xp_e(estado: Dictionary, e: Dictionary, atributo: String, cantidad: float = 1.0) -> void:
	_xp(estado, int(e["jugador_id"]), bool(e["equipo_local"]), atributo, cantidad)


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
## `absoluto` separa DOS preguntas que antes eran la misma:
##
##   desde donde SE ANIMA a patear -> absoluto. Que tan lejos del arco
##   ves chance es tu pierna, no contra quien jugas. Normalizado, decima
##   y quinta remataban desde exactamente la misma distancia.
##
##   que tan BUENO sale el remate -> normalizado. Aca si tiene que ser
##   relativo: absoluto, un delantero de primera no erraba nunca y la
##   liga terminaba con 4,10 goles por partido contra 2,20 en decima,
##   mientras el motor abstracto daba lo mismo en todas.
##
## Se midio que son palancas independientes: el rango mueve la distancia
## de los remates y no los goles; los pesos de tiro_resolucion mueven los
## goles y no la distancia (tests/_diag_remates.gd).
## Solo el ANGULO al arco: 1 de frente, 0 desde la linea de fondo. Es la
## mitad de factor_geometria que NO depende de cuan lejos estas.
##
## Existe aparte porque el tiro libre necesita separar las dos preguntas.
## Con el factor combinado, la distancia quedaba limitada dos veces —una
## por `tiros_libres` del pateador y otra por el rango fijo de
## factor_geometria, que corta en ~25,6 m— y el atributo no podia estirar
## el alcance ni un metro por encima de eso. Medido: subir
## rango_libre_bueno de 30 a 34 no movia nada.
static func factor_angulo(pos: Vector2, equipo_local: bool) -> float:
	var arco := arco_rival(equipo_local)
	var dx: float = maxf(absf(arco.x - pos.x), 1.0)
	var dy: float = absf(pos.y)
	return clampf(1.0 - (dy / dx) / 1.5, 0.0, 1.0)


static func factor_geometria(pos: Vector2, equipo_local: bool, jugador: Dictionary = {},
		es_decision: bool = false) -> float:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(equipo_local)
	var dist := pos.distance_to(arco)
	var dx: float = maxf(absf(arco.x - pos.x), 1.0)
	var dy: float = absf(pos.y)
	var rango: float = float(f["rango_tiro_medio"])
	if not jugador.is_empty():
		rango = _por_atributo(jugador, "tiro", f["rango_tiro_malo"],
			f["rango_tiro_bueno"], float(f["mezcla_fisica_rango_tiro"]) if es_decision else 0.0)
	var f_dist: float = clampf(1.0 - (dist - 5.0) / rango, 0.0, 1.0)
	return f_dist * factor_angulo(pos, equipo_local)


# ---------------------------------------------------------------------------
# Armado del estado inicial
# ---------------------------------------------------------------------------

## Nivel al que se juega el partido en curso (media de los dos planteles).
## Es estado estático a propósito y no un parámetro: lo consumen una
## docena de curvas repartidas por todo el motor, la mitad de ellas sin
## `estado` a mano, y los partidos se simulan de a uno. Lo fija
## crear_estado() al armar el partido.
static var _nivel_partido: float = MatchEngine.NIVEL_REFERENCIA


## Interpola entre dos valores segun un atributo 0-100, medido contra el
## NIVEL del partido (ver MatchEngine.relativo_al_nivel).
##
## Va normalizado por defecto porque la cancha no cambia de tamaño con la
## división. Con el gradiente de NivelDivision, un delantero de primera
## con tiro ~87 remataba desde mucho más lejos (rango_tiro) que uno de
## décima con tiro ~37, y así primera terminaba con 18,8 remates y 4,10
## goles por partido contra 6,4 y 2,20 en décima — mientras el motor
## abstracto, que resuelve el resto de la liga y contra el que están
## calibrados economía, objetivos y fans, daba ~3,3 en todas.
##
## `mezcla_absoluta` es para lo que SÍ tiene que escalar con la división:
## la velocidad y la aceleración. Son las que hacen que primera se vea
## rápida y asociada y décima lenta y trabada, que es lo que hace que
## ascender se note. Lo que no puede escalar es cuántos goles termina
## habiendo.
##
## Va de 0 (todo relativo al nivel del partido) a 1 (fisico puro). Es un
## MEZCLADOR y no un booleano porque el rango de tiro necesita quedarse en
## el medio: en absoluto puro un plantel de primera remata desde tan lejos
## que suma tres remates por partido y se va a 3,25 goles contra 2,50 del
## motor abstracto; en relativo puro decima y quinta rematan exactamente
## desde la misma distancia, que es lo que no queremos.
static func _por_atributo(jugador: Dictionary, atributo: String, en_0: float, en_100: float,
		mezcla_absoluta: float = 0.0) -> float:
	var bruto: float = float(jugador["atributos"][atributo])
	var relativo: float = MatchEngine.relativo_al_nivel(bruto, _nivel_partido)
	var valor: float = lerpf(relativo, bruto, clampf(mezcla_absoluta, 0.0, 1.0))
	return en_0 + clampf(valor / 100.0, 0.0, 1.0) * (en_100 - en_0)


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
	return _por_atributo(jugador, "velocidad", f["vel_min"], f["vel_max"], 1.0)


## Cuántos m/s² gana por segundo. Nadie pasa de parado a su velocidad
## punta en un tick: hay una rampa, y `aceleracion` es lo que decide cuán
## corta es. Un jugador de aceleración 90 llega a punta en ~1,7 s y uno de
## 20 tarda casi el doble, que en los primeros metros —donde se define un
## mano a mano— es la diferencia entre llegar y no llegar.
##
## Hasta ahora `aceleracion` no la leía NADIE: solo pesaba en la media del
## jugador vía position_weights.json.
static func _aceleracion(jugador: Dictionary) -> float:
	var f: Dictionary = pesos()["fisica"]
	return _por_atributo(jugador, "aceleracion", f["acel_min"], f["acel_max"], 1.0)


## Cuánto terreno cubre desde su velocidad ACTUAL en `segundos`, con la
## rampa incluida. Lo usa el remate para saber hasta dónde llega el
## arquero mientras la pelota viaja: con aceleración, estimar con la
## velocidad punta le daba un alcance que no tiene.
static func _alcance_en(e: Dictionary, segundos: float) -> float:
	var v0: float = float(e.get("rapidez", 0.0))
	var a: float = float(e.get("aceleracion", 3.0))
	var vmax: float = float(e["vel_max"])
	var t_rampa: float = maxf(vmax - v0, 0.0) / maxf(a, 0.01)
	if segundos <= t_rampa:
		return v0 * segundos + 0.5 * a * segundos * segundos
	return v0 * t_rampa + 0.5 * a * t_rampa * t_rampa + vmax * (segundos - t_rampa)


## Reparte los 11 de un equipo en los slots de su formación.
static func _armar_jugadores(equipo: Team, es_local: bool, estado: Dictionary) -> void:
	# El reparto es por SLOT, no por puesto: el slot `i` de la formación lo
	# ocupa jugadores[i]. Antes se repartía por `posicion` y, si un equipo
	# tenía tres jugadores del mismo puesto, los que sobraban caían al
	# mismo casillero y quedaban apilados. Además así el rol en cancha sale
	# de la formación, que es lo que permite jugar a alguien fuera de su
	# puesto sin ninguna mecánica nueva.
	var slots := Formaciones.slots(equipo.formacion)
	for i in range(mini(equipo.jugadores.size(), slots.size())):
		var j: Dictionary = equipo.jugadores[i]
		var rol: String = str(slots[i]["rol"])
		var base: Vector2 = slots[i]["base"]
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
			"aceleracion": _aceleracion(j),
			# Velocidad ESCALAR actual. Arranca en cero: nadie sale
			# lanzado desde el saque del medio.
			"rapidez": 0.0,
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
	_nivel_partido = MatchEngine.nivel_partido(home, away)
	var estado := {
		"home": home, "away": away,
		"nivel": _nivel_partido,
		"jugadores": {},
		"pelota": {"pos": Vector2.ZERO, "vel": Vector2.ZERO, "poseedor_id": -1, "en_vuelo": false},
		"minuto": 0.0,
		"tick": 0,
		"rng": rng,
		"log": [],
		"goles_log": [],
		# {de, a, local} del último pase completado: de quién salió, a qué
		# clave llegó y de qué equipo. Lo consume _asistente_de().
		"ultimo_pase": {},
		# Los que estan SALIENDO de la cancha (expulsados o cambiados) y
		# los que estan ENTRANDO desde el lateral. Mientras haya alguno,
		# el juego espera. Ver _avanzar_entradas_y_salidas.
		"saliendo": [],
		"entrando": [],
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
		"dist_pases": [],
		"dist_pelotazos": [],
		# §7.3 aprendizaje por uso: cuántas veces cada jugador usó cada
		# atributo, y cuántos ticks estuvo en cancha. Se normaliza al
		# terminar (ver xp_normalizada) para que el TOTAL no dependa del
		# motor, solo el reparto.
		"xp": {},
		"ticks_en_cancha": {},
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


## CARRIL DE BANDA. A donde va el que conduce: el arco rival, salvo que
## venga ABIERTO y todavia no haya llegado a la altura del area — ahi va
## al vertice del area de su lado, o sea corre la linea pero sin meterse
## en el cornerin.
##
## Antes los once roles conducian derecho al arco y el que recibia en la
## banda se metia al medio desde el primer toque: el juego de banda no
## existia. Medido con tests/_diag_banda.gd sobre 30 partidos, la
## conduccion abierta se desviaba 1,9 m hacia el medio y solo el 81%
## terminaba todavia abierta; ahora son 1,1 m y el 90%.
##
## Se ata a estar ABIERTO y no al rol EXT a proposito. Dos de las cinco
## formaciones —3-5-2 y 5-3-2— no tienen ningun extremo y sacan el ancho
## de los laterales; con la regla puesta en el rol esas dos se quedaban
## sin banda. El umbral es el mismo `banda_para_centrar` que ya decide si
## estas lo bastante abierto como para colgarla.
##
## Apunta hacia el VERTICE del area y no hacia la linea de fondo:
## corriendo paralelo a la cal el jugador no progresa, `valor_posicion` no
## le mejora y termina en el cornerin. Medido con el paralelo puro, las
## conducciones abiertas caian de 72 a 56 y los centros de 2,1 a 1,7.
## Cuanto se pega lo gradua `apego_a_la_banda`.
static func _destino_de_conduccion(pos: Vector2, es_local: bool) -> Vector2:
	var arco := arco_rival(es_local)
	var f: Dictionary = pesos()["fisica"]
	if absf(pos.y) < float(f["banda_para_centrar"]):
		return arco
	if absf(arco.x - pos.x) <= AREA_LARGO:
		return arco
	# `apego_a_la_banda` mezcla entre el arco (0) y el vertice del area
	# (1). Es la palanca del tradeoff: mas apego se ve mas a juego de
	# banda, pero el que corre la linea se aleja de sus companeros y
	# pierde opciones de pase. Medido en quinta, apego pleno costaba 0,25
	# goles por partido (tests/_diag_goles_motores.gd, 120 partidos).
	var lado: float = 1.0 if pos.y >= 0.0 else -1.0
	var vertice := Vector2(arco.x - signf(arco.x) * AREA_LARGO, lado * AREA_MEDIO_ANCHO)
	return arco.lerp(vertice, clampf(float(f["apego_a_la_banda"]), 0.0, 1.0))


## Punto hasta donde se mira el corredor de conduccion. Sigue el MISMO
## destino al que iria conduciendo: mirar hacia el arco mientras se corre
## la banda hacia otro lado dejaba la utilidad evaluando un camino que el
## jugador no pensaba recorrer.
static func _frente_de(pos: Vector2, es_local: bool) -> Vector2:
	var hacia: Vector2 = _destino_de_conduccion(pos, es_local) - pos
	if hacia.length() < 0.001:
		return pos
	var largo: float = minf(float(pesos()["fisica"]["corredor_conduccion"]), hacia.length())
	return pos + hacia.normalized() * largo


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
	# El arquero no encara, no juega paredes y no sale conduciendo: saca.
	# Sin esto se lo vio salir de un saque de arco a jugar una pared con un
	# defensor, perderla y comerse el gol — el motor lo trataba como a un
	# jugador de campo más porque nada lo distinguía.
	var es_arquero: bool = poseedor["rol"] == "ARQ"
	var pos: Vector2 = poseedor["pos"]
	var presion := presion_normalizada(estado, pos, es_local)
	var mi_valor := valor_posicion(pos, es_local)
	var opciones := []

	# ACORRALADO: en tu propia zona y con gente encima, la unica salida es
	# sacarla de ahi. No se pondera contra el resto — se DESCARTA el resto.
	#
	# Subirle el peso al despeje no alcanzaba y el motivo es estructural,
	# no de calibracion: el pase largo se evalua UNA VEZ POR CADA
	# companero alcanzable, asi que compiten diez opciones contra una sola
	# de despeje y el maximo de diez casi siempre gana. Medido, un
	# defensor con la pelota en su propia area y presion media 0,72
	# despejaba 1 de cada 23 veces; multiplicando por 3,6 el peso de la
	# presion, 4 de 23. El problema no era cuanto vale despejar sino
	# contra cuantos rivales compite.
	#
	# Se dejan el despeje y el pelotazo: las dos sacan la pelota del area,
	# que es lo que importa. Lo que se va son el pase corto, la conduccion,
	# la gambeta, la pared y el pase al hueco — todo lo que implica seguir
	# jugando con la pelota en la puerta del propio arco.
	var acorralado: bool = mi_valor <= float(f["zona_despeje"]) 		and presion >= float(f["presion_despeje"])

	# §4.2: con rivales metidos en tu propio tercio, el arquero la manda
	# lejos en vez de repartirla corto.
	#
	# La medicion no mostraba que el arquero eligiera MAL —el companero al
	# que se la da esta libre (presion 0,02) y la tasa de pase del motor es
	# 73%, que es realista— pero salir jugando con tres rivales rondando el
	# area es una decision, y en el futbol de verdad solo la toma el que
	# sabe. Lo pondera la INTELIGENCIA: un arquero lucido la revienta, uno
	# limitado insiste en salir jugando y regala la pelota en la puerta del
	# area, que es justo el error que uno espera de una division baja.
	var arquero_apurado := 0.0
	if es_arquero:
		var arco_propio := arco_rival(not es_local)
		var invasores := 0
		for id_r in estado["jugadores"]:
			var er: Dictionary = estado["jugadores"][id_r]
			if er["equipo_local"] == es_local:
				continue
			if absf(arco_propio.x - er["pos"].x) <= float(pesos()["fisica"]["tercio_propio_arquero"]):
				invasores += 1
		var lucidez_arq: float = clampf(
			float(jugador["atributos"]["inteligencia"]) / 100.0, 0.0, 1.0)
		arquero_apurado = clampf(
			float(invasores) / float(pesos()["fisica"]["invasores_para_reventarla"]),
			0.0, 1.0) * lucidez_arq

	# --- Conducir -----------------------------------------------------
	# `camino_libre` responde una pregunta que ningun otro termino hacia:
	# QUIEN LE TAPA EL CAMINO. `presion` mira quien lo RODEA, que es otra
	# cosa: un delantero solo, con veinte metros de cancha abierta por
	# delante, media igual que uno encerrado entre lineas. Encima el
	# termino `progreso` de conducir se apaga cuanto mas cerca del arco
	# rival estas, asi que la conduccion se hundia justo en el tercio
	# donde correr con la pelota vale mas. Medido, un poseedor libre y
	# adelantado conducia el 40-55% de las veces (tests/_diag_pase_atras).
	var camino_libre := 1.0 - riesgo_linea(estado, pos, _frente_de(pos, es_local), es_local)
	if not es_arquero:
		var wc: Dictionary = w["conducir"]
		var u_conducir: float = wc["base"] + wc["espacio"] * (1.0 - presion)
		u_conducir += wc["progreso"] * (1.0 - mi_valor)
		u_conducir += wc["camino"] * camino_libre
		opciones.append({
			"tipo": "conducir", "utilidad": u_conducir,
			"detalle": {"presion": presion, "mi_valor": mi_valor, "camino": camino_libre},
		})

	# --- Tirar --------------------------------------------------------
	# ABSOLUTO: la DECISION de patear de lejos es fisica. La resolucion
	# del remate, mas abajo en _resolver_tiro, sigue normalizada.
	var geo := factor_geometria(pos, es_local, jugador, true)
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
	var sabe_gambetear: bool = not es_arquero 		and float(jugador["atributos"]["control"]) >= float(f["control_minimo_gambeta"])
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
		var u_gambeta: float = wg["base"]
		u_gambeta += wg["habilidad"] * ventaja * ventaja
		u_gambeta += wg["progreso"] * (1.0 - mi_valor)
		u_gambeta -= wg["presion"] * presion
		# ENCARAR DESDE LA BANDA. Es el recurso del extremo que quiere
		# acomodarse frente al arco, y era el que no existia: medido, 0,2
		# gambetas por partido en esa situacion (tests/_diag_banda.gd).
		#
		# Va aparte de `progreso` porque no es lo mismo estar adelantado
		# que estar adelantado Y ABIERTO. Por el medio, con la defensa
		# junta por delante, encarar sigue siendo mala idea; por afuera
		# tenes al lateral solo y la linea de fondo para irte.
		#
		# Reusa los dos umbrales de `puede_centrar`: si estas lo bastante
		# abierto y adelantado como para colgarla, estas en la zona donde
		# un extremo encara. Una sola definicion de "venir por la banda".
		if absf(pos.y) >= float(f["banda_para_centrar"]) and mi_valor >= float(f["avance_para_centrar"]):
			u_gambeta += wg["banda"]
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
	# ABSOLUTO: hasta donde llega una patada es fisico, no relativo a la
	# division. Normalizado al nivel del partido, un plantel con fuerza
	# media 37 ponia exactamente la misma pelota de 60 m que uno de 86 —
	# medido, las tres divisiones daban la misma distribucion. En una liga
	# de burros todos eran "promedio" y por lo tanto todos llegaban lejos.
	var max_dist: float = _por_atributo(jugador, attr_alcance,
		f["max_dist_pase_malo"], f["max_dist_pase_bueno"], 1.0)
	var sesgo_pase: float = float(sesgos["creador_pase"]) if Personalidad.tiene(jugador, "Creador") else 1.0
	# El pase al hueco hay que VERLO: si el jugador no tiene la visión, la
	# opción ni le aparece. Es lo que separa a un armador de un jugador que
	# solo la toca al de al lado.
	var wh: Dictionary = w["pase_hueco"]
	# El pelotazo llega tan lejos como la pierna del que la pega, no como
	# su técnica: por eso un equipo malo igual lo tiene disponible.
	var wl: Dictionary = w["pase_largo"]
	var max_largo: float = _por_atributo(jugador, "fuerza",
		f["max_pelotazo_debil"], f["max_pelotazo_fuerte"], 1.0)
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
				+ wl["salida"] * (1.0 - mi_valor) 				+ wl["arquero_apurado"] * arquero_apurado
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
			- wp["distancia"] * (dist / max_dist) 			- wp["arquero_apurado"] * arquero_apurado
		# El pase atras es un recurso para salir de una presion, no la
		# jugada de un jugador libre y con la cancha abierta por delante.
		# Sin esto competia de igual a igual con seguir corriendo, y encima
		# multiplicado por los N companeros que quedaban por detras: es el
		# mismo problema estructural del despeje (ver `acorralado`), diez
		# opciones contra una sola y el maximo de diez gana casi siempre.
		if progreso < 0.0:
			u_pase -= wp["retroceso_libre"] * (-progreso) * camino_libre * (1.0 - presion)
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
		if sabe_pared and not es_arquero and dist <= dist_max_muro and rival_delante != -1:
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
	# Ver `acorralado` arriba: con la pelota en tu propia zona y gente
	# encima, se descartan las opciones de seguir jugandola. Se filtra al
	# final y no en cada bloque para que la regla se lea de una sola vez.
	if acorralado:
		var salidas := []
		for o in opciones:
			if SALIDAS_DE_EMERGENCIA.has(str(o["tipo"])):
				salidas.append(o)
		if not salidas.is_empty():
			return salidas
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
	_xp_e(estado, poseedor, "control")
	_xp_e(estado, e_rival, "quite")

	var att_a: Dictionary = jugador["atributos"]
	var att_d: Dictionary = defensor["atributos"]
	var habilidad: float = float(att_a["control"]) * 0.7 + float(att_a["agilidad"]) * 0.3
	var marca: float = float(att_d["quite"]) * 0.7 + float(att_d["agilidad"]) * 0.3

	var ata := Duel.atributo_efectivo(habilidad, "tecnico", eq_a.resistencia_pct(jugador["id"]))
	var def := Duel.atributo_efectivo(marca, "defensivo", eq_d.resistencia_pct(defensor["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, jugador, "control", minuto, estado["rng"]),
		MatchEngine._bloques_equipo(eq_d, eq_a, defensor, "quite", minuto, estado["rng"]))
	var pasa := Duel.gana_atacante(res, estado["rng"])

	# Lo pasó: el que quedó mal parado puede haberlo bajado. La falta se
	# COBRA —con su tarjeta, su parada de juego y su tiro libre— en vez de
	# amonestar suelto. Antes acá se llamaba directo a
	# _chequear_tarjeta_repetido, así que salía una amarilla sin falta: se
	# veía la barrida, aparecía la tarjeta y el juego seguía como si nada.
	if pasa and estado["rng"].randf() < float(f["prob_falta_en_gambeta"]):
		_cobrar_falta(estado, poseedor["pos"], es_local, defensor, eq_d, eq_a, minuto)
		return

	if pasa:
		estado["gambetas"][lado_g]["ganadas"] += 1
		# Al que lo pasan queda fuera de la jugada unos segundos y el que
		# gambeteó sigue con la pelota: la ventaja la da la penalización,
		# no un salto de posición.
		#
		# Antes acá se lo TELETRANSPORTABA a tres metros más allá del
		# defensor. Eran hasta cinco metros en un tick, o sea el doble de
		# lo que puede correr, y como el punto de llegada se calculaba
		# desde el defensor, muchas veces lo dejaba pegado a OTRO rival:
		# se veía al que llevaba la pelota aparecer de golpe encima de un
		# marcador nuevo. La gambeta se lee igual —el defensor se queda
		# clavado— sin romper la física del resto del motor.
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
	return absf(arco.x - punto.x) <= AREA_LARGO and absf(punto.y) <= AREA_MEDIO_ANCHO


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

	_xp_e(estado, estado["jugadores"][atacante], "cabezazo")
	_xp_e(estado, estado["jugadores"][defensor], "salto")
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

	var objetivo_x: float = base.x + pelota_pos.x * ax
	var objetivo_y: float = base.y + (pelota_pos.y - base.y) * ay

	if not tiene_pelota_mi_equipo:
		# El estilo CORRE LA LÍNEA hacia el arco rival o hacia el propio.
		#
		# Antes multiplicaba `ax`, o sea cuánto sigue el jugador a la
		# pelota. Eso no corre la línea: la amplifica en las DOS
		# direcciones, y como la pelota pasa tiempo en las dos mitades, el
		# efecto se cancela solo. Medido con tests/_diag_estilos_linea.gd:
		# los seis estilos defendían entre 40,3 y 41,8 m de su arco, o sea
		# un metro y medio de diferencia entre Presión alta y Defensivo.
		# Elegir estilo no cambiaba nada visible, que era el reporte.
		#
		# Como desplazamiento, la línea va de 31,9 m (Defensivo) a 44,0 m
		# (Presión alta): doce metros, que sí se ven.
		# El desplazamiento se mide contra el estilo POR DEFECTO, no
		# contra cero: asi el equilibrio del motor —que se calibro con
		# todos los estilos en la misma linea— no se mueve, y lo unico que
		# cambia es la diferencia ENTRE estilos. Restando el valor crudo,
		# los seis estilos defendian ocho metros mas atras y los goles
		# caian de 2,4 a 1,8 por partido en las tres divisiones.
		var retroceso: float = Estilos.retroceso_sin_pelota(equipo.estilo) 			- Estilos.RETROCESO_DEFAULT
		var hacia_rival: float = 1.0 if e["equipo_local"] else -1.0
		objetivo_x += -retroceso * float(f["desplazamiento_por_estilo"]) * hacia_rival
	if rol == "ARQ":
		# Su propio corral: entre la línea y el borde del área.
		if e["equipo_local"]:
			objetivo_x = clampf(objetivo_x, -ARQUERO_X_MIN, -ARQUERO_X_MAX)
		else:
			objetivo_x = clampf(objetivo_x, ARQUERO_X_MAX, ARQUERO_X_MIN)
		return Vector2(objetivo_x, clampf(objetivo_y, -ARCO_MEDIO_ANCHO * 2.2, ARCO_MEDIO_ANCHO * 2.2))
	objetivo_x = clampf(objetivo_x, -LIMITE_X, LIMITE_X)

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
	# ...pero SOLO cuando la pelota ya está cerca. Con la pelota en campo
	# propio el delantero baja a recibir, que es lo que hace un 9 de
	# verdad. Antes el pin al hombro del último defensor era incondicional
	# —un maxf sin excusa— asi que los de arriba quedaban clavados contra
	# la linea del rival aunque la pelota estuviera a sesenta metros: se
	# los veia parados en offside detrás de los centrales mientras el
	# equipo salia jugando, y la unica manera de llegarles era el
	# pelotazo. El equipo quedaba partido en dos.

	# Subir con el ataque. Los de atras no se quedan en su casillero
	# cuando el equipo mete la pelota en campo rival: acompañan hacia la
	# linea de la pelota, tanto mas cuanto mas metida esta.
	#
	# Medido antes del cambio: con la pelota en el tercio rival el MC se
	# paraba a 54,9 m del arco rival —veinticinco metros DETRAS de la
	# pelota— y no pisaba el area ni una vez. Daba el pase al delantero y
	# se quedaba mirando, que es exactamente lo que se reporto.
	#
	# Se mueve hacia la pelota y no hacia el arco a proposito: asi el
	# jugador nunca se adelanta a la jugada y la forma del equipo se
	# mantiene. El clamp de offside de mas abajo igual lo alcanza.
	if tiene_pelota_mi_equipo and SUBIDA_POR_ROL.has(rol):
		var avance_pelota: float = valor_posicion(pelota_pos, e["equipo_local"])
		var umbral: float = float(f["avance_para_acompanar"])
		var pleno: float = float(f["avance_acompanamiento_pleno"])
		var cuanto: float = clampf((avance_pelota - umbral) / maxf(pleno - umbral, 0.01), 0.0, 1.0)
		var empuje: float = float(SUBIDA_POR_ROL[rol]) * cuanto
		empuje *= Estilos.acompanamiento(equipo.estilo) / Estilos.ACOMPANAMIENTO_DEFAULT
		# Los de atras acompañan hasta la LINEA DE LA PELOTA. El MCO no:
		# el llega AL AREA, que es lo que hace un enganche cuando la
		# jugada ya esta metida y lo que lo diferencia de un MC.
		#
		# Con el destino en la pelota se quedaba a 32 m del arco y entraba
		# al area MENOS que cuando jugaba de segundo punta —0,06 contra
		# 0,11 por situacion de ataque—, o sea justo lo contrario de
		# acompañar: la pelota suele estar en el borde del area o abierta,
		# asi que apuntarle a ella lo dejaba afuera siempre.
		var destino_x: float = pelota_pos.x
		if rol == "MCO":
			var arco_at := arco_rival(e["equipo_local"])
			var borde: float = arco_at.x - signf(arco_at.x) * AREA_LARGO
			if e["equipo_local"]:
				destino_x = maxf(pelota_pos.x, borde)
			else:
				destino_x = minf(pelota_pos.x, borde)
		objetivo_x = lerpf(objetivo_x, destino_x, clampf(empuje, 0.0, 1.0))

	if tiene_pelota_mi_equipo and ROLES_EN_EL_HOMBRO.has(rol):
		var avance: float = valor_posicion(pelota_pos, e["equipo_local"])
		# El 9 baja MUCHO MENOS que el resto: es la referencia y tiene que
		# quedar alguien arriba. Los que vienen a buscarla son el enganche
		# y los extremos, que es como se reparte de verdad. Bajando los
		# tres por igual, el equipo se quedaba sin nadie en el area y los
		# remates caian a la mitad.
		if avance < float(f["avance_para_jugar_en_el_hombro"]):
			# Baja a ofrecerse: se acerca a la pelota en vez de esperarla.
			var apoyo: float = float(f["apoyo_del_delantero"])
			if rol == "DC":
				apoyo *= float(f["apoyo_del_nueve"])
			objetivo_x = lerpf(objetivo_x, pelota_pos.x, apoyo)
			objetivo_y = lerpf(objetivo_y, pelota_pos.y, apoyo * 0.5)
			return Vector2(clampf(objetivo_x, -LIMITE_X, LIMITE_X),
				clampf(objetivo_y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
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
	var dist: float = delta.length()
	if dist < 0.01:
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		return
	var dir: Vector2 = delta / dist
	var rapidez: float = float(e.get("rapidez", 0.0))

	# Girar cuesta velocidad: a 8 m/s no se cambia de sentido sin frenar.
	# Un cambio chico de rumbo casi no paga (el coseno vale ~1), pero
	# darse vuelta del todo deja al jugador casi parado, y ahí la
	# aceleración vuelve a decidir cuánto tarda en relanzarse.
	if e["vel"].length_squared() > 0.01:
		var alineacion: float = dir.dot(e["vel"].normalized())
		rapidez *= clampf((alineacion + 1.0) * 0.5,
			float(pesos()["fisica"]["freno_giro"]), 1.0)

	var tope: float = float(e["vel_max"]) * factor
	rapidez = minf(rapidez + float(e.get("aceleracion", 3.0)) * TICK_SEG, tope)
	var paso: float = rapidez * TICK_SEG
	if paso >= dist:
		e["pos"] = objetivo
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		return
	e["pos"] = e["pos"] + dir * paso
	e["vel"] = dir * rapidez
	e["rapidez"] = rapidez


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
## `mitad` 1 o 2 = arranque de un tiempo (lo anuncia el relato); 0 = saque
## del medio después de un gol. En los dos casos el saque queda ARMADO,
## no ejecutado: se para el juego unos segundos y recién entonces se la
## tocan. Antes el post-gol reiniciaba y devolvía la pelota de una, así
## que el que la tenía salía corriendo desde el círculo — el mismo bug
## que ya se había arreglado para el arranque de cada tiempo, pero por
## este otro camino.
## Quién saca del medio.
##
## Buscaba el MCO y nada más, y si el equipo no tenía uno devolvía -1: el
## saque quedaba SIN armar, nadie tomaba la pelota y el tiempo entero no
## se jugaba. De las cinco formaciones solo el 4-2-3-1 tiene MCO, así que
## en cuanto los clubes de la IA dejaron de jugar todos 4-2-3-1, cuatro de
## cada cinco partidos se morían enteros — 33 de 40 medidos.
##
## Ahora hay cadena de suplentes y el último eslabón es "cualquiera que no
## sea el arquero": mientras el equipo tenga a alguien en cancha, el saque
## sale. La preferencia es por quién se para más cerca del círculo.
const ROLES_PARA_SACAR := ["MCO", "DC", "MC", "EXT", "LAT", "DFC"]


static func _quien_saca_del_medio(estado: Dictionary, saca_local: bool) -> int:
	for rol in ROLES_PARA_SACAR:
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if e["equipo_local"] == saca_local and e["rol"] == rol:
				return id
	# Ni uno de los roles conocidos: con tal de que no sea el arquero.
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == saca_local and e["rol"] != "ARQ":
			return id
	return -1


static func _reiniciar_desde_medio(estado: Dictionary, saca_local: bool, mitad: int = 0) -> void:
	var sacador := _quien_saca_del_medio(estado, saca_local)

	# En un saque del medio TODOS tienen que estar en su propia mitad. Las
	# posiciones base de los de arriba (EXT en x=8, DC en x=14) están en
	# campo rival, así que hay que traerlos. Antes se los CLAMPEABA a x=±1,
	# y como el DC y el MCO comparten y=0, terminaban tres o cuatro
	# jugadores amontonados arriba del círculo central: apenas arrancaba el
	# partido ya estaban todos disputando la pelota.
	#
	# Ahora la formación se COMPRIME dentro de la propia mitad en vez de
	# aplastarse contra la línea, que además da la foto correcta de un
	# saque del medio: arquero en su arco, línea de fondo, mediocampo y los
	# de arriba sobre el círculo.
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		var base: Vector2 = e["base"]
		# Se mide la profundidad desde el arco PROPIO y se comprime. No se
		# puede usar el signo de base.x para saber de qué lado va: la base
		# del delantero está en campo rival, así que el signo miente.
		var propio: float = -MEDIO_LARGO if e["equipo_local"] else MEDIO_LARGO
		var hacia: float = 1.0 if e["equipo_local"] else -1.0
		var x: float = propio + hacia * absf(base.x - propio) * COMPRESION_SAQUE
		var p := Vector2(x, base.y)
		# Fuera del círculo central: la pelota la toca UNO solo. Es la
		# regla real y es lo que hace que el saque se lea como un saque.
		#
		# Y se sale del círculo HACIA ATRÁS, nunca hacia adelante. Con la
		# dirección cruda, alguien parado apenas del lado propio de la
		# mitad salía empujado a campo rival: se veía un rival parado en
		# tu campo mientras vos sacabas del medio, que no puede pasar.
		if id != sacador and p.length() < RADIO_CIRCULO + 0.5:
			var atras: float = -1.0 if e["equipo_local"] else 1.0
			var dir: Vector2 = p.normalized() if p.length() > 0.01 else Vector2(atras, 0.0)
			if dir.x * atras < 0.0:
				dir.x = -dir.x
			p = dir * (RADIO_CIRCULO + 0.5)
		# Nadie del lado equivocado de la mitad. La compresión y el empujón
		# del círculo pueden pasarse los dos, y en un saque del medio los
		# 11 que no sacan tienen que estar en su propio campo.
		if id != sacador:
			p.x = minf(p.x, -0.5) if e["equipo_local"] else maxf(p.x, 0.5)
		e["pos"] = p
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		# La marca se resetea a donde quedó parado: si arrastrara la del
		# balón parado anterior, en el saque del medio los 22 arrancarían
		# caminando hacia la última falta en vez de esperar la pelota.
		e["marca"] = p

	estado["pelota"]["pos"] = Vector2.ZERO
	estado["pelota"]["vel"] = Vector2.ZERO
	estado["pelota"]["en_vuelo"] = false
	estado["pelota"]["es_remate"] = false
	estado["pelota"]["altura_max"] = 0.0
	estado["pelota"]["z"] = 0.0
	estado["pelota"]["ticks_con_pelota"] = 0
	estado["pelota"].erase("saliendo")
	# El saque del medio cancela cualquier balón parado pendiente: si un
	# tiempo termina con el juego detenido, el siguiente no puede arrancar
	# esperando una falta que ya no existe.
	estado["detenido"] = 0
	estado["quietos"] = 0
	estado.erase("balon_parado")

	if sacador == -1:
		estado["pelota"]["poseedor_id"] = -1
		return
	estado["jugadores"][sacador]["pos"] = Vector2.ZERO
	estado["jugadores"][sacador]["marca"] = Vector2.ZERO
	estado["pelota"]["poseedor_id"] = sacador
	estado["balon_parado"] = {
		"tipo": "saque_inicial", "saca_local": saca_local, "mitad": mitad,
	}
	estado["detenido"] = int(TICKS_DETENIDO["saque_inicial"])
	estado["quietos"] = int(TICKS_DETENIDO["saque_inicial"])
	estado["corte_este_tick"] = true


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
	_xp_e(estado, poseedor, attr_remate)
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
	var bloqueador := -1 if attr_remate == "cabezazo" else _bloqueador_de_tiro(
		estado, poseedor["pos"], es_local,
		float(pesos()["fisica"]["dist_max_bloqueo_libre"]) if attr_remate == "tiros_libres" else -1.0)
	if bloqueador != -1 and _gana_bloqueo(estado, bloqueador, jugador, eq_a, eq_d, poseedor["pos"], es_local, minuto):
		_accion(estado, bloqueador, ACCION_BARRIDA)
		_xp_e(estado, estado["jugadores"][bloqueador], "barrida")
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
	# La punteria (chance_porteria) mira el valor ABSOLUTO del atributo, asi
	# que con el gradiente por division (NivelDivision) un delantero de
	# primera no erraba nunca. Se normaliza al nivel del partido — solo
	# para esto: el duelo contra el arquero, mas abajo, ya es relativo por
	# construccion y usa remate_efectivo sin tocar.
	var remate_normalizado: float = MatchEngine.relativo_al_nivel(remate_efectivo, _nivel_partido)
	var calidad: float = remate_normalizado / 100.0 * float(r["peso_atributo"]) + geo * float(r["peso_geometria"])
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
	_xp(estado, int(arquero["id"]), not es_local, "reflejos")
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
		var segundos_vuelo: float = maxf(poseedor["pos"].distance_to(arco) / vel_remate, TICK_SEG)
		alcance = _alcance_en(e_arq, segundos_vuelo) + ALCANCE_ESTIRADA

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
		# Se tira SOBRE la línea, no adentro del arco: toma el costado al
		# que va la pelota pero su X se queda en la línea. Con el destino
		# crudo, un remate que termina 1,2 m adentro de la red arrastraba
		# al arquero adentro del arco, tratando de meterse él también.
		datos["destino_arquero"] = Vector2(
			-ARQUERO_X_MIN if arco.x < 0.0 else ARQUERO_X_MIN, destino.y)


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
	estado["quietos"] = int(round(TICKS_DETENIDO["gol"] * FRACCION_QUIETOS))


## Quién le dio el último pase al que acaba de convertir, o -1 si la trajo
## solo (gambeta, rebote, tiro libre que pateó él mismo). Pide que el
## goleador sea EL MISMO que recibió ese pase: si la pelota rebotó y le
## quedó a otro, el pase ya no fue la asistencia del gol.
static func _asistente_de(estado: Dictionary, es_local: bool, clave_goleador: int) -> int:
	var up: Dictionary = estado.get("ultimo_pase", {})
	if up.is_empty():
		return -1
	if bool(up["local"]) != es_local or int(up["a"]) != clave_goleador:
		return -1
	return int(up["de"])


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
			_manotear_al_corner(estado, es_local)
		return

	var gol: bool = tipo == "gol"
	# El penal llega por acá igual que cualquier remate, pero se cuenta
	# como penal: no es un tiro más en las estadísticas.
	var es_penal: bool = bool(datos.get("penal", false))
	estado["eventos"].append({
		"minuto": minuto, "tipo": "penal" if es_penal else "tiro_puerta",
		"equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": datos["rol"], "clave": datos["clave"],
		"resultado": ("gol" if gol else ("atajado" if es_penal else "atajada")),
	})
	var jugador: Dictionary = datos.get("jugador", {})
	var dist: float = float(datos.get("dist", 0.0))
	if gol:
		eq_a.goles += 1
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre,
			"jugador_id": jugador.get("id", -1),
			"asistencia_id": _asistente_de(estado, es_local, int(datos["clave"]))})
		if es_penal:
			estado["log"].append("min %d - PENAL: gol de %s %s (%s)" % [
				minuto, jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre])
		else:
			estado["log"].append("min %d - GOL de %s %s (%s) desde %.0f m" % [
				minuto, jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre, dist])
		_festejar_gol(estado, not es_local)
		return

	if es_penal:
		estado["log"].append("min %d - PENAL: lo ataja el arquero de %s" % [minuto, eq_d.nombre])
	else:
		estado["log"].append("min %d - %s (%s) remata desde %.0f m, ataja el arquero" % [
			minuto, datos["rol"], eq_a.nombre, dist])
	# El arquero no siempre la retiene: si la manotea, sale al córner.
	# Cuanto mejor su agarre, más veces la queda.
	if rng.randf() > float(datos.get("agarre", 0.5)):
		_manotear_al_corner(estado, es_local)
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
		# El saque de arco es una INTERRUPCIÓN, no un pase más: la pelota
		# se pone en el área chica, los rivales salen del área caminando y
		# recién después se juega. Antes se resolvía en un tick y por eso
		# no se entendía de dónde salía la pelota.
		var arq_pos: Vector2 = estado["jugadores"][arquero_clave]["pos"]
		var punto := Vector2(
			-MEDIO_LARGO + 5.5 if arquero_local else MEDIO_LARGO - 5.5,
			clampf(arq_pos.y, -9.0, 9.0))
		_detener_juego(estado, punto, arquero_local, arquero_clave, "corto",
			int(TICKS_DETENIDO["saque_arco"]))
		_marcar_fuera_del_area(estado, arquero_local)
		estado["eventos"].append({
			"minuto": _minuto_int(estado), "tipo": "saque_arco",
			"equipo": _equipo_de(estado, arquero_local).nombre,
			"rival": _equipo_de(estado, not arquero_local).nombre,
			"jugador_posicion": "ARQ", "clave": arquero_clave, "resultado": "saque",
		})
		return

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
## La pelota se va, pero NO se resuelve en el acto: sale volando hasta
## pasar la línea y el saque se cobra cuando llega. Antes el reinicio
## ocurría en el mismo tick en que se decidía que salía, así que nunca se
## veía irse la pelota — aparecía directamente el lateral cobrado.
static func _pelota_fuera(estado: Dictionary, punto: Vector2, toco_local: bool) -> void:
	var pelota: Dictionary = estado["pelota"]
	var desde: Vector2 = pelota["pos"]
	# Un poco más allá de la línea, para que se vea cruzar y no frenar
	# justo encima.
	var salida: Vector2 = punto
	if absf(punto.y) >= MEDIO_ANCHO:
		salida = Vector2(punto.x, punto.y + signf(punto.y) * MARGEN_SALIDA)
	else:
		salida = Vector2(punto.x + signf(punto.x) * MARGEN_SALIDA, punto.y)
	if desde.distance_to(salida) < 0.5:
		_resolver_salida(estado, punto, toco_local)
		return
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["es_pase"] = false
	pelota["es_centro"] = false
	pelota["es_remate"] = false
	pelota["saliendo"] = {"punto": punto, "toco_local": toco_local}
	pelota["origen_pos"] = desde
	pelota["destino_pos"] = salida
	pelota["destino_id"] = -1
	pelota["pasador_local"] = toco_local
	pelota["altura_max"] = 0.8
	pelota["ticks_con_pelota"] = 0
	pelota.erase("pared_a")
	pelota["vel"] = (salida - desde).normalized() 		* maxf(pelota["vel"].length(), float(pesos()["fisica"]["vel_salida_min"]))


## Ya cruzó la línea: se cobra lo que corresponda según por dónde salió y
## quién la tocó último, igual que el reglamento.
static func _resolver_salida(estado: Dictionary, punto: Vector2, toco_local: bool) -> void:
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
	estado["reinicios"]["lateral"] = int(estado["reinicios"].get("lateral", 0)) + 1
	_detener_juego(estado, pos, saca_local, ejecutor, "corto", int(TICKS_DETENIDO["lateral"]))
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "lateral",
		"equipo": _equipo_de(estado, saca_local).nombre,
		"rival": _equipo_de(estado, not saca_local).nombre,
		"jugador_posicion": estado["jugadores"][ejecutor]["rol"], "clave": ejecutor,
		"jugador_id": int(estado["jugadores"][ejecutor]["jugador_id"]),
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
	# El corner se toma con calma: un rato congelado donde salio la pelota,
	# y despues tiempo de sobra para que los que suben lleguen al area y el
	# que lo tira se pare en el banderin. Como el que llega a su marca se
	# queda quieto, ese sobrante son los segundos de "todos ubicados,
	# esperando el centro" — que es lo que faltaba: no se veia quien lo
	# pateaba, la pelota salia de la nada.
	_detener_juego(estado, esquina, ataca_local, ejecutor, "corner",
		_ticks_de_pausa(estado, int(TICKS_DETENIDO["corner"])),
		false, TICKS_CONGELADO_CORNER)
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "corner",
		"equipo": _equipo_de(estado, ataca_local).nombre,
		"rival": _equipo_de(estado, not ataca_local).nombre,
		"jugador_posicion": estado["jugadores"][ejecutor]["rol"], "clave": ejecutor,
		# Quien lo patea, por id y no solo por puesto: es lo que deja
		# comprobar que el corner lo ejecuta el que eligio el club (ver
		# core/roles.gd). El resto de los eventos ya lo traia.
		"jugador_id": int(estado["jugadores"][ejecutor]["jugador_id"]),
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
## `dist_max` se pasa aparte para el tiro libre: la barrera esta a los
## 9,15 reglamentarios, o sea mas lejos del tope de bloqueo del juego
## abierto (6 m). Sin esto la barrera era decorado — se paraba en la
## linea del remate y la pelota le pasaba por el medio siempre.
static func _bloqueador_de_tiro(estado: Dictionary, desde: Vector2, es_local: bool,
		dist_max: float = -1.0) -> int:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(es_local)
	var radio: float = f["radio_bloqueo_tiro"]
	var tope: float = dist_max if dist_max > 0.0 else float(f["dist_max_bloqueo"])
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
		if dist_al_rematador > tope or dist_al_rematador > desde.distance_to(arco):
			continue
		var d := _dist_a_segmento(e["pos"], desde, arco)
		if d < mejor_d:
			mejor_d = d
			mejor = id
	return mejor


## La manotea al córner: la pelota sale POR AL LADO del arco, desviada a
## un costado, no derecho para atrás. Antes esto usaba _desviar_afuera con
## el centro del arco como origen, y como ahí la salida más cercana es la
## propia línea de fondo, la pelota viajaba tres metros hacia atrás
## metiéndose en la red — se veía quedar en las manos del arquero y de
## golpe se cobraba un córner que nunca se vio salir.
static func _manotear_al_corner(estado: Dictionary, es_local_ataca: bool) -> void:
	var rng: RandomNumberGenerator = estado["rng"]
	var arco := arco_rival(es_local_ataca)
	var lado: float = 1.0 if rng.randf() < 0.5 else -1.0
	var y: float = (ARCO_MEDIO_ANCHO + 1.0 + rng.randf() * 4.0) * lado
	_pelota_fuera(estado, Vector2(arco.x, y), not es_local_ataca)


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
## Marca a los rivales fuera del área para el saque de arco, como manda
## la regla. Es la versión "caminando" de _despejar_area: en vez de
## teletransportarlos, se les cambia la marca y salen durante la pausa.
static func _marcar_fuera_del_area(estado: Dictionary, arquero_local: bool) -> void:
	var borde_x: float = -MEDIO_LARGO + AREA_LARGO if arquero_local else MEDIO_LARGO - AREA_LARGO
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == arquero_local:
			continue
		var m: Vector2 = e.get("marca", e["pos"])
		var dentro: bool = (m.x < borde_x) if arquero_local else (m.x > borde_x)
		if dentro and absf(m.y) < AREA_MEDIO_ANCHO:
			e["marca"] = Vector2(borde_x + (2.0 if arquero_local else -2.0), m.y)


static func _despejar_area(estado: Dictionary, arquero_local: bool) -> void:
	var borde_x: float = -MEDIO_LARGO + AREA_LARGO if arquero_local else MEDIO_LARGO - AREA_LARGO
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == arquero_local:
			continue
		var dentro: bool = (e["pos"].x < borde_x) if arquero_local else (e["pos"].x > borde_x)
		if dentro and absf(e["pos"].y) < AREA_MEDIO_ANCHO:
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
	# Se separan porque son jugadas distintas: el pelotazo es a propósito
	# largo (lo manda `fuerza`) y mezclarlo con el pase normal escondía
	# cuánto se estaba pasando de largo en el juego asociado.
	var _d: float = poseedor["pos"].distance_to(objetivo)
	if es_pelotazo:
		estado["dist_pelotazos"].append(_d)
	else:
		estado["dist_pases"].append(_d)
	_accion(estado, int(poseedor["clave"]), ACCION_PATEA)
	# §7.3: pasar entrena `pases`; reventarla, `fuerza`. El centro suma
	# `centros` cuando se marca como tal, un tick después de esto.
	_xp_e(estado, poseedor, "fuerza" if es_pelotazo else "pases")
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
		# Los primeros ticks NADIE se mueve: suena el silbato y el juego
		# se corta en seco. Sin esta pausa dentro de la pausa, el momento
		# en que para el juego no se lee — la jugada sigue fluyendo hacia
		# otro lado y parece que nunca hubo interrupción.
		if int(estado.get("quietos", 0)) > 0:
			estado["quietos"] = int(estado["quietos"]) - 1
			for id in estado["jugadores"]:
				estado["jugadores"][id]["vel"] = Vector2.ZERO
				estado["jugadores"][id]["rapidez"] = 0.0
			if int(estado["quietos"]) == 0:
				# Se terminó de ver dónde quedó: se acomoda la pelota en el
				# punto y cada uno aparece en su marca.
				# Solo si hay balon parado de verdad. El gol y el saque inicial
				# tambien paran el juego, pero se ubican solos y NO pasan por
				# _marcar_posiciones: ahi `marca` es la del corner anterior y
				# ubicar por ella los mandaria a todos al area equivocada.
				var bp_pos: Dictionary = estado.get("balon_parado", {})
				if bp_pos.has("pos"):
					pelota["pos"] = bp_pos["pos"]
					_ubicar_para_el_balon_parado(estado)
		else:
			var ejecutor_bp: int = int(estado.get("balon_parado", {}).get("ejecutor", -1))
			# El expulsado no se acomoda para el saque: se esta yendo. Sin
			# esto lo movian los dos —este bucle hacia su marca y la
			# caminata hacia el lateral— y quedaba forcejeando en el medio
			# sin llegar nunca a salir.
			for id in estado["jugadores"]:
				if _en_transito(estado, id):
					continue
				var e_p: Dictionary = estado["jugadores"][id]
				# El que va a ejecutar no se "acomoda": va a BUSCAR la
				# pelota, y va corriendo. Con el trote de los demas no
				# llegaba —medido, se quedaba a 12 m del banderin— y
				# terminaba apareciendo encima de la pelota al momento
				# del centro. Por eso no se veia quien pateaba.
				var factor: float = FACTOR_CORRE_A_LA_PELOTA if id == ejecutor_bp 					else FACTOR_TROTE_PARADO
				_mover_hacia(e_p, e_p.get("marca", e_p["pos"]), factor)
		# El que sale camina hacia afuera y el que entra trota a su lugar;
		# el saque espera a que terminen.
		if not _avanzar_entradas_y_salidas(estado):
			estado["detenido"] = maxi(int(estado["detenido"]), 1)
		if int(estado["detenido"]) == 0:
			_ejecutar_balon_parado(estado)
			# Mismo motivo que en el paso 2: si el reinicio fue un pase,
			# la pelota arranca en este fotograma y no en el siguiente.
			if pelota["en_vuelo"]:
				_avanzar_pelota(estado)
		_cerrar_tick(estado, con_fotogramas, eventos_antes)
		return

	# 1. Pelota en vuelo: avanza, y alguien puede controlarla o interceptarla.
	if pelota["en_vuelo"]:
		_avanzar_pelota(estado)
	# 2. Con poseedor: decide y ejecuta.
	elif pelota["poseedor_id"] != -1:
		_decidir_y_ejecutar(estado)
		# Si la decisión la puso en movimiento, la pelota arranca YA. Sin
		# esto perdía un tick entero: el pase salía, la pelota se quedaba
		# clavada donde estaba, el que la pateó se movía —porque al soltarla
		# deja de ser el poseedor y el paso 3 ya no lo saltea— y recién al
		# tick siguiente la pelota empezaba a viajar. Se veía como si la
		# pelota saliera sola y tarde.
		if pelota["en_vuelo"]:
			_avanzar_pelota(estado)

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
		# El que camina hacia el lateral —expulsado o cambiado— ya lo
		# mueve _avanzar_entradas_y_salidas, y el que entra tambien. Si
		# ademas lo acomoda la formacion, las dos fuerzas se pelean: la
		# formacion lo tira hacia la pelota y la salida hacia la linea, y
		# el que sale no llega nunca. Se agoto el tope TICKS_MAX_SALIENDO
		# y se lo borro igual de la cancha con la pelota en los pies, que
		# dejaba `poseedor_id` apuntando a un jugador que ya no existe.
		if _en_transito(estado, id):
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
			_mover_hacia(e, _punto_de_presion(estado, e, pelota["pos"]))
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
	# Minutos en cancha (§7.3). Va acá y no en el cuerpo del tick porque
	# el juego detenido también es tiempo jugado: contando solo los ticks
	# "vivos", un titular sumaba 0,80 de partido contra el 1,00 que da el
	# motor abstracto, o sea que el equipo del usuario crecía 20% más
	# lento que el resto de la liga.
	for id_m in estado["jugadores"]:
		var e_m: Dictionary = estado["jugadores"][id_m]
		var k_m: String = "%s_%d" % ["h" if e_m["equipo_local"] else "a", int(e_m["jugador_id"])]
		var reg: Dictionary = estado["ticks_en_cancha"].get(k_m,
			{"t": 0, "rol": e_m["rol"], "id": int(e_m["jugador_id"]), "local": bool(e_m["equipo_local"])})
		reg["t"] = int(reg["t"]) + 1
		estado["ticks_en_cancha"][k_m] = reg

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
	estado["corte_este_tick"] = false


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

	# Ídem para la pelota que se está yendo afuera: nadie la corta, se la
	# deja salir y el saque se cobra cuando cruzó.
	if pelota.has("saliendo"):
		if llego:
			var datos_salida: Dictionary = pelota["saliendo"]
			pelota.erase("saliendo")
			pelota["altura_max"] = 0.0
			pelota["z"] = 0.0
			_resolver_salida(estado, datos_salida["punto"], bool(datos_salida["toco_local"]))
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
## ¿Esta clave todavia esta caminando hacia afuera?
static func _sigue_saliendo(estado: Dictionary, clave: int) -> bool:
	if clave < 0:
		return false
	for s in estado.get("saliendo", []):
		if int(s["clave"]) == clave:
			return true
	return false


## Un paso de las salidas y las entradas. Devuelve true cuando no queda
## nadie en el medio — que es la condicion para reanudar el juego.
##
## El que sale camina hasta el lateral y recien ahi se lo saca de los 22:
## sacarlo antes es lo que hacia que los cambios y las expulsiones fueran
## un jugador que desaparece de un fotograma al otro. El que entra aparece
## en ese mismo punto del lateral y trota hasta el lugar que dejo libre el
## que salio.
static func _avanzar_entradas_y_salidas(estado: Dictionary) -> bool:
	var siguen := []
	for s in estado["saliendo"]:
		var clave: int = int(s["clave"])
		if not estado["jugadores"].has(clave):
			continue
		s["ticks"] = int(s["ticks"]) + 1
		var e: Dictionary = estado["jugadores"][clave]
		var destino: Vector2 = s["destino"]
		var paso: float = FACTOR_CAMINA_EXPULSADO if bool(s.get("expulsado", false)) 			else FACTOR_SALE_CAMBIADO
		_mover_hacia(e, destino, paso)
		if e["pos"].distance_to(destino) > 0.5 and int(s["ticks"]) < TICKS_MAX_SALIENDO:
			siguen.append(s)
			continue
		# Salio: recien ahora deja de estar en la cancha. Si se va con la
		# pelota —pasa cuando se agota TICKS_MAX_SALIENDO y se lo saca
		# donde este— hay que soltarla antes de borrarlo: `poseedor_id`
		# apuntando a una clave que ya no existe rompe el tick siguiente.
		if int(estado["pelota"]["poseedor_id"]) == clave:
			_dar_pelota_al_arquero(estado, not bool(e["equipo_local"]))
		estado["jugadores"].erase(clave)
	estado["saliendo"] = siguen

	var entrando := []
	for en in estado["entrando"]:
		var clave_e: int = int(en["clave"])
		if not estado["jugadores"].has(clave_e):
			continue
		# No entra hasta que el que sale llegue a la linea: dos jugadores
		# de un equipo no pueden estar en la cancha a la vez, y ademas es
		# lo que se ve en un partido — el cuarto arbitro no lo deja pasar
		# hasta que el otro salio.
		if _sigue_saliendo(estado, int(en.get("espera_a", -1))):
			entrando.append(en)
			continue
		en["ticks"] = int(en["ticks"]) + 1
		var e2: Dictionary = estado["jugadores"][clave_e]
		var destino_e: Vector2 = en["destino"]
		_mover_hacia(e2, destino_e, FACTOR_ENTRA_SUPLENTE)
		if e2["pos"].distance_to(destino_e) > 1.5 and int(en["ticks"]) < TICKS_MAX_SALIENDO:
			entrando.append(en)
	estado["entrando"] = entrando

	return estado["saliendo"].is_empty() and estado["entrando"].is_empty()


## Pone la cancha al dia con quien tiene que estar jugando: saca a los
## que salieron (expulsados o cambiados) y mete a los que entraron.
##
## No teletransporta: al que sale lo manda a caminar hacia el lateral y al
## que entra lo pone en ese mismo punto para que trote a su lugar. El
## juego espera a que terminen (ver _avanzar_entradas_y_salidas).
static func _sincronizar_cambios(estado: Dictionary) -> void:
	for es_local in [true, false]:
		var equipo := _equipo_de(estado, es_local)
		var deben_estar := {}
		for j in equipo.jugadores_en_cancha():
			if equipo.expulsados_partido.has(j["id"]):
				continue
			deben_estar[clave_de(j["id"], es_local)] = j

		var libres := []  # los lugares que dejan los que se van
		for clave in estado["jugadores"].keys():
			var e: Dictionary = estado["jugadores"][clave]
			if e["equipo_local"] != es_local:
				continue
			if _en_transito(estado, clave):
				continue
			if not deben_estar.has(clave):
				# El que entra hereda el SLOT del que sale (rol y
				# casillero), no el de su propio puesto: un cambio ocupa
				# el lugar que se libera, no inventa uno nuevo.
				libres.append({
					"pos": e["pos"], "rol": e["rol"], "base": e["base"],
					# Quien deja el hueco: el suplente lo espera en la
					# linea antes de entrar.
					"deja": clave,
				})
				_empezar_salida(estado, clave)

		for clave in deben_estar:
			if estado["jugadores"].has(clave):
				continue
			var j: Dictionary = deben_estar[clave]
			var hueco: Dictionary = libres.pop_back() if not libres.is_empty() else {}
			var rol: String = str(hueco["rol"]) if hueco.has("rol") else str(j["posicion"])
			var base: Vector2 = hueco["base"] if hueco.has("base") else Vector2.ZERO
			if not hueco.has("base"):
				var s_def: Array = BASE_FORMACION.get(rol, BASE_FORMACION["MC"])
				base = s_def[0]
				if not es_local:
					base = Vector2(-base.x, base.y)
			# Adonde va: al lugar que dejo el que salio. Y de donde sale:
			# del lateral, como en el futbol.
			var destino: Vector2 = hueco["pos"] if hueco.has("pos") else base
			var entra_por := _punto_de_salida(destino)
			estado["jugadores"][clave] = {
				"clave": clave, "jugador_id": j["id"], "equipo_local": es_local,
				"rol": rol, "base": base, "pos": entra_por, "vel": Vector2.ZERO,
				"objetivo": base, "vel_max": _vel_max(j),
				"aceleracion": _aceleracion(j), "rapidez": 0.0,
			}
			estado["entrando"].append({
				"clave": clave, "destino": destino, "ticks": 0,
				"espera_a": int(hueco["deja"]) if hueco.has("deja") else -1,
			})

	# Si arranco alguna salida o entrada, el juego se DETIENE: en el
	# futbol un cambio se hace con la pelota parada, y ademas es lo que
	# hace que se vea. Sin esto los que estan en transito quedan quietos
	# —el bucle normal no los mueve— mientras el partido sigue de largo.
	if not (estado["saliendo"].is_empty() and estado["entrando"].is_empty()):
		estado["detenido"] = maxi(int(estado.get("detenido", 0)), 1)


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
	_xp_e(estado, estado["jugadores"][clave_def], "inteligencia")
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
	# §7.4.6: el pase va a alguien concreto, y la pelota ya lo sabe. Es el
	# unico lugar del motor espacial donde hay una dupla de verdad.
	var destino_clave: int = int(estado["pelota"].get("destino_id", -1))
	var companero_id := -1
	if destino_clave != -1 and estado["jugadores"].has(destino_clave):
		var e_dest: Dictionary = estado["jugadores"][destino_clave]
		# Solo si el destino es un COMPAÑERO. Un centro al area o un
		# pelotazo pueden tener como destino a un rival, y ahi no hay
		# dupla que valga.
		if bool(e_dest["equipo_local"]) == pasador_local:
			companero_id = int(e_dest["jugador_id"])
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_pas, eq_def, pasador, "pases", minuto, estado["rng"], companero_id),
		MatchEngine._bloques_equipo(eq_def, eq_pas, defensor, "quite", minuto, estado["rng"]))
	# gana_atacante = el pase pasa. Si el atacante pierde, hay intercepción.
	return not Duel.gana_atacante(res, estado["rng"])


static func _entregar_pelota(estado: Dictionary, clave: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	# Quién se la dio a quién: es todo lo que hace falta para saber si el
	# gol que venga después tuvo asistencia. Se anota al RECIBIRLA y no al
	# patearla, porque un pase que interceptan no le asiste a nadie. Vale
	# igual para el centro cabeceado: el centro también entra por acá.
	var receptor: Dictionary = estado["jugadores"][clave]
	if bool(pelota.get("es_pase", false)) \
			and bool(pelota.get("pasador_local", false)) == bool(receptor["equipo_local"]) \
			and int(pelota.get("pasador_id", -1)) != int(receptor["jugador_id"]):
		estado["ultimo_pase"] = {
			"de": int(pelota["pasador_id"]), "a": clave,
			"local": bool(receptor["equipo_local"]),
		}
	else:
		estado["ultimo_pase"] = {}
	pelota["poseedor_id"] = clave
	pelota["en_vuelo"] = false
	pelota["vel"] = Vector2.ZERO
	pelota["pos"] = estado["jugadores"][clave]["pos"]
	pelota["ticks_con_pelota"] = 0


## Quiénes del equipo que NO tiene la pelota salen a presionarla: los dos
## más cercanos, salvo el arquero (que no abandona el arco a perseguir).
## Con uno solo, el que conduce se lo saca de encima y sigue de largo.
## Adónde va el que sale a presionar. Normalmente a la pelota, pero si la
## tiene el ARQUERO adentro de su área, se planta en el borde del área en
## vez de meterse a buscarla: nadie va a apretar a un arquero que tiene la
## pelota en las manos dentro del área, y verlos entrar en manada al saque
## de arco era de las cosas que más cantaban que esto era una simulación.
static func _punto_de_presion(estado: Dictionary, e: Dictionary, pelota_pos: Vector2) -> Vector2:
	var poseedor_id: int = int(estado["pelota"]["poseedor_id"])
	if poseedor_id == -1:
		return pelota_pos
	var poseedor: Dictionary = estado["jugadores"][poseedor_id]
	if poseedor["rol"] != "ARQ" or not _en_el_area(pelota_pos, not bool(poseedor["equipo_local"])):
		return pelota_pos
	# Borde del área grande del arquero, a la altura de la pelota.
	var borde_x: float = -MEDIO_LARGO + AREA_LARGO if poseedor["equipo_local"] else MEDIO_LARGO - AREA_LARGO
	var fuera: float = borde_x + (2.0 if poseedor["equipo_local"] else -2.0)
	return Vector2(fuera, clampf(pelota_pos.y, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0))


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
		# El arquero no sale conduciendo mientras piensa: se queda con la
		# pelota. Quitarle "conducir" de las opciones no alcanzaba, porque
		# este atajo lo hace avanzar igual en todos los ticks en que no
		# decide — y así se lo veía salir caminando del área.
		if poseedor["rol"] != "ARQ":
			_conducir(estado, poseedor)
		return

	var opciones := evaluar_opciones(estado, poseedor, jugador)
	if opciones.is_empty():
		# Sin opciones y sin poder conducir, el arquero se quedaría con la
		# pelota para siempre: la revienta, que es lo que hace cualquier
		# arquero sin salida.
		if poseedor["rol"] == "ARQ":
			_despejar(estado, poseedor, jugador)
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
			# El centro se lanza como pase, así que el XP de `pases` ya se
			# sumó; se corrige acá, que es donde se sabe que era centro.
			_xp_e(estado, poseedor, "pases", -1.0)
			_xp_e(estado, poseedor, "centros")
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


## Cuántas veces se tira la tarjeta en ESTA infracción. NO es una
## constante: el presupuesto de tiradas se acumula con el TIEMPO y cada
## infracción se lleva lo acumulado desde la anterior.
##
## El problema que resuelve: CHANCE_AMARILLA está calibrado sobre los
## ~180 duelos por partido del motor abstracto, y este motor resuelve
## muchos menos, así que cada infracción tiene que tirar varias veces para
## llegar a la misma tasa POR PARTIDO — que es lo que importa, porque de
## ahí salen las suspensiones. Con una constante, CADA cambio que movía
## cuántas infracciones hay —el tiempo muerto del balón parado, la
## aceleración, la presión al arquero— desajustaba las tarjetas y había
## que recalibrarla a mano. Pasó tres veces seguidas.
##
## Acumular por tiempo lo vuelve invariante: el total esperado es
## `tiradas_por_tick × ticks del partido` sin importar CUÁNTAS
## infracciones haya. Si hay menos, cada una carga con más presupuesto.
## En términos de fútbol también se sostiene: en un partido cortado, cada
## falta pesa más.
##
## Se acota por arriba para que una sequía larga no convierta a la
## siguiente falta en una amarilla automática.
static func _chequeos_tarjeta(estado: Dictionary) -> int:
	var f: Dictionary = pesos()["fisica"]
	var transcurridos: int = maxi(int(estado["tick"]) - int(estado.get("tick_ultima_tarjeta", 0)), 1)
	estado["tick_ultima_tarjeta"] = int(estado["tick"])
	var tiradas: float = float(f["tiradas_tarjeta_por_partido"]) 		/ float(TICKS_POR_MITAD * 2) * float(transcurridos)
	return clampi(int(round(tiradas)), 1, int(f["tiradas_tarjeta_tope"]))


## Hay que CORTAR en la primera tarjeta: si no, el mismo jugador puede
## sacar dos amarillas en la misma entrada y quedar expulsado en el acto,
## que no existe en el fútbol. Con las tiradas encadenadas sin corte
## salían 1,10 rojas por partido contra las ~0,4 del motor abstracto.
##
## Y las tiradas se reparten por TODO el equipo, no todas sobre el que
## acaba de hacer la falta. El presupuesto representa las infracciones
## que este motor no simula —hay 10 faltas por partido contra las 22 de
## un partido real— y esas las cometieron otros. Cargándolas todas al
## mismo jugador, las amarillas se concentraban en poca gente y salían
## 0,88 rojas por partido, con expulsado en 2 de cada 3 partidos, contra
## 0,43 del motor abstracto y 0,25 reales. Casi todas por doble amarilla.
## Medido con tests/_diag_faltas.gd.
##
## La primera tirada sí es para el infractor: esa falta la hizo él y se
## vio. Las demás son para cualquiera de sus compañeros en cancha.
static func _chequear_tarjeta_repetido(estado: Dictionary, defensor: Dictionary,
		eq_d: Team, eq_a: Team, minuto: int) -> void:
	var veces := _chequeos_tarjeta(estado)
	var en_cancha := eq_d.jugadores_en_cancha()
	for i in range(veces):
		var quien := defensor
		if i > 0 and not en_cancha.is_empty():
			var candidato: Dictionary = en_cancha[estado["rng"].randi() % en_cancha.size()]
			if str(candidato.get("posicion", "")) != "ARQ":
				quien = candidato
		var antes: int = estado["eventos"].size()
		MatchEngine._chequear_tarjeta(quien, eq_d, eq_a, estado["rng"], estado["eventos"], minuto, true, estado["log"])
		if estado["eventos"].size() > antes:
			# Si fue roja, se lo saca de la cancha AHORA. La limpieza
			# periodica corre cada 20 ticks (5 segundos de juego) y la roja
			# puede caer en cualquiera de ellos, asi que el expulsado
			# seguia corriendo y disputando la pelota hasta la limpieza
			# siguiente: medido, 11 de 14 expulsados seguian jugando 2,4
			# segundos de promedio y hasta 3,5. Se ve, porque el partido se
			# dibuja.
			if eq_d.expulsados_partido.has(int(quien["id"])):
				_mandar_a_las_duchas(estado, int(quien["id"]), eq_d == _equipo_de(estado, true))
			return  # ya cobró: una entrada, una tarjeta


## Arranca la salida del expulsado: se queda en la cancha caminando hacia
## el lateral y el juego no se reanuda hasta que sale.
##
## Va al lateral MAS CERCANO, a la altura de la mitad de la cancha, que es
## por donde sale un expulsado de verdad. Un par de metros pasada la linea
## para que se lo vea salir y no quedar pisandola.
static func _mandar_a_las_duchas(estado: Dictionary, jugador_id: int, es_local: bool) -> void:
	_empezar_salida(estado, clave_de(jugador_id, es_local), true)


## Pone a alguien a caminar hacia afuera. Lo usan la expulsion y el cambio:
## en los dos casos el que se va sale por el lateral y el juego lo espera.
static func _empezar_salida(estado: Dictionary, clave: int, expulsado: bool = false) -> void:
	if not estado["jugadores"].has(clave):
		return
	for s in estado["saliendo"]:
		if int(s["clave"]) == clave:
			return
	if int(estado["pelota"]["poseedor_id"]) == clave:
		_dar_pelota_al_arquero(estado, not bool(estado["jugadores"][clave]["equipo_local"]))
	estado["saliendo"].append({
		"clave": clave,
		"destino": _punto_de_salida(estado["jugadores"][clave]["pos"]),
		"ticks": 0,
		"expulsado": expulsado,
	})


## ¿Esta clave esta yendose o entrando? Los que estan en el medio de eso
## no se acomodan para el saque ni los toca el barrido de cambios.
static func _en_transito(estado: Dictionary, clave: int) -> bool:
	for s in estado.get("saliendo", []):
		if int(s["clave"]) == clave:
			return true
	for e in estado.get("entrando", []):
		if int(e["clave"]) == clave:
			return true
	return false


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

	# ¿Adentro del área que defiende el infractor? Penal. El área es la
	# misma que mira _en_el_area — el arco que ataca la victima ES el que
	# defiende el infractor— y antes estaba escrita a mano con sus dos
	# medidas repetidas, que es justo lo que AREA_LARGO y AREA_MEDIO_ANCHO
	# existen para evitar.
	if _en_el_area(punto, victima_local):
		_cobrar_penal(estado, victima_local, minuto)
		return
	_tiro_libre(estado, punto, victima_local, minuto)


## Cobra el penal: PARA el juego y acomoda la cancha. No lo ejecuta.
##
## Antes se resolvia en el mismo tick en que se cobraba, asi que en la
## cancha se veia la falta y la pelota adentro del arco sin nada en el
## medio: ni corte, ni jugadores saliendo del area, ni el pateador
## tomandose su tiempo. Un penal es la jugada mas detenida que hay y se
## veia como la mas rapida.
##
## La ejecucion vive en _ejecutar_penal, que la llama _ejecutar_balon_parado
## cuando se termina la pausa — el mismo camino que la falta y el corner.
static func _cobrar_penal(estado: Dictionary, ataca_local: bool, minuto: int) -> void:
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	estado["penales"] = int(estado.get("penales", 0)) + 1

	# Lo patea el que eligio el club (Equipo > Roles). Si no eligio a
	# nadie, o si el elegido no esta en la cancha, lo patea el de mas
	# `tiro` DE CAMPO: antes el automatico recorria los once y el arquero
	# entraba en la comparacion, asi que si tenia el mejor `tiro` se iba
	# caminando hasta el punto del penal.
	var pateador := _dict_jugador(
		estado, eq_a, Roles.ejecutor(eq_a, Roles.PENALES, eq_a.en_cancha))
	var arquero := eq_d.arquero()
	if pateador.is_empty() or arquero.is_empty():
		_dar_pelota_al_arquero(estado, not ataca_local, true)
		return

	var arco := arco_rival(ataca_local)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var punto := Vector2(arco.x + hacia * DIST_PENAL, 0.0)
	var clave_pat := clave_de(int(pateador["id"]), ataca_local)
	var clave_arq := clave_de(int(arquero["id"]), not ataca_local)

	# Todos afuera del area salvo el pateador y el arquero. Es la regla y
	# es lo que hace que la foto se lea como un penal.
	var borde_x: float = arco.x + hacia * AREA_LARGO
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		if id == clave_pat:
			# Unos metros DETRAS de la pelota: el pateador toma carrera.
			# `hacia` apunta del arco hacia el medio, asi que SUMARLO es
			# alejarse del arco. Restarlo lo dejaba entre la pelota y el
			# arco, o sea de espaldas, pateando para el otro lado.
			e["pos"] = punto + Vector2(hacia * 3.0, 0.0)
			e["marca"] = e["pos"]
			continue
		if id == clave_arq:
			e["pos"] = Vector2(arco.x - hacia * 0.2, 0.0)
			e["marca"] = e["pos"]
			continue
		# Si esta adentro del area, se va al borde por el camino mas corto,
		# repartidos en abanico para que no queden todos en el mismo punto.
		var p: Vector2 = e["pos"]
		if absf(arco.x - p.x) <= AREA_LARGO and absf(p.y) <= AREA_MEDIO_ANCHO:
			# `hacia` apunta del arco hacia el medio, asi que SUMARLO es
			# alejarse del arco. Restarlo los metia mas adentro del area,
			# que es lo contrario de sacarlos.
			p.x = borde_x + hacia * estado["rng"].randf_range(0.5, 4.0)
			p.y = clampf(p.y + estado["rng"].randf_range(-6.0, 6.0),
				-MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0)
		e["pos"] = p
		e["marca"] = p

	var pelota: Dictionary = estado["pelota"]
	pelota["pos"] = punto
	pelota["vel"] = Vector2.ZERO
	pelota["en_vuelo"] = false
	pelota["es_remate"] = false
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota["poseedor_id"] = -1
	pelota["ticks_con_pelota"] = 0

	estado["balon_parado"] = {
		"tipo": "penal", "ataca_local": ataca_local, "minuto": minuto,
		"pateador_id": int(pateador["id"]), "pos": punto,
	}
	estado["detenido"] = int(TICKS_DETENIDO["penal"])
	estado["quietos"] = int(TICKS_DETENIDO["penal"])
	estado["corte_este_tick"] = true


## Ejecuta el penal ya cobrado: el duelo de siempre con una ventaja
## grande para el pateador, que es lo que es un penal.
static func _ejecutar_penal(estado: Dictionary, bp: Dictionary) -> void:
	var f: Dictionary = pesos()["fisica"]
	var ataca_local: bool = bool(bp["ataca_local"])
	var minuto: int = int(bp["minuto"])
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	var pateador := _dict_jugador(estado, eq_a, int(bp["pateador_id"]))
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

	# El resultado ya esta decidido, pero el remate VIAJA como cualquier
	# otro: la pelota sale del punto, tarda en llegar y el arquero se tira
	# mientras vuela. Antes se aplicaba en el mismo tick en que se pateaba,
	# asi que del corte se pasaba a la pelota adentro del arco sin ver ni
	# el disparo ni la atajada — justo lo unico que se venia a mirar.
	var clave_pat := clave_de(int(pateador["id"]), ataca_local)
	var punto: Vector2 = bp["pos"]
	var arco := arco_rival(ataca_local)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	# Se acerca a la pelota para pegarle: venia esperando 3 m atras.
	if estado["jugadores"].has(clave_pat):
		estado["jugadores"][clave_pat]["pos"] = punto + Vector2(hacia * 0.8, 0.0)
	_accion(estado, clave_pat, ACCION_PATEA)
	_lanzar_remate(estado,
		{"pos": punto, "clave": clave_pat, "rol": str(pateador["posicion"])},
		{
			"tipo": "gol" if gol else "atajada", "penal": true,
			"es_local": ataca_local, "clave": clave_pat,
			"rol": str(pateador["posicion"]), "jugador": pateador,
			"agarre": float(arquero["atributos"]["agarre"]) / 100.0,
			"dist": DIST_PENAL,
		})


## Tiro libre: la pone el mejor ejecutante disponible, los rivales se
## alejan la distancia reglamentaria, y si está a tiro de arco se remata
## con `tiros_libres` — otro atributo del GDD que no leía nadie. Si está
## lejos o muy escorado, se cuelga al área.
## En que se convierte una falta a favor: remate al arco (`directo`),
## pelota colgada al area (`centro`) o juego corto (`corto`). De esto
## cuelga todo lo demas — quien la patea, quien sube al area y quien arma
## la barrera.
##
## Es publica y esta separada de _tiro_libre porque la mide
## tests/_diag_tipos_libre.gd. Antes ese diagnostico repetia la
## clasificacion a mano y quedaba desactualizado en cada cambio: es la
## regla de una sola fuente de verdad.
static func tipo_de_falta(estado: Dictionary, pos: Vector2, ataca_local: bool) -> String:
	var f: Dictionary = pesos()["fisica"]
	var d_arco: float = pos.distance_to(arco_rival(ataca_local))

	# Le pega al arco si el ANGULO da y ademas le da la pierna desde ahi.
	# Son dos preguntas distintas y por eso se miden por separado: el
	# angulo con factor_angulo —de una falta escorada nadie patea, por
	# cerca que este— y la distancia con `tiros_libres` del pateador (ver
	# _alcance_de_tiro_libre). Mas lejos de su alcance no lo intenta: la
	# cuelga, que es lo que hace el que sabe que no llega.
	var alcance := _alcance_de_tiro_libre(estado, pos, ataca_local)
	var angulo_da: bool = factor_angulo(pos, ataca_local) >= float(f["angulo_minimo_tiro_libre"])
	if alcance >= 0.0 and d_arco <= alcance and angulo_da:
		return "directo"

	if d_arco <= float(f["dist_libre_al_area"]):
		return "centro"

	# LA FALTA LEJANA, SEGUN EL ESTILO. Un Juego directo o un Fisico la
	# cuelgan al area desde cuarenta y cinco metros; un Tiki taka la juega
	# corta. Antes TODAS se jugaban cortas y no subia nadie: medido con
	# tests/_diag_falta_lejana.gd, de las 4,2 faltas por partido y por
	# equipo, 1,4 caian en la banda de 38 a 50 m y el motor las ejecutaba
	# tocandosela al companero mas cercano.
	var cuelga_lejos: bool = d_arco <= float(f["dist_para_colgar_lejos"])
	cuelga_lejos = cuelga_lejos and Estilos.cuelga_de_lejos(_equipo_de(estado, ataca_local).estilo)
	if cuelga_lejos:
		return "centro"

	return "corto"


## Hasta que distancia del arco se ANIMA a patear una falta el que la va
## a patear. Devuelve -1 si no hay nadie que pueda ejecutarla.
##
## Lo decide `tiros_libres`, que hasta ahora no entraba en la decision:
## el tipo de falta salia de factor_geometria con el rango medio fijo, o
## sea que un pateador de 99 y uno de 1 le pegaban desde exactamente la
## misma distancia. Medido antes del cambio (tests/_diag_rango_libre.gd):
## todos los directos salian de 22,4 m de media con un maximo de 24,1 m,
## sin importar quien pateaba.
##
## Los dos extremos salen de `rango_libre_malo` y `rango_libre_bueno`, y
## son RADIOS desde el centro del arco, no profundidades desde la linea de
## fondo. La diferencia importa: el piso vale 16,5 —el mismo numero que la
## profundidad del area— pero NO significa "el borde del area". En el
## vertice del area la distancia al centro del arco es 26,1 m, asi que una
## falta pegada al borde lateral queda muy por fuera de ese radio. Lo que
## define el piso es un semicirculo central justo afuera del area, que es
## de donde patea de verdad un ejecutante limitado. Por eso el valor no se
## deriva de AREA_LARGO aunque coincida: son dos medidas distintas que hoy
## dan el mismo numero, y atarlas haria que mover una moviera la otra.
##
## Se leen ABSOLUTOS —mezcla 1.0— por el mismo
## motivo que el alcance del pase y del pelotazo: hasta donde llega una
## patada es fisico y no depende de contra quien juegues. Normalizado al
## nivel del partido, un pateador de decima le pegaria desde tan lejos
## como uno de primera.
static func _alcance_de_tiro_libre(estado: Dictionary, pos: Vector2, ataca_local: bool) -> float:
	var pateador := _elegir_ejecutor(estado, pos, ataca_local, "directo")
	if pateador == -1 or not estado["jugadores"].has(pateador):
		return -1.0
	var equipo := _equipo_de(estado, ataca_local)
	var j := _dict_jugador(estado, equipo, estado["jugadores"][pateador]["jugador_id"])
	if j.is_empty():
		return -1.0
	var f: Dictionary = pesos()["fisica"]
	return _por_atributo(j, "tiros_libres", float(f["rango_libre_malo"]),
		float(f["rango_libre_bueno"]), 1.0)


static func _tiro_libre(estado: Dictionary, punto: Vector2, ataca_local: bool, _minuto: int) -> void:
	var pos := Vector2(
		clampf(punto.x, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0),
		clampf(punto.y, -MEDIO_ANCHO + 2.0, MEDIO_ANCHO - 2.0))

	# Qué clase de tiro libre es lo decide DÓNDE fue la falta, y eso es lo
	# que después decide quién sube al área y quién se queda.
	var tipo := tipo_de_falta(estado, pos, ataca_local)

	var ejecutor := _elegir_ejecutor(estado, pos, ataca_local, tipo)
	if ejecutor == -1:
		_dar_pelota_al_arquero(estado, ataca_local, true)
		return
	# La falta se congela DONDE PASO y despues se acomodan trotando.
	_detener_juego(estado, pos, ataca_local, ejecutor, tipo,
		_ticks_de_pausa(estado, int(TICKS_DETENIDO["falta"])),
		false, TICKS_CONGELADO_FALTA)


## La pausa de un balon parado: la de siempre, salvo que haya que esperar
## a que el pateador designado llegue trotando. Deja marcado que se esta
## esperando para que esos ticks no se cobren como tiempo de juego.
static func _ticks_de_pausa(estado: Dictionary, base: int) -> int:
	var espera: int = int(estado.get("ticks_espera_ejecutor", 0))
	estado["ticks_espera_ejecutor"] = 0
	if espera <= base:
		estado["esperando_ejecutor"] = 0
		return base
	# Solo lo que EXCEDE la pausa normal es tiempo regalado: la pausa de
	# siempre ya estaba contada en el reloj.
	estado["esperando_ejecutor"] = espera - base
	return espera


## Quién la ejecuta. En el tiro libre directo manda `tiros_libres`; en el
## que se cuelga al área, `centros`; en el corto, el que está más cerca,
## que es lo que hace que el juego se reanude rápido.
static func _elegir_ejecutor(estado: Dictionary, pos: Vector2, ataca_local: bool, tipo: String) -> int:
	# Se limpia SIEMPRE y de entrada: el tiro libre corto sale por el
	# return de abajo sin pasar por la eleccion, y despues igual llama a
	# _ticks_de_pausa — sin esto se comia la espera que habia calculado el
	# corner anterior y frenaba el juego sin motivo.
	estado["ticks_espera_ejecutor"] = 0
	if tipo == "corto":
		return _mas_cercano_del_equipo(estado, pos, ataca_local)
	var atributo := "tiros_libres" if tipo == "directo" else "centros"
	var equipo := _equipo_de(estado, ataca_local)
	# El mejor ejecutante DE LOS QUE PUEDEN LLEGAR. Antes se elegia al
	# mejor del equipo sin mirar donde estaba: medido, el que tiraba el
	# corner estaba a 74 metros de media del banderin, o sea que no
	# llegaba caminando ni en diez segundos y aparecia ahi de golpe al
	# momento del centro. Por eso "no se ve quien patea": no camina hasta
	# la pelota, se teletransporta encima de ella.
	# A quien eligio el club para este balon parado (Equipo > Roles). No
	# alcanza con que este designado: tiene que poder llegar a la pelota.
	# El que esta a setenta metros no camina hasta ahi en el tiempo de la
	# pausa, y si igual se lo hace patear, aparece encima de la pelota de
	# golpe.
	var rol := Roles.CORNERS if tipo == "corner" else (
		Roles.LIBRES_CERCA if tipo == "directo" else Roles.LIBRES_LEJOS)
	# El elegido POR EL CLUB, no el automatico: a este se lo espera aunque
	# este lejos, y esa espera solo tiene sentido si hubo una decision.
	var designado := Roles.explicito(equipo, rol, equipo.en_cancha)

	var mejor := -1.0
	var elegido := -1
	var mas_cerca := -1
	var dist_mas_cerca: float = INF
	var clave_designado := -1
	var dist_designado: float = INF
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != ataca_local or e["rol"] == "ARQ":
			continue
		var d: float = pos.distance_to(e["pos"])
		if d < dist_mas_cerca:
			dist_mas_cerca = d
			mas_cerca = id
		# Al designado se lo mide aparte: se lo espera desde mas lejos.
		if int(e["jugador_id"]) == designado and d <= DIST_MAX_EJECUTOR_DESIGNADO:
			clave_designado = id
			dist_designado = d
		if d > DIST_MAX_AL_EJECUTOR:
			continue
		var j := _dict_jugador(estado, equipo, e["jugador_id"])
		if j.is_empty():
			continue
		if float(j["atributos"][atributo]) > mejor:
			mejor = float(j["atributos"][atributo])
			elegido = id
	if clave_designado != -1:
		# Cuanto hay que esperarlo. Lo lee quien detiene el juego para
		# estirar la pausa, y esos ticks no cuentan como tiempo jugado
		# (ver `esperando_ejecutor` en simular).
		estado["ticks_espera_ejecutor"] = int(
			ceil(dist_designado / METROS_POR_TICK_EJECUTOR)) + TICKS_MARGEN_EJECUTOR
		return clave_designado
	estado["ticks_espera_ejecutor"] = 0
	if elegido != -1:
		return elegido
	return mas_cerca if mas_cerca != -1 else _mas_cercano_del_equipo(estado, pos, ataca_local)


## Para el juego, deja la pelota en el punto y le da a cada uno su marca.
## Los jugadores NO se teletransportan: durante los ticks de pausa trotan
## hasta ahí (ver el paso 0 de _tick), así se ve cómo el área se llena.
## `corte` = frenada en seco: en vez de que los jugadores caminen a sus
## marcas, se los planta ahí y el juego queda TOTALMENTE congelado los
## ticks que dure. Es lo que se usa en la falta y en el saque del medio,
## donde el reinicio tiene que leerse como un corte y no como una
## transición. El resto de los reinicios (lateral, córner, saque de arco)
## siguen con la gente acomodándose, que ahí sí se ve bien.
## Pone a cada uno EN su marca de una vez, apenas se termina el
## congelado del corte. Es lo que ya hacia el penal —que fija
## quietos = detenido y por eso nunca troto nadie— y ahora hacen las
## paradas de TIPOS_QUE_SE_UBICAN.
##
## Antes se acomodaban trotando durante la pausa, y no llegaban: medido
## con tests/_diag_area_parada.gd, un equipo Fisico mandaba 7,8
## jugadores al area en un corner y al momento del saque habia 2,0
## adentro, con 24,5 m de deuda promedio. La pausa del corner son 5 s y
## el 60%% se va en el congelado, asi que quedaban 2 s de trote a 0,45
## de la velocidad: unos 6 m contra los 25 que hacian falta. O sea que
## el reparto por estilo (Estilos.SUBEN_AL_CORNER) existia pero no
## llegaba a la cancha.
##
## El congelado se mantiene: primero se VE donde se corto la jugada y
## recien despues aparecen ubicados, que es como se lee un corte. Los
## ticks que sobran de la pausa son los de todos parados esperando el
## saque.
##
## Volver es al reves: no se teletransporta nadie. Terminada la jugada
## el que subio vuelve corriendo con el movimiento de siempre, o baja
## marcando si el rival sale de contra.
static func _ubicar_para_el_balon_parado(estado: Dictionary) -> void:
	if not TIPOS_QUE_SE_UBICAN.has(str(estado.get("balon_parado", {}).get("tipo", ""))):
		return
	for id in estado["jugadores"]:
		# El que se esta yendo o entrando NO se ubica: esta caminando
		# hacia el lateral y lo mueve _avanzar_entradas_y_salidas.
		if _en_transito(estado, id):
			continue
		var e: Dictionary = estado["jugadores"][id]
		e["pos"] = e.get("marca", e["pos"])
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0


static func _detener_juego(estado: Dictionary, pos: Vector2, ataca_local: bool,
		ejecutor: int, tipo: String, ticks: int, corte: bool = false,
		congelar: int = 0) -> void:
	var pelota: Dictionary = estado["pelota"]
	# La pelota NO se pone en el punto todavía: se queda DONDE QUEDÓ
	# —afuera de la cancha, en las manos del arquero, donde fue la falta—
	# durante toda la parte quieta, y recién se acomoda cuando los
	# jugadores empiezan a moverse. Sin esto la pelota cruzaba la línea y
	# al fotograma siguiente ya aparecía puesta para el lateral: nunca se
	# llegaba a ver que se había ido.
	pelota["vel"] = Vector2.ZERO
	pelota["en_vuelo"] = false
	pelota["poseedor_id"] = -1
	pelota["es_centro"] = false
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota.erase("pared_a")
	# El juego se cortó: el pase de hace diez segundos ya no asiste nada.
	estado["ultimo_pase"] = {}
	_marcar_posiciones(estado, pos, ataca_local, ejecutor, tipo)
	estado["balon_parado"] = {"tipo": tipo, "pos": pos, "ataca_local": ataca_local, "ejecutor": ejecutor}
	estado["detenido"] = ticks + congelar
	if congelar > 0:
		# Nadie se acomoda todavia: quedan CONGELADOS donde estaban. Las
		# marcas ya estan puestas, asi que cuando se termine el congelado
		# trotan hasta ellas — no se teletransportan, que es lo que hacia
		# que la falta no se leyera.
		estado["quietos"] = congelar
		estado["corte_este_tick"] = true
		return
	if corte:
		for id in estado["jugadores"]:
			var e_c: Dictionary = estado["jugadores"][id]
			e_c["pos"] = e_c.get("marca", e_c["pos"])
			e_c["vel"] = Vector2.ZERO
			e_c["rapidez"] = 0.0
		pelota["pos"] = pos
		estado["quietos"] = ticks
		estado["corte_este_tick"] = true
	else:
		estado["quietos"] = int(round(ticks * FRACCION_QUIETOS))


## Adónde va cada uno mientras el juego está parado. Es la parte que hace
## que un tiro libre en zona rival se VEA distinto a uno en campo propio:
## en el que se cuelga al área suben los de arriba y baja toda la defensa
## rival, y en uno lejano cada uno vuelve a su casillero de formación.
static func _marcar_posiciones(estado: Dictionary, pos: Vector2, ataca_local: bool,
		ejecutor: int, tipo: String) -> void:
	var rng: RandomNumberGenerator = estado["rng"]
	var arco := arco_rival(ataca_local)
	var dentro_x: float = arco.x - (11.0 if arco.x > 0.0 else -11.0)
	# Quién arma la barrera se decide ANTES de acomodar a nadie: son los
	# defensores más cercanos a la pelota, y el puesto que ocupa cada uno
	# en la fila es lo que después los pone hombro con hombro.
	for id in estado["jugadores"]:
		estado["jugadores"][id]["puesto_barrera"] = -1
	if tipo == "corner" or tipo == "centro" or tipo == "directo":
		# El centro de un tiro libre es mas medido que un corner: suben
		# dos menos, porque la jugada arranca con el juego en marcha y
		# hay que quedar parado por si sale mal.
		#
		# En el DIRECTO suben todavia menos: la jugada es el remate, y los
		# que van al area van a ESPERAR EL RECHAZO, no a cabecear un
		# centro. Antes no subia nadie —medido, 1,0 atacantes en el area
		# con tests/_diag_area_parada.gd— porque _marca_en_tiro_libre deja
		# a cada uno donde estaba parado.
		var suben := Estilos.suben_al_corner(_equipo_de(estado, ataca_local).estilo)
		if tipo == "centro":
			suben = maxi(suben - 2, 2)
		elif tipo == "directo":
			suben = maxi(suben - 4, 2)
		_repartir_para_el_corner(estado, ataca_local, ejecutor, suben)
	if tipo == "directo":
		# Se eligen por cercania AL PUESTO de la barrera y no a la pelota:
		# son los que menos tienen que caminar para llegar a tiempo.
		var puesto_barrera := pos + (arco - pos).normalized() * 9.15
		var candidatos := []
		for id in estado["jugadores"]:
			var e_b: Dictionary = estado["jugadores"][id]
			if e_b["equipo_local"] == ataca_local or e_b["rol"] == "ARQ" or id == ejecutor:
				continue
			var d_puesto: float = puesto_barrera.distance_to(e_b["pos"])
			# Mas lejos que esto no llega a tiempo: quedaria a mitad de
			# camino cuando el otro ya la pateo, que es peor que no ir.
			if d_puesto > DIST_MAX_A_LA_BARRERA:
				continue
			candidatos.append({"id": id, "d": d_puesto})
		candidatos.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
		var cuantos := mini(_tamano_barrera(pos, ataca_local), candidatos.size())
		for i in range(cuantos):
			estado["jugadores"][candidatos[i]["id"]]["puesto_barrera"] = i
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if id == ejecutor:
			e["marca"] = pos
			continue
		if e["rol"] == "ARQ":
			e["marca"] = e["base"]
			continue

		if tipo == "centro" or tipo == "corner":
			# CUANTOS suben al area lo decide el ESTILO, no el rol. Antes
			# subian solo los roles de ataque (MCO/EXT/DC), asi que un
			# 5-3-2 mandaba dos jugadores y el corner era un ataque de dos
			# contra once; despues los mande a todos, que tampoco es. Un
			# equipo Fisico sube ocho, incluidos los centrales, que es de
			# donde saca sus goles; uno de Contragolpe sube cuatro y deja
			# gente atras esperando justamente el contragolpe.
			#
			# Y el que no sube al area TAMPOCO se queda en su casillero:
			# se para en la mitad de la cancha a jugar el rebote, que es
			# donde termina la mitad de los corners.
			var mio: bool = e["equipo_local"] == ataca_local
			if not mio:
				# Defendiendo baja todo el mundo: eso no depende de nada.
				e["marca"] = Vector2(dentro_x + rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0))
				continue
			if int(e.get("sube_al_area", 0)) == 1:
				e["marca"] = Vector2(dentro_x + rng.randf_range(-5.0, 5.0), rng.randf_range(-14.0, 14.0))
				continue
			if int(e.get("sube_al_area", 0)) == 0:
				# A la mitad de la cancha, del lado del arco rival.
				var hacia_medio: float = 1.0 if ataca_local else -1.0
				e["marca"] = Vector2(hacia_medio * rng.randf_range(2.0, 10.0),
					clampf(float(e["base"].y), -20.0, 20.0))
				continue
			e["marca"] = e["base"]
			continue

		if tipo == "directo":
			# El que fue marcado para esperar el rechazo se para en el
			# area; los demas —incluida toda la defensa, que arma la
			# barrera y marca— siguen con la regla de siempre.
			if e["equipo_local"] == ataca_local and int(e.get("sube_al_area", 0)) == 1:
				var en_area := Vector2(dentro_x + rng.randf_range(-4.0, 4.0),
					rng.randf_range(-12.0, 12.0))
				# La distancia reglamentaria vale para todos, tambien para
				# el que espera el rechazo.
				if pos.distance_to(en_area) < 9.15:
					en_area = pos + (en_area - pos).normalized() * 9.15
				e["marca"] = en_area
				continue
			e["marca"] = _marca_en_tiro_libre(e, pos, ataca_local)
			continue
		e["marca"] = e["base"]


## Cuántos se quedan SIEMPRE atrás en un córner propio, además del
## arquero: aunque el estilo sea de mandar a todos, alguien cubre.
const RESGUARDO_MINIMO_EN_CORNER := 1


## Reparte al equipo que ataca un córner en tres grupos, según el estilo:
## los que suben al área (1), los que se paran en la mitad a jugar el
## rebote (0) y los que se quedan de resguardo (-1). El arquero siempre
## se queda.
##
## Quién sube no es por rol sino por amenaza aérea: un central que cabecea
## bien sube antes que un lateral chiquito, que es exactamente lo que pasa
## en una cancha.
static func _repartir_para_el_corner(estado: Dictionary, ataca_local: bool,
		ejecutor: int, cuantos: int) -> void:
	var equipo := _equipo_de(estado, ataca_local)
	var candidatos := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		e["sube_al_area"] = -1
		if e["equipo_local"] != ataca_local:
			continue
		if str(e["rol"]) == "ARQ" or id == ejecutor:
			continue
		# Amenaza en el área: cabecear y saltar. Los de arriba suman por
		# oficio de área, no por atributo.
		var j := _dict_jugador(estado, equipo, e["jugador_id"])
		var amenaza := 100.0
		if not j.is_empty():
			amenaza = float(j["atributos"]["cabezazo"]) + float(j["atributos"]["salto"])
		if ROLES_QUE_ATACAN.has(str(e["rol"])):
			amenaza += 40.0
		candidatos.append({"id": id, "amenaza": amenaza})
	candidatos.sort_custom(func(a, b): return float(a["amenaza"]) > float(b["amenaza"]))

	var tope: int = mini(cuantos, maxi(candidatos.size() - RESGUARDO_MINIMO_EN_CORNER, 0))
	for i in range(candidatos.size()):
		var clave: int = int(candidatos[i]["id"])
		if i < tope:
			estado["jugadores"][clave]["sube_al_area"] = 1
		elif i < candidatos.size() - RESGUARDO_MINIMO_EN_CORNER:
			estado["jugadores"][clave]["sube_al_area"] = 0


## Cuántos se paran en la barrera. Cuanto más de frente y más cerca del
## arco es la falta, más gente se pone: una falta al borde del área de
## frente lleva cinco, una escorada y lejana lleva dos.
static func _tamano_barrera(pos: Vector2, ataca_local: bool) -> int:
	var geo := factor_geometria(pos, ataca_local)
	return clampi(2 + int(round(geo * 6.0)), 2, 5)


## Dónde se para cada uno en un tiro libre directo.
##
## Antes esto era una sola línea que empujaba a los rivales cercanos en
## dirección OPUESTA a la pelota, cada uno hacia donde estuviera parado.
## Dos consecuencias, las dos visibles en la cancha: no había barrera —
## nadie se ponía entre la pelota y el arco— y al que había quedado del
## lado de adelante lo mandaba todavía más adelante, o sea que la defensa
## se iba ATRÁS DE LA PELOTA y el pateador quedaba solo de frente al
## arco. Con eso, una falta de afuera del área era gol casi seguro.
static func _marca_en_tiro_libre(e: Dictionary, pos: Vector2, ataca_local: bool) -> Vector2:
	var arco := arco_rival(ataca_local)
	var hacia_arco: Vector2 = (arco - pos).normalized()

	if e["equipo_local"] != ataca_local:
		# Barrera: los N defensores más cercanos se paran EN LA LÍNEA de
		# la pelota al arco, a los 9,15 reglamentarios, hombro con hombro.
		var puesto := int(e.get("puesto_barrera", -1))
		if puesto >= 0:
			var lateral := Vector2(-hacia_arco.y, hacia_arco.x)
			return pos + hacia_arco * 9.15 + lateral * (float(puesto) - 1.0) * 0.8
		# El resto se queda DONDE ESTA, corrido a lo justo: afuera de los
		# 9,15 y, si le toca defender, del lado del arco.
		#
		# Antes volvian a su casillero de formacion, que esta a veinte
		# metros. Con el teletransporte no se notaba, pero desde que se
		# acomodan trotando no llegaban nunca: la barrera se armaba a
		# medias y media defensa quedaba en el camino. Un defensor
		# tampoco vuelve a su puesto en un tiro libre — baja unos metros
		# y marca, que es lo que hace esto.
		#
		# Y los de arriba NO bajan: un delantero no se vuelve 28 metros
		# porque le cobraron una falta a su equipo. Se queda arriba
		# esperando el rechazo, solo respetando la distancia.
		var p: Vector2 = e["pos"]
		if not ROLES_QUE_ATACAN.has(str(e["rol"])):
			var limite: float = pos.x + hacia_arco.x * 1.0
			p.x = minf(p.x, limite) if hacia_arco.x < 0.0 else maxf(p.x, limite)
		if pos.distance_to(p) < 9.15:
			var fuera: Vector2 = (p - pos)
			if fuera.length() < 0.1:
				fuera = hacia_arco
			p = pos + fuera.normalized() * 9.15
		return p

	# Los compañeros del pateador también respetan los 9,15.
	var d: float = pos.distance_to(e["pos"])
	if d < 9.15:
		var salida: Vector2 = (e["pos"] - pos)
		if salida.length() < 0.1:
			salida = -hacia_arco
		return pos + salida.normalized() * 9.15
	return e["pos"]


## Un reinicio se JUEGA, no se arranca corriendo: se la toca al compañero
## más atrasado que esté a distancia de pase. Vale para el saque del
## medio, el lateral y el tiro libre lejano — en los tres el que la pone
## en juego no sale conduciendo.
##
## Si no hay NADIE a distancia de pase corto, la revienta hacia adelante.
## Nunca se queda con la pelota: quedarse era el bug — el ejecutor la
## tomaba y salía corriendo, que no es reanudar el juego, y encima el
## rival lo tenía que ir a buscar como si nada hubiera pasado.
##
## El alcance sale del pasador, no de una constante. Antes el corte era
## `max_dist_pase_malo`, o sea el alcance del PEOR pasador posible, para
## todos: cualquiera que no tuviera un compañero ahí nomás se quedaba
## conduciendo. Y al bajar ese peso de 22 a 16 metros —recalibrando el
## alcance por division— el caso pasó de raro a común.
static func _tocar_corto(estado: Dictionary, saca_local: bool) -> void:
	var poseedor_id: int = int(estado["pelota"]["poseedor_id"])
	if poseedor_id == -1 or not estado["jugadores"].has(poseedor_id):
		return
	var poseedor: Dictionary = estado["jugadores"][poseedor_id]
	var equipo := _equipo_de(estado, saca_local)
	var jugador := _dict_jugador(estado, equipo, poseedor["jugador_id"])
	if jugador.is_empty():
		return

	var f: Dictionary = pesos()["fisica"]
	var attr := atributo_pase(jugador, 0.0)
	var max_corto: float = _por_atributo(jugador, attr,
		f["max_dist_pase_malo"], f["max_dist_pase_bueno"], 1.0)

	# Hacia donde se juega el reinicio depende de DONDE ES.
	#
	# En campo propio se la toca al mas atrasado: es poner la pelota en
	# juego sin riesgo. Pero esa regla estaba aplicada SIEMPRE, asi que
	# una falta a favor en campo rival tambien se jugaba para atras — el
	# equipo retrocedia treinta metros cada vez que le cobraban una falta,
	# que es lo contrario de lo que hace cualquier equipo.
	#
	# De la mitad para adelante se busca al que este MAS ADELANTADO
	# dentro del alcance, que es jugar la falta rapido.
	var hacia_adelante: bool = valor_posicion(poseedor["pos"], saca_local) 		>= float(f["avance_para_jugar_la_falta_adelante"])
	var mejor := -1
	var mejor_valor: float = INF if not hacia_adelante else -INF
	# Y por si no hay nadie cerca: el más cercano de todos, para reventarla
	# hacia él en vez de quedarse con la pelota.
	var mas_cerca := -1
	var dist_mas_cerca: float = INF
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != saca_local or id == poseedor_id or e["rol"] == "ARQ":
			continue
		var dist: float = poseedor["pos"].distance_to(e["pos"])
		if dist < dist_mas_cerca:
			dist_mas_cerca = dist
			mas_cerca = id
		if dist > max_corto:
			continue
		# valor_posicion es 1 pegado al arco rival.
		var valor := valor_posicion(e["pos"], saca_local)
		if (valor > mejor_valor) if hacia_adelante else (valor < mejor_valor):
			mejor_valor = valor
			mejor = id
	if mejor != -1:
		_lanzar_pase(estado, poseedor, mejor, jugador)
		return
	if mas_cerca != -1:
		# Pelotazo: no llega un pase, pero la pelota SALE igual.
		_lanzar_pase(estado, poseedor, mas_cerca, jugador, null, true)
		return
	# Sin un solo compañero en cancha (once expulsado) no hay a quién
	# tocarsela; ahi si se queda con ella y juega.


## Se reanuda: el ejecutor toca la pelota y la jugada arranca.
static func _ejecutar_balon_parado(estado: Dictionary) -> void:
	var bp: Dictionary = estado.get("balon_parado", {})
	estado.erase("balon_parado")
	if bp.is_empty():
		return
	if str(bp["tipo"]) == "saque_medio":
		_reiniciar_desde_medio(estado, bool(bp["saca_local"]))
		return
	if str(bp["tipo"]) == "penal":
		_ejecutar_penal(estado, bp)
		return
	if str(bp["tipo"]) == "saque_inicial":
		# El saque del medio es un PASE, no un arranque: se la toca a un
		# compañero y desde ahí empieza el partido. Sin esto el que la
		# tenía salía corriendo solo desde el círculo central, que no es
		# lo que pasa en ninguna cancha.
		_tocar_corto(estado, bool(bp["saca_local"]))
		# Solo se anuncia el arranque de un tiempo; el saque del medio tras
		# un gol ya se contó como gol.
		if int(bp["mitad"]) > 0:
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
				# Nadie llego al area: se juega en corto. Antes se salia
				# sin hacer nada y el ejecutor arrancaba a conducir con la
				# pelota, que no es reanudar un centro ni un corner.
				_tocar_corto(estado, ataca_local)
				return
			_lanzar_pase(estado, e_ej, objetivo, jugador)
			estado["pelota"]["altura_max"] = float(pesos()["fisica"]["altura_centro"])
			estado["pelota"]["es_centro"] = true
			estado["pelota"]["centro_de"] = ataca_local
			estado["centros"]["intentos"] = int(estado["centros"].get("intentos", 0)) + 1
		_:
			# Corto (lateral, falta lejana): se la TOCA a un compañero. Si
			# no, el ejecutor arrancaba corriendo con la pelota desde la
			# línea de banda, que no es poner la pelota en juego.
			_tocar_corto(estado, ataca_local)


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
	var destino := _destino_de_conduccion(poseedor["pos"], poseedor["equipo_local"])
	var dir: Vector2 = (destino - poseedor["pos"]).normalized()
	# Un punto bien por delante para que nunca "llegue" y frene: conducir
	# es avanzar, no ir a un destino. Pasa por _mover_hacia para que el que
	# lleva la pelota también arranque con rampa y no salga disparado.
	_mover_hacia(poseedor, poseedor["pos"] + dir * 20.0, float(f["avance_conducir"]))
	# El que lleva la pelota sí puede meterse en el área (a diferencia de
	# los que se posicionan sin ella, ver LIMITE_X), pero no atravesar la
	# línea de fondo.
	poseedor["pos"] = Vector2(
		clampf(poseedor["pos"].x, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
		clampf(poseedor["pos"].y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))


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
	# §7.3: el que va al quite entrena `quite`; al que se la disputan,
	# `control`. Es literalmente el ejemplo del GDD ("un lateral al que le
	# hacen 20 gambetas gana XP de quite").
	_xp_e(estado, estado["jugadores"][mejor_id], "quite")
	_xp_e(estado, poseedor, "control")
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
	# Adonde tiene que mirar la camara. Normalmente null y la vista sigue
	# la pelota; con alguien saliendo o entrando la accion es el jugador y
	# no la pelota, que se quedo quieta a treinta metros de ahi.
	var foco = null
	var en_transito: Array = estado.get("saliendo", []) + estado.get("entrando", [])
	if not en_transito.is_empty():
		var clave_f: int = int(en_transito[0]["clave"])
		if estado["jugadores"].has(clave_f):
			var e_f: Dictionary = estado["jugadores"][clave_f]
			foco = {"x": e_f["pos"].x, "y": e_f["pos"].y}
	estado["fotogramas"].append({
		"tick": estado["tick"],
		"minuto": estado["minuto"],
		"foco": foco,
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
		# El juego se cortó en seco en este tick (falta, saque del medio):
		# la vista lo usa para el parpadeo.
		"corte": bool(estado.get("corte_este_tick", false)),
		"goles": {"home": estado["home"].goles, "away": estado["away"].goles},
	})


# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------

## Cuánto del reparto de XP sale del PUESTO en vez de las acciones
## concretas del partido. Ver el comentario adentro de xp_normalizada.
const MEZCLA_PERFIL := 0.45


## §7.3: convierte los conteos crudos de acciones en una distribución
## comparable entre motores. Cada jugador reparte `minutos/90` puntos de
## XP entre los atributos que usó, en proporción a cuánto usó cada uno.
##
## Normalizar así es lo que permite que el motor abstracto —que no sabe
## quién hizo qué— entregue lo MISMO en total con una estimación por
## puesto: si los totales no coincidieran, los jugadores del usuario
## crecerían a otro ritmo que los de la IA, y a diferencia de los goles
## ese desbalance se acumula temporada a temporada en vez de promediarse.
static func xp_normalizada(estado: Dictionary) -> Dictionary:
	var total_ticks := float(TICKS_POR_MITAD * 2)
	var pesos: Dictionary = PlayerGenerator.get_weights()
	var out := {"home": {}, "away": {}}
	# Se recorre por MINUTOS, no por acciones: un central que jugó los 90
	# sin tocar la pelota igual entrenó, y si se lo saltea acá su equipo
	# crece más lento que el de la IA —donde el motor abstracto sí le da
	# su parte— y el desbalance se acumula por temporada.
	for clave_t in estado["ticks_en_cancha"]:
		var reg: Dictionary = estado["ticks_en_cancha"][clave_t]
		var fraccion: float = clampf(float(reg["t"]) / total_ticks, 0.0, 1.0)
		if fraccion <= 0.0:
			continue
		var lado: String = "home" if bool(reg["local"]) else "away"
		var jugador_id: int = int(reg["id"])
		var d: Dictionary = estado["xp"].get(lado, {}).get(jugador_id, {})
		var suma := 0.0
		for a in d:
			suma += maxf(float(d[a]), 0.0)
		# El reparto MEZCLA lo que hizo con lo que su puesto exige. Las
		# acciones de un partido tocan cuatro o cinco atributos, mientras
		# que el perfil del puesto (el que usa el motor abstracto) reparte
		# entre nueve: con solo las acciones, el equipo del usuario crecía
		# un 6% más lento que el resto de la liga, medido en 5 temporadas.
		# Y tiene sentido más allá del número: un jugador entrena lo que su
		# puesto le exige, no solo lo que le tocó hacer ese domingo.
		var perfil: Dictionary = pesos.get(str(reg["rol"]), {})
		var suma_p := 0.0
		for a in perfil:
			suma_p += float(perfil[a])
		var norm := {}
		if suma > 0.0:
			for a in d:
				var v: float = maxf(float(d[a]), 0.0)
				if v > 0.0:
					norm[a] = v / suma * (1.0 - MEZCLA_PERFIL) * fraccion
		var peso_perfil: float = MEZCLA_PERFIL if suma > 0.0 else 1.0
		if suma_p > 0.0:
			for a in perfil:
				norm[a] = float(norm.get(a, 0.0)) 					+ float(perfil[a]) / suma_p * peso_perfil * fraccion
		if norm.is_empty():
			continue
		out[lado][jugador_id] = norm
	return out


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
		if bool(estado.get("cancelado", false)):
			break
		_reiniciar_desde_medio(estado, mitad == 0, mitad + 1)
		estado["minuto"] = MINUTOS_MOSTRADOS_POR_MITAD * mitad
		# `jugados` cuenta el tiempo DE JUEGO: los ticks que se van en una
		# entrada o una salida no cuentan, igual que el arbitro repone lo
		# que se pierde en un cambio. Sin esto, animar los cambios le
		# comia el 10% del partido y los goles bajaban de 2,36 a 1,84.
		var jugados := 0
		var reloj := 0
		while jugados < TICKS_POR_MITAD + TICKS_DE_DESCUENTO 				and reloj < TICKS_POR_MITAD + TICKS_DE_DESCUENTO + TICKS_REPUESTOS_TOPE:
			# DESCUENTO. El tiempo no se termina con una pelota parada sin
			# ejecutar: se cobro un penal y el partido se acabo antes de
			# que lo patearan. Pasados los 45, se sigue solo mientras haya
			# algo pendiente, y como mucho hasta el tope de descuento.
			if jugados >= TICKS_POR_MITAD and not _hay_algo_sin_terminar(estado):
				break
			var en_transito: bool = not (estado["saliendo"].is_empty()
				and estado["entrando"].is_empty())
			# Esperar a que el pateador designado llegue al banderin
			# tampoco es tiempo de juego. Sin esto, estirar la pausa le
			# comeria minutos al partido y bajarian los goles — es la
			# misma cuenta que se hizo con los cambios.
			var esperando: int = int(estado.get("esperando_ejecutor", 0))
			if esperando > 0:
				estado["esperando_ejecutor"] = esperando - 1
			_tick(estado, con_fotogramas)
			reloj += 1
			if not en_transito and esperando <= 0:
				jugados += 1
			# Tres expulsados dejan al equipo en 8 y el partido se termina
			# ahi: gana el rival, no importa como iba el marcador.
			if MatchEngine.cancelar_si_falta_gente(
					home, away, _minuto_int(estado), estado["log"], estado["eventos"]):
				estado["cancelado"] = true
				break
			if not ventanas.is_empty() and estado["minuto"] >= ventanas[0]:
				var minuto_ventana: int = ventanas.pop_front()
				MatchEngine._procesar_cambios(home, away, minuto_ventana, true, estado["log"], estado["eventos"])
				_sincronizar_cambios(estado)

	# Ver MatchEngine.simular: el 3-0 de la cancelacion no lo hizo nadie y
	# pisa los goles que hubiera habido, asi que el log de goleadores se
	# vacia. Sin esto la tabla y las estadisticas individuales de la liga
	# dejan de cerrar.
	if bool(estado.get("cancelado", false)):
		estado["goles_log"] = []

	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": estado["log"],
		"goles_log": estado["goles_log"],
		"cancelado": bool(estado.get("cancelado", false)),
		"eventos": estado["eventos"],
		"fotogramas": estado["fotogramas"],
		# §7.3: cuánto entrenó cada jugador cada atributo, normalizado.
		"xp": xp_normalizada(estado),
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
			"dist_pases": estado["dist_pases"],
			"dist_pelotazos": estado["dist_pelotazos"],
			"reinicios": estado["reinicios"],
			"cooldown_activos": estado["cooldown"].size(),
			"pase_detalle": estado["pase_detalle"],
			"pases": estado["pases"],
			"decisiones": estado["decisiones"],
		},
	}
