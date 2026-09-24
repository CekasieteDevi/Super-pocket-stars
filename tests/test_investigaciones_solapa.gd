extends SceneTree

## Mercado › Investigaciones: los conocidos usan la fila del mercado, se
## filtran por puesto, division e informe, y el que ya no esta en la
## piramide no aparece.
##
## Todo en memoria: la partida es nueva y no se guarda nada en disco.

const SEED := 7411

var fallos := 0


func _init() -> void:
	call_deferred("_correr")


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


## Cuantas filas de jugador hay debajo del ultimo encabezado: las filas
## del mercado son PanelContainer y la primera es el encabezado.
func _filas_conocidos(main) -> int:
	var hijos: Array = main.contenedor_investigaciones.get_children()
	var desde := -1
	for i in range(hijos.size()):
		if hijos[i] is Label and str(hijos[i].text).to_lower().begins_with("conocidos"):
			desde = i
	var filas := 0
	for i in range(desde + 1, hijos.size()):
		if hijos[i] is PanelContainer and not hijos[i].is_queued_for_deletion():
			filas += 1
	# El encabezado tambien es un PanelContainer.
	return max(filas - 1, 0)


func _correr() -> void:
	var gs = root.get_node("GameState")
	gs.partida_nueva(SEED)
	var equipo: Team = gs.equipo_jugador

	var d1: Team = gs.piramide.divisiones[0].equipos[0]
	var d2: Team = gs.piramide.divisiones[1].equipos[0]
	if d1 == equipo:
		d1 = gs.piramide.divisiones[0].equipos[1]
	if d2 == equipo:
		d2 = gs.piramide.divisiones[1].equipos[1]
	var arquero := {}
	for j in d1.jugadores:
		if str(j["posicion"]) == "ARQ":
			arquero = j
	var de_d2: Dictionary = d2.jugadores[3]
	var de_reserva: Dictionary = d2.reservas[0] if not d2.reservas.is_empty() else d2.banco[0]
	Investigadores.marcar_conocido(equipo, int(arquero["id"]))
	Investigadores.marcar_conocido(equipo, int(de_d2["id"]))
	Investigadores.marcar_conocido(equipo, int(de_reserva["id"]))
	equipo.conocimiento[int(de_d2["id"])] = 30.0
	# Un id que no es de nadie: un retirado de una partida vieja.
	Investigadores.marcar_conocido(equipo, 987654321)

	var main: Control = load("res://ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._mostrar_seccion("mercado", "mercado")
	main._mostrar_solapa_mercado("investigaciones")
	await process_frame

	_ok(_filas_conocidos(main) == 3,
		"se ven los 3 conocidos que siguen en un club, reserva incluida, y no el retirado (%d)" % _filas_conocidos(main))

	main.filtro_conocidos_posicion = "ARQ"
	main._refrescar_investigaciones()
	await process_frame
	var arqueros := 0
	for j in [arquero, de_d2, de_reserva]:
		if str(j["posicion"]) == "ARQ":
			arqueros += 1
	_ok(_filas_conocidos(main) == arqueros,
		"el filtro de puesto deja solo a los %d arqueros" % arqueros)

	main.filtro_conocidos_posicion = ""
	main.filtro_conocidos_division = 1
	main._refrescar_investigaciones()
	await process_frame
	_ok(_filas_conocidos(main) == 2, "el filtro de division deja a los 2 de D2")

	main.filtro_conocidos_division = -1
	main.filtro_conocidos_pronto = true
	main._refrescar_investigaciones()
	await process_frame
	_ok(_filas_conocidos(main) == 1, "Vence pronto deja solo al de 30 dias")

	Investigadores.olvidar_ausentes(equipo, gs.piramide.ids_presentes())
	_ok(not Investigadores.conoce(equipo, 987654321) and equipo.conocimiento.size() == 3,
		"el cierre olvida al retirado y conserva a los otros 3")

	main.queue_free()
	await process_frame
	print("FALLOS=%d" % fallos)
	quit()
