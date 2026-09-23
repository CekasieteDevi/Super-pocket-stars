extends SceneTree

## Solo lectura del guardado. Simula en memoria el mismo boton Jugar fecha.
## Traza acciones y sprites del poseedor al comienzo del partido.
func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	var gs := root.get_node("GameState")
	assert(gs.hay_partida_guardada())
	assert(gs.cargar_partida())
	gs.jugar_siguiente_fecha()
	var lista: Array = gs.ultimos_fotogramas
	assert(not lista.is_empty())
	var conteo := {}
	for f in lista:
		for a in f.get("acciones", []):
			if MotorEspacial.es_accion_regate(str(a["accion"])):
				conteo[a["accion"]] = int(conteo.get(a["accion"], 0)) + 1
	print("REGATES_PARTIDO_COMPLETO ", conteo)
	var archivo := FileAccess.open("res://scratch/diag_guardado_fotogramas.bin", FileAccess.WRITE)
	archivo.store_var(lista)
	archivo.close()
	var vista := VistaPartido.new()
	root.add_child(vista)
	vista.iniciar(lista, Color.RED, Color.BLUE)
	vista.set_process(false)
	if "capturar" in OS.get_cmdline_user_args():
		root.size = Vector2i(1152, 648)
		for i in range(45):
			vista._mostrar(i, 0.0)
			vista._seguir_camara(i, 0.25)
			await process_frame
			await RenderingServer.frame_post_draw
			if i >= 29:
				root.get_texture().get_image().save_png("res://scratch/diag_regate_%02d.png" % i)
	var ultima := ""
	for i in range(mini(180, lista.size())):
		var f: Dictionary = lista[i]
		vista._mostrar(i, 0.0)
		for n in range(f["jugadores"].size()):
			var j: Dictionary = f["jugadores"][n]
			if int(j["jugador_id"]) != 924:
				continue
			var ent: Dictionary = vista.vista.entidades[n]
			var accion := str(ent["accion"])
			var indice := AtlasJugadores.cuadro(accion, float(ent["fase_animacion"]),
				int(ent["direccion"]), ent["pose"] in [SpritesPartido.CORRE_A, SpritesPartido.CORRE_B])
			var firma := "%s/%s/%d" % [accion, ent["pose"], indice]
			if firma != ultima or MotorEspacial.es_accion_regate(accion):
				print("OCAMPO tick=%d min=%.2f accion=%s pose=%s atlas=%d fase=%.3f z=%.3f pos=%s acciones=%s" % [
					i, f["minuto"], accion, ent["pose"], indice, ent["fase_animacion"],
					ent["z"], ent["pos"], f.get("acciones", [])])
			ultima = firma
	vista.free()
	quit()
