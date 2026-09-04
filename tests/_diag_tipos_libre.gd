extends SceneTree

## En que se convierte una falta a favor segun donde fue: remate al arco,
## pelota colgada al area o juego corto.
##
## Llama a MotorEspacial.tipo_de_falta, la misma funcion que usa el
## partido. Antes repetia la clasificacion a mano y quedaba desfasado en
## cada cambio del motor.
##
## Como el alcance del remate depende de `tiros_libres` del que patea, se
## barre por pateador: se le fija el atributo al plantel entero y se mide
## desde donde le pega al arco.

const SEED := 3300
const FALTAS := 400
const ATRIBUTOS := [1, 25, 50, 75, 99]


func _init() -> void:
	print("De %d faltas a favor entre 16 y 60 m del arco, segun `tiros_libres`" % FALTAS)
	print("del plantel que las patea:")
	print("  attr | directo | centro | corto | remate mas lejano")
	for attr in ATRIBUTOS:
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var casa := Team.generar("Casa", rng, 0)
		var visita := Team.generar("Visita", rng, 400)
		# Estilo fijo para que la falta lejana no dependa del sorteo.
		casa.estilo = "Tiki taka"
		visita.estilo = "Tiki taka"
		for j in casa.jugadores:
			j["atributos"]["tiros_libres"] = attr
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

		var cuenta := {}
		var mas_lejos := 0.0
		var arco := MotorEspacial.arco_rival(true)
		var hacia: float = -1.0 if arco.x > 0.0 else 1.0
		var r2 := RandomNumberGenerator.new()
		r2.seed = SEED
		for i in range(FALTAS):
			var dist: float = r2.randf_range(16.0, 60.0)
			var punto := Vector2(arco.x + hacia * dist, r2.randf_range(-28.0, 28.0))
			var tipo := MotorEspacial.tipo_de_falta(estado, punto, true)
			cuenta[tipo] = int(cuenta.get(tipo, 0)) + 1
			if tipo == "directo":
				mas_lejos = maxf(mas_lejos, punto.distance_to(arco))
		print("  %4d | %7d | %6d | %5d | %.1f m" % [
			attr, int(cuenta.get("directo", 0)), int(cuenta.get("centro", 0)),
			int(cuenta.get("corto", 0)), mas_lejos])
	quit()
