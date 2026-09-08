class_name Penales
extends RefCounted

## Definición por penales (§8.7) — mejor de 5 por equipo y después muerte
## súbita de a uno, como cualquier eliminación directa real, cortando en
## cuanto el resultado ya está decidido matemáticamente (no hace falta
## patear los 5 si el resultado ya no puede cambiar). No usa el motor de
## posesión/zona del partido (un penal es un tiro fijo, no una jugada
## armada): cada uno es un duelo simple entre el tiro del pateador y los
## reflejos+estirada del arquero rival.
##
## La tanda entera —la secuencia Y el resultado de cada remate— vive acá y
## es una sola para los dos motores. El motor espacial no la recalcula: le
## pasa a `definir` una Callable con la que PATEA en la cancha cada penal
## ya decidido, para que el jugador lo vea. Si cada motor resolviera el
## remate por su lado no habría paridad: medido, el duelo espacial convierte
## el 96,8% de los penales y el de acá el 84,2%, o sea que el jugador
## definiría sus tandas con chances muy distintas a las de la IA.

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
##
## Es pública porque el motor espacial patea la misma tanda en la cancha y
## tiene que mandar al punto del penal al MISMO jugador que elegiría acá.
static func orden_de_pateo(equipo: Team) -> Array:
	var disponibles: Array = equipo.jugadores_disponibles_por_posiciones(["DFC", "LAT", "MC", "MCO", "EXT", "DC"])
	if disponibles.is_empty():
		disponibles = equipo.todos_los_jugadores()
	var ordenados := disponibles.duplicate()
	ordenados.sort_custom(func(a, b): return a["atributos"]["tiro"] > b["atributos"]["tiro"])
	return ordenados


## El resultado ya no puede cambiar por más que pateen lo que les queda.
static func decidido(goles_a: int, goles_b: int, restantes_a: int, restantes_b: int) -> bool:
	return goles_a > goles_b + restantes_b or goles_b > goles_a + restantes_a


## Devuelve {"ganador":Team, "goles_local":int, "goles_visitante":int, "tandas":Array}.
## "tandas" es la secuencia de patadas, para poder animarla o loguearla:
## [{"equipo":String, "jugador_id":int, "jugador_posicion":String, "gol":bool}, ...]
##
## `al_patear` MIRA cada penal ya resuelto, no lo decide: recibe
## (pateador: Dictionary, arquero: Dictionary, es_local: bool, gol: bool) y
## no devuelve nada. El motor espacial la usa para patearlo en la cancha y
## dejar fotogramas. Vacía (los cruces de la IA) = la tanda se resuelve y
## nadie la mira.
static func definir(home: Team, away: Team, rng: RandomNumberGenerator,
		al_patear: Callable = Callable()) -> Dictionary:
	var pateadores_home := orden_de_pateo(home)
	var pateadores_away := orden_de_pateo(away)
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
			var gol := _resolver(al_patear, pateador, arquero_away, true, rng)
			if gol:
				goles_home += 1
			pateos_home += 1
			tandas.append(_anotar(home, pateador, gol))
			if decidido(goles_home, goles_away, RONDA_REGULAR - pateos_home, RONDA_REGULAR - pateos_away):
				break

		if pateos_away < RONDA_REGULAR:
			var pateador_v: Dictionary = pateadores_away[pateos_away % pateadores_away.size()]
			var gol_v := _resolver(al_patear, pateador_v, arquero_home, false, rng)
			if gol_v:
				goles_away += 1
			pateos_away += 1
			tandas.append(_anotar(away, pateador_v, gol_v))
			if decidido(goles_home, goles_away, RONDA_REGULAR - pateos_home, RONDA_REGULAR - pateos_away):
				break

	var ronda_extra := 0
	while goles_home == goles_away:
		var idx_home := (pateos_home + ronda_extra) % pateadores_home.size()
		var pateador_h: Dictionary = pateadores_home[idx_home]
		var gol_h := _resolver(al_patear, pateador_h, arquero_away, true, rng)
		if gol_h:
			goles_home += 1
		tandas.append(_anotar(home, pateador_h, gol_h))

		var idx_away := (pateos_away + ronda_extra) % pateadores_away.size()
		var pateador_a: Dictionary = pateadores_away[idx_away]
		var gol_a := _resolver(al_patear, pateador_a, arquero_home, false, rng)
		if gol_a:
			goles_away += 1
		tandas.append(_anotar(away, pateador_a, gol_a))

		ronda_extra += 1

	var ganador: Team = home if goles_home > goles_away else away
	return {"ganador": ganador, "goles_local": goles_home, "goles_visitante": goles_away, "tandas": tandas}


static func _resolver(al_patear: Callable, pateador: Dictionary, arquero: Dictionary,
		es_local: bool, rng: RandomNumberGenerator) -> bool:
	var gol := patear(pateador, arquero, rng)
	if al_patear.is_valid():
		al_patear.call(pateador, arquero, es_local, gol)
	return gol


static func _anotar(equipo: Team, pateador: Dictionary, gol: bool) -> Dictionary:
	return {
		"equipo": equipo.nombre,
		"jugador_id": int(pateador["id"]),
		"jugador_posicion": str(pateador["posicion"]),
		"gol": gol,
	}
