extends SceneTree

## Estilos de juego (§8.6.2) — identidad de club: todo equipo tiene uno y
## sobrevive al guardado. Ningún estilo le gana a otro por tabla.
## Correr con: godot --headless --script tests/test_estilos.gd

const SEED := 5252


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_todo_equipo_generado_tiene_estilo(rng)
	_test_estilo_persiste_en_guardado(rng)
	_test_migracion_de_guardado_viejo_sin_estilo(rng)

	quit()


func _test_todo_equipo_generado_tiene_estilo(rng: RandomNumberGenerator) -> void:
	print("=== Todo equipo generado tiene un estilo valido ===")
	var equipo := Team.generar("ClubA", rng, 0)
	if Estilos.LISTA.has(equipo.estilo):
		print("OK: estilo=%s" % equipo.estilo)
	else:
		print("FALLA: estilo=%s" % equipo.estilo)


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
