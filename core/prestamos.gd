class_name Prestamos
extends RefCounted

## Préstamos (§9.3 extendido, plantel de 25 §14): un club cede a un jugador
## de su BANCO o su CANTERA (nunca un titular — perdería demasiada fuerza
## un club que no controlás vos) a otro club por una temporada. El que
## recibe paga un fee único al dueño y el sueldo mientras dura el préstamo;
## el dueño recupera al jugador automáticamente (con lo que haya crecido en
## el otro club) al cierre de la temporada de retorno, sin que nadie tenga
## que acordarse de hacerlo a mano.
##
## Nota técnica: el jugador prestado se agrega/saca de las listas jugadores/
## banco/cantera directamente, sin ocupar "el lugar" de nadie del otro club
## (a diferencia del Mercado, que sí hace swaps 1x1) — nada en el resto del
## código asume que esas listas tienen un tamaño fijo, así que un préstamo
## es simplemente un jugador de más en el banco del que recibe mientras
## dura, y un hueco real en el banco/cantera del que cede (una razón real
## para pensarlo dos veces antes de prestar a alguien que hace falta).

const DURACION_TEMPORADAS := 1
const FEE_PORCENTAJE := 0.10

## §9.3 rework: cuanto puede durar un prestamo pedido desde el mercado.
## En temporadas, y media temporada es media de verdad: el retorno se
## chequea tambien a mitad de año (ver procesar_retornos).
const DURACIONES := {"medio": 0.5, "una": 1.0, "dos": 2.0}
const ETIQUETAS_DURACION := {"medio": "Medio año", "una": "1 temporada", "dos": "2 temporadas"}

## Cuanto del sueldo tiene que cubrir el que PIDE para que al dueño le
## cierre. Menos que esto y lo esta usando de deposito.
const PORCENTAJE_SUELDO_MINIMO := 0.5

## Cuanto crece por temporada, en el calculo que hace el dueño de lo que
## va a valer su jugador cuando termine el prestamo. Es una ESTIMACION
## suya, no la verdad: se apoya en el techo que le queda por realizar.
## Estaba en 0.55. Desde que el crecimiento depende de minutos y
## rendimiento, un GOAT titular promedio cierra ~20% de su distancia al
## techo por temporada (tests/_diag_desarrollo_por_rendimiento.gd).
const CRECIMIENTO_ESTIMADO := 0.2

## Cuanto por encima de esa estimacion tiene que estar la opcion de compra
## para que el dueño la firme. Vender el futuro sale mas caro que vender
## el presente.
const MARGEN_OPCION := 1.15

## Cuanto por encima de lo que el jugador vale HOY llega a pagar un club
## de la IA para ejercer la opcion de compra. Es el espejo de MARGEN_OPCION
## y por eso es mas chico: el dueño pactó el precio pensando en lo que iba
## a valer, y el que compra decide con el valor que tiene delante. Si el
## pibe crecio, la opcion quedo barata y la ejerce; si no crecio, la deja
## vencer y devuelve al jugador.
const TOPE_OPCION_COMPRADOR := 1.10

## Con cuanta anticipacion se avisa que la opcion se vence, en temporadas.
## 0.25 es un cuarto de año: alcanza para juntar la plata de Fichajes sin
## que el aviso llegue tan temprano que se olvide.
const AVISO_ANTES_DE_VENCER := 0.25

## Cuantos años de contrato firma el que ejerce la opcion. Es el contrato
## estandar de un fichaje (Team.incorporar).
const ANIOS_CONTRATO_OPCION := 3


