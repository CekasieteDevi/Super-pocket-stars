class_name Cancha3D
extends RefCounted

## Lo que comparten las vistas 3D del partido (VistaV2, ArbitroV2 y los
## laboratorios de motor_v2/): los modelos, la cámara, el estadio y cómo se
## elige el clip de andar. Salió de VistaCancha3D, la vista 3D del motor
## espacial, cuando se borró (docs/motor_v2.md, etapa 8).

const ESCENA_ESTADIO := "res://assets/3d/estadio.glb"
const ESCENA_JUGADOR := "res://assets/3d/jugador.glb"
const ESCENA_GOLERO := "res://assets/3d/golero.glb"
const ESCENA_PELOTA := "res://assets/3d/pelota.glb"

const RADIO_PELOTA := 0.11

## La pelota real (22 cm) al lado de un chibi de 1.7 m casi no se veía en la
## primera prueba. Se dibuja al doble; el motor sigue con su tamaño real.
const ESCALA_PELOTA := 2.0

## Ángulo de la cámara sobre el horizonte. Con 38° se veía demasiado desde
## arriba; el usuario pidió la altura de su vista de Blender (tribuna baja,
## ~9 m). 18° con lente abierta muestra mucha más cancha hacia el fondo.
const ELEVACION_CAMARA := 18.0
const FOV_HORIZONTAL := 60.0

## Con la cámara baja, la tribuna del lado de la cámara queda entre la
## cámara y la jugada cuando la pelota va por esa banda (tapaba media
## pantalla). Todo lo vertical que está más de estos metros detrás de la
## banda de cámara no se dibuja: tribuna, carteles (a 4 m) y torres. El
## piso sí, para que no quede un hueco abajo.
const DETRAS_DE_BANDA_M := 3.0

## El mismo verde oscuro del suelo exterior del estadio de Blender.
const COLOR_PISO_FONDO := Color("3e8c36")

## Materiales del estadio que son piso: nunca se cortan.
const MATERIALES_PISO := ["Cesped", "Cesped_2", "Tierra", "Lineas"]

## Metros de carrera por ciclo de la animación Correr (dos pasos). Los
## clips de andar van en cinta (el pie apoyado retrocede a la velocidad del
## cuerpo): con estos metros por ciclo el pie apoyado queda quieto en la
## cancha. Son los "metros" de data/acciones_v2.json; test_cuerpo_v2 lo
## controla. Antes 3,2 (el paso de los sprites), con clips hechos en el lugar.
const METROS_POR_CICLO := 2.2

## Por debajo del pique trota y despacio camina (m/s), con margen al cambiar.
## Metros de cada ciclo de piernas de esas animaciones (antes 1,5 y 2,4).
const ANDAR_CAMINA_HASTA_MS := 1.8
const ANDAR_TROTA_HASTA_MS := 4.6
const ANDAR_MARGEN_MS := 0.6

## Arriba de esto (m/s) mueve las piernas: con el pie de la pelota a 1,5 m/s
## se lo veía deslizar.
const VELOCIDAD_PARA_PIERNAS := 0.7

## El arquero en guardia da pasitos: recién corre más rápido que esto (m/s).
## Con la guardia a 2-3 m/s patinaba (medido con scratch/_detector_3d.gd).
const ARQUERO_CORRE_MS := 1.6

## Tarjeta: el árbitro corre a ARBITRO_CORRE_MS hasta el jugador. La tarjeta
## se ve en la mano entre estos segundos del clip Tarjeta_Completa.
const ARBITRO_CORRE_MS := 6.0
const TARJETA_EN_MANO := Vector2(0.375, 2.04)

## Parado sin acción: respira con los brazos sueltos (el "Quieto" del GLB es
## la pose original, con las manos en la cintura).
const ANIM_QUIETO := "Respirar"

## Si el arquero tiene que correrse menos que esto de costado, ataja parado:
## abajo (de rodilla), al pecho (Agarrar) o arriba (saltando). Si no, estirada
## baja o alta.
const PARADA_TRAVESIA_M := 1.0

## Cámara: zoom base del encuadre, en píxeles por metro de cancha (con ~22
## entra un cuarto de la cancha en un celular horizontal) y cuántas veces
## menos cancha muestra la vista 3D a lo ancho. Con 1,0 los chibis quedaban de
## ~20 px y solo se veían las cabezas.
const PX_POR_METRO_BASE := 22.0
const ACERCAMIENTO := 2.2
## Qué tan rápido alcanza la cámara su objetivo (por segundo). Alto = pega
## saltos, bajo = se queda colgada.
const SUAVIZADO_CAMARA := 3.2
## Metros fuera de la línea de fondo que la cámara puede mostrar (pista, muro
## y tribunas) y hasta dónde sigue a la pelota a lo ancho: con la cámara baja
## la profundidad visible es enorme hacia el fondo y corta hacia adelante.
const MARGEN_FONDO_M := 12.0
const MARGEN_LATERAL_M := 6.0


## Camina, trota o corre, con margen para no cambiar a cada rato cerca del
## límite.
static func andar(actual: String, velocidad: float) -> String:
	var margen := ANDAR_MARGEN_MS
	match actual:
		"Caminar":
			if velocidad > ANDAR_CAMINA_HASTA_MS + margen:
				return "Trotar" if velocidad <= ANDAR_TROTA_HASTA_MS else "Correr"
		"Trotar":
			if velocidad < ANDAR_CAMINA_HASTA_MS - margen:
				return "Caminar"
			if velocidad > ANDAR_TROTA_HASTA_MS + margen:
				return "Correr"
		_:
			if velocidad < ANDAR_TROTA_HASTA_MS - margen:
				return "Caminar" if velocidad < ANDAR_CAMINA_HASTA_MS else "Trotar"
	return actual
