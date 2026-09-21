class_name Cesiones
extends RefCounted

## Lista de cedibles: vos decidis a quien pueden pedirte a prestamo.
##
## Es la contracara de core/traspasos.gd. Aquella lista filtra las ofertas
## de COMPRA; esta filtra los pedidos de CESION. Un jugador puede estar
## cerrado a la venta y abierto a la cesion al mismo tiempo, que es
## justamente el caso del pibe que no queres vender pero necesitas que
## juegue en algun lado.
##
## - NO_DISPONIBLE: no llega ningun pedido por el. Es el DEFAULT, al reves
##   que en Traspasos: cedes al que vos elegis, no al que se les ocurra a
##   ellos.
## - DISPONIBLE: llegan pedidos de cesion.
##
## No hay "venta rapida" acá: una cesion ya es temporal, y un estado que
## regale los terminos no tiene contracara real — el jugador vuelve igual.
##
## El estado vive en el club DUEÑO (Team.cesiones) y se borra solo cuando
## el jugador se va (Team._limpiar_registro).

const DISPONIBLE := "disponible"
const NO_DISPONIBLE := "no_disponible"

## El orden del boton que cicla en la solapa Cesion.
const CICLO := [NO_DISPONIBLE, DISPONIBLE]

const ETIQUETAS := {
	NO_DISPONIBLE: "No cedible",
	DISPONIBLE: "Cedible",
}

const AYUDAS := {
	NO_DISPONIBLE: "No te llega ningun pedido de cesion por el.",
	DISPONIBLE: "Otros clubes te lo pueden pedir a prestamo. Los terminos se negocian.",
}

## Cada cuantos dias, en promedio, algun club se fija en tu lista de
## cedibles. El mismo ritmo que las ofertas de compra: la lista la abris
## vos a proposito, asi que abrirla y no recibir nada seria una mecanica
## muerta. Estaba en 6 con UN club al azar que casi nunca servia: medido
## con tests/_diag_pedidos_cesion.gd, con banco y reservas cedibles
## llegaban 0,8 pedidos por ventana en tercera y 1,5 en septima.
const DIAS_ENTRE_PEDIDOS := Ofertas.DIAS_ENTRE_INTERESES

## Cuanto ofrecen de fee, como fraccion del valor del jugador. El piso es
## el 10% fijo que cobraba la cesion vieja (Prestamos.FEE_PORCENTAJE);
## arrancan por debajo porque para eso existe la contraoferta.
const FEE_INICIAL_MIN := 0.04
const FEE_INICIAL_MAX := 0.11

## Hasta cuanto de fee llegan a pagar si les apretas. Mas que esto y
## prefieren buscar a otro: por ese precio compran media ficha.
const FEE_TOPE := 0.20

## Que parte del sueldo se ofrecen a cubrir de arranque. Nunca menos del
## minimo que acepta el dueño (Prestamos.PORCENTAJE_SUELDO_MINIMO), asi
## que el pedido siempre nace negociable.
const SUELDO_INICIAL_MIN := 0.5
const SUELDO_INICIAL_MAX := 0.9

## Cada cuantos pedidos viene uno con opcion de compra.
const PROBABILIDAD_OPCION := 0.35

## Cuanto ofrecen por la opcion, contra lo que el DUEÑO estima que va a
## valer al vencer (Prestamos.valor_futuro_estimado). Tiran abajo del
## margen que pide el dueño (MARGEN_OPCION = 1.15) para que haya algo que
## discutir.
const OPCION_INICIAL_MIN := 0.85
const OPCION_INICIAL_MAX := 1.20

## Hasta cuanto suben la opcion si se la peleas.
const OPCION_TOPE := 1.45

## Cuanto plus le llegan a poner al jugador por encima de lo que cobra,
## como fraccion de su sueldo. Es la palanca para que el jugador diga que
## si cuando baja de categoria (ver Prestamos.ceder).
const PLUS_TOPE := 0.60

## Cuanto mejor que el plantel que lo pide tiene que ser el jugador para
## que lo pidan. Un club no pide prestado a alguien peor que lo que ya
## tiene.
const VENTAJA_MINIMA := 2.0

