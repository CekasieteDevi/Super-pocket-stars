class_name ArbitroV2
extends RefCounted

## El árbitro del Motor V2 (docs/motor_v2.md, etapa 6). Es una capa visual,
## como OficialesPartido en el motor espacial: no decide nada. Sigue el juego
## a DISTANCIA_M de la pelota. Cuando el partido anota una tarjeta hace lo
## mismo que en VistaCancha3D (_tarjeta_en_curso): corre hasta el costado del
## jugador (a lo sumo CORRE_MAX_SEG), se para de frente a la cámara y muestra
## la tarjeta (Tarjeta_Completa). El motor corta al saque a los `tarjeta_seg`
## (data/fisica_v2.json, "reglas"): CORRE_MAX_SEG más lo que dura el gesto.
##
## Se mueve con el reloj del partido (los pasos), no con el de la pantalla:
## apurado a x16 llega igual.

const PASO_SEG := 1.0 / 60.0
## Cerca de la pelota, del lado del medio de la cancha (OficialesPartido).
const DISTANCIA_M := OficialesPartido.DISTANCIA_ARBITRO_M
## No sale a correr por cada metro que se mueve la pelota.
const HOLGURA_M := 3.0
const ACELERACION := 6.0
## En el penal: metros detrás del punto penal (hacia el medio) y hacia la
## banda de enfrente a la cámara.
const PENAL_ATRAS_M := 6.0
const PENAL_AL_COSTADO_M := 14.0
## En el córner: a esta distancia de la pelota (un poco más que la barrera,
## 9,15 m) y girado esto de la línea al medio de la cancha.
const PARADA_M := 11.0
const PARADA_GIRO_RAD := 0.6
## En el tiro libre, el lateral y el saque de arco: detrás de la pelota (del
## lado del arco del que saca) y al costado, hacia la banda de enfrente a la
## cámara. Hacia el medio de la cancha quedaba parado en la línea del pase:
## en la revisión visual de la etapa 7, "el juez se mete en el medio".
const PARADA_ATRAS_M := 4.0
const PARADA_AL_COSTADO_M := 8.0
## Lo más que tarda en llegar al jugador (VistaCancha3D.TARJETA_CORRE_MAX_TICKS).
const CORRE_MAX_SEG := VistaCancha3D.TARJETA_CORRE_MAX_TICKS * MotorEspacial.TICK_SEG
const CORRE_MIN_SEG := MotorEspacial.TICK_SEG
## A cuánto del jugador se para. Con los 1,8 m de VistaCancha3D
## (TARJETA_AL_LADO_M) quedaba lejos: esa vista acerca la cámara mucho más.
const AL_LADO_M := 1.1

var modelo: Jugador3D
var _tarjeta: MeshInstance3D
var _pos := Vector2(0.0, -DISTANCIA_M)
var _rapidez := 0.0
var _rumbo := 0.0
var _metros := 0.0
var _paso := -1
var _tarjeta_seg := 4.5
## La tarjeta en curso: paso del evento, de dónde salió, adónde va y cuánto tarda.
var _tarjeta_paso := -1
var _desde_pos := Vector2.ZERO
var _lugar := Vector2.ZERO
var _corre_seg := 0.0


func _init(mundo: Node3D) -> void:
	modelo = Jugador3D.new(load(VistaCancha3D.ESCENA_JUGADOR))
	mundo.add_child(modelo)
	modelo.colorear(OficialesPartido.COLOR_CAMISETA, OficialesPartido.COLOR_PANTALON, OficialesPartido.COLOR_PELO)
	modelo.poner_peinado(Jugador3D.PEINADO_OFICIAL)
	modelo.poner_cara(GestosCara.CARA_OFICIAL, Jugador3D.Gesto.NORMAL)
	_tarjeta = Utileria3D.tarjeta()
	_tarjeta.visible = false
	mundo.add_child(_tarjeta)
	_tarjeta_seg = float(FisicaV2.parametros_reglas().get("tarjeta_seg", _tarjeta_seg))


