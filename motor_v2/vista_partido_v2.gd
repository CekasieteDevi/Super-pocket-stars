class_name VistaPartidoV2
extends Control

## Etapa 8 del Motor V2 (docs/motor_v2.md): la pantalla del partido. Arma el
## partido de una receta (CerebroV2.armar_de_receta) y lo juega en vivo: cada
## cuadro avanza los pasos que tocan y la vista 3D (VistaV2) dibuja el estado
## del motor. El resultado ya se conoce (MotorV2.simular jugó la misma receta
## sin vista): acá se mira.
##
## Reusa el marcador y los controles (HudPartido), el minimapa y el relato
## (RelatoPartido) del juego. Los eventos traen el paso del motor en que
## pasaron: se cuentan cuando el partido llega a ese paso.

signal terminado

const PASO_SEG := 1.0 / 60.0
## Lo más que avanza en un cuadro: a x16 son 16 pasos por cuadro a 60 fps. El
## tope evita que un cuadro lento arrastre a los siguientes.
const PASOS_POR_CUADRO_MAX := 96
## Cuánto se acerca la cámara mientras el árbitro muestra la tarjeta.
const ACERCAMIENTO_TARJETA := 1.9
## Cuánto dura el cartel del gol (segundos de verdad).
const SEG_FESTEJO := 2.2
const SEG_PARPADEO := 0.35
## El número de periodo que muestra el marcador (HudPartido.periodo).
const PERIODO_DEL_MARCADOR := {"primer_tiempo": 1, "segundo_tiempo": 2, "alargue_1": 3, "alargue_2": 4, "tanda": 4,
	"terminado": 2}

var vista: VistaV2
var minimapa: Minimapa
var hud: HudPartido
var velocidad := 1.0
var pausado := false

## Lo que tardaron los pasos del motor en el último cuadro (ms): lo lee el
## banco del teléfono (motor_v2/banco_etapa8.gd).
var ms_motor := 0.0

var _partido: Object
var _visto: PartidoVistoV2
var _eventos: Array = []
var _idx_evento := 0
var _acumulado := 0.0
var _composicion := PackedInt32Array()
## El estadio del local (VistaV2.poner_estadio).
var _nivel_estadio := ""
var _terminado := true
var _nombres: Dictionary = {}
## Lo que no cambia en el partido: el color de cada equipo, el del arquero y,
## por id de jugador, el número y el pelo.
var _camisetas := [Color.WHITE, Color.WHITE]
var _arqueros := [Color.WHITE, Color.WHITE]
var _shorts := [Color.TRANSPARENT, Color.TRANSPARENT]
var _por_id: Dictionary = {}
var _tarjeta_seg := 4.5
var _corte_visto := -1

var _relato_restante := 0.0
var _relato_total := 1.0
var _relato_peso := RelatoPartido.NADA
var _festejo_restante := 0.0
var _parpadeo_restante := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	minimapa = Minimapa.new()
	add_child(minimapa)
	hud = HudPartido.new()
	add_child(hud)
	hud.velocidad_pedida.connect(func(v: float): velocidad = v)
	hud.pausa_pedida.connect(func():
		pausado = not pausado
		hud.marcar_pausa(pausado))
	hud.saltar_pedido.connect(saltar_al_final)
	set_process(true)


## `receta` y `eventos`: los de MotorV2.simular. Los equipos, para los colores,
## los números y los nombres (pueden haber cambiado con el partido: acá solo
## se lee cómo se ven).
func iniciar(receta: Dictionary, eventos: Array, local: Team, visitante: Team) -> void:
	_partido = CerebroV2.armar_de_receta(receta)
	_visto = PartidoVistoV2.new(_partido)
	_eventos = eventos
	_idx_evento = 0
	_acumulado = 0.0
	_composicion = PackedInt32Array()
	_terminado = false
	pausado = false
	_relato_restante = 0.0
	_festejo_restante = 0.0
	_parpadeo_restante = 0.0
	_corte_visto = -1
	_tarjeta_seg = float((receta["reglas"] as Dictionary).get("tarjeta_seg", 4.5))
	_nivel_estadio = EstadoCancha.nivel_estadio(local.calidad_cancha)
	_nombres = RelatoPartido.nombres(local, visitante)
	var colores := ColoresClub.par_equipos(local, visitante)
	_camisetas = [colores[0], colores[1]]
	_arqueros = ColoresClub.arqueros(colores[0], colores[1])
	_shorts = [local.color_short, visitante.color_short]
	_por_id.clear()
	for equipo in [local, visitante]:
		for j in (equipo as Team).todos_los_jugadores():
			var id := int(j["id"])
			_por_id[id] = {"numero": (equipo as Team).dorsal_de(id), "pelo": AtlasJugadores.tono_pelo_de(id)}
	hud.nombre_local = local.nombre
	hud.nombre_visitante = visitante.nombre
	hud.nombre_local_marcador = _corto(local)
	hud.nombre_visitante_marcador = _corto(visitante)
	hud.color_local = colores[0]
	hud.color_visitante = colores[1]
	hud.configurar_identidades(local.identidad_visual(), visitante.identidad_visual())
	hud.relato = ""
	hud.festejo = 0.0
	hud.marcar_pausa(false)
	_rearmar_vista()
	_mostrar(1.0, 0.0)


