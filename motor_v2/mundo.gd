class_name MundoV2
extends RefCounted

## El mundo del Motor V2 (docs/motor_v2.md, capa 1): la pelota y los 22
## cuerpos avanzan con un paso fijo de 1/60 s. Es la versión mínima de la
## etapa 0: sirve para medir si GDScript llega al presupuesto del teléfono
## (≤ 4 ms por cuadro con vista, ≤ 3 s por partido sin vista) antes de
## escribir nada grande.
##
## Los números de la pelota son de partida (docs/motor_v2.md, "La pelota");
## la etapa 1 los pasa a data/fisica_v2.json y los calibra contra video.
##
## Ejes: x a lo largo (hacia el arco visitante), y hacia arriba, z a lo
## ancho. Los cuerpos viven en el plano (x, z) y se guardan como Vector2
## (x, z), igual que las posiciones del motor espacial.
##
## Todo el estado está en arreglos empaquetados y no en un Dictionary por
## jugador: en GDScript cada lectura de un Dictionary es un hash.

const PASO_SEG := 1.0 / 60.0
const JUGADORES := 22
const GRAVEDAD := 9.81

## Cancha y arco, los mismos que el motor espacial.
const MEDIO_LARGO := ProyeccionPartido.MEDIO_LARGO
const MEDIO_ANCHO := ProyeccionPartido.MEDIO_ANCHO
const ARCO_MEDIO_ANCHO := MotorEspacial.ARCO_MEDIO_ANCHO
const ARCO_ALTO := MotorEspacial.ARCO_ALTO
const RADIO_PALO := 0.06

## Pelota FIFA talle 5: 0.43 kg, radio 0.11 m.
const RADIO_PELOTA := 0.11
const MASA_PELOTA := 0.43
## 0.5 * densidad del aire (1.2) * área (π 0.11²) / masa: la aceleración de
## arrastre es K_AIRE * Cd * |v| * v.
const K_AIRE := 0.5 * 1.2 * PI * RADIO_PELOTA * RADIO_PELOTA / MASA_PELOTA
const CD_RAPIDA := 0.25
const CD_LENTA := 0.45
## Debajo de esto el arrastre es el de pelota lenta (crisis de arrastre).
const VELOCIDAD_CRISIS := 12.0
## Sustentación por giro: Cl ≈ parámetro de giro (r ω / |v|), con tope.
const CL_TOPE := 0.35
## El giro pierde esta fracción por segundo.
const GIRO_DECAE := 0.12
## Pique: restitución vertical y rozamiento que frena lo horizontal.
const RESTITUCION_PISO := 0.62
const ROCE_PIQUE := 0.35
## Debajo de esta velocidad vertical deja de picar y rueda.
const VERTICAL_RUEDA := 0.6
## Frenado al rodar (m/s²): de 10 m/s se para en unos 40 m con el aire.
const FRENADO_RODANDO := 1.1
const RESTITUCION_PALO := 0.7
const RESTITUCION_CUERPO := 0.3
## La pelota rápida hace subpasos para no avanzar más que esto en uno: el
## pie de un jugador mide ~0.25 m.
const SUBPASO_MAX_M := 0.1

## Cuerpos: cápsulas de este radio y alto (el chibi a escala 0.75 mide ~1.7).
const RADIO_CUERPO := 0.35
const ALTO_CUERPO := 1.7

## Locomoción de partida (la etapa 2 la saca de `fisica` en utility_pesos.json).
const ACELERACION := 4.5
const FRENADA := 7.0
## Giro máximo (rad/s) parado y a toda velocidad: corriendo no gira en el lugar.
const GIRO_PARADO := 12.0
const GIRO_A_TOPE := 3.0

# --- Pelota ---
var pelota_pos := Vector3(0.0, RADIO_PELOTA, 0.0)
var pelota_vel := Vector3.ZERO
## Giro (rad/s) como vector: el eje por la magnitud.
var pelota_giro := Vector3.ZERO
var pelota_previa := Vector3(0.0, RADIO_PELOTA, 0.0)

# --- Cuerpos (índice 0..10 local, 11..21 visitante) ---
var pos := PackedVector2Array()
var pos_previa := PackedVector2Array()
var rumbo := PackedFloat32Array()
var rapidez := PackedFloat32Array()
var objetivo := PackedVector2Array()
var velocidad_max := PackedFloat32Array()
var masa := PackedFloat32Array()

var paso := 0
var rng := RandomNumberGenerator.new()

## Contadores para el reporte del banco.
var piques := 0
var golpes_palo := 0
var choques_cuerpos := 0
var choques_pelota := 0


