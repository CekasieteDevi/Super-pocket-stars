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
