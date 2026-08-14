extends SceneTree

## Foco individual (§7.4 punto 3, core/entrenamiento.gd) — cupos segun
## instalaciones, asignar/quitar, racha de temporadas consecutivas, y el
## auto-asignado de la IA. Correr con:
## godot --headless --script tests/test_entrenamiento.gd

const SEED := 7474


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_limite_sigue_el_nivel_de_instalaciones(rng)
	_test_asignar_respeta_el_cupo(rng)
	_test_reasignar_el_mismo_jugador_no_gasta_cupo_extra(rng)
	_test_quitar(rng)
	_test_actualizar_racha(rng)
	_test_ia_mantiene_el_foco_existente_y_llena_cupos(rng)
	_test_integracion_progresion_dobla_solo_el_atributo_en_foco(rng)
	_test_foco_individual_persiste_en_guardado(rng)

	quit()


func _test_limite_sigue_el_nivel_de_instalaciones(rng: RandomNumberGenerator) -> void:
	print("=== limite() sigue el nivel de instalaciones de entrenamiento ===")
	var equipo := Team.generar("ClubA", rng, 0)
	equipo.instalaciones["entrenamiento"] = 1
	var limite1 := Entrenamiento.limite(equipo)
	equipo.instalaciones["entrenamiento"] = 5
	var limite5 := Entrenamiento.limite(equipo)
	if limite1 == 1 and limite5 == 5:
		print("OK: nivel 1 -> 1 cupo, nivel 5 -> 5 cupos.")
	else:
		print("FALLA: limite1=%d limite5=%d" % [limite1, limite5])


func _test_asignar_respeta_el_cupo(rng: RandomNumberGenerator) -> void:
	print("\n=== asignar() rechaza pasar el cupo, pero permite hasta el limite ===")
	var equipo := Team.generar("ClubB", rng, 0)
	equipo.instalaciones["entrenamiento"] = 2
	var ids := []
	for j in equipo.banco:
		ids.append(j["id"])

	var ok := true
	ok = ok and Entrenamiento.asignar(equipo, ids[0], "tiro") == true
	ok = ok and Entrenamiento.asignar(equipo, ids[1], "pases") == true
	ok = ok and Entrenamiento.asignar(equipo, ids[2], "control") == false  # ya no hay cupo
	ok = ok and equipo.foco_individual.size() == 2

	if ok:
		print("OK: 2 cupos, el tercero se rechaza.")
	else:
		print("FALLA: foco_individual=%s" % [equipo.foco_individual])


func _test_reasignar_el_mismo_jugador_no_gasta_cupo_extra(rng: RandomNumberGenerator) -> void:
	print("\n=== Reasignarle el atributo a alguien que YA tenia foco no cuenta como cupo nuevo ===")
	var equipo := Team.generar("ClubC", rng, 0)
	equipo.instalaciones["entrenamiento"] = 1
	var id: int = equipo.banco[0]["id"]

	var ok := true
	ok = ok and Entrenamiento.asignar(equipo, id, "tiro") == true
	ok = ok and Entrenamiento.asignar(equipo, id, "pases") == true  # mismo jugador, cambia el atributo
	ok = ok and equipo.foco_individual[id] == "pases"
	ok = ok and equipo.foco_individual.size() == 1

	if ok:
		print("OK: reasignar el mismo jugador cambia el atributo sin pedir un cupo nuevo.")
	else:
		print("FALLA: foco_individual=%s" % [equipo.foco_individual])


func _test_quitar(rng: RandomNumberGenerator) -> void:
	print("\n=== quitar() libera el cupo ===")
	var equipo := Team.generar("ClubD", rng, 0)
	var id: int = equipo.banco[0]["id"]
	Entrenamiento.asignar(equipo, id, "tiro")
	Entrenamiento.quitar(equipo, id)
	if not equipo.foco_individual.has(id):
		print("OK: el jugador ya no tiene foco asignado.")
	else:
		print("FALLA")


func _test_actualizar_racha(rng: RandomNumberGenerator) -> void:
	print("\n=== actualizar_racha(): mismo atributo suma, distinto o vacio corta la racha ===")
	var jugador := PlayerGenerator.generate(0, rng, "MC")

	Entrenamiento.actualizar_racha(jugador, "tiro")
	var ok: bool = jugador["foco_atributo"] == "tiro" and jugador["foco_temporadas_consecutivas"] == 1

	Entrenamiento.actualizar_racha(jugador, "tiro")
	ok = ok and jugador["foco_temporadas_consecutivas"] == 2

	Entrenamiento.actualizar_racha(jugador, "pases")  # cambio de atributo
	ok = ok and jugador["foco_atributo"] == "pases" and jugador["foco_temporadas_consecutivas"] == 1

	Entrenamiento.actualizar_racha(jugador, "")  # sin foco esta temporada
	ok = ok and jugador["foco_atributo"] == "" and jugador["foco_temporadas_consecutivas"] == 0

	if ok:
		print("OK: la racha sube con el mismo atributo, se resetea a 1 si cambia y a 0 si se saca el foco.")
	else:
		print("FALLA: %s" % [jugador.get("foco_atributo")])


