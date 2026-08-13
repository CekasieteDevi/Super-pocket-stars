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


static func _indice_en(arr: Array, jugador_id: int) -> int:
	for i in range(arr.size()):
		if arr[i]["id"] == jugador_id:
			return i
	return -1


## Cede a jugador_id (de banco o cantera de origen) a destino por una
## temporada. temporada_actual es la temporada en curso al momento de
## cederlo — determina cuándo vuelve.
static func ceder(origen: Team, destino: Team, jugador_id: int, temporada_actual: int) -> Dictionary:
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

	if en_cantera:
		origen.cantera.remove_at(_indice_en(origen.cantera, jugador_id))
	else:
		origen.banco.remove_at(idx_banco)
		origen._limpiar_registro(jugador_id)

	destino.caja["fichajes"] -= fee
	origen.caja["fichajes"] += fee
	destino.banco.append(jugador)
	destino._registrar_fichaje(jugador, valor, 1)

	var temporada_retorno: int = temporada_actual + DURACION_TEMPORADAS
	origen.prestados_afuera[jugador_id] = {"club": destino, "temporada_retorno": temporada_retorno, "desde_cantera": en_cantera}
	destino.prestados_propios[jugador_id] = {"club_dueno": origen, "temporada_retorno": temporada_retorno}

	return {"exito": true, "jugador": jugador, "fee": fee, "temporada_retorno": temporada_retorno}


## Se llama al cierre de cada temporada para "equipo": repatría a los
## jugadores que equipo cedió y cuyo préstamo ya venció. Devuelve la lista
## de jugadores que volvieron.
static func procesar_retornos(equipo: Team, temporada_actual: int) -> Array:
	var vueltos := []
	for id in equipo.prestados_afuera.keys().duplicate():
		var info: Dictionary = equipo.prestados_afuera[id]
		if temporada_actual < info["temporada_retorno"]:
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
			equipo._registrar_fichaje(jugador, ValorJugador.calcular(jugador, 50.0, 2), 2)

		equipo.prestados_afuera.erase(id)
		vueltos.append(jugador)

	return vueltos
