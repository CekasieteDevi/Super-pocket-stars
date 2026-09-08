class_name AgentesLibres
extends RefCounted

## Agentes libres (§9.3 extendido, plantel de 25 §14): pool de jugadores sin
## club, fichables SIN fee de transferencia (solo el sueldo). Se alimenta de
## vencimientos de contrato de los clubes de la IA (Liga._avanzar_contratos)
## — al jugador humano no se le vencen contratos solo todavía (misma
## simplificación documentada que ya existía: sin una pantalla de "renovar
## contrato", forzar la salida de un titular sin que el jugador lo decida
## sería quitarle el control de su propio plantel). El pool es por división
## (Liga.agentes_libres), igual que el resto del mercado.

const CONTRATO_LIBRE_ANIOS := 2

## Con cuantos años firma el juvenil que sube a tapar un puesto. El mismo
## contrato que cualquier promocion de cantera (ver Team.promover_juvenil):
## subir por un vencimiento ajeno no es un debut distinto de los otros.
const ANIOS_CANTERANO := 3


## Saca a "jugador" del plantel de equipo (venció contrato, no se lo
## renovó) y lo manda al pool. El puesto que deja vacante lo tapa alguien
## en el acto — ningún club puede quedar con un agujero en la formación de
## un día para el otro; la profundidad real que gana el juego es que ese
## jugador liberado ahora se puede fichar gratis desde el pool.
##
## Quién tapa el puesto lo decide `desde_cantera`: ver _reemplazo_para.
## Devuelve {jugador, de_cantera} con el que entró, o {} si el que se iba
## no estaba en el plantel.
static func liberar(equipo: Team, jugador: Dictionary, pool: Array,
		rng: RandomNumberGenerator, desde_cantera: bool = false) -> Dictionary:
	var id: int = jugador["id"]
	var idx := -1
	var en_banco := false
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["id"] == id:
			idx = i
			break
	if idx == -1:
		en_banco = true
		for i in range(equipo.banco.size()):
			if equipo.banco[i]["id"] == id:
				idx = i
				break
	if idx == -1:
		return {}

	var relevo := _reemplazo_para(equipo, jugador["posicion"], rng, desde_cantera)
	if relevo.is_empty():
		relevo = _dejar_hueco(equipo, idx, en_banco, jugador["posicion"])
	else:
		var reemplazo: Dictionary = relevo["jugador"]
		if en_banco:
			equipo.banco[idx] = reemplazo
		else:
			equipo.jugadores[idx] = reemplazo
	equipo.recalcular_capitan()

	equipo._limpiar_registro(id)
	pool.append(jugador)
	return relevo


## Con quien se tapa el puesto que dejo el que se fue.
##
## `desde_cantera` tira PRIMERO de los juveniles propios. Es para eso que
## la cantera genera juveniles todos los años, y lo usa solo el club del
## jugador humano: la IA no tiene quien le mire la cantera.
##
## Antes se generaba siempre un jugador nuevo del nivel del club, y ese
## fichaje cobraba sueldo de mercado contra el presupuesto de Contratos.
## Medido en una partida de division 10: se vencieron siete contratos y
## los siete reemplazos costaron $13.580 contra los $6.714 que cobraban
## los que se iban. Son $6.866 de un presupuesto de $8.025 —el 86%—
## gastados en jugadores que el club no eligio.
##
## Se busca primero un juvenil del mismo puesto y despues el mejor que
## haya: a un canterano fuera de puesto lo reacomoda Alineacion.arreglar,
## a un fichaje que nadie pidio no lo arregla nadie.
##
## Con la cantera vacia devuelve {} y NO inventa un jugador: en la vida
## real a un club no le aparece un futbolista de la nada porque se le
## venza un contrato. El puesto queda sin cubrir y lo resuelve el jugador
## como quiera —comprando, fichando un libre o subiendo un juvenil—, que
## es exactamente la decision que el fichaje automatico le sacaba. Quien
## se hace cargo del hueco es _dejar_hueco.
##
## La IA sigue generando el reemplazo (desde_cantera == false): nadie le
## mira el plantel a los 200 clubes de la piramide, y un club de la IA con
## el once incompleto no lo arregla nunca mas.
static func _reemplazo_para(equipo: Team, posicion: String,
		rng: RandomNumberGenerator, desde_cantera: bool) -> Dictionary:
	if desde_cantera:
		var mejor := -1
		for i in range(equipo.cantera.size()):
			if mejor == -1:
				mejor = i
				continue
			var en_puesto: bool = equipo.cantera[i]["posicion"] == posicion
			var mejor_en_puesto: bool = equipo.cantera[mejor]["posicion"] == posicion
			if en_puesto != mejor_en_puesto:
				if en_puesto:
					mejor = i
			elif equipo.cantera[i]["media"] > equipo.cantera[mejor]["media"]:
				mejor = i
		if mejor != -1:
			var juvenil: Dictionary = equipo.cantera[mejor]
			juvenil["es_canterano"] = true
			equipo.cantera.remove_at(mejor)
			equipo._registrar_fichaje(
				juvenil, ValorJugador.calcular(juvenil, 50.0, ANIOS_CANTERANO),
				ANIOS_CANTERANO)
			equipo.promociones_temporada += 1
			return {"jugador": juvenil, "de_cantera": true}

	if desde_cantera:
		return {}

	# Del nivel del club: un club de decima no ficha un agente libre de
	# primera (ver Team.nivel_potencial).
	var nuevo := PlayerGenerator.generate(
		equipo.siguiente_id_cantera, rng, posicion, equipo.nivel_potencial())
	equipo.siguiente_id_cantera += 1
	equipo._registrar_fichaje(
		nuevo, ValorJugador.calcular(nuevo, 50.0, CONTRATO_LIBRE_ANIOS),
		CONTRATO_LIBRE_ANIOS)
	return {"jugador": nuevo, "de_cantera": false}


