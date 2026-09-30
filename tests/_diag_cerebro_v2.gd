extends SceneTree

## Medición de la etapa 4 del Motor V2 (docs/motor_v2.md): 11 contra 11 sin
## arqueros ni reglas, varias semillas, sin vista. Imprime lo que pide el
## "Pasa si" (posesiones, bloques, pases al espacio) y los detectores de la
## etapa 3.
##   <godot> --path . --headless --script tests/_diag_cerebro_v2.gd -- segundos=600 semillas=3

const SEED := 20261002
const MUESTRA_SEG := 0.5


func _init() -> void:
	var segundos := 600.0
	var semillas := 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("segundos="):
			segundos = float(arg.get_slice("=", 1))
		if arg.begins_with("semillas="):
			semillas = int(arg.get_slice("=", 1))
	for s in semillas:
		var c := CerebroV2.armar_partido(SEED + s)
		var m := medir(c, segundos)
		imprimir(SEED + s, segundos, c, m)
	quit()


## Corre el partido y junta las muestras de los bloques.
static func medir(c: Object, segundos: float) -> Dictionary:
	var pasos_muestra := int(MUESTRA_SEG * 60.0)
	var muestras := int(segundos / MUESTRA_SEG)
	var roles: PackedInt32Array = c.get_roles()
	var equipos: PackedInt32Array = c.get_equipos()
	var bola_x := []
	var bola_z := []
	var bloque_x := [[], []]
	var bloque_z := [[], []]
	var def_x := []
	var def_bloque_x := []
	var def_bola_z := []
	var def_bloque_z := []
	var dispersion_linea := 0.0
	var muestras_linea := 0
	var dura := 0.0
	for k in muestras:
		dura += c.simular(pasos_muestra)
		var pos: PackedVector2Array = c.get_pos()
		var b: Vector3 = c.get_pelota_pos()
		bola_x.append(b.x)
		bola_z.append(b.z)
		var suma := [Vector2.ZERO, Vector2.ZERO]
		var cuantos := [0, 0]
		for i in pos.size():
			if roles[i] == 0:
				continue
			suma[equipos[i]] += pos[i]
			cuantos[equipos[i]] += 1
		for e in 2:
			var centro: Vector2 = suma[e] / maxf(float(cuantos[e]), 1.0)
			bloque_x[e].append(centro.x)
			bloque_z[e].append(centro.y)
		# El bloque que defiende, y su línea de atrás.
		var defiende: int = 1 - int(c.get_equipo_con_pelota())
		var centro_d: Vector2 = suma[defiende] / maxf(float(cuantos[defiende]), 1.0)
		def_x.append(b.x)
		def_bloque_x.append(centro_d.x)
		def_bola_z.append(b.z)
		def_bloque_z.append(centro_d.y)
		var xs := []
		for i in pos.size():
			if equipos[i] == defiende and (roles[i] == 1 or roles[i] == 2):
				xs.append(pos[i].x)
		if xs.size() >= 3:
			dispersion_linea += desvio(xs)
			muestras_linea += 1
	return {
		"dura": dura,
		"corr_x": [correlacion(bola_x, bloque_x[0]), correlacion(bola_x, bloque_x[1])],
		"corr_z": [correlacion(bola_z, bloque_z[0]), correlacion(bola_z, bloque_z[1])],
		"corr_def_x": correlacion(def_x, def_bloque_x),
		"corr_def_z": correlacion(def_bola_z, def_bloque_z),
		"dispersion_linea": dispersion_linea / maxf(float(muestras_linea), 1.0),
	}


static func imprimir(semilla: int, segundos: float, c: Object, m: Dictionary) -> void:
	var k: Dictionary = c.contadores()
	var d: Dictionary = c.contadores_cerebro()
	var minutos := segundos / 60.0
	var pases: float = maxf(k["pases"], 1.0)
	print("[diag_cerebro] semilla %d, %.0f s, %.2f µs/paso" % [semilla, segundos, m["dura"] * 1e6 / (segundos * 60.0)])
	print("[diag_cerebro]   posesiones %d  pases/posesión %.2f  con 3+ %d  con 5+ %d  máx %d" % [k["posesiones"],
		float(k["pases_en_posesiones"]) / maxf(k["posesiones"], 1.0), k["posesiones_3_pases"],
		k["posesiones_5_pases"], k["max_pases_posesion"]])
	print("[diag_cerebro]   pases/min %.1f  completos %.0f%%  cortados %.0f%%  afuera %.0f%%  globos %.0f%%  de primera %.0f%%" % [
		k["pases"] / minutos, 100.0 * (k["completados"] + k["completados_otro"]) / pases,
		100.0 * k["cortes"] / pases, 100.0 * k["pases_afuera"] / pases, 100.0 * k["pases_globo"] / pases,
		100.0 * k["de_primera"] / pases])
	print("[diag_cerebro]   al espacio %d (%d completos)  a corrida preparada %d  paredes devueltas %d  offsides %d" % [
		k["pases_al_espacio"], k["pases_al_espacio_completos"], k["pases_a_corrida"], k["paredes_devueltas"],
		k["offsides"]])
	print("[diag_cerebro]   quites: de conducción %d  de control %d  sueltas %d" % [k["quites_conduccion"], k["quites_control"], k["quites_suelta"]])
	print("[diag_cerebro]   llegadas %d-%d  laterales %d  córners %d  saques de arco %d  quites/min %.1f  posesión %.0f%%-%.0f%%" % [
		k["llegadas_0"], k["llegadas_1"], k["laterales"], k["corners"], k["saques_de_arco"], k["quites"] / minutos,
		100.0 * k["posesion_0"] / maxf(k["posesion_0"] + k["posesion_1"], 0.01),
		100.0 * k["posesion_1"] / maxf(k["posesion_0"] + k["posesion_1"], 0.01)])
	print("[diag_cerebro]   decisiones %s" % [d])
	print("[diag_cerebro]   bloques: corr x %.2f / %.2f  corr z %.2f / %.2f  (el que defiende: x %.2f  z %.2f)  línea de atrás ±%.1f m" % [
		m["corr_x"][0], m["corr_x"][1], m["corr_z"][0], m["corr_z"][1], m["corr_def_x"], m["corr_def_z"],
		m["dispersion_linea"]])
	print("[diag_cerebro]   correcciones %d  saltos_pelota %d  frenadas_en_seco %d  peor salto cuerpo %.3f m  espera media %.3f s" % [
		k["correcciones"], k["saltos_pelota"], k["frenadas_en_seco"], k["peor_salto_cuerpo_m"], k["espera_media"]])


static func correlacion(a: Array, b: Array) -> float:
	var n := mini(a.size(), b.size())
	if n < 2:
		return 0.0
	var ma := 0.0
	var mb := 0.0
	for i in n:
		ma += a[i]
		mb += b[i]
	ma /= n
	mb /= n
	var sab := 0.0
	var saa := 0.0
	var sbb := 0.0
	for i in n:
		sab += (a[i] - ma) * (b[i] - mb)
		saa += (a[i] - ma) * (a[i] - ma)
		sbb += (b[i] - mb) * (b[i] - mb)
	if saa <= 0.0 or sbb <= 0.0:
		return 0.0
	return sab / sqrt(saa * sbb)


static func desvio(xs: Array) -> float:
	var m := 0.0
	for x in xs:
		m += x
	m /= xs.size()
	var s := 0.0
	for x in xs:
		s += (x - m) * (x - m)
	return sqrt(s / xs.size())
