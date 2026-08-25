extends SceneTree

## De donde salen los goles de mas en las divisiones altas: mas remates o
## mejor conversion. Equipos parejos, generados con el nivel de cada
## division (NivelDivision), motor espacial.

const N := 40


func _init() -> void:
	print("div | media | goles | remates | conversion | pases ok")
	for d in [9, 6, 3, 0]:
		var g := 0
		var tir := 0
		var pas := 0
		var media := 0.0
		for i in range(N):
			var rng := RandomNumberGenerator.new()
			rng.seed = 3000 + i
			var h := Team.generar("H", rng, 0, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
			var a := Team.generar("A", rng, 1000, NivelDivision.potencial(d), "Uruguay", NivelDivision.realizacion(d))
			media += h.media_equipo()
			var r := MotorEspacial.simular(h, a, rng, false)
			g += int(r["goles_local"]) + int(r["goles_visitante"])
			var st: Dictionary = r["stats"]
			tir += int(st["tiros"]["home"]) + int(st["tiros"]["away"])
			if st.has("pases"):
				pas += int(st["pases"]["home"]) + int(st["pases"]["away"])
		var gg := float(g) / N
		var tt := float(tir) / N
		print("%3d | %5.1f | %5.2f | %7.1f | %9.1f%% | %8.1f" % [
			d + 1, media / N, gg, tt, 100.0 * gg / max(1.0, tt), float(pas) / N])
	quit()
