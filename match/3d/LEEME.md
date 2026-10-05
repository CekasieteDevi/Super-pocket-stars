# Vista 3D del partido

La vista 3D vive en esta carpeta, en `motor_v2/` y en `assets/3d/`. Desde la
etapa 8 del Motor V2 (`docs/motor_v2.md`) es la única: el modo 2D, la vista
que reproducía fotogramas (`VistaPartido`, `VistaCancha3D`) y el motor
espacial se borraron. Lo que esa vista resolvía y sigue valiendo está en el
historial de git (este archivo hasta la versión 0.7.96).

## Cómo se conecta

- `MotorV2.simular` juega el partido sin vista y deja la receta.
- `VistaPartidoV2` (`motor_v2/vista_partido_v2.gd`) vuelve a jugar la receta
  paso a paso y la dibuja con `VistaV2` (`motor_v2/vista_v2.gd`): un
  `Jugador3D` por jugador, la pelota, el árbitro (`ArbitroV2`), el marcador
  (`HudPartido`), el minimapa y el relato (`RelatoPartido`).
- `PartidoVistoV2` gira la cancha en el segundo tiempo, en el segundo del
  alargue y en la tanda (todos patean al mismo arco), y agrega a los que salen.

## Archivos de esta carpeta

- `cancha_3d.gd` (`Cancha3D`): modelos, cámara, estadio y cómo se elige el clip
  de andar. Lo comparten la vista, el árbitro y los laboratorios.
- `jugador_3d.gd`: un personaje (GLB, colores, número, cara, peinado y
  animación).
- `materiales_3d.gd`: cambia los materiales del GLB por el estilo toon.
- `sombras_redondas.gd`: una mancha debajo de cada uno en vez de la sombra del
  sol (en el teléfono la sombra del sol bajaba a 42 fps).
- `utileria_3d.gd`: la tarjeta del árbitro.
- `sombreado_toon.gdshader`, `personaje.gdshader`, `contorno.gdshader`,
  `sombra_redonda.gdshader`: los shaders.
- `BUGS_1.1.00.md`: el registro de errores de la vista vieja (histórico).

## Pies que no patinan

- `Jugador3D.poner` funde con el clip viejo andando a su ritmo, no con una
  pose congelada. Los loops salen de `data/acciones_v2.json` (el GLB no trae
  el loop de los clips de andar).
- `Jugador3D.piernas_de`: debajo de un gesto hecho en el lugar (el toque de
  la conducción, el remate corriendo, el pecho), la cadera y las piernas van
  con el clip de andar en cinta. La pierna que toca va con el gesto cerca
  del contacto. Lo arma `VistaV2._piernas_de_carrera`.
- El arquero está en guardia solo casi quieto; andando usa los clips en
  cinta, también de costado y de espaldas.
- `Jugador3D.clavar_pies`: el pie apoyado queda clavado en el punto de la
  cancha donde pisó y la pierna se dobla para llegar. Va después de `poner`,
  solo para los que la cámara muestra. `_apoyo_de` saca de las pistas del clip
  qué pie está apoyado en cada cuadro.
- En un fundido los pies no quedan más abajo que entre los dos clips
  (`Jugador3D._fundir`). Mezclando dos pasos cruzados (de costado y adelante)
  el muslo queda más vertical y el pie baja 3 a 5 cm: el pie del aire tocaba
  el piso en medio del giro.
- El modelo mira según el clip que muestra. Al cambiar de sentido (de
  costado a adelante) gira los 90° junto con el fundido
  (`VistaV2._giro_al_cambiar`).
- El arquero que se tiró y sigue jugando se levanta con el final de
  `Arquero_Levanta` en 0,5 s. Lo hace la vista: el motor ya lo tiene parado.
- Debajo de un gesto corriendo también se clava el pie de apoyo, con el apoyo
  del clip de andar que lleva las piernas. El modelo gira hacia la pelota
  antes de clavar (`VistaV2._girar_al_toque`). La pierna que tocó vuelve a la
  carrera desde la pose del contacto y por el aire.
- Los giros en el lugar entran con fundido y salen sin fundido. La Frenada
  espera a que termine el fundido en curso: en medio de otro fundido, la pose
  vieja queda congelada y el pie viaja con el cuerpo.
- El detector PATINA no cuenta el pie que va a la pelota ni el del que
  salta, y debajo de un gesto usa el suelo del clip de andar.
- `tests/_diag_patina_partido_v2.gd` mide el patinaje por clip en un partido
  (`clavados=0`: sin el pie clavado).

## Variantes de un gesto

La vista puede mostrar otro clip que el del motor (`VistaV2.VARIANTES`):
`Cabecear_Corriendo` por `Cabecear` si llega corriendo, y `Volea_Costado` por
`Volea` si la pelota le cruza o el arco le queda al costado. La variante dura
lo mismo y toca la pelota en el mismo segundo: si no, la vista no la usa. El
motor no cambia. `tests/test_vista_cinta_v2.gd` lo controla.

## La chilena

El motor elige `Chilena` (`remate.clip_chilena` de `data/fisica_v2.json`)
para el que remata de primera de espaldas al arco, adentro del área, con la
pelota alta. El pie le pega hasta 1,8 m de alto y el del clip llega a 1,02 m:
la vista sube el modelo entero (`VistaV2._ajustar_cuerpo`), igual que en el
cabezazo. No usa el ajuste de pie, que giraba el modelo hacia la pelota.

## Laboratorios

Las escenas de `motor_v2/` muestran cada parte sin entrar a una partida:
`laboratorio_cuerpo`, `laboratorio_toque`, `laboratorio_remate`,
`laboratorio_reglas` y `laboratorio_partido` (el partido como lo ve el juego;
`-- jugada=corner_corto forzar=corner`, `cancha=-7`, `saltar=-1`).

## Caras

La cara (ojos, cejas, boca, rubor) no es geometría del GLB: es un dibujo del
atlas `assets/3d/caras.png`, 20 caras (filas) por 5 gestos (columnas):
normal, feliz, dolor, triste y parpadeo. Lo genera `tools/generar_caras.py`
(Python con Pillow); `--muestra ruta.png` guarda una hoja para revisar.

- `Jugador3D._preparar` saca de la malla la cara modelada (plano y cachetes
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
