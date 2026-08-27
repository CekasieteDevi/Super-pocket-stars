class_name Ofertas
extends RefCounted

## §9.3 rework: las negociaciones abiertas del club, en las dos
## direcciones y por rondas.
##
## Antes una oferta se resolvía en el acto: tocabas Ofertar y en el mismo
## instante sabías si era sí o no. Acá una negociación DURA: la mandás, el
## otro se toma unos días, y puede aceptar, contraofertar o levantarse de
## la mesa. Y al revés: los otros clubes vienen a ofertar por los tuyos y
## te toca a vos decidir.
##
## Lo que hace que esto sea un sistema y no una lista de botones es que el
## jugador tiene la última palabra. Los clubes pueden arreglar el precio y
## el pase caerse igual porque no se pusieron de acuerdo en el contrato
## —eso no lo controla nadie— y ahí tu jugador se queda, con la novela
## adentro del vestuario.
##
## Solo existe para el club del jugador humano. Los clubes de la IA
## siguen resolviendo entre ellos de una (Mercado.ventana_entre_divisiones):
## simular cien negociaciones invisibles por temporada sería trabajo que
## nadie ve.

## Le toca responder al otro club.
const PENDIENTE_ELLOS := "pendiente_ellos"
## Nos toca responder a nosotros.
const PENDIENTE_NOSOTROS := "pendiente_nosotros"
## Los CLUBES se pusieron de acuerdo; falta el contrato con el jugador.
const ACUERDO_CLUB := "acuerdo_club"
## Terminadas.
const CERRADA := "cerrada"
const RECHAZADA := "rechazada"
const RETIRADA := "retirada"
const SIN_ACUERDO := "sin_acuerdo"

const ABIERTAS := [PENDIENTE_ELLOS, PENDIENTE_NOSOTROS, ACUERDO_CLUB]

## Cuánto tarda el otro club en contestar. Que no sea instantáneo es lo
## que convierte el mercado en algo que hay que administrar: mandás tres
## ofertas y esperás.
const DIAS_RESPUESTA_MIN := 2
const DIAS_RESPUESTA_MAX := 6

## Cuántas veces puede ir y venir una negociación antes de que el otro se
## canse. Sin tope, regatear sería gratis y siempre convendría.
const RONDAS_MAXIMAS := 4

## En una contraoferta nuestra, cuánto por encima de lo que pide el club
## hay que poner para que la acepte sin pensarlo.
const MARGEN_ACEPTACION := 1.0

## Cuando NOSOTROS contraofertamos pidiendo más por un jugador nuestro, el
## comprador acepta hasta este múltiplo de lo que él calculó que vale.
## Más que eso y se baja.
const TOPE_SOBREPRECIO_COMPRADOR := 1.35


