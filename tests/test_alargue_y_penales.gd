extends SceneTree

## El cruce de copa del jugador se juega ENTERO en la cancha: los 90', el
## alargue y la tanda de penales.
##
## Antes el partido se cortaba en el minuto 90 y el alargue y los penales le
## llegaban escritos en el resumen. El Motor V2 los juega en la cancha.

const SEED := 4242

## Cuantos cruces se prueban buscando los dos casos que hacen falta: uno
## que se defina en el alargue y uno que llegue a los penales.
const CRUCES := 60
## Partidos de liga buscando un empate. Empata uno de cada cinco (12 de 60
## con esta semilla): con 20 partidos el test fallaba por azar, sin ningun
## empate en los primeros 20 (BUG-011 movio los resultados).
const PARTIDOS_DE_LIGA := 40


func _init() -> void:
	var fallos := 0
	var casos := _buscar_casos()
	fallos += _test_hay_de_los_dos(casos)
	fallos += _test_el_alargue_se_ve(casos)
	fallos += _test_la_tanda_se_patea_en_la_cancha(casos)
	fallos += _test_la_tanda_no_toca_el_marcador(casos)
	fallos += _test_el_marcador_de_la_tanda_coincide(casos)
	fallos += _test_la_tanda_se_patea_a_un_solo_arco(casos)
	fallos += _test_en_liga_el_empate_sigue_siendo_empate()
	fallos += _test_mirar_la_tanda_no_la_cambia()
	print("\nFALLOS=%d" % fallos)
	quit()


func _armar_cruce(rng: RandomNumberGenerator, i: int) -> Array:
	var casa := Team.generar("Casa %d" % i, rng, i * 100)
	var visita := Team.generar("Visita %d" % i, rng, 50000 + i * 100)
	Alineacion.arreglar(casa)
	Alineacion.arreglar(visita)
	return [casa, visita]


## Juega cruces hasta tener uno definido en el alargue y uno definido por
## penales. Los dos se reusan en todos los tests que siguen.
func _buscar_casos() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casos := {}
	for i in range(CRUCES):
		var equipos := _armar_cruce(rng, i)
		var r := MotorV2.simular(equipos[0], equipos[1], rng, true, true)
		var d := str(r["definicion"])
		if d != "90 minutos" and not casos.has(d):
			casos[d] = r
		if casos.has("alargue") and casos.has("penales"):
			break
	return casos


func _test_hay_de_los_dos(casos: Dictionary) -> int:
	print("=== En %d cruces a eliminacion directa salen alargue y penales ===" % CRUCES)
	var faltan := []
	for d in ["alargue", "penales"]:
		if not casos.has(d):
			faltan.append(d)
	if not faltan.is_empty():
		print("FALLA: en %d cruces no salio ningun caso de: %s." % [CRUCES, ", ".join(faltan)])
		return 1
	print("OK: hay un cruce definido en el alargue y uno definido por penales.")
	return 0


