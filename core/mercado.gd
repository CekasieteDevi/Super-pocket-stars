class_name Mercado
extends RefCounted

## Mercado de pases — Fase 6 (GDD §9.3), extendido en la fase del plantel
## de 25 (§14) para usar el banco de verdad. Sigue siendo un INTERCAMBIO
## directo entre dos clubes en la misma posición (no la cadena de
## reemplazo completa del GDD, que necesitaría agentes libres y un mercado
## de ofertas más rico) pero ahora, en vez de que el jugador que llega pise
## el puesto titular a la fuerza en ambos lados: el que compra sube al
## entrante como titular directo y manda a su titular saliente al banco; el
## que vende promueve a su suplente de esa posición y el que llega a cambio
## entra al banco. El único que sale del club de verdad es a quien no le
## queda lugar en el banco.
##
## Extendido con resistencia de venta (resistencia_venta): una oferta común
## (ofertar_por_jugador) puede ser rechazada aunque la plata alcance, si el
## club no quiere desprenderse de esa pieza — para forzar la venta sin
## resistencia existe la cláusula de rescisión (pagar_clausula), fijada al
## fichar a cada jugador (Team.FACTOR_CLAUSULA).

const UMBRAL_DIFERENCIA_MEDIA := 8.0

## Hasta que edad un jugador cuenta como "joya" y su club se lo pelea por
## el techo y no por lo que rinde hoy (ver resistencia_venta).
const EDAD_JOYA := 23

## Cuanto tiene que mejorar el puesto un fichaje de otra division para que
## valga la pena. Mas bajo que UMBRAL_DIFERENCIA_MEDIA porque acá no hay
## trueque: el que compra pone plata y no resigna a nadie de arriba.
const MEJORA_MINIMA_ENTRE_DIVISIONES := 4.0

## Que fraccion del presupuesto de fichajes se anima a gastar un club en
## UNA sola compra. Sin esto, el primer club en tocarle el turno se
## fundia el presupuesto entero en un jugador y no fichaba nunca mas.
const FRACCION_MAXIMA_POR_FICHAJE := 0.55

## Cuantas compras intenta cada club por temporada.
const INTENTOS_POR_CLUB := 4
const POSICIONES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]


## equipo_protegido: si se pasa (el club del jugador humano), nunca
## participa de estos intercambios automáticos — el mercado de la IA es
## entre clubes de la IA. Sin esto, el jugador se puede despertar con un
## fichaje que nunca pidió ni vio venir.
static func ejecutar_ventana(liga: Liga, rng: RandomNumberGenerator, equipo_protegido: Team = null) -> Array:
	var transferencias := []
	if liga.equipos.size() < 2:
		return transferencias

	var intentos: int = liga.equipos.size() * 2
	for i in range(intentos):
		var idx_a := rng.randi() % liga.equipos.size()
		var idx_b := rng.randi() % liga.equipos.size()
		if idx_a == idx_b:
			continue
		var club_a: Team = liga.equipos[idx_a]
		var club_b: Team = liga.equipos[idx_b]
		if club_a == equipo_protegido or club_b == equipo_protegido:
			continue

		var posicion: String = POSICIONES[rng.randi() % POSICIONES.size()]
		var indice_a := _indice_en_posicion(club_a, posicion, rng)
		var indice_b := _indice_en_posicion(club_b, posicion, rng)
		if indice_a < 0 or indice_b < 0:
			continue

		var jugador_a: Dictionary = club_a.jugadores[indice_a]
		var jugador_b: Dictionary = club_b.jugadores[indice_b]
		if jugador_a["media"] == jugador_b["media"]:
			continue

		var a_es_mejor: bool = jugador_a["media"] > jugador_b["media"]
		var mejor_club: Team = club_a if a_es_mejor else club_b
		var mejor_jugador: Dictionary = jugador_a if a_es_mejor else jugador_b
		var mejor_indice: int = indice_a if a_es_mejor else indice_b
		var peor_club: Team = club_b if a_es_mejor else club_a
		var peor_jugador: Dictionary = jugador_b if a_es_mejor else jugador_a
		var peor_indice: int = indice_b if a_es_mejor else indice_a

		# §8.6.4: peor_club es el que compra (recibe a mejor_jugador) — un DT
		# Chequera acepta comprar por una mejora bastante más chica, uno
		# Cantera pide mucha más diferencia (prefiere su propia cantera).
		var umbral_compra := UMBRAL_DIFERENCIA_MEDIA * DT.factor_umbral_fichaje(peor_club)
		if mejor_jugador["media"] - peor_jugador["media"] < umbral_compra:
			continue

		var valor_mejor := ValorJugador.calcular(mejor_jugador, mejor_club.animo.get(mejor_jugador["id"], 50.0), mejor_club.contratos.get(mejor_jugador["id"], 1))
		var valor_peor := ValorJugador.calcular(peor_jugador, peor_club.animo.get(peor_jugador["id"], 50.0), peor_club.contratos.get(peor_jugador["id"], 1))
		var diferencia: float = max(0.0, valor_mejor - valor_peor)

		if peor_club.caja["fichajes"] < diferencia:
			continue

		peor_club.caja["fichajes"] -= diferencia
		mejor_club.caja["fichajes"] += diferencia

		# El que compra (peor_club) pisa el puesto titular directo con el
		# que llega — no hay que "banquear" a peor_jugador en peor_club
		# porque se va entero al otro club (ver vender_titular abajo), no
		# se queda de suplente en su club de origen.
		peor_club.jugadores[peor_indice] = mejor_jugador
		peor_club.recalcular_capitan()
		mejor_club.vender_titular(mejor_indice, peor_jugador)

		peor_club._registrar_fichaje(mejor_jugador, valor_mejor)
		mejor_club._registrar_fichaje(peor_jugador, valor_peor)
		peor_club._limpiar_registro(peor_jugador["id"])  # peor_jugador ya no es de este club
		mejor_club._limpiar_registro(mejor_jugador["id"])  # mejor_jugador ya no es de este club

		transferencias.append({
			"jugador_id": mejor_jugador["id"], "posicion": posicion,
			"de": mejor_club.nombre, "a": peor_club.nombre, "valor": valor_mejor,
		})

	return transferencias


