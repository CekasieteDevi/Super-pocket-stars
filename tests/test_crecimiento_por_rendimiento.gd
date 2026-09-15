extends SceneTree

## §7.1: el crecimiento depende de los minutos y del rendimiento, no solo
## de la edad. Antes un DC GOAT de 16 años y media 50 llegaba a 84 a los 18
## jugara o no. Correr con:
## godot --headless --script tests/test_crecimiento_por_rendimiento.gd

const SEED := 4242
const N := 60

const TITULAR_NORMAL := {"partidos": 34.0, "goles": 16.0, "asistencias": 5.0, "a_favor": 45.0, "en_contra": 45.0}
const GOLEADOR := {"partidos": 36.0, "goles": 40.0, "asistencias": 6.0, "a_favor": 60.0, "en_contra": 40.0}
const FLOJO := {"partidos": 34.0, "goles": 5.0, "asistencias": 2.0, "a_favor": 35.0, "en_contra": 55.0}

var fallos := 0


func _init() -> void:
	_test_la_liga_acumula_el_rendimiento()
	_test_jugar_hace_crecer_mas()
	_test_rendir_hace_crecer_mas()
	_test_un_defensor_rinde_por_goles_recibidos()
	_test_un_crack_no_llega_al_techo_a_los_18()
	_test_el_rendimiento_se_consume()
	print("FALLOS=%d" % fallos)
	quit()


func _ok(condicion: bool, texto: String) -> void:
	if condicion:
		print("OK: " + texto)
	else:
		print("FALLA: " + texto)
		fallos += 1


## Media promedio de N jugadores después de `temporadas` con el mismo
## rendimiento cada año.
func _media_tras(rend: Dictionary, temporadas: int, puesto: String = "DC") -> float:
	var suma := 0.0
	for i in range(N):
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + i
		var j := PlayerGenerator.generate(i, rng, puesto, 96)
		j["potencial"] = 96
		j["genetica_tier"] = Genetics.tier_de(96)
		j["potenciales"] = PlayerGenerator.techos_por_atributo(96, rng)
		j["edad"] = 16
		j["personalidad"] = []
		var m0: float = PlayerGenerator.compute_media(j["atributos"], puesto)
		for a in j["atributos"]:
			j["atributos"][a] = clampf(round(float(j["atributos"][a]) * 50.0 / m0), 1, 99)
		for t in range(temporadas):
			j["rendimiento"] = rend.duplicate()
			Progresion.aplicar_temporada(j, rng)
		suma += float(j["media"])
	return suma / N


func _test_la_liga_acumula_el_rendimiento() -> void:
	print("=== La liga acumula minutos, goles y goles recibidos por jugador ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var nombres := []
	for i in range(4):
		nombres.append("Club %d" % i)
	var liga := Liga.new()
	liga.inicializar(nombres, rng)
	var goles_tabla := 0
	for fecha in range(liga.fixture.size()):
		liga.jugar_fecha(fecha, rng)
		liga.avanzar_dias(7)
	for fila in liga.estadisticas.values():
		goles_tabla += int(fila["goles"])
	var goles_jugadores := 0.0
	var partidos_arquero := 0.0
	for e in liga.equipos:
		for j in e.todos_los_jugadores():
			goles_jugadores += float(j.get("rendimiento", {}).get("goles", 0.0))
		partidos_arquero = maxf(partidos_arquero, float(e.arquero().get("rendimiento", {}).get("partidos", 0.0)))
	_ok(is_equal_approx(goles_jugadores, float(goles_tabla)),
		"los goles del rendimiento (%d) coinciden con la tabla de goleadores (%d)" % [goles_jugadores, goles_tabla])
	_ok(partidos_arquero >= liga.fixture.size() - 1,
		"el arquero titular suma %.1f partidos de %d fechas" % [partidos_arquero, liga.fixture.size()])


func _test_jugar_hace_crecer_mas() -> void:
	print("\n=== El titular crece más que el que no juega ===")
	var titular := _media_tras(TITULAR_NORMAL, 2)
	var no_juega := _media_tras({}, 2)
	_ok(titular - 50.0 > 2.0 * (no_juega - 50.0),
		"titular 50 -> %.1f, sin jugar 50 -> %.1f en dos temporadas" % [titular, no_juega])


func _test_rendir_hace_crecer_mas() -> void:
	print("\n=== Con los mismos minutos, el que rinde crece más ===")
	var goleador := _media_tras(GOLEADOR, 2)
	var flojo := _media_tras(FLOJO, 2)
	_ok(goleador - flojo >= 5.0, "40 goles 50 -> %.1f, 5 goles 50 -> %.1f" % [goleador, flojo])


func _test_un_defensor_rinde_por_goles_recibidos() -> void:
	print("\n=== Un central se mide por los goles que recibe su equipo ===")
	var solido := {"posicion": "DFC", "rendimiento": {"partidos": 34.0, "a_favor": 45.0, "en_contra": 25.0}}
	var coladero := {"posicion": "DFC", "rendimiento": {"partidos": 34.0, "a_favor": 45.0, "en_contra": 70.0}}
	_ok(Progresion.factor_rendimiento(solido) > 1.1 and Progresion.factor_rendimiento(coladero) < 0.9,
		"valla sólida %.2f, coladero %.2f" % [Progresion.factor_rendimiento(solido), Progresion.factor_rendimiento(coladero)])
	var poca_muestra := {"posicion": "DC", "rendimiento": {"partidos": 3.0, "goles": 3.0, "a_favor": 4.0, "en_contra": 3.0}}
	_ok(Progresion.factor_rendimiento(poca_muestra) < 1.3,
		"tres goles en tres partidos no alcanzan para el máximo: %.2f" % Progresion.factor_rendimiento(poca_muestra))


func _test_un_crack_no_llega_al_techo_a_los_18() -> void:
	print("\n=== Un GOAT de 16 con media 50 no llega a su techo a los 18 ===")
	var goleador := _media_tras(GOLEADOR, 2)
	_ok(goleador < 76.0, "con 40 goles por temporada, a los 18 tiene %.1f" % goleador)


func _test_el_rendimiento_se_consume() -> void:
	print("\n=== El rendimiento de una temporada no acelera la siguiente ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var j := PlayerGenerator.generate(1, rng, "DC")
	j["rendimiento"] = GOLEADOR.duplicate()
	Progresion.aplicar_temporada(j, rng)
	_ok(j["rendimiento"].is_empty(), "rendimiento vacío después de la temporada")
