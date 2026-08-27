extends SceneTree

## El jugador humano puede comprarle a cualquiera, igual que la IA: de
## cualquier division y del plantel entero o la cantera del rival.

const SEED := 7777


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_ubicar_encuentra_en_los_tres_lados(rng)
	_test_comprar_de_otra_division(rng)
	_test_comprar_una_joya_de_la_cantera(rng)
	_test_sin_plata_no_hay_compra(rng)
	_test_la_clausula_no_se_puede_rechazar(rng)
	quit()


func _test_ubicar_encuentra_en_los_tres_lados(rng: RandomNumberGenerator) -> void:
	print("=== ubicar() ve titulares, banco y cantera ===")
	var e := Team.generar("Club", rng, 0)
	e.generar_camada(rng, 3, e.nivel_potencial())
	var origenes := {}
	for j in [e.jugadores[0], e.banco[0], e.cantera[0]]:
		var d := Mercado.ubicar(e, j["id"])
		if d.is_empty():
			print("FALLA: no encontro al jugador %d." % j["id"])
			return
		origenes[d["origen"]] = true
	if origenes.has("titular") and origenes.has("banco") and origenes.has("cantera"):
		print("OK: los tres origenes se ubican.")
	else:
		print("FALLA: origenes encontrados %s." % [origenes.keys()])


func _test_comprar_de_otra_division(rng: RandomNumberGenerator) -> void:
	print("\n=== Se le compra a un club de otra division ===")
	var p := Piramide.generar(rng)
	var mio: Team = p.divisiones[8].equipos[0]
	var lejano: Team = p.divisiones[3].equipos[0]
	mio.caja["fichajes"] = 50000000.0
	var objetivo: Dictionary = lejano.jugadores[7]
	var id: int = objetivo["id"]
	var antes := lejano.jugadores.size() + lejano.banco.size()
	var r := Mercado.comprar_al_contado(mio, lejano, id, rng, true)  # clausula: sin rechazo
	var lo_tengo := not Mercado.ubicar(mio, id).is_empty()
	var lo_perdio := Mercado.ubicar(lejano, id).is_empty()
	if r["exito"] and lo_tengo and lo_perdio and lejano.jugadores.size() + lejano.banco.size() == antes:
		print("OK: division 9 le compro a division 4 por %s, y el vendedor sigue con %d jugadores." % [
			Economia.formato_dinero(r["precio"]), antes])
	else:
		print("FALLA: %s | tengo=%s perdio=%s" % [r, lo_tengo, lo_perdio])


func _test_comprar_una_joya_de_la_cantera(rng: RandomNumberGenerator) -> void:
	print("\n=== Se le compra una joya a la cantera de otro club ===")
	var p := Piramide.generar(rng)
	var mio: Team = p.divisiones[0].equipos[0]
	var chico: Team = p.divisiones[9].equipos[0]
	chico.generar_camada(rng, 5, 90)
	mio.caja["fichajes"] = 50000000.0
	var joya: Dictionary = chico.cantera[0]
	var id: int = joya["id"]
	var cantera_antes := chico.cantera.size()
	var r := Mercado.comprar_al_contado(mio, chico, id, rng, true)
	if r["exito"] and r["origen"] == "cantera" and chico.cantera.size() == cantera_antes - 1 \
			and not Mercado.ubicar(mio, id).is_empty():
		print("OK: la joya (potencial %d) paso de la cantera de decima a primera." % int(joya["potencial"]))
	else:
		print("FALLA: %s | cantera %d -> %d" % [r, cantera_antes, chico.cantera.size()])


func _test_sin_plata_no_hay_compra(rng: RandomNumberGenerator) -> void:
	print("\n=== Sin presupuesto no se compra ===")
	var p := Piramide.generar(rng)
	var pobre: Team = p.divisiones[9].equipos[0]
	var rico: Team = p.divisiones[0].equipos[0]
	pobre.caja["fichajes"] = 1000.0
	var id: int = rico.jugadores[10]["id"]
	var r := Mercado.comprar_al_contado(pobre, rico, id, rng, true)
	if not r["exito"] and str(r["motivo"]).contains("presupuesto"):
		print("OK: decima puede OFERTAR por un crack de primera, lo que no puede es pagarlo.")
	else:
		print("FALLA: %s" % r)


func _test_la_clausula_no_se_puede_rechazar(rng: RandomNumberGenerator) -> void:
	print("\n=== La clausula fuerza la venta ===")
	var p := Piramide.generar(rng)
	var mio: Team = p.divisiones[4].equipos[0]
	var rival: Team = p.divisiones[4].equipos[1]
	mio.caja["fichajes"] = 50000000.0
	var fallos := 0
	for _i in range(12):
		if rival.jugadores.is_empty():
			break
		var id: int = rival.jugadores[0]["id"]
		var r := Mercado.comprar_al_contado(mio, rival, id, rng, true)
		if not r["exito"]:
			fallos += 1
	if fallos == 0:
		print("OK: 12 clausulas pagadas, ninguna rechazada.")
	else:
		print("FALLA: %d de 12 clausulas rechazadas." % fallos)
