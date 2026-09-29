# Vista 3D del partido (etapa 1)

La vista 3D vive en esta carpeta y en `assets/3d/`. No modifica ningún archivo del 2D.

## Cómo se conecta

- `MotorEspacial` graba los fotogramas, igual que siempre.
- `VistaPartido` los interpreta y arma `entidades`, igual que siempre.
- `VistaCancha3D` hereda de `VistaCancha` y lee esas entidades. No dibuja en 2D:
  mueve los modelos de un `SubViewport` 3D.
- La usan `prototipo_3d.tscn` y el juego: Opciones > Simulación (3D / 2D, en
  `user://opciones.cfg`, 2D por defecto). `main.gd` `_aplicar_simulacion` cambia
  la cancha de `VistaPartido` antes de cada partido animado (y del
  Laboratorio), en el mismo lugar del árbol. Test `tests/test_simulacion_3d.gd`;
  foto en el juego `scratch/_foto_juego_3d.gd -- [tick=N] [2d]` (con ventana).
  Falta probarlo en Android (rendimiento, memoria, carga).

## Archivos

- `vista_cancha_3d.gd`: cámara, estadio, jugadores y pelota.
- `jugador_3d.gd`: un personaje (GLB, colores y animación).
- `materiales_3d.gd`: cambia los materiales del GLB por el estilo toon.
- `sombreado_toon.gdshader`: toon de tres tonos.
- `prototipo_3d.gd` / `.tscn`: banco de pruebas con un partido real.

- `camara_partido_3d.gd`: la cámara del 2D con los límites de lo que ve el 3D.
- `galeria_animaciones.tscn`: las 19 animaciones de jugador en el motor real.
  Con `-- capturar` guarda `scratch/galeria_0..3.png` (0, 25, 50 y 75%) y cierra.

## Caras

La cara (ojos, cejas, boca, rubor) no es geometría del GLB: es un dibujo del
atlas `assets/3d/caras.png`, 20 caras (filas) por 5 gestos (columnas):
normal, feliz, dolor, triste y parpadeo. Lo genera `tools/generar_caras.py`
(Python con Pillow); `--muestra ruta.png` guarda una hoja para revisar.

- `Jugador3D._con_cara` saca de la malla la cara modelada (plano y cachetes
  arriba de 1.15 m) y le da a la piel de la cabeza el UV2 del rectángulo
  `RECT_CARA` visto de frente. El alfa del color del vértice marca el frente:
  sin eso la cara salía también en la nuca. Se hace una vez por malla.
- `personaje.gdshader` pinta el dibujo sin luz, como los ojos del modelo. El
  rubor (alfa bajo) se mezcla con la piel y recibe luz: sin luz se veía marrón.
- La cara sale del `jugador_id` (`Jugador3D.cara_de`): es la misma en todos
  los partidos y un plantel de ids seguidos no repite cara hasta el 21.
  Los oficiales tienen la del "concentrado".
- El gesto lo decide `GestosCara`: dolor al caer por una falta y al
  lesionarse (el lesionado, hasta que sale); feliz y triste desde el gol
  hasta 2 s después del saque del medio; feliz al festejar. En la cara
  normal parpadea cada ~3 s de partido.

`tests/test_caras_3d.gd` valida el atlas y los gestos en un partido real
(semilla 22). Fotos: `scratch/_diag_caras_foto.gd -- [gesto=N] [desde=N]
[golero]` (las 20 caras) y `scratch/_diag_caras_partido.gd -- division=1
semilla=22` (caída, lesión y gol, de cerca).

## Animaciones de jugador

Cada acción del motor tiene su animación (`VistaCancha3D.ANIM_DE_ACCION`).
Cada una dura lo mismo que la acción en el motor, así la fase 0..1 cae en el
mismo gesto. Se generan y verifican con `juego3d/animaciones_jugador.py` (Blender).

Estándares que cumple cada una (medidos, no a ojo):

