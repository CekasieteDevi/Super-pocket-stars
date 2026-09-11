extends SceneTree

## Etapa 2 del plan de realismo: la defensa es del EQUIPO. Uno presiona,
## otro cubre y un tercero cierra una linea distinta; el reparto se
## sostiene varios ticks, el tiempo de llegada manda sobre la distancia
## cruda y una presion superada manda a replegar.

const SEED := 5170

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


## Una escena de ataque: le da la pelota a un MC del equipo pedido en el
## punto pedido. El reparto defensivo lo hace cada test, porque varios
## necesitan tocar la escena antes.
func _escena(semilla: int, ataca_local: bool, pelota: Vector2) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var estado := _armar_estado(rng)
	var portador := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if e["equipo_local"] == ataca_local and str(e["rol"]) == "MC":
			portador = int(id)
			break
	estado["jugadores"][portador]["pos"] = pelota
	estado["pelota"]["pos"] = pelota
	estado["pelota"]["poseedor_id"] = portador
	estado["pelota"]["ticks_con_pelota"] = 8
	MotorEspacial._calcular_linea_offside(estado)
	return estado


func _init() -> void:
	_test_hay_un_presionante_y_una_cobertura_distinta()
	_test_la_cobertura_queda_del_lado_del_arco_propio()
	_test_el_cierre_tapa_un_carril_separado()
	_test_el_reparto_no_se_intercambia_cada_tick()
	_test_el_tiempo_de_llegada_manda_sobre_la_distancia()
	_test_la_presion_superada_repliega()
	_test_los_disparadores_suben_la_intensidad()
	_test_anda_con_diez()
	_test_el_reparto_es_estable()
	_test_la_correa_de_zona_limita_el_costado_y_no_el_retroceso()
	_test_recuperaciones_altas_y_separacion_en_partidos()
	print("\nFALLOS=%d" % fallos)
	quit()


func _falla(texto: String) -> void:
	fallos += 1
	print("FALLA: " + texto)


func _test_hay_un_presionante_y_una_cobertura_distinta() -> void:
	print("=== Un presionante y una cobertura, para los dos lados ===")
	for lado in [true, false]:
		var signo := 1.0 if lado else -1.0
		var estado := _escena(SEED, lado, Vector2(10.0 * signo, 4.0))
		var plan := MotorEspacial._planificar_defensa(estado, lado)
		var p: int = int(plan["presionante"])
		var c: int = int(plan["cobertura"])
		if p == -1:
			_falla("atacando %s nadie salio a presionar." % ["el local" if lado else "la visita"])
			return
		if c == -1:
			_falla("atacando %s nadie quedo de cobertura." % ["el local" if lado else "la visita"])
			return
		if c == p:
			_falla("el presionante y la cobertura son el mismo jugador.")
			return
		for papel in [p, c]:
			if papel == -1:
				continue
			var e: Dictionary = estado["jugadores"][papel]
			if bool(e["equipo_local"]) == lado:
				_falla("un jugador del equipo que ataca quedo en el reparto defensivo.")
				return
			if str(e["rol"]) == "ARQ":
				_falla("el arquero quedo en el reparto defensivo.")
				return
	print("OK: presionante y cobertura son rivales distintos, atacando para los dos lados.")


func _test_la_cobertura_queda_del_lado_del_arco_propio() -> void:
	print("\n=== La cobertura se para detras del presionante ===")
	for lado in [true, false]:
		var signo := 1.0 if lado else -1.0
		var estado := _escena(SEED + 3, lado, Vector2(6.0 * signo, -8.0))
		var plan := MotorEspacial._planificar_defensa(estado, lado)
		var p: int = int(plan["presionante"])
		var c: int = int(plan["cobertura"])
		if p == -1 or c == -1:
			_falla("no se repartio cobertura en la escena de control.")
			return
		var presionante: Dictionary = estado["jugadores"][p]
		var arco: Vector2 = MotorEspacial.arco_propio(bool(presionante["equipo_local"]))
		var punto := MotorEspacial._objetivo_de_presion(estado, estado["jugadores"][c])
		if arco.distance_to(punto) >= arco.distance_to(presionante["pos"]):
			_falla("la cobertura no quedo entre el presionante y su arco.")
			return
		var punto_p := MotorEspacial._objetivo_de_presion(estado, presionante)
		if punto_p.distance_to(punto) < 1.0:
			_falla("presionante y cobertura van al mismo punto.")
			return
	print("OK: la cobertura queda entre el presionante y su propio arco.")


