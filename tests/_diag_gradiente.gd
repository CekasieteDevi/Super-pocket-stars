extends SceneTree

## Que media da cada potencial_objetivo. Sirve para saber si el gradiente
## que se pide por division es alcanzable con el generador actual.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	print("pot_objetivo | media once | media banco | potencial real")
	for pot in [40, 50, 60, 70, 80, 90, 95, 99]:
		var once := 0.0
		var banco := 0.0
		var p := 0.0
		var n := 0.0
		for k in range(20):
			var t := Team.generar("C%d_%d" % [pot, k], rng, k * 1000, pot)
			for j in t.jugadores:
				once += float(j["media"])
				p += float(j["potencial"])
			for j in t.banco:
				banco += float(j["media"])
			n += 1.0
		print("%12d | %10.1f | %11.1f | %14.1f" % [
			pot, once / n / 11.0, banco / n / 7.0, p / n / 11.0])
	quit()
