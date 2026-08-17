extends SceneTree

## ¿El bloqueo depende de los atributos? Enfrenta rematadores y defensores
## de distinto nivel y mide que fraccion de los remates termina bloqueada.

const N := 25

func _init() -> void:
	print("Remates bloqueados, segun nivel del que patea y del que defiende:")
	print("(un delantero de elite no deberia ser tapado casi nunca por un defensa flojo)\n")
	print("            defensa 30   defensa 55   defensa 85")
	for tiro in [30, 60, 90]:
		var fila := "  tiro %2d " % tiro
		for defensa in [30, 55, 85]:
			fila += "     %5.0f%%" % _medir(tiro, defensa)
		print(fila)
	quit()


func _medir(tiro: int, defensa: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987
	var bloqueados := 0
	var total := 0
	for i in range(N):
		var h := Team.generar("H%d" % i, rng)
		var a := Team.generar("A%d" % i, rng, 1000)
		for j in h.todos_los_jugadores():
			j["atributos"]["tiro"] = tiro
		for j in a.todos_los_jugadores():
			j["atributos"]["barrida"] = defensa
			j["atributos"]["agilidad"] = defensa
		var r := MotorEspacial.simular(h, a, rng, false)
		for ev in r["eventos"]:
			if ev["equipo"] != h.nombre:
				continue
			if ev["tipo"] == "tiro" and ev["resultado"] == "bloqueado":
				bloqueados += 1
				total += 1
			elif ev["tipo"] == "tiro" or ev["tipo"] == "tiro_puerta":
				total += 1
	return float(bloqueados) / maxf(total, 1) * 100.0
