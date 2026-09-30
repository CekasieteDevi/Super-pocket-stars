extends Control

## Banco de la etapa 0 del Motor V2 (docs/motor_v2.md): mide si el mundo en
## GDScript entra en el presupuesto del teléfono de referencia.
##
## 1. Con vista: el mundo a 60 Hz con los 22 Jugador3D dibujados, durante
##    `segundos` de reloj. Mide ms de simulación y de vista por cuadro y fps.
## 2. Sin vista: 90 minutos de partido lo más rápido posible, en un hilo
##    aparte como la simulación de hoy (main.gd, _en_segundo_plano).
##
## Imprime todo con el prefijo [banco_v2] (en el teléfono sale en logcat) y
## sale solo. Argumentos (después de `--`): `solo_vista`, `solo_sin_vista`,
## `segundos=N` (60), `semilla=N`, `velocidad=N` (pasos del mundo por paso de
## reloj, 1 = tiempo real), `sin_hilo` (el partido sin vista en el hilo
## principal), `variantes` (con vista repite con otras perillas de dibujo,
## ver VARIANTES), `nativo` (el mundo y el cerebro falso en C++,
## MundoV2Nativo de motor_v2/cpp, en vez de GDScript).

const PREFIJO := "[banco_v2]"
const MINUTOS := 90
## Presupuesto de docs/motor_v2.md, "Definición de hecho".
const PRESUPUESTO_MS_CUADRO := 4.0
const PRESUPUESTO_SEG_PARTIDO := 3.0
## Si un cuadro se atrasa, no se ponen más de estos pasos de golpe.
const PASOS_MAX_POR_CUADRO := 4
## Los primeros cuadros cargan shaders y mallas: no cuentan.
const CUADROS_DE_CALENTAMIENTO := 60
## Perillas de VistaV2 para separar qué pesa en el dibujo: [nombre, msaa,
## sombras del sol, escala 3D, cortes de la sombra, manchas redondas,
## personajes que proyectan la sombra del sol].
const VARIANTES := [
	["normal", Viewport.MSAA_2X, true, 1.0, 4, false, true],
	["sin_msaa", Viewport.MSAA_DISABLED, true, 1.0, 4, false, true],
	["sin_sombras", Viewport.MSAA_2X, false, 1.0, 4, false, true],
	["sin_msaa_ni_sombras", Viewport.MSAA_DISABLED, false, 1.0, 4, false, true],
	["escala_075", Viewport.MSAA_2X, true, 0.75, 4, false, true],
	["sombra_2_cortes", Viewport.MSAA_2X, true, 1.0, 2, false, true],
	["sombra_1_corte", Viewport.MSAA_2X, true, 1.0, 1, false, true],
	["redonda", Viewport.MSAA_2X, false, 1.0, 4, true, false],
	["redonda_con_sol", Viewport.MSAA_2X, true, 1.0, 4, true, false],
	["redonda_con_sol_1_corte", Viewport.MSAA_2X, true, 1.0, 1, true, false],
]

var _semilla := 20260929
var _segundos := 60.0
var _velocidad := 1
var _con_vista := true
var _sin_vista := true
var _en_hilo := true
var _nativo := false
## MundoV2Nativo (la clase la registra la extensión de motor_v2/bin).
var _mundo_nativo: Object
var _variantes: Array = [VARIANTES[0]]
var _variante := 0