## El alargue son dos tiempos de 15' que se juegan en la cancha: arrancan con
## su saque y el reloj llega al 120.
func _test_el_alargue_se_ve(casos: Dictionary) -> int:
	print("
=== El alargue se juega en la cancha ===")
	var fallos := 0
	for d in ["alargue", "penales"]:
		if not casos.has(d):
			continue
		var r: Dictionary = casos[d]
		var saques := []
		var minuto_max := 0
		for ev in r["eventos"]:
			if str(ev["tipo"]) == "saque_inicial":
				saques.append(str(ev["resultado"]))
			if str(ev["tipo"]) != "penal_tanda":
				minuto_max = maxi(minuto_max, int(ev["minuto"]))
		if not (saques.has("3") and saques.has("4")):
			print("FALLA: el cruce definido en '%s' no arranco los dos tiempos del alargue (%s)." % [d, str(saques)])
			fallos += 1
			continue
		if minuto_max < 105:
			print("FALLA: el alargue de '%s' llego solo hasta el minuto %d." % [d, minuto_max])
			fallos += 1
			continue
		print("OK: '%s' juega los dos tiempos del alargue y llega al minuto %d." % [d, minuto_max])
	return fallos


func _test_la_tanda_se_patea_en_la_cancha(casos: Dictionary) -> int:
	print("
=== La tanda se patea en la cancha, penal por penal ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	var remates := 0
	for ev in r["eventos"]:
		if str(ev["tipo"]) == "penal_tanda":
			remates += 1
	var pateados: int = r["penales"]["tandas"].size()
	if remates != pateados or pateados < 6:
		print("FALLA: se patearon %d penales y el relato tiene %d." % [pateados, remates])
		return 1
	print("OK: %d penales pateados, %d en el relato." % [pateados, remates])
	return 0


## Un penal de la tanda no es un gol del partido: los 120' terminaron
## empatados y el marcador se queda ahi.
func _test_la_tanda_no_toca_el_marcador(casos: Dictionary) -> int:
	print("
=== Los penales de la tanda no tocan el marcador ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	if int(r["goles_local"]) != int(r["goles_visitante"]):
		print("FALLA: se definio por penales pero el partido quedo %d-%d." % [
			int(r["goles_local"]), int(r["goles_visitante"])])
		return 1
	var pen: Dictionary = r["penales"]
	if int(pen["goles_local"]) == int(pen["goles_visitante"]):
		print("FALLA: la tanda quedo empatada %d-%d." % [int(pen["goles_local"]), int(pen["goles_visitante"])])
		return 1
	if (r["goles_log"] as Array).size() != int(r["goles_local"]) + int(r["goles_visitante"]):
		print("FALLA: hay %d goles anotados para un %d-%d." % [(r["goles_log"] as Array).size(),
			int(r["goles_local"]), int(r["goles_visitante"])])
		return 1
	print("OK: el partido queda %d-%d y la tanda %d-%d." % [int(r["goles_local"]), int(r["goles_visitante"]),
		int(pen["goles_local"]), int(pen["goles_visitante"])])
	return 0


## Lo que se cuenta tiene que ser lo que paso: el ultimo penal del relato
## trae el marcador final de la tanda.
func _test_el_marcador_de_la_tanda_coincide(casos: Dictionary) -> int:
	print("
=== El marcador que se cuenta en la tanda es el resultado real ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var r: Dictionary = casos["penales"]
	var ultimo := {}
	for ev in r["eventos"]:
		if str(ev["tipo"]) == "penal_tanda":
			ultimo = ev
	var pen: Dictionary = r["penales"]
	if ultimo.is_empty() or int(ultimo["tanda_local"]) != int(pen["goles_local"]) 			or int(ultimo["tanda_visitante"]) != int(pen["goles_visitante"]):
		print("FALLA: el relato termina la tanda %s y el resultado dice %d-%d." % [
			str([ultimo.get("tanda_local"), ultimo.get("tanda_visitante")]), int(pen["goles_local"]), int(pen["goles_visitante"])])
		return 1
	print("OK: relato y resultado dicen lo mismo, %d-%d." % [int(pen["goles_local"]), int(pen["goles_visitante"])])
	return 0


## En una tanda real los dos equipos patean al mismo arco. El motor no cambia
## de lado: lo hace la vista (PartidoVistoV2). Se vuelve a jugar la receta con
## la vista y se mira dónde termina cada penal en la pantalla.
func _test_la_tanda_se_patea_a_un_solo_arco(casos: Dictionary) -> int:
	print("
=== Los dos equipos patean la tanda al mismo arco ===")
	if not casos.has("penales"):
		print("FALLA: no hay cruce definido por penales para revisar.")
		return 1
	var c: Object = CerebroV2.armar_de_receta(casos["penales"]["receta_v2"])
	var visto := PartidoVistoV2.new(c)
	var lados := {}
	var por_equipo := [0, 0]
	var vistos := 0
	var pasos := 0
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
		c.avanzar()
		visto.actualizar()
		pasos += 1
		if str(c.get_estado()["periodo"]) != "tanda":
			continue
		var eventos: Array = c.eventos()
		for k in range(vistos, eventos.size()):
			if str(eventos[k]["tipo"]) == "penal_tanda":
				lados[signf(visto.get_pelota_pos().x)] = true
				por_equipo[int(eventos[k]["equipo"])] += 1
		vistos = eventos.size()
	if lados.size() != 1 or por_equipo[0] == 0 or por_equipo[1] == 0:
		print("FALLA: en pantalla los penales terminan en %d arcos (%d del local, %d del visitante)." % [lados.size(),
			por_equipo[0], por_equipo[1]])
		return 1
	print("OK: %d penales del local y %d del visitante, todos al mismo arco." % [por_equipo[0], por_equipo[1]])
	return 0


## El alargue es de la eliminacion directa, no del motor: un partido de
## liga empatado sigue terminando empatado a los 90.
func _test_en_liga_el_empate_sigue_siendo_empate() -> int:
	print("\n=== En liga un empate termina a los 90' ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var empates := 0
	for i in range(PARTIDOS_DE_LIGA):
		var equipos := _armar_cruce(rng, i)
		var r := MotorV2.simular(equipos[0], equipos[1], rng, false)
		if str(r["definicion"]) != "90 minutos":
			print("FALLA: un partido de liga se definio en '%s'." % str(r["definicion"]))
			return 1
		if not r["penales"].is_empty():
			print("FALLA: un partido de liga pateo penales.")
			return 1
		if int(r["goles_local"]) == int(r["goles_visitante"]):
			empates += 1
	if empates == 0:
		print("FALLA: en %d partidos de liga no hubo ni un empate: el test no midio nada." % PARTIDOS_DE_LIGA)
		return 1
	print("OK: %d partidos de liga, %d empates, ninguno con alargue ni penales." % [PARTIDOS_DE_LIGA, empates])
	return 0


## Penales resuelve la tanda de los cruces de la IA (MatchEngine). Mirarla no
## puede cambiar ni un remate: el callback solo observa.
func _test_mirar_la_tanda_no_la_cambia() -> int:
	print("\n=== Mirar la tanda no cambia ni un penal ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipos := _armar_cruce(rng, 0)

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = SEED
	var a_ciegas := Penales.definir(equipos[0], equipos[1], rng_a)

	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = SEED
	var mirados := []
	var mirada := Penales.definir(equipos[0], equipos[1], rng_b,
		func(pateador: Dictionary, _arquero: Dictionary, _es_local: bool, gol: bool) -> void:
			mirados.append({"id": int(pateador["id"]), "gol": gol}))

	var difiere: bool = int(a_ciegas["goles_local"]) != int(mirada["goles_local"])
	difiere = difiere or int(a_ciegas["goles_visitante"]) != int(mirada["goles_visitante"])
	if difiere:
		print("FALLA: la misma tanda da %d-%d sin mirarla y %d-%d mirandola." % [
			int(a_ciegas["goles_local"]), int(a_ciegas["goles_visitante"]),
			int(mirada["goles_local"]), int(mirada["goles_visitante"])])
		return 1
	if mirados.size() != a_ciegas["tandas"].size():
		print("FALLA: se patearon %d penales y se miraron %d." % [
			a_ciegas["tandas"].size(), mirados.size()])
		return 1
	for i in range(mirados.size()):
		var esperado: Dictionary = a_ciegas["tandas"][i]
		var mal: bool = int(mirados[i]["id"]) != int(esperado["jugador_id"])
		mal = mal or bool(mirados[i]["gol"]) != bool(esperado["gol"])
		if mal:
			print("FALLA: el penal %d no coincide entre mirar y no mirar." % (i + 1))
			return 1
	print("OK: %d penales, mismo pateador y mismo resultado en los dos casos (%d-%d)." % [
		mirados.size(), int(mirada["goles_local"]), int(mirada["goles_visitante"])])
	return 0
