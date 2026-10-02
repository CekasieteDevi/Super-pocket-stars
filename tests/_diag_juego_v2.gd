extends SceneTree

## Etapa 7 del Motor V2 (docs/motor_v2.md): cómo se juega. Mide lo que el
## usuario marca en la revisión visual: por qué sale la pelota, cuánto se aleja
## al conducir, cuántos acompañan en el área un ataque por la banda, a qué
## altura van los remates y cuántos cabezazos hay. No es un test: mide.
##
##   <godot> --path . --headless --script tests/_diag_juego_v2.gd -- partidos=60 a=4 b=4 semilla=97000
##
## `fisica=seccion.clave:valor,...` pisa data/fisica_v2.json en memoria.

const SEED := 97000
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## Cada cuántos pasos se mira la cancha (0,25 s).
const CADA_PASOS := 15
## La banda: a más de esto del eje de la cancha. El último tercio: a menos de
## esto de la línea de fondo rival.
const BANDA_M := 20.0
const ULTIMO_TERCIO_M := 30.0
## Cerca del arco: a menos de esto del medio de la línea de gol (el área llega
## a 16,5; la línea del offside suele dejar a los que llegan en el borde).
const CERCA_DEL_ARCO_M := 24.0
const AREA_LARGO_M := 16.5
const AREA_MEDIO_ANCHO_M := 20.16
const MEDIO_LARGO_M := 52.5
const TIPO_CENTRO := 5
const GOLPES := ["colocado", "fuerte", "efecto", "globo", "cabeza"]
const FRANJAS_M := ["menos de 1 m", "1 a 2 m", "2 a 3 m", "3 a 5 m", "más de 5 m"]
const FRANJAS_TIRO := ["lejos (0,05 a 0,15)", "a media distancia (0,15 a 0,3)", "a tiro (0,3 a 0,5)", "encima (más de 0,5)"]
const FRANJAS_LIBRE := ["a menos de 16,5 m", "de 16,5 a 25 m", "de 25 a 35 m"]
const DECISIONES := ["conducir", "pase", "pase_hueco", "pase_largo", "centro", "pared", "despeje", "remate"]
const RESULTADOS :=["gol", "atajado", "palo", "bloqueado", "afuera", "otro"]


