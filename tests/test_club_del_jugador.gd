extends SceneTree

## El club del jugador se elige al empezar: nombre y colores. Renombrar un
## club NO es cambiarle un campo — el nombre es la clave de la tabla de
## posiciones y viaja como texto a los clasicos y a la procedencia de cada
## jugador.

const SEED := 5150


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_test_renombrar_arregla_todo(rng)
	_test_no_deja_nombres_repetidos(rng)
	_test_los_colores_elegidos_mandan(rng)
	_test_los_colores_sobreviven_un_guardado(rng)
	_test_el_visitante_se_corre_si_se_parecen(rng)

	quit()


func _test_renombrar_arregla_todo(rng: RandomNumberGenerator) -> void:
	print("=== Renombrar mueve la fila de la tabla, los clasicos y la procedencia ===")
	var p := Piramide.generar(rng)
	var liga: Liga = p.divisiones[9]
	var mio: Team = liga.equipos[0]
	var viejo := mio.nombre
	var tenia_clasico := mio.rival_directo != ""

	if not p.renombrar(mio, "Deportivo Prueba"):
		print("FALLA: no dejo renombrar a un nombre libre.")
		return
	if mio.nombre != "Deportivo Prueba":
		print("FALLA: el club sigue llamandose %s." % mio.nombre)
		return
	if liga.tabla.has(viejo):
		print("FALLA: quedo la fila vieja en la tabla.")
		return
	if not liga.tabla.has("Deportivo Prueba"):
		print("FALLA: no quedo la fila nueva en la tabla.")
		return
	if liga.tabla.size() != liga.equipos.size():
		print("FALLA: la tabla tiene %d filas para %d equipos." % [
			liga.tabla.size(), liga.equipos.size()])
		return
	for otro in liga.equipos:
		if otro.rival_directo == viejo:
			print("FALLA: %s todavia cree que su clasico se llama %s." % [otro.nombre, viejo])
			return
	for j in mio.todos_los_jugadores():
		if str(j.get("club_actual", "")) == viejo:
			print("FALLA: un jugador todavia figura como del club viejo.")
			return
	# Y el clasico tiene que seguir existiendo, no desaparecer.
	if tenia_clasico and mio.rival_directo == "":
		print("FALLA: se perdio el clasico al renombrar.")
		return
	print("OK: %s -> %s, con la tabla, el clasico y los %d jugadores al dia." % [
		viejo, mio.nombre, mio.todos_los_jugadores().size()])


func _test_no_deja_nombres_repetidos(rng: RandomNumberGenerator) -> void:
	print("\n=== No se puede usar un nombre que ya existe ===")
	var p := Piramide.generar(rng)
	var mio: Team = p.divisiones[9].equipos[0]
	var ajeno: String = p.divisiones[0].equipos[3].nombre

	if p.renombrar(mio, ajeno):
		print("FALLA: dejo ponerle el nombre de otro club.")
		return
	if p.renombrar(mio, "   "):
		print("FALLA: dejo ponerle un nombre vacio.")
		return
	if not p.existe_nombre(ajeno):
		print("FALLA: existe_nombre no encuentra un club que existe.")
		return
	print("OK: rechaza '%s' porque ya esta tomado, y rechaza el vacio." % ajeno)


func _test_los_colores_elegidos_mandan(rng: RandomNumberGenerator) -> void:
	print("\n=== Si el club eligio color, ese manda; si no, sale del nombre ===")
	var elegido := Team.generar("ConColor", rng, 0)
	var derivado := Team.generar("SinColor", rng, 400)
	elegido.color_camiseta = Color(0.11, 0.22, 0.33)

	if ColoresClub.de_equipo(elegido) != elegido.color_camiseta:
		print("FALLA: no respeto el color elegido.")
		return
	if ColoresClub.de_equipo(derivado) != ColoresClub.de(derivado.nombre):
		print("FALLA: el que no eligio tendria que salir de su nombre.")
		return
	print("OK: el que eligio usa el suyo, el que no usa el de su nombre.")


func _test_los_colores_sobreviven_un_guardado(rng: RandomNumberGenerator) -> void:
	print("\n=== Los colores sobreviven guardar y cargar ===")
	var e := Team.generar("Guardado", rng, 0)
	e.color_camiseta = ColoresClub.PALETA[4]
	e.color_short = ColoresClub.PALETA[8]
	var vuelto := Team.cargar(e.guardar())
	# Se comparan en hexadecimal y no con is_equal_approx: el guardado es
	# JSON, el color viaja como "#rrggbb" y eso cuantiza a 8 bits por
	# canal. La diferencia es de menos de 1/255 y no se ve, pero rompe una
	# comparacion de floats.
	if vuelto.color_camiseta.to_html(false) != e.color_camiseta.to_html(false):
		print("FALLA: la camiseta volvio como %s en vez de %s." % [
			vuelto.color_camiseta.to_html(false), e.color_camiseta.to_html(false)])
		return
	if vuelto.color_short.to_html(false) != e.color_short.to_html(false):
		print("FALLA: el pantalon volvio como %s en vez de %s." % [
			vuelto.color_short.to_html(false), e.color_short.to_html(false)])
		return

	# Y una partida vieja, sin el campo, no tiene que romper: vuelve a
	# derivar del nombre.
	var datos := e.guardar()
	datos.erase("color_camiseta")
	datos.erase("color_short")
	var viejo := Team.cargar(datos)
	if viejo.color_camiseta.a > 0.0:
		print("FALLA: una partida vieja tendria que quedar sin color elegido.")
		return
	print("OK: %s y %s vuelven enteros, y una partida vieja queda sin elegir." % [
		e.color_camiseta.to_html(false), e.color_short.to_html(false)])


func _test_el_visitante_se_corre_si_se_parecen(rng: RandomNumberGenerator) -> void:
	print("\n=== Dos clubes del mismo color no juegan iguales ===")
	var local := Team.generar("Local", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	local.color_camiseta = ColoresClub.PALETA[0]
	visita.color_camiseta = ColoresClub.PALETA[0]

	var par := ColoresClub.par_equipos(local, visita)
	if par[0] != local.color_camiseta:
		print("FALLA: al local le cambiaron la camiseta; tendria que jugar con la suya.")
		return
	if par[0] == par[1]:
		print("FALLA: los dos quedaron del mismo color.")
		return
	print("OK: el local mantiene %s y al visitante se le corre a %s." % [
		Color(par[0]).to_html(false), Color(par[1]).to_html(false)])
