extends SceneTree

## §8.4 #26 (ex club) y #27 (titulo o descenso en juego en las ultimas 5
## fechas). Son dos de los cinco modificadores de motivacion que el GDD le
## asigna al bloque D, que estaba vacio en el 91% de los duelos.

const SEED := 24680


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_el_sello_de_procedencia(rng)
	_test_ex_club_suma_solo_contra_el_suyo(rng)
	_test_la_recta_final_solo_al_final(rng)
	_test_la_recta_final_es_para_los_extremos(rng)
	_test_entra_en_el_bloque_d(rng)

	quit()


func _test_el_sello_de_procedencia(rng: RandomNumberGenerator) -> void:
	print("=== Cambiar de club deja marca, y volver al mismo no la duplica ===")
	var a := Team.generar("Primero", rng, 0)
	var b := Team.generar("Segundo", rng, 400)
	var j: Dictionary = a.jugadores[5]

	if str(j.get("club_actual", "")) != "Primero":
		print("FALLA: al generarse tendria que quedar sellado como de Primero.")
		return
	if not j.get("ex_clubes", []).is_empty():
		print("FALLA: recien generado no tendria que tener ex clubes.")
		return

	b._registrar_fichaje(j, 1000.0, 3)
	var ex: Array = j.get("ex_clubes", [])
	if not ex.has("Primero") or str(j["club_actual"]) != "Segundo":
		print("FALLA: tras el pase quedo ex_clubes=%s, club_actual=%s" % [
			str(ex), str(j.get("club_actual", ""))])
		return

	# Vuelve al primero y despues se va otra vez: no puede duplicar.
	a._registrar_fichaje(j, 1000.0, 3)
	b._registrar_fichaje(j, 1000.0, 3)
	var ex2: Array = j.get("ex_clubes", [])
	if ex2.size() != 2:
		print("FALLA: tras dar la vuelta entera quedaron %d ex clubes: %s" % [
			ex2.size(), str(ex2)])
		return
	print("OK: %s, y hoy juega en %s." % [str(ex2), str(j["club_actual"])])


func _test_ex_club_suma_solo_contra_el_suyo(rng: RandomNumberGenerator) -> void:
	print("\n=== Solo motiva contra el club que lo dejo ir ===")
	var viejo := Team.generar("ClubViejo", rng, 0)
	var nuevo := Team.generar("ClubNuevo", rng, 400)
	var otro := Team.generar("Cualquiera", rng, 800)
	var j: Dictionary = viejo.jugadores[7]
	nuevo._registrar_fichaje(j, 1000.0, 3)

	var contra_el_suyo := Motivacion.modificador(j, nuevo, viejo)
	var contra_otro := Motivacion.modificador(j, nuevo, otro)
	if contra_el_suyo < Motivacion.BONUS_EX_CLUB:
		print("FALLA: contra su ex club dio %.1f." % contra_el_suyo)
		return
	if contra_otro != 0.0:
		print("FALLA: contra un club cualquiera dio %.1f." % contra_otro)
		return
	print("OK: +%.0f contra su ex club, 0 contra el resto." % contra_el_suyo)


func _test_la_recta_final_solo_al_final(rng: RandomNumberGenerator) -> void:
	print("\n=== La recta final se prende recien en las ultimas fechas ===")
	var liga := Liga.new()
	var nombres := []
	for i in range(20):
		nombres.append("R%d" % i)
	liga.inicializar(nombres, rng, 0)

	Motivacion.marcar_recta_final(liga, 0)
	var alguno_al_principio := false
	for e in liga.equipos:
		alguno_al_principio = alguno_al_principio or e.recta_final_caliente
	if alguno_al_principio:
		print("FALLA: en la fecha 1 ya habia equipos con la recta final prendida.")
		return

	var ultima: int = liga.fixture.size() - 1
	Motivacion.marcar_recta_final(liga, ultima)
	var cuantos := 0
	for e in liga.equipos:
		if e.recta_final_caliente:
			cuantos += 1
	if cuantos == 0:
		print("FALLA: en la ultima fecha no se prendio para nadie.")
		return
	print("OK: en la fecha 1 nadie, y en la ultima %d de %d equipos." % [
		cuantos, liga.equipos.size()])


func _test_la_recta_final_es_para_los_extremos(rng: RandomNumberGenerator) -> void:
	print("\n=== Se prende arriba y abajo, no en el medio de la tabla ===")
	var liga := Liga.new()
	var nombres := []
	for i in range(20):
		nombres.append("E%d" % i)
	liga.inicializar(nombres, rng, 0)
	Motivacion.marcar_recta_final(liga, liga.fixture.size() - 1)

	var orden: Array = liga.tabla_ordenada()
	for pos in range(orden.size()):
		var e: Team = null
		for candidato in liga.equipos:
			if candidato.nombre == orden[pos]:
				e = candidato
		var deberia: bool = pos < Motivacion.PUESTOS_DE_ARRIBA \
			or pos >= orden.size() - Motivacion.PUESTOS_DE_ABAJO
		if e.recta_final_caliente != deberia:
			print("FALLA: el %d° tiene la recta final en %s y deberia ser %s." % [
				pos + 1, e.recta_final_caliente, deberia])
			return
	print("OK: prendida en los %d de arriba y los %d de abajo, apagada en los otros %d." % [
		Motivacion.PUESTOS_DE_ARRIBA, Motivacion.PUESTOS_DE_ABAJO,
		orden.size() - Motivacion.PUESTOS_DE_ARRIBA - Motivacion.PUESTOS_DE_ABAJO])


func _test_entra_en_el_bloque_d(rng: RandomNumberGenerator) -> void:
	print("\n=== Llega al duelo, y por el bloque D ===")
	var viejo := Team.generar("Viejo", rng, 0)
	var nuevo := Team.generar("Nuevo", rng, 400)
	var j: Dictionary = viejo.jugadores[9]
	nuevo._registrar_fichaje(j, 1000.0, 3)
	nuevo.jugadores[9] = j
	nuevo.recta_final_caliente = true

	var con := MatchEngine._bloques_equipo(nuevo, viejo, j, "pases", 45, rng)
	nuevo.recta_final_caliente = false
	var otro := Team.generar("Neutro", rng, 800)
	var sin := MatchEngine._bloques_equipo(nuevo, otro, j, "pases", 45, rng)

	if float(con["D"]) - float(sin["D"]) < Motivacion.BONUS_EX_CLUB:
		print("FALLA: el bloque D paso de %.1f a %.1f." % [float(sin["D"]), float(con["D"])])
		return
	print("OK: bloque D %.1f sin motivacion y %.1f con ex club + recta final." % [
		float(sin["D"]), float(con["D"])])
