extends SceneTree

## Estilos de juego (§8.6.2/§8.6.3) — identidad de club, choque de estilos
## como modificador de bloque C, y que el motor de partido lo tenga en
## cuenta de verdad (no solo en el módulo aislado).
## Correr con: godot --headless --script tests/test_estilos.gd

const SEED := 5252


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_todo_equipo_generado_tiene_estilo(rng)
	_test_modificador_gana_y_pierde(rng)
	_test_modificador_sin_estilo_es_cero()
	_test_estilo_persiste_en_guardado(rng)
	_test_migracion_de_guardado_viejo_sin_estilo(rng)
	_test_bloque_c_del_motor_incluye_el_choque(rng)

	quit()


func _test_todo_equipo_generado_tiene_estilo(rng: RandomNumberGenerator) -> void:
	print("=== Todo equipo generado tiene un estilo valido ===")
	var equipo := Team.generar("ClubA", rng, 0)
	if Estilos.LISTA.has(equipo.estilo):
		print("OK: estilo=%s" % equipo.estilo)
	else:
		print("FALLA: estilo=%s" % equipo.estilo)


func _test_modificador_gana_y_pierde(rng: RandomNumberGenerator) -> void:
	print("\n=== La tabla de matchups del GDD se respeta ===")
	var ok := true
	ok = ok and is_equal_approx(Estilos.modificador("Tiki taka", "Presión alta"), Estilos.BONUS)
	ok = ok and is_equal_approx(Estilos.modificador("Tiki taka", "Defensivo"), -Estilos.BONUS)
	ok = ok and is_equal_approx(Estilos.modificador("Defensivo", "Contragolpe"), Estilos.BONUS)
	ok = ok and is_equal_approx(Estilos.modificador("Físico", "Juego directo"), -Estilos.BONUS)
	ok = ok and is_equal_approx(Estilos.modificador("Físico", "Defensivo"), 0.0)  # matchup no declarado -> neutro
	if ok:
		print("OK: gana/pierde/neutro coinciden con la tabla del GDD.")
	else:
		print("FALLA en algun matchup de la tabla.")


func _test_modificador_sin_estilo_es_cero() -> void:
	print("\n=== Sin estilo (equipo viejo de un guardado previo) no rompe, da 0 ===")
	if is_equal_approx(Estilos.modificador("", "Tiki taka"), 0.0) and is_equal_approx(Estilos.modificador("Tiki taka", ""), 0.0):
		print("OK: estilo vacio no aporta modificador.")
	else:
		print("FALLA")


func _test_estilo_persiste_en_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== El estilo sobrevive un guardar/cargar (JSON real) ===")
	var equipo := Team.generar("ClubGuardado", rng, 0)
	var estilo_original: String = equipo.estilo
	var datos := equipo.guardar()
	var texto := JSON.stringify(datos)
	var datos_parseados = JSON.parse_string(texto)
	var equipo_cargado := Team.cargar(datos_parseados)

	if equipo_cargado.estilo == estilo_original:
		print("OK: estilo=%s sobrevivio el round-trip." % estilo_original)
	else:
		print("FALLA: original=%s cargado=%s" % [estilo_original, equipo_cargado.estilo])


func _test_migracion_de_guardado_viejo_sin_estilo(rng: RandomNumberGenerator) -> void:
	print("\n=== Un guardado de antes de esta feature (sin 'estilo') se migra en vez de quedar vacio ===")
	var equipo := Team.generar("ClubViejo", rng, 0)
	var datos := equipo.guardar()
	datos.erase("estilo")  # simula un guardado hecho antes de que existiera el campo
	var texto := JSON.stringify(datos)
	var datos_parseados = JSON.parse_string(texto)

	var cargado_1 := Team.cargar(datos_parseados)
	var cargado_2 := Team.cargar(datos_parseados)

	if Estilos.LISTA.has(cargado_1.estilo) and cargado_1.estilo == cargado_2.estilo:
		print("OK: se le asigno '%s', y es estable entre cargas sucesivas del mismo guardado." % cargado_1.estilo)
	else:
		print("FALLA: cargado_1=%s cargado_2=%s" % [cargado_1.estilo, cargado_2.estilo])


func _test_bloque_c_del_motor_incluye_el_choque(rng: RandomNumberGenerator) -> void:
	print("\n=== El motor de partido usa el choque de estilos, no solo Estilos.gd aislado ===")
	# Mismos dos planteles (mismos atributos) en las dos tandas, variando
	# solo el estilo de away entre "le gana a home" y "neutro" -- un solo
	# partido puede irse para cualquier lado por azar, asi que se promedia
	# sobre muchos partidos con seeds distintas para que el +3/-3pp del
	# choque de estilos se note en el agregado. Con el bloque D de
	# Personalidad ahora atado al minuto (Lento de arranque/Se apaga/
	# Clutch/etc.), cada partido individual tiene mas varianza que antes,
	# asi que 150 muestras dejaron de alcanzar de forma confiable -- 500
	# es donde el efecto del estilo (+569 de diferencia a los 800) ya se
	# separa con margen del ruido de fondo.
	var home := Team.generar("Home", rng, 0)
	var away := Team.generar("Away", rng, 100)
	home.estilo = "Tiki taka"
	# §7.4.5: cambiar el estilo a mano estrena una tactica, y eso resta
	# hasta -8 en TODOS los duelos. Sin volver a sembrar la familiaridad,
	# este test medía el matchup de estilos mas una penalizacion distinta
	# en cada tanda, y la penalizacion es mas grande que el efecto que se
	# quiere medir.
	_reasentar_tactica(home)

	var muestras := 500
	var goles_con_ventaja := 0
	away.estilo = "Presión alta"  # Tiki taka le gana a Presion alta -> +3 para home
	_reasentar_tactica(away)
	for i in range(muestras):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 1000 + i
		goles_con_ventaja += MatchEngine.simular(home, away, rng_partido)["goles_local"]

	var goles_neutro := 0
	away.estilo = "Tiki taka"  # mismo estilo, matchup neutro (0 modificador)
	_reasentar_tactica(away)
	for i in range(muestras):
		var rng_partido := RandomNumberGenerator.new()
		rng_partido.seed = 1000 + i
		goles_neutro += MatchEngine.simular(home, away, rng_partido)["goles_local"]

	if goles_con_ventaja > goles_neutro:
		print("OK: con matchup favorable, home hizo %d goles en %d partidos vs %d neutro." % [goles_con_ventaja, muestras, goles_neutro])
	else:
		print("FALLA: con matchup=%d neutro=%d (deberia ser mayor)." % [goles_con_ventaja, goles_neutro])


## Deja al equipo con su tactica actual ya asimilada. Lo necesita
## cualquier test que cambie `estilo` o `formacion` a mano: en el juego
## eso se paga con familiaridad (§7.4.5), pero aca lo unico que se quiere
## medir es otra cosa.
func _reasentar_tactica(equipo: Team) -> void:
	equipo.familiaridad = Familiaridad.inicial(equipo.formacion, equipo.estilo)
