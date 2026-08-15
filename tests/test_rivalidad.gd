extends SceneTree

## Rival directo / clásico (§8.4 #14, core/rivalidad.gd) — pareo horneado
## por división, tarjetas +50% y varianza extra en el bloque C cuando se
## enfrentan. Correr con: godot --headless --script tests/test_rivalidad.gd

const SEED := 5656


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_hornear_clasicos_empareja_simetrico(rng)
	_test_es_clasico(rng)
	_test_factor_tarjetas(rng)
	_test_variacion_solo_si_es_clasico(rng)
	_test_integracion_piramide_hornea_clasicos_para_los_200(rng)
	_test_integracion_publico_favorece_al_local_con_mas_fans(rng)

	quit()


func _test_hornear_clasicos_empareja_simetrico(rng: RandomNumberGenerator) -> void:
	print("=== hornear_clasicos() empareja de a 2, simetrico (A<->B) ===")
	var equipos := []
	for i in range(6):
		equipos.append(Team.generar("Club%d" % i, rng, i * 100))

	Rivalidad.hornear_clasicos(equipos)

	var ok := true
	for i in range(0, 6, 2):
		var a: Team = equipos[i]
		var b: Team = equipos[i + 1]
		ok = ok and a.rival_directo == b.nombre and b.rival_directo == a.nombre

	if ok:
		print("OK: 3 pares simetricos entre 6 equipos.")
	else:
		print("FALLA: %s" % [equipos.map(func(e): return "%s->%s" % [e.nombre, e.rival_directo])])


func _test_es_clasico(rng: RandomNumberGenerator) -> void:
	print("\n=== es_clasico() da true solo para el par horneado ===")
	var a := Team.generar("A", rng, 0)
	var b := Team.generar("B", rng, 100)
	var c := Team.generar("C", rng, 200)
	a.rival_directo = b.nombre
	b.rival_directo = a.nombre

	var ok := true
	ok = ok and Rivalidad.es_clasico(a, b) == true
	ok = ok and Rivalidad.es_clasico(b, a) == true
	ok = ok and Rivalidad.es_clasico(a, c) == false
	ok = ok and Rivalidad.es_clasico(b, c) == false

	if ok:
		print("OK: solo A-B da true.")
	else:
		print("FALLA")


func _test_factor_tarjetas(rng: RandomNumberGenerator) -> void:
	print("\n=== factor_tarjetas: 1.5x si es clasico, 1.0x si no ===")
	var ok: bool = is_equal_approx(Rivalidad.factor_tarjetas(true), Rivalidad.FACTOR_TARJETAS)
	ok = ok and is_equal_approx(Rivalidad.factor_tarjetas(false), 1.0)
	if ok:
		print("OK: %.1fx vs 1.0x." % Rivalidad.FACTOR_TARJETAS)
	else:
		print("FALLA")


func _test_variacion_solo_si_es_clasico(rng: RandomNumberGenerator) -> void:
	print("\n=== variacion(): siempre 0 si no es clasico, no siempre 0 si lo es ===")
	var ok := true
	for i in range(20):
		if not is_equal_approx(Rivalidad.variacion(false, rng), 0.0):
			ok = false
			break

	var alguna_no_cero := false
	for i in range(20):
		if not is_equal_approx(Rivalidad.variacion(true, rng), 0.0):
			alguna_no_cero = true
			break

	if ok and alguna_no_cero:
		print("OK: sin clasico siempre 0, con clasico varia.")
	else:
		print("FALLA: sin_clasico_siempre_cero=%s alguna_variacion=%s" % [ok, alguna_no_cero])


func _test_integracion_piramide_hornea_clasicos_para_los_200(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: Piramide.generar() le da un clasico real a los 200 equipos ===")
	var piramide := Piramide.generar(rng)
	var ok := true
	var revisados := 0
	for liga in piramide.divisiones:
		var nombres_division := {}
		for equipo in liga.equipos:
			nombres_division[equipo.nombre] = true
		for equipo in liga.equipos:
			revisados += 1
			if equipo.rival_directo == "" or not nombres_division.has(equipo.rival_directo):
				ok = false

	if ok and revisados == 200:
		print("OK: 200 equipos revisados, todos con un rival_directo real de su propia division de origen.")
	else:
		print("FALLA: ok=%s revisados=%d" % [ok, revisados])


func _test_integracion_publico_favorece_al_local_con_mas_fans(rng: RandomNumberGenerator) -> void:
	print("\n=== Integracion: mas fans de local se nota en el resultado (promedio de goles) ===")
	var home := Team.generar("HomeFans", rng, 0)
	var away := Team.generar("AwayFans", rng, 100)

	var muestras := 300
	home.fans = 0.0
	var goles_sin_fans := 0
	for i in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 8000 + i
		goles_sin_fans += MatchEngine.simular(home, away, r, false)["goles_local"]

	home.fans = 100.0
	var goles_con_fans := 0
	for i in range(muestras):
		var r := RandomNumberGenerator.new()
		r.seed = 8000 + i
		goles_con_fans += MatchEngine.simular(home, away, r, false)["goles_local"]

	if goles_con_fans > goles_sin_fans:
		print("OK: con 100 fans de local, %d goles en %d partidos vs %d con 0 fans." % [goles_con_fans, muestras, goles_sin_fans])
	else:
		print("FALLA: sin_fans=%d con_fans=%d" % [goles_sin_fans, goles_con_fans])
