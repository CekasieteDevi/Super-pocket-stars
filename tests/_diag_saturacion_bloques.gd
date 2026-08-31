extends SceneTree

## Cuanto se saturan los cuatro bloques del §8.5 en partidos de verdad.
##
## El tope es ±15 (±12 en D). Si un bloque llega al tope seguido, todo lo
## que se le agregue no hace nada — que es lo que le pasa a la quimica
## (§7.4.6) cuando la racha de acciones ya lleno el bloque B.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var muestras := 40
	var cuenta := {"A": 0, "B": 0, "C": 0, "D": 0}
	var saturados := {"A": 0, "B": 0, "C": 0, "D": 0}
	var suma := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}
	var desperdicio := {"A": 0.0, "B": 0.0, "C": 0.0, "D": 0.0}

	for m in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 9000 + m
		var casa := Team.generar("Casa", r, 0)
		var visita := Team.generar("Visita", r, 100)
		casa.local = true
		# Un once que viene junto, para que la quimica este en juego.
		for _f in range(int(Quimica.PARTIDOS_TOPE)):
			Quimica.despues_de_partido(casa)

		# Se recorren rachas y minutos como los que se dan en un partido.
		for racha in range(0, 11):
			casa.racha = racha
			for minuto in [10, 40, 70, 88]:
				var j: Dictionary = casa.jugadores[(racha + minuto) % casa.jugadores.size()]
				var otro: int = int(casa.jugadores[(racha + 1) % casa.jugadores.size()]["id"])
				var b: Dictionary = MatchEngine._bloques_equipo(
					casa, visita, j, "pases", minuto, r, otro)
				for k in ["A", "B", "C", "D"]:
					var tope: float = 12.0 if k == "D" else 15.0
					var crudo: float = float(b[k])
					cuenta[k] += 1
					suma[k] += absf(crudo)
					if absf(crudo) >= tope:
						saturados[k] += 1
						desperdicio[k] += absf(crudo) - tope

	print("bloque | promedio |vs tope| saturado | pp tirados a la basura por duelo")
	for k in ["A", "B", "C", "D"]:
		var tope: float = 12.0 if k == "D" else 15.0
		print("%6s | %8.2f | %5.0f | %6.1f%% | %.2f" % [
			k, suma[k] / cuenta[k], tope,
			float(saturados[k]) / float(cuenta[k]) * 100.0,
			desperdicio[k] / float(cuenta[k])])
	quit()