## `paso`: el paso del partido. `bola`: la pelota en la cancha ya girada.
## `tarjeta`: {} o {paso, roja, pos} de la última tarjeta (PartidoVistoV2.get_tarjeta).
## `parada`: {tipo, punto} de la parada en curso (PartidoVistoV2.get_parada).
func dibujar(paso: int, bola: Vector2, tarjeta: Dictionary, delta: float, parada := {}) -> void:
	var dt := 0.0 if _paso < 0 or paso < _paso else float(paso - _paso) * PASO_SEG
	if paso < _paso:
		# Otro partido: vuelve a su lugar.
		_pos = bola + Vector2(0.0, -DISTANCIA_M)
		_rapidez = 0.0
		_tarjeta_paso = -1
	_paso = paso
	_tarjeta.visible = false
	var desde := INF if tarjeta.is_empty() else float(paso - int(tarjeta["paso"])) * PASO_SEG
	if desde < _tarjeta_seg:
		_con_tarjeta(tarjeta, desde, dt, delta)
		return
	var al_medio := (-bola).normalized() if bola.length() > 1.0 else Vector2(0.0, -1.0)
	var destino := bola + al_medio * DISTANCIA_M
	var tipo := str(parada.get("tipo", "nada"))
	if tipo == "penal":
		# Al borde del área, del lado de la banda de enfrente a la cámara:
		# siguiendo a la pelota quedaba parado entre el que patea y el arco.
		var punto: Vector2 = parada["punto"]
		destino = Vector2(punto.x - signf(punto.x) * PENAL_ATRAS_M, -PENAL_AL_COSTADO_M)
	elif tipo == "tiro_libre" or tipo == "lateral" or tipo == "saque_arco":
		var punto: Vector2 = parada["punto"]
		# Hacia la banda de enfrente, salvo que la pelota ya esté contra ella.
		var medio_ancho := ProyeccionPartido.MEDIO_ANCHO
		var costado := 1.0 if punto.y < -medio_ancho + PARADA_AL_COSTADO_M + 2.0 else -1.0
		destino = punto + Vector2(-float(parada.get("ataca", 1.0)) * PARADA_ATRAS_M, costado * PARADA_AL_COSTADO_M)
		destino.x = clampf(destino.x, -ProyeccionPartido.MEDIO_LARGO + 2.0, ProyeccionPartido.MEDIO_LARGO - 2.0)
		destino.y = clampf(destino.y, -medio_ancho + 2.0, medio_ancho - 2.0)
	elif tipo != "nada" and tipo != "saque_medio":
		# En el córner, a la distancia de la barrera y corrido hacia la banda
		# de enfrente: no tapa al que saca.
		var punto: Vector2 = parada["punto"]
		var hacia := (-punto).normalized() if punto.length() > 1.0 else Vector2(0.0, -1.0)
		destino = punto + hacia.rotated(PARADA_GIRO_RAD * (1.0 if hacia.x * hacia.y >= 0.0 else -1.0)) * PARADA_M
		destino.y = clampf(destino.y, -ProyeccionPartido.MEDIO_ANCHO + 2.0, ProyeccionPartido.MEDIO_ANCHO - 2.0)
	elif _pos.distance_to(destino) < HOLGURA_M:
		destino = _pos
	var falta := _pos.distance_to(destino)
	# Frena para llegar parado: v² = 2·a·d.
	var tope := minf(VistaCancha3D.ARBITRO_CORRE_MS, sqrt(2.0 * ACELERACION * falta))
	_rapidez = move_toward(_rapidez, tope, ACELERACION * dt)
	if falta > 1e-3:
		var avance := minf(_rapidez * dt, falta)
		_rumbo = atan2(destino.x - _pos.x, destino.y - _pos.y)
		_pos += (destino - _pos) / falta * avance
		_metros += avance
	modelo.position = Vector3(_pos.x, 0.0, _pos.y)
	modelo.rotation.y = _rumbo if _rapidez > 0.3 else atan2(bola.x - _pos.x, bola.y - _pos.y)
	_andar(_rapidez, float(paso) * PASO_SEG, delta)


