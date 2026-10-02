extends Control

## Etapa 8 del Motor V2 (docs/motor_v2.md): el partido como lo ve el juego.
## Arma dos clubes, juega el partido con MotorV2.simular (sin vista, como la
## liga) y lo muestra con VistaPartidoV2: marcador, relato, minimapa y
## controles. Sirve para mirar la pantalla del partido sin entrar a una
## partida.
##
## Argumentos (después de `--`): `semilla=N`, `division=N` (0 = primera),
## `velocidad=N`, `capturas=carpeta` con `cada=segundos` y `dura=segundos`
## (guarda imágenes y sale).

const SEMILLA := 20261201

var _vista: VistaPartidoV2
var _capturas := ""
var _cada := 2.0
var _dura := 20.0
var _tiempo := 0.0
var _capturadas := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var semilla := SEMILLA
	var division := 4
	var velocidad := 1.0
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semilla": semilla = int(p[1])
			"division": division = int(p[1])
			"velocidad": velocidad = float(p[1])
			"capturas": _capturas = p[1]
			"cada": _cada = float(p[1])
			"dura": _dura = float(p[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	print("[lab_partido] %s %d - %d %s, %d eventos" % [local.nombre, r["goles_local"], r["goles_visitante"],
		visitante.nombre, (r["eventos"] as Array).size()])
	_vista = VistaPartidoV2.new()
	add_child(_vista)
	_vista.iniciar(r["receta_v2"], r["eventos"], local, visitante)
	_vista.velocidad = velocidad
	_vista.hud.menu_pedido.connect(func(): get_tree().quit())
	_vista.terminado.connect(func(): print("[lab_partido] terminado"))


func _process(delta: float) -> void:
	if _capturas == "":
		return
	_tiempo += delta
	if _tiempo >= float(_capturadas) * _cada:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/captura_%03d.png" % [_capturas, _capturadas])
		_capturadas += 1
	if _tiempo > _dura:
		get_tree().quit()
