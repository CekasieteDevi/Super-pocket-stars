extends SceneTree

## Etapa 5 del Motor V2 (docs/motor_v2.md): remates y arqueros, sin pantalla.
## - Los números de fábrica del C++ (remate.h) son los de data/fisica_v2.json.
## - `apuntar` encuentra con la física la patada que cruza por el punto pedido.
## - Sin error, el remate va adonde se apuntó: adentro es gol, afuera es afuera.
## - El arquero: ataja la que le llega a tiro, se estira a la del costado y no
##   llega al ángulo desde cerca. El rebote queda en juego. La que agarra la
##   lleva en las manos.
## - "Pasa si": en un partido, el porcentaje de remates al arco y de atajadas
##   por división cae en el rango del motor actual
##   (tests/_diag_embudo_remates.gd). Sin correcciones de la pelota.
## - Misma semilla = misma huella.

const SEED := 20261005
## Rango del embudo del motor actual y del abstracto en partidos parejos de
## primera, quinta y décima (tests/_diag_embudo_remates.gd, 40 partidos por
## división, semilla 97000): al arco del 50 al 69% de los remates, atajadas del
## 38 al 55% de los remates al arco. La medición de la etapa
## (tests/_diag_remates_v2.gd, 16 partidos de 45 minutos) da 62-66% y 51-53%.
## El test juega menos: con unos 150 remates al arco por división el desvío de
## las atajadas es de 4 puntos, y con 5 de margen D5 dio 63% una vez. Se le dan
## 8 puntos de cada lado.
const AL_ARCO := Vector2(42.0, 77.0)
const ATAJADAS := Vector2(30.0, 63.0)
## Seis partidos de 40 minutos por división: con dos de 30, décima (que
## remata menos) juntaba 23 remates y las atajadas saltaban del 29 al 55%.
const PARTIDOS := 6
const MINUTOS_PARTIDO := 40.0

var fallos := 0


func _init() -> void:
	if not ClassDB.class_exists("CanchitaV2Nativa"):
		_ok(false, "la extensión motor_v2 está armada para esta plataforma (motor_v2/bin)")
		print("FALLOS=%d" % fallos)
		quit(1)
		return
	_numeros_como_el_json()
	_apuntar()
	_sin_error()
	_arquero()
	_rebote_y_manos()
	_partidos()
	_huellas()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _numeros_como_el_json() -> void:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	var fabrica: Dictionary = c.remate_de_fabrica()
	var distintos := []
	var json := {"remate": FisicaV2.parametros_remate(), "arquero": FisicaV2.parametros_arquero()}
	for seccion in fabrica:
		for clave in fabrica[seccion]:
			var valor = fabrica[seccion][clave]
			var del_json = json[seccion].get(clave, null)
			if valor is Dictionary:
				for k in valor:
					if del_json == null or absf(float(del_json.get(k, NAN)) - float(valor[k])) > 1e-9:
						distintos.append("%s.%s.%s" % [seccion, clave, k])
			elif del_json == null or absf(float(del_json) - float(valor)) > 1e-9:
				distintos.append("%s.%s: C++ %s, JSON %s" % [seccion, clave, valor, del_json])
	for seccion in json:
		for clave in json[seccion]:
			if not str(clave).begins_with("clip_") and not (fabrica[seccion] as Dictionary).has(clave):
				distintos.append("%s.%s del JSON no lo lee el C++" % [seccion, clave])
	_ok(distintos.is_empty(), "remate.h tiene los mismos valores que los JSON %s" % [distintos])