func _test_el_cierre_tapa_un_carril_separado() -> void:
	print("\n=== El cierre tapa una linea de pase distinta ===")
	var estado := _escena(SEED + 7, false, Vector2(-6.0, 0.0))
	estado["home"].estilo = "Presión alta"
	var plan := MotorEspacial._planificar_defensa(estado, false)
	var cierre: int = int(plan["cierre"])
	if cierre == -1:
		_falla("presion alta no asigno a nadie a cerrar una linea.")
		return
	var punto_cierre: Vector2 = MotorEspacial._objetivo_de_presion(estado, estado["jugadores"][cierre])
	var punto_cob: Vector2 = MotorEspacial._objetivo_de_presion(estado, estado["jugadores"][int(plan["cobertura"])])
	if punto_cierre.distance_to(punto_cob) <= 4.0:
		_falla("el cierre y la cobertura van al mismo carril (%.1f m)." % punto_cierre.distance_to(punto_cob))
		return
	# El estilo de bloque no manda al tercero sin disparadores.
	estado["home"].estilo = "Contragolpe"
	estado["defensa"] = {}
	var plan_bloque := MotorEspacial._planificar_defensa(estado, false)
	if int(plan_bloque["cierre"]) != -1 and float(plan_bloque["intensidad"]) < 0.6:
		_falla("contragolpe saco un tercero sin disparadores de presion.")
		return
	print("OK: presion alta cierra un carril separado y contragolpe conserva el bloque.")


func _test_el_reparto_no_se_intercambia_cada_tick() -> void:
	print("\n=== El presionante no se intercambia cada fotograma ===")
	var estado := _escena(SEED + 11, true, Vector2(8.0, 0.0))
	var cambios := 0
	var previo := -1
	var ticks := 24
	for t in range(ticks):
		estado["tick"] = t
		var plan := MotorEspacial._planificar_defensa(estado, true)
		var p: int = int(plan["presionante"])
		if previo != -1 and p != previo:
			cambios += 1
		previo = p
		# Los 22 siguen moviendose: el reparto tiene que aguantar eso.
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			e["pos"] = e["pos"] + Vector2(0.25 * signf(float(int(id) % 3) - 1.0), 0.2)
	if cambios > ticks / MotorEspacial.TICKS_DEFENSA_MIN:
		_falla("el presionante cambio %d veces en %d ticks." % [cambios, ticks])
		return
	print("OK: %d cambios de presionante en %d ticks con los 22 en movimiento." % [cambios, ticks])


func _test_el_tiempo_de_llegada_manda_sobre_la_distancia() -> void:
	print("\n=== Llega antes el que puede, no el que esta mas cerca ===")
	var estado := _escena(SEED + 17, true, Vector2(0.0, 0.0))
	var visita: Team = estado["away"]
	# Dos rivales al mismo lado: uno pegado a la pelota pero exhausto,
	# otro dos metros mas lejos y entero.
	var cerca := -1
	var lejos := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if bool(e["equipo_local"]) or str(e["rol"]) == "ARQ":
			continue
		if cerca == -1:
			cerca = int(id)
		elif lejos == -1:
			lejos = int(id)
		else:
			# El resto se va lejos para no competir por el puesto.
			e["pos"] = Vector2(40.0, 30.0)
	estado["jugadores"][cerca]["pos"] = Vector2(3.0, 0.0)
	estado["jugadores"][lejos]["pos"] = Vector2(6.0, 0.0)
	estado["jugadores"][cerca]["vel_max"] = estado["jugadores"][lejos]["vel_max"]
	estado["jugadores"][cerca]["base"] = estado["jugadores"][lejos]["base"]
	var plan_entero := MotorEspacial._planificar_defensa(estado, true)
	if int(plan_entero["presionante"]) != cerca:
		_falla("con todo igual no salio el mas cercano.")
		return
	# Ahora el mas cercano esta fundido.
	visita.resistencia[int(estado["jugadores"][cerca]["jugador_id"])] = 0.30
	estado["defensa"] = {}
	var plan_cansado := MotorEspacial._planificar_defensa(estado, true)
	if int(plan_cansado["presionante"]) != lejos:
		_falla("el mas cercano exhausto siguio saliendo a presionar.")
		return
	print("OK: el cansancio le saca el puesto al que esta tres metros mas cerca.")


