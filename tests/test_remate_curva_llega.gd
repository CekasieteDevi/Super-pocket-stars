extends SceneTree

## El remate con efecto tiene que llegar a destino. La curva avanzaba con
## el paso del tick anterior, que se achica en el medio de la Bezier: en
## remates cortos y muy curvos la pelota no llegaba nunca y quedaba
## colgada sobre el arquero, con los 22 quietos, hasta el final del tiempo.
## Pasaba 1 de cada 5 partidos (tests/_diag_guardado_trancada.gd).

const SEED := 9410
## Un remate de 20 m a vel_remate tarda menos de 4 ticks. Diez sobran
## para la curva mas larga; el bug nunca terminaba.
const TICKS_MAX := 10
var fallos := 0


func _init() -> void:
	for local in [true, false]:
		for tipo in ["atajada", "gol", "palo", "afuera"]:
			for salida in [Vector2(6.0, 8.0), Vector2(10.0, 12.0), Vector2(16.0, 14.0)]:
				_probar(local, tipo, salida)
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _comprobar(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion: fallos += 1


func _probar(local: bool, tipo: String, salida: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var casa := Team.generar("Casa", rng, 0)
	var visita := Team.generar("Visita", rng, 400)
	for equipo in [casa, visita]:
		equipo.reset_partido()
	casa.local = true
	visita.local = false
	casa.clima_partido = Clima.generar(rng)
	visita.clima_partido = casa.clima_partido
	casa.arbitro_partido = Arbitro.generar(rng)
	visita.arbitro_partido = casa.arbitro_partido
	var estado := MotorEspacial.crear_estado(casa, visita, rng)
	MotorEspacial._reiniciar_desde_medio(estado, local, 1)
	var atacante: Dictionary = (casa if local else visita).jugadores.back()
	atacante["atributos"]["tiro"] = 99.0
	atacante["atributos"]["efecto"] = 99.0
	var clave := MotorEspacial.clave_de(atacante["id"], local)
	var poseedor: Dictionary = estado["jugadores"][clave]
	for id in estado["jugadores"]:
		if str(estado["jugadores"][id]["rol"]) != "ARQ":
			estado["jugadores"][id]["pos"] = Vector2(0.0, 30.0)
	var arco := MotorEspacial.arco_rival(local)
	poseedor["pos"] = arco + Vector2(-salida.x if local else salida.x, salida.y)
	estado["pelota"]["pos"] = poseedor["pos"]
	estado["pelota"]["poseedor_id"] = clave
	var datos := {"tipo": tipo, "es_local": local, "clave": clave, "rol": poseedor["rol"],
		"jugador": atacante, "dist": salida.length(), "agarre": 0.5, "forzar_curva": true}
	MotorEspacial._lanzar_remate(estado, poseedor, datos)
	var nombre := "%s local=%s desde %s" % [tipo, local, salida]
	if estado["pelota"].get("trayectoria_curva", {}).is_empty():
		_comprobar(false, "el remate sale con curva: " + nombre)
		return
	var ticks := 0
	while bool(estado["pelota"].get("es_remate", false)) and ticks < TICKS_MAX:
		MotorEspacial._avanzar_pelota(estado)
		ticks += 1
	_comprobar(not bool(estado["pelota"].get("es_remate", false)),
		"el remate con curva llega en %d ticks: %s" % [ticks, nombre])