## El sueldo que cobra hoy el jugador, segun su dueño. Un canterano NO
## tiene entrada en `sueldos` (nunca firmo ficha), y leer ahi un 0.0 hacia
## que el prestamo lo rechazara siempre: el jugador comparaba su sueldo
## contra cero y la cuenta le daba que le bajaban el sueldo. La tabla es
## la misma que usa `ceder` para repartir el pago.
## La division que el jugador SIENTE como destino al evaluar un prestamo.
##
## Un suplente o una reserva no pierde nada por bajar de categoria: en su
## club no juega, y a prestamo va a sumar minutos. Para el, bajar no pesa.
## El titular si resigna vitrina, y para el el salto pesa la MITAD que en
## un pase, porque es temporal. Subir pesa la mitad para todos.
##
## Antes bajar pesaba igual para el titular y para el suplente. Medido sobre
## una partida real en 3a: de 11 cedibles, 10 rechazaban cualquier pedido
## de 9a o 10a con "No quiere bajar de categoria".
static func division_percibida(dueno: Team, jugador_id: int, division_origen: int,
		division_destino: int) -> int:
	var salto: int = division_destino - division_origen
	if salto > 0 and not _es_titular(dueno, jugador_id):
		return division_origen
	return division_origen + int(round(salto / 2.0))


## La media del plantel de destino que el jugador pesa al evaluar un
## prestamo (Negociacion.interes_jugador). Al suplente no le pesa ser el
## mejor del club que lo pide: va a sumar minutos, igual que en
## division_percibida. -1 apaga el factor. Sin esto el suplente de 1a
## rechazaba bajar a 5a con "tendria que cargar con el equipo"
## (tests/test_prestamos_mercado.gd).
static func media_destino_percibida(dueno: Team, jugador_id: int, media_destino: float) -> float:
	return media_destino if _es_titular(dueno, jugador_id) else -1.0


static func _es_titular(equipo: Team, jugador_id: int) -> bool:
	return _indice_en(equipo.jugadores, jugador_id) >= 0


static func sueldo_de_referencia(dueno: Team, jugador: Dictionary) -> float:
	var id := int(jugador["id"])
	return float(dueno.sueldos.get(id, Economia.sueldo_sugerido(
		ValorJugador.base_salarial(jugador, 50.0, 3, dueno.division_actual))))


## Lo que el dueño CREE que va a valer su jugador cuando termine el
## prestamo. Un pibe con mucho techo sin realizar se le va a encarecer, y
## por eso no te lo va a atar barato; un veterano se le va a abaratar, y
## ahi la opcion le conviene.
static func valor_futuro_estimado(jugador: Dictionary, temporadas: float) -> float:
	var media: float = float(jugador["media"])
	var techo: float = float(jugador["potencial"])
	var edad: int = int(jugador["edad"])
	var proyectada := media
	if edad <= 27:
		proyectada = minf(techo, media + (techo - media) * CRECIMIENTO_ESTIMADO * temporadas)
	else:
		# De los 28 para arriba se va apagando.
		proyectada = maxf(20.0, media - 2.0 * temporadas)
	var futuro: Dictionary = jugador.duplicate()
	futuro["media"] = proyectada
	futuro["edad"] = edad + int(ceil(temporadas))
	return ValorJugador.calcular(futuro, 50.0, 3)


## ¿El dueño acepta prestarlo con estas condiciones? Le importan tres
## cosas: que le saquen el sueldo de encima, no desprenderse de una pieza
## que necesita, y —si hay opcion de compra— no regalar el futuro.
##
## `opcion_compra` 0.0 = sin opcion.
static func evaluar_pedido(dueno: Team, jugador: Dictionary, porcentaje_sueldo: float,
		opcion_compra: float, temporadas: float) -> Dictionary:
	var id := int(jugador["id"])
	if porcentaje_sueldo < PORCENTAJE_SUELDO_MINIMO:
		return {"acepta": false,
			"motivo": "Querés que sigamos pagándole el sueldo. Cubrí al menos el %d%%." % int(PORCENTAJE_SUELDO_MINIMO * 100.0)}
	# Un titular no se presta: el club que no controlás vos no se debilita
	# solo (mismo criterio que la version original de ceder()).
	for j in dueno.jugadores:
		if int(j["id"]) == id:
			return {"acepta": false, "motivo": "Es titular nuestro, no lo prestamos."}
	if opcion_compra > 0.0:
		var minimo := valor_futuro_estimado(jugador, temporadas) * MARGEN_OPCION
		if opcion_compra < minimo:
			return {"acepta": false,
				"motivo": "La opción de compra es muy baja para lo que creemos que va a valer.",
				"minimo": minimo}
	return {"acepta": true}


