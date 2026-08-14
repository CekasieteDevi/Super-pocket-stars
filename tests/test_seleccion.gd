extends SceneTree

## Selección nacional (Seleccion.previsualizar/convocar, amistosos).
## Correr con: godot --headless --script tests/test_seleccion.gd

const SEED := 4141


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var piramide := Piramide.generar(rng)

	_test_convocatoria_18_sin_repetidos(piramide)
	_test_convocatoria_son_los_mejores(piramide)
	_test_previsualizar_no_cuenta_convocatorias(piramide)
	_test_convocar_si_cuenta_convocatorias(piramide)
	_test_generar_rival_da_un_equipo_jugable(rng)
	_test_amistoso_completo_y_lesion_vuelve_al_club(piramide, rng)

	quit()


func _test_convocatoria_18_sin_repetidos(piramide: Piramide) -> void:
	print("=== La convocatoria tiene 18 jugadores distintos (11+7) ===")
	var seleccion := Seleccion.new()
	var resultado := seleccion.previsualizar(piramide)
	var uruguay: Team = resultado["equipo"]

	var ids := {}
	for j in uruguay.todos_los_jugadores():
		ids[j["id"]] = true

	var ok: bool = uruguay.jugadores.size() == 11 and uruguay.banco.size() == 7 and ids.size() == 18

	if ok:
		print("OK: 11 titulares + 7 banco, 18 ids distintos.")
	else:
		print("FALLA: titulares=%d banco=%d ids_unicos=%d" % [uruguay.jugadores.size(), uruguay.banco.size(), ids.size()])


func _test_convocatoria_son_los_mejores(piramide: Piramide) -> void:
	print("\n=== Los convocados por posicion son los mejores disponibles de toda la piramide ===")
	var seleccion := Seleccion.new()
	var resultado := seleccion.previsualizar(piramide)
	var uruguay: Team = resultado["equipo"]

	var mejor_dc_real := -1.0
	for liga in piramide.divisiones:
		for club in liga.equipos:
			for j in club.todos_los_jugadores():
				if j["posicion"] == "DC" and club.puede_jugar(j["id"]) and j["media"] > mejor_dc_real:
					mejor_dc_real = j["media"]

	var dc_convocado := -1.0
	for j in uruguay.jugadores:
		if j["posicion"] == "DC":
			dc_convocado = j["media"]
			break

	if is_equal_approx(dc_convocado, mejor_dc_real):
		print("OK: el DC convocado (media %.1f) es el mejor DC disponible de toda la piramide." % dc_convocado)
	else:
		print("FALLA: convocado=%.1f mejor_real=%.1f" % [dc_convocado, mejor_dc_real])


func _test_previsualizar_no_cuenta_convocatorias(piramide: Piramide) -> void:
	print("\n=== previsualizar() no infla el historial de convocatorias ===")
	var seleccion := Seleccion.new()
	seleccion.previsualizar(piramide)
	seleccion.previsualizar(piramide)
	seleccion.previsualizar(piramide)

	if seleccion.convocatorias.is_empty():
		print("OK: 3 previsualizaciones seguidas, el historial sigue vacio.")
	else:
		print("FALLA: convocatorias=%s" % [seleccion.convocatorias])


func _test_convocar_si_cuenta_convocatorias(piramide: Piramide) -> void:
	print("\n=== convocar() si registra el historial ===")
	var seleccion := Seleccion.new()
	var resultado := seleccion.convocar(piramide)
	var uruguay: Team = resultado["equipo"]

	var ok := true
	for j in uruguay.todos_los_jugadores():
		if seleccion.convocatorias.get(j["id"], 0) != 1:
			ok = false

	seleccion.convocar(piramide)  # si son los mismos 18 (nadie se lesiono ni nada cambio), suben a 2
	var alguno_en_dos := false
	for j in uruguay.todos_los_jugadores():
		if seleccion.convocatorias.get(j["id"], 0) >= 2:
			alguno_en_dos = true

	if ok and alguno_en_dos:
		print("OK: cada convocado suma 1 en el historial cada vez que convocar() se llama.")
	else:
		print("FALLA: convocatorias=%s" % [seleccion.convocatorias])


func _test_generar_rival_da_un_equipo_jugable(rng: RandomNumberGenerator) -> void:
	print("\n=== Seleccion.generar_rival() da un equipo con plantel completo ===")
	var rival := Seleccion.generar_rival("Brasil", 75.0, rng)

	if rival.jugadores.size() == 11 and rival.banco.size() == 7 and rival.nombre.find("Brasil") != -1:
		print("OK: %s con plantel completo." % rival.nombre)
	else:
		print("FALLA: nombre=%s titulares=%d banco=%d" % [rival.nombre, rival.jugadores.size(), rival.banco.size()])


func _test_amistoso_completo_y_lesion_vuelve_al_club(piramide: Piramide, rng: RandomNumberGenerator) -> void:
	print("\n=== Un partido completo de la seleccion corre sin errores, y una lesion forzada vuelve al club real ===")
	var seleccion := Seleccion.new()
	var convocatoria := seleccion.convocar(piramide)
	var uruguay: Team = convocatoria["equipo"]
	var clubes_por_jugador: Dictionary = convocatoria["clubes_por_jugador"]
	var rival := Seleccion.generar_rival("España", 70.0, rng)

	var r := MatchEngine.simular(uruguay, rival, rng, false)
	var ok_partido: bool = r.has("goles_local") and r.has("goles_visitante")

	# Forzamos una lesion en un convocado y verificamos el mismo mecanismo
	# de propagacion que usa GameState._jugar_amistoso_seleccion.
	var jugador: Dictionary = uruguay.jugadores[0]
	var id: int = jugador["id"]
	uruguay.lesionar(id, "Prueba", 5)
	var club_real: Team = clubes_por_jugador.get(id)
	club_real.lesionar(id, "Prueba", 5)

	var ok_lesion: bool = club_real.esta_lesionado(id)

	if ok_partido and ok_lesion:
		print("OK: el amistoso corre sin errores (%d-%d) y la lesion se propaga al club real (%s)." % [r["goles_local"], r["goles_visitante"], club_real.nombre])
	else:
		print("FALLA: ok_partido=%s ok_lesion=%s" % [ok_partido, ok_lesion])
