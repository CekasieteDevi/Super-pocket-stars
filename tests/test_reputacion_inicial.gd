extends SceneTree

## La reputacion inicial tiene que SEPARAR a las divisiones: de ella
## cuelgan el aforo (y con el los ingresos por entradas), el estado de la
## cancha, la resistencia a vender y el objetivo que pone la directiva.

const SEED := 4242


func _init() -> void:
	_test_la_curva_respeta_el_techo()
	_test_cada_division_queda_separada()
	quit()


func _test_la_curva_respeta_el_techo() -> void:
	print("=== El techo de 80 se conserva: 80-100 es lo que se gana ganando ===")
	var tope := Economia.reputacion_inicial(200.0)
	var piso := Economia.reputacion_inicial(0.0)
	if tope > Economia.REPUTACION_INICIAL_MAX:
		print("FALLA: una media altisima dio %.1f, se pasa del techo." % tope)
		return
	if piso < Economia.REPUTACION_INICIAL_MIN:
		print("FALLA: una media de cero dio %.1f, baja del piso." % piso)
		return
	# Y tiene que ser creciente, si no una division mejor podria dar menos.
	var previo := -1.0
	for m in range(0, 101, 5):
		var r := Economia.reputacion_inicial(float(m))
		if r < previo - 0.001:
			print("FALLA: no es creciente, en media %d bajo a %.1f" % [m, r])
			return
		previo = r
	print("OK: entre %.0f y %.0f, y siempre creciente." % [piso, tope])


func _test_cada_division_queda_separada() -> void:
	print("\n=== Cada division nace con reputacion distinta a la de al lado ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var por_division := []
	for d in range(10):
		var nivel: Dictionary = NivelDivision.NIVELES[d]
		var suma := 0.0
		var n := 8
		for i in range(n):
			var e := Team.generar("D%d-%d" % [d + 1, i], rng, (d * 20 + i) * 400,
				int(nivel["potencial"]), "Uruguay", nivel["realizacion"])
			suma += e.reputacion
		por_division.append(suma / float(n))

	# Antes el clamp aplastaba lo de arriba: division 1 y 2 daban las dos
	# 80 clavado pese a tener seis puntos de plantel de diferencia.
	var minima_brecha := 999.0
	var peor := -1
	for d in range(9):
		var brecha: float = por_division[d] - por_division[d + 1]
		if brecha < minima_brecha:
			minima_brecha = brecha
			peor = d
	if minima_brecha < 2.0:
		print("FALLA: entre division %d (%.1f) y %d (%.1f) hay %.1f de reputacion." % [
			peor + 1, por_division[peor], peor + 2, por_division[peor + 1], minima_brecha])
		return
	print("OK: division 1 %.1f, division 10 %.1f, y la brecha mas chica entre vecinas es %.1f." % [
		por_division[0], por_division[9], minima_brecha])
