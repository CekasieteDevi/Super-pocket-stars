class_name Sponsors
extends RefCounted

## Sponsors del club: te mandan ofertas, ocupan un lugar de los diez que
## hay, te pagan al cerrar la temporada y te cortan el contrato si no
## cumplís lo que te pidieron.
##
## La gracia es que el sponsor que te sirve hoy te sobra mañana: en
## división 10 te va a escribir el Kiosco Don Beto y en primera te escribe
## Sumsung, pero si llenaste los diez lugares con kioscos no te llega
## ninguna oferta grande — no llegan ofertas si no hay lugar. Cancelar un
## contrato chico para hacerle sitio a uno grande es la decisión.
##
## Los sponsors son SOLO del club del jugador. Los 200 clubes de la IA no
## los tienen: sería llevarle la contabilidad de sponsors a doscientos
## clubes que nadie va a mirar, y su economía ya está resuelta con
## Economia.procesar_temporada.

const RUTA := "res://data/sponsors.json"

## Los lugares del club. Diez, como los slots de investigadores.
const LUGARES := 10

## Lo que paga POR TEMPORADA un sponsor de DIVISIÓN 10 en cada escalón de
## exigencia, antes de su factor propio. De ahí para arriba se multiplica
## por lo mismo que escala el resto de la economía (Economia.factor_division),
## así que un sponsor de primera con el mismo requisito paga ~205 veces más
## — igual que los ingresos de un club de primera.
##
## Antes el número era por partido y se cobraba fecha a fecha. Confundía:
## la plata no entraba al presupuesto en el momento, porque el presupuesto
## se arma una vez por año en el cierre de temporada. Un sponsor que dice
## "paga por partido" y no mueve el presupuesto en ningún partido es una
## mecánica que no se siente. Ahora el número es el del año y se cobra
## cuando termina, así que va derecho al presupuesto del año siguiente.
##
## Son los mismos valores de antes multiplicados por las 38 fechas: la
## economía no cambia, cambia cómo se dice y cuándo se cobra.
const PAGO_D10 := {
	"ninguno": 684.0,
	"no_ultimo": 1520.0,
	"mitad_tabla": 2470.0,
	"top5": 3610.0,
	"top3": 5130.0,
	"campeon": 7220.0,
}

## Lo que le pide cada escalón al CLUB para siquiera escribirte, en
## reputación y en hinchada. Es el "si cruzamos cierto número nos empiezan
## a llegar sponsors": antes cualquier club de cualquier tamaño recibía
## las mismas ofertas y conseguir sponsors era gratis.
##
## La reputación va como un ESCALÓN sobre lo que le corresponde a la
## división (Reputacion.referencia): un sponsor de décima que pide
## prestigio pide prestigio de décima. Sin eso, un mínimo absoluto de 60
## dejaría a las divisiones de abajo sin ningún sponsor grande y a primera
## con todos regalados.
##
## La hinchada va en APOYO (0..1, ver Fans.apoyo) por la misma razón: lo
## que importa es ser grande para tu categoría. Un club recién generado
## arranca en ~0.3, así que los dos primeros escalones le escriben desde
## el dia uno y el resto hay que ganárselos.
## Los escalones están corridos 5 puntos por debajo de la referencia
## porque la reputación REAL de una división se queda un poco abajo de
## ella: medido a ocho temporadas, la décima termina en 29 de media
## contra una referencia de 35 —pierde sus dos mejores por ascenso cada
## año y recibe descendidos con su -8, y no tiene nada más abajo que la
## compense—. Con los escalones sin correr, un club normal de décima no
## calificaba ni para un sponsor de media tabla.
const MINIMO_REPUTACION := {
	"ninguno": -17.0,
	"no_ultimo": -11.0,
	"mitad_tabla": -5.0,
	"top5": 0.0,
	"top3": 5.0,
	"campeon": 10.0,
}

const MINIMO_APOYO := {
	"ninguno": 0.0,
	"no_ultimo": 0.20,
	"mitad_tabla": 0.35,
	"top5": 0.50,
	"top3": 0.62,
	"campeon": 0.75,
}

const TEXTO_REQUISITO := {
	"ninguno": "Sin requisitos.",
	"no_ultimo": "No salir último en la liga.",
	"mitad_tabla": "Terminar en la mitad de arriba de la tabla.",
	"top5": "Terminar entre los 5 primeros.",
	"top3": "Terminar entre los 3 primeros.",
	"campeon": "Salir campeón de la liga.",
}

## Cuántos días vive una oferta antes de que el sponsor se canse. Sin
## esto, las ofertas se acumulan y elegir deja de tener costo.
const DIAS_OFERTA := 12

## Chance por día de que llegue una oferta, con el club a media tabla.
## Baja con lo mal que te vaya: "los sponsors aparecen cuando nos empieza
## a ir bien" — un club último de la tabla no le interesa a nadie.
const CHANCE_BASE := 0.14

