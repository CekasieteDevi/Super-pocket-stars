extends SceneTree

## §7.2: cada atributo tiene su propio techo. Lo que se prueba es que dos
## jugadores del MISMO potencial global salgan distintos, que el
## crecimiento respete el techo de cada atributo y no el global, y que un
## guardado viejo (sin el campo) se migre en vez de quedar plano.
## Correr con: godot --headless --script tests/test_potencial_por_atributo.gd

const SEED := 7272


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_dos_prodigios_son_distintos(rng)
	_test_el_crecimiento_respeta_el_techo_propio(rng)
	_test_nadie_pasa_su_techo(rng)
	_test_guardado_viejo_se_migra(rng)
	quit()


func _test_dos_prodigios_son_distintos(rng: RandomNumberGenerator) -> void:
	print("=== Dos jugadores del mismo potencial tienen techos distintos ===")
	var a := PlayerGenerator.techos_por_atributo(80, rng)
	var b := PlayerGenerator.techos_por_atributo(80, rng)
	var distintos := 0
	var rango_a := 0
	var min_a := 999
	var max_a := -999
	for attr in a:
		if a[attr] != b[attr]:
			distintos += 1
		min_a = mini(min_a, int(a[attr]))
		max_a = maxi(max_a, int(a[attr]))
	rango_a = max_a - min_a
	# Con desvio 9 sobre 25 atributos, el rango tipico ronda los 30 puntos.
	if distintos >= 20 and rango_a >= 15:
		print("OK: %d de %d techos difieren; uno va de %d a %d (rango %d)." % [
			distintos, a.size(), min_a, max_a, rango_a])
	else:
		print("FALLA: distintos=%d rango=%d (se esperaba individualidad)" % [distintos, rango_a])


func _test_el_crecimiento_respeta_el_techo_propio(rng: RandomNumberGenerator) -> void:
	print("\n=== Un atributo con techo alto crece y uno con techo bajo no ===")
	var j := PlayerGenerator.generate(1, rng, "DC")
	j["edad"] = 20
	j["potencial"] = 90
	j["genetica_tier"] = "Idolo"
	j["personalidades"] = {}
	for attr in j["atributos"]:
		j["atributos"][attr] = 40
	j["potenciales"]["tiro"] = 95
	j["potenciales"]["quite"] = 42
	for t in range(4):
		Progresion.aplicar_temporada(j, rng)
	var tiro: int = j["atributos"]["tiro"]
	var quite: int = j["atributos"]["quite"]
	if tiro > 60 and quite < 50:
		print("OK: tiro 40 -> %d (techo 95), quite 40 -> %d (techo 42)." % [tiro, quite])
	else:
		print("FALLA: tiro=%d quite=%d" % [tiro, quite])


func _test_nadie_pasa_su_techo(rng: RandomNumberGenerator) -> void:
	print("\n=== Nadie crece mucho mas alla de su techo ===")
	var peor := 0
	for i in range(40):
		var j := PlayerGenerator.generate(i, rng)
		j["edad"] = 19
		j["personalidades"] = {}
		for t in range(12):
			Progresion.aplicar_temporada(j, rng)
		for attr in j["atributos"]:
			peor = maxi(peor, int(j["atributos"][attr]) - Progresion.techo_de(j, attr))
	# El techo es duro durante el crecimiento: el ruido no empuja arriba.
	if peor <= 0:
		print("OK: nadie supero su techo (maximo excedido: %d)." % peor)
	else:
		print("FALLA: alguien supero su techo por %d puntos" % peor)


func _test_guardado_viejo_se_migra(rng: RandomNumberGenerator) -> void:
	print("\n=== Un guardado sin techos se migra, no queda plano ===")
	var equipo := Team.generar("Viejo", rng)
	var datos := equipo.guardar()
	for lista in ["jugadores", "banco"]:
		for j in datos[lista]:
			j.erase("potenciales")
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	var j0: Dictionary = cargado.jugadores[0]
	var techos: Dictionary = j0.get("potenciales", {})
	var min_t := 999
	var max_t := -999
	for attr in techos:
		min_t = mini(min_t, int(techos[attr]))
		max_t = maxi(max_t, int(techos[attr]))
	# Y tiene que ser ESTABLE: cargar dos veces da lo mismo.
	var cargado2 := Team.cargar(JSON.parse_string(JSON.stringify(datos)))
	var igual: bool = cargado2.jugadores[0]["potenciales"] == techos

	if not techos.is_empty() and (max_t - min_t) >= 10 and igual:
		print("OK: migrado a techos de %d a %d, y estable entre cargas." % [min_t, max_t])
	else:
		print("FALLA: techos=%d rango=%d estable=%s" % [techos.size(), max_t - min_t, igual])
