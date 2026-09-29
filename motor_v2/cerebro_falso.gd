class_name CerebroFalsoV2
extends RefCounted

## Cerebros de mentira para la etapa 0 del Motor V2 (docs/motor_v2.md): no
## deciden fútbol, solo le dan al mundo el trabajo de un partido. Cada
## jugador piensa a 10 Hz, escalonado (22 jugadores en 6 pasos), y corre a
## un punto al azar cerca de su puesto. El más cercano de cada equipo va a
## la pelota y la patea en cualquier dirección hacia el arco rival, con
## altura y efecto al azar, para que la pelota vuele, pique, ruede y pegue
## en los palos. Un gol o una salida la vuelve a poner en juego.

## 10 Hz con pasos de 1/60 s.
const PASOS_POR_TURNO := 6
## Puestos 4-4-2 del equipo local (x negativa = su campo); el visitante es
## el espejo.
const PUESTOS := [
	Vector2(-50.0, 0.0),
	Vector2(-35.0, -24.0), Vector2(-38.0, -8.0), Vector2(-38.0, 8.0), Vector2(-35.0, 24.0),
	Vector2(-18.0, -22.0), Vector2(-20.0, -7.0), Vector2(-20.0, 7.0), Vector2(-18.0, 22.0),
	Vector2(-5.0, -8.0), Vector2(-5.0, 8.0),
]
const DISPERSION_M := 7.0
const PATEA_DISTANCIA_M := 0.75
const PATEA_ALTURA_M := 0.6
const ESPERA_ENTRE_PATADAS := 36  # pasos (0.6 s)

var _mundo: MundoV2
var _perseguidor := PackedInt32Array([1, 12])
var _puede_patear := PackedInt32Array()

var patadas := 0
var goles := 0
var salidas := 0


func _init(mundo: MundoV2) -> void:
	_mundo = mundo
	_puede_patear.resize(MundoV2.JUGADORES)
	for i in MundoV2.JUGADORES:
		mundo.pos[i] = _puesto(i) * Vector2(0.9, 1.0)
		mundo.objetivo[i] = mundo.pos[i]
	mundo.pos_previa = mundo.pos


func _puesto(i: int) -> Vector2:
	var base: Vector2 = PUESTOS[i % 11]
	return base if i < 11 else Vector2(-base.x, -base.y)


## Se llama antes de cada paso del mundo.
func pensar() -> void:
	var m := _mundo
	var turno := m.paso % PASOS_POR_TURNO
	var pelota := Vector2(m.pelota_pos.x, m.pelota_pos.z)
	if turno == 0:
		_elegir_perseguidores(pelota)
	# Se anticipa la pelota 0.3 s: si no, el que la persigue siempre llega tarde.
	var adelante := pelota + Vector2(m.pelota_vel.x, m.pelota_vel.z) * 0.3
	for i in range(turno, MundoV2.JUGADORES, PASOS_POR_TURNO):
		if i == _perseguidor[0] or i == _perseguidor[1]:
			m.objetivo[i] = adelante
		elif i % 11 == 0:
			var linea := -MundoV2.MEDIO_LARGO + 1.0 if i < 11 else MundoV2.MEDIO_LARGO - 1.0
			m.objetivo[i] = Vector2(linea, clampf(pelota.y * 0.3, -2.5, 2.5))
		else:
			# El bloque se corre con la pelota, más un desvío al azar.
			var p := _puesto(i) + Vector2(pelota.x * 0.5, pelota.y * 0.25)
			p += Vector2(m.rng.randf_range(-DISPERSION_M, DISPERSION_M), m.rng.randf_range(-DISPERSION_M, DISPERSION_M))
			m.objetivo[i] = p.clamp(Vector2(-MundoV2.MEDIO_LARGO, -MundoV2.MEDIO_ANCHO),
				Vector2(MundoV2.MEDIO_LARGO, MundoV2.MEDIO_ANCHO))
	for k in 2:
		_intentar_patear(_perseguidor[k])
	_reglas()


func _elegir_perseguidores(pelota: Vector2) -> void:
	for equipo in 2:
		var mejor := -1
		var mejor_d := INF
		for i in range(equipo * 11, equipo * 11 + 11):
			var d := pelota.distance_squared_to(_mundo.pos[i])
			if d < mejor_d:
				mejor_d = d
				mejor = i
		_perseguidor[equipo] = mejor


func _intentar_patear(i: int) -> void:
	var m := _mundo
	if m.paso < _puede_patear[i] or m.pelota_pos.y > PATEA_ALTURA_M:
		return
	if Vector2(m.pelota_pos.x, m.pelota_pos.z).distance_to(m.pos[i]) > PATEA_DISTANCIA_M:
		return
	var hacia := 1.0 if i < 11 else -1.0
	var angulo := m.rng.randf_range(-1.2, 1.2)
	var rapidez := m.rng.randf_range(6.0, 27.0)
	var dir := Vector2(cos(angulo) * hacia, sin(angulo))
	var alto := 0.0 if m.rng.randf() < 0.5 else m.rng.randf_range(0.1, 0.45) * rapidez
	var giro := Vector3(0.0, m.rng.randf_range(-12.0, 12.0), 0.0)
	m.patear(Vector3(dir.x * rapidez, alto, dir.y * rapidez), giro)
	_puede_patear[i] = m.paso + ESPERA_ENTRE_PATADAS
	patadas += 1


## Gol o salida: la pelota vuelve a juego (en el medio o en la línea).
func _reglas() -> void:
	var m := _mundo
	var p := m.pelota_pos
	if absf(p.x) > MundoV2.MEDIO_LARGO + MundoV2.RADIO_PELOTA:
		if absf(p.z) < MundoV2.ARCO_MEDIO_ANCHO and p.y < MundoV2.ARCO_ALTO:
			goles += 1
			m.poner_pelota(Vector3(0.0, MundoV2.RADIO_PELOTA, 0.0))
		else:
			salidas += 1
			m.poner_pelota(Vector3(signf(p.x) * (MundoV2.MEDIO_LARGO - 5.5), MundoV2.RADIO_PELOTA, signf(p.z) * 9.0))
	elif absf(p.z) > MundoV2.MEDIO_ANCHO + MundoV2.RADIO_PELOTA:
		salidas += 1
		m.poner_pelota(Vector3(p.x, MundoV2.RADIO_PELOTA, signf(p.z) * (MundoV2.MEDIO_ANCHO - 0.5)))