func _init() -> void:
	var partidos := 60
	var a := 4
	var b := 4
	var semilla := SEED
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"partidos": partidos = maxi(1, int(p[1]))
			"a": a = int(p[1])
			"b": b = int(p[1])
			"semilla": semilla = int(p[1])
			"fisica": _pisar(FisicaV2.datos(), p[1])
	var k := {}
	var kc := {}
	var banda := {"muestras": 0.0, "compas": 0.0, "rivales": 0.0, "solo": 0.0, "cerca": 0.0, "centros": 0.0,
		"centro_compas": 0.0, "centro_solo": 0.0, "rapidez": 0.0, "rol_3": 0.0, "rol_2": 0.0, "rol_5": 0.0, "rol_6": 0.0, "rol_4": 0.0}
	var remates := {"n": 0.0, "raso": 0.0, "medio": 0.0, "alto": 0.0}
	var por_golpe := {}
	var afuera_tipo := {}
	for n in partidos:
		var e: Array = ESTILOS[n % ESTILOS.size()]
		var c: Object = CerebroV2.armar_partido(semilla + n, e[0], e[1], a, b, true)
		var pasos := 0
		var centros_vistos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(CADA_PASOS)
			pasos += CADA_PASOS
			_mirar_banda(c, banda)
			# Cada centro, en el cuadro en que sale: cuántos compañeros hay en
			# el área.
			var pases: Array = c.registro_pases()
			while centros_vistos < pases.size():
				var r: Dictionary = pases[centros_vistos]
				centros_vistos += 1
				if int(r["tipo"]) == TIPO_CENTRO and str(c.get_estado()["parada"]) == "nada":
					var en_area := _en_el_area(c, int(r["pateador"]))
					banda["centros"] += 1.0
					banda["centro_compas"] += float(en_area)
					if en_area == 0:
						banda["centro_solo"] += 1.0
		var cuenta_cerebro: Dictionary = c.contadores_cerebro()
		for clave in cuenta_cerebro:
			kc[clave] = float(kc.get(clave, 0.0)) + float(cuenta_cerebro[clave])
		var cuenta: Dictionary = c.contadores()
		for clave in cuenta:
			if typeof(cuenta[clave]) == TYPE_INT or typeof(cuenta[clave]) == TYPE_FLOAT:
				if str(clave) == "conduce_max_m":
					k[clave] = maxf(float(k.get(clave, 0.0)), float(cuenta[clave]))
				else:
					k[clave] = float(k.get(clave, 0.0)) + float(cuenta[clave])
		for r in c.registro_remates():
			var golpe: String = GOLPES[clampi(int(r["golpe"]), 0, GOLPES.size() - 1)]
			if not por_golpe.has(golpe):
				por_golpe[golpe] = {"n": 0.0, "gol": 0.0, "alto_suma": 0.0}
			por_golpe[golpe]["n"] += 1.0
			por_golpe[golpe]["alto_suma"] += float(r["alto"])
			if int(r["resultado"]) == 0:
				por_golpe[golpe]["gol"] += 1.0
			if golpe == "cabeza":
				continue
			remates["n"] += 1.0
			var alto := float(r["alto"])
			remates["raso" if alto < 0.5 else ("medio" if alto < 1.4 else "alto")] += 1.0
		for r in c.registro_pases():
			if bool(r["afuera"]):
				var t := int(r["tipo"])
				afuera_tipo[t] = float(afuera_tipo.get(t, 0.0)) + 1.0
	var f := func(clave: String) -> float: return float(k.get(clave, 0.0)) / float(partidos)
	print("[juego] D%d/D%d, %d partidos, semilla %d. Por partido." % [a + 1, b + 1, partidos, semilla])
	print("[juego] La pelota sale %.2f veces: de un pase %.2f, conduciendo %.2f, de un control %.2f, de un remate %.2f, de un rebote %.2f, otra %.2f" % [
		f.call("salidas"), f.call("salidas_pase"), f.call("salidas_conduce"), f.call("salidas_control"),
		f.call("salidas_remate"), f.call("salidas_rebote"), f.call("salidas_otra")])
	var tipos := ["de primera", "conducir", "pase", "al hueco", "largo", "centro", "pared", "despeje"]
	var texto := "[juego] Pases que salen sin que los toque nadie:"
	for t in afuera_tipo:
		texto += " %s %.2f" % [tipos[clampi(int(t), 0, tipos.size() - 1)], float(afuera_tipo[t]) / partidos]
	print(texto)
	var cp := maxf(float(k.get("conduce_pasos", 0.0)), 1.0)
	print("[juego] Conducción: %.1f toques, %.1f s con la pelota conducida; pelota a %.2f m de media del que la lleva, a más de 2,5 m el %.1f%% del tiempo (lo más lejos, %.1f m); corre al %.0f%% de su punta; se la quitan %.2f veces" % [
		f.call("conducciones"), cp / 60.0 / partidos, float(k.get("conduce_metros", 0.0)) / cp,
		100.0 * float(k.get("conduce_lejos", 0.0)) / cp, float(k.get("conduce_max_m", 0.0)),
		100.0 * float(k.get("conduce_corre", 0.0)) / cp, f.call("quites_conduccion")])
	var m := maxf(banda["muestras"], 1.0)
	print("[juego] Ataque por la banda en el último tercio: %.1f s por partido; en el área hay %.2f compañeros y %.2f rivales de campo; sin ningún compañero el %.0f%% del tiempo; a menos de 24 m del arco, %.2f compañeros" % [
		banda["muestras"] * CADA_PASOS / 60.0 / partidos, banda["compas"] / m, banda["rivales"] / m, 100.0 * banda["solo"] / m,
		banda["cerca"] / m])
	for t in [[2, "30 a 20 m"], [1, "20 a 10 m"], [0, "menos de 10 m"]]:
		var n_t := maxf(float(banda.get("t%d_n" % t[0], 0.0)), 1.0)
		print("[juego]   con la pelota a %s del fondo (%.1f s por partido): %.2f compañeros en el área; ninguno el %.0f%%" % [t[1],
			n_t * CADA_PASOS / 60.0 / partidos, float(banda.get("t%d_compas" % t[0], 0.0)) / n_t,
			100.0 * float(banda.get("t%d_solo" % t[0], 0.0)) / n_t])
	print("[juego] Centros en juego %.2f por partido: al salir hay %.2f compañeros en el área; ninguno en el %.0f%%. El que la lleva por la banda va a %.1f m/s: lateral %.0f%%, volante %.0f%%, enganche %.0f%%, extremo %.0f%%, 9 %.0f%%" % [
		banda["centros"] / partidos, banda["centro_compas"] / maxf(banda["centros"], 1.0),
		100.0 * banda["centro_solo"] / maxf(banda["centros"], 1.0), banda["rapidez"] / m, 100.0 * banda["rol_2"] / m, 100.0 * banda["rol_3"] / m,
		100.0 * banda["rol_4"] / m, 100.0 * banda["rol_5"] / m, 100.0 * banda["rol_6"] / m])
	var rn := maxf(remates["n"], 1.0)
	print("[juego] Remates de pie %.2f: rasos (apuntados a menos de 0,5 m) %.0f%%, a media altura %.0f%%, altos (más de 1,4 m) %.0f%%" % [
		remates["n"] / partidos, 100.0 * remates["raso"] / rn, 100.0 * remates["medio"] / rn, 100.0 * remates["alto"] / rn])
	for golpe in GOLPES:
		if por_golpe.has(golpe):
			var g: Dictionary = por_golpe[golpe]
			print("[juego]   %-9s %.2f por partido, gol %.0f%%, apunta a %.2f m de alto" % [golpe, g["n"] / partidos,
				100.0 * g["gol"] / g["n"], g["alto_suma"] / g["n"]])
	print("[juego] Cabeza: %.2f gestos, erra %.0f%%; cabezazos al arco %.2f (goles %.2f); centros %.2f; córners %.2f" % [
		f.call("gestos_cabeza"), 100.0 * float(k.get("fallos_cabeza", 0.0)) / maxf(float(k.get("gestos_cabeza", 0.0)), 1.0),
		f.call("remates_cabeza"), f.call("goles_cabeza"), float(k.get("centro", 0.0)) / partidos, f.call("paradas_corner")])
	# Cuánto se le va la pelota al que la tiene después de cada toque suyo.
	for tipo in ["control", "conduce"]:
		var total := 0.0
		for fr in 5:
			total += float(k.get("separa_%s_%d" % [tipo, fr], 0.0))
		var linea := "[juego] Después de un toque de %s (%.1f por partido), lo más lejos que se le va:" % [tipo, total / partidos]
		for fr in 5:
			var n_fr := float(k.get("separa_%s_%d" % [tipo, fr], 0.0))
			linea += " %s %.0f%% (pierde %.0f%%)" % [FRANJAS_M[fr], 100.0 * n_fr / maxf(total, 1.0),
				100.0 * float(k.get("pierde_%s_%d" % [tipo, fr], 0.0)) / maxf(n_fr, 1.0)]
		print(linea)
	print("[juego] El que la tiene corre a más del 90%% de su punta el %.0f%% del tiempo" % [
		100.0 * float(k.get("lleva_a_fondo", 0.0)) / maxf(float(k.get("lleva_pasos", 0.0)), 1.0)])
	# Qué decide según qué tan a tiro está el arco.
	for fr in 4:
		var total := 0.0
		for d in DECISIONES:
			total += float(kc.get("zona%d_%s" % [fr, d], 0.0))
		var linea := "[juego] Decisiones con el arco %s: %.1f por partido (con el remate entre las opciones %.0f%%):" % [
			FRANJAS_TIRO[fr], total / partidos, 100.0 * float(kc.get("zona%d_con_tiro" % fr, 0.0)) / maxf(total, 1.0)]
		for d in DECISIONES:
			var n_d := float(kc.get("zona%d_%s" % [fr, d], 0.0))
			if n_d > 0.0:
				linea += " %s %.0f%%" % [d, 100.0 * n_d / total]
		print(linea)
	for fr in 3:
		var total := 0.0
		for d in DECISIONES:
			total += float(k.get("libre%d_%s" % [fr, d], 0.0))
		var linea := "[juego] Sin rivales de campo entre él y el arco, %s: %.2f decisiones por partido:" % [FRANJAS_LIBRE[fr], total / partidos]
		for d in DECISIONES:
			var n_d := float(k.get("libre%d_%s" % [fr, d], 0.0))
			if n_d > 0.0:
				linea += " %s %.0f%%" % [d, 100.0 * n_d / total]
		print(linea)
	print("[juego] Después de una entrada que saca la pelota: la agarra el equipo del que entró %.2f, el otro %.2f, sale de la cancha %.2f; el que la llevaba cae %.2f" % [
		f.call("entrada_gana"), f.call("entrada_pierde"), f.call("entrada_afuera"), f.call("entradas_tumban")])
	print("[juego] Entradas %.2f: le sacan la pelota %.2f, falta %.2f, no tocan nada %.2f. Quites %.1f (a uno que conduce %.1f, a uno que la controló %.1f, pelota suelta %.1f)" % [
		f.call("entradas"), f.call("entradas_limpias"), f.call("faltas_entrada"),
		f.call("entradas") - f.call("entradas_limpias") - f.call("faltas_entrada"), f.call("quites"),
		f.call("quites_conduccion"), f.call("quites_control"), f.call("quites_suelta")])
	print("[juego] Goles %.2f, remates %.2f, pases %.1f (completos %.1f), quites %.1f, cortes %.1f" % [
		f.call("goles_0") + f.call("goles_1"), f.call("remates"), f.call("pases") - f.call("pases_despeje"),
		f.call("completados") + f.call("completados_otro"), f.call("quites"), f.call("cortes")])
	quit()


