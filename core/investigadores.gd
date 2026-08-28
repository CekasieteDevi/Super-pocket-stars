class_name Investigadores
extends RefCounted

## §9.4 rework: los INVESTIGADORES, la red de espionaje del club.
##
## Antes, en el mercado veías de un rival la media, el potencial, el valor
## y la cláusula de cualquiera, gratis y al instante. Con esto, de un
## jugador ajeno solo sabés el nombre y el puesto hasta que alguien vaya a
## verlo jugar. Todo lo demás —lo que rinde, lo que cobra, cuánto le queda
## de contrato, si tiene alguna habilidad— hay que averiguarlo.
##
## Es lo que le da sentido a negociar: si investigaste sabés más o menos
## cuánto pedir; si vas a ciegas podés ofertar una miseria y que te cierren
## la puerta (ver Negociacion).
##
## No se parecen a las instalaciones y por eso no viven en Instalaciones:
## no se MEJORAN, se contratan y se despiden. Tenés diez lugares y en cada
## uno ponés al investigador que puedas pagar. Las estrellas no cambian la
## calidad del informe —el informe siempre termina siendo completo— sino
## la VELOCIDAD, que es lo escaso: un mercado dura lo que dura.
##
## Los clubes de la IA no pasan por acá. Ellos ven todo, siempre. Simular
## su ignorancia sería trabajo invisible para el jugador.

## Seis slots, en una grilla de 3x2 en la UI. Diez era un numero sin
## forma: nadie llegaba a llenarlos y la pantalla era una lista larga.
const SLOTS := 6
const ESTRELLAS_MIN := 1
const ESTRELLAS_MAX := 10

## Cuántos DÍAS tarda en completar un informe, según las estrellas. Una
## temporada son ~266 días (38 fechas), asi que 1 estrella es media
## temporada y 10 estrellas tres semanas.
const DIAS_UNA_ESTRELLA := 133.0
const DIAS_DIEZ_ESTRELLAS := 21.0

## Cuánto dura un informe antes de quedar viejo, en días de calendario.
## Tres temporadas (~266 días cada una).
##
## Que CADUQUE es lo que le da trabajo permanente a la red: sin esto,
## investigabas una vez en la temporada 1 y en la 10 seguías viendo el
## rendimiento de ese jugador al día, gratis y para siempre, y después
## del primer año los investigadores no tenían nada que hacer.
##
## Se lleva en días y no en temporadas para no tener que arrastrar el
## número de temporada por medio motor: se descuenta en el mismo lugar
## que la fatiga y los días de lesión (Team.avanzar_dias).
const DIAS_VIGENCIA := 798

## Cuánto sale contratar a uno, de una vez y para siempre (sale de
## Mejoras). Crece con el cuadrado de las estrellas: un investigador de 10
## es una inversión de club grande, no algo que compres en división 10 con
## el vuelto.
const COSTO_BASE := 5000.0


static func dias_de_informe(estrellas: int) -> float:
	var e: float = float(clamp(estrellas, ESTRELLAS_MIN, ESTRELLAS_MAX))
	var t: float = (e - 1.0) / float(ESTRELLAS_MAX - 1)
	return lerpf(DIAS_UNA_ESTRELLA, DIAS_DIEZ_ESTRELLAS, t)


static func costo(estrellas: int) -> float:
	var e: float = float(clamp(estrellas, ESTRELLAS_MIN, ESTRELLAS_MAX))
	return COSTO_BASE * e * e


