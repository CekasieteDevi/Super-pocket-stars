class_name PrototipoVista
extends Control

## Banco de pruebas de la vista nueva. Simula un partido REAL con
## MotorEspacial y lo reproduce con VistaPartido. No toca el juego: no lo
## llama nadie, se abre a mano con match/prototipo_vista.tscn (F6).
##
## Hasta la etapa 2 usaba una coreografía inventada, que sirvió para
## aprobar proyección, cámara y sombras. Desde la etapa 3 usa el motor.

const SEMILLA := 20260818

var reproductor: VistaPartido


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	reproductor = VistaPartido.new()
	add_child(reproductor)

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)

	var colores := ColoresClub.par(local.nombre, visita.nombre)
	reproductor.iniciar(
		r["fotogramas"], colores[0], colores[1],
		local.nombre, visita.nombre,
		VistaPartido.construir_nombres(local, visita))
	# La textura según el estado real de la cancha se conecta en la etapa 6,
	# junto con arcos y tribunas.
	reproductor.hud.menu_pedido.connect(func(): print("[prototipo] menú (sin acción todavía)"))
	print("[prototipo] %s %d-%d %s | %d fotogramas" % [
		local.nombre, r["goles_local"], r["goles_visitante"], visita.nombre,
		r["fotogramas"].size()])
