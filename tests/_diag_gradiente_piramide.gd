extends SceneTree

## El gradiente real de la piramide recien generada.

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)
	print("div | once | banco | escalon | potencial | tier mas comun")
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var once := 0.0
		var banco := 0.0
		var pot := 0.0
		var n := 0.0
		var tiers := {}
		for e in liga.equipos:
			for j in e.jugadores:
				once += float(j["media"])
				pot += float(j["potencial"])
				tiers[j["genetica_tier"]] = int(tiers.get(j["genetica_tier"], 0)) + 1
			for j in e.banco:
				banco += float(j["media"])
			n += 1.0
		var top := ""
		var top_n := 0
		for t in tiers:
			if tiers[t] > top_n:
				top_n = tiers[t]
				top = t
		var m_once: float = once / n / 11.0
		var m_banco: float = banco / n / 7.0
		print("%3d | %4.1f | %5.1f | %7.1f | %9.1f | %s" % [
			d + 1, m_once, m_banco, m_once - m_banco, pot / n / 11.0, top])
	quit()