- Duración = `DURACION_ACCION` × 0.25 s.
- Contacto en la fracción de `CoreografiaPartido.PERFILES` (±1.6 cuadros).
- Ningún vértice atraviesa el piso, sumando el salto del motor en las aéreas.
- Parado, la cara no mira más de 25° abajo; en ningún cuadro más de 50° al piso
  (se exime el golpe del cabezazo).
- El festejo es un loop: el último cuadro es igual al primero.
- En los regates los pies siguen el recorrido de `VistaPartido._trayectoria_regate`.
- Lateral y pecho: la pelota va a los anclajes `Mano_L`/`Mano_R`/`Pecho` del GLB.

## Contacto con la pelota

La coreografía del 2D ubica la pelota con puntos del SPRITE (el cabezazo a
2.7 m). En 3D la pelota va al punto del cuerpo que la toca (`CONTACTO_3D`):
anclajes del GLB `Frente`, `Pie_R`, `Pie_L`, `Talon_R`, `Pecho`, `Mano_L/R`.

- El golpe: el de la coreografía (`impacto`) o, en estirada, barrida y bloqueo,
  el instante en que la pelota del motor pasa más cerca del jugador.
- La animación se reparte en dos tramos para que su cuadro de contacto caiga
  justo en el golpe (`_fase_con_contacto`).
- La pelota se desvía al punto de contacto 0.8 tick antes y después del golpe,
  a 16 m/s como máximo (no salta). Bloqueo y estirada se ven venir 3 ticks antes.
- Recepciones (pecho, control, agarre): la pelota sigue al cuerpo y después se
  acomoda adelante del pie.
- Regates: el recorrido de la pelota se achica a la escala del chibi.
- Amague: el motor lo graba junto con el control del pie y el 2D no lo muestra;
  el 3D muestra el control y después el amague.

- Control con el pie: la pelota usa la altura del motor (la coreografía la
  subía al pie del sprite, que en el chibi es el pecho).

## Tiro bloqueado

El motor graba remate y bloqueo en el mismo tick, con el defensor pegado al
que patea, y la pelota sale rebotada del pie. El 3D arma la jugada
(`_bloqueos`, `BLOQUEO_*`): el defensor se para entre la pelota y el arco
mirando al que patea, el remate sale hacia el arco, pega en su pierna
0.25 tick después y rebota por el recorrido del motor.

## Movimiento

- Mezcla: al cambiar de animación la pose vieja se funde con la nueva en
  0.15 s de partido (`Jugador3D.MEZCLA_SEG`); en un salto de reproducción no.
- Piernas: el 3D mide los metros y la velocidad de cada uno
  (`_medir_paso`). Corre desde 0.7 m/s aunque el 2D lo dibuje quieto, con
  pasos más cortos cuanto más despacio va.
- Regates: el recorrido del que regatea se promedia (±1.2 tick) durante el
  regate y 2 ticks después; el motor lo mueve a los tirones.
- Parado: `Respirar` (brazos sueltos), cada uno en otro punto del loop.
- Recepciones (control con el pie y pecho): el motor frena en seco al que
  recibe y tarda 1 s en arrancar. El 3D promedia su recorrido (±1.8 tick,
  `_recepciones`) y, hecho el control, si se mueve pasa a correr.
  Entonces mira para donde corre (`_recepcion_hecha`), no a la pelota que
  venía: andaba de espaldas. `scratch/_diag_espaldas.gd` busca a los que andan
  de espaldas más de 0.2 s.

## Centro bajado de pecho (3D-09)

El motor deja caer el centro, lo hace rodar hasta el receptor y recién ahí
graba `control_pie`. `_preparar_centros` busca esos controles (pelota que venía
a más de 1.4 m, cayó y rodó suelta hasta 6 ticks) y los cambia por pecho:

- En el aire: la pelota sigue desde el último tick a 3 m (`_pelota_del_centro`,
  recta al pecho, bajando con la velocidad que traía) y llega con la velocidad
  del vuelo. El receptor llega antes adonde el motor lo junta con la pelota: su
  recorrido del motor se adelanta en el tiempo (`_tiempo_del_centro`, en la
  ventana de la recepción), frena al tomarla y se pone al día corriendo.
