extends SceneTree

## Que porcentaje de los goles lleva asistencia en cada motor. Los dos
## tienen que dar parecido: si no, el goleador de la liga y el asistidor
## de la liga dependen de con que motor se jugo cada partido.

const SEED := 771
const PARTIDOS := 30


func _init() -> void:
	for motor in ["espacial", "abstracto"]:
		var goles := 0
		var con_asist := 0
		var por_puesto := {}
		for i in range(PARTIDOS):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i
			var casa := Team.generar("Casa", rng, 0)
			var visita := Team.generar("Visita", rng, 400)
			var r: Dictionary
			if motor == "espacial":
				r = MotorEspacial.simular(casa, visita, rng, false)
			else:
				r = MatchEngine.simular(casa, visita, rng, false)
			for g in r["goles_log"]:
				goles += 1
				var a := int(g.get("asistencia_id", -1))
				if a >= 0:
					con_asist += 1
					var eq: Team = casa if str(g["equipo"]) == casa.nombre else visita
					for j in eq.jugadores + eq.banco:
						if int(j["id"]) == a:
							por_puesto[j["posicion"]] = int(por_puesto.get(j["posicion"], 0)) + 1
							break
		print("%s: %d goles, %d con asistencia (%.0f%%)" % [
			motor, goles, con_asist, 100.0 * con_asist / maxi(goles, 1)])
		var puestos := por_puesto.keys()
		puestos.sort_custom(func(a, b): return por_puesto[a] > por_puesto[b])
		var partes := []
		for p in puestos:
			partes.append("%s %d" % [p, por_puesto[p]])
		print("   asistencias por puesto: %s" % ", ".join(partes))
	quit()