var _mundo: MundoV2
var _cerebro: CerebroFalsoV2
var _vista: VistaV2
var _acumulado := 0.0
var _reloj := 0.0
var _cuadros := 0
var _ms_sim := PackedFloat32Array()
var _ms_vista := PackedFloat32Array()
var _ms_cuadro := PackedFloat32Array()
var _llamadas := 0.0
var _hilo: Thread
var _etiqueta: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		if arg == "solo_vista":
			_sin_vista = false
		elif arg == "solo_sin_vista":
			_con_vista = false
		elif arg == "sin_hilo":
			_en_hilo = false
		elif arg == "nativo":
			_nativo = true
		elif arg == "variantes":
			_variantes = VARIANTES
		elif arg.begins_with("variantes="):
			var nombres := arg.trim_prefix("variantes=").split(",")
			_variantes = VARIANTES.filter(func(v): return nombres.has(v[0]))
		elif arg.begins_with("segundos="):
			_segundos = float(arg.trim_prefix("segundos="))
		elif arg.begins_with("semilla="):
			_semilla = int(arg.trim_prefix("semilla="))
		elif arg.begins_with("velocidad="):
			_velocidad = maxi(1, int(arg.trim_prefix("velocidad=")))
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(20, 20)
	_etiqueta.add_theme_font_size_override("font_size", 28)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	_reportar("equipo: %s | %s | %d núcleos | %s" % [OS.get_name(), OS.get_processor_name(),
		OS.get_processor_count(), RenderingServer.get_video_adapter_name()])
	if _con_vista:
		_empezar_con_vista()
	else:
		_empezar_sin_vista()
	add_child(_etiqueta)


func _empezar_con_vista() -> void:
	_mundo = MundoV2.new(_semilla)
	_cerebro = CerebroFalsoV2.new(_mundo)
	if _nativo:
		_mundo_nativo = ClassDB.instantiate("MundoV2Nativo")
		_mundo_nativo.configurar_pelota(FisicaV2.parametros())
		_mundo_nativo.iniciar(_semilla)
	_vista = VistaV2.new()
	var v: Array = _variantes[_variante]
	_vista.msaa = v[1]
	_vista.sombras = v[2]
	_vista.escala_3d = v[3]
	_vista.cortes_sombra = v[4]
	_vista.sombras_redondas = v[5]
	_vista.personajes_con_sombra_sol = v[6]
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	move_child(_vista, 0)
	_acumulado = 0.0
	_reloj = 0.0
	_cuadros = 0
	_llamadas = 0.0
	_ms_sim.clear()
	_ms_vista.clear()
	_ms_cuadro.clear()
	_etiqueta.text = "Etapa 0: con vista (%s)" % v[0]


func _process(delta: float) -> void:
	if _vista == null:
		return
	_cuadros += 1
	var t0 := Time.get_ticks_usec()
	_acumulado += delta
	var pasos := 0
	while _acumulado >= MundoV2.PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		for v in _velocidad:
			if _nativo:
				_mundo_nativo.avanzar()
			else:
				_cerebro.pensar()
				_mundo.avanzar()
		_acumulado -= MundoV2.PASO_SEG
		pasos += 1
	if pasos == PASOS_MAX_POR_CUADRO:
		_acumulado = 0.0
	var t1 := Time.get_ticks_usec()
	if _nativo:
		_vista.dibujar_nativo(_mundo_nativo, _acumulado / MundoV2.PASO_SEG, delta)
	else:
		_vista.dibujar(_mundo, _acumulado / MundoV2.PASO_SEG, delta)
	var t2 := Time.get_ticks_usec()
	if _cuadros <= CUADROS_DE_CALENTAMIENTO:
		return
	_reloj += delta
	_ms_sim.append(float(t1 - t0) / 1000.0)
	_ms_vista.append(float(t2 - t1) / 1000.0)
	_ms_cuadro.append(delta * 1000.0)
	_llamadas += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if _cuadros % 30 == 0:
		_etiqueta.text = "Etapa 0: con vista (%s)  %.0f/%.0f s  %d fps" % [
			_variantes[_variante][0], _reloj, _segundos, Engine.get_frames_per_second()]
	if _reloj >= _segundos:
		_terminar_con_vista()


