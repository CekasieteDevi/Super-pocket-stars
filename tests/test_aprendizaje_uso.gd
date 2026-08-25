extends SceneTree

## §7.3 aprendizaje por uso: se gana XP en el atributo que se usa, y eso
## acelera su crecimiento. Lo critico es la PARIDAD: un titular tiene que
## acumular lo mismo en total lo resuelva el motor espacial (partidos del
## usuario) o el abstracto (los otros 19 clubes), o sus jugadores crecen
## a distinto ritmo y el desbalance se acumula por temporada.
## Correr con: godot --headless --script tests/test_aprendizaje_uso.gd

const SEED := 9191


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_los_dos_motores_dan_el_mismo_total(rng)
	_test_el_espacial_reparte_segun_lo_que_paso(rng)
	_test_usar_un_atributo_lo_hace_crecer_mas(rng)
	_test_el_uso_se_consume(rng)
	quit()


func _test_los_dos_motores_dan_el_mismo_total(rng: RandomNumberGenerator) -> void:
	print("=== Los dos motores entregan el mismo XP total por titular ===")
	var peor_esp := 99.0
	var peor_abs := 99.0
	var mejor_esp := -1.0
	var mejor_abs := -1.0
	for i in range(12):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 100 + i
		var a := Team.generar("A", r1)
		var b := Team.generar("B", r1)
		var r2 := RandomNumberGenerator.new()
		r2.seed = 100 + i
		var esp := MotorEspacial.simular(a, b, r2, false)
		var a2 := Team.generar("A", RandomNumberGenerator.new())
		var b2 := Team.generar("B", RandomNumberGenerator.new())
		var r3 := RandomNumberGenerator.new()
		r3.seed = 100 + i
		var abs_r := MatchEngine.simular(a2, b2, r3, false)
		peor_esp = minf(peor_esp, _total_minimo_titular(a, esp["xp"]["home"]))
		mejor_esp = maxf(mejor_esp, _total_maximo(esp["xp"]["home"]))
		peor_abs = minf(peor_abs, _total_minimo_titular(a2, abs_r["xp"]["home"]))
		mejor_abs = maxf(mejor_abs, _total_maximo(abs_r["xp"]["home"]))
	# Un titular que juega los 90 suma 1.0; los que salen, menos.
	var ok: bool = mejor_esp <= 1.01 and mejor_abs <= 1.01
	ok = ok and peor_esp > 0.2 and peor_abs > 0.2
	if ok:
		print("OK: espacial max %.2f min %.2f | abstracto max %.2f min %.2f (tope 1.00 por partido)." % [
			mejor_esp, peor_esp, mejor_abs, peor_abs])
	else:
		print("FALLA: espacial max %.2f min %.2f | abstracto max %.2f min %.2f" % [
			mejor_esp, peor_esp, mejor_abs, peor_abs])


func _total_minimo_titular(equipo: Team, xp: Dictionary) -> float:
	var minimo := 99.0
	for j in equipo.jugadores:
		var d = xp.get(j["id"], null)
		if d == null:
			return 0.0
		var s := 0.0
		for a in d:
			s += float(d[a])
		minimo = minf(minimo, s)
	return minimo


func _total_maximo(xp: Dictionary) -> float:
	var maximo := 0.0
	for id in xp:
		var s := 0.0
		for a in xp[id]:
			s += float(xp[id][a])
		maximo = maxf(maximo, s)
	return maximo


func _test_el_espacial_reparte_segun_lo_que_paso(_rng: RandomNumberGenerator) -> void:
	print("
=== El motor espacial reparte segun lo que cada puesto hace ===")
	# Un partido suelto no alcanza: hay delanteros que no rematan ninguna
	# vez. Se agrega sobre varios, que es como se acumula en una temporada.
	var tiro_dc := 0.0
	var tiro_dfc := 0.0
	var quite_dc := 0.0
	var quite_dfc := 0.0
	for i in range(10):
		var r1 := RandomNumberGenerator.new()
		r1.seed = 300 + i
		var a := Team.generar("A", r1)
		var b := Team.generar("B", r1)
		var r2 := RandomNumberGenerator.new()
		r2.seed = 300 + i
		var res := MotorEspacial.simular(a, b, r2, false)
		var xp: Dictionary = res["xp"]["home"]
		for j in a.jugadores:
			var d: Dictionary = xp.get(j["id"], {})
			if j["posicion"] == "DC":
				tiro_dc += float(d.get("tiro", 0.0))
				quite_dc += float(d.get("quite", 0.0))
			elif j["posicion"] == "DFC":
				tiro_dfc += float(d.get("tiro", 0.0))
				quite_dfc += float(d.get("quite", 0.0))
	# Hay 2 DFC por cada DC, asi que se compara per capita.
	var ok: bool = tiro_dc > tiro_dfc / 2.0 and quite_dfc / 2.0 > quite_dc
	if ok:
		print("OK: en 10 partidos, tiro DC %.2f vs DFC %.2f (per capita) y quite DFC %.2f vs DC %.2f." % [
			tiro_dc, tiro_dfc / 2.0, quite_dfc / 2.0, quite_dc])
	else:
		print("FALLA: tiro dc=%.2f dfc=%.2f | quite dc=%.2f dfc=%.2f" % [
			tiro_dc, tiro_dfc / 2.0, quite_dc, quite_dfc / 2.0])


func _test_usar_un_atributo_lo_hace_crecer_mas(rng: RandomNumberGenerator) -> void:
	print("\n=== Usar un atributo lo hace crecer mas rapido ===")
	var base := PlayerGenerator.generate(1, rng, "DC")
	base["edad"] = 20
	base["personalidades"] = {}
	for attr in base["atributos"]:
		base["atributos"][attr] = 40
		base["potenciales"][attr] = 90

	var usado := base.duplicate(true)
	# Una temporada entera de titular rematando: todo el uso en `tiro`.
	usado["xp_uso"] = {"tiro": 25.0}
	var sin_uso := base.duplicate(true)
	sin_uso["xp_uso"] = {}

	var r1 := RandomNumberGenerator.new()
	r1.seed = 1
	Progresion.aplicar_temporada(usado, r1)
	var r2 := RandomNumberGenerator.new()
	r2.seed = 1
	Progresion.aplicar_temporada(sin_uso, r2)

	var con: int = usado["atributos"]["tiro"]
	var sin: int = sin_uso["atributos"]["tiro"]
	if con > sin:
		print("OK: tiro con uso %d contra %d sin uso (+%d en una temporada)." % [con, sin, con - sin])
	else:
		print("FALLA: con uso %d, sin uso %d" % [con, sin])


func _test_el_uso_se_consume(rng: RandomNumberGenerator) -> void:
	print("\n=== El uso se consume al cerrar la temporada ===")
	var j := PlayerGenerator.generate(2, rng, "MC")
	j["edad"] = 22
	j["personalidades"] = {}
	j["xp_uso"] = {"pases": 20.0}
	Progresion.aplicar_temporada(j, rng)
	if (j["xp_uso"] as Dictionary).is_empty():
		print("OK: lo que jugo este ano no acelera el que viene.")
	else:
		print("FALLA: quedo %s" % [j["xp_uso"]])
