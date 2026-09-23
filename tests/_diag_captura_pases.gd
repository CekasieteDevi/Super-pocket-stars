extends SceneTree

## Medición, no test. Captura con render real varios pases del partido
## guardado (fotogramas de _diag_curva_pases.gd) con la cámara fija. Arma
## una imagen estroboscópica: cada cuadro suma la pelota dibujada en ese
## instante, así la curva o la recta del pase se ve en una sola imagen.
const SEED := 0
const SUBPASOS := 8


func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	var ruta := "res://scratch/diag_curva_pases_fotogramas.bin"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bin="):
			ruta = "res://scratch/" + a.trim_prefix("bin=")
	var leer := FileAccess.open(ruta, FileAccess.READ)
	var lista: Array = leer.get_var()
	leer.close()
	root.size = Vector2i(1152, 648)
	var vista := VistaPartido.new()
	root.add_child(vista)
	vista.size = Vector2(1152, 648)
	vista.iniciar(lista, Color(0.85, 0.15, 0.15), Color(0.15, 0.3, 0.85))
	vista.set_process(false)
	var elegidos: Array = []
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.is_valid_int():
			elegidos.append(int(a))
	if elegidos.is_empty():
		for indice in vista._coreografia.contactos:
			var c: Dictionary = vista._coreografia.contactos[indice]
			if str(c["accion"]) == "patea" and elegidos.size() < 6 and int(indice) > 10:
				elegidos.append(int(indice))
	for indice in elegidos:
		await _capturar(vista, lista, indice)
	vista.free()
	quit()


func _capturar(vista: VistaPartido, lista: Array, indice: int) -> void:
	var desde := maxi(0, indice - 10)
	var hasta := mini(lista.size() - 2, indice + 2)
	var a := Vector2(lista[desde]["pelota"]["x"], lista[desde]["pelota"]["y"])
	var b := Vector2(lista[hasta]["pelota"]["x"], lista[hasta]["pelota"]["y"])
	var centro := (a + b) * 0.5
	var suma: Image = null
	var base: Image = null
	for i in range(desde, hasta):
		for s in range(SUBPASOS):
			vista._mostrar(i, float(s) / float(SUBPASOS))
			vista.vista.camara.saltar_a(centro, vista.size)
			vista.vista.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			if suma == null:
				suma = img.duplicate()
				base = img
				continue
			# Solo la pelota: se copia lo que el render dibujó alrededor de
			# donde la vista la ubica. Los jugadores quedan del primer cuadro.
			var centro_px := _punto_pelota(vista)
			if centro_px != Vector2.INF:
				var r := 9
				for y in range(maxi(0, int(centro_px.y) - r), mini(img.get_height(), int(centro_px.y) + r)):
					for x in range(maxi(0, int(centro_px.x) - r), mini(img.get_width(), int(centro_px.x) + r)):
						var c := img.get_pixel(x, y)
						if c.r > 0.85 and c.g > 0.85 and c.b > 0.85:
							suma.set_pixel(x, y, c)
			if s == 0 and i == indice - 1:
				img.save_png("res://scratch/verificado_pase_%d_golpe.png" % indice)
	suma.save_png("res://scratch/verificado_pase_%d_trazo.png" % indice)
	print("CAPTURA pase=%d ticks=%d-%d min=%.2f" % [indice, desde, hasta, float(lista[indice]["minuto"])])


static func _punto_pelota(vista: VistaPartido) -> Vector2:
	for ent in vista.vista.entidades:
		if ent["tipo"] != "pelota":
			continue
		var escala: float = vista.vista.camara.px_por_metro / CamaraPartido.PX_POR_METRO_BASE
		var punto: Vector2 = vista.vista._p(ent["pos"].x, ent["pos"].y, float(ent.get("z", 0.0)))
		punto += Vector2(ent.get("offset_px", Vector2.ZERO)) * escala
		if bool(ent.get("anclada", false)):
			punto = vista.vista._p(ent["pos"].x, ent["pos"].y) + Vector2(ent["anclaje_px"]) * escala
		return punto + vista.vista.global_position
	return Vector2.INF
