extends SceneTree

## Los cuatro bloques del §8.5 medidos DENTRO de una temporada de verdad,
## no en partidos sinteticos.
##
## El diagnostico anterior (_diag_saturacion_bloques) daba A=0.00 y
## C=1.82, que sugeria que dos de los cuatro bloques no se usaban. Pero
## armaba los equipos a mano: sin clima asignado, sin arbitro, sin forma
## del dia, sin lesiones ni amarillas encima. Todo eso lo pone la Liga al
## jugar la fecha, asi que hay que medirlo jugando.

func _init() -> void:
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(4242)

	var cuenta := 0
	var suma := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
	var maximo := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
	var saturados := {"A": 0, "B": 0, "C": 0, "D": 0}
	var no_cero := {"A": 0, "B": 0, "C": 0, "D": 0}

	# Media temporada alcanza: ya hay forma, lesiones, amarillas, rachas y
	# el clima cambia fecha a fecha.
	for fecha in range(20):
		gs.jugar_siguiente_fecha()
		var liga: Liga = gs.liga_jugador()
		for e in liga.equipos:
			var rival: Team = liga.equipos[0] if e != liga.equipos[0] else liga.equipos[1]
			for i in range(e.jugadores.size()):
				var j: Dictionary = e.jugadores[i]
				var companero: int = int(e.jugadores[(i + 1) % e.jugadores.size()]["id"])
				var b: Dictionary = MatchEngine._bloques_equipo(
					e, rival, j, "pases", 45, gs.rng, companero)
				cuenta += 1
				for k in ["A", "B", "C", "D"]:
					var tope: float = 12.0 if k == "D" else 15.0
					var v: float = float(b[k])
					suma[k] += absf(v)
					maximo[k] = maxf(maximo[k], absf(v))
					if absf(v) >= tope:
						saturados[k] += 1
					if absf(v) > 0.01:
						no_cero[k] += 1

	print("Medido en %d duelos de una media temporada real:\n" % cuenta)
	print("bloque | promedio |  pico | tope | saturado | usado (no cero)")
	for k in ["A", "B", "C", "D"]:
		var tope: float = 12.0 if k == "D" else 15.0
		print("%6s | %8.2f | %5.2f | %4.0f | %7.1f%% | %13.1f%%" % [
			k, suma[k] / cuenta, maximo[k], tope,
			float(saturados[k]) / float(cuenta) * 100.0,
			float(no_cero[k]) / float(cuenta) * 100.0])
	gs.free()
	quit()