## Contrata a un investigador y lo mete en el primer slot libre.
static func contratar(equipo: Team, estrellas: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if equipo.investigadores.size() >= SLOTS:
		return {"exito": false, "motivo": "Ya tenés los %d investigadores." % SLOTS}
	var precio := costo(estrellas)
	if equipo.caja["mejoras"] < precio:
		return {"exito": false, "motivo": "No alcanza el presupuesto de Mejoras.",
			"costo": precio, "disponible": equipo.caja["mejoras"]}
	equipo.caja["mejoras"] -= precio
	var inv := nuevo(equipo.siguiente_id_investigador, estrellas, rng)
	equipo.siguiente_id_investigador += 1
	equipo.investigadores.append(inv)
	return {"exito": true, "investigador": inv, "costo": precio}


## La forma de un investigador, en un solo lugar.
##
## Team armaba el investigador inicial a mano, con las mismas claves menos
## `nombre_objetivo`, y la UI se rompia al leerlo: el codigo viejo solo
## tocaba esa clave cuando el tipo estaba ocupado, asi que el agujero
## nunca se noto. Mismo problema que tuvo `conocimiento` — si un formato
## se escribe a mano en dos lados, tarde o temprano difieren.
## `rng` null = se arma uno sembrado con el id. Asi un investigador
## siempre tiene el MISMO nombre aunque se lo reconstruya al cargar una
## partida vieja, sin tener que pasar el rng del juego hasta aca.
static func nuevo(id: int, estrellas: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash("investigador:%d" % id)
	var identidad := GeneradorNombres.nombre_jugador(rng)
	return {
		"id": id,
		"nombre": "%s %s" % [identidad["nombre"], identidad["apellido"]],
		"estrellas": clamp(estrellas, ESTRELLAS_MIN, ESTRELLAS_MAX),
		"objetivo": -1,       # jugador_id que está investigando, -1 = libre
		"club_objetivo": "",  # de qué club es, para poder mostrarlo
		"nombre_objetivo": "",
		"dias": 0.0,          # cuánto lleva investigando a este objetivo
	}


## Lo despide. No hay devolución: lo que pagaste, pagado. Sirve para
## liberar un slot y poner a uno mejor. Un informe a medio hacer se
## pierde.
static func despedir(equipo: Team, investigador_id: int) -> bool:
	for i in range(equipo.investigadores.size()):
		if int(equipo.investigadores[i]["id"]) == investigador_id:
			equipo.investigadores.remove_at(i)
			return true
	return false


static func libres(equipo: Team) -> Array:
	var salida := []
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == -1:
			salida.append(inv)
	return salida


## Le pone un objetivo al MEJOR investigador libre — al jugador no le
## interesa elegir cuál, le interesa cuánto tarda.
static func investigar(equipo: Team, jugador_id: int, club_nombre: String,
		nombre_jugador: String = "") -> Dictionary:
	if equipo.conocimiento.has(jugador_id):
		return {"exito": false, "motivo": "Ya lo conocés."}
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == jugador_id:
			return {"exito": false, "motivo": "Ya lo estás investigando."}
	var mejor := {}
	for inv in libres(equipo):
		if mejor.is_empty() or int(inv["estrellas"]) > int(mejor["estrellas"]):
			mejor = inv
	if mejor.is_empty():
		return {"exito": false, "motivo": "No tenés investigadores libres."}
	mejor["objetivo"] = jugador_id
	mejor["club_objetivo"] = club_nombre
	mejor["nombre_objetivo"] = nombre_jugador
	mejor["dias"] = 0.0
	return {"exito": true, "investigador": mejor, "dias_totales": dias_de_informe(int(mejor["estrellas"]))}


## Lo saca del objetivo sin completarlo. El progreso se pierde.
static func cancelar(equipo: Team, investigador_id: int) -> bool:
	for inv in equipo.investigadores:
		if int(inv["id"]) == investigador_id:
			inv["objetivo"] = -1
			inv["club_objetivo"] = ""
			inv["nombre_objetivo"] = ""
			inv["dias"] = 0.0
			return true
	return false


## Avanza los informes en curso. Lo llama Team.avanzar_dias, igual que la
## fatiga y las lesiones: los informes corren con el calendario, no con
## las fechas jugadas, así que una semana de dos partidos no acelera nada.
## Devuelve los jugador_id de los informes que se completaron.
## Devuelve los jugador_id de los informes que se COMPLETARON en este
## tramo. De paso vence los que ya quedaron viejos (DIAS_VIGENCIA).
static func avanzar(equipo: Team, dias: int) -> Array:
	# Los informes viejos se van venciendo con el calendario.
	for id in equipo.conocimiento.keys():
		var resta: float = float(equipo.conocimiento[id]) - float(dias)
		if resta <= 0.0:
			equipo.conocimiento.erase(id)
		else:
			equipo.conocimiento[id] = resta

	var terminados := []
	for inv in equipo.investigadores:
		var objetivo: int = int(inv["objetivo"])
		if objetivo == -1:
			continue
		inv["dias"] = float(inv["dias"]) + float(dias)
		if float(inv["dias"]) >= dias_de_informe(int(inv["estrellas"])):
			marcar_conocido(equipo, objetivo)
			terminados.append(objetivo)
			inv["objetivo"] = -1
			inv["club_objetivo"] = ""
			inv["nombre_objetivo"] = ""
			inv["dias"] = 0.0
	return terminados


## Cuánto le falta a un informe, de 0.0 a 1.0. -1.0 si nadie lo investiga.
static func progreso(equipo: Team, jugador_id: int) -> float:
	for inv in equipo.investigadores:
		if int(inv["objetivo"]) == jugador_id:
			return clampf(float(inv["dias"]) / dias_de_informe(int(inv["estrellas"])), 0.0, 1.0)
	return -1.0


## Lo unico que se sabe de un jugador sin informe. El resto de la UI se
## apoya en esto para no filtrar datos sin querer.
##
## No hace falta mirar la fecha: el informe se vence solo descontando dias
## en avanzar(), asi que si esta en el diccionario, esta vigente.
static func conoce(equipo: Team, jugador_id: int) -> bool:
	return equipo.conocimiento.has(jugador_id)


## Da por conocido a un jugador, con el plazo entero por delante. Existe
## para que el formato de `conocimiento` (dias restantes, no un booleano)
## viva en UN solo lugar: escribirlo a mano desde afuera es como se colo
## el bug de `= true`, que con el descuento de avanzar() dejaba el
## conocimiento en un dia y lo evaporaba en la primera semana.
static func marcar_conocido(equipo: Team, jugador_id: int) -> void:
	equipo.conocimiento[jugador_id] = float(DIAS_VIGENCIA)


## Cuantos dias le quedan de vigencia a un informe. -1 si no lo conoces.
static func vigencia(equipo: Team, jugador_id: int) -> int:
	if not equipo.conocimiento.has(jugador_id):
		return -1
	return int(ceil(float(equipo.conocimiento[jugador_id])))
