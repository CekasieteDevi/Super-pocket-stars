extends SceneTree

## Cuando se registra la pose de vuelo del arquero, contra cuando llega
## la pelota. Tiene que caer DENTRO de los cuatro ticks que dura la pose
## (VistaPartido.DURACION_ACCION), o el arquero se levanta antes.

const SEED := 4242
const PARTIDOS := 12
const DURACION_POSE := 4


func _init() -> void:
	var adelanto: Array = []
	var fuera_de_pose := 0
	var vuelos := 0

	for p in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p * 977
		var casa := Team.generar("Casa", rng, p * 100)
		var visita := Team.generar("Visita", rng, 500 + p * 100)
		casa.estilo = "Presión alta"
		visita.estilo = "Presión alta"
		var res := MotorEspacial.simular(casa, visita, rng, true)
		var fs: Array = res["fotogramas"]
		for i in range(fs.size()):
			var vuela := -1
			for a in fs[i].get("acciones", []):
				if str(a["accion"]) == MotorEspacial.ACCION_VUELA:
					vuela = int(a["clave"])
			if vuela == -1:
				continue
			vuelos += 1
			# Buscar en cuantos ticks se resuelve el remate.
			for k in range(i, mini(i + 12, fs.size())):
				var ev = fs[k]["evento"]
				if ev == null:
					continue
				var r := str(ev.get("resultado", ""))
				if r in ["atajada", "gol", "palo", "atajado"]:
					adelanto.append(k - i)
					if k - i >= DURACION_POSE:
						fuera_de_pose += 1
					break

	print("=== Pose de vuelo del arquero (%d vuelos) ===" % vuelos)
	print("ticks entre tirarse y que se resuelva el remate: media %.2f, max %d" % [
		_media(adelanto), int(_max(adelanto))])
	print("vuelos que se resuelven DESPUES de que la pose termina: %d de %d" % [
		fuera_de_pose, adelanto.size()])
	quit()


func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _max(a: Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, float(v))
	return m
