class_name Mercado
extends RefCounted

## Mercado de pases — Fase 6 (GDD §9.3), simplificado. Sin plantel de 25
## todavía (eso es fase 14) no hay banco ni agentes libres: cada club tiene
## exactamente 11 titulares fijos, así que un fichaje acá es un
## INTERCAMBIO directo entre dos clubes en la misma posición, pagando el
## club que recibe el jugador mejor la diferencia de valor de mercado. No es
## la cadena de reemplazo completa del GDD (esa necesita plantilla con
## suplentes) pero ya usa presupuesto, valor de mercado y contratos reales.

const UMBRAL_DIFERENCIA_MEDIA := 8.0
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

		if mejor_jugador["media"] - peor_jugador["media"] < UMBRAL_DIFERENCIA_MEDIA:
			continue

		var valor_mejor := ValorJugador.calcular(mejor_jugador, mejor_club.animo.get(mejor_jugador["id"], 50.0), mejor_club.contratos.get(mejor_jugador["id"], 1))
		var valor_peor := ValorJugador.calcular(peor_jugador, peor_club.animo.get(peor_jugador["id"], 50.0), peor_club.contratos.get(peor_jugador["id"], 1))
		var diferencia: float = max(0.0, valor_mejor - valor_peor)

		if peor_club.caja["fichajes"] < diferencia:
			continue

		peor_club.caja["fichajes"] -= diferencia
		mejor_club.caja["fichajes"] += diferencia

		peor_club.jugadores[peor_indice] = mejor_jugador
		mejor_club.jugadores[mejor_indice] = peor_jugador
		_reasentar(mejor_jugador, mejor_club, peor_club, valor_mejor)
		_reasentar(peor_jugador, peor_club, mejor_club, valor_peor)
		peor_club.recalcular_capitan()
		mejor_club.recalcular_capitan()

		transferencias.append({
			"jugador_id": mejor_jugador["id"], "posicion": posicion,
			"de": mejor_club.nombre, "a": peor_club.nombre, "valor": valor_mejor,
		})

	return transferencias


static func _indice_en_posicion(equipo: Team, posicion: String, rng: RandomNumberGenerator) -> int:
	var candidatos := []
	for i in range(equipo.jugadores.size()):
		if equipo.jugadores[i]["posicion"] == posicion:
			candidatos.append(i)
	if candidatos.is_empty():
		return -1
	return candidatos[rng.randi() % candidatos.size()]


## Actualiza el estado ligado al club (sueldo/contrato/ánimo/fatiga/lesión)
## cuando un jugador pasa de origen a destino.
static func _reasentar(jugador: Dictionary, origen: Team, destino: Team, valor: float) -> void:
	var id: int = jugador["id"]
	origen.sueldos.erase(id)
	origen.contratos.erase(id)
	origen.animo.erase(id)
	origen.fatiga_acumulada.erase(id)
	origen.lesiones.erase(id)

	destino.sueldos[id] = Economia.sueldo_sugerido(valor)
	destino.contratos[id] = 3
	destino.animo[id] = 50.0
	destino.fatiga_acumulada[id] = 1.0
