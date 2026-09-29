class_name VistaCancha3D
extends VistaCancha

## Vista 3D del partido. Reemplaza a VistaCancha sin tocar a VistaPartido.
##
## Hereda de VistaCancha solo para cumplir el mismo contrato: VistaPartido
## escribe `entidades`, `camara`, `estado_cancha` y `euforia` y pide
## queue_redraw(). Acá no se dibuja nada en 2D: cada cuadro se leen las
## entidades y se mueven los modelos de un SubViewport 3D.
##
## Ejes: el motor usa metros con X a lo largo e Y a lo ancho. En Godot la X
## queda igual, la Y del motor pasa a Z y la altura va en Y. La Y del motor
## crece hacia la tribuna de cámara, igual que Z hacia la cámara 3D.

const ESCENA_ESTADIO := "res://assets/3d/estadio.glb"
const ESCENA_JUGADOR := "res://assets/3d/jugador.glb"
const ESCENA_GOLERO := "res://assets/3d/golero.glb"
const ESCENA_PELOTA := "res://assets/3d/pelota.glb"

const RADIO_PELOTA := 0.11

## La pelota real (22 cm) al lado de un chibi de 1.7 m casi no se veía en la
## primera prueba. Se dibuja al doble; el motor sigue con su tamaño real.
const ESCALA_PELOTA := 2.0

## En 2D la pelota se dibuja en el mismo punto que los pies y se lee como
## "adelante". En 3D ese punto queda entre las piernas: la pelota del que
## conduce se corre hacia adelante. 0.4 m = punta del botín del chibi
## (0.17 m a escala 0.75) + radio dibujado de la pelota (0.22 m).
const PELOTA_DELANTE_M := 0.4

## Distancias (m) entre pelota y jugador en las que el corrimiento va de
## completo a cero. Gradual para que pases y recepciones no peguen saltos.
const CONDUCE_CERCA_M := 0.35
const CONDUCE_LEJOS_M := 1.0

## Arriba de esta altura la pelota va por el aire y no se corre.
const CONDUCE_ALTURA_M := 0.35
## Velocidad tope (m/s de partido) con que la pelota conducida se acomoda
## adelante del pie.
const CONDUCCION_VELOCIDAD := 3.0

## Tiro bloqueado. El motor graba el remate y el bloqueo en el MISMO tick, con
## el defensor pegado al que patea (o detrás), y la pelota sale rebotada
## desde el pie: no se veía ni el tiro ni el bloqueo. En 3D se arma la
## jugada: el defensor se para entre la pelota y el arco mirando al que
## patea, el remate sale hacia el arco, le pega en la pierna y rebota por
## donde la manda el motor.
const BLOQUEO_DISTANCIA_M := 0.95   # de la pelota a la pierna del defensor
const BLOQUEO_VIAJE_TICKS := 0.25   # del pie del que patea a la pierna
const BLOQUEO_REBOTE_TICKS := 0.9   # de la pierna al recorrido del motor
const BLOQUEO_LLEGA_TICKS := 1.5    # cuánto antes del remate se acomoda
const BLOQUEO_SUELTA_TICKS := 2.5   # cuánto después vuelve a su lugar

## Atajada. El motor dobla el remate en el último tick para que termine donde
## está el arquero (en el partido de muestra, 2.3 m): se veía la pelota
## desviarse sola hacia las manos. En 3D la pelota sigue recta desde el pie
## y es el arquero el que se corre hasta la línea del tiro.
const ATAJADA_LLEGA_TICKS := 2.0    # cuánto antes de agarrarla se empieza a correr
const ATAJADA_SUELTA_TICKS := 3.0   # cuánto tarda en volver a su lugar después
const ATAJADA_MAX_M := 3.5          # más lejos que esto no se arma (otra jugada)
## Altura de las manos del arquero en el cuadro de agarre de "Agarrar"
## (medida en la muestra: 0.52-0.58 m).
const ALTURA_MANOS_ATAJADA_M := 0.55

## Tiro con efecto: el motor ya curva la pelota (una Bézier que viaja en
## `pelota.trayectoria`), pero el reproductor une los ticks con rectas y la
## deja casi al ras. Acá va por la curva y sube en arco: CURVA_ARCO_M de panza
## y entra a CURVA_ENTRA_M; después cae en la red.
const CURVA_ARCO_M := 1.0
const CURVA_ENTRA_M := 1.2
## El que patea con efecto se acomoda (dos pasos cortos, abre los brazos) los
## últimos ticks antes del remate, si no viene muy rápido.
const ANIM_REMATE_EFECTO := "Remate_Efecto"
const ANIM_EFECTO_ACOMODA := "Efecto_Acomoda"
const EFECTO_ACOMODA_TICKS := 3.0
const EFECTO_ACOMODA_VELOCIDAD_MAX := 6.0

## Cuerpos sólidos (solo en 3D): el motor no choca a los jugadores entre sí
## (en un duelo quedan a 0.2 m, y el Laboratorio apila en el mismo punto a
## los que no juegan). Cada cuadro se separan hasta esta distancia entre
## centros: el ancho del pelo del chibi (~0.7 m).
const SEPARACION_CUERPOS_M := 0.72
## Qué tan rápido el dibujo sigue al corrimiento (1/s de partido). Suave para que al
## separarse o volver no pegue saltos; en un salto de reproducción, directo.
## 16 y no 10: en los duelos el motor los junta a 0.2 m de golpe y con 10
## quedaban encimados (a menos de 0.4 m) un rato, ~20 veces por partido.
const SUAVIZADO_CUERPOS := 16.0

## Caída y lesión: el chibi queda tendido hacia adelante (la cabeza ~1 m más
## allá del pie) y el motor deja al que lo barrió a 0.35 m: se veían uno
## encima del otro. Solo en 3D el tendido se corre hasta que su cadera y el
## centro de su cuerpo queden a esta distancia de los demás.
const TENDIDOS := ["cae", "lesionado"]
const SEPARACION_TENDIDO_M := 0.8
## Del pie al centro del cuerpo tendido (cadera 0.52 y coronilla 1.95 del
## modelo, por ESCALA_CHIBI).
const CENTRO_TENDIDO_M := 0.55

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

## Metros de carrera por ciclo de la animación Correr (dos pasos). Es el
## mismo paso de 1.6 m que usa VistaPartido._pose para los sprites.
const METROS_POR_CICLO := 3.2
## Por debajo del pique trota y despacio camina (m/s), con margen al cambiar.
## Metros de cada ciclo de piernas de esas animaciones.
const ANDAR_CAMINA_HASTA_MS := 1.8
const ANDAR_TROTA_HASTA_MS := 4.6
const ANDAR_MARGEN_MS := 0.6
const ANDAR_SUAVIZADO := 2.5
const CICLO_CAMINAR_M := 1.5
const CICLO_TROTAR_M := 2.4
## Qué tan rápido (m/s de partido) la pelota toma o suelta el desvío del que
## la lleva (regate, recepción).
const DESVIO_PELOTA_VELOCIDAD := 8.0
## En el festejo el suavizado de los del grupo se apaga en estos ticks.
const FESTEJO_SUELTA_TICKS := 1.5
## Un cambio del desvío mayor que esto en un cuadro es un salto y se suaviza.
const DESVIO_PELOTA_SALTO_M := 0.4
## Forcejeo: el rival a menos de esto del que lleva la pelota, los dos
## corriendo (más de este paso por tick) hacia el mismo lado, y cuánto dura
## después de separarse (ticks).
const FORCEJEO_DISTANCIA_M := 1.3
const FORCEJEO_PASO_MIN_M := 0.5
const FORCEJEO_MANTIENE_TICKS := 1.0
## Trabada: el robo de cerca (m) y cuánto antes del tick del robo mete la
## pierna (ticks).
const QUITE_DISTANCIA_M := 3.0
const QUITE_ANTES_TICKS := 0.6
const QUITE_BUSCA_TICKS := 12
const QUITE_PASE_FUERTE_MS := 10.0
## Pelota suelta en los pies: a cuánto (m), cuántos ticks para atrás se busca
## y cuánto antes de que llegue arranca el control.
const CONTROL_SUELTO_DISTANCIA_M := 0.9
const CONTROL_SUELTO_BUSCA_TICKS := 5
const CONTROL_SUELTO_ANTES_TICKS := 0.4

## VistaPartido guarda `fase_animacion` de la carrera como metros * 2.5.
const FASE_POR_METRO := 2.5

## Por debajo de esta velocidad (m/s) el rumbo sale de la orientación del
## motor y no del movimiento: parado, el ruido de posición hace girar.
const VELOCIDAD_PARA_RUMBO := 0.8
## Arriba de esto (m/s de partido) mueve las piernas aunque el 2D lo dibuje
## quieto: con el pie de la pelota a 1.5 m/s se lo veía deslizar.
const VELOCIDAD_PARA_PIERNAS := 0.7
## El arquero en guardia da pasitos: recién corre más rápido que esto (m/s).
## Con la guardia a 2-3 m/s patinaba (medido con scratch/_detector_3d.gd).
const ARQUERO_CORRE_MS := 1.6
## Suavizado del recorrido del que regatea (ver _desvio_de_regate): media
## ventana del promedio y cuánto sigue después de terminar el regate.
const REGATE_SUAVIZADO_TICKS := 1.2
const REGATE_SUAVIZADO_DESPUES := 2.0
## Recepciones con el recorrido promediado (ver _leer_gestos): desde un poco
## antes del control y hasta que termina de acelerar.
const RECEPCIONES_FLUIDAS := ["control_pie", "pecho"]
const RECEPCION_ANTES_TICKS := 0.5
const RECEPCION_DESPUES_TICKS := 2.0
## Media ventana del promedio en las recepciones: más larga que en los
## regates, así arranca a moverse mientras controla.
const RECEPCION_SUAVIZADO_TICKS := 1.8
## Desde esta fase del control, si ya se mueve, pasa a correr.
const RECEPCION_LISTA_FASE := 0.45
## En el control con el pie el toque es enseguida: ya puede salir corriendo.
const CONTROL_LISTA_FASE := 0.2
## Control con el pie (pase por el suelo): cuánto adelantado en el tiempo se
## lo dibuja desde el control, y hasta qué tick después lo devuelve.
const CONTROL_ADELANTO_TICKS := 0.0
const CONTROL_ADELANTO_VUELVE_TICKS := 16.0
## Centro que cae y se controla (3D-09, ver _preparar_centros): el motor lo
## deja caer, rodar y lo controla con el pie. En 3D sigue en el aire hasta el
## pecho del receptor, que llega antes al punto.
const CENTRO_BUSCA_TICKS := 6         # de la caída al control, como mucho
const CENTRO_ALTO_M := 1.4            # venía por arriba (como en el motor)
const CENTRO_DESDE_M := 3.0           # el vuelo se redibuja desde esta altura
const CENTRO_TOMA_M := 0.6            # el receptor del motor llega a la pelota
const CENTRO_CAIDA_MAX_MS := 12.0     # bajando hasta el pecho, como mucho
const CENTRO_VUELO_MIN_TICKS := 0.5
const CENTRO_LLEGA_RITMO := 0.15      # ritmo del recorrido del receptor al tomarla
const CENTRO_ANTES_POR_ADELANTO := 2.0  # ticks que corre de más por tick de adelanto
const CENTRO_CORRE_MAX_MS := 8.0      # yendo a la toma, como mucho (o lo que corre en el motor)
const CENTRO_ATRASO_MAX_TICKS := 0.75 # la toma en el aire se atrasa hasta esto; si no, pica
const CENTRO_VUELVE_TICKS := 5.0      # de la toma a ponerse al día, si no toca antes
const CENTRO_PIQUE_MIN_TICKS := 0.75  # del pique a la toma, como poco
const GRAVEDAD := 9.8
const CENTRO_SUELTA_TICKS := 0.6      # al final se junta con la pelota de siempre
## El defensor que compra el amague (ver _registrar_comprador): hasta qué
## distancia del que regatea cuenta, cuántos ticks dura su intento y desde qué
## segundo de Quitar arranca (el estirón del pie cae ~0.25 s después, con la
## pelota yéndose para el lado del amague).
## Salida en diagonal de la elástica (ver _corte_de_elastica): cuánto se corre
## para el lado de la pelota, entre qué ticks desde el inicio del regate, y
## cuándo empieza a devolverlo (en 10 ticks).
const CORTE_ELASTICA_M := 1.1
const CORTE_DESDE_TICKS := 1.1
const CORTE_HASTA_TICKS := 3.0
const CORTE_VUELVE_TICKS := 8.0
## Lateral: el corte deja al que saca en la banda este tanto antes del saque,
## levantando la pelota (Lateral_Prepara dura 3 ticks).
const LATERAL_PREPARA_TICKS := 3.0
## Tarjeta: el árbitro corre a ARBITRO_CORRE_MS (a lo sumo tantos ticks), se
## para a TARJETA_AL_LADO_M del jugador y Tarjeta_Completa dura TARJETA_TICKS;
## la tarjeta se ve en la mano entre esos segundos de la animación.
const ARBITRO_CORRE_MS := 6.0
const TARJETA_CORRE_MAX_TICKS := 8.0
const TARJETA_AL_LADO_M := 1.8
const TARJETA_TICKS := 10.0
const TARJETA_EN_MANO := Vector2(0.375, 2.04)
## Tiro libre: barrera solo si la pelota está a menos de esto del arco.
## Corner: cuántos ticks antes del saque levanta el brazo el que patea.
const BARRERA_HASTA_ARCO_M := 35.0
## Altura del tiro libre (ver _armar_vuelo_del_tiro_libre): por arriba de la
## barrera (que salta hasta ~2 m), al entrar al arco (travesaño 2.44) y
## cuando pega en la barrera.
const BARRERA_ALTO_M := 2.35
const TIRO_LIBRE_ENTRA_M := 1.5
const BARRERA_PEGA_M := 1.1
## Rebote en la barrera: cuánto tarda en caer (ticks), cuánto sube de más al
## pegar (m) y el pique en el piso (m).
const REBOTE_TICKS := 1.1
const REBOTE_SUBE := 2.4
const REBOTE_PIQUE_M := 0.3
## Un rebote largo (en un partido el motor deja la pelota cerca del que pateó)
## tarda más: va a esta velocidad (m por tick), no en REBOTE_TICKS.
const REBOTE_M_POR_TICK := 4.0

## Palo y travesaño. El motor lleva el remate al palo por el piso hasta la
## línea (su altura cae a 0 al llegar) y, si sale por el fondo, la deja ahí
## quieta hasta el saque de arco. El 3D la lleva a pegar en el marco del
## estadio (medido en estadio.glb) y arma el rebote (ver _preparar_palos).
const POSTE_Y_M := 3.72          # centro del poste
const MARCO_ATRAS_M := 0.05      # centro del marco detrás de la línea
const TRAVESANO_Y_M := 2.50      # centro del travesaño
const MARCO_RADIO_M := 0.06
## Alto del centro de la pelota al pegar en el poste, por el golpe que la mandó.
const PALO_ALTO_M := {MotorEspacial.ACCION_CABECEA: 1.1, MotorEspacial.ACCION_PALOMITA: 1.0,
	"volea": 0.9, "chilena": 1.0}
const PALO_ALTO_PIE_M := 0.55
## En juego o al córner: el rebote vuelve al recorrido del motor en este tiempo.
const PALO_REBOTE_TICKS := 1.0
const TRAVESANO_REBOTE_TICKS := 1.2
## Afuera por el fondo: vuela por arriba de la red, pica detrás del arco y
## rueda un poco. SUBE es la pendiente de salida (metros por vuelo entero).
const PALO_SALE_VUELO_TICKS := 1.3
const PALO_SALE_RUEDA_TICKS := 1.0
const PALO_SALE_FONDO_M := 3.6
const PALO_SALE_RUEDA_M := 1.0
const PALO_SALE_COSTADO_M := 3.2
const TRAVESANO_SALE_SUBE := 6.0
const PALO_SALE_SUBE := 1.2
const PALO_PIQUE_M := 0.35
## Gol pegando en el palo: del poste a la red.
const PALO_GOL_TICKS := 0.6
## La pelota pega un poco antes de los cuerpos de la barrera.
const BARRERA_PEGA_ANTES_M := 0.35
## Pelota alta que cae suelta (3D-10, ver _preparar_piques). Vuelos más bajos
## que PIQUE_ALTO_M no se tocan: un pase bombeado corto casi no pica.
const PIQUE_ALTO_M := 2.0
const PIQUE_BUSCA_TICKS := 16         # de la caída a que alguien la toma, como mucho
## Pelota de fútbol en pasto: en cada pique conserva la mitad de la velocidad
## vertical y el 60% de la horizontal (roce y efecto). Con eso el saque de
## arco del minuto 24 (semilla 5) pica a 2 m, después a 0.5 m, y llega al
## receptor a ~4 m/s; antes llegaba a 24 m/s y en un tick quedaba a 1 m/s.
const PIQUE_RESTITUCION := 0.5
const PIQUE_ROCE := 0.6
const PIQUE_MIN_M := 0.05             # un pique más bajo ya es rodar
const PIQUE_RUEDA_SEG := 1.2          # rodando, la velocidad cae a 1/e en esto
const PIQUE_ENTRA_TICKS := 0.3        # del golpe (en el pie), se pasa al vuelo nuevo
const PIQUE_SUELTA_TICKS := 0.5       # al tomarla, se junta con la pelota de siempre
## Cámara hacia el oficial que marca: cuánto del camino hacia él (0..1), qué
## tan rápido va y vuelve (1/s) y cuánto se acerca en cada señal.
const FOCO_OFICIAL_TIRA := 1.0
const FOCO_OFICIAL_VELOCIDAD := 1.0
## Más lejos que esto de lo que se está mirando, la cámara corta al oficial.
const FOCO_OFICIAL_CORTE_M := 25.0
## Cambio con el juego parado (3D-07): el foco del fotograma sigue al que sale
## y al que entra hasta el tick antes del saque, y la cámara llegaba tarde al
## cobro. Se suelta este tanto antes de que termine el foco y, con la pelota a
## más de FOCO_CAMBIO_CORTE_M del centro, se corta a ella en vez de barrer.
const FOCO_CAMBIO_SUELTA_TICKS := 3.0
const FOCO_CAMBIO_CORTE_M := 12.0
## El cuarto árbitro, corrido de la mitad de la cancha (a la izquierda en la
## cámara): el motor lo pone justo donde sale el que se va y lo tapaba.
const CUARTO_ARBITRO_CORRIDO_M := -2.2
## A cuánto de la línea (m): al lado del suplente que espera en un cambio, y
## siempre ahí (con los 4 m de OficialesPartido saltaba 2 m al empezar el cambio).
const CUARTO_ARBITRO_EN_CAMBIO_M := 2.0
## Altura a la que mira la cámara cuando enfoca a un oficial.
const FOCO_OFICIAL_ALTO_M := 1.0
## Altura de la mano (en el modelo, sin la escala) desde la que la bandera
## levantada empieza a ponerse vertical.
const BANDERA_MANO_BAJA_M := 0.85
const FOCO_OFICIAL_MAX_TICKS := 8.0
## El tablero no lleva la cámara al cuarto árbitro: en el cambio la cámara
## sigue al que sale y al que entra (el foco del fotograma), que pasan por al
## lado de él, y se acerca (ZOOM_CAMBIO).
const ZOOM_DE_SENAL := {"tarjeta_amarilla": 0.4, "tarjeta_roja": 0.4, "bandera_arriba": 0.4}
const PRIORIDAD_DE_SENAL := {"tarjeta_amarilla": 3, "tarjeta_roja": 3, "bandera_arriba": 2}
const ZOOM_CAMBIO := 0.55
const CORNER_BRAZO_TICKS := 5.0
## Después del saque sigue mirando hacia donde tiró este tanto (el 2D lo
## giraba a una de sus 8 direcciones en medio del lanzamiento).
const LATERAL_MIRA_TICKS := 1.5
## Tiro libre y corner (ver _mira_de_pateador): mira adonde va la pelota
## estando a menos de esto de ella, y hasta este tanto después del saque.
const PATEADOR_CERCA_M := 3.0
const PATEADOR_MIRA_TICKS := 0.5
## Cuánto afuera de la línea lateral se para el que saca (el centro del cuerpo),
## y entre qué ticks después del saque vuelve adonde lo tiene el motor (no
## durante el lanzamiento: se deslizaba tirando).
const LATERAL_AFUERA_M := 0.35
const LATERAL_ENTRA_DESDE_TICKS := 1.2
const LATERAL_ENTRA_HASTA_TICKS := 3.5
## Estirada: hasta dónde llega el chibi estirado (la cabeza, desde su lugar en
## el motor: 2.45 m del modelo por ESCALA_CHIBI) y cuánto corto queda cuando
## la pelota del motor no se desvía (no la tocó).
const ESTIRADA_ALCANCE_M := 1.85
const ESTIRADA_QUEDA_CORTO_M := 0.3
## Cuánto corre la cadera Atajar_Volando en su cuadro de contacto (10/24:
## 1.04 m del modelo por ESCALA_CHIBI).
const ESTIRADA_CADERA_CONTACTO_M := 0.78
## En el tiro con efecto se corre al menos esto de lo que se corre en el motor.
const ESTIRADA_CURVA_ESCALA_MIN := 0.15
## La estirada que le pasa al lado arranca tarde: cuando la pelota cruza por
## su línea la estirada va por esta fracción (negativa: arranca un poco después;
## antes, con la pelota alta, le rozaba la cabeza).
const ESTIRADA_TARDE_FASE := -0.05
const COMPRA_DISTANCIA_M := 4.0
const COMPRA_TICKS := 3.4
const COMPRA_QUITAR_DESDE_SEG := 0.2

## Qué tan rápido gira un jugador hacia su rumbo (1/s).
const GIRO_POR_SEGUNDO := 10.0

## Acción del motor -> animación del GLB. Cada animación dura lo mismo que
## la acción en el motor (DURACION_ACCION x 0.25 s), así la fase 0..1 de
## VistaPartido cae en el mismo gesto. Lo que no está acá, o no existe en el
## modelo, cae en Quieto o Correr según la pose.
const ANIM_DE_ACCION := {
	MotorEspacial.ACCION_PATEA: "Patear_Corriendo",
	MotorEspacial.ACCION_SAQUE_ARCO: "Saque_Arco",
	LANZA_ARQUERO: "Arquero_Lanza",
	VOLEO_ARQUERO: "Arquero_Voleo",
	MotorEspacial.ACCION_BARRIDA: "Barrida",
	MotorEspacial.ACCION_VUELA: "Atajar_Volando",
	MotorEspacial.ACCION_AGARRA: "Agarrar",
	MotorEspacial.ACCION_CABECEA: "Cabecear",
	MotorEspacial.ACCION_PALOMITA: "Palomita",
	MotorEspacial.ACCION_FESTEJA: "Festejar",
	"volea": "Volea",
	"chilena": "Chilena",
	"control_pie": "Control_Corriendo",
	"pecho": "Pecho",
	"taco": "Taco",
	"amague_centro": "Amague",
	"regate_croqueta": "Regate_Croqueta",
	"regate_bicicleta": "Regate_Bicicleta",
	"regate_ruleta": "Regate_Ruleta",
	"regate_globito": "Regate_Globito",
	"regate_elastica": "Regate_Elastica",
	"bloquea": "Bloquear",
	"cae": "Caer",
	"lesionado": "Lesionado",
	"lateral_prepara": "Lateral_Prepara",
	"lateral_manos": "Lateral",
}

## Saques del arquero con la pelota en las manos (después de agarrarla): el
## motor los graba como un pase ("patea") o un despeje ("saque_arco"), igual
## que con el pie. El 3D los cambia por el saque con la mano (rodando) y la
## volea (ver _preparar_saques_de_mano). Entre el agarre y el saque la sostiene.
const LANZA_ARQUERO := "lanza_arquero"
const VOLEO_ARQUERO := "voleo_arquero"
const SAQUE_DE_MANO := {MotorEspacial.ACCION_PATEA: LANZA_ARQUERO, MotorEspacial.ACCION_SAQUE_ARCO: VOLEO_ARQUERO}
const ANIM_SOSTIENE := "Arquero_Sostiene"
## En Arquero_Voleo suelta la pelota en 8/24 y le pega en 12/24: en el medio cae.
const VOLEO_SUELTA := 8.0 / 24.0

## Animaciones en bucle mientras dura la acción: el festejo dura lo que la
## pelota queda en la red (10 ticks) y su loop es de medio segundo.
const ANIM_EN_BUCLE := ["Festejar"]
## Parado sin acción: respira con los brazos sueltos (el "Quieto" del GLB es
## la pose original, con las manos en la cintura).
const ANIM_QUIETO := "Respirar"
## La estirada hacia la izquierda del arquero (la de ANIM_DE_ACCION va a su derecha).
const ANIM_VUELA_IZQUIERDA := "Atajar_Volando_Izq"
## Estirada que termina en agarre (3D-08): sigue la estirada hasta caer
## (Atajar_Volando toca el piso en 15/24), queda tirado con la pelota y se
## levanta (Arquero_Levanta, 6 ticks, tirado del cuadro 6 al 13 de 36).
const ANIM_LEVANTA := "Arquero_Levanta"
const ANIM_LEVANTA_IZQUIERDA := "Arquero_Levanta_Izq"
const ESTIRADA_CAE_FASE := 15.0 / 24.0
const LEVANTA_TICKS := 6.0
const LEVANTA_TIRADO_SEG := Vector2(5.0 / 24.0, 12.0 / 24.0)
## Si le sobra tiempo antes del saque, se queda tirado hasta esto más; si le
## falta, se levanta más rápido.
const LEVANTA_TIRADO_EXTRA_MAX_SEG := 0.5
## Remates a las distintas partes del arco (ver _preparar_remates). El motor
## manda todo remate casi al ras y llega al arco a 0 m: acá cada remate al arco
## llega a una altura y el arquero ataja según dónde va. Si tiene que correrse
## menos de PARADA_TRAVESIA_M de costado ataja parado: abajo (de rodilla), al
## pecho (Agarrar) o arriba (saltando); si no, estirada baja o alta (al ángulo).
const PARADA_TRAVESIA_M := 1.0
const ANIM_ATAJA_ARRIBA := "Atajar_Arriba"
const ANIM_ATAJA_ABAJO := "Atajar_Abajo"
const ANIM_VUELA_ALTA := "Atajar_Volando_Alto"
const ANIM_VUELA_ALTA_IZQUIERDA := "Atajar_Volando_Alto_Izq"
## Las paradas tienen las manos en la pelota en 6/24 de 4 ticks: arrancan un
## tick antes de que llegue.
const PARADA_CONTACTO_TICKS := 1.0
## Alto de las manos en el contacto de cada atajada (golero.glb, medido con
## scratch/_medir_manos_arquero.gd): ahí va el centro de la pelota. La estirada
## suma el salto del 2D (sin(fase·π)·0.55 por la escala de altura).
const MANOS_ARRIBA_M := 1.11
const MANOS_ABAJO_M := 0.24
const MANOS_PECHO_M := 0.60
const MANOS_VUELA_M := 0.58
const MANOS_VUELA_ALTA_M := 1.35
const SALTO_VUELO_M := 0.53
## El gol que le pasa por arriba al arquero que no se corre, y el que va al
## ángulo: centro de la pelota entre estas alturas (el travesaño a 2.5 m).
const GOL_ARRIBA_M := Vector2(1.7, 2.1)
const GOL_ANGULO_M := Vector2(1.6, 2.15)
const GOL_MEDIA_M := Vector2(0.7, 1.2)
const GOL_RAS_M := Vector2(0.22, 0.36)
## Panza del remate sobre la recta del pie al arco, y altura de salida.
const REMATE_PANZA_M := 0.25
const REMATE_SALE_M := {"volea": 0.9, "chilena": 0.9, MotorEspacial.ACCION_CABECEA: 1.5,
	MotorEspacial.ACCION_PALOMITA: 1.0}
## Adentro del arco la pelota sigue en la red y cae hasta este tanto después.
const REMATE_EN_RED_TICKS := 12.0
## Señal de los oficiales (OficialesPartido) -> animación. "bandera_baja" es
## la de siempre: corre o está parado con la bandera abajo.
const ANIM_DE_SENAL := {
	"tarjeta_amarilla": "Tarjeta", "tarjeta_roja": "Tarjeta",
	"bandera_arriba": "Bandera_Arriba", "bandera_horizontal": "Bandera_Horizontal",
	"tablero": "Tablero",
}

## Preparación del lateral: VistaPartido marca la pelota `anclada` con un
## corrimiento en píxeles del sprite, que no sirve en 3D. Va a las manos.
const ANCLA_DE_ACCION := {"lateral_prepara": "manos"}

## CONTACTO CON LA PELOTA. Acción -> [punto del modelo que la toca, fracción
## de la animación en la que ese punto llega al golpe]. Las fracciones salen
## de las claves de cada animación (verificadas en animaciones_jugador.py):
## Patear_Corriendo golpea en el cuadro 5 de 12, Cabecear en el 8 de 13, etc.
## "manos" = entre Mano_L y Mano_R.
##
## Medido con tests/_diag_contactos_3d.gd antes de esto: el cabezazo pasaba
## a 1.4 m de la frente (la coreografía 2D pone la pelota a la altura de la
## cabeza del SPRITE, 2.7 m), la volea a 0.7 m del pie y el bloqueo a 3 m.
const CONTACTO_3D := {
	MotorEspacial.ACCION_PATEA: ["Pie_R", 4.0 / 11.0],
	MotorEspacial.ACCION_SAQUE_ARCO: ["Pie_R", 12.0 / 24.0],
	LANZA_ARQUERO: ["Mano_R", 7.0 / 12.0],
	VOLEO_ARQUERO: ["Pie_R", 12.0 / 24.0],
	"volea": ["Pie_R", 7.0 / 18.0],
	"chilena": ["Pie_R", 11.0 / 30.0],
	MotorEspacial.ACCION_CABECEA: ["Frente", 7.0 / 12.0],
	MotorEspacial.ACCION_PALOMITA: ["Frente", 9.0 / 24.0],
	"taco": ["Talon_R", 6.0 / 12.0],
	"control_pie": ["Pie_R", 3.0 / 9.0],
	"pecho": ["Pecho", 0.0],
	MotorEspacial.ACCION_AGARRA: ["manos", 0.0],
	"lateral_manos": ["manos", 3.0 / 12.0],
	MotorEspacial.ACCION_VUELA: ["manos", 10.0 / 24.0],
	MotorEspacial.ACCION_BARRIDA: ["Pie_L", 6.0 / 18.0],
	"bloquea": ["Pie_R", 5.0 / 18.0],
}

