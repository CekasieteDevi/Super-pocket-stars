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
## Subido de 0.55 con el escalon de elite (ValorJugador.MEDIA_ELITE): un
## crack de media 99 cuesta diez veces lo que un titular bueno, asi que
## comprarlo ES fundirse el presupuesto. Ese es el trato.
const FRACCION_MAXIMA_POR_FICHAJE := 0.85

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


## Dónde está un jugador dentro de un club: {"jugador":Dictionary,
## "origen":"titular"/"banco"/"cantera"} o {} si no está.
##
## Hace falta porque las dos vias de compra del jugador humano miraban
## SOLO vendedor.jugadores, asi que el banco y —lo que mas importa— la
## cantera ajena eran invisibles: la joya que la IA pesca de la academia
## de un club de decima el jugador no la podia ni ver.
static func ubicar(vendedor: Team, jugador_id: int) -> Dictionary:
	for j in vendedor.jugadores:
		if int(j["id"]) == jugador_id:
			return {"jugador": j, "origen": "titular"}
	for j in vendedor.banco:
		if int(j["id"]) == jugador_id:
			return {"jugador": j, "origen": "banco"}
	for j in vendedor.cantera:
		if int(j["id"]) == jugador_id:
			return {"jugador": j, "origen": "cantera"}
	return {}


## §9.3: compra al contado. Es la misma operacion que hace la IA en
## ventana_entre_divisiones —plata contra jugador, sin nadie a cambio— y
## sirve para cualquiera del plantel o de la cantera del vendedor, de la
## division que sea.
##
## `forzar` = pagar la clausula de rescision: precio mas alto pero venta
## obligatoria, sin resistencia.
##
## Reemplaza a las dos vias que tenia el jugador humano hasta el mercado
## abierto: ofertar_por_jugador() (un TRUEQUE, te llevabas al objetivo y
## dabas tu titular mas flojo de ese puesto) y pagar_clausula(). Las dos
## miraban solo vendedor.jugadores y las dos quedaron borradas.
static func comprar_al_contado(comprador: Team, vendedor: Team, jugador_id: int,
		rng: RandomNumberGenerator, forzar: bool = false) -> Dictionary:
	if comprador == vendedor:
		return {"exito": false, "motivo": "Ese jugador ya es tuyo."}
	var donde := ubicar(vendedor, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}
	var jugador: Dictionary = donde["jugador"]

	var valor := ValorJugador.calcular(
		jugador, vendedor.animo.get(jugador_id, 50.0), vendedor.contratos.get(jugador_id, 3))
	var precio: float = vendedor.clausulas.get(jugador_id, valor * Team.FACTOR_CLAUSULA) if forzar else valor

	if comprador.caja["fichajes"] < precio:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes.",
			"precio": precio, "disponible": comprador.caja["fichajes"]}

	if not forzar and rng.randf() < resistencia_venta(vendedor, jugador):
		return {"exito": false, "motivo": "El club no quiere desprenderse de esa pieza con una oferta común.",
			"resistencia": true, "clausula": vendedor.clausulas.get(jugador_id, valor * Team.FACTOR_CLAUSULA)}

	# La cantera no es plantel: sale de la lista y listo, no hay hueco que
	# tapar. Del plantel si, y de eso se encarga Team.perder_jugador.
	if donde["origen"] == "cantera":
		for i in range(vendedor.cantera.size()):
			if int(vendedor.cantera[i]["id"]) == jugador_id:
				vendedor.cantera.remove_at(i)
				break
		vendedor._limpiar_registro(jugador_id)
	elif not vendedor.perder_jugador(jugador_id, rng):
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}

	comprador.caja["fichajes"] -= precio
	vendedor.caja["fichajes"] += precio
	var saliente := comprador.incorporar(jugador, valor)

	return {"exito": true, "jugador": jugador, "posicion": jugador["posicion"],
		"precio": precio, "origen": donde["origen"], "jugador_sale": saliente}


static func _indice_en_posicion(equipo: Team, posicion: String, rng: RandomNumberGenerator) -> int:
	var candidatos := []
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == posicion:
			candidatos.append(i)
	if candidatos.is_empty():
		return -1
	return candidatos[rng.randi() % candidatos.size()]


