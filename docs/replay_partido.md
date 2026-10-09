# Replay de partido (debugger)

Vuelve a jugar un partido guardado con su receta y compara el marcador con el
que quedó en el save. Si pedís el resumen o un rango de pasos, también muestra
qué decidió el cerebro en cada paso. Sirve para ver qué pasó en un minuto
exacto de un partido real del celu, sin tener que volver a jugarlo.

El script es `tools/replay_partido.gd`. Corre solo en la PC, en modo consola.

## Antes de usarlo

1. Copiá el save del celu. Nunca uses `user://partida.json` del PC: el replay
   escribe en el save que le pases.

   ```
   adb -s 324450411348 shell "run-as uy.cekasiete.superpocketstars cat files/partida.json" > scratch/replay/partida.json
   ```

2. El save tiene que tener la receta del último partido (`ultimo_resultado.receta`).
   Si no la tiene, el script sale con código 2.

3. La librería nativa del PC (`motor_v2/bin/libmotor_v2.windows.template_release.x86_64.dll`)
   tiene que estar compilada desde el mismo código que el celu. La línea `TRAZA`
   muestra el `build=` que usó el PC. Si el celu tiene otro build, `IGUAL` puede
   dar `false` sin que haya un bug en el partido.

## Comando

```
"E:\IntelliJ\Super Pocket Stars\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/replay_partido.gd -- scratch/replay/partida.json [opciones]
```

Opciones (se pueden combinar `--resumen` con una de las otras dos):

| Opción | Qué muestra |
|---|---|
| `--resumen` | Totales: salidas, decisiones elegidas, pasos por decisión y por motivo. |
| `--pasos=A-B` | Una fila por paso entre el paso A y el B. |
| `--minuto=M` | Una fila por paso cuyo minuto del reloj está entre M-1 y M+1. |
| `--minuto=M,margen` | Igual, con otro margen en minutos (por ejemplo `--minuto=14,0.5`). |

No se puede pedir `--pasos` y `--minuto` juntos: el script sale con código 1.

## Códigos de salida

| Código | Significado |
|---|---|
| 0 | El marcador rehecho es igual al del save (`IGUAL true`). |
| 1 | Distinto, o error al leer el save o los parámetros. |
| 2 | El save no tiene receta: no se puede volver a jugar. |

## Cómo leer la salida

- `REPLAY` y `GUARDADO`: el marcador rehecho y el del save.
- `IGUAL`: si coinciden. Es la prueba de que el replay es fiel.
- `TRAZA ... coincide=true`: la traza tiene una fila por paso, y `build=` dice qué
  versión del motor la hizo.
- `DECISIONES_ELEGIDAS`: cuántas veces el cerebro eligió cada decisión (cuenta
  eventos, no pasos).
- `PASOS_POR_DECISION` y `PASOS_POR_MOTIVO`: en cuántos pasos estuvo vigente
  cada decisión o cada motivo. Es otra medida: una decisión elegida una vez puede
  durar muchos pasos.
- `SALIDAS`: ver la sección siguiente.

Las filas de `--pasos` y `--minuto` tienen estas columnas:

`paso`, `minuto`, `pelota` (x, y, z), `poseedor` (índice del jugador o -1),
`decision`, `accion` (qué toque hizo el poseedor), `motivo` (por qué el cerebro
eligió esa decisión), `direccion` (x, z), `rapidez`, `raya_m` (metros de la
pelota a la raya más cercana).

Los nombres salen del código C++: `DEC_*` en `canchita_v2_nativa.cpp`, `TOQUE_*`
y `MOTIVO_*` en `canchita.h`. Así se busca en el código lo que aparece en la fila.

## Salidas (pelota fuera)

`SALIDAS` cuenta las veces que la pelota salió de la cancha y las separa por
quién la tocó último (pase, conducción, control, remate, rebote, otra). Es un
clasificador: no mira la pelota en cada paso, mira el último toque cuando sale.

Estado al 2026-10-09: en el partido de referencia (Racing Punta Norte 2-1 Umbrella,
día 133, 18635 pasos) dio **0 salidas**. Se midió que la pelota nunca estuvo a
menos de 1,72 m de la banda. Causa: el control y la conducción apuntan hacia
adentro de la cancha (`control_raya_m = 1,5` en `toque.h`, y el margen de 2 m en
`Canchita::apuntar`). Eso se agregó a propósito porque el control salía de la
cancha 1,2 veces por partido (comentario en `canchita.cpp`, control). Quitar el
margen trae de vuelta las salidas, así que es una decisión de juego, no de
conteo. Pendiente: reconciliar el número de salidas con la medición de semillas
(260 contra 165 en las semillas 97000–97039).

## Qué no hace

- No corre una partida nueva: solo rehace la que quedó guardada.
- No cambia el save original (trabaja sobre la copia que le pases).
- Un partido por corrida.
- Al salir puede imprimir `ObjectDB instances leaked` o `resources still in use`:
  es ruido de cierre del motor, no un fallo del replay.