## Recepciones: después del contacto la pelota sigue al cuerpo hasta el
## final de la acción (el pecho la baja al pie, las manos la retienen).
const RECEPCION_3D := ["pecho", "control_pie", MotorEspacial.ACCION_AGARRA]

## La tiene en las manos hasta el golpe (el lateral y los saques del arquero).
const SUELTA_DE_MANOS := ["lateral_manos", LANZA_ARQUERO, VOLEO_ARQUERO]

## Golpes desde el piso: la pelota no se hunde aunque el pie quede bajo.
const CONTACTO_PISO := [MotorEspacial.ACCION_PATEA, MotorEspacial.ACCION_SAQUE_ARCO, LANZA_ARQUERO,
	"taco", "control_pie", MotorEspacial.ACCION_BARRIDA, "bloquea"]

## Ticks antes y después del golpe en los que la pelota se lleva al punto de
## contacto. Con 0.8 tick (0.2 s) el desvío se ve como parte del golpe y no
## como un salto: el cabezazo baja la pelota ~0.9 m en ese tramo.
const VENTANA_CONTACTO_TICKS := 0.8

## El desvío hacia el punto de contacto cambia como mucho a esta velocidad
## (m/s de partido). Sin límite, cuando otra jugada cortaba el gesto antes de
## tiempo el desvío desaparecía de golpe: la pelota saltaba hasta 3.9 m entre
## dos cuadros (medido con tests/_diag_contactos_3d.gd).
const VELOCIDAD_CORRECCION := 16.0
## Soltando la corrección (la pelota ya salió del pie), m/s de partido.
const VELOCIDAD_SUELTA := 6.0

## Ventanas más largas donde el desvío es grande. El bloqueo: el motor lo
## graba con la pelota a ~2.9 m del que bloquea (medido en la muestra), y a
## 16 m/s hacen falta ~0.5 s para desviarla hasta su pierna sin saltos
## (con 1.8 ticks llegaba a 0.31 m: el remate se escapa mientras la sigue).
const VENTANA_POR_ACCION := {"bloquea": 2.4, MotorEspacial.ACCION_VUELA: 1.2}

var _viewport: SubViewport
var _mundo: Node3D
var _camara_3d: Camera3D
var _pelota: Node3D
## Manchas debajo de personas y pelota (en vez de la sombra del sol, ver
## SombrasRedondas). Alcanza para los 22, suplentes en la banda, oficiales y
## la pelota.
const MANCHAS := 40
var _manchas: SombrasRedondas
var _escenas := {}
var _personas := {}
var _pos_previa := {}
var _rumbo := {}
var _lado_vuelo := {}
var _pelota_previa := Vector3.INF
var _tiempo := 0.0
## Posición y rumbo de cada jugador en este cuadro, para correr la pelota.
var _pies := []
## Índice del jugador en el fotograma -> gesto activo {accion, desde, clave, dt}.
## `dt` = ticks desde el golpe (negativo antes). Sale de VistaPartido y de su
## coreografía, igual que la fase que ya viene en las entidades.
var _gestos := {}
## clave_desde_accion -> fase del contacto, buscada en los fotogramas.
var _fase_contacto := {}
## Desvío actual de la pelota hacia el punto de contacto y la posición de
## reproducción del cuadro anterior (para medir el tiempo de partido).
var _correccion := Vector3.ZERO
## Corrimiento de la pelota conducida hacia adelante del pie (suavizado, ver
## CONDUCCION_VELOCIDAD).
var _conduccion := Vector2.ZERO
var _desvio_pelota := Vector2.ZERO
var _desvio_objetivo_previo := Vector2.ZERO
## Si en el cuadro anterior la pelota ya la llevaba un regate terminado.
var _regate_terminado := false
var _posicion_previa := -1.0
## Transform3D fijo para la cámara, o null para seguir la jugada. Lo usa la
## verificación de contactos para mirar cada golpe de cerca.
var camara_forzada = null
## Índice del jugador -> tick en que el motor le grabó control y amague juntos.
var _amagues := {}
## Posición de reproducción del cuadro (en ticks), para los amagues.
var _tiempo_reproduccion := 0.0
## Posición de cada jugador en este cuadro (para separar a los tendidos).
var _posiciones: Array = []
## Corrimiento dibujado de cada persona (clave -> Vector2) para que no se
## encimen, y los segundos de partido de este cuadro (-1 en un salto).
var _desvio_cuerpo := {}
var _segundos := 0.0
## Tiros bloqueados de la grabación (ver BLOQUEO_*), y el que corre ahora.
var _bloqueos: Array = []
var _fotos_bloqueos = null
var _bloqueo := {}
## id del motor -> índice en `jugadores` del fotograma actual.
var _indice_de := {}
## Dónde está la pierna del defensor en este cuadro (la pelota va ahí).
var _pierna_bloqueo := Vector3.INF
## Pierna menos pelota del motor al rebotar (se apaga en BLOQUEO_REBOTE_TICKS).
var _rebote_desfase := Vector3.INF
## Atajadas de la grabación (ver ATAJADA_*), la que corre ahora, dónde
## tiene las manos el arquero en este cuadro y, por arquero, sus manos
## respecto del cuerpo en el cuadro anterior.
## Pelota en las manos del arquero: [{clave, desde (agarre), hasta (saque)}].
var _manos_arquero: Array = []
## "clave_tick" del saque de un arquero que la tenía en las manos -> acción
## del 3D (LANZA_ARQUERO o VOLEO_ARQUERO).
var _saques_mano := {}
## Estiradas que terminan en agarre (ver _preparar_tendidos): [{clave,
## estirada, agarre, cae, contacto (fase), extra (s), velocidad, sube, hasta}].
var _tendidos: Array = []
var _atajadas: Array = []
var _atajada := {}
var _manos_atajada := Vector3.INF
var _manos_relativas := {}
## id del motor -> [desde, fin] del último regate (ver _desvio_de_regate), y
## los jugadores del fotograma actual (su orden es el de `indice`).
var _regates := {}
var _jugadores_cuadro: Array = []
## id del defensor -> la elástica cuyo amague compra (ver _registrar_comprador).
var _compradores := {}
## id del arquero -> [hacia dónde miraba al empezar la estirada (a la pelota),
## tick en que empezó].
var _mira_vuela := {}
## id del arquero -> {desde, c: corrimiento que se le suma, resto: lo que la
## estirada lo corrió más que el motor, base, vuelve} (ver
## _corregir_cadera_de_vuelo).
var _cadera_de_vuelo := {}
## Laterales de la grabación: {inicio, saque, clave, pos, mira} (ver
## _cortar_caminata_del_lateral).
var _laterales: Array = []
## Tiros con efecto: [{id, golpe}] (ver _preparar_efectos).
var _efectos: Array = []
## Remates que pegan en el palo o el travesaño (ver _preparar_palos).
var _palos: Array = []
## Remates al arco con su altura y la atajada (ver _preparar_remates).
var _remates_3d: Array = []
## Para comparar con el dibujo de antes (diagnósticos: `-- sin_remates`).
var sin_remates := OS.get_cmdline_user_args().has("sin_remates")
## Pelotas altas que caen y siguen sueltas, con pique (ver _preparar_piques).
var _piques: Array = []
## id -> tick en que le robó la pelota de cerca a un rival (ver _anotar_quite).
var _quites := {}
## id -> tick en que le quedó en los pies una pelota suelta (ver _anotar_control_suelto).
var _controles_sueltos := {}
## id -> [lado del rival, hasta cuándo] (ver _preparar_forcejeos).
var _forcejeos := {}
## id -> ventanas [desde, fin] de sus recepciones (ver _preparar_bloqueos).
var _recepciones := {}
## Centros bajados de pecho en el aire (ver _preparar_centros).
var _centros: Array = []
## Oficiales: clave -> [señal, tick en que empezó] y sus objetos en la mano.
var _senales := {}
var _utileria := {}
## Pelota parada (ver _preparar_bloqueos): tiros libres con barrera
## {falta, saque, ids} y corners {falta, saque, ejecutor}.
var _barreras: Array = []
var _corners: Array = []
## Tiros libres y corners: {falta, saque, ejecutor, bola, mira} (ver _mira_de_pateador).
var _pateadores: Array = []
## Cámara con la pelota dibujada (ver _seguir_pelota_dibujada).
var _centro_camara_previo := Vector2.INF
var _bola_camara_previa := Vector2.INF
var _vel_bola_camara := Vector2.ZERO
## El foco del fotograma mandaba el cuadro anterior / se soltó antes del saque
## (ver _foco_por_soltar).
var _foco_mandaba := false
var _foco_suelto := false
## Tarjetas de la grabación: {falta, saque, lugar, roja} (ver _tarjeta_en_curso).
var _tarjetas: Array = []
## Tick del golpe del tiro libre que está en el aire (ver _altura_tiro_libre).
var _tiro_libre_golpe := INF
## Oficial que está marcando algo (la cámara va hacia él, ver _mover_camara):
## dónde está este cuadro (INF si nadie), cuánto se acerca, y el último, para
## volver suave cuando termina.
var _foco_oficial := Vector2.INF
var _foco_zoom := 1.0
var _foco_prioridad := 0
var _foco_peso := 0.0
var _zoom_cambio_peso := 0.0
var _foco_ultimo := Vector2.INF
var _foco_zoom_ultimo := 1.0
## El que prepara un lateral cortado en este cuadro (su entrada de _pies), o {}.
var _pie_lateral := {}
## Ticks que pasaron desde que el festejo congeló la reproducción (ver
## _contar_festejo); 0 fuera del festejo.
var _festejo_ticks := 0.0
## Goles y lesiones de la grabación, para el gesto de cada cara (GestosCara).
var _caras := {}
## clave -> [última posición, metros recorridos, velocidad] (ver _medir_paso).
var _odometro := {}

## El motor graba "amague_centro" y "control_pie" en el MISMO tick y
## VistaPartido se queda con el control (medido en la muestra, semilla +63
## fotograma 906): el amague no se veía nunca, tampoco en el 2D. En 3D se
## muestra el control y, pasado este tiempo, el amague hasta que arranca la
## patada.
const AMAGUE_DESPUES_DEL_CONTROL_TICKS := 1.0


func _init() -> void:
	# Antes de que VistaPartido la use: iniciar() ya llama a saltar_a().
	camara = CamaraPartido3D.new()


func _ready() -> void:
	# No se llama a VistaCancha._ready(): esas texturas son del dibujo 2D.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(contenedor)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	contenedor.add_child(_viewport)
	_mundo = Node3D.new()
	_viewport.add_child(_mundo)
	_armar_ambiente()
	for ruta in [ESCENA_ESTADIO, ESCENA_JUGADOR, ESCENA_GOLERO, ESCENA_PELOTA]:
		_escenas[ruta] = load(ruta)
	var estadio: Node3D = _escenas[ESCENA_ESTADIO].instantiate()
	_mundo.add_child(estadio)
	# La red trae su textura con alfa: se deja su material.
	Materiales3D.aplicar(estadio, {}, ["Arco_Red"])
	Materiales3D.cortar_lado_camara(estadio, ProyeccionPartido.MEDIO_ANCHO + DETRAS_DE_BANDA_M, MATERIALES_PISO)
	# Piso de fondo: con la cámara baja y la tribuna de este lado cortada, más
	# allá de la banda se veía el celeste del cielo. Va apenas debajo de todo.
	var fondo := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(400.0, 400.0)
	fondo.mesh = plano
	fondo.position = Vector3(0.0, -0.05, 0.0)
	fondo.material_override = Materiales3D.toon(COLOR_PISO_FONDO)
	_mundo.add_child(fondo)
	_pelota = _escenas[ESCENA_PELOTA].instantiate()
	_pelota.scale = Vector3.ONE * ESCALA_PELOTA
	_mundo.add_child(_pelota)
	_manchas = SombrasRedondas.new(MANCHAS)
	_mundo.add_child(_manchas)
	Materiales3D.aplicar(_pelota)
	set_process(true)


func _armar_ambiente() -> void:
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("8fd3ff")
	# Sin luz ambiente: el tono de sombra lo pone el shader toon.
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color.BLACK
	entorno.ambient_light_energy = 0.0
	entorno.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var mundo_entorno := WorldEnvironment.new()
	mundo_entorno.environment = entorno
	_mundo.add_child(mundo_entorno)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color(1.0, 0.9, 0.78)
	sol.light_energy = 1.0
	# Sin sombra: en el teléfono de referencia bajaba el partido de 60 a 43 fps
	# (docs/motor_v2.md, etapa 0). La reemplazan las SombrasRedondas.
	sol.shadow_enabled = false
	_mundo.add_child(sol)
	# Misma dirección que el sol de Blender (0.55, 0.6, -0.75), pasada a ejes
	# de Godot: arriba-izquierda-adelante, como en los sprites.
	sol.look_at_from_position(Vector3.ZERO, Vector3(0.55, -0.75, -0.6), Vector3.UP)
	_camara_3d = Camera3D.new()
	_camara_3d.keep_aspect = Camera3D.KEEP_WIDTH
	_camara_3d.fov = FOV_HORIZONTAL
	_camara_3d.far = 400.0
	_mundo.add_child(_camara_3d)
	_camara_3d.current = true


## El dibujo 2D no corre. VistaPartido igual llama a queue_redraw().
func _draw() -> void:
	pass


func _process(delta: float) -> void:
	_tiempo += delta
	var vistos := {}
	var hay_pelota := false
	var indice := 0
	_pies.clear()
	_cortar_caminata_del_lateral()
	_cortar_despues_de_tarjeta()
	_leer_gestos()
	_segundos = _segundos_de_partido()
	_contar_festejo(delta)
	_seguir_pelota_dibujada(delta)
	_mover_camara()
	_pierna_bloqueo = Vector3.INF
	_manos_atajada = Vector3.INF
	_pie_lateral = {}
	_foco_oficial = Vector2.INF
	_foco_prioridad = 0
	_separar_cuerpos()
	# Ya separadas: el tendido se aparta de donde se DIBUJAN los demás.
	_posiciones.clear()
	var i_ent := 0
	for ent in entidades:
		var tipo := str(ent.get("tipo", ""))
		if tipo == "jugador":
			_posiciones.append(ent["pos"] + _desvio_cuerpo.get(_clave(ent, i_ent), Vector2.ZERO))
		if tipo == "jugador" or tipo == "oficial":
			i_ent += 1
	_preparar_forcejeos()
	for ent in entidades:
		match str(ent.get("tipo", "")):
			"jugador", "oficial":
				_actualizar_persona(ent, _clave(ent, indice), delta, vistos, indice)
				indice += 1
			"pelota":
				hay_pelota = true
				_actualizar_pelota(ent)
	# En la segunda mitad del agarre el 2D no manda la pelota (el sprite ya la
	# trae entre los guantes): en 3D sigue en las manos del arquero.
	if not hay_pelota:
		for pie in _pies:
			if str(pie["accion"]) == MotorEspacial.ACCION_AGARRA or (str(pie["accion"]) == "" \
					and int(pie.get("id", -1)) >= 0 and _sostiene(int(pie["id"]))):
				hay_pelota = true
				_actualizar_pelota({"tipo": "pelota", "z": 0.0,
					"pos": (pie["pos"] as Vector2) - (pie["desvio"] as Vector2)})
				break
	_pelota.visible = hay_pelota
	for clave in _personas:
		_personas[clave].visible = vistos.has(clave)
	_poner_manchas()


func _poner_manchas() -> void:
	var i := 0
	for clave in _personas:
		var p3: Jugador3D = _personas[clave]
		if p3.visible and i < MANCHAS - 1:
			_manchas.poner_jugador(i, p3.position)
			i += 1
	if _pelota.visible:
		_manchas.poner_pelota(i, _pelota.position)
		i += 1
	while i < MANCHAS:
		_manchas.ocultar(i)
		i += 1


## El encuadre sale de CamaraPartido, igual que en el 2D: el centro que
## sigue a la pelota y el zoom en px por metro, pasado a distancia.
## La cámara sigue a la pelota que se DIBUJA, no a la del motor. VistaPartido
## anticipa con la pelota del fotograma siguiente, y en un tiro libre el motor
## ya la graba en la barrera en el tick del saque (acá todavía está en el
## punto): la cámara se iba a la barrera antes de que pateen. Se deshace su
## paso de este cuadro y se da el mismo paso con la pelota dibujada. En el
## festejo, un foco del fotograma o un salto de reproducción queda el suyo.
func _seguir_pelota_dibujada(delta: float) -> void:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty() or _pelota == null:
		return
	var bola := Vector2(_pelota.global_position.x, _pelota.global_position.z)
	var idx := mini(int(rep.posicion), rep.fotogramas.size() - 1)
	# El foco del fotograma (el expulsado caminando al lateral) no cuenta si
	# ya se cortó al tiro libre.
	# Tampoco mientras la cámara va a un oficial: en el offside el motor ya
	# apunta al que sale por un cambio y la cámara barría media cancha.
	# Ni en los últimos ticks antes de que termine (el cobro después del cambio).
	var con_oficial := _foco_oficial != Vector2.INF or _foco_peso > 0.0
	var con_foco: bool = rep.fotogramas[idx].get("foco", null) != null
	_foco_suelto = con_foco and _foco_por_soltar(rep)
	var foco_manda := con_foco and not _despues_del_corte_de_tarjeta() \
		and not con_oficial and not _foco_suelto
	var propio := _segundos >= 0.0 and rep._festejo_restante <= 0.0 \
		and not foco_manda and _centro_camara_previo != Vector2.INF
	var corta := _foco_mandaba and _foco_suelto and propio \
		and bola.distance_to(_centro_camara_previo) > FOCO_CAMBIO_CORTE_M
	_foco_mandaba = foco_manda
	if corta:
		camara.saltar_a(bola, rep.size)
		_zoom_cambio_peso = 0.0
		_vel_bola_camara = Vector2.ZERO
	elif propio:
		camara.centro = _centro_camara_previo
		if _segundos > 0.0 and _bola_camara_previa != Vector2.INF:
			var v := (bola - _bola_camara_previa) / _segundos
			if v.length() < 60.0:
				_vel_bola_camara = _vel_bola_camara.lerp(v, clampf(_segundos * 12.0, 0.0, 1.0))
		camara.seguir(bola, _vel_bola_camara, size, delta)
	else:
		_vel_bola_camara = Vector2.ZERO
	_bola_camara_previa = bola
	_centro_camara_previo = camara.centro


## El foco del fotograma (el que sale o entra en un cambio) termina dentro de
## FOCO_CAMBIO_SUELTA_TICKS: el juego vuelve y la cámara tiene que estar en
## el cobro (3D-07).
func _foco_por_soltar(rep: VistaPartido) -> bool:
	var t := rep.posicion
	var fotos: Array = rep.fotogramas
	for q in range(int(t) + 1, mini(fotos.size(), int(t) + int(ceilf(FOCO_CAMBIO_SUELTA_TICKS)) + 2)):
		if fotos[q].get("foco", null) == null:
			return float(q) - t <= FOCO_CAMBIO_SUELTA_TICKS
	return false


func _mover_camara() -> void:
	# Solo para verificar contactos de cerca (tests/_diag_contactos_3d.gd).
	if camara_forzada != null:
		_camara_3d.global_transform = camara_forzada
		return
	var ancho_m: float = maxf(size.x, 1.0) / maxf(camara.px_por_metro, 1.0) / CamaraPartido3D.ACERCAMIENTO
	var distancia := ancho_m * 0.5 / tan(deg_to_rad(FOV_HORIZONTAL) * 0.5)
	var objetivo := Vector3(camara.centro.x, 0.0, camara.centro.y)
	# Un oficial marcando algo (tarjeta, offside, cambio): como en la tele, la
	# cámara va hacia él y se acerca. El asistente y el cuarto árbitro están en
	# la banda, fuera de cuadro si se sigue solo a la pelota.
	var quiere := 1.0 if _foco_oficial != Vector2.INF else 0.0
	# Como en la tele: al asistente del otro lado de la cancha se corta, no se
	# barre media cancha. En un salto de reproducción también.
	var lejos := false
	var hacia := _foco_oficial if _foco_oficial != Vector2.INF else _foco_ultimo
	if hacia != Vector2.INF:
		lejos = hacia.distance_to(Vector2(objetivo.x, objetivo.z)) > FOCO_OFICIAL_CORTE_M
	if _segundos < 0.0 or lejos:
		_foco_peso = quiere
	_foco_peso = move_toward(_foco_peso, quiere, get_process_delta_time() * FOCO_OFICIAL_VELOCIDAD)
	if _foco_oficial != Vector2.INF:
		_foco_ultimo = _foco_oficial
		_foco_zoom_ultimo = _foco_zoom
	if _foco_peso > 0.0 and _foco_ultimo != Vector2.INF:
		var s := smoothstep(0.0, 1.0, _foco_peso)
		# A la altura del pecho: de cerca, la bandera o la tarjeta arriba de la
		# cabeza quedaban fuera de cuadro (o debajo del título de la muestra).
		objetivo = objetivo.lerp(Vector3(_foco_ultimo.x, FOCO_OFICIAL_ALTO_M, _foco_ultimo.y), FOCO_OFICIAL_TIRA * s)
		distancia *= lerpf(1.0, _foco_zoom_ultimo, s)
	# Cambio: de cerca al que sale y al que entra (la cámara ya los sigue).
	var en_cambio := 1.0 if _lado_del_cambio() != 0.0 and not _foco_suelto else 0.0
	_zoom_cambio_peso = en_cambio if _segundos < 0.0 \
		else move_toward(_zoom_cambio_peso, en_cambio, get_process_delta_time() * FOCO_OFICIAL_VELOCIDAD)
	distancia *= lerpf(1.0, ZOOM_CAMBIO, smoothstep(0.0, 1.0, _zoom_cambio_peso))
	var e := deg_to_rad(ELEVACION_CAMARA)
	_camara_3d.position = objetivo + Vector3(0.0, sin(e), cos(e)) * distancia
	_camara_3d.look_at(objetivo, Vector3.UP)


## Con un cambio en curso, de qué banda salen y entran (+1 / -1), o 0. Es la
## del suplente que espera (el motor lo pone en la banda más cercana al que
## sale, MotorEspacial._punto_de_salida).
func _lado_del_cambio() -> float:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return 0.0
	var f: Dictionary = rep.fotogramas[clampi(int(_tiempo_reproduccion), 0, rep.fotogramas.size() - 1)]
	var cambios: Array = f.get("cambios", [])
	if cambios.is_empty():
		return 0.0
	# El que entra todavía puede no estar en el fotograma: el lado es el mismo
	# que el de la banda más cercana al que sale.
	var entra := VistaPartido._jugador_en(f, int(cambios[0].get("entrante_clave", -1)))
	if entra.is_empty():
		entra = VistaPartido._jugador_en(f, int(cambios[0].get("saliente_clave", -1)))
	if entra.is_empty():
		return 0.0
	return 1.0 if float(entra["y"]) >= 0.0 else -1.0


## La cara y el peinado de cada uno salen de su jugador_id (los mismos en
## todos los partidos) y el gesto, de lo que le pasa: gol, lesión, falta (ver
## GestosCara). El parpadeo corre con el tiempo de partido: en pausa se queda
## quieto.
func _poner_cara(p3: Jugador3D, ent: Dictionary, indice: int) -> void:
	var segundos := _tiempo_reproduccion * MotorEspacial.TICK_SEG
	if str(ent["tipo"]) != "jugador" or indice < 0 or indice >= _jugadores_cuadro.size():
		p3.clave_motor = -1
		p3.poner_peinado(Jugador3D.PEINADO_OFICIAL)
		p3.poner_cara(GestosCara.CARA_OFICIAL, Jugador3D.Gesto.NORMAL, segundos)
		return
	var j: Dictionary = _jugadores_cuadro[indice]
	p3.clave_motor = int(j["id"])
	var jugador_id := int(j.get("jugador_id", j["id"]))
	var gesto := GestosCara.gesto(_caras, int(j["id"]), bool(j["equipo_local"]),
		str(ent.get("accion", "")), _tiempo_reproduccion)
	p3.poner_peinado(Jugador3D.peinado_de(jugador_id))
	p3.poner_cara(Jugador3D.cara_de(jugador_id), gesto, segundos)


## Las entidades no traen la clave del jugador. El orden de la lista es el
## de los jugadores del fotograma y no cambia entre cuadros; el color entra
## en la clave para que un cambio de jugador no herede el giro del anterior.
static func _clave(ent: Dictionary, indice: int) -> String:
	if str(ent["tipo"]) == "oficial":
		return "of_%s" % str(ent.get("rol_oficial", indice))
	return "%d_%s_%d" % [indice, Color(ent["color"]).to_html(false), int(bool(ent.get("arquero", false)))]


func _persona(clave: String, es_arquero: bool) -> Jugador3D:
	if not _personas.has(clave):
		var ruta := ESCENA_GOLERO if es_arquero else ESCENA_JUGADOR
		var p := Jugador3D.new(_escenas[ruta])
		_mundo.add_child(p)
		_personas[clave] = p
	return _personas[clave]


## Los gestos que VistaPartido está mostrando, con su jugador y el instante
## del golpe. Las entidades traen la fase pero no la clave ni el golpe.
func _leer_gestos() -> void:
	_gestos.clear()
	_amagues.clear()
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return
	var idx := mini(int(rep.posicion), rep.fotogramas.size() - 1)
	var t := rep.posicion - float(idx)
	if rep._idx_congelado != -1:
		idx = rep._idx_congelado
		t = 0.0
	var tiempo := float(idx) + t
	_tiempo_reproduccion = tiempo
	var activas: Dictionary = rep._coreografia.gestos(tiempo, rep._acciones_activas(idx))
	var jugadores: Array = rep.fotogramas[idx]["jugadores"]
	_jugadores_cuadro = jugadores
	for clave_r in activas:
		var ar: Dictionary = activas[clave_r]
		if MotorEspacial.es_accion_regate(str(ar.get("accion", ""))):
			var desde_r := float(ar.get("desde", idx))
			var fin_r := desde_r + float(VistaPartido.DURACION_ACCION.get(str(ar["accion"]), 1))
			var jr := VistaPartido._jugador_en(rep.fotogramas[int(desde_r)], int(clave_r))
			var frente_r := Vector2(float(jr.get("regate_ox", jr.get("ox", 1.0))), float(jr.get("regate_oy", jr.get("oy", 0.0))))
			_regates[int(clave_r)] = [desde_r, fin_r, str(ar["accion"]),
				frente_r.normalized() if frente_r.length() > 0.01 else Vector2.RIGHT]
			if str(ar["accion"]) == "regate_elastica" and not _compradores.values().any(
					func(c): return int(c["ejecutor"]) == int(clave_r) and float(c["desde"]) == desde_r):
				_registrar_comprador(rep, int(clave_r), desde_r, fin_r)
	var indice_de := {}
	for i in jugadores.size():
		indice_de[int(jugadores[i]["id"])] = i
	_indice_de = indice_de
	_bloqueo = _bloqueo_en(rep, tiempo)
	_atajada = _atajada_en(tiempo)
	for clave_c in activas:
		var gc: Dictionary = activas[clave_c]
		if str(gc.get("accion", "")) != "control_pie" or not indice_de.has(int(clave_c)):
			continue
		var desde_c := int(gc.get("desde", idx))
		for a in rep.fotogramas[desde_c].get("acciones", []):
			if int(a["clave"]) == int(clave_c) and str(a["accion"]) == "amague_centro":
				_amagues[indice_de[int(clave_c)]] = desde_c
	# Bloqueo y estirada: el motor graba la acción en el tick en que la pelota
	# ya está pasando (el bloqueo, a ~3 m). Mirando uno o dos ticks adelante la
	# pelota empieza a ir hacia la pierna o los guantes antes del golpe.
	for k in range(idx + 1, mini(idx + 4, rep.fotogramas.size())):
		for a in rep.fotogramas[k].get("acciones", []):
			var nombre := str(a["accion"])
			var clave_a := int(a["clave"])
			if not VENTANA_POR_ACCION.has(nombre) or activas.has(clave_a) or not indice_de.has(clave_a):
				continue
			# Ataja parado: no se tira (ver _preparar_remates).
			if nombre == MotorEspacial.ACCION_VUELA and not _parada_de(clave_a, float(k)).is_empty():
				continue
			var dur_a := float(VistaPartido.DURACION_ACCION.get(nombre, 1))
			var fc := _fase_de_contacto_buscada(rep, clave_a, k, nombre, dur_a)
			var dt_a := tiempo - (float(k) + fc * dur_a)
			if -dt_a <= float(VENTANA_POR_ACCION[nombre]):
				_gestos[indice_de[clave_a]] = {"accion": nombre, "desde": k, "clave": clave_a,
					"fase_contacto": fc, "dt": dt_a, "anticipado": true,
					"sin_toque": nombre == MotorEspacial.ACCION_VUELA and not _estirada_toca(rep, float(k) + fc * dur_a)}
	for i in jugadores.size():
		var clave := int(jugadores[i]["id"])
		if not activas.has(clave):
			continue
		var g: Dictionary = activas[clave].duplicate()
		var accion := str(g.get("accion", ""))
		var accion_3d := _saque_de_mano(clave, int(g.get("desde", idx)), accion)
		if not CONTACTO_3D.has(accion_3d):
			continue
		if accion == MotorEspacial.ACCION_VUELA and not _parada_de(clave, float(g.get("desde", idx))).is_empty():
			continue
		g["clave"] = clave
		var desde := int(g.get("desde", idx))
		var c: Dictionary = rep._coreografia.contactos.get(desde, {})
		var duracion := float(VistaPartido.DURACION_ACCION.get(accion, 1))
		if bool(g.get("coreografiada", false)) and not c.is_empty():
			# La coreografía ya fijó el golpe: la fase vale `impacto` justo ahí.
			g["fase_contacto"] = float(c["impacto"])
			g["dt"] = tiempo - float(c["golpe"])
		else:
			g["fase_contacto"] = _fase_de_contacto_buscada(rep, clave, desde, accion, duracion)
			g["dt"] = tiempo - (float(desde) + float(g["fase_contacto"]) * duracion)
		if accion == MotorEspacial.ACCION_VUELA:
			g["sin_toque"] = not _estirada_toca(rep, float(desde) + float(g["fase_contacto"]) * duracion)
			# El motor graba la estirada en ticks seguidos: la segunda, con la
			# pelota ya pasando, lo daba vuelta. Solo una estirada nueva cambia.
			if not _mira_vuela.has(clave) or desde >= int(_mira_vuela[clave][1]) + int(duracion) \
					or desde < int(_mira_vuela[clave][1]):
				var jv := VistaPartido._jugador_en(rep.fotogramas[desde], clave)
				var pv: Dictionary = rep.fotogramas[desde]["pelota"]
				var mira_v := Vector2(pv["x"], pv["y"]) - Vector2(jv.get("x", 0.0), jv.get("y", 0.0))
				if not jv.is_empty() and mira_v.length() > 0.1:
					var momento := float(desde) + float(g["fase_contacto"]) * duracion
					# Para qué lado se tira: de qué lado de él pasa la pelota cuando
					# se estira (al empezar la estirada la pelota todavía viene de
					# frente y el lado salía al azar: siempre a su derecha).
					# Para qué lado se tira: a lo largo de la línea de su arco, hacia
					# donde termina yendo la pelota (2 ticks después). Con su frente
					# o con la línea del remate no sirve: mira un poco al que patea,
					# y el remate del motor pasa casi por encima de él.
					var m1 := clampi(int(round(momento)) + 2, 0, rep.fotogramas.size() - 1)
					var p1 := Vector2(rep.fotogramas[m1]["pelota"]["x"], rep.fotogramas[m1]["pelota"]["y"])
					var arquero := Vector2(jv["x"], jv["y"])
					var mira_n := mira_v.normalized()
					var frente_arco := Vector2(-signf(arquero.x), 0.0)  # de su arco hacia la cancha
					var derecha := Vector2(-frente_arco.y, frente_arco.x)
					var a_su_izquierda := (p1 - arquero).dot(derecha) < 0.0
					var corto := Vector2.ZERO
					var escala_v := 1.0
					var retraso_v := 0.0
					if bool(g["sin_toque"]):
						var lado_v := Vector2(-mira_n.y, mira_n.x) * (-1.0 if a_su_izquierda else 1.0)
						corto = _estirada_corta(rep, clave, momento, desde, lado_v)
						var cruce := _cruce_del_arquero(rep, clave, desde)
						if float(_curva_de(rep.fotogramas[desde]).get("curva_m", 0.0)) > 0.0:
							corto = Vector2.ZERO
							escala_v = _estirada_corta_curva(rep, clave, desde)
						elif not cruce.is_empty() and absf(float(cruce[1]) - float(jv["y"])) \
								< ESTIRADA_ALCANCE_M + RADIO_PELOTA * ESCALA_PELOTA + ESTIRADA_QUEDA_CORTO_M:
							# Le pasa al lado (el motor igual dice que no la tocó):
							# correrlo lo dejaba junto al palo tirándose para el otro
							# lado. Reacciona tarde: se queda donde estaba y recién se
							# tira cuando la pelota ya le pasa.
							corto = Vector2.ZERO
							escala_v = 0.0
							retraso_v = maxf(0.0, float(cruce[0]) - float(desde) - ESTIRADA_TARDE_FASE * duracion)
					_mira_vuela[clave] = [mira_n, desde, corto, a_su_izquierda, escala_v, arquero, retraso_v]
		g["accion"] = accion_3d
		_gestos[i] = g
	# En un tiro bloqueado la pelota la lleva _pelota_del_bloqueo: el contacto
	# común del bloqueo (el instante más cercano del motor) la volvía a traer.
	if not _bloqueo.is_empty():
		_gestos.erase(int(indice_de.get(int(_bloqueo["bloqueador"]), -2)))