## §9.3 extendido: mercado entre clubes de TODA la piramide. Cualquiera
## puede comprarle a cualquiera, de la division que sea.
##
## ejecutar_ventana() opera dentro de una sola division y es un TRUEQUE en
## el que el club con el peor jugador de un puesto recibe al mejor: sirve
## para que los planteles se muevan, pero nivela la liga en vez de
## estratificarla, y deja a los clubes grandes tapando bajas con juveniles.
## Esto es lo contrario y es lo que hace que la piramide se sienta una
## piramide: plata contra talento, de arriba hacia abajo.
##
## En la practica termina comprando el de arriba y cobrando el de abajo,
## pero eso sale solo de la caja, que escala con la categoria (ver
## Economia.MULTIPLICADOR_DIVISION): un club de decima PUEDE ofertar por un
## crack de primera, lo que no puede es pagarlo.
##
## Se compra por dos motivos distintos:
##   REFUERZO: alguien que mejora un puesto flojo, hoy.
##   JOYA: un pibe con techo muy por encima de lo que da el club, aunque
##   todavia no rinda. Es el caso del crack que aparece en la cantera de
##   un club de decima — que puede negarse a venderlo, ver
##   resistencia_venta.
static func ventana_entre_divisiones(piramide, rng: RandomNumberGenerator, equipo_protegido: Team = null) -> Array:
	var transferencias := []
	for d in range(piramide.divisiones.size()):
		var compradores: Array = piramide.divisiones[d].equipos.duplicate()
		compradores.shuffle()
		for comprador in compradores:
			if comprador == equipo_protegido or comprador.quebrado:
				continue
			# Cada intento es una gestion distinta (otro puesto, otro club,
			# otra division): que una falle no cierra el mercado del club.
			# Con break, un club tenia UN intento real y no tres.
			for _i in range(INTENTOS_POR_CLUB):
				var t := _intentar_compra(piramide, d, comprador, rng, equipo_protegido)
				if not t.is_empty():
					transferencias.append(t)
	return transferencias


static func _intentar_compra(piramide, division_compradora: int, comprador: Team,
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

	# A que division se mira: CUALQUIERA, mas abajo, mas arriba o la propia.
	# Lo unico que decide si el negocio se puede hacer es la plata y las
	# ganas de vender del otro, no una regla sobre a donde mirar.
	#
	# Casi siempre a una division cercana y cada tanto muy lejos: elevar al
	# cuadrado un numero entre 0 y 1 lo empuja hacia el 0, asi que los
	# pasos chicos son los comunes. Uniforme no sirve —un club de primera
	# gastaba casi todos sus intentos mirando decima, donde no hay nadie
	# que lo mejore— pero tampoco puede mirar siempre al lado, o la joya
	# del fondo no sube nunca y un club chico no le compra jamas un
	# descarte a uno grande.
	var total_div: int = piramide.divisiones.size()
	var paso: int = int(rng.randf() * rng.randf() * float(total_div))
	if rng.randf() < 0.5:
		paso = -paso
	var objetivo_div: int = clampi(division_compradora + paso, 0, total_div - 1)
	var vendedores: Array = piramide.divisiones[objetivo_div].equipos
	var vendedor: Team = vendedores[rng.randi() % vendedores.size()]
	if vendedor == equipo_protegido or vendedor == comprador:
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
		"de": vendedor.nombre, "de_division": objetivo_div + 1,
		"a": comprador.nombre, "a_division": division_compradora + 1,
		"valor": valor, "media": float(objetivo["media"]), "potencial": int(objetivo["potencial"]),
	}


## §9.3 rework: cierra un pase con los terminos que se PACTARON en la
## negociacion (ver core/negociacion.gd), en vez de al valor de tabla.
##
## comprar_al_contado() sigue siendo la via de la IA y de la clausula, que
## no negocian: pagan lo que dice la calculadora. Esta es la del jugador
## humano, donde el precio lo pusiste vos y el sueldo lo acordaste con el
## jugador.
static func ejecutar_pase(comprador: Team, vendedor: Team, jugador_id: int, precio: float,
		sueldo: float, anios: int, rng: RandomNumberGenerator) -> Dictionary:
	var donde := ubicar(vendedor, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}
	if comprador.caja["fichajes"] < precio:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes."}
	var jugador: Dictionary = donde["jugador"]

	if donde["origen"] == "cantera":
		for i in range(vendedor.cantera.size()):
			if int(vendedor.cantera[i]["id"]) == jugador_id:
				vendedor.cantera.remove_at(i)
				break
		vendedor._limpiar_registro(jugador_id)
	elif not vendedor.perder_jugador(jugador_id, rng):
		return {"exito": false, "motivo": "Ese jugador ya no está en ese club."}

	comprador.caja["fichajes"] -= precio
	vendedor.caja["fichajes"] += precio
	var saliente := comprador.incorporar(jugador, precio, anios)
	# incorporar() registra el fichaje con el sueldo de tabla; acá se pisa
	# con el que se acordó, que es el que el jugador acepto.
	comprador.sueldos[jugador_id] = sueldo
	comprador.contratos[jugador_id] = anios

	return {"exito": true, "jugador": jugador, "posicion": jugador["posicion"],
		"precio": precio, "sueldo": sueldo, "anios": anios,
		"origen": donde["origen"], "jugador_sale": saliente}
