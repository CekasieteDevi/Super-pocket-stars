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

const SLOTS := 10
const ESTRELLAS_MIN := 1
const ESTRELLAS_MAX := 10

## Cuántos DÍAS tarda en completar un informe, según las estrellas. Una
## temporada son ~266 días (38 fechas), asi que 1 estrella es media
## temporada y 10 estrellas tres semanas.
const DIAS_UNA_ESTRELLA := 133.0
const DIAS_DIEZ_ESTRELLAS := 21.0

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
static func contratar(equipo: Team, estrellas: int) -> Dictionary:
	if equipo.investigadores.size() >= SLOTS:
		return {"exito": false, "motivo": "Ya tenés los %d investigadores." % SLOTS}
	var precio := costo(estrellas)
	if equipo.caja["mejoras"] < precio:
		return {"exito": false, "motivo": "No alcanza el presupuesto de Mejoras.",
			"costo": precio, "disponible": equipo.caja["mejoras"]}
	equipo.caja["mejoras"] -= precio
	var inv := {
		"id": equipo.siguiente_id_investigador,
		"estrellas": clamp(estrellas, ESTRELLAS_MIN, ESTRELLAS_MAX),
		"objetivo": -1,       # jugador_id que está investigando, -1 = libre
		"club_objetivo": "",  # de qué club es, para poder mostrarlo
		"nombre_objetivo": "",
		"dias": 0.0,         # cuánto lleva investigando a este objetivo
	}
	equipo.siguiente_id_investigador += 1
	equipo.investigadores.append(inv)
	return {"exito": true, "investigador": inv, "costo": precio}


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
static func avanzar(equipo: Team, dias: int) -> Array:
	var terminados := []
	for inv in equipo.investigadores:
		var objetivo: int = int(inv["objetivo"])
		if objetivo == -1:
			continue
		inv["dias"] = float(inv["dias"]) + float(dias)
		if float(inv["dias"]) >= dias_de_informe(int(inv["estrellas"])):
			equipo.conocimiento[objetivo] = true
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
static func conoce(equipo: Team, jugador_id: int) -> bool:
	return equipo.conocimiento.has(jugador_id)