func _terminar_con_vista() -> void:
	var n := _ms_cuadro.size()
	_reportar("CON_VISTA %s%s semilla=%d velocidad=x%d cuadros=%d reloj=%.1fs fps=%.1f pantalla=%s llamadas=%.0f" % [
		_variantes[_variante][0], " nativo" if _nativo else "", _semilla, _velocidad, n, _reloj, float(n) / _reloj, str(get_viewport().get_visible_rect().size),
		_llamadas / float(n)])
	_reportar("  sim_ms:    %s" % _resumen(_ms_sim))
	_reportar("  vista_ms:  %s" % _resumen(_ms_vista))
	_reportar("  cuadro_ms: %s" % _resumen(_ms_cuadro))
	var p95 := _percentil(_ms_sim, 0.95)
	_reportar("  PASA_SIM_CON_VISTA=%s (p95 %.2f ms <= %.1f ms)" % [
		"SI" if p95 <= PRESUPUESTO_MS_CUADRO else "NO", p95, PRESUPUESTO_MS_CUADRO])
	if _nativo:
		_reportar("  partido: %s huella=%d" % [str(_mundo_nativo.contadores()), _mundo_nativo.huella()])
	else:
		_reportar("  partido: goles=%d patadas=%d salidas=%d piques=%d palos=%d huella=%d" % [
			_cerebro.goles, _cerebro.patadas, _cerebro.salidas, _mundo.piques, _mundo.golpes_palo, _mundo.huella()])
	_vista.queue_free()
	_vista = null
	_variante += 1
	if _variante < _variantes.size():
		_empezar_con_vista()
	elif _sin_vista:
		_empezar_sin_vista()
	else:
		get_tree().quit()


func _empezar_sin_vista() -> void:
	_etiqueta.text = "Etapa 0: sin vista (90 min)..."
	if _en_hilo:
		_hilo = Thread.new()
		_hilo.start(_partido_nativo_sin_vista if _nativo else _partido_sin_vista)
	else:
		# Un cuadro para que se vea la etiqueta antes de trabarse.
		await get_tree().process_frame
		await get_tree().process_frame
		_terminar_sin_vista(_partido_nativo_sin_vista() if _nativo else _partido_sin_vista())


func _physics_process(_delta: float) -> void:
	if _hilo != null and not _hilo.is_alive():
		var r: Dictionary = _hilo.wait_to_finish()
		_hilo = null
		_terminar_sin_vista(r)


## 90 minutos: el paso del mundo y el del cerebro se miden por separado.
func _partido_sin_vista() -> Dictionary:
	var mundo := MundoV2.new(_semilla)
	var cerebro := CerebroFalsoV2.new(mundo)
	var pasos := int(MINUTOS * 60.0 / MundoV2.PASO_SEG)
	var us_mundo := 0
	var us_cerebro := 0
	var inicio := Time.get_ticks_usec()
	for k in pasos:
		var a := Time.get_ticks_usec()
		cerebro.pensar()
		var b := Time.get_ticks_usec()
		mundo.avanzar()
		var c := Time.get_ticks_usec()
		us_cerebro += b - a
		us_mundo += c - b
	var total := Time.get_ticks_usec() - inicio
	# Otra vez sin medir cada paso: cuánto pesa el reloj en la medición.
	var mundo2 := MundoV2.new(_semilla)
	var cerebro2 := CerebroFalsoV2.new(mundo2)
	var inicio2 := Time.get_ticks_usec()
	for k in pasos:
		cerebro2.pensar()
		mundo2.avanzar()
	var total2 := Time.get_ticks_usec() - inicio2
	return {"pasos": pasos, "total": total, "total_limpio": total2, "mundo": us_mundo, "cerebro": us_cerebro,
		"goles": cerebro.goles, "patadas": cerebro.patadas, "salidas": cerebro.salidas,
		"piques": mundo.piques, "palos": mundo.golpes_palo, "choques": mundo.choques_cuerpos,
		"choques_pelota": mundo.choques_pelota, "huella": mundo.huella(), "huella2": mundo2.huella()}


## 90 minutos en C++: una vez con todo el lazo adentro de la extensión y otra
## llamando cada paso desde GDScript (lo que cuesta cruzar a C++).
func _partido_nativo_sin_vista() -> Dictionary:
	var pasos := int(MINUTOS * 60.0 / MundoV2.PASO_SEG)
	var m: Object = ClassDB.instantiate("MundoV2Nativo")
	m.configurar_pelota(FisicaV2.parametros())
	m.iniciar(_semilla)
	var seg: float = m.simular(pasos)
	var m2: Object = ClassDB.instantiate("MundoV2Nativo")
	m2.configurar_pelota(FisicaV2.parametros())
	m2.iniciar(_semilla)
	var inicio := Time.get_ticks_usec()
	for k in pasos:
		m2.avanzar()
	var total2 := Time.get_ticks_usec() - inicio
	var r: Dictionary = m.contadores()
	r.merge({"pasos": pasos, "total": total2, "total_limpio": int(seg * 1e6), "mundo": int(seg * 1e6), "cerebro": 0,
		"huella": m.huella(), "huella2": m2.huella(), "nativo": true})
	return r


