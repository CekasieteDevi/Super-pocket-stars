extends SceneTree

## ¿El saque de arco depende del arquero? Compara equipos identicos salvo
## por los atributos del arquero (pies/golpe), y mide que fraccion de las
## salidas llega a un companero.

const N := 40

func _init() -> void:
	print("Salidas del arquero que llegan a un companero, segun sus atributos:")
	for nivel in [20, 45, 70, 95]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		var propias := 0
		var total := 0
		for i in range(N):
			var h := Team.generar("H%d" % i, rng)
			var a := Team.generar("A%d" % i, rng, 1000)
			# Se le fija pies y golpe SOLO al arquero local.
			for j in h.jugadores:
				if j["posicion"] == "ARQ":
					j["atributos"]["pies"] = nivel
					j["atributos"]["golpe"] = nivel
			var r := MotorEspacial.simular(h, a, rng, true)
			var res := _contar(r["fotogramas"], true)
			propias += res[0]
			total += res[1]
		print("  pies/golpe %d -> %.0f%% completadas (%d salidas)" % [
			nivel, float(propias) / maxf(total, 1) * 100.0, total])
	quit()


func _contar(fotogramas: Array, local: bool) -> Array:
	var ok := 0
	var total := 0
	var esperando := false
	for f in fotogramas:
		var pid: int = int(f["pelota"]["poseedor_id"])
		if pid == -1:
			continue
		var rol := ""
		var es_local := false
		for j in f["jugadores"]:
			if int(j["id"]) == pid:
				rol = str(j["rol"])
				es_local = bool(j["equipo_local"])
				break
		if rol == "ARQ" and es_local == local:
			esperando = true
		elif esperando:
			total += 1
			if es_local == local:
				ok += 1
			esperando = false
	return [ok, total]
