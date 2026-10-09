extends SceneTree

## Vuelve a jugar el último partido seguido de un save y compara el marcador con
## el que quedó guardado. Uso (sobre una COPIA del save, nunca user://partida.json):
##   godot --headless --path <proyecto> --script res://tools/replay_partido.gd -- <ruta_save_copia> [--resumen] [--pasos=A-B | --minuto=M[,margen]]
## Salida: REPLAY (marcador rehecho), GUARDADO (marcador del save), IGUAL true/false.
## Con --resumen: salidas por tipo (clasificador) y, desde la traza de cada paso,
## cuántos pasos quedaron con cada decisión y cada motivo. Son dos medidas distintas:
## DECISIONES_ELEGIDAS cuenta cada vez que el cerebro eligió (contadores_cerebro);
## PASOS_POR_DECISION cuenta pasos con la decisión vigente del poseedor (traza).
## Con --pasos=A-B: una línea por paso entre A y B.
## Con --minuto=M: una línea por paso cuyo minuto del reloj mostrado está en
## [M - margen, M + margen] (margen por defecto 1 minuto). El minuto sale de
## get_estado()["minuto"] en cada paso, así que no hace falta convertir pasos.
## Cada línea: paso, minuto, pelota, poseedor, decisión, acción, motivo, dirección,
## rapidez y distancia a la raya.
## Código de salida: 0 igual, 1 distinto o error, 2 el save no trae receta.

const DECISIONES := ["nada", "conducir", "pase", "pase_hueco", "pase_largo", "centro",
	"pared", "despeje", "remate", "regate"]
const TIPOS_SALIDA := ["pase", "conduce", "control", "remate", "rebote", "otra"]
const MINUTO_MARGEN_POR_DEFECTO := 1.0
const PASOS_MAXIMOS := 60 * 60 * 20

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var resumen := args.has("--resumen")
	var ventana := _leer_ventana(args)
	var minuto := _leer_minuto(args)
	var pidio_rango := false
	for a in args:
		if a.begins_with("--pasos=") or a.begins_with("--minuto="):
			pidio_rango = true
	if pidio_rango and (ventana.is_empty() == minuto.is_empty()):
		print("ERROR usar solo uno: --pasos=A-B o --minuto=M[,margen], bien escritos")
		quit(1)
		return
	var rutas: Array[String] = []
	for a in args:
		if not a.begins_with("--"):
			rutas.append(a)
	if rutas.is_empty():
		print("ERROR falta la ruta del save")
		quit(1)
		return
	var file := FileAccess.open(rutas[0], FileAccess.READ)
	if file == null:
		print("ERROR no se pudo abrir ", rutas[0])
		quit(1)
		return
	var texto := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(texto) != OK:
		print("ERROR el save no es JSON valido")
		quit(1)
		return
	var datos: Dictionary = json.data
	var ultimo: Dictionary = datos.get("ultimo_resultado", {})
	var texto_receta := str(ultimo.get("receta", ""))
	var receta: Dictionary = str_to_var(texto_receta) if texto_receta != "" else {}
	if receta.is_empty():
		print("SIN_RECETA el save no trae la receta del ultimo partido seguido")
		quit(2)
		return
	var c: Object = CerebroV2.armar_de_receta(receta)
	# Antes de simular: la traza solo guarda los pasos que corren con ella encendida.
	c.activar_traza(resumen or pidio_rango)
	# Un paso por vez: así hay una fila de traza por paso y `pasos` es exacto.
	# El minuto de cada paso se guarda por número de paso, para filtrar por minuto.
	var minutos := {}
	var pasos := 0
	var est: Dictionary = c.get_estado()
	minutos[int(est["paso"])] = float(est["minuto"])
	while str(est["periodo"]) != "terminado" and pasos < PASOS_MAXIMOS:
		c.simular(1)
		pasos += 1
		est = c.get_estado()
		minutos[int(est["paso"])] = float(est["minuto"])
	var g: PackedInt32Array = c.get_goles()
	var gl_guardado := int(ultimo.get("gl", -1))
	var gv_guardado := int(ultimo.get("gv", -1))
	var igual := int(g[0]) == gl_guardado and int(g[1]) == gv_guardado
	print("PARTIDO ", ultimo.get("local", "?"), " vs ", ultimo.get("visitante", "?"))
	print("REPLAY ", g[0], "-", g[1], " pasos=", pasos)
	print("GUARDADO ", gl_guardado, "-", gv_guardado)
	print("IGUAL ", igual)
	if resumen:
		_imprimir_resumen(c, pasos)
	if pidio_rango:
		_imprimir_filas(c, minutos, ventana, minuto)
	quit(0 if igual else 1)


