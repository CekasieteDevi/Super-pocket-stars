extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): la traza de un ataque. Escribe, paso
## por paso, qué decide el que tiene la pelota a menos de `cerca` metros del
## arco rival y cómo termina la jugada. Sirve para leer una jugada que en la
## pantalla se ve rara. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_traza_v2.gd -- partidos=2 a=4 b=4 semilla=97000 cerca=35

const SEED := 97000
const MEDIO_LARGO_M := 52.5
const ROLES := ["ARQ", "DFC", "LAT", "MC", "MCO", "EXT", "DC"]
const TIPOS := ["conducir", "pase", "pase_hueco", "pase_largo", "centro", "pared", "despeje", "remate"]


func _init() -> void:
	var partidos := 2
	var a := 4
	var b := 4
	var semilla := SEED
	var cerca := 35.0
	# Con banda=1: cada medio segundo con la pelota por la banda en el último
	# tercio, dónde está cada compañero de campo y adónde va.
	var banda := false
	# Los estilos de cada equipo, y resumen=1: en vez de la traza, qué decide el
	# equipo 0 según lo lejos que está del fondo rival.
	var estilo_a := ""
	var estilo_b := ""
	var resumen := false
	var tabla := {}
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"a": a = int(p[1])
			"b": b = int(p[1])
			"semilla": semilla = int(p[1])
			"cerca": cerca = float(p[1])
			"banda": banda = int(p[1]) == 1
			"estilo_a": estilo_a = p[1]
			"estilo_b": estilo_b = p[1]
			"resumen": resumen = int(p[1]) == 1
			"fisica": _pisar(FisicaV2.datos(), p[1])
	for n in partidos:
		var c: Object = CerebroV2.armar_partido(semilla + n, estilo_a, estilo_b, a, b, true)
		if not resumen:
			print("[traza] --- partido %d ---" % n)
		var antes: Dictionary = c.contadores_cerebro()
		var remates := 0
		var goles := 0
		var equipo_antes := -1
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(1)
			pasos += 1
			var ahora: Dictionary = c.contadores_cerebro()
			var tipo := ""
			for t in TIPOS:
				if int(ahora[t]) > int(antes[t]):
					tipo = t
			antes = ahora
			var k: Dictionary = c.contadores()
			var pos: PackedVector2Array = c.get_pos()
			var equipos: PackedInt32Array = c.get_equipos()
			if int(k["remates"]) > remates:
				remates = int(k["remates"])
				if not resumen:
					print("[traza] %6.1f s   REMATE" % [pasos / 60.0])
			if int(k["goles_0"]) + int(k["goles_1"]) > goles:
				goles = int(k["goles_0"]) + int(k["goles_1"])
				if not resumen:
					print("[traza] %6.1f s   GOL" % [pasos / 60.0])
			var con := int(c.get_equipo_con_pelota())
			if con != equipo_antes:
				var bola: Vector3 = c.get_pelota_pos()
				if not resumen and equipo_antes >= 0 and MEDIO_LARGO_M - bola.x * (1.0 if equipo_antes == 0 else -1.0) <= cerca:
					print("[traza] %6.1f s   la pierde el equipo %d (%s)" % [pasos / 60.0, equipo_antes, str(c.get_estado()["parada"])])
				equipo_antes = con
			if banda and pasos % 30 == 0:
				_mirar_banda(c, pasos)
			if tipo == "" or banda:
				continue
			var d: Dictionary = c.ultima_decision()
			var i := int(d["decisor"])
			if i < 0 or i >= pos.size():
				continue
			var signo := 1.0 if int(equipos[i]) == 0 else -1.0
			var al_fondo := MEDIO_LARGO_M - pos[i].x * signo
			if resumen:
				if int(equipos[i]) == 0:
					var zona := 0 if al_fondo > 60.0 else (1 if al_fondo > 40.0 else (2 if al_fondo > 25.0 else 3))
					var clave := "%d_%s" % [zona, tipo]
					tabla[clave] = int(tabla.get(clave, 0)) + 1
				continue
			if al_fondo > cerca:
				continue
			# El rival de campo más cerca y los que tiene entre él y el arco.
			var arqueros: PackedInt32Array = c.get_arqueros()
			var cerca_m := 99.0
			var delante := 0
			for o in pos.size():
				if int(equipos[o]) == int(equipos[i]) or int(arqueros[o]) == 1:
					continue
				cerca_m = minf(cerca_m, pos[o].distance_to(pos[i]))
				var t := (pos[o].x - pos[i].x) * signo / maxf(al_fondo, 1.0)
				if t > 0.0 and t < 1.0 and absf(pos[o].y - pos[i].y * (1.0 - t)) <= 4.66 * t + 1.0:
					delante += 1
			var opciones: Array = d["opciones"]
			opciones.sort_custom(func(x, y): return float(x["utilidad"]) > float(y["utilidad"]))
			var texto := ""
			for o in opciones.slice(0, 4):
				texto += " %s %.2f" % [o["tipo"], o["utilidad"]]
			print("[traza] %6.1f s eq %d j%-2d a %4.1f m del fondo, z %5.1f | rival a %4.1f m, %d en el medio | %-10s | %s, %d opciones, %d cortados |%s" % [
				pasos / 60.0, equipos[i], i, al_fondo, pos[i].y, cerca_m, delante, tipo,
				"puede pasar" if bool(d["puede_pasar"]) else "no puede pasar", d["ofrecidas"], d["cortados"], texto])
	if resumen:
		var zonas := ["a más de 60 m del fondo", "de 60 a 40 m", "de 40 a 25 m", "a menos de 25 m"]
		for z in 4:
			var total := 0
			for t in TIPOS:
				total += int(tabla.get("%d_%s" % [z, t], 0))
			var texto := "[resumen] %s %s: %.1f decisiones por partido:" % [estilo_a, zonas[z], float(total) / partidos]
			for t in TIPOS:
				var n_t := int(tabla.get("%d_%s" % [z, t], 0))
				if n_t > 0:
					texto += " %s %.0f%%" % [t, 100.0 * n_t / maxf(total, 1.0)]
			print(texto)
	quit()


