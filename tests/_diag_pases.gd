extends SceneTree

## Distribución de la distancia de pase segun el nivel del plantel. La
## pregunta que contesta: ¿un equipo flojo esta tirando pases de area a
## area? Deberia ser al reves — el alcance sale de `pases` (ver
## max_dist_pase_malo/bueno), asi que un plantel limitado tendria que
## jugar corto y uno bueno abrir la cancha.

const N := 30


func _init() -> void:
	print("nivel | `pases` medio | pases/partido | dist media | mediana | >30m | >40m | max | pelotazos/partido")
	for nivel in [-1, 30, 55, 80]:
		var dists := []
		var attr := 0.0
		var attr_n := 0.0
		var largos_n := 0
		for i in range(N):
			var rng := RandomNumberGenerator.new()
			rng.seed = 555 + i
			var a: Team = Team.generar("A", rng) if nivel < 0 else Team.generar("A", rng, 0, nivel)
			var b: Team = Team.generar("B", rng, 100) if nivel < 0 else Team.generar("B", rng, 100, nivel)
			for j in a.todos_los_jugadores():
				if j["posicion"] != "ARQ":
					attr += float(j["atributos"]["pases"])
					attr_n += 1.0
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 555 + i
			var r := MotorEspacial.simular(a, b, rng2, false)
			dists.append_array(r["stats"]["dist_pases"])
			largos_n += r["stats"]["dist_pelotazos"].size()
		dists.sort()
		var suma := 0.0
		var largos := 0
		var muy_largos := 0
		for d in dists:
			suma += d
			if d > 30.0:
				largos += 1
			if d > 40.0:
				muy_largos += 1
		var n: int = dists.size()
		print("%5s | %13.1f | %13.1f | %10.1f | %7.1f | %3.0f%% | %3.0f%% | %.0f" % [
			"nat" if nivel < 0 else str(nivel), attr / maxf(attr_n, 1), float(n) / N,
			suma / maxf(n, 1), dists[n / 2] if n > 0 else 0.0,
			100.0 * largos / maxf(n, 1), 100.0 * muy_largos / maxf(n, 1),
			dists[n - 1] if n > 0 else 0.0]) ; print("        pelotazos por partido: %.1f" % (float(largos_n) / N))
	quit()