## Oferta del jugador humano por un jugador puntual de otro club — a
## diferencia de ejecutar_ventana() (automático, entre clubes de la IA),
## esto lo dispara la UI cuando el usuario elige a alguien. El que sale a
## cambio es siempre tu titular más débil en esa misma posición (pasa a tu
## banco, no se libera), y solo se permite si el objetivo es realmente
## mejor — si no, no tiene sentido la oferta.
## §9.3 extendido: cuánto le cuesta a un club de la IA desprenderse de un
## jugador con una oferta común (no una cláusula) — 0.0 lo vende sin
## problema, cerca de 1.0 casi nunca acepta. Más resistencia si es el
## capitán, si es claramente su mejor jugador en esa posición (nadie
## vende a su figura sin pelear), o si el club tiene buena reputación
## (no necesita la plata tanto como uno de reputación baja).
static func resistencia_venta(vendedor: Team, jugador: Dictionary) -> float:
	var resistencia := 0.0
	if jugador["id"] == vendedor.capitan_id:
		resistencia += 0.25

	# Contra todo el plantel (titulares+banco) en esa posición, no solo el
	# titular: posiciones como ARQ o DC tienen un solo titular, así que
	# comparar solo contra "el resto de titulares" nunca encontraría a
	# nadie con quien comparar.
	var media_resto := 0.0
	var cuenta := 0
	for j in vendedor.todos_los_jugadores():
		if j["posicion"] == jugador["posicion"] and j["id"] != jugador["id"]:
			media_resto += j["media"]
			cuenta += 1
	if cuenta > 0 and jugador["media"] - (media_resto / cuenta) >= 8.0:
		resistencia += 0.3

	# La joya de la cantera. Un club chico que saca un fenomeno puede
	# preferir quedarselo y jugarse el ascenso con el, en vez de cobrar:
	# cuanto mas techo tiene el pibe respecto del nivel del club, mas se
	# lo pelea. Sin esto, cada crack que aparecia abajo subia de division
	# la misma temporada, siempre.
	var sobra_techo: float = float(jugador["potencial"]) - float(vendedor.nivel_potencial())
	if sobra_techo > 0.0 and int(jugador["edad"]) <= EDAD_JOYA:
		resistencia += clamp(sobra_techo / 40.0, 0.0, 1.0) * 0.35

	resistencia += clamp(vendedor.reputacion / 100.0, 0.0, 1.0) * 0.3
	resistencia += DT.ajuste_resistencia_venta(vendedor)  # §8.6.4: Chequera vende mas facil, Cantera protege mas
	return clamp(resistencia, 0.0, 0.85)


