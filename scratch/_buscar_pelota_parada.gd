extends SceneTree
## Busca en partidos simulados: tarjetas, offside, corner, tiro libre directo
## (con barrera) y cambios. Imprime semilla + n y tick de cada uno.
func _initialize() -> void:
	var hallados := {}
	for n in range(0, 12):
		var rng := RandomNumberGenerator.new()
		rng.seed = PrototipoVista.SEMILLA + n
		var local := Team.generar("Atlético Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var fotos: Array = MotorEspacial.simular(local, visita, rng, true)["fotogramas"]
		for k in fotos.size():
			var f: Dictionary = fotos[k]
			for ev in f.get("eventos", []):
				var tipo := str(ev.get("tipo", ""))
				var extra := ""
				if tipo == "tarjeta":
					tipo = "tarjeta_" + str(ev.get("resultado", "amarilla"))
				elif tipo == "falta":
					extra = str(ev.get("tiro_libre", ev.get("subtipo", "")))
				if tipo in ["tarjeta_amarilla", "tarjeta_roja", "offside", "corner", "falta"]:
					var llave := tipo
					if not hallados.has(llave): hallados[llave] = []
					if (hallados[llave] as Array).size() < 4:
						hallados[llave].append("s+%d t%d %s" % [n, k, extra])
			if not f.get("cambios", []).is_empty() and (k == 0 or fotos[k - 1].get("cambios", []).is_empty()):
				if not hallados.has("cambio"): hallados["cambio"] = []
				if (hallados["cambio"] as Array).size() < 4:
					hallados["cambio"].append("s+%d t%d" % [n, k])
			var ult: Dictionary = f.get("decision", {}) if f.get("decision") is Dictionary else {}
	for llave in hallados:
		print("HALLADO %s: %s" % [llave, ", ".join(hallados[llave])])
	quit()
