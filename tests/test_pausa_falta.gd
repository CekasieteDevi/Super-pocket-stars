extends SceneTree

## La falta se tiene que VER donde paso.
##
## Antes, en el mismo tick en que se cobraba, se teletransportaba a los
## 22 jugadores a sus puestos de balon parado. El que hizo la falta
## aparecia a veinte metros de la jugada y la amarilla salia sobre una
## cancha ya acomodada: no se entendia quien le habia hecho que a quien.
## Ahora hay dos segundos congelados y despues se acomodan TROTANDO.

const SEED := 3300


func _init() -> void:
	_test_nadie_se_mueve_durante_el_congelado()
	_test_despues_se_acomodan_trotando()
	_test_el_lateral_da_tiempo_a_llegar()
	quit()


func _armar_estado(rng: RandomNumberGenerator) -> Dictionary:
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	casa.reset_partido()
	visita.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, true, 1)
	return estado


func _posiciones(estado: Dictionary) -> Dictionary:
	var out := {}
	for id in estado["jugadores"]:
		out[id] = Vector2(estado["jugadores"][id]["pos"])
	return out


func _mayor_desplazamiento(antes: Dictionary, estado: Dictionary) -> float:
	var maximo := 0.0
	for id in antes:
		maximo = maxf(maximo, float(antes[id].distance_to(estado["jugadores"][id]["pos"])))
	return maximo


func _test_nadie_se_mueve_durante_el_congelado() -> void:
	print("=== Durante el congelado no se mueve nadie ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var estado := _armar_estado(rng)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	var punto := Vector2(arco.x + hacia * 24.0, 3.0)
	var antes := _posiciones(estado)

	MotorEspacial._tiro_libre(estado, punto, true, 24)
	# El tick de la falta tampoco puede mover a nadie: ahi estaba el
	# teletransporte.
	var d_cobro := _mayor_desplazamiento(antes, estado)
	if d_cobro > 0.1:
		print("FALLA: al cobrar la falta alguien se movio %.1f m." % d_cobro)
		return

	for t in range(MotorEspacial.TICKS_CONGELADO_FALTA - 1):
		MotorEspacial._tick(estado, false)
	var d := _mayor_desplazamiento(antes, estado)
	if d > 0.6:
		print("FALLA: durante el congelado alguien se movio %.1f m." % d)
		return
	print("OK: %d ticks (%.1f s) sin que nadie se mueva mas de %.1f m." % [
		MotorEspacial.TICKS_CONGELADO_FALTA,
		MotorEspacial.TICKS_CONGELADO_FALTA * MotorEspacial.TICK_SEG, d])


func _test_despues_se_acomodan_trotando() -> void:
	print("\n=== Terminado el congelado, se acomodan ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var estado := _armar_estado(rng)
	var arco := MotorEspacial.arco_rival(true)
	var hacia: float = -1.0 if arco.x > 0.0 else 1.0
	MotorEspacial._tiro_libre(estado, Vector2(arco.x + hacia * 24.0, 3.0), true, 24)
	var antes := _posiciones(estado)
	for t in range(MotorEspacial.TICKS_CONGELADO_FALTA + 3):
		MotorEspacial._tick(estado, false)
	var d := _mayor_desplazamiento(antes, estado)
	if d < 1.0:
		print("FALLA: pasado el congelado nadie se movio (%.1f m)." % d)
		return
	print("OK: pasado el congelado se acomodan (el que mas, %.1f m)." % d)


func _test_el_lateral_da_tiempo_a_llegar() -> void:
	print("\n=== El lateral no se saca de un frame ===")
	# Dos segundos: el que saca tiene que llegar a la linea caminando, no
	# aparecer ahi en el momento del saque.
	var segundos: float = MotorEspacial.TICKS_DETENIDO["lateral"] * MotorEspacial.TICK_SEG
	if segundos < 2.0:
		print("FALLA: el lateral dura %.2f s." % segundos)
		return
	print("OK: el lateral dura %.2f s." % segundos)
