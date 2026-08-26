extends SceneTree

## §9.3: mercado entre divisiones. El de arriba compra, el de abajo cobra.

const SEED := 909


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_perder_jugador_tapa_el_hueco(rng)
	_test_incorporar_mantiene_el_plantel(rng)
	_test_la_joya_se_pelea(rng)
	_test_el_jugador_humano_no_se_toca(rng)
	_test_los_de_arriba_compran_mejor(rng)
	quit()


func _test_perder_jugador_tapa_el_hueco(rng: RandomNumberGenerator) -> void:
	print("=== Perder un titular no deja el plantel corto ===")
	var e := Team.generar("Vendedor", rng, 0)
	e.generar_camada(rng, 4, e.nivel_potencial())
	var titulares := e.jugadores.size()
	var banco := e.banco.size()
	var victima: int = e.jugadores[5]["id"]
	var ok: bool = e.perder_jugador(victima, rng)
	var sigue := false
	for j in e.todos_los_jugadores():
		if j["id"] == victima:
			sigue = true
	if ok and not sigue and e.jugadores.size() == titulares and e.banco.size() == banco:
		print("OK: el vendido se fue y el plantel sigue en %d+%d." % [titulares, banco])
	else:
		print("FALLA: ok=%s sigue=%s plantel %d+%d." % [ok, sigue, e.jugadores.size(), e.banco.size()])


func _test_incorporar_mantiene_el_plantel(rng: RandomNumberGenerator) -> void:
	print("\n=== Comprar tampoco infla el plantel ===")
	var e := Team.generar("Comprador", rng, 0)
	var titulares := e.jugadores.size()
	var banco := e.banco.size()
	# Un crack en un puesto que ya tiene: tiene que entrar de titular.
	var puesto: String = e.jugadores[10]["posicion"]
	var crack := PlayerGenerator.generate(9000, rng, puesto, 99)
	crack["media"] = 99.0
	e.incorporar(crack, 500000.0)
	var es_titular := false
	for j in e.jugadores:
		if j["id"] == 9000:
			es_titular = true
	if es_titular and e.jugadores.size() == titulares and e.banco.size() == banco:
		print("OK: entro de titular y el plantel sigue en %d+%d." % [titulares, banco])
	else:
		print("FALLA: titular=%s plantel %d+%d." % [es_titular, e.jugadores.size(), e.banco.size()])


func _test_la_joya_se_pelea(rng: RandomNumberGenerator) -> void:
	print("\n=== Un club chico se pelea a su joya ===")
	# Sin esto, cada crack que aparece abajo sube de division la misma
	# temporada, siempre.
	var chico := Team.generar("Chico", rng, 0, NivelDivision.potencial(9), "Uruguay", NivelDivision.realizacion(9))
	var comun: Dictionary = chico.jugadores[3].duplicate(true)
	comun["potencial"] = chico.nivel_potencial()
	comun["edad"] = 21
	var joya: Dictionary = chico.jugadores[3].duplicate(true)
	joya["potencial"] = chico.nivel_potencial() + 35
	joya["edad"] = 19
	var r_comun := Mercado.resistencia_venta(chico, comun)
	var r_joya := Mercado.resistencia_venta(chico, joya)
	if r_joya > r_comun + 0.15:
		print("OK: resistencia %.2f por la joya contra %.2f por uno comun." % [r_joya, r_comun])
	else:
		print("FALLA: resistencia joya %.2f, comun %.2f." % [r_joya, r_comun])


func _test_el_jugador_humano_no_se_toca(rng: RandomNumberGenerator) -> void:
	print("\n=== Al club del jugador no le compran ni le venden solos ===")
	var p := Piramide.generar(rng)
	var mio: Team = p.divisiones[7].equipos[0]
	var antes := []
	for j in mio.todos_los_jugadores():
		antes.append(j["id"])
	for _t in range(3):
		var tr := Mercado.ventana_entre_divisiones(p, rng, mio)
		for t in tr:
			if t["de"] == mio.nombre or t["a"] == mio.nombre:
				print("FALLA: el club protegido aparece en una transferencia.")
				return
	var despues := []
	for j in mio.todos_los_jugadores():
		despues.append(j["id"])
	if antes == despues:
		print("OK: el plantel del jugador quedo intacto tras 3 ventanas.")
	else:
		print("FALLA: le cambiaron el plantel.")


func _test_los_de_arriba_compran_mejor(rng: RandomNumberGenerator) -> void:
	print("\n=== Los clubes de arriba fichan mejor que los de abajo ===")
	var p := Piramide.generar(rng)
	var suma := {}
	var cuenta := {}
	for _t in range(4):
		for liga in p.divisiones:
			for e in liga.equipos:
				e.caja["fichajes"] = 400000.0
		for t in Mercado.ventana_entre_divisiones(p, rng, null):
			var d: int = int(t["a_division"])
			suma[d] = float(suma.get(d, 0.0)) + float(t["media"])
			cuenta[d] = int(cuenta.get(d, 0)) + 1
	var arriba := _media_de(suma, cuenta, [1, 2, 3])
	var abajo := _media_de(suma, cuenta, [7, 8, 9])
	if arriba - abajo > 15.0:
		print("OK: divisiones 1-3 fichan media %.1f, divisiones 7-9 media %.1f." % [arriba, abajo])
	else:
		print("FALLA: 1-3 fichan %.1f y 7-9 fichan %.1f, muy parecido." % [arriba, abajo])


func _media_de(suma: Dictionary, cuenta: Dictionary, divisiones: Array) -> float:
	var s := 0.0
	var n := 0.0
	for d in divisiones:
		s += float(suma.get(d, 0.0))
		n += float(cuenta.get(d, 0))
	return s / max(1.0, n)
