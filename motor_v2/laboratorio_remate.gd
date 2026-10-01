extends Control

## Laboratorio de remates, etapa 5 de docs/motor_v2.md: una tanda de remates
## contra el arquero en la cancha entera (CanchitaV2Nativa, modo ARCO),
## dibujada con los Jugador3D del partido (VistaV2). El 9 remata al punto y
## con el golpe de la tanda, el arquero lo lee y se tira, y un compañero
## espera el rebote en el punto penal. Nadie decide el resultado: sale del
## vuelo de la pelota y de la mano del arquero.
##
## Con pantalla: arriba a la izquierda, el remate, cómo terminó y qué hizo el
## arquero. Cada remate empieza 1,5 s después de que termina el anterior; un
## toque o una tecla pasa al siguiente.
## Sin pantalla (--headless): patea la tanda entera con la vista dibujando,
## imprime cada remate con [lab_remate] y sale.
## Argumentos (después de `--`): `semilla=N`, `arquero=N` (atributos del
## arquero, 70), `tiro=N` (del que remata, 70).

const PREFIJO := "[lab_remate]"
const PASO_SEG := 1.0 / 60.0
const PASOS_MAX_POR_CUADRO := 4
const SEMILLA := 20261005
## Cuánto se ve cómo terminó antes del remate siguiente.
const PAUSA_SEG := 1.5
## Hasta cuánto dura un remate si nada lo termina.
const MAX_REMATE_SEG := 4.0
const GOLPES := ["colocado", "fuerte", "efecto", "globo", "cabeza"]
const RESULTADOS := ["gol", "atajado", "palo", "bloqueado", "afuera", "otro"]
const CLIPS := ["agarra", "abajo", "arriba", "vuela a su derecha", "vuela a su izquierda",
	"vuela alto a su derecha", "vuela alto a su izquierda"]
## La tanda: distancia al arco (m), lateral y alto del punto (m), golpe y
## lateral desde donde patea.
const TANDA := [
	[16.0, 0.0, 0.2, 0, 0.0], [16.0, 1.5, 0.2, 0, 0.0], [16.0, -2.5, 1.0, 1, 0.0], [20.0, 3.0, 1.9, 1, -4.0],
	[18.0, 2.8, 1.0, 2, -6.0], [22.0, -2.8, 1.5, 2, 6.0], [24.0, 0.5, 1.8, 3, 0.0], [11.0, -3.0, 1.9, 0, 0.0],
	[11.0, 2.0, 0.2, 1, 3.0], [28.0, 2.3, 0.2, 1, 0.0], [25.0, -1.5, 1.0, 1, -3.0], [14.0, 0.0, 1.0, 0, 5.0],
]

var _canchita: Object
var _vista: VistaV2
var _etiqueta: Label
var _semilla := SEMILLA
var _arquero := 70.0
var _tiro := 70.0
var _acumulado := 0.0
var _indice := -1
var _pasos := 0
var _pausa := -1.0
var _clip := ""
var _resultados := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for arg in OS.get_cmdline_user_args():
		var partes := arg.split("=", true, 1)
		if partes.size() != 2:
			continue
		match partes[0]:
			"semilla": _semilla = int(partes[1])
			"arquero": _arquero = float(partes[1])
			"tiro": _tiro = float(partes[1])
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		_medir()
		get_tree().quit()
		return
	_etiqueta = Label.new()
	_etiqueta.position = Vector2(16, 16)
	_etiqueta.add_theme_font_size_override("font_size", 24)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 6)
	add_child(_etiqueta)
	_siguiente()