- De rebote: si para eso tiene que correr a más de 8 m/s (`_corre_bien`), la
  pelota pica donde cae el centro del motor y sube con gravedad hasta su pecho
  donde el motor lo junta.
- Bajada, la pelota queda en su pie hasta que el motor se la da; el control del
  motor ya no se muestra. Mira a la pelota que viene hasta que sale corriendo.

`scratch/_diag_centro_3d.gd --fixed-fps 30 -- division=1 semilla=N
[corte_viejo] [detalle] [sin_centros]` mide cada uno.

## Pelota alta que pica (3D-10)

El motor frena en seco la pelota que cae suelta (`FRENADO_PELOTA_SUELTA`, 0.35
por tick): el saque de arco llega a 24 m/s y en 3 m queda quieta, sin picar.
`_preparar_piques` toma cada vuelo de más de 2 m que nadie toca en el aire (ni
remate ni centro de 3D-09) y lo redibuja del golpe hasta que alguien la toma:

- Mismo recorrido del motor, mismo punto y mismo tick de la toma. Sale del pie.
- El vuelo dura y sube lo mismo que en el motor; de ahí salen la gravedad y la
  velocidad con que toca el piso.
- Cae antes y pica: en cada pique conserva la mitad de la velocidad vertical y
  el 60% de la horizontal (`PIQUE_*`). Después rueda frenando. El giro sale
  solo, del avance (`_actualizar_pelota`).

`scratch/_diag_pique_3d.gd --fixed-fps 30 -- division=1 semilla=N
[corte_viejo] [detalle] [sin_piques]` mide cada uno.

## Lateral

El motor deja la pelota en la línea y el que saca camina hasta ahí (hasta
17 ticks). El 3D corta como la tele (`_cortar_caminata_del_lateral`): salta la
reproducción a 3 ticks del saque, con el jugador ya en la banda, mirando a la
cancha, levantando la pelota en las manos.

## Elástica

Recorrido de pelota propio (`elastica_3d`), el rival más cercano compra el
amague (se tira a quitarla para ese lado) y después del cruce sale en diagonal
1.1 m para el lado de la pelota (`_corte_de_elastica`).

## Palo y travesaño

El motor lleva el remate al palo por el piso hasta la línea y, si sale por el
fondo, la deja quieta ahí hasta el saque de arco. El 3D (`_preparar_palos`,
`_pelota_en_palo`) la lleva a pegar en el marco del estadio (`POSTE_Y_M`,
`TRAVESANO_Y_M`, medidos en estadio.glb): travesaño abajo y adelante, poste a
la altura del golpe (cara de adentro si vuelve o entra, de afuera si sale).
Después:
- Afuera: por arriba de la red, pica detrás del arco y rueda hasta el corte.
- Córner: el motor la manda por la línea a cualquier lado (cruzaba el arco):
  pega en el palo de ese lado y sale por afuera hasta donde la tiene el motor.
- En juego: vuelve a la cancha y se junta con el recorrido del motor.
- Gol de palo: del poste a la red (el festejo congela el tick del gol).
La estirada del arquero no la toca. `scratch/_diag_palo.gd --fixed-fps 30 --
division=1 semilla=N [desde=T hasta=T] [resumen]` recorre cada palo.

## Pelota parada y oficiales

- Tiro libre cerca del arco (<35 m): los defensores a 8-10.5 m de la pelota
  sobre la línea al arco hacen `Barrera` (de frente a la pelota) y
  `Barrera_Salto` cuando patean. Corner: el que patea hace `Levantar_Brazo`.
- Oficiales: la señal de `OficialesPartido` elige la animación
  (`ANIM_DE_SENAL`: `Tarjeta`, `Bandera_Arriba`, `Bandera_Horizontal`,
  `Tablero`). La utilería (`utileria_3d.gd`: bandera, tarjeta, tablero con los
  números) va en la mano. Mientras marcan miran a la cámara, y la cámara va
  hacia ellos y se acerca (tarjeta > bandera > tablero; el tablero 2 s). Si el
  oficial está a más de 25 m de lo que se mira (el asistente del otro lado),
  corta en vez de barrer la cancha, y mientras tanto no manda el `foco` del
  fotograma (en el offside el motor ya apunta al que sale por un cambio).
