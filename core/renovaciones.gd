class_name Renovaciones
extends RefCounted

## §9.3: renovar un contrato es una NEGOCIACION, no un tramite automatico.
##
## Antes, al club del jugador humano se le renovaba todo solo: contrato
## vencido, dos a cuatro años nuevos al azar y el sueldo recalculado al
## valor de HOY (ver Liga._renovar_contrato). Nadie decidia nada y la masa
## salarial subia sola cada temporada, contra un ingreso que tiene techo
## duro (el aforo clampea a 1.0, ver Economia.procesar_temporada). Ese era
## el agujero: el club no tenia forma de decir que no.
##
## Ahora es un ida y vuelta. El jugador tiene un numero en la cabeza; vos
## le ofreces años y plata. Segun lo que ofrezcas:
##
##   - Acepta. Firma y se acabo.
##   - Contraoferta. Baja lo que pide (o pide un año mas en vez de mas
##     plata) y espera tu respuesta. Ronda tras ronda va cediendo, asi
##     que termina firmando por menos de lo que queria al principio.
##   - Se ofende. Debajo de FRACCION_INSULTO no es negociar bajo, es
##     faltarle el respeto: corta la negociacion y no te atiende por
##     DIAS_BLOQUEO. Mismo criterio que Negociacion.FRACCION_INSULTO usa
##     para los pases.
##   - Se cansa. Si despues de RONDAS_MAX vueltas seguis sin llegarle,
##     lo termina el, con el mismo bloqueo.

## Se muestran los que tienen UN año o menos: los que se van al final de
## esta temporada si no se hace nada.
const ANIOS_PARA_MOSTRAR := 1

const ANIOS_MIN := 1
const ANIOS_MAX := 5

## Cuanto se le perdona a una oferta que casi llega. Misma razon que en
## Negociacion.TOLERANCIA_ACEPTACION: lo que pide se recalcula al
## contestar y el animo derivo mientras tanto.
const TOLERANCIA := 0.98

## Debajo de esta fraccion de lo que pide, la oferta ofende. Un jugador
## que paso de media 60 a 90 y recibe un 25% menos de lo que vale no lo
## lee como una oferta baja: lo lee como que el club no lo valora.
const FRACCION_INSULTO := 0.75

## Cuanto no te atiende despues de ofenderse. Dos meses de calendario: una
## temporada son ~266 dias (38 fechas), asi que son ~8 fechas sin poder
## sentarte con el. Si el contrato se le vence en el medio, lo perdiste.
const DIAS_BLOQUEO := 60

## Cuanto de la brecha cede el jugador en cada contraoferta.
##
## Calibrado con tests/_diag_rondas_renovacion.gd, que cuenta los clicks
## de "Ofrecer" que hacen falta para cerrar. Con 0.35 una oferta al 88%
## tardaba SEIS rondas y se sentia una grilla, no una charla. Con 0.6,
## cualquier oferta que el jugador vaya a aceptar cierra en cuatro o
## menos.
const CESION_POR_RONDA := 0.6

## Cuantas veces se sienta a hablar antes de cansarse.
##
## Sin este tope, una oferta por debajo de PISO_DE_CESION dejaba la
## negociacion en contraoferta para siempre: el jugador nunca aceptaba y
## nunca cortaba, asi que se podia clickear "Ofrecer" al infinito sin que
## pasara nada. Ahora la quinta negativa la termina el.
const RONDAS_MAX := 4

## Hasta donde puede bajar, por mas rondas que pases. Es el piso real de
## lo que acepta: 82% de lo que pedia al empezar. Sin piso, con paciencia
## infinita se lo renovaba por dos pesos.
const PISO_DE_CESION := 0.82

## A partir de esta ronda deja de pedir solo plata y pide un año mas. Un
## jugador al que le estiraste la negociacion quiere estabilidad, y para
## el club es la salida barata: un año mas no cuesta caja hoy.
const RONDA_PIDE_ANIOS := 2

## Cuanto mueve el largo del contrato lo que el jugador pide, por cada año
## arriba de ANIOS_REFERENCIA.
##
## Los jovenes cobran por atarse: firmar cinco años a los 22 es resignar
## los pases que podrian venir, y lo cobran. Los veteranos pagan por lo
## contrario: a los 33, tener contrato largo es seguridad y aceptan menos.
const ANIOS_REFERENCIA := 2
const PRIMA_JOVEN_POR_ANIO := 0.06
const DESCUENTO_VETERANO_POR_ANIO := 0.05
const EDAD_VETERANO := 30

