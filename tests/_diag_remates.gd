extends SceneTree

## Una linea por division: cuantos goles, cuantos remates y desde donde.
## Es el diagnostico corto para barrer pesos de tiro_resolucion.

const SEED := 4400
const PARTIDOS := 30


func _init() -> void:
	print("div | goles | remates | >20m | >25m | al arco | conversion | dist p50/p90")
	for division in [9, 4, 0]:
		_medir(division)
	quit()


func _medir(division: int) -> void:
	var tiros := []
	var goles := 0
	var al_arco := 0
	for i in range(PARTIDOS):
		var r1 := RandomNumberGenerator.new()
		r1.seed = SEED + i
		var a := Team.generar("A", r1, 0, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var b := Team.generar("B", r1, 400, NivelDivision.potencial(division),
			"Uruguay", NivelDivision.realizacion(division))
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + i
		var res := MotorEspacial.simular(a, b, r2, false)
		goles += int(res["goles_local"]) + int(res["goles_visitante"])
		for ev in res["eventos"]:
			if str(ev.get("tipo", "")) == "tiro_puerta":
				al_arco += 1
		tiros.append_array(res["stats"]["dist_tiros"])

	var n: int = maxi(tiros.size(), 1)
	var largos := 0
	var muy_largos := 0
	for d in tiros:
		if float(d) > 20.0:
			largos += 1
		if float(d) > 25.0:
			muy_largos += 1
	var orden := tiros.duplicate()
	orden.sort()
	print("%3d | %5.2f | %7.1f | %3.0f%% | %3.0f%% | %6.0f%% | %9.1f%% | %.0f/%.0f" % [
		division + 1, float(goles) / PARTIDOS, float(tiros.size()) / PARTIDOS,
		100.0 * largos / n, 100.0 * muy_largos / n,
		100.0 * al_arco / n, 100.0 * goles / n,
		float(orden[int(n * 0.5)]), float(orden[int(n * 0.9)])])