## La patada que busca apuntar() cruza el plano del arco por el punto pedido.
func _apuntar() -> void:
	var p := FisicaV2.parametros()
	var casos := [
		# desde, meta, rapidez, elevación fija (-1 = la busca), giro
		[Vector3(36.5, 0.11, 0.0), Vector3(52.5, 1.9, 0.0), 19.6, -1.0, 0.0, "alto al medio desde 16 m"],
		[Vector3(36.5, 0.11, 3.0), Vector3(52.5, 1.0, -2.3), 26.0, -1.0, 0.0, "fuerte cruzado desde 16 m"],
		[Vector3(24.5, 0.11, 0.0), Vector3(52.5, 1.9, 1.5), 25.0, -1.0, 0.0, "alto desde 28 m"],
		[Vector3(32.5, 0.11, -6.0), Vector3(52.5, 1.0, 2.3), 21.0, -1.0, 45.0, "con efecto desde 21 m"],
		[Vector3(30.5, 0.11, 0.0), Vector3(52.5, 1.8, 0.5), 0.0, 0.7, 0.0, "globo desde 22 m"],
	]
	for caso in casos:
		var r: Dictionary = CanchitaV2Nativa.apuntar_prueba(p, caso[0], caso[1], caso[2], caso[3], caso[4])
		var cruce: Vector3 = r.get("cruce", Vector3.INF)
		var error := Vector2(cruce.y, cruce.z).distance_to(Vector2(caso[1].y, caso[1].z))
		_ok(bool(r["ok"]) and error < 0.1, "apuntar, %s: cruza a %.3f m del punto" % [caso[5], error])
	var rasante: Dictionary = CanchitaV2Nativa.apuntar_prueba(p, Vector3(36.5, 0.11, 0.0), Vector3(52.5, 0.2, 2.3),
		19.6, -1.0, 0.0)
	var v: Vector3 = rasante.get("vel", Vector3.ZERO)
	var c: Vector3 = rasante.get("cruce", Vector3.INF)
	_ok(bool(rasante["ok"]) and absf(v.y) < 1e-6 and absf(c.z - 2.3) < 0.1,
		"el rasante sale por el piso (vertical %.3f) y cruza a %.3f m del palo pedido" % [v.y, absf(c.z - 2.3)])


## Sin error ni arquero, el remate entra donde se apuntó; al costado del palo, afuera.
func _sin_error() -> void:
	var sin_error := FisicaV2.parametros_remate()
	sin_error["error_rad"] = 0.0
	sin_error["error_rapidez"] = 0.0
	var resultados := {}
	for caso in [[16.0, 2.3, 0.2, CanchitaV2Nativa.REMATE_COLOCADO], [22.0, -3.0, 1.9, CanchitaV2Nativa.REMATE_FUERTE],
			[18.0, 2.8, 1.0, CanchitaV2Nativa.REMATE_EFECTO], [25.0, 0.0, 1.8, CanchitaV2Nativa.REMATE_GLOBO],
			[20.0, 4.6, 1.0, CanchitaV2Nativa.REMATE_COLOCADO], [20.0, 0.0, 3.0, CanchitaV2Nativa.REMATE_FUERTE]]:
		var c := _cancha(SEED, sin_error, false)
		var x := 52.5 - float(caso[0])
		c.poner_jugador(0, Vector2(x - 0.6, 0.0), PI * 0.5)
		c.rematar(0, caso[3], caso[2], caso[1])
		c.lanzar(Vector3(x, 0.11, 0.0), Vector3.ZERO, Vector3.ZERO, 0)
		var res := _hasta_el_final(c)
		var adentro := absf(float(caso[1])) < 3.66 and float(caso[2]) < 2.44
		resultados["%.0f m, (%.1f, %.1f)" % [caso[0], caso[1], caso[2]]] = res
		_ok(res == (CanchitaV2Nativa.RESULTADO_GOL if adentro else CanchitaV2Nativa.RESULTADO_AFUERA),
			"sin error, desde %.0f m al punto (%.1f, %.1f): %s" % [caso[0], caso[1], caso[2],
				"gol" if res == 0 else ("afuera" if res == 4 else str(res))])


