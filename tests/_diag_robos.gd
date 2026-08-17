extends SceneTree

## ¿Que pasa despues de un quite? ¿El que la perdio la vuelve a disputar
## enseguida y se arma un loop, o el juego sigue?

const N := 20

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31416
	var div := {}
	var robos := 0
	var ganados := 0
	for i in range(N):
		var h := Team.generar("H%d" % i, rng)
		var a := Team.generar("A%d" % i, rng, 1000)
		var r := MotorEspacial.simular(h, a, rng, false)
		var s: Dictionary = r["stats"]
		robos += int(s["robos"]["intentos"])
		ganados += int(s["robos"]["ganados"])
		for k in s["divididas"]:
			div[k] = div.get(k, 0) + int(s["divididas"][k])

	print("Quites intentados por partido: %.1f" % (float(robos) / N))
	print("Quites ganados (pelota dividida) por partido: %.1f" % (float(ganados) / N))
	print("Cooldown entre disputas: %d ticks = %.1f seg de juego" % [
		int(MotorEspacial.pesos()["fisica"]["ticks_cooldown_robo"]),
		int(MotorEspacial.pesos()["fisica"]["ticks_cooldown_robo"]) * MotorEspacial.TICK_SEG])
	var total := 0
	for k in div:
		total += int(div[k])
	print("\nQuien termina quedandose la pelota dividida:")
	for k in div:
		print("  %s: %.1f por partido (%.0f%%)" % [k, float(div[k]) / N, float(div[k]) / total * 100.0])
	quit()
