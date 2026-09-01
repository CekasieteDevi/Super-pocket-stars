extends SceneTree

## Como se para el equipo: saque del medio, corner, delanteros y estilo.
## Los cuatro salieron de mirar el partido animado.

const SEED := 8080


func _armar_estado(rng: RandomNumberGenerator, estilo_local := "") -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	if estilo_local != "":
		casa.estilo = estilo_local
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	return MotorEspacial.crear_estado(casa, visita, rng)


func _init() -> void:
	_test_en_el_saque_del_medio_nadie_esta_en_campo_ajeno()
	_test_al_corner_sube_lo_que_dice_el_estilo()
	_test_los_de_arriba_bajan_a_recibir()
	_test_el_estilo_corre_la_linea()
	quit()


func _test_en_el_saque_del_medio_nadie_esta_en_campo_ajeno() -> void:
	print("=== En el saque del medio, cada uno en su mitad ===")
	# La compresion de la formacion y el empujon fuera del circulo podian
	# pasarse los dos, y se veia un rival parado en tu campo mientras vos
	# sacabas del medio.
	var intrusos := 0
	var mirados := 0
	for i in range(40):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var estado := _armar_estado(rng)
		var saca_local: bool = i % 2 == 0
		MotorEspacial._reiniciar_desde_medio(estado, saca_local, 1)
		var sacador := MotorEspacial._quien_saca_del_medio(estado, saca_local)
		for id in estado["jugadores"]:
			if id == sacador:
				continue
			var e: Dictionary = estado["jugadores"][id]
			mirados += 1
			var en_campo_propio: bool = e["pos"].x < 0.0 if e["equipo_local"] else e["pos"].x > 0.0
			if not en_campo_propio:
				intrusos += 1
	if intrusos > 0:
		print("FALLA: %d de %d quedaron en campo ajeno al sacar del medio." % [intrusos, mirados])
		return
	print("OK: los %d jugadores quedaron en su propia mitad." % mirados)


## Cuantos suben al area en un corner propio, con un estilo dado.
func _reparto_de_corner(estilo: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 100
	var en_area := 0
	var en_el_medio := 0
	var atras := 0
	for i in range(12):
		var estado := _armar_estado(rng, estilo)
		var arco := MotorEspacial.arco_rival(true)
		var esquina := Vector2(arco.x, MotorEspacial.MEDIO_ANCHO - 0.5)
		var ejecutor := MotorEspacial._mas_cercano_del_equipo(estado, esquina, true)
		MotorEspacial._marcar_posiciones(estado, esquina, true, ejecutor, "corner")
		for id in estado["jugadores"]:
			var e: Dictionary = estado["jugadores"][id]
			if not e["equipo_local"] or id == ejecutor or str(e["rol"]) == "ARQ":
				continue
			var x: float = float(e["marca"].x)
			if absf(arco.x - x) <= 20.0:
				en_area += 1
			elif x > -8.0:
				en_el_medio += 1
			else:
				atras += 1
	return {"area": float(en_area) / 12.0, "medio": float(en_el_medio) / 12.0,
		"atras": float(atras) / 12.0}


func _test_al_corner_sube_lo_que_dice_el_estilo() -> void:
	print("
=== Al corner sube lo que dice el estilo ===")
	# Subian solo los roles de ataque, asi que un 5-3-2 mandaba DOS
	# jugadores al area. Mandarlos a todos tampoco es: cuantos suben lo
	# decide la filosofia del equipo.
	var fisico := _reparto_de_corner("Físico")
	var defensivo := _reparto_de_corner("Contragolpe")
	if float(fisico["area"]) - float(defensivo["area"]) < 2.0:
		print("FALLA: Fisico sube %.1f al area y Contragolpe %.1f." % [
			fisico["area"], defensivo["area"]])
		return
	# Y el que no sube al area no se queda en su casillero: juega el
	# rebote desde la mitad de la cancha.
	if float(defensivo["medio"]) < 1.0:
		print("FALLA: con Contragolpe solo %.1f se paran en la mitad." % defensivo["medio"])
		return
	if float(fisico["atras"]) > 1.5:
		print("FALLA: con Fisico quedan %.1f atras; deberia quedar el resguardo minimo." % fisico["atras"])
		return
	print("OK: Fisico sube %.1f al area y %.1f al medio; Contragolpe %.1f y %.1f." % [
		fisico["area"], fisico["medio"], defensivo["area"], defensivo["medio"]])


func _test_los_de_arriba_bajan_a_recibir() -> void:
	print("\n=== Con la pelota en campo propio, los de arriba bajan ===")
	# El pin al hombro del ultimo defensor era incondicional: quedaban
	# clavados contra la linea rival aunque la pelota estuviera a sesenta
	# metros, y la unica manera de llegarles era el pelotazo.
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 200
	var estado := _armar_estado(rng)
	var equipo: Team = estado["home"]

	# La pelota bien atras, en campo propio del local.
	estado["pelota"]["pos"] = Vector2(-40.0, 0.0)
	MotorEspacial._calcular_linea_offside(estado)
	var bajaron := 0
	var mirados := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not e["equipo_local"] or not MotorEspacial.ROLES_QUE_ATACAN.has(str(e["rol"])):
			continue
		if str(e["rol"]) == "DC":
			continue  # el 9 se queda de referencia, a proposito
		mirados += 1
		var objetivo := MotorEspacial._objetivo_sin_pelota(estado, e, equipo, true)
		# Baja: su objetivo esta mas atras que su casillero de formacion.
		if objetivo.x < float(e["base"].x):
			bajaron += 1
	if mirados == 0:
		print("FALLA: esta formacion no tiene extremos ni enganche; el test no mide nada.")
		return
	if bajaron != mirados:
		print("FALLA: solo %d de %d bajaron a recibir." % [bajaron, mirados])
		return
	print("OK: los %d de arriba (sin contar al 9) bajan a ofrecerse." % mirados)


func _test_el_estilo_corre_la_linea() -> void:
	print("\n=== Presion alta defiende mas arriba que Defensivo ===")
	# Antes el estilo multiplicaba cuanto se sigue a la pelota, que la
	# amplifica en las DOS direcciones y se cancela solo: los seis
	# estilos defendian entre 40,3 y 41,8 m de su arco.
	var alta := _linea_defensiva("Presión alta")
	var baja := _linea_defensiva("Defensivo")
	if alta - baja < 6.0:
		print("FALLA: Presion alta a %.1f m y Defensivo a %.1f m del arco propio." % [alta, baja])
		return
	print("OK: Presion alta a %.1f m del arco propio y Defensivo a %.1f." % [alta, baja])


## Distancia media de los 10 de campo a su arco, con el rival atacando.
func _linea_defensiva(estilo: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 300
	var estado := _armar_estado(rng, estilo)
	var equipo: Team = estado["home"]
	estado["pelota"]["pos"] = Vector2(-25.0, 0.0)
	MotorEspacial._calcular_linea_offside(estado)
	var suma := 0.0
	var n := 0
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		if not e["equipo_local"] or str(e["rol"]) == "ARQ":
			continue
		suma += MotorEspacial._objetivo_sin_pelota(estado, e, equipo, false).x \
			+ MotorEspacial.MEDIO_LARGO
		n += 1
	return suma / maxf(n, 1)
