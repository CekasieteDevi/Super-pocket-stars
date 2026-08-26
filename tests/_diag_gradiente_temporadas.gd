extends SceneTree

## ¿El gradiente por division sobrevive a las temporadas? Se genera la
## piramide y se corren N temporadas COMPLETAS (economia, mercado,
## progresion, cantera, ascensos y descensos) mirando si la forma
## aguanta o se aplana.
##
## Importa porque NivelDivision solo fija la condicion INICIAL: no hay
## nada que mantenga la brecha despues.

const TEMPORADAS := 12
const CADA := 4


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)

	print("=== Media del once por division ===")
	_fila(p, 0)
	for t in range(TEMPORADAS):
		for liga in p.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)
		p.fin_de_temporada(rng, null, t)
		if (t + 1) % CADA == 0:
			_fila(p, t + 1)

	print("\n=== Movilidad: de donde salen los clubes de primera ===")
	_origen(p)
	quit()


func _media(liga: Liga) -> float:
	var total := 0.0
	for e in liga.equipos:
		total += e.media_equipo()
	return total / float(liga.equipos.size())


## El TECHO promedio. Si el techo converge, entran jugadores de otro lado
## (cantera o mercado); si se mantiene y solo sube la media, es potencial
## sin realizar que se va llenando, que es esperable por diseño.
func _potencial(liga: Liga) -> float:
	var total := 0.0
	var n := 0.0
	for e in liga.equipos:
		for j in e.jugadores:
			total += float(j["potencial"])
			n += 1.0
	return total / max(1.0, n)


func _fila(p: Piramide, temporada: int) -> void:
	var partes := []
	var pot := []
	for d in range(p.divisiones.size()):
		partes.append("%5.1f" % _media(p.divisiones[d]))
		pot.append("%5.1f" % _potencial(p.divisiones[d]))
	var ultimo: int = p.divisiones.size() - 1
	print("temp %2d media | %s | brecha %.1f" % [temporada, " ".join(partes),
		_media(p.divisiones[0]) - _media(p.divisiones[ultimo])])
	print("        techo | %s | brecha %.1f" % [" ".join(pot),
		_potencial(p.divisiones[0]) - _potencial(p.divisiones[ultimo])])


## Cuantos de los clubes que hoy estan en primera arrancaron en primera.
func _origen(p: Piramide) -> void:
	var nombres_primera := {}
	for e in p.divisiones[0].equipos:
		nombres_primera[e.nombre] = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var original := Piramide.generar(rng)
	var eran := 0
	for e in original.divisiones[0].equipos:
		if nombres_primera.has(e.nombre):
			eran += 1
	print("de los %d clubes de primera, %d ya estaban ahi al empezar." % [
		nombres_primera.size(), eran])
