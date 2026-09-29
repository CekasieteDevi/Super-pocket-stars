extends SceneTree
## Resumen de lo que hace el arquero con la pelota en N partidos: -- division=N partidos=M
func _initialize() -> void:
	var division := 0
	var partidos := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("division="): division = int(a.trim_prefix("division=")) - 1
		if a.begins_with("partidos="): partidos = int(a.trim_prefix("partidos="))
	var cuenta := {}
	var muestra := OS.get_cmdline_user_args().has("muestra")
	if muestra:
		var fisica: Dictionary = MotorEspacial.pesos()["fisica"]
		for c in MuestraAnimaciones3D.FISICA_DE_LA_MUESTRA: fisica[c] = MuestraAnimaciones3D.FISICA_DE_LA_MUESTRA[c]
	for n in partidos:
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var local: Team
		var visita: Team
		if muestra:
			local = Team.generar("Atlético Prueba", rng)
			visita = Team.generar("Deportivo Banco", rng, 1000)
		else:
			local = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
			visita = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay", NivelDivision.realizacion(division))
		var fs: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		var arqs := {}
		for j in fs[0]["jugadores"]:
			if str(j.get("rol", "")) == "ARQ": arqs[int(j["id"])] = true
		var desde := -1
		var dueno := -1
		for k in fs.size():
			var f: Dictionary = fs[k]
			for e in f.get("eventos", []):
				if str(e.get("tipo", "")) == "saque_arco":
					cuenta["evento_saque_arco"] = int(cuenta.get("evento_saque_arco", 0)) + 1
			for a in f.get("acciones", []):
				if arqs.has(int(a["clave"])):
					var nombre := "acc_" + str(a["accion"])
					if int(f.get("detenido", 0)) > 0 or (k > 0 and int(fs[k-1].get("detenido", 0)) > 0):
						nombre += "_parado"
					cuenta[nombre] = int(cuenta.get(nombre, 0)) + 1
					if nombre == "acc_saque_arco_parado":
						var j := VistaPartido._jugador_en(f, int(a["clave"]))
						var jp := VistaPartido._jugador_en(fs[k-3], int(a["clave"]))
						print("partido %d: saque de arco tick %d, arquero a %.1f m de la pelota (3 ticks antes a %.1f m)" % [n, k,
							Vector2(j["x"], j["y"]).distance_to(Vector2(f["pelota"]["x"], f["pelota"]["y"])),
							Vector2(jp["x"], jp["y"]).distance_to(Vector2(fs[k-3]["pelota"]["x"], fs[k-3]["pelota"]["y"]))])
			var p := int(f["pelota"].get("poseedor_id", -1))
			if p != dueno:
				if arqs.has(dueno):
					var como := "suelta"
					for a in f.get("acciones", []) + fs[k-1].get("acciones", []):
						if int(a["clave"]) == dueno and str(a["accion"]) != "agarra": como = str(a["accion"])
					var parado := int(fs[desde].get("detenido", 0)) > 0
					print("partido %d: ARQ tuvo %d ticks (%d-%d) %s -> %s, pase %s, viaja %.1f m en 4 ticks" % [n, k - desde, desde, k,
						"PARADO" if parado else "juego", como, str(f["pelota"].get("es_pase", false)),
						Vector2(fs[mini(k+4, fs.size()-1)]["pelota"]["x"], fs[mini(k+4, fs.size()-1)]["pelota"]["y"]).distance_to(Vector2(f["pelota"]["x"], f["pelota"]["y"]))])
				dueno = p
				desde = k
	print("CUENTA ", cuenta)
	quit()
