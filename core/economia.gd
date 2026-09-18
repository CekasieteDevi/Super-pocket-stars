class_name Economia
extends RefCounted

## Economía del club — Fase 6 (GDD §9.1). Procesamiento a nivel temporada
## (todavía no hay calendario semanal para ingresos partido a partido):
## entradas + sponsor + premio por posición como ingreso, sueldos +
## mantenimiento como egreso, repartido en los 4 presupuestos fijos.

## §15 decisión 2 / §9.1: Fichajes 60% / Contratos 20% / Mejoras 10% del
## NETO LIBRE (ingresos - sueldos - mantenimiento), reescalado a que sumen
## 100% entre estos tres. El mantenimiento no se reparte porque no se
## gasta: es un costo administrativo del club (cancha, luz) que ya se
## restó de los ingresos antes de llegar acá.
const PRESUPUESTO_PORCENTAJES := {
	"fichajes": 60.0 / 90.0, "contratos": 20.0 / 90.0, "mejoras": 10.0 / 90.0,
}
## Las categorías de la caja del club, y las mismas tres que se reparten.
##
## Antes había una cuarta, Mantenimiento, que se reponía con una reserva
## fija de $12.500 por temporada y solo servía para pagar multas. Las
## multas se eliminaron (ver Liga), así que la categoría quedó sin nada
## que pagar: era un presupuesto que el jugador no podía gastar en nada.
const CATEGORIAS_CAJA := ["fichajes", "contratos", "mejoras"]

## PRECIO_ENTRADA calibrado (feedback de playtesting: "gané $797,000 en
## división 10 cuando un jugador de media 75 cuesta $170,000") — con
## $80 la entrada, un club de división baja con reputación ~45 sacaba
## ~$800,000 de ingresos por temporada contra un jugador MEDIANO del
## propio plantel valuado en ~$17,500: una desproporción de ~45x que
## dejaba a cualquier club de división baja nadando en plata en vez de
## sentirse pobre. Bajado a $12 (de $80): el mismo club ahora saca
## ~$140,000-195,000 por temporada, con el neto rondando cero para los
## clubes de asistencia floja y positivo pero ajustado para el resto —
## una temporada entera de ahorro no te compra la división entera, pero
## sí un par de refuerzos reales si administrás bien.
const PARTIDOS_DE_LOCAL := 19
const AFORO_BASE := 800
const PRECIO_ENTRADA := 12.0
const SPONSOR_BASE := 15000.0
## Mantenimiento a factor 1.0. El costo real de cada club es este número
## por su factor_division, igual que los ingresos.
##
## Antes eran $25.000 planos para todos, fuera del multiplicador. Eso
## castigaba solo a las divisiones bajas: en décima, con ingresos de
## $54.771, se comía el 46% de la temporada, mientras que en primera
## ($16M de ingresos) era ruido. Un club de décima cerraba con $12.463 de
## neto y $1.385 de presupuesto de Mejoras — con eso no llegaba nunca a
## la primera mejora de instalaciones, que costaba $40.000.
##
## Escalado, décima paga $10.750 (20% de sus ingresos) y cierra con
## $26.713 de neto: el doble que antes.
const MANTENIMIENTO_BASE := 25000.0
const PREMIO_POR_POSICION := {1: 50000.0, 2: 30000.0, 3: 15000.0}

## Premios de copa. 1 = campeon, 2 = finalista.
##
## La copa de DIVISION escala con la division, igual que el premio de
## liga: es una competencia de esa division y su plata tiene que valer lo
## que vale ahi. Con esta base paga el 40% de lo que paga salir campeon
## —cinco partidos contra treinta y ocho— en las diez divisiones.
const PREMIO_COPA_DIVISION := {1: 20000.0, 2: 8000.0}

## La Copa del Rey NO escala: la juegan los 128 clubes clasificados de las
## diez divisiones, es la MISMA competencia para todos. Si escalara,
## ganarla desde decima —la hazaña mas grande que se puede hacer en el
## juego, ganarle a los otros 127— pagaria $8.600 y ganarla desde primera pagaria
## $1,76M, o sea al reves. Fijo, son casi cinco temporadas de ingresos
## para un club de decima y un extra lindo para uno de primera.
const PREMIO_COPA_REY := {1: 250000.0, 2: 100000.0}

