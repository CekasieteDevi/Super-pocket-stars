# Jugadas colectivas

Objetivo: ataques coordinados, con decisiones y movimientos sin pelota.

1. **Pared y tercer hombre — implementado.** A pasa a B; B habilita la ruptura de C. Se revisa el segundo carril al recibir; si se cierra, B conserva la pelota.
2. **Desborde y pase atrás — implementado.** Con pelota abierta cerca del fondo, un compañero prepara la llegada al punto penal. El extremo busca ese espacio cuando el corredor puede llegar y el carril está libre.
3. **Cambio de frente — implementado.** Detecta defensa volcada hacia la pelota, prepara amplitud contraria y prioriza cambiar hacia el receptor libre, incluso sin ganar metros.
4. **Lateral por sorpresa — implementado.** Extremo marcado baja el ritmo cuando el lateral del mismo costado prepara una corrida por fuera. Pase al espacio cuando puede llegar.
5. **Diagonal del extremo — implementado.** Extremo abierto busca el intervalo real entre lateral y central del mismo costado; el pasador puede habilitar ese destino.
6. **Delantero que baja — implementado.** El nueve ofrece descarga y sostiene el apoyo; un extremo o volante ataca su posición cuando la deja libre.
7. **Amague de centro y enganche — implementado.** Con amenaza de centro y espacio interior, la gambeta puede preparar un recorte hacia adentro. Clip propio compuesto con cuadros existentes: arma golpe, cancela y recoge el pie.
8. **Circular y acelerar — implementado.** Tras pases completados entre al menos tres jugadores, prioriza un envío vertical cuando aparece un carril libre.

## Primer cambio: tercer hombre

Reutiliza la pared y su corrida coordinada. Busca un tercer compañero con ruptura o llegada preparada, dos carriles seguros y alcance suficiente del apoyo. El apoyo necesita técnica de pase. La combinación compite con las demás decisiones; no garantiza recepción ni gol. Conserva controles de intercepción y fuera de juego.

Prueba: `tests/test_tercer_hombre.gd`. Falta calibrar frecuencia viendo partidos completos.

## Segundo cambio: desborde y pase atrás

Llegadas de MC, MCO, DC y EXT a tres carriles alrededor del punto penal. Comparten cupo de corridas, separación de destinos y control de posición legal con los demás desmarques. El pase busca el destino de la llegada, con límite de alcance, riesgo y tiempo de llegada del receptor. No fuerza remate ni gol.

Prueba: `tests/test_desborde_pase_atras.gd`, ambos sentidos y ambas bandas; descarta corredor lejano, carril cerrado y ausencia de desborde. Frecuencia visual pendiente de calibración.

## Tercer cambio: cambio de frente

Detecta al menos tres rivales en la banda de la pelota y una diferencia de dos frente a la opuesta, dentro de una franja longitudinal de 25 metros. EXT y LAT del lado contrario pueden sostener amplitud. Premia el cambio si el receptor está libre; conserva alcance físico y riesgo del pase. Reacciona a la defensa atraída: no impone una secuencia previa de pases.

Prueba: `tests/test_cambio_frente.gd`, ambas bandas y sentidos, receptor marcado y defensa equilibrada. Frecuencia visual pendiente de calibración.

## Cuarto cambio: lateral por sorpresa

LAT a hasta 24 metros y por detrás de un EXT con marca ofrece ruptura ocho metros adelante y seis por fuera. Respeta línea legal, espacio disponible y cupo de corridas. El extremo reduce su conducción mientras dura el plan. El pase preparado espera a que el lateral pueda alcanzar el envío; las demás decisiones siguen disponibles.

Prueba: `tests/test_doblamiento.gd`, ambas bandas y sentidos, ausencia de marca, lateral lejano a la recepción, banda opuesta y salida cubierta. Frecuencia visual pendiente de calibración.

## Quinto cambio: diagonal del extremo

