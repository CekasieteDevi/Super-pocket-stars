extends SceneTree

## De donde sale y a donde va la plata de un club, temporada por
## temporada. Es la foto que hay que mirar antes de tocar nada.

const SEED := 3131


func _init() -> void:
	for division in [9, 5, 0]:
		_medir(division)
	quit()


func _medir(division: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var liga: Liga = piramide.divisiones[division]
	var equipo: Team = liga.equipos[0]

	print("\n=== Division %d — %s ===" % [division + 1, equipo.nombre])
	print("  reputacion %.0f · fans %.0f · media del once %.1f" % [
		equipo.reputacion, equipo.fans, equipo.media_equipo()])

	# Las piezas del ingreso, a mano, para poder verlas por separado.
	var ocupacion_base: float = 0.3 + clampf(equipo.reputacion, 0.0, 100.0) / 100.0 * 0.7
	var ocupacion: float = clampf(
		ocupacion_base + equipo.fans / 100.0 * Economia.BONUS_OCUPACION_FANS, 0.0, 1.0)
	var asistencia: float = Economia.AFORO_BASE * Instalaciones.factor_aforo(equipo) * ocupacion
	var entradas: float = Economia.PARTIDOS_DE_LOCAL * asistencia * Economia.PRECIO_ENTRADA
	var sponsor: float = Economia.SPONSOR_BASE + (liga.equipos.size() - 10) * 1000.0
	var factor := Economia.factor_division(division)
	var sueldos := 0.0
	for id in equipo.sueldos:
		sueldos += equipo.sueldos[id]

	print("  ENTRA (x%.2f por division):" % factor)
	print("    entradas   %s   (%d de local x %.0f personas x $%.0f, ocupacion %.0f%%)" % [
		Economia.formato_dinero(entradas * factor), Economia.PARTIDOS_DE_LOCAL,
		asistencia, Economia.PRECIO_ENTRADA, ocupacion * 100.0])
	print("    sponsor    %s" % Economia.formato_dinero(sponsor * factor))
	print("  SALE:")
	print("    sueldos    %s   (%d jugadores)" % [
		Economia.formato_dinero(sueldos), equipo.sueldos.size()])
	print("    mantenim.  %s" % Economia.formato_dinero(Economia.MANTENIMIENTO_FIJO))
	var neto: float = (entradas + sponsor) * factor - sueldos - Economia.MANTENIMIENTO_FIJO
	print("  NETO       %s" % Economia.formato_dinero(neto))
	if neto > 0.0:
		print("    -> fichajes %s · contratos %s · mejoras %s" % [
			Economia.formato_dinero(neto * Economia.PRESUPUESTO_PORCENTAJES["fichajes"]),
			Economia.formato_dinero(neto * Economia.PRESUPUESTO_PORCENTAJES["contratos"]),
			Economia.formato_dinero(neto * Economia.PRESUPUESTO_PORCENTAJES["mejoras"])])

	# Contra que se compara: cuanto vale un jugador de este nivel.
	var valores := []
	for j in equipo.jugadores:
		valores.append(ValorJugador.calcular(j, 50.0, 3))
	valores.sort()
	print("  un jugador del plantel vale entre %s y %s (mediana %s)" % [
		Economia.formato_dinero(valores[0]),
		Economia.formato_dinero(valores[-1]),
		Economia.formato_dinero(valores[valores.size() / 2])])
