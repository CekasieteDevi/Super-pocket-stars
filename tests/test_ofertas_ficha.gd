extends SceneTree

## Una oferta recibida dice si es compra o préstamo, qué lugar ocupa el
## jugador en el plantel (titular, suplente o reserva) y tiene un botón
## "Ficha" que lleva a la ficha y vuelve a la misma oferta.
##
## Todo en memoria: la partida es nueva y no se guarda nada en disco.

const SEED := 7310

var fallos := 0


func _init() -> void:
	call_deferred("_correr")


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


func _correr() -> void:
	var gs = root.get_node("GameState")
	gs.partida_nueva(SEED)
	var equipo: Team = gs.equipo_jugador
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var comprador: Team = gs.piramide.divisiones[gs.division_jugador].equipos[1]
	if comprador == equipo:
		comprador = gs.piramide.divisiones[gs.division_jugador].equipos[2]

	var titular: Dictionary = equipo.jugadores[5]
	var suplente: Dictionary = equipo.banco[0]
	var compra := Ofertas.nueva(9001, comprador.nombre, titular, 1000000.0, true, rng)
	var prestamo := Ofertas.nueva(9002, comprador.nombre, suplente, 50000.0, true, rng)
	prestamo["tipo"] = "cesion"
	prestamo["duracion"] = "una"
	prestamo["porcentaje_sueldo"] = 0.5
	prestamo["opcion_compra"] = 0.0
	equipo.ofertas.append(compra)
	equipo.ofertas.append(prestamo)

	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._mostrar_seccion("mercado", "mercado")
	main._mostrar_solapa_mercado("recibidas")
	await process_frame

	var filas := {}
	for fila in main.contenedor_recibidas.get_children():
		var texto := ""
		var botones := []
		for hijo in fila.get_children():
			if hijo is Label:
				texto = hijo.text
			elif hijo is Button:
				botones.append(hijo.text)
		filas[texto] = botones
	var fila_compra := ""
	var fila_prestamo := ""
	for texto in filas:
		if str(titular["apellido"]) in texto:
			fila_compra = texto
		if str(suplente["apellido"]) in texto:
			fila_prestamo = texto
	_ok(fila_compra.begins_with("COMPRA"), "la compra se anuncia como compra: " + fila_compra)
	_ok(fila_prestamo.begins_with("PRÉSTAMO"), "el préstamo se anuncia como préstamo: " + fila_prestamo)
	_ok("titular" in fila_compra, "la fila dice que es titular")
	_ok("suplente" in fila_prestamo, "la fila dice que es suplente")
	_ok(filas.get(fila_compra, []).has("Ficha"), "la fila tiene el botón Ficha")

	main._abrir_oferta(9001)
	_ok(main.label_negociacion_sub.text.begins_with("COMPRA  ·  titular"),
		"el modal de compra dice tipo y lugar: " + main.label_negociacion_sub.text)
	_ok(main.boton_negociacion_ficha.visible, "el modal de compra tiene el botón Ficha")
	main.boton_negociacion_ficha.pressed.emit()
	_ok(main.paneles["ficha"].visible, "Ficha abre la ficha del jugador")
	_ok(main.ficha_jugador_id == int(titular["id"]), "la ficha es la del jugador de la oferta")
	_ok(not main.dialogo_negociacion.visible, "el modal se cierra para ver la ficha")
	_ok(main.boton_volver_ficha.text == "< Volver a la oferta", "el botón de volver lleva a la oferta")
	main._volver_desde_ficha()
	_ok(main.dialogo_negociacion.visible and main.negociacion_oferta_id == 9001,
		"al volver se reabre la misma oferta")
	main.dialogo_negociacion.hide()

	main._abrir_oferta(9002)
	_ok(main.label_cesion_sub.text.begins_with("PRÉSTAMO  ·  suplente"),
		"el modal de préstamo dice tipo y lugar: " + main.label_cesion_sub.text)
	main.boton_cesion_ficha.pressed.emit()
	_ok(main.ficha_jugador_id == int(suplente["id"]), "Ficha del préstamo abre al suplente")
	main._volver_desde_ficha()
	_ok(main.dialogo_cesion.visible, "al volver se reabre el préstamo")

	print("FALLOS=%d" % fallos)
	quit()
