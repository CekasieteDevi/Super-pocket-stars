extends SceneTree

## Etapa 6 del Motor V2 (docs/motor_v2.md): reglas y pelota parada, sin pantalla.
## - Los números de fábrica del C++ (reglas.h) son los de FisicaV2.parametros_reglas().
## - "Pasa si": partidos de 90 minutos completos sin intervención, con dos
##   tiempos y todas las reanudaciones (saque del medio, lateral, saque de
##   arco, córner, tiro libre). Cada parada se ejecuta. Nadie camina hasta la
##   línea para sacar un lateral (lo que la vista 3D actual corta) y nadie
##   aparece encima de la pelota.
## - Etapa 7: el partido dura de verdad 2 minutos por tiempo y el reloj
##   muestra 0-90. Para que aparezca todo se juegan 40 partidos.
## - Sin correcciones de la pelota, sin SALTO_PELOTA y sin teletransportes de
##   jugador (más de 0,5 m entre pasos, docs/motor_v2.md "Definición de hecho").
## - Hay faltas que salen del contacto, tarjetas, offside cobrado, cambios y
##   penales; el expulsado deja al equipo con diez.
## - La tanda termina con un ganador.
## - Misma semilla = mismo partido.

const SEED := 20261010
## Cuarenta partidos del juego (4 minutos de verdad cada uno): con pocos, el
## penal puede no aparecer (0,1 por partido, tests/_diag_calibracion_v2.gd).
const PARTIDOS := 40
## Lo que tiene que haber sumando todos (unas 2,3 faltas, 1,1 amarillas y 0,15
## offside por partido en la medición).
## Lo más que puede marcar el reloj: 90, más 5 de adición, más los 22,5 s de
## verdad que puede seguir un tiempo con la jugada sin cerrar (8,4 minutos).
const MINUTO_MAX := 104.0
const FALTAS_MIN := 50
const AMARILLAS_MIN := 20
## Más que esto entre dos pasos es un teletransporte.
const SALTO_MAX_M := 0.5
## BUG-017: el que se va cruza la raya a menos de esto del medio de la banda
## de la cámara (con cinco saliendo juntos, el último va a 5 m del medio).
const SALIDA_DEL_MEDIO_M := 10.0
## Y el cambiado o el lesionado llega a correr a esto (reglas.salir_lesionado_ms
## es 7,5; cuando salían a 0,7 de su punta cansada no pasaban de 5 m/s).
const SALIDA_MS := 7.0

var fallos := 0


