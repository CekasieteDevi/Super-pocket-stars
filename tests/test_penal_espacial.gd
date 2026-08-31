extends SceneTree

## El penal tiene que VERSE como un penal: el juego para, el area queda
## vacia salvo pateador y arquero, la pelota espera en el punto, y recien
## despues se patea.
##
## Antes se resolvia en el mismo tick en que se cobraba: en la cancha se
## veia la falta y la pelota adentro del arco sin nada en el medio.

const SEED := 9110


func _init() -> void:
	_test_el_penal_para_el_juego()
	_test_el_area_queda_vacia()
	_test_se_ejecuta_al_terminar_la_pausa()
	_test_el_pateador_esta_detras_de_la_pelota()
	_test_el_remate_se_ve_viajar()
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


func _test_el_penal_para_el_juego() -> void:
	print("=== Cobrar un penal PARA el juego, no lo resuelve ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var goles_antes: int = estado["goles_log"].size()

	MotorEspacial._cobrar_penal(estado, true, 30)

	if not estado.has("balon_parado"):
		print("FALLA: no quedo un balon parado armado.")
		return
	if str(estado["balon_parado"]["tipo"]) != "penal":
		print("FALLA: el balon parado quedo como '%s'." % str(estado["balon_parado"]["tipo"]))
		return
	if int(estado["detenido"]) <= 0:
		print("FALLA: el juego no quedo detenido.")
		return
	if estado["goles_log"].size() != goles_antes:
		print("FALLA: se resolvio en el acto, ya hay un gol cargado.")
		return
	print("OK: queda armado y el juego detenido %d ticks, sin resolver nada todavia." % int(estado["detenido"]))


func _test_el_area_queda_vacia() -> void:
	print("\n=== En el area solo quedan el pateador y el arquero ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var estado := _armar_estado(rng)
	MotorEspacial._cobrar_penal(estado, true, 30)

	var arco := MotorEspacial.arco_rival(true)
	var bp: Dictionary = estado["balon_parado"]
	var pateador_clave := MotorEspacial.clave_de(int(bp["pateador_id"]), true)
	var adentro := []
	for id in estado["jugadores"]:
		var e: Dictionary = estado["jugadores"][id]
		var p: Vector2 = e["pos"]
		if absf(arco.x - p.x) <= 16.5 and absf(p.y) <= 20.16:
			if id == pateador_clave or str(e["rol"]) == "ARQ":
				continue
			adentro.append(str(e["rol"]))
	if not adentro.is_empty():
		print("FALLA: quedaron %d adentro del area: %s" % [adentro.size(), str(adentro)])
		return

	# Y la pelota esperando en el punto, a 11 m del arco.
	var d: float = estado["pelota"]["pos"].distance_to(arco)
	if absf(d - MotorEspacial.DIST_PENAL) > 0.2:
		print("FALLA: la pelota quedo a %.1f m del arco." % d)
		return
	print("OK: area despejada y la pelota esperando a %.0f m." % d)


func _test_se_ejecuta_al_terminar_la_pausa() -> void:
	print("\n=== Al terminar la pausa se patea ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var penales := 0
	var resueltos := 0

	# Se cobran varios para no depender de que uno solo entre o lo atajen.
	for i in range(30):
		var estado := _armar_estado(rng)
		MotorEspacial._cobrar_penal(estado, true, 30)
		penales += 1
		var eventos_antes: int = estado["eventos"].size()
		# Se corren ticks de sobra para cubrir la pausa entera.
		for t in range(MotorEspacial.TICKS_DETENIDO["penal"] + 10):
			MotorEspacial._tick(estado, false)
		for k in range(eventos_antes, estado["eventos"].size()):
			if str(estado["eventos"][k].get("tipo", "")) == "penal":
				resueltos += 1
				break

	if resueltos != penales:
		print("FALLA: se cobraron %d penales y se ejecutaron %d." % [penales, resueltos])
		return
	print("OK: los %d penales cobrados se patearon al terminar la pausa." % penales)


## El pateador tiene que estar DETRAS de la pelota, o sea mas lejos del
## arco que el punto. Estaba al reves: quedaba entre la pelota y el arco,
## de espaldas, como si pateara para el otro lado.
func _test_el_pateador_esta_detras_de_la_pelota() -> void:
	print("\n=== El pateador queda detras de la pelota ===")
	# Los dos arcos, porque el error de signo solo se ve si se miran los dos.
	for saca_local in [true, false]:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + 3
		var estado := _armar_estado(rng)
		MotorEspacial._cobrar_penal(estado, saca_local, 30)
		var bp: Dictionary = estado["balon_parado"]
		var arco := MotorEspacial.arco_rival(saca_local)
		var pat: Dictionary = estado["jugadores"][MotorEspacial.clave_de(
			int(bp["pateador_id"]), saca_local)]
		var d_pelota: float = absf(arco.x - float(bp["pos"].x))
		var d_pateador: float = absf(arco.x - pat["pos"].x)
		if d_pateador <= d_pelota:
			print("FALLA: atacando el arco en x=%.0f el pateador quedo a %.1f m del arco y la pelota a %.1f: esta adelante." % [
				arco.x, d_pateador, d_pelota])
			return
	print("OK: en los dos arcos el pateador toma carrera desde atras.")


## El remate tiene que VIAJAR: la pelota sale del punto y tarda en
## llegar. Antes se aplicaba en el mismo tick, asi que del corte se
## pasaba a la pelota adentro del arco sin ver el disparo ni la atajada.
func _test_el_remate_se_ve_viajar() -> void:
	print("\n=== La pelota del penal viaja hasta el arco ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 4
	var volaron := 0
	var se_tiro_el_arquero := 0
	for i in range(20):
		var estado := _armar_estado(rng)
		MotorEspacial._cobrar_penal(estado, true, 30)
		var arco := MotorEspacial.arco_rival(true)
		for t in range(MotorEspacial.TICKS_DETENIDO["penal"]):
			MotorEspacial._tick(estado, false)
		# Justo despues de la pausa, la pelota tiene que estar en el aire
		# y todavia lejos del arco.
		var pelota: Dictionary = estado["pelota"]
		if bool(pelota["en_vuelo"]) and pelota["pos"].distance_to(arco) > 3.0:
			volaron += 1
		# Y el arquero tiene adonde tirarse mientras la pelota viaja: sin
		# eso se queda clavado y la pelota le pasa por al lado.
		if pelota.get("remate", {}).has("destino_arquero"):
			se_tiro_el_arquero += 1
	if volaron != 20:
		print("FALLA: solo %d de 20 penales salieron viajando." % volaron)
		return
	if se_tiro_el_arquero < 15:
		print("FALLA: el arquero se tiro en %d de 20." % se_tiro_el_arquero)
		return
	print("OK: los 20 remates viajan y el arquero se tira en %d." % se_tiro_el_arquero)
