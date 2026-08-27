extends SceneTree

## §9.4 rework: la red de espionaje del club.

const SEED := 1919


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_test_arranca_con_uno_de_una_estrella(rng)
	_test_las_estrellas_son_velocidad(rng)
	_test_un_informe_tarda_y_termina(rng)
	_test_uno_por_jugador_y_slots_limitados(rng)
	_test_despedir_libera_el_slot(rng)
	_test_guardado(rng)
	quit()


func _test_arranca_con_uno_de_una_estrella(rng: RandomNumberGenerator) -> void:
	print("=== Todo club arranca con un investigador de 1 estrella ===")
	var e := Team.generar("Espia", rng, 0)
	if e.investigadores.size() == 1 and int(e.investigadores[0]["estrellas"]) == 1 \
			and e.conocimiento.is_empty():
		print("OK: 1 investigador de 1 estrella y cero jugadores conocidos.")
	else:
		print("FALLA: %s / conocimiento %s" % [e.investigadores, e.conocimiento])


func _test_las_estrellas_son_velocidad(_rng: RandomNumberGenerator) -> void:
	print("\n=== Las estrellas son VELOCIDAD, no calidad de informe ===")
	var una := Investigadores.dias_de_informe(1)
	var diez := Investigadores.dias_de_informe(10)
	var caro := Investigadores.costo(10)
	var barato := Investigadores.costo(1)
	if una > diez * 5.0 and caro > barato * 50.0:
		print("OK: 1 estrella tarda %.0f dias y 10 estrellas %.0f; cuestan %s y %s." % [
			una, diez, Economia.formato_dinero(barato), Economia.formato_dinero(caro)])
	else:
		print("FALLA: dias %.0f/%.0f, costos %.0f/%.0f." % [una, diez, barato, caro])


func _test_un_informe_tarda_y_termina(rng: RandomNumberGenerator) -> void:
	print("\n=== Un informe tarda lo suyo y despues revela ===")
	var e := Team.generar("Espia2", rng, 0)
	var ajeno := Team.generar("Rival", rng, 1000)
	var objetivo: int = ajeno.jugadores[9]["id"]

	var r := Investigadores.investigar(e, objetivo, ajeno.nombre)
	if not r["exito"]:
		print("FALLA: no pudo empezar (%s)." % r["motivo"])
		return
	e.avanzar_dias(30)
	var a_medias := Investigadores.progreso(e, objetivo)
	if Investigadores.conoce(e, objetivo):
		print("FALLA: lo conocio a los 30 dias, deberia tardar ~133.")
		return
	e.avanzar_dias(120)
	if Investigadores.conoce(e, objetivo) and Investigadores.libres(e).size() == 1:
		print("OK: a los 30 dias iba %.0f%% y a los 150 el informe cerro y el investigador quedo libre." % [a_medias * 100.0])
	else:
		print("FALLA: conoce=%s libres=%d" % [Investigadores.conoce(e, objetivo), Investigadores.libres(e).size()])


func _test_uno_por_jugador_y_slots_limitados(rng: RandomNumberGenerator) -> void:
	print("\n=== Un investigador por jugador, y hay 10 slots ===")
	var e := Team.generar("Espia3", rng, 0)
	e.caja["mejoras"] = 50000000.0
	for _i in range(Investigadores.SLOTS + 3):
		Investigadores.contratar(e, 1)
	if e.investigadores.size() != Investigadores.SLOTS:
		print("FALLA: quedaron %d investigadores, el tope es %d." % [e.investigadores.size(), Investigadores.SLOTS])
		return
	var ajeno := Team.generar("Rival3", rng, 2000)
	var objetivo: int = ajeno.jugadores[0]["id"]
	Investigadores.investigar(e, objetivo, ajeno.nombre)
	var repetido := Investigadores.investigar(e, objetivo, ajeno.nombre)
	if not repetido["exito"] and Investigadores.libres(e).size() == Investigadores.SLOTS - 1:
		print("OK: tope de %d slots y no se puede poner a dos sobre el mismo jugador." % Investigadores.SLOTS)
	else:
		print("FALLA: repetido=%s libres=%d" % [repetido, Investigadores.libres(e).size()])


func _test_despedir_libera_el_slot(rng: RandomNumberGenerator) -> void:
	print("\n=== Despedir libera el slot para poner a uno mejor ===")
	var e := Team.generar("Espia4", rng, 0)
	e.caja["mejoras"] = 50000000.0
	var id_malo: int = int(e.investigadores[0]["id"])
	Investigadores.despedir(e, id_malo)
	var r := Investigadores.contratar(e, 10)
	if e.investigadores.size() == 1 and int(e.investigadores[0]["estrellas"]) == 10 and r["exito"]:
		print("OK: se fue el de 1 estrella y entro uno de 10 por %s." % Economia.formato_dinero(r["costo"]))
	else:
		print("FALLA: %s" % [e.investigadores])


func _test_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Investigadores y conocimiento sobreviven al guardado ===")
	var e := Team.generar("Espia5", rng, 0)
	var ajeno := Team.generar("Rival5", rng, 3000)
	Investigadores.marcar_conocido(e, int(ajeno.jugadores[0]["id"]))
	Investigadores.investigar(e, ajeno.jugadores[1]["id"], ajeno.nombre)
	e.avanzar_dias(40)

	var vuelto := Team.cargar(JSON.parse_string(JSON.stringify(e.guardar())))
	var sabe: bool = Investigadores.conoce(vuelto, ajeno.jugadores[0]["id"])
	var sigue: float = Investigadores.progreso(vuelto, ajeno.jugadores[1]["id"])
	if sabe and sigue > 0.2:
		print("OK: conocimiento intacto y el informe en curso va %.0f%%." % (sigue * 100.0))
	else:
		print("FALLA: sabe=%s progreso=%.2f" % [sabe, sigue])
