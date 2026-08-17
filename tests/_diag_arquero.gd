extends SceneTree

## ¿El arquero siempre se la da a los defensas, o elige? Instrumenta a
## quien le llega la pelota que sale del arquero, separando si la recibe un
## companero o si la intercepta un rival.

const N := 30

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var por_rol := {}
	var propios := 0
	var perdidas := 0
	for i in range(N):
		var h := Team.generar("H%d" % i, rng)
		var a := Team.generar("A%d" % i, rng, 1000)
		var r := MotorEspacial.simular(h, a, rng, true)
		var esperando := false
		var equipo_arquero := false
		for f in r["fotogramas"]:
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
			if rol == "ARQ":
				esperando = true
				equipo_arquero = es_local
			elif esperando:
				if es_local == equipo_arquero:
					por_rol[rol] = por_rol.get(rol, 0) + 1
					propios += 1
				else:
					perdidas += 1
				esperando = false

	var total := propios + perdidas
	print("Salidas del arquero: %d (en %d partidos)" % [total, N])
	print("  la recibe un companero: %.0f%%   la intercepta un rival: %.0f%%" % [
		float(propios) / total * 100.0, float(perdidas) / total * 100.0])
	print("\nA que companero le llega:")
	var roles := por_rol.keys()
	roles.sort_custom(func(x, y): return por_rol[x] > por_rol[y])
	for rol in roles:
		print("  %s: %.0f%%" % [rol, float(por_rol[rol]) / propios * 100.0])
	quit()