## Las internacionales tampoco escalan, por lo mismo, y pagan mas porque
## se juegan contra los mejores del continente. Solo llegan clubes de
## primera, donde el titulo de liga paga $4,4M: esto es un cuarto de eso.
const PREMIO_COPA_INTERNACIONAL := {1: 1000000.0, 2: 400000.0}

## Cuanto multiplica los ingresos la CATEGORIA del club (indice 0 =
## primera). Aforo, sponsors y derechos de TV no son iguales en primera
## que en decima, pero AFORO_BASE, SPONSOR_BASE y PRECIO_ENTRADA son
## constantes fijas: sin esto, los ingresos iban de 127k en decima a 182k
## en primera (+43%) mientras los sueldos —que siguen al valor del
## jugador— iban de 43k a 535k (x12,5). Resultado: con el gradiente de
## NivelDivision, las divisiones 1 a 4 nacian en rojo profundo (-353k en
## primera) y quebraban de entrada, mientras decima nadaba en plata.
##
## La curva es geometrica, ~1,27 por escalon, y decima queda en 1.0 a
## proposito: ahi es donde arranca el jugador y donde esta calibrado el
## balance (ver PRECIO_ENTRADA), asi que ese escalon no se toca.
## Las tres de arriba estan MUY por encima de la curva geometrica del
## resto. No es arbitrario: es el escalon de elite de ValorJugador
## (MEDIA_ELITE). Arriba de media 70 los jugadores valen —y por lo tanto
## cobran, el sueldo es el 10% del valor— ordenes de magnitud mas, asi que
## los ingresos tienen que acompañar o primera nace quebrada. De division
## 4 para abajo no cambia nada, igual que los precios.
##
## RECALIBRADO midiendo las diez ligas ENTERAS (tests/
## _diag_economia_divisiones.gd), no un club por division como la vez
## anterior. Lo que se encontro con esa medicion:
##
##  - El 228 de primera era deuda de antes de que `base_salarial` sacara
##    el escalon de elite de los SUELDOS. Existia porque los sueldos de
##    primera llegaban a $535k; hoy los egresos promedio de primera son
##    $492k, pero el multiplicador producia $41,6M de ingresos.
##  - El poder de compra relativo no era monotono: bajaba parejo de
##    decima (41% del valor del plantel) hasta tercera (11%) y ahi
##    rebotaba a 16% y 28%. Un club de tercera no podia fichar a NADIE de
##    su propia division: el mejor jugador costaba 2,8 temporadas de
##    presupuesto mientras en decima costaba media.
##
## El objetivo elegido: el mejor jugador de tu division cuesta entre 2 y 3
## temporadas de presupuesto de fichajes —o sea, para traerlo hay que
## vender— y la plata crece fuerte con la categoria. El "mejor jugador"
## se mide como el promedio del mejor de CADA club de la division: el
## mejor de la division a secas es una sola tirada y salta como loco entre
## divisiones vecinas.
##
## Decima deja de ser 1.0. Ese escalon estaba calibrado junto con
## PRECIO_ENTRADA para que "una temporada de ahorro te compre un par de
## refuerzos reales", y eso es justamente lo contrario del objetivo
## nuevo: ahora el refuerzo tope hay que ganarselo vendiendo.
##
## Cuarta subio de 3.31 a 4.5 el 2026-09-18. Medido con
## tests/test_economia_divisiones.gd sobre las semillas 1 a 8 y 777: con
## 3.31 el mejor jugador costaba 3.8 temporadas de media (de 2.8 a 4.8),
## fuera de la banda en 8 de 9 semillas. El test pasaba solo con la 777.
## Con 4.5 cuesta 2.4 de media (de 2.1 a 3.0), entre tercera y quinta.
const MULTIPLICADOR_DIVISION := [88.2, 32.3, 9.67, 4.5, 2.00, 1.18, 0.89, 0.69, 0.543, 0.43]


## -1 (liga suelta, sin escalon en la piramide) = sin multiplicador.
static func factor_division(division: int) -> float:
	if division < 0:
		return 1.0
	return MULTIPLICADOR_DIVISION[clamp(division, 0, MULTIPLICADOR_DIVISION.size() - 1)]