static func _corto(equipo: Team) -> String:
	var corto := equipo.abreviacion.strip_edges()
	return corto if corto != "" else equipo.nombre


## La vista tiene un Jugador3D por cada uno. Si alguien entra o se va, la
## vista cambia solo a esos (VistaV2.recomponer): armarla entera trababa un
## cuadro 148 ms en el teléfono.
func _rearmar_vista() -> void:
	_visto.actualizar()
	var ids := _visto.ids()
	if ids == _composicion and vista != null:
		return
	_composicion = ids
	var equipos := _visto.equipos()
	var arqueros := _visto.arqueros()
	var ropa := []
	for i in ids.size():
		var e := int(equipos[i])
		var dato: Dictionary = _por_id.get(int(ids[i]), {})
		ropa.append({
			"camiseta": _arqueros[e] if int(arqueros[i]) == 1 else _camisetas[e],
			"short": _shorts[e],
			"pelo": dato.get("pelo", Color("3b2618")),
			"numero": int(dato.get("numero", 0)),
		})
	if vista != null:
		vista.recomponer(equipos, arqueros, ids, ropa)
		vista.poner_estadio(_nivel_estadio)
		return
	vista = VistaV2.new()
	vista.nivel_estadio = _nivel_estadio
	vista.equipos = equipos
	vista.arqueros = arqueros
	vista.ids = ids
	vista.ropa = ropa
	# Como la vista del juego: sin la sombra del sol en los personajes y con
	# una mancha debajo de cada uno (docs/motor_v2.md, etapa 0).
	# En el teléfono, con el sol prendido solo para el estadio el banco de la
	# etapa 8 daba 42 fps y 236 llamadas de dibujo.
	vista.sombras = false
	vista.sombras_redondas = true
	vista.personajes_con_sombra_sol = false
	vista.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vista)
	# Atrás de todo: el minimapa y el marcador quedan arriba.
	move_child(vista, 0)


func _fin() -> bool:
	return str(_partido.get_estado()["periodo"]) == "terminado"


func _process(delta: float) -> void:
	# Con el panel oculto el partido no corre (como la vista vieja).
	if not is_visible_in_tree() or _terminado or _partido == null:
		return
	if pausado:
		return
	_avanzar_efectos(delta)
	_acumulado += delta * velocidad
	var pasos := 0
	var t0 := Time.get_ticks_usec()
	while _acumulado >= PASO_SEG and pasos < PASOS_POR_CUADRO_MAX and not _fin():
		_partido.avanzar()
		_acumulado -= PASO_SEG
		pasos += 1
	ms_motor = float(Time.get_ticks_usec() - t0) / 1000.0
	_acumulado = minf(_acumulado, PASO_SEG)
	_narrar()
	_rearmar_vista()
	_mostrar(_acumulado / PASO_SEG, delta)
	if _fin():
		_finalizar()


## Salta al resultado sin dibujar lo del medio.
func saltar_al_final() -> void:
	if _partido == null or _terminado:
		return
	var pasos := 0
	while not _fin() and pasos < MotorV2.PASOS_TOPE:
		_partido.simular(600)
		pasos += 600
	# Saltar no narra ni festeja.
	_idx_evento = _eventos.size()
	_relato_restante = 0.0
	_festejo_restante = 0.0
	hud.relato = ""
	hud.festejo = 0.0
	_rearmar_vista()
	_mostrar(1.0, 0.0)
	call_deferred("_finalizar")


func _finalizar() -> void:
	if _terminado:
		return
	_terminado = true
	terminado.emit()


