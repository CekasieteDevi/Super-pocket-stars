extends SceneTree

## ¿Los centros dependen de los atributos aereos? Cruza cabezazo/salto del
## que ataca contra salto/fuerza del que defiende.

const N := 25

func _init() -> void:
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = 1
	var h0 := Team.generar("X", rng0)
	var r0 := MotorEspacial.simular(h0, Team.generar("Y", rng0, 1000), rng0, false)
	print("Reparto de un centro que cae al area: %s\n" % str(r0["stats"]["centros"]))

	print("Duelos aereos ganados por el que ataca:\n")
	print("            def 30    def 60    def 90")
	for aereo in [30, 60, 90]:
		var fila := "  ata %2d " % aereo
		for defensa in [30, 60, 90]:
			fila += "     %4.0f%%" % _medir(aereo, defensa)
		print(fila)
	quit()


func _medir(aereo: int, defensa: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var ganados := 0
	var total := 0
	for i in range(N):
		var h := Team.generar("H%d" % i, rng)
		var a := Team.generar("A%d" % i, rng, 1000)
		for j in h.todos_los_jugadores():
			j["atributos"]["cabezazo"] = aereo
			j["atributos"]["salto"] = aereo
			j["atributos"]["centros"] = 70
		for j in a.todos_los_jugadores():
			j["atributos"]["salto"] = defensa
			j["atributos"]["fuerza"] = defensa
			j["atributos"]["cabezazo"] = defensa
		var r := MotorEspacial.simular(h, a, rng, false)
		for ev in r["eventos"]:
			if ev["tipo"] == "centro" and ev["equipo"] == h.nombre:
				if ev["resultado"] == "gana":
					ganados += 1
					total += 1
				elif ev["resultado"] == "despeja":
					total += 1
	return float(ganados) / maxf(total, 1) * 100.0