## Que tanto mas abajo miran en las cesiones entre clubes de la IA. Un
## club pide prestado a uno de arriba, no al reves: el sesgo de division va
## hacia las categorias inferiores. Los pedidos que te llegan a VOS no usan
## este tope (ver generar_pedido).
const DIVISIONES_ABAJO_MAX := 3


static func estado(equipo, id: int) -> String:
	var e := str(equipo.cesiones.get(id, NO_DISPONIBLE))
	return e if CICLO.has(e) else NO_DISPONIBLE


## No guarda el default: el dict solo lleva a los que abriste.
static func fijar(equipo, id: int, nuevo: String) -> void:
	if not CICLO.has(nuevo) or nuevo == NO_DISPONIBLE:
		equipo.cesiones.erase(id)
		return
	equipo.cesiones[id] = nuevo


static func siguiente(actual: String) -> String:
	var i: int = CICLO.find(actual)
	return str(CICLO[(i + 1) % CICLO.size()]) if i >= 0 else DISPONIBLE


static func acepta_pedidos(equipo, id: int) -> bool:
	return estado(equipo, id) == DISPONIBLE


## Los terminos de un pedido, en una linea, para la lista y el historial.
static func resumen(o: Dictionary) -> String:
	var t := "%s, cubren %d%% del sueldo, fee %s" % [
		Prestamos.ETIQUETAS_DURACION.get(str(o.get("duracion", "una")), "1 temporada"),
		int(round(float(o.get("porcentaje_sueldo", 1.0)) * 100.0)),
		Economia.formato_dinero(float(o.get("monto", 0.0)))]
	if float(o.get("opcion_compra", 0.0)) > 0.0:
		t += ", opcion de compra %s" % Economia.formato_dinero(float(o["opcion_compra"]))
	if float(o.get("plus_sueldo", 0.0)) > 0.0:
		t += ", le ponen %s de plus" % Economia.formato_dinero(float(o["plus_sueldo"]))
	return t


## Los topes de ESTE club para ESTE jugador. Es lo que aguanta si le
## contraofertas: mas que esto y se levanta de la mesa.
##
## Salen todos del valor del jugador y de la caja del que pide, asi que un
## club de decima no puede fingir que te paga como uno de primera.
static func topes(pide: Team, dueno: Team, jugador: Dictionary, temporadas: float) -> Dictionary:
	var id := int(jugador["id"])
	var valor := ValorJugador.calcular(
		jugador, dueno.animo.get(id, 50.0), dueno.contratos.get(id, 3))
	var sueldo := Prestamos.sueldo_de_referencia(dueno, jugador)
	return {
		"fee": minf(valor * FEE_TOPE, float(pide.caja.get("fichajes", 0.0))),
		"porcentaje_sueldo": 1.0,
		"opcion_compra": Prestamos.valor_futuro_estimado(jugador, temporadas) * OPCION_TOPE,
		"plus_sueldo": sueldo * PLUS_TOPE,
		"valor": valor,
		"sueldo": sueldo,
	}


