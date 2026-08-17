extends SceneTree

## ¿El pase al hueco depende de la vision del que lo tira? Compara equipos
## identicos salvo por la vision de sus jugadores.

const N := 25

func _init() -> void:
	print("Pases al hueco y su efecto, segun la vision del equipo:")
	print("(el umbral para que la opcion ni aparezca es vision %d)\n" % int(MotorEspacial.pesos()["fisica"]["vision_minima_hueco"]))
	for vision in [25, 45, 65, 90]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 606
		var huecos := 0.0
		var pases := 0.0
		var goles := 0.0
		for i in range(N):
			var h := Team.generar("H%d" % i, rng)
			var a := Team.generar("A%d" % i, rng, 1000)
			for j in h.todos_los_jugadores():
				j["atributos"]["vision"] = vision
			for j in a.todos_los_jugadores():
				j["atributos"]["vision"] = vision
			var r := MotorEspacial.simular(h, a, rng, false)
			var d: Dictionary = r["stats"]["decisiones"]
			huecos += float(d.get("pase_hueco", 0))
			pases += float(d.get("pase", 0))
			goles += float(r["goles_local"]) + float(r["goles_visitante"])
		print("  vision %2d -> %5.1f pases al hueco y %5.1f pases normales por partido | %.2f goles" % [
			vision, huecos / N, pases / N, goles / N])
	quit()
