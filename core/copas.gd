class_name Copas
extends RefCounted

## Copa Nacional (128 clubes) y Copas de División (16 por división) — Fase 7
## (GDD §10). Corren aparte de la liga: se resuelven de punta a punta con
## una llamada, en vez de intercaladas fecha a fecha con el campeonato como
## sería en un calendario semanal real — simplificación documentada.
##
## Quién entra lo decide ClasificacionCopas con la tabla de la temporada
## anterior. `posiciones` vacío (el caso de los tests, que juegan copas
## sobre una pirámide recién generada) ordena por reputación.


static func jugar_copa_nacional(piramide: Piramide, rng: RandomNumberGenerator,
		posiciones: Dictionary = {}) -> Copa:
	return _jugar_hasta_el_final("Copa Nacional",
		ClasificacionCopas.clasificados_nacional(piramide, posiciones), rng)


static func jugar_copas_de_division(piramide: Piramide, rng: RandomNumberGenerator,
		posiciones: Dictionary = {}) -> Array:
	var copas := []
	for d in range(piramide.divisiones.size()):
		var nombre := "Copa Division %d" % (d + 1)
		copas.append(_jugar_hasta_el_final(nombre,
			ClasificacionCopas.clasificados_de_division(piramide, d, posiciones), rng))
	return copas


static func _jugar_hasta_el_final(nombre: String, equipos: Array, rng: RandomNumberGenerator) -> Copa:
	var copa := Copa.iniciar(nombre, equipos, rng)
	while copa.campeon == null:
		copa.jugar_siguiente_ronda(rng)
	return copa
