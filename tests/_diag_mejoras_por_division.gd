extends SceneTree

## Cuanto presupuesto de Mejoras deja una temporada en cada division.
## Es el numero del que cuelga el costo de subir una instalacion: el
## objetivo es que cinco temporadas en decima paguen un nivel de cada una
## de las cinco instalaciones, o sea un nivel por temporada.

const SEED := 777

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	print("div | ingresos prom | sueldos prom | mantenim. | neto prom | MEJORAS prom | fichajes prom")
	for d in range(10):
		var liga: Liga = piramide.divisiones[d]
		var n: int = liga.equipos.size()
		var ing := 0.0
		var sue := 0.0
		var man := 0.0
		var neto := 0.0
		for i in range(n):
			var r := Economia.procesar_temporada(liga.equipos[i], i + 1, n, d)
			ing += float(r["ingresos"])
			sue += float(r["sueldos"])
			man += float(r["mantenimiento"])
			neto += float(r["neto"])
		var mejoras: float = (neto / n) * Economia.PRESUPUESTO_PORCENTAJES["mejoras"]
		var fichajes: float = (neto / n) * Economia.PRESUPUESTO_PORCENTAJES["fichajes"]
		print("%3d | %13s | %12s | %9s | %9s | %12s | %13s" % [
			d + 1, Economia.formato_dinero(ing / n), Economia.formato_dinero(sue / n),
			Economia.formato_dinero(man / n), Economia.formato_dinero(neto / n),
			Economia.formato_dinero(mejoras), Economia.formato_dinero(fichajes)])
	quit()