## Estirada que no llega: la pelota del motor pasa a ~1.9 m del arquero y el
## chibi estirado llega con la cabeza a ESTIRADA_ALCANCE_M: la pelota le pasaba
## por la cabeza. Se lo corre para atrás lo justo para quedar corto. El
## alcance se mide desde donde queda la cadera menos lo que la corre la
## estirada: lo que corre el motor desde `desde` hacia `lado` ya no se suma
## (ver _corregir_cadera_de_vuelo).
func _estirada_corta(rep: VistaPartido, clave: int, momento: float, desde: int, lado: Vector2) -> Vector2:
	var fotos: Array = rep.fotogramas
	var k0 := clampi(int(momento), 0, fotos.size() - 1)
	var k1 := mini(k0 + 1, fotos.size() - 1)
	var fr := momento - float(k0)
	var j0 := VistaPartido._jugador_en(fotos[k0], clave)
	var j1 := VistaPartido._jugador_en(fotos[k1], clave)
	var ji := VistaPartido._jugador_en(fotos[desde], clave)
	if j0.is_empty() or j1.is_empty() or ji.is_empty():
		return Vector2.ZERO
	var arquero := Vector2(j0["x"], j0["y"]).lerp(Vector2(j1["x"], j1["y"]), fr)
	var corrido := (arquero - Vector2(ji["x"], ji["y"])).dot(lado)
	arquero -= lado * maxf(0.0, minf(corrido, ESTIRADA_CADERA_CONTACTO_M))
	var alcance := ESTIRADA_ALCANCE_M + RADIO_PELOTA * ESCALA_PELOTA + ESTIRADA_QUEDA_CORTO_M
	var pelota := Vector2(fotos[k0]["pelota"]["x"], fotos[k0]["pelota"]["y"]).lerp(
		Vector2(fotos[k1]["pelota"]["x"], fotos[k1]["pelota"]["y"]), fr)
	var d := pelota - arquero
	var falta := d.length() - alcance
	if falta >= 0.0 or d.length() < 0.01:
		return Vector2.ZERO
	return d.normalized() * falta


## Cuándo y por dónde cruza la pelota la línea del arquero (paralela a la del
## arco, por donde él estaba al tirarse): [tick, y del cruce] o [] si no cruza.
func _cruce_del_arquero(rep: VistaPartido, clave: int, desde: int) -> Array:
	var fotos: Array = rep.fotogramas
	var j := VistaPartido._jugador_en(fotos[desde], clave)
	if j.is_empty():
		return []
	var x := float(j["x"])
	for k in range(maxi(desde, 1), mini(desde + 6, fotos.size())):
		var a := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
		var b := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"])
		if (a.x - x) * (b.x - x) > 0.0 or absf(b.x - a.x) < 0.01:
			continue
		var u := (x - a.x) / (b.x - a.x)
		return [float(k - 1) + u, a.lerp(b, u).y]
	return []


## Estirada que no llega a un tiro con efecto: el arquero del motor corre
## hacia donde termina la curva y, cuando la pelota pasa por su lado (todavía
## doblando y alta), ya se pasó: se tiraba de más y la pelota le entraba por
## adentro. Correrlo para atrás lo hacía deslizar al revés. Se achica lo que
## se corre (escala de su recorrido en el motor): se tira desde cerca de donde
## estaba, hacia la pelota, y la pelota le pasa por arriba de las manos.
func _estirada_corta_curva(rep: VistaPartido, clave: int, desde: int) -> float:
	var fotos: Array = rep.fotogramas
	var fin := mini(desde + 4, fotos.size() - 1)
	var ja := VistaPartido._jugador_en(fotos[desde], clave)
	var jb := VistaPartido._jugador_en(fotos[fin], clave)
	if ja.is_empty() or jb.is_empty():
		return 1.0
	var inicio := Vector2(ja["x"], ja["y"])
	var va := Vector2(jb["x"], jb["y"]) - inicio
	if va.length() < 0.1:
		return 1.0
	var avance := va.normalized()
	var mejor := INF
	var arquero_m := Vector2.ZERO
	var pelota_m := Vector2.ZERO
	var t := float(desde)
	while t <= float(fin):
		var k := int(t)
		var fr := t - float(k)
		var j0 := VistaPartido._jugador_en(fotos[k], clave)
		var j1 := VistaPartido._jugador_en(fotos[mini(k + 1, fin)], clave)
		var tr := _curva_de(fotos[k])
		if not j0.is_empty() and not j1.is_empty() and not tr.is_empty():
			var arq := Vector2(j0["x"], j0["y"]).lerp(Vector2(j1["x"], j1["y"]), fr)
			var p0 := float(tr.get("progreso", 0.0))
			var tr1 := _curva_de(fotos[mini(k + 1, fotos.size() - 1)])
			var p1 := float(tr1.get("progreso", 1.0)) if not tr1.is_empty() else 1.0
			var p := clampf(lerpf(p0, p1, fr), 0.0, 1.0)
			var o := Vector2(tr["origen"]["x"], tr["origen"]["y"])
			var c := Vector2(tr["control"]["x"], tr["control"]["y"])
			var d := Vector2(tr["destino"]["x"], tr["destino"]["y"])
			var q := o.lerp(c, p).lerp(c.lerp(d, p), p)
			if q.distance_to(arq) < mejor:
				mejor = q.distance_to(arq)
				arquero_m = arq
				pelota_m = q
		t += 0.05
	var recorrido := (arquero_m - inicio).dot(avance)
	if mejor == INF or recorrido < 0.1:
		return 1.0
	# Hasta dónde puede correrse para que la pelota le quede un alcance y un
	# poco más adelante.
	var puede := (pelota_m - inicio).dot(avance) \
		- (ESTIRADA_ALCANCE_M + RADIO_PELOTA * ESCALA_PELOTA + ESTIRADA_QUEDA_CORTO_M)
	return clampf(puede / recorrido, ESTIRADA_CURVA_ESCALA_MIN, 1.0)


## Cuánto de la altura de la estirada (0.25..1) según la altura más alta de la
## pelota en los ticks de la estirada: rodando, casi al ras del piso.
func _altura_del_remate(desde: int, clave: int = -1) -> float:
	var rep := get_parent() as VistaPartido
	if rep == null or desde < 0:
		return 1.0
	# El remate elegido (ver _preparar_remates): el salto que pone las manos a
	# su altura; parado no se tira.
	var plan := _remate_de_arquero(clave, float(desde)) if clave >= 0 else {}
	if not plan.is_empty():
		return float(plan["alto"]) if str(plan["forma"]).begins_with("vuela") else 0.0
	var z := 0.0
	for k in range(desde, mini(desde + 4, rep.fotogramas.size())):
		z = maxf(z, float(rep.fotogramas[k]["pelota"].get("z", 0.0)))
		# El de efecto va por arriba en el 3D (el motor lo manda casi al ras).
		var tr := _curva_de(rep.fotogramas[k])
		if float(tr.get("curva_m", 0.0)) > 0.0:
			z = maxf(z, _altura_de_curva(float(tr.get("progreso", 0.0))))
	# El tiro libre que pasa la barrera va alto en el 3D (el motor lo manda
	# al ras): la estirada también.
	for r in _barreras:
		if r.has("vuelo") and str(r["vuelo"]["tipo"]) == "pasa" \
				and absf(float(r["vuelo"]["cruce"]) - float(desde)) < 4.0:
			z = maxf(z, TIRO_LIBRE_ENTRA_M)
	return clampf(z / 1.2, 0.25, 1.0)


## ¿La estirada toca la pelota? En el motor, si la pelota sigue derecho y casi
## igual de rápido después de pasar junto al arquero, no la tocó (no llegó): los
## guantes pasan cerca pero la pelota no se desvía a ellos. Antes se la llevaba
## igual a las manos y parecía que lo atravesaba.
func _estirada_toca(rep: VistaPartido, momento: float) -> bool:
	# El remate al palo no lo toca: la pelota va al marco (ver _pelota_en_palo).
	for p in _palos:
		if momento >= float(p["golpe"]) and momento <= float(p["llega"]) + 1.0:
			return false
	var fotos: Array = rep.fotogramas
	var k := clampi(int(round(momento)), 1, fotos.size() - 2)
	var p0 := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
	var p1 := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"])
	var p2 := Vector2(fotos[k + 1]["pelota"]["x"], fotos[k + 1]["pelota"]["y"])
	var antes := p1 - p0
	var despues := p2 - p1
	if int(fotos[k + 1]["pelota"].get("poseedor_id", -1)) != -1:
		return true  # la agarró alguien
	# Adentro del arco la red la frena (o ya está quieta en la red, en el
	# segundo tick de la estirada): frenar ahí no es que la tocó.
	var en_red := absf(p2.x) > MotorEspacial.LARGO * 0.5 or absf(p1.x) > MotorEspacial.LARGO * 0.5
	if antes.length() < 0.3 or despues.length() < 0.3:
		return not en_red
	var desvio := absf(antes.angle_to(despues)) > deg_to_rad(20.0)
	if en_red:
		return desvio
	return desvio or despues.length() < antes.length() * 0.3


## Hacia dónde sale la pelota del golpe coreografiado en `desde`, medido en
## el motor (muestra del golpe -> la siguiente). La `direccion` de la
## coreografía en la chilena da la del centro que llega: mide la pelota
## contra el pie, que en ese tick todavía está sobre el jugador.
func _salida_del_golpe(desde: int) -> Vector2:
	var rep := get_parent() as VistaPartido
	if rep == null or desde < 0:
		return Vector2.ZERO
	var c: Dictionary = rep._coreografia.contactos.get(desde, {})
	if c.is_empty():
		return Vector2.ZERO
	var g := int(c["golpe"])
	if g + 1 >= rep.fotogramas.size():
		return Vector2.ZERO
	var a: Dictionary = rep.fotogramas[g]["pelota"]
	var b: Dictionary = rep.fotogramas[g + 1]["pelota"]
	var d := Vector2(b["x"], b["y"]) - Vector2(a["x"], a["y"])
	return d.normalized() if d.length() > 0.3 else Vector2.ZERO


## Busca una vez por grabación los tiros bloqueados: un bloqueo con un
## remate del rival en el mismo tick o en el anterior.
func _preparar_bloqueos(rep: VistaPartido) -> void:
	if is_same(_fotos_bloqueos, rep.fotogramas):
		return
	_fotos_bloqueos = rep.fotogramas
	_bloqueos.clear()
	_atajadas.clear()
	var fotos: Array = rep.fotogramas
	_preparar_remates(rep, fotos)
	for k in fotos.size():
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) == MotorEspacial.ACCION_AGARRA:
				var armada := _armar_atajada(rep, k, int(a["clave"]))
				if not armada.is_empty():
					_atajadas.append(armada)
	_preparar_saques_de_mano(rep, fotos)
	for k in fotos.size():
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) != "bloquea":
				continue
			var armado := _armar_bloqueo(rep, k, int(a["clave"]))
			if not armado.is_empty():
				_bloqueos.append(armado)
	# Recepción: el motor frena al que recibe (en seco, muchas veces quieto 4
	# ticks antes) y después tarda 1 s en arrancar. Se lo dibuja con el
	# recorrido promediado, como en los regates: controla y ya sale.
	_recepciones.clear()
	_quites.clear()
	_controles_sueltos.clear()
	for k in fotos.size():
		var con_accion := {}
		for a in fotos[k].get("acciones", []):
			con_accion[int(a["clave"])] = true
			if str(a["accion"]) in RECEPCIONES_FLUIDAS:
				_agregar_recepcion(fotos, k, int(a["clave"]),
					float(VistaPartido.DURACION_ACCION.get(str(a["accion"]), 1)), str(a["accion"]) == "control_pie")
		# Pases que el motor da por recibidos sin acción de control (la pelota
		# pasa a ser suya y listo): el que recibía quedaba quieto y arrancaba
		# despacio igual.
		if k == 0 or VistaPartido._es_reubicacion(fotos[k]):
			continue
		var dueno := int(fotos[k]["pelota"].get("poseedor_id", -1))
		if dueno == -1 or dueno == int(fotos[k - 1]["pelota"].get("poseedor_id", -1)) or con_accion.has(dueno):
			continue
		_anotar_quite(fotos, k, dueno)
		_anotar_control_suelto(fotos, k, dueno)
		if k + 1 < fotos.size() and fotos[k + 1].get("acciones", []).any(func(b): return int(b["clave"]) == dueno):
			continue
		_agregar_recepcion(fotos, k, dueno, 2.0, true)
	_preparar_centros(fotos)
	_preparar_pelota_parada(fotos)
	_preparar_efectos(fotos)
	_preparar_palos(rep, fotos)
	_preparar_piques(rep, fotos)
	_caras = GestosCara.preparar(fotos, rep.hud.nombre_local if rep.hud != null else "")
	_laterales.clear()
	for k in fotos.size():
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) != "lateral_manos":
				continue
			# La caminata: los cuadros de antes con el lateral preparándose.
			var inicio := k
			while inicio > 0 and int(fotos[inicio - 1].get("lateral_preparacion", {}).get("clave", -1)) == int(a["clave"]):
				inicio -= 1
			var j := VistaPartido._jugador_en(fotos[k], int(a["clave"]))
			if inicio >= k or j.is_empty():
				continue
			# El motor lo pone medio metro ADENTRO de la cancha: saca con los
			# pies afuera de la línea.
			var pos := Vector2(j["x"], signf(float(j["y"])) * (MotorEspacial.MEDIO_ANCHO + LATERAL_AFUERA_M))
			var mira := Vector2.ZERO
			if k + 1 < fotos.size():
				mira = Vector2(fotos[k + 1]["pelota"]["x"], fotos[k + 1]["pelota"]["y"]) - pos
			if mira.length() < 0.1:
				mira = Vector2(0.0, -signf(pos.y))
			_laterales.append({"inicio": inicio, "saque": k, "clave": int(a["clave"]), "pos": pos,
				"mira": mira.normalized()})


## Tiros libres y corners. El motor para el juego (`detenido`), acomoda a
## todos y en el primer tick con el juego andando alguien patea. En el tiro
## libre cerca del arco los defensores que quedan a 8-10.5 m de la pelota,
## sobre la línea al arco, son la barrera (el motor los pone a 9 m).
## Trabada: la pelota pasa a `dueno` en el tick `k` sin acción del motor y el
## último que la tuvo es rival: cortó el pase o se la sacó. Si la cortó con un
## rival encima (QUITE_DISTANCIA_M) o el pase venía fuerte, mete la pierna
## (Quitar); una pelota suelta que recoge solo, no. En el motor casi no hay
## robos pie a pie: los cambios de dueño son pases cortados.
func _anotar_quite(fotos: Array, k: int, dueno: int) -> void:
	var antes := -1
	for q in range(k - 1, maxi(-1, k - QUITE_BUSCA_TICKS), -1):
		if VistaPartido._es_reubicacion(fotos[q + 1]):
			return
		antes = int(fotos[q]["pelota"].get("poseedor_id", -1))
		if antes != -1:
			break
	if antes == -1 or antes == dueno:
		return
	var jd := VistaPartido._jugador_en(fotos[k], dueno)
	var ja := VistaPartido._jugador_en(fotos[k], antes)
	if jd.is_empty() or ja.is_empty() or bool(jd["equipo_local"]) == bool(ja["equipo_local"]):
		return
	var yo := Vector2(jd["x"], jd["y"])
	var cerca := false
	for j in fotos[k]["jugadores"]:
		if bool(j["equipo_local"]) != bool(jd["equipo_local"]) and yo.distance_to(Vector2(j["x"], j["y"])) <= QUITE_DISTANCIA_M:
			cerca = true
	var llega := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"]).distance_to(
		Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])) / MotorEspacial.TICK_SEG
	if cerca or llega >= QUITE_PASE_FUERTE_MS:
		_quites[dueno] = float(k)


## Pelota suelta que queda en los pies: el motor recién le da la pelota unos
## ticks después de que le llegó (un despeje o un pase que muere ahí) y en el
## 3D se veía la pelota pegada al pie y el jugador sin hacer nada, como si le
## rebotara. Desde el primer tick en que la tiene cerca, la para (control).
func _anotar_control_suelto(fotos: Array, k: int, dueno: int) -> void:
	var primero := -1
	for q in range(k - 1, maxi(0, k - CONTROL_SUELTO_BUSCA_TICKS) - 1, -1):
		if int(fotos[q]["pelota"].get("poseedor_id", -1)) != -1 or VistaPartido._es_reubicacion(fotos[q + 1]):
			break
		var j := VistaPartido._jugador_en(fotos[q], dueno)
		if j.is_empty():
			break
		if Vector2(j["x"], j["y"]).distance_to(Vector2(fotos[q]["pelota"]["x"], fotos[q]["pelota"]["y"])) > CONTROL_SUELTO_DISTANCIA_M:
			break
		primero = q
	if primero >= 0 and k - primero >= 1:
		_controles_sueltos[dueno] = float(primero)


## Hombro con hombro: el que lleva la pelota corriendo y el rival más cercano
## a menos de FORCEJEO_DISTANCIA_M, yendo para el mismo lado. id -> [lado del
## rival (+1 a su derecha, -1 a su izquierda), hasta cuándo]. Dura un poco más
## que el contacto, así no parpadea al separarse un instante.
func _preparar_forcejeos() -> void:
	for id in _forcejeos.keys():
		if float(_forcejeos[id][1]) < _tiempo_reproduccion or _segundos < 0.0:
			_forcejeos.erase(id)
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return
	var idx := clampi(int(_tiempo_reproduccion), 0, rep.fotogramas.size() - 2)
	if int(rep.fotogramas[idx].get("detenido", 0)) > 0:
		return
	var dueno := int(rep.fotogramas[idx]["pelota"].get("poseedor_id", -1))
	var i_d := -1
	for i in mini(_jugadores_cuadro.size(), _posiciones.size()):
		if int(_jugadores_cuadro[i]["id"]) == dueno:
			i_d = i
	if i_d < 0:
		return
	var jd := VistaPartido._jugador_en(rep.fotogramas[idx + 1], dueno)
	if jd.is_empty():
		return
	var vd := Vector2(jd["x"], jd["y"]) - Vector2(_jugadores_cuadro[i_d]["x"], _jugadores_cuadro[i_d]["y"])
	if vd.length() < FORCEJEO_PASO_MIN_M:
		return
	var frente := vd.normalized()
	var derecha := Vector2(-frente.y, frente.x)
	var mejor := -1
	var mejor_d := FORCEJEO_DISTANCIA_M
	for i in mini(_jugadores_cuadro.size(), _posiciones.size()):
		var j: Dictionary = _jugadores_cuadro[i]
		if bool(j["equipo_local"]) == bool(_jugadores_cuadro[i_d]["equipo_local"]) or str(j.get("rol", "")) == "ARQ":
			continue
		var d := (_posiciones[i] as Vector2).distance_to(_posiciones[i_d])
		var jr := VistaPartido._jugador_en(rep.fotogramas[idx + 1], int(j["id"]))
		if d >= mejor_d or jr.is_empty():
			continue
		var vr := Vector2(jr["x"], jr["y"]) - Vector2(j["x"], j["y"])
		if vr.length() < FORCEJEO_PASO_MIN_M or vr.normalized().dot(frente) < 0.6:
			continue
		mejor = i
		mejor_d = d
	if mejor < 0:
		return
	var lado := 1 if ((_posiciones[mejor] as Vector2) - (_posiciones[i_d] as Vector2)).dot(derecha) > 0.0 else -1
	var hasta := _tiempo_reproduccion + FORCEJEO_MANTIENE_TICKS
	_forcejeos[dueno] = [lado, hasta]
	_forcejeos[int(_jugadores_cuadro[mejor]["id"])] = [-lado, hasta]


## Remates con efecto: el que patea y el tick del golpe. Se reconocen por la
## curva que el motor le pone a la pelota en ese tick o el siguiente.
func _preparar_efectos(fotos: Array) -> void:
	_efectos.clear()
	for k in fotos.size():
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) != MotorEspacial.ACCION_PATEA:
				continue
			for kk in [k, k + 1]:
				if kk < fotos.size() and float(_curva_de(fotos[kk]).get("curva_m", 0.0)) > 0.0:
					_efectos.append({"id": int(a["clave"]), "golpe": k})
					break


static func _curva_de(fotograma: Dictionary) -> Dictionary:
	var tr = fotograma["pelota"].get("trayectoria", {})
	return tr if tr is Dictionary else {}


## Tick del golpe con efecto de `id` si está por patear o pateando (-1 si no).
func _efecto_de(id: int) -> int:
	for e in _efectos:
		if int(e["id"]) == id and _tiempo_reproduccion >= float(e["golpe"]) - EFECTO_ACOMODA_TICKS - 1.5 \
				and _tiempo_reproduccion <= float(e["golpe"]) + 3.0:
			return int(e["golpe"])
	return -1


## La pelota por la curva del motor en este instante: Vector3(x, altura, y), o
## INF si no hay curva. Terminada la curva (ya en la red) cae desde donde entró.
func _pelota_en_curva() -> Vector3:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return Vector3.INF
	var fotos: Array = rep.fotogramas
	var idx := clampi(int(_tiempo_reproduccion), 0, fotos.size() - 1)
	var t := _tiempo_reproduccion - float(idx)
	var tr := _curva_de(fotos[idx])
	var p0 := float(tr.get("progreso", 0.0))
	# El tick del golpe: el motor graba la curva recién en el siguiente, con la
	# pelota ya afuera (ver CoreografiaPartido). Sale del origen.
	if float(tr.get("curva_m", 0.0)) <= 0.0 and idx + 1 < fotos.size():
		var sig := _curva_de(fotos[idx + 1])
		var bola := Vector2(fotos[idx]["pelota"]["x"], fotos[idx]["pelota"]["y"])
		if float(sig.get("curva_m", 0.0)) > 0.0 \
				and bola.distance_to(Vector2(sig["origen"]["x"], sig["origen"]["y"])) < 1.0:
			tr = sig
			p0 = 0.0
	if float(tr.get("curva_m", 0.0)) > 0.0:
		var p1 := 1.0
		if idx + 1 < fotos.size():
			var tr1 := _curva_de(fotos[idx + 1])
			if not tr1.is_empty() and tr1.get("origen") == tr.get("origen"):
				p1 = float(tr1.get("progreso", 1.0))
		if p1 <= p0:
			p1 = 1.0
		var p := clampf(lerpf(p0, p1, t), 0.0, 1.0)
		var o := Vector2(tr["origen"]["x"], tr["origen"]["y"])
		var c := Vector2(tr["control"]["x"], tr["control"]["y"])
		var d := Vector2(tr["destino"]["x"], tr["destino"]["y"])
		var q := o.lerp(c, p).lerp(c.lerp(d, p), p)
		return Vector3(q.x, _altura_de_curva(p), q.y)
	# Recién terminada: la pelota quedó en el destino (la red) y cae.
	for atras in range(1, 4):
		if idx - atras < 0:
			break
		var previa := _curva_de(fotos[idx - atras])
		if float(previa.get("curva_m", 0.0)) <= 0.0:
			continue
		var d := Vector2(previa["destino"]["x"], previa["destino"]["y"])
		var ahora := Vector2(fotos[idx]["pelota"]["x"], fotos[idx]["pelota"]["y"])
		if ahora.distance_to(d) > 1.0:
			break
		var seg := (float(atras - 1) + t) * MotorEspacial.TICK_SEG
		return Vector3(d.x, maxf(0.0, CURVA_ENTRA_M - 4.9 * seg * seg), d.y)
	return Vector3.INF


static func _altura_de_curva(p: float) -> float:
	return CURVA_ARCO_M * 4.0 * p * (1.0 - p) + CURVA_ENTRA_M * p


## Busca una vez por grabación los remates que llegan al arco (gol o atajada;
## el palo y el tiro libre tienen su propio vuelo) y elige para cada uno a qué
## altura llega y cómo lo ataja el arquero. La elección sale del tick del golpe
## y del que patea: la misma cada vez que se ve el partido. Solo cambia el
## dibujo: el motor manda todo remate al ras y llega al arco a 0 m.
func _preparar_remates(rep: VistaPartido, fotos: Array) -> void:
	_remates_3d.clear()
	if sin_remates:
		return
	var k := 1
	while k < fotos.size():
		if not bool(fotos[k]["pelota"].get("es_remate", false)) or bool(fotos[k - 1]["pelota"].get("es_remate", false)):
			k += 1
			continue
		var fin := k
		while fin + 1 < fotos.size() and bool(fotos[fin + 1]["pelota"].get("es_remate", false)):
			fin += 1
		var armado := _armar_remate(rep, fotos, k, fin)
		if not armado.is_empty():
			_remates_3d.append(armado)
		k = fin + 1


## Un número de 0 a 1 que sale siempre igual de (a, b, sal).
static func _azar(a: int, b: int, sal: int) -> float:
	return float(hash([a, b, sal]) & 0xFFFF) / 65535.0


