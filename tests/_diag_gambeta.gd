extends SceneTree

## ¿La gambeta depende de los atributos? Cruza el control del que encara
## contra el quite del que marca.

const N := 25

func _init() -> void:
	print("Gambetas ganadas, segun control del que encara y quite del que marca:\n")
	print("             quite 30   quite 55   quite 85")
	for control in [30, 60, 90]:
		var fila := "  control %2d " % control
		for quite in [30, 55, 85]:
			var r := _medir(control, quite)
			fila += "   %2.0f%% (%.1f)" % [r[0], r[1]]
		print(fila)
	print("\n(porcentaje ganado, y entre parentesis intentos por partido)")
	quit()


func _medir(control: int, quite: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 313
	var intentos := 0
	var ganadas := 0
	for i in range(N):
		var h := Team.generar("H%d" % i, rng)
		var a := Team.generar("A%d" % i, rng, 1000)
		for j in h.todos_los_jugadores():
			j["atributos"]["control"] = control
			j["atributos"]["agilidad"] = control
		for j in a.todos_los_jugadores():
			j["atributos"]["quite"] = quite
			j["atributos"]["agilidad"] = quite
		var r := MotorEspacial.simular(h, a, rng, false)
		for ev in r["eventos"]:
			if ev["tipo"] == "gambeta" and ev["equipo"] == h.nombre:
				if ev["resultado"] == "pasa":
					ganadas += 1
					intentos += 1
				elif ev["resultado"] == "pierde":
					intentos += 1
	return [float(ganadas) / maxf(intentos, 1) * 100.0, float(intentos) / N]
