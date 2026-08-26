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


## Saca a "jugador" del plantel de equipo (venció contrato, la IA decidió no
## renovar) y lo manda al pool. El puesto que deja vacante lo ocupa un
## refuerzo recién generado en su misma posición — un club de la IA no
## puede quedar con un agujero en la formación de un día para el otro; la
## profundidad real que gana el juego es que ese jugador liberado ahora se
## puede fichar gratis desde el pool.
static func liberar(equipo: Team, jugador: Dictionary, pool: Array, rng: RandomNumberGenerator) -> void:
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
		return

	# Del nivel del club: un club de decima no ficha un agente libre de
	# primera (ver Team.nivel_potencial).
	var reemplazo := PlayerGenerator.generate(
		equipo.siguiente_id_cantera, rng, jugador["posicion"], equipo.nivel_potencial())
	equipo.siguiente_id_cantera += 1
	if en_banco:
		equipo.banco[idx] = reemplazo
	else:
		equipo.jugadores[idx] = reemplazo
	equipo.recalcular_capitan()

	equipo._registrar_fichaje(reemplazo, ValorJugador.calcular(reemplazo, 50.0, 2), 2)
	equipo._limpiar_registro(id)
	pool.append(jugador)


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

	pool.remove_at(idx_pool)
	lista[indice_saliente] = agente
	equipo.recalcular_capitan()

	equipo._registrar_fichaje(agente, ValorJugador.calcular(agente, 50.0, CONTRATO_LIBRE_ANIOS), CONTRATO_LIBRE_ANIOS)
	equipo._limpiar_registro(saliente["id"])
	pool.append(saliente)

	return {"exito": true, "entra": agente, "sale": saliente}