## El remate que vuela de `k` a `fin` (ticks con `es_remate`): {} si no llega
## al arco. `llega`: el gol al cruzar la línea, la atajada en las manos (el
## motor termina el vuelo en el arquero, en el tick siguiente al último).
## `forma`: la atajada (vuela, vuela_alta, abajo, pecho, arriba); en el gol,
## cómo se tira el arquero que no llega. `h`: el alto del centro de la pelota
## al llegar; `alto`: la escala del salto de la estirada.
func _armar_remate(rep: VistaPartido, fotos: Array, k: int, fin: int) -> Dictionary:
	var llega := mini(fin + 1, fotos.size() - 1)
	var ev := {}
	for kk in range(fin, mini(llega + 2, fotos.size())):
		for e in fotos[kk].get("eventos", []):
			if str(e.get("tipo", "")) in ["tiro_puerta", "penal"]:
				ev = e
	if ev.is_empty() or bool(ev.get("palo", false)) or bool(ev.get("tiro_libre", false)):
		return {}
	var gol := str(ev.get("resultado", "")) == "gol"
	var clave := int(ev.get("clave", -1))
	var golpe := float(k - 1)
	var accion := MotorEspacial.ACCION_PATEA
	for i in range(k, maxi(-1, k - 6), -1):
		var c: Dictionary = rep._coreografia.contactos.get(i, {})
		if not c.is_empty() and int(c["clave"]) == clave:
			golpe = float(c["golpe"])
			accion = str(c["accion"])
			break
	var jt := VistaPartido._jugador_en(fotos[k - 1], clave)
	if jt.is_empty():
		return {}
	var arquero := -1
	for j in fotos[k - 1]["jugadores"]:
		if str(j["rol"]) == "ARQ" and bool(j["equipo_local"]) != bool(jt["equipo_local"]):
			arquero = int(j["id"])
	var ja := VistaPartido._jugador_en(fotos[int(golpe)], arquero)
	if ja.is_empty():
		return {}
	var llegada := float(llega)
	var y_llega := float(fotos[llega]["pelota"]["y"])
	var fin_red := float(llega)
	if gol:
		var linea := MotorEspacial.MEDIO_LARGO
		for j in range(k, llega + 1):
			var a: Dictionary = fotos[j - 1]["pelota"]
			var b: Dictionary = fotos[j]["pelota"]
			if absf(float(b["x"])) >= linea and absf(float(a["x"])) < linea:
				var u := (linea - absf(float(a["x"]))) / maxf(absf(float(b["x"])) - absf(float(a["x"])), 0.01)
				llegada = float(j - 1) + u
				y_llega = lerpf(float(a["y"]), float(b["y"]), u)
				break
		var j2 := llega + 1
		while j2 < fotos.size() and j2 < llega + int(REMATE_EN_RED_TICKS) and not VistaPartido._es_reubicacion(fotos[j2]):
			j2 += 1
		fin_red = float(j2)
	if llegada - golpe < 0.3:
		return {}
	var parado := absf(y_llega - float(ja["y"])) < PARADA_TRAVESIA_M
	# La que no retiene (rechazo) sale de los guantes de la estirada: el
	# motor la hace rebotar alta y parado quedaba lejos de las manos.
	if not gol:
		var retiene := false
		for kk in range(llega, mini(llega + 2, fotos.size())):
			retiene = retiene or int(fotos[kk]["pelota"].get("poseedor_id", -1)) == arquero
		parado = parado and retiene
	var cabeza := accion in [MotorEspacial.ACCION_CABECEA, MotorEspacial.ACCION_PALOMITA]
	var r1 := _azar(int(golpe), clave, 1)
	var r2 := _azar(int(golpe), clave, 2)
	var forma := "vuela"
	var h := 0.0
	var alto := 1.0
	if not gol:
		if parado:
			# De frente: abajo (de rodilla), al pecho o arriba (saltando).
			if r1 < (0.45 if cabeza else 0.35):
				forma = "abajo"
				h = MANOS_ABAJO_M
			elif r1 < 0.72:
				forma = "pecho"
				h = MANOS_PECHO_M
			else:
				forma = "arriba"
				h = MANOS_ARRIBA_M
		elif r1 < (0.2 if cabeza else 0.35):
			forma = "vuela_alta"
			alto = 0.3 + 0.7 * r2
			h = MANOS_VUELA_ALTA_M + SALTO_VUELO_M * alto
		else:
			alto = r2
			h = MANOS_VUELA_M + SALTO_VUELO_M * alto
	elif parado:
		# Le pasa por arriba: salta y no llega.
		forma = "arriba"
		h = lerpf(GOL_ARRIBA_M.x, GOL_ARRIBA_M.y, r2)
	elif r1 < (0.55 if cabeza else 0.4):
		# Al ras: se tira bajo y le pasa por abajo de los guantes.
		h = lerpf(GOL_RAS_M.x, GOL_RAS_M.y, r2)
		alto = 0.0
	elif r1 < 0.65:
		h = lerpf(GOL_MEDIA_M.x, GOL_MEDIA_M.y, r2)
		alto = clampf((h - MANOS_VUELA_M) / SALTO_VUELO_M, 0.0, 1.0)
	else:
		# Al ángulo: la estirada alta, con las manos un poco abajo de la pelota.
		forma = "vuela_alta"
		h = lerpf(GOL_ANGULO_M.x, GOL_ANGULO_M.y, r2)
		alto = clampf((h - 0.25 - MANOS_VUELA_ALTA_M) / SALTO_VUELO_M, 0.0, 1.0)
	return {"golpe": golpe, "llega": llegada, "hasta": fin_red if gol else llegada, "gol": gol,
		"clave": clave, "arquero": arquero, "forma": forma, "h": h, "alto": alto,
		"z0": float(REMATE_SALE_M.get(accion, 0.0))}


## Alto del centro de la pelota del remate `r` en `t`: de la salida (el pie o
## la cabeza) al alto elegido, con un poco de panza (casi nada al ras).
static func _alto_de_remate(r: Dictionary, t: float, radio: float) -> float:
	var g := float(r["golpe"])
	var u := clampf((t - g) / maxf(float(r["llega"]) - g, 0.01), 0.0, 1.0)
	var h := float(r["h"])
	var panza := REMATE_PANZA_M if h > 0.5 else REMATE_PANZA_M * 0.2
	return lerpf(maxf(float(r["z0"]), radio), h, u) + panza * 4.0 * u * (1.0 - u)


## La pelota de un remate al arco en este instante (la de `nueva` con el alto
## del remate) o INF. Sale del pie de a poco (la corrección del golpe); la
## atajada termina en las manos (su contacto la lleva) y el gol cae en la red.
func _pelota_del_remate(nueva: Vector3, radio: float) -> Vector3:
	var t := _tiempo_reproduccion
	for r in _remates_3d:
		var g := float(r["golpe"])
		if t < g or t > float(r["hasta"]):
			continue
		var llega := float(r["llega"])
		var festejando := bool(r["gol"]) and _festejo_ticks > 0.0
		if t <= llega and not festejando:
			var alto := lerpf(nueva.y, _alto_de_remate(r, t, radio), smoothstep(g, g + 0.3, t))
			if not bool(r["gol"]):
				alto = lerpf(alto, nueva.y, smoothstep(llega - 0.4, llega, t))
			return Vector3(nueva.x, maxf(alto, radio), nueva.z)
		if not bool(r["gol"]):
			return Vector3.INF
		# En la red: cae desde donde entró (el festejo congela la reproducción).
		var seg := (t - llega + _festejo_ticks) * MotorEspacial.TICK_SEG
		return Vector3(nueva.x, maxf(radio, float(r["h"]) - 4.9 * seg * seg), nueva.z)
	return Vector3.INF


## El remate que el arquero `clave` ataja (o intenta atajar) en `tiempo`, o {}.
func _remate_de_arquero(clave: int, tiempo: float) -> Dictionary:
	for r in _remates_3d:
		if int(r["arquero"]) == clave and tiempo >= float(r["golpe"]) - 0.5 and tiempo <= float(r["llega"]) + 5.0:
			return r
	return {}


## La atajada sin tirarse (abajo, al pecho o arriba) del arquero en `tiempo`, o {}.
func _parada_de(clave: int, tiempo: float) -> Dictionary:
	var r := _remate_de_arquero(clave, tiempo)
	return r if str(r.get("forma", "")) in ["abajo", "pecho", "arriba"] else {}


## Busca una vez por grabación los remates al palo o al travesaño (los que
## salen, siguen en juego o van al córner) y los goles que entran pegando en
## el palo.
func _preparar_palos(rep: VistaPartido, fotos: Array) -> void:
	_palos.clear()
	for k in range(1, fotos.size()):
		for ev in fotos[k].get("eventos", []):
			var gol := str(ev.get("resultado", "")) == "gol" and bool(ev.get("palo", false))
			if str(ev.get("resultado", "")) != "palo" and not gol:
				continue
			var armado := _armar_palo(rep, fotos, k, ev, gol)
			if not armado.is_empty():
				_palos.append(armado)


## Un remate al marco que llega en el tick `k`: dónde pega (centro de la
## pelota, x/alto/y) y cómo sigue. `tipo`: "afuera" (el motor la deja en la
## línea hasta el saque de arco), "gol" (la pasa a la red en el mismo tick) o
## "sigue" (en juego o al córner: el motor la hace volar desde la línea).
func _armar_palo(rep: VistaPartido, fotos: Array, k: int, ev: Dictionary, gol: bool) -> Dictionary:
	var clave := int(ev.get("clave", -1))
	var golpe := float(k - 1)
	var origen := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
	var accion := MotorEspacial.ACCION_PATEA
	for i in range(k, maxi(-1, k - 12), -1):
		var c: Dictionary = rep._coreografia.contactos.get(i, {})
		if not c.is_empty() and int(c["clave"]) == clave:
			golpe = float(c["golpe"])
			origen = c["origen"]
			accion = str(c["accion"])
			break
	if golpe >= float(k):
		return {}
	var linea := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"])
	var lado := signf(linea.x)
	var destino := "gol" if gol else str(ev.get("destino_palo", "en_juego"))
	var travesano := bool(ev.get("travesano", false))
	var radio := RADIO_PELOTA * ESCALA_PELOTA
	var toca := MARCO_RADIO_M + radio
	# Al córner el motor la manda por la línea a cualquier lado, cruzando el
	# arco si le toca el otro: pega en el palo de ese lado y sale por afuera;
	# el 3D la lleva hasta donde el motor ya la tiene afuera y sigue el motor.
	var afuera_en := -1
	if destino == "corner":
		for j in range(k + 1, mini(fotos.size(), k + 10)):
			var q := Vector2(fotos[j]["pelota"]["x"], fotos[j]["pelota"]["y"])
			if absf(q.y) > POSTE_Y_M + 1.0 or VistaPartido._es_reubicacion(fotos[j]):
				afuera_en = j
				break
		if afuera_en == -1 or VistaPartido._es_reubicacion(fotos[afuera_en]):
			destino = "afuera"
		elif not travesano:
			linea.y = absf(linea.y) * signf(float(fotos[afuera_en]["pelota"]["y"]))
	var marco_x := lado * (MotorEspacial.MEDIO_LARGO + MARCO_ATRAS_M)
	var impacto: Vector3
	if travesano:
		# Abajo y adelante del travesaño: rebota para arriba o para el piso.
		impacto = Vector3(marco_x - lado * toca * 0.87, TRAVESANO_Y_M - toca * 0.5,
			clampf(linea.y, -POSTE_Y_M + toca, POSTE_Y_M - toca))
	else:
		# Cara de adentro si vuelve a la cancha o entra; de afuera si sale.
		var costado := signf(linea.y) if absf(linea.y) > 0.01 else 1.0
		var adentro := destino in ["gol", "en_juego"]
		impacto = Vector3(marco_x - lado * toca * 0.7,
			float(PALO_ALTO_M.get(accion, PALO_ALTO_PIE_M)),
			costado * (POSTE_Y_M + (-1.0 if adentro else 1.0) * toca * 0.7))
	var z0 := 0.0
	if accion in [MotorEspacial.ACCION_CABECEA, MotorEspacial.ACCION_PALOMITA]:
		z0 = 1.5
	elif accion in ["volea", "chilena"]:
		z0 = 0.9
	var armado := {"golpe": golpe, "llega": float(k), "origen": origen, "z0": z0,
		"impacto": impacto, "travesano": travesano, "linea": linea}
	# Con efecto la pelota va por la curva del motor, que termina en la línea.
	for i in range(int(golpe), k + 1):
		var tr := _curva_de(fotos[i])
		if float(tr.get("curva_m", 0.0)) > 0.0:
			armado["curva_destino"] = Vector2(tr["destino"]["x"], tr["destino"]["y"])
	if destino == "gol":
		armado["tipo"] = "gol"
		armado["fin"] = float(k) + PALO_GOL_TICKS
		return armado
	if destino == "corner":
		var sale: Dictionary = fotos[afuera_en]["pelota"]
		armado["tipo"] = "corner"
		armado["sube"] = TRAVESANO_SALE_SUBE if travesano else PALO_SALE_SUBE
		armado["sale"] = Vector3(sale["x"], float(sale.get("z", 0.0)), sale["y"])
		armado["fin"] = float(afuera_en)
		return armado
	if destino == "afuera":
		# Hasta que el motor la lleva al saque de arco.
		var corte := k + 1
		while corte < fotos.size() and not VistaPartido._es_reubicacion(fotos[corte]) and corte < k + 40:
			corte += 1
		var pica: Vector2
		if travesano:
			pica = Vector2(lado * (MotorEspacial.MEDIO_LARGO + PALO_SALE_FONDO_M), impacto.z * 1.15)
		else:
			pica = Vector2(lado * (MotorEspacial.MEDIO_LARGO + PALO_SALE_FONDO_M * 0.65),
				signf(impacto.z) * (POSTE_Y_M + PALO_SALE_COSTADO_M))
		var suelo := Vector2(impacto.x, impacto.z)
		armado["tipo"] = "afuera"
		armado["pica"] = pica
		armado["reposo"] = pica + (pica - suelo).normalized() * PALO_SALE_RUEDA_M
		armado["fin"] = float(corte)
		return armado
	# En juego: el motor la hace volar desde la línea hacia la cancha.
	armado["tipo"] = "sigue"
	armado["sube"] = 0.8 if travesano else PALO_SALE_SUBE
	armado["dura"] = TRAVESANO_REBOTE_TICKS if travesano else PALO_REBOTE_TICKS
	armado["fin"] = float(k) + float(armado["dura"])
	return armado


## Alto del centro de la pelota que sale de `y0` con pendiente `sube` y
## termina en `y1` (en el piso, el radio) al final del tramo, en la fracción `w`.
static func _parabola_de_rebote(y0: float, sube: float, y1: float, w: float) -> float:
	return y0 + sube * w - (y0 - y1 + sube) * w * w


## La pelota de un remate al palo en este instante (x, alto del centro, y), o
## INF si no hay. `nueva` es la que iba a dibujarse (motor, contacto del pie,
## curva): al salir del pie se parte de ella.
func _pelota_en_palo(nueva: Vector3, radio: float) -> Vector3:
	var t := _tiempo_reproduccion
	for p in _palos:
		var golpe := float(p["golpe"])
		var llega := float(p["llega"])
		if t < golpe or t >= float(p["fin"]):
			continue
		var imp: Vector3 = p["impacto"]
		var al_marco := Vector2(imp.x, imp.z)
		var ahora := Vector2(nueva.x, nueva.z)
		var festejando := str(p["tipo"]) == "gol" and _festejo_ticks > 0.0
		if t <= llega and not festejando:
			var u := (t - golpe) / (llega - golpe)
			var suelo: Vector2
			if p.has("curva_destino"):
				suelo = ahora + (al_marco - (p["curva_destino"] as Vector2)) * u
			else:
				var recta := (p["origen"] as Vector2).lerp(al_marco, u)
				suelo = ahora.lerp(recta, smoothstep(0.0, 0.3, u))
			var alto := lerpf(float(p["z0"]) + radio, imp.y, u)
			alto = lerpf(nueva.y, alto, smoothstep(0.0, 0.3, u))
			return Vector3(suelo.x, maxf(alto, radio), suelo.y)
		var s := t - llega
		match str(p["tipo"]):
			"gol":
				# El festejo congela la reproducción en el tick del gol.
				var w := clampf((s + _festejo_ticks) / PALO_GOL_TICKS, 0.0, 1.0)
				var red := al_marco.lerp(p["linea"], w)
				return Vector3(red.x, _parabola_de_rebote(imp.y, 0.0, radio, w), red.y)
			"corner":
				# Hasta donde el motor ya la tiene afuera del palo, a su altura.
				var sale: Vector3 = p["sale"]
				var w := s / (float(p["fin"]) - llega)
				var aire := al_marco.lerp(Vector2(sale.x, sale.z), w)
				return Vector3(aire.x, _parabola_de_rebote(imp.y, float(p["sube"]), sale.y + radio, w), aire.y)
			"afuera":
				var sube := TRAVESANO_SALE_SUBE if bool(p["travesano"]) else PALO_SALE_SUBE
				if s < PALO_SALE_VUELO_TICKS:
					var w := s / PALO_SALE_VUELO_TICKS
					var aire := al_marco.lerp(p["pica"], w)
					return Vector3(aire.x, _parabola_de_rebote(imp.y, sube, radio, w), aire.y)
				var r := clampf((s - PALO_SALE_VUELO_TICKS) / PALO_SALE_RUEDA_TICKS, 0.0, 1.0)
				var rueda := (p["pica"] as Vector2).lerp(p["reposo"], 1.0 - (1.0 - r) * (1.0 - r))
				var pique := PALO_PIQUE_M * sin(clampf(r * 1.6, 0.0, 1.0) * PI)
				return Vector3(rueda.x, radio + pique, rueda.y)
			_:
				# El motor ya la hace volar desde la línea: se le suma lo que el
				# marco la corre y el alto del rebote, que se apagan.
				var w := clampf(s / float(p["dura"]), 0.0, 1.0)
				var suelo := ahora + (al_marco - (p["linea"] as Vector2)) * (1.0 - smoothstep(0.0, 1.0, w))
				var alto := maxf(nueva.y, _parabola_de_rebote(imp.y, float(p["sube"]), radio, w))
				return Vector3(suelo.x, alto, suelo.y)
	return Vector3.INF


## Pelota alta que cae y sigue suelta (3D-10). El motor la frena en seco al
## caer (FRENADO_PELOTA_SUELTA, 0.35 por tick): el saque de arco llega a 24 m/s
## y en 3 m queda quieta, sin picar. Acá el vuelo y lo que sigue se reparten de
## nuevo sobre el mismo recorrido del motor, del golpe hasta que alguien la toma
## (el mismo punto y el mismo tick): cae antes, pica y rueda frenando. Solo
## cambia el dibujo.
func _preparar_piques(rep: VistaPartido, fotos: Array) -> void:
	_piques.clear()
	for k in range(2, fotos.size()):
		if float(fotos[k]["pelota"].get("z", 0.0)) <= 0.05 and float(fotos[k - 1]["pelota"].get("z", 0.0)) > 0.05:
			var armado := _armar_pique(rep, fotos, k)
			if not armado.is_empty():
				_piques.append(armado)


## El pique de la pelota que cae en el tick `cae`, o {} si no va: la tocó
## alguien en el aire, era un remate, un vuelo bajo, la toman al caer o ya la
## dibuja un centro (3D-09).
func _armar_pique(rep: VistaPartido, fotos: Array, cae: int) -> Dictionary:
	if VistaPartido._es_reubicacion(fotos[cae]):
		return {}
	# El golpe: hacia atrás, en el aire y sin que nadie la toque, hasta la acción.
	var golpe := cae - 1
	var alto := 0.0
	while golpe > 0:
		var p: Dictionary = fotos[golpe]["pelota"]
		if bool(p.get("es_remate", false)) or VistaPartido._es_reubicacion(fotos[golpe]):
			return {}
		alto = maxf(alto, float(p.get("z", 0.0)))
		if not fotos[golpe].get("acciones", []).is_empty():
			break
		if float(p.get("z", 0.0)) <= 0.05:
			return {}
		golpe -= 1
	if golpe <= 0 or alto < PIQUE_ALTO_M:
		return {}
	var c: Dictionary = rep._coreografia.contactos.get(golpe, {})
	var desde := float(c["golpe"]) if not c.is_empty() else float(golpe - 1)
	# Hasta que alguien la toma (o sale, o se cansó de buscar).
	var fin := cae
	while fin < mini(fotos.size() - 1, cae + PIQUE_BUSCA_TICKS):
		if int(fotos[fin]["pelota"].get("poseedor_id", -1)) != -1 or not fotos[fin].get("acciones", []).is_empty():
			break
		if VistaPartido._es_reubicacion(fotos[fin]):
			fin -= 1
			break
		fin += 1
	# Cuándo toca el piso: lo que le quedaba al último tick en el aire, al ritmo
	# con que venía bajando.
	var z_a := float(fotos[cae - 1]["pelota"].get("z", 0.0))
	var baja := z_a
	if cae - 2 >= golpe:
		baja = float(fotos[cae - 2]["pelota"].get("z", 0.0)) - z_a
	var toca := float(cae - 1) + clampf(z_a / maxf(baja, 0.01), 0.0, 1.0)
	if float(fin) - toca < 1.0 or toca <= desde:
		return {}
	for cc in _centros:
		if float(cc["desde"]) <= float(fin) and float(cc["suelta"]) >= desde:
			return {}
	# El recorrido del motor, del golpe a la toma. Sale del pie: en el tick del
	# golpe el motor ya la tiene 6 m adelante (el saque de arco saltaba a 60 m/s).
	var puntos: Array = [c["origen"] if not c.is_empty() else _bola_motor(fotos, desde)]
	for q in range(int(desde) + 1, fin + 1):
		puntos.append(Vector2(fotos[q]["pelota"]["x"], fotos[q]["pelota"]["y"]))
	var largos: Array = [0.0]
	for i in range(1, puntos.size()):
		largos.append(float(largos[-1]) + (puntos[i] as Vector2).distance_to(puntos[i - 1]))
	if float(largos[-1]) < 1.0:
		return {}
	# El vuelo dura lo mismo y sube lo mismo que en el motor: la gravedad y la
	# velocidad con que llega al piso salen de ahí.
	var vuelo := (toca - desde) * MotorEspacial.TICK_SEG
	var total := (float(fin) - desde) * MotorEspacial.TICK_SEG
	var g := 8.0 * alto / (vuelo * vuelo)
	var v := 4.0 * alto / vuelo * PIQUE_RESTITUCION
	var u := 1.0
	var t := vuelo
	# Recorrido "crudo" (la horizontal del vuelo vale 1): después se escala
	# para que termine donde el motor la da por tomada.
	var crudo := vuelo
	var piques: Array = []
	while t < total and v * v / (2.0 * g) >= PIQUE_MIN_M:
		u *= PIQUE_ROCE
		var dura := 2.0 * v / g
		piques.append([t, dura, v, u])
		crudo += u * minf(dura, total - t)
		t += dura
		v *= PIQUE_RESTITUCION
	var rueda := [INF, 0.0]
	if t < total:
		u *= PIQUE_ROCE
		rueda = [t, u]
		crudo += u * PIQUE_RUEDA_SEG * (1.0 - exp(-(total - t) / PIQUE_RUEDA_SEG))
	return {"desde": desde, "toca": toca, "fin": float(fin), "vuelo": vuelo, "g": g,
		"piques": piques, "rueda": rueda, "crudo": crudo, "puntos": puntos, "largos": largos}


## Recorrido crudo y alto sobre el piso del pique `p` a los `s` segundos del
## golpe. Alto -1 en el vuelo (ahí manda el del motor).
static func _pique_en(p: Dictionary, s: float) -> Vector2:
	var vuelo := float(p["vuelo"])
	if s <= vuelo:
		return Vector2(s, -1.0)
	var crudo := vuelo
	var g := float(p["g"])
	for q in p["piques"]:
		var t0 := float(q[0])
		var dura := float(q[1])
		if s < t0 + dura:
			var w := s - t0
			return Vector2(crudo + float(q[3]) * w, float(q[2]) * w - 0.5 * g * w * w)
		crudo += float(q[3]) * dura
	var rueda: Array = p["rueda"]
	if s < float(rueda[0]):
		return Vector2(crudo, 0.0)
	return Vector2(crudo + float(rueda[1]) * PIQUE_RUEDA_SEG * (1.0 - exp(-(s - float(rueda[0])) / PIQUE_RUEDA_SEG)), 0.0)


## La pelota del pique (3D-10) en este instante, o INF si no hay. `nueva` es
## la que iba a dibujarse: se parte de ella al golpe y se vuelve a ella al
## tomarla.
func _pelota_con_pique(nueva: Vector3, radio: float) -> Vector3:
	var t := _tiempo_reproduccion
	for p in _piques:
		if t < float(p["desde"]) or t > float(p["fin"]):
			continue
		var r := _pique_en(p, (t - float(p["desde"])) * MotorEspacial.TICK_SEG)
		var largos: Array = p["largos"]
		var puntos: Array = p["puntos"]
		var metros := float(largos[-1]) * r.x / float(p["crudo"])
		var i := 1
		while i < largos.size() - 1 and float(largos[i]) < metros:
			i += 1
		var tramo := maxf(float(largos[i]) - float(largos[i - 1]), 0.001)
		var suelo := (puntos[i - 1] as Vector2).lerp(puntos[i], clampf((metros - float(largos[i - 1])) / tramo, 0.0, 1.0))
		var alto := nueva.y if r.y < 0.0 else radio + r.y
		var aca := Vector3(suelo.x, alto, suelo.y)
		var w := minf(smoothstep(float(p["desde"]), float(p["desde"]) + PIQUE_ENTRA_TICKS, t),
			1.0 - smoothstep(float(p["fin"]) - PIQUE_SUELTA_TICKS, float(p["fin"]), t))
		return nueva.lerp(aca, w)
	return Vector3.INF


func _preparar_pelota_parada(fotos: Array) -> void:
	_barreras.clear()
	_corners.clear()
	_pateadores.clear()
	_tarjetas.clear()
	for k in fotos.size():
		for ev in fotos[k].get("eventos", []):
			var tipo := str(ev.get("tipo", ""))
			if tipo == "tarjeta":
				var s_t := k + 1
				while s_t < fotos.size() and int(fotos[s_t].get("detenido", 0)) > 0 and s_t < k + 80:
					s_t += 1
				var falta := OficialesPartido._punto_del_evento(fotos[k], ev)
				# Se para al costado del amonestado (a lo largo de la cancha) y un
				# poco atrás: de frente a la cámara con el jugador al lado. Atrás
				# del todo, el jugador le tapaba la tarjeta.
				var al_lado := Vector2(-signf(falta.x) * TARJETA_AL_LADO_M if absf(falta.x) > 1.0 else TARJETA_AL_LADO_M, -0.6)
				_tarjetas.append({"falta": k, "saque": s_t, "lugar": falta + al_lado,
					"roja": str(ev.get("resultado", "amarilla")) != "amarilla"})
				continue
			if tipo not in ["falta", "corner"]:
				continue
			var s := k + 1
			while s < fotos.size() and int(fotos[s].get("detenido", 0)) > 0:
				s += 1
			if s >= fotos.size():
				continue
			var ejecutor := -1
			for a in fotos[s].get("acciones", []):
				if str(a["accion"]) in [MotorEspacial.ACCION_PATEA, "saque_arco"]:
					ejecutor = int(a["clave"])
			var je := VistaPartido._jugador_en(fotos[s - 1], ejecutor)
			if ejecutor == -1 or je.is_empty():
				continue
			# Adonde va la pelota: unos ticks después del saque (al arco si no
			# se movió).
			var desde_b := Vector2(fotos[s - 1]["pelota"]["x"], fotos[s - 1]["pelota"]["y"])
			var va := Vector2(fotos[mini(s + 3, fotos.size() - 1)]["pelota"]["x"],
				fotos[mini(s + 3, fotos.size() - 1)]["pelota"]["y"]) - desde_b
			if va.length() < 0.5:
				va = MotorEspacial.arco_rival_en(fotos[s - 1], bool(je["equipo_local"])) - desde_b
			_pateadores.append({"falta": k, "saque": s, "ejecutor": ejecutor, "bola": desde_b,
				"mira": va.normalized()})
			if tipo == "corner":
				_corners.append({"falta": k, "saque": s, "ejecutor": ejecutor})
				continue
			var f: Dictionary = fotos[s - 1]
			var bola := Vector2(f["pelota"]["x"], f["pelota"]["y"])
			var arco := MotorEspacial.arco_rival_en(f, bool(je["equipo_local"]))
			if bola.distance_to(arco) > BARRERA_HASTA_ARCO_M:
				continue
			var linea := (arco - bola).normalized()
			var ids := []
			for j in f["jugadores"]:
				if bool(j["equipo_local"]) == bool(je["equipo_local"]):
					continue
				var d := Vector2(j["x"], j["y"]) - bola
				var sobre := d.dot(linea)
				var costado := absf(d.cross(linea))
				if d.length() > 8.0 and d.length() < 10.5 and sobre > 0.0 and costado < 3.0:
					ids.append(int(j["id"]))
			if ids.size() >= 2:
				var registro := {"falta": k, "saque": s, "ids": ids, "bola": bola}
				_armar_vuelo_del_tiro_libre(fotos, registro, ids, bola, arco)
				_barreras.append(registro)


## La altura del remate del tiro libre, que el motor manda al ras del piso (el
## gol pasaba a través de la barrera). Si la pelota pasa la barrera, sube por
## arriba (BARRERA_ALTO_M a la distancia de la barrera) y baja al arco
## (TIRO_LIBRE_ENTRA_M al cruzar la línea). Si el motor la bloquea (pega en la
## barrera) les llega al cuerpo (BARRERA_PEGA_M) y cae en el rebote.
func _armar_vuelo_del_tiro_libre(fotos: Array, registro: Dictionary, ids: Array, bola: Vector2, arco: Vector2) -> void:
	var s := int(registro["saque"])
	var f0: Dictionary = fotos[s - 1]
	var muro := 0.0
	for id in ids:
		var j := VistaPartido._jugador_en(f0, int(id))
		muro += Vector2(j["x"], j["y"]).distance_to(bola) / float(ids.size())
	var bloqueado := false
	for k in range(s, mini(fotos.size(), s + 2)):
		for ev in fotos[k].get("eventos", []):
			if str(ev.get("resultado", "")) == "bloqueado":
				bloqueado = true
	if bloqueado:
		# Hasta la barrera de verdad (donde están los de la barrera), no hasta
		# donde el motor graba la pelota en el saque: en un partido la dejaba a
		# medio metro del que patea y la pelota subía ahí mismo, sin llegar.
		var centro := Vector2.ZERO
		for id in ids:
			var jm := VistaPartido._jugador_en(f0, int(id))
			centro += Vector2(jm["x"], jm["y"]) / float(ids.size())
		var direccion := (centro - bola).normalized()
		var impacto := maxf(muro - BARRERA_PEGA_ANTES_M, 1.0)
		var despues := mini(s + 2, fotos.size() - 1)
		var rebote := (bola + direccion * impacto).distance_to(
			Vector2(fotos[despues]["pelota"]["x"], fotos[despues]["pelota"]["y"]))
		registro["vuelo"] = {"tipo": "barrera", "origen": bola, "impacto": impacto, "direccion": direccion,
			"rebote_ticks": maxf(REBOTE_TICKS, rebote / REBOTE_M_POR_TICK)}
		return
	# Pasa: hasta dónde llega derecho (la línea de meta o donde frena).
	var cruce := -1.0
	var largo := 0.0
	for k in range(s, mini(fotos.size(), s + 10)):
		var p := Vector2(fotos[k]["pelota"]["x"], fotos[k]["pelota"]["y"])
		var p_ant := Vector2(fotos[k - 1]["pelota"]["x"], fotos[k - 1]["pelota"]["y"])
		if absf(p.x) >= MotorEspacial.LARGO * 0.5 and absf(p_ant.x) < MotorEspacial.LARGO * 0.5:
			var u := (MotorEspacial.LARGO * 0.5 - absf(p_ant.x)) / maxf(absf(p.x) - absf(p_ant.x), 0.001)
			cruce = float(k - 1) + u
			largo = p_ant.lerp(p, u).distance_to(bola)
			break
		if p.distance_to(p_ant) < 0.2 or int(fotos[k]["pelota"].get("poseedor_id", -1)) != -1:
			cruce = float(k)
			largo = p.distance_to(bola)
			break
	if cruce < 0.0 or largo < muro + 2.0:
		return
	# z(d) = a·d − b·d², con z(muro) = BARRERA_ALTO_M y z(largo) = TIRO_LIBRE_ENTRA_M.
	var h1 := BARRERA_ALTO_M
	var h2 := TIRO_LIBRE_ENTRA_M
	var b := (h1 * largo - h2 * muro) / (muro * largo * (largo - muro))
	var a := (h1 + b * muro * muro) / muro
	registro["vuelo"] = {"tipo": "pasa", "origen": bola, "a": a, "b": b, "cruce": cruce, "largo": largo}