## "--pasos=A-B" → [A, B]. Vacío si no se pidió o está mal escrito.
func _leer_ventana(args: PackedStringArray) -> Array[int]:
	var salida: Array[int] = []
	for a in args:
		if a.begins_with("--pasos="):
			var partes := a.trim_prefix("--pasos=").split("-")
			if partes.size() == 2 and partes[0].is_valid_int() and partes[1].is_valid_int():
				salida.append(int(partes[0]))
				salida.append(int(partes[1]))
	return salida


## "--minuto=M" o "--minuto=M,margen" → [M - margen, M + margen]. Vacío si no se pidió.
func _leer_minuto(args: PackedStringArray) -> Array[float]:
	var salida: Array[float] = []
	for a in args:
		if a.begins_with("--minuto="):
			var partes := a.trim_prefix("--minuto=").split(",")
			if partes.size() < 1 or partes.size() > 2 or not partes[0].is_valid_float():
				continue
			var margen := MINUTO_MARGEN_POR_DEFECTO
			if partes.size() == 2:
				if not partes[1].is_valid_float():
					continue
				margen = float(partes[1])
			var m := float(partes[0])
			salida.append(m - margen)
			salida.append(m + margen)
	return salida


## Una línea por fila de traza que cae en el rango de pasos y/o de minuto pedido.
func _imprimir_filas(c: Object, minutos: Dictionary, rango_paso: Array[int], rango_min: Array[float]) -> void:
	var filas: Array = c.get_traza()
	if not rango_paso.is_empty():
		print("VENTANA pasos ", rango_paso[0], "-", rango_paso[1])
	if not rango_min.is_empty():
		print("VENTANA minutos ", "%.2f" % rango_min[0], "-", "%.2f" % rango_min[1])
	var n := 0
	for f in filas:
		var paso := int(f["paso"])
		var minuto := float(minutos.get(paso, -1.0))
		if not rango_paso.is_empty() and (paso < rango_paso[0] or paso > rango_paso[1]):
			continue
		if not rango_min.is_empty() and (minuto < rango_min[0] or minuto > rango_min[1]):
			continue
		var p: Vector3 = f["pelota"]
		var dir: Vector2 = f["direccion"]
		print("paso=%d min=%.2f pelota=(%.1f, %.2f, %.1f) poseedor=%d decision=%s accion=%s motivo=%s dir=(%.2f, %.2f) rapidez=%.1f raya=%.1f" % [
			paso, minuto, p.x, p.y, p.z, int(f["poseedor"]),
			str(f["decision"]).trim_prefix("DEC_").to_lower(),
			str(f["accion"]).trim_prefix("TOQUE_").to_lower(),
			str(f["motivo"]).trim_prefix("MOTIVO_").to_lower(),
			dir.x, dir.y, float(f["rapidez"]), float(f["raya_m"])])
		n += 1
	print("FILAS ", n)


func _imprimir_resumen(c: Object, pasos: int) -> void:
	var k: Dictionary = c.contadores()
	if not k.has("salidas"):
		print("SALIDAS FALTA: contadores() no trae 'salidas'; no se puede verificar")
	else:
		var partes := []
		var suma := 0
		for t in TIPOS_SALIDA:
			var n := int(k.get("salidas_" + t, 0))
			suma += n
			partes.append("%s=%d" % [t, n])
		var total := int(k.get("salidas", 0))
		print("SALIDAS total=", total, " ", " ".join(partes), " suma_ok=", suma == total)

	var cd: Dictionary = c.contadores_cerebro()
	var dec := []
	for d in DECISIONES:
		dec.append("%s=%d" % [d, int(cd.get(d, 0))])
	print("DECISIONES_ELEGIDAS ", " ".join(dec))

	var filas: Array = c.get_traza()
	var por_decision := {}
	var por_motivo := {}
	var con_poseedor := 0
	for f in filas:
		var d := str(f["decision"]).trim_prefix("DEC_").to_lower()
		por_decision[d] = int(por_decision.get(d, 0)) + 1
		var m := str(f["motivo"]).trim_prefix("MOTIVO_").to_lower()
		por_motivo[m] = int(por_motivo.get(m, 0)) + 1
		if int(f["poseedor"]) >= 0:
			con_poseedor += 1
	print("TRAZA pasos=", pasos, " filas=", filas.size(), " coincide=", filas.size() == pasos,
		" con_poseedor=", con_poseedor, " build=", c.get_build_id())
	print("PASOS_POR_DECISION ", _texto_conteos(por_decision))
	print("PASOS_POR_MOTIVO ", _texto_conteos(por_motivo))


func _texto_conteos(conteos: Dictionary) -> String:
	var claves := conteos.keys()
	claves.sort()
	var partes := []
	for k in claves:
		partes.append("%s=%d" % [k, conteos[k]])
	return " ".join(partes)
