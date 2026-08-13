class_name Copas
extends RefCounted

## Copa Nacional (200 clubes) y Copas de División (20 por división) — Fase 7
## (GDD §10). Corren aparte de la liga: se resuelven de punta a punta con
## una llamada, en vez de intercaladas fecha a fecha con el campeonato como
## sería en un calendario semanal real — simplificación documentada.


static func jugar_copa_nacional(piramide: Piramide, rng: RandomNumberGenerator) -> Copa:
	var todos := []
	for liga in piramide.divisiones:
		for equipo in liga.equipos:
			todos.append(equipo)
	return _jugar_hasta_el_final("Copa Nacional", todos, rng)


static func jugar_copas_de_division(piramide: Piramide, rng: RandomNumberGenerator) -> Array:
	var copas := []
	for d in range(piramide.divisiones.size()):
		var nombre := "Copa Division %d" % (d + 1)
		copas.append(_jugar_hasta_el_final(nombre, piramide.divisiones[d].equipos.duplicate(), rng))
	return copas


static func _jugar_hasta_el_final(nombre: String, equipos: Array, rng: RandomNumberGenerator) -> Copa:
	var copa := Copa.iniciar(nombre, equipos, rng)
	while copa.campeon == null:
		copa.jugar_siguiente_ronda(rng)
	return copa