## Corre hasta el costado del jugador y le muestra la tarjeta.
func _con_tarjeta(tarjeta: Dictionary, desde: float, dt: float, delta: float) -> void:
	var jugador: Vector2 = tarjeta["pos"]
	# Al costado del jugador (a lo largo de la cancha, del lado del medio)
	# y un poco atrás: de frente a la cámara con el jugador al lado. Atrás
	# del todo, el jugador le tapaba la tarjeta (VistaCancha3D). En cada
	# cuadro: el jugador frena unos metros después de la falta, y con el lugar
	# calculado una sola vez el árbitro quedaba al lado del que la recibió.
	var lado := -signf(jugador.x) if absf(jugador.x) > 1.0 else 1.0
	_lugar = jugador + Vector2(lado * AL_LADO_M, -0.4)
	if int(tarjeta["paso"]) != _tarjeta_paso:
		_tarjeta_paso = int(tarjeta["paso"])
		_desde_pos = _pos
		_corre_seg = clampf(_desde_pos.distance_to(_lugar) / VistaCancha3D.ARBITRO_CORRE_MS, CORRE_MIN_SEG, CORRE_MAX_SEG)
	var antes := _pos
	_pos = _desde_pos.lerp(_lugar, smoothstep(0.0, _corre_seg, desde))
	var avance := _pos.distance_to(antes)
	_metros += avance
	# En los cuadros en que el partido no avanzó (dt = 0) queda la rapidez de
	# antes. Puesta en 0, el modelo pasaba a quieto un cuadro de cada dos y
	# llegaba deslizándose, sin mover las piernas.
	if dt > 0.0:
		_rapidez = avance / dt
	modelo.position = Vector3(_pos.x, 0.0, _pos.y)
	if desde < _corre_seg:
		if avance > 1e-4:
			_rumbo = atan2(_pos.x - antes.x, _pos.y - antes.y)
		modelo.rotation.y = _rumbo
		_andar(_rapidez, float(_paso) * PASO_SEG, delta)
		return
	_rapidez = 0.0
	# De frente a la cámara (a +z), como en VistaCancha3D.
	_rumbo = 0.0
	modelo.rotation.y = 0.0
	var t := desde - _corre_seg
	modelo.poner("Tarjeta_Completa", minf(t, modelo.duracion("Tarjeta_Completa")), delta)
	if t >= VistaCancha3D.TARJETA_EN_MANO.x and t <= VistaCancha3D.TARJETA_EN_MANO.y:
		_poner_tarjeta(bool(tarjeta["roja"]))


func _andar(rapidez: float, segundo: float, delta: float) -> void:
	var anim := VistaCancha3D.ANIM_QUIETO
	if rapidez >= VistaCancha3D.VELOCIDAD_PARA_PIERNAS:
		anim = VistaCancha3D._andar("Trotar", rapidez)
		if anim == VistaCancha3D.ANIM_QUIETO:
			anim = "Caminar"
	if anim == VistaCancha3D.ANIM_QUIETO:
		modelo.poner(anim, fposmod(segundo, maxf(modelo.duracion(anim), 0.01)), delta)
		return
	var clips := FisicaV2.clips()
	var ciclo := float(clips[anim].get("metros", VistaCancha3D.METROS_POR_CICLO)) if clips.has(anim) \
		else VistaCancha3D.METROS_POR_CICLO
	modelo.poner(anim, fposmod(_metros / ciclo, 1.0) * modelo.duracion(anim), delta)


## La tarjeta en la mano derecha, a lo largo del antebrazo (como VistaCancha3D._poner_utileria).
func _poner_tarjeta(roja: bool) -> void:
	_tarjeta.visible = true
	Utileria3D.pintar_tarjeta(_tarjeta, roja)
	var mano := DetectorPatinaV2.ancla_de(modelo, "Mano_R")
	var eje := modelo.hueso("Antebrazo.R").basis.y.normalized()
	var frente := modelo.global_transform.basis.z.normalized()
	_tarjeta.global_transform = Transform3D(Utileria3D.base_a_lo_largo(eje, frente), mano + eje * 0.07)


func foco() -> Vector2:
	return _pos


## Sigue donde estaba `otro`: el laboratorio arma la vista de nuevo cuando
## alguien entra o se va, y el árbitro no puede volver a su lugar del saque.
func copiar_de(otro: ArbitroV2) -> void:
	_pos = otro._pos
	_rapidez = otro._rapidez
	_rumbo = otro._rumbo
	_metros = otro._metros
	_paso = otro._paso
	_tarjeta_paso = otro._tarjeta_paso
	_desde_pos = otro._desde_pos
	_lugar = otro._lugar
	_corre_seg = otro._corre_seg
