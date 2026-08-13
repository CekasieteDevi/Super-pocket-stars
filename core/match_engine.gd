class_name MatchEngine
extends RefCounted

## Motor de partido — Fase 2 (GDD §8.8). Cadena de posesiones tick a tick,
## sin ningún nodo de Godot: 1000 partidos deben poder simularse en segundos.
##
## Modificadores conectados en esta fase: local (§8.3, bloque C) y racha de
## acciones exitosas + armonía + capitán (bloque B). El resto de los 37
## modificadores (§8.4) llega cuando existan sus sistemas de origen: clima y
## calendario (fase 7), ánimo/forma de temporada (fase 5), rasgos (fase 9).

const TICKS_POR_MITAD := 90

## Pases consecutivos exitosos que hacen falta para llegar al último tercio.
## Sin esto, con ~50% de éxito por duelo parejo se genera un tiro casi cada
## 2 ticks y el marcador se dispara a números de básquet. Simula la posesión
## sostenida real en vez de un solo pase mágico que atraviesa la cancha.
const AVANCE_REQUERIDO := 3

const GRUPO_POR_ATRIBUTO := {
	"pases": "tecnico", "control": "tecnico", "tiro": "tecnico",
	"quite": "defensivo", "barrida": "defensivo",
}


static func _grupo_de(attr: String) -> String:
	return GRUPO_POR_ATRIBUTO.get(attr, "tecnico")


static func _elegir(jugadores: Array, rng: RandomNumberGenerator) -> Dictionary:
	return jugadores[rng.randi() % jugadores.size()]


## §8.5: bloque B (equipo/racha/armonía/capitán) y bloque C (local). Los
## bloques A y D quedan en 0 hasta que existan sus datos de origen.
static func _bloques_equipo(equipo: Team, jugador_id: int) -> Dictionary:
	var bloque_b: float = equipo.armonia + clamp(float(equipo.racha), 0.0, 10.0)
	if jugador_id == equipo.capitan_id:
		bloque_b += 2.0
	var bloque_c := 5.0 if equipo.local else 0.0
	return {"B": bloque_b, "C": bloque_c}


static func _duelo(atacante: Dictionary, atacante_attr: String, equipo_atacante: Team,
		defensor: Dictionary, defensor_attr: String, equipo_defensor: Team) -> Dictionary:
	var ata_eff := Duel.atributo_efectivo(
		atacante["atributos"][atacante_attr], _grupo_de(atacante_attr),
		equipo_atacante.resistencia_pct(atacante["id"]))
	var def_eff := Duel.atributo_efectivo(
		defensor["atributos"][defensor_attr], _grupo_de(defensor_attr),
		equipo_defensor.resistencia_pct(defensor["id"]))
	var resultado := Duel.resolver(
		ata_eff, def_eff,
		_bloques_equipo(equipo_atacante, atacante["id"]),
		_bloques_equipo(equipo_defensor, defensor["id"]))
	equipo_atacante.desgastar(atacante["id"], atacante["atributos"]["energia"])
	equipo_defensor.desgastar(defensor["id"], defensor["atributos"]["energia"])
	return resultado


static func simular(home: Team, away: Team, rng: RandomNumberGenerator, con_log: bool = false) -> Dictionary:
	home.reset_partido()
	away.reset_partido()
	home.local = true
	away.local = false

	var log := []
	var goles_log := []

	for mitad in range(2):
		var posesion: Team = home if mitad == 0 else away
		var zona := "build"

		for tick in range(TICKS_POR_MITAD):
			var minuto: int = mitad * 45 + int(tick / (TICKS_POR_MITAD / 45.0)) + 1
			var rival: Team = away if posesion == home else home

			if zona == "build":
				var medios := posesion.jugadores_por_posiciones(["MC", "MCO", "LAT"])
				if medios.is_empty():
					medios = posesion.jugadores
				var marcadores := rival.jugadores_por_posiciones(["DFC", "LAT", "MC"])
				if marcadores.is_empty():
					marcadores = rival.jugadores

				var atacante := _elegir(medios, rng)
				var defensor := _elegir(marcadores, rng)
				var resultado := _duelo(atacante, "pases", posesion, defensor, "quite", rival)
				var exito := Duel.gana_atacante(resultado, rng)

				if con_log:
					log.append("min %d - PASE - %s (pases %d) vs %s (quite %d) -> %.1f%% -> %s" % [
						minuto, atacante["posicion"], atacante["atributos"]["pases"],
						defensor["posicion"], defensor["atributos"]["quite"],
						resultado["final"], "avanza" if exito else "pierde"
					])

				if exito:
					posesion.racha += 1
					posesion.avance += 1
					if posesion.avance >= AVANCE_REQUERIDO:
						posesion.avance = 0
						zona = "final"
				else:
					posesion.racha = 0
					posesion.avance = 0
					posesion = rival
					zona = "build"
			else:
				var ofensivos := posesion.jugadores_por_posiciones(["EXT", "DC", "MCO"])
				if ofensivos.is_empty():
					ofensivos = posesion.jugadores
				var marcadores := rival.jugadores_por_posiciones(["DFC", "LAT"])
				if marcadores.is_empty():
					marcadores = rival.jugadores

				var atacante := _elegir(ofensivos, rng)
				var defensor := _elegir(marcadores, rng)
				var resultado := _duelo(atacante, "control", posesion, defensor, "quite", rival)
				var exito := Duel.gana_atacante(resultado, rng)

				if con_log:
					log.append("min %d - GAMBETA - %s (control %d) vs %s (quite %d) -> %.1f%% -> %s" % [
						minuto, atacante["posicion"], atacante["atributos"]["control"],
						defensor["posicion"], defensor["atributos"]["quite"],
						resultado["final"], "tira" if exito else "pierde"
					])

				if exito:
					var tiro := _resolver_tiro(posesion, rival, atacante, rng, con_log, log, minuto)
					if tiro["gol"]:
						posesion.goles += 1
						if con_log:
							goles_log.append({"minuto": minuto, "equipo": posesion.nombre, "jugador_id": atacante["id"]})
					posesion.racha = 0
					posesion = rival
					zona = "build"
				else:
					posesion.racha = 0
					posesion = rival
					zona = "build"

	return {
		"goles_local": home.goles,
		"goles_visitante": away.goles,
		"log": log,
		"goles_log": goles_log,
	}


