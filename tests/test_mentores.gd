extends SceneTree

## Mentores (§6 extendido) — Mentores.es_mentor/es_aprendiz/mejor_bonus_disponible
## y su conexión con Progresion.aplicar_temporada. Correr con:
## godot --headless --script tests/test_mentores.gd

const SEED := 5252


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_es_mentor_requiere_edad_y_rasgo(rng)
	_test_es_aprendiz_por_edad(rng)
	_test_bonus_disponible_es_el_mejor_no_la_suma(rng)
	_test_sin_mentor_bonus_es_cero(rng)
	_test_joven_crece_mas_rapido_con_mentor(rng)
	_test_veterano_no_se_beneficia_del_mentor(rng)

	quit()


func _jugador_base(rng: RandomNumberGenerator, edad: int, personalidades: Dictionary = {}) -> Dictionary:
	var j := PlayerGenerator.generate(rng.randi(), rng, "MC")
	j["edad"] = edad
	j["personalidades"] = personalidades
	return j


func _test_es_mentor_requiere_edad_y_rasgo(rng: RandomNumberGenerator) -> void:
	print("=== es_mentor(): hace falta edad Y el rasgo correcto ===")
	var joven_con_rasgo := _jugador_base(rng, 24, {"positiva": "Lider nato", "negativa": "Vago"})
	var veterano_sin_rasgo := _jugador_base(rng, 30, {"positiva": "Positivo", "negativa": "Vago"})
	var veterano_con_rasgo := _jugador_base(rng, 30, {"positiva": "Lider nato", "negativa": "Vago"})

	var ok: bool = not Mentores.es_mentor(joven_con_rasgo)
	ok = ok and not Mentores.es_mentor(veterano_sin_rasgo)
	ok = ok and Mentores.es_mentor(veterano_con_rasgo)

	if ok:
		print("OK: ni el joven con rasgo ni el veterano sin rasgo califican; el veterano CON rasgo si.")
	else:
		print("FALLA: joven=%s veterano_sin=%s veterano_con=%s" % [
			Mentores.es_mentor(joven_con_rasgo), Mentores.es_mentor(veterano_sin_rasgo), Mentores.es_mentor(veterano_con_rasgo)
		])


func _test_es_aprendiz_por_edad(rng: RandomNumberGenerator) -> void:
	print("\n=== es_aprendiz(): solo los jovenes ===")
	var joven := _jugador_base(rng, 20)
	var veterano := _jugador_base(rng, 25)

	if Mentores.es_aprendiz(joven) and not Mentores.es_aprendiz(veterano):
		print("OK: 20 años es aprendiz, 25 no.")
	else:
		print("FALLA: joven=%s veterano=%s" % [Mentores.es_aprendiz(joven), Mentores.es_aprendiz(veterano)])


func _test_bonus_disponible_es_el_mejor_no_la_suma(rng: RandomNumberGenerator) -> void:
	print("\n=== mejor_bonus_disponible(): el mejor rasgo presente, no la suma de todos ===")
	var equipo := Team.generar("ClubMentores", rng, 0)
	for j in equipo.jugadores:
		j["edad"] = 30
		j["personalidades"] = {"positiva": "Profesional", "negativa": "Vago"}
	equipo.jugadores[0]["personalidades"] = {"positiva": "Lider nato", "negativa": "Vago"}  # el mejor rasgo

	var bonus := Mentores.mejor_bonus_disponible(equipo)

	if is_equal_approx(bonus, Mentores.BONUS_POR_RASGO["Lider nato"]):
		print("OK: bonus = %.2f (Lider nato), no la suma de todos los Profesional + el Lider nato." % bonus)
	else:
		print("FALLA: bonus=%.2f" % bonus)


func _test_sin_mentor_bonus_es_cero(rng: RandomNumberGenerator) -> void:
	print("\n=== Sin nadie que califique como mentor, el bonus es 0 ===")
	var equipo := Team.generar("ClubSinMentores", rng, 1000)
	for j in equipo.todos_los_jugadores():
		j["edad"] = 22  # todos jovenes, nadie llega a la edad minima de mentor
		j["personalidades"] = {"positiva": "Lider nato", "negativa": "Vago"}

	var bonus := Mentores.mejor_bonus_disponible(equipo)

	if is_equal_approx(bonus, 0.0):
		print("OK: bonus = 0 sin ningun veterano que califique.")
	else:
		print("FALLA: bonus=%.2f" % bonus)


func _test_joven_crece_mas_rapido_con_mentor(rng: RandomNumberGenerator) -> void:
	print("\n=== Progresion.aplicar_temporada: un aprendiz crece mas rapido con el multiplicador de mentor ===")
	var joven_solo := _jugador_base(rng, 19)
	var joven_con_mentor := joven_solo.duplicate(true)
	joven_con_mentor["atributos"] = joven_solo["atributos"].duplicate()

	# Potencial bien por encima de los atributos actuales, para que haya
	# margen de crecimiento real que un mentor pueda acelerar.
	joven_solo["potencial"] = 95
	joven_con_mentor["potencial"] = 95
	for attr in joven_solo["atributos"]:
		joven_solo["atributos"][attr] = 40
		joven_con_mentor["atributos"][attr] = 40

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 777
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 777  # mismo seed que rng2, para que el ruido aleatorio sea igual en ambos casos

	Progresion.aplicar_temporada(joven_solo, rng2, 1.0)
	Progresion.aplicar_temporada(joven_con_mentor, rng3, 1.20)

	var media_solo: float = joven_solo["media"]
	var media_con_mentor: float = joven_con_mentor["media"]

	if media_con_mentor > media_solo:
		print("OK: con mentor la media crecio mas (%.2f) que sin mentor (%.2f)." % [media_con_mentor, media_solo])
	else:
		print("FALLA: solo=%.2f con_mentor=%.2f" % [media_solo, media_con_mentor])


func _test_veterano_no_se_beneficia_del_mentor(rng: RandomNumberGenerator) -> void:
	print("\n=== Un jugador que ya no es aprendiz no se beneficia del multiplicador ===")
	var veterano_a := _jugador_base(rng, 30)
	var veterano_b := veterano_a.duplicate(true)
	veterano_b["atributos"] = veterano_a["atributos"].duplicate()
	veterano_a["potencial"] = 95
	veterano_b["potencial"] = 95

	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 333
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 333

	Progresion.aplicar_temporada(veterano_a, rng2, Mentores.multiplicador_para(veterano_a, 0.20))
	Progresion.aplicar_temporada(veterano_b, rng3, Mentores.multiplicador_para(veterano_b, 0.20))

	if is_equal_approx(veterano_a["media"], veterano_b["media"]):
		print("OK: el multiplicador para un no-aprendiz da 1.0 siempre, resultado identico con o sin mentor en el club.")
	else:
		print("FALLA: a=%.2f b=%.2f" % [veterano_a["media"], veterano_b["media"]])