static func _indice_en(arr: Array, jugador_id: int) -> int:
	for i in range(arr.size()):
		if arr[i]["id"] == jugador_id:
			return i
	return -1


## Cede a jugador_id (de banco o cantera de origen) a destino por una
## temporada. temporada_actual es la temporada en curso al momento de
## cederlo — determina cuándo vuelve.
## `temporadas` en temporadas (0.5 / 1.0 / 2.0). `porcentaje_sueldo` es la
## parte del sueldo que paga el que RECIBE; el resto lo sigue pagando el
## dueño, que por eso no borra su registro. `opcion_compra` 0.0 = sin
## opcion; si hay, queda anotada y se ofrece al vencer.
## `plus_sueldo` es plata EXTRA que el que recibe le pone al jugador por
## encima de lo que cobra hoy. Al dueño no le cuesta nada y no le importa;
## es la unica palanca que tiene el que pide para convencer a un jugador
## que no quiere bajar de categoria. Se evapora cuando el prestamo vence:
## el dueño lo recupera con su sueldo de siempre.
## `fee` en -1.0 = el 10% de tabla (FEE_PORCENTAJE). Una cesion negociada
## (core/cesiones.gd) pasa el fee que se acordo en la mesa, que es otro.
static func ceder(origen: Team, destino: Team, jugador_id: int, temporada_actual: float,
		temporadas: float = float(DURACION_TEMPORADAS), porcentaje_sueldo: float = 1.0,
		opcion_compra: float = 0.0, plus_sueldo: float = 0.0, fee: float = -1.0) -> Dictionary:
	if origen == destino:
		return {"exito": false, "motivo": "No podés prestarte un jugador a vos mismo."}

	# Sirve para CUALQUIERA del club, titular incluido. Al titular ajeno lo
	# frena antes evaluar_pedido —un club de la IA no debilita su once—,
	# pero sobre los tuyos decidis vos: la lista de cedibles
	# (core/cesiones.gd) no distingue, y ceder al que hoy juega para que
	# vaya a jugar a otro lado es una decision valida.
	var donde := Mercado.ubicar(origen, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador no está en ese club."}
	var jugador: Dictionary = donde["jugador"]
	var en_cantera: bool = str(donde["origen"]) == "cantera"

	var valor := ValorJugador.calcular(jugador, origen.animo.get(jugador_id, 50.0), origen.contratos.get(jugador_id, 1))
	if fee < 0.0:
		fee = valor * FEE_PORCENTAJE
	if destino.caja["fichajes"] < fee:
		return {"exito": false, "motivo": "No alcanza el presupuesto de Fichajes para el fee del préstamo.", "fee": fee, "disponible": destino.caja["fichajes"]}

	var sueldo_completo: float = sueldo_de_referencia(origen, jugador)
	var pago_destino: float = sueldo_completo * porcentaje_sueldo + maxf(0.0, plus_sueldo)
	if not Economia.puede_pagar_contrato(destino, pago_destino):
		return Economia.motivo_contrato_corto(destino, pago_destino)

	if en_cantera:
		origen.cantera.remove_at(_indice_en(origen.cantera, jugador_id))
	else:
		_sacar_del_plantel(origen, jugador_id)
		# NO se limpia el registro del dueño: sigue pagando su parte del
		# sueldo mientras dura el préstamo, y conserva contrato y cláusula
		# porque el jugador sigue siendo suyo.
		origen.sueldos[jugador_id] = sueldo_completo * (1.0 - porcentaje_sueldo)

	destino.caja["fichajes"] -= fee
	origen.caja["fichajes"] += fee
	_ubicar_en_destino(destino, jugador)
	destino._registrar_fichaje(jugador, valor, 1)
	# _registrar_fichaje le cobró a Contratos el sueldo de tabla; el que
	# paga de verdad es su PARTE del sueldo pactada en el préstamo.
	destino.caja["contratos"] += destino.sueldos[jugador_id] - pago_destino
	destino.sueldos[jugador_id] = pago_destino

	# El uso de la temporada arranca de cero en el club nuevo: lo que
	# aprendio antes de irse ya lo tiene sumado el dueño, y mezclarlos
	# haria que el reporte de vuelta contara partidos que no jugo ahi.
	jugador["partidos_prestamo"] = 0
	jugador["goles_prestamo"] = 0
	jugador["asistencias_prestamo"] = 0

	var temporada_retorno: float = temporada_actual + temporadas
	origen.prestados_afuera[jugador_id] = {"club": destino, "temporada_retorno": temporada_retorno,
		"desde_cantera": en_cantera, "sueldo_completo": sueldo_completo,
		"opcion_compra": opcion_compra, "media_al_ceder": float(jugador["media"])}
	destino.prestados_propios[jugador_id] = {"club_dueno": origen, "temporada_retorno": temporada_retorno,
		"opcion_compra": opcion_compra}

	return {"exito": true, "jugador": jugador, "fee": fee, "temporada_retorno": temporada_retorno,
		"opcion_compra": opcion_compra, "sueldo_propio": pago_destino}


## Donde entra el cedido en el club que lo recibe.
##
## Antes iba SIEMPRE al banco, y ahi la mecanica se mordia la cola: el
## sentido de ceder a un pibe es que juegue, pero como no jugaba no sumaba
## uso (Progresion.multiplicador_uso) y volvia igual que como se fue. Si
## es mejor que el peor titular de su puesto, entra al once y ese titular
## pasa al banco.
##
## No usa Team.incorporar porque incorporar puede ECHAR del club al que
## desplaza cuando el plantel esta lleno: un prestamo es un jugador de
## mas, no le cuesta el puesto a nadie (ver la nota tecnica de arriba).
static func _ubicar_en_destino(destino: Team, jugador: Dictionary) -> void:
	var posicion: String = jugador["posicion"]
	var idx_peor := -1
	for i in range(destino.jugadores.size()):
		if destino.jugadores[i]["posicion"] != posicion:
			continue
		if idx_peor == -1 or float(destino.jugadores[i]["media"]) < float(destino.jugadores[idx_peor]["media"]):
			idx_peor = i
	if idx_peor != -1 and float(jugador["media"]) > float(destino.jugadores[idx_peor]["media"]):
		var sale: Dictionary = destino.jugadores[idx_peor]
		destino.jugadores[idx_peor] = jugador
		destino.mover_a_banco(sale)
		destino.recalcular_capitan()
		return
	# mover_a_banco y no banco.append: si el banco esta lleno, el que llega
	# a prestamo entra como reserva.
	destino.mover_a_banco(jugador)


## Se llama al cierre de cada temporada para "equipo": repatría a los
## jugadores que equipo cedió y cuyo préstamo ya venció. Devuelve una
## lista de reportes {jugador, club, partidos, goles, asistencias, media_antes,
## media_ahora}: el que se fue puede volver mejor de lo que se fue, y
## enterarse de eso es la mitad del punto de haberlo prestado.
## `momento` es la temporada en curso como decimal: 3.0 es el arranque de
## la temporada 3 y 3.5 la mitad. Hace falta para que un prestamo de medio
## año sea de medio año de verdad — antes solo se chequeaba al cierre.
static func procesar_retornos(equipo: Team, momento: float, equipo_humano: Team = null) -> Array:
	var vueltos := []
	for id in equipo.prestados_afuera.keys().duplicate():
		var info: Dictionary = equipo.prestados_afuera[id]
		if momento < float(info["temporada_retorno"]):
			continue

		var destino: Team = info["club"]
		# Vence la opcion de compra: es AHORA o nunca. Un club de la IA
		# decide solo; si el que la tiene sos vos, la decision es tuya y
		# se toma antes de que venza (GameState.ejercer_opcion_de_compra),
		# asi que llegar hasta aca significa que la dejaste pasar.
		var precio: float = float(info.get("opcion_compra", 0.0))
		if precio > 0.0 and destino != equipo_humano:
			var esta := Mercado.ubicar(destino, int(id))
			if not esta.is_empty() and conviene_la_opcion(destino, equipo, esta["jugador"], precio):
				var partidos_prestamo := int(esta["jugador"].get("partidos_prestamo", 0))
				var goles_prestamo := int(esta["jugador"].get("goles_prestamo", 0))
				var asistencias_prestamo := int(esta["jugador"].get("asistencias_prestamo", 0))
				var compra := ejercer_opcion(destino, equipo, int(id))
				if compra["exito"]:
					vueltos.append({
						"jugador": compra["jugador"],
						"club": destino.nombre,
						"comprado": true,
						"precio": precio,
						"partidos": partidos_prestamo,
						"goles": goles_prestamo,
						"asistencias": asistencias_prestamo,
						"media_antes": float(info.get("media_al_ceder", compra["jugador"]["media"])),
						"media_ahora": float(compra["jugador"]["media"]),
					})
					continue

		var jugador := _sacar_del_plantel(destino, int(id))
		if jugador.is_empty():
			# El jugador ya no está (por ejemplo, se vendió mientras estaba a
			# préstamo, caso raro que hoy no puede pasar porque el mercado no
			# toca al banco ajeno, pero por las dudas no se rompe acá).
			equipo.prestados_afuera.erase(id)
			continue

		destino._limpiar_registro(id)
		destino.prestados_propios.erase(id)

		if info["desde_cantera"]:
			equipo.cantera.append(jugador)
		else:
			equipo.mover_a_banco(jugador)
			# El dueño nunca solto el registro (paga su parte del sueldo
			# durante el prestamo), asi que al volver solo se le repone el
			# sueldo entero.
			equipo.sueldos[id] = float(info.get("sueldo_completo",
				ValorJugador.base_salarial(
					jugador, 50.0, 2, equipo.division_actual) * 0.10))

		equipo.prestados_afuera.erase(id)
		vueltos.append({
			"jugador": jugador,
			"club": destino.nombre,
			"comprado": false,
			"opcion_vencida": float(info.get("opcion_compra", 0.0)),
			"partidos": int(jugador.get("partidos_prestamo", 0)),
			"goles": int(jugador.get("goles_prestamo", 0)),
			"asistencias": int(jugador.get("asistencias_prestamo", 0)),
			"media_antes": float(info.get("media_al_ceder", jugador["media"])),
			"media_ahora": float(jugador["media"]),
		})
		jugador["partidos_prestamo"] = 0
		jugador["goles_prestamo"] = 0
		jugador["asistencias_prestamo"] = 0

	return vueltos


## Ejerce la opcion de compra pactada: el club que lo tenia a prestamo se
## lo queda al precio que se firmo al ceder.
##
## No pasa por Mercado.ejecutar_pase porque el jugador ya esta FISICAMENTE
## en el comprador —esta a prestamo—, y ejecutar_pase lo busca en el
## plantel del vendedor y no lo encuentra. Aca solo cambian los papeles:
## la plata, el registro del dueño y el contrato nuevo.
##
## `sueldo` en -1.0 = lo que el jugador pretende (Negociacion.sueldo_pretendido).
static func ejercer_opcion(comprador: Team, dueno: Team, jugador_id: int,
		sueldo: float = -1.0, anios: int = ANIOS_CONTRATO_OPCION) -> Dictionary:
	if not comprador.prestados_propios.has(jugador_id):
		return {"exito": false, "motivo": "Ese jugador no está a préstamo en tu club."}
	var info: Dictionary = comprador.prestados_propios[jugador_id]
	var precio: float = float(info.get("opcion_compra", 0.0))
	if precio <= 0.0:
		return {"exito": false, "motivo": "Ese préstamo no tiene opción de compra."}
	var donde := Mercado.ubicar(comprador, jugador_id)
	if donde.is_empty():
		return {"exito": false, "motivo": "Ese jugador ya no está en tu plantel."}
	var jugador: Dictionary = donde["jugador"]
	if not Mercado.puede_comprarse(jugador):
		return {"exito": false, "motivo": Mercado.MOTIVO_RECIEN_COMPRADO,
			"recien_comprado": true}

	if comprador.caja["fichajes"] < precio:
		return {"exito": false, "motivo": "No te alcanza el presupuesto de Fichajes para la opción.",
			"precio": precio, "disponible": comprador.caja["fichajes"]}
	if sueldo < 0.0:
		sueldo = Negociacion.sueldo_pretendido(jugador,
			sueldo_de_referencia(dueno, jugador),
			dueno.division_actual, comprador.division_actual)
	if not Economia.puede_pagar_contrato(comprador, sueldo - float(comprador.sueldos.get(jugador_id, 0.0))):
		return Economia.motivo_contrato_corto(comprador, sueldo)

	comprador.caja["fichajes"] -= precio
	dueno.caja["fichajes"] += precio

	# El dueño lo suelta del todo: deja de pagar su parte del sueldo y
	# pierde contrato, clausula y las dos listas de mercado.
	dueno.prestados_afuera.erase(jugador_id)
	dueno._limpiar_registro(jugador_id)

	# El comprador deja de tenerlo prestado y le hace ficha propia. Su
	# sueldo de prestamo ya estaba descontado de Contratos, asi que solo
	# se corrige la diferencia contra el nuevo.
	comprador.prestados_propios.erase(jugador_id)
	comprador.caja["contratos"] += float(comprador.sueldos.get(jugador_id, 0.0)) - sueldo
	comprador.sueldos[jugador_id] = sueldo
	comprador.contratos[jugador_id] = anios
	jugador["club_actual"] = comprador.nombre
	jugador["partidos_prestamo"] = 0
	jugador["goles_prestamo"] = 0
	jugador["asistencias_prestamo"] = 0
	Mercado.marcar_compra(jugador)

	return {"exito": true, "jugador": jugador, "precio": precio,
		"sueldo": sueldo, "anios": anios}


## ¿Un club de la IA ejerce la opcion? Mira lo mismo que miraria cualquiera:
## si el precio pactado quedo barato contra lo que el jugador vale hoy, si
## le mejora el plantel, si le entra en la caja y si el jugador quiere
## quedarse.
static func conviene_la_opcion(comprador: Team, dueno: Team, jugador: Dictionary,
		precio: float) -> bool:
	if not Mercado.puede_comprarse(jugador):
		return false
	var id := int(jugador["id"])
	var valor := ValorJugador.calcular(jugador, comprador.animo.get(id, 50.0), 3)
	if precio > valor * TOPE_OPCION_COMPRADOR:
		return false
	if float(jugador["media"]) <= comprador.media_equipo():
		return false
	if comprador.caja["fichajes"] < precio:
		return false
	var sueldo_actual := sueldo_de_referencia(dueno, jugador)
	var pretende := Negociacion.sueldo_pretendido(jugador, sueldo_actual,
		dueno.division_actual, comprador.division_actual)
	if not Economia.puede_pagar_contrato(comprador, pretende - float(comprador.sueldos.get(id, 0.0))):
		return false
	# El jugador tambien decide: quedarse es un pase, no una renovacion.
	var detalle := Negociacion.interes_jugador(jugador, comprador.animo.get(id, 50.0),
		sueldo_actual, pretende, dueno.division_actual, comprador.division_actual,
		comprador.media_equipo())
	return bool(detalle["acepta"])


## El retorno contado en una linea: cuanto jugo, cuanto metio y cuanto
## crecio mientras estuvo afuera. Es lo que hace que ceder a un pibe sea
## una decision y no un tramite — si volvio igual que como se fue, el
## prestamo no sirvio de nada y el texto lo dice.
static func texto_retorno(r: Dictionary) -> String:
	var jugador: Dictionary = r["jugador"]
	var quien := "%s %s" % [str(jugador.get("nombre", "")), str(jugador.get("apellido", ""))]
	if bool(r.get("comprado", false)):
		return "OPCION DE COMPRA: %s ejerce la opcion por %s (%s) y se queda con el. Cobras %s." % [
			str(r["club"]), quien.strip_edges(), str(jugador["posicion"]),
			Economia.formato_dinero(float(r["precio"]))]
	var t := "PRESTAMO: vuelve %s (%s) de %s tras %d partido(s)" % [
		quien.strip_edges(), str(jugador["posicion"]), str(r["club"]), int(r["partidos"])]
	if int(r["goles"]) > 0:
		t += " y %d gol(es)" % int(r["goles"])
	if int(r.get("asistencias", 0)) > 0:
		t += " y %d asistencia(s)" % int(r["asistencias"])
	var delta: int = int(round(float(r["media_ahora"]) - float(r["media_antes"])))
	if delta > 0:
		t += ". Vuelve mejor: media %d (+%d)." % [int(round(float(r["media_ahora"]))), delta]
	elif delta < 0:
		t += ". Vuelve peor: media %d (%d)." % [int(round(float(r["media_ahora"]))), delta]
	else:
		t += ". Vuelve igual: media %d." % int(round(float(r["media_ahora"])))
	if float(r.get("opcion_vencida", 0.0)) > 0.0:
		t += " No ejercieron la opcion de %s." % Economia.formato_dinero(
			float(r["opcion_vencida"]))
	return t


## Lo saca del plantel de partido (once, banco o reservas), este donde
## este. Si era titular, sube al mejor suplente de su puesto: NO se usa Team.perder_jugador
## porque esa ficha a alguien nuevo para tapar el hueco del banco, y un
## club que devuelve un prestamo no se gana un jugador por eso.
static func _sacar_del_plantel(destino: Team, id: int) -> Dictionary:
	for i in range(destino.jugadores.size()):
		if int(destino.jugadores[i]["id"]) != id:
			continue
		var jugador: Dictionary = destino.jugadores[i]
		var posicion: String = jugador["posicion"]
		var mejor := -1
		for k in range(destino.banco.size()):
			if str(destino.banco[k]["posicion"]) != posicion:
				continue
			if mejor == -1 or float(destino.banco[k]["media"]) > float(destino.banco[mejor]["media"]):
				mejor = k
		if mejor >= 0:
			destino.jugadores[i] = destino.banco[mejor]
			destino.banco.remove_at(mejor)
		else:
			# Sin suplente del puesto el once queda en diez hasta que
			# Alineacion.arreglar lo tape antes del partido, que es
			# exactamente lo que pasa con un lesionado.
			destino.jugadores.remove_at(i)
		destino.recalcular_capitan()
		return jugador

	var idx := _indice_en(destino.banco, id)
	if idx >= 0:
		var j: Dictionary = destino.banco[idx]
		destino.banco.remove_at(idx)
		return j
	idx = _indice_en(destino.reservas, id)
	if idx >= 0:
		var j2: Dictionary = destino.reservas[idx]
		destino.reservas.remove_at(idx)
		return j2
	return {}