## Tiro libre que pega en la barrera: dónde va la pelota (INF fuera de eso).
## Del saque vuela derecho hasta la barrera en un tick y, del golpe, rebota
## hasta donde la tiene el motor: al pie de la barrera o, en un partido,
## cerca del que pateó (el motor la graba ahí después del bloqueo).
func _pelota_en_barrera() -> Vector2:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return Vector2.INF
	var t := _tiempo_reproduccion
	for r in _barreras:
		if not r.has("vuelo") or str(r["vuelo"]["tipo"]) != "barrera":
			continue
		var s := float(r["saque"])
		var v: Dictionary = r["vuelo"]
		var rt := float(v.get("rebote_ticks", REBOTE_TICKS))
		if t < s or t > s + 1.0 + rt:
			continue
		var pega: Vector2 = (v["origen"] as Vector2) + (v["direccion"] as Vector2) * float(v["impacto"])
		if t <= s + 1.0:
			return (v["origen"] as Vector2).lerp(pega, t - s)
		var k := clampi(int(t), 0, rep.fotogramas.size() - 1)
		var k1 := mini(k + 1, rep.fotogramas.size() - 1)
		var motor := Vector2(rep.fotogramas[k]["pelota"]["x"], rep.fotogramas[k]["pelota"]["y"]).lerp(
			Vector2(rep.fotogramas[k1]["pelota"]["x"], rep.fotogramas[k1]["pelota"]["y"]), t - float(k))
		return pega.lerp(motor, smoothstep(0.0, 1.0, (t - s - 1.0) / rt))
	return Vector2.INF


## Altura (m) de la pelota en un tiro libre con barrera, o -1 si no hay.
func _altura_tiro_libre(pelota: Vector2) -> float:
	var t := _tiempo_reproduccion
	for r in _barreras:
		if not r.has("vuelo"):
			continue
		var v: Dictionary = r["vuelo"]
		var s := float(r["saque"])
		var d := pelota.distance_to(v["origen"])
		# El golpe: el saque. La coreografía deja la pelota quieta en el punto
		# hasta ese tick (el motor ya la graba lejos) y vuela al siguiente.
		_tiro_libre_golpe = s
		if str(v["tipo"]) == "pasa":
			var cruce := float(v["cruce"])
			if t < s - 1.0 or t > cruce + 0.5:
				continue
			if t <= cruce:
				return maxf(0.0, float(v["a"]) * d - float(v["b"]) * d * d)
			return TIRO_LIBRE_ENTRA_M * (1.0 - smoothstep(cruce, cruce + 0.4, t))
		else:
			var rt := float(v.get("rebote_ticks", REBOTE_TICKS))
			if t < s - 1.0 or t > s + 1.0 + rt * 1.6:
				continue
			# Sube hasta la barrera (a la altura del cuerpo)...
			if t <= s + 1.0:
				var u := clampf(t - s, 0.0, 1.0)
				return BARRERA_PEGA_M * u * (2.0 - u)
			# ...pega, salta para arriba del cuerpo que la frenó y cae al piso
			# con un piquecito. Frenar en seco y bajar derecho parecía que
			# atravesaba al de la barrera.
			var rb := (t - s - 1.0) / rt
			if rb <= 1.0:
				return maxf(0.0, BARRERA_PEGA_M + REBOTE_SUBE * rb - (BARRERA_PEGA_M + REBOTE_SUBE) * rb * rb)
			return REBOTE_PIQUE_M * sin(clampf((rb - 1.0) / 0.6, 0.0, 1.0) * PI)
	return -1.0


## La animación de pelota parada de `id` ahora, o {}: parado en la barrera,
## su salto cuando patean, o el brazo arriba del que va a tirar el corner.
func _gesto_de_pelota_parada(id: int, p3: Jugador3D) -> Dictionary:
	var t := _tiempo_reproduccion
	for b in _barreras:
		if not (b["ids"] as Array).has(id):
			continue
		var saque := float(b["saque"])
		if t >= saque and t < saque + 3.0 and p3.tiene("Barrera_Salto"):
			return {"anim": "Barrera_Salto", "tiempo": (t - saque) * MotorEspacial.TICK_SEG}
		# En la barrera recién cuando llegó a su lugar (antes camina hasta ahí).
		if t >= float(b["falta"]) and t < saque and _quieto(p3) and p3.tiene("Barrera"):
			return {"anim": "Barrera", "tiempo": fposmod(t * MotorEspacial.TICK_SEG, p3.duracion("Barrera"))}
	for c in _corners:
		if int(c["ejecutor"]) != id:
			continue
		var desde := float(c["saque"]) - CORNER_BRAZO_TICKS
		if t >= desde and t < float(c["saque"]) - 1.0 and _quieto(p3) and p3.tiene("Levantar_Brazo"):
			return {"anim": "Levantar_Brazo", "tiempo": minf((t - desde) * MotorEspacial.TICK_SEG, p3.duracion("Levantar_Brazo"))}
	return {}


## Hacia dónde mira el que va a patear un tiro libre o un corner, o ZERO: ya
## al lado de la pelota, adonde la manda. El 2D lo dejaba con la dirección de
## la última acción y quedaba mirando a la grada (bug 3D-05).
func _mira_de_pateador(id: int, pos: Vector2) -> Vector2:
	var t := _tiempo_reproduccion
	for p in _pateadores:
		if int(p["ejecutor"]) == id and t >= float(p["falta"]) and t < float(p["saque"]) + PATEADOR_MIRA_TICKS 				and pos.distance_to(p["bola"]) < PATEADOR_CERCA_M:
			return p["mira"]
	return Vector2.ZERO


## Hacia dónde mira el que está en la barrera (a la pelota), o ZERO.
func _mira_de_barrera(id: int, pos: Vector2) -> Vector2:
	var t := _tiempo_reproduccion
	for b in _barreras:
		if (b["ids"] as Array).has(id) and t >= float(b["falta"]) and t < float(b["saque"]) + 3.0:
			return (b["bola"] as Vector2) - pos
	return Vector2.ZERO


func _quieto(p3: Jugador3D) -> bool:
	for clave in _odometro:
		if _personas.get(clave) == p3:
			return float(_odometro[clave][2]) < 0.6
	return true


## Una recepción de `id` en el tick `k` (ver _preparar_bloqueos): la ventana
## en que se le promedia el recorrido. `al_pie` alarga la ventana (con el pie
## sale enseguida y el motor sigue acelerando un rato).
func _agregar_recepcion(fotos: Array, k: int, id: int, duracion: float, al_pie: bool) -> void:
	if not _recepciones.has(id):
		_recepciones[id] = []
	var fin := float(k) + duracion + RECEPCION_DESPUES_TICKS
	var vuelve := float(k) + CONTROL_ADELANTO_VUELVE_TICKS
	var adelanto := 0.0
	if al_pie:
		adelanto = CONTROL_ADELANTO_TICKS
		fin = maxf(fin, vuelve)
	# El promedio no mira más allá de su próxima acción (un pase y darse
	# vuelta): mezclaba la vuelta y frenaba antes de pasarla.
	var proxima := INF
	for k2 in range(k + 1, mini(fotos.size(), k + 24)):
		if fotos[k2].get("acciones", []).any(func(b): return int(b["clave"]) == id):
			proxima = float(k2) - 1.0
			break
	(_recepciones[id] as Array).append([float(k) - RECEPCION_ANTES_TICKS, fin, float(k), adelanto, vuelve, proxima])


## Centro que cae y se controla (3D-09): el motor deja caer el centro, lo
## hace rodar hasta el receptor y recién ahí graba el control con el pie. Acá
## la pelota sigue en el aire (desde el último tick a CENTRO_DESDE_M) hasta el
## pecho del receptor, que la baja de pecho. El receptor llega antes al punto
## donde el motor lo junta con la pelota: su recorrido se adelanta en el tiempo
## (`_tiempo_del_centro`) y se frena al tomarla. Solo cambia el dibujo.
func _preparar_centros(fotos: Array) -> void:
	_centros.clear()
	for k in range(2, fotos.size()):
		for a in fotos[k].get("acciones", []):
			var c := int(a["clave"])
			if str(a["accion"]) != "control_pie" or int(fotos[k]["pelota"].get("poseedor_id", -1)) != c:
				continue
			var j := VistaPartido._jugador_en(fotos[k], c)
			if j.is_empty() or str(j.get("rol", "")) == "ARQ":
				continue
			# Cayó y rodó suelta, sin que nadie la toque, hasta el control.
			var cae := k
			while cae > k - CENTRO_BUSCA_TICKS and cae > 1 and float(fotos[cae - 1]["pelota"].get("z", 0.0)) <= 0.05 \
					and int(fotos[cae - 1]["pelota"].get("poseedor_id", -1)) == -1 \
					and fotos[cae - 1].get("acciones", []).is_empty() and not VistaPartido._es_reubicacion(fotos[cae]):
				cae -= 1
			if cae == k or float(fotos[cae - 1]["pelota"].get("z", 0.0)) <= 0.05:
				continue
			# Desde el último tick del vuelo bastante alto (o el último en el aire).
			var s := cae - 1
			var alto := 0.0
			for q in range(cae - 1, maxi(0, cae - 1 - CENTRO_BUSCA_TICKS), -1):
				var pq: Dictionary = fotos[q]["pelota"]
				if int(pq.get("poseedor_id", -1)) != -1 or float(pq.get("z", 0.0)) <= 0.05 \
						or not fotos[q].get("acciones", []).is_empty() or VistaPartido._es_reubicacion(fotos[q]):
					break
				alto = maxf(alto, float(pq.get("z", 0.0)))
				if float(pq.get("z", 0.0)) >= CENTRO_DESDE_M and s == cae - 1:
					s = q
			if alto < CENTRO_ALTO_M or VistaPartido._es_reubicacion(fotos[s]):
				continue
			var p_s := _bola_motor(fotos, float(s))
			var z_s := float(fotos[s]["pelota"].get("z", 0.0))
			var v_s := p_s.distance_to(_bola_motor(fotos, float(s - 1)))
			# Cuándo el motor lo junta con la pelota, y dónde.
			var junta := float(k)
			var t := float(s)
			while t <= float(k):
				if _motor_de(fotos, c, t).distance_to(_bola_motor(fotos, t)) <= CENTRO_TOMA_M:
					junta = t
					break
				t += 0.05
			var punto := _motor_de(fotos, c, junta)
			# La toma: con la velocidad del vuelo y sin caer más rápido que un tope.
			var vuelo := maxf(CENTRO_VUELO_MIN_TICKS, maxf(punto.distance_to(p_s) / maxf(v_s, 0.5),
				(z_s - 1.0) / (CENTRO_CAIDA_MAX_MS * MotorEspacial.TICK_SEG)))
			# El siguiente toque del receptor (o pierde la pelota) corta la bajada.
			var sigue := float(k) + 10.0
			for q in range(k + 1, mini(fotos.size(), k + 10)):
				if int(fotos[q]["pelota"].get("poseedor_id", -1)) != c \
						or fotos[q].get("acciones", []).any(func(b): return int(b["clave"]) == c):
					sigue = float(q) - 1.0
					break
			var mira := p_s - punto
			# Si para llegar a la toma tiene que correr de más, la toma se atrasa
			# (la pelota llega más despacio) hasta que le alcance corriendo.
			var centro := {}
			var toma := float(s) + vuelo
			var tope_toma := minf(float(k), toma + CENTRO_ATRASO_MAX_TICKS)
			var vz := z_s - float(fotos[s - 1]["pelota"].get("z", 0.0))
			while toma <= tope_toma:
				centro = _armar_centro(c, k, float(s), toma, junta, sigue, p_s, z_s, vz, mira)
				if _corre_bien(fotos, centro):
					break
				centro = {}
				toma += 0.25
			if centro.is_empty():
				# No llega a tomarla en el aire: la pelota pica donde cae el centro
				# del motor y la baja de pecho en el rebote, donde el motor lo junta.
				var pique := float(cae)
				toma = maxf(junta, pique + CENTRO_PIQUE_MIN_TICKS)
				if toma > float(k):
					continue
				var p_l := _bola_motor(fotos, pique)
				centro = _armar_centro(c, k, pique, toma, toma, sigue, p_l, 0.0, 0.0, p_l - _motor_de(fotos, c, toma))
				centro["pique"] = true
			_centros.append(centro)
			# La recepción del control arranca antes y lleva el tiempo del centro.
			for w in _recepciones.get(c, []):
				if float(w[2]) == float(k) and (w as Array).size() == 6:
					w[0] = minf(float(w[0]), float(centro["arranca"]) - 1.0)
					w.append(centro)


## Un centro de _preparar_centros: la pelota va de `pelota` (altura `z`,
## bajando `vz` por tick) en `desde` al pecho en `toma`. El receptor llega en
## la toma adonde el motor lo junta con la pelota (`junta`), frena al tomarla
## y se pone al día (`vuelve`) antes de su próximo toque (`sigue`).
static func _armar_centro(clave: int, k: int, desde: float, toma: float, junta: float, sigue: float,
		pelota: Vector2, z: float, vz: float, mira: Vector2) -> Dictionary:
	var dur := float(VistaPartido.DURACION_ACCION["pecho"])
	var adelanto := maxf(0.0, junta - toma)
	var vuelve := toma + maxf(2.0 * adelanto + 1.0, minf(CENTRO_VUELVE_TICKS, sigue - toma))
	return {"clave": clave, "desde": desde, "toma": toma, "junta": maxf(junta, toma), "control": k,
		"fin": minf(toma + dur, sigue), "arranca": toma - maxf(2.0, CENTRO_ANTES_POR_ADELANTO * adelanto),
		"vuelve": vuelve,
		# Bajada, la pelota queda en su pie hasta que el motor se la da y él se
		# puso al día.
		"suelta": minf(maxf(maxf(toma + dur, float(k) + 0.5), vuelve), sigue),
		"pelota": pelota, "z": z, "vz": vz, "mira": mira.normalized() if mira.length() > 0.1 else Vector2.ZERO}


## ¿El receptor llega a la toma sin correr más rápido que CENTRO_CORRE_MAX_MS
## (o que lo que ya corre en el motor)? Medido de a 0.1 tick.
static func _corre_bien(fotos: Array, c: Dictionary) -> bool:
	var id := int(c["clave"])
	var dt := 0.1
	var motor := 0.0
	var dibujo := 0.0
	var t := float(c["arranca"])
	while t < float(c["vuelve"]):
		var r0 := _motor_de(fotos, id, t)
		var r1 := _motor_de(fotos, id, t + dt)
		var w0 := _motor_de(fotos, id, _tiempo_del_centro(c, t))
		var w1 := _motor_de(fotos, id, _tiempo_del_centro(c, t + dt))
		if r0 == Vector2.INF or r1 == Vector2.INF or w0 == Vector2.INF or w1 == Vector2.INF:
			return false
		motor = maxf(motor, r0.distance_to(r1))
		dibujo = maxf(dibujo, w0.distance_to(w1))
		t += dt
	var tope := maxf(CENTRO_CORRE_MAX_MS * MotorEspacial.TICK_SEG * dt, motor * 1.1)
	return dibujo <= tope


## Tiempo del recorrido del motor del receptor de un centro (3D-09): se
## adelanta hasta llegar en la toma adonde el motor lo junta con la pelota,
## casi quieto al tomarla, y vuelve al tiempo real después.
static func _tiempo_del_centro(c: Dictionary, t: float) -> float:
	var t0 := float(c["arranca"])
	var tc := float(c["toma"])
	var tj := float(c["junta"])
	var t1 := float(c["vuelve"])
	if t <= t0 or t >= t1:
		return t
	if t <= tc:
		return _hermite(t0, tj, tc - t0, CENTRO_LLEGA_RITMO * (tc - t0), (t - t0) / (tc - t0))
	return _hermite(tj, t1, CENTRO_LLEGA_RITMO * (t1 - tc), t1 - tc, (t - tc) / (t1 - tc))


static func _hermite(p0: float, p1: float, m0: float, m1: float, u: float) -> float:
	var u2 := u * u
	var u3 := u2 * u
	return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * m0 \
		+ (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * m1


## Posición del motor (x, y) de la pelota y de un jugador en un tiempo con fracción.
static func _bola_motor(fotos: Array, t: float) -> Vector2:
	var k0 := clampi(int(t), 0, fotos.size() - 1)
	var k1 := mini(k0 + 1, fotos.size() - 1)
	var a: Dictionary = fotos[k0]["pelota"]
	var b: Dictionary = fotos[k1]["pelota"]
	return Vector2(a["x"], a["y"]).lerp(Vector2(b["x"], b["y"]), t - float(k0))


static func _motor_de(fotos: Array, id: int, t: float) -> Vector2:
	var k0 := clampi(int(t), 0, fotos.size() - 1)
	var k1 := mini(k0 + 1, fotos.size() - 1)
	var a := VistaPartido._jugador_en(fotos[k0], id)
	var b := VistaPartido._jugador_en(fotos[k1], id)
	if a.is_empty():
		return Vector2.INF
	if b.is_empty():
		b = a
	return Vector2(a["x"], a["y"]).lerp(Vector2(b["x"], b["y"]), t - float(k0))


## El centro que el receptor `id` está bajando de pecho (o yendo a buscar), o {}.
func _centro_de(id: int) -> Dictionary:
	for c in _centros:
		if int(c["clave"]) == id and _tiempo_reproduccion >= float(c["arranca"]) \
				and _tiempo_reproduccion <= float(c["control"]) + float(VistaPartido.DURACION_ACCION["control_pie"]):
			return c
	return {}


## La pelota del centro (3D-09): del último tick alto del motor al pecho del
## receptor y, bajada de pecho, al pie; al final se junta con la de siempre
## (`normal`). INF fuera de eso.
func _pelota_del_centro(normal: Vector3, radio: float) -> Vector3:
	var t := _tiempo_reproduccion
	for c in _centros:
		if t < float(c["desde"]) or t > float(c["suelta"]):
			continue
		var pie := {}
		for p in _pies:
			if int(p.get("id", -1)) == int(c["clave"]):
				pie = p
		if pie.is_empty():
			return Vector3.INF
		var modelo: Jugador3D = pie["modelo"]
		var frente := Vector3(pie["frente"].x, 0.0, pie["frente"].y)
		var pecho := modelo.ancla("Pecho") + frente * radio
		var s := float(c["desde"])
		var tc := float(c["toma"])
		if t < tc:
			# Recta hasta el pecho; baja con la velocidad que traía (sin pasarse).
			var u := (t - s) / (tc - s)
			var ini: Vector2 = c["pelota"]
			var xz := ini.lerp(Vector2(pecho.x, pecho.z), u)
			var y0 := float(c["z"]) + radio
			var dy := pecho.y - y0
			if bool(c.get("pique", false)):
				# El rebote, con gravedad, hasta el pecho.
				var dur_s := (tc - s) * MotorEspacial.TICK_SEG
				var ts := (t - s) * MotorEspacial.TICK_SEG
				var v0 := (dy + 0.5 * GRAVEDAD * dur_s * dur_s) / dur_s
				return Vector3(xz.x, maxf(radio, y0 + v0 * ts - 0.5 * GRAVEDAD * ts * ts), xz.y)
			var m0 := float(c["vz"]) * (tc - s)
			if dy < 0.0:
				m0 = maxf(m0, 2.5 * dy)
			return Vector3(xz.x, maxf(radio, _hermite(y0, pecho.y, m0, 1.2 * dy, u)), xz.y)
		# Bajada de pecho, como en _punto_de_contacto.
		var avance := (t - tc) / float(VistaPartido.DURACION_ACCION["pecho"])
		var piso := Vector3(pie["pos"].x, radio, pie["pos"].y) + frente * PELOTA_DELANTE_M
		var bajada := pecho.lerp(piso, smoothstep(0.35, 0.95, avance))
		return bajada.lerp(normal, smoothstep(float(c["suelta"]) - CENTRO_SUELTA_TICKS, float(c["suelta"]), t))
	return Vector3.INF


## Lateral como en la tele: el motor deja la pelota en la línea y el que saca
## camina hasta ahí (hasta 17 ticks) con la pelota en las manos. Al empezar esa
## caminata se corta al jugador ya en la banda, LATERAL_PREPARA_TICKS antes
## del saque, levantando la pelota. Cambia la posición de reproducción (como
## un salto): el motor y el 2D no se tocan.
func _cortar_caminata_del_lateral() -> void:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return
	_preparar_bloqueos(rep)
	var t := rep.posicion
	for l in _laterales:
		var llega := float(l["saque"]) - LATERAL_PREPARA_TICKS
		if t >= float(l["inicio"]) and t < llega - 0.01:
			rep.posicion = llega
			var f: Dictionary = rep.fotogramas[int(l["saque"])]
			camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), rep.size)
			return


## Festejo del gol: VistaPartido congela la reproducción en el cuadro del gol
## y mueve solo al grupo que festeja. Con el tiempo de partido quieto, el
## arquero quedaba colgado en el aire a mitad de la estirada y el goleador
## corría al banderín con las piernas quietas (el odómetro no sumaba). Mientras
## dura, el 3D cuenta su propio tiempo, al ritmo del festejo del 2D.
func _contar_festejo(delta: float) -> void:
	var rep := get_parent() as VistaPartido
	if rep == null or rep._idx_congelado == -1 or rep._festejo_restante <= 0.0:
		_festejo_ticks = 0.0
		return
	if _segundos == 0.0:
		_segundos = delta * maxf(rep.velocidad, 1.0)
	_festejo_ticks += maxf(_segundos, 0.0) / MotorEspacial.TICK_SEG


## Tarjetas (ver _preparar_pelota_parada): el árbitro corre hasta donde fue
## la falta, saca la tarjeta, la muestra y la guarda (Tarjeta_Completa), y la
## reproducción corta al tiro libre ya por patearse (como en la tele; el
## expulsado caminando al lateral no se ve). Devuelve la tarjeta que corre
## ahora, con "llega" (tick en que llega) y "fin" ya calculados, o {}.
func _tarjeta_en_curso(pos_arbitro: Vector2) -> Dictionary:
	var t := _tiempo_reproduccion
	for r in _tarjetas:
		var k := float(r["falta"])
		if t < k or t > k + TARJETA_CORRE_MAX_TICKS + TARJETA_TICKS:
			r.erase("desde_pos")
			continue
		# Desde dónde corre: donde estaba al empezar. Se calcula una vez por
		# pasada: una reubicación del motor en el medio (el expulsado que sale)
		# la hacía empezar de nuevo. Al salir de la ventana se borra.
		if not r.has("desde_pos"):
			r["desde_pos"] = pos_arbitro
			var dist := pos_arbitro.distance_to(r["lugar"])
			var corre := clampf(dist / (ARBITRO_CORRE_MS * MotorEspacial.TICK_SEG), 1.0, TARJETA_CORRE_MAX_TICKS)
			r["llega"] = k + corre
			r["fin"] = float(r["llega"]) + TARJETA_TICKS
		if t <= float(r["fin"]):
			return r
	return {}


func _despues_del_corte_de_tarjeta() -> bool:
	var t := _tiempo_reproduccion
	for r in _tarjetas:
		if r.has("fin") and t > float(r["fin"]) and t < float(r["saque"]) + 2.0:
			return true
	return false


## Terminada la tarjeta, corta al tiro libre (3 ticks antes del saque).
func _cortar_despues_de_tarjeta() -> void:
	var rep := get_parent() as VistaPartido
	if rep == null:
		return
	var t := rep.posicion
	for r in _tarjetas:
		if not r.has("fin"):
			continue
		var llega_saque := float(r["saque"]) - LATERAL_PREPARA_TICKS
		if t > float(r["fin"]) and t < llega_saque - 0.01 and t < float(r["fin"]) + 1.0:
			rep.posicion = llega_saque
			var f: Dictionary = rep.fotogramas[int(r["saque"])]
			camara.saltar_a(Vector2(f["pelota"]["x"], f["pelota"]["y"]), rep.size)
			return


## El lateral que está sacando `id` en este instante, o {}.
func _lateral_de(id: int) -> Dictionary:
	var t := _tiempo_reproduccion
	for l in _laterales:
		if int(l["clave"]) == id and t >= float(l["saque"]) - LATERAL_PREPARA_TICKS - 0.01 \
				and t < float(l["saque"]) + LATERAL_ENTRA_HASTA_TICKS:
			return l
	return {}


func _armar_bloqueo(rep: VistaPartido, k: int, bloqueador: int) -> Dictionary:
	var fotos: Array = rep.fotogramas
	for kk in [k, k - 1]:
		if kk < 0:
			continue
		for b in fotos[kk].get("acciones", []):
			var tirador := int(b["clave"])
			if str(b["accion"]) != MotorEspacial.ACCION_PATEA or tirador == bloqueador:
				continue
			# Remate de pelota parada (tiro libre): la barrera ya está entre la
			# pelota y el arco, no hay que armar nada.
			if kk > 0 and int(fotos[kk - 1].get("detenido", 0)) > 0:
				return {}
			var c: Dictionary = rep._coreografia.contactos.get(kk, {})
			var golpe := float(c["golpe"]) if not c.is_empty() and int(c["clave"]) == tirador else float(kk)
			var jt := VistaPartido._jugador_en(fotos[int(golpe)], tirador)
			if jt.is_empty():
				continue
			var pel: Dictionary = fotos[int(golpe)]["pelota"]
			var bola := Vector2(pel["x"], pel["y"])
			var arco := (MotorEspacial.arco_rival_en(fotos[int(golpe)], bool(jt["equipo_local"])) - bola).normalized()
			return {"golpe": golpe, "tirador": tirador, "bloqueador": bloqueador, "desde": k,
				"pelota": bola, "arco": arco, "pierna": bola + arco * BLOQUEO_DISTANCIA_M}
	return {}


## Una atajada: el último remate antes del agarre, sin otro toque en el medio
## (la estirada del mismo arquero sí). La línea del tiro sale del pie y pasa
## por la primera muestra en vuelo; el arquero va al punto de esa línea más
## cercano a donde lo puso el motor.
func _armar_atajada(rep: VistaPartido, c: int, arquero: int) -> Dictionary:
	var fotos: Array = rep.fotogramas
	var pel_c: Dictionary = fotos[c]["pelota"]
	if int(pel_c.get("poseedor_id", -1)) != arquero:
		return {}
	for kk in range(c - 1, maxi(-1, c - 9), -1):
		var contacto: Dictionary = rep._coreografia.contactos.get(kk, {})
		if contacto.is_empty():
			continue
		if int(contacto["clave"]) == arquero:
			continue
		if str(contacto["accion"]) not in [MotorEspacial.ACCION_PATEA, "volea", "cabecea", "chilena", "palomita"]:
			return {}
		var golpe := float(contacto["golpe"])
		var g := int(golpe)
		if g + 1 >= c:
			return {}
		var p0: Dictionary = fotos[g]["pelota"]
		var p1: Dictionary = fotos[g + 1]["pelota"]
		var origen := Vector2(p0["x"], p0["y"])
		var direccion := Vector2(p1["x"], p1["y"]) - origen
		if direccion.length() < 0.5:
			return {}
		direccion = direccion.normalized()
		var jk := VistaPartido._jugador_en(fotos[c], arquero)
		if jk.is_empty():
			return {}
		var arquero_pos := Vector2(jk["x"], jk["y"])
		var punto := origen + direccion * maxf(0.0, (arquero_pos - origen).dot(direccion))
		if punto.distance_to(arquero_pos) > ATAJADA_MAX_M:
			return {}
		return {"golpe": golpe, "agarre": float(c), "arquero": arquero, "origen": origen,
			"punto": punto, "arquero_motor": arquero_pos}
	return {}


## Después de agarrarla el arquero la tiene en las manos hasta que la juega
## (4-7 ticks en los partidos). El motor la deja en sus pies y graba el saque
## como un pase ("patea") o un despeje ("saque_arco"): acá es con la mano,
## rodando, o de volea. Si se la sacan de otro modo, solo la sostiene.
func _preparar_saques_de_mano(rep: VistaPartido, fotos: Array) -> void:
	_manos_arquero.clear()
	_saques_mano.clear()
	for k in fotos.size():
		for a in fotos[k].get("acciones", []):
			if str(a["accion"]) != MotorEspacial.ACCION_AGARRA:
				continue
			var clave := int(a["clave"])
			var fin := k
			while fin + 1 < fotos.size() and int(fotos[fin + 1]["pelota"].get("poseedor_id", -1)) == clave \
					and not VistaPartido._es_reubicacion(fotos[fin + 1]):
				fin += 1
			var hasta := float(fin + 1)
			var saque := hasta
			# El saque queda grabado en el último tick con la pelota o en el
			# siguiente. La sostiene hasta el golpe de la coreografía (antes).
			for s in range(fin, mini(fin + 2, fotos.size())):
				for b in fotos[s].get("acciones", []):
					if int(b["clave"]) == clave and SAQUE_DE_MANO.has(str(b["accion"])):
						var a3: String = SAQUE_DE_MANO[str(b["accion"])]
						_saques_mano["%d_%d" % [clave, s]] = a3
						var c: Dictionary = rep._coreografia.contactos.get(s, {})
						hasta = float(c["golpe"]) if not c.is_empty() and int(c["clave"]) == clave else float(s)
						# Donde empieza el gesto del saque (su contacto cae en el golpe).
						saque = hasta - float(CONTACTO_3D[a3][1]) * float(VistaPartido.DURACION_ACCION.get(str(b["accion"]), 1))
			_manos_arquero.append({"clave": clave, "desde": float(k), "hasta": hasta, "saque": minf(saque, hasta)})
	_preparar_tendidos(rep, fotos)