## ¿El club que pide acepta los terminos que le contraofertamos?
##
## Devuelve {acepta, mejor} — `mejor` son los terminos que SI firmaria,
## para poder contraofertar en vez de solo decir que no. La plata que no
## tiene en Contratos es un no duro: no se puede contraofertar con una
## caja que no existe.
static func evaluar_contraoferta(pide: Team, dueno: Team, jugador: Dictionary,
		terminos: Dictionary) -> Dictionary:
	var temporadas: float = float(Prestamos.DURACIONES.get(
		str(terminos.get("duracion", "una")), 1.0))
	var t := topes(pide, dueno, jugador, temporadas)

	var fee: float = float(terminos.get("monto", 0.0))
	var pct: float = float(terminos.get("porcentaje_sueldo", 1.0))
	var opcion: float = float(terminos.get("opcion_compra", 0.0))
	var plus: float = float(terminos.get("plus_sueldo", 0.0))

	var mejor := {
		"monto": minf(fee, float(t["fee"])),
		"porcentaje_sueldo": minf(pct, float(t["porcentaje_sueldo"])),
		"opcion_compra": 0.0 if opcion <= 0.0 else minf(opcion, float(t["opcion_compra"])),
		"plus_sueldo": minf(plus, float(t["plus_sueldo"])),
		"duracion": str(terminos.get("duracion", "una")),
	}

	# El sueldo que le queda pagando: su parte mas el plus. Si no le entra
	# en Contratos, baja la parte hasta donde le entre — y si ni asi llega
	# al minimo que acepta el dueño, la cesion no existe.
	var pago: float = float(t["sueldo"]) * float(mejor["porcentaje_sueldo"]) + float(mejor["plus_sueldo"])
	var disponible: float = float(pide.caja.get("contratos", 0.0))
	if pago > disponible and float(t["sueldo"]) > 0.0:
		var margen: float = maxf(0.0, disponible - float(mejor["plus_sueldo"]))
		mejor["porcentaje_sueldo"] = clampf(margen / float(t["sueldo"]), 0.0, 1.0)
		if float(mejor["porcentaje_sueldo"]) < Prestamos.PORCENTAJE_SUELDO_MINIMO:
			return {"acepta": false, "mejor": {}, "sin_caja": true}

	var acepta: bool = (
		is_equal_approx(float(mejor["monto"]), fee) or float(mejor["monto"]) >= fee) and \
		float(mejor["porcentaje_sueldo"]) >= pct and \
		float(mejor["opcion_compra"]) >= opcion and \
		float(mejor["plus_sueldo"]) >= plus
	return {"acepta": acepta, "mejor": mejor, "sin_caja": false}


## Un club viene a pedirte prestado a alguien de tu lista de cedibles.
##
## Mira solo a los que marcaste DISPONIBLE. Recorre los clubes de tu
## division y de todas las de abajo, y junta los pares
## club-jugador donde el jugador mejora al club. Sortea con peso por esa
## mejora y arma el pedido tirando de todos los numeros para su lado. Si
## el par sorteado no cierra (no le entra en la caja, el jugador no iria),
## prueba con otro. Devuelve la oferta nueva o {} si no vino nadie.
##
## Antes miraba UN club al azar y se rendia si no servia: el que de verdad
## lo necesitaba casi nunca salia sorteado.
static func generar_pedido(equipo: Team, piramide, rng: RandomNumberGenerator,
		dias: int, division_propia: int) -> Dictionary:
	if rng.randf() > float(dias) / DIAS_ENTRE_PEDIDOS:
		return {}

	var candidatos := []
	for j in equipo.todos_los_jugadores():
		var id := int(j["id"])
		if not acepta_pedidos(equipo, id):
			continue
		# Al que ya cediste no te lo pueden volver a pedir: no esta.
		if equipo.prestados_afuera.has(id):
			continue
		var ocupado := false
		for o in equipo.ofertas:
			if int(o["jugador_id"]) == id and Ofertas.abierta(o):
				ocupado = true
				break
		if not ocupado:
			candidatos.append(j)
	if candidatos.is_empty():
		return {}

	# Piden de tu division para abajo: el que pide prestado es el que no
	# puede comprar, y ese esta abajo. Sin tope de profundidad: con el tope
	# de DIVISIONES_ABAJO_MAX, un club de 3a en la temporada 13 con el
	# banco cedible (medias 43-58) recibia 0 pedidos en 90 dias, porque de
	# 3a a 6a no hay club con media tan baja. El que lo necesita esta en 9a.
	var pares := []
	for d in range(division_propia, piramide.divisiones.size()):
		for pide in piramide.divisiones[d].equipos:
			if pide == equipo or pide.quebrado:
				continue
			var media_pide: float = pide.media_equipo()
			for j in candidatos:
				# Nadie pide prestado a alguien peor que lo que ya tiene.
				var ventaja: float = float(j["media"]) - media_pide
				if ventaja >= VENTAJA_MINIMA:
					pares.append({"pide": pide, "division": d, "jugador": j, "peso": ventaja})

	while not pares.is_empty():
		var suma := 0.0
		for par in pares:
			suma += float(par["peso"])
		var tiro := rng.randf() * suma
		var i := 0
		while i < pares.size() - 1:
			tiro -= float(pares[i]["peso"])
			if tiro <= 0.0:
				break
			i += 1
		var par: Dictionary = pares[i]
		pares.remove_at(i)
		var oferta := _armar_pedido(equipo, par["pide"], int(par["division"]), par["jugador"],
			rng, division_propia)
		if not oferta.is_empty():
			return oferta
	return {}


