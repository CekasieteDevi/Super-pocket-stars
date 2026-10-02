extends Control

## Banco de la etapa 8 del Motor V2 (docs/motor_v2.md): la prueba larga en el
## teléfono de referencia.
##
## 1. Sin vista: `sin_vista=N` partidos con MotorV2.simular (como "Simular
##    temporada"). Mide los segundos por partido y la huella del primero, para
##    compararla con la de la PC (misma semilla = mismo partido).
## 2. Con vista: `partidos=N` partidos seguidos con la pantalla del juego
##    (VistaPartidoV2), en tiempo real. Mide fps y memoria cada MUESTRA_SEG y
##    los ms que tarda la simulación por cuadro.
##
## Imprime todo con el prefijo [banco_v2] (en el teléfono sale en logcat) y
## sale solo. La temperatura y la batería se leen por adb antes y después.
## Argumentos (después de `--`): `sin_vista=N` (5), `partidos=N` (3),
## `velocidad=N` (1), `semilla=N`, `division=N` (4).

const PREFIJO := "[banco_v2]"
const SEMILLA := 20261008
## Cada cuánto se anotan los fps y la memoria.
const MUESTRA_SEG := 30.0
## Los primeros cuadros cargan shaders y mallas: no cuentan.
const CUADROS_DE_CALENTAMIENTO := 120
## Presupuesto de docs/motor_v2.md, "Definición de hecho".
const PRESUPUESTO_SEG_PARTIDO := 3.0
const PRESUPUESTO_MS_CUADRO := 4.0

var _semilla := SEMILLA
var _division := 4
var _sin_vista := 5
var _partidos := 3
var _velocidad := 1.0

var _vista: VistaPartidoV2
var _jugados := 0
var _cuadros := 0
var _cuadros_muestra := 0
var _tiempo_muestra := 0.0
var _tiempo_total := 0.0
var _fps_muestras := PackedFloat32Array()
var _peor_cuadro_ms := 0.0
var _lentos := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		var p := arg.split("=", true, 1)
		if p.size() != 2:
			continue
		match p[0]:
			"sin_vista": _sin_vista = int(p[1])
			"partidos": _partidos = int(p[1])
			"velocidad": _velocidad = float(p[1])
			"semilla": _semilla = int(p[1])
			"division": _division = int(p[1])
	print("%s etapa 8: %s, %s, %d núcleos, pantalla %s" % [PREFIJO, OS.get_name(), OS.get_model_name(),
		OS.get_processor_count(), str(DisplayServer.screen_get_size())])
	await get_tree().process_frame
	_medir_sin_vista()
	if _partidos <= 0:
		_salir()
		return
	_siguiente_partido()


## Dos clubes de la misma división y el rng del partido, siempre iguales para
## la misma semilla.
func _clubes(semilla: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var local: Team = Team.generar("Atlético Prueba", rng, 0, NivelDivision.potencial(_division), "Uruguay",
		NivelDivision.realizacion(_division))
	var visitante: Team = Team.generar("Deportivo Banco", rng, 1000, NivelDivision.potencial(_division), "Uruguay",
		NivelDivision.realizacion(_division))
	return [local, visitante, rng]


func _medir_sin_vista() -> void:
	var total := 0.0
	var peor := 0.0
	for n in _sin_vista:
		var c := _clubes(_semilla + n)
		var t0 := Time.get_ticks_usec()
		var r: Dictionary = MotorV2.simular(c[0], c[1], c[2], true)
		var seg := float(Time.get_ticks_usec() - t0) / 1e6
		total += seg
		peor = maxf(peor, seg)
		var texto := ""
		if n == 0:
			# La huella: el mismo partido armado de la receta y jugado de nuevo.
			var p: Object = CerebroV2.armar_de_receta(r["receta_v2"])
			var pasos := 0
			while str(p.get_estado()["periodo"]) != "terminado" and pasos < MotorV2.PASOS_TOPE:
				p.simular(600)
				pasos += 600
			texto = ", huella %d, %d pasos" % [p.huella(), int(p.get_estado()["paso"])]
		print("%s sin vista, semilla %d: %d-%d en %.2f s%s" % [PREFIJO, _semilla + n, r["goles_local"],
			r["goles_visitante"], seg, texto])
	if _sin_vista > 0:
		var media := total / _sin_vista
		print("%s sin vista: %.2f s por partido de media, %.2f el peor (presupuesto %.1f): %s" % [PREFIJO, media, peor,
			PRESUPUESTO_SEG_PARTIDO, "PASA" if peor <= PRESUPUESTO_SEG_PARTIDO else "NO PASA"])


func _siguiente_partido() -> void:
	if _vista != null:
		_vista.queue_free()
		_vista = null
	if _jugados >= _partidos:
		_resumen()
		_salir()
		return
	var c := _clubes(_semilla + 100 + _jugados)
	var r: Dictionary = MotorV2.simular(c[0], c[1], c[2], true)
	_vista = VistaPartidoV2.new()
	add_child(_vista)
	_vista.iniciar(r["receta_v2"], r["eventos"], c[0], c[1])
	_vista.velocidad = _velocidad
	_vista.terminado.connect(_termino, CONNECT_ONE_SHOT)
	print("%s con vista, partido %d de %d: %d-%d, memoria %.0f MB" % [PREFIJO, _jugados + 1, _partidos, r["goles_local"],
		r["goles_visitante"], OS.get_static_memory_usage() / 1048576.0])


func _termino() -> void:
	_jugados += 1
	call_deferred("_siguiente_partido")


func _process(delta: float) -> void:
	if _vista == null:
		return
	_cuadros += 1
	if _cuadros <= CUADROS_DE_CALENTAMIENTO:
		return
	_tiempo_total += delta
	_tiempo_muestra += delta
	_cuadros_muestra += 1
	_peor_cuadro_ms = maxf(_peor_cuadro_ms, delta * 1000.0)
	# Un cuadro lento: más de dos cuadros de 60 fps.
	if delta > 2.0 / 60.0:
		_lentos += 1
	if _tiempo_muestra >= MUESTRA_SEG:
		var fps := float(_cuadros_muestra) / _tiempo_muestra
		_fps_muestras.append(fps)
		print("%s   %4.0f s: %.1f fps, memoria %.0f MB, %d nodos, %d llamadas de dibujo" % [PREFIJO, _tiempo_total, fps,
			OS.get_static_memory_usage() / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		_tiempo_muestra = 0.0
		_cuadros_muestra = 0


func _resumen() -> void:
	if _fps_muestras.is_empty():
		return
	var suma := 0.0
	var peor := 1e9
	for f in _fps_muestras:
		suma += f
		peor = minf(peor, f)
	var n := _fps_muestras.size()
	# El primer minuto contra el último: si baja, el teléfono se calentó.
	var primero := _fps_muestras[0]
	var ultimo := _fps_muestras[n - 1]
	print("%s con vista: %d partidos en %.0f s; %.1f fps de media, %.1f la peor muestra; primera muestra %.1f, última %.1f; %d cuadros lentos (más de 33 ms), el peor de %.0f ms; memoria al final %.0f MB" % [
		PREFIJO, _partidos, _tiempo_total, suma / n, peor, primero, ultimo, _lentos, _peor_cuadro_ms,
		OS.get_static_memory_usage() / 1048576.0])


func _salir() -> void:
	print("%s FIN" % PREFIJO)
	get_tree().quit()
