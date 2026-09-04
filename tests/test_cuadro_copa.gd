extends SceneTree

## El armado del cuadro de una copa: que cada cruce quede debajo de los dos
## de los que sale (que es lo que hace que el cuadro se pueda dibujar sin
## lineas cruzadas), que los titulos digan la ronda que es de verdad y que
## el camino del club propio se lea bien.

const SEED := 8123


func _init() -> void:
	var fallas := 0
	fallas += _test_alineacion()
	fallas += _test_titulos()
	fallas += _test_camino()
	fallas += _test_copa_real()
	fallas += _test_cuadro_fijo()
	print("FALLOS=%d" % fallas)
	quit()


func _cruce(local: String, visitante: String, gl: int, gv: int) -> Dictionary:
	return {
		"local": local, "visitante": visitante, "gl": gl, "gv": gv,
		"ganador": local if gl > gv else visitante,
		"definicion": "90 minutos", "penales_texto": "",
	}


## Un cuadro de 8 equipos con el orden de cada ronda DESORDENADO a
## proposito. Hoy Copa ya no sortea de nuevo en cada ronda, asi que las
## rondas vienen en el orden del cuadro; las partidas guardadas de antes
## de ese cambio, no. El armado tiene que dar el cuadro correcto igual,
## venga en el orden que venga.
##
## Lo que se prueba es el invariante que hace dibujable el cuadro: los dos
## equipos del cruce i de una columna tienen que salir de las celdas 2i y
## 2i+1 de la columna anterior. Si eso se cumple, cada cruce queda
## centrado entre los dos de los que sale y ninguna linea se cruza.
func _test_alineacion() -> int:
	var r1 := [_cruce("A", "B", 1, 0), _cruce("C", "D", 0, 1),
		_cruce("E", "F", 2, 0), _cruce("G", "H", 0, 3)]
	# La segunda ronda sale sorteada: H contra A y D contra E.
	var r2 := [_cruce("H", "A", 0, 1), _cruce("D", "E", 2, 1)]
	var r3 := [_cruce("D", "A", 0, 1)]
	var cuadro := CuadroCopa.armar([r1, r2, r3], [], [], "A")
	var fallas := _verificar_alineacion(cuadro["columnas"])
	if fallas == 0:
		print("OK: el cuadro se reconstruye bien aunque las rondas vengan guardadas en cualquier orden.")
	return fallas


## Para cada columna, el cruce i de la siguiente tiene que estar formado
## por los ganadores de las celdas 2i y 2i+1 de esta.
func _verificar_alineacion(columnas: Array) -> int:
	var fallas := 0
	for c in range(columnas.size() - 1):
		var aca: Array = columnas[c]["cruces"]
		var alla: Array = columnas[c + 1]["cruces"]
		for i in range(alla.size()):
			var arriba: Dictionary = alla[i]
			for k in range(2):
				var idx := i * 2 + k
				if idx >= aca.size():
					print("FALLA: la columna %d no tiene celda %d para el cruce %d de la siguiente." % [
						c, idx, i])
					fallas += 1
					continue
				var celda: Dictionary = aca[idx]
				var viene_de := str(celda.get("equipo", ""))
				if not celda.has("bye"):
					viene_de = str(celda.get("ganador", ""))
				var esperado := str(arriba["local"]) if k == 0 else str(arriba["visitante"])
				if viene_de != esperado:
					print("FALLA: %s del cruce %s-%s no sale de la celda de abajo (ahi esta %s)." % [
						esperado, arriba["local"], arriba["visitante"], viene_de])
					fallas += 1
	return fallas


## Con 20 equipos la primera ronda son 4 cruces y 12 que pasan sin jugar:
## no es "cuartos de final" por tener 4 cruces, es una ronda previa.
func _test_titulos() -> int:
	var fallas := 0
	var previa := [_cruce("A", "B", 1, 0), _cruce("C", "D", 1, 0),
		_cruce("E", "F", 1, 0), _cruce("G", "H", 1, 0)]
	var bye := []
	for i in range(12):
		bye.append("Bye%d" % i)
	var cuadro := CuadroCopa.armar([], previa_a_pendientes(previa), bye, "")
	var titulo := str(cuadro["columnas"][0]["titulo"])
	if titulo == "Ronda previa":
		print("OK: 4 cruces con 12 que esperan se llama ronda previa, no cuartos.")
	else:
		print("FALLA: con 20 equipos la primera ronda se llamo \"%s\"." % titulo)
		fallas += 1

	# Un cuadro completo de 16: octavos, cuartos, semis y final.
	var equipos := []
	for i in range(16):
		equipos.append("E%d" % i)
	var rondas := []
	var vivos := equipos
	while vivos.size() > 1:
		var ronda := []
		var siguientes := []
		for i in range(0, vivos.size(), 2):
			ronda.append(_cruce(vivos[i], vivos[i + 1], 1, 0))
			siguientes.append(vivos[i])
		rondas.append(ronda)
		vivos = siguientes
	var completo := CuadroCopa.armar(rondas, [], [], vivos[0])
	var titulos := []
	for col in completo["columnas"]:
		titulos.append(str(col["titulo"]))
	if titulos == ["Octavos de final", "Cuartos de final", "Semifinales", "Final"]:
		print("OK: un cuadro de 16 se titula octavos / cuartos / semis / final.")
	else:
		print("FALLA: los titulos dieron %s." % [titulos])
		fallas += 1
	return fallas


func previa_a_pendientes(ronda: Array) -> Array:
	var salida := []
	for c in ronda:
		salida.append([str(c["local"]), str(c["visitante"])])
	return salida


