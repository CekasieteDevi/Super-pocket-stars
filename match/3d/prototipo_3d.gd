class_name Prototipo3D
extends Control

## Banco de pruebas de la vista 3D, etapa 1. Es PrototipoVista con la vista
## cambiada: simula un partido real con MotorEspacial, lo reproduce con el
## mismo VistaPartido del juego y solo reemplaza VistaCancha por
## VistaCancha3D. No lo llama nadie: se abre a mano con
## match/3d/prototipo_3d.tscn (F6).

## La misma semilla que PrototipoVista: el mismo partido en 2D y en 3D.
const SEMILLA := PrototipoVista.SEMILLA

var reproductor: VistaPartido


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reproductor = VistaPartido.new()
	add_child(reproductor)
	_cambiar_a_3d()

	var rng := RandomNumberGenerator.new()
	rng.seed = SEMILLA
	# `-- division=N` (1 = primera .. 10): los dos equipos con el nivel de
	# esa división. Sin eso, como PrototipoVista (planteles al azar, ~7ª).
	# `-- semilla=N`: otro partido.
	# `-- corte_viejo`: el partido de antes del arreglo 3D-02 (el rival
	# volvía a disputar el corte de un pase que ya lo había pasado). Es el
	# que tiene los minutos anotados en BUGS_1.1.00.md. Los cambios, también
	# como antes de 3D-06 (por la banda más cercana) y el arquero que la
	# agarra en una estirada, como antes de 3D-08 (no queda tirado).
	var division := -1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("division="):
			division = clampi(int(arg.trim_prefix("division=")), 1, NivelDivision.NIVELES.size()) - 1
		if arg.begins_with("semilla="):
			rng.seed = int(arg.trim_prefix("semilla="))
		if arg == "corte_viejo":
			MotorEspacial.pesos()["fisica"]["un_corte_por_vuelo"] = 0
			MotorEspacial.pesos()["fisica"]["cambio_por_abajo"] = 0
			MotorEspacial.pesos()["fisica"]["arquero_tendido_ticks"] = 0
			MotorEspacial.pesos()["fisica"]["desvio_lo_toca_el_defensor"] = 0
			MotorEspacial.pesos()["fisica"]["cambio_de_lado"] = 0
	var local: Team
	var visita: Team
	if division >= 0:
		var potencial := NivelDivision.potencial(division)
		var realizacion := NivelDivision.realizacion(division)
		local = Team.generar("Atlético Prueba", rng, 0, potencial, "Uruguay", realizacion)
		visita = Team.generar("Deportivo Banco", rng, 1000, potencial, "Uruguay", realizacion)
	else:
		local = Team.generar("Atlético Prueba", rng)
		visita = Team.generar("Deportivo Banco", rng, 1000)
	var r := MotorEspacial.simular(local, visita, rng, true)
	var colores := ColoresClub.par(local.nombre, visita.nombre)
	reproductor.iniciar(
		r["fotogramas"], colores[0], colores[1],
		local.nombre, visita.nombre,
		VistaPartido.construir_nombres(local, visita),
		VistaCancha.nivel_estadio_desde_calidad(local.calidad_cancha))
	reproductor.hud.menu_pedido.connect(func(): print("[prototipo 3d] menú (sin acción todavía)"))
	print("[prototipo 3d] %s %d-%d %s | %d fotogramas | medias %.1f y %.1f" % [
		local.nombre, r["goles_local"], r["goles_visitante"], visita.nombre, r["fotogramas"].size(),
		local.media_equipo(), visita.media_equipo()])


## VistaPartido crea su VistaCancha en _ready(). Se reemplaza por la 3D en
## el mismo lugar del árbol (debajo del minimapa y del HUD), sin tocar el
## código de VistaPartido.
func _cambiar_a_3d() -> void:
	var vieja := reproductor.vista
	var nueva := VistaCancha3D.new()
	nueva.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reproductor.add_child(nueva)
	reproductor.move_child(nueva, vieja.get_index())
	reproductor.remove_child(vieja)
	vieja.queue_free()
	reproductor.vista = nueva
