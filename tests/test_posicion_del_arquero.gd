extends SceneTree

## Donde se para el arquero y donde termina el remate que ataja.
##
## Viene de verlo jugando: "a veces el golero esta tan adelantado que la
## pelota lo pasa de largo y luego aparece en sus manos".
##
## Eran dos cosas encadenadas:
##  - El desplazamiento por estilo (16 m) se le aplicaba tambien al
##    arquero. Con Presion alta lo paraba en el borde del area: 7,32 m de
##    su linea de media y 32% del partido a mas de 10 m.
##  - La atajada terminaba en la LINEA del arco. El arquero adelantado
##    tenia que volver corriendo mientras la pelota volaba a 26 m/s, no
##    llegaba, y el motor le daba la pelota igual. En el 69% de las
##    atajadas con Presion alta la pelota ya lo habia pasado.
##
## Medido con tests/_diag_arquero_posicion.gd.

const SEED := 4242
const PARTIDOS := 6
## Presion alta era el peor caso y Defensivo el mejor: si el estilo ya no
## lo mueve, los dos tienen que dar lo mismo.
const ESTILOS := ["Presión alta", "Defensivo"]

## Su corral son los 16,5 m entre la linea y el borde del area, pero solo
## se va lejos cuando el juego esta en la otra mitad. Medido: 2,9 a 3,1 m
## de media segun el estilo. Con el estilo encima daba 7,32.
const DISTANCIA_MEDIA_MAX := 4.5
## Y a mas de 10 m de la linea casi nunca. Medido: 1-2%. Antes, 32%.
const FRACCION_LEJOS_MAX := 0.05


func _init() -> void:
	var fallos := 0
	var medidas := {}
	for estilo in ESTILOS:
		medidas[estilo] = _medir(estilo)
	fallos += _test_el_estilo_no_lo_saca_del_arco(medidas)
	fallos += _test_la_pelota_no_lo_pasa_de_largo(medidas)
	print("FALLOS=%d" % fallos)
	quit()


## Simula `PARTIDOS` con los dos equipos en `estilo` y devuelve:
##  - dist: distancia del arquero a su linea, fotograma por fotograma
##  - lejos: cuantas de esas muestras pasan los 10 m
##  - atajadas / pasadas: atajadas totales y en cuantas la pelota ya
##    habia pasado al arquero cuando el motor se la dio
func _medir(estilo: String) -> Dictionary:
	var suma := 0.0
	var muestras := 0
	var lejos := 0
	var atajadas := 0
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
				suma += d
				muestras += 1
				if d > 10.0:
					lejos += 1

			# La atajada: el arquero pasa a tener la pelota que venia
			# volando. Se mira el fotograma ANTERIOR, que es el ultimo de
			# vuelo, contra donde esta el arquero al tomarla.
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
			if b1.distance_to(b2) < 0.5:
				continue   # no venia viajando: no hay nada que mirar
			atajadas += 1
			var linea_arq: float = -MotorEspacial.MEDIO_LARGO if arq.x < 0.0 else MotorEspacial.MEDIO_LARGO
			if absf(b2.x - linea_arq) < absf(arq.x - linea_arq):
				pasadas += 1

	return {
		"media": suma / maxf(muestras, 1),
		"fraccion_lejos": float(lejos) / maxf(muestras, 1),
		"atajadas": atajadas,
		"pasadas": pasadas,
	}


func _test_el_estilo_no_lo_saca_del_arco(medidas: Dictionary) -> int:
	print("=== El estilo del equipo no mueve al arquero ===")
	var fallos := 0
	for estilo in ESTILOS:
		var m: Dictionary = medidas[estilo]
		if float(m["media"]) > DISTANCIA_MEDIA_MAX:
			print("FALLA: con %s el arquero se para a %.2f m de su linea, mas de los %.1f tolerados." % [
				estilo, m["media"], DISTANCIA_MEDIA_MAX])
			fallos += 1
		if float(m["fraccion_lejos"]) > FRACCION_LEJOS_MAX:
			print("FALLA: con %s pasa el %.0f%% del partido a mas de 10 m de su linea (tope %.0f%%)." % [
				estilo, 100.0 * float(m["fraccion_lejos"]), 100.0 * FRACCION_LEJOS_MAX])
			fallos += 1
	if fallos == 0:
		print("OK: %s a %.2f m de su linea y %s a %.2f m; ninguno vive afuera del arco." % [
			ESTILOS[0], medidas[ESTILOS[0]]["media"],
			ESTILOS[1], medidas[ESTILOS[1]]["media"]])
	return fallos


func _test_la_pelota_no_lo_pasa_de_largo(medidas: Dictionary) -> int:
	print("
=== La atajada termina en el arquero, no en la linea ===")
	var fallos := 0
	var total := 0
	for estilo in ESTILOS:
		var m: Dictionary = medidas[estilo]
		total += int(m["atajadas"])
		if int(m["pasadas"]) > 0:
			print("FALLA: con %s, %d de %d atajadas le llegan con la pelota ya pasada." % [
				estilo, m["pasadas"], m["atajadas"]])
			fallos += 1
	if total == 0:
		print("FALLA: no se midio ninguna atajada; el test no esta mirando nada.")
		return 1
	if fallos == 0:
		print("OK: las %d atajadas medidas terminan delante del arquero." % total)
	return fallos