func _init() -> void:
	if not ClassDB.class_exists("CanchitaV2Nativa"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_numeros_como_el_json()
	_partidos()
	_expulsiones()
	_tanda()
	_huellas()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _numeros_como_el_json() -> void:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	var fabrica: Dictionary = c.reglas_de_fabrica()
	var json := FisicaV2.parametros_reglas()
	var distintos := []
	for clave in fabrica:
		var valor = fabrica[clave]
		var del_json = json.get(clave, null)
		if valor is Dictionary or valor is Array:
			var lista_c: Array = valor.values() if valor is Dictionary else valor
			var lista_j: Array = []
			if del_json is Dictionary:
				for k in valor:
					lista_j.append(del_json.get(k, NAN))
			elif del_json is Array:
				lista_j = del_json
			for k in lista_c.size():
				if k >= lista_j.size() or absf(float(lista_j[k]) - float(lista_c[k])) > 1e-9:
					distintos.append("%s[%d]" % [clave, k])
		elif del_json == null or absf(float(del_json) - float(valor)) > 1e-9:
			distintos.append("%s: C++ %s, JSON %s" % [clave, valor, del_json])
	for clave in json:
		var s := str(clave)
		if not s.begins_with("clip_") and s != "tanda" and s != "alargue" and not fabrica.has(clave):
			distintos.append("%s del JSON no lo lee el C++" % s)
	_ok(distintos.is_empty(), "reglas.h tiene los mismos valores que FisicaV2.parametros_reglas() %s" % [distintos])


func _partidos() -> void:
	var suma := {}
	for n in PARTIDOS:
		var semilla := SEED + n
		var c: Object = CerebroV2.armar_partido(semilla, "", "", -1, -1, true)
		var cantidad_inicial: int = c.cantidad()
		var pasos := _hasta_el_final(c, 60 * 60 * 15)
		var k: Dictionary = c.contadores()
		var e: Dictionary = c.get_estado()
		var minutos := pasos / 3600.0
		var eventos: Array = c.eventos()
		var fines := eventos.filter(func(v): return v["tipo"] == "fin_tiempo").size()
		# Dos minutos de verdad por tiempo, más lo que esperan las paradas: el
		# reloj corre solo con la pelota en juego. Un saque que no sale deja el
		# partido colgado (pasaba en el saque inicial, 5 de 60 partidos).
		var fuera := eventos.filter(func(v): return float(v["minuto"]) < 0.0 or float(v["minuto"]) > MINUTO_MAX).size()
		_ok(e["periodo"] == "terminado" and fines == 2 and minutos >= 4.0 and minutos <= 8.0
				and float(e["minuto"]) >= 90.0 and fuera == 0,
			"semilla %d: termina solo, con dos tiempos, en %.1f min de verdad y con el reloj en %.0f' (%d fines)" % [
				semilla, minutos, e["minuto"], fines])
		# Cada parada se ejecutó. La que estaba armada al final de cada tiempo no
		# cuenta: pueden ser dos del mismo tipo (semilla 20261021: los dos
		# tiempos terminan con la pelota saliendo por el fondo).
		var sin_sacar := []
		for t in ["saque_medio", "lateral", "saque_arco", "corner", "tiro_libre", "penal"]:
			var resto: int = int(k["paradas_" + t]) - int(k["saques_" + t])
			if resto < 0 or resto > 2:
				sin_sacar.append("%s %d/%d" % [t, k["saques_" + t], k["paradas_" + t]])
		_ok(sin_sacar.is_empty(), "semilla %d: cada reanudación se sacó %s" % [semilla, sin_sacar])
		_ok(int(k["camina_lateral"]) == 0 and int(k["saques_de_lejos"]) == 0,
			"semilla %d: nadie camina hasta la línea del lateral (%d pasos) ni saca lejos de la pelota (%d)" % [
				semilla, k["camina_lateral"], k["saques_de_lejos"]])
		_ok(int(k["correcciones"]) == 0 and int(k["saltos_pelota"]) == 0 and float(k["peor_salto_cuerpo_m"]) < SALTO_MAX_M,
			"semilla %d: sin correcciones (%d), SALTO_PELOTA = 0 (%d) y sin teletransportes (peor %.2f m)" % [
				semilla, k["correcciones"], k["saltos_pelota"], k["peor_salto_cuerpo_m"]])
		var rojas: int = int(k["rojas_0"]) + int(k["rojas_1"])
		# El lesionado sin nadie para entrar también sale.
		var menos: int = cantidad_inicial - c.cantidad()
		_ok(menos >= rojas and menos <= rojas + int(k["lesiones"]),
			"semilla %d: los expulsados dejan al equipo con uno menos (%d en cancha, %d rojas)" % [
				semilla, c.cantidad(), rojas])
		_ok(c.get_ids().size() == c.cantidad() and not c.get_ids().has(-1),
			"semilla %d: cada uno en cancha tiene su id de jugador" % semilla)
		for clave in ["paradas_saque_medio", "paradas_lateral", "paradas_saque_arco", "paradas_corner",
				"paradas_tiro_libre", "paradas_penal", "faltas_0", "faltas_1", "amarillas_0", "amarillas_1",
				"rojas_0", "rojas_1", "offsides_cobrados_0", "offsides_cobrados_1", "cambios_0", "cambios_1",
				"penales", "lesiones", "entradas_limpias", "faltas_entrada"]:
			suma[clave] = int(suma.get(clave, 0)) + int(k[clave])
		print("   semilla %d: %d-%d · faltas %d-%d · amarillas %d · rojas %d · offside %d · cambios %d · penales %d · lateral máx %.1f s" % [
			semilla, k["goles_0"], k["goles_1"], k["faltas_0"], k["faltas_1"], int(k["amarillas_0"]) + int(k["amarillas_1"]),
			rojas, int(k["offsides_cobrados_0"]) + int(k["offsides_cobrados_1"]), int(k["cambios_0"]) + int(k["cambios_1"]),
			k["penales"], k["espera_max_lateral"]])
	var faltan := []
	for t in ["saque_medio", "lateral", "saque_arco", "corner", "tiro_libre", "penal"]:
		if int(suma["paradas_" + t]) == 0:
			faltan.append(t)
	_ok(faltan.is_empty(), "en %d partidos aparecen todas las reanudaciones %s" % [PARTIDOS, faltan])
	var faltas: int = suma["faltas_0"] + suma["faltas_1"]
	_ok(faltas >= FALTAS_MIN and int(suma["faltas_entrada"]) > 0 and int(suma["entradas_limpias"]) > 0,
		"las entradas sacan la pelota (%d) o hacen falta (%d de %d faltas)" % [suma["entradas_limpias"],
			suma["faltas_entrada"], faltas])
	_ok(int(suma["amarillas_0"]) + int(suma["amarillas_1"]) >= AMARILLAS_MIN,
		"hay tarjetas (%d amarillas, %d rojas)" % [int(suma["amarillas_0"]) + int(suma["amarillas_1"]),
			int(suma["rojas_0"]) + int(suma["rojas_1"])])
	_ok(int(suma["offsides_cobrados_0"]) + int(suma["offsides_cobrados_1"]) > 0,
		"se cobra el offside (%d)" % (int(suma["offsides_cobrados_0"]) + int(suma["offsides_cobrados_1"])))
	_ok(int(suma["cambios_0"]) + int(suma["cambios_1"]) > 0 and int(suma["cambios_0"]) <= 5 * PARTIDOS
			and int(suma["cambios_1"]) <= 5 * PARTIDOS,
		"hay cambios, cinco por equipo como mucho (%d y %d)" % [suma["cambios_0"], suma["cambios_1"]])


## Con dos rojas y una lesión a propósito (CanchitaV2Nativa.forzar_falta, la
## misma falta del partido con la tarjeta elegida): el que se va sale de la
## cancha, el saque lo espera, los índices de los que siguen se reacomodan y
## el partido termina igual. Antes subía roja_por_falta y esperaba que
## salieran solas: daba de 0 a 8 rojas según la semilla.
func _expulsiones() -> void:
	var c := _corto(SEED + 50, 20.0, false)
	var inicial: int = c.cantidad()
	# Minuto en que se pide cada una: [minuto, tarjeta, lesión]. Sale en el
	# primer cruce que haya desde ahí.
	var pedidas := [[2.0, 2, false], [6.0, 2, false], [10.0, 0, true]]
	var salidas := 0
	var pasos := 0
	var en_cancha_ok := true
	var sin_esperar := 0
	var por_otro_lado := 0
	# Los que se van y ya pisaron la cancha: al que cobran afuera (el que iba a
	# sacar un lateral) no se le cuenta la banda donde estaba.
	var adentro := {}
	var rapidez_salida := 0.0
	var medio_ancho := ProyeccionPartido.MEDIO_ANCHO
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 150:
		c.avanzar()
		pasos += 1
		if not pedidas.is_empty() and pasos >= float(pedidas[0][0]) * 3600.0 				and c.forzar_falta(int(pedidas[0][1]), bool(pedidas[0][2])):
			pedidas.pop_front()
		if pasos % 30 != 0:
			continue
		var afuera: Array = c.get_afuera()
		salidas = maxi(salidas, afuera.size())
		# La banda de la cámara: +z en el primer tiempo, -z en el segundo.
		var banda := 1.0 if int(c.get_estado()["lado"]) == 0 else -1.0
		for a in afuera:
			var p: Vector2 = a["pos"]
			if absf(p.y) < medio_ancho:
				adentro[a["id"]] = true
			elif adentro.has(a["id"]) and (p.y * banda < 0.0 or absf(p.x) > SALIDA_DEL_MEDIO_M):
				por_otro_lado += 1
			if not bool(a["expulsado"]):
				rapidez_salida = maxf(rapidez_salida, float(a["rapidez"]))
		if str(c.get_estado()["parada"]) == "nada":
			for a in afuera:
				if absf((a["pos"] as Vector2).y) < medio_ancho - 0.5:
					sin_esperar += 1
		var vistos := {}
		for id in c.get_ids():
			if vistos.has(id) or id < 0:
				en_cancha_ok = false
			vistos[id] = true
	var k: Dictionary = c.contadores()
	var rojas: int = int(k["rojas_0"]) + int(k["rojas_1"])
	var menos: int = inicial - c.cantidad()
	_ok(pedidas.is_empty() and str(c.get_estado()["periodo"]) == "terminado" and rojas >= 2 and int(k["lesiones"]) >= 1
			and menos >= rojas and menos <= rojas + int(k["lesiones"]) and en_cancha_ok,
		"con %d rojas y %d lesiones el partido termina, con %d en cancha y sin ids repetidos (faltan pedir %d, %s, ids %s, %.0f min)" % [
			rojas, k["lesiones"], c.cantidad(), pedidas.size(), c.get_estado()["periodo"], en_cancha_ok, pasos / 3600.0])
	_ok(salidas > 0 and int(k["correcciones"]) == 0 and float(k["peor_salto_cuerpo_m"]) < SALTO_MAX_M,
		"los que se van salen por sus medios (hasta %d a la vez) y nadie salta (peor %.2f m)" % [salidas,
			k["peor_salto_cuerpo_m"]])
	_ok(sin_esperar == 0, "el saque espera a que el que se va salga de la cancha (%d veces no)" % sin_esperar)
	_ok(por_otro_lado == 0 and rapidez_salida >= SALIDA_MS,
		"los que se van salen por el medio de la banda de la cámara (%d por otro lado) y corriendo (%.1f m/s)" % [
			por_otro_lado, rapidez_salida])


## Un partido corto empatado se define por penales y la tanda tiene ganador.
## Dos minutos por tiempo: lo que dura de verdad el partido del juego.
func _tanda() -> void:
	var jugadas := 0
	for n in 20:
		var c := _corto(SEED + 100 + n, 2.0, true)
		_hasta_el_final(c, 60 * 60 * 30)
		var k: Dictionary = c.contadores()
		if int(k["goles_0"]) != int(k["goles_1"]):
			continue
		var e: Dictionary = c.get_estado()
		var goles: Vector2i = e["goles_tanda"]
		var pateados: Vector2i = e["pateados_tanda"]
		var penales := (c.eventos() as Array).filter(func(v): return v["tipo"] == "penal_tanda").size()
		_ok(e["periodo"] == "terminado" and goles.x != goles.y and penales == pateados.x + pateados.y
				and absi(pateados.x - pateados.y) <= 1,
			"semilla %d: el empate %d-%d se define por penales %d-%d en %d penales" % [SEED + 100 + n, k["goles_0"],
				k["goles_1"], goles.x, goles.y, penales])
		jugadas += 1
		if jugadas >= 2:
			break
	_ok(jugadas > 0, "hubo algún empate para patear la tanda")


func _huellas() -> void:
	var huellas := []
	for vez in 2:
		var c := _corto(SEED, 5.0, false)
		_hasta_el_final(c, 60 * 60 * 30)
		huellas.append(c.huella())
	_ok(huellas[0] == huellas[1], "misma semilla, mismo partido (%s)" % huellas[0])


## Un partido con `minutos` de verdad por tiempo y el reloj a la par (sin la
## ficción del 0-90).
static func _corto(semilla: int, minutos: float, tanda: bool) -> Object:
	var c: Object = CerebroV2.armar_partido(semilla, "", "", -1, -1, true, tanda)
	var r := FisicaV2.parametros_reglas(tanda)
	r["minutos_tiempo"] = minutos
	r["segundos_tiempo"] = minutos * 60.0
	c.configurar_reglas(r)
	c.empezar(CanchitaV2Nativa.PARTIDO, semilla)
	return c


static func _hasta_el_final(c: Object, tope: int) -> int:
	var pasos := 0
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < tope:
		c.simular(600)
		pasos += 600
	return pasos


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		fallos += 1
		print("FALLA: " + texto)