- El brazo del chibi no pasa la cabeza: "brazo arriba" es en diagonal. Con la
  bandera levantada el palo se endereza hacia arriba para que se vea. El
  tablero va arriba de la cabeza con dos mangos hasta las manos, con los
  números de los dos lados, y el cuarto árbitro mira a la cancha. El cuarto
  árbitro se dibuja 2.2 m a la izquierda de la mitad de la cancha, para no
  tapar al que sale.
- Codos: la malla tiene el codo doblado (manos en la cintura). El IK de los
  brazos (`_codo_bisagra` en animaciones_jugador.py) hace que el codo solo
  gire sobre su eje y el resto lo haga el hombro; girando el antebrazo por el
  camino más corto se salía de ese plano y se veía un nudo. Es lo de siempre
  en todas las poses (`bisagraL/R=0` lo apaga).

## Tiro con efecto

El motor curva el remate con una Bézier que viaja en `pelota.trayectoria`
(origen, control, destino, progreso). El 3D:
- Dibuja la pelota por esa curva (`_pelota_en_curva`), no por rectas entre
  ticks, y en arco: `CURVA_ARCO_M` de panza y entra a `CURVA_ENTRA_M`; ya en
  la red, cae. La curva arranca en el tick del golpe (el motor la graba recién
  en el siguiente, con la pelota afuera).
- El que patea (`_efectos`) se acomoda antes con `Efecto_Acomoda` (dos pasos
  cortos, brazos abiertos; si no viene a más de 6 m/s) y le pega con
  `Remate_Efecto` (derecha, cara interna: la envuelve y termina cruzada), con
  el golpe en el mismo 4/11 de `Patear_Corriendo`.
- Estirada que no llega: el arquero del motor corre hasta el final de la curva
  y se pasaba de la pelota. Se achica lo que se corre
  (`_estirada_corta_curva`): se tira desde cerca y la pelota pasa por arriba.

En la muestra (jugada 28, Laboratorio `tiro_efecto` semilla 30) se le agrega
la llegada en diagonal con la pelota (`_con_acomodo`) y el remate se graba
como en un partido, con la pelota ya afuera.

## Andar, forcejeo y trabada

- Por debajo del pique trota (`Trotar`, hasta 4.6 m/s) y despacio camina
  (`Caminar`, hasta 1.8 m/s), con margen y una velocidad más lenta para
  decidir (no cambia a cada rato). La fase de piernas es la misma en las tres:
  no cambia de pie al pasar de una a otra. Cada jugador tiene su zancada
  (±8 %, sale de su clave).
- `Forcejear` / `Forcejear_Izq`: el que lleva la pelota corriendo y el rival
  más cercano a menos de 1.3 m, los dos para el mismo lado, van hombro con
  hombro con el brazo contra el otro (`_preparar_forcejeos`).
- Trabada (`_anotar_quite`): en el motor casi no hay robos pie a pie; los
  cambios de dueño son pases cortados. Si lo corta con un rival encima (3 m) o
  el pase venía fuerte (10 m/s), mete la pierna (`Quitar`).

## Frenada en el motor

`MotorEspacial._mover_hacia(..., frenar)` frena antes de llegar
(`fisica.frenada` = 6 m/s² en utility_pesos.json) al acomodarse en la
formación, en la pelota parada y en los cambios; presión, pase, arquero y
corridas llegan igual. Frenadas en seco por partido (de >4 m/s a <0.8 en un
tick): 268 → 56 en primera. Goles en 60 partidos de décima: 1.17 sin frenada,
1.12 con frenada. La muestra arma sus jugadas con la física de antes
(`FISICA_DE_LA_MUESTRA`) para no cambiar las que ya se revisaron.

