extends SceneTree

## Cuantos de los cambios que hace el motor son al ARQUERO, y por que motivo.
## Se corre igual antes y despues del arreglo, con la misma semilla.

const SEED := 4141
const PARTIDOS := 200


func _init() -> void:
	for config in ["descanso", "equilibrado", "rendimiento"]:
		_medir(config)
	quit()


func _medir(config: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var home := Team.generar("Home", rng, 0)
	var away := Team.generar("Away", rng, 100)
	home.config_cambios = config
	away.config_cambios = config

	var cambios := 0
	var arq_cansancio := 0
	var arq_lesion := 0
	var partidos_con_arq := 0

	for i in range(PARTIDOS):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 3000 + i
		var res: Dictionary = MatchEngine.simular(home, away, rng_partido)
		var hubo := false
		for e in res["eventos"]:
			if e["tipo"] != "cambio":
				continue
			cambios += 1
			if e["jugador_posicion"] != "ARQ":
				continue
			hubo = true
			if e["resultado"] == "lesion":
				arq_lesion += 1
			else:
				arq_cansancio += 1
		if hubo:
			partidos_con_arq += 1

	print("%-14s cambios=%4d  arquero: cansancio=%3d lesion=%3d  partidos con cambio de ARQ=%3d/%d" % [
		config, cambios, arq_cansancio, arq_lesion, partidos_con_arq, PARTIDOS])
