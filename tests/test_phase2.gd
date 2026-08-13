extends SceneTree

## Fase 2 del roadmap (GDD §13): motor de duelo y de partido, sin gráficos.
## Correr con: godot --headless --script tests/test_phase2.gd
##
## Qué verificamos:
##   1. Curva de goles por partido creíble (no todo 0-0 ni goleadas absurdas).
##   2. Ventaja de local: el mismo equipo gana más de local que de visitante.
##   3. El equipo favorito (media más alta) le gana al débil más de la mitad de las veces.

const SEED := 4141


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_distribucion_general(rng)
	_test_ventaja_local(rng)
	_test_favorito_gana_mas(rng)
	_test_log_de_muestra(rng)

	quit()


func _test_distribucion_general(rng: RandomNumberGenerator) -> void:
	var n := 1000
	print("\n=== %d partidos entre equipos parejos generados al azar ===" % n)
	var total_goles := 0
	var resultados := {"local": 0, "empate": 0, "visitante": 0}
	var marcadores := {}

	for i in range(n):
		var home := Team.generar("Local", rng)
		var away := Team.generar("Visitante", rng)
		var r := MatchEngine.simular(home, away, rng, false)
		total_goles += r["goles_local"] + r["goles_visitante"]
		if r["goles_local"] > r["goles_visitante"]:
			resultados["local"] += 1
		elif r["goles_local"] < r["goles_visitante"]:
			resultados["visitante"] += 1
		else:
			resultados["empate"] += 1
		var marcador := "%d-%d" % [r["goles_local"], r["goles_visitante"]]
		marcadores[marcador] = marcadores.get(marcador, 0) + 1

	print("Promedio de goles por partido: %.2f" % (float(total_goles) / n))
	print("Local %d%% | Empate %d%% | Visitante %d%%" % [
		100 * resultados["local"] / n,
		100 * resultados["empate"] / n,
		100 * resultados["visitante"] / n,
	])

	var claves := marcadores.keys()
	claves.sort_custom(func(a, b): return marcadores[a] > marcadores[b])
	print("Marcadores mas comunes:")
	for i in range(min(8, claves.size())):
		var m = claves[i]
		print("  %s : %d" % [m, marcadores[m]])


func _test_ventaja_local(rng: RandomNumberGenerator) -> void:
	var n := 500
	print("\n=== Ventaja de local (mismos dos equipos, %d partidos alternando local) ===" % n)
	var equipo_a := Team.generar("Equipo A", rng)
	var equipo_b := Team.generar("Equipo B", rng)
	var gana_a_local := 0
	var gana_a_visitante := 0

	for i in range(n):
		var r1 := MatchEngine.simular(equipo_a, equipo_b, rng, false)
		if r1["goles_local"] > r1["goles_visitante"]:
			gana_a_local += 1
		var r2 := MatchEngine.simular(equipo_b, equipo_a, rng, false)
		if r2["goles_visitante"] > r2["goles_local"]:
			gana_a_visitante += 1

	print("A de local le gana a B: %d/%d (%.1f%%)" % [gana_a_local, n, 100.0 * gana_a_local / n])
	print("A de visitante le gana a B: %d/%d (%.1f%%)" % [gana_a_visitante, n, 100.0 * gana_a_visitante / n])


func _test_favorito_gana_mas(rng: RandomNumberGenerator) -> void:
	print("\n=== Favorito vs equipo debil (mejor y peor de 5 candidatos, 300 partidos) ===")
	var mejor: Team = null
	var peor: Team = null

	for i in range(5):
		var candidato := Team.generar("Candidato", rng)
		if mejor == null or candidato.media_equipo() > mejor.media_equipo():
			mejor = candidato
		if peor == null or candidato.media_equipo() < peor.media_equipo():
			peor = candidato

	print("Media favorito: %.1f | Media debil: %.1f" % [mejor.media_equipo(), peor.media_equipo()])

	var n := 300
	var gana_favorito := 0
	var empatan := 0

	for i in range(n):
		var r := MatchEngine.simular(mejor, peor, rng, false)
		if r["goles_local"] > r["goles_visitante"]:
			gana_favorito += 1
		elif r["goles_local"] == r["goles_visitante"]:
			empatan += 1

	print("El favorito gana %d/%d (%.1f%%), empata %d" % [gana_favorito, n, 100.0 * gana_favorito / n, empatan])


func _test_log_de_muestra(rng: RandomNumberGenerator) -> void:
	print("\n=== Log de un partido de muestra (solo tiros a puerta y goles) ===")
	var home := Team.generar("Nacional de Muestra", rng)
	var away := Team.generar("Rival de Muestra", rng)
	var r := MatchEngine.simular(home, away, rng, true)
	print("Resultado final: %d - %d" % [r["goles_local"], r["goles_visitante"]])
	for entry in r["log"]:
		if entry.find("GOL") != -1 or entry.find("TIRO A PUERTA") != -1 or entry.find("REBOTE") != -1:
			print(entry)
