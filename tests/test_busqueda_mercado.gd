extends SceneTree

## §9.3 rework: el buscador del mercado — filtros, orden y la NIEBLA.

const SEED := 2424


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)
	var mio: Team = piramide.divisiones[7].equipos[0]

	_test_sin_filtros_trae_toda_la_piramide(piramide, mio)
	_test_no_aparezco_yo(piramide, mio)
	_test_los_filtros_acotan(piramide, mio)
	_test_orden_alfabetico(piramide, mio)
	_test_la_niebla_tapa_todo_menos_nombre_y_puesto(piramide, mio)
	_test_investigar_destapa(piramide, mio, rng)
	_test_lo_desconocido_ordena_al_final(piramide, mio)
	_test_las_habilidades_dormidas_no_se_ven()
	quit()


func _fichas(piramide: Piramide, mio: Team, filtros: Dictionary) -> Array:
	var salida := []
	for entrada in BusquedaMercado.buscar(piramide, mio, filtros):
		salida.append(BusquedaMercado.ficha(mio, entrada))
	return salida


func _test_sin_filtros_trae_toda_la_piramide(piramide: Piramide, mio: Team) -> void:
	print("=== Sin filtros trae a todos ===")
	var r := BusquedaMercado.buscar(piramide, mio, BusquedaMercado.filtros_vacios())
	# 200 clubes x 18 de plantel, menos el propio. La cantera arranca vacia.
	if r.size() > 3000:
		print("OK: %d jugadores en la piramide entera." % r.size())
	else:
		print("FALLA: solo %d jugadores." % r.size())


func _test_no_aparezco_yo(piramide: Piramide, mio: Team) -> void:
	print("\n=== Mi propio plantel no aparece en el mercado ===")
	for entrada in BusquedaMercado.buscar(piramide, mio, BusquedaMercado.filtros_vacios()):
		if entrada["equipo"] == mio:
			print("FALLA: aparece un jugador propio.")
			return
	print("OK: ningun jugador propio en los resultados.")


func _test_los_filtros_acotan(piramide: Piramide, mio: Team) -> void:
	print("\n=== Cada filtro acota, y son opcionales ===")
	var base := BusquedaMercado.buscar(piramide, mio, BusquedaMercado.filtros_vacios()).size()

	var f := BusquedaMercado.filtros_vacios()
	f["posicion"] = "ARQ"
	var solo_arqueros := BusquedaMercado.buscar(piramide, mio, f)
	var todos_arqueros := true
	for e in solo_arqueros:
		if str(e["jugador"]["posicion"]) != "ARQ":
			todos_arqueros = false

	f = BusquedaMercado.filtros_vacios()
	f["division"] = 0
	var solo_primera := BusquedaMercado.buscar(piramide, mio, f)
	var todos_primera := true
	for e in solo_primera:
		if int(e["division"]) != 1:
			todos_primera = false

	f = BusquedaMercado.filtros_vacios()
	f["edad_max"] = 21
	var solo_pibes := BusquedaMercado.buscar(piramide, mio, f)
	var todos_pibes := true
	for e in solo_pibes:
		if int(e["jugador"]["edad"]) > 21:
			todos_pibes = false

	if todos_arqueros and todos_primera and todos_pibes \
			and solo_arqueros.size() < base and solo_primera.size() < base and solo_pibes.size() < base:
		print("OK: %d sin filtros -> %d arqueros, %d de primera, %d de 21 o menos." % [
			base, solo_arqueros.size(), solo_primera.size(), solo_pibes.size()])
	else:
		print("FALLA: arqueros=%s primera=%s pibes=%s" % [todos_arqueros, todos_primera, todos_pibes])


func _test_orden_alfabetico(piramide: Piramide, mio: Team) -> void:
	print("\n=== El resultado viene alfabetico ===")
	var f := BusquedaMercado.filtros_vacios()
	f["division"] = 3
	var fichas := _fichas(piramide, mio, f)
	var ordenado := true
	for i in range(1, fichas.size()):
		if str(fichas[i - 1]["nombre"]) > str(fichas[i]["nombre"]):
			ordenado = false
			break
	if ordenado and fichas.size() > 100:
		print("OK: %d fichas en orden alfabetico (de %s a %s)." % [
			fichas.size(), fichas[0]["nombre"], fichas[-1]["nombre"]])
	else:
		print("FALLA: ordenado=%s, %d fichas." % [ordenado, fichas.size()])