## Si la caja total queda por debajo de -20% del valor del plantel, quiebra.
const UMBRAL_QUIEBRA := -0.2


static func _fila_vacia_caja() -> Dictionary:
	var c := {}
	for categoria in CATEGORIAS_CAJA:
		c[categoria] = 0.0
	return c


## §8.4 #22 extendido a la economía: el APOYO de la hinchada (0..1, ver
## Fans.apoyo — qué tan grande es para su categoría, no cuántos son) suma
## hasta +30% de ocupación encima de la base de reputación, nunca la
## reduce. Un club que se gana una hinchada de verdad llena más la cancha
## que uno con la misma reputación y sin bancada; la recompensa es real
## pero acotada (clamp a 100% de aforo).
##
## El párrafo que estaba acá decía que en temporada 1 esto daba
## exactamente la ocupación de antes "con fans=0 en absolutamente todos
## los clubes". Era cierto y era el bug: `fans` no se inicializaba nunca,
## así que este bonus valía 0 para todo el mundo durante toda la partida
## y la economía se calibró sin él. Ver OCUPACION_BASE, que es lo que
## compensa haberlo arreglado.
const BONUS_OCUPACION_FANS := 0.3

## El piso de ocupación, antes de la reputación y de la hinchada.
##
## Era 0.30. Bajó a 0.20 cuando la hinchada empezó a valer de verdad: con
## el bug viejo `fans` valía 0 para TODOS los clubes de la partida —nunca
## se inicializaba— así que BONUS_OCUPACION_FANS no aportaba nada y toda
## la economía quedó calibrada con la cancha llenándose solo por
## reputación. Al arreglarlo, un club normal (apoyo ~0.32) pasaba a
## recaudar 11% más en primera y 18% más en décima sin haber hecho nada.
##
## Con 0.20 el club promedio queda donde estaba y el que se gana una
## hinchada grande gana hasta +0.20 de ocupación sobre eso: la hinchada
## mueve la aguja en vez de regalar plata.
const OCUPACION_BASE := 0.2


