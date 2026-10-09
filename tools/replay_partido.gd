extends SceneTree

## Vuelve a jugar el último partido seguido de un save y compara el marcador con
## el que quedó guardado. Uso (sobre una COPIA del save, nunca user://partida.json):
##   godot --headless --path <proyecto> --script res://tools/replay_partido.gd -- <ruta_save_copia> [--resumen]
## Salida: REPLAY (marcador rehecho), GUARDADO (marcador del save), IGUAL true/false.
## Con --resumen: salidas por tipo (clasificador) y, desde la traza de cada paso,
## cuántos pasos quedaron con cada decisión y cada motivo. Son dos medidas distintas:
## DECISIONES_ELEGIDAS cuenta cada vez que el cerebro eligió (contadores_cerebro);
## PASOS_POR_DECISION cuenta pasos con la decisión vigente del poseedor (traza).
## Código de salida: 0 igual, 1 distinto o error, 2 el save no trae receta.

const DECISIONES := ["nada", "conducir", "pase", "pase_hueco", "pase_largo", "centro",
	"pared", "despeje", "remate", "regate"]
const TIPOS_SALIDA := ["pase", "conduce", "control", "remate", "rebote", "otra"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var resumen := args.has("--resumen")
	var rutas: Array[String] = []
	for a in args:
		if a != "--resumen":
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
	c.activar_traza(resumen)
	# Un paso por vez: así hay una fila de traza por paso y `pasos` es exacto.
	var pasos := 0
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
		c.simular(1)
		pasos += 1
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
	quit(0 if igual else 1)


func _imprimir_resumen(c: Object, pasos: int) -> void:
	var k: Dictionary = c.contadores()
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
