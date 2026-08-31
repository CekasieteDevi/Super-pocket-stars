extends SceneTree

## Goles por partido de los dos motores, con los MISMOS planteles y las
## mismas semillas. El abstracto resuelve el resto de la liga, asi que es
## contra el que tiene que quedar parado el espacial: si se separan, tu
## liga y la de la IA juegan a deportes distintos.

const SEED := 4400
const PARTIDOS := 40


func _init() -> void:
	print("div | espacial | abstracto")
	for division in [9, 4, 0]:
		var esp := 0
		var abs_ := 0
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
			esp += int(res["goles_local"]) + int(res["goles_visitante"])

			var r3 := RandomNumberGenerator.new()
			r3.seed = SEED + i
			var a2 := Team.generar("A", r3, 0, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var b2 := Team.generar("B", r3, 400, NivelDivision.potencial(division),
				"Uruguay", NivelDivision.realizacion(division))
			var r4 := RandomNumberGenerator.new()
			r4.seed = SEED + i
			var res2 := MatchEngine.simular(a2, b2, r4)
			esp += 0
			abs_ += int(res2["goles_local"]) + int(res2["goles_visitante"])
		print("%3d | %8.2f | %9.2f" % [
			division + 1, float(esp) / PARTIDOS, float(abs_) / PARTIDOS])
	quit()
