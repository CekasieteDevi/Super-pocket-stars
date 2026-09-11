extends SceneTree

func _init() -> void:
	call_deferred("_probar")

func _probar() -> void:
	for estado in ["potrero", "regular", "hibrido"]:
		var malla := VistaCancha._malla_desgaste(estado)
		assert(malla == VistaCancha._malla_desgaste(estado))
		var cantidad := 180 if estado == "potrero" else (70 if estado == "regular" else 24)
		assert(malla.surface_get_array_len(0) == cantidad * 4)
		assert(malla.surface_get_array_index_len(0) == cantidad * 6)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1978
		var minimo := Vector2(INF, INF)
		var maximo := Vector2(-INF, -INF)
		for i in range(cantidad):
			var centro := Vector2.ZERO
			if i % 3 != 0:
				centro.x = (ProyeccionPartido.MEDIO_LARGO - 4.0) * (-1.0 if i % 2 == 0 else 1.0)
			var pos := centro + Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-8.0, 8.0))
			var ancho := rng.randf_range(0.15, 0.65)
			minimo = minimo.min(pos)
			maximo = maximo.max(pos + Vector2(ancho, 0.15))
		var caja := malla.get_aabb()
		assert(Vector2(caja.position.x, caja.position.y).is_equal_approx(minimo))
		assert(Vector2(caja.end.x, caja.end.y).is_equal_approx(maximo))
	var vista := VistaCancha.new()
	root.add_child(vista)
	vista.size = Vector2(1280, 720)
	for estado in ["potrero", "regular", "hibrido"]:
		vista.estado_cancha = estado
		vista.queue_redraw()
		await process_frame
	vista.free()
	print("OK: tres canchas, misma geometria, mallas reutilizadas y dibujo ejecutado")
	quit()
