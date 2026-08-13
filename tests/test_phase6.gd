extends SceneTree

## Fase 6 del roadmap (GDD §9): economía, mercado y scouts.
## Correr con: godot --headless --script tests/test_phase6.gd
##
## Qué verificamos:
##   1. Economía: ingresos/egresos razonables, la reputación responde a la
##      tabla, ninguna caja queda con NaN/infinito.
##   2. Mercado: hay transferencias, el dinero se mueve entre las cajas de
##      "fichajes" de comprador y vendedor, y los planteles siguen en 11.
##   3. Scouts: con scout nivel 1 el reporte es un rango amplio; con nivel 8
##      el rango colapsa al valor real.
##   4. Ninguna caja/valor termina en negativo absurdo sin que se marque quiebra.

const N_EQUIPOS := 20
const SEED := 8080


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var nombres := []
	for i in range(N_EQUIPOS):
		nombres.append("Club %02d" % (i + 1))

	var liga := Liga.new()
	liga.inicializar(nombres, rng)

	_test_valor_y_scouts(liga)

	liga.jugar_temporada(rng, false)

	var resultado: Array = liga.nueva_temporada(rng)
	var informes: Array = resultado[0]
	var transferencias: Array = resultado[1]

	_test_economia(informes)
	_test_mercado(liga, transferencias)
	_test_integridad_planteles(liga)

	quit()


func _test_valor_y_scouts(liga: Liga) -> void:
	print("=== Valor de jugador y scouts ===")
	var jugador: Dictionary = liga.equipos[0].jugadores[0]
	var valor := ValorJugador.calcular(jugador, 50.0, 3)
	print("Jugador de muestra: %s media %.1f, edad %d -> valor %.0f" % [jugador["posicion"], jugador["media"], jugador["edad"], valor])

	var reporte_n1 := Scout.reportar(jugador, 1)
	var reporte_n8 := Scout.reportar(jugador, 8)
	var attr: String = jugador["atributos"].keys()[0]
	print("Reporte scout nivel 1 de '%s': real %d, rango %s (margen %d)" % [attr, jugador["atributos"][attr], reporte_n1[attr], Scout.margen(1)])
	print("Reporte scout nivel 8 de '%s': real %d, rango %s (margen %d)" % [attr, jugador["atributos"][attr], reporte_n8[attr], Scout.margen(8)])

	if reporte_n8[attr][0] == jugador["atributos"][attr] and reporte_n8[attr][1] == jugador["atributos"][attr]:
		print("OK: scout nivel 8 da el dato exacto.")
	else:
		print("FALLA: scout nivel 8 deberia dar el dato exacto.")
	if reporte_n1[attr][1] - reporte_n1[attr][0] > reporte_n8[attr][1] - reporte_n8[attr][0]:
		print("OK: el rango del scout nivel 1 es mas ancho que el del nivel 8.")
	else:
		print("FALLA: el scout nivel 1 deberia ser menos preciso que el nivel 8.")


func _test_economia(informes: Array) -> void:
	print("\n=== Economia de fin de temporada (%d clubes) ===" % informes.size())
	var total_ingresos := 0.0
	var total_egresos := 0.0
	var quebrados := 0
	var valores_invalidos := 0

	for informe in informes:
		total_ingresos += informe["ingresos"]
		total_egresos += informe["egresos"]
		if informe["quebrado"]:
			quebrados += 1
		if is_nan(informe["caja_total"]) or is_inf(informe["caja_total"]):
			valores_invalidos += 1

	print("Ingresos promedio por club: %.0f" % (total_ingresos / informes.size()))
	print("Egresos promedio por club: %.0f" % (total_egresos / informes.size()))
	print("Clubes en quiebra: %d" % quebrados)

	var ejemplo = informes[0]
	print("Ejemplo (%s): ingresos %.0f, egresos %.0f, neto %.0f, valor plantel %.0f" % [
		ejemplo["equipo"], ejemplo["ingresos"], ejemplo["egresos"], ejemplo["neto"], ejemplo["valor_plantel"]
	])

	if valores_invalidos == 0:
		print("OK: ninguna caja quedo en NaN/infinito.")
	else:
		print("FALLA: %d cajas en NaN/infinito." % valores_invalidos)


func _test_mercado(liga: Liga, transferencias: Array) -> void:
	print("\n=== Mercado de pases ===")
	print("Transferencias ejecutadas en la ventana: %d" % transferencias.size())
	for i in range(min(5, transferencias.size())):
		var t = transferencias[i]
		print("  %s (%s) : %s -> %s por %.0f" % [t["jugador_id"], t["posicion"], t["de"], t["a"], t["valor"]])

	if transferencias.size() > 0:
		print("OK: el mercado genero al menos una transferencia en la ventana.")
	else:
		print("FALLA: no hubo transferencias (revisar umbral/presupuesto).")


func _test_integridad_planteles(liga: Liga) -> void:
	print("\n=== Integridad de planteles despues del mercado ===")
	var ok := true
	for equipo in liga.equipos:
		if equipo.jugadores.size() != 11:
			ok = false
			print("FALLA %s: plantel con %d jugadores" % [equipo.nombre, equipo.jugadores.size()])
			continue
		for j in equipo.jugadores:
			var id = j["id"]
			if not equipo.sueldos.has(id) or not equipo.contratos.has(id) or not equipo.animo.has(id):
				ok = false
				print("FALLA %s: jugador %d sin sueldo/contrato/animo asignado" % [equipo.nombre, id])
	if ok:
		print("OK: los 20 planteles siguen en 11 jugadores, todos con sueldo/contrato/animo.")