## El remate siguiente de la tanda, con una canchita y una vista nuevas.
func _siguiente() -> void:
	_indice = (_indice + 1) % TANDA.size()
	var r: Array = TANDA[_indice]
	_canchita = ClassDB.instantiate("CanchitaV2Nativa")
	_canchita.configurar(FisicaV2.parametros(), FisicaV2.parametros_cuerpo(), FisicaV2.clips(),
		FisicaV2.parametros_toque())
	_canchita.configurar_remate(FisicaV2.parametros_remate(), FisicaV2.parametros_arquero())
	var a := {"velocidad": 70.0, "aceleracion": 70.0, "agilidad": 70.0, "pases": 70.0, "control": 70.0,
		"tiro": _tiro, "golpe": _tiro, "cabezazo": _tiro}
	_canchita.agregar(0, FisicaV2.jugador_de(a).merged(a))
	_canchita.agregar(0, FisicaV2.jugador_de(a).merged(a))
	var g := {"velocidad": 60.0, "aceleracion": 60.0, "agilidad": 60.0, "reflejos": _arquero, "estirada": _arquero,
		"agarre": _arquero, "achique": _arquero, "arquero": true}
	_canchita.agregar(1, FisicaV2.jugador_de(g).merged(g))
	_canchita.empezar(CanchitaV2Nativa.ARCO, _semilla + _indice)
	var x := 52.5 - float(r[0])
	var z := float(r[4])
	var rumbo := atan2(52.5 - x, -z)
	_canchita.poner_jugador(0, Vector2(x - 0.6 * sin(rumbo), z - 0.6 * cos(rumbo)), rumbo)
	_canchita.poner_jugador(1, Vector2(41.5, 1.0), PI * 0.5)
	_canchita.poner_jugador(2, Vector2(51.7, 0.0), -PI * 0.5)
	_canchita.rematar(0, int(r[3]), float(r[2]), float(r[1]))
	_canchita.lanzar(Vector3(x, 0.11, z), Vector3.ZERO, Vector3.ZERO, 0)
	if _vista != null:
		_vista.queue_free()
	_vista = VistaV2.new()
	_vista.equipos = _canchita.get_equipos()
	_vista.arqueros = _canchita.get_arqueros()
	_vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_vista)
	if _etiqueta != null:
		move_child(_etiqueta, -1)
	_pasos = 0
	_pausa = -1.0
	_clip = ""


func _process(delta: float) -> void:
	if _etiqueta == null:
		return
	_acumulado += delta
	var pasos := 0
	while _acumulado >= PASO_SEG and pasos < PASOS_MAX_POR_CUADRO:
		_avanzar()
		_acumulado -= PASO_SEG
		pasos += 1
	_acumulado = minf(_acumulado, PASO_SEG)
	_vista.dibujar_canchita(_canchita, _acumulado / PASO_SEG, delta)
	_etiqueta.text = _texto()
	if _pausa >= 0.0:
		_pausa += delta
		if _pausa >= PAUSA_SEG:
			_siguiente()


func _avanzar() -> void:
	_canchita.avanzar()
	_pasos += 1
	var accion: String = _canchita.get_accion(2)
	if accion != "" and _clip == "":
		_clip = accion
	if _pausa < 0.0 and (int(_canchita.get_ultimo_resultado()) >= 0 or _pasos * PASO_SEG >= MAX_REMATE_SEG):
		_pausa = 0.0


func _texto() -> String:
	var r: Array = TANDA[_indice]
	var t := "Remate %d de %d (toque: el siguiente)\n" % [_indice + 1, TANDA.size()]
	t += "%s desde %.0f m al punto (%.1f, %.1f)\n" % [GOLPES[int(r[3])], r[0], r[1], r[2]]
	var res := int(_canchita.get_ultimo_resultado())
	if res >= 0:
		t += "%s · el arquero: %s" % [RESULTADOS[res], _clip if _clip != "" else "no se tiró"]
	return t


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_pressed() and (evento is InputEventKey or evento is InputEventMouseButton
			or evento is InputEventScreenTouch):
		_siguiente()


## Sin pantalla: la tanda entera con la vista dibujando (sin mostrarse).
func _medir() -> void:
	var total := {}
	for k in TANDA.size():
		_siguiente()
		while _pausa < 0.0:
			_avanzar()
			_vista.dibujar_canchita(_canchita, 1.0, PASO_SEG)
		var r: Array = TANDA[_indice]
		var res := int(_canchita.get_ultimo_resultado())
		var nombre: String = RESULTADOS[res] if res >= 0 else "sin terminar"
		total[nombre] = int(total.get(nombre, 0)) + 1
		print("%s %s desde %.0f m al punto (%.1f, %.1f): %s; el arquero: %s" % [PREFIJO, GOLPES[int(r[3])], r[0], r[1],
			r[2], nombre, _clip if _clip != "" else "no se tiró"])
	print("%s total %s  correcciones %d" % [PREFIJO, total, _canchita.contadores()["correcciones"]])