func _test_la_presion_superada_repliega() -> void:
	print("\n=== Si lo pasan, no sale un tercero ===")
	var estado := _escena(SEED + 23, true, Vector2(0.0, 0.0))
	estado["away"].estilo = "Presión alta"
	var plan := MotorEspacial._planificar_defensa(estado, true)
	# Primero se engancha: llega a disputarla. Sin eso, "lo pasaron" no
	# quiere decir nada — un delantero que presiona de frente siempre
	# tiene la pelota entre el y su arco.
	var presionante: Dictionary = estado["jugadores"][int(plan["presionante"])]
	presionante["pos"] = estado["pelota"]["pos"] + Vector2(2.0, 0.0)
	plan = MotorEspacial._planificar_defensa(estado, true)
	if int(plan["cierre"]) == -1:
		_falla("la escena de control no asigno cierre; el test no mide nada.")
		return
	# Ahora el poseedor lo pasa: queda mas cerca del arco que el defiende.
	var arco: Vector2 = MotorEspacial.arco_propio(false)
	var poseedor: Dictionary = estado["jugadores"][int(estado["pelota"]["poseedor_id"])]
	poseedor["pos"] = presionante["pos"] + (arco - presionante["pos"]).normalized() * 6.0
	estado["pelota"]["pos"] = poseedor["pos"]
	var plan_pasado := MotorEspacial._planificar_defensa(estado, true)
	if int(plan_pasado["cierre"]) != -1:
		_falla("con la presion superada igual salio un tercero a cerrar.")
		return
	print("OK: superada la presion, el tercero se queda en el bloque.")


func _test_los_disparadores_suben_la_intensidad() -> void:
	print("\n=== Los disparadores de presion ===")
	var base := _escena(SEED + 29, true, Vector2(0.0, 0.0))
	var calma := MotorEspacial._intensidad_de_presion(base, false)
	# Pelota contra la banda.
	var banda := _escena(SEED + 29, true, Vector2(0.0, MEDIO_ANCHO_TEST))
	var i_banda := MotorEspacial._intensidad_de_presion(banda, false)
	if i_banda <= calma:
		_falla("la pelota contra la banda no subio la intensidad (%.2f vs %.2f)." % [i_banda, calma])
		return
	# Control largo: la pelota recien llega.
	var control := _escena(SEED + 29, true, Vector2(0.0, 0.0))
	control["pelota"]["ticks_con_pelota"] = 0
	if MotorEspacial._intensidad_de_presion(control, false) <= calma:
		_falla("la pelota recien controlada no subio la intensidad.")
		return
	# De espaldas: el poseedor va hacia su propio arco.
	var espaldas := _escena(SEED + 29, true, Vector2(0.0, 0.0))
	espaldas["jugadores"][int(espaldas["pelota"]["poseedor_id"])]["vel"] = Vector2(-4.0, 0.0)
	if MotorEspacial._intensidad_de_presion(espaldas, false) <= calma:
		_falla("el poseedor yendo hacia su arco no subio la intensidad.")
		return
	print("OK: banda, control largo y recepcion de espaldas suben la intensidad sobre %.2f." % calma)


func _test_anda_con_diez() -> void:
	print("\n=== El reparto funciona con diez ===")
	var estado := _escena(SEED + 31, true, Vector2(5.0, 0.0))
	var expulsado := -1
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not bool(e["equipo_local"]) and str(e["rol"]) == "LAT":
			expulsado = int(id)
			break
	estado["jugadores"].erase(expulsado)
	var plan := MotorEspacial._planificar_defensa(estado, true)
	if int(plan["presionante"]) == -1 or int(plan["cobertura"]) == -1:
		_falla("con diez jugadores el reparto se quedo sin presionante o sin cobertura.")
		return
	if int(plan["presionante"]) == expulsado or int(plan["cobertura"]) == expulsado:
		_falla("el reparto le dio un papel al que ya no esta en cancha.")
		return
	print("OK: con diez sigue habiendo presionante y cobertura.")


func _test_el_reparto_es_estable() -> void:
	print("\n=== La misma escena reparte igual ===")
	for i in range(8):
		var a := _escena(SEED + 40 + i, true, Vector2(4.0 + float(i), -3.0))
		var b := _escena(SEED + 40 + i, true, Vector2(4.0 + float(i), -3.0))
		var pa := MotorEspacial._planificar_defensa(a, true)
		var pb := MotorEspacial._planificar_defensa(b, true)
		for papel in ["presionante", "cobertura", "cierre"]:
			if int(pa[papel]) != int(pb[papel]):
				_falla("la escena %d dio distinto %s (%d vs %d)." % [i, papel, int(pa[papel]), int(pb[papel])])
				return
	print("OK: ocho escenas repartidas dos veces dieron el mismo reparto.")


