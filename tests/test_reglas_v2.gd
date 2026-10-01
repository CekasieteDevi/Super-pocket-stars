extends SceneTree

## Etapa 6 del Motor V2 (docs/motor_v2.md): reglas y pelota parada, sin pantalla.
## - Los números de fábrica del C++ (reglas.h) son los de FisicaV2.parametros_reglas().
## - "Pasa si": partidos de 90 minutos completos sin intervención, con dos
##   tiempos y todas las reanudaciones (saque del medio, lateral, saque de
##   arco, córner, tiro libre). Cada parada se ejecuta. Nadie camina hasta la
##   línea para sacar un lateral (lo que la vista 3D actual corta) y nadie
##   aparece encima de la pelota.
## - Sin correcciones de la pelota, sin SALTO_PELOTA y sin teletransportes de
##   jugador (más de 0,5 m entre pasos, docs/motor_v2.md "Definición de hecho").
## - Hay faltas que salen del contacto, tarjetas, offside cobrado, cambios y
##   penales; el expulsado deja al equipo con diez.
## - La tanda termina con un ganador.
## - Misma semilla = mismo partido.

const SEED := 20261010
## Tres partidos de 90 minutos: con uno solo, el penal o la roja pueden no
## aparecer (0,9 penales y 0,2 rojas por partido, tests/_diag_reglas_v2.gd).
const PARTIDOS := 3
## Lo que tiene que haber sumando los tres (unos 24 faltas, 3,5 amarillas y 3
## offside por partido en la medición).
const FALTAS_MIN := 30
const AMARILLAS_MIN := 3
## Más que esto entre dos pasos es un teletransporte.
const SALTO_MAX_M := 0.5

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
		if not s.begins_with("clip_") and s != "tanda" and not fabrica.has(clave):
			distintos.append("%s del JSON no lo lee el C++" % s)
	_ok(distintos.is_empty(), "reglas.h tiene los mismos valores que FisicaV2.parametros_reglas() %s" % [distintos])


func _partidos() -> void:
	var suma := {}
	for n in PARTIDOS:
		var semilla := SEED + n
		var c: Object = CerebroV2.armar_partido(semilla, "", "", -1, -1, true)
		var cantidad_inicial: int = c.cantidad()
		var pasos := _hasta_el_final(c, 60 * 60 * 120)
		var k: Dictionary = c.contadores()
		var e: Dictionary = c.get_estado()
		var minutos := pasos / 3600.0
		var eventos: Array = c.eventos()
		var fines := eventos.filter(func(v): return v["tipo"] == "fin_tiempo").size()
		_ok(e["periodo"] == "terminado" and fines == 2 and minutos >= 92.0 and minutos <= 101.0,
			"semilla %d: el partido termina solo, con dos tiempos y su agregado (%.1f min, %d fines)" % [
				semilla, minutos, fines])
		# Cada parada se ejecutó (la que estaba armada al final no cuenta).
		var sin_sacar := []
		for t in ["saque_medio", "lateral", "saque_arco", "corner", "tiro_libre", "penal"]:
			var resto: int = int(k["paradas_" + t]) - int(k["saques_" + t])
			if resto < 0 or resto > 1:
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


## Con rojas y lesiones a propósito (muchas más que en un partido): el que se
## va sale de la cancha, los índices de los que siguen se reacomodan y el
## partido termina igual.
func _expulsiones() -> void:
	var semilla := SEED + 50
	var c: Object = CerebroV2.armar_partido(semilla, "", "", -1, -1, true)
	var r := FisicaV2.parametros_reglas()
	r["minutos_tiempo"] = 20.0
	r["roja_por_falta"] = 0.12
	r["lesion_por_contacto"] = 60.0
	c.configurar_reglas(r)
	c.empezar(CanchitaV2Nativa.PARTIDO, semilla)
	var inicial: int = c.cantidad()
	var salidas := 0
	var pasos := 0
	var en_cancha_ok := true
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 60:
		c.simular(60)
		pasos += 60
		salidas = maxi(salidas, (c.get_afuera() as Array).size())
		var ids: PackedInt32Array = c.get_ids()
		var vistos := {}
		for id in ids:
			if vistos.has(id) or id < 0:
				en_cancha_ok = false
			vistos[id] = true
	var k: Dictionary = c.contadores()
	var rojas: int = int(k["rojas_0"]) + int(k["rojas_1"])
	var menos: int = inicial - c.cantidad()
	_ok(str(c.get_estado()["periodo"]) == "terminado" and rojas >= 2 and menos >= rojas
			and menos <= rojas + int(k["lesiones"]) and en_cancha_ok,
		"con %d rojas y %d lesiones el partido termina, con %d en cancha y sin ids repetidos" % [rojas, k["lesiones"],
			c.cantidad()])
	_ok(salidas > 0 and int(k["correcciones"]) == 0 and float(k["peor_salto_cuerpo_m"]) < SALTO_MAX_M,
		"los que se van salen caminando (hasta %d a la vez) y nadie salta (peor %.2f m)" % [salidas,
			k["peor_salto_cuerpo_m"]])


## Un partido corto empatado se define por penales y la tanda tiene ganador.
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


static func _corto(semilla: int, minutos: float, tanda: bool) -> Object:
	var c: Object = CerebroV2.armar_partido(semilla, "", "", -1, -1, true, tanda)
	var r := FisicaV2.parametros_reglas(tanda)
	r["minutos_tiempo"] = minutos
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