## Cuanto encarece la renovacion que el jugador la este pasando mal. Un
## jugador con el animo por el piso no firma por lo mismo que uno
## contento: o le pagas la diferencia o se va.
const PESO_ANIMO := 0.30


## Los del plantel activo (titulares+banco) a los que se les vence el
## contrato. La cantera no entra: todavia no tiene contrato profesional.
static func pendientes(equipo: Team) -> Array:
	var lista := []
	for jugador in equipo.todos_los_jugadores():
		if int(equipo.contratos.get(jugador["id"], 99)) > ANIOS_PARA_MOSTRAR:
			continue
		lista.append(jugador)
	lista.sort_custom(func(a, b):
		return int(equipo.contratos.get(a["id"], 0)) < int(equipo.contratos.get(b["id"], 0)))
	return lista


## Cuantos dias faltan para que te vuelva a atender. 0 = te atiende.
static func dias_bloqueado(equipo: Team, id: int) -> int:
	return int(equipo.renovaciones.get(id, {}).get("bloqueo", 0))


## En que ronda va la negociacion. 0 = todavia no le ofreciste nada.
static func ronda(equipo: Team, id: int) -> int:
	return int(equipo.renovaciones.get(id, {}).get("ronda", 0))


## Lo que el jugador quiere cobrar por firmar esos años, ANTES de sentarse
## a negociar.
##
## Parte de lo que vale hoy (Economia.sueldo_de_ficha, que ya incluye el
## Mercenario y el Hincha del club) y nunca baja de lo que cobra hoy: a
## nadie se le renueva por menos de lo que ya gana.
##
## Sirve para las dos negociaciones que hay, y la diferencia entre ellas
## sale sola de si el jugador esta o no en el plantel:
##
##   - Uno propio: cobra un sueldo hoy y su pretension se amortigua
##     contra tu division (ValorJugador.media_salarial).
##   - Un agente libre (AgentesLibres.fichar): no cobra nada hoy y NO se
##     amortigua. Si se amortiguara, un crack sin club firmaria por dos
##     pesos en decima division; sin amortiguar, pide lo que vale y lo
##     unico que te frena es que el presupuesto de Contratos te alcance.
static func sueldo_pretendido(equipo: Team, jugador: Dictionary, anios: int) -> float:
	var id: int = jugador["id"]
	var anios_reales: int = clampi(anios, ANIOS_MIN, ANIOS_MAX)
	var division: int = equipo.division_actual if equipo.contratos.has(id) else -1
	var base: float = maxf(
		float(equipo.sueldos.get(id, 0.0)),
		Economia.sueldo_de_ficha(jugador, anios_reales, division))

	var extra: int = anios_reales - ANIOS_REFERENCIA
	var factor_anios := 1.0
	if int(jugador.get("edad", 25)) >= EDAD_VETERANO:
		factor_anios -= DESCUENTO_VETERANO_POR_ANIO * float(extra)
	else:
		factor_anios += PRIMA_JOVEN_POR_ANIO * float(extra)

	# 50 de animo es neutro: por debajo pide mas, por encima menos.
	var animo: float = clampf(equipo.animo.get(id, 50.0), 0.0, 100.0)
	var factor_animo: float = 1.0 + (50.0 - animo) / 100.0 * PESO_ANIMO

	return base * maxf(factor_anios, 0.5) * factor_animo


## Lo que pide AHORA, contando lo que ya cedio en esta negociacion. Si
## nunca te sentaste con el, es el pretendido de tabla.
##
## Lo cedido se guarda como fraccion y no como monto porque el pretendido
## cambia con los años que le ofrezcas: si negociaste por 2 años y despues
## le ofreces 5, el descuento que ya te gano lo sigue acompañando.
static func pide_ahora(equipo: Team, jugador: Dictionary, anios: int) -> float:
	var estado: Dictionary = equipo.renovaciones.get(int(jugador["id"]), {})
	var fraccion: float = float(estado.get("fraccion", 1.0))
	return sueldo_pretendido(equipo, jugador, anios) * fraccion