## Cierra una temporada terminada para un club. posicion_tabla es 1-indexado.
##
## NO es una consulta: ademas de devolver el informe le mueve al club la
## caja, el presupuesto, la reputacion, la hinchada y el estado de
## quiebra, y le vacia los acumuladores de premios de copa y sponsors.
## Llamala una sola vez por temporada y por club. Para preguntar "cuanto
## cerraria" sin mover nada, usa calcular_temporada().
static func procesar_temporada(equipo: Team, posicion_tabla: int, total_equipos: int, division: int = -1) -> Dictionary:
	var ocupacion_base: float = OCUPACION_BASE + clamp(equipo.reputacion, 0.0, 100.0) / 100.0 * 0.7
	# El APOYO y no la cantidad cruda: la hinchada es exponencial y lo que
	# llena el estadio es ser grande para tu categoria, no el numero.
	var ocupacion: float = clamp(
		ocupacion_base + Fans.apoyo(equipo, division) * BONUS_OCUPACION_FANS, 0.0, 1.0)
	var asistencia: float = AFORO_BASE * Instalaciones.factor_aforo(equipo) * ocupacion
	var ingreso_entradas: float = PARTIDOS_DE_LOCAL * asistencia * PRECIO_ENTRADA
	var ingreso_sponsor: float = SPONSOR_BASE + (total_equipos - posicion_tabla) * 1000.0
	var premio: float = PREMIO_POR_POSICION.get(posicion_tabla, 0.0)
	# Los de copa entran YA calculados (ver GameState._pagar_premio_de_copa):
	# el de division ya trae aplicado el factor y los de Rey/internacional
	# no lo llevan a proposito, asi que van afuera del multiplicador.
	var premios_copa: float = equipo.premios_copa
	# Los sponsors ya cobraron partido a partido con el pago de SU
	# division (ver Sponsors.pago_de), asi que tampoco pasan por el
	# multiplicador: se lo aplicaron ellos cuando firmaron.
	var por_sponsors: float = equipo.ingresos_sponsors
	var ingresos: float = (ingreso_entradas + ingreso_sponsor + premio) 		* factor_division(division) + premios_copa + por_sponsors
	equipo.premios_copa = 0.0
	equipo.ingresos_sponsors = 0.0

	var total_sueldos := 0.0
	for id in equipo.sueldos:
		total_sueldos += equipo.sueldos[id]
	var mantenimiento: float = MANTENIMIENTO_BASE * factor_division(division)
	var egresos: float = total_sueldos + mantenimiento

	var neto: float = ingresos - egresos
	# El presupuesto se REINICIA cada temporada, como en un modo carrera:
	# lo que no gastaste se pierde. Antes se acumulaba (+=) y despues de
	# ocho temporadas un club de primera tenia $157M dormidos en la caja y
	# uno de decima mas de ocho temporadas de ingresos sin gastar — con
	# suficientes años, cualquier club terminaba pudiendo comprar
	# cualquier cosa, que es justo lo que el escalon de elite de
	# ValorJugador esta para evitar.
	#
	# La DEUDA si se arrastra: si cerraste en rojo, arrancas el año
	# debiendo. Si no, la quiebra desapareceria sola cada temporada y
	# _recalcular_quiebra no volveria a dispararse nunca.
	for categoria in PRESUPUESTO_PORCENTAJES:
		var asignado: float = neto * PRESUPUESTO_PORCENTAJES[categoria]
		equipo.caja[categoria] = asignado + minf(0.0, equipo.caja[categoria])
		equipo.presupuesto_temporada[categoria] = asignado
	# Foto provisoria. La definitiva la saca fotografiar_caja() cuando
	# termina toda la intertemporada — ver ahi por que.
	fotografiar_caja(equipo)

	# Reputacion y hinchada: la posicion final mueve las dos. Los TITULOS y
	# los ascensos tambien mueven la reputacion, pero eso lo aplica
	# GameState, que es el unico que sabe quien gano que (ver
	# Reputacion.por_titulo).
	Reputacion.sumar(equipo, Reputacion.por_posicion(posicion_tabla, total_equipos))
	Reputacion.tirar_a_la_referencia(equipo, division)
	Fans.actualizar_por_temporada(equipo, posicion_tabla, total_equipos, division)

	var estado := _recalcular_quiebra(equipo)

	return {
		"ingresos": ingresos, "egresos": egresos, "neto": neto,
		"premios_copa": premios_copa, "sponsors": por_sponsors,
		"sueldos": total_sueldos, "mantenimiento": mantenimiento,
		"caja_total": estado["caja_total"], "valor_plantel": estado["valor_plantel"], "quebrado": estado["quebrado"],
	}


## Con que caja arranca la temporada el club. La UI muestra "gastaste X de
## Y" como caja_al_cierre - caja, asi que esta foto es el cero contra el
## que se mide todo lo que el jugador decide gastar.
##
## Tiene que sacarse cuando NO queda movimiento automatico pendiente.
## Antes se sacaba dentro de procesar_temporada, apenas repartido el neto,
## y despues el cierre seguia: vencian contratos, entraban reemplazos de
## agentes libres y subian canteranos, y cada uno de esos movimientos toca
## el presupuesto de Contratos. Resultado: el jugador abria Economia el
## primer dia de la temporada, sin haber hecho nada, y le decia que ya
## habia gastado $2.241 de Contratos.
##
## La plata estaba bien; lo que estaba mal era contra que se comparaba.
static func fotografiar_caja(equipo: Team) -> void:
	equipo.caja_al_cierre = equipo.caja.duplicate()


## La misma cuenta que procesar_temporada, pero sin tocar al club.
##
## Corre el cierre sobre una COPIA y devuelve solo el informe. El equipo
## que se le pasa queda exactamente como estaba: misma caja, misma
## reputacion, misma hinchada, mismos acumuladores.
##
## Comparar dos cierres del mismo club con procesar_temporada medía dos
## clubes distintos, porque la primera llamada ya le habia movido la
## reputacion y la hinchada a la segunda. Eso rompio dos tests el
## 2026-09-03: el premio de copa daba $50.892 en vez de $50.000 en decima
## y -$439.671 en primera. Usa esta funcion para cualquier comparacion,
## previsualizacion o medicion.
static func calcular_temporada(equipo: Team, posicion_tabla: int, total_equipos: int, division: int = -1) -> Dictionary:
	return procesar_temporada(Team.cargar(equipo.guardar()), posicion_tabla, total_equipos, division)


