extends SceneTree

## Como se VE el arquero. Tres mediciones, por estilo de los dos equipos.
##
##  1. Donde se para: distancia a su propia linea, y cuanto tiempo pasa a
##     mas de 10 m de ella.
##  2. Donde esta EN EL MOMENTO de atajar.
##  3. El SALTO de la pelota al quedarle en las manos. Es lo que se ve
##     feo: la pelota termina el vuelo en un punto y al fotograma
##     siguiente aparece en el arquero, varios metros mas alla.
##
##     Se mide asi: distancia entre el ultimo fotograma de vuelo y el
##     arquero cuando la toma, menos lo que la pelota recorre en un tick.
##     Ese resto es el teletransporte. No depende de como el motor elija
##     el destino, asi que sirve para comparar antes y despues.

const SEED := 4242
const PARTIDOS := 24
const ESTILOS := ["Presión alta", "Tiki taka", "Juego directo", "Físico", "Contragolpe", "Defensivo"]


func _init() -> void:
	print("estilo          | a su linea | >10 m | al atajar | ultimo salto | >8 m | lo paso")
	for estilo in ESTILOS:
		_medir(estilo)
	quit()


func _medir(estilo: String) -> void:
	var dist: Array = []
	var lejos := 0
	var saltos: Array = []
	var al_atajar: Array = []
	var pasadas := 0

	for p in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + p * 977
		var casa := Team.generar("Casa", rng, p * 100)
		var visita := Team.generar("Visita", rng, 500 + p * 100)
		casa.estilo = estilo
		visita.estilo = estilo
		var res := MotorEspacial.simular(casa, visita, rng, true)
		var fs: Array = res["fotogramas"]
		for i in range(2, fs.size()):
			var f: Dictionary = fs[i]
			for j in f["jugadores"]:
				if str(j["rol"]) != "ARQ":
					continue
				var linea: float = -MotorEspacial.MEDIO_LARGO if bool(j["equipo_local"]) else MotorEspacial.MEDIO_LARGO
				var d: float = absf(float(j["x"]) - linea)
				dist.append(d)
				if d > 10.0:
					lejos += 1

			var pos_id: int = int(f["pelota"]["poseedor_id"])
			if pos_id == -1 or int(fs[i - 1]["pelota"]["poseedor_id"]) != -1:
				continue
			var ev = f["evento"]
			if ev == null or str(ev.get("resultado", "")) != "atajada":
				continue
			var arq := Vector2.ZERO
			for j in f["jugadores"]:
				if int(j["id"]) == pos_id:
					arq = Vector2(float(j["x"]), float(j["y"]))
			var b1 := Vector2(float(fs[i - 2]["pelota"]["x"]), float(fs[i - 2]["pelota"]["y"]))
			var b2 := Vector2(float(fs[i - 1]["pelota"]["x"]), float(fs[i - 1]["pelota"]["y"]))
			var paso: float = b1.distance_to(b2)
			if paso < 0.5:
				continue   # no venia viajando: no hay salto que medir
			saltos.append(b2.distance_to(arq))
			# ¿La pelota ya lo habia pasado cuando el motor se la dio?
			var linea_arq: float = -MotorEspacial.MEDIO_LARGO if arq.x < 0.0 else MotorEspacial.MEDIO_LARGO
			if absf(b2.x - linea_arq) < absf(arq.x - linea_arq):
				pasadas += 1
			al_atajar.append(absf(arq.x - (-MotorEspacial.MEDIO_LARGO if arq.x < 0.0 else MotorEspacial.MEDIO_LARGO)))

	print("%-15s | %6.2f m   | %3.0f%%  | %6.2f m  | %5.2f m | %3.0f%%   | %3.0f%% (n=%d)" % [
		estilo, _media(dist), 100.0 * lejos / maxf(dist.size(), 1),
		_media(al_atajar), _media(saltos),
		100.0 * _mayores(saltos, 8.0) / maxf(saltos.size(), 1),
		100.0 * pasadas / maxf(saltos.size(), 1), saltos.size()])


func _media(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())


func _mayores(a: Array, umbral: float) -> int:
	var n := 0
	for v in a:
		if float(v) > umbral:
			n += 1
	return n