## Cada cuantos dias de mercado, en promedio, un club de la IA sale a ceder
## a alguien. Con ~90 dias de mercado por año son dos intentos por club.
const DIAS_ENTRE_CESIONES_IA := 45.0

## Cuantos cedidos a la vez tiene como mucho un club de la IA. Sin tope,
## un grande vaciaba las reservas en una ventana.
const CEDIDOS_IA_MAX := 3

## Hasta que edad cede la IA. Se cede al pibe para que juegue y crezca
## (el que no juega crece al 25%, ver core/progresion.gd); al veterano de
## reserva no hay nada que hacerle crecer.
const EDAD_MAX_CEDIBLE_IA := 23


## Cesiones entre clubes de la IA. Corre con el mercado abierto, igual que
## los pedidos que te llegan a vos, y con el mismo criterio: el que pide
## esta en la division del dueño o hasta DIVISIONES_ABAJO_MAX mas abajo, y
## el cedido lo mejora por VENTAJA_MINIMA. La IA cede solo reservas y
## cantera jovenes, sin tocar el once (Prestamos.evaluar_pedido lo prohibe).
##
## Antes no existia: los clubes de la IA no se prestaban nunca entre ellos,
## y un juvenil sin lugar en un grande se quedaba sin jugar ni crecer.
##
## `protegido` es tu club: no cede ni recibe por aca, eso lo decidis vos.
## Devuelve las cesiones hechas: {dueno, pide, jugador, fee, duracion}.
static func ronda_ia(piramide, rng: RandomNumberGenerator, dias: int,
		protegido: Team, momento: float) -> Array:
	var hechas := []
	for d in range(piramide.divisiones.size()):
		for dueno in piramide.divisiones[d].equipos:
			if dueno == protegido or dueno.quebrado:
				continue
			if rng.randf() > float(dias) / DIAS_ENTRE_CESIONES_IA:
				continue
			if dueno.prestados_afuera.size() >= CEDIDOS_IA_MAX:
				continue
			var hecha := _ceder_ia(dueno, d, piramide, rng, protegido, momento)
			if not hecha.is_empty():
				hechas.append(hecha)
	return hechas


