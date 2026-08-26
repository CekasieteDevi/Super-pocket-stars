extends SceneTree

## §7.4.2: foco de entrenamiento del equipo.

const SEED := 5150


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_enfocar_no_regala_crecimiento()
	_test_area_chica_empuja_mas_por_atributo()
	_test_cambiar_a_mitad_de_temporada_reparte(rng)
	_test_reinicio_por_temporada(rng)
	_test_la_ia_entrena_lo_que_juega(rng)
	_test_guardado(rng)
	quit()


func _total(mult: Dictionary) -> float:
	var t := 0.0
	for k in mult:
		t += float(mult[k])
	return t


func _test_enfocar_no_regala_crecimiento() -> void:
	print("=== Enfocar reparte, no regala ===")
	# Si el total subiera al enfocar, "general" no lo elegiria nadie y el
	# foco seria un boton de mas-es-mejor en vez de una decision.
	var attrs := PlayerGenerator.get_all_attributes()
	var base := _total(FocoEquipo.multiplicadores({FocoEquipo.GENERAL: 1.0}, attrs))
	var ok := true
	for area in FocoEquipo.AREAS:
		var t := _total(FocoEquipo.multiplicadores({area: 1.0}, attrs))
		if absf(t - base) > 0.01:
			print("FALLA: %s suma %.2f contra %.2f de general." % [area, t, base])
			ok = false
	if ok:
		print("OK: las 6 areas suman lo mismo (%.1f)." % base)


func _test_area_chica_empuja_mas_por_atributo() -> void:
	print("\n=== Un area chica empuja mas por atributo ===")
	# Con 8 atributos tecnicos y 2 defensivos, un bonus fijo por atributo
	# haria que tecnico fuera 4 veces mejor y no hubiera nada que elegir.
	var attrs := PlayerGenerator.get_all_attributes()
	var tec := FocoEquipo.multiplicadores({"tecnico": 1.0}, attrs)
	var def := FocoEquipo.multiplicadores({"defensivo": 1.0}, attrs)
	if float(def["quite"]) > float(tec["control"]):
		print("OK: quite con foco defensivo x%.2f > control con foco tecnico x%.2f." % [
			def["quite"], tec["control"]])
	else:
		print("FALLA: quite x%.2f no supera a control x%.2f." % [def["quite"], tec["control"]])


func _test_cambiar_a_mitad_de_temporada_reparte(rng: RandomNumberGenerator) -> void:
	print("\n=== Cambiar de area a mitad de temporada reparte ===")
	var e := Team.generar("Reparto", rng, 0)
	e.reiniciar_carga()
	e.foco_equipo = "defensivo"
	e.avanzar_dias(70)   # 10 semanas
	e.foco_equipo = "tecnico"
	e.avanzar_dias(70)   # otras 10
	var reparto := e.reparto_foco()
	var d: float = float(reparto.get("defensivo", 0.0))
	var t: float = float(reparto.get("tecnico", 0.0))
	if absf(d - 0.5) < 0.01 and absf(t - 0.5) < 0.01:
		print("OK: 50%% defensivo y 50%% tecnico, no solo el ultimo.")
	else:
		print("FALLA: reparto defensivo %.2f / tecnico %.2f." % [d, t])


func _test_reinicio_por_temporada(rng: RandomNumberGenerator) -> void:
	print("\n=== El reparto se reinicia con la temporada ===")
	var e := Team.generar("Reinicio", rng, 0)
	e.foco_equipo = "fisico"
	e.avanzar_dias(70)
	e.reiniciar_carga()
	if e.reparto_foco().is_empty():
		print("OK: arranca la temporada nueva sin semanas acumuladas.")
	else:
		print("FALLA: quedaron semanas de la temporada anterior: %s" % [e.reparto_foco()])


func _test_la_ia_entrena_lo_que_juega(rng: RandomNumberGenerator) -> void:
	print("\n=== Los clubes de la IA entrenan segun su estilo ===")
	# Sin esto los 200 clubes entrenarian "general" y el sistema solo
	# existiria para el jugador.
	var piramide := Piramide.generar(rng)
	var areas := {}
	var coherentes := 0
	var total := 0
	for liga in piramide.divisiones:
		for e in liga.equipos:
			areas[e.foco_equipo] = true
			total += 1
			if e.foco_equipo == FocoEquipo.para_estilo(e.estilo):
				coherentes += 1
	if coherentes == total and areas.size() >= 4:
		print("OK: los %d clubes entrenan segun su estilo, %d areas distintas en la piramide." % [
			total, areas.size()])
	else:
		print("FALLA: %d/%d coherentes, %d areas distintas." % [coherentes, total, areas.size()])


func _test_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== El foco sobrevive al guardado ===")
	var e := Team.generar("Guardado", rng, 0)
	e.reiniciar_carga()
	e.foco_equipo = "pelota_parada"
	e.avanzar_dias(35)
	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(e.guardar())))
	var r_antes := e.reparto_foco()
	var r_despues := vuelto.reparto_foco()
	if vuelto.foco_equipo == "pelota_parada" and absf(
			float(r_antes.get("pelota_parada", 0.0)) - float(r_despues.get("pelota_parada", 0.0))) < 0.01:
		print("OK: area y semanas acumuladas iguales despues de guardar y cargar.")
	else:
		print("FALLA: quedo %s con reparto %s." % [vuelto.foco_equipo, r_despues])
