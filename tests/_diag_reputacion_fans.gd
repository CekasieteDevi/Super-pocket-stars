extends SceneTree

## Como evolucionan REPUTACION e HINCHADA a lo largo de una carrera, y
## que le pasa al ingreso por entradas.
##
## Lo que se busca: que el prestigio se mueva de verdad (antes, ganar la
## liga todas las temporadas tardaba ~18 en mover 40 puntos y las copas
## no valian nada) y que la hinchada abra ordenes de magnitud entre
## divisiones sin que la economia se desarme.

const TEMPORADAS := 8


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var p := Piramide.generar(rng)

	print("=== Arranque ===")
	_fila(p, 0)
	var entradas_inicial := _entradas(p)
	for t in range(TEMPORADAS):
		for liga in p.divisiones:
			for fecha in range(liga.fixture.size()):
				liga.jugar_fecha(fecha, rng, null)
				liga.avanzar_dias(7)
		p.fin_de_temporada(rng, null, t)
		if (t + 1) % 4 == 0:
			_fila(p, t + 1)

	print("\n=== Ingreso por entradas (promedio por club) ===")
	for d in range(p.divisiones.size()):
		print("  D%-2d  arranque %12s   temporada %d %12s" % [
			d + 1, Economia.formato_dinero(entradas_inicial[d]),
			TEMPORADAS, Economia.formato_dinero(_entradas(p)[d])])
	quit()


## La ocupacion depende del apoyo, asi que se puede estimar el ingreso de
## entradas sin correr la temporada entera otra vez.
func _entradas(p: Piramide) -> Array:
	var por_division := []
	for d in range(p.divisiones.size()):
		var total := 0.0
		for e in p.divisiones[d].equipos:
			var base: float = Economia.OCUPACION_BASE + clampf(e.reputacion, 0.0, 100.0) / 100.0 * 0.7
			var ocupacion: float = clampf(
				base + Fans.apoyo(e, d) * Economia.BONUS_OCUPACION_FANS, 0.0, 1.0)
			total += (Economia.AFORO_BASE * Instalaciones.factor_aforo(e) * ocupacion * Economia.PRECIO_ENTRADA
				* Economia.PARTIDOS_DE_LOCAL) * Economia.factor_division(d)
		por_division.append(total / float(p.divisiones[d].equipos.size()))
	return por_division


func _fila(p: Piramide, temporada: int) -> void:
	print("-- temporada %d" % temporada)
	for d in range(p.divisiones.size()):
		var liga: Liga = p.divisiones[d]
		var orden := liga.tabla_ordenada()
		var primero := _buscar(liga, orden[0])
		var ultimo := _buscar(liga, orden[orden.size() - 1])
		var rep := 0.0
		var fans := 0.0
		for e in liga.equipos:
			rep += e.reputacion
			fans += e.fans
		print("  D%-2d  rep media %5.1f  (1o %5.1f / ult %5.1f)   hinchada media %10s  (1o %9s / ult %9s)" % [
			d + 1, rep / liga.equipos.size(), primero.reputacion, ultimo.reputacion,
			Fans.texto(fans / liga.equipos.size()),
			Fans.texto(primero.fans), Fans.texto(ultimo.fans)])


func _buscar(liga: Liga, nombre: String) -> Team:
	for e in liga.equipos:
		if e.nombre == nombre:
			return e
	return null
