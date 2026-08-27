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
const CRECIMIENTO_ESTIMADO := 0.55

## Cuanto por encima de esa estimacion tiene que estar la opcion de compra
## para que el dueño la firme. Vender el futuro sale mas caro que vender
## el presente.
const MARGEN_OPCION := 1.15


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
static func ceder(origen: Team, destino: Team, jugador_id: int, temporada_actual: float,
		temporadas: float = float(DURACION_TEMPORADAS), porcentaje_sueldo: float = 1.0,
		opcion_compra: float = 0.0) -> Dictionary:
	if origen == destino:
		return {"exito": false, "motivo": "No podés prestarte un jugador a vos mismo."}

	var idx_banco := _indice_en(origen.banco, jugador_id)
	var en_cantera := false
	var jugador: Dictionary
	if idx_banco >= 0:
		jugador = origen.banco[idx_banco]
	else:
		var idx_cantera := _indice_en(origen.cantera, jugador_id)
		if idx_cantera < 0:
			return {"exito": false, "motivo": "Ese jugador no está en tu banco ni en tu cantera."}
		jugador = origen.cantera[idx_cantera]
		en_cantera = true

	var valor := ValorJugador.calcular(jugador, origen.animo.get(jugador_id, 50.0), origen.contratos.get(jugador_id, 1))
	var fee: float = valor * FEE_PORCENTAJE
	if destino.caja["fichajes"] < fee:
		return {"exito": false, "motivo": "No alcanza el presupuesto de Fichajes para el fee del préstamo.", "fee": fee, "disponible": destino.caja["fichajes"]}

	var sueldo_completo: float = float(origen.sueldos.get(jugador_id, Economia.sueldo_sugerido(
		ValorJugador.base_salarial(jugador, 50.0, 3))))

	if en_cantera:
		origen.cantera.remove_at(_indice_en(origen.cantera, jugador_id))
	else:
		origen.banco.remove_at(idx_banco)
		# NO se limpia el registro del dueño: sigue pagando su parte del
		# sueldo mientras dura el préstamo, y conserva contrato y cláusula
		# porque el jugador sigue siendo suyo.
		origen.sueldos[jugador_id] = sueldo_completo * (1.0 - porcentaje_sueldo)

	destino.caja["fichajes"] -= fee
	origen.caja["fichajes"] += fee
	destino.banco.append(jugador)
	destino._registrar_fichaje(jugador, valor, 1)
	destino.sueldos[jugador_id] = sueldo_completo * porcentaje_sueldo

	var temporada_retorno: float = temporada_actual + temporadas
	origen.prestados_afuera[jugador_id] = {"club": destino, "temporada_retorno": temporada_retorno,
		"desde_cantera": en_cantera, "sueldo_completo": sueldo_completo, "opcion_compra": opcion_compra}
	destino.prestados_propios[jugador_id] = {"club_dueno": origen, "temporada_retorno": temporada_retorno,
		"opcion_compra": opcion_compra}

	return {"exito": true, "jugador": jugador, "fee": fee, "temporada_retorno": temporada_retorno,
		"opcion_compra": opcion_compra, "sueldo_propio": sueldo_completo * porcentaje_sueldo}


## Se llama al cierre de cada temporada para "equipo": repatría a los
## jugadores que equipo cedió y cuyo préstamo ya venció. Devuelve la lista
## de jugadores que volvieron.
## `momento` es la temporada en curso como decimal: 3.0 es el arranque de
## la temporada 3 y 3.5 la mitad. Hace falta para que un prestamo de medio
## año sea de medio año de verdad — antes solo se chequeaba al cierre.
static func procesar_retornos(equipo: Team, momento: float) -> Array:
	var vueltos := []
	for id in equipo.prestados_afuera.keys().duplicate():
		var info: Dictionary = equipo.prestados_afuera[id]
		if momento < float(info["temporada_retorno"]):
			continue

		var destino: Team = info["club"]
		var idx := _indice_en(destino.banco, id)
		if idx < 0:
			# El jugador ya no está (por ejemplo, se vendió mientras estaba a
			# préstamo, caso raro que hoy no puede pasar porque el mercado no
			# toca al banco ajeno, pero por las dudas no se rompe acá).
			equipo.prestados_afuera.erase(id)
			continue

		var jugador: Dictionary = destino.banco[idx]
		destino.banco.remove_at(idx)
		destino._limpiar_registro(id)
		destino.prestados_propios.erase(id)

		if info["desde_cantera"]:
			equipo.cantera.append(jugador)
		else:
			equipo.banco.append(jugador)
			# El dueño nunca solto el registro (paga su parte del sueldo
			# durante el prestamo), asi que al volver solo se le repone el
			# sueldo entero.
			equipo.sueldos[id] = float(info.get("sueldo_completo",
				ValorJugador.base_salarial(jugador, 50.0, 2) * 0.10))

		equipo.prestados_afuera.erase(id)
		vueltos.append(jugador)

	return vueltos