## Estirada que termina en agarre: el motor graba `vuela` y, 1-3 ticks
## después, `agarra` (Agarrar, parado): el arquero se paraba en el aire. Acá
## sigue la estirada hasta caer, queda tirado con la pelota en el pecho y se
## levanta (Arquero_Levanta) antes del saque. El motor lo deja tirado
## (`fisica.arquero_tendido_ticks`); si no alcanza, se levanta más rápido.
func _preparar_tendidos(rep: VistaPartido, fotos: Array) -> void:
	_tendidos.clear()
	for m in _manos_arquero:
		var clave := int(m["clave"])
		var k := int(m["desde"])
		# Ataja parado: no se tira (ver _preparar_remates).
		if not _parada_de(clave, float(k)).is_empty():
			continue
		# La primera de las estiradas que graba seguidas antes del agarre.
		var estirada := -1
		for kk in range(k, maxi(-1, k - 7), -1):
			var vuela := false
			for a in fotos[kk].get("acciones", []):
				if int(a["clave"]) == clave and str(a["accion"]) == MotorEspacial.ACCION_VUELA:
					vuela = true
			if vuela:
				estirada = kk
			elif estirada >= 0:
				break
		if estirada < 0:
			continue
		# Cae cuando la animación llega a ESTIRADA_CAE_FASE, repartida en dos
		# tramos como en la estirada (su contacto en el golpe del motor).
		var dur_v := float(VistaPartido.DURACION_ACCION[MotorEspacial.ACCION_VUELA])
		var fc := _fase_de_contacto_buscada(rep, clave, estirada, MotorEspacial.ACCION_VUELA, dur_v)
		var ca := float(CONTACTO_3D[MotorEspacial.ACCION_VUELA][1])
		var cae := float(estirada) + dur_v * (fc + (ESTIRADA_CAE_FASE - ca) / (1.0 - ca) * (1.0 - fc))
		var ventana := (float(m["saque"]) - cae) * MotorEspacial.TICK_SEG
		var dura := LEVANTA_TICKS * MotorEspacial.TICK_SEG
		var extra := clampf(ventana - dura, 0.0, LEVANTA_TIRADO_EXTRA_MAX_SEG)
		var velocidad := maxf(1.0, dura / maxf(ventana, 0.25 * dura))
		_tendidos.append({"clave": clave, "estirada": float(estirada), "agarre": float(k), "cae": cae, "contacto": fc,
			"extra": extra, "velocidad": velocidad,
			"sube": cae + (LEVANTA_TIRADO_SEG.y + extra) / velocidad / MotorEspacial.TICK_SEG,
			"hasta": cae + (dura + extra) / velocidad / MotorEspacial.TICK_SEG})
	# La atajada (las manos en la línea del tiro) dura hasta que se levanta:
	# soltarla con el arquero tirado lo arrastraba por el piso. Se suelta
	# mientras se para (en 0.4 s patinaba 1.3 m).
	for a in _atajadas:
		var t := _tendido_de(int(a["arquero"]), float(a["agarre"]))
		if not t.is_empty():
			a["suelta_desde"] = float(t["sube"])
			a["suelta"] = float(t["hasta"])


## La estirada con agarre del arquero `clave` en `tiempo` (entre que se tira y
## que termina de levantarse), o {}.
func _tendido_de(clave: int, tiempo: float) -> Dictionary:
	for t in _tendidos:
		if int(t["clave"]) == clave and tiempo >= float(t["estirada"]) and tiempo <= float(t["hasta"]):
			return t
	return {}


## Segundos de Arquero_Levanta en `tiempo`: tirado del cuadro 6 al 13 con el
## tiempo que sobre (`extra`), y más rápido si falta (`velocidad`).
static func _tiempo_levanta(t: Dictionary, tiempo: float) -> float:
	var e := (tiempo - float(t["cae"])) * MotorEspacial.TICK_SEG * float(t["velocidad"])
	var x := float(t["extra"])
	var h0 := LEVANTA_TIRADO_SEG.x
	var h1 := LEVANTA_TIRADO_SEG.y
	if e <= h0:
		return maxf(e, 0.0)
	if e <= h1 + x:
		return h0 + (e - h0) * (h1 - h0) / (h1 - h0 + x)
	return e - x


## La acción del 3D: el pase o el despeje del arquero que la tenía en las
## manos es su saque con la mano o de volea.
func _saque_de_mano(clave: int, desde: int, accion: String) -> String:
	if not SAQUE_DE_MANO.has(accion):
		return accion
	return str(_saques_mano.get("%d_%d" % [clave, desde], accion))


## Lo mismo sin saber en qué tick empezó (la entidad de VistaPartido no lo
## trae): el saque de ese jugador que está corriendo ahora. La coreografía lo
## empieza hasta 2 ticks antes del tick grabado.
func _saque_de_mano_ahora(clave: int, accion: String) -> String:
	if not SAQUE_DE_MANO.has(accion):
		return accion
	var t := int(_tiempo_reproduccion)
	for k in range(t + 2, t - 5, -1):
		if _saques_mano.has("%d_%d" % [clave, k]):
			return str(_saques_mano["%d_%d" % [clave, k]])
	return accion


## Si el arquero `clave` tiene la pelota en las manos en este instante.
func _sostiene(clave: int) -> bool:
	for m in _manos_arquero:
		if int(m["clave"]) == clave and _tiempo_reproduccion >= float(m["desde"]) \
				and _tiempo_reproduccion < float(m["hasta"]):
			return true
	return false


## El arquero que la sostiene sin otra acción (ni el agarre ni el saque).
func _pie_que_sostiene() -> Dictionary:
	for pie in _pies:
		if str(pie["accion"]) == "" and int(pie.get("id", -1)) >= 0 and _sostiene(int(pie["id"])):
			return pie
	return {}


func _atajada_en(tiempo: float) -> Dictionary:
	for a in _atajadas:
		if tiempo >= float(a["golpe"]) and tiempo <= float(a.get("suelta", float(a["agarre"]) + ATAJADA_SUELTA_TICKS)):
			return a
	return {}


## Cuánto del corrimiento del arquero va en este instante (0..1).
func _peso_atajada() -> float:
	if _atajada.is_empty():
		return 0.0
	var c := float(_atajada["agarre"])
	var t := _tiempo_reproduccion
	var suelta := float(_atajada.get("suelta", c + ATAJADA_SUELTA_TICKS))
	var desde := float(_atajada.get("suelta_desde", c + 1.0))
	return smoothstep(c - ATAJADA_LLEGA_TICKS, c - 0.3, t) * (1.0 - smoothstep(desde, suelta, t))


func _bloqueo_en(rep: VistaPartido, tiempo: float) -> Dictionary:
	_preparar_bloqueos(rep)
	for b in _bloqueos:
		var g := float(b["golpe"])
		if tiempo >= g - BLOQUEO_LLEGA_TICKS and tiempo <= g + BLOQUEO_SUELTA_TICKS + 1.5:
			return b
	return {}


## Peso (0..1) del armado del bloqueo en este instante: entra antes del
## remate y se suelta después del rebote.
func _peso_bloqueo() -> float:
	if _bloqueo.is_empty():
		return 0.0
	var g := float(_bloqueo["golpe"])
	var t := _tiempo_reproduccion
	return smoothstep(g - BLOQUEO_LLEGA_TICKS, g - 0.3, t) * (1.0 - smoothstep(g + 0.8, g + BLOQUEO_SUELTA_TICKS, t))


## Estirada, barrida y bloqueo no tienen coreografía: el golpe es el instante
## en que la pelota del motor pasa más cerca del jugador durante la acción.
func _fase_de_contacto_buscada(rep: VistaPartido, clave: int, desde: int, accion: String, duracion: float) -> float:
	var llave := "%d_%d_%s" % [clave, desde, accion]
	if _fase_contacto.has(llave):
		return _fase_contacto[llave]
	var mejor := INF
	var fase_mejor := 0.0
	var pasos := int(duracion * 10.0)
	for s in range(pasos + 1):
		var tt := float(desde) + float(s) * 0.1
		var i0 := mini(int(tt), rep.fotogramas.size() - 1)
		var i1 := mini(i0 + 1, rep.fotogramas.size() - 1)
		var fr := tt - float(i0)
		var pj0 := VistaPartido._jugador_en(rep.fotogramas[i0], clave)
		var pj1 := VistaPartido._jugador_en(rep.fotogramas[i1], clave)
		if pj0.is_empty() or pj1.is_empty():
			continue
		var pj := Vector2(pj0["x"], pj0["y"]).lerp(Vector2(pj1["x"], pj1["y"]), fr)
		var b0: Dictionary = rep.fotogramas[i0]["pelota"]
		var b1: Dictionary = rep.fotogramas[i1]["pelota"]
		var pb := Vector2(b0["x"], b0["y"]).lerp(Vector2(b1["x"], b1["y"]), fr)
		var d := pj.distance_to(pb)
		if d < mejor:
			mejor = d
			fase_mejor = float(s) * 0.1 / duracion
	_fase_contacto[llave] = fase_mejor
	return fase_mejor


## Fase del motor -> tiempo de la animación, en dos tramos: el contacto del
## motor cae justo en el cuadro de contacto de la animación.
static func _fase_con_contacto(fase: float, fase_contacto: float, contacto_anim: float) -> float:
	if fase <= fase_contacto:
		return fase / fase_contacto * contacto_anim if fase_contacto > 0.0 else contacto_anim
	return contacto_anim + (fase - fase_contacto) / maxf(1.0 - fase_contacto, 0.001) * (1.0 - contacto_anim)


func _actualizar_persona(ent: Dictionary, clave: String, delta: float, vistos: Dictionary, indice: int = -1) -> void:
	var es_arquero := bool(ent.get("arquero", false))
	var p3 := _persona(clave, es_arquero)
	vistos[clave] = true
	var pos: Vector2 = ent["pos"] + _desvio_cuerpo.get(clave, Vector2.ZERO)
	if str(ent.get("rol_oficial", "")) == OficialesPartido.CUARTO_ARBITRO:
		# En un cambio, del lado por donde salen y entran: el motor los saca
		# por la banda más cercana y OficialesPartido lo deja siempre en la de
		# acá; el tablero quedaba del otro lado de la cancha.
		# Más cerca de la línea que los 4 m de OficialesPartido: en la banda de
		# allá quedaba detrás de los carteles y solo asomaba la cabeza.
		var lado := _lado_del_cambio()
		if lado == 0.0:
			lado = signf(pos.y) if pos.y != 0.0 else 1.0
		pos.y = lado * (MotorEspacial.MEDIO_ANCHO + CUARTO_ARBITRO_EN_CAMBIO_M)
		pos.x += CUARTO_ARBITRO_CORRIDO_M
	p3.position = Vector3(pos.x, float(ent.get("z", 0.0)), pos.y)
	p3.colorear(Color(ent["color"]), Color(ent.get("color_short", Color.TRANSPARENT)),
		Color(ent.get("color_pelo", Color.SADDLE_BROWN)))
	p3.poner_numero(int(ent.get("numero", 0)))
	_poner_cara(p3, ent, indice)

	var accion := str(ent.get("accion", ""))
	var id_j := -1
	if str(ent["tipo"]) == "jugador" and indice >= 0 and indice < _jugadores_cuadro.size():
		id_j = int(_jugadores_cuadro[indice]["id"])
	if es_arquero and id_j >= 0:
		accion = _saque_de_mano_ahora(id_j, accion)
	var fase_ent := float(ent.get("fase_animacion", 0.0))
	# Centro que el motor deja caer y controla con el pie (3D-09): lo baja de
	# pecho en el aire y, bajada, ya no hace el control del motor.
	var mira_centro := Vector2.ZERO
	var centro_r := _centro_de(id_j) if str(ent["tipo"]) == "jugador" and id_j >= 0 else {}
	if not centro_r.is_empty() and accion in ["", "control_pie"]:
		if _tiempo_reproduccion >= float(centro_r["toma"]) and _tiempo_reproduccion <= float(centro_r["fin"]):
			accion = "pecho"
			fase_ent = clampf((_tiempo_reproduccion - float(centro_r["toma"]))
				/ float(VistaPartido.DURACION_ACCION["pecho"]), 0.0, 1.0)
			mira_centro = centro_r["mira"]
		elif _tiempo_reproduccion > float(centro_r["fin"]):
			accion = ""
	var desvio_regate := Vector2.ZERO
	if str(ent["tipo"]) == "jugador":
		desvio_regate = _desvio_de_regate(indice, accion, ent["pos"])
		pos += desvio_regate
		p3.position = Vector3(pos.x, p3.position.y, pos.y)
	# Lateral cortado: ya está en la banda, mirando a la cancha, levantando la
	# pelota (el motor lo tiene todavía llegando).
	var lateral := {}
	if str(ent["tipo"]) == "jugador" and indice >= 0 and indice < _jugadores_cuadro.size():
		lateral = _lateral_de(int(_jugadores_cuadro[indice]["id"]))
	# Tarjeta: el árbitro corre hasta la falta (ver _tarjeta_en_curso).
	var tarjeta_r := {}
	if str(ent["tipo"]) == "oficial" and str(ent.get("rol_oficial", "")) == OficialesPartido.ARBITRO:
		tarjeta_r = _tarjeta_en_curso(ent["pos"])
		if not tarjeta_r.is_empty():
			var k_t := float(tarjeta_r["falta"])
			var llega_t := float(tarjeta_r["llega"])
			var u_t := smoothstep(k_t, llega_t, _tiempo_reproduccion) if llega_t > k_t else 1.0
			pos = (tarjeta_r["desde_pos"] as Vector2).lerp(tarjeta_r["lugar"], u_t)
			p3.position = Vector3(pos.x, p3.position.y, pos.y)
	var preparando := not lateral.is_empty() and _tiempo_reproduccion < float(lateral["saque"])
	if not lateral.is_empty():
		# Afuera de la línea hasta el saque; después vuelve de a poco adonde
		# lo tiene el motor.
		var s := float(lateral["saque"])
		pos = (lateral["pos"] as Vector2).lerp(pos,
			smoothstep(s + LATERAL_ENTRA_DESDE_TICKS, s + LATERAL_ENTRA_HASTA_TICKS, _tiempo_reproduccion))
		p3.position = Vector3(pos.x, p3.position.y, pos.y)
	if preparando:
		accion = "lateral_prepara"
	var rol_bloqueo := ""
	var peso_bloqueo := _peso_bloqueo()
	if not _bloqueo.is_empty() and str(ent["tipo"]) == "jugador":
		if indice == int(_indice_de.get(int(_bloqueo["bloqueador"]), -2)):
			rol_bloqueo = "bloqueador"
			pos = pos.lerp(_bloqueo["pierna"], peso_bloqueo)
			p3.position = Vector3(pos.x, p3.position.y, pos.y)
		elif indice == int(_indice_de.get(int(_bloqueo["tirador"]), -2)):
			rol_bloqueo = "tirador"
	var ataja := not _atajada.is_empty() and str(ent["tipo"]) == "jugador" \
		and indice == int(_indice_de.get(int(_atajada["arquero"]), -2))
	if ataja:
		# Las manos (no el centro del cuerpo) van al punto del tiro. Se usan
		# las del cuadro anterior: la pose de este todavía no está puesta.
		var rel: Vector2 = _manos_relativas.get(clave, Vector2.ZERO)
		var corrido: Vector2 = _atajada["punto"] - rel - (_atajada["arquero_motor"] as Vector2)
		pos += corrido * _peso_atajada()
		p3.position = Vector3(pos.x, p3.position.y, pos.y)
	var fase_amague := -1.0
	if accion == "control_pie" and _amagues.has(indice):
		var pasado := _tiempo_reproduccion - (float(_amagues[indice]) + AMAGUE_DESPUES_DEL_CONTROL_TICKS)
		if pasado >= 0.0:
			accion = "amague_centro"
			fase_amague = clampf(pasado / float(VistaPartido.DURACION_ACCION["amague_centro"]), 0.0, 1.0)
	# Terminado el gesto del regate mira para donde corre (la salida en
	# diagonal de la elástica), aunque el motor no haya cerrado la acción.
	# Recepción hecha y saliendo (corre, ver _recepcion_hecha): también. La
	# dirección de VistaPartido mira a la pelota que venía y el que la bajaba
	# de pecho y salía para el otro lado caminaba de espaldas (bug 3D-04).
	var regate_hecho := MotorEspacial.es_accion_regate(accion) and fase_ent >= 0.999
	regate_hecho = regate_hecho or _recepcion_hecha(accion, fase_ent, clave)
	var rumbo := _rumbo_de(ent, clave, pos, delta, "" if regate_hecho else accion)
	# El que baja el centro de pecho, de frente a la pelota que viene.
	if mira_centro != Vector2.ZERO and not regate_hecho:
		rumbo = mira_centro
	var objetivo := atan2(rumbo.x, rumbo.y)
	var actual: float = _rumbo.get(clave, objetivo)
	# El que cae sigue mirando hacia donde corría: la dirección que elige
	# VistaPartido para la acción mira al rival que le hizo la falta, y el
	# chibi se daba vuelta y caía para el otro lado.
	if accion in TENDIDOS:
		objetivo = actual
	if not lateral.is_empty() and _tiempo_reproduccion < float(lateral["saque"]) + LATERAL_MIRA_TICKS:
		var mira_l: Vector2 = lateral["mira"]
		objetivo = atan2(mira_l.x, mira_l.y)
	# Elástica: el defensor que compra el amague mira para el lado del amague.
	var compra := {}
	if str(ent["tipo"]) == "jugador" and accion == "" and indice >= 0 and indice < _jugadores_cuadro.size():
		compra = _compra_de(int(_jugadores_cuadro[indice]["id"]))
	if not compra.is_empty():
		var mira_c: Vector2 = compra["mira"]
		objetivo = atan2(mira_c.x, mira_c.y)
	# Estirada: de frente a la pelota que viene, y se tira a un costado. El
	# motor lo gira hacia el lado del vuelo y, con la estirada al costado del
	# cuerpo, caía mirando al arco.
	# Sigue mirando así un rato después, tirado y levantándose.
	if indice >= 0 and indice < _jugadores_cuadro.size() and _mira_vuela.has(int(_jugadores_cuadro[indice]["id"])):
		var id_v := int(_jugadores_cuadro[indice]["id"])
		var dato_v: Array = _mira_vuela[id_v]
		# La que termina en agarre sigue hasta que se levanta (ver _preparar_tendidos).
		var tendido_v := _tendido_de(id_v, _tiempo_reproduccion)
		var fin_v := float(tendido_v["hasta"]) if not tendido_v.is_empty() else float(dato_v[1]) + 8.0
		if accion == MotorEspacial.ACCION_VUELA or _tiempo_reproduccion < fin_v:
			var mira_vuela: Vector2 = dato_v[0]
			objetivo = atan2(mira_vuela.x, mira_vuela.y)
			rumbo = mira_vuela.normalized()
			# Queda corto (ver _estirada_corta): entra con la estirada y se
			# devuelve cuando ya se levantó.
			var d0 := float(dato_v[1])
			var corto: Vector2 = dato_v[2] if dato_v.size() > 2 else Vector2.ZERO
			var vuelve_desde := float(tendido_v["sube"]) if not tendido_v.is_empty() else fin_v - 2.0
			var vuelve := 1.0 - smoothstep(vuelve_desde, fin_v, _tiempo_reproduccion)
			# Tiro con efecto: se corre menos (ver _estirada_corta_curva).
			if dato_v.size() > 5 and float(dato_v[4]) < 1.0:
				var ini: Vector2 = dato_v[5]
				pos = pos.lerp(ini + (pos - ini) * float(dato_v[4]), vuelve)
			# Lo que corre la cadera la estirada, descontado de lo que corre el
			# motor (ver _corregir_cadera_de_vuelo): la del cuadro anterior;
			# después de poner la pose se ajusta con la de este.
			var cv: Dictionary = _cadera_de_vuelo.get(id_v, {})
			if cv.is_empty() or int(cv["desde"]) != int(d0):
				cv = {"desde": int(d0), "c": Vector2.ZERO, "resto": 0.0}
				_cadera_de_vuelo[id_v] = cv
			cv["base"] = pos
			cv["vuelve"] = vuelve * (1.0 - (_peso_atajada() if ataja else 0.0))
			pos += cv["c"] as Vector2
			pos += corto * smoothstep(d0, d0 + 1.2, _tiempo_reproduccion) * vuelve
			p3.position = Vector3(pos.x, p3.position.y, pos.y)
		else:
			_mira_vuela.erase(id_v)
			_cadera_de_vuelo.erase(id_v)
	# Barrera: de frente a la pelota. Oficiales con bandera o tablero: a la cancha.
	if str(ent["tipo"]) == "jugador" and accion == "" and indice >= 0 and indice < _jugadores_cuadro.size():
		var mira_b := _mira_de_barrera(int(_jugadores_cuadro[indice]["id"]), pos)
		if mira_b.length() > 0.1:
			objetivo = atan2(mira_b.x, mira_b.y)
	# Tiro libre y corner: el que patea, adonde va la pelota.
	if str(ent["tipo"]) == "jugador" and indice >= 0 and indice < _jugadores_cuadro.size():
		var mira_p := _mira_de_pateador(int(_jugadores_cuadro[indice]["id"]), pos)
		if mira_p.length() > 0.1:
			objetivo = atan2(mira_p.x, mira_p.y)
	# Mirando a la cámara (a +Z): el de la banda de acá, de frente a la cancha,
	# quedaba de espaldas y no se le veía la bandera.
	if str(ent["tipo"]) == "oficial" and str(ent.get("senal", "")) in \
			["bandera_arriba", "bandera_horizontal", "tarjeta_amarilla", "tarjeta_roja"]:
		objetivo = 0.0
	# El cuarto árbitro, como en la tele, mira a la cancha con el tablero
	# arriba: el tablero tiene los números de los dos lados.
	# Y siempre, sin tablero también: parado en la banda mirando a la cámara
	# parecía que no seguía el partido.
	if str(ent["tipo"]) == "oficial" and str(ent.get("rol_oficial", "")) == OficialesPartido.CUARTO_ARBITRO:
		objetivo = atan2(0.0, -signf(pos.y))
	if not tarjeta_r.is_empty() and _tiempo_reproduccion >= float(tarjeta_r["llega"]):
		objetivo = 0.0
	# Chilena: de espaldas a donde sale la pelota. La dirección del sprite de
	# VistaPartido viene espejada (el 2D da vuelta el dibujo) y el chibi
	# quedaba de costado y se tiraba para el lado contrario.
	if accion == "chilena" and str(ent["tipo"]) == "jugador":
		var g_ch: Dictionary = _gestos.get(indice, {})
		var salida := _salida_del_golpe(int(g_ch.get("desde", -1)))
		if salida.length() < 0.1:
			var rep_ch := get_parent() as VistaPartido
			var foto_ch: Dictionary = rep_ch.fotogramas[mini(int(_tiempo_reproduccion), rep_ch.fotogramas.size() - 1)] \
				if rep_ch != null and not rep_ch.fotogramas.is_empty() else {}
			salida = MotorEspacial.arco_rival_en(foto_ch, bool(ent.get("equipo_local", true))) - pos
		if salida.length() > 0.1:
			objetivo = atan2(-salida.x, -salida.y)
	# Tiro bloqueado: el que patea mira al arco y el defensor, al que patea.
	if rol_bloqueo != "" and peso_bloqueo > 0.0:
		var mira: Vector2 = _bloqueo["arco"] if rol_bloqueo == "tirador" else -_bloqueo["arco"]
		objetivo = lerp_angle(objetivo, atan2(mira.x, mira.y), peso_bloqueo)
	# En un salto de reproducción (el corte del lateral, una reubicación) ya
	# mira para donde tiene que mirar: girar en el lugar delataba el corte.
	# La estirada tampoco gira de a poco: ya en el aire se retorcía 40°.
	var gira_ya := _segundos < 0.0 or accion == MotorEspacial.ACCION_VUELA
	_rumbo[clave] = objetivo if gira_ya else lerp_angle(actual, objetivo, 1.0 - exp(-GIRO_POR_SEGUNDO * delta))
	p3.rotation.y = _rumbo[clave]
	var fase := fase_ent if fase_amague < 0.0 else fase_amague
	# Congelado por el festejo: la acción que venía (la estirada del arquero)
	# se termina igual; el festejo es solo vista, el motor sigue en el gol.
	if _festejo_ticks > 0.0 and ANIM_DE_ACCION.has(accion) and accion != MotorEspacial.ACCION_FESTEJA:
		var motor := str(SAQUE_DE_MANO.find_key(accion)) if SAQUE_DE_MANO.values().has(accion) else accion
		fase = minf(1.0, fase + _festejo_ticks / float(VistaPartido.DURACION_ACCION.get(motor, 1)))
	# Estirada que reacciona tarde (ver _leer_gestos): la misma, corrida. La
	# pelota ya pasó: sin llevar el cuadro de contacto al golpe (en un cuadro
	# saltaba al de contacto y la cadera se corría 0.8 m de golpe).
	var vuelo_tarde := false
	var vuelo_corrido := 0.0
	if accion == MotorEspacial.ACCION_VUELA and indice >= 0 and indice < _jugadores_cuadro.size():
		var dv: Array = _mira_vuela.get(int(_jugadores_cuadro[indice]["id"]), [])
		# El motor graba la estirada en ticks seguidos y cada una la volvía a
		# empezar (la cadera saltaba para atrás): sigue la primera.
		var dur_v := float(VistaPartido.DURACION_ACCION.get(accion, 4))
		var desde_accion := _tiempo_reproduccion - float(ent.get("fase_animacion", 0.0)) * dur_v
		if dv.size() > 1 and desde_accion > float(dv[1]) + 0.01:
			vuelo_corrido = (desde_accion - float(dv[1])) / dur_v
			fase = minf(1.0, fase + vuelo_corrido)
		if dv.size() > 6 and float(dv[6]) > 0.0:
			fase = clampf(fase - float(dv[6]) / float(VistaPartido.DURACION_ACCION.get(accion, 4)), 0.0, 1.0)
			vuelo_tarde = true
	if accion == MotorEspacial.ACCION_VUELA:
		# La altura de la estirada del 2D es sin(fase·π)·0.55. Acá con la fase
		# que sigue en el festejo (congelada, lo dejaba parado en el aire) y
		# baja si el remate va por abajo: con la pelota rodando se tiraba alto
		# y la pelota le pasaba por debajo de la cabeza.
		var alto := 1.0
		if indice >= 0 and indice < _jugadores_cuadro.size() and _mira_vuela.has(int(_jugadores_cuadro[indice]["id"])):
			alto = _altura_del_remate(int(_mira_vuela[int(_jugadores_cuadro[indice]["id"])][1]), int(_jugadores_cuadro[indice]["id"]))
		if id_j >= 0 and not _parada_de(id_j, _tiempo_reproduccion).is_empty():
			alto = 0.0
		p3.position.y = sin(clampf(fase, 0.0, 1.0) * PI) * 0.55 * alto
	# Estirada con agarre: el motor ya pasó al agarre (parado). Sigue la
	# estirada hasta caer y queda tirado (ver _preparar_tendidos).
	var tendido := _tendido_de(id_j, _tiempo_reproduccion) if es_arquero and id_j >= 0 else {}
	# fase_tendido: la de la estirada desde que se tiró; anim_tendido: la de
	# su animación (con el contacto en el golpe, como en la estirada).
	var fase_tendido := -1.0
	var anim_tendido := 1.0
	if not tendido.is_empty():
		fase_tendido = (_tiempo_reproduccion - float(tendido["estirada"])) \
			/ float(VistaPartido.DURACION_ACCION[MotorEspacial.ACCION_VUELA])
		anim_tendido = _fase_con_contacto(clampf(fase_tendido, 0.0, 1.0), float(tendido["contacto"]),
			float(CONTACTO_3D[MotorEspacial.ACCION_VUELA][1]))
		p3.position.y = 0.0
	if not tendido.is_empty() and accion in [MotorEspacial.ACCION_VUELA, MotorEspacial.ACCION_AGARRA, ""]:
		# El salto del 2D se apaga al caer: con la animación ya en el piso
		# quedaba flotando medio metro.
		p3.position.y = sin(clampf(fase_tendido, 0.0, 1.0) * PI) * 0.55 * _altura_del_remate(int(tendido["estirada"]), int(tendido["clave"])) \
			* (1.0 - smoothstep(0.45, ESTIRADA_CAE_FASE, anim_tendido))
	if preparando:
		fase = clampf((_tiempo_reproduccion - (float(lateral["saque"]) - LATERAL_PREPARA_TICKS)) / LATERAL_PREPARA_TICKS, 0.0, 0.999)
	if accion in TENDIDOS and str(ent["tipo"]) == "jugador":
		pos += _separacion_tendido(pos, Vector2(sin(_rumbo[clave]), cos(_rumbo[clave])), fase)
		p3.position = Vector3(pos.x, p3.position.y, pos.y)
	var gesto: Dictionary = _gestos.get(indice, {}) if str(ent["tipo"]) == "jugador" else {}
	# Un gesto anticipado todavía no es la acción del jugador: solo mueve la pelota.
	if not gesto.is_empty() and str(gesto["accion"]) != accion and not bool(gesto.get("anticipado", false)):
		gesto = {}
	if str(ent["tipo"]) == "jugador":
		_pies.append({"pos": pos, "frente": Vector2(sin(_rumbo[clave]), cos(_rumbo[clave])), "id": id_j,
			"accion": accion, "fase": fase, "modelo": p3, "gesto": gesto, "desvio": desvio_regate,
			"terminado": MotorEspacial.es_accion_regate(accion) and fase >= 0.999})
		if preparando:
			_pie_lateral = _pies[-1]

	var pose := str(ent.get("pose", ""))
	# Con lo que se dibuja (el árbitro que corre a la tarjeta lo mueve el 3D).
	_medir_paso(clave, pos)
	var anim := ""
	var tiempo := 0.0
	# La fase del regate (MotorEspacial.fase_regate) llega a 1 antes de que
	# termine la acción: el último tick quedaba congelado en el último cuadro
	# mientras el jugador ya salía. Terminado el gesto, corre (o respira).
	var gesto_terminado := MotorEspacial.es_accion_regate(accion) and fase >= 0.999
	# Recepción: hecho el control (la pelota ya bajó), si sale corriendo corre.
	# La pose del control es de parado: con el recorrido fluido (ver
	# RECEPCIONES_FLUIDAS) se deslizaba controlando a 2.5 m/s.
	if _recepcion_hecha(accion, fase, clave):
		gesto_terminado = true
	if ANIM_DE_ACCION.has(accion) and p3.tiene(ANIM_DE_ACCION[accion]) and not gesto_terminado:
		anim = ANIM_DE_ACCION[accion]
		if anim in ANIM_EN_BUCLE:
			# La fase va de 0 a 1 en toda la acción; el loop se repite adentro.
			var segundos := fase * float(VistaPartido.DURACION_ACCION.get(accion, 1)) * MotorEspacial.TICK_SEG
			tiempo = fposmod(segundos, p3.duracion(anim))
		elif not gesto.is_empty() and str(gesto["accion"]) == accion and not vuelo_tarde:
			# El cuadro de contacto de la animación cae en el golpe del motor.
			var f := _fase_con_contacto(clampf(fase, 0.0, 1.0), minf(float(gesto["fase_contacto"]) + vuelo_corrido, 0.95),
				float(CONTACTO_3D[accion][1]))
			tiempo = f * p3.duracion(anim)
		else:
			tiempo = clampf(fase, 0.0, 1.0) * p3.duracion(anim)
	elif pose in [SpritesPartido.CORRE_A, SpritesPartido.CORRE_B] \
			or float(_odometro[clave][2]) > (ARQUERO_CORRE_MS if es_arquero else VELOCIDAD_PARA_PIERNAS):
		# También por debajo de la velocidad de "corre" del 2D (1.6 m/s): el
		# que salía del regate a 1.5 m/s quedaba en el quieto y deslizaba.
		# Camina, trota o corre según la velocidad (ver _medir_paso); el
		# golero no tiene trote ni caminata y usa Correr.
		anim = str(_odometro[clave][3]) if _odometro[clave].size() > 3 else "Correr"
		if not p3.tiene(anim):
			anim = "Correr"
		# Las piernas van con los metros que recorre el dibujo, medidos acá:
		# el `recorrido` del motor no avanza en las jugadas del Laboratorio y
		# el que salía corriendo después del regate deslizaba con las piernas
		# quietas.
		tiempo = fposmod(float(_odometro[clave][1]) / METROS_POR_CICLO, 1.0) * p3.duracion(anim)
	elif es_arquero:
		anim = "Golero_Guardia"
		tiempo = fposmod(_tiempo, p3.duracion(anim))
	else:
		anim = ANIM_QUIETO
		tiempo = _tiempo_quieto(p3, clave)
	# Con la pelota en las manos, entre el agarre y el saque: la sostiene.
	if es_arquero and accion == "" and id_j >= 0 and _sostiene(id_j) and p3.tiene(ANIM_SOSTIENE):
		anim = ANIM_SOSTIENE
		tiempo = fposmod(_tiempo, p3.duracion(anim))
	# Tiro con efecto: se acomoda antes y le pega con el interno.
	if str(ent["tipo"]) == "jugador" and indice >= 0 and indice < _jugadores_cuadro.size():
		var golpe_e := _efecto_de(int(_jugadores_cuadro[indice]["id"]))
		if golpe_e >= 0:
			if accion == MotorEspacial.ACCION_PATEA and anim == ANIM_DE_ACCION[accion] and p3.tiene(ANIM_REMATE_EFECTO):
				# Misma fracción de la animación: el golpe cae en 4/11 en las dos.
				tiempo *= p3.duracion(ANIM_REMATE_EFECTO) / maxf(p3.duracion(anim), 0.01)
				anim = ANIM_REMATE_EFECTO
			elif accion == "" and p3.tiene(ANIM_EFECTO_ACOMODA) and _odometro.has(clave) \
					and float(_odometro[clave][2]) < EFECTO_ACOMODA_VELOCIDAD_MAX:
				# El motor graba el remate con la pelota ya afuera: el golpe es un
				# tick antes y el gesto arranca otro antes (CoreografiaPartido). Se
				# acomoda hasta ahí y, terminado el remate, no vuelve a acomodarse.
				var arranca := float(golpe_e) - 2.0
				var ta := (_tiempo_reproduccion - (arranca - EFECTO_ACOMODA_TICKS)) * MotorEspacial.TICK_SEG
				if _tiempo_reproduccion > arranca + 0.25:
					ta = -1.0
				if ta >= 0.0 and ta <= p3.duracion(ANIM_EFECTO_ACOMODA):
					anim = ANIM_EFECTO_ACOMODA
					tiempo = ta
	# Hombro con hombro con el rival que lo marca (ver _preparar_forcejeos).
	if anim in ["Correr", "Trotar"] and indice >= 0 and indice < _jugadores_cuadro.size():
		var lado_f := int(_forcejeos.get(int(_jugadores_cuadro[indice]["id"]), [0, 0.0])[0])
		var anim_f := "Forcejear" if lado_f > 0 else "Forcejear_Izq"
		if lado_f != 0 and p3.tiene(anim_f):
			anim = anim_f
			tiempo = fposmod(float(_odometro[clave][1]) / METROS_POR_CICLO, 1.0) * p3.duracion(anim)
	# La pelota suelta que le quedó en los pies: la para (ver _anotar_control_suelto).
	if accion == "" and indice >= 0 and indice < _jugadores_cuadro.size() and p3.tiene(ANIM_DE_ACCION["control_pie"]):
		var ks := float(_controles_sueltos.get(int(_jugadores_cuadro[indice]["id"]), -100.0))
		var tc := (_tiempo_reproduccion - (ks - CONTROL_SUELTO_ANTES_TICKS)) * MotorEspacial.TICK_SEG
		if tc >= 0.0 and tc <= p3.duracion(ANIM_DE_ACCION["control_pie"]):
			anim = ANIM_DE_ACCION["control_pie"]
			tiempo = tc
	# Trabada: le sacó la pelota de cerca a un rival sin acción del motor.
	if accion == "" and indice >= 0 and indice < _jugadores_cuadro.size() and p3.tiene("Quitar"):
		var quite := float(_quites.get(int(_jugadores_cuadro[indice]["id"]), -100.0))
		var tq := (_tiempo_reproduccion - (quite - QUITE_ANTES_TICKS)) * MotorEspacial.TICK_SEG
		if tq >= 0.0 and tq <= p3.duracion("Quitar"):
			anim = "Quitar"
			tiempo = tq
	if not compra.is_empty() and p3.tiene("Quitar"):
		var tq := COMPRA_QUITAR_DESDE_SEG + (_tiempo_reproduccion - float(compra["desde"])) * MotorEspacial.TICK_SEG
		if tq >= 0.0 and tq <= p3.duracion("Quitar"):
			anim = "Quitar"
			tiempo = tq
	if rol_bloqueo == "bloqueador":
		# La pierna llega a la pelota BLOQUEO_VIAJE_TICKS después del remate
		# (el motor graba el bloqueo recién en el tick siguiente).
		var dur := p3.duracion("Bloquear")
		var contacto := float(CONTACTO_3D["bloquea"][1]) * dur
		var t_seg := (_tiempo_reproduccion - (float(_bloqueo["golpe"]) + BLOQUEO_VIAJE_TICKS)) \
			* MotorEspacial.TICK_SEG + contacto
		if t_seg >= 0.0 and t_seg <= dur:
			anim = "Bloquear"
			tiempo = t_seg
		elif t_seg > dur and accion == "bloquea":
			anim = ANIM_QUIETO
			tiempo = _tiempo_quieto(p3, clave)
	# Estirada con agarre: la estirada hasta caer, tirado y se levanta.
	if not tendido.is_empty() and accion in [MotorEspacial.ACCION_AGARRA, ""] and p3.tiene(ANIM_LEVANTA):
		if _tiempo_reproduccion < float(tendido["cae"]):
			anim = ANIM_DE_ACCION[MotorEspacial.ACCION_VUELA]
			tiempo = anim_tendido * p3.duracion(anim)
		else:
			anim = ANIM_LEVANTA_IZQUIERDA if _vuela_a_la_izquierda(indice) else ANIM_LEVANTA
			tiempo = minf(_tiempo_levanta(tendido, _tiempo_reproduccion), p3.duracion(anim))
	# Estirada hacia su izquierda: la animación propia (ver _mira_vuela).
	if anim == ANIM_DE_ACCION.get(MotorEspacial.ACCION_VUELA, "") and _vuela_a_la_izquierda(indice) \
			and p3.tiene(ANIM_VUELA_IZQUIERDA):
		anim = ANIM_VUELA_IZQUIERDA
	# Remate al ángulo: la estirada alta; de frente, ataja parado (abajo, al
	# pecho o arriba) con las manos en la pelota cuando llega (ver _preparar_remates).
	if es_arquero and id_j >= 0:
		var r_v := _remate_de_arquero(id_j, _tiempo_reproduccion)
		if anim.begins_with(ANIM_DE_ACCION[MotorEspacial.ACCION_VUELA]) and str(r_v.get("forma", "")) == "vuela_alta":
			var alta := ANIM_VUELA_ALTA_IZQUIERDA if anim == ANIM_VUELA_IZQUIERDA else ANIM_VUELA_ALTA
			if p3.tiene(alta):
				anim = alta
		var parada := _parada_de(id_j, _tiempo_reproduccion)
		if not parada.is_empty() and accion in [MotorEspacial.ACCION_VUELA, MotorEspacial.ACCION_AGARRA, ""]:
			var anim_p := str({"abajo": ANIM_ATAJA_ABAJO, "arriba": ANIM_ATAJA_ARRIBA}.get(
				str(parada["forma"]), ANIM_DE_ACCION[MotorEspacial.ACCION_AGARRA]))
			var antes := PARADA_CONTACTO_TICKS if anim_p != ANIM_DE_ACCION[MotorEspacial.ACCION_AGARRA] else 0.0
			# El festejo congela la reproducción: el salto se termina igual.
			var tp := (_tiempo_reproduccion + _festejo_ticks - (float(parada["llega"]) - antes)) * MotorEspacial.TICK_SEG
			if tp < -0.1:
				# Hasta ahí, en guardia (el motor ya graba la estirada).
				if accion == MotorEspacial.ACCION_VUELA and p3.tiene("Golero_Guardia"):
					anim = "Golero_Guardia"
					tiempo = fposmod(_tiempo, p3.duracion(anim))
			elif p3.tiene(anim_p) and (tp <= p3.duracion(anim_p) or accion != ""):
				anim = anim_p
				tiempo = clampf(tp, 0.0, p3.duracion(anim_p))
	# Pelota parada: la barrera (y su salto) y el que va a patear el corner.
	if str(ent["tipo"]) == "jugador" and accion == "" and indice >= 0 and indice < _jugadores_cuadro.size():
		var parada := _gesto_de_pelota_parada(int(_jugadores_cuadro[indice]["id"]), p3)
		if not parada.is_empty():
			anim = str(parada["anim"])
			tiempo = float(parada["tiempo"])
	# Oficiales: la señal que manda OficialesPartido (tarjeta, bandera, tablero).
	var senal := str(ent.get("senal", "")) if str(ent["tipo"]) == "oficial" else ""
	var senal_mano := senal
	if not tarjeta_r.is_empty():
		senal = ""
		senal_mano = ""
		var t_tarjeta := (_tiempo_reproduccion - float(tarjeta_r["llega"])) * MotorEspacial.TICK_SEG
		if t_tarjeta >= 0.0 and p3.tiene("Tarjeta_Completa"):
			anim = "Tarjeta_Completa"
			tiempo = t_tarjeta
			if t_tarjeta >= TARJETA_EN_MANO.x and t_tarjeta <= TARJETA_EN_MANO.y:
				senal_mano = "tarjeta_roja" if bool(tarjeta_r["roja"]) else "tarjeta_amarilla"
	var anim_senal := str(ANIM_DE_SENAL.get(senal, ""))
	if anim_senal != "" and p3.tiene(anim_senal):
		anim = anim_senal
		if senal.begins_with("tarjeta_"):
			tiempo = clampf(float(ent.get("fase_senal", 1.0)), 0.0, 1.0) * p3.duracion(anim)
		else:
			tiempo = _tiempo_de_senal(clave, senal, p3.duracion(anim))
	else:
		_senales.erase(clave)
	p3.poner(anim, tiempo, _segundos)
	p3.espejado = _espejo_de_vuelo(ent, clave, pos, accion, rumbo)
	if id_j >= 0 and _cadera_de_vuelo.has(id_j) and _cadera_de_vuelo[id_j].has("base"):
		var ajuste := _corregir_cadera_de_vuelo(id_j, p3)
		pos += ajuste
		p3.position += Vector3(ajuste.x, 0.0, ajuste.y)
		if not _pies.is_empty() and int(_pies[-1]["id"]) == id_j:
			_pies[-1]["pos"] = pos
	if str(ent["tipo"]) == "oficial":
		_poner_utileria(clave, p3, ent, senal_mano)
		if not tarjeta_r.is_empty():
			# La cámara va con el árbitro mientras corre y muestra la tarjeta.
			_foco_oficial = pos
			_foco_zoom = float(ZOOM_DE_SENAL["tarjeta_roja"])
			_foco_prioridad = 3
		# El tablero puede quedar arriba más de 5 s: la cámara lo muestra al
		# principio y vuelve al juego.
		var desde_senal := float(_senales.get(clave, [senal, 0.0, _tiempo_reproduccion])[2])
		# Si hay dos a la vez (un cambio durante un offside) gana la tarjeta,
		# después la bandera y después el tablero.
		if ZOOM_DE_SENAL.has(senal) and _tiempo_reproduccion - desde_senal < FOCO_OFICIAL_MAX_TICKS \
				and int(PRIORIDAD_DE_SENAL.get(senal, 0)) > _foco_prioridad:
			_foco_oficial = pos
			_foco_zoom = float(ZOOM_DE_SENAL[senal])
			_foco_prioridad = int(PRIORIDAD_DE_SENAL.get(senal, 0))
	if rol_bloqueo == "bloqueador":
		_pierna_bloqueo = p3.ancla(str(CONTACTO_3D["bloquea"][0]))
	if ataja:
		var manos := (p3.ancla("Mano_L") + p3.ancla("Mano_R")) * 0.5
		_manos_relativas[clave] = Vector2(manos.x - p3.global_position.x, manos.z - p3.global_position.z)
		_manos_atajada = manos