static func nueva(id: int, club: String, jugador: Dictionary, monto: float, entrante: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	return {
		"id": id,
		"club": club,
		"jugador_id": int(jugador["id"]),
		"jugador": "%s %s" % [str(jugador.get("nombre", "")), str(jugador.get("apellido", ""))],
		"posicion": str(jugador["posicion"]),
		"monto": monto,
		"entrante": entrante,
		"estado": PENDIENTE_NOSOTROS if entrante else PENDIENTE_ELLOS,
		"ronda": 1,
		"dias": float(rng.randi_range(DIAS_RESPUESTA_MIN, DIAS_RESPUESTA_MAX)),
		"log": [],
	}


static func abierta(oferta: Dictionary) -> bool:
	return ABIERTAS.has(str(oferta["estado"]))


static func _anotar(oferta: Dictionary, texto: String) -> void:
	oferta["log"].append(texto)


## Descuenta días a las negociaciones que esperan respuesta del OTRO club
## y las resuelve cuando se cumple el plazo. Devuelve las que se movieron,
## para que la UI pueda avisar.
##
## `piramide` hace falta para encontrar al club que está del otro lado:
## las ofertas guardan el NOMBRE, no la referencia (igual que Copa y
## Confederacion), así se serializan sin arrastrar medio mundo.
static func avanzar(equipo: Team, dias: int, piramide, rng: RandomNumberGenerator,
		temporada_actual: int, division_propia: int) -> Array:
	var movidas := []
	for oferta in equipo.ofertas:
		var estado := str(oferta["estado"])
		# ACUERDO_CLUB de una oferta ENTRANTE = aceptaste vender y ahora
		# ellos hablan de contrato con TU jugador. Eso no lo manejas vos.
		var espera_al_otro: bool = estado == PENDIENTE_ELLOS 			or (estado == ACUERDO_CLUB and bool(oferta["entrante"]))
		if not espera_al_otro:
			continue
		oferta["dias"] = float(oferta["dias"]) - float(dias)
		if float(oferta["dias"]) > 0.0:
			continue
		if estado == ACUERDO_CLUB:
			_negocia_el_contrato_ajeno(equipo, oferta, piramide, rng, division_propia)
		else:
			_responde_el_otro(equipo, oferta, piramide, rng, temporada_actual)
		movidas.append(oferta)
	return movidas


static func _club_por_nombre(piramide, nombre: String) -> Team:
	for liga in piramide.divisiones:
		for e in liga.equipos:
			if e.nombre == nombre:
				return e
	return null


## El otro club contesta. Es el mismo criterio que usa Negociacion, pero
## con la posibilidad de CONTRAOFERTAR en vez de solo decir que sí o que
## no: si le falta poco, pide lo que pide y te devuelve la pelota.
static func _responde_el_otro(equipo: Team, oferta: Dictionary, piramide,
		rng: RandomNumberGenerator, temporada_actual: int) -> void:
	var otro := _club_por_nombre(piramide, str(oferta["club"]))
	var id := int(oferta["jugador_id"])
	if otro == null:
		oferta["estado"] = RETIRADA
		_anotar(oferta, "El club desapareció de la pirámide.")
		return

	if bool(oferta["entrante"]):
		_responde_comprador(equipo, oferta, otro, id)
	else:
		_responde_vendedor(equipo, oferta, otro, id, rng, temporada_actual)


## Somos NOSOTROS los que ofertamos por un jugador de `vendedor`.
static func _responde_vendedor(equipo: Team, oferta: Dictionary, vendedor: Team, id: int,
		rng: RandomNumberGenerator, temporada_actual: int) -> void:
	var donde := Mercado.ubicar(vendedor, id)
	if donde.is_empty():
		oferta["estado"] = RETIRADA
		_anotar(oferta, "Ya no juega en %s." % vendedor.nombre)
		return
	var jugador: Dictionary = donde["jugador"]
	var r := Negociacion.evaluar_oferta(vendedor, jugador, float(oferta["monto"]))

	if r["insulto"]:
		Negociacion.bloquear(vendedor, id, temporada_actual)
		oferta["estado"] = RETIRADA
		_anotar(oferta, "%s se ofendió con los %s y cortó la negociación." % [
			vendedor.nombre, Economia.formato_dinero(oferta["monto"])])
		return
	if r["acepta"]:
		oferta["estado"] = ACUERDO_CLUB
		_anotar(oferta, "%s acepta los %s. Falta arreglar contrato con el jugador." % [
			vendedor.nombre, Economia.formato_dinero(oferta["monto"])])
		return
	if int(oferta["ronda"]) >= RONDAS_MAXIMAS:
		oferta["estado"] = RETIRADA
		_anotar(oferta, "%s se cansó de negociar y se levantó de la mesa." % vendedor.nombre)
		return

	oferta["monto"] = float(r["pedido"])
	oferta["estado"] = PENDIENTE_NOSOTROS
	oferta["ronda"] = int(oferta["ronda"]) + 1
	_anotar(oferta, "%s contraoferta: piden %s." % [
		vendedor.nombre, Economia.formato_dinero(r["pedido"])])


## Son ELLOS los que ofertan por un jugador NUESTRO y les contraofertamos.
static func _responde_comprador(equipo: Team, oferta: Dictionary, comprador: Team, id: int) -> void:
	var donde := Mercado.ubicar(equipo, id)
	if donde.is_empty():
		oferta["estado"] = RETIRADA
		_anotar(oferta, "El jugador ya no está en el plantel.")
		return
	var jugador: Dictionary = donde["jugador"]
	var tasacion := ValorJugador.calcular(
		jugador, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))
	var monto := float(oferta["monto"])

	if monto <= tasacion * TOPE_SOBREPRECIO_COMPRADOR and comprador.caja["fichajes"] >= monto:
		oferta["estado"] = ACUERDO_CLUB
		_anotar(oferta, "%s acepta tu contraoferta de %s." % [
			comprador.nombre, Economia.formato_dinero(monto)])
		return
	if int(oferta["ronda"]) >= RONDAS_MAXIMAS:
		oferta["estado"] = RETIRADA
		_anotar(oferta, "%s no llega a esa cifra y se retira." % comprador.nombre)
		return

	# Le pone lo que puede: su tope, o lo que le entra en la caja.
	var mejorado: float = minf(tasacion * TOPE_SOBREPRECIO_COMPRADOR,
		comprador.caja["fichajes"] * Mercado.FRACCION_MAXIMA_POR_FICHAJE)
	if mejorado <= float(oferta["monto"]) * 0.5:
		oferta["estado"] = RETIRADA
		_anotar(oferta, "%s no puede pagar eso y se retira." % comprador.nombre)
		return
	oferta["monto"] = mejorado
	oferta["estado"] = PENDIENTE_NOSOTROS
	oferta["ronda"] = int(oferta["ronda"]) + 1
	_anotar(oferta, "%s baja la oferta a %s: es lo que le da la caja." % [
		comprador.nombre, Economia.formato_dinero(mejorado)])