## Fichaje de un agente libre del pool: sin fee de transferencia, el club
## solo empieza a pagarle el sueldo. Reemplaza a un jugador puntual del
## plantel propio (titular o banco, lo elige quien ficha) — ese jugador
## desplazado, a su vez, pasa a integrar el pool en su lugar, así nunca se
## pierde de golpe y el mercado de libres se sigue renovando solo.
static func fichar(equipo: Team, pool: Array, jugador_id: int, indice_saliente: int, es_banco: bool) -> Dictionary:
	var idx_pool := -1
	for i in range(pool.size()):
		if pool[i]["id"] == jugador_id:
			idx_pool = i
			break
	if idx_pool < 0:
		return {"exito": false, "motivo": "Ese agente libre ya no está disponible."}

	var lista: Array = equipo.banco if es_banco else equipo.jugadores
	if indice_saliente < 0 or indice_saliente >= lista.size():
		return {"exito": false, "motivo": "Puesto inválido."}

	var agente: Dictionary = pool[idx_pool]
	var saliente: Dictionary = lista[indice_saliente]

	# Gratis es el pase, no el sueldo: un libre igual entra a la nómina y
	# sale de Contratos. Lo que cuesta de verdad es la DIFERENCIA con el
	# que se va, porque _limpiar_registro le devuelve su sueldo a la caja.
	var sueldo := Economia.sueldo_de_ficha(
		agente, CONTRATO_LIBRE_ANIOS, equipo.division_actual)
	var diferencia: float = sueldo - float(equipo.sueldos.get(saliente["id"], 0.0))
	if not Economia.puede_pagar_contrato(equipo, diferencia):
		return Economia.motivo_contrato_corto(equipo, diferencia)

	pool.remove_at(idx_pool)
	lista[indice_saliente] = agente
	equipo.recalcular_capitan()

	equipo._registrar_fichaje(agente, ValorJugador.calcular(agente, 50.0, CONTRATO_LIBRE_ANIOS), CONTRATO_LIBRE_ANIOS)
	equipo._limpiar_registro(saliente["id"])
	pool.append(saliente)

	return {"exito": true, "entra": agente, "sale": saliente}


## Que hace el plantel con un puesto que no tapo nadie.
##
## El hueco NO se deja en el once. El motor reparte por SLOT —el slot `i`
## de la formacion lo ocupa jugadores[i], ver MotorEspacial— asi que sacar
## al del medio le correria el puesto a todos los que siguen y el equipo
## saldria parado en una formacion que nadie eligio. Entonces:
##
##   - Si el que se fue estaba en el banco, el banco se achica y listo: es
##     una lista sin slots.
##   - Si era titular, lo tapa alguien del banco (del mismo puesto si hay)
##     y el hueco baja al banco.
##   - Solo con el banco tambien vacio se achica el once, y ahi el ULTIMO
##     titular tapa el slot vacante para que el array se recorte por el
##     final y nadie mas cambie de puesto.
static func _dejar_hueco(equipo: Team, idx: int, en_banco: bool,
		posicion: String) -> Dictionary:
	if en_banco:
		equipo.banco.remove_at(idx)
		return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": {}}

	var mejor := -1
	for i in range(equipo.banco.size()):
		var en_puesto: bool = str(equipo.banco[i]["posicion"]) == posicion
		if mejor == -1:
			mejor = i
			continue
		var mejor_en_puesto: bool = str(equipo.banco[mejor]["posicion"]) == posicion
		if en_puesto != mejor_en_puesto:
			if en_puesto:
				mejor = i
		elif float(equipo.banco[i]["media"]) > float(equipo.banco[mejor]["media"]):
			mejor = i

	if mejor != -1:
		var sube: Dictionary = equipo.banco[mejor]
		equipo.jugadores[idx] = sube
		equipo.banco.remove_at(mejor)
		return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": sube}

	var ultimo: int = equipo.jugadores.size() - 1
	if ultimo > idx:
		equipo.jugadores[idx] = equipo.jugadores[ultimo]
	if ultimo >= 0:
		equipo.jugadores.remove_at(ultimo)
	return {"jugador": {}, "de_cantera": false, "hueco": true, "sube": {}}
