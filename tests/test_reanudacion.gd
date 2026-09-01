extends SceneTree

## Un reinicio se JUEGA: la pelota SALE de los pies del que la pone en
## juego. Nunca se la queda y arranca a conducir.
##
## El corte para elegir a quien tocarsela era `max_dist_pase_malo`, una
## constante — el alcance del PEOR pasador posible, aplicada a todos. Si
## no habia un companero dentro de ese radio, la funcion se iba sin hacer
## nada y el ejecutor se quedaba con la pelota y salia corriendo. Al bajar
## ese peso de 22 a 16 m (recalibrando el alcance por division) el caso
## paso de raro a comun.
##
## Y el centro que no encontraba a nadie en el area hacia lo mismo.

const SEED := 6161
const INTENTOS := 60


func _init() -> void:
	_test_el_tiro_libre_lejano_sale_con_un_pase()
	_test_el_lateral_sale_con_un_pase()
	_test_ningun_reinicio_deja_al_ejecutor_conduciendo()
	quit()


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
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
	return estado


## Corre la pausa entera y devuelve si la pelota salio viajando.
func _se_reanudo_con_un_pase(estado: Dictionary, ticks: int) -> bool:
	for t in range(ticks):
		MotorEspacial._tick(estado, false)
		var pelota: Dictionary = estado["pelota"]
		if bool(pelota["en_vuelo"]):
			return true
	return false


func _test_el_tiro_libre_lejano_sale_con_un_pase() -> void:
	print("=== El tiro libre lejano se reanuda con un pase ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var con_pase := 0
	for i in range(INTENTOS):
		var estado := _armar_estado(rng)
		# Una falta en campo propio, lejos del arco rival: el caso "corto".
		var arco := MotorEspacial.arco_rival(true)
		var hacia: float = -1.0 if arco.x > 0.0 else 1.0
		var punto := Vector2(arco.x + hacia * 75.0, rng.randf_range(-25.0, 25.0))
		MotorEspacial._tiro_libre(estado, punto, true, 30)
		if _se_reanudo_con_un_pase(estado, MotorEspacial.TICKS_CONGELADO_FALTA
				+ int(MotorEspacial.TICKS_DETENIDO["falta"]) + 3):
			con_pase += 1
	if con_pase != INTENTOS:
		print("FALLA: %d de %d tiros libres se reanudaron con un pase." % [con_pase, INTENTOS])
		return
	print("OK: los %d tiros libres lejanos salieron con un pase." % INTENTOS)


func _test_el_lateral_sale_con_un_pase() -> void:
	print("\n=== El lateral se reanuda con un pase ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var con_pase := 0
	for i in range(INTENTOS):
		var estado := _armar_estado(rng)
		# Contra la linea de banda, que es donde menos companeros hay
		# cerca: el caso que mas se rompia.
		var pos := Vector2(rng.randf_range(-40.0, 40.0),
			MotorEspacial.MEDIO_ANCHO * (1.0 if rng.randf() < 0.5 else -1.0))
		var ejecutor := MotorEspacial._mas_cercano_del_equipo(estado, pos, true)
		if ejecutor == -1:
			continue
		MotorEspacial._detener_juego(estado, pos, true, ejecutor, "corto",
			int(MotorEspacial.TICKS_DETENIDO["lateral"]))
		if _se_reanudo_con_un_pase(estado, int(MotorEspacial.TICKS_DETENIDO["lateral"]) + 3):
			con_pase += 1
	if con_pase != INTENTOS:
		print("FALLA: %d de %d laterales se reanudaron con un pase." % [con_pase, INTENTOS])
		return
	print("OK: los %d laterales salieron con un pase." % INTENTOS)


func _test_ningun_reinicio_deja_al_ejecutor_conduciendo() -> void:
	print("\n=== En un partido entero, ningun reinicio se juega conduciendo ===")
	# La prueba de verdad: partidos completos, contando cada balon parado
	# que se reanudo sin que la pelota saliera de los pies del ejecutor.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var conduciendo := 0
	var reinicios := 0
	var tipos_malos := {}
	for i in range(6):
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED + 2 + i
		var estado := _armar_estado(r2)
		for t in range(MotorEspacial.TICKS_POR_MITAD):
			var habia: bool = estado.has("balon_parado")
			var tipo := str(estado.get("balon_parado", {}).get("tipo", ""))
			var ejecutor: int = int(estado.get("balon_parado", {}).get("ejecutor", -1))
			var detenido_antes: int = int(estado.get("detenido", 0))
			MotorEspacial._tick(estado, false)
			# El tick en que se ejecuto el balon parado: antes habia uno
			# armado con la cuenta en 1, y despues ya no esta.
			if not habia or detenido_antes != 1 or estado.has("balon_parado"):
				continue
			if tipo == "directo" or tipo == "penal":
				continue  # esos se reanudan con un remate, no con un pase
			reinicios += 1
			# Lo que se mide es que el ejecutor NO se quede con la pelota.
			# Que siga en vuelo no sirve: un pase corto puede salir y ser
			# recibido en el mismo tick, y eso es un reinicio bien jugado.
			var pelota: Dictionary = estado["pelota"]
			if int(pelota["poseedor_id"]) == ejecutor and ejecutor != -1:
				conduciendo += 1
				tipos_malos[tipo] = int(tipos_malos.get(tipo, 0)) + 1
	if reinicios == 0:
		print("FALLA: no se conto ningun reinicio; el test no mide nada.")
		return
	if conduciendo > 0:
		print("FALLA: %d de %d reinicios quedaron con el ejecutor conduciendo: %s" % [
			conduciendo, reinicios, str(tipos_malos)])
		return
	print("OK: los %d reinicios de %d medios tiempos salieron con la pelota en movimiento." % [
		reinicios, 6])
