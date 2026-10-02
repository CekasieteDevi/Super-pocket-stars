extends SceneTree

## Etapa 4 del Motor V2 (docs/motor_v2.md): el cerebro en C++
## (motor_v2/cpp/src/cerebro/), sin pantalla.
## - Los pesos de fábrica del C++ son los de data/utility_pesos.json y
##   data/fisica_v2.json ("cerebro").
## - La exponencial y el logaritmo propios (matematica_fija.h) coinciden con
##   los de Godot.
## - "Pasa si": 11 contra 11 sin reglas durante 20 minutos (desde la etapa 5,
##   con arqueros y remates), con
##   posesiones de varios pases, bloques que se desplazan con la pelota y
##   pases al espacio que salen solos. Sin correcciones de la pelota.
## - Presionante, cobertura y línea defensiva: el que presiona es el que
##   llega primero y la línea de atrás se para junta.
## - Misma semilla = misma huella.

const SEED := 20261002
## 20 minutos: desde la etapa 5 hay remates y arqueros, y la posesión termina
## también en un remate o en las manos del arquero. En 10 minutos esta semilla
## pasó de 3 posesiones de 5 pases a 0 (otras semillas dan 1 y 4): ruido de una
## muestra chica, no el juego armado.
const SEGUNDOS := 1200.0
const DiagCerebro := preload("res://tests/_diag_cerebro_v2.gd")

var fallos := 0


