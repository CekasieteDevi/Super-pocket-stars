extends SceneTree

## §7.1: cuánto rinde cada puesto en una temporada de la pirámide. Es la
## referencia contra la que Progresion mide si un jugador rindió por
## encima o por debajo de lo esperable para su puesto.

const SEED := 777


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	# Con avanzar_dias, como en el juego: sin eso nadie se cura, los
	# planteles de 18 no llegan al mínimo y medio fixture termina 0-3.
	for liga in piramide.divisiones:
		for fecha in range(liga.fixture.size()):
			liga.jugar_fecha(fecha, rng)
			liga.avanzar_dias(7)
	var por_puesto := {}
	var partidos := []
	for liga in piramide.divisiones:
		for e in liga.equipos:
			for j in e.todos_los_jugadores():
				var rend: Dictionary = j.get("rendimiento", {})
				var p := float(rend.get("partidos", 0.0))
				partidos.append(p)
				if p < 10.0:
					continue
				var pos: String = j["posicion"]
				if not por_puesto.has(pos):
					por_puesto[pos] = []
				por_puesto[pos].append([float(rend["goles"]) / p, float(rend["asistencias"]) / p,
					float(rend["en_contra"]) / p, (float(rend["a_favor"]) - float(rend["en_contra"])) / p])
	print("puesto | n | goles/p (media, desvio) | asist/p | en_contra/p | dif/p")
	for pos in por_puesto:
		var filas: Array = por_puesto[pos]
		var linea := "%s | %d" % [pos, filas.size()]
		for k in range(4):
			var s := 0.0
			var s2 := 0.0
			for f in filas:
				s += f[k]
				s2 += f[k] * f[k]
			var m := s / filas.size()
			linea += " | %.3f (%.3f)" % [m, sqrt(maxf(s2 / filas.size() - m * m, 0.0))]
		print(linea)
	partidos.sort()
	print("partidos jugados: p10 %.1f  p50 %.1f  p75 %.1f  p90 %.1f  max %.1f" % [
		partidos[int(partidos.size() * 0.1)], partidos[int(partidos.size() * 0.5)],
		partidos[int(partidos.size() * 0.75)], partidos[int(partidos.size() * 0.9)], partidos[-1]])
	quit()
