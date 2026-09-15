extends SceneTree

## Cuánto cuesta el partido en vivo, por partes: simular, preparar los
## sprites y cada cuadro de la reproducción. Se corre CON ventana (sin
## --headless), porque sin ventana Godot no dibuja y el _draw no cuesta:
##   godot --path . --script tests/_diag_rendimiento_partido.gd

const SEED := 20260818
const CUADROS := 900

var vista: VistaPartido
var cuadro := 0
var inicio_cuadro := 0
var tiempos: Array = []
var procesos: Array = []
var llamadas: Array = []
var dibujo_cancha: Array = []
var _t_cancha := 0


func _initialize() -> void:
	_preparar.call_deferred()


func _preparar() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1152, 648)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var local := Team.generar("Local", rng)
	var visita := Team.generar("Visita", rng, 1000)
	var t0 := Time.get_ticks_usec()
	var r := MotorEspacial.simular(local, visita, rng, true)
	var t1 := Time.get_ticks_usec()
	print("simular: %.0f ms, %d fotogramas" % [(t1 - t0) / 1000.0, r["fotogramas"].size()])

	vista = VistaPartido.new()
	root.add_child(vista)
	vista.size = Vector2(1152, 648)
	var colores := ColoresClub.par(local.nombre, visita.nombre)
	t0 = Time.get_ticks_usec()
	vista.iniciar(r["fotogramas"], colores[0], colores[1], local.nombre, visita.nombre,
		VistaPartido.construir_nombres(local, visita), "regular")
	t1 = Time.get_ticks_usec()
	print("iniciar (sprites): %.0f ms" % ((t1 - t0) / 1000.0))

	# _mostrar solo, sin dibujar: la parte en GDScript del cuadro.
	t0 = Time.get_ticks_usec()
	for i in range(300):
		vista._mostrar(300 + i, 0.5)
	t1 = Time.get_ticks_usec()
	print("_mostrar: %.3f ms por cuadro" % ((t1 - t0) / 300000.0))
	vista.velocidad = 1.0
	# La señal `draw` sale justo antes de cada _draw, y los tres se
	# redibujan en el orden en que VistaPartido los encola: cancha,
	# minimapa, HUD. La resta mide el _draw de la cancha.
	vista.vista.draw.connect(func(): _t_cancha = Time.get_ticks_usec())
	vista.minimapa.draw.connect(func():
		if cuadro > 60:
			dibujo_cancha.append((Time.get_ticks_usec() - _t_cancha) / 1000.0))
	inicio_cuadro = Time.get_ticks_usec()


func _process(_delta: float) -> bool:
	if vista == null:
		return false
	var ahora := Time.get_ticks_usec()
	cuadro += 1
	# Los primeros cuadros cargan shaders y texturas: no son el régimen.
	if cuadro > 60:
		tiempos.append((ahora - inicio_cuadro) / 1000.0)
		procesos.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		llamadas.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	inicio_cuadro = ahora
	if cuadro >= CUADROS + 60:
		tiempos.sort()
		procesos.sort()
		print("cuadro total: p50 %.2f ms  p90 %.2f ms  p99 %.2f ms" % [
			tiempos[tiempos.size() / 2], tiempos[int(tiempos.size() * 0.9)], tiempos[int(tiempos.size() * 0.99)]])
		print("process (incluye _draw): p50 %.2f ms  p90 %.2f ms" % [
			procesos[procesos.size() / 2], procesos[int(procesos.size() * 0.9)]])
		print("draw calls: %d" % int(llamadas[llamadas.size() / 2]))
		dibujo_cancha.sort()
		print("_draw de la cancha: p50 %.2f ms  p90 %.2f ms" % [
			dibujo_cancha[dibujo_cancha.size() / 2], dibujo_cancha[int(dibujo_cancha.size() * 0.9)]])
		return true
	return false