## Cuántas ofertas puede haber esperando respuesta a la vez. No es lo
## mismo que LUGARES: sin tope, dejar la bandeja sin tocar durante medio
## año te daba una lista de treinta para elegir con calma.
const MAX_OFERTAS := 4

static var _cache = null


static func catalogo() -> Array:
	if _cache == null:
		_cache = DataLoader.load_json(RUTA)["divisiones"]
	return _cache


## Lo que paga por temporada un sponsor de esta división. `division` es
## 0-indexada (0 = primera).
static func pago_de(requisito: String, factor: float, division: int) -> float:
	var base: float = float(PAGO_D10.get(requisito, PAGO_D10["ninguno"]))
	# Relativo a división 10, que es donde están calibrados los números de
	# PAGO_D10: en primera el mismo sponsor paga lo que paga primera.
	var escala: float = Economia.factor_division(division) \
		/ Economia.factor_division(Piramide.N_DIVISIONES - 1)
	return base * factor * escala


## Una oferta nueva de un sponsor de esta división que el club todavía no
## tenga (ni contratado ni ofertando). {} si no hay ninguno libre.
static func generar_oferta(equipo: Team, division: int, rng: RandomNumberGenerator) -> Dictionary:
	var lista: Array = catalogo()[clampi(division, 0, lista_size() - 1)]
	var ocupados := {}
	for s in equipo.sponsors:
		ocupados[str(s["nombre"])] = true
	for o in equipo.sponsors_ofertas:
		ocupados[str(o["nombre"])] = true

	var libres := []
	for s in lista:
		if ocupados.has(str(s["nombre"])):
			continue
		# El club tiene que estar a la altura: un sponsor que paga como
		# los que pagan por salir campeon no le escribe a cualquiera.
		if not tiene_el_nombre(equipo, str(s["requisito"]), division):
			continue
		libres.append(s)
	if libres.is_empty():
		return {}
	var elegido: Dictionary = libres[rng.randi() % libres.size()]
	return {
		"nombre": str(elegido["nombre"]),
		"requisito": str(elegido["requisito"]),
		"pago": pago_de(str(elegido["requisito"]), float(elegido["factor"]), division),
		"division": division + 1,
		"dias": DIAS_OFERTA,
	}


static func lista_size() -> int:
	return catalogo().size()


## Cuántas ofertas llegan hoy. `posicion` y `total` son la tabla de la
## liga: cuanto peor vas, menos ganas tiene nadie de ponerte la marca en
## la camiseta.
##
## No llega NADA si no hay lugar libre: es lo que obliga a cancelar un
## contrato chico si querés que te escriba uno grande.
static func tirar_ofertas(equipo: Team, division: int, posicion: int, total: int,
		rng: RandomNumberGenerator) -> Array:
	if equipo.sponsors.size() >= LUGARES:
		return []
	if equipo.sponsors_ofertas.size() >= MAX_OFERTAS:
		return []
	# De 1.4 saliendo primero a 0.35 saliendo último.
	var relativo: float = 1.0 - float(posicion - 1) / float(maxi(total - 1, 1))
	var chance: float = CHANCE_BASE * lerpf(0.35, 1.4, relativo)
	if rng.randf() >= chance:
		return []
	var oferta := generar_oferta(equipo, division, rng)
	if oferta.is_empty():
		return []
	equipo.sponsors_ofertas.append(oferta)
	return [oferta]


## Un día menos para cada oferta. Devuelve las que se cayeron.
static func avanzar_dias(equipo: Team, dias: int) -> Array:
	var caidas := []
	var vivas := []
	for o in equipo.sponsors_ofertas:
		o["dias"] = int(o["dias"]) - dias
		if int(o["dias"]) <= 0:
			caidas.append(o)
		else:
			vivas.append(o)
	equipo.sponsors_ofertas = vivas
	return caidas


static func aceptar(equipo: Team, nombre: String, temporada: int) -> Dictionary:
	if equipo.sponsors.size() >= LUGARES:
		return {"exito": false, "motivo": "No te quedan lugares libres. Cancelá un contrato primero."}
	for i in range(equipo.sponsors_ofertas.size()):
		if str(equipo.sponsors_ofertas[i]["nombre"]) != nombre:
			continue
		var o: Dictionary = equipo.sponsors_ofertas[i]
		equipo.sponsors_ofertas.remove_at(i)
		equipo.sponsors.append({
			"nombre": str(o["nombre"]), "requisito": str(o["requisito"]),
			"pago": float(o["pago"]), "division": int(o["division"]),
			"desde": temporada, "cobrado": 0.0, "partidos": 0,
		})
		return {"exito": true, "sponsor": equipo.sponsors[equipo.sponsors.size() - 1]}
	return {"exito": false, "motivo": "Esa oferta ya no está."}


static func rechazar(equipo: Team, nombre: String) -> bool:
	for i in range(equipo.sponsors_ofertas.size()):
		if str(equipo.sponsors_ofertas[i]["nombre"]) == nombre:
			equipo.sponsors_ofertas.remove_at(i)
			return true
	return false