## El corazon del ida y vuelta. Devuelve {respuesta, ...} donde respuesta
## es "acepta", "contraoferta", "insulto", "se_cansa" o "bloqueado".
##
## No firma nada: eso lo hace `firmar`, y solo despues de un "acepta".
## Separarlo deja que la UI muestre lo que contesto antes de mover plata.
static func ofrecer(equipo: Team, jugador: Dictionary, anios: int, sueldo: float) -> Dictionary:
	var id: int = jugador["id"]
	var bloqueo := dias_bloqueado(equipo, id)
	if bloqueo > 0:
		return {"respuesta": "bloqueado", "dias": bloqueo}

	var anios_reales: int = clampi(anios, ANIOS_MIN, ANIOS_MAX)
	var tabla := sueldo_pretendido(equipo, jugador, anios_reales)
	var pide := pide_ahora(equipo, jugador, anios_reales)
	var estado: Dictionary = equipo.renovaciones.get(
		id, {"fraccion": 1.0, "ronda": 0, "bloqueo": 0})

	if sueldo >= pide * TOLERANCIA:
		return {"respuesta": "acepta", "pide": pide, "anios": anios_reales, "sueldo": sueldo}

	if sueldo < pide * FRACCION_INSULTO:
		estado["bloqueo"] = DIAS_BLOQUEO
		estado["ronda"] = 0
		estado["fraccion"] = 1.0
		equipo.renovaciones[id] = estado
		return {"respuesta": "insulto", "pide": pide, "dias": DIAS_BLOQUEO}

	estado["ronda"] = int(estado.get("ronda", 0)) + 1

	# Se le acabo la paciencia. No es lo mismo que ofenderse —no le
	# faltaste el respeto, no se pusieron de acuerdo— pero termina igual:
	# no se sienta a hablar de nuevo hasta dentro de DIAS_BLOQUEO.
	if int(estado["ronda"]) > RONDAS_MAX:
		estado["bloqueo"] = DIAS_BLOQUEO
		estado["ronda"] = 0
		estado["fraccion"] = 1.0
		equipo.renovaciones[id] = estado
		return {"respuesta": "se_cansa", "pide": pide, "dias": DIAS_BLOQUEO,
			"ofreciste": sueldo}

	# Ni acepta ni se ofende: cede parte de la brecha y vuelve a preguntar.
	var brecha: float = pide - sueldo
	var nuevo_pide: float = maxf(pide - brecha * CESION_POR_RONDA, tabla * PISO_DE_CESION)
	# La fraccion es contra el pretendido de TABLA, no contra lo que pedia
	# la ronda pasada: asi sigue valiendo si cambias los años ofrecidos.
	estado["fraccion"] = clampf(nuevo_pide / maxf(tabla, 0.01), PISO_DE_CESION, 1.0)
	equipo.renovaciones[id] = estado

	# Estirada la negociacion, prefiere estabilidad a plata: pide un año
	# mas. Si es veterano eso ademas le baja lo que pide (ver
	# sueldo_pretendido), asi que es la salida barata para el club.
	var anios_pedidos := anios_reales
	if int(estado["ronda"]) >= RONDA_PIDE_ANIOS and anios_reales < ANIOS_MAX:
		anios_pedidos = anios_reales + 1

	return {"respuesta": "contraoferta", "pide": nuevo_pide,
		"anios": anios_pedidos, "ronda": int(estado["ronda"]),
		"pedia": pide, "ofreciste": sueldo}


## Cierra la renovacion con lo acordado. El sueldo sale de Contratos como
## cualquier ficha, pero lo que se cobra es la DIFERENCIA con lo que ya
## cobraba: el club ya venia pagando su sueldo viejo.
static func firmar(equipo: Team, jugador: Dictionary, anios: int, sueldo: float) -> Dictionary:
	var id: int = jugador["id"]
	if not equipo.contratos.has(id):
		return {"exito": false, "motivo": "Ese jugador ya no está en el club."}

	var veredicto := ofrecer(equipo, jugador, anios, sueldo)
	if str(veredicto["respuesta"]) != "acepta":
		return {"exito": false, "motivo": "No acepta ese contrato.", "veredicto": veredicto}

	var diferencia: float = sueldo - float(equipo.sueldos.get(id, 0.0))
	if not Economia.puede_pagar_contrato(equipo, diferencia):
		return Economia.motivo_contrato_corto(equipo, diferencia)

	equipo.caja["contratos"] -= diferencia
	equipo.sueldos[id] = sueldo
	equipo.contratos[id] = clampi(anios, ANIOS_MIN, ANIOS_MAX)
	equipo.renovaciones.erase(id)
	return {"exito": true, "sueldo": sueldo, "anios": equipo.contratos[id],
		"diferencia": diferencia}


## Descuenta los dias de bloqueo. La llama Team.avanzar_dias, en el mismo
## lugar que las lesiones y los informes de los investigadores: el enojo
## se le pasa con el calendario, no con las fechas jugadas.
static func avanzar(equipo: Team, dias: int) -> void:
	for id in equipo.renovaciones.keys():
		var estado: Dictionary = equipo.renovaciones[id]
		if int(estado.get("bloqueo", 0)) <= 0:
			continue
		estado["bloqueo"] = maxi(0, int(estado["bloqueo"]) - dias)