## El arquero (atributos 70): a lo que le llega de lejos lo ataja; se estira a
## la del costado; desde cerca, al ángulo alto no llega.
func _arquero() -> void:
	var r := _serie(22.0, 0.0, 1.0, 10)
	_ok(r["atajado"] >= 7, "remate al cuerpo desde 22 m: ataja %d de 10" % r["atajado"])
	r = _serie(16.0, 1.5, 0.2, 10)
	_ok(r["estiradas"] >= 8, "rasante a 1,5 m del medio desde 16 m: se estira %d de 10" % r["estiradas"])
	r = _serie(11.0, 3.0, 1.9, 10)
	_ok(r["gol"] + r["palo"] >= 8, "al ángulo alto desde 11 m: gol o palo %d de 10" % (r["gol"] + r["palo"]))
	r = _serie(28.0, 2.3, 0.2, 10)
	_ok(r["atajado"] >= 7, "rasante al palo desde 28 m: ataja %d de 10" % r["atajado"])


func _serie(distancia: float, lateral: float, alto: float, veces: int) -> Dictionary:
	var r := {"gol": 0, "atajado": 0, "palo": 0, "estiradas": 0}
	for k in veces:
		var c := _cancha(SEED + k, FisicaV2.parametros_remate(), true)
		var x := 52.5 - distancia
		c.poner_jugador(0, Vector2(x - 0.6, 0.0), PI * 0.5)
		c.poner_jugador(1, Vector2(51.7, 0.0), -PI * 0.5)
		c.rematar(0, CanchitaV2Nativa.REMATE_COLOCADO, alto, lateral)
		c.lanzar(Vector3(x, 0.11, 0.0), Vector3.ZERO, Vector3.ZERO, 0)
		var res := _hasta_el_final(c)
		if res == CanchitaV2Nativa.RESULTADO_GOL:
			r["gol"] += 1
		elif res == CanchitaV2Nativa.RESULTADO_ATAJADO:
			r["atajado"] += 1
		elif res == CanchitaV2Nativa.RESULTADO_PALO:
			r["palo"] += 1
		r["estiradas"] += int(c.contadores()["estiradas"])
	return r


## El rebote del arquero queda en la cancha y lo juega el que llega; la que
## agarra la lleva en las manos, pegada a él, sin corregir la pelota.
func _rebote_y_manos() -> void:
	var rebotes := 0
	var en_juego := 0
	var manos := 0
	var pegada := true
	var correcciones := 0
	for k in 30:
		var c := _cancha(SEED + 100 + k, FisicaV2.parametros_remate(), true)
		# Un compañero espera el rebote en el punto penal.
		var a := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0}
		c.poner_jugador(0, Vector2(29.4, 0.0), PI * 0.5)
		c.poner_jugador(1, Vector2(51.7, 0.0), -PI * 0.5)
		c.rematar(0, CanchitaV2Nativa.REMATE_FUERTE, 1.0, 1.2 if k % 2 == 0 else -1.2)
		c.lanzar(Vector3(30.0, 0.11, 0.0), Vector3.ZERO, Vector3.ZERO, 0)
		var toco_rebote := false
		var reboto := false
		var en_manos := false
		for paso in 300:
			c.avanzar()
			var k2: Dictionary = c.contadores()
			if not reboto and int(k2["rebotes_arquero"]) + int(k2["roces_arquero"]) > 0:
				reboto = true
			if reboto and int(c.get_ultimo_toque()) == 0 and int(c.get_en_manos()) < 0:
				toco_rebote = true
			if int(c.get_en_manos()) == 1:
				en_manos = true
				var b: Vector3 = c.get_pelota_pos()
				var pos: PackedVector2Array = c.get_pos()
				if Vector2(b.x, b.z).distance_to(pos[1]) > 0.6:
					pegada = false
		var fin: Dictionary = c.contadores()
		correcciones += int(fin["correcciones"]) + int(fin["saltos_pelota"])
		if reboto:
			rebotes += 1
			if toco_rebote:
				en_juego += 1
		if en_manos:
			manos += 1
	_ok(rebotes >= 3, "el arquero da rebotes (%d de 30 remates fuertes)" % rebotes)
	_ok(en_juego >= 1, "el rebote queda en juego: el atacante la vuelve a tocar en %d de %d" % [en_juego, rebotes])
	_ok(manos >= 3 and pegada, "la que agarra la lleva en las manos, pegada al cuerpo (%d veces)" % manos)
	_ok(correcciones == 0, "sin correcciones ni saltos de la pelota (%d)" % correcciones)