Además `fisica.giro_acel` (12 m/s²): la velocidad cambia de a poco hacia la
nueva dirección (vueltas en seco 275 → 7 por partido); y
`fisica.arranque_extra` (0.8): parado acelera 1.8 veces más que cerca de su
punta (el que recibe sale a 2.2 m/s el primer tick, antes 1.4). En 0 vuelven
al comportamiento de antes. Goles en 30 partidos por división (1/5/10):
2.30/1.93/1.00 contra 2.13/1.97/1.03 sin eso.

`scratch/_detector_3d.gd` (con `--fixed-fps 30`) recorre un partido entero
del prototipo y anota lo raro: pelota que salta, jugadores que patinan,
dueño lejos de la pelota, cuerpos encimados.

## Cuerpos sólidos

El motor no choca a los jugadores entre sí (en un duelo quedan a 0.2 m y el
Laboratorio apila en un punto a los que no juegan). El 3D separa cada par a
0.72 m entre centros (`_separar_cuerpos`), con suavizado en segundos de
partido. Caída y lesión: el tendido además se aparta de los demás y sigue
mirando hacia donde corría. Solo cambia el dibujo: motor, pelota y 2D igual.

## Muestra de animaciones

`muestra_animaciones_3d.tscn` repite una jugada en loop: ← → cambia de
jugada, ↑ ↓ velocidad (x0.25, x0.5, x1), espacio pausa, R reinicia.
`-- clip=N` arranca en la jugada N. Se abre en el monitor 2 (`--screen 1`).

Medición: `tests/_diag_contactos_3d.gd` recorre la muestra de a 0.1 tick y mide
la distancia pelota-cuerpo en el golpe, en la recepción, la conducción de los
regates y los saltos, y cuántos pares de cuerpos quedan encimados. Con `-- capturar` (con ventana) guarda fotos de cerca de
cada golpe en `scratch/contactos/`.

## Arquero con la pelota

El arquero usa su propio modelo (`golero.glb`, de `golero_chibi.blend`); sus
animaciones salen de `definiciones_golero()` en animaciones_jugador.py
(`construir_todas(golero=True)`).

- Después de `Agarrar` la tiene en las manos hasta que la juega (4-7 ticks;
  tirado en una estirada, ver "Estirada que termina en agarre"):
  `Arquero_Sostiene`, la pelota entre los guantes (`_manos_arquero`). El motor
  la deja en sus pies y el 2D la oculta en la segunda mitad del agarre: el 3D
  la dibuja igual en las manos.
- El motor graba el saque como un pase (`patea`) o un despeje (`saque_arco`),
  igual que con el pie (`_preparar_saques_de_mano`). El 3D los cambia por
  `lanza_arquero` (`Arquero_Lanza`: por abajo, rodando, la suelta con la mano
  derecha en 7/12) y `voleo_arquero` (`Arquero_Voleo`: la suelta en 8/24, cae
  y le pega de volea en 12/24). La pelota va en las manos hasta soltarla.
- Saque de arco (pelota parada, desde el piso): `Saque_Arco`, llega corriendo
  y le pega en 12/24.

## Estirada del arquero

`Atajar_Volando` corre la cadera 0.98 m al costado y el motor, que lo lleva
hacia la pelota, también: se sumaban. `_corregir_cadera_de_vuelo` deja la
cadera en lo que corra más de los dos (lo del motor que la animación ya cubre
se descuenta), medido con la pose ya puesta (`Jugador3D.corrimiento_cadera`).
Terminada, se queda donde cayó (antes volvía de golpe ~1 m al pararse) y se
junta con el motor entre 6 y 8 ticks después de tirarse. `_estirada_corta`
mide el alcance con esa cadera (`ESTIRADA_CADERA_CONTACTO_M`).

- El motor graba `vuela` en ticks seguidos: la animación sigue la primera
  (antes volvía a empezar y la cadera saltaba para atrás).
- La que reacciona tarde no lleva su cuadro de contacto al golpe (saltaba de
  0 a 0.42 s en un cuadro).