static func _ceder_ia(dueno: Team, division_dueno: int, piramide, rng: RandomNumberGenerator,
		protegido: Team, momento: float) -> Dictionary:
	# El plantel de la IA es el once y siete suplentes, sin reservas ni
	# cantera: mirando solo reservas no habia a quien ceder. Cede suplentes
	# mientras le queden los que necesita para presentarse con margen para
	# un lesionado (Liga.MINIMO_DISPONIBLES).
	var plantel: Array = dueno.todos_los_jugadores()
	var sobran: bool = plantel.size() - 1 >= Liga.MINIMO_DISPONIBLES + 1
	var arqueros := 0
	for j in plantel:
		if str(j["posicion"]) == "ARQ":
			arqueros += 1
	var candidatos := []
	for j in (dueno.banco + dueno.reservas if sobran else []) + dueno.cantera:
		var id := int(j["id"])
		# Al que tiene prestado no lo puede ceder: no es suyo.
		if dueno.prestados_propios.has(id) or int(j.get("edad", 99)) > EDAD_MAX_CEDIBLE_IA:
			continue
		# El arquero suplente no se va si es el unico.
		if str(j["posicion"]) == "ARQ" and arqueros <= 2 and not dueno.cantera.has(j):
			continue
		candidatos.append(j)
	if candidatos.is_empty():
		return {}

	var pares := []
	var ultima: int = mini(division_dueno + DIVISIONES_ABAJO_MAX, piramide.divisiones.size() - 1)
	for d in range(division_dueno, ultima + 1):
		for pide in piramide.divisiones[d].equipos:
			if pide == dueno or pide == protegido or pide.quebrado:
				continue
			if pide.todos_los_jugadores().size() >= Team.PLANTEL_MAXIMO:
				continue
			var media_pide: float = pide.media_equipo()
			for j in candidatos:
				var ventaja: float = float(j["media"]) - media_pide
				if ventaja >= VENTAJA_MINIMA:
					pares.append({"pide": pide, "division": d, "jugador": j, "peso": ventaja})

	while not pares.is_empty():
		var suma := 0.0
		for par in pares:
			suma += float(par["peso"])
		var tiro := rng.randf() * suma
		var i := 0
		while i < pares.size() - 1:
			tiro -= float(pares[i]["peso"])
			if tiro <= 0.0:
				break
			i += 1
		var par: Dictionary = pares[i]
		pares.remove_at(i)
		var pide: Team = par["pide"]
		var jugador: Dictionary = par["jugador"]
		var t := _terminos(dueno, pide, int(par["division"]), jugador, rng, division_dueno)
		if t.is_empty():
			continue
		var temporadas: float = float(Prestamos.DURACIONES[str(t["duracion"])])
		# Sin opcion de compra: es una negociacion aparte que entre dos
		# clubes de la IA no tiene quien la discuta.
		var r := Prestamos.ceder(dueno, pide, int(jugador["id"]), momento, temporadas,
			float(t["porcentaje_sueldo"]), 0.0, float(t["plus_sueldo"]), float(t["fee"]))
		if bool(r["exito"]):
			return {"dueno": dueno, "pide": pide, "jugador": jugador, "fee": float(r["fee"]),
				"duracion": str(t["duracion"])}
	return {}


## Los terminos iniciales del pedido de `pide` por `jugador`, o {} si ese
## club no puede pedirlo.
static func _armar_pedido(equipo: Team, pide: Team, d: int, jugador: Dictionary,
		rng: RandomNumberGenerator, division_propia: int) -> Dictionary:
	var t := _terminos(equipo, pide, d, jugador, rng, division_propia)
	if t.is_empty():
		return {}
	var oferta := Ofertas.nueva(equipo.siguiente_id_oferta, pide.nombre, jugador, float(t["fee"]), true, rng)
	equipo.siguiente_id_oferta += 1
	oferta["tipo"] = "cesion"
	oferta["duracion"] = t["duracion"]
	oferta["porcentaje_sueldo"] = t["porcentaje_sueldo"]
	oferta["opcion_compra"] = t["opcion_compra"]
	oferta["plus_sueldo"] = t["plus_sueldo"]
	oferta["log"].append("%s pide a %s a prestamo: %s" % [
		pide.nombre, oferta["jugador"], resumen(oferta)])
	equipo.ofertas.append(oferta)
	return oferta


