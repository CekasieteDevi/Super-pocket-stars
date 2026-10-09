extends SceneTree

## Vuelve a jugar el último partido seguido de un save y compara el marcador con
## el que quedó guardado. Uso (sobre una COPIA del save, nunca user://partida.json):
##   godot --headless --path <proyecto> --script res://tools/replay_partido.gd -- <ruta_save_copia>
## Salida: REPLAY (marcador rehecho), GUARDADO (marcador del save), IGUAL true/false.
## Código de salida: 0 igual, 1 distinto o error, 2 el save no trae receta.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("USO: replay_partido.gd -- <ruta_save_copia>")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		print("ERROR no se pudo abrir ", args[0])
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
	var pasos := 0
	while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
		c.simular(600)
		pasos += 600
	var g: PackedInt32Array = c.get_goles()
	var gl_guardado := int(ultimo.get("gl", -1))
	var gv_guardado := int(ultimo.get("gv", -1))
	var igual := int(g[0]) == gl_guardado and int(g[1]) == gv_guardado
	print("PARTIDO ", ultimo.get("local", "?"), " vs ", ultimo.get("visitante", "?"))
	print("REPLAY ", g[0], "-", g[1], " pasos=", pasos)
	print("GUARDADO ", gl_guardado, "-", gv_guardado)
	print("IGUAL ", igual)
	quit(0 if igual else 1)
