extends SceneTree

## Barrido del umbral de transicion de la etapa 4. Mide, no falla.

const SEED := 4410


func _init() -> void:
	for umbral in [0.35, 0.55, 0.70, 0.80, 0.90]:
		MotorEspacial._pesos_ritmo_cache = {}
		var w: Dictionary = MotorEspacial.pesos_ritmo()
		w["umbral_transicion"] = umbral
		var t := {}
		for i in range(8):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED + i * 31
			var casa := Team.generar("Casa", rng, 0)
			var visita := Team.generar("Visita", rng, 3)
			var res := MotorEspacial.simular(casa, visita, rng, false)
			var s: Dictionary = res.get("stats", {}).get("ritmo", {})
			for k in s:
				t[k] = int(t.get(k, 0)) + int(s[k])
		var c: int = int(t.get("circulacion", 0))
		var a: int = int(t.get("aceleracion", 0))
		var tr: int = int(t.get("transicion", 0))
		var n: int = maxi(c + a + tr, 1)
		print("umbral %.2f -> circ %.0f%%  acel %.0f%%  tran %.0f%%   atras/p %.1f  devol/p %.1f" % [
				umbral, 100.0 * c / n, 100.0 * a / n, 100.0 * tr / n,
				float(int(t.get("atras_sin_presion", 0))) / 8.0,
				float(int(t.get("devolucion", 0))) / 8.0])
	MotorEspacial._pesos_ritmo_cache = {}
	quit()
