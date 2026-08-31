extends SceneTree

## El saque del medio tiene que salir con CUALQUIER formacion.
##
## Bug encontrado jugando: el segundo tiempo no se jugaba y el jugador
## quedaba parado con la pelota en el circulo. La causa era que el sacador
## se buscaba por rol "MCO" y solo el 4-2-3-1 tiene uno; sin MCO el saque
## quedaba sin armar, nadie tomaba la pelota y el tiempo entero moria.
## Estaba latente desde siempre y salio a la luz cuando los clubes de la
## IA dejaron de jugar todos 4-2-3-1.

const SEED := 3300


func _init() -> void:
	_test_todas_las_formaciones_sacan()
	_test_los_dos_tiempos_se_juegan()
	quit()


func _test_todas_las_formaciones_sacan() -> void:
	print("=== Cualquier formacion puede sacar del medio ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for formacion in Formaciones.lista():
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		casa.formacion = formacion
		visita.formacion = formacion
		casa.reset_partido()
		visita.reset_partido()
		casa.local = true
		visita.local = false
		casa.clima_partido = Clima.generar(rng)
		visita.clima_partido = casa.clima_partido
		casa.arbitro_partido = Arbitro.generar(rng)
		visita.arbitro_partido = casa.arbitro_partido

		var estado := MotorEspacial.crear_estado(casa, visita, rng)
		MotorEspacial._reiniciar_desde_medio(estado, true, 1)
		if int(estado["pelota"]["poseedor_id"]) == -1:
			print("FALLA: con %s no hay quien saque del medio." % formacion)
			return
		if not estado.has("balon_parado"):
			print("FALLA: con %s el saque quedo sin armar." % formacion)
			return
	print("OK: las %d formaciones arman el saque." % Formaciones.lista().size())


func _test_los_dos_tiempos_se_juegan() -> void:
	print("\n=== Los dos tiempos se juegan de verdad ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var partidos := 20
	var mudos_primero := 0
	var mudos_segundo := 0
	var eventos_totales := 0

	for i in range(partidos):
		var r := RandomNumberGenerator.new()
		r.seed = SEED + i
		var casa := Team.generar("Casa", r, 0)
		var visita := Team.generar("Visita", r, 400)
		# Formaciones distintas y ninguna 4-2-3-1: es el caso que rompia.
		casa.formacion = "3-5-2"
		visita.formacion = "4-4-2"
		var res := MotorEspacial.simular(casa, visita, r, false)
		var del_primero := 0
		var del_segundo := 0
		for ev in res["eventos"]:
			if int(ev.get("minuto", 0)) <= 45:
				del_primero += 1
			else:
				del_segundo += 1
		eventos_totales += res["eventos"].size()
		if del_primero == 0:
			mudos_primero += 1
		if del_segundo == 0:
			mudos_segundo += 1

	if mudos_primero > 0 or mudos_segundo > 0:
		print("FALLA: %d partidos sin nada en el 1T y %d sin nada en el 2T, de %d." % [
			mudos_primero, mudos_segundo, partidos])
		return
	print("OK: %d partidos sin 4-2-3-1, ninguno mudo, %d eventos de promedio." % [
		partidos, eventos_totales / partidos])