## Aceptaste vender: ahora el comprador se sienta con TU jugador. Acá no
## opinás — si no se ponen de acuerdo en el contrato, el pase se cae y el
## jugador se queda, sabiendo que lo quisiste vender.
##
## El comprador ofrece lo que Negociacion.sueldo_pretendido dice que el
## jugador va a pedir, así que casi siempre cierra; lo que lo tumba es que
## el jugador no quiera ir igual (bajar mucho de categoría, ser hincha del
## club, estar cómodo donde está).
static func _negocia_el_contrato_ajeno(equipo: Team, oferta: Dictionary, piramide,
		rng: RandomNumberGenerator, division_propia: int) -> void:
	var comprador := _club_por_nombre(piramide, str(oferta["club"]))
	var id := int(oferta["jugador_id"])
	var donde := Mercado.ubicar(equipo, id)
	if comprador == null or donde.is_empty():
		oferta["estado"] = RETIRADA
		_anotar(oferta, "La operación se cayó sola.")
		return
	var jugador: Dictionary = donde["jugador"]

	var division_comprador := division_propia
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(comprador):
			division_comprador = d
			break

	var sueldo_actual: float = float(equipo.sueldos.get(id, 0.0))
	var ofrecido := Negociacion.sueldo_pretendido(
		jugador, sueldo_actual, division_propia, division_comprador)
	var detalle := Negociacion.interes_jugador(
		jugador, equipo.animo.get(id, 50.0), sueldo_actual, ofrecido,
		division_propia, division_comprador)

	if not detalle["acepta"]:
		oferta["estado"] = SIN_ACUERDO
		_anotar(oferta, "No se pusieron de acuerdo con el jugador: %s Se queda." % [
			Negociacion.motivo_rechazo(detalle)])
		return

	var monto := float(oferta["monto"])
	var r := Mercado.ejecutar_pase(comprador, equipo, id, monto, ofrecido, 3, rng)
	if not r["exito"]:
		oferta["estado"] = SIN_ACUERDO
		_anotar(oferta, "La operación no se pudo cerrar: %s" % r["motivo"])
		return
	oferta["estado"] = CERRADA
	_anotar(oferta, "Vendido a %s por %s." % [comprador.nombre, Economia.formato_dinero(monto)])