## §8.2: destino del tiro, duelo contra el arquero, y rebote si ataja sin agarrar.
static func _resolver_tiro(equipo_atacante: Team, equipo_defensor: Team, atacante: Dictionary,
		rng: RandomNumberGenerator, con_log: bool, log: Array, minuto: int) -> Dictionary:
	var arquero := equipo_defensor.arquero()
	var tiro: int = atacante["atributos"]["tiro"]
	var destino := _resolver_destino(tiro, rng)

	if destino != "porteria":
		if con_log:
			log.append("min %d - TIRO - %s (tiro %d) -> %s" % [minuto, atacante["posicion"], tiro, destino])
		return {"gol": false, "destino": destino}

	var arquero_attrs = arquero["atributos"]
	var arquero_valor: float = arquero_attrs["reflejos"] * 0.5 + arquero_attrs["estirada"] * 0.3 + arquero_attrs["agarre"] * 0.2
	var resultado := _duelo_tiro(atacante, float(tiro), equipo_atacante, arquero, arquero_valor, equipo_defensor)
	var gol := Duel.gana_atacante(resultado, rng)

	if con_log:
		log.append("min %d - TIRO A PUERTA - %s (tiro %d) vs Arq. (%.1f) -> %.1f%% -> %s" % [
			minuto, atacante["posicion"], tiro, arquero_valor, resultado["final"],
			"GOL" if gol else "ATAJADA"
		])

	if gol:
		return {"gol": true, "destino": destino}

	var chance_rebote: float = clamp(1.0 - float(arquero_attrs["agarre"]) / 100.0, 0.1, 0.7)
	if rng.randf() < chance_rebote:
		var rebotadores := equipo_atacante.jugadores_por_posiciones(["DC", "EXT", "MCO"])
		if rebotadores.is_empty():
			rebotadores = equipo_atacante.jugadores
		var rematador := _elegir(rebotadores, rng)
		var tiro_rebote: float = float(rematador["atributos"]["tiro"]) * 0.8
		var resultado_rebote := _duelo_tiro(rematador, tiro_rebote, equipo_atacante, arquero, arquero_valor * 0.9, equipo_defensor)
		var gol_rebote := Duel.gana_atacante(resultado_rebote, rng)
		if con_log:
			log.append("min %d - REBOTE - %s (tiro %.0f) -> %.1f%% -> %s" % [
				minuto, rematador["posicion"], tiro_rebote, resultado_rebote["final"],
				"GOL" if gol_rebote else "ATAJADA"
			])
		return {"gol": gol_rebote, "destino": "porteria"}

	return {"gol": false, "destino": destino}


static func _duelo_tiro(atacante: Dictionary, tiro_valor: float, equipo_atacante: Team,
		arquero: Dictionary, arquero_valor: float, equipo_defensor: Team) -> Dictionary:
	var ata_eff := Duel.atributo_efectivo(tiro_valor, "tecnico", equipo_atacante.resistencia_pct(atacante["id"]))
	var def_eff := Duel.atributo_efectivo(arquero_valor, "tecnico", equipo_defensor.resistencia_pct(arquero["id"]))
	var resultado := Duel.resolver(
		ata_eff, def_eff,
		_bloques_equipo(equipo_atacante, atacante["id"]),
		_bloques_equipo(equipo_defensor, arquero["id"]))
	equipo_atacante.desgastar(atacante["id"], atacante["atributos"]["energia"])
	equipo_defensor.desgastar(arquero["id"], arquero["atributos"]["energia"])
	return resultado


## §8.2 punto 1: a mayor tiro, más chance de ir a puerta; el palo escala con
## la precisión, "afuera" baja cuanto mejor es el rematador.
static func _resolver_destino(tiro: int, rng: RandomNumberGenerator) -> String:
	var t: float = clamp(tiro, 0, 100) / 100.0
	var chance_palo: float = 0.05 * t
	var chance_afuera: float = clamp(0.6 - 0.45 * t, 0.08, 0.6)
	var chance_porteria: float = max(0.0, 1.0 - chance_palo - chance_afuera)

	var roll := rng.randf()
	if roll < chance_porteria:
		return "porteria"
	elif roll < chance_porteria + chance_palo:
		return "palo"
	return "afuera"