## Lo que `pide` ofrece de arranque por `jugador` de `dueno`, o {} si no le
## alcanza la caja o el jugador no iria ni con el plus. Es el mismo criterio
## para el pedido que te llega a vos y para la cesion entre clubes de la IA
## (ronda_ia). `division_propia` es la division del dueño y `d` la del que pide.
static func _terminos(equipo: Team, pide: Team, d: int, jugador: Dictionary,
		rng: RandomNumberGenerator, division_propia: int) -> Dictionary:
	var id_j := int(jugador["id"])
	var duracion: String = ["medio", "una", "una", "dos"][rng.randi() % 4]
	var temporadas: float = float(Prestamos.DURACIONES[duracion])
	var t := topes(pide, equipo, jugador, temporadas)

	var fee: float = float(t["valor"]) * rng.randf_range(FEE_INICIAL_MIN, FEE_INICIAL_MAX)
	if float(pide.caja.get("fichajes", 0.0)) < fee:
		return {}
	var pct: float = rng.randf_range(SUELDO_INICIAL_MIN, SUELDO_INICIAL_MAX)
	# Si ni cubriendo la parte que ofrece le entra en Contratos, no puede
	# pedirlo: seria un pedido que nace muerto.
	if float(t["sueldo"]) * pct > float(pide.caja.get("contratos", 0.0)):
		return {}
	var opcion := 0.0
	if rng.randf() < PROBABILIDAD_OPCION:
		opcion = Prestamos.valor_futuro_estimado(jugador, temporadas) * \
			rng.randf_range(OPCION_INICIAL_MIN, OPCION_INICIAL_MAX)

	# El que pide ya viene con el plus puesto si el jugador no querria ir.
	# Sin esto la mecanica nacia muerta: el que pide siempre esta MAS ABAJO
	# en la piramide, o sea que el jugador siempre baja de categoria, y el
	# reparto del sueldo es plata entre clubes que a el no le mueve nada
	# (ver Prestamos.ceder). Todos los pedidos terminaban en SIN_ACUERDO.
	var plus := 0.0
	if d != division_propia:
		var detalle := Negociacion.interes_jugador(
			jugador, equipo.animo.get(id_j, 50.0), float(t["sueldo"]), float(t["sueldo"]),
			division_propia, Prestamos.division_percibida(equipo, id_j, division_propia, d))
		if not detalle["acepta"]:
			plus = Negociacion.plus_para_convencer(detalle, float(t["sueldo"]))
			# Ni con el tope de plus lo convence: no lo pide. Pedir a
			# alguien que no va a ir jamas es ruido en la bandeja.
			if plus <= 0.0 or plus > float(t["plus_sueldo"]):
				return {}
			if float(t["sueldo"]) * pct + plus > float(pide.caja.get("contratos", 0.0)):
				return {}
	return {"duracion": duracion, "fee": fee, "porcentaje_sueldo": pct,
		"opcion_compra": opcion, "plus_sueldo": plus}


## Le contraofertamos: los terminos vuelven a la mesa del que pide.
## `terminos` trae monto (el fee), porcentaje_sueldo, opcion_compra,
## plus_sueldo y duracion.
static func contraofertar(oferta: Dictionary, terminos: Dictionary, rng: RandomNumberGenerator) -> void:
	oferta["monto"] = float(terminos.get("monto", oferta["monto"]))
	oferta["porcentaje_sueldo"] = float(terminos.get("porcentaje_sueldo", oferta["porcentaje_sueldo"]))
	oferta["opcion_compra"] = float(terminos.get("opcion_compra", oferta["opcion_compra"]))
	oferta["plus_sueldo"] = float(terminos.get("plus_sueldo", oferta.get("plus_sueldo", 0.0)))
	oferta["duracion"] = str(terminos.get("duracion", oferta["duracion"]))
	oferta["estado"] = Ofertas.PENDIENTE_ELLOS
	oferta["ronda"] = int(oferta["ronda"]) + 1
	oferta["dias"] = float(rng.randi_range(Ofertas.DIAS_RESPUESTA_MIN, Ofertas.DIAS_RESPUESTA_MAX))
	oferta["log"].append("Contraofertaste: %s" % resumen(oferta))