const MEDIO_ANCHO_TEST := 30.0

func _test_la_correa_de_zona_limita_el_costado_y_no_el_retroceso() -> void:
	print("\n=== La correa del bloque ===")
	var estado := _escena(SEED + 53, true, Vector2(20.0, 30.0))
	var central := {}
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not bool(e["equipo_local"]) and str(e["rol"]) == "DFC":
			central = e
			break
	if central.is_empty():
		_falla("la formacion no trajo ningun DFC; el test no mide nada.")
		return
	var base: Vector2 = central["base"]
	var radio: float = float(MotorEspacial.pesos_defensa()["radio_defensa"])
	# Basculacion: el destino no se va mas de un radio del casillero.
	var lejos := MotorEspacial._recortar_a_la_zona(central, base + Vector2(0.0, 40.0))
	if absf(lejos.y - base.y) > radio + 0.01:
		_falla("la correa dejo al central %.1f m de su carril." % absf(lejos.y - base.y))
		return
	# Adelantarse tambien tiene correa.
	var hacia_rival := -1.0 if bool(central["equipo_local"]) else 1.0
	var adelante := MotorEspacial._recortar_a_la_zona(central, base + Vector2(-40.0 * hacia_rival, 0.0))
	if (base.x - adelante.x) * hacia_rival > radio + 0.01:
		_falla("la correa dejo al central adelantarse de mas.")
		return
	# Retroceder no tiene correa: siempre puede bajar a su area.
	var atras := MotorEspacial._recortar_a_la_zona(central, base + Vector2(40.0 * hacia_rival, 0.0))
	if not is_equal_approx(atras.x, base.x + 40.0 * hacia_rival):
		_falla("la correa le impidio al central retroceder a su arco.")
		return
	print("OK: la correa limita basculacion y adelantamiento, y deja retroceder.")


func _test_recuperaciones_altas_y_separacion_en_partidos() -> void:
	print("\n=== Recuperaciones altas y bloque en partidos completos ===")
	var altas := 0
	var partidos := 12
	var separacion := 0.0
	var muestras := 0
	for i in range(partidos):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + 900 + i
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 0)
		var res := MotorEspacial.simular(casa, visita, rng, true)
		var previo := 0
		for fg in res["fotogramas"]:
			if int(fg.get("detenido", 0)) > 0:
				continue
			var poseedor: int = int(fg["pelota"]["poseedor_id"])
			if poseedor == -1:
				continue
			var equipo := 0
			var atras := 0.0
			var n_atras := 0
			var arriba := 0.0
			var n_arriba := 0
			for j in fg["jugadores"]:
				if int(j["id"]) == poseedor:
					equipo = 1 if bool(j["equipo_local"]) else -1
			for j in fg["jugadores"]:
				if equipo == 0 or (bool(j["equipo_local"]) == (equipo == 1)):
					continue
				var rol: String = str(j["rol"])
				if rol == "DFC" or rol == "LAT":
					atras += float(j["x"])
					n_atras += 1
				elif rol == "EXT" or rol == "DC":
					arriba += float(j["x"])
					n_arriba += 1
			if n_atras > 0 and n_arriba > 0:
				separacion += absf(arriba / float(n_arriba) - atras / float(n_atras))
				muestras += 1
			if equipo != 0 and equipo != previo:
				var x: float = float(fg["pelota"]["x"])
				if (equipo == 1 and x > 0.0) or (equipo == -1 and x < 0.0):
					altas += 1
				previo = equipo
	if altas == 0:
		_falla("en %d partidos no hubo ninguna recuperacion en campo rival." % partidos)
		return
	var media := separacion / maxf(float(muestras), 1.0)
	# El bloque tiene que seguir siendo un bloque: entre 15 y 60 metros de
	# la linea de atras a la de arriba. Fuera de ese rango el equipo esta
	# partido o amontonado, y cualquiera de las dos cosas se ve.
	if media < 15.0 or media > 60.0:
		_falla("el bloque defensivo mide %.1f m entre lineas." % media)
		return
	print("OK: %.1f recuperaciones altas por partido y %.1f m entre lineas." % [
		float(altas) / float(partidos), media])