## Aceptar una oferta ENTRANTE: los clubes ya arreglaron, ahora hablan
## ellos con el jugador (ver _negocia_el_contrato_ajeno).
static func aceptar_entrante(oferta: Dictionary, rng: RandomNumberGenerator) -> void:
	oferta["estado"] = ACUERDO_CLUB
	oferta["dias"] = float(rng.randi_range(DIAS_RESPUESTA_MIN, DIAS_RESPUESTA_MAX))
	_anotar(oferta, "Aceptaste los %s. Ahora hablan de contrato con el jugador." % [
		Economia.formato_dinero(oferta["monto"])])


## Contraoferta NUESTRA: ponemos otra cifra y la pelota vuelve al otro
## lado. Sirve en las dos direcciones.
static func contraofertar(oferta: Dictionary, monto: float, rng: RandomNumberGenerator) -> void:
	oferta["monto"] = monto
	oferta["estado"] = PENDIENTE_ELLOS
	oferta["ronda"] = int(oferta["ronda"]) + 1
	oferta["dias"] = float(rng.randi_range(DIAS_RESPUESTA_MIN, DIAS_RESPUESTA_MAX))
	_anotar(oferta, "Contraofertaste %s." % Economia.formato_dinero(monto))


static func rechazar(oferta: Dictionary) -> void:
	oferta["estado"] = RECHAZADA
	_anotar(oferta, "Rechazaste la oferta.")


## Pasa una negociacion terminada al historial y la saca de la lista viva.
static func archivar(equipo: Team) -> void:
	var vivas := []
	for oferta in equipo.ofertas:
		if abierta(oferta):
			vivas.append(oferta)
		else:
			equipo.historial_mercado.append(oferta)
	equipo.ofertas = vivas


## Cada cuantos dias, en promedio, algun club se fija en tu plantel.
const DIAS_ENTRE_INTERESES := 9.0

## Cuanto de lo que vale el jugador ofrecen de arranque. Empiezan tirando
## abajo a proposito: para eso existe la contraoferta.
const OFERTA_INICIAL_MIN := 0.65
const OFERTA_INICIAL_MAX := 1.05


## Los otros clubes vienen a buscar a los tuyos. Cuanto mejor sea el
## jugador y mas rico el que mira, mas seguido pasa.
##
## Solo miran a los que TIENEN valor de reventa: no hay ofertas por el
## cuarto arquero. Y no ofertan por alguien que ya tiene una negociacion
## abierta, que seria una encerrona.
static func generar_entrantes(equipo: Team, piramide, rng: RandomNumberGenerator,
		dias: int, division_propia: int) -> Array:
	var nuevas := []
	if rng.randf() > float(dias) / DIAS_ENTRE_INTERESES:
		return nuevas

	var candidatos := equipo.jugadores + equipo.banco
	if candidatos.is_empty():
		return nuevas
	var jugador: Dictionary = candidatos[rng.randi() % candidatos.size()]
	var id := int(jugador["id"])
	for o in equipo.ofertas:
		if int(o["jugador_id"]) == id and abierta(o):
			return nuevas

	var valor := ValorJugador.calcular(jugador, equipo.animo.get(id, 50.0), equipo.contratos.get(id, 3))
	# Un club de cualquier division, con sesgo a los de cerca: los mismos
	# que compran en Mercado.ventana_entre_divisiones.
	var total_div: int = piramide.divisiones.size()
	var paso: int = int(rng.randf() * rng.randf() * float(total_div))
	if rng.randf() < 0.5:
		paso = -paso
	var d: int = clampi(division_propia + paso, 0, total_div - 1)
	var clubes: Array = piramide.divisiones[d].equipos
	var comprador: Team = clubes[rng.randi() % clubes.size()]
	if comprador == equipo:
		return nuevas

	var monto: float = valor * rng.randf_range(OFERTA_INICIAL_MIN, OFERTA_INICIAL_MAX)
	if comprador.caja["fichajes"] < monto:
		return nuevas

	var oferta := nueva(equipo.siguiente_id_oferta, comprador.nombre, jugador, monto, true, rng)
	equipo.siguiente_id_oferta += 1
	_anotar(oferta, "%s ofrece %s por %s." % [
		comprador.nombre, Economia.formato_dinero(monto), oferta["jugador"]])
	equipo.ofertas.append(oferta)
	nuevas.append(oferta)
	return nuevas
