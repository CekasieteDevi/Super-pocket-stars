extends SceneTree

## Medicion (no es test): por que hay cracks en el pool de agentes libres.
## Cuenta cuantos superan cada corte de media temporada a temporada, y con
## que sueldo piden, para ver si el problema es que quedan libres o que
## nadie los puede fichar. Correr con:
## godot --headless --script tests/_diag_cracks_libres.gd

const SEED := 909
const TEMPORADAS := 8
const CORTES := [80, 85, 90]


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var piramide := Piramide.generar(rng)

	print("temporada  pool  m>=80  m>=85  m>=90  mejor  edad_mejor  pide_mejor  clubes_que_pagan")
	for t in range(TEMPORADAS):
		piramide.jugar_temporada(rng)
		for liga in piramide.divisiones:
			liga.noticias.clear()
		piramide.fin_de_temporada(rng, null, t)

		var pool: Array = piramide.agentes_libres
		var cuenta := [0, 0, 0]
		var mejor := {}
		for a in pool:
			var m := float(a["media"])
			for i in range(CORTES.size()):
				if m >= float(CORTES[i]):
					cuenta[i] += 1
			if mejor.is_empty() or m > float(mejor["media"]):
				mejor = a

		var pide := 0.0
		var pagan := 0
		if not mejor.is_empty():
			pide = AgentesLibres.sueldo_libre(mejor, AgentesLibres.CONTRATO_LIBRE_ANIOS)
			for liga in piramide.divisiones:
				for club in liga.equipos:
					if Economia.puede_pagar_contrato(club, pide):
						pagan += 1

		print("%9d  %4d  %5d  %5d  %5d  %5.1f  %10d  %10s  %17d" % [
			t + 1, pool.size(), cuenta[0], cuenta[1], cuenta[2],
			float(mejor.get("media", 0.0)), int(mejor.get("edad", 0)),
			Economia.formato_dinero(pide), pagan])

	print("\n--- De donde salieron los mejores del pool ---")
	var pool: Array = piramide.agentes_libres
	pool.sort_custom(func(a, b): return float(a["media"]) > float(b["media"]))
	for i in range(mini(10, pool.size())):
		var a: Dictionary = pool[i]
		print("media %5.1f  %3s  %2d años  potencial %3d  temporadas_libre %s  club_actual %s" % [
			float(a["media"]), str(a["posicion"]), int(a["edad"]),
			int(a["potencial"]), str(a.get("temporadas_libre", 0)),
			str(a.get("club_actual", "-"))])
	quit()