## Los temporizadores del relato y del cartel del gol corren en segundos de
## verdad: son tiempo de lectura, no de partido.
func _avanzar_efectos(delta: float) -> void:
	if _relato_restante > 0.0:
		_relato_restante = maxf(_relato_restante - delta, 0.0)
		hud.relato_alfa = clampf(_relato_restante / (_relato_total * 0.3), 0.0, 1.0)
		if _relato_restante == 0.0:
			hud.relato = ""
	if _festejo_restante > 0.0:
		_festejo_restante = maxf(_festejo_restante - delta, 0.0)
	hud.festejo = _festejo_restante / SEG_FESTEJO
	if _parpadeo_restante > 0.0:
		_parpadeo_restante = maxf(_parpadeo_restante - delta, 0.0)
	hud.parpadeo = _parpadeo_restante / SEG_PARPADEO


## Cuenta los eventos a los que el partido ya llegó. Si en el mismo cuadro
## entran varios, gana el más importante.
func _narrar() -> void:
	var paso := int(_partido.get_estado()["paso"])
	var mejor = null
	var mejor_peso := RelatoPartido.NADA
	while _idx_evento < _eventos.size() and int(_eventos[_idx_evento]["paso"]) <= paso:
		var ev: Dictionary = _eventos[_idx_evento]
		_idx_evento += 1
		var peso := RelatoPartido.importancia(ev)
		if peso > mejor_peso:
			mejor_peso = peso
			mejor = ev
	if mejor == null or (_relato_restante > 0.0 and mejor_peso < _relato_peso):
		return
	var texto := RelatoPartido.linea(mejor, _nombres)
	if texto == "":
		return
	hud.relato = texto
	_relato_peso = mejor_peso
	_relato_total = float(RelatoPartido.SEG_RELATO.get(mejor_peso, 2.0))
	_relato_restante = _relato_total
	hud.relato_alfa = 1.0
	if str(mejor.get("resultado", "")) == "gol" and str(mejor.get("tipo", "")) in ["tiro_puerta", "penal"]:
		_festejo_restante = SEG_FESTEJO


## Dibuja la cancha, el minimapa y el marcador con el estado de ahora.
func _mostrar(alfa: float, delta: float) -> void:
	var estado: Dictionary = _partido.get_estado()
	# El corte al saque después de una tarjeta: el parpadeo del marcador.
	if int(estado["corte"]) != _corte_visto:
		_corte_visto = int(estado["corte"])
		if _corte_visto >= 0:
			_parpadeo_restante = SEG_PARPADEO
	vista.foco = _visto.foco(_tarjeta_seg)
	vista.acercamiento = ACERCAMIENTO_TARJETA if not _visto.tarjeta_en_curso(_tarjeta_seg).is_empty() else 1.0
	vista.dibujar_canchita(_visto, alfa, delta)

	var pos := _visto.get_pos()
	var equipos := _visto.equipos()
	var arqueros := _visto.arqueros()
	var ents := []
	for i in pos.size():
		var e := int(equipos[i])
		ents.append({"tipo": "jugador", "pos": pos[i], "color": _arqueros[e] if int(arqueros[i]) == 1 else _camisetas[e]})
	var bola := _visto.get_pelota_pos()
	ents.append({"tipo": "pelota", "pos": Vector2(bola.x, bola.z)})
	minimapa.position = size - minimapa.size - Vector2.ONE * Minimapa.MARGEN_PX
	minimapa.entidades = ents
	minimapa.encuadre = vista.encuadre_metros()
	minimapa.queue_redraw()

	var goles: PackedInt32Array = _partido.get_goles()
	hud.goles_local = int(goles[0])
	hud.goles_visitante = int(goles[1])
	hud.minuto = int(float(estado["minuto"]))
	hud.periodo = int(PERIODO_DEL_MARCADOR.get(str(estado["periodo"]), 2))
	var pateados := Vector2i(estado["pateados_tanda"])
	if str(estado["periodo"]) == "tanda" or pateados != Vector2i.ZERO:
		var adentro := Vector2i(estado["goles_tanda"])
		hud.tanda = {"home": adentro.x, "away": adentro.y}
	else:
		hud.tanda = {}
	var poseedor := int(_partido.get_poseedor())
	var ids: PackedInt32Array = _partido.get_ids()
	hud.poseedor = ""
	if poseedor >= 0 and poseedor < ids.size():
		var es_local := int(_partido.get_equipos()[poseedor]) == 0
		hud.poseedor = str(_nombres.get(BasePartido.clave_de(int(ids[poseedor]), es_local), ""))
	hud.queue_redraw()