func _init(semilla: int) -> void:
	rng.seed = semilla
	pos.resize(JUGADORES)
	rumbo.resize(JUGADORES)
	rapidez.resize(JUGADORES)
	objetivo.resize(JUGADORES)
	velocidad_max.resize(JUGADORES)
	masa.resize(JUGADORES)
	for i in JUGADORES:
		velocidad_max[i] = rng.randf_range(6.8, 8.6)
		masa[i] = rng.randf_range(65.0, 85.0)
		rumbo[i] = 0.0 if i < 11 else PI
	pos_previa = pos


## Un paso de 1/60 s: cuerpos, choques entre cuerpos, pelota.
func avanzar() -> void:
	pos_previa = pos
	pelota_previa = pelota_pos
	_mover_cuerpos()
	_separar_cuerpos()
	_mover_pelota()
	paso += 1


## Patea la pelota desde donde está (la etapa 2 lo hace en la ventana de
## contacto de la acción; acá es instantáneo).
func patear(velocidad: Vector3, giro: Vector3) -> void:
	pelota_vel = velocidad
	pelota_giro = giro


func poner_pelota(p: Vector3) -> void:
	pelota_pos = p
	pelota_previa = p
	pelota_vel = Vector3.ZERO
	pelota_giro = Vector3.ZERO


## Aceleración y frenada hacia el objetivo, con giro que se cierra con la
## velocidad. Llega frenando: la rapidez deseada es la que se puede frenar
## en la distancia que falta.
func _mover_cuerpos() -> void:
	var dt := PASO_SEG
	var p := pos
	var r := rumbo
	var v := rapidez
	for i in JUGADORES:
		var falta: Vector2 = objetivo[i] - p[i]
		var d := falta.length()
		var vi: float = v[i]
		var ri: float = r[i]
		var deseada := 0.0
		if d > 0.05:
			deseada = minf(velocidad_max[i], sqrt(2.0 * FRENADA * d))
			var angulo := atan2(falta.x, falta.y)
			var giro_max := lerpf(GIRO_PARADO, GIRO_A_TOPE, vi / 9.0) * dt
			var dif := wrapf(angulo - ri, -PI, PI)
			ri += clampf(dif, -giro_max, giro_max)
			# Lo que falta girar frena: a 90° del rumbo no se sigue a fondo.
			deseada *= maxf(0.0, cos(dif))
		if deseada > vi:
			vi = minf(deseada, vi + ACELERACION * dt)
		else:
			vi = maxf(deseada, vi - FRENADA * dt)
		v[i] = vi
		r[i] = ri
		p[i] += Vector2(sin(ri), cos(ri)) * (vi * dt)
	pos = p
	rumbo = r
	rapidez = v


## Dos cápsulas que se pisan se separan, cada una según la masa de la otra.
## Se miran los 231 pares: docs/motor_v2.md pedía una grilla de 5 m, pero en
## GDScript armarla y recorrerla costaba más que los pares con descarte por
## eje (12.9 contra 7.5 us por paso en la PC, medido en la etapa 0). Con
## 22 cuerpos no hace falta.
func _separar_cuerpos() -> void:
	var p := pos
	var minimo := RADIO_CUERPO * 2.0
	var minimo2 := minimo * minimo
	for i in JUGADORES - 1:
		var pi: Vector2 = p[i]
		for j in range(i + 1, JUGADORES):
			var entre: Vector2 = p[j] - pi
			if absf(entre.x) >= minimo or absf(entre.y) >= minimo:
				continue
			var d2 := entre.length_squared()
			if d2 < minimo2 and d2 > 0.000001:
				var d := sqrt(d2)
				var n := entre / d
				var mi: float = masa[i]
				var mj: float = masa[j]
				var hunde := minimo - d
				pi -= n * (hunde * mj / (mi + mj))
				p[j] += n * (hunde * mi / (mi + mj))
				choques_cuerpos += 1
		p[i] = pi
	pos = p


func _mover_pelota() -> void:
	var rapida := pelota_vel.length()
	var subpasos := maxi(1, ceili(rapida * PASO_SEG / SUBPASO_MAX_M))
	var dt := PASO_SEG / float(subpasos)
	for s in subpasos:
		_subpaso_pelota(dt)
	pelota_giro *= 1.0 - GIRO_DECAE * PASO_SEG
	_chocar_cuerpos()