Busca un LAT y un DFC rivales del mismo costado, separados entre 7 y 20 metros de ancho y hasta 10 de profundidad. El EXT parte abierto y ataca hacia dentro un destino legal entre ambos. Descarta trayectos largos, carriles tapados y destinos cubiertos. Comparte cupo de rupturas y pase al espacio con el sistema existente; no fuerza el envío ni el resultado.

Prueba: `tests/test_diagonal_extremo.gd`, ambas bandas y sentidos, posición legal, pase al intervalo, cierre de defensores, cobertura y extremo ya centrado. Frecuencia visual pendiente de calibración.

## Sexto cambio: delantero que baja

DC adelantado respecto al poseedor ofrece un apoyo siete metros hacia la pelota, si tiene espacio y línea de pase. Guarda la posición que deja y sostiene la descarga durante un reparto adicional. EXT, MCO o MC pueden atacar esa posición cuando el nueve retrocedió al menos tres metros y la defensa no la cubre. Comparte cupos, posiciones legales y pases al espacio existentes. No obliga al central a seguir al nueve ni garantiza un pase.

Prueba: `tests/test_nueve_baja.gd`, ambos sentidos, descarga, espera de espacio libre, relevo, habilitación, cobertura defensiva y plan vencido. Frecuencia visual pendiente de calibración.

## Séptimo cambio: amague de centro y enganche

Desde banda, a 6–24 metros de la línea de fondo, un jugador capaz de centrar y con compañero en el área puede elegir enganche en su gambeta. Requiere carril y destino interiores libres. Si gana el duelo, orienta y sostiene un corredor hacia dentro; se desplaza con la conducción normal, sin salto de posición. Mantiene faltas y pérdidas. El intento emite `amague_centro`, con clip de tres ticks, sin lanzar la pelota.

Prueba: `tests/test_enganche_banda.gd`, ambas bandas y sentidos, amenaza de centro, selección, cobertura interior, éxito y pérdida del duelo. Frecuencia visual pendiente de calibración.

## Octavo cambio: circular y acelerar

Amplía las fases de ritmo existentes: registra al menos dos pases completados sin avance de ocho metros y tres participantes distintos. Cuando una opción disponible gana ocho metros y tiene carril y receptor libres, pasa a aceleración y premia ese envío. No exige circular antes de aprovechar una oportunidad ni reemplaza la transición. El avance completado reinicia la secuencia; el cambio de posesión usa el borrado de ritmo existente.

Prueba: `tests/test_circular_acelerar.gd`, ambos sentidos, circulación insuficiente, intercambio repetido entre dos, ventana vertical, selección, carril tapado y reinicio. Frecuencia visual pendiente de calibración.

## Primera medición integrada

`tests/medir_jugadas_colectivas.gd`: ocho partidos, semillas 20260914–20260921. Resultado en `mediciones/jugadas_colectivas.json`. Los contadores distinguen planes asignados de acciones elegidas; no significan jugadas completadas.

- Acciones: 38 cambios de frente, 13 pases a corridas preparadas, 1 aceleración preparada.
- Planes: 65 aperturas, 43 diagonales, 145 descargas del nueve, 18 relevos, 16 llegadas al pase atrás.
- Sin registros en esta muestra: doblajes asignados, tercer hombre elegido, pase atrás coordinado elegido, enganche elegido.

La funcionalidad pasa pruebas de escenas, pero varias jugadas resultaban demasiado raras en esta muestra. Esa limitación motivó la calibración siguiente.

## Calibración integrada: 48 partidos y 48 adicionales

Muestra principal: divisiones 1, 5 y 10 alternadas, equipos y formaciones generados con semillas 20260914–20260961. Referencia `mediciones/colectivas_antes.json`; versión ajustada `mediciones/colectivas_calibrado.json`. Segunda muestra: semillas 20261014–20261061, `mediciones/colectivas_validacion.json`.