func _test_camino() -> int:
	var fallas := 0
	var r1 := [_cruce("A", "B", 1, 0), _cruce("C", "D", 0, 1)]
	var r2 := [_cruce("A", "D", 0, 2)]

	var casos := {
		"D": "Campeón",
		"B": "Eliminado",
		"A": "Eliminado",
		"Z": "No clasificaste",
	}
	for club in casos:
		var texto := CuadroCopa.camino_de([r1, r2], [], [], "D", club)
		if not texto.begins_with(str(casos[club])):
			print("FALLA: el camino de %s dio \"%s\" y tenia que empezar con \"%s\"." % [
				club, texto, casos[club]])
			fallas += 1
	if fallas == 0:
		print("OK: campeón, eliminado y el que no jugó se leen distinto.")

	var proxima := CuadroCopa.camino_de([r1], [["A", "D"]], [], "", "A")
	if proxima.contains("contra D"):
		print("OK: con la ronda por jugarse dice contra quién te toca.")
	else:
		print("FALLA: el camino con ronda pendiente dio \"%s\"." % proxima)
		fallas += 1
	return fallas


## Una copa de verdad, jugada con el motor: 20 clubes, como la copa de
## division. Lo que se prueba es que el cuadro que sale de ella sea
## consistente — cada columna con el doble de celdas que la siguiente.
func _test_copa_real() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var equipos := []
	for i in range(20):
		equipos.append(Team.generar("Club %d" % i, rng, i * 40))
	var copa := Copa.iniciar("Prueba", equipos, rng)
	while copa.campeon == null:
		copa.jugar_siguiente_ronda(rng)

	var cuadro := CuadroCopa.desde_copa(copa)
	var columnas: Array = cuadro["columnas"]
	var fallas := 0
	if columnas.is_empty():
		print("FALLA: el cuadro de una copa jugada salio vacio.")
		return 1
	for c in range(columnas.size() - 1):
		var aca: int = columnas[c]["cruces"].size()
		var alla: int = columnas[c + 1]["cruces"].size()
		if aca != alla * 2:
			print("FALLA: la columna %d tiene %d celdas y la siguiente %d (tenía que ser el doble)." % [
				c, aca, alla])
			fallas += 1
	fallas += _verificar_alineacion(columnas)
	if fallas == 0:
		print("OK: en una copa de 20 clubes jugada entera el cuadro cierra y esta alineado (%s)." % [
			_tamanos(columnas)])
	if str(cuadro["campeon"]) == copa.campeon.nombre:
		print("OK: el campeón del cuadro es el campeón de la copa (%s)." % cuadro["campeon"])
	else:
		print("FALLA: el campeón del cuadro no coincide con el de la copa.")
		fallas += 1
	return fallas


func _tamanos(columnas: Array) -> Array:
	var out := []
	for c in columnas:
		out.append(c["cruces"].size())
	return out


## El cuadro es FIJO: se sortea una sola vez y despues cada ganador se
## enfrenta al ganador del cruce de al lado. Antes se volvia a sortear
## despues de cada ronda, asi que no habia cuadro: cada ronda era un
## sorteo nuevo entre los que quedaban.
func _test_cuadro_fijo() -> int:
	var fallas := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	# Con 8 equipos no hay byes: el cuadro es perfecto desde la primera.
	var equipos := []
	for i in range(8):
		equipos.append(Team.generar("Club %d" % i, rng, i * 40))
	var copa := Copa.iniciar("Prueba", equipos, rng)
	while copa.campeon == null:
		var ronda := copa.jugar_siguiente_ronda(rng)
		if copa.partidos_pendientes.is_empty():
			break
		for i in range(copa.partidos_pendientes.size()):
			var par: Array = copa.partidos_pendientes[i]
			var esperado_a := str(ronda[i * 2]["ganador"])
			var esperado_b := str(ronda[i * 2 + 1]["ganador"])
			if par[0].nombre != esperado_a or par[1].nombre != esperado_b:
				print("FALLA: el cruce %d de la ronda siguiente es %s vs %s y tenia que ser %s vs %s." % [
					i, par[0].nombre, par[1].nombre, esperado_a, esperado_b])
				fallas += 1
	if fallas == 0:
		print("OK: cada cruce lo juegan los ganadores de los dos cruces de al lado, sin sorteo nuevo.")

	# Con 20 equipos hay ronda previa: al que paso sin jugar le toca
	# despues uno que SI jugo, no otro que tambien paso.
	rng.seed = SEED + 1
	var veinte := []
	for i in range(20):
		veinte.append(Team.generar("Veinte %d" % i, rng, 2000 + i * 40))
	var copa20 := Copa.iniciar("Prueba 20", veinte, rng)
	var con_bye := []
	for e in copa20.equipos_con_bye:
		con_bye.append(e.nombre)
	var previa := copa20.jugar_siguiente_ronda(rng)
	var ganadores := []
	for p in previa:
		ganadores.append(str(p["ganador"]))
	var mezclados := 0
	for i in range(mini(ganadores.size(), copa20.partidos_pendientes.size())):
		var par: Array = copa20.partidos_pendientes[i]
		var nombres := [par[0].nombre, par[1].nombre]
		var tiene_bye: bool = con_bye.has(nombres[0]) or con_bye.has(nombres[1])
		var tiene_ganador: bool = ganadores.has(nombres[0]) or ganadores.has(nombres[1])
		if tiene_bye and tiene_ganador:
			mezclados += 1
	if mezclados == ganadores.size():
		print("OK: los %d que ganaron la ronda previa se cruzan con equipos que pasaron sin jugar." % [
			ganadores.size()])
	else:
		print("FALLA: solo %d de %d cruces mezclan a un ganador de la previa con uno que paso sin jugar." % [
			mezclados, ganadores.size()])
		fallas += 1
	return fallas
