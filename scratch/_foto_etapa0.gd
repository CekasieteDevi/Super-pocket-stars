extends SceneTree
## Foto del banco de la etapa 0 con vista, a los 4 s: `-- salida=ruta.png`.
var _n := 0
var _salida := "user://foto_etapa0.png"
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("salida="):
			_salida = a.trim_prefix("salida=")
	root.add_child((load("res://motor_v2/banco_etapa0.tscn") as PackedScene).instantiate())
	process_frame.connect(_cuadro)
func _cuadro() -> void:
	_n += 1
	if _n == 240:
		root.get_texture().get_image().save_png(_salida)
		quit()