func _mirar_banda(c: Object, pasos: int) -> void:
	var poseedor := int(c.get_poseedor())
	if poseedor < 0 or str(c.get_estado()["parada"]) != "nada":
		return
	var pos: PackedVector2Array = c.get_pos()
	var equipos: PackedInt32Array = c.get_equipos()
	var signo := 1.0 if int(equipos[poseedor]) == 0 else -1.0
	if absf(pos[poseedor].y) < 16.0 or MEDIO_LARGO_M - pos[poseedor].x * signo > 35.0:
		return
	var roles: PackedInt32Array = c.get_roles()
	var objetivos: PackedVector2Array = c.get_objetivos()
	var desmarques: PackedVector2Array = c.get_desmarques()
	var rapidez: PackedFloat32Array = c.get_rapidez()
	var lineas: PackedFloat32Array = c.get_lineas()
	var texto := "[banda] %6.1f s j%d (%s) a %4.1f m del fondo, z %5.1f, a %.1f m/s; offside a %.1f m |" % [pasos / 60.0, poseedor,
		ROLES[roles[poseedor]], MEDIO_LARGO_M - pos[poseedor].x * signo, pos[poseedor].y, rapidez[poseedor],
		MEDIO_LARGO_M - lineas[int(equipos[poseedor])] * signo]
	for i in pos.size():
		if i == poseedor or int(equipos[i]) != int(equipos[poseedor]) or roles[i] < 3:
			continue
		texto += " %s %.0f,%.0f>%.0f,%.0f%s %.1f" % [ROLES[roles[i]], MEDIO_LARGO_M - pos[i].x * signo, pos[i].y,
			MEDIO_LARGO_M - objetivos[i].x * signo, objetivos[i].y, "" if is_nan(desmarques[i].x) else "*", rapidez[i]]
	print(texto)


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
