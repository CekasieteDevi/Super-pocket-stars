extends SceneTree
func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PrototipoVista.SEMILLA
	var local := Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
	var visita := Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(0), "Uruguay", NivelDivision.realizacion(0))
	var r := MotorEspacial.simular(local, visita, rng, true)
	var fotos: Array = r["fotogramas"]
	print("resultado %d-%d" % [r["goles_local"], r["goles_visitante"]])
	for k in fotos.size():
		for e in fotos[k].get("eventos", []):
			if str(e.get("resultado", "")) == "gol":
				var fest := []
				for q in range(k, mini(k + 12, fotos.size())):
					for a in fotos[q].get("acciones", []):
						if str(a["accion"]) == "festeja" and not fest.has(int(a["clave"])): fest.append(int(a["clave"]))
				var ultimo := -1
				for q in range(k - 1, maxi(0, k - 10), -1):
					for a in fotos[q].get("acciones", []):
						if str(a["accion"]) in ["patea", "cabecea", "volea", "chilena", "palomita"]: ultimo = int(a["clave"]); break
					if ultimo != -1: break
				print("GOL tick %d min %s tipo=%s clave_evento=%s ultimo_remate=%s festejan=%s grupo=%s" % [k, str(int(fotos[k].get("minuto", 0))), str(e.get("tipo", "")), str(e.get("clave", "")), str(ultimo), str(fest), str(e.get("festejo", ""))])
	quit()