## Todo el plantel activo (titulares+banco, §14), no solo los 11 titulares
## -- el banco es un activo real del club (podría venderse), y contarlo de
## menos hacía que el umbral de quiebra fuera mucho más fácil de cruzar de
## lo que debería para cualquier club con un banco de valor. Actualiza
## equipo.quebrado in-place y devuelve los tres valores, para que
## procesar_quiebra() pueda reevaluar después de cada venta forzada sin
## repetir la fórmula.
static func _recalcular_quiebra(equipo: Team) -> Dictionary:
	var valor_plantel := 0.0
	for j in equipo.todos_los_jugadores():
		valor_plantel += ValorJugador.calcular(j, equipo.animo.get(j["id"], 50.0), equipo.contratos.get(j["id"], 1))

	var caja_total := 0.0
	for categoria in equipo.caja:
		caja_total += equipo.caja[categoria]

	equipo.quebrado = valor_plantel > 0.0 and caja_total < UMBRAL_QUIEBRA * valor_plantel
	return {"caja_total": caja_total, "valor_plantel": valor_plantel, "quebrado": equipo.quebrado}


## §9.1 extendido: un club en quiebra no se queda ahí para siempre —
## liquida a sus jugadores más valiosos (el mejor primero) por una
## fracción de su valor a un comprador externo genérico, y rellena el
## puesto con un reemplazo barato (misma lógica que AgentesLibres.liberar:
## nunca se queda con un agujero en la formación). Sigue vendiendo hasta
## salir de la quiebra o quedarse sin nadie más para vender — exactamente
## lo que haría un club real sin plata: se debilita para sobrevivir, y esa
## debilidad se paga en la cancha (peor plantel → más fácil que descienda).
## No se llama para el equipo del jugador humano (ver Liga) — esa decisión
## de a quién vender es suya, no automática.
const FRACCION_VENTA_DE_URGENCIA := 0.7


static func procesar_quiebra(equipo: Team, rng: RandomNumberGenerator) -> Array:
	var ventas := []
	if not equipo.quebrado:
		return ventas

	var maximo_intentos: int = Team.FORMACION.size() + Team.BANCO_FORMACION.size()
	var intentos := 0
	while equipo.quebrado and intentos < maximo_intentos:
		intentos += 1

		# Las tres listas del plantel: una reserva cara se vende igual que
		# un titular, y encima antes (vale mas de lo que aporta).
		var mejor_idx := -1
		var mejor_media := -1.0
		var lista: Array = equipo.jugadores
		for candidata in [equipo.jugadores, equipo.banco, equipo.reservas]:
			for i in range(candidata.size()):
				if candidata[i]["media"] > mejor_media:
					mejor_media = candidata[i]["media"]
					mejor_idx = i
					lista = candidata
		if mejor_idx < 0:
			break

		var saliente: Dictionary = lista[mejor_idx]
		var valor := ValorJugador.calcular(saliente, equipo.animo.get(saliente["id"], 50.0), equipo.contratos.get(saliente["id"], 1))
		var ingreso: float = valor * FRACCION_VENTA_DE_URGENCIA

		# Del nivel del club, no de la tabla global (ver Team.nivel_potencial).
		var reemplazo := PlayerGenerator.generate(
			equipo.siguiente_id_cantera, rng, saliente["posicion"], equipo.nivel_potencial())
		equipo.siguiente_id_cantera += 1
		# Al que sale del once o del banco hay que reponerlo (el club no
		# puede quedar con un agujero en la formacion). A una RESERVA no:
		# nadie la extraña, se vende y listo.
		if lista == equipo.reservas:
			lista.remove_at(mejor_idx)
		else:
			lista[mejor_idx] = reemplazo
			equipo._registrar_fichaje(reemplazo, ValorJugador.calcular(reemplazo, 50.0, 2), 2)
		equipo.recalcular_capitan()

		equipo.caja["fichajes"] += ingreso
		equipo._limpiar_registro(saliente["id"])

		ventas.append({"saliente": saliente, "posicion": saliente["posicion"], "ingreso": ingreso})
		_recalcular_quiebra(equipo)

	return ventas


