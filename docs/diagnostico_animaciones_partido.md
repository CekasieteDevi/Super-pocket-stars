# Diagnosticar animaciones dentro del partido

Caso documentado el 22 de septiembre de 2026, cambios v0.4.02 y v0.4.03.
Esta guía guarda evidencia e instrucciones para nuevos chats; no reemplaza
las reglas de ejecución de Godot en [AGENTS.md](../AGENTS.md).

## Síntoma y reproducción exacta

En el siguiente partido del guardado, Estudiantes Costa Azul–Umbrella,
Ocampo corría y parecía dar saltitos al regatear cerca del minuto 3.
El usuario aclaró que verlo bien en el laboratorio no era suficiente.

El diagnóstico usó `GameState.cargar_partida()` y
`GameState.jugar_siguiente_fecha()`, igual que el flujo del juego, sin guardar.
No alcanza con simular directamente dos equipos con una semilla cualquiera:
el resto de las divisiones consume RNG antes del partido seguido.

Datos de ese guardado, no constantes universales:

- Jugador: Ocampo, `jugador_id = 924`, clave espacial visitante `100924`.
- Inicio: índice de fotograma 30, minuto 2.91, `regate_croqueta`.
- Su `z` visual permanecía en cero: el síntoma no era un salto físico.
- Tras la corrección del ritmo, regate en índices 30–33 y carrera desde 34.
- El partido completo corregido produjo una croqueta y una bicicleta.
  Los otros tres regates se verificaron con casos controlados del motor y
  la vista del partido; no afirmar que los cinco aparecieron en ese guardado.

## Qué se cambió y qué no bastó

### Primer intento: coherencia de posiciones, fase y dirección

La vista reconstruía posiciones durante el regate y sustituía las del motor
si la diferencia superaba 0.18 metros. También calculaba la fase con una
duración diferente y elegía la dirección del sprite mirando al rival.

Se quitó esa reconstrucción de `VistaPartido._mostrar()`. Se conservan las
posiciones grabadas, se comparte `MotorEspacial.fase_regate()`, se exportan
`regate_ox`/`regate_oy` y se enlaza la pelota al finalizar el gesto.
El rumbo del regate debe quedar fijo aunque un enganche cambie la orientación
normal del jugador en el mismo tick.

**Ese intento no resolvió el síntoma reportado.** El usuario volvió a verlo.
No repetir el error de declarar resuelto un problema visual solo porque
las posiciones son continuas o una revisión estática pasa.

### Segundo intento: ritmo y dibujos realmente disponibles

Había una decisión equivocada explícita en el código: un tick por dibujo.
El partido reproduce cuatro ticks por segundo. Doce dibujos ocupaban tres
segundos, con poses sostenidas que hacían parecer el regate una serie de
saltitos. La vista ya interpola entre ticks y puede mostrar varios dibujos
en cada intervalo; no necesita alargar la jugada para mostrarlos todos.

Se separó cantidad de cuadros y duración del gesto:

| Regate | Cuadros | Ticks actuales | Duración x1 |
| --- | --- | --- | --- |
| Croqueta | 12 | 4 | 1 s |
| Bicicleta | 12 | 6 | 1.5 s |
| Ruleta | 12 | 6 | 1.5 s |
| Globito | 12 | 8 | 2 s |
| Elástica | 6 | 3 | 0.75 s |

La fuente es `MotorEspacial.DURACION_REGATE_TICKS`.
`VistaPartido.DURACION_ACCION` referencia esa tabla. La fase compartida es
`clamp(edad / max(duración - 1, 1), 0, 1)`; el último intervalo enlaza con la
pelota normal. El laboratorio también usa esta duración y fase.
Son valores de esta corrección, no una receta para cualquier animación.
Cambiar duración también cambia cuánto tiempo el motor bloquea nuevas
decisiones y duelos: verificar la simulación, además de la apariencia.

La hoja antigua `assets/partido/regates/elastica.png` tenía **cinco de sus
seis celdas vacías**. El fallback devolvía la única celda pintada para todas
las fases. Las pruebas de «textura no nula/no transparente» lo aceptaban.
`SpritesPartido.regate_png()` ahora usa cuadros completos del atlas preparado:
`[68, 69, 70, 69, 71, 0]`. La prueba exige al menos cuatro imágenes distintas
por regate, además de comprobar tamaño y espejo.

## Procedimiento para el próximo fallo

1. Leer las instrucciones del proyecto. Si la conversación ya autoriza la
   reproducción aislada, usar esa autorización sin volver a pedirla. Esta
   guía no concede un permiso permanente para ejecutar Godot.
2. Identificar guardado, próximo rival, jugador y momento. Leer el guardado;
   no sobrescribirlo. Calcular su SHA-256 antes y después de diagnosticar.
3. Reproducir el flujo real. Registrar acción emitida por el motor, índice,
   posición, orientación, fase, pose y altura dibujada. No deducir la acción
   por cómo se ve una captura estática.
4. Seguir la ruta real del dibujo:
   - `core/motor_espacial.gd`: `_marcar_regate`, `_actualizar_regate`, `_push_fotograma`.
   - `match/vista_partido.gd`: `_acciones_activas`, `_mostrar`, `_trayectoria_regate`.
   - `match/coreografia_partido.gd`: contactos que pueden reemplazar gestos.
   - `match/vista_cancha.gd`: `_dibujar_cuerpo`, selección efectiva de textura.
   - `match/sprites_partido.gd`: `regate_png`; `match/atlas_jugadores.gd`: atlas general.