Correcciones:

- Los pases con destino adelantado se valoran por ese destino, también si son largos o pases atrás coordinados.
- El doblaje admite al lateral a 24 metros, conservando banda, marca, posición legal y espacio libre.
- Las llegadas al pase atrás empiezan hasta 24 metros antes del fondo. Ofrecen punto penal o borde del área según dónde esté el extremo; sostienen el plan un reparto adicional.
- El extremo puede sostener la banda para ganar fondo si hay llegada preparada y corredor despejado.
- El tiempo de llegada usa la velocidad de pase del jugador, no la máxima posible. Se admite riesgo menor a 0.85, con penalización y las intercepciones normales. La utilidad reconoce al rematador libre.
- El enganche compara tres salidas hacia dentro. El marcador del duelo no se cuenta otra vez como cobertura; otros defensores y contactos cercanos siguen cerrando carriles.

| Conteo por 48 partidos | Antes | Ajustado | Segunda muestra ajustada |
| --- | ---: | ---: | ---: |
| Doblajes asignados | 5 | 49 | 39 |
| Llegadas al pase atrás asignadas | 91 | 196 | 230 |
| Decisiones con pase atrás coordinado disponible | 0 | 3 | 14 |
| Pases atrás coordinados elegidos | 0 | 0 | 5 |
| Enganches elegidos | 7 | 14 | 12 |
| Tercer hombre elegido | 15 | 13 | 9 |
| Goles | 97 | 89 | 86 |
| Remates de decisión | 224 | 204 | 215 |
| Decisiones de conducción | 1332 | 1396 | 1241 |

Los planes asignados no equivalen a recepciones, asistencias ni goles. El pase atrás ya aparece en la segunda muestra, pero sigue siendo raro. No hay evidencia aquí de una reducción general de conducción: en las mismas semillas aumentó. La caída de goles/remates requiere seguimiento; no se modificó la resolución del remate para compensarla. La segunda muestra no tiene comparación anterior emparejada. Pendiente revisar reproducciones y ampliar la calibración; no declarar resuelta toda la variedad visual.

Verificación: pruebas de calibración, enganche, doblaje, tercer hombre, pase atrás y ritmo; regresión de desmarques con 60 partidos sin fallos. El diagnóstico opcional cuenta candidatos, decisiones con opción disponible y acciones elegidas, sin cambiar utilidades ni consumir azar.

Reproducir: `--headless --path . --script tests/medir_jugadas_colectivas.gd -- partidos=48 semilla=20260914 salida=res://docs/mediciones/colectivas_calibrado.json`.

## Descarga útil después de conducir

Se favorece al mejor pase ejecutable hacia un compañero libre después de sostener la pelota. El premio empieza después de tres ticks y crece hasta nueve; exige ganar al menos tres metros o abrir ocho metros hacia banda sin retroceder más de uno. Conserva límites de alcance y orientación ya aplicados, exige carril y receptor libres, y no cambia la utilidad del remate ni su resolución. Sin alternativa válida, no penaliza conducir. El arquero queda fuera.

Peso adoptado: `asociacion_colectiva.descarga_util = 0.35` en `data/utility_pesos.json`. Probados 0, 0.35 y 0.7 con las mismas 48 semillas. El peso 0.7 redujo más la conducción, pero dio 84 goles frente a 89 de la referencia; se eligió el ajuste moderado antes de ejecutar una segunda comparación emparejada.

| Métrica | Principal, sin ajuste | Principal, 0.35 | Validación, sin ajuste | Validación, 0.35 |
| --- | ---: | ---: | ---: | ---: |
| Partidos | 48 | 48 | 48 | 48 |
| Decisiones de conducción | 1396 | 1251 | 1241 | 1111 |
| Metros conduciendo, redondeados | 16926 | 16400 | 16043 | 15722 |
| Pases completados según contador del motor | 1546 | 1564 | 1738 | 1790 |
| Pases a corridas preparadas elegidos | 64 | 76 | 61 | 67 |
| Tercer hombre elegido | 13 | 23 | 9 | 12 |
| Remates de decisión | 204 | 204 | 215 | 200 |
| Goles | 89 | 90 | 86 | 88 |

