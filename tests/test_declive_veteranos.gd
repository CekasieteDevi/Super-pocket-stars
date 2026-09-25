extends SceneTree

## Crece hasta 32; desde 35, la vitalidad amortigua declive y retiro.


func _init() -> void:
	var base_rng := RandomNumberGenerator.new()
	base_rng.seed = 33043
	var base := PlayerGenerator.generate(1, base_rng, "DC", 95)
	for atributo in base["atributos"]:
		base["atributos"][atributo] = 85
		base["potenciales"][atributo] = 100
	base["potencial"] = 100
	base["media"] = PlayerGenerator.compute_media(base["atributos"], "DC")

	var a_32 := _envejecer(base, 31, 77, 50)
	var a_35 := _envejecer(base, 34, 77, 50)
	var a_40_baja := _envejecer(base, 39, 77, 10)
	var a_40_alta := _envejecer(base, 39, 77, 95)
	var perdida_35 := 85.0 - float(a_35["media"])
	var perdida_40_baja := 85.0 - float(a_40_baja["media"])
	var perdida_40_alta := 85.0 - float(a_40_alta["media"])

	if float(a_32["media"]) >= 85.0 and perdida_35 > 0.0 \
			and perdida_40_baja > perdida_40_alta \
			and int(a_40_baja["atributos"]["tiro"]) < int(a_40_alta["atributos"]["tiro"]):
		print("OK: crece hasta 32; desde 35 cae y la vitalidad protege GRL y tiro.")
	else:
		print("FALLA: media32 %.1f; perdidas 35/40 baja/40 alta = %.1f / %.1f / %.1f" % [
			float(a_32["media"]), perdida_35, perdida_40_baja, perdida_40_alta])
	_probar_probabilidad_retiro(base)
	_probar_retiro(base_rng)
	quit()


func _envejecer(base: Dictionary, edad_inicial: int, semilla: int,
		vitalidad: int) -> Dictionary:
	var jugador: Dictionary = base.duplicate(true)
	jugador["edad"] = edad_inicial
	jugador["atributos"]["vitalidad"] = vitalidad
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	Progresion.aplicar_temporada(jugador, rng)
	return jugador


func _probar_probabilidad_retiro(base: Dictionary) -> void:
	var fragil: Dictionary = base.duplicate(true)
	var vital: Dictionary = base.duplicate(true)
	fragil["edad"] = 40
	vital["edad"] = 40
	fragil["atributos"]["vitalidad"] = 10
	vital["atributos"]["vitalidad"] = 95
	var antes := Progresion.probabilidad_retiro(fragil) > Progresion.probabilidad_retiro(vital)
	vital["edad"] = 45
	if antes and Progresion.probabilidad_retiro(vital) == 1.0:
		print("OK: la vitalidad demora el retiro y a los 45 es obligatorio.")
	else:
		print("FALLA: retiro no respeta vitalidad o limite de 45.")


func _probar_retiro(rng: RandomNumberGenerator) -> void:
	var equipo := Team.generar("Veteranos", rng, 10000)
	var retirado: Dictionary = equipo.jugadores[0]
	var id := int(retirado["id"])
	retirado["edad"] = Progresion.EDAD_RETIRO_SEGURO
	retirado["atributos"]["vitalidad"] = 100
	var liga := Liga.new()
	liga._retirar_por_edad(equipo, rng, false)
	var sigue := false
	for jugador in equipo.todos_los_jugadores():
		if int(jugador["id"]) == id:
			sigue = true
	if not sigue and liga.agentes_libres.is_empty():
		print("OK: a los 45 se retira aunque tenga vitalidad y contrato.")
	else:
		print("FALLA: el jugador de 45 siguio en el club o quedo como agente libre.")
