extends SceneTree

## Que nivel de instalacion se paga con UNA temporada del presupuesto de
## Mejoras de cada division. El objetivo: el nivel N alcanzable en la
## division 11-N, o sea una mejora por temporada en cualquier escalon.

const SEED := 777

func _init() -> void:
	print("nivel | costo de subir")
	for n in range(1, Instalaciones.NIVEL_MAXIMO):
		print("%d->%d | %s" % [n, n + 1,
			Economia.formato_dinero(Instalaciones.costo_siguiente_nivel(n))])

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	print("\ndiv | mejoras/temporada | nivel mas alto que paga en una temporada")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var neto := 0.0
		for i in range(n):
			neto += float(Economia.procesar_temporada(liga.equipos[i], i + 1, n, d)["neto"])
		var mejoras: float = (neto / n) * Economia.PRESUPUESTO_PORCENTAJES["mejoras"]
		var alcanza := 1
		for nivel in range(1, Instalaciones.NIVEL_MAXIMO):
			if Instalaciones.costo_siguiente_nivel(nivel) <= mejoras:
				alcanza = nivel + 1
		print("%3d | %17s | nivel %d" % [d + 1, Economia.formato_dinero(mejoras), alcanza])
	quit()