- `scratch/_diag_estirada_3d.gd --fixed-fps 30 -- division=1 [semilla=N]
  [detalle]` mide motor, origen y cadera en cada estirada de un partido.

### Estirada que termina en agarre (3D-08)

El motor graba `vuela` y 1-3 ticks después `agarra`: con Agarrar (parado)
el arquero se paraba en el aire. `_preparar_tendidos` las arma:

- Sigue la estirada hasta caer (Atajar_Volando toca el piso en 15/24; con su
  contacto en el golpe, como la estirada) y pasa a `Arquero_Levanta`
  (`_Izq` del otro lado): se trae la pelota al pecho, queda tirado (cuadros
  6-13 de 36), gira, apoya la rodilla y se para en la pose de
  `Arquero_Sostiene`. Si sobra tiempo antes del saque queda tirado hasta
  0.5 s más (`LEVANTA_TIRADO_EXTRA_MAX_SEG`); si falta, se levanta más rápido.
- El motor lo deja tirado: `fisica.arquero_tendido_ticks` (10 desde que se
  tira; `tendido_hasta` en el arquero) no decide el saque hasta ahí. Antes
  sacaba 4-6 ticks después de tirarse. La muestra y `corte_viejo` lo dejan en 0.
- Mira a la pelota, la cadera queda donde cayó y la atajada (manos en la
  línea del tiro) dura hasta que se para; se juntan con el motor mientras
  se levanta (`sube` → `hasta`). Sin salto del 2D después de caer.
- `scratch/_diag_estirada_agarre.gd -- division=1 semilla=N` lista estiradas
  con agarre (tick, saque); `scratch/_foto_arquero.gd --fixed-fps 30 --
  division=1 semilla=5 desde=538 hasta=555 paso=0.5 id=0` saca fotos de cerca
  de un jugador en el partido (en ventana).

## Remates a las partes del arco

El motor manda todo remate de pie al ras (0.30 m de panza) y llega al arco a
0 m; toda atajada era una estirada con la pelota a 0.55 m. `_preparar_remates`
toma cada remate que llega al arco (gol o atajada; el palo y el tiro libre
tienen su vuelo) y elige, siempre igual para el mismo partido (`_azar` del
tick del golpe y el que patea), a qué alto llega y cómo ataja el arquero:

- Si el arquero se corre menos de `PARADA_TRAVESIA_M` (1 m) de costado ataja
  parado: `Atajar_Abajo` (de rodilla, pelota al ras), `Agarrar` (al pecho) o
  `Atajar_Arriba` (salta, a la altura de la boca). Arrancan 1 tick antes de
  que llegue (manos en la pelota en 6/24) y terminan en la pose de
  `Arquero_Sostiene`; hasta ahí, en guardia. No se tira ni queda tendido.
  La que no retiene (rechazo) es siempre estirada: el motor la hace rebotar
  alta y sale de los guantes.
- Si no, se estira: baja/media (`Atajar_Volando`) o al ángulo
  (`Atajar_Volando_Alto` / `_Izq`, en diagonal y bien arriba; mismos cuadros).
  El salto del 2D se escala para que las manos lleguen al alto de la pelota.
- Gol: al ras (le pasa abajo de los guantes), a media altura o al ángulo con la
  estirada que no llega; si no se corre, le pasa por arriba y salta tarde.
  En la red cae desde donde entró.
- La pelota va del pie (o la cabeza) al alto elegido con un poco de panza
  (`_alto_de_remate`); la atajada termina en las manos, a esa altura.
- La cabeza del chibi no deja pasar las manos por arriba ni adelante de la
  cara: parado agarra hasta ~1.1 m; más arriba es la estirada alta (~1.9 m).

Alto de las manos de cada animación: `scratch/_medir_manos_arquero.gd --
[anims=A,B]`. Plan de un partido y pelota-manos cuadro a cuadro:
`scratch/_diag_remates_3d.gd --fixed-fps 30 -- division=1 semilla=N [detalle]
[sin_remates]`; remates del motor: `scratch/_diag_remates_zonas.gd -- division=1
semillas=5,1,3`.

