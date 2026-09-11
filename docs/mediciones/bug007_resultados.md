# BUG-007: alcance, elección y precisión del remate

Fecha: 2026-09-11. Motor: Godot 4.7.1.

## Corrección

- El alcance del jugador habilita el intento. Ya no aumenta su utilidad desde el mismo punto.
- La decisión compara una geometría común: distancia y ángulo, con `rango_tiro_medio` de 24 metros.
- La precisión pierde más con la dificultad cuando el rematador tiene poca técnica.
- El castigo adicional crece cuadráticamente con la dificultad. Así concentra el efecto en ocasiones difíciles.
- El tiro lejano sigue disponible para quien tiene alcance. No existe un veto por repetición.
- Los cabezazos, tiros libres, penales y resultados forzados del laboratorio conservan sus rutas.
- El duelo contra el arquero conserva sus pesos. El motor abstracto no cambia.

Pesos finales: `tiro.geometria = 8.5` y `tiro_resolucion.castigo_distancia = 0.1`.
El lector acepta archivos anteriores sin el nuevo peso.

La calibración comparó variantes sobre la misma copia del proyecto.
Con geometría 7 y castigo 0,2, los goles bajaban de 2,12 a 1,66 por partido.
Con castigo 0,1 y geometría 7, quedaban en 1,76.
La combinación final conserva 1,81 y mantiene la reducción de tiros lejanos.

## Aislamiento de cambios simultáneos

Durante el trabajo se incorporó defensa coordinada en los mismos archivos.
La comparación causal usa copias congeladas con idéntica defensa, equipos y semillas.
La copia anterior desactiva únicamente la nueva utilidad y precisión del remate.
También conserva el peso anterior de utilidad, 7.
El registro opcional permanece activo en ambas copias.

Una verificación adicional mide el proyecto integrado con la revisión posterior de esa defensa.
Las huellas SHA-256 identifican las versiones medidas en [bug007/codigo.json](bug007/codigo.json).
Los resultados iniciales del proyecto, anteriores a los cambios simultáneos, no se mezclan con esta comparación.

## Comparación aislada: 300 partidos

Diagnóstico: `tests/_diag_remates.gd`, semillas 4400–4499, 100 partidos por división: 10, 5 y 1.
Cada corrida genera equipos nuevos. Los equipos parejos conservan sus estilos sorteados.

| Métrica | Antes | Después |
| --- | ---: | ---: |
| Goles totales por partido | 2,12 | 1,81 |
| Intentos desde 25+ m, tiro 70–99 | 367 | 86 |
| Goles de esos intentos | 72 | 13 |
| Conversión de esos intentos | 19,6% | 15,1% |

Los intentos lejanos del grupo alto bajan 76,6%. Sus goles lejanos bajan 81,9%.
Los goles totales por partido bajan 14,6%.
La diferencia emparejada es −0,31 goles; intervalo normal aproximado del 95%: [−0,485; −0,135].

La conversión es descriptiva: las posiciones elegidas cambian entre versiones.
Sus muestras son menores y no prueban por sí solas una reducción estadísticamente concluyente.
La prueba controlada de abajo verifica el cambio de precisión sin ese sesgo.

Los JSON conservan todos los remates, separados por atributo, distancia y resultado.
Los intervalos son [0,11), [11,18), [18,25) y [25,infinito).
Los grupos de atributo son 1–39, 40–69 y 70–99.
Las tablas del diagnóstico filtran el atributo `tiro`; cabezazos y libres permanecen identificados en el registro.
Los intentos incluyen bloqueados, palos, remates afuera, atajadas y goles. Los penales quedan fuera del registro.
La columna de goles totales sí incluye penales. La conversión usa exclusivamente goles de remates registrados.

## Comparación contra la etapa 0: 168 partidos

Diagnóstico: `tests/_diag_realismo.gd`, 12 partidos por celda y 14 celdas.
Semillas: `77100 + índice * 13`. Incluye equipos parejos, favoritos y tapados, con dos cruces de estilos.
Cada partido se repite con y sin fotogramas.

| Versión | Goles por partido | Remates por partido |
| --- | ---: | ---: |
| Etapa 0 histórica | 3,143 | 8,560 |
| Copia aislada anterior a BUG-007 | 3,405 | 8,750 |
| Copia aislada corregida | 3,000 | 8,536 |

La corrección queda 4,5% debajo de los goles de la etapa 0, dentro del límite del 15%.
Frente a su copia anterior, la reducción es 11,9%.
Los 168 partidos corregidos conservan marcador y remates con y sin fotogramas.
Las celdas individuales contienen solamente 12 partidos; sus diferencias no son objetivos de calibración.

## Pruebas controladas

`tests/test_tiro_lejano.gd` usa mil semillas por combinación y prueba ambos sentidos de ataque.
El escenario mantiene el resto de los atributos y elimina bloqueadores.

| Tiro | Distancia | Precisión anterior | Precisión corregida |
| --- | ---: | ---: | ---: |
| 20 | 10 m | 66,7% | 67,0% |
| 20 | 28 m | 52,2% | 36,1% |
| 90 | 10 m | 85,5% | 85,5% |
| 90 | 28 m | 80,5% | 63,6% |