## Segundo de la animación de una señal que se sostiene (bandera, tablero):
## desde que arrancó, y queda en el último cuadro. En un salto de reproducción
## ya está levantada.
func _tiempo_de_senal(clave: String, senal: String, dur: float) -> float:
	var previa: Array = _senales.get(clave, [])
	if previa.is_empty() or str(previa[0]) != senal:
		# [señal, desde dónde cuenta la animación, cuándo empezó de verdad
		# (para la cámara)].
		var t0 := _tiempo_reproduccion - (100.0 if _segundos < 0.0 else 0.0)
		_senales[clave] = [senal, t0, _tiempo_reproduccion]
		previa = _senales[clave]
	elif _segundos < 0.0:
		previa[2] = _tiempo_reproduccion  # salto (o la muestra que vuelve a empezar)
	return clampf((_tiempo_reproduccion - float(previa[1])) * MotorEspacial.TICK_SEG, 0.0, dur)


## La bandera (asistentes, siempre en la mano derecha), la tarjeta (árbitro,
## mientras la muestra) y el tablero (cuarto árbitro, en los cambios).
func _poner_utileria(clave: String, p3: Jugador3D, ent: Dictionary, senal: String) -> void:
	if not _utileria.has(clave):
		var cosas := {}
		var rol := str(ent.get("rol_oficial", ""))
		if rol.begins_with("asistente"):
			cosas["bandera"] = Utileria3D.bandera()
		elif rol == OficialesPartido.ARBITRO:
			cosas["tarjeta"] = Utileria3D.tarjeta()
		elif rol == OficialesPartido.CUARTO_ARBITRO:
			cosas["tablero"] = Utileria3D.tablero()
		for n in cosas.values():
			_mundo.add_child(n)
		_utileria[clave] = cosas
	var cosas: Dictionary = _utileria[clave]
	var mano := p3.ancla("Mano_R")
	var antebrazo := p3.hueso("Antebrazo.R")
	var frente := p3.global_transform.basis.z.normalized()
	if cosas.has("bandera"):
		var b: Node3D = cosas["bandera"]
		b.visible = p3.visible
		# Levantada, el palo va parado: el brazo del chibi llega a la altura de
		# la cabeza y a lo largo del antebrazo la bandera quedaba de costado.
		var eje_b := antebrazo.basis.y.normalized()
		if senal == "bandera_arriba":
			var alto_mano := (mano.y - p3.global_position.y) / maxf(p3.scale.y, 0.01)
			var sube := clampf((alto_mano - BANDERA_MANO_BAJA_M) / 0.35, 0.0, 1.0)
			eje_b = eje_b.lerp(Vector3.UP, sube * 0.85).normalized()
		b.global_transform = Transform3D(Utileria3D.base_a_lo_largo(eje_b, frente), mano)
	if cosas.has("tarjeta"):
		var t: MeshInstance3D = cosas["tarjeta"]
		t.visible = p3.visible and senal.begins_with("tarjeta_")
		if t.visible:
			Utileria3D.pintar_tarjeta(t, senal == "tarjeta_roja")
			var eje := antebrazo.basis.y.normalized()
			t.global_transform = Transform3D(Utileria3D.base_a_lo_largo(eje, frente), mano + eje * 0.07)
	if cosas.has("tablero"):
		var tb: Node3D = cosas["tablero"]
		tb.visible = p3.visible and senal == "tablero"
		if tb.visible:
			Utileria3D.numeros_tablero(tb, int(ent.get("numero_sale", 0)), int(ent.get("numero_entra", 0)))
			# Arriba de la cabeza, sostenido de los mangos: las manos del chibi
			# llegan a la altura de la cara.
			var mano_l := p3.ancla("Mano_L")
			var mano_r := p3.ancla("Mano_R")
			var base := Basis.looking_at(-frente, Vector3.UP)
			var centro := (mano_l + mano_r) * 0.5 + frente * 0.08 \
				+ Vector3.UP * (Utileria3D.LARGO_MANGO + Utileria3D.TABLERO_TAM.y * 0.5)
			Utileria3D.mangos_tablero(tb, (mano_l - centro).dot(base.x), (mano_r - centro).dot(base.x))
			tb.global_transform = Transform3D(base, centro)


## Elástica: el rival más cercano "compra" el amague. El primer toque va a la
## derecha del que regatea; el defensor se tira a quitarla para ese lado
## (animación Quitar, mirando a donde va la pelota) y cuando la pelota cruza
## ya está jugado. El motor lo corre 3.2 m en un tick hacia ese lado: con el
## recorrido promediado (se lo anota en _regates) se ve como la estirada.
func _registrar_comprador(rep: VistaPartido, ejecutor: int, desde: float, fin: float) -> void:
	var f0: Dictionary = rep.fotogramas[int(desde)]
	var defensor := VistaPartido._defensor_del_regate(f0, ejecutor)
	var je := VistaPartido._jugador_en(f0, ejecutor)
	var jd := VistaPartido._jugador_en(f0, defensor)
	if defensor < 0 or je.is_empty() or jd.is_empty():
		return
	var pe := Vector2(je["x"], je["y"])
	if pe.distance_to(Vector2(jd["x"], jd["y"])) > COMPRA_DISTANCIA_M:
		return
	var frente := Vector2(float(je.get("regate_ox", je.get("ox", 1.0))), float(je.get("regate_oy", je.get("oy", 0.0))))
	frente = frente.normalized() if frente.length() > 0.01 else Vector2.RIGHT
	var amague := elastica_3d(0.4)
	var punto := pe + frente * (amague.x + 0.5) + Vector2(-frente.y, frente.x) * (amague.y + 0.4)
	# Mira fija, calculada desde donde arranca: si se recalcula mientras se
	# tira, al llegar al punto se daba vuelta.
	var mira := punto - Vector2(jd["x"], jd["y"])
	_compradores[defensor] = {"ejecutor": ejecutor, "desde": desde, "fin": fin,
		"mira": mira.normalized() if mira.length() > 0.1 else -frente}
	_regates[defensor] = [desde, fin]


## El que compra el amague, si `id` lo es ahora: {} si no.
func _compra_de(id: int) -> Dictionary:
	if not _compradores.has(id):
		return {}
	var c: Dictionary = _compradores[id]
	var t := _tiempo_reproduccion
	if t < float(c["desde"]) - 0.5 or t > float(c["desde"]) + COMPRA_TICKS:
		if t < float(c["desde"]) - 2.0 or t > float(c["fin"]) + 30.0:
			_compradores.erase(id)
		return {}
	return c


## Regate: el motor mueve al que regatea a los tirones (al terminar la ruleta,
## 1.6 m en un tick y después 0.37 por tick: un pique rarísimo). Mientras
## regatea y un rato después se lo dibuja con su recorrido promediado en una
## ventana de ±REGATE_SUAVIZADO_TICKS. Devuelve cuánto correrlo del motor.
func _desvio_de_regate(indice: int, accion: String, crudo: Vector2) -> Vector2:
	if indice < 0 or indice >= _jugadores_cuadro.size():
		return Vector2.ZERO
	var id := int(_jugadores_cuadro[indice]["id"])
	# Festejo: VistaPartido lleva a los del grupo al banderín con el partido
	# congelado. El suavizado mira los fotogramas (quietos) y los dejaba
	# clavados: el goleador festejaba en el área y corrían dos del montón.
	var rep := get_parent() as VistaPartido
	if rep != null and rep._festejo_restante > 0.0 and rep._festejo_grupo.has(id):
		return _desvio_sin_festejo(indice, accion, crudo) * (1.0 - smoothstep(0.0, FESTEJO_SUELTA_TICKS, _festejo_ticks))
	return _desvio_sin_festejo(indice, accion, crudo)


func _desvio_sin_festejo(indice: int, accion: String, crudo: Vector2) -> Vector2:
	var id := int(_jugadores_cuadro[indice]["id"])
	if not _regates.has(id) or _tiempo_reproduccion > float(_regates[id][1]) + REGATE_SUAVIZADO_DESPUES + 1.5:
		# Sin regate corriendo: la recepción que toque ahora, si hay. La de un
		# centro (3D-09) primero: la de un control anterior dura 16 ticks.
		var ventanas: Array = []
		for w in _recepciones.get(id, []):
			if (w as Array).size() > 6:
				ventanas.append(w)
		ventanas.append_array(_recepciones.get(id, []))
		for w in ventanas:
			if _tiempo_reproduccion >= float(w[0]) and _tiempo_reproduccion <= float(w[1]) + REGATE_SUAVIZADO_DESPUES + 1.5:
				var t_r := _tiempo_reproduccion
				var peso_r := smoothstep(float(w[0]), float(w[0]) + 1.0, t_r) \
					* (1.0 - smoothstep(float(w[1]) + REGATE_SUAVIZADO_DESPUES, float(w[1]) + REGATE_SUAVIZADO_DESPUES + 1.5, t_r))
				# Control con el pie: se lo dibuja un poco adelantado en el tiempo
				# (donde el motor lo pone un instante después, ya arrancando). El
				# adelanto entra con el control y se devuelve de a poco corriendo.
				var k_r := float(w[2])
				var vuelve_r := float(w[4])
				var adelanto: float = float(w[3]) * smoothstep(k_r - 1.5, k_r + 0.5, t_r) \
					* (1.0 - smoothstep(k_r + 2.0, vuelve_r, t_r))
				var t_motor := t_r + adelanto
				if (w as Array).size() > 6:
					t_motor = _tiempo_del_centro(w[6], t_r)
				return (_recorrido_promediado(id, t_motor, RECEPCION_SUAVIZADO_TICKS, float(w[5])) - crudo) * peso_r
		if not _regates.has(id):
			return Vector2.ZERO
	var r: Array = _regates[id]
	var t := _tiempo_reproduccion
	var desde := float(r[0])
	var fin := float(r[1])
	var corte := _corte_de_elastica(r, t)
	if t < desde or t > fin + REGATE_SUAVIZADO_DESPUES + 1.5:
		if t < desde - 1.0 or t > fin + REGATE_SUAVIZADO_DESPUES + 30.0:
			_regates.erase(id)
		return corte
	var peso := smoothstep(desde, desde + 0.5, t) \
		* (1.0 - smoothstep(fin + REGATE_SUAVIZADO_DESPUES, fin + REGATE_SUAVIZADO_DESPUES + 1.5, t))
	if peso <= 0.0:
		return corte
	return (_recorrido_promediado(id, t) - crudo) * peso + corte


## Elástica: después de cruzar la pelota (fase 0.6) sale en diagonal para el
## lado de la pelota, lejos del defensor que compró el amague, y sigue derecho
## corrido ese tanto. El motor la hace en línea recta. El corrimiento se
## devuelve de a poco mucho después, mientras corre (no se nota).
func _corte_de_elastica(r: Array, t: float) -> Vector2:
	if r.size() < 4 or str(r[2]) != "regate_elastica":
		return Vector2.ZERO
	var desde := float(r[0])
	var frente: Vector2 = r[3]
	var izquierda := Vector2(frente.y, -frente.x)
	var sale := smoothstep(desde + CORTE_DESDE_TICKS, desde + CORTE_HASTA_TICKS, t)
	var vuelve := 1.0 - smoothstep(desde + CORTE_VUELVE_TICKS, desde + CORTE_VUELVE_TICKS + 10.0, t)
	return izquierda * CORTE_ELASTICA_M * sale * vuelve


## Promedio del recorrido del motor de `id` entre t-w y t+w. La ventana se
## achica pareja contra un corte de jugada, así en el borde da la posición
## del motor tal cual (no salta).
func _recorrido_promediado(id: int, t: float, w: float = REGATE_SUAVIZADO_TICKS, tope: float = INF) -> Vector2:
	var rep := get_parent() as VistaPartido
	var fotos: Array = rep.fotogramas
	var idx := mini(int(t), fotos.size() - 1)
	var minimo := t - w
	for k in range(idx, maxi(-1, idx - int(ceil(w)) - 1), -1):
		if VistaPartido._es_reubicacion(fotos[k]):
			minimo = maxf(minimo, float(k))
			break
	var maximo := minf(minf(t + w, float(fotos.size() - 1)), tope)
	for k in range(idx + 1, mini(fotos.size(), idx + int(ceil(w)) + 2)):
		if VistaPartido._es_reubicacion(fotos[k]):
			maximo = minf(maximo, float(k - 1))
			break
	var w_util := maxf(0.0, minf(w, minf(t - minimo, maximo - t)))
	var suma := Vector2.ZERO
	var n := 0
	for i in 9:
		var tau := t + w_util * (float(i) / 4.0 - 1.0)
		var k0 := mini(int(tau), fotos.size() - 1)
		var k1 := mini(k0 + 1, fotos.size() - 1)
		var j0 := VistaPartido._jugador_en(fotos[k0], id)
		var j1 := VistaPartido._jugador_en(fotos[k1], id)
		if j0.is_empty():
			continue
		if j1.is_empty() or VistaPartido._es_reubicacion(fotos[k1]):
			j1 = j0
		suma += Vector2(j0["x"], j0["y"]).lerp(Vector2(j1["x"], j1["y"]), tau - float(k0))
		n += 1
	return suma / float(n) if n > 0 else Vector2.ZERO


## Odómetro propio de la vista, cada cuadro: metros que caminó esta persona
## y su velocidad (m/s de partido, suavizada). En un salto de reproducción no
## suma: el salto no es un paso. Arranca en un punto distinto para cada uno,
## así no pisan todos con el mismo pie.
func _medir_paso(clave: String, pos: Vector2) -> void:
	if not _odometro.has(clave):
		_odometro[clave] = [pos, float(absi(hash(clave)) % 1000) / 1000.0 * METROS_POR_CICLO, 0.0, "Correr", 0.0]
	var dato: Array = _odometro[clave]
	var paso := (pos - (dato[0] as Vector2)).length()
	if _segundos > 0.0 and paso < 3.0:
		dato[2] = lerpf(float(dato[2]), paso / _segundos, 1.0 - exp(-8.0 * _segundos))
		# El andar sale de una velocidad más lenta: la del motor salta de tick
		# a tick y cambiaba de caminar a trotar varias veces por segundo.
		dato[4] = lerpf(float(dato[4]), paso / _segundos, 1.0 - exp(-ANDAR_SUAVIZADO * _segundos))
		dato[3] = _andar(str(dato[3]), float(dato[4]))
		# Despacio da pasos cortos: con la zancada del pique (3.2 m) a 1.5 m/s
		# las piernas iban en cámara lenta. Se suma en "metros de pique" para
		# que el ciclo de la animación siga siendo METROS_POR_CICLO: la fase es
		# la misma al pasar de caminar a trotar o a correr (no cambia de pie).
		# Cada uno con su zancada, un poco distinta: todos iguales parecían
		# marchando.
		var propia := 0.92 + 0.16 * float(absi(hash(clave + "z")) % 100) / 100.0
		var zancada := clampf(float(dato[2]) * 0.55, 1.3, METROS_POR_CICLO)
		if str(dato[3]) == "Caminar":
			zancada = CICLO_CAMINAR_M
		elif str(dato[3]) == "Trotar":
			zancada = CICLO_TROTAR_M
		dato[1] = float(dato[1]) + paso * METROS_POR_CICLO / (zancada * propia)
	elif _segundos < 0.0:
		dato[2] = 0.0
	dato[0] = pos


## Camina, trota o corre, con margen para no cambiar a cada rato cerca del
## límite.
static func _andar(actual: String, velocidad: float) -> String:
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