func _test_ia_mantiene_el_foco_existente_y_llena_cupos(rng: RandomNumberGenerator) -> void:
	print("\n=== La IA mantiene el foco de quien ya lo tenia y llena los cupos que sobran ===")
	var equipo := Team.generar("ClubIA", rng, 0)
	equipo.instalaciones["entrenamiento"] = 3
	var id_existente: int = equipo.banco[0]["id"]
	equipo.banco[0]["edad"] = 19
	equipo.foco_individual[id_existente] = "control"
	equipo.banco[0]["foco_atributo"] = "control"
	equipo.banco[0]["foco_temporadas_consecutivas"] = 1

	Entrenamiento.asignar_foco_automatico_ia(equipo, rng)

	var ok := true
	ok = ok and equipo.foco_individual.get(id_existente, "") == "control"  # no lo toco
	ok = ok and equipo.foco_individual.size() <= 3
	ok = ok and equipo.foco_individual.size() >= 1  # al menos mantuvo el que ya tenia

	if ok:
		print("OK: mantiene el foco existente (%d/%d cupos usados)." % [equipo.foco_individual.size(), 3])
	else:
		print("FALLA: foco_individual=%s" % [equipo.foco_individual])


func _test_integracion_progresion_dobla_solo_el_atributo_en_foco(rng: RandomNumberGenerator) -> void:
	print("\n=== Progresion.aplicar_temporada: el foco dobla SOLO el atributo elegido ===")
	var base := PlayerGenerator.generate(0, rng, "MC")
	base["potencial"] = 90
	base["edad"] = 20
	for attr in base["atributos"]:
		base["atributos"][attr] = 40

	var sin_foco: Dictionary = base.duplicate(true)
	var con_foco: Dictionary = base.duplicate(true)

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 111
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 111

	Progresion.aplicar_temporada(sin_foco, rng_a, 1.0, 1.0, "")
	Progresion.aplicar_temporada(con_foco, rng_b, 1.0, 1.0, "tiro")

	var crecio_tiro_mas: bool = con_foco["atributos"]["tiro"] > sin_foco["atributos"]["tiro"]
	var otro_atributo := "pases"
	var igual_en_otro: bool = con_foco["atributos"][otro_atributo] == sin_foco["atributos"][otro_atributo]

	if crecio_tiro_mas and igual_en_otro:
		print("OK: tiro %d (sin foco) -> %d (con foco), %s sin cambios (%d en ambos)." % [
			sin_foco["atributos"]["tiro"], con_foco["atributos"]["tiro"], otro_atributo, con_foco["atributos"][otro_atributo]
		])
	else:
		print("FALLA: tiro sin=%d con=%d, %s sin=%d con=%d" % [
			sin_foco["atributos"]["tiro"], con_foco["atributos"]["tiro"],
			otro_atributo, sin_foco["atributos"][otro_atributo], con_foco["atributos"][otro_atributo]
		])


func _test_foco_individual_persiste_en_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== foco_individual (Team) y foco_atributo/racha (jugador) sobreviven un guardar/cargar ===")
	var equipo := Team.generar("ClubGuardadoFoco", rng, 0)
	var id: int = equipo.banco[0]["id"]
	Entrenamiento.asignar(equipo, id, "tiro")
	equipo.banco[0]["foco_atributo"] = "tiro"
	equipo.banco[0]["foco_temporadas_consecutivas"] = 2

	var datos := equipo.guardar()
	var cargado := Team.cargar(JSON.parse_string(JSON.stringify(datos)))

	var jugador_cargado := {}
	for j in cargado.banco:
		if j["id"] == id:
			jugador_cargado = j
			break

	var ok: bool = cargado.foco_individual.get(id, "") == "tiro"
	ok = ok and jugador_cargado.get("foco_atributo", "") == "tiro"
	ok = ok and jugador_cargado.get("foco_temporadas_consecutivas", -1) == 2
	ok = ok and typeof(jugador_cargado["foco_temporadas_consecutivas"]) == TYPE_INT
	ok = ok and typeof(id) == typeof(cargado.foco_individual.keys()[0])  # la clave sigue siendo int, no string

	if ok:
		print("OK: round-trip preserva el foco del equipo y la racha del jugador (como int).")
	else:
		print("FALLA: foco_individual=%s jugador=%s" % [cargado.foco_individual, jugador_cargado])
