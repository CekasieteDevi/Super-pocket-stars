extends SceneTree

const SEED := 7310
const REPETICIONES := 150


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var p := Piramide.generar(rng)
	p.jugar_temporada(rng)
	var sube_90 := 0
	var sube_copa := 0
	var definidos_alargue_o_penales := 0
	var total := 0
	for cruce in p.cruces_de_playoff():
		var local: Team = cruce["local"]
		var visitante: Team = cruce["visitante"]
		for i in range(REPETICIONES):
			rng.seed = SEED + i * 31 + int(cruce["limite"])
			var r := MatchEngine.simular(local, visitante, rng, false)
			if r["goles_visitante"] > r["goles_local"]:
				sube_90 += 1
			rng.seed = SEED + i * 31 + int(cruce["limite"])
			var c := Copa.resolver_cruce(local, visitante, rng, false)
			if c["ganador"] == visitante:
				sube_copa += 1
			if str(c["definicion"]) != "90 minutos":
				definidos_alargue_o_penales += 1
			total += 1
	print("cruces=%d  90min(empate=local): sube %.1f%%  |  copa: sube %.1f%%, %.1f%% se define en alargue/penales" % [
		total, 100.0 * sube_90 / total, 100.0 * sube_copa / total,
		100.0 * definidos_alargue_o_penales / total])
	quit()