## Segundo del loop de respiración de esta persona. Cada una arranca en otro
## punto del loop (sale de su clave): todos respirando juntos parecía un coro.
func _tiempo_quieto(p3: Jugador3D, clave: String) -> float:
	var dur := p3.duracion(ANIM_QUIETO)
	if dur <= 0.0:
		return 0.0
	var desfase := float(absi(hash(clave)) % 1000) / 1000.0 * dur
	return fposmod(_tiempo + desfase, dur)


## Separa a los que se enciman. Cada par más cerca que SEPARACION_CUERPOS_M
## se empuja por mitades, unas pasadas (en un montón, el del medio se abre
## con los dos). El dibujo va hacia ese corrimiento con suavizado. Solo
## cambia dónde se dibuja: el motor, la pelota y el 2D no se enteran.
func _separar_cuerpos() -> void:
	var claves := []
	var puntos := []
	var indice := 0
	for ent in entidades:
		var tipo := str(ent.get("tipo", ""))
		if tipo != "jugador" and tipo != "oficial":
			continue
		claves.append(_clave(ent, indice))
		puntos.append(ent["pos"])
		indice += 1
	var desvio := []
	desvio.resize(puntos.size())
	desvio.fill(Vector2.ZERO)
	for _pasada in 4:
		var hubo := false
		for a in puntos.size():
			for b in range(a + 1, puntos.size()):
				var pa: Vector2 = puntos[a] + desvio[a]
				var pb: Vector2 = puntos[b] + desvio[b]
				var d := pa - pb
				var largo := d.length()
				if largo >= SEPARACION_CUERPOS_M:
					continue
				# Apilados en el mismo punto: una dirección fija por par, así
				# no tiemblan de un cuadro al otro.
				var hacia := d / largo if largo > 0.01 else Vector2.RIGHT.rotated(float(a * 7 + b * 13))
				var empuje := hacia * (SEPARACION_CUERPOS_M - largo) * 0.5
				desvio[a] += empuje
				desvio[b] -= empuje
				hubo = true
		if not hubo:
			break
	# En segundos de PARTIDO: a x16 los jugadores se acercan 16 veces más
	# rápido y el corrimiento tiene que seguirlos igual.
	var suave := 1.0 if _segundos < 0.0 else 1.0 - exp(-SUAVIZADO_CUERPOS * _segundos)
	var nuevos := {}
	for i in claves.size():
		var previo: Vector2 = _desvio_cuerpo.get(claves[i], desvio[i])
		nuevos[claves[i]] = previo.lerp(desvio[i], suave)
	_desvio_cuerpo = nuevos


## Cuánto correr al tendido para no quedar encima de nadie. Entra mientras
## cae y sale mientras se levanta, así no salta al empezar ni al terminar.
func _separacion_tendido(pos: Vector2, frente: Vector2, fase: float) -> Vector2:
	var peso := smoothstep(0.0, 0.3, fase) * (1.0 - smoothstep(0.8, 1.0, fase))
	if peso <= 0.0:
		return Vector2.ZERO
	var empuje := Vector2.ZERO
	var puntos := [pos, pos + frente * CENTRO_TENDIDO_M]
	for otro in _posiciones:
		var q: Vector2 = otro
		if q.distance_to(pos) < 0.01:
			continue  # él mismo
		for punto in puntos:
			var d: Vector2 = punto - q
			if d.length() < SEPARACION_TENDIDO_M:
				var hacia := d.normalized() if d.length() > 0.01 else -frente
				empuje += hacia * (SEPARACION_TENDIDO_M - d.length())
	return empuje.limit_length(SEPARACION_TENDIDO_M * 1.5) * peso


## Corriendo, el rumbo sale del movimiento real (continuo). Quieto o en una
## acción, de la dirección que eligió VistaPartido, que en las acciones mira
## a la pelota o al contacto.
## Recepción (control con el pie o pecho) con la pelota ya bajada y el que la
## recibió saliendo: deja la pose del control y corre para donde va.
func _recepcion_hecha(accion: String, fase: float, clave: String) -> bool:
	var lista := CONTROL_LISTA_FASE if accion == "control_pie" else RECEPCION_LISTA_FASE
	return accion in RECEPCIONES_FLUIDAS and fase >= lista and _odometro.has(clave) \
		and float(_odometro[clave][2]) > VELOCIDAD_PARA_PIERNAS


func _rumbo_de(ent: Dictionary, clave: String, pos: Vector2, delta: float, accion: String) -> Vector2:
	var rumbo := Vector2.ZERO
	if _pos_previa.has(clave) and accion.is_empty() and delta > 0.0:
		var vel: Vector2 = (pos - _pos_previa[clave]) / delta
		if vel.length() > VELOCIDAD_PARA_RUMBO:
			rumbo = vel
	_pos_previa[clave] = pos
	if rumbo == Vector2.ZERO:
		rumbo = _direccion_a_cancha(int(ent.get("direccion", SpritesPartido.ABAJO)))
	return rumbo.normalized()


## Las 8 direcciones de los sprites están en PANTALLA (ver
## SpritesPartido.direccion_desde). Se deshace la proyección oblicua para
## volver a un rumbo en la cancha.
static func _direccion_a_cancha(direccion: int) -> Vector2:
	var angulo := float(2 - direccion) * PI / 4.0
	var en_pantalla := Vector2(cos(angulo), sin(angulo))
	var dy := en_pantalla.y / ProyeccionPartido.COMPRESION_Y
	var dx := en_pantalla.x - dy * ProyeccionPartido.SHEAR_X
	return Vector2(dx, dy).normalized()


## La estirada corre la cadera 0.98 m al costado y el motor, que lo lleva
## hacia la pelota, también: se sumaban y el arquero volaba el doble. La
## cadera va a lo que corra más de los dos (lo del motor que la estirada ya
## cubre se descuenta). Terminada la estirada se queda donde cayó (sin eso,
## al pararse volvía de golpe lo que había corrido la animación) y se va
## juntando con el motor mientras se levanta. Se mide con la pose ya puesta:
## devuelve cuánto hay que mover el modelo además de lo que ya se le sumó.
func _corregir_cadera_de_vuelo(id: int, p3: Jugador3D) -> Vector2:
	var cv: Dictionary = _cadera_de_vuelo[id]
	var dato_v: Array = _mira_vuela.get(id, [])
	var base: Vector2 = cv["base"]
	cv.erase("base")
	if dato_v.size() < 6:
		return Vector2.ZERO
	var frente: Vector2 = dato_v[0]
	var lado := Vector2(-frente.y, frente.x) * (-1.0 if bool(dato_v[3]) else 1.0)
	var e := (base - (dato_v[5] as Vector2)).dot(lado)
	var a := p3.corrimiento_cadera().dot(lado)
	var c := 0.0
	if p3._anim_actual.begins_with(ANIM_DE_ACCION[MotorEspacial.ACCION_VUELA]):
		c = -maxf(0.0, minf(e, a))
		cv["resto"] = a + c
	else:
		c = float(cv["resto"]) - a
	var nueva := lado * c * float(cv["vuelve"])
	var ajuste := nueva - (cv["c"] as Vector2)
	cv["c"] = nueva
	return ajuste


## Atajar_Volando se tira hacia la DERECHA del arquero. El lado se decide
## una sola vez, al empezar el vuelo, mirando dónde está la pelota.
func _vuela_a_la_izquierda(indice: int) -> bool:
	if indice < 0 or indice >= _jugadores_cuadro.size():
		return false
	var dato: Array = _mira_vuela.get(int(_jugadores_cuadro[indice]["id"]), [])
	return dato.size() > 3 and bool(dato[3])


func _espejo_de_vuelo(ent: Dictionary, clave: String, pos: Vector2, accion: String, rumbo: Vector2) -> bool:
	# Con las dos estiradas en el GLB ya no se espeja el modelo.
	var p3: Jugador3D = _personas.get(clave)
	if p3 != null and p3.tiene(ANIM_VUELA_IZQUIERDA):
		return false
	if accion != MotorEspacial.ACCION_VUELA:
		_lado_vuelo.erase(clave)
		return false
	if not _lado_vuelo.has(clave):
		var pelota := pos
		for e in entidades:
			if str(e.get("tipo", "")) == "pelota":
				pelota = e["pos"]
				break
		# Derecha del modelo: mira a +Z y su derecha es -X (el GLB viene de
		# Blender mirando a -Y con la derecha en -X).
		var th := atan2(rumbo.x, rumbo.y)
		var derecha := Vector2(-cos(th), sin(th))
		_lado_vuelo[clave] = (pelota - pos).dot(derecha) < 0.0
	return _lado_vuelo[clave]


func _actualizar_pelota(ent: Dictionary) -> void:
	var pos: Vector2 = ent["pos"]
	var radio := RADIO_PELOTA * ESCALA_PELOTA
	# Remate con efecto: por la curva del motor, no por rectas entre ticks.
	var curva := _pelota_en_curva()
	if curva != Vector3.INF and Vector2(curva.x, curva.z).distance_to(pos) < 2.5:
		pos = Vector2(curva.x, curva.z)
	else:
		curva = Vector3.INF
	var cercano := _pie_mas_cercano(pos)
	# El que regatea se dibuja con el recorrido suavizado: la pelota que lleva
	# se corre lo mismo, si no se le despegaba del pie.
	# El desvío de la pelota va hacia el de ese pie con velocidad tope: al
	# salir un pase desde una recepción suavizada (o al cambiar el pie más
	# cercano) se cortaba en seco y la pelota saltaba 2.8 m en un cuadro.
	var desvio_obj := Vector2.ZERO
	if not cercano.is_empty() and (cercano["desvio"] as Vector2) != Vector2.ZERO:
		var crudo: Vector2 = (cercano["pos"] as Vector2) - (cercano["desvio"] as Vector2)
		if crudo.distance_to(pos) < 2.0:
			desvio_obj = cercano["desvio"]
	var sin_desvio := pos
	# Regates: el recorrido de VistaPartido._trayectoria_regate está pensado
	# para el sprite de 1.8 m (la elástica la saca 0.85 m al costado). El
	# chibi mide ESCALA_CHIBI de eso y el pie no llegaba: pelota-pie promedio
	# 0.39 m en la elástica. Se achica igual que el cuerpo; la altura no.
	var terminado := false
	if not cercano.is_empty() and MotorEspacial.es_accion_regate(str(cercano["accion"])):
		var centro: Vector2 = cercano["pos"]
		if centro.distance_to(pos + desvio_obj) < 3.0:
			terminado = bool(cercano["terminado"])
			if terminado:
				# Terminado el gesto el 2D la deja donde terminó su recorrido (en
				# la elástica, 1 m adelante) hasta que el motor cierra la acción.
				# La lleva el pie: se conduce desde donde estaba, sin salto.
				if not _regate_terminado and _pelota_previa != Vector3.INF:
					_conduccion = Vector2(_pelota_previa.x, _pelota_previa.z) - centro
				# Va al pie por el mismo desvío suave (abajo): soltarla a los 3 m
				# de golpe, en el pase de salida, la hacía saltar 2.8 m.
				desvio_obj = centro - sin_desvio
			elif str(cercano["accion"]) == "regate_elastica":
				# La del 2D (0.85 m al costado, ida y vuelta) no la alcanzaba el pie
				# y no se leía: la del 3D sale afuera y cruza al otro lado.
				var frente: Vector2 = cercano["frente"]
				var o := elastica_3d(float(cercano["fase"]))
				pos = centro + frente * o.x + Vector2(-frente.y, frente.x) * o.y - desvio_obj
			else:
				pos = centro + (pos + desvio_obj - centro) * Jugador3D.ESCALA_CHIBI - desvio_obj
	# Sigue al instante lo que el desvío cambia de a poco (el regate, el pie
	# que se mueve) y suaviza solo los saltos (se suelta el pie, cambia de pie).
	# Con el regate terminado la toma al instante: la continuidad la da
	# _conduccion (arriba); suave, la pelota quedaba hasta 1 m atrás del pie.
	if _segundos < 0.0 or terminado:
		_desvio_pelota = desvio_obj
	else:
		var cambio := desvio_obj - _desvio_objetivo_previo
		if cambio.length() < DESVIO_PELOTA_SALTO_M:
			_desvio_pelota += cambio
		_desvio_pelota = _desvio_pelota.move_toward(desvio_obj, DESVIO_PELOTA_VELOCIDAD * _segundos)
	_desvio_objetivo_previo = desvio_obj
	pos += _desvio_pelota
	var nueva := Vector3(pos.x, _altura_3d(float(ent.get("z", 0.0))) + radio, pos.y)
	if curva != Vector3.INF:
		nueva.y = maxf(nueva.y, curva.y + radio)
	var en_barrera := _pelota_en_barrera()
	if en_barrera != Vector2.INF:
		nueva = Vector3(en_barrera.x, nueva.y, en_barrera.y)
	var z_libre := _altura_tiro_libre(Vector2(nueva.x, nueva.z))
	if z_libre >= 0.0:
		nueva.y = maxf(nueva.y, z_libre + radio)
	# Ya pateado el tiro libre, la pelota va por su vuelo: la corrección del
	# golpe (que la lleva al pie) la retenía y llegaba a la barrera por el piso.
	var vuela_libre := z_libre >= 0.0 and _tiempo_reproduccion > _tiro_libre_golpe + 0.05
	# El que prepara el lateral la tiene en las manos aunque VistaPartido no la
	# marque `anclada`: con el contacto ya planificado la deja a la altura del
	# sprite (2.4 m, arriba de la cabeza) y al lanzar saltaba 1.7 m a las manos.
	var agarrada := not cercano.is_empty() and ANCLA_DE_ACCION.has(str(cercano["accion"])) \
		and (cercano["pos"] as Vector2).distance_to(pos) < 2.0
	# Lateral cortado: la pelota del motor todavía está en las manos del que
	# viene caminando (a metros de la línea); va a las del que ya está ahí.
	if not _pie_lateral.is_empty():
		cercano = _pie_lateral
		agarrada = true
	# El arquero que la agarró la tiene en las manos hasta el saque (el motor
	# la deja en sus pies).
	var sostiene := _pie_que_sostiene()
	if not agarrada and not sostiene.is_empty():
		cercano = sostiene
		agarrada = true
	var contacto := _mejor_contacto(pos)
	var corrimiento := Vector2.ZERO
	if not agarrada and float(contacto["peso"]) <= 0.0 \
			and float(ent.get("z", 0.0)) < CONDUCE_ALTURA_M and not cercano.is_empty() \
			and (str(cercano["accion"]) in ["", "amague_centro"] or bool(cercano.get("terminado", false))):
		# Durante una acción (regate, taco, control) la pelota ya trae su
		# recorrido de VistaPartido: correrla al pie la despegaba del gesto.
		# El amague es un gesto sin toque: la pelota sigue adelante del pie.
		# Terminado el gesto del regate (el motor todavía no cerró la acción)
		# ya conduce: si no, después del globito quedaba debajo del cuerpo.
		corrimiento = _corrimiento_al_pie(pos, cercano)
	# Hacia el corrimiento con velocidad tope: al terminar un regate saltaba
	# 0.36 m adelante del pie en un cuadro.
	if _segundos < 0.0:
		_conduccion = corrimiento
	else:
		_conduccion = _conduccion.move_toward(corrimiento, CONDUCCION_VELOCIDAD * _segundos)
	nueva += Vector3(_conduccion.x, 0.0, _conduccion.y)
	_regate_terminado = terminado
	# Agarres y contactos se miden desde la pelota ya corrida: lo que quede
	# del corrimiento mientras se apaga lo compensa la corrección.
	var deseada := Vector3.ZERO
	var fija := false
	if agarrada:
		# El desvío ES el agarre: al pasar al saque o soltarla no hay salto.
		deseada = _pelota_en_ancla(cercano, radio) - nueva
		fija = true
	elif float(contacto["peso"]) > 0.0:
		deseada = (_punto_de_contacto(contacto["pie"], radio) - nueva) * float(contacto["peso"])
		# Antes de soltar el lateral la pelota sigue agarrada: sin transición.
		var g: Dictionary = contacto["pie"]["gesto"]
		fija = str(g["accion"]) in SUELTA_DE_MANOS and float(g["dt"]) <= 0.0
		# Agarrada, va con las manos: en la segunda mitad del agarre la pelota
		# del 2D desaparece y la de reemplazo (en el piso) la hacía bajar.
		fija = fija or (str(g["accion"]) == MotorEspacial.ACCION_AGARRA and float(g["dt"]) >= 0.0)
	if vuela_libre:
		deseada = Vector3.ZERO
		fija = true
	var armada := _pelota_del_bloqueo(radio, nueva)
	if armada == Vector3.INF:
		armada = _pelota_de_la_atajada(radio)
	if armada != Vector3.INF:
		deseada = armada - nueva
		fija = true
	var segundos := _segundos
	if segundos < 0.0 or fija:
		_correccion = deseada  # salto de reproducción o pelota agarrada
	else:
		# Soltarla (después del golpe) más despacio que tomarla: a 16 m/s se
		# sumaba a la del pase y la pelota salía a ~50 m/s dos o tres cuadros.
		var suelta := deseada.length() < _correccion.length()
		_correccion = _correccion.move_toward(deseada, (VELOCIDAD_SUELTA if suelta else VELOCIDAD_CORRECCION) * segundos)
	nueva += _correccion
	nueva.y = maxf(nueva.y, radio)
	# Remate al arco: llega a su altura (ver _preparar_remates).
	var del_remate := _pelota_del_remate(nueva, radio)
	if del_remate != Vector3.INF:
		nueva = del_remate
	# Remate al palo: va al marco y rebota (la estirada que no llega no la
	# desvía a los guantes).
	var al_palo := _pelota_en_palo(nueva, radio)
	if al_palo != Vector3.INF:
		nueva = al_palo
	# Centro bajado de pecho: en el aire hasta el pecho (ver _preparar_centros).
	var del_centro := _pelota_del_centro(nueva, radio)
	if del_centro != Vector3.INF:
		nueva = del_centro
	# Pelota alta que cae suelta: pica y rueda (ver _preparar_piques).
	var con_pique := _pelota_con_pique(nueva, radio)
	if con_pique != Vector3.INF:
		nueva = con_pique
	if _pelota_previa != Vector3.INF:
		var paso := nueva - _pelota_previa
		paso.y = 0.0
		# Rueda sin patinar: gira lo que avanzó dividido el radio dibujado.
		if paso.length() > 0.001 and paso.length() < 5.0:
			_pelota.rotate(Vector3.UP.cross(paso).normalized(), paso.length() / radio)
	_pelota_previa = nueva
	_pelota.position = nueva


## Altura de la pelota. La del reproductor, salvo en el control con el pie:
## la coreografía del 2D la lleva al pie del SPRITE (13 px, ~0.55 m) y sube
## el vuelo que llega hasta ahí. En el chibi eso es el pecho: la pelota
## llegaba a la altura del pecho y parecía un control de pecho. Ahí va la
## altura del motor, que la trae al piso.
func _altura_3d(z: float) -> float:
	var rep := get_parent() as VistaPartido
	if rep == null or rep.fotogramas.is_empty():
		return z
	var coreo := rep._coreografia
	var tiempo := _tiempo_reproduccion
	var idx := mini(int(tiempo), rep.fotogramas.size() - 1)
	var rige := {}
	# El contacto que está corriendo o, si no hay, el próximo del vuelo.
	for k in range(idx, maxi(-1, idx - 8), -1):
		var c: Dictionary = coreo.contactos.get(k, {})
		if not c.is_empty():
			if tiempo < float(c["fin"]):
				rige = c
			break
	if rige.is_empty():
		for k in range(idx + 1, mini(rep.fotogramas.size(), idx + 33)):
			if coreo._hay_corte(k - 1, k):
				break
			if coreo.contactos.has(k):
				rige = coreo.contactos[k]
				break
	if rige.is_empty() or str(rige["accion"]) != "control_pie":
		return z
	var a: Dictionary = rep.fotogramas[idx]["pelota"]
	var t := tiempo - float(idx)
	if idx + 1 >= rep.fotogramas.size() or coreo._hay_corte(idx, idx + 1):
		return float(a.get("z", 0.0))
	var b: Dictionary = rep.fotogramas[idx + 1]["pelota"]
	return lerpf(float(a.get("z", 0.0)), float(b.get("z", 0.0)), t)


## Atajada: del golpe al agarre la pelota va en línea recta del pie a las
## manos del arquero (que se corrió a la línea del tiro). INF fuera de eso;
## después la retiene el agarre de siempre.
func _pelota_de_la_atajada(radio: float) -> Vector3:
	if _atajada.is_empty() or _manos_atajada == Vector3.INF:
		return Vector3.INF
	var g := float(_atajada["golpe"])
	var c := float(_atajada["agarre"])
	var t := _tiempo_reproduccion
	if t < g or t >= c:
		return Vector3.INF
	var origen: Vector2 = _atajada["origen"]
	var punto: Vector2 = _atajada["punto"]
	var desde := Vector3(origen.x, radio, origen.y)
	# Altura fija: la de las manos al agarrar. Con la de cada cuadro la pelota
	# subía y bajaba siguiendo los brazos de la estirada.
	var hasta := Vector3(punto.x, maxf(ALTURA_MANOS_ATAJADA_M, radio), punto.y)
	var bola := desde.lerp(hasta, (t - g) / (c - g))
	# Con el remate elegido (ver _preparar_remates), a su altura: la de las manos.
	var r := _remate_de_arquero(int(_atajada["arquero"]), c)
	if not r.is_empty():
		bola.y = _alto_de_remate(r, t, radio)
	return bola


## Tiro bloqueado: la pelota sale del pie hacia el arco, pega en la pierna
## del defensor y se va juntando con el rebote del motor (`base`). INF
## fuera de esos instantes.
func _pelota_del_bloqueo(radio: float, base: Vector3) -> Vector3:
	if _bloqueo.is_empty() or _pierna_bloqueo == Vector3.INF:
		return Vector3.INF
	var g := float(_bloqueo["golpe"])
	var t := _tiempo_reproduccion
	var golpe_pierna := g + BLOQUEO_VIAJE_TICKS
	if t < g or t >= golpe_pierna + BLOQUEO_REBOTE_TICKS:
		return Vector3.INF
	# Del lado del que patea: la pelota toca la pierna, no la atraviesa.
	var arco: Vector2 = _bloqueo["arco"]
	var pierna := _pierna_bloqueo - Vector3(arco.x, 0.0, arco.y) * radio
	pierna.y = maxf(pierna.y, radio)
	if t < golpe_pierna:
		_rebote_desfase = Vector3.INF
		var bola: Vector2 = _bloqueo["pelota"]
		return Vector3(bola.x, radio, bola.y).lerp(pierna, (t - g) / BLOQUEO_VIAJE_TICKS)
	# El rebote sale de la pierna con la velocidad del motor: el desfase entre
	# la pierna y la pelota del motor en el golpe se va apagando (mezclar
	# hacia la pelota del motor, que ya viaja rápido, la hacía pegar saltos).
	if _rebote_desfase == Vector3.INF:
		_rebote_desfase = pierna - base
	return base + _rebote_desfase * (1.0 - smoothstep(0.0, 1.0, (t - golpe_pierna) / BLOQUEO_REBOTE_TICKS))


## Cuánto hay que llevar la pelota al punto de contacto (0..1) y de quién.
## Golpe: 1 en el instante del golpe, 0 a VENTANA_CONTACTO_TICKS antes y
## después. Recepción: sube hasta el contacto y queda en 1 hasta el final.
## Lateral: la pelota está en las manos hasta que la suelta.
func _mejor_contacto(pelota: Vector2) -> Dictionary:
	var mejor := {"peso": 0.0, "pie": {}}
	for pie in _pies:
		var g: Dictionary = pie["gesto"]
		if g.is_empty() or bool(g.get("sin_toque", false)):
			continue
		# Un gesto lejos de la pelota es de otra jugada: no la arrastra.
		if (pie["pos"] as Vector2).distance_to(pelota) > 6.0:
			continue
		var accion := str(g["accion"])
		var dt := float(g["dt"])
		var ventana := float(VENTANA_POR_ACCION.get(accion, VENTANA_CONTACTO_TICKS))
		var peso := 0.0
		if accion in RECEPCION_3D:
			peso = 1.0 if dt >= 0.0 else 1.0 - smoothstep(0.0, ventana, -dt)
		elif accion in SUELTA_DE_MANOS:
			peso = 1.0 if dt <= 0.0 else 1.0 - smoothstep(0.0, ventana, dt)
		else:
			peso = 1.0 - smoothstep(0.0, ventana, absf(dt))
		if peso > float(mejor["peso"]):
			mejor = {"peso": peso, "pie": pie}
	return mejor


## Dónde tiene que estar el centro de la pelota para tocar el punto del
## cuerpo: un radio hacia adelante (hacia atrás en el taco). En pecho y
## control baja al pie a medida que avanza la acción: termina donde la deja
## la conducción (PELOTA_DELANTE_M), así no salta al soltarla.
func _punto_de_contacto(pie: Dictionary, radio: float) -> Vector3:
	var g: Dictionary = pie["gesto"]
	var accion := str(g["accion"])
	var modelo: Jugador3D = pie["modelo"]
	var frente := Vector3(pie["frente"].x, 0.0, pie["frente"].y)
	var nombre := str(CONTACTO_3D[accion][0])
	var p: Vector3
	if nombre == "manos":
		p = (modelo.ancla("Mano_L") + modelo.ancla("Mano_R")) * 0.5
	else:
		p = modelo.ancla(nombre)
	var c := p + frente * (-radio if accion == "taco" else radio)
	if accion == VOLEO_ARQUERO:
		# En las manos hasta que la suelta; después cae (acelerando) hasta el pie.
		var golpe := float(CONTACTO_3D[accion][1])
		var fa := _fase_con_contacto(clampf(float(pie["fase"]), 0.0, 1.0), float(g["fase_contacto"]), golpe)
		var manos := (modelo.ancla("Mano_L") + modelo.ancla("Mano_R")) * 0.5 + frente * radio
		var u := clampf((fa - VOLEO_SUELTA) / (golpe - VOLEO_SUELTA), 0.0, 1.0)
		c = manos.lerp(c, u * u)
	if accion in CONTACTO_PISO:
		c.y = maxf(c.y, radio)
	if accion in ["pecho", "control_pie"]:
		var fc := float(g["fase_contacto"])
		var avance := clampf((float(pie["fase"]) - fc) / maxf(1.0 - fc, 0.001), 0.0, 1.0)
		var piso := Vector3(pie["pos"].x, radio, pie["pos"].y) + frente * PELOTA_DELANTE_M
		# Primero amortigua pegada al cuerpo; recién después se acomoda para
		# conducir. En el pecho baja más tarde: se ve el pecho frenándola.
		c = c.lerp(piso, smoothstep(0.35 if accion == "pecho" else 0.45, 0.95, avance))
	return c


## Segundos de partido desde el cuadro anterior (con x2, x4... avanzan más).
## -1 si la reproducción saltó o volvió atrás.
func _segundos_de_partido() -> float:
	var rep := get_parent() as VistaPartido
	if rep == null:
		return -1.0
	var d := rep.posicion - _posicion_previa
	var idx := mini(int(rep.posicion), rep.fotogramas.size() - 1)
	var idx_previo := int(_posicion_previa)
	_posicion_previa = rep.posicion
	if d < 0.0 or d > 2.0:
		return -1.0
	# Reubicación (saque del medio, cambio de jugada): la cancha cambia de
	# golpe y el desvío de la jugada anterior no tiene que arrastrarse.
	if idx != idx_previo and idx >= 0 and VistaPartido._es_reubicacion(rep.fotogramas[idx]):
		return -1.0
	return d * MotorEspacial.TICK_SEG


func _pie_mas_cercano(pelota: Vector2) -> Dictionary:
	var mejor := INF
	var elegido := {}
	for pie in _pies:
		var d: float = (pie["pos"] as Vector2).distance_to(pelota)
		if d < mejor:
			mejor = d
			elegido = pie
	return elegido


## Pelota de la elástica en el marco del jugador: (adelante, a su derecha) en
## metros. Con el exterior la saca afuera (fase 0.4), con el interior la cruza
## al otro lado (0.6) y sigue adelante. La animación Regate_Elastica está
## hecha sobre esto (copia en juego3d/animaciones_jugador.py, elastica_3d).
static func elastica_3d(fase: float) -> Vector2:
	var f := clampf(fase, 0.0, 1.0)
	if f < 0.4:
		return Vector2(0.32, 0.36 * smoothstep(0.0, 1.0, f / 0.4))
	if f < 0.6:
		return Vector2(0.32, 0.36 - 0.68 * smoothstep(0.0, 1.0, (f - 0.4) / 0.2))
	var s := smoothstep(0.0, 1.0, (f - 0.6) / 0.4)
	return Vector2(0.32 + 0.12 * s, -0.32 + 0.14 * s)


## Corrimiento hacia adelante del jugador más cercano a la pelota. Pesa 1
## pegado al pie y se apaga de a poco al alejarse la pelota.
func _corrimiento_al_pie(pelota: Vector2, pie: Dictionary) -> Vector2:
	var d: float = (pie["pos"] as Vector2).distance_to(pelota)
	var peso := 1.0 - smoothstep(CONDUCE_CERCA_M, CONDUCE_LEJOS_M, d)
	return (pie["frente"] as Vector2) * PELOTA_DELANTE_M * peso


## La pelota agarrada va entre las dos manos o contra el pecho, un radio
## hacia adelante. En el control de pecho baja al pie a medida que avanza la
## acción, igual que la altura del 2D (de 1.25 m a 0).
func _pelota_en_ancla(pie: Dictionary, radio: float) -> Vector3:
	var modelo: Jugador3D = pie["modelo"]
	var frente := Vector3(pie["frente"].x, 0.0, pie["frente"].y)
	if ANCLA_DE_ACCION.get(str(pie["accion"]), "manos") == "pecho":
		var pecho := modelo.ancla("Pecho") + frente * radio
		var piso := Vector3(pie["pos"].x, radio, pie["pos"].y) + frente * PELOTA_DELANTE_M
		return pecho.lerp(piso, clampf(float(pie["fase"]), 0.0, 1.0))
	return (modelo.ancla("Mano_L") + modelo.ancla("Mano_R")) * 0.5 + frente * radio
