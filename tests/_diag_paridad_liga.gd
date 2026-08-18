extends SceneTree

## Paridad REAL: en la liga de verdad, ¿mi equipo vive partidos con más
## goles que el resto? Mi partido lo resuelve MotorEspacial y los demás
## MatchEngine, así que si no dan lo mismo, la economía, los objetivos y
## los fans quedan mal calibrados SOLO para el jugador.
##
## Es la prueba que importa: medir con Team.generar suelto no reproduce
## los planteles que arma la pirámide ni el reparto de niveles de la liga.
## No se puede usar el autoload GameState en modo --script, así que se
## reproduce la misma secuencia (igual que tests/test_gamestate_flujo.gd).

const DIVISION_INICIAL := 9
const TEMPORADAS := 4


func _init() -> void:
	for div in [DIVISION_INICIAL, 4, 0]:
		var mios := 0.0
		var n_mios := 0.0
		var ajenos := 0.0
		var n_ajenos := 0.0
		for t in range(TEMPORADAS):
			var mios_temp := 0.0
			var n_mios_temp := 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 2026 + t
			var piramide := Piramide.generar(rng)
			var liga: Liga = piramide.divisiones[div]
			var yo: Team = liga.equipos[0]
			for fecha in range(liga.fixture.size()):
				var r := liga.jugar_fecha(fecha, rng, yo)
				liga.avanzar_dias(7)
				if r["resultado_seguido"] != null:
					var rs: Dictionary = r["resultado_seguido"]
					mios_temp += int(rs["gl"]) + int(rs["gv"])
					n_mios_temp += 1.0
				for _texto in r["resultados_texto"]:
					n_ajenos += 1.0
			# La suma de goles a favor de la tabla son TODOS los goles de la
			# liga; los mios se descuentan para quedarme con los del resto.
			var gf := 0.0
			for nombre in liga.tabla:
				gf += float(liga.tabla[nombre]["gf"])
			ajenos += gf - mios_temp
			mios += mios_temp
			n_mios += n_mios_temp
		# n_ajenos conto todos los partidos, incluidos los mios.
		n_ajenos -= n_mios
		print("division %d | mis partidos (espacial): %.2f goles | resto (abstracto): %.2f" % [
			div + 1, mios / maxf(n_mios, 1), (ajenos) / maxf(n_ajenos, 1)])
	quit()