## "Pasa si": al arco y atajadas por división, dentro del rango del motor actual.
func _partidos() -> void:
	for division in [0, 4, 9]:
		var suma := {}
		for n in PARTIDOS:
			var estilos: Array = [["Tiki taka", "Juego directo"], ["Presion alta", "Contragolpe"]][n % 2]
			var c := CerebroV2.armar_partido(SEED + n, estilos[0], estilos[1], division, division)
			c.simular(int(MINUTOS_PARTIDO * 3600.0))
			var k: Dictionary = c.contadores()
			for clave in k:
				suma[clave] = float(suma.get(clave, 0.0)) + float(k[clave])
		var remates: float = maxf(suma["remates"], 1.0)
		var al_arco: float = suma["remates_gol"] + suma["remates_atajado"]
		var p_arco := 100.0 * al_arco / remates
		var p_atajadas: float = 100.0 * suma["remates_atajado"] / maxf(al_arco, 1.0)
		_ok(suma["remates"] >= 20.0 and suma["goles_0"] + suma["goles_1"] > 0.0,
			"división %d: hay remates (%d) y goles (%d)" % [division + 1, suma["remates"], suma["goles_0"] + suma["goles_1"]])
		_ok(p_arco >= AL_ARCO.x and p_arco <= AL_ARCO.y,
			"división %d: al arco %.0f%% (rango %.0f-%.0f%%)" % [division + 1, p_arco, AL_ARCO.x, AL_ARCO.y])
		_ok(p_atajadas >= ATAJADAS.x and p_atajadas <= ATAJADAS.y,
			"división %d: atajadas %.0f%% (rango %.0f-%.0f%%)" % [division + 1, p_atajadas, ATAJADAS.x, ATAJADAS.y])
		_ok(suma["correcciones"] == 0.0 and suma["saltos_pelota"] == 0.0,
			"división %d: cero correcciones (%d) y SALTO_PELOTA = 0 (%d)" % [division + 1, suma["correcciones"],
				suma["saltos_pelota"]])


func _huellas() -> void:
	var h := []
	for vez in 2:
		var c := CerebroV2.armar_partido(SEED + 7, "", "", 0, 0)
		c.simular(5 * 3600)
		h.append(c.huella())
	_ok(h[0] == h[1], "misma semilla, mismo partido (%d)" % h[0])


## Modo ARCO: el 0 remata al arco de +x; con `con_arquero`, lo defiende el 1.
static func _cancha(semilla: int, remate: Dictionary, con_arquero: bool) -> Object:
	var c: Object = ClassDB.instantiate("CanchitaV2Nativa")
	c.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(), FisicaV2.parametros_toque())
	c.configurar_remate(remate, FisicaV2.parametros_arquero())
	var a := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0,
		"tiro": 70.0, "golpe": 70.0, "cabezazo": 70.0}
	c.agregar(0, FisicaV2.jugador_de(a).merged(a))
	if con_arquero:
		var g := {"velocidad": 60.0, "aceleracion": 60.0, "agilidad": 60.0, "reflejos": 70.0, "estirada": 70.0,
			"agarre": 70.0, "achique": 70.0, "arquero": true}
		c.agregar(1, FisicaV2.jugador_de(g).merged(g))
	c.empezar(CanchitaV2Nativa.ARCO, semilla)
	return c


static func _hasta_el_final(c: Object) -> int:
	for paso in 300:
		c.avanzar()
		if int(c.get_ultimo_resultado()) >= 0:
			break
	return int(c.get_ultimo_resultado())


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		fallos += 1
		print("FALLA: " + texto)
