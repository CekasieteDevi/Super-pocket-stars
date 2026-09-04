# Instrucciones para Claude

Este archivo se carga solo al empezar cada sesión. Es el lugar para
dejarme instrucciones que valgan siempre, sin tener que repetirlas.
Editalo cuando quieras: lo que esté acá lo sigo.

## Cómo escribo el código

- **Todo en español**: nombres de variables, funciones, clases, archivos,
  comentarios y mensajes de commit.
- Los comentarios explican **por qué**, no qué. Si un número está
  calibrado, el comentario dice contra qué se midió y qué pasaba con el
  valor anterior.
- Antes de crear una constante nueva, buscar si el valor ya se deriva de
  otra cosa. Una sola fuente de verdad.

## Godot

- No está en el PATH. Se llama por ruta completa:
  `"E:\IntelliJ\Super Pocket Stars\Godot_v4.7.1-stable_win64_console.exe"`
- Después de agregar un `class_name` nuevo hay que reconstruir la caché o
  no compila:
  `<godot> --path . --headless --editor --quit`

## Tests

- Un test es `extends SceneTree`, tiene una `const SEED`, imprime
  `OK: ...` / `FALLA: ...` y termina con `FALLOS=n`.
- Se corren con `<godot> --path . --headless --script tests/<archivo>.gd`
- Los archivos con prefijo `_diag_` son mediciones, no tests: quedan
  fuera de la regresión.
- **La regresión completa gatea el commit**: `bash tests/correr_regresion.sh 8`
  (~5 min con 8 en paralelo). No commitear con fallas.

## Cómo trabajar los cambios de balance

- **Medir antes de tocar, con la misma semilla, y volver a medir lo
  mismo después.** Un cambio de balance sin números medidos no se
  entrega.
- Los dos motores tienen que dar resultados comparables: `MotorEspacial`
  (tus partidos de liga) y `MatchEngine` (todo lo demás). La paridad
  entre los dos es el ancla.
- Si un test empieza a fallar después de un cambio, revisar si el test
  estaba bien: varias veces pasaba por ruido y no porque midiera algo.

## Trampas conocidas

Las dos que estaban acá se arreglaron el 2026-09-03. Quedan anotadas
porque el arreglo define un contrato que hay que respetar.

- `Economia.procesar_temporada` **no es una consulta**: le mueve al club
  la caja, el presupuesto, la reputación, la hinchada y la quiebra.
  Llamala una sola vez por temporada y por club. Para comparar, medir o
  previsualizar un cierre, usá `Economia.calcular_temporada`, que corre
  el mismo cierre sobre una copia y no toca al club.
- `Team.reset_partido()` ya no manda a la cancha al que no puede jugar:
  filtra `jugadores` por `puede_jugar()`. Eso es todo lo que hace — el
  puesto queda vacío y el equipo sale con diez. Quien BUSCA el reemplazo
  y tapa el hueco sigue siendo `Alineacion.arreglar`, y la llaman
  `Liga.jugar_fecha` (clubes de la IA) y el modal de alineación (club del
  jugador).

## Cosas que no se tocan

- **La partida guardada del usuario**:
  `C:/Users/Administrator/AppData/Roaming/Godot/app_userdata/Super Pocket Stars/partida.json`
  Los tests que escriben a disco usan `user://partida_test.json`.
- El harness de capturas de pantalla se agrega temporalmente a
  `project.godot` y hay que **borrarlo siempre** al terminar, dejando
  `git status` limpio.

## APK

- `bash build_apk.sh` — firma con build-tools 35.0.0 porque con 28.0.3
  Godot falla la firma en silencio.
- adb: `export PATH="$PATH:/d/dev-tools/android-sdk/platform-tools"`

## Documentación de diseño

`docs/motor_espacial.md` es el documento de diseño. Las referencias tipo
§8.4 #22 que aparecen en los comentarios del código apuntan ahí.

## Estilo de escritura (STE adaptado)

- Voz activa siempre. "El script lee el archivo", no "el archivo es leído".
- Una idea por oración. Máximo ~20 palabras.
- Sujeto explícito. Nada de oraciones sin sujeto.
- Presente simple por defecto.
- Un término técnico = una sola palabra fija. No sinónimos ("carpeta" siempre, nunca "directorio" a veces).
- Todo término técnico se explica la primera vez que aparece, entre paréntesis, en una línea.
- Instrucciones en imperativo: "Ejecutá X", no "se podría ejecutar X".
- Nada de metáforas, ironía ni frases de relleno.
- Listas para pasos o condiciones. Nunca párrafos largos con pasos adentro.
- Español rioplatense, claro y directo.