func _subpaso_pelota(dt: float) -> void:
	var v := pelota_vel
	var p := pelota_pos
	var en_piso := p.y <= RADIO_PELOTA + 0.001 and absf(v.y) < 0.001
	var rapida := v.length()
	if en_piso:
		# Rodando: frenado constante más el aire; no hay Magnus contra el piso.
		var horizontal := Vector3(v.x, 0.0, v.z)
		var h := horizontal.length()
		var frena := (FRENADO_RODANDO + K_AIRE * CD_LENTA * h * h) * dt
		v = Vector3.ZERO if h <= frena else horizontal * ((h - frena) / h)
		p += v * dt
	else:
		var acel := Vector3(0.0, -GRAVEDAD, 0.0)
		if rapida > 0.01:
			var cd := CD_RAPIDA if rapida > VELOCIDAD_CRISIS else CD_LENTA
			acel -= v * (K_AIRE * cd * rapida)
			var w := pelota_giro.length()
			if w > 0.1:
				# Magnus: perpendicular a la velocidad y al eje de giro.
				var cl := minf(RADIO_PELOTA * w / rapida, CL_TOPE)
				acel += pelota_giro.cross(v) / w * (K_AIRE * cl * rapida)
		v += acel * dt
		p += v * dt
		if p.y < RADIO_PELOTA:
			p.y = RADIO_PELOTA
			if -v.y < VERTICAL_RUEDA:
				v.y = 0.0
			else:
				v.y = -v.y * RESTITUCION_PISO
				# El pique frena lo horizontal y le saca giro.
				v.x *= 1.0 - ROCE_PIQUE * 0.3
				v.z *= 1.0 - ROCE_PIQUE * 0.3
				pelota_giro *= 1.0 - ROCE_PIQUE
				piques += 1
	# Palos y travesaño: solo cerca de la línea de gol.
	if absf(p.x) > MEDIO_LARGO - 0.5 and absf(p.x) < MEDIO_LARGO + 0.5:
		var linea := signf(p.x) * MEDIO_LARGO
		for lado in [-1.0, 1.0]:
			var eje := Vector2(linea, lado * ARCO_MEDIO_ANCHO)
			if p.y < ARCO_ALTO + RADIO_PALO:
				var r := _rebote_en_eje(Vector2(p.x, p.z), Vector2(v.x, v.z), eje)
				if r.size() > 0:
					p.x = r[0].x
					p.z = r[0].y
					v.x = r[1].x
					v.z = r[1].y
		if absf(p.z) < ARCO_MEDIO_ANCHO:
			var r := _rebote_en_eje(Vector2(p.x, p.y), Vector2(v.x, v.y), Vector2(linea, ARCO_ALTO))
			if r.size() > 0:
				p.x = r[0].x
				p.y = r[0].y
				v.x = r[1].x
				v.y = r[1].y
	pelota_vel = v
	pelota_pos = p


## Choque de la pelota (círculo en un plano) con un palo (círculo): devuelve
## [posición, velocidad] corregidas o [] si no se tocan.
func _rebote_en_eje(p: Vector2, v: Vector2, eje: Vector2) -> Array:
	var entre := p - eje
	var d := entre.length()
	var minimo := RADIO_PELOTA + RADIO_PALO
	if d >= minimo or d < 0.0001:
		return []
	var n := entre / d
	var vn := v.dot(n)
	if vn < 0.0:
		v -= n * ((1.0 + RESTITUCION_PALO) * vn)
		golpes_palo += 1
	return [eje + n * minimo, v]


## La pelota que pega en un cuerpo rebota con poca energía (la cápsula no
## patea: eso es una acción).
func _chocar_cuerpos() -> void:
	var p := pelota_pos
	if p.y > ALTO_CUERPO + RADIO_PELOTA:
		return
	var plano := Vector2(p.x, p.z)
	var minimo := RADIO_CUERPO + RADIO_PELOTA
	for j in JUGADORES:
		var entre: Vector2 = plano - pos[j]
		if absf(entre.x) >= minimo or absf(entre.y) >= minimo:
			continue
		var d := entre.length()
		if d < minimo and d > 0.0001:
			var n := entre / d
			var vc := Vector2(sin(rumbo[j]), cos(rumbo[j])) * rapidez[j]
			var rel := Vector2(pelota_vel.x, pelota_vel.z) - vc
			var vn := rel.dot(n)
			plano = pos[j] + n * minimo
			if vn < 0.0:
				rel -= n * ((1.0 + RESTITUCION_CUERPO) * vn)
				pelota_vel.x = rel.x + vc.x
				pelota_vel.z = rel.y + vc.y
				choques_pelota += 1
	pelota_pos.x = plano.x
	pelota_pos.z = plano.y


## Huella del estado para comparar PC y Android (misma semilla, mismo partido).
func huella() -> int:
	return hash(var_to_bytes([pos, rumbo, rapidez, pelota_pos, pelota_vel, pelota_giro]))
