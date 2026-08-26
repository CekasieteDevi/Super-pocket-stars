extends SceneTree

## ¿Los clubes de arriba compran abajo, y eso sostiene la piramide?

const TEMPORADAS := 8


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)
	print("=== Techo promedio del once por division ===")
	_fila(p, 0)
	var compras := {}
	var joyas := 0
	var gasto := 0.0
	var gasto_div := {}
	var media_div := {}
	for t in range(TEMPORADAS):
		for liga in p.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)
		var cierre := p.fin_de_temporada(rng, null, t)
		for tr in cierre["transferencias_entre_divisiones"]:
			var d: int = int(tr["a_division"])
			compras[d] = int(compras.get(d, 0)) + 1
			gasto += float(tr["valor"])
			gasto_div[d] = float(gasto_div.get(d, 0.0)) + float(tr["valor"])
			media_div[d] = float(media_div.get(d, 0.0)) + float(tr["media"])
			if tr["joya"]:
				joyas += 1
		if (t + 1) % 4 == 0:
			_fila(p, t + 1)
	print("\n=== Compras entre divisiones en %d temporadas ===" % TEMPORADAS)
	var total := 0
	for d in range(p.divisiones.size()):
		total += int(compras.get(d + 1, 0))
	print("total %d (%.1f por temporada), de las cuales %d fueron joyas juveniles" % [
		total, float(total) / TEMPORADAS, joyas])
	print("gasto promedio por fichaje: %s" % Economia.formato_dinero(gasto / max(1.0, float(total))))
	print("division | compras | gasto medio | media del fichado")
	for d in range(p.divisiones.size()):
		var n: int = int(compras.get(d + 1, 0))
		if n == 0:
			print("%8d | %7d |           - |        -" % [d + 1, 0])
			continue
		print("%8d | %7d | %11s | %8.1f" % [d + 1, n,
			Economia.formato_dinero(float(gasto_div.get(d + 1, 0.0)) / float(n)),
			float(media_div.get(d + 1, 0.0)) / float(n)])
	quit()


func _contar(p: Piramide, antes: Dictionary = {}) -> Dictionary:
	var por_division := {}
	var joyas := 0
	var gasto := 0.0
	for d in range(p.divisiones.size()):
		for n in p.divisiones[d].noticias:
			if not n.contains("FICHAJES: ") or not n.contains("division"):
				continue
			por_division[d + 1] = int(por_division.get(d + 1, 0)) + 1
			if n.contains("joven promesa"):
				joyas += 1
	return {"por_division": por_division, "joyas": joyas, "gasto": gasto}


func _fila(p: Piramide, temporada: int) -> void:
	var partes := []
	for d in range(p.divisiones.size()):
		var total := 0.0
		var n := 0.0
		for e in p.divisiones[d].equipos:
			for j in e.jugadores:
				total += float(j["potencial"])
				n += 1.0
		partes.append("%5.1f" % (total / max(1.0, n)))
	print("temp %2d | %s" % [temporada, " ".join(partes)])
