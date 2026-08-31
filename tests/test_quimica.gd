extends SceneTree

## §7.4.6: quimica entre jugadores. Lo que se prueba es que mantener el
## once junto rinda, que rotar cueste, y que la quimica NO infle el juego
## entero —solo entra en las acciones entre los dos.

const SEED := 71330


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_curva()
	_test_la_clave_no_depende_del_orden()
	_test_se_hace_jugando_y_se_pierde_rotando(rng)
	_test_se_limpia_cuando_uno_se_va(rng)
	_test_pesa_en_el_partido(rng)
	_test_sobrevive_un_guardado(rng)

	quit()


func _test_curva() -> void:
	print("\n=== Nada hasta jugar mucho juntos, despues de +2 a +5 ===")
	if Quimica.bonus_de_partidos(0.0) != 0.0:
		print("FALLA: sin partidos juntos deberia dar 0.")
		return
	if Quimica.bonus_de_partidos(Quimica.PARTIDOS_MINIMOS - 1.0) != 0.0:
		print("FALLA: por debajo del minimo deberia dar 0.")
		return
	var en_minimo := Quimica.bonus_de_partidos(Quimica.PARTIDOS_MINIMOS)
	var en_tope := Quimica.bonus_de_partidos(Quimica.PARTIDOS_TOPE)
	if not is_equal_approx(en_minimo, Quimica.BONUS_MIN):
		print("FALLA: en el minimo dio %.2f, deberia ser %.1f" % [en_minimo, Quimica.BONUS_MIN])
		return
	if not is_equal_approx(en_tope, Quimica.BONUS_MAX):
		print("FALLA: en el tope dio %.2f, deberia ser %.1f" % [en_tope, Quimica.BONUS_MAX])
		return
	if Quimica.bonus_de_partidos(Quimica.PARTIDOS_TOPE * 3.0) > Quimica.BONUS_MAX:
		print("FALLA: se pasa del tope.")
		return
	print("OK: %d partidos -> +%.0f, %d -> +%.0f, y no se pasa de ahi." % [
		int(Quimica.PARTIDOS_MINIMOS), en_minimo, int(Quimica.PARTIDOS_TOPE), en_tope])


func _test_la_clave_no_depende_del_orden() -> void:
	print("\n=== A-B y B-A son la misma dupla ===")
	if Quimica.clave(7, 3) != Quimica.clave(3, 7):
		print("FALLA: %s != %s" % [Quimica.clave(7, 3), Quimica.clave(3, 7)])
		return
	print("OK: %s en los dos sentidos." % Quimica.clave(7, 3))


func _test_se_hace_jugando_y_se_pierde_rotando(rng: RandomNumberGenerator) -> void:
	print("\n=== Se hace jugando juntos y se pierde al separarlos ===")
	var e := Team.generar("Quimica", rng, 0)
	var a: int = int(e.jugadores[1]["id"])
	var b: int = int(e.jugadores[2]["id"])

	for _i in range(20):
		Quimica.despues_de_partido(e)
	var juntos := Quimica.partidos(e, a, b)
	if juntos < 20.0:
		print("FALLA: tras 20 fechas juntos llevan %.1f partidos." % juntos)
		return
	if Quimica.bonus(e, a, b) <= 0.0:
		print("FALLA: 20 partidos juntos y no suman nada.")
		return
	var bonus_juntos := Quimica.bonus(e, a, b)

	# Se saca a uno del once: la dupla deja de sumar partidos y se oxida.
	var salio: Dictionary = e.jugadores[2]
	e.jugadores.remove_at(2)
	e.banco.append(salio)
	for _i in range(20):
		Quimica.despues_de_partido(e)
	var despues := Quimica.partidos(e, a, b)
	if despues >= juntos:
		print("FALLA: separados siguen sumando (%.1f -> %.1f)." % [juntos, despues])
		return
	print("OK: 20 fechas juntos dan +%.1f (%.0f partidos); 20 fechas separados lo bajan a %.1f." % [
		bonus_juntos, juntos, despues])