## El club que pide contesta nuestra contraoferta. Igual que en una
## compra: acepta, mejora hasta su tope y devuelve la pelota, o se cansa.
static func responder(equipo: Team, oferta: Dictionary, piramide,
		rng: RandomNumberGenerator) -> void:
	var pide := Ofertas._club_por_nombre(piramide, str(oferta["club"]))
	var id := int(oferta["jugador_id"])
	if pide == null:
		oferta["estado"] = Ofertas.RETIRADA
		oferta["log"].append("El club desaparecio de la piramide.")
		return
	var donde := Mercado.ubicar(equipo, id)
	if donde.is_empty():
		oferta["estado"] = Ofertas.RETIRADA
		oferta["log"].append("El jugador ya no esta en el plantel.")
		return
	var jugador: Dictionary = donde["jugador"]

	var r := evaluar_contraoferta(pide, equipo, jugador, oferta)
	if bool(r.get("sin_caja", false)):
		oferta["estado"] = Ofertas.RETIRADA
		oferta["log"].append("%s no puede pagarle el sueldo ni cubriendo el minimo: se baja." % pide.nombre)
		return
	if bool(r["acepta"]):
		oferta["estado"] = Ofertas.ACUERDO_CLUB
		oferta["dias"] = float(rng.randi_range(Ofertas.DIAS_RESPUESTA_MIN, Ofertas.DIAS_RESPUESTA_MAX))
		oferta["log"].append("%s acepta los terminos. Falta que %s quiera ir." % [
			pide.nombre, oferta["jugador"]])
		return
	if int(oferta["ronda"]) >= Ofertas.RONDAS_MAXIMAS:
		oferta["estado"] = Ofertas.RETIRADA
		oferta["log"].append("%s se canso de negociar y se levanto de la mesa." % pide.nombre)
		return

	var mejor: Dictionary = r["mejor"]
	oferta["monto"] = float(mejor["monto"])
	oferta["porcentaje_sueldo"] = float(mejor["porcentaje_sueldo"])
	oferta["opcion_compra"] = float(mejor["opcion_compra"])
	oferta["plus_sueldo"] = float(mejor["plus_sueldo"])
	oferta["estado"] = Ofertas.PENDIENTE_NOSOTROS
	oferta["ronda"] = int(oferta["ronda"]) + 1
	oferta["log"].append("%s llega hasta aca: %s" % [pide.nombre, resumen(oferta)])


## Los clubes arreglaron: ahora habla el jugador, que tiene la ultima
## palabra. En una cesion bajar de categoria pesa la mitad para el titular
## y nada para el suplente (ver Prestamos.division_percibida), y lo unico
## que lo puede
## dar vuelta es el plus que le pongan encima del sueldo: el reparto del
## sueldo es plata entre clubes y a el no le cambia nada.
static func cerrar(equipo: Team, oferta: Dictionary, piramide, rng: RandomNumberGenerator,
		division_propia: int, momento: float) -> void:
	var pide := Ofertas._club_por_nombre(piramide, str(oferta["club"]))
	var id := int(oferta["jugador_id"])
	var donde := Mercado.ubicar(equipo, id)
	if pide == null or donde.is_empty():
		oferta["estado"] = Ofertas.RETIRADA
		oferta["log"].append("La cesion se cayo sola.")
		return
	var jugador: Dictionary = donde["jugador"]

	var division_pide := division_propia
	for d in range(piramide.divisiones.size()):
		if piramide.divisiones[d].equipos.has(pide):
			division_pide = d
			break

	var sueldo_actual := Prestamos.sueldo_de_referencia(equipo, jugador)
	var plus: float = maxf(0.0, float(oferta.get("plus_sueldo", 0.0)))
	var detalle := Negociacion.interes_jugador(
		jugador, equipo.animo.get(id, 50.0), sueldo_actual, sueldo_actual + plus,
		division_propia, Prestamos.division_percibida(equipo, id, division_propia, division_pide))
	if not detalle["acepta"]:
		oferta["estado"] = Ofertas.SIN_ACUERDO
		oferta["log"].append("%s no quiere ir a %s: %s Se queda." % [
			oferta["jugador"], pide.nombre, Negociacion.motivo_rechazo(detalle)])
		return

	var temporadas: float = float(Prestamos.DURACIONES.get(str(oferta["duracion"]), 1.0))
	var r := Prestamos.ceder(equipo, pide, id, momento, temporadas,
		float(oferta["porcentaje_sueldo"]), float(oferta["opcion_compra"]), plus,
		float(oferta["monto"]))
	if not r["exito"]:
		oferta["estado"] = Ofertas.SIN_ACUERDO
		oferta["log"].append("La cesion de %s no se pudo cerrar: %s" % [
			oferta["jugador"], r["motivo"]])
		return
	oferta["estado"] = Ofertas.CERRADA
	oferta["log"].append("%s se va cedido a %s (%s). Cobras %s de fee." % [
		oferta["jugador"], pide.nombre,
		Prestamos.ETIQUETAS_DURACION.get(str(oferta["duracion"]), "1 temporada"),
		Economia.formato_dinero(r["fee"])])
