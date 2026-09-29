extends SceneTree
func _initialize() -> void:
	var m: Node3D = (load("res://assets/3d/golero.glb") as PackedScene).instantiate()
	var ap: AnimationPlayer = m.find_children("*", "AnimationPlayer", true, false)[0]
	for nombre in ["Atajar_Volando", "Atajar_Volando_Izq", "Golero_Guardia", "Respirar"]:
		if not ap.has_animation(nombre): continue
		var an := ap.get_animation(nombre)
		var s: String = nombre + ": "
		for i in 13:
			var tt := an.length * i / 12.0
			s += "%.2f%s " % [tt, str(an.position_track_interpolate(0, tt))]
		print(s)
	quit()