static func ofertar_por_jugador(comprador: Team, vendedor: Team, jugador_objetivo_id: int, rng: RandomNumberGenerator) -> Dictionary:
	var indice_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["id"] == jugador_objetivo_id:
			indice_objetivo = i
			break
	if indice_objetivo < 0:
		return {"exito": false, "motivo": "Ese jugador ya no juega en ese club."}

	var jugador_objetivo: Dictionary = vendedor.jugadores[indice_objetivo]
	var posicion: String = jugador_objetivo["posicion"]

	var indice_saliente := -1
	for i in range(comprador.jugadores.size()):
		if comprador.jugadores[i]["posicion"] == posicion:
			if indice_saliente == -1 or comprador.jugadores[i]["media"] < comprador.jugadores[indice_saliente]["media"]:
				indice_saliente = i
	if indice_saliente < 0:
		return {"exito": false, "motivo": "No tenés ningún jugador en esa posición para dar de cambio."}

	var jugador_saliente: Dictionary = comprador.jugadores[indice_saliente]
	if jugador_objetivo["media"] <= jugador_saliente["media"]:
		return {"exito": false, "motivo": "Tu jugador actual en esa posición ya es igual o mejor."}

	var valor_objetivo := ValorJugador.calcular(jugador_objetivo, vendedor.animo.get(jugador_objetivo["id"], 50.0), vendedor.contratos.get(jugador_objetivo["id"], 1))
	var valor_saliente := ValorJugador.calcular(jugador_saliente, comprador.animo.get(jugador_saliente["id"], 50.0), comprador.contratos.get(jugador_saliente["id"], 1))
	var diferencia: float = max(0.0, valor_objetivo - valor_saliente)

	if comprador.caja["fichajes"] < diferencia:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes.", "diferencia": diferencia, "disponible": comprador.caja["fichajes"]}

	var resistencia := resistencia_venta(vendedor, jugador_objetivo)
	if rng.randf() < resistencia:
		return {
			"exito": false, "motivo": "El club no quiere desprenderse de esa pieza con una oferta común.",
			"resistencia": true, "clausula": vendedor.clausulas.get(jugador_objetivo_id, 0.0),
		}

	comprador.caja["fichajes"] -= diferencia
	vendedor.caja["fichajes"] += diferencia

	# El comprador pisa el puesto titular directo — jugador_saliente se va
	# entero al club vendedor (ver vender_titular), no se banquea en el
	# suyo propio.
	comprador.jugadores[indice_saliente] = jugador_objetivo
	comprador.recalcular_capitan()
	vendedor.vender_titular(indice_objetivo, jugador_saliente)

	comprador._registrar_fichaje(jugador_objetivo, valor_objetivo)
	vendedor._registrar_fichaje(jugador_saliente, valor_saliente)
	comprador._limpiar_registro(jugador_saliente["id"])  # jugador_saliente ya no es de este club
	vendedor._limpiar_registro(jugador_objetivo["id"])  # jugador_objetivo ya no es de este club

	return {
		"exito": true, "jugador_entra": jugador_objetivo, "jugador_sale": jugador_saliente,
		"diferencia": diferencia, "posicion": posicion,
	}