func _test_se_limpia_cuando_uno_se_va(rng: RandomNumberGenerator) -> void:
	print("\n=== Si uno se va del club, la dupla se tira ===")
	var e := Team.generar("Limpieza", rng, 0)
	for _i in range(10):
		Quimica.despues_de_partido(e)
	var antes: int = e.quimica.size()
	if antes == 0:
		print("FALLA: no se registro ninguna dupla.")
		return

	# Se va un titular: todas sus duplas son basura que se arrastraria en
	# el guardado para siempre.
	var se_va: int = int(e.jugadores[3]["id"])
	e.jugadores.remove_at(3)
	e.jugadores.append(e.banco.pop_back())
	Quimica.despues_de_partido(e)

	for c in e.quimica:
		var partes: PackedStringArray = str(c).split("-")
		if int(partes[0]) == se_va or int(partes[1]) == se_va:
			print("FALLA: quedo la dupla %s de alguien que ya no esta." % c)
			return
	print("OK: de %d duplas quedaron %d, ninguna del que se fue." % [antes, e.quimica.size()])


## Se mide la TASA DE PASE y no los puntos. La quimica entra en un solo
## tipo de accion y aporta ~3 pp: sobre 60 partidos eso mueve uno o dos
## puntos en la tabla, que es ruido. La tasa de pase es donde el efecto
## existe de verdad, y es la que hay que mirar para saber si funciona.
func _test_pesa_en_el_partido(rng: RandomNumberGenerator) -> void:
	print("
=== Un once hecho completa mas pases que uno recien armado ===")
	var muestras := 40
	var ok_sin := 0
	var tot_sin := 0
	var ok_con := 0
	var tot_con := 0

	for i in range(muestras):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 8800 + i
		var casa := Team.generar("Casa", r1, 0)
		var visita := Team.generar("Visita", r1, 100)
		var res := MatchEngine.simular(casa, visita, r1, false)
		var c1 := _contar_pases(res, "Casa")
		ok_sin += c1[0]
		tot_sin += c1[1]

		var r2 := RandomNumberGenerator.new()
		r2.seed = 8800 + i
		var casa2 := Team.generar("Casa", r2, 0)
		var visita2 := Team.generar("Visita", r2, 100)
		# Mismo plantel, mismo rival, misma semilla: lo unico distinto es
		# que este once viene jugando junto hace una temporada larga.
		for _f in range(int(Quimica.PARTIDOS_TOPE)):
			Quimica.despues_de_partido(casa2)
		var res2 := MatchEngine.simular(casa2, visita2, r2, false)
		var c2 := _contar_pases(res2, "Casa")
		ok_con += c2[0]
		tot_con += c2[1]

	if tot_sin == 0 or tot_con == 0:
		print("FALLA: no se contaron pases.")
		return
	var tasa_sin := float(ok_sin) / float(tot_sin) * 100.0
	var tasa_con := float(ok_con) / float(tot_con) * 100.0
	if tasa_con <= tasa_sin:
		print("FALLA: con quimica %.1f%% de pase, sin quimica %.1f%%." % [tasa_con, tasa_sin])
		return
	print("OK: en %d partidos, %.1f%% de pase sin quimica y %.1f%% con el once hecho (+%.1f pp)." % [
		muestras, tasa_sin, tasa_con, tasa_con - tasa_sin])


func _contar_pases(res: Dictionary, equipo: String) -> Array:
	var ok := 0
	var total := 0
	for ev in res["eventos"]:
		if str(ev.get("tipo", "")) != "pase" or str(ev.get("equipo", "")) != equipo:
			continue
		total += 1
		if str(ev.get("resultado", "")) == "avanza":
			ok += 1
	return [ok, total]


func _test_sobrevive_un_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Sobrevive un guardado ===")
	var e := Team.generar("Guardado", rng, 0)
	for _i in range(12):
		Quimica.despues_de_partido(e)
	var a: int = int(e.jugadores[0]["id"])
	var b: int = int(e.jugadores[1]["id"])
	var esperado := Quimica.partidos(e, a, b)
	var vuelto := Team.cargar(e.guardar())
	if not is_equal_approx(Quimica.partidos(vuelto, a, b), esperado):
		print("FALLA: guardo %.1f y volvio %.1f." % [
			esperado, Quimica.partidos(vuelto, a, b)])
		return

	# Una partida anterior a §7.4.6 no trae el campo y arranca sin duplas.
	var datos := e.guardar()
	datos.erase("quimica")
	var viejo := Team.cargar(datos)
	if not viejo.quimica.is_empty():
		print("FALLA: una partida vieja deberia arrancar sin duplas.")
		return
	print("OK: %.0f partidos de dupla sobreviven el guardado, y una partida vieja arranca limpia." % esperado)
