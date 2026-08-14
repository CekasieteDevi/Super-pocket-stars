class_name Penales
extends RefCounted

## Definición por penales (§8.7) — mejor de 5 por equipo y después muerte
## súbita de a uno, como cualquier eliminación directa real, cortando en
## cuanto el resultado ya está decidido matemáticamente (no hace falta
## patear los 5 si el resultado ya no puede cambiar). No usa el motor de
## posesión/zona del partido (un penal es un tiro fijo, no una jugada
## armada): cada uno es un duelo simple entre el tiro del pateador y los
## reflejos+estirada del arquero rival.

const RONDA_REGULAR := 5


## Probabilidad de convertir: parte de una base realista (~78% en fútbol
## profesional) y se mueve según qué tan por encima o debajo del arquero
## está el tiro del pateador. §5: si el arquero tiene Atajapenales
## manifestada, le resta directo a esa chance — es la única habilidad que
## no engancha en el bloque D genérico del duelo (Habilidades.gd), porque
## Penales no pasa por el motor de posesión/duelos normal. Mismo motivo
## para Pícaro/Clutch/Frágil mental del pateador (Personalidad.bonus_penal).
static func _chance_gol(pateador: Dictionary, arquero: Dictionary) -> float:
	var tiro: float = pateador["atributos"]["tiro"]
	var arquero_valor: float = arquero["atributos"]["reflejos"] * 0.6 + arquero["atributos"]["estirada"] * 0.4
	var chance: float = 0.78 + (tiro - arquero_valor) / 250.0
	chance -= Habilidades.bonus_atajapenales(arquero)
	chance += Personalidad.bonus_penal(pateador)
	return clamp(chance, 0.45, 0.95)


static func patear(pateador: Dictionary, arquero: Dictionary, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < _chance_gol(pateador, arquero)


## Los mejores pateadores primero (mayor "tiro"). Nunca queda vacío: con
## el plantel de 25 siempre hay al menos un jugador disponible; si hiciera
## falta patear más veces que pateadores hay, se repite la lista (módulo).
static func _orden_pateadores(equipo: Team) -> Array:
	var disponibles: Array = equipo.jugadores_disponibles_por_posiciones(["DFC", "LAT", "MC", "MCO", "EXT", "DC"])
	if disponibles.is_empty():
		disponibles = equipo.todos_los_jugadores()
	var ordenados := disponibles.duplicate()
	ordenados.sort_custom(func(a, b): return a["atributos"]["tiro"] > b["atributos"]["tiro"])
	return ordenados


static func _decidido(goles_a: int, goles_b: int, restantes_a: int, restantes_b: int) -> bool:
	return goles_a > goles_b + restantes_b or goles_b > goles_a + restantes_a


## Devuelve {"ganador":Team, "goles_local":int, "goles_visitante":int, "tandas":Array}.
## "tandas" es la secuencia de patadas, para poder animarla o loguearla:
## [{"equipo":String, "jugador_posicion":String, "gol":bool}, ...]
static func definir(home: Team, away: Team, rng: RandomNumberGenerator) -> Dictionary:
	var pateadores_home := _orden_pateadores(home)
	var pateadores_away := _orden_pateadores(away)
	var arquero_home := home.arquero()
	var arquero_away := away.arquero()

	var goles_home := 0
	var goles_away := 0
	var pateos_home := 0
	var pateos_away := 0
	var tandas := []

	while pateos_home < RONDA_REGULAR or pateos_away < RONDA_REGULAR:
		if pateos_home < RONDA_REGULAR:
			var pateador: Dictionary = pateadores_home[pateos_home % pateadores_home.size()]
			var gol := patear(pateador, arquero_away, rng)
			if gol:
				goles_home += 1
			pateos_home += 1
			tandas.append({"equipo": home.nombre, "jugador_posicion": pateador["posicion"], "gol": gol})
			if _decidido(goles_home, goles_away, RONDA_REGULAR - pateos_home, RONDA_REGULAR - pateos_away):
				break

		if pateos_away < RONDA_REGULAR:
			var pateador_v: Dictionary = pateadores_away[pateos_away % pateadores_away.size()]
			var gol_v := patear(pateador_v, arquero_home, rng)
			if gol_v:
				goles_away += 1
			pateos_away += 1
			tandas.append({"equipo": away.nombre, "jugador_posicion": pateador_v["posicion"], "gol": gol_v})
			if _decidido(goles_home, goles_away, RONDA_REGULAR - pateos_home, RONDA_REGULAR - pateos_away):
				break

	var ronda_extra := 0
	while goles_home == goles_away:
		var idx_home := (pateos_home + ronda_extra) % pateadores_home.size()
		var pateador_h: Dictionary = pateadores_home[idx_home]
		var gol_h := patear(pateador_h, arquero_away, rng)
		if gol_h:
			goles_home += 1
		tandas.append({"equipo": home.nombre, "jugador_posicion": pateador_h["posicion"], "gol": gol_h})

		var idx_away := (pateos_away + ronda_extra) % pateadores_away.size()
		var pateador_a: Dictionary = pateadores_away[idx_away]
		var gol_a := patear(pateador_a, arquero_home, rng)
		if gol_a:
			goles_away += 1
		tandas.append({"equipo": away.nombre, "jugador_posicion": pateador_a["posicion"], "gol": gol_a})

		ronda_extra += 1

	var ganador: Team = home if goles_home > goles_away else away
	return {"ganador": ganador, "goles_local": goles_home, "goles_visitante": goles_away, "tandas": tandas}