## Una malla por personaje

`jugador.glb` y `golero.glb` traen el personaje en una sola malla (`Chibi`)
con un solo material: una llamada de dibujo por jugador (en un partido de
primera, 1119 → 264 por cuadro). La une `unir_personaje()` de
`juego3d/exportar_juego3d.py` al exportar: lo que iba pegado a un hueso
(cabeza, pelo, cara, escudo) queda pesado 100 % a ese hueso.

- Cada cara lleva el color de su material en el color del vértice (sRGB) y
  en el UV cómo se pinta: U = tipo (0 fijo, 1 camiseta, 2 short, 3 pelo,
  4 piel, 5 sin luz, 6 cachetes, 7 contorno), V = alfa (glTF la da vuelta).
- `personaje.gdshader` hace todo: el toon de tres tonos, los colores de cada
  jugador (`Jugador3D.colorear`), lo que era sin luz por `EMISSION`, y los
  cachetes (antes semitransparentes) como piel × 0.45 con luz + rosado × 0.55.
- Compatibility ilumina en sRGB: el color del vértice va tal cual; en
  Forward+ y Mobile se pasa a lineal.

## Peinados

Diez peinados de hombre, solo del 3D (el 2D tiene los suyos): 0 puntas (el
pelo original), 1 pelado, 2 rapado, 3 mohicano, 4 afro, 5 jopo, 6 raya al
costado, 7 rulos cortos, 8 hongo, 9 alto (flat top).

- Los arma `juego3d/peinados.py` en Blender (`construir_peinados()`,
  `mostrar(n)`) en `jugador_chibi.blend` y `golero_chibi.blend`: una malla por
  peinado (`Pelo_<n>_<nombre>`, propiedad `peinado`) pegada al hueso Cabeza.
- El GLB los trae todos: `unir_personaje()` pone en la V del UV 2 + peinado
  (en Godot, `UV.y = -1 - peinado`). `Jugador3D.poner_peinado(n)` saca los
  triángulos de los otros; la malla queda en caché por peinado y la comparten
  los que lo tienen (sigue una llamada de dibujo por jugador).
- `Jugador3D.peinado_de(jugador_id)`: 10 ids seguidos pasan por los 10. Los
  oficiales, rapado (`PEINADO_OFICIAL`).
- `tests/test_peinados_3d.gd`; foto de los 10 en fila:
  `scratch/_foto_peinados.gd -- salida=res://... [atras] [golero] [lejos]`
  (con ventana).

## Dorsales

El número de la espalda es el del fotograma (`numero`, de `Team.dorsal_de`,
el mismo del 2D y de la ficha); los oficiales no llevan.

- Cifras del atlas `assets/3d/numeros.png` (0 a 9 en fila, celdas 1:2), que
  genera `tools/generar_numeros.py` con Archivo (la fuente de los números del
  juego) en ExtraBold angosta. Blancas: el color lo pone el shader, el del 2D
  (`SpritesPartido._color_numero`: negro sobre camiseta clara, blanco sobre
  oscura).
- `Jugador3D._con_cara` le da a la espalda de la camiseta (normal hacia atrás)
  el UV2 del rectángulo `RECT_NUMERO` y la marca en el alfa del color, como
  la cara. `personaje.gdshader` pone una cifra al medio o dos, cada una en su
  mitad; espejado da vuelta el U (si no, se leía al revés).
- `Jugador3D.poner_numero(n)`; lo llama `VistaCancha3D` con cada entidad.

`tests/test_dorsales_3d.gd` valida atlas, malla, cifras y el partido. Fotos:
`scratch/_foto_dorsales.gd -- [salida=...] [lejos] [golero] [frente]
[anim=Correr t=0.35]` (con ventana).

## Qué falta (etapas siguientes)

- Bugs vistos en partido para la 1.1.00: [BUGS_1.1.00.md](BUGS_1.1.00.md) (misma semilla, no cambiarla).
