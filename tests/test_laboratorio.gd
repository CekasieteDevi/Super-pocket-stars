extends SceneTree

## El laboratorio de animaciones: que cada situacion genere fotogramas de
## verdad y que se vea lo que promete.

const SEED := 2024


func _init() -> void:
	var fallas := 0
	for s in Laboratorio.SITUACIONES:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var r := Laboratorio.generar(str(s["clave"]), casa, visita, rng)
		var fotogramas: Array = r["fotogramas"]
		var tipos := {}
		for e in r["eventos"]:
			tipos[str(e.get("tipo", ""))] = int(tipos.get(str(e.get("tipo", "")), 0)) + 1
		# Ni tan corto que no se vea nada ni tan largo que sea un partido:
		# la primera version corria 200 ticks fijos —53 segundos— para una
		# jugada de 1 a 5.
		if fotogramas.size() < 20 or fotogramas.size() > 120:
			print("FALLA: %s genero %d fotogramas (se esperan entre 20 y 120)." % [
				s["clave"], fotogramas.size()])
			fallas += 1
			continue
		# El evento que le da nombre a la jugada tiene que estar PEGADO a
		# un fotograma del principio: la vista lee los eventos de cada
		# cuadro para narrar y mostrar la tarjeta, y los que se emiten
		# fuera de un tick no los ve nadie.
		#
		# Se miran los primeros 20 y no los primeros 12 porque el gol no
		# emite su evento cuando sale el remate sino cuando la pelota
		# LLEGA al arco, unos ticks despues: es correcto que sea asi.
		var con_evento := -1
		for f in range(mini(fotogramas.size(), 20)):
			if not fotogramas[f].get("eventos", []).is_empty():
				con_evento = f
				break
		if con_evento < 0:
			print("FALLA: %s no engancha ningun evento a los primeros fotogramas." % s["clave"])
			fallas += 1
			continue
		# Que los 22 (o 21 tras la roja) esten y que la pelota exista.
		var ultimo: Dictionary = fotogramas[fotogramas.size() - 1]
		if ultimo["jugadores"].size() < 20:
			print("FALLA: %s termina con %d jugadores en cancha." % [
				s["clave"], ultimo["jugadores"].size()])
			fallas += 1
			continue
		print("OK: %-12s %d fotogramas, %d en cancha al final, eventos %s" % [
			s["clave"], fotogramas.size(), ultimo["jugadores"].size(), tipos])
	fallas += _test_no_toca_al_equipo()
	fallas += _test_siempre_da_lo_mismo()
	fallas += _test_el_gol_es_gol()
	fallas += _test_el_corner_tiene_gente_en_el_area()
	print("FALLOS=%d" % fallas)
	quit()


## El motor lesiona y suspende de verdad: _chequear_lesion escribe en
## lesiones y una roja suma una fecha a suspendidos, y reset_partido() no
## limpia ninguna de las dos. Mirar una animacion no puede romperte un
## titular, asi que se juega con copias — esto lo comprueba.
func _test_no_toca_al_equipo() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	var fallas := 0
	for s in Laboratorio.SITUACIONES:
		var copia_casa := Team.cargar(casa.guardar())
		var copia_visita := Team.cargar(visita.guardar())
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED
		Laboratorio.generar(str(s["clave"]), copia_casa, copia_visita, r2)
		for e in [casa, visita]:
			if not e.lesiones.is_empty() or not e.suspendidos.is_empty() 					or not e.expulsados_partido.is_empty() or e.goles != 0:
				print("FALLA: reproducir \"%s\" toco al equipo de verdad (%d lesiones, %d suspendidos, %d goles)." % [
					s["clave"], e.lesiones.size(), e.suspendidos.size(), e.goles])
				fallas += 1
	if fallas == 0:
		print("OK: reproducir las %d jugadas no deja lesiones, suspensiones ni goles en los equipos reales." % [
			Laboratorio.SITUACIONES.size()])
	return fallas


## Una jugada del laboratorio tiene que dar SIEMPRE lo mismo: se viene a
## mirar como quedo la animacion, y si el resultado cambia entre una
## reproduccion y la siguiente no se puede comparar nada.
func _test_siempre_da_lo_mismo() -> int:
	var fallas := 0
	for s in Laboratorio.SITUACIONES:
		var firmas := []
		for intento in range(2):
			var rng := RandomNumberGenerator.new()
			rng.seed = SEED
			var casa := Team.generar("Casa", rng, 0)
			var visita := Team.generar("Visita", rng, 400)
			var propio := RandomNumberGenerator.new()
			propio.seed = Laboratorio.SEMILLA
			var r := Laboratorio.generar(str(s["clave"]), casa, visita, propio)
			var fg: Array = r["fotogramas"]
			var ultimo: Dictionary = fg[fg.size() - 1]
			firmas.append("%d|%d-%d|%.2f,%.2f" % [
				fg.size(), int(r["goles_local"]), int(r["goles_visitante"]),
				float(ultimo["pelota"]["x"]), float(ultimo["pelota"]["y"])])
		if firmas[0] != firmas[1]:
			print("FALLA: %s da distinto cada vez (%s vs %s)." % [
				s["clave"], firmas[0], firmas[1]])
			fallas += 1
	if fallas == 0:
		print("OK: las %d jugadas dan exactamente lo mismo al repetirlas." % [
			Laboratorio.SITUACIONES.size()])
	return fallas


## "Gol y festejo" tiene que terminar en gol. Antes se tiraba el duelo
## contra el arquero y se podia errar, y el clip no mostraba ni el gol ni
## el festejo.
func _test_el_gol_es_gol() -> int:
	for intento in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + intento
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		var propio := RandomNumberGenerator.new()
		propio.seed = Laboratorio.SEMILLA
		var r := Laboratorio.generar("gol", casa, visita, propio)
		if int(r["goles_local"]) != 1:
			print("FALLA: el clip del gol termino %d-%d." % [
				int(r["goles_local"]), int(r["goles_visitante"])])
			return 1
		# Y UNA sola vez: reintentar hasta acertar cantaba el gol de mas.
		var goles := 0
		for e in r["eventos"]:
			if str(e.get("tipo", "")) == "tiro_puerta" and str(e.get("resultado", "")) == "gol":
				goles += 1
		if goles != 1:
			print("FALLA: el clip del gol tiene %d eventos de gol." % goles)
			return 1
	print("OK: el clip del gol termina 1-0 y canta el gol una sola vez, las 3 veces.")
	return 0


## Un corner sin nadie en el area se juega para atras: el ejecutor no
## tiene a quien buscar.
func _test_el_corner_tiene_gente_en_el_area() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	var propio := RandomNumberGenerator.new()
	propio.seed = Laboratorio.SEMILLA
	var r := Laboratorio.generar("corner", casa, visita, propio)
	var fg: Array = r["fotogramas"]
	var arco := MotorEspacial.arco_rival(true)
	# Al momento del centro: cuantos atacantes hay adentro del area grande.
	var mejor := 0
	for f in range(fg.size()):
		var n := 0
		for j in fg[f]["jugadores"]:
			if not bool(j["equipo_local"]):
				continue
			if absf(arco.x - float(j["x"])) <= 16.5 and absf(float(j["y"])) <= 20.16:
				n += 1
		mejor = maxi(mejor, n)
	if mejor >= 4:
		print("OK: en el corner llegan a haber %d atacantes adentro del area." % mejor)
		return 0
	print("FALLA: en el corner nunca hay mas de %d atacantes en el area." % mejor)
	return 1