Precisión significa remates a puerta entre todos los intentos de esa escena.
La prueba nueva produce `FALLOS=4` con el comportamiento anterior y `FALLOS=0` con la corrección.
También verifica eventos, estadísticas, XP y estado final del RNG con diagnóstico y fotogramas activados o desactivados.
Cada intento y cada gol no penal tienen exactamente una fila de diagnóstico.

Dos pruebas anteriores mezclaban comportamiento con balance:

- `test_alcance_pase.gd` exigía una diferencia del percentil 90 entre divisiones.
  El alcance del tiro ahora se verifica mediante escenas controladas en `test_tiro_lejano.gd`.
  Las pruebas de alcance de pases permanecen.
- `test_expulsados.gd` infería reposición de tiempo mediante goles por partido.
  Ahora cuenta fotogramas sin entradas ni salidas y exige conservar la duración de juego.
  Con reposición desactivada en una copia, falla: 898 ticks frente al mínimo de 958.
  Con el motor corregido pasan los 12 partidos, además de 485 ticks de entradas y salidas.

## Integración con defensa coordinada y regresión

La revisión posterior de defensa también se verificó con los pesos finales.
Sus 300 partidos producen 1,82 goles por partido.
El grupo de tiro 70–99 registra 79 intentos desde 25+ metros y 13 goles: 16,5% de conversión.

Los 168 partidos del diagnóstico amplio producen 3,060 goles y 8,714 remates por partido.
Los goles quedan 2,7% debajo de la etapa 0, dentro del límite del 15%.
Los 168 resultados coinciden con y sin fotogramas.

`_diag_goles_motores.gd`, 40 partidos por división, conserva la diferencia registrada como SIM-001:

| División | Espacial | Abstracto |
| --- | ---: | ---: |
| 10 | 1,73 | 3,08 |
| 5 | 1,95 | 2,73 |
| 1 | 1,90 | 2,88 |

Esta versión de integración cubre 114 scripts, sin fallas pendientes tras las comprobaciones siguientes.
La corrida principal ejecutó 113 scripts en ocho procesos, con códigos de salida y registros individuales.
Se limitó cada proceso a 900 segundos. La corrida duró 510,4 segundos.

Se resolvieron dos resultados de esa corrida mediante revisión y comprobaciones específicas:

- `test_expulsados`: pasó después de reemplazar la inferencia por goles con la medición directa de tiempo.
- `test_phase2`: terminó correctamente. Es un diagnóstico histórico que imprime tablas y `Resultado final`, sin marcadores `OK:`.
  El clasificador inicial confundió esa diferencia de formato con una falla.

`test_guardado` completó la comprobación restante fuera del sandbox, usando solamente `partida_test.json`.
El sandbox había impedido abrir ese archivo temporal. La partida del usuario no se modificó.

El registro [bug007/pruebas.json](bug007/pruebas.json) conserva los resultados iniciales y sus comprobaciones finales.

### Cambios simultáneos posteriores

Durante la revisión de cierre, otra tarea incorporó las etapas 4, 7 y 8 al mismo motor.
Las mediciones y los 114 scripts anteriores corresponden a la versión identificada como `integracion` en las huellas.
No se presentan como una calibración global de esas tres etapas posteriores.

BUG-007 se volvió a verificar sobre el motor con esas etapas: `test_tiro_lejano.gd` da `FALLOS=0`.
Conserva los mismos resultados controlados de precisión y la equivalencia de eventos, estadísticas, XP y RNG.
El registro está en [tiro_integracion_reciente.log](bug007/tiro_integracion_reciente.log).
También pasan `test_expulsados`, `test_alcance_pase`, `test_laboratorio` y `test_penal_espacial` sobre esa versión posterior.
La calibración global de las nuevas etapas corresponde a su propia integración.

## Archivos y reproducción

- [Remates anteriores](bug007/remates_antes.json) y [remates corregidos](bug007/remates_despues.json): comparación aislada.
- [Realismo anterior](bug007/realismo_antes.csv) y [realismo corregido](bug007/realismo_despues.csv): 168 partidos por versión.
- [Remates integrados](bug007/integracion_remates.json) y [realismo integrado](bug007/integracion_realismo.csv): integración con defensa coordinada.
- [Prueba anterior](bug007/tiro_antes.log) y [prueba corregida](bug007/tiro_despues.log): escenas de BUG-007.

Desde la raíz del proyecto, usando el ejecutable Godot indicado en `CLAUDE.md`:

```powershell
& $godotExe --headless --path . --script tests/test_tiro_lejano.gd
& $godotExe --headless --path . --script tests/test_expulsados.gd
& $godotExe --headless --path . --script tests/_diag_remates.gd -- partidos=100 salida=res://docs/mediciones/bug007/repeticion.json
& $godotExe --headless --path . --script tests/_diag_realismo.gd -- partidos=12 salida=res://docs/mediciones/bug007/repeticion_realismo
```

Las copias congeladas permanecen en la carpeta hermana `bug007_verificacion`, fuera del repositorio.
La carpeta de resultados incluye `.gdignore` para evitar que Godot importe los CSV como traducciones.

## Límites

- Esta corrección no completa la etapa 9 del plan de realismo.
- Las probabilidades describen el modelo del juego; no son xG validado con partidos reales.
- La diferencia de goles con el motor abstracto sigue siendo el pendiente SIM-001.
- Las mediciones ejecutadas junto a otras pruebas no sirven como comparación de rendimiento.
- No se realizó revisión visual de partidos animados.
