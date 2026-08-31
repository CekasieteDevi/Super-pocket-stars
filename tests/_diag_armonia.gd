extends SceneTree
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	var minimo := INF
	var maximo := -INF
	var suma := 0.0
	var n := 200
	for i in range(n):
		var e := Team.generar("C%d" % i, rng, i * 400)
		minimo = minf(minimo, e.armonia)
		maximo = maxf(maximo, e.armonia)
		suma += e.armonia
	print("[chk] armonia en %d clubes: min %.1f, max %.1f, promedio %.1f" % [
		n, minimo, maximo, suma / n])
	print("[chk] el GDD la define como una banda de +5 / +2 / 0 / -3 / -5")
	quit()
