class_name PrototipoVista
extends Control

## Banco de pruebas de la vista nueva. Simula un partido REAL con
## MotorEspacial y lo reproduce con VistaPartido. No toca el juego: no lo
## llama nadie, se abre a mano con match/prototipo_vista.tscn (F6).
##
## Hasta la etapa 2 esto usaba una coreografía inventada, que sirvió para
## aprobar proyección, cámara y sombras. Desde la etapa 3 usa el motor.

const SEMILLA := 20260818

var reproductor: VistaPartido
var _barra: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	reproductor = VistaPartido.new()
	add_child(reproductor)

	_armar_controles()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	var local := Team.generar("Atlético Prueba", rng)
	var visita := Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)

	var colores := ColoresClub.par(local.nombre, visita.nombre)
	reproductor.iniciar(r["fotogramas"], colores[0], colores[1])
	print("[prototipo] %s %d-%d %s | %d fotogramas" % [
		local.nombre, r["goles_local"], r["goles_visitante"], visita.nombre,
		r["fotogramas"].size()])


## Los controles van abajo a la IZQUIERDA: en horizontal el pulgar llega a
## los bordes, no al centro. El minimapa ocupa la derecha.
func _armar_controles() -> void:
	_barra = HBoxContainer.new()
	_barra.add_theme_constant_override("separation", 8)
	add_child(_barra)
	for etiqueta in ["x1", "x2", "x4", "x8", "x16"]:
		var b := Button.new()
		b.text = etiqueta
		b.custom_minimum_size = Vector2(56, 48)  # 48dp mínimo táctil
		var v := float(etiqueta.substr(1))
		b.pressed.connect(func(): reproductor.velocidad = v)
		_barra.add_child(b)
	var pausa := Button.new()
	pausa.text = "Pausa"
	pausa.custom_minimum_size = Vector2(80, 48)
	pausa.pressed.connect(func():
		reproductor.pausado = not reproductor.pausado
		pausa.text = "Seguir" if reproductor.pausado else "Pausa")
	_barra.add_child(pausa)
	var saltar := Button.new()
	saltar.text = "Saltar"
	saltar.custom_minimum_size = Vector2(80, 48)
	saltar.pressed.connect(func(): reproductor.saltar_al_final())
	_barra.add_child(saltar)


func _process(_delta: float) -> void:
	if _barra != null:
		_barra.position = Vector2(14, size.y - _barra.size.y - 14)