static func cancelar(equipo: Team, nombre: String) -> bool:
	for i in range(equipo.sponsors.size()):
		if str(equipo.sponsors[i]["nombre"]) == nombre:
			equipo.sponsors.remove_at(i)
			return true
	return false


## Las fechas de liga que tiene una temporada. Es lo que se usa para
## prorratear al sponsor que firma con el año empezado.
static func partidos_de_liga() -> int:
	return Economia.PARTIDOS_DE_LOCAL * 2


## Lo que lleva ganado un sponsor en lo que va del año.
##
## Se prorratea por fechas jugadas bajo contrato. El que firma en la
## última fecha no cobra el año entero: si cobrara, la jugada óptima
## sería dejar los diez lugares vacíos y llenarlos sobre el final.
static func acumulado_de(sponsor: Dictionary) -> float:
	var fechas: int = mini(int(sponsor["partidos"]), partidos_de_liga())
	return float(sponsor["pago"]) * float(fechas) / float(partidos_de_liga())


## Se jugó una fecha de liga. No entra plata: solo corre el contador que
## después decide qué parte del año cobra cada sponsor.
static func registrar_partido(equipo: Team) -> void:
	for s in equipo.sponsors:
		s["partidos"] = int(s["partidos"]) + 1
		s["cobrado"] = acumulado_de(s)


## Cierre de temporada: cobran todos. Devuelve el total.
##
## La plata no va a la caja: la caja se ARMA de cero en el cierre a
## partir del ingreso del año. Se acumula en Team.ingresos_sponsors y
## entra como un ingreso más de la temporada, igual que los premios de
## copa. Va antes de Economia.procesar_temporada, que es quien la reparte
## en el presupuesto del año que viene.
static func cobrar_temporada(equipo: Team) -> float:
	var total := 0.0
	for s in equipo.sponsors:
		var parte := acumulado_de(s)
		s["cobrado"] = parte
		total += parte
	equipo.ingresos_sponsors += total
	return total


## Si el club llega al minimo de reputacion y de hinchada de este
## escalon. Vale para las dos puntas: para que te escriban y para que se
## queden. Un club que cae de division o que se vacia el estadio pierde a
## los sponsors grandes al cerrar la temporada.
static func tiene_el_nombre(equipo: Team, requisito: String, division: int) -> bool:
	return (equipo.reputacion >= reputacion_minima(requisito, division)
		and Fans.apoyo(equipo, division) >= float(MINIMO_APOYO.get(requisito, 0.0)))


static func reputacion_minima(requisito: String, division: int) -> float:
	return clampf(
		Reputacion.referencia(division) + float(MINIMO_REPUTACION.get(requisito, 0.0)),
		Reputacion.MINIMO, Reputacion.MAXIMO)


## Que le pide este escalon al club, para mostrarlo en la ficha del
## sponsor: no sirve de nada que te lo saquen si no sabias que te lo
## pedian.
static func texto_minimos(requisito: String, division: int) -> String:
	var partes := ["reputación %d" % int(round(reputacion_minima(requisito, division)))]
	var apoyo := float(MINIMO_APOYO.get(requisito, 0.0))
	if apoyo > 0.0:
		partes.append("hinchada de %s" % Fans.texto(Fans.fans_para_apoyo(apoyo, division)))
	return "Pide " + " y ".join(partes) + "."


static func cumple(requisito: String, posicion: int, total: int) -> bool:
	match requisito:
		"ninguno":
			return true
		"no_ultimo":
			return posicion < total
		"mitad_tabla":
			return posicion <= int(ceil(total / 2.0))
		"top5":
			return posicion <= 5
		"top3":
			return posicion <= 3
		"campeon":
			return posicion == 1
	return true


## Cierre de temporada: el que pidió algo y no lo tuvo, se va. Devuelve
## los que se fueron, para el feed.
static func evaluar_temporada(equipo: Team, posicion: int, total: int,
		division: int = -1) -> Array:
	var caidos := []
	var siguen := []
	for s in equipo.sponsors:
		var req := str(s["requisito"])
		if cumple(req, posicion, total) and tiene_el_nombre(equipo, req, division):
			# El contador de lo cobrado es POR TEMPORADA, como todo el
			# resto de la economia: se reinicia con ella.
			s["cobrado"] = 0.0
			s["partidos"] = 0
			siguen.append(s)
		else:
			caidos.append(s)
	equipo.sponsors = siguen
	# Las ofertas que quedaron sin responder tampoco cruzan el año: el
	# sponsor que te escribio en octubre no te sigue esperando en marzo.
	equipo.sponsors_ofertas = []
	return caidos


## Lo que entra por temporada con los sponsors de hoy, a año completo.
static func pago_por_temporada(equipo: Team) -> float:
	var total := 0.0
	for s in equipo.sponsors:
		total += float(s["pago"])
	return total
