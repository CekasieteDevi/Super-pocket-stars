extends SceneTree

## Busca una lesion en partidos completos del motor espacial y recorre la
## misma VistaPartido que usa la UI. No acepta una textura suelta: exige
## evento, pose lesionado y cambio del jugador en la grabacion real.
const INTENTOS := 120


func _init() -> void:
	call_deferred("_probar")


func _probar() -> void:
	for semilla in range(INTENTOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = 81000 + semilla
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		# El partido sigue siendo real; solo se sube la propension para que la
		# verificacion no dependa de acertar una lesion rara por azar.
		for equipo in [casa, visita]:
			for j in equipo.todos_los_jugadores():
				j["propension_lesion"] = 100
		var r := MotorEspacial.simular(casa, visita, rng, true)
		var lesion := {}
		var indice_lesion := -1
		# Una lesión después de la ventana 75' sigue siendo válida para el
		# partido, pero no puede tener sustitución antes del pitazo. Buscar otra
		# lesión evita que ese caso tardío vuelva azarosa la verificación.
		for candidata in r.get("eventos", []):
			if str(candidata.get("tipo", "")) != "lesion":
				continue
			var clave_candidata := int(candidata.get("clave", -1))
			var tiene_accion := false
			var indice_accion := -1
			for indice_f in range(r["fotogramas"].size()):
				var f: Dictionary = r["fotogramas"][indice_f]
				for a in f.get("acciones", []):
					if int(a.get("clave", -1)) == clave_candidata \
							and str(a.get("accion", "")) == "lesionado":
						tiene_accion = true
						indice_accion = indice_f
						break
				if tiene_accion:
					break
			var tiene_cambio := false
			for ev_cambio in r.get("eventos", []):
				if str(ev_cambio.get("tipo", "")) == "cambio" \
						and int(ev_cambio.get("saliente_id", -1)) == int(candidata.get("jugador_id", -1)):
					tiene_cambio = true
					break
			if tiene_accion and tiene_cambio:
				lesion = candidata
				indice_lesion = indice_accion
				break
		if lesion.is_empty():
			continue
		var clave := int(lesion.get("clave", -1))
		var saliente_id := int(lesion.get("jugador_id", -1))
		var entrante_id := -1
		for ev_cambio in r.get("eventos", []):
			if str(ev_cambio.get("tipo", "")) == "cambio" \
					and int(ev_cambio.get("saliente_id", -1)) == saliente_id:
				entrante_id = int(ev_cambio.get("entrante_id", -1))
				break
		var salio := false
		var entro := false
		var indice_cambio := -1
		for indice_f in range(r["fotogramas"].size()):
			var f: Dictionary = r["fotogramas"][indice_f]
			var hay_saliente := false
			for j in f.get("jugadores", []):
				if int(j.get("jugador_id", -1)) == saliente_id:
					hay_saliente = true
				if int(j.get("jugador_id", -1)) == entrante_id:
					entro = true
			if entro and not hay_saliente:
				salio = true
				indice_cambio = indice_f
				break
		if not salio or not entro or indice_lesion < 0 or indice_cambio < 0:
			continue
		var vista := VistaPartido.new()
		root.add_child(vista)
		vista.iniciar(r["fotogramas"], Color("2c8ed1"), Color("d14c4c"),
			casa.nombre, visita.nombre, VistaPartido.construir_nombres(casa, visita))
		vista.set_process(false)
		for i in range(r["fotogramas"].size()):
			vista._mostrar(i, 0.5)
			if "capturar" in OS.get_cmdline_user_args() \
					and i in [indice_lesion + 2, indice_cambio]:
				vista._seguir_camara(i, 0.0625)
				await process_frame
				await RenderingServer.frame_post_draw
				var etiqueta := "caida" if i == indice_lesion + 2 else "sustitucion"
				root.get_texture().get_image().save_png(
					"res://scratch/verificado_lesion_partido_%s.png" % etiqueta)
		print("OK: partido real con lesion, pose PNG y sustitucion; semilla %d, caida f%d, sustitucion f%d." % [
			81000 + semilla, indice_lesion, indice_cambio])
		vista.free()
		quit()
		return
	print("FALLA: no aparecio una lesion en %d partidos controlados." % INTENTOS)
	quit(1)