func _terminar_sin_vista(r: Dictionary) -> void:
	if r.get("nativo", false):
		var pasos_n := float(r["pasos"])
		_reportar("SIN_VISTA nativo semilla=%d hilo=%s pasos=%d partido=%.3fs (llamando cada paso desde GDScript %.3fs)" % [
			_semilla, str(_en_hilo), int(pasos_n), float(r["total_limpio"]) / 1e6, float(r["total"]) / 1e6])
		_reportar("  por paso: %.2f us adentro de C++ | %.2f us llamado desde GDScript" % [
			float(r["total_limpio"]) / pasos_n, float(r["total"]) / pasos_n])
		_reportar("  PASA_SIN_VISTA=%s (%.3f s <= %.1f s, sin cerebro real)" % [
			"SI" if float(r["total_limpio"]) / 1e6 <= PRESUPUESTO_SEG_PARTIDO else "NO",
			float(r["total_limpio"]) / 1e6, PRESUPUESTO_SEG_PARTIDO])
		_reportar("  partido: goles=%d patadas=%d salidas=%d piques=%d palos=%d choques=%d choques_pelota=%d" % [
			r["goles"], r["patadas"], r["salidas"], r["piques"], r["palos"], r["choques"], r["choques_pelota"]])
		_reportar("  huella=%d repetida=%d DETERMINISTA=%s" % [r["huella"], r["huella2"],
			"SI" if r["huella"] == r["huella2"] else "NO"])
		_reportar("FIN")
		get_tree().quit()
		return
	var pasos := float(r["pasos"])
	var seg := float(r["total_limpio"]) / 1e6
	_reportar("SIN_VISTA semilla=%d hilo=%s pasos=%d partido=%.2fs (medido paso a paso %.2fs)" % [
		_semilla, str(_en_hilo), int(pasos), seg, float(r["total"]) / 1e6])
	_reportar("  por paso: total %.1f us | mundo %.1f us | cerebro falso %.1f us" % [
		float(r["total_limpio"]) / pasos, float(r["mundo"]) / pasos, float(r["cerebro"]) / pasos])
	_reportar("  PASA_SIN_VISTA=%s (%.2f s <= %.1f s, sin cerebro real)" % [
		"SI" if seg <= PRESUPUESTO_SEG_PARTIDO else "NO", seg, PRESUPUESTO_SEG_PARTIDO])
	_reportar("  partido: goles=%d patadas=%d salidas=%d piques=%d palos=%d choques=%d choques_pelota=%d" % [
		r["goles"], r["patadas"], r["salidas"], r["piques"], r["palos"], r["choques"], r["choques_pelota"]])
	_reportar("  huella=%d repetida=%d DETERMINISTA=%s" % [r["huella"], r["huella2"],
		"SI" if r["huella"] == r["huella2"] else "NO"])
	_reportar("FIN")
	get_tree().quit()


func _reportar(texto: String) -> void:
	print("%s %s" % [PREFIJO, texto])


func _resumen(v: PackedFloat32Array) -> String:
	var suma := 0.0
	for x in v:
		suma += x
	return "prom %.2f | p50 %.2f | p95 %.2f | p99 %.2f | max %.2f" % [
		suma / maxf(v.size(), 1), _percentil(v, 0.5), _percentil(v, 0.95), _percentil(v, 0.99), _percentil(v, 1.0)]


func _percentil(v: PackedFloat32Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var orden := v.duplicate()
	orden.sort()
	return orden[clampi(int(ceil(q * orden.size())) - 1, 0, orden.size() - 1)]
