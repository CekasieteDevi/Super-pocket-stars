class_name ProyeccionPartido
extends RefCounted

## Proyección oblicua de la cancha — ÚNICO lugar donde se convierte
## simulación a pantalla. Todo el render (cancha, sprites, sombras,
## pelota, efectos) tiene que pasar por acá: si la proyección cambia,
## cambia todo junto y nada queda desalineado.
##
## El motor trabaja en metros con el origen en el centro de la cancha
## (105x68), X hacia el arco visitante e Y a lo ancho. Acá eso se
## convierte en píxeles con la cancha inclinada, no cenital.

const LARGO := 105.0
const ANCHO := 68.0
const MEDIO_LARGO := LARGO / 2.0
const MEDIO_ANCHO := ANCHO / 2.0

## Cuánto se aplasta la profundidad. 1.0 sería cenital puro; cuanto más
## bajo, más "acostada" se ve la cancha.
const COMPRESION_Y := 0.52

## Inclinación lateral: corre el fondo hacia un costado para que no se vea
## como un rectángulo de frente.
const SHEAR_X := 0.10

## Cuántos píxeles sube en pantalla un metro de altura de pelota. Es lo
## que hace legible que un centro va por arriba.
const ESCALA_Z := 0.85

## PEDIDO PENDIENTE: poder cambiar entre distintos ángulos de cámara.
## No hace falta rehacer nada — estas tres constantes SON el ángulo, y
## como toda la conversión pasa por sim_a_pantalla, alcanza con volverlas
## un preset seleccionable (por ejemplo: "lateral" con SHEAR 0 y
## compresión baja, "isométrico" con SHEAR alto, "cenital" con compresión
## 1.0). Lo único a cuidar es que la cámara relee metros_visibles(), así
## que el clamp se ajusta solo.


## La conversión. `centro_cam` es el punto de la cancha (en metros) que
## queda en el centro de la pantalla; `px_por_metro` es el zoom.
static func sim_a_pantalla(x: float, y: float, z: float,
		centro_cam: Vector2, px_por_metro: float, centro_pantalla: Vector2) -> Vector2:
	var rx := x - centro_cam.x
	var ry := y - centro_cam.y
	return centro_pantalla + Vector2(
		(rx + ry * SHEAR_X) * px_por_metro,
		(ry * COMPRESION_Y - z * ESCALA_Z) * px_por_metro)


## Igual pero recibiendo un Vector2 de cancha (sin altura).
static func punto(p: Vector2, centro_cam: Vector2, px_por_metro: float, centro_pantalla: Vector2) -> Vector2:
	return sim_a_pantalla(p.x, p.y, 0.0, centro_cam, px_por_metro, centro_pantalla)


## Cuántos metros de cancha entran en la pantalla con este zoom. Lo usa la
## cámara para no salirse de los bordes.
static func metros_visibles(tamano_pantalla: Vector2, px_por_metro: float) -> Vector2:
	return Vector2(
		tamano_pantalla.x / px_por_metro,
		tamano_pantalla.y / (px_por_metro * COMPRESION_Y))


## Un desplazamiento de cancha convertido a desplazamiento EN PANTALLA.
## Es la parte lineal de la proyección (sin cámara ni zoom), y es lo que
## hace falta para elegir hacia qué lado mira un sprite: moverse en +y de
## cancha se ve como bajar, no como ir a un costado.
static func direccion_pantalla(delta_sim: Vector2) -> Vector2:
	return Vector2(
		delta_sim.x + delta_sim.y * SHEAR_X,
		delta_sim.y * COMPRESION_Y)


## Profundidad para el Y-sort: el que está más abajo en pantalla se dibuja
## después (adelante). Se ordena por la Y de simulación, que es el eje que
## se aleja de la cámara.
static func profundidad(y_sim: float) -> float:
	return y_sim