## Con la pelota controlada por la banda en el último tercio: cuántos
## compañeros del que la lleva y cuántos rivales de campo hay en el área.
func _mirar_banda(c: Object, banda: Dictionary) -> void:
	var poseedor := int(c.get_poseedor())
	if poseedor < 0 or str(c.get_estado()["parada"]) != "nada":
		return
	var pos: PackedVector2Array = c.get_pos()
	var equipos: PackedInt32Array = c.get_equipos()
	var equipo := int(equipos[poseedor])
	# El equipo 0 ataca hacia +x.
	var signo := 1.0 if equipo == 0 else -1.0
	var p := pos[poseedor]
	if absf(p.y) < BANDA_M or MEDIO_LARGO_M - p.x * signo > ULTIMO_TERCIO_M:
		return
	var compas := 0
	var rivales := 0
	var cerca := 0
	var arqueros: Array = c.get_arqueros() if c.has_method("get_arqueros") else []
	for i in pos.size():
		if i == poseedor or arqueros.has(i):
			continue
		var q := pos[i]
		if int(equipos[i]) == equipo and Vector2(MEDIO_LARGO_M - q.x * signo, q.y).length() <= CERCA_DEL_ARCO_M:
			cerca += 1
		if MEDIO_LARGO_M - q.x * signo <= AREA_LARGO_M and absf(q.y) <= AREA_MEDIO_ANCHO_M:
			if int(equipos[i]) == equipo:
				compas += 1
			else:
				rivales += 1
	# Por tramo: a 30-20 m del fondo, a 20-10 y a menos de 10. Lejos del
	# fondo el área vacía es normal (la línea del offside está afuera).
	var tramo := "t%d" % clampi(int((MEDIO_LARGO_M - p.x * signo) / 10.0), 0, 2)
	banda[tramo + "_n"] = float(banda.get(tramo + "_n", 0.0)) + 1.0
	banda[tramo + "_compas"] = float(banda.get(tramo + "_compas", 0.0)) + float(compas)
	if compas == 0:
		banda[tramo + "_solo"] = float(banda.get(tramo + "_solo", 0.0)) + 1.0
	banda["muestras"] += 1.0
	banda["rapidez"] += float(c.get_rapidez()[poseedor])
	var rol := "rol_%d" % int(c.get_roles()[poseedor])
	if banda.has(rol):
		banda[rol] += 1.0
	banda["compas"] += float(compas)
	banda["rivales"] += float(rivales)
	banda["cerca"] += float(cerca)
	if compas == 0:
		banda["solo"] += 1.0


## Cuántos compañeros de campo de `de` hay en el área rival.
func _en_el_area(c: Object, de: int) -> int:
	var pos: PackedVector2Array = c.get_pos()
	var equipos: PackedInt32Array = c.get_equipos()
	if de < 0 or de >= pos.size():
		return 0
	var signo := 1.0 if int(equipos[de]) == 0 else -1.0
	var n := 0
	for i in pos.size():
		if i != de and int(equipos[i]) == int(equipos[de]) and MEDIO_LARGO_M - pos[i].x * signo <= AREA_LARGO_M 				and absf(pos[i].y) <= AREA_MEDIO_ANCHO_M:
			n += 1
	return n


func _pisar(datos: Dictionary, texto: String) -> void:
	for par in texto.split(","):
		var kv := par.split(":")
		var clave := kv[0].split(".")
		datos[clave[0]][clave[1]] = float(kv[1])
		print("FISICA %s = %s" % [kv[0], kv[1]])
