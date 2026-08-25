extends SceneTree

## Una lesion solo duele si el reemplazo es peor. Aca se mide el escalon
## real entre once, banco y cantera.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var piramide := Piramide.generar(rng)
	for div in [0, 4, 8]:
		var liga: Liga = piramide.divisiones[div]
		var t := 0.0
		var b := 0.0
		var c := 0.0
		var n := 0.0
		var nc := 0.0
		for e in liga.equipos:
			e.generar_camada(rng, Instalaciones.cantidad_camada(e))
			for j in e.jugadores:
				t += float(j["media"])
			for j in e.banco:
				b += float(j["media"])
			for j in e.cantera:
				c += float(j["media"])
				nc += 1.0
			n += 1.0
		print("division %d | once %.1f | banco %.1f (%+.1f) | cantera %.1f (%+.1f)" % [
			div + 1, t / n / 11.0, b / n / 7.0, b / n / 7.0 - t / n / 11.0,
			c / max(1.0, nc), c / max(1.0, nc) - t / n / 11.0])
	quit()
