extends SceneTree

## BUG-014 (docs/bugs_pendientes.md): el arquero sale a los pies del rival que
## lleva la pelota en su área (Canchita::_pensar_jugador). Antes volvía a su
## línea y el rival entraba al arco conduciendo.
##
## Juega partidos enteros con reglas, sin vista. Cuenta las llegadas (un rival
## lleva la pelota a menos de LLEGADA_M del medio del arco) y cuántas terminan
## con la pelota en las manos del arquero o tocada por él.
##
## Correr con: godot --path . --headless --script tests/test_arquero_a_los_pies_v2.gd

const SEED := 97000
const PARTIDOS := 60
const ESTILOS := [["Tiki taka", "Juego directo"], ["Presión alta", "Contragolpe"]]
## Hasta dónde cuenta una llegada: el doble de lo que sale el arquero a los
## pies (achique_margen_pelota, 4 m).
const LLEGADA_M := 8.0
## Cancha del motor (Cerebro::MEDIO_LARGO, motor_v2/cpp/src/cerebro/cerebro.h).
const MEDIO_LARGO := 52.5
## Área grande (Cerebro::AREA_LARGO y AREA_MEDIO_ANCHO, mismo archivo).
const AREA_LARGO := 16.5
const AREA_MEDIO_ANCHO := 20.16
## Desde dónde sale a los pies (achique_margen_pelota, data/utility_pesos.json).
## Es una constante porque el test apaga ese peso para medir sin la salida.
const MARGEN_M := 4.0
## El motor piensa cada 6 pasos: una muestra por turno.
const CADA := 6

var fallos := 0


func _init() -> void:
	var con := _medir()
	_ok(con["llegadas"] >= PARTIDOS / 2, "hay llegadas en %d partidos (%d)." % [PARTIDOS, con["llegadas"]])
	# Antes del arreglo: 2 en estos mismos partidos (4 en 120). Con el arquero
	# siguiendo al rival que se aleja eran 10; sin seguirlo, 6.
	_ok(con["del_arquero"] >= 5, "el arquero se queda con la pelota o la toca en 5 llegadas o más (%d)."
		% con["del_arquero"])
	# Siguiendo al rival que se aleja: 119 muestras. Sin seguirlo quedan 34, lo
	# que tarda en frenar.
	_ok(con["se_aleja"] <= 60, "el arquero no se aleja del arco detrás del rival: 60 muestras o menos (%d)."
		% con["se_aleja"])
	# El test mide algo: sin el margen el arquero no sale a los pies.
	var pesos := BasePartido.pesos_arquero()
	var margen: float = pesos["achique_margen_pelota"]
	pesos["achique_margen_pelota"] = 0.0
	var sin := _medir()
	pesos["achique_margen_pelota"] = margen
	_ok(sin["del_arquero"] * 2 <= con["del_arquero"], "sin la salida a los pies son menos de la mitad (%d)."
		% sin["del_arquero"])
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _ok(condicion: bool, mensaje: String) -> void:
	if condicion:
		print("OK: %s" % mensaje)
	else:
		fallos += 1
		print("FALLA: %s" % mensaje)


## Las llegadas de PARTIDOS partidos de quinta y cuántas corta el arquero.
## `se_aleja` cuenta las muestras con el rival llevando la pelota en el área a
## menos de MARGEN_M del arquero, y los dos más lejos del arco que en la
## muestra anterior.
func _medir() -> Dictionary:
	var s := {"llegadas": 0, "del_arquero": 0, "se_aleja": 0}
	for n in PARTIDOS:
		var estilos: Array = ESTILOS[n % ESTILOS.size()]
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + n
		var local := Team.generar("Local", rng, 0, NivelDivision.potencial(4), "Uruguay", NivelDivision.realizacion(4))
		var visitante := Team.generar("Visitante", rng, 1000, NivelDivision.potencial(4), "Uruguay",
			NivelDivision.realizacion(4))
		local.estilo = estilos[0]
		visitante.estilo = estilos[1]
		var c: Object = CerebroV2.armar(local, visitante, SEED + n, true)
		var equipos: PackedInt32Array = c.get_equipos()
		var arqueros: PackedInt32Array = c.get_arqueros()
		# El arquero de la llegada en curso; -1 si no hay.
		var defiende := -1
		# El arquero que tenía al rival encima en la muestra anterior, y a
		# cuánto del medio del arco estaban él y la pelota; -1 si no había.
		var encima := -1
		var arquero_antes := 0.0
		var pelota_antes := 0.0
		var pasos := 0
		while str(c.get_estado()["periodo"]) != "terminado" and pasos < 60 * 60 * 20:
			c.simular(CADA)
			pasos += CADA
			var lleva: int = c.get_poseedor()
			var ahora := -1
			var encima_ahora := -1
			var arquero_al_arco := 0.0
			var pelota_al_arco := 0.0
			if lleva >= 0 and arqueros[lleva] == 0:
				var bola: Vector3 = c.get_pelota_pos()
				var lado := signf(bola.x)
				# Los equipos cambian de lado en el entretiempo: el arquero que
				# defiende ese arco es el rival que está de ese lado.
				var pos: PackedVector2Array = c.get_pos()
				var arquero := -1
				for i in equipos.size():
					if arqueros[i] == 1 and equipos[i] != equipos[lleva] and signf(pos[i].x) == lado:
						arquero = i
				pelota_al_arco = Vector2(bola.x - lado * MEDIO_LARGO, bola.z).length()
				if pelota_al_arco < LLEGADA_M:
					ahora = arquero
				if arquero >= 0 and absf(bola.x - lado * MEDIO_LARGO) <= AREA_LARGO and absf(bola.z) <= AREA_MEDIO_ANCHO \
						and Vector2(bola.x - pos[arquero].x, bola.z - pos[arquero].y).length() < MARGEN_M:
					encima_ahora = arquero
					arquero_al_arco = Vector2(pos[arquero].x - lado * MEDIO_LARGO, pos[arquero].y).length()
			s["se_aleja"] += int(encima_ahora >= 0 and encima_ahora == encima and pelota_al_arco > pelota_antes
				and arquero_al_arco > arquero_antes)
			encima = encima_ahora
			arquero_antes = arquero_al_arco
			pelota_antes = pelota_al_arco
			if ahora >= 0 and defiende < 0:
				s["llegadas"] += 1
			elif ahora < 0 and defiende >= 0:
				s["del_arquero"] += int(int(c.get_en_manos()) == defiende or int(c.get_ultimo_toque()) == defiende)
			defiende = ahora
	return s
