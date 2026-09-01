extends SceneTree

## §9.3 rework: pedir un jugador a préstamo desde el mercado — duración,
## reparto del sueldo y opción de compra.

const SEED := 3030

var gs = null


func _init() -> void:
	_test_no_prestan_titulares()
	_test_hay_que_bancar_el_sueldo()
	_test_el_sueldo_se_reparte()
	_test_la_opcion_barata_no_pasa()
	_test_medio_ano_vuelve_a_mitad_de_temporada()
	if gs != null:
		gs.free()
	quit()


func _partida() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	if gs != null:
		gs.free()
	gs = load("res://game/game_state.gd").new()
	gs.piramide = piramide
	gs.rng = rng
	gs.temporada_actual = 3
	gs.fecha_actual = 0
	gs.division_jugador = 4
	gs.equipo_jugador = piramide.divisiones[4].equipos[0]
	gs._sembrar_presupuestos()
	gs.equipo_jugador.caja["fichajes"] = 500000000.0
	# El libro de pases solo abre en enero, febrero y julio, y una
	# partida arranca en marzo: sin esto toda operacion se rechaza.
	gs.dia_absoluto = Calendario.primer_dia_de_mercado()
	return {"piramide": piramide, "rng": rng, "dueno": piramide.divisiones[4].equipos[1]}


func _test_no_prestan_titulares() -> void:
	print("=== Un club no presta a un titular suyo ===")
	var p := _partida()
	var dueno: Team = p["dueno"]
	var titular: Dictionary = dueno.jugadores[5]
	var r: Dictionary = gs.pedir_prestamo(dueno, int(titular["id"]), "una", 1.0, 0.0)
	if not r["exito"] and str(r["motivo"]).contains("titular"):
		print("OK: %s" % r["motivo"])
	else:
		print("FALLA: %s" % [r])


func _test_hay_que_bancar_el_sueldo() -> void:
	print("\n=== Si no le sacas el sueldo de encima, no te lo presta ===")
	var p := _partida()
	var dueno: Team = p["dueno"]
	var suplente: Dictionary = dueno.banco[2]
	var r: Dictionary = gs.pedir_prestamo(dueno, int(suplente["id"]), "una", 0.2, 0.0)
	if not r["exito"] and str(r["motivo"]).contains("sueldo"):
		print("OK: %s" % r["motivo"])
	else:
		print("FALLA: %s" % [r])


func _test_el_sueldo_se_reparte() -> void:
	print("\n=== El sueldo se reparte entre los dos clubes ===")
	var p := _partida()
	var dueno: Team = p["dueno"]
	var suplente: Dictionary = dueno.banco[3]
	var id := int(suplente["id"])
	var sueldo_original: float = float(dueno.sueldos.get(id, 0.0))

	var r: Dictionary = gs.pedir_prestamo(dueno, id, "una", 0.7, 0.0)
	if not r["exito"]:
		print("FALLA: no se concreto (%s)." % r["motivo"])
		return
	var pago_yo: float = float(gs.equipo_jugador.sueldos.get(id, 0.0))
	var paga_el: float = float(dueno.sueldos.get(id, 0.0))
	var lo_tengo := not Mercado.ubicar(gs.equipo_jugador, id).is_empty()
	if lo_tengo and is_equal_approx(pago_yo, sueldo_original * 0.7) \
			and is_equal_approx(paga_el, sueldo_original * 0.3):
		print("OK: de %s, pago %s y el dueño sigue pagando %s." % [
			Economia.formato_dinero(sueldo_original),
			Economia.formato_dinero(pago_yo), Economia.formato_dinero(paga_el)])
	else:
		print("FALLA: tengo=%s yo=%.0f el=%.0f de %.0f" % [lo_tengo, pago_yo, paga_el, sueldo_original])


func _test_la_opcion_barata_no_pasa() -> void:
	print("\n=== El dueño no te ata su futuro barato ===")
	# El club estima cuanto va a valer el jugador cuando termine el
	# prestamo. Si la opcion esta por debajo de eso, no firma.
	var p := _partida()
	var dueno: Team = p["dueno"]
	var suplente: Dictionary = dueno.banco[4]
	var id := int(suplente["id"])
	var futuro := Prestamos.valor_futuro_estimado(suplente, 1.0)

	var barata: Dictionary = gs.pedir_prestamo(dueno, id, "una", 1.0, futuro * 0.4)
	var justa: Dictionary = gs.pedir_prestamo(dueno, id, "una", 1.0, futuro * Prestamos.MARGEN_OPCION * 1.05)
	if not barata["exito"] and justa["exito"]:
		print("OK: al 40%% de lo estimado dijo que no; pagando el margen, si (estimado %s)." % [
			Economia.formato_dinero(futuro)])
	else:
		print("FALLA: barata=%s justa=%s" % [barata.get("exito"), justa.get("exito")])


func _test_medio_ano_vuelve_a_mitad_de_temporada() -> void:
	print("\n=== Medio año es medio año de verdad ===")
	# Antes los retornos solo se miraban al CERRAR la temporada, asi que
	# un prestamo de medio año duraba igual que uno de una.
	var p := _partida()
	var dueno: Team = p["dueno"]
	var suplente: Dictionary = dueno.banco[5]
	var id := int(suplente["id"])

	var r: Dictionary = gs.pedir_prestamo(dueno, id, "medio", 1.0, 0.0)
	if not r["exito"]:
		print("FALLA: no se concreto (%s)." % r["motivo"])
		return
	var retorno := float(r["temporada_retorno"])

	# A un cuarto de temporada sigue conmigo; pasada la mitad, vuelve.
	var mio_al_cuarto := not Mercado.ubicar(gs.equipo_jugador, id).is_empty()
	Prestamos.procesar_retornos(dueno, 3.25)
	var sigue := not Mercado.ubicar(gs.equipo_jugador, id).is_empty()
	Prestamos.procesar_retornos(dueno, 3.6)
	var volvio := Mercado.ubicar(gs.equipo_jugador, id).is_empty() \
		and not Mercado.ubicar(dueno, id).is_empty()
	if mio_al_cuarto and sigue and volvio and is_equal_approx(retorno, 3.5):
		print("OK: vence en %.2f, a 3.25 sigue prestado y a 3.6 ya volvio." % retorno)
	else:
		print("FALLA: retorno=%.2f sigue=%s volvio=%s" % [retorno, sigue, volvio])