func _test_la_niebla_tapa_todo_menos_nombre_y_puesto(piramide: Piramide, mio: Team) -> void:
	print("\n=== Sin informe: solo nombre y puesto ===")
	var f := BusquedaMercado.filtros_vacios()
	f["division"] = 0
	var fichas := _fichas(piramide, mio, f)
	var ficha: Dictionary = fichas[0]
	var tapado: bool = ficha["edad"] == null and ficha["valor"] == null \
		and ficha["salario"] == null and ficha["contrato"] == null and ficha["animo"] == null
	var visible: bool = str(ficha["nombre"]) != "" and str(ficha["posicion"]) != ""
	if tapado and visible and not bool(ficha["conocido"]):
		print("OK: se ve '%s' (%s) y nada mas." % [ficha["nombre"], ficha["posicion"]])
	else:
		print("FALLA: %s" % ficha)


func _test_investigar_destapa(piramide: Piramide, mio: Team, rng: RandomNumberGenerator) -> void:
	print("\n=== Con el informe terminado se ve todo ===")
	var f := BusquedaMercado.filtros_vacios()
	f["division"] = 0
	var entradas := BusquedaMercado.buscar(piramide, mio, f)
	var entrada: Dictionary = entradas[0]
	var id := int(entrada["jugador"]["id"])

	var r := Investigadores.investigar(mio, id, entrada["equipo"].nombre)
	if not r["exito"]:
		print("FALLA: no arranco el informe (%s)." % r["motivo"])
		return
	mio.avanzar_dias(200)

	var ficha := BusquedaMercado.ficha(mio, entrada)
	if bool(ficha["conocido"]) and ficha["edad"] != null and ficha["valor"] != null \
			and ficha["salario"] != null and ficha["contrato"] != null and ficha["animo"] != null:
		print("OK: %s, %d anios, vale %s, cobra %s, contrato %d, animo %d." % [
			ficha["nombre"], int(ficha["edad"]), Economia.formato_dinero(ficha["valor"]),
			Economia.formato_dinero(ficha["salario"]), int(ficha["contrato"]), int(ficha["animo"])])
	else:
		print("FALLA: %s" % ficha)


func _test_lo_desconocido_ordena_al_final(piramide: Piramide, mio: Team) -> void:
	print("\n=== Ordenar por una columna tapada no llena la pantalla de '?' ===")
	var f := BusquedaMercado.filtros_vacios()
	f["division"] = 0
	var fichas := BusquedaMercado.ordenar(_fichas(piramide, mio, f), "valor", false)
	if fichas.is_empty():
		print("FALLA: sin fichas.")
		return
	# El unico investigado del test anterior tiene que quedar primero.
	var primero_conocido: bool = fichas[0]["valor"] != null
	var ultimo_tapado: bool = fichas[-1]["valor"] == null
	if primero_conocido and ultimo_tapado:
		print("OK: los conocidos van primero y los tapados al final, ordene como ordene.")
	else:
		print("FALLA: primero=%s ultimo=%s" % [fichas[0]["valor"], fichas[-1]["valor"]])


func _test_las_habilidades_dormidas_no_se_ven() -> void:
	print("\n=== Una habilidad dormida no se le ve a un jugador ajeno ===")
	# Encontrartela despues de comprarlo es la sorpresa que hace que valga
	# la pena arriesgarse con un juvenil; verla de antemano la mataria.
	var nivel := 2
	var dormido := {"media": Habilidades.MEDIA_MINIMA[nivel] - 10.0,
		"habilidad": {"nombre": "Cabeceador", "nivel": nivel}}
	var despierto := {"media": Habilidades.MEDIA_MINIMA[nivel] + 10.0,
		"habilidad": {"nombre": "Cabeceador", "nivel": nivel}}

	var ajeno_dormido := BusquedaMercado.habilidad_visible(dormido, true)
	var ajeno_despierto := BusquedaMercado.habilidad_visible(despierto, true)
	var propio_dormido := BusquedaMercado.habilidad_visible(dormido, false)

	if ajeno_dormido.is_empty() and not ajeno_despierto.is_empty() and not propio_dormido.is_empty():
		print("OK: dormida invisible en un ajeno, visible en el propio, y la manifestada se ve siempre.")
	else:
		print("FALLA: ajeno dormido=%s, ajeno despierto=%s, propio dormido=%s" % [
			ajeno_dormido, ajeno_despierto, propio_dormido])
