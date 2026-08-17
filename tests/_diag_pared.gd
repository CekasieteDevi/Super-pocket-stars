extends SceneTree

## ¿La pared depende de `pases`? Mide cuantas se intentan y que fraccion
## completa el circuito (el muro la recibe y la devuelve).

const N := 25

func _init() -> void:
	var f: Dictionary = MotorEspacial.pesos()["fisica"]
	print("Paredes segun el `pases` del equipo (umbral: %d)\n" % int(f["pases_minimo_pared"]))
	print("  pases | intentos/partido | muro alcanzado | muro a %.0f-%.0fm | carrera %.0f-%.0fm" % [
		f["pared_muro_cerca"], f["pared_muro_lejos"], f["pared_avance_min"], f["pared_avance_max"]])
	for pases in [25, 40, 60, 90]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 8181
		var intentos := 0
		var ok := 0
		for i in range(N):
			var h := Team.generar("H%d" % i, rng)
			var a := Team.generar("A%d" % i, rng, 1000)
			for j in h.todos_los_jugadores():
				j["atributos"]["pases"] = pases
			for j in a.todos_los_jugadores():
				j["atributos"]["pases"] = pases
			var r := MotorEspacial.simular(h, a, rng, false)
			var p: Dictionary = r["stats"]["paredes"]
			intentos += int(p.get("intentos", 0))
			ok += int(p.get("muro_ok", 0))
		var falso := {"atributos": {"pases": pases}}
		print("  %5d | %14.1f  | %11.0f%%  | muro %.1fm, carrera %.1fm" % [
			pases, float(intentos) / N, float(ok) / maxf(intentos, 1) * 100.0,
			MotorEspacial._por_atributo(falso, "pases", f["pared_muro_cerca"], f["pared_muro_lejos"]),
			MotorEspacial._por_atributo(falso, "pases", f["pared_avance_min"], f["pared_avance_max"])])
	quit()
