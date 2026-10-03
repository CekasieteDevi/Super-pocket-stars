extends SceneTree

## Medición CON PANTALLA (no va en la regresión): cuánto tarda cada cuadro
## del partido dibujado (VistaPartidoV2), con el render de verdad y sin
## vsync. Anota el tiempo de CPU y de GPU del render del viewport y dónde
## está la pelota, para ver si los tirones caen en un lugar de la cancha
## (cerca del arco: remates, córners, tiros libres) o en un momento.
##
## Argumentos (después de `--`): `semilla=N`, `division=N`, `segundos=N`
## (segundos de verdad; 60 por defecto), `velocidad=N`.

const SEED := 20261201
const PREFIJO := "[dibujo]"

var _vista: VistaPartidoV2
var _segundos := 60.0
var _velocidad := 1.0
## Desde cuántos ms se anota un cuadro (`umbral=N`).
var _umbral_ms := 25.0
var _tiempo := 0.0
var _armado := false
var _cuadros := 0
## Por franja de x de la pelota (cada 10 m): [cuadros, ms de cuadro, ms de GPU].
var _por_franja := {}
var _peores: Array = []
var _primeros: Dictionary = {}


func _armar() -> void:
	var semilla := SEED
	var division := 4
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"semilla": semilla = int(p[1])
			"division": division = int(p[1])
			"segundos": _segundos = float(p[1])
			"velocidad": _velocidad = float(p[1])
			"umbral": _umbral_ms = float(p[1])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(1280, 720)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(division), "Uruguay",
		NivelDivision.realizacion(division))
	var r: Dictionary = MotorV2.simular(local, visitante, rng, true)
	_vista = VistaPartidoV2.new()
	root.add_child(_vista)
	_vista.iniciar(r["receta_v2"], r["eventos"], local, visitante)
	_vista.velocidad = _velocidad


func _process(delta: float) -> bool:
	if not _armado:
		_armado = true
		_armar()
		return false
	_tiempo += delta
	_cuadros += 1
	if _cuadros < 30:
		return false
	var sub: SubViewport = _vista.vista._viewport
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(sub.get_viewport_rid())
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(sub.get_viewport_rid())
	var bola: Vector3 = _vista._visto.get_pelota_pos()
	var franja := int(floor(bola.x / 10.0))
	var dato: Array = _por_franja.get(franja, [0, 0.0, 0.0, 0.0, 0.0, 0.0])
	dato[0] += 1
	dato[1] += delta * 1000.0
	dato[2] += gpu
	dato[3] = maxf(dato[3], delta * 1000.0)
	dato[4] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	dato[5] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	_por_franja[franja] = dato
	if delta * 1000.0 > _umbral_ms:
		_peores.append({"ms": snappedf(delta * 1000.0, 0.1), "gpu": snappedf(gpu, 0.1), "cpu": snappedf(cpu, 0.1),
			"t": snappedf(_tiempo, 0.01), "x": snappedf(bola.x, 0.1), "z": snappedf(bola.z, 0.1),
			"parada": str(_vista._partido.get_estado()["parada"]), "paso": int(_vista._partido.get_estado()["paso"])})
	if _tiempo > _segundos or _vista._terminado:
		_informar()
		return true
	return false


func _informar() -> void:
	print("%s %d cuadros en %.1f s, %.1f fps" % [PREFIJO, _cuadros, _tiempo, _cuadros / _tiempo])
	var franjas := _por_franja.keys()
	franjas.sort()
	for f in franjas:
		var d: Array = _por_franja[f]
		print("%s x %d..%d m: %d cuadros, %.2f ms de media, GPU %.2f ms, peor %.1f ms, %.0f llamadas, %.0f mil triángulos" % [
			PREFIJO, f * 10, f * 10 + 10, d[0], d[1] / d[0], d[2] / d[0], d[3], d[4] / d[0], d[5] / d[0] / 1000.0])
	for p in _peores.slice(0, 80):
		print("%s %s" % [PREFIJO, str(p)])
	print("FALLOS=0")
