extends SceneTree

## ¿El cambio congela una jugada viva?
##
## Un cambio se hace con la pelota parada. Si arranca con la pelota en el
## aire, el usuario ve el pase o el remate clavado a mitad de camino
## durante toda la caminata del suplente, y la jugada recien termina
## cuando el cambio termina. El caso feo es el remate: se ve la
## sustitucion ANTES que el gol.
##
## Mide tres cosas sobre los fotogramas, que es lo que ve el usuario:
##  - EN EL AIRE: cambios que arrancan con la pelota viajando y sin que
##    se haya cortado el juego. Esa es la jugada que queda clavada
##    esperando a que el suplente termine de entrar.
##  - GOLES PEGADOS: goles que caen dentro de los 12 fotogramas
##    siguientes al final de un cambio.
##  - GOLES SIN CAMARA: goles convertidos en un fotograma que ademas
##    tiene `foco`, o sea que la camara estaba mirando al suplente y no
##    al arco.
##
## Medido con 60 partidos, antes y despues de la guarda de
## MotorEspacial._sincronizar_cambios:
##   antes:   106 cambios, 18 en el aire (17%), 0 sin camara
##   despues:  79 cambios,  7 en el aire  (9%), 0 sin camara
## Bajan los cambios animados porque los del entretiempo ahora se aplican
## sin caminata. Los 7 que quedan son falsos positivos: la pelota ya
## estaba muerta sobre la linea, que el fotograma no distingue de la
## pelota viajando.

const SEMILLA := 20260908
const PARTIDOS := 60


func _init() -> void:
	var cambios := 0
	var en_el_aire := 0
	var goles := 0
	var goles_pegados := 0
	var goles_sin_camara := 0
	for n in range(PARTIDOS):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEMILLA + n
		var local := Team.generar("Atletico Prueba", rng)
		var visita := Team.generar("Deportivo Banco", rng, 1000)
		var r := MotorEspacial.simular(local, visita, rng, true)
		var fs: Array = r["fotogramas"]
		var ultimo_foco := -999
		var inicio := -1
		for i in range(fs.size()):
			var con_foco: bool = fs[i].get("foco", null) != null
			if con_foco:
				ultimo_foco = i
				if inicio == -1:
					inicio = i
					cambios += 1
					if _pelota_en_el_aire(fs, i):
						en_el_aire += 1
			elif inicio != -1:
				inicio = -1
			for ev in fs[i].get("eventos", []):
				if str(ev.get("resultado", "")) == "gol" 					and str(ev.get("tipo", "")) in ["tiro_puerta", "penal"]:
					goles += 1
					if i - ultimo_foco <= 12:
						goles_pegados += 1
					if con_foco:
						goles_sin_camara += 1
	print("cambios animados=%d con la pelota en el aire=%d (%.0f%%)" % [
		cambios, en_el_aire, 100.0 * en_el_aire / maxi(cambios, 1)])
	print("goles=%d pegados a un cambio=%d sin camara=%d" % [
		goles, goles_pegados, goles_sin_camara])
	quit()


## ¿El cambio arranco con la pelota EN EL AIRE? Es el caso reportado: el
## remate sale, el cambio congela el juego y la pelota se queda clavada a
## mitad de camino del arco hasta que el suplente termina de entrar.
##
## Se pide que la pelota venga sin dueño y moviendose, y que no haya
## habido corte: despues de una falta o un saque de arco la pelota
## tambien se mueve —o se teletransporta al punto— y eso no es una jugada
## interrumpida.
static func _pelota_en_el_aire(fs: Array, i: int) -> bool:
	if i < 2:
		return false
	for k in [i - 2, i - 1, i]:
		if int(fs[k]["pelota"]["poseedor_id"]) != -1:
			return false
		if bool(fs[k].get("corte", false)):
			return false
	return _dist(fs[i - 2], fs[i - 1]) > 1.0


static func _dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(float(a["pelota"]["x"]), float(a["pelota"]["y"])).distance_to(
		Vector2(float(b["pelota"]["x"]), float(b["pelota"]["y"])))
