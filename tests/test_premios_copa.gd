extends SceneTree

## Los premios de copa: que se cobren, que la de division escale con la
## division y que el Rey y las internacionales NO escalen.

const SEED := 6420


func _init() -> void:
	var fallas := 0
	var gs = load("res://game/game_state.gd").new()
	gs.partida_nueva(SEED, "Club Prueba")

	# --- La copa de division escala; el Rey no --------------------------
	var esperado_div10: float = Economia.PREMIO_COPA_DIVISION[1] * Economia.factor_division(9)
	var esperado_div1: float = Economia.PREMIO_COPA_DIVISION[1] * Economia.factor_division(0)
	if esperado_div1 > esperado_div10 * 100.0:
		print("OK: la copa de division paga %s en decima y %s en primera." % [
			Economia.formato_dinero(esperado_div10), Economia.formato_dinero(esperado_div1)])
	else:
		print("FALLA: la copa de division no escala (decima %s, primera %s)." % [
			esperado_div10, esperado_div1])
		fallas += 1

	# --- Se le paga al campeon y al finalista ---------------------------
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipos := []
	for i in range(8):
		equipos.append(Team.generar("Club %d" % i, rng, i * 40))
	var copa := Copa.iniciar("Prueba", equipos, rng)
	while copa.campeon == null:
		copa.jugar_siguiente_ronda(rng)
	var perdedor_nombre := copa.finalista()
	var perdedor: Team = null
	for e in equipos:
		if e.nombre == perdedor_nombre:
			perdedor = e
	if perdedor != null and perdedor != copa.campeon:
		print("OK: el finalista es el que perdio la final (%s cayo con %s)." % [
			perdedor_nombre, copa.campeon.nombre])
	else:
		print("FALLA: no se pudo identificar al finalista (\"%s\")." % perdedor_nombre)
		fallas += 1

	# --- El premio sobrevive al cierre de temporada ---------------------
	# La caja se REINICIA en el cierre: si el premio se sumara a la caja en
	# el momento de ganarlo, se perderia en el mismo cierre que lo pago.
	# Cada llamada va por Economia.calcular_temporada, que cierra sobre
	# una copia fresca del club. procesar_temporada no es una consulta:
	# ademas de devolver el informe le mueve al club la reputacion y la
	# hinchada, asi que la segunda llamada sobre el mismo equipo mediria
	# un club distinto del de la primera y la diferencia dejaria de ser el
	# premio (daba $50.892 en vez de $50.000 en decima, y -$439.671 en
	# primera).
	var equipo: Team = gs.equipo_jugador
	var sin_premio := _cerrar(equipo, 0.0, 9)
	var con_premio := _cerrar(equipo, 50000.0, 9)
	var diferencia: float = float(con_premio["ingresos"]) - float(sin_premio["ingresos"])
	if absf(diferencia - 50000.0) < 1.0:
		print("OK: el premio entra entero al ingreso de la temporada (+%s)." % [
			Economia.formato_dinero(diferencia)])
	else:
		print("FALLA: el premio de $50.000 movio el ingreso en %s." % [
			Economia.formato_dinero(diferencia)])
		fallas += 1
	# Que el acumulador se vacie se prueba sobre un club aparte, porque el
	# de arriba ya es una copia.
	var cobrador: Team = Team.cargar(equipo.guardar())
	cobrador.premios_copa = 50000.0
	Economia.procesar_temporada(cobrador, 10, 20, 9)
	if absf(cobrador.premios_copa) < 0.01:
		print("OK: cobrado el premio, el acumulador queda en cero.")
	else:
		print("FALLA: el acumulador quedo en %s despues de cobrarlo." % cobrador.premios_copa)
		fallas += 1
	if absf(float(con_premio["premios_copa"]) - 50000.0) < 1.0:
		print("OK: el informe economico dice cuanto vino de copas.")
	else:
		print("FALLA: el informe no informa los premios de copa.")
		fallas += 1

	# El premio NO puede pasar por el multiplicador de division: en primera
	# lo multiplicaria por 88 y el Rey dejaria de ser un premio fijo.
	var en_primera := _cerrar(equipo, 50000.0, 0)
	var sin_en_primera := _cerrar(equipo, 0.0, 0)
	var dif_primera: float = float(en_primera["ingresos"]) - float(sin_en_primera["ingresos"])
	if absf(dif_primera - 50000.0) < 1.0:
		print("OK: en primera el premio sigue valiendo lo mismo, no se multiplica por 88.")
	else:
		print("FALLA: en primera el premio de $50.000 valio %s." % [
			Economia.formato_dinero(dif_primera)])
		fallas += 1

	gs.free()
	print("FALLOS=%d" % fallas)
	quit()


## Cierra la temporada del club con estos premios de copa y en esta
## division, sin tocarlo: Economia.calcular_temporada corre el cierre
## sobre una copia. Comparar dos cierres exige que los dos arranquen del
## mismo estado, y procesar_temporada le mueve la reputacion y la hinchada
## al club que procesa.
func _cerrar(equipo: Team, premios: float, division: int) -> Dictionary:
	var copia := Team.cargar(equipo.guardar())
	copia.premios_copa = premios
	return Economia.calcular_temporada(copia, 10, 20, division)
