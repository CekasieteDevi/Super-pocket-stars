extends SceneTree

## Etapa 1 del plan de realismo: el juego sin pelota es del EQUIPO.
## Cada jugador toma una intencion que dura varios ticks, el reparto no
## manda a dos al mismo punto, la perdida cancela las corridas y la
## pared puede abortarse si le cierran el carril de retorno.

const SEED := 9140

var fallos := 0


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 0)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


## Una escena de ataque: le da la pelota a un jugador del equipo pedido,
## en el punto pedido, y reparte los desmarques.
func _escena(semilla: int, local: bool, pelota_x: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var estado := _armar_estado(rng)
	var portador := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == local and str(e["rol"]) == "MC":
			portador = int(id)
			break
	estado["jugadores"][portador]["pos"] = Vector2(pelota_x, 0.0)
	estado["pelota"]["pos"] = Vector2(pelota_x, 0.0)
	estado["pelota"]["poseedor_id"] = portador
	MotorEspacial._calcular_linea_offside(estado)
	MotorEspacial._planificar_desmarques(estado, local)
	return estado


func _init() -> void:
	_test_el_reparto_da_intenciones_a_los_dos_lados()
	_test_dos_no_van_al_mismo_punto()
	_test_la_intencion_dura_varios_ticks()
	_test_la_perdida_cancela_las_rupturas()
	_test_queda_un_apoyo_de_seguridad()
	_test_no_rompen_todos_juntos()
	_test_los_destinos_son_legales()
	_test_el_defensor_que_tapa_corre_el_apoyo()
	_test_el_reparto_es_estable()
	_test_la_pared_se_aborta_si_le_cierran_el_retorno()
	print("\nFALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: " + texto)


func _test_el_reparto_da_intenciones_a_los_dos_lados() -> void:
	print("=== El reparto funciona atacando para los dos lados ===")
	for lado in [true, false]:
		var signo := 1.0 if lado else -1.0
		var estado := _escena(SEED, lado, 10.0 * signo)
		var planes: Dictionary = estado["desmarques"]
		if planes.is_empty():
			_falla("atacando %s no se repartio ninguna intencion." % ["el local" if lado else "la visita"])
			return
		for clave in planes:
			var e: Dictionary = estado["jugadores"][int(clave)]
			if bool(e["equipo_local"]) != lado:
				_falla("le toco una intencion a un jugador del equipo que defiende.")
				return
			if not MotorEspacial.TIPOS_DESMARQUE.has(str(planes[clave]["tipo"])):
				_falla("tipo de intencion desconocido: %s." % planes[clave]["tipo"])
				return
	print("OK: los dos lados reparten intenciones, y solo al que ataca.")


func _test_dos_no_van_al_mismo_punto() -> void:
	print("\n=== Dos receptores no convergen al mismo punto ===")
	# Dos desmarques al mismo metro cuadrado son una sola opcion de pase,
	# tapada por el mismo defensor.
	var peor := INF
	var mirados := 0
	for i in range(30):
		var estado := _escena(SEED + i, i % 2 == 0, -8.0 + float(i % 5) * 8.0)
		var destinos := []
		for clave in estado["desmarques"]:
			destinos.append(estado["desmarques"][clave]["destino"])
		for a in range(destinos.size()):
			for b in range(a + 1, destinos.size()):
				mirados += 1
				peor = minf(peor, (destinos[a] as Vector2).distance_to(destinos[b]))
	if mirados == 0:
		_falla("ninguna escena reparto dos intenciones; el test no mide nada.")
		return
	# El reparto PENALIZA la convergencia, no la prohibe: el umbral del
	# test es la mitad de la separacion pedida, que es lo que distingue
	# "se pisan" de "estan cerca".
	if peor < MotorEspacial.SEPARACION_DESMARQUE * 0.5:
		_falla("dos destinos quedaron a %.1f m (separacion pedida: %.1f)." % [
			peor, MotorEspacial.SEPARACION_DESMARQUE])
		return
	print("OK: en %d pares, los dos destinos mas juntos quedaron a %.1f m." % [mirados, peor])


func _test_la_intencion_dura_varios_ticks() -> void:
	print("
=== La intencion dura, no se recalcula cada tick ===")
	# El punto de la etapa: sostener el movimiento. Si el destino cambia
	# en cada foto, el jugador tiembla en el lugar y no llega a ningun
	# lado. Se mide el PLAZO anotado, no cuanto se parece el destino de un
	# tick al del siguiente: al vencer, el reparto puede volver a elegir
	# el mismo punto y eso no seria una intencion larga sino una nueva.
	var estado := _escena(SEED + 200, true, 5.0)
	var planes: Dictionary = estado["desmarques"]
	if planes.is_empty():
		_falla("no se repartio ninguna intencion.")
		return
	var tick0: int = int(estado["tick"])
	for clave in planes:
		var plazo: int = int(planes[clave]["hasta"]) - tick0
		if plazo < MotorEspacial.TICKS_DESMARQUE_MIN or plazo > MotorEspacial.TICKS_DESMARQUE_MAX:
			_falla("una intencion se anoto por %d ticks; el rango es %d a %d." % [
				plazo, MotorEspacial.TICKS_DESMARQUE_MIN, MotorEspacial.TICKS_DESMARQUE_MAX])
			return
	# Y mientras el plazo corre, el destino no se mueve aunque los
	# jugadores si: es lo que distingue una intencion de un recalculo.
	var clave_uno: int = int(planes.keys()[0])
	var destino_inicial: Vector2 = planes[clave_uno]["destino"]
	var hasta: int = int(planes[clave_uno]["hasta"])
	while int(estado["tick"]) < hasta - 1:
		estado["tick"] = int(estado["tick"]) + 1
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			e["pos"] = e["pos"] + Vector2(0.4, 0.2)
		MotorEspacial._calcular_linea_offside(estado)
		MotorEspacial._planificar_desmarques(estado, true)
		var vigente = MotorEspacial.desmarque_de(estado, clave_uno)
		if vigente == null:
			break
		if (vigente as Vector2).distance_to(destino_inicial) > 3.0:
			_falla("el destino se movio %.1f m sin haber vencido el plazo." % [
				(vigente as Vector2).distance_to(destino_inicial)])
			return
	print("OK: los plazos caen entre %d y %d ticks y el destino se sostiene." % [
		MotorEspacial.TICKS_DESMARQUE_MIN, MotorEspacial.TICKS_DESMARQUE_MAX])


func _test_la_perdida_cancela_las_rupturas() -> void:
	print("\n=== Una perdida cancela las intenciones ===")
	var estado := _escena(SEED + 300, true, 12.0)
	if estado["desmarques"].is_empty():
		_falla("no se repartio nada, no hay nada que cancelar.")
		return
	# Se la roba el rival: la pelota cambia de equipo.
	var ladron := -1
	for id in estado["jugadores"]:
		if not estado["jugadores"][id]["equipo_local"]:
			ladron = int(id)
			break
	estado["pelota"]["poseedor_id"] = ladron
	estado["pelota"]["pos"] = estado["jugadores"][ladron]["pos"]
	estado["tick"] = int(estado["tick"]) + 1
	MotorEspacial._calcular_linea_offside(estado)
	MotorEspacial._planificar_desmarques(estado, false)
	for clave in estado["desmarques"]:
		if bool(estado["jugadores"][int(clave)]["equipo_local"]):
			_falla("tras la perdida, el que atacaba conservo su intencion.")
			return
	print("OK: la perdida borro las intenciones del que atacaba.")


func _test_queda_un_apoyo_de_seguridad() -> void:
	print("\n=== Siempre queda alguien ofreciendose al pie ===")
	# Sin la reserva, el reparto premia a los que progresan y el poseedor
	# se queda sin ninguna opcion corta.
	var sin_apoyo := 0
	var escenas := 0
	for i in range(24):
		var estado := _escena(SEED + 400 + i, i % 2 == 0, -20.0 + float(i % 6) * 10.0)
		if estado["desmarques"].is_empty():
			continue
		escenas += 1
		var hay := false
		for clave in estado["desmarques"]:
			if str(estado["desmarques"][clave]["tipo"]) == "apoyo":
				hay = true
				break
		if not hay:
			sin_apoyo += 1
	if escenas == 0:
		_falla("ninguna escena reparto intenciones; el test no mide nada.")
		return
	if sin_apoyo > 0:
		_falla("%d de %d escenas quedaron sin apoyo de seguridad." % [sin_apoyo, escenas])
		return
	print("OK: las %d escenas dejaron un apoyo al pie." % escenas)


func _test_no_rompen_todos_juntos() -> void:
	print("\n=== No rompen todos al mismo tiempo ===")
	var peor := 0
	for i in range(24):
		var estado := _escena(SEED + 500 + i, i % 2 == 0, 5.0 + float(i % 4) * 8.0)
		var corridas := 0
		for clave in estado["desmarques"]:
			var tipo := str(estado["desmarques"][clave]["tipo"])
			if tipo == "ruptura" or tipo == "llegada":
				corridas += 1
		peor = maxi(peor, corridas)
	if peor > MotorEspacial.MAX_RUPTURAS:
		_falla("una escena mando %d a correr; el tope es %d." % [peor, MotorEspacial.MAX_RUPTURAS])
		return
	print("OK: el maximo de corridas simultaneas fue %d (tope %d)." % [peor, MotorEspacial.MAX_RUPTURAS])


func _test_los_destinos_son_legales() -> void:
	print("\n=== Ningun desmarque apunta a posicion adelantada ===")
	var ilegales := 0
	var mirados := 0
	for i in range(24):
		var estado := _escena(SEED + 600 + i, i % 2 == 0, -10.0 + float(i % 5) * 12.0)
		var linea: Dictionary = estado["linea_offside"]
		for clave in estado["desmarques"]:
			var e: Dictionary = estado["jugadores"][int(clave)]
			var destino: Vector2 = estado["desmarques"][clave]["destino"]
			mirados += 1
			if bool(e["equipo_local"]):
				if destino.x > float(linea["local"]) + 0.01:
					ilegales += 1
			elif destino.x < float(linea["away"]) - 0.01:
				ilegales += 1
	if mirados == 0:
		_falla("no se miro ningun destino.")
		return
	if ilegales > 0:
		_falla("%d de %d destinos caian mas alla de la linea de offside." % [ilegales, mirados])
		return
	print("OK: los %d destinos quedaron del lado habilitado." % mirados)


func _test_el_defensor_que_tapa_corre_el_apoyo() -> void:
	print("\n=== Un defensor que tapa el apoyo mueve el destino ===")
	# Es la escena que pide la etapa: si le cierran la linea de pase, el
	# apoyo se busca por otro lado y no en el mismo punto tapado.
	var estado := _escena(SEED + 700, true, 0.0)
	var planes: Dictionary = estado["desmarques"]
	var clave := -1
	for c in planes:
		if str(planes[c]["tipo"]) == "apoyo":
			clave = int(c)
			break
	if clave == -1:
		_falla("la escena no dejo ningun apoyo para tapar.")
		return
	var destino_libre: Vector2 = planes[clave]["destino"]
	# Se para un rival justo en la mitad de esa linea de pase y se vuelve
	# a repartir desde cero.
	var estado2 := _escena(SEED + 700, true, 0.0)
	var tapador := -1
	for id in estado2["jugadores"]:
		if not estado2["jugadores"][id]["equipo_local"] and str(estado2["jugadores"][id]["rol"]) != "ARQ":
			tapador = int(id)
			break
	estado2["jugadores"][tapador]["pos"] = estado2["pelota"]["pos"].lerp(destino_libre, 0.5)
	estado2["desmarques"] = {}
	estado2["desmarques_hasta"] = -1
	MotorEspacial._calcular_linea_offside(estado2)
	MotorEspacial._planificar_desmarques(estado2, true)
	var nuevo = MotorEspacial.desmarque_de(estado2, clave)
	if nuevo == null:
		print("OK: con la linea tapada, ese jugador ya no toma el apoyo.")
		return
	if (nuevo as Vector2).distance_to(destino_libre) < 2.0:
		_falla("con un rival en la linea, el apoyo quedo en el mismo punto.")
		return
	print("OK: el apoyo se corrio %.1f m al taparle la linea." % (nuevo as Vector2).distance_to(destino_libre))


func _test_el_reparto_es_estable() -> void:
	print("
=== El mismo estado reparte siempre igual ===")
	# El reparto recorre las claves ordenadas y no usa el RNG del partido.
	# Si dependiera del orden en que el diccionario devuelve llaves, dos
	# corridas con la misma semilla podrian divergir, y eso rompe el
	# invariante de que el render no cambia nada.
	for i in range(8):
		var a := _escena(SEED + 900 + i, i % 2 == 0, -15.0 + float(i % 4) * 12.0)
		var b := _escena(SEED + 900 + i, i % 2 == 0, -15.0 + float(i % 4) * 12.0)
		if a["desmarques"].size() != b["desmarques"].size():
			_falla("dos corridas iguales repartieron distinta cantidad de intenciones.")
			return
		for clave in a["desmarques"]:
			if not b["desmarques"].has(clave):
				_falla("dos corridas iguales le dieron la intencion a jugadores distintos.")
				return
			var da: Dictionary = a["desmarques"][clave]
			var db: Dictionary = b["desmarques"][clave]
			if str(da["tipo"]) != str(db["tipo"]) or (da["destino"] as Vector2).distance_to(db["destino"]) > 0.001:
				_falla("la misma escena dio dos repartos distintos.")
				return
	print("OK: ocho escenas repetidas dieron el mismo reparto.")

func _test_la_pared_se_aborta_si_le_cierran_el_retorno() -> void:
	print("\n=== La pared se aborta si le cierran el retorno ===")
	# La devolucion ya no sale siempre: el muro mira el carril y, si esta
	# tapado, se queda la pelota.
	var abortadas := 0
	var devueltas := 0
	for i in range(60):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + 800 + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 0)
		var res := MotorEspacial.simular(casa, visita, rng, false)
		var paredes: Dictionary = res.get("stats", {}).get("paredes", {})
		abortadas += int(paredes.get("abortadas", 0))
		devueltas += int(paredes.get("muro_ok", 0))
	if devueltas == 0:
		_falla("en 60 partidos no se completo ninguna pared; el test no mide nada.")
		return
	if abortadas == 0:
		_falla("en 60 partidos (%d paredes completadas) no se aborto ninguna." % devueltas)
		return
	print("OK: %d paredes devueltas y %d abortadas por carril cerrado." % [devueltas, abortadas])