func _init() -> void:
	if not ClassDB.class_exists("CanchitaV2Nativa"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_pesos_como_los_json()
	_matematica()
	_defensa()
	_partido()
	_huellas()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _pesos_como_los_json() -> void:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	var fabrica: Dictionary = c.pesos_cerebro_de_fabrica()
	var pesos := MotorEspacial.pesos()
	var distintos := []
	for seccion in fabrica:
		var json: Dictionary = FisicaV2.parametros_cerebro() if seccion == "cerebro" else pesos[seccion]
		for clave in fabrica[seccion]:
			if not json.has(clave):
				distintos.append("%s.%s falta en el JSON" % [seccion, clave])
			elif absf(float(json[clave]) - float(fabrica[seccion][clave])) > 1e-9:
				distintos.append("%s.%s: C++ %s, JSON %s" % [seccion, clave, fabrica[seccion][clave], json[clave]])
	for clave in FisicaV2.parametros_cerebro():
		if not (fabrica["cerebro"] as Dictionary).has(clave):
			distintos.append("cerebro.%s del JSON no lo lee el C++" % clave)
	_ok(distintos.is_empty(), "cerebro.h tiene los mismos valores que los JSON %s" % [distintos])


func _matematica() -> void:
	var peor_exp := 0.0
	var peor_log := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for k in 2000:
		var x := rng.randf_range(-40.0, 5.0)
		peor_exp = maxf(peor_exp, absf(CanchitaV2Nativa.exponencial(x) / exp(x) - 1.0))
		var y := rng.randf_range(0.001, 1000.0)
		peor_log = maxf(peor_log, absf(CanchitaV2Nativa.logaritmo(y) - log(y)))
	_ok(peor_exp < 1e-14, "exponencial propia: error relativo %s" % peor_exp)
	_ok(peor_log < 1e-14, "logaritmo propio: error %s" % peor_log)


## Sin la pelota: el presionante es el que llega primero al balón de su
## equipo, hay alguien que lo cubre y la línea de atrás se para a la misma
## altura. Se mira en el momento, 30 veces a lo largo de dos minutos.
func _defensa() -> void:
	var c: Object = CerebroV2.armar_partido(SEED)
	var roles: PackedInt32Array = c.get_roles()
	var equipos: PackedInt32Array = c.get_equipos()
	var con_presionante := 0
	var con_cobertura := 0
	var presionante_cerca := 0
	var muestras := 0
	for k in 30:
		c.simular(240)
		if c.get_poseedor() < 0:
			continue
		var defiende: int = 1 - int(c.get_equipo_con_pelota())
		var papeles: PackedInt32Array = c.get_papeles()
		# El plan de defensa se rehace cada 6 pasos. Si la pelota acaba de
		# cambiar de equipo, los papeles todavía son los del plan anterior
		# (los tiene el equipo que ahora ataca): se mira el plan siguiente.
		var del_que_defiende := false
		for i in papeles.size():
			if equipos[i] == defiende and papeles[i] != 0:
				del_que_defiende = true
		if not del_que_defiende:
			c.simular(6)
			if c.get_poseedor() < 0 or 1 - int(c.get_equipo_con_pelota()) != defiende:
				continue
			papeles = c.get_papeles()
		muestras += 1
		var pos: PackedVector2Array = c.get_pos()
		var b: Vector3 = c.get_pelota_pos()
		var bola := Vector2(b.x, b.z)
		var d_presionante := INF
		var d_min := INF
		for i in pos.size():
			if equipos[i] != defiende or roles[i] == 0:
				continue
			d_min = minf(d_min, pos[i].distance_to(bola))
			if papeles[i] == 1:
				d_presionante = pos[i].distance_to(bola)
			if papeles[i] == 2:
				con_cobertura += 1
		if d_presionante < INF:
			con_presionante += 1
			# Es el que llega primero con su zona: puede no ser el más cerca
			# por metros, pero anda cerca.
			if d_presionante <= d_min + 6.0:
				presionante_cerca += 1
	_ok(muestras >= 10, "hubo pelota controlada en %d de 30 muestras" % muestras)
	_ok(con_presionante == muestras, "siempre sale uno a presionar (%d de %d)" % [con_presionante, muestras])
	_ok(con_cobertura >= muestras * 0.8, "casi siempre alguien lo cubre (%d de %d)" % [con_cobertura, muestras])
	_ok(presionante_cerca >= muestras * 0.8, "el que presiona anda cerca de la pelota (%d de %d)" % [presionante_cerca, muestras])


func _partido() -> void:
	var c: Object = CerebroV2.armar_partido(SEED)
	var m: Dictionary = DiagCerebro.medir(c, SEGUNDOS)
	DiagCerebro.imprimir(SEED, SEGUNDOS, c, m)
	var k: Dictionary = c.contadores()
	var d: Dictionary = c.contadores_cerebro()
	# Posesiones de varios pases.
	_ok(int(k["posesiones_3_pases"]) >= 5, "posesiones de 3 pases o más: %d (al menos 5 en 20 min)" % k["posesiones_3_pases"])
	_ok(int(k["posesiones_5_pases"]) >= 1, "posesiones de 5 pases o más: %d (al menos 1)" % k["posesiones_5_pases"])
	var pases := maxf(float(k["pases"]), 1.0)
	_ok((float(k["completados"]) + float(k["completados_otro"])) / pases >= 0.45,
		"se completa casi la mitad de los pases o más (%.0f%%)" % [100.0 * (float(k["completados"]) + float(k["completados_otro"])) / pases])
	# Bloques que se desplazan con la pelota: el centro de cada equipo sigue a
	# la pelota a lo largo y a lo ancho.
	for e in 2:
		_ok(float(m["corr_x"][e]) >= 0.8, "el bloque %d sigue a la pelota a lo largo (correlación %.2f)" % [e, m["corr_x"][e]])
		_ok(float(m["corr_z"][e]) >= 0.6, "el bloque %d sigue a la pelota a lo ancho (correlación %.2f)" % [e, m["corr_z"][e]])
	_ok(float(m["corr_def_x"]) >= 0.4, "el que defiende también se corre con la pelota (%.2f)" % m["corr_def_x"])
	_ok(float(m["dispersion_linea"]) <= 5.0, "la línea de atrás se para junta: ±%.1f m" % m["dispersion_linea"])
	# Pases al espacio que salen solos: al hueco o a la corrida que el cerebro
	# ya había preparado, y alguno llega.
	# Etapa 7: el pase que el planeador ve cortado ya no se ofrece
	# (cerebro.riesgo_maximo). Antes salían 14,6 pases al hueco por partido y
	# se cortaba el 46%; ahora son pocos (de 1 a 6 en estos 10 minutos, según la
	# semilla) y la pared todavía menos. Con un solo partido el test pasaba o
	# fallaba por ruido: se suman tres.
	var raros := {"pases_al_espacio": int(k["pases_al_espacio"]),
		"pases_al_espacio_completos": int(k["pases_al_espacio_completos"]), "pared": int(d["pared"])}
	for n in [1, 2]:
		var otro: Object = CerebroV2.armar_partido(SEED + 20 + n)
		otro.simular(int(SEGUNDOS * 60.0))
		raros["pases_al_espacio"] += int(otro.contadores()["pases_al_espacio"])
		raros["pases_al_espacio_completos"] += int(otro.contadores()["pases_al_espacio_completos"])
		raros["pared"] += int(otro.contadores_cerebro()["pared"])
	_ok(raros["pases_al_espacio"] >= 3, "pases al espacio en tres partidos: %d (al menos 3)" % raros["pases_al_espacio"])
	_ok(raros["pases_al_espacio_completos"] >= 1,
		"pases al espacio que llegan en tres partidos: %d (al menos 1)" % raros["pases_al_espacio_completos"])
	_ok(raros["pared"] >= 1, "el poseedor elige pared en tres partidos (%d)" % raros["pared"])
	_ok(int(d["desmarque_ruptura"]) > 0 and int(d["apoyos_de_grilla"]) > 0,
		"hay rupturas (%d) y apoyos de la grilla (%d)" % [d["desmarque_ruptura"], d["apoyos_de_grilla"]])
	# Todas las decisiones del poseedor aparecen.
	for tipo in ["conducir", "pase", "pase_hueco", "pase_largo", "remate"]:
		_ok(int(d[tipo]) > 0, "el poseedor elige %s (%d)" % [tipo, d[tipo]])
	# Lo de la etapa 3 sigue valiendo con 22 jugadores y el cerebro.
	_ok(int(k["correcciones"]) == 0 and int(k["saltos_pelota"]) == 0,
		"cero correcciones de la pelota (%d) y SALTO_PELOTA = 0 (%d)" % [k["correcciones"], k["saltos_pelota"]])
	_ok(int(k["frenadas_en_seco"]) == 0, "nadie frena en seco (%d)" % k["frenadas_en_seco"])
	_ok(float(k["peor_salto_cuerpo_m"]) < 0.1, "ningún cuerpo salta (peor %.3f m)" % k["peor_salto_cuerpo_m"])


func _huellas() -> void:
	var h := []
	for vez in 2:
		var c: Object = CerebroV2.armar_partido(SEED + 7)
		c.simular(60 * 60)
		h.append(c.huella())
	_ok(h[0] == h[1], "misma semilla, mismo partido (%d)" % h[0])


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		fallos += 1
		print("FALLA: " + texto)