## Paga la cláusula de rescisión completa: venta OBLIGATORIA, sin
## resistencia_venta y sin comparar si el objetivo es "mejor" que tu
## titular actual (pagar de más por alguien que no te mejora es una
## decisión tuya, no algo que el sistema tenga que impedir). Todo el
## monto sale de Fichajes — no hay "diferencia" con nadie porque no hay
## intercambio de jugadores de por medio, solo la cláusula en efectivo.
static func pagar_clausula(comprador: Team, vendedor: Team, jugador_objetivo_id: int) -> Dictionary:
	var indice_objetivo := -1
	for i in range(vendedor.jugadores.size()):
		if vendedor.jugadores[i]["id"] == jugador_objetivo_id:
			indice_objetivo = i
			break
	if indice_objetivo < 0:
		return {"exito": false, "motivo": "Ese jugador ya no juega en ese club."}

	var jugador_objetivo: Dictionary = vendedor.jugadores[indice_objetivo]
	var posicion: String = jugador_objetivo["posicion"]
	var clausula: float = vendedor.clausulas.get(
		jugador_objetivo_id,
		ValorJugador.calcular(jugador_objetivo, vendedor.animo.get(jugador_objetivo_id, 50.0), vendedor.contratos.get(jugador_objetivo_id, 1)) * Team.FACTOR_CLAUSULA
	)

	if comprador.caja["fichajes"] < clausula:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes para pagar la cláusula.", "clausula": clausula, "disponible": comprador.caja["fichajes"]}

	var indice_saliente := -1
	for i in range(comprador.jugadores.size()):
		if comprador.jugadores[i]["posicion"] == posicion:
			if indice_saliente == -1 or comprador.jugadores[i]["media"] < comprador.jugadores[indice_saliente]["media"]:
				indice_saliente = i
	if indice_saliente < 0:
		return {"exito": false, "motivo": "No tenés ningún jugador en esa posición para reemplazar."}

	var jugador_saliente: Dictionary = comprador.jugadores[indice_saliente]
	var valor_saliente := ValorJugador.calcular(jugador_saliente, comprador.animo.get(jugador_saliente["id"], 50.0), comprador.contratos.get(jugador_saliente["id"], 1))

	comprador.caja["fichajes"] -= clausula
	vendedor.caja["fichajes"] += clausula

	comprador.jugadores[indice_saliente] = jugador_objetivo
	comprador.recalcular_capitan()
	vendedor.vender_titular(indice_objetivo, jugador_saliente)

	comprador._registrar_fichaje(jugador_objetivo, clausula / Team.FACTOR_CLAUSULA)
	vendedor._registrar_fichaje(jugador_saliente, valor_saliente)
	comprador._limpiar_registro(jugador_saliente["id"])
	vendedor._limpiar_registro(jugador_objetivo_id)

	return {
		"exito": true, "jugador_entra": jugador_objetivo, "jugador_sale": jugador_saliente,
		"clausula": clausula, "posicion": posicion,
	}


static func _indice_en_posicion(equipo: Team, posicion: String, rng: RandomNumberGenerator) -> int:
	var candidatos := []
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == posicion:
			candidatos.append(i)
	if candidatos.is_empty():
		return -1
	return candidatos[rng.randi() % candidatos.size()]


## §9.3 extendido: mercado ENTRE divisiones. El de arriba compra, el de
## abajo cobra.
##
## ejecutar_ventana() opera dentro de una sola division y es un TRUEQUE en
## el que el club con el peor jugador de un puesto recibe al mejor: sirve
## para que los planteles se muevan, pero nivela la liga en vez de
## estratificarla, y deja a los clubes grandes tapando bajas con juveniles.
## Esto es lo contrario y es lo que hace que la piramide se sienta una
## piramide: plata contra talento, de arriba hacia abajo.
##
## Un club solo mira DIVISIONES MAS BAJAS que la suya. Lo que lo limita no
## es una regla sino la caja, y la caja ahora escala con la categoria (ver
## Economia.MULTIPLICADOR_DIVISION), asi que los de arriba compran mas y
## mejor sin que haya que decirselo.
##
## Se compra por dos motivos distintos:
##   REFUERZO: alguien que mejora un puesto flojo, hoy.
##   JOYA: un pibe con techo muy por encima de lo que da el club, aunque
##   todavia no rinda. Es el caso del crack que aparece en la cantera de
##   un club de decima — que puede negarse a venderlo, ver
##   resistencia_venta.
static func ventana_entre_divisiones(piramide, rng: RandomNumberGenerator, equipo_protegido: Team = null) -> Array:
	var transferencias := []
	for d in range(piramide.divisiones.size() - 1):
		var compradores: Array = piramide.divisiones[d].equipos.duplicate()
		compradores.shuffle()
		for comprador in compradores:
			if comprador == equipo_protegido or comprador.quebrado:
				continue
			# Cada intento es una gestion distinta (otro puesto, otro club,
			# otra division): que una falle no cierra el mercado del club.
			# Con break, un club tenia UN intento real y no tres.
			for _i in range(INTENTOS_POR_CLUB):
				var t := _intentar_compra_abajo(piramide, d, comprador, rng, equipo_protegido)
				if not t.is_empty():
					transferencias.append(t)
	return transferencias