## Sueldo anual sugerido para un jugador recién fichado o generado: una
## fracción de su valor de mercado, como es habitual en fútbol. Bajado de
## 0.15 a 0.10 junto con el ajuste de PRECIO_ENTRADA (feedback de
## playtesting, ver más arriba): con 0.15, la masa salarial crecía más
## rápido que el ingreso (que tiene techo — reputación tarda en subir y
## la asistencia nunca pasa de 1.0x) a medida que los jugadores mejoraban
## con la progresión, empujando a cada vez más clubes a números rojos
## temporada tras temporada. Con 0.10 el neto promedio de la pirámide se
## mantiene sano varias temporadas seguidas en vez de derrumbarse.
static func sueldo_sugerido(valor: float) -> float:
	return valor * 0.10


## Lo que va a cobrar un jugador si lo fichás hoy por esos años. Es la
## misma cuenta que hace Team._registrar_fichaje: vive acá para que la UI
## y los chequeos de presupuesto puedan preguntarla ANTES de fichar, sin
## repetir la fórmula.
## division es la del club que PAGA el sueldo, no la del que vende: lo que
## se paga es destacar sobre la categoria donde vas a jugar (ver
## ValorJugador.media_salarial).
static func sueldo_de_ficha(jugador: Dictionary, contrato_anios: int,
		division: int = -1) -> float:
	return sueldo_sugerido(ValorJugador.base_salarial(
		jugador, 50.0, contrato_anios, division)) * Personalidad.factor_sueldo(jugador)


## El sueldo del que llega sale del presupuesto de Contratos, y ahora hay
## que tenerlo ENTERO antes de firmar: si te quedan $1.000 y el jugador
## cobra $1.100, no lo fichás.
##
## Antes no se chequeaba nada (Team._registrar_fichaje descontaba y
## listo), así que Contratos era la única caja que se podía dejar en
## negativo sin aviso — la deuda se arrastraba al año siguiente y sumaba
## para la quiebra sin que nadie te lo hubiera dicho.
static func puede_pagar_contrato(equipo: Team, sueldo: float) -> bool:
	return equipo.caja.get("contratos", 0.0) >= sueldo


static func motivo_contrato_corto(equipo: Team, sueldo: float) -> Dictionary:
	return {"exito": false,
		"motivo": "No te alcanza el presupuesto de Contratos para el sueldo.",
		"sueldo": sueldo, "disponible": equipo.caja.get("contratos", 0.0)}


## "$1234567.8" -> "$1,234,568" (redondeado). Para que los montos se lean
## de un vistazo en vez de tener que contar ceros.
## Con cuanta reputacion nace un club, a partir de la media de su once.
##
## Antes era `clamp(media, 20, 80)`, o sea la media a secas con un techo.
## El techo esta bien —80 a 100 es lo que se GANA ganando, no con lo que
## te toco al empezar— pero recortar en vez de reescalar aplastaba lo de
## arriba: division 1 (media 86.8) y division 2 (media 80.2) daban las dos
## 80, y con eso el mismo aforo, el mismo ingreso por entradas y la misma
## resistencia a vender. Seis puntos de plantel no se notaban en ningun
## lado.
##
## Ahora el rango util de medias se estira sobre el rango de reputacion,
## asi que las diez divisiones quedan separadas y el techo se conserva.
const REPUTACION_INICIAL_MIN := 20.0
const REPUTACION_INICIAL_MAX := 80.0
const MEDIA_REFERENCIA_MIN := 20.0
const MEDIA_REFERENCIA_MAX := 90.0


static func reputacion_inicial(media: float) -> float:
	var t: float = clampf(
		(media - MEDIA_REFERENCIA_MIN) / (MEDIA_REFERENCIA_MAX - MEDIA_REFERENCIA_MIN),
		0.0, 1.0)
	return lerpf(REPUTACION_INICIAL_MIN, REPUTACION_INICIAL_MAX, t)


static func formato_dinero(valor: float) -> String:
	var negativo := valor < 0.0
	var entero := int(round(abs(valor)))
	var digitos := str(entero)
	var con_comas := ""
	var contador := 0
	for i in range(digitos.length() - 1, -1, -1):
		con_comas = digitos[i] + con_comas
		contador += 1
		if contador % 3 == 0 and i != 0:
			con_comas = "," + con_comas
	return ("-$" if negativo else "$") + con_comas
