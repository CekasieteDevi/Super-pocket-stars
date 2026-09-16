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
## 0,4 s por tick: conserva los 120 s reales por mitad, pero evita hacer
## 960 pasos antes de mostrar el partido en celulares.
const TICK_SEG := 0.4
## Cuantos ticks como maximo rueda la pelota sin dueno antes de que se la
## demos igual (ver _dirigir_pelota_a). Dos segundos: la pelota frena en
## medio metro y el que se la quedo corre siete metros por segundo, asi
## que en la practica la alcanza mucho antes.
const TICKS_DIRIGIDA_MAX := 5
## Cuanto de su velocidad conserva por tick la pelota que ya tiene dueno
## decidido pero todavia rueda. Frena rapido a proposito: el pase muere
## cerca de donde termino y el jugador va a buscarla ahi.
const FRENADO_PELOTA_SUELTA := 0.35
## Por debajo de esta velocidad la pelota queda quieta (m/s).
const VEL_PELOTA_QUIETA := 1.0
## Distancia de contacto real para tomar una pelota suelta. `radio_control`
## sirve para resolver un control, pero usarlo aca hacia que el jugador
## recibiera la pelota a mas de un metro y pareciera que se la arrastraban.
const RADIO_TOMA_PELOTA := 0.35
## Con que velocidad se le escapa la pelota al que pierde un duelo cuerpo
## a cuerpo, hacia el que se la saco (m/s). Ahi la pelota estaba quieta
## en sus pies, asi que la direccion la da el duelo y no un vuelo previo.
const VEL_ESCAPE_DUELO := 6.0

## Un partido dura 2 minutos REALES por tiempo, jugados a velocidad real
## (la UI reproduce 2,5 fotogramas por segundo, o sea 1 seg de pantalla = 1
## seg de simulación). Eso son 300 ticks por tiempo.
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
const TICKS_POR_MITAD := 300
const MINUTOS_MOSTRADOS_POR_MITAD := 45.0

## Alargue (§8.7): dos tiempos de 15' que se juegan con el MISMO motor y a
## la misma escala que los 45'. Los ticks se derivan de los minutos en vez
## de escribirse a mano, para que si algun dia cambia la duracion de una
## mitad el alargue la siga solo.
const MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE := 15.0
const TICKS_POR_TIEMPO_ALARGUE := int(TICKS_POR_MITAD * MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE / MINUTOS_MOSTRADOS_POR_MITAD)

## Cuantos ticks se le da a un penal de la tanda para resolverse solo: la
## pausa de acomodarse, la carrera, el remate y el viaje de la pelota. Es
## un SEGURO, igual que TICKS_DE_DESCUENTO: el penal cierra en cuanto la
## pelota llega (ver _patear_de_la_tanda). Con la pausa del penal en 20
## ticks y un remate de 11 m, 60 ticks son mas del triple de lo que tarda.
const TICKS_MAX_PENAL_DE_TANDA := 60

## Cuantos ticks queda la pelota en la red (o en las manos del arquero)
## antes de armar el penal siguiente. Sin esta pausa la tanda pasa de un
## remate al otro sin que se llegue a ver como termino cada uno.
const TICKS_ENTRE_PENALES := 12

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

## Cuánto se mete la red detrás de la línea. No es reglamentario: es el
## arco que dibuja VistaCancha, que lee este mismo número.
const PROFUNDIDAD_ARCO := 2.2

## Dónde frena la pelota que se va por el fondo, en metros detrás de la
## línea. Con la cámara inclinada, una pelota quieta a menos de ~3,7 m
## detrás de la línea y cerca del arco cae ENCIMA del dibujo de la red, y
## se ve trabada en ella: medido con tests/_diag_pelota_en_la_red.gd, le
## pasaba al 38% de las salidas por el fondo. La pista mide 5 m
## (VistaCancha.PISTA), así que 4 m todavía queda adentro del estadio.
const DESCANSO_FONDO := 4.0
## O, si no llega a pasar el arco, a cuánto del palo hacia el costado.
## Con la cámara inclinada, el arco lejano tapa en pantalla hasta ~4,7 m
## de costado, contando la pelota.
const DESCANSO_COSTADO := 5.0

## Distancia mínima entre la pelota que se va y el costado de la red,
## contando el radio de la pelota.
const DESPEJE_RED := 0.5

## El area grande, en metros reglamentarios desde la linea de fondo y
## desde el centro del arco. Estaban escritos a mano dentro de
## _en_el_area; ahora los lee tambien el carril de banda, que gira hacia
## el arco justo "a la altura del area". Un solo lugar donde cambiarlos.
const AREA_LARGO := 16.5
const AREA_MEDIO_ANCHO := 20.16

## Metros hasta la linea de fondo desde los que la banda ya es el ultimo
## tramo: de ahi para adentro el extremo engancha y la segunda linea llega
## al pase atras. Estaba escrito a mano en _opcion_enganche y en la llegada
## de _candidatos_desmarque.
const ULTIMO_TRAMO_BANDA := 24.0

## Desde el ultimo tercio de la cancha el cambio de frente deja de valer:
## la pelota cruza por delante del area y el ataque se reinicia en la otra
## banda en vez de terminar. Medido con tests/_diag_centro_lado_a_lado.gd
## (semilla 4400, 30 partidos): cortandolo solo a 24 m, desde 24-35 m el
## 68% de los pelotazos seguia yendo a la otra banda. Con el tercio, 0%.
const ULTIMO_TERCIO := LARGO / 3.0

## Metros desde la linea de fondo adonde ataca el 9 un centro desde el
## ultimo tramo: entre el area chica (5,5 m) y el punto penal (11 m).
const PROFUNDIDAD_DEL_NUEVE_AL_CENTRO := 8.0

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
## Es un SEGURO, no el final: la mitad se cierra sola en cuanto la jugada
## termina (ver el bucle de `simular`). Este numero solo evita que un
## estado raro deje el partido corriendo para siempre.
##
## Eran 15 ticks, con un comentario que decia "casi 4 minutos": la cuenta
## era vieja, con TICKS_POR_MITAD en 480 son 1,4 minutos mostrados. Un
## corner esta 24 ticks detenido antes de patearse, asi que 15 nunca
## alcanzaban: medido con semilla 909, 4 de 120 mitades se cerraban con un
## corner, un lateral o un tiro libre cobrado y sin ejecutar.
##
## 90 ticks = 8,4 minutos mostrados. Es el peor caso encadenado que se
## permite: un corner (24 detenido + centro + cabezazo) que termina en
## penal (20 detenido + patada).
const TICKS_DE_DESCUENTO := 90


## Hay una jugada sin terminar que no puede quedar en el aire: una pelota
## parada por ejecutar, un centro viajando o un remate yendo al arco.
static func _hay_algo_sin_terminar(estado: Dictionary) -> bool:
	var tipo := str(estado.get("balon_parado", {}).get("tipo", ""))
	# El saque del medio NO es una jugada pendiente: un gol sobre la hora
	# TERMINA la mitad. Antes contaba como pendiente y se iba el descuento
	# entero en el festejo — 8 de 120 mitades medidas se cerraban asi.
	if tipo == "saque_medio" or tipo == "saque_inicial":
		return false
	if tipo != "":
		return true
	if int(estado.get("detenido", 0)) > 0:
		return true
	var pelota: Dictionary = estado["pelota"]
	# La pelota en el aire tampoco termino en nada: el centro del corner
	# que se acaba de ejecutar todavia no lo cabeceo nadie. Sin esto la
	# mitad se cortaba con la pelota viajando.
	return bool(pelota.get("es_remate", false)) or bool(pelota.get("en_vuelo", false))


## Anota que la mitad se termino con la jugada sin terminar. Solo mide:
## no cambia nada del partido. Con el descuento andando tiene que quedar
## en cero.
static func _anotar_corte_sucio(estado: Dictionary) -> void:
	if not _hay_algo_sin_terminar(estado):
		return
	var tipo := str(estado.get("balon_parado", {}).get("tipo", ""))
	if tipo == "":
		tipo = "remate" if bool(estado["pelota"].get("es_remate", false)) else "detenido"
	var d: Dictionary = estado["cortadas"]
	d[tipo] = int(d.get(tipo, 0)) + 1


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
## Un cabezazo no es una patada: sale de un salto y la anima otro sprite.
const ACCION_CABECEA := "cabecea"
## El arquero asegura una atajada y sostiene la pelota antes de jugarla.
const ACCION_AGARRA := "agarra"
## Saque de arco con secuencia propia de armado, impacto y seguimiento.
const ACCION_SAQUE_ARCO := "saque_arco"
## Cabezazo en vuelo horizontal, normalmente tras un centro bajo.
const ACCION_PALOMITA := "palomita"
## El gol. Es la unica accion que no dura un instante: el goleador festeja
## todo lo que dura la pelota en la red (TICKS_DETENIDO["gol"]).
const ACCION_FESTEJA := "festeja"


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


## ¿Hay un rival de campo metido en el tercio del arquero? Si lo hay, el
## arquero la revienta: no sale jugando corto, ni con la pelota en las
## manos ni en el saque de arco.
##
## Antes era un peso que ponderaba la inteligencia, y el saque de arco se la
## tocaba siempre al defensor mas atrasado. Se veia: la toca al central, el
## delantero corta el pase y remata, una y otra vez. Medido con
## tests/_diag_arquero_regala.gd (280 partidos, semilla 77100): el 33% de
## las salidas del arquero se perdia en el propio tercio, y el 17% de los
## goles salia de ahi. Con un solo rival alcanza: el que corta el pase es uno.
static func _arquero_encerrado(estado: Dictionary, es_local: bool) -> bool:
	var arco_x: float = arco_propio(es_local).x
	var tercio: float = float(pesos()["fisica"]["tercio_propio_arquero"])
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != es_local and e["rol"] != "ARQ" \
				and absf(arco_x - e["pos"].x) <= tercio:
			return true
	return false


## Qué tan buena es una posición para atacar: 1.0 pegado al arco rival,
## 0.0 en el arco propio. Es el término "progreso" de la utilidad (§4.1).
static func valor_posicion(pos: Vector2, equipo_local: bool) -> float:
	var arco := arco_rival(equipo_local)
	return clampf(1.0 - pos.distance_to(arco) / LARGO, 0.0, 1.0)


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


## Sin jugador, describe una geometria comun para comparar ocasiones.
## Con jugador, mantiene el alcance fisico y las rutas anteriores de resolucion.
## BUG-007: la decision usa ese alcance solo para habilitar el intento.
static func factor_geometria(pos: Vector2, equipo_local: bool, jugador: Dictionary = {},
		es_decision: bool = false) -> float:
	var f: Dictionary = pesos()["fisica"]
	var arco := arco_rival(equipo_local)
	var dist := pos.distance_to(arco)
	var rango: float = float(f["rango_tiro_medio"])
	if not jugador.is_empty():
		rango = _por_atributo(jugador, "tiro", f["rango_tiro_malo"],
			f["rango_tiro_bueno"], float(f["mezcla_fisica_rango_tiro"]) if es_decision else 0.0)
	var f_dist: float = clampf(1.0 - (dist - 5.0) / rango, 0.0, 1.0)
	return f_dist * factor_angulo(pos, equipo_local)


## La misma ocasión pierde más precisión con poca técnica. El alcance del
## jugador habilita el intento, pero no agranda el arco ni acorta la distancia.
static func probabilidad_porteria(geometria: float, atributo_normalizado: float) -> float:
	var r: Dictionary = pesos()["tiro_resolucion"]
	var tecnica := clampf(atributo_normalizado / 100.0, 0.0, 1.0)
	var calidad_cercana := tecnica * float(r["peso_atributo"]) + float(r["peso_geometria"])
	var dificultad := 1.0 - clampf(geometria, 0.0, 1.0)
	# La curva concentra el castigo adicional en ocasiones difíciles. Una
	# caída lineal también quitaba demasiados goles dentro del área.
	var perdida := dificultad * (
		float(r["peso_geometria"]) * float(r["porteria_calidad"])
		+ dificultad * float(r.get("castigo_distancia", 0.1)) * (2.0 - tecnica))
	return clampf(float(r["porteria_base"]) + calidad_cercana * float(r["porteria_calidad"])
		- perdida, 0.05, 0.85)


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
			# Dorsal. Sale de Team.dorsal_de, que es la unica fuente: la
			# ficha del plantel muestra el mismo numero. Es solo para el
			# sprite; nada de la simulacion lo mira.
			"numero": equipo.dorsal_de(int(j["id"])),
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
			# Etapa 5: el esfuerzo se cobra en cada tick con Team.desgastar,
			# que pide `energia`. Buscar el dict del jugador 22 veces por
			# tick costaba mas que la cuenta.
			"energia": int(j["atributos"]["energia"]),
			"reserva": 1.0,
			# Etapa 3: hacia donde mira y cuanto gira por segundo. Todos
			# arrancan mirando al arco que atacan, que es como se forman.
			"orientacion": orientacion_inicial(es_local),
			"giro": _giro_de(j),
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
		# En que periodo esta el partido: 1 y 2 son las mitades, 3 y 4 los
		# tiempos del alargue. El rotulo del reloj sale de ACA y no del
		# minuto: en el descuento del segundo tiempo el reloj marca 93' y
		# leerlo por minuto mostraba "1T alargue" en un partido de liga.
		"periodo": 1,
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
		"cortes": 0,
		# Mitades que se cortaron con la jugada SIN TERMINAR, por tipo. Es
		# el sintoma que se mide: si esto no es cero, un corner o un penal
		# cobrado sobre la hora no se llego a patear.
		"cortadas": {},
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
		# Etapa 4: fase del equipo que ataca y su progreso. Ver
		# _planificar_ritmo. `ritmo_stats` solo mide.
		"ritmo": {},
		"ritmo_stats": {},
		# Etapa 5: carga de esfuerzo cobrada y ticks con la reserva baja.
		# Solo mide. Ver _contabilizar_esfuerzo.
		"esfuerzo_stats": {"carga": 0.0, "ticks_jugador": 0, "ticks_reserva_baja": 0},
		# Etapa 3: recepciones de pase, dificultad sumada, toques largos, y
		# demora de control contra la cadencia vieja de los controles
		# limpios. Solo mide. Ver _controlar_recepcion.
		"control_stats": {"recepciones": 0, "dificultad": 0.0, "toques_largos": 0,
				"demora": 0, "cadencia": 0},
	}
	_armar_jugadores(home, true, estado)
	_armar_jugadores(away, false, estado)
	# Etapa 8: el perfil de cada uno sale de sus atributos y su rol, y no
	# cambia durante el partido salvo que le cambie el rol.
	_construir_perfiles(estado)
	return estado


# ---------------------------------------------------------------------------
# Presión (§4.3)
# ---------------------------------------------------------------------------

## Suma de la cercanía de los rivales, pesando más al que está entre el
## poseedor y el arco al que ataca (marca "de frente"). Devuelve un valor
## sin normalizar; usar presion_normalizada para 0..1.
## `excluir` saca a un rival de la cuenta: el remate lo usa para no cobrar dos
## veces al defensor que ya tuvo su chance de bloquearlo.
static func presion_sobre(estado: Dictionary, pos: Vector2, equipo_local: bool, excluir: int = -1) -> float:
	var p: Dictionary = pesos()["presion"]
	var radio: float = p["radio"]
	var arco := arco_rival(equipo_local)
	var dir_ataque := (arco - pos).normalized()
	var total := 0.0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == equipo_local or int(id) == excluir:
			continue
		var d: float = pos.distance_to(e["pos"])
		if d >= radio:
			continue
		var cercania: float = 1.0 - d / radio
		# ¿está del lado por el que quiero avanzar?
		var de_frente: float = maxf(0.0, dir_ataque.dot((e["pos"] - pos).normalized()))
		total += cercania * (1.0 + de_frente * (p["factor_frente"] - 1.0))
	return total


static func presion_normalizada(estado: Dictionary, pos: Vector2, equipo_local: bool, excluir: int = -1) -> float:
	var p: Dictionary = pesos()["presion"]
	return clampf(presion_sobre(estado, pos, equipo_local, excluir) / float(p["normalizador"]), 0.0, 1.0)


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

	# §4.2: con un rival en su tercio, el arquero no sale jugando corto.
	# Es una REGLA, como `acorralado`, no un peso (ver _arquero_encerrado).
	var arquero_encerrado: bool = es_arquero and _arquero_encerrado(estado, es_local)

	# --- Conducir -----------------------------------------------------
	# `camino_libre` responde una pregunta que ningun otro termino hacia:
	# QUIEN LE TAPA EL CAMINO. `presion` mira quien lo RODEA, que es otra
	# cosa: un delantero solo, con veinte metros de cancha abierta por
	# delante, media igual que uno encerrado entre lineas. Encima el
	# termino `progreso` de conducir se apaga cuanto mas cerca del arco
	# rival estas, asi que la conduccion se hundia justo en el tercio
	# donde correr con la pelota vale mas. Medido, un poseedor libre y
	# adelantado conducia el 40-55% de las veces (tests/_diag_pase_atras).
	var camino_libre := 1.0 - riesgo_linea(estado, pos, _corredor_elegido(estado, poseedor), es_local)
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
	# El alcance solo habilita. La utilidad compara la misma geometría para
	# todos: tener más pierna no convierte un tiro lejano en la mejor jugada.
	var alcance := factor_geometria(pos, es_local, jugador, true)
	var geo := factor_geometria(pos, es_local)
	if alcance > float(f["geometria_minima_tiro"]):
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
	# El arquero encerrado siempre lo tiene: si ningun companero queda a
	# tiro de pelotazo, el despeje es la unica salida que le queda.
	if acorralado or arquero_encerrado:
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
		var enganche := _opcion_enganche(estado, poseedor, jugador, rival_a_encarar)
		if not enganche.is_empty():
			u_gambeta += 0.45 * (1.0 - enganche["riesgo"])
		opciones.append({
			"tipo": "gambeta", "utilidad": u_gambeta, "objetivo_id": rival_a_encarar,
			"enganche": enganche,
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

		# Leer la corrida preparada antes de descartar receptores lejanos.
		var corrida: Dictionary = estado.get("desmarques", {}).get(id, {})
		# Una ruptura o llegada central ya preparada tambien sirve para el
		# pase atras: no exigir que haya nacido cuando la pelota estaba en banda.
		var llegada_central := false
		if corrida.get("tipo", "") in ["ruptura", "llegada"]:
			var destino_corrida: Vector2 = corrida["destino"]
			llegada_central = absf(destino_corrida.y) <= 11.0 and absf(arco_rival(es_local).x - destino_corrida.x) <= 22.0
		if (bool(corrida.get("pase_atras", false)) or llegada_central) and _zona_de_desborde(pos, es_local):
			var entrega: Vector2 = corrida["destino"]
			var encuentro := _encuentro_pase_atras(estado, poseedor, comp, jugador, entrega, max_dist)
			if not encuentro.is_empty():
				entrega = encuentro["punto"]
			var distancia_entrega := pos.distance_to(entrega)
			var riesgo_entrega := _riesgo_de_salida(estado, pos, entrega, es_local)
			var velocidad_entrega := _por_atributo(jugador, atributo_pase(jugador, distancia_entrega), f["vel_pase_min"], f["vel_pase_max"])
			var tiempo_entrega := distancia_entrega / maxf(velocidad_entrega, 1.0)
			var llega_a_tiempo: bool = comp["pos"].distance_to(entrega) <= float(comp["vel_max"]) * tiempo_entrega * 0.75 + 1.5
			if bool(estado.get("medir_opciones_colectivas", false)):
				_contar_jugada(estado, "pase_atras_evaluado")
				if not llega_a_tiempo:
					_contar_jugada(estado, "pase_atras_receptor_lejos")
				if distancia_entrega > max_dist:
					_contar_jugada(estado, "pase_atras_sin_alcance")
				if riesgo_entrega >= 0.85:
					_contar_jugada(estado, "pase_atras_tapado")
					if not estado.has("muestra_pase_atras"):
						var rivales_carril := []
						for rival in estado["jugadores"].values():
							if rival["equipo_local"] != es_local and _dist_a_segmento(rival["pos"], pos, entrega) < 6.0:
								rivales_carril.append({"rol": rival["rol"], "pos": rival["pos"]})
						estado["muestra_pase_atras"] = {"desde": pos, "destino": entrega, "receptor": comp["pos"], "rivales": rivales_carril}
				if (entrega.x - pos.x) * (1.0 if es_local else -1.0) >= -2.0:
					_contar_jugada(estado, "pase_atras_falta_fondo")
			if distancia_entrega <= max_dist and llega_a_tiempo and riesgo_entrega < 0.85 \
					and (entrega.x - pos.x) * (1.0 if es_local else -1.0) < -2.0:
				opciones.append({"tipo": "pase", "objetivo_id": id, "punto": entrega,
					# La ventaja es dejar un rematador libre; el riesgo del envio
					# ya pesa en seguridad y sigue resolviendose por intercepcion.
					"utilidad": wp["base"] + wp["seguridad"] * (1.0 - riesgo_entrega)
						+ 1.1 * (1.0 - presion_normalizada(estado, entrega, es_local)),
					"detalle": {"pase_atras_al_area": true, "llegada_coordinada": true, "riesgo": riesgo_entrega, "dist": distancia_entrega}})
		if ve_el_hueco and not es_arquero and corrida.get("tipo", "") in ["ruptura", "llegada"]:
			var espacio: Vector2 = corrida["destino"]
			var distancia_espacio := pos.distance_to(espacio)
			var avance_espacio: float = (espacio.x - comp["pos"].x) * (1.0 if es_local else -1.0)
			var riesgo_espacio := riesgo_linea(estado, pos, espacio, es_local)
			var listo_doblamiento := true
			if bool(corrida.get("doblamiento", false)):
				listo_doblamiento = comp["pos"].distance_to(espacio) <= float(comp["vel_max"]) * distancia_espacio / maxf(float(f["vel_pase_max"]), 1.0) * 0.75 + 1.5
			if avance_espacio > 2.0 and distancia_espacio <= max_largo and riesgo_espacio < 0.55 and listo_doblamiento:
				var largo_espacio := distancia_espacio > max_dist
				var utilidad_espacio: float = wh["base"] + wh["progreso"] * (valor_posicion(espacio, es_local) - mi_valor) \
					+ wh["seguridad"] * (1.0 - riesgo_espacio) - wh["distancia"] * distancia_espacio / max_largo
				opciones.append({"tipo": "pase_largo" if largo_espacio else "pase_hueco",
					"utilidad": utilidad_espacio * sesgo_pase * factor_vision + 0.35 * (1.0 - riesgo_espacio),
					"objetivo_id": id, "punto": espacio,
					"detalle": {"dist": distancia_espacio, "riesgo": riesgo_espacio, "corrida_preparada": true}})

		# El centro tiene alcance aereo, independiente del pase corto.
		# Tambien se cuelga al ESPACIO: al punto del area adonde ya corre un
		# companero. Con el centro solo al que estaba parado adentro, casi
		# nunca habia a quien: medido (tests/_diag_centro_lado_a_lado.gd,
		# semilla 4400, 30 partidos), con la pelota abierta entre 20 y 32 m
		# el 9 pisaba el area el 16% del tiempo y salian 0,6 centros por
		# partido. Sin receptor el extremo cambiaba de frente por encima del area.
		var punto_centro = null
		if puede_centrar and _en_el_area(comp["pos"], es_local):
			punto_centro = comp["pos"]
		elif puede_centrar and corrida.get("tipo", "") in ["ruptura", "llegada"] \
				and _en_el_area(corrida["destino"], es_local):
			var destino_centro: Vector2 = corrida["destino"]
			var velocidad_centro := _por_atributo(jugador, atributo_pase(jugador, pos.distance_to(destino_centro)), f["vel_pase_min"], f["vel_pase_max"])
			var tiempo_centro := pos.distance_to(destino_centro) / maxf(velocidad_centro, 1.0)
			if comp["pos"].distance_to(destino_centro) <= float(comp["vel_max"]) * tiempo_centro * 0.75 + 1.5:
				punto_centro = destino_centro
		if punto_centro != null and pos.distance_to(punto_centro) <= max_largo:
			var wce: Dictionary = w["centro"]
			var u_centro: float = wce["base"] \
				+ wce["punteria"] * (float(jugador["atributos"]["centros"]) / 100.0) \
				+ wce["progreso"] * (valor_posicion(punto_centro, es_local) - mi_valor)
			opciones.append({
				"tipo": "centro", "utilidad": u_centro, "objetivo_id": id, "punto": punto_centro,
				"detalle": {"centros": jugador["atributos"]["centros"]},
			})

		# --- Pelotazo ------------------------------------------------
		# Para los que están MÁS LEJOS de lo que llega un pase normal. No
		# hace falta ser buen pasador: el alcance sale de `fuerza`, así
		# que un equipo limitado que no puede salir jugando igual la
		# puede reventar hacia adelante. Que sea de baja efectividad sale
		# solo del motor: una pelota que viaja mucho es más fácil de leer
		# (ver lectura_pase_largo en _gana_intercepcion).
		var ventaja_cambio := _ventaja_cambio_frente(estado, pos, comp["pos"], es_local)
		if dist > max_dist:
			var cambia_banda: bool = pos.y * comp["pos"].y < 0.0 and absf(pos.y - comp["pos"].y) >= AREA_MEDIO_ANCHO \
				and progreso_hacia(comp, pos, es_local) >= -0.06 \
				and (presion > 0.2 or camino_libre < 0.5) \
				and presion_normalizada(estado, comp["pos"], es_local) < 0.25 \
				and absf(arco_rival(es_local).x - pos.x) >= ULTIMO_TERCIO
			cambia_banda = cambia_banda or ventaja_cambio > 0.0
			if dist > max_largo or (progreso_hacia(comp, pos, es_local) <= 0.0 and not cambia_banda):
				continue
			# Tampoco por progreso: desde el ultimo tercio, un pelotazo a la otra
			# banda pasa por encima del area igual (ver _ventaja_cambio_frente).
			if pos.y * comp["pos"].y < 0.0 and absf(comp["pos"].y) >= float(f["banda_para_centrar"]) \
					and absf(arco_rival(es_local).x - pos.x) < ULTIMO_TERCIO:
				continue
			var u_largo: float = wl["base"] \
				+ wl["progreso"] * (valor_posicion(comp["pos"], es_local) - mi_valor) \
				+ wl["presion"] * presion \
				+ wl["salida"] * (1.0 - mi_valor)
			u_largo += ventaja_cambio * 0.9
			opciones.append({
				"tipo": "pase_largo", "utilidad": u_largo, "objetivo_id": id,
				"detalle": {"dist": dist, "presion": presion, "cambio_frente": cambia_banda},
			})
			continue
		var progreso: float = valor_posicion(comp["pos"], es_local) - mi_valor
		var riesgo := riesgo_linea(estado, pos, comp["pos"], es_local)
		var u_pase: float = wp["base"] \
			+ wp["progreso"] * progreso \
			+ wp["seguridad"] * (1.0 - riesgo) \
			- wp["distancia"] * (dist / max_dist)
		# El pase atras es un recurso para salir de una presion, no la
		# jugada de un jugador libre y con la cancha abierta por delante.
		# Sin esto competia de igual a igual con seguir corriendo, y encima
		# multiplicado por los N companeros que quedaban por detras: es el
		# mismo problema estructural del despeje (ver `acorralado`), diez
		# opciones contra una sola y el maximo de diez gana casi siempre.
		u_pase += ventaja_cambio * 0.9 * (1.0 - riesgo)
		if progreso < 0.0:
			u_pase -= wp["retroceso_libre"] * (-progreso) * camino_libre * (1.0 - presion)
		# Desde el fondo, devolver al centro del area crea un remate de
		# frente. No se confunde con retroceder cuando se puede avanzar.
		var pase_atras_al_area: bool = absf(pos.y) >= float(f["banda_para_centrar"]) \
			and mi_valor > 0.8 and absf(comp["pos"].y) < float(f["banda_para_centrar"]) \
			and (comp["pos"].x - pos.x) * (1.0 if es_local else -1.0) < 0.0 \
			and absf(comp["pos"].x - pos.x) < 14.0 and dist < 24.0
		if pase_atras_al_area:
			u_pase += 1.1 * (1.0 - riesgo)
		# Abrir hacia un extremo libre permite atacar desde el costado.
		if absf(comp["pos"].y) >= float(f["banda_para_centrar"]) and absf(pos.y) < float(f["banda_para_centrar"]) \
				and progreso > -0.03 and mi_valor > 0.45:
			u_pase += 0.5 * (1.0 - riesgo) * (1.0 - presion_normalizada(estado, comp["pos"], es_local))
		opciones.append({
			"tipo": "pase", "utilidad": u_pase, "objetivo_id": id,
			"detalle": {"progreso": progreso, "riesgo": riesgo, "dist": dist, "pase_atras_al_area": pase_atras_al_area},
		})

		if sabe_pared and not es_arquero and dist <= dist_max_muro:
			var tercero := _buscar_tercer_hombre(estado, poseedor, comp)
			if not tercero.is_empty():
				opciones.append({"tipo": "pared", "objetivo_id": id,
					"tercero_id": tercero["clave"], "punto": tercero["destino"],
					"utilidad": wpa["base"] + wpa["progreso"] * (valor_posicion(tercero["destino"], es_local) - mi_valor)
						+ wpa["seguridad"] * (1.0 - tercero["riesgo"]) + 0.25,
					"detalle": {"tercer_hombre": true, "riesgo_muro": tercero["riesgo"]}})

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
		# El arquero no la tira al hueco: medido, el 62% de esos pases los
		# cortaba el rival en el propio tercio (tests/_diag_arquero_regala.gd).
		if not ve_el_hueco or es_arquero:
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

	_ponderar_plan(estado, opciones, poseedor, jugador, presion, camino_libre)
	_aplicar_pie_preferido(estado, opciones, poseedor, jugador, es_local,
		float(sesgos["pie_preferido_penalizacion"]))
	# Ver `acorralado` arriba: con la pelota en tu propia zona y gente
	# encima, se descartan las opciones de seguir jugandola. Se filtra al
	# final y no en cada bloque para que la regla se lea de una sola vez.
	if acorralado or arquero_encerrado:
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
	if tipo in ["pase", "pase_largo", "pase_hueco"] and opcion.has("punto"):
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
## Un rival a espaldas de la salida presiona, pero no tapa ese carril.
## Dentro de dos metros sigue contando: aun puede disputar el primer toque.
## Ajustar el encuentro a la carrera real en vez de esperar un punto fijo.
static func _encuentro_pase_atras(estado: Dictionary, pasador: Dictionary, receptor: Dictionary,
		jugador: Dictionary, previsto: Vector2, alcance: float) -> Dictionary:
	var desde: Vector2 = pasador["pos"]
	var pos: Vector2 = receptor["pos"]
	var local: bool = pasador["equipo_local"]
	var f: Dictionary = pesos()["fisica"]
	var velocidad := _por_atributo(jugador, atributo_pase(jugador, desde.distance_to(previsto)), f["vel_pase_min"], f["vel_pase_max"])
	var tiempo := desde.distance_to(pos) / maxf(velocidad, 1.0)
	var anticipado := pos.move_toward(previsto, float(receptor["vel_max"]) * tiempo * 0.65)
	var puntos := [previsto, anticipado, previsto + Vector2(-3.0 if local else 3.0, 0.0),
		previsto + Vector2(0.0, -3.0), previsto + Vector2(0.0, 3.0)]
	var mejor := {}
	var mejor_valor := -INF
	for punto in puntos:
		var entrega: Vector2 = punto
		var profundidad := absf(arco_rival(local).x - entrega.x)
		if profundidad < 7.0 or profundidad > 22.0 or absf(entrega.y) > 11.0 \
				or entrega.distance_to(previsto) > 8.0 or (entrega.x - desde.x) * (1.0 if local else -1.0) >= -2.0:
			continue
		var distancia := desde.distance_to(entrega)
		var vel := _por_atributo(jugador, atributo_pase(jugador, distancia), f["vel_pase_min"], f["vel_pase_max"])
		if distancia > alcance or pos.distance_to(entrega) > float(receptor["vel_max"]) * distancia / maxf(vel, 1.0) * 0.75 + 1.5:
			continue
		var riesgo := _riesgo_de_salida(estado, desde, entrega, local)
		# Desviar el plan solo si abre un carril claro; no regalarla para variar.
		if riesgo >= (0.85 if entrega == previsto else 0.65):
			continue
		var libertad := 1.0 - presion_normalizada(estado, entrega, local)
		var valor := 1.0 - riesgo + 0.6 * libertad - entrega.distance_to(previsto) * 0.025
		if valor > mejor_valor:
			mejor_valor = valor
			mejor = {"punto": entrega}
	return mejor


static func _riesgo_de_salida(estado: Dictionary, desde: Vector2, hasta: Vector2, local: bool, excluir: int = -1) -> float:
	var peor := 0.0
	var direccion := hasta - desde
	for rival in estado["jugadores"].values():
		if rival["equipo_local"] == local or int(rival["clave"]) == excluir:
			continue
		var relativo: Vector2 = rival["pos"] - desde
		if relativo.dot(direccion) < 0.0 and relativo.length() > 2.0:
			continue
		peor = maxf(peor, clampf(1.0 - _dist_a_segmento(rival["pos"], desde, hasta) / 6.0, 0.0, 1.0))
	return peor


## Soltar despues de conducir si hay un companero libre que mejora el ataque.
## Se aplica a las opciones ejecutables, despues del filtro de orientacion.
static func _premiar_descarga_util(estado: Dictionary, poseedor: Dictionary, opciones: Array) -> void:
	if poseedor["rol"] == "ARQ":
		return
	var ticks := int(estado["pelota"].get("ticks_con_pelota", 0))
	var espera := clampf(float(ticks - 3) / 6.0, 0.0, 1.0)
	var peso := float(pesos().get("asociacion_colectiva", {}).get("descarga_util", 0.35))
	if espera <= 0.0 or peso <= 0.0:
		return
	var local: bool = poseedor["equipo_local"]
	var pos: Vector2 = poseedor["pos"]
	var mejor := -1
	var valor_mejor := -INF
	for i in range(opciones.size()):
		var o: Dictionary = opciones[i]
		if o["tipo"] not in ["pase", "pase_hueco", "pase_largo"]:
			continue
		var receptor: Dictionary = estado["jugadores"].get(o.get("objetivo_id", -1), {})
		if receptor.is_empty() or receptor["rol"] == "ARQ":
			continue
		var destino: Vector2 = o.get("punto", receptor["pos"])
		var avance := (destino.x - pos.x) * (1.0 if local else -1.0)
		var apertura := absf(destino.y) - absf(pos.y) > 8.0 and avance >= -1.0
		if avance < 3.0 and not apertura:
			continue
		if _riesgo_de_salida(estado, pos, destino, local) >= 0.45 or presion_normalizada(estado, destino, local) >= 0.35:
			continue
		if float(o["utilidad"]) > valor_mejor:
			mejor = i
			valor_mejor = float(o["utilidad"])
	if mejor == -1:
		return
	var bono := peso * espera
	opciones[mejor]["utilidad"] += bono
	opciones[mejor]["detalle"]["descarga_util"] = true
	for o in opciones:
		if o["tipo"] == "conducir":
			o["utilidad"] -= bono * 0.5


static func _contar_jugada(estado: Dictionary, nombre: String) -> void:
	var conteo: Dictionary = estado.get("jugadas_colectivas", {})
	estado["jugadas_colectivas"] = conteo
	conteo[nombre] = int(conteo.get(nombre, 0)) + 1


static func _opcion_enganche(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary, rival_duelo: int = -1) -> Dictionary:
	var pos: Vector2 = poseedor["pos"]
	var local: bool = poseedor["equipo_local"]
	var f: Dictionary = pesos()["fisica"]
	var distancia_arco := absf(arco_rival(local).x - pos.x)
	if poseedor["rol"] == "ARQ" or absf(pos.y) < float(f["banda_para_centrar"]) \
			or distancia_arco < 6.0 or distancia_arco > ULTIMO_TRAMO_BANDA \
			or float(jugador["atributos"]["centros"]) < float(f["centros_minimo"]):
		return {}
	var amenaza := false
	for comp in estado["jugadores"].values():
		if comp["equipo_local"] == local and comp["clave"] != poseedor["clave"] and _en_el_area(comp["pos"], local):
			amenaza = true
			break
	if not amenaza:
		return {}
	var mejor := {}
	for avance in [2.0, 0.0, -2.0]:
		var destino := pos + Vector2(avance * (1.0 if local else -1.0), -6.0 * signf(pos.y))
		# El marcador se resuelve en el duelo; aca se comprueba la cobertura.
		var riesgo := _riesgo_de_salida(estado, pos, destino, local, rival_duelo)
		if riesgo >= 0.55 or presion_normalizada(estado, destino, local, rival_duelo) >= 0.4:
			continue
		if mejor.is_empty() or riesgo < float(mejor["riesgo"]):
			mejor = {"destino": destino, "riesgo": riesgo}
	return mejor


static func _resolver_gambeta(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary, clave_rival: int, enganche: Dictionary = {}) -> void:
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
	if not enganche.is_empty():
		_accion(estado, int(poseedor["clave"]), "amague_centro")
	# El que va a ser encarado se tira a cortarla.
	# La gambeta puede empezar antes, pero la barrida y la falta necesitan
	# contacto real. Antes el defensor se tiraba y podia cometer falta a los
	# ocho metros, que en pantalla se ve como una falta por bluetooth.
	var hay_contacto: bool = e_rival["pos"].distance_to(poseedor["pos"]) <= float(f["radio_tackle"])
	if hay_contacto:
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

	# Encarar es un duelo, así que lleva la MISMA tirada de falta que el
	# quite: `prob_falta_por_duelo`, una sola por duelo. Antes tenía su
	# propio peso (prob_falta_en_gambeta) y solo se tiraba si el atacante
	# pasaba; ahora el defensor puede bajarlo también cuando le gana, que
	# es lo que hace el que no llega. La falta se COBRA —con su tarjeta,
	# su parada de juego y su tiro libre— en vez de amonestar suelto.
	if hay_contacto and estado["rng"].randf() < float(f["prob_falta_por_duelo"]):
		_cobrar_falta(estado, poseedor["pos"], es_local, defensor, eq_d, eq_a, minuto)
		return

	if pasa:
		estado["gambetas"][lado_g]["ganadas"] += 1
		if not enganche.is_empty():
			poseedor["corredor"] = enganche["destino"]
			poseedor["corredor_hasta"] = int(estado["tick"]) + TICKS_PLAN
			girar_hacia(poseedor, enganche["destino"] - poseedor["pos"])
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
		_entregar_rodando(estado, clave_rival)
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
## Un centro ganado dentro del area lo resuelve de cabeza, salvo que el
## que gano remate MUCHO mejor de volea que de cabeza: ahi va de volea o de
## chilena. El margen de 12 puntos es el que evita que un cabeceador con
## buen tiro deje de cabecear por dos puntos de diferencia.
##
## Es publica porque el laboratorio necesita la MISMA regla para elegir a
## quien cabecea en el clip: con la regla duplicada, el clip del cabezazo
## elegia al mejor de arriba y el motor le hacia tirar una chilena.
static func remata_de_acrobacia(jugador: Dictionary) -> bool:
	return float(jugador["atributos"]["volea"]) > float(jugador["atributos"]["cabezazo"]) + 12.0


## Chance de intentar una volea cuando el centro cae dentro del area.
## No reemplaza al cabezazo: premia la volea, pero deja que aparezca tambien
## en delanteros mixtos. La distancia evita que todo centro termine igual.
static func chance_volea_desde_centro(jugador: Dictionary, punto: Vector2,
		arco: Vector2, rng: RandomNumberGenerator) -> bool:
	var attrs: Dictionary = jugador["atributos"]
	var volea := float(attrs.get("volea", 0.0))
	var cabezazo := float(attrs.get("cabezazo", 0.0))
	var distancia := punto.distance_to(arco)
	var zona := clampf(1.0 - absf(distancia - 12.0) / 12.0, 0.0, 1.0)
	var tecnica := clampf((volea - cabezazo + 35.0) / 100.0, 0.0, 1.0)
	var chance := clampf(0.035 + tecnica * 0.25 + zona * 0.075, 0.0, 0.34)
	return rng.randf() < chance


## Variante rara del cabezazo: centro bajo, zona de remate cercana y jugador
## con buena capacidad aérea/agilidad.
static func remata_de_palomita(jugador: Dictionary, punto: Vector2,
		arco: Vector2, rng: RandomNumberGenerator) -> bool:
	var distancia := punto.distance_to(arco)
	if distancia < 5.0 or distancia > 18.0:
		return false
	var attrs: Dictionary = jugador["atributos"]
	var calidad := clampf((float(attrs.get("cabezazo", 0.0)) * 0.45 \
		+ float(attrs.get("salto", 0.0)) * 0.25 \
		+ float(attrs.get("agilidad", 0.0)) * 0.30) / 100.0, 0.0, 1.0)
	var cercania := 1.0 - absf(distancia - 11.0) / 7.0
	var chance := clampf(0.035 + calidad * 0.10 + maxf(cercania, 0.0) * 0.075, 0.0, 0.22)
	return rng.randf() < chance


static func _resolver_centro(estado: Dictionary, punto: Vector2, ataca_local: bool, minuto: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	estado["centros"]["caidos"] = int(estado["centros"].get("caidos", 0)) + 1

	# El laboratorio monta el centro para MIRAR el cabezazo. Sin esto la
	# jugada terminaba en cualquier otra cosa: el arquero salia a
	# descolgarla (radio_achique = 7 m, y el punto de caida esta a 5,5 m
	# del arco) o el marcador ganaba el salto, y el clip mostraba al
	# arquero sacando en vez del gol de cabeza. Vale UNA vez y se
	# consume. En un partido de verdad la clave no existe.
	var forzado := str(estado.get("forzar_centro", ""))
	if forzado != "":
		estado.erase("forzar_centro")

	# El arquero primero: si LLEGO al punto de caida, la descuelga.
	#
	# Antes alcanzaba con estar a 7 m (radio_achique) en el momento de caer,
	# que es darle la pelota desde lejos en un tick. Y encima casi no
	# pasaba: el arquero no se movia hacia el centro. Medido antes de la
	# etapa, el centro caia en promedio a 16 m de el y solo 5 de 123 caian
	# a menos de 7 m (40 partidos); en la grilla de
	# tests/_diag_arquero_decisiones.gd, 0 descolgados en 168 partidos.
	# Ahora sale a buscarlo mientras vuela (etapa 6, ver
	# _punto_para_interceptar) y tiene que estar a su alcance con los brazos
	# arriba. Afuera del area no hay manos.
	var arq_clave := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != ataca_local and e["rol"] == "ARQ" and not _en_transito(estado, id):
			arq_clave = id
			break
	if arq_clave != -1 and forzado == "":
		var arq_e: Dictionary = estado["jugadores"][arq_clave]
		var alcance: float = ALCANCE_ESTIRADA + float(pesos_arquero()["alcance_descuelgue"])
		if _en_el_area(punto, ataca_local) and punto.distance_to(arq_e["pos"]) <= alcance:
			var arq := eq_d.arquero()
			var chance: float = float(arq["atributos"]["achique"]) / 100.0 * float(f["achique_eficacia"])
			if rng.randf() < chance:
				estado["centros"]["descolgado"] = int(estado["centros"].get("descolgado", 0)) + 1
				_entregar_rodando(estado, arq_clave)
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
		_entregar_rodando(estado, atacante)
		return

	var j_a := _dict_jugador(estado, eq_a, estado["jugadores"][atacante]["jugador_id"])
	var j_d := _dict_jugador(estado, eq_d, estado["jugadores"][defensor]["jugador_id"])
	if j_a.is_empty() or j_d.is_empty():
		_entregar_rodando(estado, atacante)
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
	if forzado == "gana" or Duel.gana_atacante(res, rng):
		estado["centros"]["ganados"] = int(estado["centros"].get("ganados", 0)) + 1
		_entregar_rodando(estado, atacante)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "centro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": estado["jugadores"][atacante]["rol"], "resultado": "gana",
		})
		# Ganó de arriba dentro del área: cabecea al arco. Antes se
		# quedaba la pelota y seguía jugando, que es lo que hacía que un
		# centro ganado no terminara casi nunca en gol.
		if _en_el_area(punto, ataca_local):
			var acrobacia := remata_de_acrobacia(j_a)
			var accion := ACCION_CABECEA
			var accion_forzada := str(estado.get("forzar_centro_accion", ""))
			var palomita_forzada := accion_forzada == ACCION_PALOMITA \
				or bool(estado.get("forzar_palomita", false))
			if palomita_forzada or (accion_forzada not in ["volea", "chilena"] \
				and not acrobacia and remata_de_palomita(j_a, punto, arco_rival(ataca_local), rng)):
				estado.erase("forzar_centro_accion")
				estado.erase("forzar_palomita")
				accion = ACCION_PALOMITA
				estado["centros"]["palomitas"] = int(estado["centros"].get("palomitas", 0)) + 1
			elif acrobacia or accion_forzada in ["volea", "chilena"] \
				or chance_volea_desde_centro(j_a, punto, arco_rival(ataca_local), rng):
				estado.erase("forzar_centro_accion")
				accion = accion_forzada if accion_forzada in ["volea", "chilena"] else \
					("chilena" if punto.distance_to(arco_rival(ataca_local)) < 9.0 and rng.randf() < 0.25 else "volea")
				estado["centros"][accion + "s"] = int(estado["centros"].get(accion + "s", 0)) + 1
			else:
				estado["centros"]["cabezazos"] = int(estado["centros"].get("cabezazos", 0)) + 1
			var attr_remate := "volea" if accion in ["volea", "chilena"] else "cabezazo"
			_resolver_tiro(estado, estado["jugadores"][atacante], j_a, attr_remate, accion)
	else:
		_entregar_rodando(estado, defensor)
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

## La recuperacion abre una ventana corta: los atacantes corren antes de
## que el rival se ordene. Un pase entre companeros no vuelve a abrirla.
const SEGUNDOS_TRANSICION := 6.0
const TICKS_PLAN := 4

static func _actualizar_transicion(estado: Dictionary) -> void:
	var id: int = int(estado["pelota"]["poseedor_id"])
	if int(estado.get("detenido", 0)) > 0:
		estado["transicion_hasta"] = -1
		if id != -1 and estado["jugadores"].has(id):
			estado["ultimo_equipo_con_pelota"] = bool(estado["jugadores"][id]["equipo_local"])
		return
	if id == -1 or not estado["jugadores"].has(id):
		return
	var local: bool = estado["jugadores"][id]["equipo_local"]
	if estado.has("ultimo_equipo_con_pelota") and bool(estado["ultimo_equipo_con_pelota"]) != local:
		estado["transicion_local"] = local
		estado["transicion_hasta"] = int(estado["tick"]) + int(SEGUNDOS_TRANSICION / TICK_SEG)
		estado["inicio_transicion"] = estado["pelota"]["pos"]
	estado["ultimo_equipo_con_pelota"] = local

static func _transicion(estado: Dictionary, local: bool) -> float:
	if bool(estado.get("transicion_local", not local)) != local:
		return 0.0
	return clampf(float(int(estado.get("transicion_hasta", -1)) - int(estado["tick"])) * TICK_SEG / SEGUNDOS_TRANSICION, 0.0, 1.0)

## El conductor compara carriles, no solo una recta al arco. Mantiene la
## eleccion un segundo para que la evasion no oscile en cada fotograma.
static func _corredor_de_desborde(estado: Dictionary, e: Dictionary) -> Dictionary:
	var pos: Vector2 = e["pos"]
	var local: bool = e["equipo_local"]
	if not _zona_de_desborde(pos, local):
		return {}
	var signo := 1.0 if local else -1.0
	for clave in estado.get("desmarques", {}):
		var plan: Dictionary = estado["desmarques"][clave]
		if not bool(plan.get("pase_atras", false)) or int(plan.get("companero", -1)) != int(e["clave"]) \
				or int(plan.get("hasta", -1)) <= int(estado["tick"]) or not estado["jugadores"].has(clave):
			continue
		# Ganar fondo sin cerrar la banda antes de que llegue el rematador.
		var destino := Vector2(clampf(pos.x + 6.0 * signo, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0), pos.y)
		if (destino.x - pos.x) * signo < 2.0 or riesgo_linea(estado, pos, destino, local) >= 0.45:
			continue
		return {"destino": destino}
	return {}


static func _corredor_elegido(estado: Dictionary, e: Dictionary) -> Vector2:
	var tick: int = estado["tick"]
	if tick < int(e.get("corredor_hasta", -1)):
		return e["corredor"]
	var local: bool = e["equipo_local"]
	var pos: Vector2 = e["pos"]
	var frente := (_destino_de_conduccion(pos, local) - pos).normalized()
	var f: Dictionary = pesos()["fisica"]
	var largo: float = float(f["corredor_conduccion"])
	if absf(pos.y) >= float(f["banda_para_centrar"]) and absf(arco_rival(local).x - pos.x) > AREA_LARGO:
		frente = Vector2(1.0 if local else -1.0, 0.0)
	var mejor := pos + frente * largo
	var valor_mejor := -INF
	var desborde := _corredor_de_desborde(estado, e)
	if not desborde.is_empty():
		mejor = desborde["destino"]
		valor_mejor = 1.55 - riesgo_linea(estado, pos, mejor, local)
	for giro in [0.0, -0.55, 0.55]:
		var dir := frente.rotated(giro)
		var destino := pos + dir * largo
		destino.x = clampf(destino.x, -MEDIO_LARGO + 2.0, MEDIO_LARGO - 2.0)
		destino.y = clampf(destino.y, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0)
		var libre := 1.0 - riesgo_linea(estado, pos, destino, local)
		var valor: float = libre + 0.35 * dir.dot(frente)
		if e["vel"].length_squared() > 0.01:
			valor += 0.2 * dir.dot(e["vel"].normalized())
		if valor > valor_mejor:
			valor_mejor = valor
			mejor = destino
	e["corredor"] = mejor
	e["corredor_hasta"] = tick + TICKS_PLAN
	return mejor

# ---------------------------------------------------------------------------
# Ritmo variable (etapa 4)
# ---------------------------------------------------------------------------

## Cuantos ticks se sostiene una fase antes de volver a estimarla. Con
## menos, la fase cambiaba de un fotograma al otro y el equipo alternaba
## entre tocar y acelerar sin que se leyera ninguna de las dos cosas.
const TICKS_RITMO := 6

const FASE_CIRCULACION := "circulacion"
const FASE_ACELERACION := "aceleracion"
const FASE_TRANSICION := "transicion"

## Pesos del ritmo. Como en pesos_defensa, el lector trae los valores por
## defecto: un json sin la seccion `ritmo` sigue andando. Y por el mismo
## motivo queda cacheado — se lee una vez por opcion y por tick.
static var _pesos_ritmo_cache: Dictionary = {}

static func pesos_ritmo() -> Dictionary:
	if not _pesos_ritmo_cache.is_empty():
		return _pesos_ritmo_cache
	var d: Dictionary = pesos().get("ritmo", {})
	_pesos_ritmo_cache = {
		"umbral_transicion": float(d.get("umbral_transicion", 0.70)),
		"frente": float(d.get("frente", 12.0)),
		"espacio_para_acelerar": float(d.get("espacio_para_acelerar", 0.62)),
		"apoyo_libre": float(d.get("apoyo_libre", 0.65)),
		"apoyo_adelante": float(d.get("apoyo_adelante", 4.0)),
		"apoyo_alcance": float(d.get("apoyo_alcance", 32.0)),
		"carril_libre": float(d.get("carril_libre", 0.40)),
		"circulacion_apoyo": float(d.get("circulacion_apoyo", 0.35)),
		"circulacion_cambio": float(d.get("circulacion_cambio", 0.30)),
		"circulacion_dist": float(d.get("circulacion_dist", 22.0)),
		"aceleracion_progreso": float(d.get("aceleracion_progreso", 0.35)),
		"aceleracion_conducir": float(d.get("aceleracion_conducir", 0.25)),
		"pausa_conduccion": float(d.get("pausa_conduccion", 0.75)),
		"tope": float(d.get("tope", 0.50)),
		"estancada_ticks": int(d.get("estancada_ticks", 12)),
		"estancada_avance": float(d.get("estancada_avance", 4.0)),
		"estancada_presion": float(d.get("estancada_presion", 0.35)),
		"devolucion_castigo": float(d.get("devolucion_castigo", 0.30)),
		"devolucion_max": float(d.get("devolucion_max", 3.0)),
	}
	return _pesos_ritmo_cache


## La fase del equipo que ataca, o "" si la pelota todavia no es de nadie.
static func fase_de_ritmo(estado: Dictionary, es_local: bool) -> String:
	var r: Dictionary = estado.get("ritmo", {})
	if r.is_empty() or bool(r.get("local", not es_local)) != es_local:
		return ""
	return str(r.get("fase", ""))


## Cuantos metros gano hacia el arco rival la posesion en curso, y hace
## cuantos ticks que no gana ninguno. Lo usa el castigo a la devolucion
## repetida: sin ganancia y sin presion, volver a la misma pareja de pases
## deja de valer lo mismo.
static func _actualizar_progreso(estado: Dictionary, r: Dictionary, ataca_local: bool) -> void:
	var w := pesos_ritmo()
	var tick: int = int(estado["tick"])
	var x: float = float((estado["pelota"]["pos"] as Vector2).x) * (1.0 if ataca_local else -1.0)
	if not r.has("x_inicio"):
		r["x_inicio"] = x
		r["mejor"] = 0.0
		r["mejor_premiado"] = 0.0
		r["tick_avance"] = tick
		r["pares"] = {}
	var avance: float = x - float(r["x_inicio"])
	if avance > float(r["mejor"]) + 0.5:
		r["mejor"] = avance
		r["tick_avance"] = tick
		# La jugada progreso de verdad: la pareja que se venia devolviendo
		# la pelota dejo de ser un bucle y el conteo arranca de cero.
		if avance >= float(r.get("mejor_premiado", 0.0)) + float(w["estancada_avance"]):
			r["mejor_premiado"] = avance
			(r["pares"] as Dictionary).clear()


## Esta la posesion trabada: sin ganar metros y sin nadie encima. Es la
## condicion que pide el plan para castigar la devolucion repetida — con
## presion, devolverla es la jugada correcta y no se toca.
static func _posesion_estancada(estado: Dictionary, presion: float) -> bool:
	var w := pesos_ritmo()
	var r: Dictionary = estado.get("ritmo", {})
	if r.is_empty() or not r.has("tick_avance"):
		return false
	if presion > float(w["estancada_presion"]):
		return false
	return int(estado["tick"]) - int(r["tick_avance"]) >= int(w["estancada_ticks"])


static func _clave_de_pareja(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]


## Cuantas veces esta pareja ya se intercambio la pelota en la posesion.
static func _veces_de_la_pareja(estado: Dictionary, a: int, b: int) -> float:
	var r: Dictionary = estado.get("ritmo", {})
	var pares: Dictionary = r.get("pares", {})
	return float(pares.get(_clave_de_pareja(a, b), 0))


## Se anota al COMPLETARSE el pase, no al patearlo: un pase que interceptan
## no es una devolucion entre dos companeros.
static func _anotar_pase_de_ritmo(estado: Dictionary, clave_de: int, clave_a: int) -> void:
	var r: Dictionary = estado.get("ritmo", {})
	if r.is_empty():
		return
	var pares: Dictionary = r.get("pares", {})
	r["pares"] = pares
	var k := _clave_de_pareja(clave_de, clave_a)
	pares[k] = int(pares.get(k, 0)) + 1
	# Recordar circulacion real, solo despues de recibir el pase.
	var de: Dictionary = estado["jugadores"].get(clave_de, {})
	var a: Dictionary = estado["jugadores"].get(clave_a, {})
	if de.is_empty() or a.is_empty() or de["equipo_local"] != a["equipo_local"]:
		return
	var avance: float = (a["pos"].x - de["pos"].x) * (1.0 if a["equipo_local"] else -1.0)
	if avance >= 8.0:
		r["toques_circulacion"] = 0
		r["participantes_circulacion"] = {}
	else:
		r["toques_circulacion"] = int(r.get("toques_circulacion", 0)) + 1
		var participantes: Dictionary = r.get("participantes_circulacion", {})
		participantes[clave_de] = true
		participantes[clave_a] = true
		r["participantes_circulacion"] = participantes


static func _ventana_tras_circular(estado: Dictionary, poseedor: Dictionary, opciones: Array) -> int:
	var ritmo: Dictionary = estado.get("ritmo", {})
	if bool(ritmo.get("local", not poseedor["equipo_local"])) != bool(poseedor["equipo_local"]) \
			or int(ritmo.get("toques_circulacion", 0)) < 2 or ritmo.get("participantes_circulacion", {}).size() < 3:
		return -1
	var mejor := -1
	var valor_mejor := -INF
	for i in range(opciones.size()):
		var o: Dictionary = opciones[i]
		if o["tipo"] not in ["pase", "pase_hueco", "pase_largo"]:
			continue
		var receptor: Dictionary = estado["jugadores"].get(o.get("objetivo_id", -1), {})
		if receptor.is_empty():
			continue
		var destino: Vector2 = o.get("punto", receptor["pos"])
		var avance: float = (destino.x - poseedor["pos"].x) * (1.0 if poseedor["equipo_local"] else -1.0)
		if avance < 8.0 or riesgo_linea(estado, poseedor["pos"], destino, poseedor["equipo_local"]) >= 0.35 \
				or presion_normalizada(estado, destino, poseedor["equipo_local"]) >= 0.3:
			continue
		if float(o["utilidad"]) > valor_mejor:
			valor_mejor = float(o["utilidad"])
			mejor = i
	return mejor


## Fase del equipo que ataca: circulacion, aceleracion o transicion.
##
## Se estima con lo que se ve en la escena —espacio por delante del
## poseedor, apoyos libres adelantados y la ventana de transicion que ya
## existia— y se sostiene TICKS_RITMO ticks. La transicion es la unica que
## puede interrumpir el plazo: es un evento del partido, no una estimacion.
##
## La fase NO bloquea ninguna opcion legal. Solo mueve utilidades, con un
## tope (ver pesos_ritmo.tope).
static func _planificar_ritmo(estado: Dictionary) -> void:
	var w := pesos_ritmo()
	var r: Dictionary = estado.get("ritmo", {})
	estado["ritmo"] = r
	if int(estado.get("detenido", 0)) > 0:
		r.clear()
		return
	var pelota: Dictionary = estado["pelota"]
	var id: int = int(pelota["poseedor_id"])
	var ataca_local: bool
	if id != -1 and estado["jugadores"].has(id):
		ataca_local = bool(estado["jugadores"][id]["equipo_local"])
	elif pelota.has("pasador_local"):
		ataca_local = bool(pelota["pasador_local"])
	else:
		return
	# Cambio de manos: el progreso, las parejas de pases y la fase de la
	# posesion anterior no dicen nada de esta.
	if r.is_empty() or bool(r.get("local", not ataca_local)) != ataca_local:
		r.clear()
		r["local"] = ataca_local
		r["fase"] = FASE_TRANSICION
		r["hasta"] = -1
	_actualizar_progreso(estado, r, ataca_local)

	var tick: int = int(estado["tick"])
	if _transicion(estado, ataca_local) > float(w["umbral_transicion"]):
		r["fase"] = FASE_TRANSICION
		r["hasta"] = -1
		_contar_fase(estado, FASE_TRANSICION)
		return
	if tick < int(r.get("hasta", -1)):
		_contar_fase(estado, str(r["fase"]))
		return
	r["hasta"] = tick + TICKS_RITMO

	# Sin poseedor no hay desde donde medir el espacio: se conserva la fase
	# vigente hasta que alguien controle la pelota.
	if id == -1 or not estado["jugadores"].has(id):
		_contar_fase(estado, str(r["fase"]))
		return
	var poseedor: Dictionary = estado["jugadores"][id]
	var pos: Vector2 = poseedor["pos"]
	var frente: Vector2 = pos + (_destino_de_conduccion(pos, ataca_local) - pos).normalized() * float(w["frente"])
	var espacio: float = 1.0 - riesgo_linea(estado, pos, frente, ataca_local)
	var signo: float = 1.0 if ataca_local else -1.0
	var apoyos := 0
	for id_c in estado["jugadores"]:
		if int(id_c) == id:
			continue
		var c: Dictionary = estado["jugadores"][id_c]
		if bool(c["equipo_local"]) != ataca_local or c["rol"] == "ARQ":
			continue
		if _en_transito(estado, int(id_c)):
			continue
		var destino: Vector2 = c["pos"]
		if (destino.x - pos.x) * signo < float(w["apoyo_adelante"]):
			continue
		if pos.distance_to(destino) > float(w["apoyo_alcance"]):
			continue
		if 1.0 - presion_normalizada(estado, destino, ataca_local) < float(w["apoyo_libre"]):
			continue
		# Y el carril tiene que existir: un companero libre al que no se
		# le puede llegar no es una ventaja, es un espejismo. Sin esta
		# comprobacion casi nunca habia circulacion (medido, 5% de los
		# ticks) porque en campo abierto siempre hay alguien despejado.
		if riesgo_linea(estado, pos, destino, ataca_local) > float(w["carril_libre"]):
			continue
		apoyos += 1
	if espacio >= float(w["espacio_para_acelerar"]) or apoyos > 0:
		r["fase"] = FASE_ACELERACION
	else:
		r["fase"] = FASE_CIRCULACION
	r["espacio"] = espacio
	r["apoyos"] = apoyos
	_contar_fase(estado, str(r["fase"]))


## Separa las dos cosas que el plan pide medir aparte: un pase atras sin
## nadie encima, y la devolucion al que acaba de darsela. Solo mide.
static func _medir_pase_atras(estado: Dictionary, elegida: Dictionary,
		poseedor: Dictionary, presion: float) -> void:
	var tipo: String = str(elegida["tipo"])
	if tipo != "pase" and tipo != "pase_largo":
		return
	var objetivo: int = int(elegida.get("objetivo_id", -1))
	if not estado["jugadores"].has(objetivo):
		return
	var local: bool = poseedor["equipo_local"]
	var adelante: float = ((estado["jugadores"][objetivo]["pos"] as Vector2).x
			- (poseedor["pos"] as Vector2).x) * (1.0 if local else -1.0)
	if adelante >= -2.0:
		return
	var s: Dictionary = estado.get("ritmo_stats", {})
	estado["ritmo_stats"] = s
	var up: Dictionary = estado.get("ultimo_pase", {})
	var devolucion: bool = not up.is_empty() and bool(up.get("local", not local)) == local 			and int(up.get("a", -1)) == int(poseedor["clave"]) 			and clave_de(int(up["de"]), local) == objetivo
	var k: String = "devolucion" if devolucion else "atras_sin_presion"
	if not devolucion and presion > float(pesos_ritmo()["estancada_presion"]):
		k = "atras_con_presion"
	s[k] = int(s.get(k, 0)) + 1


## Solo mide. Los contadores no entran en ninguna decision ni tocan el RNG.
static func _contar_fase(estado: Dictionary, fase: String) -> void:
	var s: Dictionary = estado.get("ritmo_stats", {})
	estado["ritmo_stats"] = s
	s[fase] = int(s.get(fase, 0)) + 1


## Ajuste de ritmo para UNA opcion. Devuelve un numero acotado por `tope`:
## la fase inclina la eleccion, no la impone.
##
## En transicion devuelve cero a proposito. Esa fase ya la bonifica el
## termino `transicion` de _ponderar_plan, que existe desde antes; sumarle
## otro premio seria cobrar dos veces lo mismo.
static func _ajuste_de_ritmo(fase: String, tipo: String, adelante: float, dist: float,
		libertad: float, cambio_de_frente: bool, camino: float) -> float:
	if fase != FASE_CIRCULACION and fase != FASE_ACELERACION:
		return 0.0
	var w := pesos_ritmo()
	var a := 0.0
	if fase == FASE_CIRCULACION:
		# Circular vale CUANDO PROGRESAR ESTA CERRADO. Con el camino
		# abierto el premio se apaga solo y la fase no frena nada.
		var cerrado: float = 1.0 - camino
		if tipo == "pase" and libertad >= float(w["apoyo_libre"]) and dist <= float(w["circulacion_dist"]):
			a += float(w["circulacion_apoyo"]) * libertad * cerrado
		if cambio_de_frente and (tipo == "pase" or tipo == "pase_largo"):
			a += float(w["circulacion_cambio"]) * libertad * cerrado
	else:
		var gana: float = clampf(adelante / 15.0, 0.0, 1.0)
		if tipo == "conducir":
			a += float(w["aceleracion_conducir"]) * camino
		elif tipo == "pase_hueco":
			a += float(w["aceleracion_progreso"]) * gana
		elif tipo == "pase" or tipo == "pase_largo":
			a += float(w["aceleracion_progreso"]) * 0.6 * gana * libertad
	return clampf(a, -float(w["tope"]), float(w["tope"]))


# ---------------------------------------------------------------------------
# Contexto del marcador (etapa 7)
# ---------------------------------------------------------------------------

## La URGENCIA de un equipo es un solo numero entre -1 y 1: cuanto
## necesita que el partido cambie.
##
## - Positiva: va perdiendo, o el empate no le alcanza. Adelanta el
##   bloque, manda mas gente a romper y acepta la opcion arriesgada.
## - Negativa: va ganando y quiere que el partido termine. Baja el
##   bloque, deja menos corridas y prefiere el apoyo seguro.
##
## Sale de tres cosas que ya existen: el minuto, la diferencia de goles y
## el rasgo del DT. El minuto pesa con un exponente, asi que al principio
## el efecto es chico y sobre el final crece: al 45' vale un octavo de lo
## que vale al 90'.
##
## Lo que NO hace: tocar duelos. El DT ya tiene su modificador de
## EJECUCION en el bloque C (DT.modificador_partido, que llama
## MatchEngine._bloques_equipo y usan los dos motores), y ese sigue
## siendo el unico. Aca el marcador cambia QUE se elige y DONDE se para
## cada uno; la calidad de la accion elegida se resuelve igual que antes.
## Por eso tampoco hay bonificacion a la punteria ni a la remontada.

## Pesos del contexto del marcador. Como en pesos_ritmo, el lector trae
## los valores por defecto —un json sin la seccion `marcador` sigue
## andando— y el resultado queda cacheado: se lee una vez por opcion y
## por tick.
static var _pesos_marcador_cache: Dictionary = {}

static func pesos_marcador() -> Dictionary:
	if not _pesos_marcador_cache.is_empty():
		return _pesos_marcador_cache
	var d: Dictionary = pesos().get("marcador", {})
	_pesos_marcador_cache = {
		"exponente": float(d.get("exponente", 3.0)),
		"empate": float(d.get("empate", 0.25)),
		"dif_extra": float(d.get("dif_extra", 0.35)),
		"dif_tope": float(d.get("dif_tope", 1.35)),
		"dt_loco": float(d.get("dt_loco", 1.35)),
		"dt_conservador": float(d.get("dt_conservador", 1.35)),
		"altura_bloque": float(d.get("altura_bloque", 6.0)),
		"tope": float(d.get("tope", 0.35)),
		"riesgo": float(d.get("riesgo", 0.35)),
		"seguridad": float(d.get("seguridad", 0.30)),
		"seguridad_dist": float(d.get("seguridad_dist", 22.0)),
		"urgencia_para_romper": float(d.get("urgencia_para_romper", 0.45)),
		"urgencia_para_guardar": float(d.get("urgencia_para_guardar", 0.45)),
		"cierre": float(d.get("cierre", 0.30)),
		"cobertura_extra": float(d.get("cobertura_extra", 0.50)),
	}
	return _pesos_marcador_cache


## Que tan avanzado esta el partido, de 0 a 1.
##
## El alargue entero vale como final: todo minuto jugado ahi es tan tarde
## como el 90'. Medirlo como minuto/120 daria un salto HACIA ATRAS al
## empezar el alargue —el 91' pesaria menos que el 90'— y el que gana se
## adelantaria justo cuando tiene que cuidar el resultado.
static func _avance_del_partido(estado: Dictionary) -> float:
	if int(estado.get("periodo", 1)) >= 3:
		return 1.0
	return clampf(float(estado["minuto"]) / (MINUTOS_MOSTRADOS_POR_MITAD * 2.0), 0.0, 1.0)


## La urgencia de un equipo, sin cache. La cuenta es barata; lo que se
## cachea es el resultado por tick (ver _planificar_marcador).
##
## El empate da urgencia POSITIVA y chica: sobre la hora los dos equipos
## quieren ganarlo. En el alargue vale igual — el empate lleva a los
## penales y tampoco le sirve a nadie.
static func _urgencia_de(estado: Dictionary, es_local: bool) -> float:
	var w := pesos_marcador()
	var equipo := _equipo_de(estado, es_local)
	var dif: int = equipo.goles - _equipo_de(estado, not es_local).goles
	var base: float
	if dif == 0:
		base = float(w["empate"])
	else:
		# El segundo gol de ventaja pesa, pero menos que el primero: al que
		# gana 3-0 no le queda mas que cuidar, y al que pierde 0-3 no le
		# alcanza con tirar al doble de gente.
		var cuanto: float = minf(1.0 + float(absi(dif) - 1) * float(w["dif_extra"]), float(w["dif_tope"]))
		base = -signf(float(dif)) * cuanto
	# El rasgo del DT amplifica la reaccion que ya le corresponde, igual
	# que en DT.modificador_partido: el Loco se tira encima cuando pierde,
	# el Conservador se guarda cuando gana. Ninguno de los dos inventa una
	# reaccion que el marcador no pide.
	var rasgo: String = str(equipo.dt.get("rasgo", "")) if not equipo.dt.is_empty() else ""
	if rasgo == "Loco" and base > 0.0:
		base *= float(w["dt_loco"])
	elif rasgo == "Conservador" and base < 0.0:
		base *= float(w["dt_conservador"])
	return clampf(base * pow(_avance_del_partido(estado), float(w["exponente"])), -1.0, 1.0)


## Deja la urgencia de los dos equipos calculada para este tick. Corre
## una vez por tick, antes de que nadie decida ni se mueva, para que la
## decision y el movimiento sin pelota lean el mismo numero.
static func _planificar_marcador(estado: Dictionary) -> void:
	estado["marcador"] = {
		"tick": int(estado["tick"]),
		"local": _urgencia_de(estado, true),
		"away": _urgencia_de(estado, false),
	}


## La urgencia de este equipo. Lo leen la altura del bloque, el cupo de
## corridas, la utilidad de las opciones y el reparto defensivo.
static func urgencia(estado: Dictionary, es_local: bool) -> float:
	var m: Dictionary = estado.get("marcador", {})
	if m.is_empty() or int(m.get("tick", -1)) != int(estado["tick"]):
		_planificar_marcador(estado)
		m = estado["marcador"]
	return float(m["local"] if es_local else m["away"])


## Cuantas corridas simultaneas se permiten segun el marcador. Es el
## punto 3 de la etapa: ganando al final se conservan apoyos y
## coberturas, perdiendo llega uno mas. Nunca baja de una: un equipo que
## gana igual ataca.
static func _cupo_de_rupturas(estado: Dictionary, ataca_local: bool) -> int:
	var w := pesos_marcador()
	var u := urgencia(estado, ataca_local)
	if u >= float(w["urgencia_para_romper"]):
		return MAX_RUPTURAS + 1
	if u <= -float(w["urgencia_para_guardar"]):
		return maxi(1, MAX_RUPTURAS - 1)
	return MAX_RUPTURAS


## Ajuste de marcador para UNA opcion, acotado por `tope`. El que
## necesita el gol acepta la jugada que gana metros y desprecia la que
## vuelve atras; el que lo cuida hace lo contrario.
##
## El remate queda AFUERA a proposito. Premiarlo con el partido cerrado
## es exactamente el abuso del tiro de lejos que arreglo BUG-007, y la
## calidad de la ocasion es de la etapa 9: el marcador decide desde donde
## se ataca, no cuantos remates lejanos se intentan.
static func _ajuste_de_marcador(urg: float, tipo: String, adelante: float, dist: float,
		libertad: float) -> float:
	var w := pesos_marcador()
	if absf(urg) < 0.01:
		return 0.0
	var a := 0.0
	var gana: float = clampf(adelante / 15.0, 0.0, 1.0)
	var atras: bool = adelante < -2.0
	if urg > 0.0:
		match tipo:
			"pase_hueco":
				a += float(w["riesgo"]) * urg * gana
			"centro":
				a += float(w["riesgo"]) * urg * 0.5
			"gambeta":
				a += float(w["riesgo"]) * urg * 0.4
			"pase", "pase_largo":
				if atras:
					a -= float(w["riesgo"]) * urg
				else:
					a += float(w["riesgo"]) * urg * 0.6 * gana
	else:
		var p: float = -urg
		match tipo:
			"pase":
				if atras or dist <= float(w["seguridad_dist"]):
					a += float(w["seguridad"]) * p * libertad
			"pase_largo":
				a -= float(w["seguridad"]) * p * 0.4
			"pase_hueco":
				a -= float(w["seguridad"]) * p * 0.6
			"gambeta":
				a -= float(w["seguridad"]) * p * 0.5
	return clampf(a, -float(w["tope"]), float(w["tope"]))


# ---------------------------------------------------------------------------
# Identidad individual (etapa 8)
# ---------------------------------------------------------------------------

## El PERFIL de un jugador dice a que juega, no cuan bueno es. Son cinco
## preferencias entre cero y uno que salen de sus atributos y de su rol, y
## se calculan una sola vez al empezar el partido.
##
## - `asociacion`: la toca y se mueve. Pase corto, pared, hueco.
## - `ruptura`: ataca el espacio por detras de la ultima linea.
## - `regate`: se la lleva y encara al que tiene enfrente.
## - `descarga`: recibe de espaldas y aguanta con el marcador encima.
## - `llegada`: entra desde atras cuando la jugada ya paso.
##
## Preferencia NO es capacidad, que es el punto 4 de la etapa. Preferir el
## regate no hace que la gambeta salga: sube la utilidad de encarar, y el
## duelo contra el rival se resuelve exactamente igual que antes. Por eso
## el perfil no toca ningun atributo efectivo ni ninguna probabilidad.
##
## Y el perfil es la FORMA del jugador, no su nivel: las cinco
## preferencias se centran contra la media del propio jugador (ver
## _construir_perfil). Sin ese centrado un crack tendria las cinco altas y
## cobraria bonificacion en todas las opciones, que es regalarle utilidad
## por ser bueno — y eso ya lo hacen sus atributos adentro de cada
## utilidad.
##
## Tampoco lee personalidad ni habilidades. Esos dos sistemas ya empujan
## donde les toca (Egoista el remate, Creador el hueco, Metodico la
## temperatura, Pie preferido el lado malo) y sumarlos aca seria cobrar
## dos veces el mismo efecto.
const RASGOS_PERFIL := ["asociacion", "ruptura", "regate", "descarga", "llegada"]

## Que mezcla de atributos arma cada preferencia. Son los mismos
## atributos que el motor ya usa para EJECUTAR esas acciones; lo que
## cambia es que aca deciden cuanto se las intenta, no como salen.
const MEZCLA_PERFIL_RASGO := {
	"asociacion": {"pases": 0.45, "vision": 0.35, "inteligencia": 0.20},
	"ruptura": {"velocidad": 0.45, "aceleracion": 0.35, "energia": 0.20},
	"regate": {"control": 0.45, "agilidad": 0.35, "aceleracion": 0.20},
	"descarga": {"fuerza": 0.40, "control": 0.35, "cabezazo": 0.25},
	"llegada": {"energia": 0.40, "inteligencia": 0.35, "tiro": 0.25},
}

## Lo que agrega el PUESTO, antes de centrar. No hay selector nuevo: el
## rol es el que ya trae el slot de la formacion (ver _armar_jugadores),
## asi que un central puesto de nueve lee el perfil del nueve.
const SESGO_ROL_PERFIL := {
	"DFC": {"asociacion": 0.05, "ruptura": -0.15, "regate": -0.20, "descarga": 0.05, "llegada": -0.15},
	"LAT": {"asociacion": 0.0, "ruptura": 0.10, "regate": 0.0, "descarga": -0.10, "llegada": 0.10},
	"MC": {"asociacion": 0.15, "ruptura": -0.05, "regate": -0.05, "descarga": -0.05, "llegada": 0.05},
	"MCO": {"asociacion": 0.15, "ruptura": 0.0, "regate": 0.10, "descarga": 0.0, "llegada": 0.10},
	"EXT": {"asociacion": -0.10, "ruptura": 0.15, "regate": 0.20, "descarga": -0.10, "llegada": 0.0},
	"DC": {"asociacion": -0.10, "ruptura": 0.10, "regate": 0.0, "descarga": 0.20, "llegada": -0.05},
}

## El arquero no tiene perfil: con la pelota decide por su propia rama
## (ver evaluar_opciones) y sin ella por su intencion (etapa 6, ver
## _planificar_arqueros).
const PERFIL_NEUTRO := {"asociacion": 0.5, "ruptura": 0.5, "regate": 0.5, "descarga": 0.5, "llegada": 0.5}


## Pesos de la identidad individual. Como en pesos_ritmo y
## pesos_marcador, el lector trae los valores por defecto y el resultado
## queda cacheado: se lee una vez por opcion y por tick.
static var _pesos_perfil_cache: Dictionary = {}

static func pesos_perfil() -> Dictionary:
	if not _pesos_perfil_cache.is_empty():
		return _pesos_perfil_cache
	var d: Dictionary = pesos().get("perfil", {})
	_pesos_perfil_cache = {
		"reparto": float(d.get("reparto", 1.6)),
		"tope": float(d.get("tope", 0.30)),
		"asociacion": float(d.get("asociacion", 0.28)),
		"regate": float(d.get("regate", 0.30)),
		"descarga": float(d.get("descarga", 0.26)),
		"corto_dist": float(d.get("corto_dist", 24.0)),
		"desmarque": float(d.get("desmarque", 0.35)),
	}
	return _pesos_perfil_cache


## Un atributo suelto, normalizado a cero–uno contra el NIVEL del
## partido. Va relativo por el mismo motivo que _por_atributo: el perfil
## es una preferencia comparada con los que estan en la cancha, y en
## decima todos los atributos brutos son bajos. Sin esto, un plantel de
## decima entero tendria las cinco preferencias planchadas contra cero y
## no habria identidad ninguna.
static func _atributo_normalizado(jugador: Dictionary, atributo: String) -> float:
	var bruto: float = float(jugador["atributos"].get(atributo, 50.0))
	return clampf(MatchEngine.relativo_al_nivel(bruto, _nivel_partido) / 100.0, 0.0, 1.0)


## Arma el perfil de un jugador desde sus atributos y su rol. Es una
## cuenta pura: no toca el RNG ni el estado, asi que dos corridas con la
## misma semilla dan el mismo perfil.
static func _construir_perfil(jugador: Dictionary, rol: String) -> Dictionary:
	if rol == "ARQ":
		return PERFIL_NEUTRO.duplicate()
	var crudo := {}
	var suma := 0.0
	var sesgos: Dictionary = SESGO_ROL_PERFIL.get(rol, {})
	for rasgo in RASGOS_PERFIL:
		var v := 0.0
		var mezcla: Dictionary = MEZCLA_PERFIL_RASGO[rasgo]
		for atributo in mezcla:
			v += float(mezcla[atributo]) * _atributo_normalizado(jugador, atributo)
		v += float(sesgos.get(rasgo, 0.0))
		crudo[rasgo] = v
		suma += v
	# Centrado contra la media del propio jugador: lo que queda es en que
	# se DESTACA, no cuanto vale. `reparto` abre el abanico; con 1.6, una
	# preferencia que saca diez puntos de mezcla a las otras cuatro se va
	# ~0,13 por encima del medio punto.
	var media: float = suma / float(RASGOS_PERFIL.size())
	var perfil := {}
	var reparto: float = float(pesos_perfil()["reparto"])
	for rasgo in RASGOS_PERFIL:
		perfil[rasgo] = clampf(0.5 + (float(crudo[rasgo]) - media) * reparto, 0.0, 1.0)
	return perfil


## Deja armado el perfil de los 22 al empezar el partido. El punto 5 de
## la etapa —recalcular al cambiar de rol o al entrar un suplente— lo
## resuelve _perfil_en, que rehace el perfil si el rol guardado ya no es
## el que el jugador tiene en la cancha.
static func _construir_perfiles(estado: Dictionary) -> void:
	for clave in estado["jugadores"]:
		_perfil_en(estado, int(clave))


## Perfil del que ocupa esta clave, construyendolo si falta o si le
## cambio el rol. Queda guardado en el dict del jugador: la mezcla se
## calcula una vez por partido y no una vez por tick.
static func _perfil_en(estado: Dictionary, clave: int) -> Dictionary:
	var e: Dictionary = estado["jugadores"].get(clave, {})
	if e.is_empty():
		return PERFIL_NEUTRO
	var rol: String = str(e["rol"])
	if e.has("perfil") and str(e.get("perfil_rol", "")) == rol:
		return e["perfil"]
	var equipo := _equipo_de(estado, bool(e["equipo_local"]))
	var jugador := _dict_jugador(estado, equipo, int(e["jugador_id"]))
	var perfil: Dictionary = PERFIL_NEUTRO.duplicate() if jugador.is_empty() else _construir_perfil(jugador, rol)
	e["perfil"] = perfil
	e["perfil_rol"] = rol
	return perfil


## El perfil de un jugador en cancha. Lo leen la decision del poseedor,
## el reparto de desmarques y los tests.
static func perfil_de(estado: Dictionary, clave: int) -> Dictionary:
	return _perfil_en(estado, clave)


## Cuanto se aparta de la media esta preferencia, de -1 a 1. Es lo que
## entra en las bonificaciones: un jugador del monton da cero y no mueve
## nada.
static func _gusto(perfil: Dictionary, rasgo: String) -> float:
	return clampf((float(perfil.get(rasgo, 0.5)) - 0.5) * 2.0, -1.0, 1.0)


## Ajuste de identidad para UNA opcion, acotado por `tope`.
##
## Cada bonificacion va multiplicada por el contexto que esa jugada
## necesita, asi que un mal contexto la apaga: el extremo encarador cobra
## el uno contra uno solo si tiene espacio, y el nueve de apoyo cobra la
## descarga solo cuando esta adelantado y con el marcador encima. Es el
## punto 3 de la etapa — el perfil inclina, no obliga.
##
## El remate queda AFUERA, igual que en _ajuste_de_marcador: darle mas
## ganas de patear al que tiene tiro alto es exactamente el abuso que
## arreglo BUG-007.
static func _ajuste_de_perfil(perfil: Dictionary, receptor: Dictionary, tipo: String,
		adelante: float, dist: float, libertad: float, presion: float, camino: float) -> float:
	var w := pesos_perfil()
	var a := 0.0
	match tipo:
		"conducir":
			a += float(w["regate"]) * _gusto(perfil, "regate") * camino * (1.0 - presion)
		"gambeta":
			a += float(w["regate"]) * _gusto(perfil, "regate") * (1.0 - presion)
		"pared":
			a += float(w["asociacion"]) * _gusto(perfil, "asociacion") * 0.8
		"pase":
			var cerca: float = clampf(1.0 - dist / maxf(float(w["corto_dist"]), 1.0), 0.0, 1.0)
			a += float(w["asociacion"]) * _gusto(perfil, "asociacion") * cerca * libertad
			# La descarga la pide el RECEPTOR, no el pasador: el nueve de
			# apoyo se ofrece de espaldas, y por eso vale darsela aunque lo
			# esten marcando. Sin este termino la unica lectura del motor
			# era "receptor tapado, mal pase".
			if not receptor.is_empty() and adelante > 0.0:
				a += float(w["descarga"]) * _gusto(receptor, "descarga") * clampf(1.0 - libertad, 0.0, 1.0) * clampf(adelante / 12.0, 0.0, 1.0)
		"pase_hueco":
			a += float(w["asociacion"]) * _gusto(perfil, "asociacion") * 0.5 * clampf(adelante / 15.0, 0.0, 1.0)
	return clampf(a, -float(w["tope"]), float(w["tope"]))


## Lo que el perfil le suma al valor de un desmarque. Es la otra mitad de
## la etapa: el volante llegador arranca desde atras y el extremo veloz
## ataca el espacio, sin que ninguno de los dos deje de poder hacer otra
## cosa — el valor del candidato sigue mandando y esto solo lo inclina.
static func _sesgo_perfil_desmarque(perfil: Dictionary, tipo: String) -> float:
	var w := pesos_perfil()
	var rasgo := ""
	match tipo:
		"apoyo":
			rasgo = "asociacion"
		"ruptura":
			rasgo = "ruptura"
		"llegada":
			rasgo = "llegada"
		"arrastre":
			rasgo = "descarga"
	if rasgo == "":
		return 0.0
	return float(w["desmarque"]) * _gusto(perfil, rasgo)


## El plan modifica la decision y deja intacta la calidad del duelo.
## La seguridad incluye al receptor: pasarle a alguien encerrado no es
## conservar posesion aunque la trayectoria inicial este despejada.
static func _ponderar_plan(estado: Dictionary, opciones: Array, poseedor: Dictionary,
		jugador: Dictionary, presion: float, camino: float) -> void:
	var local: bool = poseedor["equipo_local"]
	var equipo := _equipo_de(estado, local)
	var plan := Estilos.plan(equipo.estilo)
	var pos: Vector2 = poseedor["pos"]
	var transicion := _transicion(estado, local) * float(plan["transicion"])
	var grupos := {}
	for o in opciones:
		grupos[o["tipo"]] = int(grupos.get(o["tipo"], 0)) + 1
	var temp := temperatura(jugador, presion)
	# Etapa 4: la fase del equipo y, si la posesion esta trabada, a quien
	# seria devolversela. `devolver_a` queda en -1 mientras la jugada
	# progrese o haya presion: devolver la pelota entonces esta bien.
	var fase := fase_de_ritmo(estado, local)
	var ventana := _ventana_tras_circular(estado, poseedor, opciones)
	if ventana != -1 and fase != FASE_TRANSICION:
		fase = FASE_ACELERACION
		estado["ritmo"]["fase"] = fase
		estado["ritmo"]["hasta"] = int(estado["tick"]) + TICKS_RITMO
		opciones[ventana]["utilidad"] += 0.45
		opciones[ventana]["detalle"]["aceleracion_preparada"] = true
	var w_ritmo := pesos_ritmo()
	# Etapa 7: cuanto necesita este equipo que el partido cambie.
	var urg := urgencia(estado, local)
	# Etapa 8: a que juega ESTE jugador. El perfil ya esta armado desde el
	# principio del partido; aca solo se lee.
	var perfil := perfil_de(estado, int(poseedor["clave"]))
	var devolver_a := -1
	var ultimo_p: Dictionary = estado.get("ultimo_pase", {})
	if _posesion_estancada(estado, presion) and not ultimo_p.is_empty() 			and bool(ultimo_p.get("local", not local)) == local 			and int(ultimo_p.get("a", -1)) == int(poseedor["clave"]):
		devolver_a = clave_de(int(ultimo_p["de"]), local)
	for o in opciones:
		var tipo: String = o["tipo"]
		var ajuste := 0.0
		# Diez receptores no deben multiplicar por diez las ganas de pasar.
		ajuste -= 0.35 * temp * log(float(grupos[tipo]))
		if tipo == "conducir":
			ajuste += 0.45 * camino * (1.0 - presion) * (1.0 - float(plan["asociacion"]))
			ajuste += transicion * camino * 0.6
			ajuste -= float(plan["asociacion"]) * 0.2
			ajuste += _ajuste_de_ritmo(fase, tipo, 0.0, 0.0, 0.0, false, camino)
			ajuste += _ajuste_de_perfil(perfil, {}, tipo, 0.0, 0.0, 0.0, presion, camino)
		elif tipo == "pared":
			ajuste += float(plan["asociacion"]) * 0.55
			ajuste += _ajuste_de_perfil(perfil, {}, tipo, 0.0, 0.0, 0.0, presion, camino)
		elif tipo == "pase" or tipo == "pase_largo" or tipo == "pase_hueco":
			var receptor: Dictionary = estado["jugadores"].get(int(o.get("objetivo_id", -1)), {})
			if receptor.is_empty():
				continue
			var destino: Vector2 = o.get("punto", receptor["pos"])
			var adelante: float = (destino.x - pos.x) * (1.0 if local else -1.0)
			var dist := pos.distance_to(destino)
			var libertad := 1.0 - presion_normalizada(estado, destino, local)
			var cambio_de_frente: bool = pos.y * destino.y < 0.0 					and absf(pos.y - destino.y) >= AREA_MEDIO_ANCHO
			if tipo == "pase":
				ajuste += float(plan["asociacion"]) * 1.15 * libertad * clampf(1.0 - dist / 35.0, 0.0, 1.0)
				ajuste -= (1.0 - libertad) * 0.55
				if adelante < -2.0 and not bool(o["detalle"].get("pase_atras_al_area", false)):
					ajuste -= camino * (1.0 - presion) * (0.45 + transicion)
			elif tipo == "pase_hueco":
				ajuste += (float(plan["verticalidad"]) * 0.35 + transicion * 0.8) * libertad * clampf(adelante / 15.0, 0.0, 1.0)
			else:
				ajuste += float(plan["verticalidad"]) * 0.3 + transicion * 0.45
				ajuste -= float(plan["asociacion"]) * 0.6
				if adelante < -2.0:
					ajuste -= 0.6 + camino * (1.0 - presion)
				if cambio_de_frente:
					# Cambiar de frente vale cuando libera al receptor, aunque
					# no gane metros hacia el arco en el primer pase.
					ajuste += libertad * (0.5 + presion * 0.6)
			ajuste += _ajuste_de_ritmo(fase, tipo, adelante, dist, libertad, cambio_de_frente, camino)
			ajuste += _ajuste_de_marcador(urg, tipo, adelante, dist, libertad)
			ajuste += _ajuste_de_perfil(perfil, perfil_de(estado, int(o.get("objetivo_id", -1))),
					tipo, adelante, dist, libertad, presion, camino)
			# La misma pareja devolviendosela sin avanzar y sin presion vale
			# cada vez menos. No se prohibe: el castigo tiene tope y el resto
			# de los pases sigue disponible, asi que siempre queda salida.
			if devolver_a != -1 and int(o.get("objetivo_id", -1)) == devolver_a:
				ajuste -= float(w_ritmo["devolucion_castigo"]) * minf(
						_veces_de_la_pareja(estado, int(poseedor["clave"]), devolver_a),
						float(w_ritmo["devolucion_max"]))
			o["detalle"]["libertad_receptor"] = libertad
		elif tipo == "gambeta" or tipo == "centro":
			# Encarar y colgarla al area son las dos jugadas de riesgo que
			# no pasan por la rama del pase. El remate NO entra aca: ver
			# _ajuste_de_marcador.
			ajuste += _ajuste_de_marcador(urg, tipo, 0.0, 0.0, 0.0)
			ajuste += _ajuste_de_perfil(perfil, {}, tipo, 0.0, 0.0, 0.0, presion, camino)
		o["utilidad"] = float(o["utilidad"]) + ajuste
		o["detalle"]["plan"] = ajuste

## Apoyos escalonados, amplitud y rupturas. Se elige un espacio cercano
## a la funcion del jugador; no se manda a los diez a buscar la pelota.
static func _buscar_apoyo(estado: Dictionary, e: Dictionary, equipo: Team, base: Vector2) -> Vector2:
	var tick: int = estado["tick"]
	var local: bool = e["equipo_local"]
	var id_poseedor: int = int(estado["pelota"]["poseedor_id"])
	if tick < int(e.get("apoyo_hasta", -1)) and int(e.get("apoyo_poseedor", -2)) == id_poseedor:
		return e["apoyo"]
	var pelota: Vector2 = estado["pelota"]["pos"]
	var plan := Estilos.plan(equipo.estilo)
	var signo := 1.0 if local else -1.0
	var lado := signf(float(e["base"].y))
	if lado == 0.0:
		lado = -1.0 if int(e["jugador_id"]) % 2 == 0 else 1.0
	var transicion := _transicion(estado, local) * float(plan["transicion"])
	var rol: String = e["rol"]
	var objetivo := base
	if rol in ["MC", "MCO"] and transicion < 0.5:
		var distancia: float = 10.0 + (1.0 - float(plan["asociacion"])) * 8.0
		var escalon := -distancia * 0.5 if rol == "MC" else distancia * 0.6
		var apoyo := Vector2(pelota.x + signo * escalon, pelota.y + lado * distancia)
		objetivo = base.lerp(apoyo, float(plan["asociacion"]) * 0.7)
	if rol == "EXT" or rol == "LAT":
		objetivo.y = lerpf(objetivo.y, lado * (MEDIO_ANCHO - 7.0), float(plan["amplitud"]))
		# El lateral desdobla al extremo de su lado cuando este puede
		# levantar la cabeza. El lateral opuesto conserva su cobertura.
		if rol == "LAT" and id_poseedor != -1 and estado["jugadores"].has(id_poseedor):
			var poseedor: Dictionary = estado["jugadores"][id_poseedor]
			if poseedor["rol"] == "EXT" and pelota.y * lado > 0.0 and presion_normalizada(estado, pelota, local) < 0.55:
				objetivo.x = pelota.x + signo * 10.0
				objetivo.y = lado * (MEDIO_ANCHO - 4.0)
	if transicion > 0.0 and rol in ["EXT", "DC"]:
		objetivo.x += signo * 14.0 * transicion
		if rol == "EXT":
			objetivo.y = lado * (MEDIO_ANCHO - 7.0)
	# Al llegar por una banda, el extremo opuesto ocupa el segundo palo.
	# Mantener a ambos abiertos tambien aqui dejaba el area sin receptores.
	if pelota.x * signo > MEDIO_LARGO - AREA_LARGO - 5.0 and absf(pelota.y) > 11.0:
		if rol == "EXT" and pelota.y * lado < 0.0:
			objetivo.x = maxf(objetivo.x * signo, pelota.x * signo + 4.0) * signo
			objetivo.y = lado * 7.0
		elif rol == "MCO":
			objetivo.x = (MEDIO_LARGO - AREA_LARGO + 2.0) * signo
			objetivo.y = -signf(pelota.y) * 4.0
	# Tras pasar, el jugador ofrece una nueva linea. Conserva el movimiento
	# al menos hasta el cambio de poseedor, sin exigir que le devuelvan.
	var ultimo: Dictionary = estado.get("ultimo_pase", {})
	if int(ultimo.get("de", -1)) == int(e["jugador_id"]) and bool(ultimo.get("local", not local)) == local and rol in ["MC", "MCO", "EXT"]:
		objetivo.x += signo * 5.0 * float(plan["asociacion"])
	var mejor := objetivo
	var mejor_valor := -INF
	for desplazamiento in [Vector2.ZERO, Vector2(0, -6), Vector2(0, 6), Vector2(-4 * signo, 3 * lado)]:
		var candidato: Vector2 = objetivo + desplazamiento
		candidato.x = clampf(candidato.x, -LIMITE_X, LIMITE_X)
		candidato.y = clampf(candidato.y, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0)
		var valor: float = 1.0 - presion_normalizada(estado, candidato, local)
		valor += 0.5 * (1.0 - riesgo_linea(estado, pelota, candidato, local))
		valor -= desplazamiento.length() * 0.035
		for comp in estado["jugadores"].values():
			if comp["equipo_local"] == local and comp["clave"] != e["clave"]:
				valor -= maxf(0.0, 1.0 - candidato.distance_to(comp["pos"]) / 6.0)
		if valor > mejor_valor:
			mejor_valor = valor
			mejor = candidato
	e["apoyo"] = mejor
	e["apoyo_hasta"] = tick + TICKS_PLAN
	e["apoyo_poseedor"] = id_poseedor
	return mejor

# ---------------------------------------------------------------------------
# Juego sin pelota: intenciones colectivas (etapa 1)
# ---------------------------------------------------------------------------

## Una intencion es lo que el jugador SE PROPUSO hacer sin la pelota, y
## dura mas de un tick. Antes cada uno recalculaba su apoyo solo, con la
## foto del tick, y no habia nada que impidiera que tres pidieran la
## pelota en el mismo metro cuadrado ni que los cinco de arriba rompieran
## juntos dejando al poseedor sin un pie al que pasarle.
##
## El plan es del EQUIPO: se reparte una vez cada TICKS_DESMARQUE_MIN
## ticks desde la misma instantanea, en orden estable por clave, y cada
## intencion sobrevive hasta que vence o deja de ser viable.
##
## Los cuatro tipos:
## - `apoyo`: se ofrece al pie, a distancia util y con la linea limpia.
## - `ruptura`: sale en diagonal por detras de la ultima linea.
## - `arrastre`: se lleva a su marcador lejos del carril central.
## - `llegada`: entra desde atras cuando otro ya fija la ultima linea.
const TIPOS_DESMARQUE := ["apoyo", "ruptura", "arrastre", "llegada"]

## Cada cuanto se vuelve a repartir, y cuanto puede durar una intencion.
## El piso es el mismo TICKS_PLAN del resto de los planes cortos (un
## segundo); el techo son tres segundos, que es lo que tarda un desmarque
## en agotarse. La duracion sale del tiempo de viaje al destino, no del
## azar: el que va lejos sostiene la corrida mas tiempo.
const TICKS_DESMARQUE_MIN := TICKS_PLAN
const TICKS_DESMARQUE_MAX := 12

## Dos desmarques al mismo punto no son dos opciones de pase: son una
## sola, tapada por el mismo defensor.
const SEPARACION_DESMARQUE := 4.0

## Cuantos pueden abandonar la linea de la pelota a la vez (ruptura o
## llegada). Sin tope, el reparto manda a todos los de arriba a correr al
## mismo tiempo y no queda nadie a quien tocarsela.
const MAX_RUPTURAS := 2

## Quien puede tomar cada tipo. El DFC queda afuera de todo: su
## acompanamiento ya lo gobierna SUBIDA_POR_ROL y meterlo a romper
## descubre el fondo.
const ROLES_QUE_ROMPEN := ["MCO", "EXT", "DC"]
const ROLES_QUE_LLEGAN := ["MC", "MCO", "LAT"]

## Presion en el destino a partir de la cual la intencion deja de tener
## sentido: el espacio que se iba a ocupar ya no existe.
const PRESION_DESTINO_INVIABLE := 0.85


## Pesos del reparto. Viven en utility_pesos.json para poder calibrarlos,
## pero el lector trae los valores por defecto: un json sin la seccion
## sigue funcionando.
static func pesos_sin_pelota() -> Dictionary:
	var sp: Dictionary = pesos().get("sin_pelota", {})
	return {
		"linea": float(sp.get("linea", 1.0)),
		"espacio": float(sp.get("espacio", 0.9)),
		"progreso": float(sp.get("progreso", 1.6)),
		"distancia_util": float(sp.get("distancia_util", 0.7)),
		"viaje": float(sp.get("viaje", 0.5)),
		"dist_ideal": float(sp.get("dist_ideal", 15.0)),
		"dist_tolerancia": float(sp.get("dist_tolerancia", 13.0)),
		"conflicto": float(sp.get("conflicto", 2.0)),
		"minimo": float(sp.get("minimo", 0.35)),
		"sesgo_apoyo": float(sp.get("sesgo_apoyo", 0.30)),
		"sesgo_ruptura": float(sp.get("sesgo_ruptura", 0.10)),
		"sesgo_arrastre": float(sp.get("sesgo_arrastre", -0.10)),
		"sesgo_llegada": float(sp.get("sesgo_llegada", 0.0)),
		"pared_riesgo_max": float(sp.get("pared_riesgo_max", 0.55)),
	}


## Largo de una corrida al espacio segun lo rapido que sea el que la
## hace. Es la misma escala que usa el pase al hueco: el punto al que se
## tira la pelota y el punto al que corre el companero salen de aca, de
## una sola cuenta.
static func largo_de_ruptura(vel_max: float) -> float:
	var f: Dictionary = pesos()["fisica"]
	var t: float = clampf((vel_max - float(f["vel_min"])) / maxf(float(f["vel_max"]) - float(f["vel_min"]), 0.01), 0.0, 1.0)
	return float(f["hueco_min"]) + (float(f["hueco_max"]) - float(f["hueco_min"])) * t


## Recorta un destino a la cancha jugable y a la linea de offside. Asi la
## legalidad se comprueba al construir el candidato y no despues: una
## ruptura apunta al filo de la linea, nunca mas alla.
static func _destino_legal(estado: Dictionary, punto: Vector2, es_local: bool) -> Vector2:
	var linea: Dictionary = estado["linea_offside"]
	var x: float = clampf(punto.x, -LIMITE_X, LIMITE_X)
	if es_local:
		x = minf(x, float(linea["local"]))
	else:
		x = maxf(x, float(linea["away"]))
	return Vector2(x, clampf(punto.y, -MEDIO_ANCHO + 3.0, MEDIO_ANCHO - 3.0))


## Cuanto vale para el equipo que ESTE jugador ocupe ESTE punto. Mide lo
## que pide la etapa: linea de pase limpia, distancia util al poseedor,
## progresion, espacio al llegar y lo que cuesta el viaje.
static func _valor_de_desmarque(estado: Dictionary, e: Dictionary, poseedor: Dictionary,
		destino: Vector2, tipo: String) -> float:
	var w := pesos_sin_pelota()
	var local: bool = e["equipo_local"]
	var pos: Vector2 = e["pos"]
	var desde: Vector2 = poseedor["pos"]
	var dist_pase: float = desde.distance_to(destino)
	var util: float = clampf(1.0 - absf(dist_pase - float(w["dist_ideal"])) / maxf(float(w["dist_tolerancia"]), 0.01), 0.0, 1.0)
	var valor: float = float(w["linea"]) * (1.0 - riesgo_linea(estado, desde, destino, local))
	valor += float(w["espacio"]) * (1.0 - presion_normalizada(estado, destino, local))
	valor += float(w["progreso"]) * (valor_posicion(destino, local) - valor_posicion(pos, local))
	valor += float(w["distancia_util"]) * util
	valor -= float(w["viaje"]) * (pos.distance_to(destino) / 30.0)
	valor += float(w["sesgo_" + tipo])
	# Etapa 8: el sesgo del EQUIPO por tipo de desmarque es el de arriba;
	# este es el del jugador. El llegador arranca desde atras y el extremo
	# veloz ataca el espacio, pero la geometria sigue mandando.
	valor += _sesgo_perfil_desmarque(_perfil_en(estado, int(e["clave"])), tipo)
	return valor


## Los desmarques que este jugador podria elegir, cada uno con su punto
## ya legal y su valor. Sale de su rol y de la geometria de la jugada; no
## se sortea nada.
static func _ventaja_cambio_frente(estado: Dictionary, desde: Vector2, destino: Vector2, local: bool) -> float:
	if absf(desde.y) < 10.0 or desde.y * destino.y >= 0.0 or absf(destino.y) < 16.0:
		return 0.0
	# En el ultimo tercio cambiar de frente es cruzarla por encima
	# del area. Medido (tests/_diag_centro_lado_a_lado.gd, semilla 4400): el
	# 53% de los pelotazos desde la zona de centro iba al extremo de la otra
	# banda, y solo el 15% terminaba en remate. Ahi la jugada es el centro.
	if absf(arco_rival(local).x - desde.x) < ULTIMO_TERCIO:
		return 0.0
	if (destino.x - desde.x) * (1.0 if local else -1.0) < -6.0:
		return 0.0
	var presion_destino := presion_normalizada(estado, destino, local)
	if presion_destino >= 0.25:
		return 0.0
	var lado_pelota := 0
	var lado_libre := 0
	for rival in estado["jugadores"].values():
		if rival["equipo_local"] == local or rival["rol"] == "ARQ":
			continue
		if absf(rival["pos"].x - desde.x) > 25.0:
			continue
		if rival["pos"].y * signf(desde.y) > 5.0:
			lado_pelota += 1
		elif rival["pos"].y * signf(desde.y) < -5.0:
			lado_libre += 1
	if lado_pelota < 3 or lado_pelota - lado_libre < 2:
		return 0.0
	return clampf(float(lado_pelota - lado_libre) / 4.0, 0.0, 1.0) * (1.0 - presion_destino)


static func _zona_de_desborde(pos: Vector2, local: bool) -> bool:
	return absf(pos.y) >= float(pesos()["fisica"]["banda_para_centrar"]) \
		and absf(arco_rival(local).x - pos.x) < 16.0


static func _diagonal_extremo(estado: Dictionary, extremo: Dictionary, poseedor: Dictionary) -> Dictionary:
	var pos: Vector2 = extremo["pos"]
	var local: bool = extremo["equipo_local"]
	if extremo["rol"] != "EXT" or absf(pos.y) < 14.0:
		return {}
	var signo := 1.0 if local else -1.0
	var mejor := {}
	var mejor_valor := -INF
	for lateral in estado["jugadores"].values():
		if lateral["equipo_local"] == local or lateral["rol"] != "LAT" or lateral["pos"].y * pos.y <= 0.0:
			continue
		for central in estado["jugadores"].values():
			if central["equipo_local"] == local or central["rol"] != "DFC":
				continue
			if absf(central["pos"].y) >= absf(lateral["pos"].y) or central["pos"].y * pos.y < 0.0:
				continue
			var ancho: float = absf(lateral["pos"].y - central["pos"].y)
			if ancho < 7.0 or ancho > 20.0 or absf(lateral["pos"].x - central["pos"].x) > 10.0:
				continue
			var medio: Vector2 = (lateral["pos"] + central["pos"]) * 0.5
			var destino := _destino_legal(estado, medio + Vector2(2.0 * signo, 0.0), local)
			if (destino.x - pos.x) * signo <= 2.0 or absf(destino.y) > absf(pos.y) - 3.0 or pos.distance_to(destino) > 22.0:
				continue
			if presion_normalizada(estado, destino, local) >= 0.4 or riesgo_linea(estado, pos, destino, local) >= 0.55:
				continue
			var valor := _valor_de_desmarque(estado, extremo, poseedor, destino, "ruptura") + 0.8
			if valor > mejor_valor:
				mejor_valor = valor
				mejor = {"tipo": "ruptura", "destino": destino, "companero": int(poseedor["clave"]),
					"diagonal_extremo": true, "valor": valor}
	return mejor


static func _candidatos_desmarque(estado: Dictionary, e: Dictionary, poseedor: Dictionary, ancla: Vector2) -> Array:
	var local: bool = e["equipo_local"]
	var pos: Vector2 = e["pos"]
	var desde: Vector2 = poseedor["pos"]
	var rol: String = e["rol"]
	var arco := arco_rival(local)
	var signo := 1.0 if local else -1.0
	var w := pesos_sin_pelota()
	var candidatos := []
	# El nueve ofrece descarga; la segunda corrida depende de que libere sitio.
	if rol == "DC" and (pos.x - desde.x) * signo > 10.0 and pos.distance_to(desde) < 32.0:
		var descarga := _destino_legal(estado, pos.move_toward(desde, 7.0), local)
		if presion_normalizada(estado, descarga, local) < 0.4 and riesgo_linea(estado, desde, descarga, local) < 0.55:
			candidatos.append({"tipo": "apoyo", "destino": descarga, "companero": int(poseedor["clave"]),
				"nueve_baja": true, "espacio_nueve": pos,
				"valor": _valor_de_desmarque(estado, e, poseedor, descarga, "apoyo") + 0.65})
	if rol in ["EXT", "MCO", "MC"]:
		for clave_nueve in estado.get("desmarques", {}):
			var plan_nueve: Dictionary = estado["desmarques"][clave_nueve]
			if not bool(plan_nueve.get("nueve_baja", false)) or not estado["jugadores"].has(clave_nueve) \
					or int(plan_nueve.get("hasta", -1)) <= int(estado["tick"]):
				continue
			var nueve: Dictionary = estado["jugadores"][clave_nueve]
			var espacio_nueve: Vector2 = plan_nueve["espacio_nueve"]
			if nueve["equipo_local"] != local or (espacio_nueve.x - nueve["pos"].x) * signo < 3.0:
				continue
			var entrada := _destino_legal(estado, espacio_nueve, local)
			if (entrada.x - pos.x) * signo <= 2.0 or pos.distance_to(entrada) > 22.0 \
					or presion_normalizada(estado, entrada, local) >= 0.4:
				continue
			candidatos.append({"tipo": "ruptura", "destino": entrada, "companero": int(clave_nueve),
				"relevo_nueve": true,
				"valor": _valor_de_desmarque(estado, e, poseedor, entrada, "ruptura") + 0.8})
	var diagonal := _diagonal_extremo(estado, e, poseedor)
	if not diagonal.is_empty():
		candidatos.append(diagonal)
	# El lateral de ese costado supera por fuera al extremo que fija marca.
	if rol == "LAT" and poseedor["rol"] == "EXT" and pos.y * desde.y > 0.0 \
			and absf(desde.y) >= 12.0 and absf(desde.y) <= MEDIO_ANCHO - 7.0 \
			and (pos.x - desde.x) * signo <= 2.0 and pos.distance_to(desde) <= 24.0:
		var atrae := false
		for rival in estado["jugadores"].values():
			if rival["equipo_local"] != local and rival["rol"] != "ARQ" and rival["pos"].distance_to(desde) < 8.0:
				atrae = true
				break
		var por_fuera := _destino_legal(estado, desde + Vector2(8.0 * signo, 6.0 * signf(desde.y)), local)
		if atrae and (por_fuera.x - desde.x) * signo > 3.0 \
				and presion_normalizada(estado, por_fuera, local) < 0.4:
			candidatos.append({"tipo": "ruptura", "destino": por_fuera,
				"companero": int(poseedor["clave"]), "doblamiento": true,
				"valor": _valor_de_desmarque(estado, e, poseedor, por_fuera, "ruptura") + 0.85})
	# El jugador de la banda opuesta sostiene amplitud para recibir libre.
	if rol in ["EXT", "LAT"] and ancla.y * desde.y < 0.0:
		var abierto := _destino_legal(estado, Vector2(ancla.x, signf(ancla.y) * 23.0), local)
		var ventaja := _ventaja_cambio_frente(estado, desde, abierto, local)
		if ventaja > 0.0 and pos.distance_to(abierto) <= 18.0:
			candidatos.append({"tipo": "apoyo", "destino": abierto, "companero": int(poseedor["clave"]),
				"valor": _valor_de_desmarque(estado, e, poseedor, abierto, "apoyo") + ventaja,
				"cambio_frente": true})
	# Mientras el extremo desborda, una segunda linea entra al pase atras.
	# Usa el cupo de llegadas y la separacion de destinos del reparto comun.
	# Arrancar antes de que el extremo llegue al area: si espera a que
	# gane fondo, el rematador tiene que recorrer veinte metros tarde.
	if absf(desde.y) >= float(pesos()["fisica"]["banda_para_centrar"]) \
			and absf(arco.x - desde.x) < ULTIMO_TRAMO_BANDA and rol in ["MC", "MCO", "DC", "EXT"]:
		for lateral in [-6.0, 0.0, 6.0]:
			# Si el extremo aun no gano fondo, ofrecer remate desde el borde.
			var profundidad := clampf(absf(arco.x - desde.x) + 4.0, 11.0, 16.0)
			# El 9 no espera el pase atras en el punto penal: ataca el
			# centro entre el area chica y el penal. Con los 11-16 m de los
			# demas, medido en tests/_diag_mco_llegada.gd (semilla 4400), su
			# plan quedaba a 14,4 m del fondo y el estaba a 19,8 m.
			if rol == "DC":
				profundidad = PROFUNDIDAD_DEL_NUEVE_AL_CENTRO
			var punto_atras := _destino_legal(estado, Vector2(arco.x - signo * profundidad, lateral), local)
			if pos.distance_to(punto_atras) > 22.0 or (punto_atras.x - pos.x) * signo < -2.0:
				continue
			if presion_normalizada(estado, punto_atras, local) > 0.55:
				continue
			candidatos.append({"tipo": "llegada", "destino": punto_atras, "pase_atras": true,
				"companero": int(poseedor["clave"]),
				"valor": _valor_de_desmarque(estado, e, poseedor, punto_atras, "llegada") + 0.8})

	# --- Apoyo: ofrecerse al pie a distancia util -----------------------
	# El apoyo se busca ALREDEDOR DEL ANCLA DE SU ROL, no alrededor de la
	# pelota. Construido como un anillo a quince metros del poseedor, el
	# equipo entero se derrumbaba sobre el balon: medido sobre la linea de
	# base, la posesion controlada subia (51,9% a 57,0% en primera) pero los
	# remates de decima caian de 7,2 a 5,2 por partido, porque nadie
	# quedaba en posicion de rematar. El ancla conserva la profundidad que
	# ya daban el hombro del ultimo defensor y el acompanamiento.
	var lado_apoyo := signf(ancla.y)
	if lado_apoyo == 0.0:
		lado_apoyo = 1.0
	for desplazamiento in [Vector2.ZERO, Vector2(0.0, -6.0), Vector2(0.0, 6.0),
			Vector2(-4.0 * signo, 3.0 * lado_apoyo), Vector2(4.0 * signo, 0.0)]:
		var destino := _destino_legal(estado, ancla + desplazamiento, local)
		candidatos.append({"tipo": "apoyo", "destino": destino, "companero": int(poseedor["clave"]),
			"valor": _valor_de_desmarque(estado, e, poseedor, destino, "apoyo")})

	# --- Ruptura diagonal: por detras de la ultima linea ----------------
	# Diagonal y no recta a proposito: corriendo derecho al arco el
	# delantero se queda en el bolsillo del central que ya lo mira. El
	# largo es el mismo del pase al hueco, asi que la corrida y la pelota
	# se encuentran donde el motor ya sabe tirarla.
	if ROLES_QUE_ROMPEN.has(rol):
		var dir_gol: Vector2 = arco - pos
		if dir_gol.length() < 0.5:
			dir_gol = Vector2(signo, 0.0)
		dir_gol = dir_gol.normalized()
		var largo: float = largo_de_ruptura(float(e["vel_max"]))
		for giro_r in [-0.5, 0.5]:
			var destino_r := _destino_legal(estado, pos + dir_gol.rotated(giro_r) * largo, local)
			candidatos.append({"tipo": "ruptura", "destino": destino_r, "companero": int(poseedor["clave"]),
				"valor": _valor_de_desmarque(estado, e, poseedor, destino_r, "ruptura")})

	# --- Arrastre: llevarse al marcador lejos del carril ----------------
	# Solo tiene sentido si hay un marcador al que llevarse. Mueve al
	# ATACANTE; si el defensor lo acompana o no lo decide su propia marca,
	# aca no se lo toca. El valor crece con cuanto despeja el carril que
	# va del poseedor al arco.
	if ROLES_QUE_ROMPEN.has(rol):
		var marcador := -1
		var d_marcador := 6.0
		for id_r in estado["jugadores"]:
			var r: Dictionary = estado["jugadores"][id_r]
			if r["equipo_local"] == local:
				continue
			var d: float = pos.distance_to(r["pos"])
			if d < d_marcador:
				d_marcador = d
				marcador = int(id_r)
		if marcador != -1:
			var lado := signf(pos.y)
			if lado == 0.0:
				lado = 1.0
			var destino_a := _destino_legal(estado, pos + Vector2(signo * 3.0, lado * 10.0), local)
			var despeja: float = _dist_a_segmento(destino_a, desde, arco) - _dist_a_segmento(pos, desde, arco)
			var valor_a: float = _valor_de_desmarque(estado, e, poseedor, destino_a, "arrastre")
			valor_a += clampf(despeja / 10.0, 0.0, 1.0) * 0.8
			candidatos.append({"tipo": "arrastre", "destino": destino_a, "companero": marcador,
				"valor": valor_a})

	# --- Llegada desde atras: solo si otro ya fija la ultima linea ------
	# Es la segunda linea. Pide dos cosas: que un companero este pegado a
	# la linea de offside, o sea sosteniendo a los centrales, y que el
	# carril por el que entra este libre. Sin la primera condicion el
	# volante entra a un area que todavia esta poblada.
	if ROLES_QUE_LLEGAN.has(rol) and (pos.x - desde.x) * signo < 2.0:
		var fijador := -1
		var linea: Dictionary = estado["linea_offside"]
		var borde_linea: float = float(linea["local"]) if local else float(linea["away"])
		for id_c in estado["jugadores"]:
			var c: Dictionary = estado["jugadores"][id_c]
			if c["equipo_local"] != local or int(id_c) == int(e["clave"]) or c["rol"] == "ARQ":
				continue
			if absf(c["pos"].x - borde_linea) <= 4.0:
				fijador = int(id_c)
				break
		if fijador != -1:
			var borde_area: float = (MEDIO_LARGO - AREA_LARGO) * signo
			for carril in [-10.0, 0.0, 10.0]:
				var punto_l := Vector2(borde_area, carril)
				if pos.distance_to(punto_l) > 30.0:
					continue
				var destino_l := _destino_legal(estado, punto_l, local)
				candidatos.append({"tipo": "llegada", "destino": destino_l, "companero": fijador,
					"valor": _valor_de_desmarque(estado, e, poseedor, destino_l, "llegada")})

	return candidatos


## Una intencion vive mientras el jugador siga en cancha, no se le haya
## vencido el plazo y el destino siga valiendo la pena. La legalidad se
## recorta de nuevo cada tick porque la linea de offside se mueve.
static func _desmarque_sigue_vivo(estado: Dictionary, clave: int, plan: Dictionary) -> bool:
	if int(estado["tick"]) >= int(plan["hasta"]):
		return false
	if not estado["jugadores"].has(clave) or _en_transito(estado, clave):
		return false
	var e: Dictionary = estado["jugadores"][clave]
	var local: bool = e["equipo_local"]
	# Si su rol le cerro el objetivo mientras corria el plazo (el delantero
	# bajo a recibir porque la pelota retrocedio), la intencion ya no la lee
	# nadie: se cancela para liberar el cupo.
	if bool(_ancla_de_rol(estado, e, _equipo_de(estado, local), true)["listo"]):
		return false
	var destino: Vector2 = _destino_legal(estado, plan["destino"], local)
	if presion_normalizada(estado, destino, local) > PRESION_DESTINO_INVIABLE:
		return false
	plan["destino"] = destino
	return true


## Reparte las intenciones del equipo que ataca. Se llama una vez por
## tick; solo recalcula cada TICKS_DESMARQUE_MIN, y siempre desde la
## misma instantanea de posiciones.
static func _planificar_desmarques(estado: Dictionary, ataca_local: bool) -> void:
	var planes: Dictionary = estado.get("desmarques", {})
	estado["desmarques"] = planes
	# El juego detenido no tiene desmarques: los 22 caminan a su marca.
	if int(estado.get("detenido", 0)) > 0:
		planes.clear()
		return
	# La perdida cancela TODO: las rupturas eran para esa posesion.
	if bool(estado.get("desmarques_local", ataca_local)) != ataca_local:
		planes.clear()
		estado["desmarques_hasta"] = -1
	estado["desmarques_local"] = ataca_local

	for clave in planes.keys():
		if not _desmarque_sigue_vivo(estado, int(clave), planes[clave]):
			planes.erase(clave)

	var tick: int = int(estado["tick"])
	if tick < int(estado.get("desmarques_hasta", -1)):
		return
	estado["desmarques_hasta"] = tick + TICKS_DESMARQUE_MIN

	var id_poseedor: int = int(estado["pelota"]["poseedor_id"])
	if id_poseedor == -1 or not estado["jugadores"].has(id_poseedor):
		return
	var poseedor: Dictionary = estado["jugadores"][id_poseedor]
	if bool(poseedor["equipo_local"]) != ataca_local:
		return

	# Orden estable por clave: dos corridas con la misma semilla reparten
	# igual, sin depender del orden en que el diccionario devuelve llaves.
	var claves := []
	for id in estado["jugadores"]:
		claves.append(int(id))
	claves.sort()

	var rupturas_vivas := 0
	var hay_apoyo := false
	var ocupados := []
	for clave_v in planes:
		var p: Dictionary = planes[clave_v]
		ocupados.append(p["destino"])
		if str(p["tipo"]) == "ruptura" or str(p["tipo"]) == "llegada":
			rupturas_vivas += 1
		elif str(p["tipo"]) == "apoyo":
			hay_apoyo = true

	var pendientes := []
	for clave in claves:
		if planes.has(clave):
			continue
		var e: Dictionary = estado["jugadores"][clave]
		if bool(e["equipo_local"]) != ataca_local or clave == id_poseedor:
			continue
		if e["rol"] == "ARQ" or e["rol"] == "DFC" or _en_transito(estado, clave):
			continue
		# El que ya tiene objetivo cerrado —el nueve que baja a recibir— no
		# entra al reparto: su movimiento lo decide el ancla y una intencion
		# para el se anotaria sin que nadie la lea, ocupando ademas el cupo
		# del apoyo de seguridad.
		var ancla := _ancla_de_rol(estado, e, _equipo_de(estado, ataca_local), true)
		if bool(ancla["listo"]):
			continue
		var candidatos := _candidatos_desmarque(estado, e, poseedor, ancla["punto"])
		if bool(estado.get("medir_opciones_colectivas", false)):
			for candidato in candidatos:
				for marca in ["doblamiento", "pase_atras", "diagonal_extremo", "nueve_baja", "relevo_nueve"]:
					if bool(candidato.get(marca, false)):
						_contar_jugada(estado, "candidato_" + marca)
		if candidatos.is_empty():
			continue
		pendientes.append({"clave": clave, "candidatos": candidatos})

	# Primero el apoyo de seguridad: si nadie esta ofreciendose al pie, se
	# reserva al mejor ANTES de repartir corridas. Sin esta reserva el
	# reparto premia siempre a los que progresan y el poseedor se queda
	# sin ninguna opcion corta.
	if not hay_apoyo:
		var mejor_seguro := {}
		for p_i in pendientes:
			for c in p_i["candidatos"]:
				if str(c["tipo"]) != "apoyo":
					continue
				if mejor_seguro.is_empty() or float(c["valor"]) > float(mejor_seguro["candidato"]["valor"]):
					mejor_seguro = {"clave": int(p_i["clave"]), "candidato": c}
		if not mejor_seguro.is_empty():
			_anotar_desmarque(estado, planes, int(mejor_seguro["clave"]), mejor_seguro["candidato"])
			ocupados.append(mejor_seguro["candidato"]["destino"])
			for i in range(pendientes.size()):
				if int(pendientes[i]["clave"]) == int(mejor_seguro["clave"]):
					pendientes.remove_at(i)
					break

	# Asignacion voraz estable: el que mas gana elige primero. No se busca
	# la combinacion optima —con 22 jugadores eso no se paga— y el empate
	# lo rompe el orden de la lista, que ya viene ordenada por clave.
	var w := pesos_sin_pelota()
	# Etapa 7: cuantos pueden estar corriendo a la vez lo decide el
	# marcador. Ganando sobre la hora queda uno solo y el resto sostiene
	# apoyos; perdiendo sale uno mas, que es aceptar el espacio de atras.
	var cupo_rupturas := _cupo_de_rupturas(estado, ataca_local)
	while not pendientes.is_empty():
		var elegido := -1
		var mejor_c := {}
		var mejor_valor := -INF
		for i in range(pendientes.size()):
			var p_i: Dictionary = pendientes[i]
			for c in p_i["candidatos"]:
				var es_corrida: bool = str(c["tipo"]) == "ruptura" or str(c["tipo"]) == "llegada"
				if es_corrida and rupturas_vivas >= cupo_rupturas:
					continue
				# Dos destinos pegados no son dos opciones: se penaliza el
				# segundo en vez de prohibirlo, asi el jugador puede igual
				# elegirlo si no tiene nada mejor.
				var valor: float = float(c["valor"])
				for o in ocupados:
					var d: float = (o as Vector2).distance_to(c["destino"])
					if d < SEPARACION_DESMARQUE:
						valor -= float(w["conflicto"]) * (1.0 - d / SEPARACION_DESMARQUE)
				if valor > mejor_valor:
					mejor_valor = valor
					mejor_c = c
					elegido = i
		if elegido == -1 or mejor_valor < float(w["minimo"]):
			break
		_anotar_desmarque(estado, planes, int(pendientes[elegido]["clave"]), mejor_c)
		ocupados.append(mejor_c["destino"])
		if str(mejor_c["tipo"]) == "ruptura" or str(mejor_c["tipo"]) == "llegada":
			rupturas_vivas += 1
		pendientes.remove_at(elegido)


## Anota una intencion y calcula cuanto dura: el tiempo que tarda en
## llegar, acotado entre el piso y el techo. El que va lejos sostiene la
## corrida; el que se acomoda dos metros vuelve a evaluar enseguida.
static func _anotar_desmarque(estado: Dictionary, planes: Dictionary, clave: int, candidato: Dictionary) -> void:
	for marca in ["pase_atras", "doblamiento", "diagonal_extremo", "nueve_baja", "relevo_nueve", "cambio_frente"]:
		if bool(candidato.get(marca, false)):
			_contar_jugada(estado, "plan_" + marca)
	var e: Dictionary = estado["jugadores"][clave]
	var viaje: float = e["pos"].distance_to(candidato["destino"]) / maxf(float(e["vel_max"]), 0.01)
	var ticks: int = clampi(int(round(viaje / TICK_SEG)), TICKS_DESMARQUE_MIN, TICKS_DESMARQUE_MAX)
	# Sostener la descarga hasta el siguiente reparto permite coordinar el relevo.
	if bool(candidato.get("nueve_baja", false)) or bool(candidato.get("pase_atras", false)):
		ticks = mini(ticks + TICKS_DESMARQUE_MIN, TICKS_DESMARQUE_MAX)
	planes[clave] = {
		"tipo": str(candidato["tipo"]),
		"destino": candidato["destino"],
		"companero": int(candidato["companero"]),
		"hasta": int(estado["tick"]) + ticks,
		"pase_atras": bool(candidato.get("pase_atras", false)),
		"doblamiento": bool(candidato.get("doblamiento", false)),
		"diagonal_extremo": bool(candidato.get("diagonal_extremo", false)),
		"nueve_baja": bool(candidato.get("nueve_baja", false)),
		"espacio_nueve": candidato.get("espacio_nueve", e["pos"]),
		"relevo_nueve": bool(candidato.get("relevo_nueve", false)),
	}


## El destino de la intencion vigente de este jugador, o null si no tiene.
## Lo leen el movimiento sin pelota y los tests.
static func _buscar_tercer_hombre(estado: Dictionary, pasador: Dictionary, apoyo: Dictionary) -> Dictionary:
	var local: bool = pasador["equipo_local"]
	if apoyo["rol"] == "ARQ":
		return {}
	var jugador := _dict_jugador(estado, _equipo_de(estado, local), apoyo["jugador_id"])
	var f: Dictionary = pesos()["fisica"]
	if jugador.is_empty() or float(jugador["atributos"]["pases"]) < float(f["pases_minimo_pared"]):
		return {}
	var alcance := _por_atributo(jugador, "pases", f["max_dist_pase_malo"], f["max_dist_pase_bueno"], 1.0)
	var riesgo_inicial := riesgo_linea(estado, pasador["pos"], apoyo["pos"], local)
	var limite := float(pesos_sin_pelota()["pared_riesgo_max"])
	if riesgo_inicial > limite:
		return {}
	var mejor := {}
	var valor_mejor := -INF
	for clave in estado.get("desmarques", {}):
		if clave == pasador["clave"] or clave == apoyo["clave"] or not estado["jugadores"].has(clave):
			continue
		var corredor: Dictionary = estado["jugadores"][clave]
		var plan: Dictionary = estado["desmarques"][clave]
		if corredor["equipo_local"] != local or corredor["rol"] == "ARQ" or plan.get("tipo", "") not in ["ruptura", "llegada"]:
			continue
		var destino: Vector2 = plan["destino"]
		if (destino.x - corredor["pos"].x) * (1.0 if local else -1.0) <= 2.0:
			continue
		if apoyo["pos"].distance_to(destino) > alcance:
			continue
		var progreso := valor_posicion(destino, local) - valor_posicion(pasador["pos"], local)
		var riesgo := riesgo_linea(estado, apoyo["pos"], destino, local)
		var valor := progreso + (1.0 - riesgo) * 0.3
		if progreso > 0.03 and riesgo <= limite and valor > valor_mejor:
			valor_mejor = valor
			mejor = {"clave": clave, "destino": destino, "riesgo": maxf(riesgo, riesgo_inicial)}
	return mejor


static func desmarque_de(estado: Dictionary, clave: int):
	var plan: Dictionary = estado.get("desmarques", {}).get(clave, {})
	if plan.is_empty():
		return null
	return plan["destino"]


## §4.4: los 21 sin pelota se mueven con matemática de vectores barata —
## nada de utilidad ni softmax, tal como exige la restricción de
## rendimiento. La posición objetivo es su base de formación desplazada
## hacia donde está la pelota, con el peso de su rol; el estilo del equipo
## decide cuánto persigue la pelota cuando NO la tiene (Presión alta la va
## a buscar de verdad, Defensivo se repliega).
## El ANCLA es donde lo pone su rol: casillero de formacion corrido por
## la pelota, el estilo, el repliegue, el acompanamiento y el hombro del
## ultimo defensor. Todavia no incluye el desmarque.
##
## Esta separado de _objetivo_sin_pelota porque el reparto de desmarques
## (etapa 1) necesita el ancla de cada jugador ANTES de elegirle destino,
## y llamar al objetivo completo seria circular. Devuelve tambien `listo`:
## el arquero y el delantero que baja a recibir ya tienen su objetivo
## final y no pasan ni por el desmarque ni por el recorte de offside.
static func _ancla_de_rol(estado: Dictionary, e: Dictionary, equipo: Team, tiene_pelota_mi_equipo: bool) -> Dictionary:
	var f: Dictionary = pesos()["fisica"]
	var pelota_pos: Vector2 = estado["pelota"]["pos"]
	var rol: String = e["rol"]
	var base: Vector2 = e["base"]
	var ax: float = ATRACCION_X.get(rol, 0.6)
	var ay: float = ATRACCION_Y.get(rol, 0.3)

	var objetivo_x: float = base.x + pelota_pos.x * ax
	var objetivo_y: float = base.y + (pelota_pos.y - base.y) * ay

	# El arquero queda AFUERA del desplazamiento por estilo. El estilo
	# corre la línea de los diez de campo; al arquero lo único que lo
	# mueve es dónde está la pelota (ATRACCION_X). Con los 16 metros del
	# estilo encima, Presión alta lo paraba en el borde del área: medido
	# con tests/_diag_arquero_posicion.gd, 7,37 m de su línea de media,
	# 32% del partido a más de 10 m, y 6,68 m afuera EN EL MOMENTO de
	# atajar. De ahí salía que la pelota lo pasara de largo.
	if not tiene_pelota_mi_equipo and rol != "ARQ":
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
		# Etapa 7: el marcador corre la linea igual que el estilo, sobre el
		# mismo eje y en metros. Perdiendo la sube, ganando la baja. El
		# tope (altura_bloque) es la mitad de lo que separa a Presion alta
		# de Defensivo: el resultado inclina la identidad del equipo, no la
		# reemplaza.
		var urg_bloque: float = urgencia(estado, bool(e["equipo_local"]))
		objetivo_x += urg_bloque * float(pesos_marcador()["altura_bloque"]) * hacia_rival
	if rol == "ARQ":
		# Su propio corral: entre la línea y el borde del área.
		if e["equipo_local"]:
			objetivo_x = clampf(objetivo_x, -ARQUERO_X_MIN, -ARQUERO_X_MAX)
		else:
			objetivo_x = clampf(objetivo_x, ARQUERO_X_MAX, ARQUERO_X_MIN)
		return {"punto": Vector2(objetivo_x, clampf(objetivo_y, -ARCO_MEDIO_ANCHO * 2.2, ARCO_MEDIO_ANCHO * 2.2)), "listo": true}
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
			return {"punto": Vector2(clampf(objetivo_x, -LIMITE_X, LIMITE_X),
				clampf(objetivo_y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0)), "listo": true}
		var linea_ataque: Dictionary = estado["linea_offside"]
		# Dónde se para respecto de la línea: el que mide bien el
		# desmarque se queda un metro detrás, el que no la calcula se pasa
		# y queda habilitando el offside. Este offset ES la fuente de los
		# offsides — con un "siempre un metro detrás" fijo, nadie se iba
		# nunca y la infracción no ocurría jamás.
		var intel: float = clampf(float(e.get("inteligencia", 50.0)) / 100.0, 0.0, 1.0)
		var offset: float = lerpf(float(f["offside_margen_torpe"]), -1.5, intel) * float(e.get("margen_offside", 1.0))
		var subida: float = smoothstep(float(f["avance_para_jugar_en_el_hombro"]), float(f["avance_para_centrar"]), avance)
		if e["equipo_local"]:
			objetivo_x = lerpf(objetivo_x, maxf(objetivo_x, float(linea_ataque["local"]) + offset), subida)
		else:
			objetivo_x = lerpf(objetivo_x, minf(objetivo_x, float(linea_ataque["away"]) - offset), subida)

	# La correa del bloque: el que defiende y no tiene papel asignado no se
	# va detras de la pelota hasta la otra punta. Bascula y se adelanta
	# hasta el radio de su rol; para atras no tiene limite.
	if not tiene_pelota_mi_equipo:
		return {"punto": _recortar_a_la_zona(e, Vector2(objetivo_x, objetivo_y)), "listo": false}

	return {"punto": Vector2(objetivo_x, objetivo_y), "listo": false}


## §4.4: los 21 sin pelota se mueven con matematica de vectores barata —
## nada de utilidad ni softmax, tal como exige la restriccion de
## rendimiento. Sobre el ancla de su rol (ver _ancla_de_rol) se le suma el
## desmarque: el que le repartió el equipo si tiene uno, y si no el apoyo
## que se busca solo.
static func _objetivo_sin_pelota(estado: Dictionary, e: Dictionary, equipo: Team, tiene_pelota_mi_equipo: bool) -> Vector2:
	var f: Dictionary = pesos()["fisica"]
	var rol: String = e["rol"]
	var ancla := _ancla_de_rol(estado, e, equipo, tiene_pelota_mi_equipo)
	if bool(ancla["listo"]):
		# Etapa 6: el arquero sigue su intencion (achicar, salir a cortar);
		# sin una, su ancla.
		if rol == "ARQ":
			return _objetivo_del_arquero(estado, e, ancla["punto"])
		return ancla["punto"]
	var objetivo_x: float = (ancla["punto"] as Vector2).x
	var objetivo_y: float = (ancla["punto"] as Vector2).y

	if tiene_pelota_mi_equipo and rol != "DFC":
		# La intencion del reparto colectivo manda sobre el apoyo que
		# calcularia el jugador por su cuenta: es el mismo movimiento
		# —ofrecerse, romper, llegar— pero acordado con los otros diez, y
		# sostenido varios ticks en vez de recalculado en cada foto. El
		# apoyo individual queda como fallback para el que no recibio
		# ninguna (ver _planificar_desmarques).
		var destino_plan = desmarque_de(estado, int(e["clave"]))
		if destino_plan != null:
			objetivo_x = (destino_plan as Vector2).x
			objetivo_y = (destino_plan as Vector2).y
		else:
			var apoyo := _buscar_apoyo(estado, e, equipo, Vector2(objetivo_x, objetivo_y))
			objetivo_x = apoyo.x
			objetivo_y = apoyo.y

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

	# Etapa 5: la reserva de sprint baja el techo de la corrida, no el trote.
	# Por eso es un minimo contra el factor y no un multiplicador: el que
	# camina a su marca no nota que viene de piques. El factor mayor que
	# uno es del que entra o sale de la cancha, que no juega la jugada.
	var techo: float = factor if factor > 1.0 else minf(factor, capacidad_de_sprint(e))
	var tope: float = float(e["vel_max"]) * techo
	rapidez = minf(rapidez + float(e.get("aceleracion", 3.0)) * TICK_SEG, tope)
	# Etapa 3: corriendo, el cuerpo sigue a la carrera con giro limitado. Al
	# trote se sigue mirando la jugada (ver _mirar_la_pelota).
	if rapidez >= float(pesos_control()["rapidez_para_girar"]):
		girar_hacia(e, dir)
	var paso: float = rapidez * TICK_SEG
	e["recorrido"] = float(e.get("recorrido", 0.0)) + minf(paso, dist)
	if paso >= dist:
		e["pos"] = objetivo
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
		return
	e["pos"] = e["pos"] + dir * paso
	e["vel"] = dir * rapidez
	e["rapidez"] = rapidez


# ---------------------------------------------------------------------------
# Control y orientacion corporal (etapa 3)
# ---------------------------------------------------------------------------
## Hasta la etapa 3 el motor no sabia hacia donde miraba nadie. Recibir de
## frente o de espaldas costaba lo mismo, y la unica demora de control era
## `fisica.ticks_control`: una espera fija por atributo antes de decidir.
##
## Ahora cada jugador tiene:
##
## - `orientacion`: vector normalizado en el dict espacial. Gira con
##   velocidad angular limitada por `agilidad` (`giro`, radianes por
##   segundo). Corriendo sigue a la carrera; al trote o quieto mira la pelota.
## - Control pendiente: `pelota.control`, con la clave del receptor y su
##   demora en ticks. Vive en la pelota porque se borra en el mismo lugar
##   donde cambia el poseedor (_entregar_pelota, el arquero y el saque).
## - Habilitacion de la accion: el poseedor decide recien cuando
##   `ticks_con_pelota` llega a la demora. Es el mismo contador que usaba la
##   espera vieja, asi que sin control pendiente el motor decide igual que
##   antes.
##
## La recepcion de un pase se resuelve UNA vez (_controlar_recepcion):
## calcula la dificultad, tira una vez el RNG del partido y decide entre
## control limpio, con su demora, o toque largo con la pelota suelta.

## Pesos de la etapa. Como en las otras etapas, el lector trae los valores
## por defecto y queda cacheado: `rapidez_para_girar` se lee en cada paso de
## cada jugador.
static var _pesos_control_cache: Dictionary = {}

static func pesos_control() -> Dictionary:
	if not _pesos_control_cache.is_empty():
		return _pesos_control_cache
	var d: Dictionary = pesos().get("control", {})
	_pesos_control_cache = {
		"giro_lento": float(d.get("giro_lento", 4.0)),
		"giro_rapido": float(d.get("giro_rapido", 9.0)),
		"rapidez_para_girar": float(d.get("rapidez_para_girar", 2.0)),
		"cono_sin_giro": float(d.get("cono_sin_giro", 2.0)),
		"peso_velocidad": float(d.get("peso_velocidad", 0.3)),
		"peso_altura": float(d.get("peso_altura", 0.2)),
		"peso_presion": float(d.get("peso_presion", 0.3)),
		"peso_angulo": float(d.get("peso_angulo", 0.2)),
		"demora_facil": float(d.get("demora_facil", 0.6)),
		"demora_dificil": float(d.get("demora_dificil", 1.6)),
		"malo_max": float(d.get("malo_max", 0.3)),
		"alivio_control": float(d.get("alivio_control", 0.8)),
		"mezcla_absoluta": float(d.get("mezcla_absoluta", 0.5)),
		"toque_largo_min": float(d.get("toque_largo_min", 2.0)),
		"toque_largo_max": float(d.get("toque_largo_max", 6.0)),
		"toque_desvio": float(d.get("toque_desvio", 0.9)),
	}
	return _pesos_control_cache


## Hacia donde mira un equipo formado: al arco que ataca.
static func orientacion_inicial(es_local: bool) -> Vector2:
	return Vector2(1.0, 0.0) if es_local else Vector2(-1.0, 0.0)


## Radianes por segundo que gira este jugador. `agilidad` se lee absoluta,
## como la velocidad: girar es fisico y no depende del rival.
static func _giro_de(jugador: Dictionary) -> float:
	var w := pesos_control()
	return _por_atributo(jugador, "agilidad", w["giro_lento"], w["giro_rapido"], 1.0)


## La orientacion de un dict espacial, siempre normalizada. Un dict viejo sin
## el campo mira al arco que ataca.
static func orientacion_de(e: Dictionary) -> Vector2:
	var o = e.get("orientacion", null)
	if o is Vector2 and o.length_squared() > 0.000001:
		return o.normalized()
	return orientacion_inicial(bool(e.get("equipo_local", true)))


## Gira el cuerpo un tick hacia `hacia`, sin pasar del giro maximo. Un
## vector nulo no cambia nada: normalizarlo daria cualquier cosa.
static func girar_hacia(e: Dictionary, hacia: Vector2) -> void:
	if hacia.length_squared() < 0.000001:
		return
	var objetivo: Vector2 = hacia.normalized()
	var actual := orientacion_de(e)
	var angulo: float = actual.angle_to(objetivo)
	var maximo: float = float(e.get("giro", pesos_control()["giro_lento"])) * TICK_SEG
	if absf(angulo) <= maximo:
		e["orientacion"] = objetivo
	else:
		e["orientacion"] = actual.rotated(signf(angulo) * maximo)


## Ticks que tarda en dejar `hacia` dentro del cono en que juega sin girar.
## Cero si ya esta adentro.
static func ticks_para_girar(e: Dictionary, hacia: Vector2) -> int:
	if hacia.length_squared() < 0.000001:
		return 0
	var exceso: float = absf(orientacion_de(e).angle_to(hacia)) - float(pesos_control()["cono_sin_giro"])
	if exceso <= 0.0:
		return 0
	var por_tick: float = maxf(float(e.get("giro", pesos_control()["giro_lento"])) * TICK_SEG, 0.01)
	return int(ceil(exceso / por_tick))


## Los que no corren miran la pelota. Corre despues de mover a todos, asi
## que no le suma giro al que ya giro corriendo: ese quedo por encima de
## `rapidez_para_girar`. El poseedor no entra aca; lo gira _conducir.
static func _mirar_la_pelota(estado: Dictionary) -> void:
	var umbral: float = float(pesos_control()["rapidez_para_girar"])
	var pelota_pos: Vector2 = estado["pelota"]["pos"]
	var poseedor: int = int(estado["pelota"]["poseedor_id"])
	for id in estado["jugadores"]:
		if int(id) == poseedor:
			continue
		var e: Dictionary = estado["jugadores"][id]
		if float(e.get("rapidez", 0.0)) >= umbral:
			continue
		girar_hacia(e, pelota_pos - e["pos"])


## Espera vieja antes de decidir, en ticks: `fisica.ticks_control` segun
## `control`, acortada por la asociacion del estilo. Sigue siendo la cadencia
## con que el poseedor reconsidera mientras conduce, y la demora de cualquier
## posesion que no empieza con una recepcion (quite, rebote, arquero).
static func cadencia_de_decision(jugador: Dictionary, equipo: Team) -> int:
	var f: Dictionary = pesos()["fisica"]
	var ticks: int = int(round(_por_atributo(jugador, "control", f["ticks_control_malo"], f["ticks_control_bueno"])))
	var asociacion: float = float(Estilos.plan(equipo.estilo)["asociacion"])
	ticks = int(round(float(ticks) * lerpf(1.0, 0.75, asociacion)))
	return maxi(ticks, 1)


## Que tan dificil es controlar la pelota que llega. Cuenta pura: no toca el
## RNG ni al jugador. Devuelve los cuatro terminos por separado para medir.
##
## - velocidad: 0 a la velocidad del pase mas flojo, 1 a la del mas fuerte.
## - altura: la altura maxima del vuelo contra la del centro.
## - presion: la misma presion normalizada que usan las decisiones.
## - angulo: 0 con la pelota llegando de frente al cuerpo, 1 por la espalda.
static func dificultad_de_recepcion(estado: Dictionary, e: Dictionary, vel_llegada: Vector2,
		altura: float) -> Dictionary:
	var f: Dictionary = pesos()["fisica"]
	var w := pesos_control()
	var v: float = vel_llegada.length()
	var t_vel: float = clampf((v - float(f["vel_pase_min"]))
			/ maxf(float(f["vel_pase_max"]) - float(f["vel_pase_min"]), 0.01), 0.0, 1.0)
	var t_alt: float = clampf(altura / maxf(float(f["altura_centro"]), 0.01), 0.0, 1.0)
	var t_pres: float = presion_normalizada(estado, e["pos"], bool(e["equipo_local"]))
	# Sin velocidad no hay de donde llega: el angulo queda en el medio.
	var t_ang := 0.5
	if v > 0.01:
		t_ang = (1.0 - orientacion_de(e).dot(-vel_llegada / v)) * 0.5
	var d: float = float(w["peso_velocidad"]) * t_vel + float(w["peso_altura"]) * t_alt \
			+ float(w["peso_presion"]) * t_pres + float(w["peso_angulo"]) * t_ang
	return {"dificultad": clampf(d, 0.0, 1.0), "velocidad": t_vel, "altura": t_alt,
			"presion": t_pres, "angulo": t_ang}


## Ticks hasta poder jugar la pelota recibida. Reemplaza a la espera vieja
## en la primera decision: la escala por la dificultad, no se le suma.
static func demora_de_control(jugador: Dictionary, equipo: Team, dificultad: float) -> int:
	var w := pesos_control()
	var f: Dictionary = pesos()["fisica"]
	# Los mismos redondeos que cadencia_de_decision: con factor 1 la demora
	# da exactamente la espera vieja.
	var base: float = float(int(round(_por_atributo(jugador, "control", f["ticks_control_malo"], f["ticks_control_bueno"]))))
	base *= lerpf(1.0, 0.75, float(Estilos.plan(equipo.estilo)["asociacion"]))
	var factor: float = lerpf(float(w["demora_facil"]), float(w["demora_dificil"]), clampf(dificultad, 0.0, 1.0))
	return maxi(int(round(base * factor)), 1)


## Chance de que la recepcion termine en toque largo. Crece con la dificultad
## y baja con `control`: con dificultad cero nadie la pierde.
static func prob_toque_largo(jugador: Dictionary, dificultad: float) -> float:
	var w := pesos_control()
	var control: float = _por_atributo(jugador, "control", 0.0, 1.0, float(w["mezcla_absoluta"]))
	return clampf(float(w["malo_max"]) * clampf(dificultad, 0.0, 1.0)
			* (1.0 - float(w["alivio_control"]) * control), 0.0, 1.0)


## La recepcion de un pase, una sola vez. La llama _resolver_recepcion con
## la velocidad y la altura capturadas ANTES de que la pelota frenara o se
## le entregara al receptor.
static func _controlar_recepcion(estado: Dictionary, clave: int, llegada: Dictionary) -> void:
	if not estado["jugadores"].has(clave):
		return
	var e: Dictionary = estado["jugadores"][clave]
	# El arquero la toma con las manos o la para con su propia rama.
	if str(e["rol"]) == "ARQ":
		return
	var equipo := _equipo_de(estado, bool(e["equipo_local"]))
	var jugador := _dict_jugador(estado, equipo, int(e["jugador_id"]))
	if jugador.is_empty():
		return
	var vel: Vector2 = llegada.get("vel", Vector2.ZERO)
	var desc := dificultad_de_recepcion(estado, e, vel, float(llegada.get("altura", 0.0)))
	var dificultad: float = float(desc["dificultad"])
	if not estado.has("control_stats"):
		estado["control_stats"] = {}
	var stats: Dictionary = estado["control_stats"]
	for clave_stat in ["recepciones", "toques_largos", "demora", "cadencia"]:
		if not stats.has(clave_stat):
			stats[clave_stat] = 0
	stats["recepciones"] = int(stats["recepciones"]) + 1
	for termino in ["dificultad", "velocidad", "altura", "presion", "angulo"]:
		stats[termino] = float(stats.get(termino, 0.0)) + float(desc[termino])
	if estado["rng"].randf() < prob_toque_largo(jugador, dificultad):
		stats["toques_largos"] = int(stats["toques_largos"]) + 1
		_toque_largo(estado, e, vel, dificultad)
		return
	var demora := demora_de_control(jugador, equipo, dificultad)
	stats["demora"] = int(stats["demora"]) + demora
	stats["cadencia"] = int(stats["cadencia"]) + cadencia_de_decision(jugador, equipo)
	estado["pelota"]["control"] = {"clave": clave, "demora": demora}


## Control malo: la pelota se le va unos metros en la direccion en que venia,
## desviada. Queda suelta y la agarra el que llegue: el receptor la va a
## buscar y el rival tambien. No se le adjudica a nadie.
static func _toque_largo(estado: Dictionary, e: Dictionary, vel: Vector2, dificultad: float) -> void:
	var w := pesos_control()
	var rng: RandomNumberGenerator = estado["rng"]
	var base: Vector2 = vel.normalized() if vel.length_squared() > 0.0001 else orientacion_de(e)
	var dir: Vector2 = base.rotated(rng.randf_range(-1.0, 1.0) * float(w["toque_desvio"]))
	var largo: float = lerpf(float(w["toque_largo_min"]), float(w["toque_largo_max"]),
			clampf(dificultad * (0.5 + rng.randf()), 0.0, 1.0))
	var desde: Vector2 = e["pos"]
	var destino := Vector2(
		clampf(desde.x + dir.x * largo, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
		clampf(desde.y + dir.y * largo, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	_soltar_pelota(estado, desde, destino, bool(e["equipo_local"]))
	var pelota: Dictionary = estado["pelota"]
	# Rueda en dos ticks: a la velocidad del rebote llegaba en uno y no se
	# veia que se le escapaba.
	var real: float = desde.distance_to(destino)
	pelota["vel"] = (destino - desde).normalized() * maxf(real / (2.0 * TICK_SEG), VEL_PELOTA_QUIETA) \
			if real > 0.01 else Vector2.ZERO
	pelota["offside"] = false
	pelota["es_centro"] = false
	pelota["es_remate"] = false
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota.erase("pared_a")
	# El receptor sale a buscar su propio toque (ver `esperando` en _tick).
	pelota["destino_id"] = int(e["clave"])


## Saca las opciones que mandan la pelota fuera del cono del cuerpo. Girar
## 180 grados con la pelota exige tiempo: esas opciones vuelven cuando el
## cuerpo gira. Conducir, gambeta y despeje no tienen destino y quedan.
static func _opciones_orientadas(estado: Dictionary, opciones: Array, poseedor: Dictionary) -> Array:
	var es_local: bool = bool(poseedor["equipo_local"])
	var quedan: Array = []
	for op in opciones:
		var destino = _destino_de_opcion(estado, op, es_local)
		if destino == null or ticks_para_girar(poseedor, destino - poseedor["pos"]) == 0:
			quedan.append(op)
	return quedan


# ---------------------------------------------------------------------------
# Cansancio por esfuerzo (etapa 5)
# ---------------------------------------------------------------------------
## Hasta la etapa 5 la resistencia solo bajaba en los duelos: el volante que
## corria el partido entero terminaba igual que el que miraba de lejos. La
## linea de base lo medía: el cansancio dependia de los duelos jugados y no
## de los metros corridos.
##
## Ahora hay dos costos, y cada uno tiene UN solo responsable:
##
## - Correr: `_contabilizar_esfuerzo`, una vez por tick y por jugador. Lee
##   la rapidez que dejo el movimiento y cobra por intensidad.
## - El contacto: `_duelo_simple` y el duelo del remate, como antes, pero
##   con `multiplicador_desgaste` mas chico, porque ya no pagan el partido
##   entero. Ninguno de los dos mira la rapidez, asi que no se cobra dos
##   veces el mismo pique.
##
## Hay dos depositos distintos:
##
## - La RESERVA de sprint, de 0 a 1, en el dict espacial del jugador. Se
##   gasta en segundos de pique y se recupera en segundos de trote. Corre en
##   `TICK_SEG` reales: es la fisica de la jugada, no los 90 minutos.
## - La RESISTENCIA de siempre, en `Team`. Es la fatiga acumulada del
##   partido; la reserva no la toca y caminar no la devuelve.
##
## La resistencia sigue afectando la ejecucion solo por
## `Duel.atributo_efectivo`. La reserva solo baja la velocidad punta.

## Pesos del esfuerzo. Como los de las otras etapas, el lector trae los
## valores por defecto y el resultado queda cacheado: se lee 22 veces por
## tick.
static var _pesos_esfuerzo_cache: Dictionary = {}

static func pesos_esfuerzo() -> Dictionary:
	if not _pesos_esfuerzo_cache.is_empty():
		return _pesos_esfuerzo_cache
	var d: Dictionary = pesos().get("esfuerzo", {})
	_pesos_esfuerzo_cache = {
		"peso_aceleracion": float(d.get("peso_aceleracion", 0.5)),
		"umbral_sprint": float(d.get("umbral_sprint", 0.55)),
		"consumo_sprint": float(d.get("consumo_sprint", 0.10)),
		"recuperacion_reserva": float(d.get("recuperacion_reserva", 0.07)),
		"reserva_para_frenar": float(d.get("reserva_para_frenar", 0.5)),
		"piso_sprint": float(d.get("piso_sprint", 0.85)),
		"desgaste_por_segundo": float(d.get("desgaste_por_segundo", 0.0)),
		"recuperacion_entretiempo": float(d.get("recuperacion_entretiempo", 0.0)),
		"tope_entretiempo": float(d.get("tope_entretiempo", 0.0)),
	}
	return _pesos_esfuerzo_cache


## Cuanto le cuesta a un jugador el tick que acaba de correr. Es el cuadrado
## de su rapidez sobre su velocidad punta, mas lo que acelero sobre lo mas
## que puede acelerar en un tick. El cuadrado hace que trotar a media
## maquina cueste un cuarto de un pique, y la aceleracion cobra el arranque
## aunque todavia vaya despacio.
static func intensidad_de_esfuerzo(rapidez: float, rapidez_previa: float,
		vel_max: float, aceleracion: float, w: Dictionary = {}) -> float:
	if w.is_empty():
		w = pesos_esfuerzo()
	var v: float = clampf(rapidez / maxf(vel_max, 0.1), 0.0, 1.0)
	var arranque: float = clampf(maxf(rapidez - rapidez_previa, 0.0) / maxf(aceleracion * TICK_SEG, 0.01), 0.0, 1.0)
	return v * v + float(w["peso_aceleracion"]) * arranque


## Que fraccion de su velocidad punta le deja la reserva. Con la reserva por
## encima de `reserva_para_frenar` no pierde nada; debajo cae de forma suave
## hasta `piso_sprint`. La curva suave evita un escalon en la velocidad del
## tick en que la reserva cruza el umbral.
static func capacidad_de_sprint(e: Dictionary) -> float:
	var reserva: float = float(e.get("reserva", 1.0))
	# Camino corto: casi siempre la reserva esta llena, y esto corre en cada
	# paso de cada jugador.
	if reserva >= 1.0:
		return 1.0
	var w := pesos_esfuerzo()
	var t: float = clampf(reserva / maxf(float(w["reserva_para_frenar"]), 0.01), 0.0, 1.0)
	return lerpf(float(w["piso_sprint"]), 1.0, t * t * (3.0 - 2.0 * t))


## Mueve la reserva un tick. Por encima del umbral gasta en proporcion a lo
## que se paso; por debajo recupera, mas cuanto mas despacio va. Parado
## recupera la tasa completa.
static func actualizar_reserva(e: Dictionary, intensidad: float, w: Dictionary = {}) -> void:
	if w.is_empty():
		w = pesos_esfuerzo()
	var umbral: float = float(w["umbral_sprint"])
	var reserva: float = float(e.get("reserva", 1.0))
	if intensidad > umbral:
		var tope: float = 1.0 + float(w["peso_aceleracion"])
		reserva -= float(w["consumo_sprint"]) * (intensidad - umbral) / maxf(tope - umbral, 0.01) * TICK_SEG
	elif reserva < 1.0:
		reserva += float(w["recuperacion_reserva"]) * (1.0 - intensidad / maxf(umbral, 0.01)) * TICK_SEG
	e["reserva"] = clampf(reserva, 0.0, 1.0)


## El cobro del esfuerzo, una vez por tick, al cerrar el tick. Va despues de
## todo el movimiento, asi que lee la rapidez final de cada uno.
##
## `en_juego` es false en el juego detenido: festejo, falta, cambio. Ahi la
## reserva se recupera —el que trota a su marca respira— pero la
## resistencia no se cobra. Tampoco se cobra al que esta entrando o
## saliendo, ni en la tanda de penales.
##
## No toca el RNG ni decide nada, y cada jugador se cobra solo: el orden del
## recorrido no cambia el resultado.
##
## Los pesos se leen una vez y los contadores se escriben al final: la
## primera version los leia y escribia por jugador y costaba +17% por
## partido (corridas pareadas).
static func _contabilizar_esfuerzo(estado: Dictionary, en_juego: bool) -> void:
	var w := pesos_esfuerzo()
	var cobrar: bool = en_juego and not bool(estado.get("en_tanda", false))
	var por_segundo: float = float(w["desgaste_por_segundo"])
	var umbral_bajo: float = float(w["reserva_para_frenar"])
	# Las mismas cuentas que intensidad_de_esfuerzo y actualizar_reserva,
	# escritas en linea: llamarlas por jugador duplicaba el costo del cobro.
	var peso_acel: float = float(w["peso_aceleracion"])
	var umbral: float = float(w["umbral_sprint"])
	var gasto: float = float(w["consumo_sprint"]) / maxf(1.0 + peso_acel - umbral, 0.01) * TICK_SEG
	var repone: float = float(w["recuperacion_reserva"]) * TICK_SEG
	var inv_umbral: float = 1.0 / maxf(umbral, 0.01)
	var hay_transito: bool = not (estado.get("saliendo", []).is_empty() and estado.get("entrando", []).is_empty())
	var home: Team = estado["home"]
	var away: Team = estado["away"]
	var carga_tick := 0.0
	var ticks_j := 0
	var bajos := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		var rapidez: float = e["rapidez"]
		var previa: float = e.get("rapidez_previa", rapidez)
		e["rapidez_previa"] = rapidez
		if hay_transito and _en_transito(estado, id):
			continue
		var v: float = minf(rapidez / maxf(float(e["vel_max"]), 0.1), 1.0)
		var intensidad: float = v * v
		if rapidez > previa:
			intensidad += peso_acel * minf((rapidez - previa) / maxf(float(e["aceleracion"]) * TICK_SEG, 0.01), 1.0)
		var reserva: float = e.get("reserva", 1.0)
		if intensidad > umbral:
			reserva = maxf(reserva - gasto * (intensidad - umbral), 0.0)
			e["reserva"] = reserva
		elif reserva < 1.0:
			reserva = minf(reserva + repone * (1.0 - intensidad * inv_umbral), 1.0)
			e["reserva"] = reserva
		if not cobrar:
			continue
		var carga: float = intensidad * TICK_SEG
		carga_tick += carga
		ticks_j += 1
		if reserva < umbral_bajo:
			bajos += 1
		if carga > 0.0:
			e["esfuerzo"] = float(e.get("esfuerzo", 0.0)) + carga
			if por_segundo > 0.0:
				var equipo: Team = home if bool(e["equipo_local"]) else away
				equipo.desgastar(e["jugador_id"], e["energia"], carga * por_segundo)
	if not cobrar:
		return
	if not estado.has("esfuerzo_stats"):
		estado["esfuerzo_stats"] = {"carga": 0.0, "ticks_jugador": 0, "ticks_reserva_baja": 0}
	var st: Dictionary = estado["esfuerzo_stats"]
	st["carga"] = float(st["carga"]) + carga_tick
	st["ticks_jugador"] = int(st["ticks_jugador"]) + ticks_j
	st["ticks_reserva_baja"] = int(st["ticks_reserva_baja"]) + bajos


## El entretiempo. Devuelve una parte de lo que se perdio en el primer
## tiempo, con tope, y llena la reserva de todos. Nunca pasa de la energia
## con la que el jugador arranco el partido: el descanso no borra la semana.
##
## Va solo antes del segundo tiempo. Entre el 90' y el alargue no hay
## descanso real, asi que ahi solo se llena la reserva (ver _jugar_periodo).
static func _recuperar_entretiempo(estado: Dictionary) -> void:
	var w := pesos_esfuerzo()
	for equipo in [estado["home"], estado["away"]]:
		for j in equipo.todos_los_jugadores():
			var id: int = int(j["id"])
			var perdida: float = maxf(float(equipo.fatiga_acumulada.get(id, 1.0)) - equipo.resistencia_pct(id), 0.0)
			var cantidad: float = minf(perdida * float(w["recuperacion_entretiempo"]), float(w["tope_entretiempo"]))
			if cantidad > 0.0:
				equipo.recuperar(id, cantidad)


static func _llenar_reservas(estado: Dictionary) -> void:
	for id in estado["jugadores"]:
		estado["jugadores"][id]["reserva"] = 1.0
		estado["jugadores"][id]["rapidez_previa"] = 0.0


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
	estado["transicion_hasta"] = -1
	estado["ultimo_equipo_con_pelota"] = saca_local
	for jugador in estado["jugadores"].values():
		jugador.erase("corredor_hasta")
		jugador.erase("apoyo_hasta")

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
		# Etapa 3: en el saque del medio todos miran al arco que atacan.
		e["orientacion"] = orientacion_inicial(bool(e["equipo_local"]))
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
	estado["pelota"].erase("control")
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


## Instantánea previa al remate, sin habilidad, desenlace ni consumo de azar.
## Son medidas del contexto; no constituyen una probabilidad ni un xG calibrado.
static func _arquero_puede_intervenir(estado: Dictionary, desde: Vector2, es_local: bool) -> bool:
	var clave := _clave_arquero(estado, not es_local)
	if clave == -1 or _en_transito(estado, clave):
		return false
	var arquero: Dictionary = estado["jugadores"][clave]
	var arco := arco_rival(es_local)
	var poste_a := arco + Vector2(0.0, ARCO_MEDIO_ANCHO)
	var poste_b := arco - Vector2(0.0, ARCO_MEDIO_ANCHO)
	var posicion: Vector2 = arquero["pos"]
	if Geometry2D.is_point_in_polygon(posicion, PackedVector2Array([desde, poste_a, poste_b])):
		return true
	var distancia := minf(_dist_a_segmento(posicion, desde, poste_a),
		minf(_dist_a_segmento(posicion, desde, poste_b), _dist_a_segmento(posicion, poste_a, poste_b)))
	if distancia <= ALCANCE_ESTIRADA:
		return true
	# Cota favorable al arquero: tiempo hasta el poste más lejano y todo su
	# alcance, sin castigar el giro. Solo descarta atajadas físicamente imposibles.
	var segundos := maxf(desde.distance_to(poste_a), desde.distance_to(poste_b)) / float(pesos()["fisica"]["vel_remate"])
	return distancia <= _alcance_en(arquero, segundos) + ALCANCE_ESTIRADA


static func describir_ocasion(estado: Dictionary, desde: Vector2, es_local: bool,
		tipo: String = "tiro") -> Dictionary:
	var arco := arco_rival(es_local)
	var poste_a := arco + Vector2(0.0, ARCO_MEDIO_ANCHO) - desde
	var poste_b := arco - Vector2(0.0, ARCO_MEDIO_ANCHO) - desde
	var angulo := absf(poste_a.angle_to(poste_b))
	var arquero := _clave_arquero(estado, not es_local)
	var posicion_arquero: Variant = null
	if arquero != -1:
		var posicion: Vector2 = estado["jugadores"][arquero]["pos"]
		# Valores escalares para conservar la instantánea al serializar el diagnóstico.
		posicion_arquero = {"x": posicion.x, "y": posicion.y}
	var bloqueador := -1
	if tipo != "cabezazo" and tipo != "penal":
		bloqueador = _bloqueador_de_tiro(estado, desde, es_local,
			float(pesos()["fisica"]["dist_max_bloqueo_libre"]) if tipo == "tiros_libres" else -1.0)
	return {"distancia": desde.distance_to(arco), "angulo_radianes": angulo,
		"presion": presion_normalizada(estado, desde, es_local),
		# Etapa 9: la presion de los que NO son el candidato al bloqueo. Es la
		# que entra en la punteria; el candidato ya cobra en su propio duelo.
		"presion_sin_bloqueador": presion_normalizada(estado, desde, es_local, bloqueador),
		"bloqueador": bloqueador, "obstruida": bloqueador != -1,
		"posicion_arquero": posicion_arquero, "tipo": tipo,
		"arco_desprotegido": not _arquero_puede_intervenir(estado, desde, es_local),
		"cobertura_arquero": cobertura_arquero(estado, desde, es_local),
		"geometria_comun": factor_geometria(desde, es_local)}


## Cuantos puntos de atributo vale un factor de contexto de la ocasion
## (fuerza por distancia, cobertura del arquero, bloqueo a quemarropa).
##
## Esos factores eran multiplicadores sobre el atributo absoluto, y el duelo
## (Duel.p_base) mira la DIFERENCIA en puntos. El mismo remate de lejos le
## sacaba 13 puntos a un 9 de primera (tiro 85) y 6 a uno de decima (tiro
## 40): la ocasion pesaba el doble segun la division. Medido con
## tests/_diag_embudo_remates.gd, 100 partidos parejos por division: el
## arquero de primera atajaba el 63% de los remates al arco contra el 47%
## de decima, y el abstracto 46% y 45%. Ahora el factor se traduce a puntos
## al nivel de referencia, igual que relativo_al_nivel: la ocasion cuesta lo
## mismo en todas las divisiones y en el nivel de referencia nada cambia.
##
## `referencia` es el factor que vale cero puntos. Con 1 el factor solo resta.
## La fuerza se centra en su media, como la cobertura del arquero: el remate
## medio llega al duelo con su atributo entero, igual que en el abstracto.
static func puntos_de_contexto(factor: float, referencia: float = 1.0) -> float:
	return (factor - referencia) * MatchEngine.NIVEL_REFERENCIA


## Distribución de destino CONDICIONADA a superar el bloqueo. Incluye habilidad.
## La mezcla heredada se conserva para palos, cabezazos y libres; no es xG.
##
## `presion` (0 a 1, sin el candidato al bloqueo) solo pesa en el remate de
## pie: el cabezazo ya se disputo arriba y el libre tiene la barrera a 9 m.
## Se centra en `presion_referencia`, la presion media de esos remates, asi
## que mueve la punteria de cada ocasion sin mover la punteria media.
static func modelo_destino_remate(geometria_comun: float, geometria_rematador: float,
		tecnica_normalizada: float, tipo: String = "tiro", presion: float = -1.0) -> Dictionary:
	var r: Dictionary = pesos()["tiro_resolucion"]
	var mezcla: float = tecnica_normalizada / 100.0 * float(r["peso_atributo"]) + geometria_rematador * float(r["peso_geometria"])
	var porteria: float = clampf(float(r["porteria_base"]) + mezcla * float(r["porteria_calidad"]), 0.05, 0.85)
	if tipo == "tiro":
		porteria = probabilidad_porteria(geometria_comun, tecnica_normalizada)
		if presion >= 0.0:
			porteria = clampf(porteria - float(r.get("castigo_presion", 0.0))
					* (clampf(presion, 0.0, 1.0) - float(r.get("presion_referencia", 0.0))), 0.05, 0.85)
	return {"probabilidad_modelo_porteria_sin_bloqueo": porteria,
		"intervalo_palo": float(r["palo"]) * mezcla,
		"factor_fuerza": float(r["fuerza_base"]) + (1.0 - float(r["fuerza_base"])) * geometria_rematador}


## Secuencia local al partido; incluye bloqueos y penales sin consumir azar.
static func _nuevo_id_remate(estado: Dictionary) -> int:
	var id := int(estado.get("secuencia_remates", 0)) + 1
	estado["secuencia_remates"] = id
	return id


## `attr_remate` conserva las rutas específicas de cabezazo y tiro libre.
static func _resolver_tiro(estado: Dictionary, poseedor: Dictionary, jugador: Dictionary, attr_remate: String = "tiro", accion_remate: String = "") -> void:
	var es_local: bool = poseedor["equipo_local"]
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var minuto := _minuto_int(estado)
	var geo := factor_geometria(poseedor["pos"], es_local, jugador)
	# Una sola instantánea alimenta bloqueo, destino y el registro opcional.
	# La presión cercana describe la escena; no se vuelve a cobrar tras el bloqueo.
	var ocasion := describir_ocasion(estado, poseedor["pos"], es_local, attr_remate)
	var remate_id := _nuevo_id_remate(estado)
	var clave := "home" if es_local else "away"
	var accion_animacion := accion_remate if accion_remate != "" else (
		ACCION_CABECEA if attr_remate == "cabezazo" else ("volea" if attr_remate == "volea" else ACCION_PATEA))
	_accion(estado, int(poseedor["clave"]), accion_animacion)
	_xp_e(estado, poseedor, attr_remate)
	# El laboratorio monta jugadas para MIRAR la animacion, y una jugada
	# que unas veces termina en gol y otras no deja comparar nada entre
	# una reproduccion y la siguiente. `forzar_remate` fija el desenlace.
	# Se lee ACA, antes del bloqueo y de la punteria: cuando el forzado se
	# aplicaba solo en el duelo contra el arquero, el remate del clip
	# igual se iba afuera o pegaba en el palo 2 de cada 5 veces.
	#
	# `forzar_remate_attr` lo ata a UN tipo de remate. Sin eso, en el clip
	# del cabezazo el forzado se lo comia el primer remate que apareciera:
	# si el centro no terminaba en cabezazo, el gol se lo terminaba
	# llevando un rival de pie diez ticks despues.
	#
	# Vale UNA vez y se consume. En un partido de verdad la clave no
	# existe.
	var forzado := ""
	if estado.has("forzar_remate"):
		var attr_pedido := str(estado.get("forzar_remate_attr", ""))
		if attr_pedido == "" or attr_pedido == attr_remate:
			forzado = str(estado["forzar_remate"])
	estado["tiros"][clave] += 1
	estado["dist_tiros"].append(poseedor["pos"].distance_to(arco_rival(es_local)))
	var tras_rechazo: bool = estado.has("ultimo_rechazo_tick") \
		and int(estado["tick"]) - int(estado["ultimo_rechazo_tick"]) <= TICKS_REMATE_TRAS_RECHAZO
	if tras_rechazo:
		_stats_arqueros(estado)["remates_tras_rechazo"] += 1
	# El destino depende de la técnica y de la ocasión. Los pesos son del
	# modelo de juego; no representan probabilidades empíricas de fútbol real.
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
	var modelo := modelo_destino_remate(ocasion["geometria_comun"], geo,
		remate_normalizado, attr_remate, float(ocasion["presion_sin_bloqueador"]))
	var chance_porteria: float = modelo["probabilidad_modelo_porteria_sin_bloqueo"]
	var chance_palo: float = modelo["intervalo_palo"]

	# El diagnóstico conserva contexto y ejecución separados, antes de las tiradas.
	var registro := {}
	if estado.has("registro_remates"):
		registro = {"remate_id": remate_id, "distancia": poseedor["pos"].distance_to(arco_rival(es_local)),
			"atributo": attr_remate, "tiro": float(jugador["atributos"][attr_remate]),
			"clave": poseedor["clave"], "local": es_local, "resultado": "bloqueado"}
		registro["ocasion"] = ocasion
		registro["ejecucion"] = {"tecnica_normalizada": remate_normalizado,
			"geometria_rematador": geo,
			"factor_fuerza": modelo["factor_fuerza"],
			"probabilidad_modelo_porteria_sin_bloqueo": chance_porteria,
			"forzado_laboratorio": forzado != ""}
		estado["registro_remates"].append(registro)

	# ¿Se cruza un defensor en el camino? Un remate bloqueado no llega
	# nunca al arquero, y muchas veces sale desviado al córner: es una de
	# las fuentes reales de córners.
	# Meterse en la línea del remate da la OPORTUNIDAD; que el bloqueo
	# salga o no lo decide un duelo (ver _gana_bloqueo), así que un
	# defensor flojo no le tapa el remate a un delantero de élite.
	# Un cabezazo no se bloquea con el cuerpo: viene por arriba y ya se
	# disputo en el duelo aereo.
	var bloqueador: int = -1 if forzado != "" else int(ocasion["bloqueador"])
	if bloqueador != -1 and _gana_bloqueo(estado, bloqueador, jugador, eq_a, eq_d, poseedor["pos"], es_local, minuto):
		_accion(estado, bloqueador, "bloquea")
		_xp_e(estado, estado["jugadores"][bloqueador], "barrida")
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "clave": poseedor["clave"], "resultado": "bloqueado",
			"remate_id": remate_id,
		})
		_resolver_rebote(estado, estado["jugadores"][bloqueador]["pos"], not es_local)
		return

	var roll := rng.randf()

	if forzado == "" and roll > chance_porteria:
		if not registro.is_empty():
			registro["resultado"] = "afuera" if roll > chance_porteria + chance_palo else "palo"
		_lanzar_remate(estado, poseedor, {
			"remate_id": remate_id,
			"tipo": "afuera" if roll > chance_porteria + chance_palo else "palo",
			"es_local": es_local, "clave": poseedor["clave"], "rol": poseedor["rol"],
			"accion": accion_animacion,
		})
		return

	# Superó bloqueo y puntería. Sin arquero capaz de llegar, no hay duelo
	# de atajada ni desgaste/XP para un arquero ausente o fuera de la jugada.
	if bool(ocasion["arco_desprotegido"]) and forzado == "":
		eq_a.desgastar(jugador["id"], jugador["atributos"]["energia"], float(pesos()["fisica"]["multiplicador_desgaste"]))
		if not registro.is_empty():
			registro["resultado"] = "gol"
		_lanzar_remate(estado, poseedor, {"remate_id": remate_id,
			"tipo": "gol", "es_local": es_local, "clave": poseedor["clave"],
			"rol": poseedor["rol"], "jugador": jugador,
			"dist": ocasion["distancia"], "arco_desprotegido": true, "tras_rechazo": tras_rechazo,
			"accion": accion_animacion})
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
	# Etapa 6: el arquero ataja desde donde ESTA. El que achico bien le tapa
	# mas arco al que remata; el que quedo corrido o salio y no llego, menos.
	# Es la misma instantanea de la ocasion, tomada antes de las tiradas.
	var cobertura: float = float(ocasion["cobertura_arquero"])
	arquero_valor += puntos_de_contexto(factor_cobertura(cobertura))
	var stats_arq := _stats_arqueros(estado)
	stats_arq["duelos"] += 1
	stats_arq["cobertura_suma"] += cobertura
	# Puntería y fuerza representan fallos distintos: errar el arco y perder
	# potencia al llegar. Ninguna vuelve a penalizar al defensor ya superado.
	var tiro_efectivo: float = remate_efectivo + puntos_de_contexto(float(modelo["factor_fuerza"]),
			float(pesos()["tiro_resolucion"].get("fuerza_referencia", 1.0)))
	var ata := Duel.atributo_efectivo(tiro_efectivo, "tecnico", eq_a.resistencia_pct(jugador["id"]))
	var def := Duel.atributo_efectivo(arquero_valor, "tecnico", eq_d.resistencia_pct(arquero["id"]))
	var res := Duel.resolver(ata, def,
		MatchEngine._bloques_equipo(eq_a, eq_d, jugador, attr_remate, minuto, rng),
		MatchEngine._bloques_equipo(eq_d, eq_a, arquero, "reflejos", minuto, rng))
	var mult_tiro: float = float(pesos()["fisica"]["multiplicador_desgaste"])
	eq_a.desgastar(jugador["id"], jugador["atributos"]["energia"], mult_tiro)
	eq_d.desgastar(arquero["id"], arq_attrs["energia"], mult_tiro)
	var gol := Duel.gana_atacante(res, rng)
	# El desenlace forzado por el laboratorio (ver arriba) manda sobre el
	# duelo, y recien aca se consume.
	if forzado != "":
		gol = forzado == "gol"
		estado.erase("forzar_remate")
		estado.erase("forzar_remate_attr")
	_xp(estado, int(arquero["id"]), not es_local, "reflejos")
	if not registro.is_empty():
		registro["resultado"] = "gol" if gol else "atajada"
	_lanzar_remate(estado, poseedor, {
		"remate_id": remate_id,
		"tipo": "gol" if gol else "atajada",
		"es_local": es_local, "clave": poseedor["clave"], "rol": poseedor["rol"],
		"jugador": jugador, "agarre": float(arquero["atributos"]["agarre"]) / 100.0,
		"dist": poseedor["pos"].distance_to(arco_rival(es_local)),
		"tras_rechazo": tras_rechazo, "accion": accion_animacion,
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
	# Penales y llamadas antiguas también comparten la secuencia del partido.
	if not datos.has("remate_id"):
		datos["remate_id"] = _nuevo_id_remate(estado)
	if estado.get("remates_aplicados", {}).has(datos["remate_id"]):
		return
	if bool(estado["pelota"].get("es_remate", false)) and estado["pelota"].get("remate", {}).get("remate_id", -1) == datos["remate_id"]:
		return
	# Un cabezazo puede seguir a una entrega pendiente del centro. Ese dueño
	# ya no controla la pelota: si queda, intercepta el vuelo y borra el remate.
	_limpiar_dirigida(estado["pelota"])
	var rng: RandomNumberGenerator = estado["rng"]
	var es_local: bool = bool(datos["es_local"])
	var arco := arco_rival(es_local)
	var lado: float = 1.0 if arco.x > 0.0 else -1.0
	var tipo := str(datos["tipo"])
	estado["pelota"].erase("trayectoria_curva")
	estado["pelota"].erase("progreso_trayectoria")

	# Hasta dónde llega el arquero mientras la pelota viaja. Es lo que
	# decide ADÓNDE va el remate: una atajada tiene que ir a un punto que
	# el arquero alcance, y un gol a uno que no. Antes el destino salía de
	# un randf() suelto y el arquero se quedaba clavado, así que la pelota
	# llegaba a la línea y después se teletransportaba a sus manos.
	var arq_clave := -1 if bool(datos.get("arco_desprotegido", false)) else _clave_arquero(estado, not es_local)
	var arq_pos := Vector2(arco.x, 0.0)
	var alcance := 3.66
	if arq_clave != -1:
		var e_arq: Dictionary = estado["jugadores"][arq_clave]
		arq_pos = e_arq["pos"]
		var vel_remate: float = float(pesos()["fisica"]["vel_remate"])
		# El vuelo termina EN EL ARQUERO, no en la línea: la distancia se
		# mide contra él. Midiendo contra el arco se le regalaba el tiempo
		# de los metros que él tiene adelantados.
		var segundos_vuelo: float = maxf(poseedor["pos"].distance_to(arq_pos) / vel_remate, TICK_SEG)
		alcance = _alcance_en(e_arq, segundos_vuelo) + ALCANCE_ESTIRADA

	var y_destino := 0.0
	# La altura nace de la acción, no solo del resultado. Una volea o un
	# cabezazo tienen que salir del gesto en el aire; un tiro normal apenas
	# se levanta. Antes el valor se pisaba abajo y todos los remates parecían
	# rodados.
	var accion_animacion := str(datos.get("accion", ACCION_PATEA))
	var altura := 0.30
	if accion_animacion == ACCION_CABECEA:
		altura = 1.65
	elif accion_animacion in ["volea", "chilena"]:
		altura = 1.35
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

	# La atajada termina DELANTE DEL ARQUERO, no delante de la línea. Con
	# el destino en la línea, el arquero adelantado tenía que correr para
	# atrás a buscarla mientras la pelota volaba a 26 m/s: no llegaba
	# nunca, así que la pelota le pasaba de largo, frenaba en la línea y
	# al fotograma siguiente aparecía en sus manos. Medido con Presión
	# alta (tests/_diag_arquero_posicion.gd): el vuelo terminaba a 6,16 m
	# de él y el 86% de las atajadas daban ese salto.
	# El gol termina adentro del arco. El palo, en el palo: sobre la
	# línea, no 1,2 m adentro, que es donde está la red de afuera.
	var x_destino: float = arco.x + lado * 1.2
	if tipo == "atajada":
		x_destino = arq_pos.x - lado * 0.3
	elif tipo == "palo":
		x_destino = arco.x
	var destino := Vector2(x_destino,
		clampf(y_destino, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	if tipo == "afuera":
		# Afuera cruza la línea por fuera del palo y sigue hasta pasar el
		# arco. Frenaba 1,2 m detrás de la línea: un remate cruzado se
		# metía en la red de afuera y quedaba ahí.
		var cruce := _cruce_fuera_del_arco(poseedor["pos"], Vector2(arco.x, destino.y))
		destino = _descanso_detras_del_arco(poseedor["pos"], cruce)
	var trayectoria_curva := _trayectoria_curva_remate(poseedor["pos"], destino, datos, tipo, rng)
	if not trayectoria_curva.is_empty():
		datos["curva_m"] = float(trayectoria_curva["curva_m"])
		datos["calidad_tiro"] = float(trayectoria_curva["calidad_tiro"])
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
	pelota["trayectoria_curva"] = trayectoria_curva
	pelota["progreso_trayectoria"] = 0.0
	pelota["pasador_local"] = es_local
	pelota["altura_max"] = altura
	pelota["ticks_con_pelota"] = 0
	pelota.erase("altura_salida")
	pelota["z"] = 0.0
	pelota.erase("pared_a")
	var dir: Vector2 = (destino - poseedor["pos"]).normalized()
	pelota["vel"] = dir * float(pesos()["fisica"]["vel_remate"])

	# El arquero se mueve hacia la trayectoria mientras la pelota viaja,
	# no cuando ya entró (ver el paso 3 de _tick). En la atajada llega
	# justo; en el gol se estira y no alcanza. La POSE de tirarse la
	# registra ese mismo paso cuando la pelota está por llegar, no acá:
	# dura cuatro ticks y un remate de 35 metros viaja más que eso, así
	# que el arquero se levantaba antes de que la pelota llegara.
	if tipo in ["gol", "atajada", "palo"] and arq_clave != -1:
		datos["arquero"] = arq_clave
		# Se tira EN SU PROPIA PROFUNDIDAD: toma el costado al que va la
		# pelota y su X se queda donde estaba. Antes se tiraba sobre la
		# línea del arco, que es lo que lo mandaba a correr para atrás en
		# vez de estirarse al costado. El clamp lo deja fuera de la red:
		# con el destino crudo, un remate que termina 1,2 m adentro
		# arrastraba al arquero adentro del arco, tratando de meterse él
		# también.
		datos["destino_arquero"] = Vector2(
			clampf(arq_pos.x, -ARQUERO_X_MIN, ARQUERO_X_MIN), destino.y)


## Decide si el remate sale con rosca. La geometria manda la oportunidad:
## de frente casi nunca hay curva; en diagonal, efecto y tiro la vuelven
## frecuente. `forzar_curva` existe solo para la escena del laboratorio.
static func _trayectoria_curva_remate(desde: Vector2, destino: Vector2,
		datos: Dictionary, tipo: String, rng: RandomNumberGenerator) -> Dictionary:
	if tipo not in ["gol", "atajada", "palo", "afuera"]:
		return {}
	var jugador: Dictionary = datos.get("jugador", {})
	var attrs: Dictionary = jugador.get("atributos", {})
	var tiro_attr := "tiros_libres" if datos.get("tiro_libre", false) else "tiro"
	var tiro := clampf(float(attrs.get(tiro_attr, attrs.get("tiro", 50))) / 100.0, 0.0, 1.0)
	var efecto := clampf(float(attrs.get("efecto", 0)) / 100.0, 0.0, 1.0)
	var direccion := (destino - desde).normalized()
	var diagonal := clampf(absf(direccion.y), 0.0, 1.0)
	if diagonal < 0.20 or efecto < 0.18:
		if not bool(datos.get("forzar_curva", false)):
			return {}
	var probabilidad := diagonal * (0.08 + efecto * 0.92) * (0.40 + tiro * 0.60)
	if not bool(datos.get("forzar_curva", false)) and rng.randf() > probabilidad:
		return {}
	var calidad := clampf(0.55 * tiro + 0.45 * efecto, 0.0, 1.0)
	# La desviacion se exagera un poco en pantalla: la proyeccion de la
	# cancha aplasta el ancho y una rosca real de 1 m apenas se percibe.
	var curva_m := diagonal * (1.6 + 5.8 * efecto) * (0.55 + 0.45 * tiro)
	var hacia_centro := -signf(desde.y)
	if is_zero_approx(hacia_centro):
		hacia_centro = 1.0 if direccion.y < 0.0 else -1.0
	var amplitud := curva_m * 1.6
	var control := desde.lerp(destino, 0.5) + Vector2(0.0, hacia_centro * amplitud)
	return {"origen": desde, "control": control, "destino": destino,
		"longitud": desde.distance_to(control) + control.distance_to(destino),
		"curva_m": amplitud, "calidad_tiro": calidad}


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
	# Una copia del mismo vuelo puede llegar dos veces; no repite eventos ni RNG.
	# Las llamadas antiguas sin identificador lo adquieren al aplicarse.
	if not datos.has("remate_id"):
		datos["remate_id"] = _nuevo_id_remate(estado)
	var remate_id: int = int(datos["remate_id"])
	if not estado.has("remates_aplicados"):
		estado["remates_aplicados"] = {}
	if estado["remates_aplicados"].has(remate_id):
		return
	estado["remates_aplicados"][remate_id] = true
	var es_local: bool = bool(datos["es_local"])
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var minuto := _minuto_int(estado)
	var tipo := str(datos["tipo"])
	# El rastro vive durante el vuelo; al resolverlo no puede quedar pegado
	# sobre el saque siguiente.
	estado["pelota"].erase("trayectoria_curva")
	estado["pelota"].erase("progreso_trayectoria")

	if tipo == "afuera" or tipo == "palo":
		estado["eventos"].append({
			"minuto": minuto, "tipo": "tiro", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": datos["rol"], "clave": datos["clave"], "resultado": tipo,
			"remate_id": remate_id,
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
	# El penal de la TANDA no toca el marcador del partido: los 120'
	# terminaron empatados y ahi se quedan. Se anota aparte y no se reanuda
	# nada — no hay saque del medio ni saque de arco, viene el penal
	# siguiente y lo arma _patear_de_la_tanda.
	if es_penal and bool(estado.get("en_tanda", false)):
		_anotar_penal_de_tanda(estado, es_local, gol, datos)
		return
	estado["eventos"].append({
		"minuto": minuto, "tipo": "penal" if es_penal else "tiro_puerta",
		"remate_id": remate_id,
		"equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": datos["rol"], "clave": datos["clave"],
		"resultado": ("gol" if gol else ("atajado" if es_penal else "atajada")),
		"con_efecto": float(datos.get("curva_m", 0.0)) > 0.0,
		"curva_m": float(datos.get("curva_m", 0.0)),
		"calidad_tiro": float(datos.get("calidad_tiro", 0.0)),
	})
	var jugador: Dictionary = datos.get("jugador", {})
	var dist: float = float(datos.get("dist", 0.0))
	if gol:
		if estado.has("cadena_rebotes"):
			estado.erase("cadena_rebotes")
			estado.erase("foco_laboratorio")
		eq_a.goles += 1
		if bool(datos.get("tras_rechazo", false)):
			_stats_arqueros(estado)["goles_tras_rechazo"] += 1
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre,
			"remate_id": remate_id,
			"jugador_id": jugador.get("id", -1),
			"asistencia_id": _asistente_de(estado, es_local, int(datos["clave"]))})
		if es_penal:
			estado["log"].append("min %d - PENAL: gol de %s %s (%s)" % [
				minuto, jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre])
		else:
			estado["log"].append("min %d - GOL de %s %s (%s) desde %.0f m" % [
				minuto, jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre, dist])
		_accion(estado, int(datos["clave"]), ACCION_FESTEJA)
		_festejar_gol(estado, not es_local)
		return

	if es_penal:
		estado["log"].append("min %d - PENAL: lo ataja el arquero de %s" % [minuto, eq_d.nombre])
	else:
		estado["log"].append("min %d - %s (%s) remata desde %.0f m, ataja el arquero" % [
			minuto, datos["rol"], eq_a.nombre, dist])
	# El arquero no siempre la retiene. Cuanto mejor su agarre, más veces
	# la queda. Si no, la rechaza: al córner o a un costado (etapa 6).
	# El penal manoteado sigue yendo al córner: su rebote es otra jugada.
	var agarre: float = clampf(float(datos.get("agarre", 0.5)), 0.0, 1.0)
	# El agarre domina la retencion. Reflejos y estirada ya influyeron en
	# llegar a la pelota, pero no convierten una mano blanda en control limpio.
	var chance_rebote: float = clampf(0.04 + (1.0 - agarre) * 0.58, 0.04, 0.62)
	var cadena_rebotes: Dictionary = estado.get("cadena_rebotes", {})
	var rebote_forzado := not es_penal and int(cadena_rebotes.get("rebotes_pendientes", 0)) > 0
	if rebote_forzado or rng.randf() < chance_rebote:
		if es_penal:
			_manotear_al_corner(estado, es_local)
		else:
			if rebote_forzado:
				cadena_rebotes["rebotes_pendientes"] = int(cadena_rebotes["rebotes_pendientes"]) - 1
				estado["forzar_rebote_aereo"] = true
			_rechazar_remate(estado, datos)
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
	estado["pelota"].erase("control")
	_accion(estado, arquero_clave, ACCION_AGARRA)


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
	# Un rechazo al corner cruza por fuera de los postes. El destino
	# extendido conserva ese cruce: desplazar solo X lo acercaba al arco.
	var es_corner := absf(punto.y) < MEDIO_ANCHO and toco_local == (punto.x < 0.0)
	if es_corner:
		var lado := signf(punto.y) if absf(punto.y) > 0.01 else (1.0 if desde.y >= 0.0 else -1.0)
		punto.y = lado * maxf(absf(punto.y), ARCO_MEDIO_ANCHO + 1.5)
	# Un poco más allá de la línea, para que se vea cruzar y no frenar
	# justo encima.
	var salida: Vector2 = punto
	if absf(punto.y) >= MEDIO_ANCHO:
		salida = Vector2(punto.x, punto.y + signf(punto.y) * MARGEN_SALIDA)
	else:
		# Por el fondo cruza por fuera del palo y sigue la misma recta
		# hasta pasar el arco, sin atravesar la red (ver DESCANSO_FONDO).
		# Una pelota que no es remate no se mete entre los palos.
		punto = _cruce_fuera_del_arco(desde, punto)
		salida = _descanso_detras_del_arco(desde, punto)
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
	pelota.erase("altura_salida")
	pelota.erase("pared_a")
	pelota["vel"] = (salida - desde).normalized() 		* maxf(pelota["vel"].length(), float(pesos()["fisica"]["vel_salida_min"]))


## Dónde cruza la línea de fondo una pelota que va de `desde` a `cruce`
## y se va afuera. Si la recta, una vez pasada la línea, se cierra hacia
## el arco y entraría a la red de afuera, el cruce se abre hasta que pase
## a DESPEJE_RED del costado de la red. Es el remate cruzado desde la
## banda: cruzaba la línea a 4,5 m del centro y se metía en la red.
static func _cruce_fuera_del_arco(desde: Vector2, cruce: Vector2) -> Vector2:
	var lado := signf(cruce.x)
	var s := signf(cruce.y) if absf(cruce.y) > 0.01 else 1.0
	# Metros de avance en X desde `desde` hasta la línea. Con menos de uno
	# la recta es casi paralela a la línea y la cuenta se dispara.
	var dx := maxf(lado * (cruce.x - desde.x), 1.0)
	var fondo := PROFUNDIDAD_ARCO + DESPEJE_RED
	var costado := ARCO_MEDIO_ANCHO + DESPEJE_RED
	# y(fondo) = cruce.y + (cruce.y - desde.y) * fondo / dx, y tiene que
	# quedar a `costado` o más, del mismo lado que el cruce.
	var minimo := (costado + s * desde.y * fondo / dx) / (1.0 + fondo / dx)
	var y := s * clampf(maxf(absf(cruce.y), minimo), costado, MEDIO_ANCHO - 1.0)
	return Vector2(cruce.x, y)


## Dónde frena, sobre la recta `desde` -> `cruce`, la pelota que se va por
## el fondo: DESCANSO_FONDO detrás de la línea. Una recta casi paralela a
## la línea llegaría lejísimos, así que el tramo después del cruce tiene
## tope.
static func _descanso_detras_del_arco(desde: Vector2, cruce: Vector2) -> Vector2:
	var dir := (cruce - desde).normalized()
	var lado := signf(cruce.x)
	# Si venía desde atrás de la línea (el rebote del palo), no vuelve a
	# la cancha: se va derecho para afuera.
	if lado * dir.x < 0.0 or dir == Vector2.ZERO:
		dir = Vector2(lado, 0.0)
	var avance_x := lado * dir.x
	var tramo := DESCANSO_FONDO * 2.0
	if avance_x > 0.05:
		tramo = minf(DESCANSO_FONDO / avance_x, tramo)
	var descanso := cruce + dir * tramo
	if lado * (descanso.x - cruce.x) >= DESCANSO_FONDO - 0.01 \
			or absf(descanso.y) >= ARCO_MEDIO_ANCHO + DESCANSO_COSTADO:
		return descanso
	# Una recta empinada que se cierra hacia el arco no llega a pasarlo con
	# el tope: frena antes, todavía lejos del palo. Si ya cruzó cerca del
	# palo, no le queda otra que seguir hasta pasar el arco por detrás.
	var hacia_el_arco := signf(dir.y) != signf(cruce.y) and absf(dir.y) > 0.01
	if hacia_el_arco:
		var hasta_el_costado := (absf(cruce.y) - ARCO_MEDIO_ANCHO - DESCANSO_COSTADO) / absf(dir.y)
		if hasta_el_costado >= 1.0:
			return cruce + dir * hasta_el_costado
	return cruce + dir * (DESCANSO_FONDO / maxf(avance_x, 0.05))


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
	estado["balon_parado"]["con_manos"] = true
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
	bloqueo += puntos_de_contexto(float(f["bloqueo_a_quemarropa"])
			+ (1.0 - float(f["bloqueo_a_quemarropa"])) * tiempo_para_reaccionar)

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
			_entregar_rodando(estado, suyo)
			return
	# Rebote suelto: sale despedida y la agarra el que llegue.
	var dir := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
	var largo: float = rng.randf_range(float(f["rebote_largo_min"]), float(f["rebote_largo_max"]))
	var destino := Vector2(
		clampf(desde.x + dir.x * largo, -LIMITE_X, LIMITE_X),
		clampf(desde.y + dir.y * largo, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	_soltar_pelota(estado, desde, destino, toco_local)


## La pelota sale despedida sin dueno hacia `destino` y la agarra el que
## llegue. La usan el rebote de un bloqueo y el rechazo del arquero.
static func _soltar_pelota(estado: Dictionary, desde: Vector2, destino: Vector2, toco_local: bool) -> void:
	var f: Dictionary = pesos()["fisica"]
	var pelota: Dictionary = estado["pelota"]
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["pos"] = desde
	pelota["vel"] = (destino - desde).normalized() * float(f["vel_pase_min"])
	pelota["destino_pos"] = destino
	pelota["destino_id"] = -1
	pelota["pasador_local"] = toco_local
	pelota["es_pase"] = false
	pelota["es_centro"] = false
	pelota["es_remate"] = false
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota["origen_pos"] = desde
	pelota["ticks_con_pelota"] = 0
	pelota.erase("altura_salida")


## Resuelve el rebote de una atajada cuando llega a tierra. El rebote puede
## ser de un defensor, de un atacante o una disputa arriba. Si queda para un
## atacante dentro del area, existe una segunda definicion de cabeza/volea.
static func _resolver_rebote_arquero(estado: Dictionary, punto: Vector2, minuto: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	var ataca_local: bool = bool(pelota.get("rebote_ataca_local", true))
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	var rng: RandomNumberGenerator = estado["rng"]
	var alto: bool = bool(pelota.get("rebote_alto", false))
	var autogol: bool = bool(pelota.get("rebote_autogol", false))
	pelota.erase("es_rebote_arquero")
	pelota.erase("rebote_alto")
	pelota.erase("rebote_ataca_local")
	pelota.erase("rebote_autogol")

	if autogol:
		eq_a.goles += 1
		estado["eventos"].append({
			"minuto": minuto, "tipo": "rebote_arquero", "equipo": eq_a.nombre,
			"rival": eq_d.nombre, "jugador_posicion": "ARQ",
			"resultado": "gol", "autogol": true,
		})
		estado["goles_log"].append({"minuto": minuto, "equipo": eq_a.nombre,
			"jugador_id": -1, "asistencia_id": -1, "autogol": true})
		estado["log"].append("min %d - GOL en contra tras rebote del arquero (%s)" % [minuto, eq_d.nombre])
		_festejar_gol(estado, not ataca_local)
		return

	var atacante := _mas_cercano_del_equipo(estado, punto, ataca_local)
	var defensor := _mas_cercano_del_equipo(estado, punto, not ataca_local)
	var cadena: Dictionary = estado.get("cadena_rebotes", {})
	var paso_cadena := int(cadena.get("paso", 0))
	var duelo_cadena := false
	if not cadena.is_empty():
		var atacantes_cadena: Array = cadena.get("atacantes", [])
		var defensor_cadena := int(cadena.get("defensor", -1))
		if paso_cadena < atacantes_cadena.size():
			var atacante_cadena := int(atacantes_cadena[paso_cadena])
			if estado["jugadores"].has(atacante_cadena):
				atacante = atacante_cadena
				duelo_cadena = true
		if estado["jugadores"].has(defensor_cadena):
			defensor = defensor_cadena
	if atacante == -1 and defensor == -1:
		_dar_pelota_al_arquero(estado, not ataca_local, true)
		return
	if atacante == -1:
		_entregar_rodando(estado, defensor)
		_registrar_resultado_rebote(estado, minuto, ataca_local, defensor, "defensor")
		return
	if defensor == -1:
		_entregar_rodando(estado, atacante)
		_registrar_resultado_rebote(estado, minuto, ataca_local, atacante, "atacante")
		_intentar_remate_rebote(estado, atacante, punto, ataca_local, alto, minuto)
		return

	var gana_atacante := duelo_cadena
	var e_a: Dictionary = estado["jugadores"][atacante]
	var e_d: Dictionary = estado["jugadores"][defensor]
	var j_a := _dict_jugador(estado, eq_a, int(e_a["jugador_id"]))
	var j_d := _dict_jugador(estado, eq_d, int(e_d["jugador_id"]))
	if duelo_cadena:
		gana_atacante = true
	elif j_a.is_empty() or j_d.is_empty():
		gana_atacante = punto.distance_to(e_a["pos"]) <= punto.distance_to(e_d["pos"])
	else:
		var a_val: float
		var d_val: float
		if alto:
			a_val = float(j_a["atributos"].get("cabezazo", 50.0)) * 0.60 \
				+ float(j_a["atributos"].get("salto", 50.0)) * 0.40
			d_val = float(j_d["atributos"].get("salto", 50.0)) * 0.45 \
				+ float(j_d["atributos"].get("cabezazo", 50.0)) * 0.25 \
				+ float(j_d["atributos"].get("fuerza", 50.0)) * 0.30
		else:
			a_val = float(j_a["atributos"].get("control", 50.0)) * 0.45 \
				+ float(j_a["atributos"].get("agilidad", 50.0)) * 0.25 \
				+ float(j_a["atributos"].get("fuerza", 50.0)) * 0.15 \
				+ float(j_a["atributos"].get("inteligencia", 50.0)) * 0.15
			d_val = float(j_d["atributos"].get("quite", 50.0)) * 0.55 \
				+ float(j_d["atributos"].get("agilidad", 50.0)) * 0.20 \
				+ float(j_d["atributos"].get("fuerza", 50.0)) * 0.25
		var diferencia_distancia: float = clampf(
			(punto.distance_to(e_d["pos"]) - punto.distance_to(e_a["pos"])) * 2.0, -15.0, 15.0)
		var res := Duel.resolver(
			Duel.atributo_efectivo(a_val + diferencia_distancia, "tecnico", eq_a.resistencia_pct(j_a["id"])),
			Duel.atributo_efectivo(d_val, "defensivo", eq_d.resistencia_pct(j_d["id"])),
			MatchEngine._bloques_equipo(eq_a, eq_d, j_a, "cabezazo" if alto else "control", minuto, rng),
			MatchEngine._bloques_equipo(eq_d, eq_a, j_d, "salto" if alto else "quite", minuto, rng))
		gana_atacante = Duel.gana_atacante(res, rng)

	var ganador: int = atacante if gana_atacante else defensor
	_entregar_rodando(estado, ganador)
	_registrar_resultado_rebote(estado, minuto, ataca_local, ganador, "atacante" if gana_atacante else "defensor")
	if gana_atacante:
		# Si el ganador estaba fuera del radio de control, la pelota rueda
		# hasta sus pies. Guardar el remate evita que la entrega borre la
		# cadena antes de resolverlo.
		if estado["pelota"].has("dirigida_a"):
			estado["pelota"]["rebote_remate_pendiente"] = {
				"atacante": atacante, "punto": punto,
				"ataca_local": ataca_local, "alto": alto,
			}
		else:
			_intentar_remate_rebote(estado, atacante, punto, ataca_local, alto, minuto)


static func _intentar_remate_rebote(estado: Dictionary, atacante: int, punto: Vector2,
		ataca_local: bool, alto: bool, minuto: int) -> void:
	if not estado["jugadores"].has(atacante):
		return
	var e: Dictionary = estado["jugadores"][atacante]
	var jugador := _dict_jugador(estado, _equipo_de(estado, ataca_local), int(e["jugador_id"]))
	if jugador.is_empty() or not _en_el_area(punto, ataca_local):
		return
	var attrs: Dictionary = jugador["atributos"]
	var cadena: Dictionary = estado.get("cadena_rebotes", {})
	var paso_cadena := int(cadena.get("paso", 0))
	var remates_cadena: Array = cadena.get("remates", [])
	var remate_cadena_forzado: bool = not cadena.is_empty() and paso_cadena < remates_cadena.size()
	if not cadena.is_empty():
		if remate_cadena_forzado:
			var plan: Dictionary = remates_cadena[paso_cadena]
			var atributo_cadena := str(plan.get("atributo", "cabezazo"))
			estado["forzar_remate"] = str(plan.get("resultado", "atajada"))
			estado["forzar_remate_attr"] = atributo_cadena
			_resolver_tiro(estado, e, jugador, atributo_cadena,
				str(plan.get("accion", ACCION_CABECEA)))
			cadena["paso"] = paso_cadena + 1
			return
	if e["pos"].distance_to(punto) > float(pesos()["fisica"]["radio_control"]) and not remate_cadena_forzado:
		return
	var chance: float = 0.28 + float(attrs.get("tiro", 50.0)) / 100.0 * 0.32
	if alto:
		chance += float(attrs.get("cabezazo", 50.0)) / 100.0 * 0.18
	else:
		chance += float(attrs.get("volea", 50.0)) / 100.0 * 0.18
	if estado["rng"].randf() > clampf(chance, 0.20, 0.78):
		return
	var accion := "volea"
	var atributo := "volea"
	if alto and estado["rng"].randf() >= clampf(0.08 + float(attrs.get("volea", 50.0)) / 100.0 * 0.30, 0.08, 0.38):
		accion = ACCION_CABECEA
		atributo = "cabezazo"
	_resolver_tiro(estado, e, jugador, atributo, accion)


static func _registrar_resultado_rebote(estado: Dictionary, minuto: int,
		ataca_local: bool, ganador: int, bando: String) -> void:
	var e: Dictionary = estado["jugadores"][ganador]
	var eq_a := _equipo_de(estado, ataca_local)
	var eq_d := _equipo_de(estado, not ataca_local)
	estado["eventos"].append({
		"minuto": minuto, "tipo": "rebote_arquero", "equipo": eq_a.nombre,
		"rival": eq_d.nombre, "jugador_posicion": e["rol"],
		"clave": ganador, "resultado": "control_%s" % bando,
	})


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
	# El vuelo del rechazo empieza donde el defensor toca la pelota.
	estado["pelota"]["pos"] = desde
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
	# Gesto visual determinista: un pase corto hacia atras sale de taco.
	var de_taco: bool = not es_pelotazo and poseedor["rol"] != "ARQ" and _d <= 8.0 and orientacion_de(poseedor).dot(dir) < -0.55
	_accion(estado, int(poseedor["clave"]), "taco" if de_taco else ACCION_PATEA)
	# §7.3: pasar entrena `pases`; reventarla, `fuerza`. El centro suma
	# `centros` cuando se marca como tal, un tick después de esto.
	_xp_e(estado, poseedor, "fuerza" if es_pelotazo else "pases")
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	# Etapa 3: la llegada que se mida tiene que ser la de ESTE pase.
	pelota.erase("llegada")
	pelota.erase("pase_atras_coordinado")
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
	_actualizar_transicion(estado)
	# La fase del que ataca se estima ANTES de decidir, para que la
	# decision (paso 2) y el movimiento sin pelota (paso 3) lean la misma.
	_planificar_ritmo(estado)
	# Y la urgencia de los DOS equipos, por el mismo motivo: el que decide
	# (paso 2), el que se para sin pelota (paso 3) y el que reparte la
	# defensa leen todos el mismo numero dentro del tick.
	_planificar_marcador(estado)
	# Etapa 5: si el tick EMPIEZA con el juego corriendo, se cobra el
	# esfuerzo. El tick que corta el juego (gol, falta) todavia fue jugado.
	estado["esfuerzo_en_juego"] = int(estado.get("detenido", 0)) <= 0
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
			_mirar_la_pelota(estado)
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
	# Los desmarques se reparten ANTES de mover a nadie, para que los once
	# lean la misma instantanea de posiciones. Repartirlos dentro del
	# bucle de movimiento le daria al de clave baja una foto distinta a la
	# del de clave alta.
	_planificar_desmarques(estado, equipo_con_pelota)
	# Etapa 6: los arqueros tambien deciden desde la misma foto.
	_planificar_arqueros(estado, equipo_con_pelota)

	var perseguidores := _perseguidores(estado, equipo_con_pelota)

	# El destinatario de un pase va a BUSCAR la pelota. Sin esto el pase
	# apunta a donde el compañero estaba al momento de pegarle, y como en
	# los ~4 ticks de vuelo ese compañero se corrió 7-9 metros, la pelota
	# llegaba a un lugar vacío y la agarraba el defensor más cercano: solo
	# el 1% de los pases se completaba, contra el ~80% de un partido real.
	var esperando := -1
	if pelota["en_vuelo"]:
		esperando = int(pelota.get("destino_id", -1))
		# Con la pelota ya adjudicada, el que sale a buscarla es el dueno
		# y no el destinatario original del pase.
		if pelota.has("dirigida_a"):
			esperando = int(pelota["dirigida_a"])
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
		# El arquero se estira hacia la trayectoria del remate. Sin esto
		# se quedaba parado y la pelota le aparecía en las manos.
		if id == arquero_al_remate:
			# Se tira SOBRE EL FINAL. La pose dura cuatro ticks, así que
			# registrarla al salir el remate dejaba al arquero levantado
			# justo cuando llegaba la pelota en los remates largos.
			var falta: float = pelota["pos"].distance_to(pelota["destino_pos"])
			if falta <= float(pesos()["fisica"]["vel_remate"]) * TICK_SEG * 2.0:
				_accion(estado, id, ACCION_VUELA)
			_mover_hacia(e, pelota["remate"]["destino_arquero"])
			continue
		if perseguidores.has(id):
			_mover_hacia(e, _objetivo_de_presion(estado, e))
			continue
		var equipo := _equipo_de(estado, e["equipo_local"])
		# Con la pelota EN EL AIRE no hay poseedor, pero el equipo que la
		# jugó sigue atacando: usar `poseedor_id != -1` hacía que durante
		# cada vuelo los dos equipos se replegaran como si hubieran
		# perdido la pelota. En un remate se veía clarísimo — pateaban al
		# arco y arrancaban a retroceder antes de saber si era gol.
		var mi_equipo_tiene: bool = e["equipo_local"] == equipo_con_pelota
		_mover_hacia(e, _objetivo_sin_pelota(estado, e, equipo, mi_equipo_tiene))
	# Etapa 3: los que quedaron al trote o quietos se perfilan hacia la
	# pelota, despues de moverse todos y desde la misma posicion de pelota.
	_mirar_la_pelota(estado)

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

	_contabilizar_esfuerzo(estado, bool(estado.get("esfuerzo_en_juego", false)))

	estado["tick"] += 1
	# El reloj MOSTRADO avanza 90 minutos a lo largo de los 960 ticks del
	# partido: es la ficción de "esto son 90 minutos". Todo lo que depende
	# del minuto (rasgos como Lento de arranque o Se apaga, el DT según el
	# marcador, las ventanas de cambio) lee este reloj, así que conserva
	# exactamente la semántica del GDD.
	# En la tanda el reloj NO corre: el partido ya termino a los 120' y el
	# cartel tiene que quedarse ahi. Sin esto la tanda seguia sumando
	# minutos y el reloj marcaba 130' con los 22 parados en el circulo.
	if not bool(estado.get("en_tanda", false)):
		estado["minuto"] += MINUTOS_MOSTRADOS_POR_MITAD / float(TICKS_POR_MITAD)
	# Se pone la cancha al dia CON EL JUEGO DETENIDO: es la condicion que
	# pide _sincronizar_cambios, y un corte es justo cuando se hace un
	# cambio de verdad. Se prueba en cada tick detenido y no cada 20 para
	# que el suplente entre en el corte que ya esta pasando en vez de
	# esperar hasta cinco segundos y arrancar con el juego reanudado.
	if int(estado.get("detenido", 0)) > 0:
		_sincronizar_cambios(estado)
	# Cuanto valia el reloj de la pausa al cerrar este tick. Lo lee la
	# guarda de _sincronizar_cambios para saber si el juego ya venia
	# detenido o se corto recien ahora.
	estado["detenido_previo"] = int(estado.get("detenido", 0))
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
	# Dejar un tick la pelota fuera de la cancha. Si cobramos el lateral o
	# corner en el mismo tick que cruza la linea, el fotograma se reemplaza
	# por la pelota ya acomodada para el saque y parece que se frena frente
	# al arco (sobre todo despues de un rebote central).
	if pelota.has("salida_cruzada"):
		var datos_cruce: Dictionary = pelota["salida_cruzada"]
		pelota.erase("salida_cruzada")
		pelota.erase("saliendo")
		_resolver_salida(estado, datos_cruce["punto"], bool(datos_cruce["toco_local"]))
		return
	# La pelota que ya tiene dueno decidido NO dobla hacia el: sigue
	# derecho y va frenando, y el tipo va a buscarla. Apuntarsela —como
	# hacia la primera version de esto— se ve como un iman: la pelota
	# venia en diagonal y de golpe se arrastraba de costado hasta sus
	# pies. Reportado mirando a x1.
	if pelota.has("dirigida_a"):
		pelota["vel"] *= FRENADO_PELOTA_SUELTA
		if pelota["vel"].length() < VEL_PELOTA_QUIETA:
			pelota["vel"] = Vector2.ZERO
		pelota["destino_pos"] = pelota["pos"] + pelota["vel"] * TICK_SEG
		pelota["ticks_dirigida"] = int(pelota["ticks_dirigida"]) + 1
	var desde: Vector2 = pelota["pos"]
	var destino: Vector2 = pelota.get("destino_pos", desde)
	var paso: float = pelota["vel"].length() * TICK_SEG
	var restante: float = desde.distance_to(destino)
	var llego: bool
	var hasta: Vector2
	var trayectoria: Dictionary = pelota.get("trayectoria_curva", {})
	if bool(pelota.get("es_remate", false)) and not trayectoria.is_empty():
		# El remate recorre una Bezier cuadratica. La resolucion sigue igual;
		# solo cambia el camino que ve la pelota.
		var avance_anterior := float(pelota.get("progreso_trayectoria", 0.0))
		var longitud := maxf(float(trayectoria.get("longitud", restante)), 0.01)
		var avance := minf(1.0, avance_anterior + paso / longitud)
		var origen_tray := trayectoria["origen"] as Vector2
		var control_tray := trayectoria["control"] as Vector2
		var destino_tray := trayectoria["destino"] as Vector2
		hasta = origen_tray.lerp(control_tray, avance).lerp(
			control_tray.lerp(destino_tray, avance), avance)
		pelota["progreso_trayectoria"] = avance
		pelota["vel"] = (hasta - desde) / TICK_SEG
		llego = avance >= 0.999
		destino = destino_tray
		restante = (destino_tray - hasta).length()
	else:
		llego = paso >= restante
		hasta = destino if llego else desde + pelota["vel"].normalized() * paso
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
	var avanzado: float = float(pelota.get("progreso_trayectoria",
		clampf(origen_z.distance_to(hasta) / maxf(total, 0.01), 0.0, 1.0)))
	pelota["z"] = altura_max * 4.0 * avanzado * (1.0 - avanzado) + float(pelota.get("altura_salida", 0.0)) * (1.0 - avanzado)

	# La pelota ya tiene dueno y nadie se la disputa en el camino: la
	# posesion esta decidida, lo que falta es que la ALCANCE. El tope de
	# ticks la cierra si el tipo no llega —la pelota ya freno y el queda
	# a un paso, asi que ahi el salto es chico (ver _dirigir_pelota_a).
	if pelota.has("dirigida_a"):
		var dueno: int = int(pelota["dirigida_a"])
		var alcanzada: bool = not estado["jugadores"].has(dueno) \
			or estado["jugadores"][dueno]["pos"].distance_to(hasta) <= RADIO_TOMA_PELOTA
		# Una entrega de pelota suelta no vence por tiempo: el jugador va hasta
		# ella. El timeout queda para pases/intercepciones, donde si el objetivo
		# desaparece hay que destrabar la jugada.
		var vencio_timeout: bool = int(pelota["ticks_dirigida"]) >= TICKS_DIRIGIDA_MAX \
			and str(pelota.get("pendiente", "")) != "entrega"
		if alcanzada or vencio_timeout:
			_completar_dirigida(estado, minuto, alcanzada)
		return

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
			# `saliendo` queda visible en el snapshot de este tick. El siguiente
			# tick cobra el reinicio, ya con la pelota claramente afuera.
			pelota["salida_cruzada"] = datos_salida
			pelota["altura_max"] = 0.0
			pelota["z"] = 0.0
			pelota["vel"] = Vector2.ZERO
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
	if not bool(pelota.get("es_rebote_arquero", false)) \
			and float(pelota.get("z", 0.0)) <= float(f["z_inalcanzable"]):
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
		# El que corta esta hasta radio_intercepcion (3,2 m) de la linea
		# de pase: darsela ahi mismo le teletransportaba la pelota a los
		# pies. Se la desvia hacia el y la toma cuando le llega.
		if _dirigir_pelota_a(estado, mejor_id, pelota["vel"].length(), "intercepcion", hasta):
			return
		_resolver_intercepcion(estado, mejor_id, minuto)
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
		estado["recibiendo_centro"] = true
		_resolver_centro(estado, hasta, bool(pelota.get("centro_de", pasador_local)), minuto)
		estado.erase("recibiendo_centro")
		return

	# Un rechazo del arquero puede caer dividido, quedar para un companero
	# o dejar un segundo remate. Resolverlo al llegar al punto real permite
	# disputar rebotes altos sin teletransportar la pelota a unos pies.
	if bool(pelota.get("es_rebote_arquero", false)):
		_resolver_rebote_arquero(estado, hasta, minuto)
		return

	var receptor := _mas_cercano_a(estado, hasta)
	if receptor == -1:
		_dar_pelota_al_arquero(estado, not pasador_local, true)
		return
	# Etapa 3: como llego el pase, antes de que _dirigir_pelota_a le baje
	# la altura y la pelota empiece a frenar. Con esto se mide el control.
	pelota["llegada"] = {"vel": pelota["vel"], "altura": float(pelota.get("altura_max", 0.0))}
	# El pase cae donde cae: el que se la queda puede estar a varios
	# metros del punto de llegada, porque se movio mientras la pelota
	# viajaba. La pelota rueda hasta el y la posesion cambia al llegar.
	if _dirigir_pelota_a(estado, receptor, pelota["vel"].length(), "recepcion", hasta):
		return
	_resolver_recepcion(estado, receptor, hasta, minuto)


## Le manda la pelota a quien el motor YA decidio que se la queda, en vez
## de aparecersela en los pies. Devuelve true si la puso a rodar y false
## si el tipo ya la tiene encima (dentro del radio de control), caso en
## que la jugada se resuelve en el acto como siempre.
##
## Medido con tests/_diag_salto_pelota.gd antes del cambio: el 17% de las
## recepciones y el 48% de las intercepciones movian la pelota mas de 3 m
## de un fotograma al siguiente, hasta 18,8 m. Eso es lo que se veia como
## "el pase se va afuera y de la nada aparece en los pies".
static func _dirigir_pelota_a(estado: Dictionary, clave: int, velocidad: float,
		pendiente: String, punto_llegada: Vector2) -> bool:
	var pelota: Dictionary = estado["pelota"]
	var meta: Vector2 = estado["jugadores"][clave]["pos"]
	if pelota["pos"].distance_to(meta) <= RADIO_TOMA_PELOTA:
		return false
	pelota["dirigida_a"] = clave
	pelota["pendiente"] = pendiente
	pelota["punto_llegada"] = punto_llegada
	pelota["ticks_dirigida"] = 0
	# Sin velocidad propia —un quite, una gambeta perdida— la pelota
	# estaba quieta en los pies del que la perdio: se le escapa hacia el
	# que gano el duelo, que es lo que hace el que se la saca.
	if velocidad < 0.01:
		pelota["vel"] = (meta - pelota["pos"]).normalized() * VEL_ESCAPE_DUELO
	pelota["destino_pos"] = pelota["pos"] + pelota["vel"] * TICK_SEG
	pelota["origen_pos"] = pelota["pos"]
	# Rueda por el piso: lo que venia por arriba ya bajo cuando alguien la
	# gano, y si conservara altura la parabola la levantaria de nuevo.
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	pelota.erase("es_rebote_arquero")
	pelota.erase("rebote_alto")
	pelota.erase("rebote_ataca_local")
	pelota.erase("rebote_autogol")
	pelota.erase("altura_salida")
	return true


## Entrega la pelota sin teletransportarla: si el que se la queda esta
## lejos, la pelota rueda hasta el y la toma al llegar. Es el mismo
## mecanismo del pase (ver _dirigir_pelota_a) aplicado a las jugadas que
## adjudican la pelota desde un PUNTO y no desde unos pies —un centro
## cabeceado, un rebote de bloqueo, una gambeta perdida, un quite—, donde
## el que gana puede estar a varios metros de la pelota. Encarar, sin ir
## mas lejos, se hace hasta a 8 m (radio_gambeta): perderla le aparecia
## la pelota en los pies al defensor desde esa distancia.
static func _entregar_rodando(estado: Dictionary, clave: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	var ganador: Dictionary = estado["jugadores"][clave]
	# Sin velocidad: en un duelo la pelota estaba quieta en los pies del
	# que la perdio, y _dirigir_pelota_a la empuja hacia el que gano.
	if not _dirigir_pelota_a(estado, clave, 0.0, "entrega", pelota["pos"]):
		_entregar_pelota(estado, clave)
		return
	pelota["poseedor_id"] = -1
	pelota["en_vuelo"] = true
	pelota["es_pase"] = false
	pelota["es_centro"] = false
	pelota["es_remate"] = false
	pelota["offside"] = false
	pelota.erase("pared_a")
	pelota.erase("saliendo")
	# Los que van a buscarla leen de que equipo es la pelota mientras
	# esta en el aire: ya es del que gano la jugada, no del que la perdio.
	pelota["pasador_local"] = ganador["equipo_local"]
	# La pose de bajarla con el pecho se decide al TOMARLA, y el centro
	# que la genera ya termino: hay que acordarse hasta que llegue.
	pelota["pecho_al_llegar"] = bool(estado.get("recibiendo_centro", false))


## La pelota llego a los pies del que ya la tenia adjudicada: se resuelve
## lo que quedo pendiente. El tope de ticks existe porque el dueno puede
## estar corriendo en la misma direccion que la pelota.
static func _completar_dirigida(estado: Dictionary, minuto: int, alcanzada: bool = true) -> void:
	var pelota: Dictionary = estado["pelota"]
	var clave: int = int(pelota["dirigida_a"])
	var pendiente: String = str(pelota["pendiente"])
	var punto: Vector2 = pelota["punto_llegada"]
	var pecho: bool = bool(pelota.get("pecho_al_llegar", false))
	var remate_rebote_pendiente: Dictionary = pelota.get("rebote_remate_pendiente", {})
	pelota.erase("rebote_remate_pendiente")
	_limpiar_dirigida(pelota)
	# Se fue de la cancha mientras la pelota rodaba (expulsion, cambio):
	# la agarra el mas cercano, que es lo que pasa en la cancha.
	if not estado["jugadores"].has(clave):
		clave = _mas_cercano_a(estado, pelota["pos"])
		if clave == -1:
			_dar_pelota_al_arquero(estado, not bool(pelota.get("pasador_local", true)), true)
			return
	# Se agoto el tope y el dueno no llego a la pelota: la levanta el que
	# la tiene al lado, que es lo que pasa en la cancha. Darsela igual
	# desde diez metros es el teletransporte que esto vino a sacar. El
	# duelo cuerpo a cuerpo se respeta: ahi la pelota se le escapa al que
	# la perdio hacia el que gano y la distancia es corta.
	if not alcanzada and pendiente != "entrega":
		var cerca := _mas_cercano_a(estado, pelota["pos"])
		if cerca != -1 and estado["jugadores"].has(clave) 				and estado["jugadores"][cerca]["pos"].distance_to(pelota["pos"]) 					< estado["jugadores"][clave]["pos"].distance_to(pelota["pos"]):
			clave = cerca
			pendiente = "recepcion"
	if pendiente == "entrega":
		if pecho:
			estado["recibiendo_centro"] = true
		_entregar_pelota(estado, clave)
		estado.erase("recibiendo_centro")
	elif pendiente == "intercepcion":
		_resolver_intercepcion(estado, clave, minuto)
	else:
		_resolver_recepcion(estado, clave, punto, minuto)
	if not remate_rebote_pendiente.is_empty() and estado["jugadores"].has(clave):
		_intentar_remate_rebote(estado, int(remate_rebote_pendiente.get("atacante", clave)),
				remate_rebote_pendiente.get("punto", pelota["pos"]),
				bool(remate_rebote_pendiente.get("ataca_local", true)),
				bool(remate_rebote_pendiente.get("alto", false)), minuto)


static func _limpiar_dirigida(pelota: Dictionary) -> void:
	pelota.erase("dirigida_a")
	pelota.erase("pendiente")
	pelota.erase("punto_llegada")
	pelota.erase("ticks_dirigida")
	pelota.erase("pecho_al_llegar")


## El rival se quedo con el pase.
static func _resolver_intercepcion(estado: Dictionary, mejor_id: int, minuto: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	var pasador_local: bool = pelota.get("pasador_local", true)
	_entregar_pelota(estado, mejor_id)
	estado["eventos"].append({
		"minuto": minuto, "tipo": "pase", "equipo": _equipo_de(estado, pasador_local).nombre,
		"rival": _equipo_de(estado, not pasador_local).nombre,
		"jugador_posicion": estado["jugadores"][mejor_id]["rol"], "resultado": "pierde",
	})


## El pase termino: quien la toma, la pared, el offside y el evento.
static func _resolver_recepcion(estado: Dictionary, receptor: int, hasta: Vector2, minuto: int) -> void:
	var pelota: Dictionary = estado["pelota"]
	var es_atras_coordinado: bool = bool(pelota.get("pase_atras_coordinado", false)) and receptor == int(pelota.get("destino_id", -1))
	pelota.erase("pase_atras_coordinado")
	var pasador_local: bool = pelota.get("pasador_local", true)
	var e_receptor: Dictionary = estado["jugadores"][receptor]
	# Etapa 3: la llegada que se capturo antes de que la pelota frenara. Sin
	# captura (recepcion en el acto) la pelota todavia trae su vuelo.
	var llegada: Dictionary = pelota.get("llegada",
			{"vel": pelota["vel"], "altura": float(pelota.get("altura_max", 0.0))})
	pelota.erase("llegada")

	# Si esto era el primer pase de una pared y llegó a un compañero, el
	# muro NO se queda con la pelota: la devuelve de primera al que salió
	# corriendo. Esa devolución es un segundo pase, con su propio riesgo de
	# que la corten.
	var pared_a: int = int(pelota.get("pared_a", -1))
	if pared_a != -1 and receptor == int(pelota.get("destino_id", -1)) and not bool(pelota.get("offside", false)) \
			and e_receptor["equipo_local"] == pasador_local and estado["jugadores"].has(pared_a):
		var muro := _dict_jugador(estado, _equipo_de(estado, pasador_local), e_receptor["jugador_id"])
		pelota.erase("pared_a")
		# La devolucion NO es automatica. Mientras viajaba el primer pase
		# un rival pudo cerrar el carril de retorno, y devolverla igual es
		# regalarla. Si el carril esta tapado, el muro se queda la pelota y
		# decide como cualquier poseedor: la pared se aborta y la jugada
		# sigue. Antes la devolucion salia siempre, pasara lo que pasara.
		var punto_retorno = pelota.get("pared_destino", null)
		var destino_retorno: Vector2 = estado["jugadores"][pared_a]["pos"]
		if punto_retorno != null:
			destino_retorno = punto_retorno
		var carril: float = riesgo_linea(estado, e_receptor["pos"], destino_retorno, pasador_local)
		var alcance_retorno := 0.0
		if not muro.is_empty():
			alcance_retorno = _por_atributo(muro, "pases", pesos()["fisica"]["max_dist_pase_malo"], pesos()["fisica"]["max_dist_pase_bueno"], 1.0)
		if not muro.is_empty() and e_receptor["pos"].distance_to(destino_retorno) <= alcance_retorno \
				and carril <= float(pesos_sin_pelota()["pared_riesgo_max"]):
			estado["paredes"]["muro_ok"] = int(estado["paredes"].get("muro_ok", 0)) + 1
			_entregar_pelota(estado, receptor)
			_lanzar_pase(estado, e_receptor, pared_a, muro, punto_retorno)
			return
		estado["paredes"]["abortadas"] = int(estado["paredes"].get("abortadas", 0)) + 1

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

	# Etapa 3: el pase llego y quedo registrado; falta que la controle. Solo
	# los pases: una pelota suelta o un toque largo recuperado no vuelven a
	# tirar, asi que la misma pelota no se juega dos veces.
	if bool(pelota.get("es_pase", false)):
		_controlar_recepcion(estado, receptor, llegada)
		if es_atras_coordinado and e_receptor["equipo_local"] == pasador_local and int(pelota["poseedor_id"]) == receptor:
			_contar_jugada(estado, "pase_atras_controlado")


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
##
## El cambio ESPERA a que el juego este cortado y la pelota quieta, igual
## que en el futbol. Antes arrancaba en cualquier tick y clavaba la
## pelota donde estuviera: el 17% de los cambios cortaba un pase o un
## remate en el aire (medido en tests/_diag_gol_vs_cambio.gd, 60
## partidos; ahora 9%, y ese resto es pelota ya muerta en la linea). El
## caso feo era el remate: la pelota quedaba a diez metros del arco
## durante los seis segundos de la caminata y el gol caia recien cuando
## el suplente terminaba de entrar, o sea que se veia la sustitucion
## ANTES que el gol.
##
## No hace falta reintentar desde afuera: _cerrar_tick vuelve a llamar en
## cada tick detenido, asi que el cambio entra en el primer corte que
## aparezca.
##
## `instantaneo` saltea la caminata: el que sale desaparece y el que entra
## queda parado en su lugar. Es lo que corresponde en el corte entre dos
## periodos —el cambio del entretiempo ya esta hecho cuando los equipos
## vuelven a la cancha— y ademas es lo unico que evita que el suplente
## entre trotando encima de un saque del medio ya ejecutado.
static func _sincronizar_cambios(estado: Dictionary, instantaneo: bool = false) -> void:
	# Tres condiciones, y las tres hacen falta.
	#
	# `detenido` solo no alcanza: el juego tambien esta detenido mientras
	# la pelota viaja hacia la red o sale rebotada al corner, y ahi el
	# cambio la clavaria en el aire igual. Por eso tambien se pide la
	# pelota quieta.
	#
	# Y el juego tiene que venir cortado de ANTES, no haberse cortado
	# recien en este tick, porque el fotograma trae `foco`: con alguien
	# entrando, la camara lo sigue A EL y suelta la pelota. Arrancando en
	# el tick del gol, la camara se iba al suplente justo en el fotograma
	# que la vista congela para el festejo — otra vez el cambio tapando al
	# gol. Un tick despues el gol ya quedo mostrado y el cambio entra
	# igual, adentro del mismo festejo.
	if not instantaneo and (int(estado.get("detenido", 0)) <= 0
			or int(estado.get("detenido_previo", 0)) <= 0
			or bool(estado["pelota"].get("en_vuelo", false))):
		return
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
				if instantaneo:
					estado["jugadores"].erase(clave)
				else:
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
			var entra_por: Vector2 = destino if instantaneo else _punto_de_salida(destino)
			estado["jugadores"][clave] = {
				"clave": clave, "jugador_id": j["id"], "equipo_local": es_local,
				"rol": rol, "base": base, "pos": entra_por, "vel": Vector2.ZERO,
				"objetivo": base, "vel_max": _vel_max(j),
				"aceleracion": _aceleracion(j), "rapidez": 0.0,
				# Etapa 5: el suplente entra con su propia condicion. La
				# resistencia ya es suya en Team; la reserva arranca llena
				# porque viene del banco, no del pique del que sale.
				"energia": int(j["atributos"]["energia"]), "reserva": 1.0,
				# Etapa 3: el suplente entra mirando al arco que ataca y
				# gira con su propia agilidad, no con la del que sale.
				"orientacion": orientacion_inicial(es_local), "giro": _giro_de(j),
			}
			if instantaneo:
				estado["jugadores"][clave]["marca"] = destino
				continue
			estado["entrando"].append({
				"clave": clave, "destino": destino, "ticks": 0,
				"espera_a": int(hueco["deja"]) if hueco.has("deja") else -1,
			})

	# La pausa dura hasta que termine el cambio. El juego ya estaba
	# cortado —lo pide la guarda de arriba—, pero el corte que lo detuvo
	# puede ser mas corto que la caminata, y si se reanuda antes los que
	# estan en transito quedan quietos: el bucle normal no los mueve.
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
	# Etapa 6: el arquero adentro de su area la corta con las manos, no con
	# el quite. Con el compuesto de campo cortaba con su `quite`, un atributo
	# que en un arquero no pondera nadie (position_weights.json). `achique`
	# es leer la salida; `agarre`, quedarsela.
	var e_def: Dictionary = estado["jugadores"][clave_def]
	if e_def["rol"] == "ARQ" and _en_el_area(estado["pelota"]["pos"], not bool(e_def["equipo_local"])):
		lectura = float(attrs["achique"]) * 0.6 + float(attrs["agarre"]) * 0.4
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
	if receptor["rol"] != "ARQ" and bool(pelota.get("en_vuelo", false)) and not bool(pelota.get("es_remate", false)) and (float(pelota.get("altura_max", 0.0)) >= 1.4 or bool(estado.get("recibiendo_centro", false))):
		_accion(estado, clave, "pecho")
	elif receptor["rol"] != "ARQ" and bool(pelota.get("en_vuelo", false)) and not bool(pelota.get("es_remate", false)) and float(pelota.get("altura_max", 0.0)) >= 0.35:
		_accion(estado, clave, "control_pie")
	if bool(pelota.get("es_pase", false)) \
			and bool(pelota.get("pasador_local", false)) == bool(receptor["equipo_local"]) \
			and int(pelota.get("pasador_id", -1)) != int(receptor["jugador_id"]):
		estado["ultimo_pase"] = {
			"de": int(pelota["pasador_id"]), "a": clave,
			"local": bool(receptor["equipo_local"]),
		}
		# Etapa 4: quien se la dio a quien, para detectar la pareja que se
		# devuelve la pelota sin que la jugada avance.
		_anotar_pase_de_ritmo(estado,
				clave_de(int(pelota["pasador_id"]), bool(receptor["equipo_local"])), clave)
	else:
		estado["ultimo_pase"] = {}
	pelota["poseedor_id"] = clave
	pelota["en_vuelo"] = false
	pelota["vel"] = Vector2.ZERO
	pelota["pos"] = estado["jugadores"][clave]["pos"]
	_limpiar_dirigida(pelota)
	# Etapa 3: nuevo poseedor, sin control pendiente. Si viene de un pase,
	# _controlar_recepcion le pone el suyo despues.
	pelota.erase("control")
	pelota.erase("llegada")
	pelota["ticks_con_pelota"] = 0
	pelota.erase("altura_salida")
	# Una recepci?n termina el vuelo anterior; su altura no pasa al pr?ximo pase.
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0



# ---------------------------------------------------------------------------
# Arqueros con decisiones (etapa 6)
# ---------------------------------------------------------------------------

## El arquero sin la pelota sigue una INTENCION breve, repartida una vez
## por tick desde la misma foto, igual que los desmarques (etapa 1) y la
## defensa (etapa 2):
##
## - `sostener`: se para en su ancla (_ancla_de_rol), que es lo de siempre.
## - `achicar`: un rival se le viene solo. Sale sobre la bisectriz del
##   angulo entre la pelota y los postes, con profundidad acotada.
## - `interceptar`: una pelota rival cae en su area y el llega antes que
##   cualquier atacante. Va al punto corriendo. La pelota la toma el
##   contacto de siempre (_avanzar_pelota, _resolver_centro): decidir salir
##   no le da la pelota.
## - `volver`: termino una salida y quedo lejos del ancla. Vuelve con la
##   misma fisica de todos, sin saltos.
##
## Es una cuenta pura sobre posiciones: no consume RNG.
const INTENCIONES_ARQUERO := ["sostener", "achicar", "interceptar", "volver"]

## Puntos de la trayectoria que se miran para cortar un pase. Seis tramos
## sobre un pase de 30 m son cinco metros cada uno, del orden de lo que la
## pelota recorre en un tick: mas fino no cambia el punto elegido.
const MUESTRAS_SALIDA := 6

## Hacia donde intenta manotear una pelota que no retiene, en grados desde
## "derecho al campo". Pasando los 90 va para atras, por al lado del palo:
## es el corner. Derecho al medio (0) no es candidato: es el rebote que un
## arquero evita. El orden fija el desempate.
const ANGULOS_RECHAZO := [-105.0, 105.0, -70.0, 70.0, -45.0, 45.0]

## Cuantos ticks despues de un rechazo en juego un remate cuenta como
## "remate tras rechazo". Cuatro segundos: lo que tarda la jugada del
## rebote. Solo mide.
const TICKS_REMATE_TRAS_RECHAZO := 16


## Pesos de la etapa. Como en pesos_perfil, el lector trae los valores por
## defecto y queda cacheado: se lee varias veces por tick.
static var _pesos_arquero_cache: Dictionary = {}

static func pesos_arquero() -> Dictionary:
	if not _pesos_arquero_cache.is_empty():
		return _pesos_arquero_cache
	var d: Dictionary = pesos().get("arquero", {})
	_pesos_arquero_cache = {
		"reaccion_lenta": float(d.get("reaccion_lenta", 0.6)),
		"reaccion_rapida": float(d.get("reaccion_rapida", 0.15)),
		"ventaja_base": float(d.get("ventaja_base", 0.25)),
		"ventaja_por_metro": float(d.get("ventaja_por_metro", 0.02)),
		"achique_min": float(d.get("achique_min", 2.5)),
		"achique_max": float(d.get("achique_max", 6.5)),
		"achique_dist_rival": float(d.get("achique_dist_rival", 24.0)),
		"achique_margen_pelota": float(d.get("achique_margen_pelota", 4.0)),
		"achique_carril": float(d.get("achique_carril", 2.5)),
		"volver_umbral": float(d.get("volver_umbral", 2.0)),
		"alcance_descuelgue": float(d.get("alcance_descuelgue", 1.0)),
		"cobertura_peso": float(d.get("cobertura_peso", 0.3)),
		"cobertura_referencia": float(d.get("cobertura_referencia", 0.648)),
		"rechazo_amenaza_corner": float(d.get("rechazo_amenaza_corner", 0.45)),
		"rechazo_amenaza_suelta": float(d.get("rechazo_amenaza_suelta", 0.5)),
		"rechazo_radio_amenaza": float(d.get("rechazo_radio_amenaza", 10.0)),
		"rechazo_centralidad": float(d.get("rechazo_centralidad", 1.0)),
		"rechazo_dispersion": float(d.get("rechazo_dispersion", 1.6)),
		"rechazo_dist_comoda": float(d.get("rechazo_dist_comoda", 25.0)),
	}
	return _pesos_arquero_cache


## Contadores de la etapa. Solo miden: ningun consumidor los necesita y no
## tocan el RNG.
static func _stats_arqueros(estado: Dictionary) -> Dictionary:
	if not estado.has("arqueros_stats"):
		estado["arqueros_stats"] = {
			"salidas": 0, "achiques": 0, "rechazos_afuera": 0, "rechazos_en_juego": 0,
			"remates_tras_rechazo": 0, "goles_tras_rechazo": 0,
			"duelos": 0, "cobertura_suma": 0.0,
		}
	return estado["arqueros_stats"]


## Reaccion y profundidad de achique de un arquero. Salen de `achique`,
## relativo al nivel del partido como todo lo que es lectura de juego. Se
## guardan en su dict: son derivados, no se persisten, y el suplente que
## entra sin ellos los arma solo.
static func _datos_de_arquero(estado: Dictionary, e: Dictionary) -> Dictionary:
	if e.has("datos_arquero"):
		return e["datos_arquero"]
	var w := pesos_arquero()
	var jugador := _dict_jugador(estado, _equipo_de(estado, bool(e["equipo_local"])), int(e["jugador_id"]))
	var datos := {"reaccion": lerpf(w["reaccion_lenta"], w["reaccion_rapida"], 0.5),
		"achique": lerpf(w["achique_min"], w["achique_max"], 0.5)}
	if not jugador.is_empty():
		datos["reaccion"] = _por_atributo(jugador, "achique", w["reaccion_lenta"], w["reaccion_rapida"])
		datos["achique"] = _por_atributo(jugador, "achique", w["achique_min"], w["achique_max"])
	e["datos_arquero"] = datos
	return datos


## Segundos que tarda en quedar a `contacto` metros de un punto, con la
## rampa de aceleracion. Es la inversa de _alcance_en: las dos preguntas
## tienen que usar la misma fisica o el arquero sale a pelotas que despues
## no alcanza.
static func _tiempo_hasta(e: Dictionary, punto: Vector2, contacto: float) -> float:
	var d: float = maxf((e["pos"] as Vector2).distance_to(punto) - contacto, 0.0)
	var v0: float = float(e.get("rapidez", 0.0))
	var a: float = maxf(float(e.get("aceleracion", 3.0)), 0.01)
	var vmax: float = maxf(float(e["vel_max"]), 0.1)
	var t_rampa: float = maxf(vmax - v0, 0.0) / a
	var d_rampa: float = v0 * t_rampa + 0.5 * a * t_rampa * t_rampa
	if d <= d_rampa:
		return (-v0 + sqrt(v0 * v0 + 2.0 * a * d)) / a
	return t_rampa + (d - d_rampa) / vmax


## El arquero no se mete adentro del arco. Mismo corral en X que su ancla;
## en Y la salida si puede abrirse hasta donde vaya la pelota.
static func _en_el_corral(punto: Vector2, local: bool) -> Vector2:
	if local:
		return Vector2(clampf(punto.x, -ARQUERO_X_MIN, LIMITE_X), punto.y)
	return Vector2(clampf(punto.x, -LIMITE_X, ARQUERO_X_MIN), punto.y)


## Donde conviene salir a cortar la pelota que viaja, o Vector2.INF si no
## conviene. Mira la trayectoria VISIBLE (donde esta y a donde va), no a
## quien se la tiraron.
##
## Condiciones, en este orden:
## 1. El punto esta en su area: afuera no puede usar las manos.
## 2. Llega a tiempo. A un punto del camino tiene que llegar antes que la
##    pelota; al punto final le alcanza con ser el primero, porque ahi la
##    toma el mas cercano. El centro se disputa al caer, asi que al punto
##    de caida tambien tiene que llegar antes.
## 3. Le gana al atacante mas rapido por `ventaja_base`, mas
##    `ventaja_por_metro` por cada metro que se aleja de la linea. Es el
##    precio de dejar el arco: cuanto mas lejos, mas seguro tiene que estar.
##    En el centro ese margen se mide contra la PELOTA: tiene que estar
##    plantado antes de que caiga.
## 4. Ningun companero la resuelve antes. Un central que llega primero la
##    corta sin dejar el arco vacio. En el centro no aplica: de arriba el
##    arquero tiene las manos y el central no.
static func _punto_para_interceptar(estado: Dictionary, e: Dictionary, datos: Dictionary) -> Vector2:
	var pelota: Dictionary = estado["pelota"]
	if not bool(pelota.get("en_vuelo", false)) or bool(pelota.get("es_remate", false)) \
			or pelota.has("saliendo") or pelota.has("dirigida_a"):
		return Vector2.INF
	var local: bool = e["equipo_local"]
	var es_centro: bool = bool(pelota.get("es_centro", false))
	# El pase de un companero no se corta. La pelota suelta (rebote) si.
	if bool(pelota.get("es_pase", false)) and bool(pelota.get("pasador_local", local)) == local:
		return Vector2.INF
	# El laboratorio monta el centro para mirar el cabezazo (ver
	# _resolver_centro): el arquero no sale a buscarlo.
	if es_centro and estado.has("forzar_centro"):
		return Vector2.INF
	var vel: float = (pelota["vel"] as Vector2).length()
	if vel < VEL_PELOTA_QUIETA:
		return Vector2.INF
	var desde: Vector2 = pelota["pos"]
	var hasta: Vector2 = pelota.get("destino_pos", desde)
	# Primero lo barato: si ningun punto cae en su area no hay nada que medir.
	var candidatos := []
	var muestras: int = 1 if es_centro else MUESTRAS_SALIDA
	for k in range(1, muestras + 1):
		var p: Vector2 = desde.lerp(hasta, float(k) / float(muestras))
		if _en_el_area(p, not local):
			candidatos.append({"punto": p, "final": k == muestras})
	if candidatos.is_empty():
		return Vector2.INF

	var w := pesos_arquero()
	var f: Dictionary = pesos()["fisica"]
	var contacto: float = float(f["radio_control"])
	var contacto_arq: float = ALCANCE_ESTIRADA + float(w["alcance_descuelgue"]) if es_centro else contacto
	var linea_x: float = arco_propio(local).x
	for c in candidatos:
		var p: Vector2 = c["punto"]
		var t_pelota: float = desde.distance_to(p) / vel
		var t_arq: float = _tiempo_hasta(e, p, contacto_arq) + float(datos["reaccion"])
		var espera: bool = bool(c["final"]) and not es_centro
		if not espera and t_arq > t_pelota:
			continue
		var requerida: float = float(w["ventaja_base"]) + float(w["ventaja_por_metro"]) * absf(p.x - linea_x)
		# El centro no es una carrera contra el atacante: el centro va A UN
		# atacante, que ya esta parado ahi, y el arquero lo gana con las
		# manos por arriba. Lo que tiene que sobrarle es tiempo para estar
		# plantado cuando cae.
		if es_centro:
			if t_pelota - t_arq >= requerida:
				return _en_el_corral(p, local)
			continue
		var t_rival: float = INF
		var t_companero: float = INF
		for id in estado["jugadores"]:
			if int(id) == int(e["clave"]) or _en_transito(estado, id):
				continue
			var otro: Dictionary = estado["jugadores"][id]
			var t := _tiempo_hasta(otro, p, contacto)
			if bool(otro["equipo_local"]) == local:
				t_companero = minf(t_companero, t)
			else:
				t_rival = minf(t_rival, t)
		var llega_arq: float = maxf(t_arq, t_pelota)
		var ventaja: float = maxf(t_rival, t_pelota) - llega_arq
		if ventaja < requerida:
			continue
		if maxf(t_companero, t_pelota) <= llega_arq:
			continue
		return _en_el_corral(p, local)
	return Vector2.INF


## El rival que se le viene solo, o -1. Tiene la pelota, esta de frente al
## arco y cerca, y ningun companero del arquero le tapa el camino al arco.
static func _rival_mano_a_mano(estado: Dictionary, e: Dictionary) -> int:
	var id: int = int(estado["pelota"]["poseedor_id"])
	if id == -1 or not estado["jugadores"].has(id):
		return -1
	var local: bool = e["equipo_local"]
	var rival: Dictionary = estado["jugadores"][id]
	if bool(rival["equipo_local"]) == local:
		return -1
	var w := pesos_arquero()
	var arco := arco_propio(local)
	var pos: Vector2 = rival["pos"]
	var dist: float = pos.distance_to(arco)
	if dist > float(w["achique_dist_rival"]) or absf(pos.y) > AREA_MEDIO_ANCHO:
		return -1
	for id_c in estado["jugadores"]:
		var c: Dictionary = estado["jugadores"][id_c]
		if bool(c["equipo_local"]) != local or c["rol"] == "ARQ" or _en_transito(estado, id_c):
			continue
		if (c["pos"] as Vector2).distance_to(arco) < dist \
				and _dist_a_segmento(c["pos"], pos, arco) <= float(w["achique_carril"]):
			return -1
	return id


## Donde se para para achicar: sobre la bisectriz del angulo que forman la
## pelota y los dos postes, a `profundidad` metros de la linea. Es el punto
## que tapa lo mismo de cada palo. Nunca a menos de `margen` metros de la
## pelota: mas cerca ya no achica, va al quite, y eso es otra jugada.
static func punto_de_achique(arco: Vector2, pelota: Vector2, profundidad: float, margen: float) -> Vector2:
	var poste_a := arco + Vector2(0.0, ARCO_MEDIO_ANCHO)
	var poste_b := arco - Vector2(0.0, ARCO_MEDIO_ANCHO)
	var bisectriz: Vector2 = (poste_a - pelota).normalized() + (poste_b - pelota).normalized()
	if bisectriz.length_squared() < 0.0001 or absf(bisectriz.x) < 0.0001:
		return Vector2(arco.x, clampf(pelota.y, -ARCO_MEDIO_ANCHO, ARCO_MEDIO_ANCHO))
	bisectriz = bisectriz.normalized()
	# Metros sobre la bisectriz desde la pelota hasta la linea del arco.
	var hasta_linea: float = (arco.x - pelota.x) / bisectriz.x
	if hasta_linea <= 0.0:
		return arco
	var en_linea: Vector2 = pelota + bisectriz * hasta_linea
	var prof: float = clampf(profundidad, 0.0, maxf(hasta_linea - margen, 0.0))
	return en_linea - bisectriz * prof


## Que parte del arco le tapa el arquero al que remata, de 0 a 1. Es el
## angulo entre los postes que cubre su cuerpo estirado (ALCANCE_ESTIRADA),
## visto desde la pelota. Achicar lo sube; quedar corrido de la bisectriz
## lo baja. Es geometria pura: no lee atributos ni consume RNG.
static func cobertura_arquero(estado: Dictionary, desde: Vector2, es_local: bool) -> float:
	var clave := _clave_arquero(estado, not es_local)
	if clave == -1 or _en_transito(estado, clave):
		return 0.0
	var arco := arco_rival(es_local)
	var g: Vector2 = estado["jugadores"][clave]["pos"]
	if (g - desde).dot(arco - desde) <= 0.0:
		return 0.0
	var base: float = (arco - desde).angle()
	var a1: float = wrapf((arco + Vector2(0.0, ARCO_MEDIO_ANCHO) - desde).angle() - base, -PI, PI)
	var a2: float = wrapf((arco - Vector2(0.0, ARCO_MEDIO_ANCHO) - desde).angle() - base, -PI, PI)
	var lo: float = minf(a1, a2)
	var hi: float = maxf(a1, a2)
	var dist: float = desde.distance_to(g)
	var media: float = PI * 0.5 if dist <= ALCANCE_ESTIRADA else asin(ALCANCE_ESTIRADA / dist)
	var centro: float = wrapf((g - desde).angle() - base, -PI, PI)
	var cubierto: float = maxf(0.0, minf(hi, centro + media) - maxf(lo, centro - media))
	return clampf(cubierto / maxf(hi - lo, 0.001), 0.0, 1.0)


## Cuanto vale el arquero en el duelo del remate segun donde esta parado.
## Centrado en la cobertura media que tenia ANTES de la etapa, medida con
## tests/_diag_arquero_decisiones.gd: asi el promedio de la liga no se
## mueve y lo que cambia es la diferencia entre achicar bien y quedar mal
## parado.
static func factor_cobertura(cobertura: float) -> float:
	var w := pesos_arquero()
	var peso: float = float(w["cobertura_peso"])
	return clampf(1.0 + peso * (cobertura - float(w["cobertura_referencia"])), 1.0 - peso, 1.0 + peso)


## La intencion de este tick para un arquero. `previo` es la del tick
## anterior: una salida a cortar se sostiene mientras sea el mismo vuelo,
## para que no se arrepienta a mitad de camino por una decima de ventaja.
static func _intencion_del_arquero(estado: Dictionary, e: Dictionary, ancla: Vector2, previo: Dictionary) -> Dictionary:
	var w := pesos_arquero()
	var tick: int = int(estado["tick"])
	var pelota: Dictionary = estado["pelota"]
	var local: bool = e["equipo_local"]
	var datos := _datos_de_arquero(estado, e)
	var tipo_previo: String = str(previo.get("tipo", "sostener"))

	if tipo_previo == "interceptar" and bool(pelota.get("en_vuelo", false)) \
			and not bool(pelota.get("es_remate", false)) and not pelota.has("dirigida_a") \
			and pelota.get("origen_pos", Vector2.INF) == previo.get("origen", Vector2.ZERO) \
			and pelota.get("destino_pos", Vector2.INF) == previo.get("fin", Vector2.ZERO):
		var sigue := previo.duplicate()
		sigue["tick"] = tick
		return sigue
	var punto := _punto_para_interceptar(estado, e, datos)
	if punto != Vector2.INF:
		return {"tipo": "interceptar", "destino": punto, "tick": tick, "desde": tick,
			"origen": pelota.get("origen_pos", pelota["pos"]), "fin": pelota.get("destino_pos", pelota["pos"])}

	var rival := _rival_mano_a_mano(estado, e)
	if rival != -1:
		var destino := punto_de_achique(arco_propio(local), estado["jugadores"][rival]["pos"],
			float(datos["achique"]), float(w["achique_margen_pelota"]))
		return {"tipo": "achicar", "destino": _en_el_corral(destino, local), "tick": tick,
			"desde": int(previo.get("desde", tick)) if tipo_previo == "achicar" else tick}

	if tipo_previo != "sostener" and (e["pos"] as Vector2).distance_to(ancla) > float(w["volver_umbral"]):
		return {"tipo": "volver", "destino": ancla, "tick": tick, "desde": tick}
	return {"tipo": "sostener", "destino": ancla, "tick": tick, "desde": tick}


## Reparte la intencion de los dos arqueros desde la misma foto, antes de
## mover a nadie. Orden estable por clave.
static func _planificar_arqueros(estado: Dictionary, equipo_con_pelota: bool) -> void:
	var planes: Dictionary = estado.get("arqueros", {})
	estado["arqueros"] = planes
	var claves := []
	for id in estado["jugadores"]:
		if estado["jugadores"][id]["rol"] == "ARQ" and not _en_transito(estado, id):
			claves.append(int(id))
	claves.sort()
	for clave in planes.keys():
		if not claves.has(int(clave)):
			planes.erase(clave)
	for clave in claves:
		var e: Dictionary = estado["jugadores"][clave]
		var local: bool = e["equipo_local"]
		var ancla: Vector2 = _ancla_de_rol(estado, e, _equipo_de(estado, local), local == equipo_con_pelota)["punto"]
		var previo: Dictionary = planes.get(clave, {})
		var plan := _intencion_del_arquero(estado, e, ancla, previo)
		var tipo: String = plan["tipo"]
		if tipo != str(previo.get("tipo", "")):
			if tipo == "interceptar":
				_stats_arqueros(estado)["salidas"] += 1
			elif tipo == "achicar":
				_stats_arqueros(estado)["achiques"] += 1
		planes[clave] = plan


## La intencion vigente de un arquero, o {} si no tiene una de este tick.
static func intencion_arquero(estado: Dictionary, clave: int) -> Dictionary:
	var plan: Dictionary = estado.get("arqueros", {}).get(clave, {})
	if plan.is_empty() or int(plan.get("tick", -1)) != int(estado["tick"]):
		return {}
	return plan


## A donde va el arquero sin la pelota. Sin intencion de este tick —una
## escena armada a mano, el primer tick despues de un corte— va al ancla,
## que es lo que hacia antes de la etapa.
static func _objetivo_del_arquero(estado: Dictionary, e: Dictionary, ancla: Vector2) -> Vector2:
	var plan := intencion_arquero(estado, int(e["clave"]))
	if plan.is_empty() or str(plan["tipo"]) == "sostener" or str(plan["tipo"]) == "volver":
		return ancla
	return plan["destino"]


## Que tan peligroso es dejar la pelota en `punto`: atacantes cerca, y un
## remate de frente y cerca desde ahi. Sin RNG: la eleccion es del
## arquero, el azar entra despues como error de ejecucion.
##
## El frente se mide con factor_angulo y no con valor_posicion: todos los
## puntos a diez metros del arquero estan a unos diez metros del arco, y
## valor_posicion les da a todos casi lo mismo (1 - 10/105, unos 0,90).
## Con ese termino ningun costado le ganaba nunca al corner: medido, 0
## rechazos en juego en 168 partidos. Lo que separa el
## rebote servido del rebote inofensivo es el ANGULO, no la distancia.
static func _amenaza_de_rebote(estado: Dictionary, punto: Vector2, ataca_local: bool) -> float:
	var w := pesos_arquero()
	var radio: float = float(w["rechazo_radio_amenaza"])
	var amenaza := 0.0
	for id in estado["jugadores"]:
		var c: Dictionary = estado["jugadores"][id]
		if bool(c["equipo_local"]) != ataca_local or _en_transito(estado, id):
			continue
		amenaza += maxf(0.0, 1.0 - punto.distance_to(c["pos"]) / radio)
	var cerca: float = clampf(1.0 - punto.distance_to(arco_rival(ataca_local)) / float(w["rechazo_dist_comoda"]), 0.0, 1.0)
	return amenaza + float(w["rechazo_centralidad"]) * factor_angulo(punto, ataca_local) * cerca


## Donde cruza la linea de la cancha una pelota que sale de `desde` en
## direccion `dir`.
static func _cruce_con_la_linea(desde: Vector2, dir: Vector2) -> Vector2:
	var t := INF
	if absf(dir.x) > 0.0001:
		t = minf(t, (MEDIO_LARGO * signf(dir.x) - desde.x) / dir.x)
	if absf(dir.y) > 0.0001:
		t = minf(t, (MEDIO_ANCHO * signf(dir.y) - desde.y) / dir.y)
	return desde + dir * maxf(t, 0.0)


## La ataja pero no la retiene. Antes iba SIEMPRE al corner. Ahora el
## arquero elige a donde la manda entre los dos corners —si la linea le
## queda a tiro— y cuatro direcciones hacia los costados, por la menor
## amenaza (_amenaza_de_rebote). Despues la ejecucion se desvia: mas cuanto
## peor es su `estirada` y mas cerca vino el remate. Asi un buen arquero la
## saca por al lado del palo y a veces, igual, el rebote le queda en juego.
static func _rechazar_remate(estado: Dictionary, datos: Dictionary) -> void:
	var ataca_local: bool = bool(datos["es_local"])
	var clave := _clave_arquero(estado, not ataca_local)
	if clave == -1:
		_manotear_al_corner(estado, ataca_local)
		return
	var w := pesos_arquero()
	var f: Dictionary = pesos()["fisica"]
	var rng: RandomNumberGenerator = estado["rng"]
	var stats := _stats_arqueros(estado)
	var e_arq: Dictionary = estado["jugadores"][clave]
	var desde: Vector2 = e_arq["pos"]
	var hacia_campo := Vector2(-signf(arco_rival(ataca_local).x), 0.0)
	var largo_medio: float = 0.5 * (float(f["rebote_largo_min"]) + float(f["rebote_largo_max"]))
	var jugador_arq := _dict_jugador(estado, _equipo_de(estado, not ataca_local), int(e_arq["jugador_id"]))
	var attrs_arq: Dictionary = jugador_arq.get("atributos", {})
	var agarre: float = clampf(float(datos.get("agarre", float(attrs_arq.get("agarre", 50.0)) / 100.0)), 0.0, 1.0)
	var reflejos: float = clampf(float(attrs_arq.get("reflejos", 50.0)) / 100.0, 0.0, 1.0)
	var estirada: float = clampf(float(attrs_arq.get("estirada", 50.0)) / 100.0, 0.0, 1.0)
	var calidad_rechazo: float = clampf(agarre * 0.55 + reflejos * 0.25 + estirada * 0.20, 0.0, 1.0)
	var dificultad_rebote: float = clampf(1.0 - float(datos.get("dist", 16.0)) / float(w["rechazo_dist_comoda"]), 0.0, 1.0)
	# Un arquero con peor agarre/reflejos no solo rechaza mas: tambien deja
	# rebotes altos y dificiles de leer. El buen arquero tiende a amortiguar.
	var chance_rebote_alto: float = clampf(0.62 - calidad_rechazo * 0.45
		+ dificultad_rebote * 0.12, 0.12, 0.70)
	var rebote_alto: bool = rng.randf() < chance_rebote_alto

	var linea_x: float = arco_rival(ataca_local).x
	var angulo: float = deg_to_rad(float(ANGULOS_RECHAZO[0]))
	var menor := INF
	var menor_lado := INF
	for grados in ANGULOS_RECHAZO:
		# La amenaza de ESE costado desempata: si el manotazo al corner le sale
		# corto, queda en juego de ese lado, asi que tambien se tira al corner
		# del lado donde no hay nadie.
		var lateral: Vector2 = desde + hacia_campo.rotated(deg_to_rad(minf(absf(grados), 70.0) * signf(grados))) * largo_medio
		var lado := _amenaza_de_rebote(estado, lateral, ataca_local)
		var dir_candidata: Vector2 = hacia_campo.rotated(deg_to_rad(grados))
		var punto: Vector2 = desde + dir_candidata * largo_medio
		var amenaza: float = float(w["rechazo_amenaza_suelta"]) + _amenaza_de_rebote(estado, punto, ataca_local)
		# Al corner solo si la linea le queda a tiro (rebote_largo_max). El
		# que ataja achicando, lejos de su arco, no la manda por al lado del
		# palo: le queda en juego igual que un costado.
		if absf(float(grados)) > 90.0 and absf((linea_x - desde.x) / dir_candidata.x) <= float(f["rebote_largo_max"]):
			amenaza = float(w["rechazo_amenaza_corner"])
		if amenaza < menor or (is_equal_approx(amenaza, menor) and lado < menor_lado):
			menor = amenaza
			menor_lado = lado
			angulo = deg_to_rad(float(grados))

	var jugador := _dict_jugador(estado, _equipo_de(estado, not ataca_local), int(e_arq["jugador_id"]))
	var habilidad: float = _por_atributo(jugador, "estirada", 0.0, 1.0) if not jugador.is_empty() else 0.5
	var dificultad: float = clampf(1.0 - float(datos.get("dist", 16.0)) / float(w["rechazo_dist_comoda"]), 0.0, 1.0)
	var dispersion: float = float(w["rechazo_dispersion"]) * (1.0 - 0.7 * habilidad) * (0.3 + 0.7 * dificultad)
	var dir: Vector2 = hacia_campo.rotated(angulo + rng.randf_range(-1.0, 1.0) * dispersion)
	var largo: float = rng.randf_range(float(f["rebote_largo_min"]), float(f["rebote_largo_max"]))
	var destino: Vector2 = desde + dir * largo
	var rebote_aereo_forzado := bool(estado.get("forzar_rebote_aereo", false))
	if rebote_aereo_forzado:
		var cadena: Dictionary = estado.get("cadena_rebotes", {})
		var punto_forzado: Vector2 = cadena.get("punto", desde + hacia_campo * 5.5)
		if punto_forzado.distance_to(desde) < 0.5:
			punto_forzado = desde + hacia_campo * 5.5
		destino = punto_forzado
		dir = (destino - desde).normalized()
		largo = desde.distance_to(destino)
		rebote_alto = true
		estado.erase("forzar_rebote_aereo")
	# Para atras sale por el fondo si la linea esta dentro del rebote mas
	# largo: la desvio con la fuerza del remate, no con la del rebote suelto.
	# Si no llega —casi paralela a la linea, o manoteada lejos del arco—
	# queda en juego. Con el cruce geometrico a secas, la pelota casi
	# paralela a la linea salia por el lateral a 34 m.
	var cruce := Vector2.INF
	if dir.dot(hacia_campo) < 0.0:
		var hasta_fondo: float = absf((linea_x - desde.x) / dir.x) if absf(dir.x) > 0.0001 else INF
		if hasta_fondo <= float(f["rebote_largo_max"]):
			cruce = Vector2(linea_x, desde.y + dir.y * hasta_fondo)
	elif absf(destino.x) >= MEDIO_LARGO or absf(destino.y) >= MEDIO_ANCHO:
		cruce = _cruce_con_la_linea(desde, dir)
	if cruce != Vector2.INF:
		# Error extremo: una pelota manoteada hacia atras puede meterse en
		# el propio arco. Es raro y depende de la calidad del arquero.
		if absf(cruce.x) >= MEDIO_LARGO - 0.01 and absf(cruce.y) <= ARCO_MEDIO_ANCHO \
			and dir.dot(hacia_campo) < 0.0:
			var chance_autogol: float = clampf(0.003 + (1.0 - calidad_rechazo) * 0.014, 0.001, 0.018)
			if rng.randf() < chance_autogol:
				stats["rechazos_en_juego"] += 1
				estado["ultimo_rechazo_tick"] = int(estado["tick"])
				_soltar_pelota(estado, desde, cruce, not ataca_local)
				var pelota_autogol: Dictionary = estado["pelota"]
				pelota_autogol["es_rebote_arquero"] = true
				pelota_autogol["rebote_ataca_local"] = ataca_local
				pelota_autogol["rebote_autogol"] = true
				pelota_autogol["rebote_alto"] = false
				return
		# Por el fondo, nunca adentro del arco propio: la saca por al lado.
		if absf(cruce.x) >= MEDIO_LARGO - 0.01 and absf(cruce.y) <= ARCO_MEDIO_ANCHO + 0.5:
			cruce.y = (ARCO_MEDIO_ANCHO + 0.5) * (1.0 if cruce.y >= 0.0 else -1.0)
		stats["rechazos_afuera"] += 1
		_pelota_fuera(estado, cruce, not ataca_local)
		return
	stats["rechazos_en_juego"] += 1
	estado["ultimo_rechazo_tick"] = int(estado["tick"])
	_soltar_pelota(estado, desde, destino, not ataca_local)
	var pelota_rebote: Dictionary = estado["pelota"]
	pelota_rebote["es_rebote_arquero"] = true
	pelota_rebote["rebote_ataca_local"] = ataca_local
	pelota_rebote["rebote_alto"] = rebote_alto
	pelota_rebote["altura_max"] = clampf(1.35 + (1.0 - calidad_rechazo) * 2.8
		+ rng.randf_range(-0.25, 0.45), 1.1, 4.5) if rebote_alto else 0.0
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "rebote_arquero",
		"equipo": _equipo_de(estado, ataca_local).nombre,
		"rival": _equipo_de(estado, not ataca_local).nombre,
		"jugador_posicion": "ARQ", "clave": clave,
		"resultado": "alto" if rebote_alto else "raso",
		"altura": float(pelota_rebote["altura_max"]),
	})


# ---------------------------------------------------------------------------
# Defensa coordinada (etapa 2)
# ---------------------------------------------------------------------------

## El equipo que no tiene la pelota reparte RESPONSABILIDADES una sola
## vez, igual que el reparto de desmarques de la etapa 1: presionante,
## cobertura y cierre de linea. Antes cada uno decidia solo —los dos mas
## cercanos a la pelota salian— y eso daba dos problemas: el segundo
## corria a la misma pelota que el primero en vez de taparle la salida, y
## el par cambiaba de tick en tick porque la distancia cruda oscila.
##
## - `presionante`: va a la pelota. Sale por TIEMPO DE LLEGADA, no por
##   distancia: el que esta mas cerca pero cansado y fuera de su zona
##   llega despues que el que esta dos metros mas lejos.
## - `cobertura`: se para detras del presionante, hacia el arco propio.
##   Es la que sostiene el repliegue si al presionante lo pasan.
## - `cierre`: tapa una linea de pase DISTINTA. Solo si el estilo lo
##   permite o si los disparadores de presion estan activos.
##
## El resto queda en el bloque y lo gobierna `_ancla_de_rol`, con la
## correa de zona que aplica `_recortar_a_la_zona`.
const TICKS_DEFENSA_MIN := TICKS_PLAN

## Hasta donde puede alejarse cada linea de su casillero cuando defiende.
## Es la correa del bloque: limita la basculacion lateral y el
## adelantamiento, nunca el retroceso —un central siempre puede bajar a
## su area.
const ZONA_POR_ROL := {
	"DFC": "radio_defensa", "LAT": "radio_defensa",
	"MC": "radio_medio", "MCO": "radio_medio",
	"EXT": "radio_ataque", "DC": "radio_ataque",
}


## Pesos de la defensa coordinada. Como en pesos_sin_pelota, el lector
## trae los valores por defecto: un json sin la seccion sigue andando.
##
## El resultado queda cacheado. Sin la cache, armar este diccionario una
## vez por candidato y por tick costaba el 48% del tiempo de partido
## (medido con corridas pareadas y alternadas: 613 ms contra 416 ms).
static var _pesos_defensa_cache: Dictionary = {}

static func pesos_defensa() -> Dictionary:
	if not _pesos_defensa_cache.is_empty():
		return _pesos_defensa_cache
	var d: Dictionary = pesos().get("defensa", {})
	_pesos_defensa_cache = {
		"zona": float(d.get("zona", 0.06)),
		"cansancio": float(d.get("cansancio", 0.5)),
		"mejora_presionante": float(d.get("mejora_presionante", 0.20)),
		"cobertura_atras": float(d.get("cobertura_atras", 8.0)),
		"cobertura_cerca": float(d.get("cobertura_cerca", 0.6)),
		"cobertura_bloque": float(d.get("cobertura_bloque", 1.6)),
		"enganche": float(d.get("enganche", 3.5)),
		"cierre_cerca": float(d.get("cierre_cerca", 4.0)),
		"cierre_lejos": float(d.get("cierre_lejos", 24.0)),
		"cierre_carril": float(d.get("cierre_carril", 0.55)),
		"banda_disparador": float(d.get("banda_disparador", 8.0)),
		"intensidad_para_cierre": float(d.get("intensidad_para_cierre", 0.6)),
		"radio_defensa": float(d.get("radio_defensa", 12.0)),
		"radio_medio": float(d.get("radio_medio", 16.0)),
		"radio_ataque": float(d.get("radio_ataque", 20.0)),
	}
	return _pesos_defensa_cache


## Cuanto tarda este jugador en llegar a un punto. No es distancia sobre
## velocidad a secas: se le suma lo que cuesta abandonar la zona y lo que
## pesa el cansancio. Las dos penalizaciones estan en SEGUNDOS, asi que el
## resultado se sigue leyendo como tiempo y se compara entre candidatos.
static func _tiempo_de_llegada(estado: Dictionary, e: Dictionary, destino: Vector2) -> float:
	var w := pesos_defensa()
	var equipo := _equipo_de(estado, bool(e["equipo_local"]))
	var resistencia: float = equipo.resistencia_pct(int(e["jugador_id"]))
	var vel: float = maxf(float(e["vel_max"]) * clampf(resistencia, 0.3, 1.0), 0.5)
	var t: float = (e["pos"] as Vector2).distance_to(destino) / vel
	# Abandonar la zona: lo que el destino se pasa del radio de su rol.
	var radio: float = float(w[str(ZONA_POR_ROL.get(str(e["rol"]), "radio_medio"))])
	var fuera: float = maxf(0.0, (e["base"] as Vector2).distance_to(destino) - radio)
	t += fuera * float(w["zona"])
	t += (1.0 - clampf(resistencia, 0.0, 1.0)) * float(w["cansancio"])
	return t


## Recorta un destino defensivo a la zona del rol. Solo limita hacia
## adelante y de costado: el que retrocede a su propia area no tiene
## correa. Sin esto el bloque entero se desliza hacia la pelota y el
## centro queda abierto.
static func _recortar_a_la_zona(e: Dictionary, punto: Vector2) -> Vector2:
	var w := pesos_defensa()
	var radio: float = float(w[str(ZONA_POR_ROL.get(str(e["rol"]), "radio_medio"))])
	var base: Vector2 = e["base"]
	var hacia_rival: float = 1.0 if e["equipo_local"] else -1.0
	var adelante: float = (punto.x - base.x) * hacia_rival
	var x: float = punto.x
	if adelante > radio:
		x = base.x + radio * hacia_rival
	return Vector2(x, clampf(punto.y, base.y - radio, base.y + radio))


## Disparadores de presion (0 a 1). Miran la SITUACION visible, no la
## decision que el rival todavia no tomo: pelota suelta o recien
## controlada, poseedor mirando a su propio arco, pelota pegada a la
## banda y la ventana corta que se abre despues de una perdida.
static func _intensidad_de_presion(estado: Dictionary, defiende_local: bool) -> float:
	var w := pesos_defensa()
	var pelota: Dictionary = estado["pelota"]
	var senales := 0.0
	var id: int = int(pelota["poseedor_id"])
	if id == -1 or int(pelota.get("ticks_con_pelota", 99)) <= 1:
		senales += 1.0  # control largo: la pelota todavia no esta dominada
	if id != -1 and estado["jugadores"].has(id):
		var p: Dictionary = estado["jugadores"][id]
		var hacia_su_arco: Vector2 = (arco_rival(bool(p["equipo_local"])) - (p["pos"] as Vector2)).normalized()
		var v: Vector2 = p["vel"]
		if v.length_squared() > 0.25 and v.normalized().dot(hacia_su_arco) < 0.0:
			senales += 1.0  # recibio de espaldas y va hacia atras
	if absf((pelota["pos"] as Vector2).y) > MEDIO_ANCHO - float(w["banda_disparador"]):
		senales += 1.0  # contra la banda, con media cancha menos para salir
	# Tras la perdida hay una ventana para apretar antes de que se ordenen.
	senales += _transicion(estado, not defiende_local)
	return clampf(senales / 3.0, 0.0, 1.0)


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


## Donde se para la cobertura: detras del presionante, sobre la recta que
## va de el al arco propio. Con los disparadores activos se acerca, para
## que el equipo apriete junto; sin ellos se queda mas atras y sostiene el
## repliegue.
static func _punto_de_cobertura(estado: Dictionary, presionante: Dictionary, intensidad: float) -> Vector2:
	var w := pesos_defensa()
	var arco: Vector2 = arco_propio(bool(presionante["equipo_local"]))
	var dir: Vector2 = arco - (presionante["pos"] as Vector2)
	if dir.length() < 0.5:
		dir = Vector2(-1.0 if presionante["equipo_local"] else 1.0, 0.0)
	var atras: float = float(w["cobertura_atras"]) * lerpf(1.0, float(w["cobertura_cerca"]), intensidad)
	# Los estilos de bloque cubren mas atras: el segundo no acompaña la
	# presion, sostiene la linea. Es lo que reemplaza a la regla vieja de
	# _perseguidores, que directamente no le daba un segundo al bloque —y
	# asi el que superaba al primero no se cruzaba con nadie.
	var estilo: String = _equipo_de(estado, bool(presionante["equipo_local"])).estilo
	if estilo == "Contragolpe" or estilo == "Defensivo":
		atras *= float(w["cobertura_bloque"])
	# Etapa 7: el que gana cubre mas atras. Es la contracara de la altura
	# del bloque — protege el espacio que deja el que se adelanta.
	var guarda: float = maxf(0.0, -urgencia(estado, bool(presionante["equipo_local"])))
	atras *= 1.0 + guarda * float(pesos_marcador()["cobertura_extra"])
	return (presionante["pos"] as Vector2) + dir.normalized() * atras


## Que linea de pase tapa el cierre: la del receptor mas cercano al
## poseedor que no este ya cubierto por la cobertura. Responde a donde
## estan parados los rivales, no al pase que el poseedor va a elegir.
static func _punto_de_cierre(estado: Dictionary, defiende_local: bool, evitar: Vector2) -> Vector2:
	var w := pesos_defensa()
	var pelota: Vector2 = estado["pelota"]["pos"]
	var salidas := []
	for id in estado["jugadores"]:
		var comp: Dictionary = estado["jugadores"][id]
		if comp["equipo_local"] == defiende_local or comp["rol"] == "ARQ":
			continue
		var dist: float = pelota.distance_to(comp["pos"])
		if dist > float(w["cierre_cerca"]) and dist < float(w["cierre_lejos"]):
			salidas.append({"clave": int(id), "pos": comp["pos"] as Vector2})
	# Orden estable: la distancia manda y la clave rompe el empate, asi dos
	# corridas con la misma semilla eligen el mismo carril.
	salidas.sort_custom(func(a, b):
		var da: float = pelota.distance_squared_to(a["pos"])
		var db: float = pelota.distance_squared_to(b["pos"])
		if is_equal_approx(da, db):
			return int(a["clave"]) < int(b["clave"])
		return da < db)
	for s in salidas:
		var punto: Vector2 = pelota.lerp(s["pos"], float(w["cierre_carril"]))
		if punto.distance_to(evitar) > 4.0:
			return punto
	return Vector2.INF


## Reparte las tres responsabilidades del equipo que defiende y las deja
## en el estado. Las sostiene TICKS_DEFENSA_MIN ticks: el presionante solo
## cambia si otro le mejora el tiempo de llegada en `mejora_presionante`,
## y asi el par no se intercambia cada fotograma por un metro de
## diferencia. El cierre se recalcula siempre, porque depende del estilo y
## de los disparadores, que cambian solos.
static func _planificar_defensa(estado: Dictionary, equipo_con_pelota_local: bool) -> Dictionary:
	var w := pesos_defensa()
	var w_m := pesos_marcador()
	var defiende_local: bool = not equipo_con_pelota_local
	var plan: Dictionary = estado.get("defensa", {})
	# Cambio de manos: el reparto anterior era del otro equipo.
	if plan.is_empty() or bool(plan.get("local", not defiende_local)) != defiende_local:
		plan = {"local": defiende_local, "presionante": -1, "cobertura": -1, "hasta": -1}
	estado["defensa"] = plan

	var pelota: Vector2 = estado["pelota"]["pos"]
	var intensidad := _intensidad_de_presion(estado, defiende_local)

	var disponibles := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] != defiende_local or e["rol"] == "ARQ":
			continue
		if _en_cooldown(estado, id) or _en_transito(estado, id):
			continue  # quedo mal parado o se esta yendo: no sale a presionar
		disponibles.append(int(id))
	disponibles.sort()

	# --- Presionante: el de menor tiempo de llegada a la pelota --------
	var mejor := -1
	var mejor_t: float = INF
	for id in disponibles:
		var e: Dictionary = estado["jugadores"][id]
		var t := _tiempo_de_llegada(estado, e, _punto_de_presion(estado, e, pelota))
		if t < mejor_t:
			mejor_t = t
			mejor = id
	var presionante: int = int(plan["presionante"])
	var sostiene: bool = presionante != -1 and disponibles.has(presionante) \
		and int(estado["tick"]) < int(plan["hasta"])
	if sostiene and mejor != -1 and mejor != presionante:
		var actual: Dictionary = estado["jugadores"][presionante]
		var t_actual := _tiempo_de_llegada(estado, actual, _punto_de_presion(estado, actual, pelota))
		if mejor_t < t_actual * (1.0 - float(w["mejora_presionante"])):
			sostiene = false
	if not sostiene:
		presionante = mejor
		plan["hasta"] = int(estado["tick"]) + TICKS_DEFENSA_MIN
		plan["enganchado"] = false
	plan["presionante"] = presionante
	# Se engancho: llego a la distancia de disputa. A partir de ahi tiene
	# sentido preguntarse si lo pasaron (ver _presion_superada).
	if presionante != -1 and estado["jugadores"][presionante]["pos"].distance_to(pelota) <= float(w["enganche"]):
		plan["enganchado"] = true

	# --- Cobertura: entre los que quedan, la que llega antes al punto --
	var cobertura: int = int(plan.get("cobertura", -1))
	if presionante == -1:
		cobertura = -1
	else:
		var punto_cob := _punto_de_cobertura(estado, estado["jugadores"][presionante], intensidad)
		if cobertura == presionante or not disponibles.has(cobertura) or int(estado["tick"]) >= int(plan["hasta"]):
			cobertura = -1
			var t_cob: float = INF
			for id in disponibles:
				if id == presionante:
					continue
				var t := _tiempo_de_llegada(estado, estado["jugadores"][id], punto_cob)
				if t < t_cob:
					t_cob = t
					cobertura = id
	plan["cobertura"] = cobertura

	# --- Cierre de linea: un tercero tapa una salida distinta ----------
	# Pide cobertura: sin nadie atras, el tercero que sale deja el bloque
	# partido. Y si al presionante YA lo pasaron, no se cierra nada — lo
	# que corresponde es replegar.
	var cierre := -1
	var punto_cierre := Vector2.INF
	if presionante != -1 and cobertura != -1:
		var estilo: String = _equipo_de(estado, defiende_local).estilo
		# Etapa 7: el que necesita la pelota sale a cerrar con menos
		# excusa; el que cuida el resultado no manda un tercero ni con los
		# disparadores activos. El estilo Presion alta sigue cerrando
		# siempre salvo que este guardando el partido.
		var urg_def := urgencia(estado, defiende_local)
		var umbral: float = float(w["intensidad_para_cierre"]) - urg_def * float(w_m["cierre"])
		var guardando: bool = urg_def <= -float(w_m["urgencia_para_guardar"])
		var permite: bool = not guardando and (estilo == "Presión alta" or intensidad >= umbral)
		if permite and not _presion_superada(estado, defiende_local, plan):
			punto_cierre = _punto_de_cierre(estado, defiende_local,
				_punto_de_cobertura(estado, estado["jugadores"][presionante], intensidad))
			if punto_cierre != Vector2.INF:
				var t_cierre: float = INF
				for id in disponibles:
					if id == presionante or id == cobertura:
						continue
					var t := _tiempo_de_llegada(estado, estado["jugadores"][id], punto_cierre)
					if t < t_cierre:
						t_cierre = t
						cierre = id
	plan["cierre"] = cierre
	plan["punto_cierre"] = punto_cierre
	plan["intensidad"] = intensidad
	return plan


## ¿Al presionante ya lo pasaron? Pide las dos cosas: que haya llegado a
## engancharse con la pelota alguna vez —el plan lo recuerda— y que ahora
## la pelota este del lado de su arco. Sin la primera condicion cualquier
## delantero que presiona desde adelante daba "superado" en el primer
## tick, porque la pelota siempre esta mas cerca del arco que el.
static func _presion_superada(estado: Dictionary, defiende_local: bool, plan: Dictionary) -> bool:
	if not bool(plan.get("enganchado", false)):
		return false
	var presionante: int = int(plan.get("presionante", -1))
	var id: int = int(estado["pelota"]["poseedor_id"])
	if id == -1 or not estado["jugadores"].has(id) or not estado["jugadores"].has(presionante):
		return false
	var arco: Vector2 = arco_propio(defiende_local)
	var d_pelota: float = arco.distance_to(estado["jugadores"][id]["pos"])
	var d_presionante: float = arco.distance_to(estado["jugadores"][presionante]["pos"])
	return d_pelota < d_presionante - 2.0


## Quienes del equipo que NO tiene la pelota salen del bloque. Es la
## lectura del reparto: presionante, cobertura y cierre, en ese orden.
## Con uno solo, el que conduce se lo saca de encima y sigue de largo.
static func _perseguidores(estado: Dictionary, equipo_con_pelota_local: bool) -> Array:
	var plan := _planificar_defensa(estado, equipo_con_pelota_local)
	var salida := []
	for papel in ["presionante", "cobertura", "cierre"]:
		var id: int = int(plan.get(papel, -1))
		if id != -1:
			salida.append(id)
	return salida


## Adonde va cada uno de los tres. El papel lo decidio el reparto; aca
## solo se traduce a un punto.
static func _objetivo_de_presion(estado: Dictionary, e: Dictionary) -> Vector2:
	var pelota: Vector2 = estado["pelota"]["pos"]
	var objetivo := _punto_de_presion(estado, e, pelota)
	var plan: Dictionary = estado.get("defensa", {})
	var clave: int = int(e["clave"])
	# El arquero con la pelota en la mano: todos se plantan en el borde.
	if objetivo != pelota or int(plan.get("presionante", -1)) == clave:
		return objetivo
	if int(plan.get("cobertura", -1)) == clave:
		var id_p: int = int(plan.get("presionante", -1))
		if estado["jugadores"].has(id_p):
			return _punto_de_cobertura(estado, estado["jugadores"][id_p], float(plan.get("intensidad", 0.0)))
		return objetivo
	if int(plan.get("cierre", -1)) == clave:
		var punto = plan.get("punto_cierre", Vector2.INF)
		if punto != Vector2.INF:
			return punto
	return objetivo


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
	var cadencia := cadencia_de_decision(jugador, equipo)
	# Etapa 3: la primera decision despues de recibir un pase espera la
	# demora de control de ESA recepcion, en lugar de la cadencia. Despues
	# reconsidera cada `cadencia` ticks, como antes. Sin control pendiente
	# la demora es la cadencia y el motor decide en los mismos ticks que
	# antes de la etapa.
	var demora := cadencia
	var control: Dictionary = pelota.get("control", {})
	if int(control.get("clave", -1)) == int(poseedor["clave"]):
		demora = int(control["demora"])
	var ticks: int = int(pelota.get("ticks_con_pelota", 0))
	if ticks < demora or (ticks - demora) % cadencia != 0:
		# El arquero no sale conduciendo mientras piensa: se queda con la
		# pelota. Quitarle "conducir" de las opciones no alcanzaba, porque
		# este atajo lo hace avanzar igual en todos los ticks en que no
		# decide — y así se lo veía salir caminando del área.
		if poseedor["rol"] != "ARQ":
			_conducir(estado, poseedor)
		else:
			girar_hacia(poseedor, arco_rival(es_local) - poseedor["pos"])
		return

	var opciones := evaluar_opciones(estado, poseedor, jugador)
	# Etapa 3: lo que manda la pelota a su espalda espera a que gire. Si no
	# queda nada para jugar, gira este tick y vuelve a decidir en el
	# siguiente: el giro avanza cada tick, asi que la espera tiene fin.
	if not opciones.is_empty():
		var orientadas := _opciones_orientadas(estado, opciones, poseedor)
		if orientadas.size() < opciones.size():
			var st_c: Dictionary = estado.get("control_stats", {})
			st_c["decisiones_con_giro"] = int(st_c.get("decisiones_con_giro", 0)) + 1
		if orientadas.is_empty():
			pelota["control"] = {"clave": int(poseedor["clave"]), "demora": ticks + 1}
			if poseedor["rol"] != "ARQ":
				_conducir(estado, poseedor)
			else:
				girar_hacia(poseedor, arco_rival(es_local) - poseedor["pos"])
			return
		opciones = orientadas
	if opciones.is_empty():
		# Sin opciones y sin poder conducir, el arquero se quedaría con la
		# pelota para siempre: la revienta, que es lo que hace cualquier
		# arquero sin salida.
		if poseedor["rol"] == "ARQ":
			_despejar(estado, poseedor, jugador)
		return
	var presion := presion_normalizada(estado, poseedor["pos"], es_local)
	var temp := temperatura(jugador, presion)
	_premiar_descarga_util(estado, poseedor, opciones)
	var elegida := elegir_softmax(opciones, temp, estado["rng"])
	if bool(estado.get("medir_opciones_colectivas", false)):
		var disponibles := {}
		for opcion in opciones:
			for marca in ["tercer_hombre", "llegada_coordinada", "cambio_frente", "corrida_preparada", "aceleracion_preparada"]:
				if bool(opcion.get("detalle", {}).get(marca, false)):
					disponibles[marca] = true
			if not opcion.get("enganche", {}).is_empty():
				disponibles["enganche"] = true
		for marca in disponibles:
			_contar_jugada(estado, "disponible_" + marca)

	estado["decisiones"][elegida["tipo"]] = estado["decisiones"].get(elegida["tipo"], 0) + 1
	_medir_pase_atras(estado, elegida, poseedor, presion)
	for marca in ["tercer_hombre", "llegada_coordinada", "cambio_frente", "corrida_preparada", "aceleracion_preparada"]:
		if bool(elegida.get("detalle", {}).get(marca, false)):
			_contar_jugada(estado, "accion_" + marca)
	if not elegida.get("enganche", {}).is_empty():
		_contar_jugada(estado, "accion_enganche")
	estado["ultima_decision"] = {
		"tipo": elegida["tipo"], "temperatura": temp, "presion": presion,
		"opciones": opciones, "jugador_rol": poseedor["rol"],
	}

	match elegida["tipo"]:
		"conducir":
			_conducir(estado, poseedor)
		"pase":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, elegida.get("punto", null))
			if bool(elegida.get("detalle", {}).get("llegada_coordinada", false)):
				estado["pelota"]["pase_atras_coordinado"] = true
		"pase_hueco":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, elegida["punto"])
		"pase_largo":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, elegida.get("punto", null), true)
			# El cambio de frente supera la primera linea por arriba. La
			# altura conserva sus controles e intercepciones reales al caer.
			estado["pelota"]["altura_max"] = float(f["z_inalcanzable"]) * 1.4
		"centro":
			_lanzar_pase(estado, poseedor, elegida["objetivo_id"], jugador, elegida.get("punto", null))
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
			estado["pelota"]["pared_a"] = elegida.get("tercero_id", poseedor["clave"])
			estado["pelota"]["pared_destino"] = elegida["punto"]
			estado["paredes"]["intentos"] = int(estado["paredes"].get("intentos", 0)) + 1
		"despeje":
			_despejar(estado, poseedor, jugador)
		"gambeta":
			_resolver_gambeta(estado, poseedor, jugador, elegida["objetivo_id"], elegida.get("enganche", {}))
			# La gambeta YA es el duelo por la pelota de este tick: si
			# además corriera el quite automático, la misma jugada se
			# resolvería dos veces.
			estado["gambeta_este_tick"] = estado["tick"]
		"tiro":
			_resolver_tiro(estado, poseedor, jugador)


## Una falta, una tirada, sobre EL QUE LA HIZO.
##
## Antes había un "presupuesto" de tiradas que se acumulaba por tiempo y
## se repartía entre todo el equipo. Tapaba que este motor cobra menos
## faltas que un partido real, pero el partido se dibuja y se veía el
## resultado: amarilla a un jugador parado a media cancha de la falta, y
## hasta al arquero. La tarjeta no tenía relación con lo que pasaba en
## pantalla.
##
## El hueco se cerró donde correspondía: prob_falta subió hasta las ~20
## faltas por partido del fútbol real (ver utility_pesos.json). Con eso
## la tarjeta puede colgar de la falta y sola, que es lo que se entiende
## mirando el partido.
##
## La chance por falta sale de `prob_amarilla_por_falta`. La roja directa
## conserva la razón del motor abstracto (CHANCE_ROJA_DIRECTA sobre
## CHANCE_AMARILLA) en vez de tener su propio peso: una sola fuente de
## verdad para "qué proporción de las tarjetas son roja directa".
static func _chequear_tarjeta_de_falta(estado: Dictionary, infractor: Dictionary,
		eq_d: Team, eq_a: Team, minuto: int) -> void:
	var f: Dictionary = pesos()["fisica"]
	var escala: float = float(f["prob_amarilla_por_falta"]) / MatchEngine.CHANCE_AMARILLA
	MatchEngine._chequear_tarjeta(infractor, eq_d, eq_a, estado["rng"], estado["eventos"],
			minuto, true, estado["log"], escala)
	# Si fue roja, se lo saca de la cancha AHORA. La limpieza periodica corre
	# cada 20 ticks (5 segundos de juego) y la roja puede caer en cualquiera
	# de ellos, asi que el expulsado seguia corriendo y disputando la pelota
	# hasta la limpieza siguiente: medido, 11 de 14 expulsados seguian
	# jugando 2,4 segundos de promedio y hasta 3,5. Se ve, porque el partido
	# se dibuja.
	if eq_d.expulsados_partido.has(int(infractor["id"])):
		_mandar_a_las_duchas(estado, int(infractor["id"]), eq_d == _equipo_de(estado, true))


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
	var victima := -1
	var distancia_victima := INF
	for clave in estado["jugadores"]:
		var candidato: Dictionary = estado["jugadores"][clave]
		if bool(candidato["equipo_local"]) == victima_local:
			var distancia: float = candidato["pos"].distance_squared_to(punto)
			if distancia < distancia_victima:
				distancia_victima = distancia
				victima = int(clave)
	# Nunca cobrar una falta si no hay una victima dentro del radio de
	# contacto. Esto protege tambien a futuros llamadores de esta funcion.
	if victima == -1 or distancia_victima > pow(float(pesos()["fisica"]["radio_tackle"]), 2):
		return
	_accion(estado, victima, "cae")
	estado["faltas"] = int(estado.get("faltas", 0)) + 1
	_chequear_tarjeta_de_falta(estado, infractor, eq_infractor, eq_victima, minuto)
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
	estado["penales"] = int(estado.get("penales", 0)) + 1

	# Lo patea el que eligio el club (Equipo > Roles). Si no eligio a
	# nadie, o si el elegido no esta en la cancha, lo patea el de mas
	# `tiro` DE CAMPO: antes el automatico recorria los once y el arquero
	# entraba en la comparacion, asi que si tenia el mejor `tiro` se iba
	# caminando hasta el punto del penal.
	_armar_penal(estado, ataca_local, minuto,
		_dict_jugador(estado, eq_a, Roles.ejecutor(eq_a, Roles.PENALES, eq_a.en_cancha)))


## Acomoda la cancha para un penal que ya patea `pateador`. Esta separado
## de _cobrar_penal porque la tanda usa la MISMA foto pero elige al
## pateador por otro lado: la lista de Penales.orden_de_pateo, no el rol
## del club.
##
## `gol_forzado` distinto de null salta el duelo y patea un resultado ya
## decidido. Lo usa la tanda: ahi el resultado lo decide Penales, que es el
## unico modelo de penal de todo el juego (ver _tanda_de_penales), y este
## motor solo lo pone en la cancha.
static func _armar_penal(estado: Dictionary, ataca_local: bool, minuto: int,
		pateador: Dictionary, gol_forzado = null) -> void:
	var eq_d := _equipo_de(estado, not ataca_local)
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
		# En la tanda los 18 que no patean miran desde el circulo central,
		# como en cualquier definicion por penales. En un penal DENTRO del
		# partido no: ahi cada uno espera el rebote donde estaba.
		if bool(estado.get("en_tanda", false)):
			var angulo: float = estado["rng"].randf_range(0.0, TAU)
			var radio: float = RADIO_CIRCULO * sqrt(estado["rng"].randf())
			e["pos"] = Vector2(cos(angulo), sin(angulo)) * radio
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
	pelota.erase("altura_salida")

	estado["balon_parado"] = {
		"tipo": "penal", "ataca_local": ataca_local, "minuto": minuto,
		"pateador_id": int(pateador["id"]), "pos": punto,
		"gol_forzado": gol_forzado,
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
	var gol: bool
	if bp.get("gol_forzado", null) != null:
		# Penal de la tanda: el resultado ya lo decidio Penales y aca solo
		# se patea. Ni se tira el duelo, para no gastar RNG en un numero
		# que no se usa.
		gol = bool(bp["gol_forzado"])
	else:
		var res := Duel.resolver(
			Duel.atributo_efectivo(float(pateador["atributos"]["tiro"]) + ventaja, "tecnico", eq_a.resistencia_pct(pateador["id"])),
			Duel.atributo_efectivo(valor_arq, "tecnico", eq_d.resistencia_pct(arquero["id"])),
			MatchEngine._bloques_equipo(eq_a, eq_d, pateador, "tiro", minuto, estado["rng"]),
			MatchEngine._bloques_equipo(eq_d, eq_a, arquero, "reflejos", minuto, estado["rng"]))
		gol = Duel.gana_atacante(res, estado["rng"])

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
	# Cuantas veces se corto el juego en la mitad. El descuento lo mira
	# para saber si el corte es NUEVO: pasado el tiempo, el primero que
	# aparece cierra la mitad.
	estado["cortes"] = int(estado.get("cortes", 0)) + 1
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

	# Saque de arco con rivales cerca: la revienta en vez de tocarla al
	# central (ver _arquero_encerrado).
	if poseedor["rol"] == "ARQ" and _arquero_encerrado(estado, saca_local):
		_despejar(estado, poseedor, jugador)
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
	# Con el juego detenido el tick no llega al paso 3, así que la línea de
	# offside es la del último tick jugado. Tras un gol era la del ataque
	# que lo convirtió: 37 de 40 saques del medio salían marcados offside.
	_calcular_linea_offside(estado)
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
			if bool(bp.get("con_manos", false)):
				_accion(estado, ejecutor, "lateral_manos")
				estado["pelota"]["altura_salida"] = 2.0
				estado["pelota"]["altura_max"] = 1.1
				estado["pelota"]["z"] = 2.0


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
	var accion_despeje := ACCION_SAQUE_ARCO if poseedor["rol"] == "ARQ" else ACCION_PATEA
	_accion(estado, int(poseedor["clave"]), accion_despeje)
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
	pelota.erase("altura_salida")
	estado["despejes"] = int(estado.get("despejes", 0)) + 1


## Avanzar con la pelota hacia el arco rival. Más lento que correr libre
## (avance_conducir < 1): si no, nadie alcanza nunca al que la lleva.
static func _conducir(estado: Dictionary, poseedor: Dictionary) -> void:
	var inicio: Vector2 = poseedor["pos"]
	var f: Dictionary = pesos()["fisica"]
	var destino := _corredor_elegido(estado, poseedor)
	var dir: Vector2 = (destino - poseedor["pos"]).normalized()
	# Un punto bien por delante para que nunca "llegue" y frene: conducir
	# es avanzar, no ir a un destino. Pasa por _mover_hacia para que el que
	# lleva la pelota también arranque con rampa y no salga disparado.
	var libre := 1.0 - riesgo_linea(estado, poseedor["pos"], destino, poseedor["equipo_local"])
	var plan := Estilos.plan(_equipo_de(estado, poseedor["equipo_local"]).estilo)
	var carrera: float = _transicion(estado, poseedor["equipo_local"]) * float(plan["transicion"])
	var factor := lerpf(float(f["avance_conducir"]), 0.88, libre * carrera)
	# El extremo da tiempo a que el lateral lo supere, sin congelarse.
	for corrida in estado.get("desmarques", {}).values():
		if bool(corrida.get("doblamiento", false)) and int(corrida["companero"]) == int(poseedor["clave"]) \
				and int(corrida["hasta"]) > int(estado["tick"]):
			factor *= 0.65
			break
	# Pausar es conducir DESPACIO protegiendo la pelota, no congelarse: el
	# poseedor sigue moviendose, y la presion y el robo del rival siguen
	# corriendo igual (pasos 3 y 4 del tick).
	if fase_de_ritmo(estado, bool(poseedor["equipo_local"])) == FASE_CIRCULACION:
		factor *= float(pesos_ritmo()["pausa_conduccion"])
	_mover_hacia(poseedor, poseedor["pos"] + dir * 20.0, factor)
	# Etapa 3: arrancando con la pelota va despacio y _mover_hacia no lo
	# gira; perfilarse hacia donde va es deliberado. Corriendo ya lo giro
	# _mover_hacia y girarlo de nuevo le daria el doble de giro.
	if float(poseedor.get("rapidez", 0.0)) < float(pesos_control()["rapidez_para_girar"]):
		girar_hacia(poseedor, dir)
	# El que lleva la pelota sí puede meterse en el área (a diferencia de
	# los que se posicionan sin ella, ver LIMITE_X), pero no atravesar la
	# línea de fondo.
	poseedor["pos"] = Vector2(
		clampf(poseedor["pos"].x, -MEDIO_LARGO + 1.0, MEDIO_LARGO - 1.0),
		clampf(poseedor["pos"].y, -MEDIO_ANCHO + 1.0, MEDIO_ANCHO - 1.0))
	if bool(estado.get("medir_opciones_colectivas", false)):
		estado["metros_conduccion"] = float(estado.get("metros_conduccion", 0.0)) + inicio.distance_to(poseedor["pos"])


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

	# ¿Fue falta? UNA tirada por duelo, gane o pierda el quite: el que
	# llega tarde puede bajarlo igual, y el que se la saca limpia puede
	# haberlo tocado antes. Las TARJETAS cuelgan de acá, no del quite en
	# sí — antes se amonestaba sin que hubiera ninguna infracción.
	#
	# Antes eran dos tiradas encadenadas y distintas según el resultado
	# (prob_falta sobre el quite fallado, prob_falta_en_quite_ganado sobre
	# el ganado). Calibradas para llegar a las 22 faltas reales cortaban
	# el partido todo el tiempo: 14,9 faltas por partido, cada una con
	# 3,5 s de juego parado, y jugando se siente insoportable.
	if estado["rng"].randf() < float(f["prob_falta_por_duelo"]):
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
		_entregar_rodando(estado, mejor_id)
		_penalizar(estado, poseedor["clave"], jug_a)
		estado["eventos"].append({
			"minuto": minuto, "tipo": "gambeta", "equipo": eq_a.nombre, "rival": eq_d.nombre,
			"jugador_posicion": poseedor["rol"], "resultado": "pierde",
		})
	else:
		_penalizar(estado, mejor_id, jug_d)


static func _serializar_trayectoria(trayectoria: Dictionary, giro: float, progreso: float) -> Dictionary:
	if trayectoria.is_empty():
		return {}
	var origen: Vector2 = trayectoria.get("origen", Vector2.ZERO)
	var control: Vector2 = trayectoria.get("control", Vector2.ZERO)
	var destino: Vector2 = trayectoria.get("destino", Vector2.ZERO)
	return {
		"origen": {"x": origen.x * giro, "y": origen.y * giro},
		"control": {"x": control.x * giro, "y": control.y * giro},
		"destino": {"x": destino.x * giro, "y": destino.y * giro},
		"progreso": progreso,
		"curva_m": float(trayectoria.get("curva_m", 0.0)),
		"calidad_tiro": float(trayectoria.get("calidad_tiro", 0.0)),
	}


static func _push_fotograma(estado: Dictionary, eventos_del_tick: Array = []) -> void:
	# En la tanda los dos equipos patean al MISMO arco. El motor sigue
	# pateando cada penal al arco que ataca ese equipo (ver
	# _tanda_de_penales), y el fotograma del penal visitante sale girado
	# 180 grados. Girar y no espejar conserva el costado: el penal cruzado
	# sigue cruzado y el arquero se tira al mismo lado.
	var giro: float = -1.0 if bool(estado.get("en_tanda", false)) and bool(estado.get("tanda_girada", false)) else 1.0
	var jugadores := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		jugadores.append({
			"id": id, "x": e["pos"].x * giro, "y": e["pos"].y * giro,
			"equipo_local": e["equipo_local"], "rol": e["rol"],
			# El peinado sale del jugador_id (ver SpritesPartido.pelo_de),
			# asi que el fotograma tiene que traerlo: la clave espacial
			# cambia de partido a partido y le daria otro pelo cada vez.
			"jugador_id": e["jugador_id"], "numero": int(e.get("numero", 0)),
			"recorrido": float(e.get("recorrido", 0.0)),
			# Etapa 3: hacia donde mira. Opcional: la vista lo usa con el
			# jugador quieto y los fotogramas viejos no lo traen.
			"ox": (float(e["orientacion"].x) if e.has("orientacion") else orientacion_inicial(bool(e["equipo_local"])).x) * giro,
			"oy": (float(e["orientacion"].y) if e.has("orientacion") else 0.0) * giro,
		})
	# Adonde tiene que mirar la camara. Normalmente null y la vista sigue
	# la pelota; con alguien saliendo o entrando la accion es el jugador y
	# no la pelota, que se quedo quieta a treinta metros de ahi.
	var foco = null
	if estado.has("foco_laboratorio"):
		var foco_laboratorio: Vector2 = estado["foco_laboratorio"]
		foco = {"x": foco_laboratorio.x * giro, "y": foco_laboratorio.y * giro}
	var en_transito: Array = estado.get("saliendo", []) + estado.get("entrando", [])
	if not en_transito.is_empty():
		var clave_f: int = int(en_transito[0]["clave"])
		if estado["jugadores"].has(clave_f):
			var e_f: Dictionary = estado["jugadores"][clave_f]
			foco = {"x": e_f["pos"].x * giro, "y": e_f["pos"].y * giro}
	estado["fotogramas"].append({
		"tick": estado["tick"],
		"minuto": estado["minuto"],
		# 1 y 2 = mitades, 3 y 4 = tiempos del alargue. El HUD rotula con
		# esto: el minuto solo no alcanza porque el descuento se pasa de 45
		# y de 90.
		"periodo": int(estado.get("periodo", 1)),
		# Ticks que le faltan a la pausa en curso, 0 si el juego corre. Es la
		# unica forma de separar juego abierto de pelota parada midiendo
		# sobre fotogramas; la vista lo ignora y los fotogramas viejos no lo
		# traen, asi que se lee con get().
		"detenido": int(estado.get("detenido", 0)),
		"foco": foco,
		"pelota": {
			"x": estado["pelota"]["pos"].x * giro, "y": estado["pelota"]["pos"].y * giro,
			# Altura en metros: hoy la animación la ignora (dibuja en 2D),
			# pero sale del motor para poder mostrar el centro por arriba
			# cuando la UI lo soporte.
			"z": float(estado["pelota"].get("z", 0.0)),
			"poseedor_id": estado["pelota"]["poseedor_id"],
			"es_pase": bool(estado["pelota"].get("es_pase", false)),
			"es_remate": bool(estado["pelota"].get("es_remate", false)),
			"saliendo": estado["pelota"].has("saliendo"),
			"trayectoria": _serializar_trayectoria(estado["pelota"].get("trayectoria_curva", {}), giro,
				float(estado["pelota"].get("progreso_trayectoria", 0.0))),
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
		"lateral_preparacion": {
			"clave": int(estado.get("balon_parado", {}).get("ejecutor", -1)),
			"restante": int(estado.get("detenido", 0)),
		} if bool(estado.get("balon_parado", {}).get("con_manos", false)) and int(estado.get("quietos", 0)) <= 0 else {},
		# El juego se cortó en seco en este tick (falta, saque del medio):
		# la vista lo usa para el parpadeo.
		"corte": bool(estado.get("corte_este_tick", false)),
		"goles": {"home": estado["home"].goles, "away": estado["away"].goles},
		# El marcador de la tanda, o null si no se esta pateando ninguna.
		# Va aparte de "goles" a proposito: los penales de la tanda no son
		# goles del partido y el HUD tiene que mostrar las dos cosas.
		"tanda": estado["tanda"].duplicate() if estado.has("tanda") else null,
	})


## Cierra de una las salidas y las entradas que quedaron a mitad de camino.
## Corre entre dos periodos: el que se estaba yendo ya salio y el que
## entraba ya esta adentro cuando los equipos vuelven a la cancha.
##
## Sin esto, una roja sobre el final de la mitad dejaba al expulsado
## caminando cuando el periodo cortaba, y el arranque del siguiente lo
## volvia a parar en su posicion base: medido en
## tests/_diag_expulsado_corta_mitad.gd, el equipo salia con ONCE al
## segundo tiempo y el expulsado jugaba 31 ticks mas. _sincronizar_cambios
## no lo tapaba porque saltea a todo el que esta en transito.
static func _cerrar_transitos(estado: Dictionary) -> void:
	for s in estado.get("saliendo", []):
		var clave: int = int(s["clave"])
		if not estado["jugadores"].has(clave):
			continue
		# El que se va con la pelota la suelta antes de desaparecer: el
		# saque del medio la reparte igual, pero un poseedor_id apuntando
		# a una clave borrada rompe el tick siguiente si algo la mira.
		if int(estado["pelota"]["poseedor_id"]) == clave:
			estado["pelota"]["poseedor_id"] = -1
		estado["jugadores"].erase(clave)
	estado["saliendo"] = []
	# El que entraba ya llego: se lo planta en el lugar que iba a ocupar.
	# La posicion real se la da igual _reiniciar_desde_medio, que acomoda
	# a los 22 para el saque.
	for en in estado.get("entrando", []):
		var clave_e: int = int(en["clave"])
		if not estado["jugadores"].has(clave_e):
			continue
		var e: Dictionary = estado["jugadores"][clave_e]
		e["pos"] = en["destino"]
		e["marca"] = en["destino"]
		e["vel"] = Vector2.ZERO
		e["rapidez"] = 0.0
	estado["entrando"] = []


## Juega UN periodo completo: los 45' de una mitad o los 15' de un tiempo
## del alargue. Estaba escrito adentro de `simular`, dentro del `for mitad`;
## se saco afuera para que el alargue juegue exactamente lo mismo que una
## mitad en vez de una copia con otros numeros.
##
## `ventanas` son los minutos en los que se procesan cambios y se consume
## in situ: el periodo saca de la lista los que ya paso.
static func _jugar_periodo(estado: Dictionary, home: Team, away: Team, saca_local: bool,
		numero: int, minuto_inicio: float, ticks_periodo: int, ventanas: Array,
		con_fotogramas: bool) -> void:
	# Un periodo arranca con los 22 que corresponden. Si quedo un cambio
	# sin aplicar —la ventana del entretiempo cae en el descuento y ahi
	# puede no haber ningun corte donde meterlo— se aplica ACA y sin
	# caminata: los equipos vuelven a la cancha ya cambiados. Sin esto el
	# suplente entraba trotando desde el lateral encima del saque del
	# medio, con el que salia llevandose la pelota del sacador.
	# Primero se cierran los transitos: el expulsado o el cambiado que
	# quedo caminando cuando corto la mitad TIENE que estar afuera antes
	# de que se acomoden los 22 (ver _cerrar_transitos).
	_cerrar_transitos(estado)
	_sincronizar_cambios(estado, true)
	# Etapa 5: todo periodo arranca con la reserva de sprint llena. Solo el
	# entretiempo devuelve ademas algo de resistencia; el corte antes del
	# alargue no es un descanso.
	if numero == 2:
		_recuperar_entretiempo(estado)
	_llenar_reservas(estado)
	_reiniciar_desde_medio(estado, saca_local, numero)
	estado["minuto"] = minuto_inicio
	estado["periodo"] = numero
	# `jugados` cuenta el tiempo DE JUEGO: los ticks que se van en una
	# entrada o una salida no cuentan, igual que el arbitro repone lo
	# que se pierde en un cambio. Sin esto, animar los cambios le
	# comia el 10% del partido y los goles bajaban de 2,36 a 1,84.
	var jugados := 0
	var reloj := 0
	# Cuantos cortes de juego habia cuando se acabo el tiempo. Pasado
	# ese punto no se cobra nada nuevo: el primer corte que aparezca
	# cierra el periodo.
	var cortes_al_expirar := -1
	# La mitad cerro sola, con la jugada terminada. Si queda en false
	# es que se agoto el tope de descuento, y eso se anota y se mide.
	var limpio := false
	while jugados < ticks_periodo + TICKS_DE_DESCUENTO 				and reloj < ticks_periodo + TICKS_DE_DESCUENTO + TICKS_REPUESTOS_TOPE:
		# DESCUENTO. El tiempo no se termina con una pelota parada sin
		# ejecutar: si se cobro un corner o un penal sobre la hora, se
		# patea. Pasados los 45 se juega SOLO lo que quedo pendiente.
		if jugados >= ticks_periodo:
			if cortes_al_expirar < 0:
				cortes_al_expirar = int(estado["cortes"])
			# El penal es la excepcion: si se cobra en el descuento
			# igual se patea, porque es la unica jugada que se define
			# sola. Se le perdona el corte y despues la mitad cierra
			# donde termine — gol, atajada o pelota afuera.
			if str(estado.get("balon_parado", {}).get("tipo", "")) == "penal":
				cortes_al_expirar = int(estado["cortes"])
			# Un corte NUEVO cierra el periodo: la pelota salio, hubo
			# gol, la ataja el arquero o se cobro una falta. Eso que
			# se cobro ya no se ejecuta.
			if int(estado["cortes"]) > cortes_al_expirar:
				limpio = true
				break
			if not _hay_algo_sin_terminar(estado):
				limpio = true
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
			limpio = true
			break
		if not ventanas.is_empty() and estado["minuto"] >= ventanas[0]:
			var minuto_ventana: int = ventanas.pop_front()
			MatchEngine._procesar_cambios(home, away, minuto_ventana, true, estado["log"], estado["eventos"])
			_sincronizar_cambios(estado)
	if not limpio:
		_anotar_corte_sucio(estado)


## LA TANDA DE PENALES, pateada en la cancha y con fotogramas (§8.7).
##
## La tanda entera la resuelve Penales.definir —cinco por lado, despues
## muerte subita, cortando en cuanto el resultado ya no puede cambiar, y
## cada remate con su duelo— y este motor la PATEA en la cancha. El motor
## no decide nada: si resolviera el remate con su propio duelo, el jugador
## definiria sus tandas al 96,8% de conversion contra el 84,2% de la IA
## (medido en tests/_diag_conversion_penales.gd). Lo unico distinto entre
## los dos motores es que aca la tanda se ve.
##
## En la pantalla los dos equipos patean al mismo arco, como en una tanda
## real. Adentro del motor cada uno sigue pateando al arco que atacaba: el
## lado sale de `es_local` en todo el motor (arco_rival, _lanzar_remate,
## _aplicar_remate) y cambiarlo solo para la tanda tocaria media docena de
## funciones. _push_fotograma gira 180 grados el fotograma del penal
## visitante (`tanda_girada`), y eso los junta a todos en el arco derecho.
static func _tanda_de_penales(estado: Dictionary, con_fotogramas: bool) -> Dictionary:
	var home: Team = estado["home"]
	var away: Team = estado["away"]
	estado["en_tanda"] = true
	estado["tanda"] = {"home": 0, "away": 0}
	# El reloj se planta en el final del alargue y no se mueve mas. El
	# descuento del segundo tiempo extra lo habia dejado en 122', y una
	# tanda no es tiempo de juego: el partido termino a los 120.
	estado["minuto"] = 90.0 + MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE * 2.0
	estado["log"].append("Termina el alargue %d-%d: se define por penales." % [home.goles, away.goles])
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "tanda_arranca",
		"equipo": home.nombre, "rival": away.nombre,
		"jugador_posicion": "", "resultado": "arranca",
	})
	var resultado := Penales.definir(home, away, estado["rng"],
		func(pateador: Dictionary, _arquero: Dictionary, es_local: bool, gol: bool) -> void:
			_patear_de_la_tanda(estado, pateador, es_local, gol, con_fotogramas))
	estado["en_tanda"] = false
	estado.erase("tanda_girada")
	estado["log"].append("PENALES: %s %d-%d %s. Pasa %s." % [
		home.nombre, int(resultado["goles_local"]), int(resultado["goles_visitante"]),
		away.nombre, resultado["ganador"].nombre])
	return resultado


## Patea en la cancha un penal de la tanda YA resuelto: se acomoda todo el
## mundo, el pateador toma carrera, la pelota viaja y el arquero se tira,
## y termina como dice `gol`. Lo llama Penales.definir despues de decidir
## cada remate.
static func _patear_de_la_tanda(estado: Dictionary, pateador: Dictionary, es_local: bool,
		gol: bool, con_fotogramas: bool) -> void:
	estado.erase("tanda_resultado")
	estado["tanda_girada"] = not es_local
	_armar_penal(estado, es_local, _minuto_int(estado), pateador, gol)
	# No se pudo armar (equipo sin arquero, o el pateador no esta en la
	# cancha): _armar_penal se va por la salida de emergencia y no deja
	# penal. El resultado ya esta decidido igual, asi que la tanda sigue:
	# ese penal no se ve y listo.
	if str(estado.get("balon_parado", {}).get("tipo", "")) != "penal":
		_anotar_penal_de_tanda(estado, es_local, gol, {"rol": str(pateador["posicion"]),
			"clave": clave_de(int(pateador["id"]), es_local), "jugador": pateador})
		return

	var ticks := 0
	while not estado.has("tanda_resultado") and ticks < TICKS_MAX_PENAL_DE_TANDA:
		_tick(estado, con_fotogramas)
		ticks += 1
	# La pausa de despues: la pelota se queda en la red o en las manos del
	# arquero unos ticks antes de que se arme el penal siguiente.
	for _i in range(TICKS_ENTRE_PENALES):
		_tick(estado, con_fotogramas)


## Anota un penal de la tanda. Lo llama _aplicar_remate cuando la pelota
## llega, en vez del camino normal del gol: no suma al marcador del
## partido, no hay festejo ni saque del medio, y la jugada termina ahi.
static func _anotar_penal_de_tanda(estado: Dictionary, es_local: bool, gol: bool,
		datos: Dictionary) -> void:
	var eq_a := _equipo_de(estado, es_local)
	var eq_d := _equipo_de(estado, not es_local)
	var tanda: Dictionary = estado["tanda"]
	var lado: String = "home" if es_local else "away"
	if gol:
		tanda[lado] = int(tanda[lado]) + 1
	estado["tanda_resultado"] = gol

	var jugador: Dictionary = datos.get("jugador", {})
	estado["eventos"].append({
		"minuto": _minuto_int(estado), "tipo": "penal_tanda",
		"remate_id": datos.get("remate_id", -1),
		"equipo": eq_a.nombre, "rival": eq_d.nombre,
		"jugador_posicion": datos["rol"], "clave": datos["clave"],
		"resultado": "gol" if gol else "atajado",
		"tanda_local": int(tanda["home"]), "tanda_visitante": int(tanda["away"]),
	})
	estado["log"].append("PENALES: %s %s (%s) %s — %d-%d" % [
		jugador.get("nombre", ""), jugador.get("apellido", ""), eq_a.nombre,
		"convierte" if gol else "la falla", int(tanda["home"]), int(tanda["away"])])

	var pelota: Dictionary = estado["pelota"]
	pelota["en_vuelo"] = false
	pelota["es_remate"] = false
	pelota["vel"] = Vector2.ZERO
	pelota["altura_max"] = 0.0
	pelota["z"] = 0.0
	if gol:
		# Se queda en la red, que es lo que hace que el gol se lea.
		pelota["poseedor_id"] = -1
	else:
		_dar_pelota_al_arquero(estado, not es_local)
	estado["detenido"] = TICKS_ENTRE_PENALES
	estado["quietos"] = TICKS_ENTRE_PENALES


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
static func simular(home: Team, away: Team, rng: RandomNumberGenerator,
		con_fotogramas: bool = false, definicion_directa: bool = false,
		con_diagnostico: bool = false) -> Dictionary:
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
	if con_diagnostico:
		estado["registro_remates"] = []
		estado["medir_opciones_colectivas"] = true

	# Mismas ventanas de cambio que MatchEngine (§8.7): entretiempo, 60' y
	# 75'. Se reusa _procesar_cambios sin tocarlo.
	var ventanas := [45, 60, 75]
	for mitad in range(2):
		if bool(estado.get("cancelado", false)):
			break
		_jugar_periodo(estado, home, away, mitad == 0, mitad + 1,
			MINUTOS_MOSTRADOS_POR_MITAD * mitad, TICKS_POR_MITAD, ventanas, con_fotogramas)

	# §8.7: en eliminacion directa el empate no vale. Se juega el alargue
	# (2x15') y si sigue igualado se patea la tanda, TODO adentro de este
	# motor y con fotogramas. Antes esos 30' y los penales los resolvia
	# MatchEngine/Penales por atras: el jugador miraba 90 minutos y se
	# enteraba del resto por el resumen.
	var definicion := "90 minutos"
	var tanda := {}
	if definicion_directa and not bool(estado.get("cancelado", false)) and home.goles == away.goles:
		definicion = "alargue"
		# Ultima ventana de cambio, antes de que empiece el alargue: es la
		# misma que usa MatchEngine.simular_alargue.
		MatchEngine._procesar_cambios(home, away, 90, true, estado["log"], estado["eventos"])
		_sincronizar_cambios(estado)
		for tiempo in range(2):
			if bool(estado.get("cancelado", false)):
				break
			_jugar_periodo(estado, home, away, tiempo == 0, 3 + tiempo,
				90.0 + MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE * tiempo,
				TICKS_POR_TIEMPO_ALARGUE, [], con_fotogramas)
		if not bool(estado.get("cancelado", false)) and home.goles == away.goles:
			definicion = "penales"
			tanda = _tanda_de_penales(estado, con_fotogramas)

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
		# Como se cerro el cruce: "90 minutos", "alargue" o "penales". En
		# un partido de liga (definicion_directa = false) es siempre
		# "90 minutos", empate incluido.
		"definicion": definicion,
		# La tanda, con el shape de Penales.definir (ganador, goles_local,
		# goles_visitante, tandas). Vacio si no se llego a patear.
		"penales": tanda,
		"eventos": estado["eventos"],
		"fotogramas": estado["fotogramas"],
		# §7.3: cuánto entrenó cada jugador cada atributo, normalizado.
		"xp": xp_normalizada(estado),
		"stats": {
			"ticks": estado["tick"],
			"posesion": estado["posesion_ticks"],
			"tiros": estado["tiros"],
			"dist_tiros": estado["dist_tiros"],
			"registro_remates": estado.get("registro_remates", []),
			"robos": estado["robos"],
			"gambetas": estado["gambetas"],
			"paredes": estado["paredes"],
			"jugadas_colectivas": estado.get("jugadas_colectivas", {}),
			"metros_conduccion": float(estado.get("metros_conduccion", 0.0)),
			"muestra_pase_atras": estado.get("muestra_pase_atras", {}),
			"centros": estado["centros"],
			"despejes": estado.get("despejes", 0),
			"faltas": estado.get("faltas", 0),
			"penales": estado.get("penales", 0),
			"libres_directos": estado.get("libres_directos", 0),
			"offsides": estado.get("offsides", 0),
			"dist_pases": estado["dist_pases"],
			"dist_pelotazos": estado["dist_pelotazos"],
			"reinicios": estado["reinicios"],
			"cortadas": estado["cortadas"],
			"cooldown_activos": estado["cooldown"].size(),
			"pase_detalle": estado["pase_detalle"],
			"pases": estado["pases"],
			"decisiones": estado["decisiones"],
			# Etapa 4: ticks por fase de ritmo y pases atras separados por
			# tipo. Solo mide; ningun consumidor lo necesita.
			"ritmo": estado.get("ritmo_stats", {}),
			# Etapa 6: salidas, achiques, rechazos y cobertura en el duelo.
			# Solo mide.
			"arqueros": estado.get("arqueros_stats", {}),
			# Etapa 5: carga de esfuerzo y reserva baja. Solo mide.
			"esfuerzo": estado.get("esfuerzo_stats", {}),
			# Etapa 3: recepciones, dificultad, toques largos y demora. Solo
			# mide.
			"control": estado.get("control_stats", {}),
		},
	}