Archivos: `mediciones/descarga_0.json`, `descarga_0.35.json`, `descarga_0.7.json`, `descarga_validacion_0.json`, `descarga_validacion_0.35.json`. Ambas comparaciones usan equipos y semillas emparejados; la segunda usa 20261014–20261061. Total: 96 partidos distintos ejecutados antes y después, más el barrido exploratorio.

En ambas muestras disminuyen las decisiones de conducción aproximadamente 10%; los metros reales bajan menos (3.1% y 2.0%). En conjunto suben los pases a corridas preparadas de 125 a 143 y tercer hombre de 22 a 35. Los goles se mantienen en esta muestra (175 a 178); no prueba una mejora estadística de definición. Los remates bajan de 419 a 404 y el pase atrás coordinado sigue siendo poco frecuente. Pendiente evaluación visual; no confundir menos decisiones de conducción con igual reducción de metros.

Verificación: `test_descarga_util.gd`, `test_ritmo_variable.gd` (incluye partidos completos), `test_tercer_hombre.gd` y `test_jugadas_preparadas.gd`, sin fallos. La prueba cubre primer toque, pase tapado, devolución hacia atrás, ausencia de pase ejecutable y preservación del remate y del estado del generador aleatorio.

Reproducir referencia: `--headless --path . --script tests/medir_jugadas_colectivas.gd -- descarga=0 partidos=48 semilla=20260914 salida=res://docs/mediciones/descarga_0.json`. Usar `descarga=0.35` para el ajuste y `semilla=20261014` para validación.

## Pase atrás: encuentro adaptado a la carrera

El pasador compara el destino previsto con un encuentro adelantado sobre la carrera actual y tres desplazamientos cercanos. Respeta alcance, tiempo de llegada, zona de remate (7–22 metros del fondo, hasta 11 metros de ancho desde el centro) y un retroceso mínimo de dos metros respecto a la pelota. Las alternativas requieren un carril más limpio que el destino original (riesgo menor a 0.65 frente a 0.85); no se cambia la resolución de la intercepción.

También puede aprovechar una ruptura o llegada central que ya estaba preparada antes de abrir la pelota a banda, aunque no tuviera la etiqueta específica del pase atrás. El receptor corre al destino elegido mediante el movimiento normal. La orientación y el pie preferido evalúan ese mismo destino, incluso en pases normales o largos con punto explícito.

Medición nueva y emparejada: 96 partidos por versión, semillas 20260914–20261009, divisiones 1/5/10 alternadas. Archivos `mediciones/atras_base.json` y `mediciones/atras_final.json`; paso intermedio en `mediciones/atras_mejora.json`.

| Métrica | Antes | Ajustado |
| --- | ---: | ---: |
| Decisiones con pase atrás coordinado disponible | 14 | 21 |
| Pases atrás coordinados elegidos | 2 | 5 |
| Control inicial del receptor tras ese pase | No medido | 5 |
| Goles | 185 | 188 |
| Remates de decisión | 410 | 412 |

El nuevo contador de control inicial excluye fuera de juego, recepción rival y controles que dejan la pelota suelta. No significa remate posterior ni asistencia. La jugada sigue siendo rara; la muestra muestra una mejora pequeña y concreta, no permite afirmar una frecuencia estable ni aumento de goles general.

Pruebas sin fallos: pase atrás (ambas bandas y sentidos, encuentro anticipado, llegada sin etiqueta, carril tapado y receptor demasiado lejos), calibración colectiva, control/orientación (incluye comparación con y sin fotogramas en seis partidos), diagonal del extremo y tercer hombre.