5. Revisar por separado movimiento físico, movimiento de cámara, pivote de
   pies, reloj de animación, orientación y contenido de cada celda del PNG.
   `z = 0` no prueba que el dibujo no parezca saltar.
6. Inspeccionar la textura usada. **El campo `atlas` del diagnóstico general
   no identifica el dibujo de un regate**: `VistaCancha` toma otra rama y llama
   a `SpritesPartido.regate_png()`. No arreglar índices del atlas general
   basándose en ese número para una acción `regate_*`.
7. Validar a tiempos fraccionarios, no solo en ticks enteros. Revisar entrada,
   contacto, salida, retorno a carrera, continuidad de pelota y espejo.
8. Capturar con render real. `--headless` sirve para lógica, pero no acredita
   la apariencia en pantalla. Usar un proceso separado; no tocar el editor
   abierto. Repetir el partido guardado y los cinco casos controlados.
9. Comprobar logs completos: Godot puede imprimir `SCRIPT ERROR: Assertion
   failed` y aun terminar con código 0 o imprimir un `OK` posterior.
10. Informar exactamente qué pasó, qué cambió y qué pruebas fallaron.
    No presentar un fallo de otra prueba como una regresión nueva sin comparar.

## Herramientas existentes y comandos

Ejecutar desde la raíz `super-pocket-stars`, solo con autorización aplicable.
Usar Godot **4.7.2-stable**, no otra versión.

Diagnóstico del guardado:

```powershell
& '..\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/_diag_guardado_animacion.gd --log-file 'res://scratch/diag_guardado.log'
```

El diagnóstico filtra Ocampo 924 y los primeros 180 fotogramas. Adaptar ese
filtro si cambia el guardado. Escribe copias de fotogramas y logs en `scratch/`;
no llama a `guardar_partida()`. Con `-- capturar`, genera capturas 29–44.
Sus colores genéricos de equipos no reproducen la identidad visual completa.

Verificación con render real, en otro proceso fuera de la pantalla:

```powershell
Start-Process -FilePath '..\Godot_v4.7.2-stable_win64_console.exe' -ArgumentList @('--path', '.', '--script', 'tests/test_regates_partido.gd', '--position', '-3000,-3000', '--resolution', '1152x648', '--log-file', 'res://scratch/verificacion_regates_render.log', '--', 'capturar') -WindowStyle Hidden
```

Para capturar el guardado, usar el mismo comando cambiando el script por
`tests/_diag_guardado_animacion.gd` y el nombre del log. Esperar la terminación
y leer el log; el retorno de `Start-Process` no significa que la prueba terminó.

Pruebas relevantes:

- `tests/test_regates_partido.gd`: cinco regates, ambos sentidos y diagonal;
  ticks reales del motor, interpolación en VistaPartido, cobertura de cuadros,
  orientación, continuidad y ausencia de mutación de los fotogramas.
  Con captura, usa el render de cancha y escribe `scratch/verificado_*.png`.
- `tests/test_animaciones_pixel.gd`: contenido, variedad de imágenes y espejos.
- `tests/test_regates.gd`: requisitos y cooldown del motor.
- `tests/test_changelog.gd`: versión y formato.
- `tests/test_coreografia_partido.gd`: contactos. En esta sesión falló en
  `Laboratorio sin contactos: tiro_efecto`; no se declaró aprobada ni se
  resolvió ese fallo como parte de los regates.

Las cuatro primeras pasaron; la prueba de regates también pasó con OpenGL
y capturas. Se revisó de nuevo ECA–Umbrella. El SHA-256 del guardado quedó
igual. Si vuelve el síntoma, registrar nueva evidencia: no asumir que esta
corrección cubre todos los posibles fallos de animación.

## Caso v0.5.00: pases con curva

El usuario vio curvas irreales en los pases del partido ECA–Umbrella.

Causas medidas con `tests/_diag_curva_pases.gd`:

- `CoreografiaPartido` llevaba la pelota al pie dibujado en el tick del pase.
  Ese punto está 22 px al costado y 0,86 m arriba. El pateador ya se corrió.
  La pelota rasa doblaba de costado y flotaba.
- `MotorEspacial._avanzar_pelota` apuntaba la pelota frenada al receptor.
  La pelota doblaba o volvía hacia atrás sin que nadie la toque.

Corrección:

- Los golpes con el pie (`CoreografiaPartido.PIE`) no usan el punto del sprite.
  Si el pateador tenía la pelota en el tick anterior, el golpe va en ese tick.
  El vuelo queda como lo grabó el motor.
- La pelota dirigida solo recibe empuje por su propia recta.

Resultado en el mismo guardado (el partido cambia un poco con el motor):

| Medida | Antes | Después |
| --- | --- | --- |
| Desvío de la recta, mediana de pases | 26,7 px | 3,2 px |
| Desvío de pases rasos, p90 | — | 2,4 px |
| Giros de la pelota sin toque, motor | 19 | 9 |

Los pases con globo siguen subiendo en pantalla: es la altura, no una curva.
La sombra marca la recta en el piso.

Verificación con render real: `tests/_diag_captura_pases.gd`. Escribe
`scratch/verificado_pase_<tick>_trazo.png` con la pelota de cada cuadro.
Usa los fotogramas que deja `_diag_curva_pases.gd`.
