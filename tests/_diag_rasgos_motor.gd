extends SceneTree

## Mide en partidos REALES los tres rasgos que desbloqueo el motor
## espacial. Cada uno se compara contra el mismo plantel sin el rasgo
## —mismos jugadores, misma semilla, mismo rival— asi que la diferencia
## sale del rasgo y no del ruido de generacion.
##
## Los tests de tests/test_personalidad_partido.gd verifican el mecanismo;
## esto verifica que el mecanismo se NOTA en un partido completo, que es
## otra cosa.

const PARTIDOS := 120


func _init() -> void:
	_medir("Enfocado", "positiva")
	_medir("Metodico", "positiva")
	_medir("Pie preferido", "negativa")
	quit()


func _medir(rasgo: String, ranura: String) -> void:
	print("\n=== %s (%d partidos) ===" % [rasgo, PARTIDOS])
	var offsides := {"con": 0.0, "sin": 0.0}
	# Un rasgo negativo que no cuesta nada no es un rasgo: los goles son
	# la prueba de que el sesgo de decision se paga en algun lado.
	var goles := {"con": 0.0, "sin": 0.0}
	var decisiones := {"con": {}, "sin": {}}
	for i in range(PARTIDOS):
		for lado in ["con", "sin"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4000 + i
			var a := Team.generar("A", rng, 60)
			var b := Team.generar("B", rng, 60)
			if lado == "con":
				for j in a.todos_los_jugadores():
					j["personalidades"] = {"positiva": "", "negativa": ""}
					j["personalidades"][ranura] = rasgo
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 4000 + i
			var r := MotorEspacial.simular(a, b, rng2, false)
			offsides[lado] += float(r["stats"].get("offsides", 0))
			goles[lado] += float(r["goles_local"])
			for k in r["stats"].get("decisiones", {}):
				decisiones[lado][k] = int(decisiones[lado].get(k, 0)) + int(r["stats"]["decisiones"][k])
	print("  offsides/partido: con %.2f  sin %.2f" % [
		offsides["con"] / PARTIDOS, offsides["sin"] / PARTIDOS])
	print("  goles a favor/partido: con %.2f  sin %.2f" % [
		goles["con"] / PARTIDOS, goles["sin"] / PARTIDOS])
	var tot := {"con": 0, "sin": 0}
	for lado in ["con", "sin"]:
		for k in decisiones[lado]:
			tot[lado] += int(decisiones[lado][k])
	var linea := ""
	for k in ["conducir", "pase", "pase_hueco", "tiro", "centro", "pared"]:
		linea += "%s %.1f/%.1f  " % [k,
			100.0 * float(decisiones["con"].get(k, 0)) / maxf(tot["con"], 1),
			100.0 * float(decisiones["sin"].get(k, 0)) / maxf(tot["sin"], 1)]
	print("  %% de decisiones (con/sin): %s" % linea)