static func _intentar_compra_abajo(piramide, division_compradora: int, comprador: Team,
		rng: RandomNumberGenerator, equipo_protegido: Team) -> Dictionary:
	var tope: float = comprador.caja["fichajes"] * FRACCION_MAXIMA_POR_FICHAJE
	if tope <= 0.0:
		return {}

	var posicion: String = POSICIONES[rng.randi() % POSICIONES.size()]
	var idx_flojo := -1
	for i in range(comprador.jugadores.size()):
		if comprador.jugadores[i]["posicion"] == posicion and (idx_flojo == -1 or comprador.jugadores[i]["media"] < comprador.jugadores[idx_flojo]["media"]):
			idx_flojo = i
	if idx_flojo == -1:
		return {}
	var a_mejorar: Dictionary = comprador.jugadores[idx_flojo]
	var nivel_comprador := comprador.nivel_potencial()

	# A que division se mira. Casi siempre a la de justo abajo y cada tanto
	# mucho mas hondo: elevar al cuadrado un numero entre 0 y 1 lo empuja
	# hacia el 0, asi que los pasos chicos son los comunes.
	#
	# Uniforme entre todas las de abajo no sirve: un club de primera
	# gastaba casi todos sus intentos mirando decima, donde no hay nadie
	# que lo mejore, y terminaba fichando menos que un club de novena.
	# Pero tampoco puede ser siempre la de al lado, o la joya del fondo no
	# sube nunca.
	var saltos: int = piramide.divisiones.size() - division_compradora - 1
	var paso: int = 1 + int(rng.randf() * rng.randf() * float(saltos))
	var abajo: int = division_compradora + mini(paso, saltos)
	var vendedores: Array = piramide.divisiones[abajo].equipos
	var vendedor: Team = vendedores[rng.randi() % vendedores.size()]
	if vendedor == equipo_protegido:
		return {}

	var mejor_id := -1
	var mejor_puntaje := 0.0
	var es_joya := false
	for j in vendedor.todos_los_jugadores() + vendedor.cantera:
		if j["posicion"] != posicion:
			continue
		var refuerzo: float = float(j["media"]) - float(a_mejorar["media"])
		var techo: float = float(j["potencial"]) - float(nivel_comprador)
		var joya: bool = int(j["edad"]) <= EDAD_JOYA and techo > 0.0
		var puntaje: float = refuerzo if refuerzo >= MEJORA_MINIMA_ENTRE_DIVISIONES else 0.0
		if joya:
			puntaje = maxf(puntaje, techo)
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_id = int(j["id"])
			es_joya = joya and refuerzo < MEJORA_MINIMA_ENTRE_DIVISIONES
	if mejor_id == -1:
		return {}

	var objetivo := {}
	for j in vendedor.todos_los_jugadores() + vendedor.cantera:
		if int(j["id"]) == mejor_id:
			objetivo = j
			break

	var valor := ValorJugador.calcular(objetivo, vendedor.animo.get(mejor_id, 50.0), vendedor.contratos.get(mejor_id, 3))
	if valor > tope:
		return {}
	if rng.randf() < resistencia_venta(vendedor, objetivo):
		return {}

	var en_cantera := false
	for j in vendedor.cantera:
		if int(j["id"]) == mejor_id:
			en_cantera = true
			break
	if en_cantera:
		var idx := -1
		for i in range(vendedor.cantera.size()):
			if int(vendedor.cantera[i]["id"]) == mejor_id:
				idx = i
				break
		vendedor.cantera.remove_at(idx)
		vendedor._limpiar_registro(mejor_id)
	elif not vendedor.perder_jugador(mejor_id, rng):
		return {}

	comprador.caja["fichajes"] -= valor
	vendedor.caja["fichajes"] += valor
	comprador.incorporar(objetivo, valor)

	return {
		"jugador_id": mejor_id, "posicion": posicion, "joya": es_joya,
		"de": vendedor.nombre, "de_division": abajo + 1,
		"a": comprador.nombre, "a_division": division_compradora + 1,
		"valor": valor, "media": float(objetivo["media"]), "potencial": int(objetivo["potencial"]),
	}
