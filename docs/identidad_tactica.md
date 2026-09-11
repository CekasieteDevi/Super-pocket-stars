# Identidad táctica de la simulación

Primera implementación: 10 de septiembre de 2026.

## Comportamiento

El motor sigue calculando el partido antes de reproducirlo. Las decisiones y los movimientos generan los fotogramas reales.

- **Tiki taka:** prioriza pases cortos, paredes y apoyos triangulares. El pasador busca otra línea después de entregar. Reduce el tiempo entre decisiones según el perfil de asociación.
- **Contragolpe:** conserva más jugadores en el bloque. Una recuperación abre seis segundos de transición. Los extremos buscan profundidad y aceleran con espacio, dentro de su velocidad individual.
- **Presión alta:** conserva el desplazamiento adelantado de la defensa. Puede activar tres jugadores cercanos: uno persigue al poseedor y los otros tapan salidas.
- **Ataque por bandas:** los laterales se desdoblan. El extremo opuesto llega al segundo palo cuando la pelota se acerca al fondo. El mediapunta ofrece una devolución dentro del área.
- **Decisiones:** el conductor compara carriles y conserva brevemente su rumbo. Los cambios de frente pueden ser laterales cuando liberan un receptor. Los pases largos tienen vuelo alto. Retroceder pierde valor cuando hay espacio libre, salvo una devolución al área.
- **Animación:** la zancada depende de la distancia recorrida y de una fase individual. Se conserva la reproducción de fotogramas antiguos.

Los atributos, la presión rival y el azar siguen influyendo. Elegir un estilo no garantiza posesión ni victorias. Las combinaciones son movimientos coordinados; no se agregó un editor de jugadas ensayadas.

## Mediciones reproducibles

`tests/_diag_identidad_tactica.gd`: semilla 64120, doce partidos por estilo y división, mismo plantel por semilla. Rival con Juego directo. Dos mitades de 480 ticks; esta medición no incluye todos los tiempos adicionales de `simular`.

Comparación en primera división:

| Medida por partido | Tiki antes → después | Contra antes → después | Presión alta antes → después |
|---|---|---|---|
| Decisiones de pase | 14,3 → 21,3 | 17,0 → 15,9 | 16,3 → 18,3 |
| Pases de al menos 28 m | 7,3 → 7,9 | 7,9 → 11,3 | 7,8 → 11,6 |
| Paredes | 0,3 → 1,7 | 0,5 → 0,2 | 0,6 → 0,7 |
| Pases hacia atrás | 14,0% → 23,0% | 11,8% → 6,3% | 15,9% → 12,3% |
| Centrales defendiendo: metros desde su arco | 22,2 → 23,3 | 18,9 → 18,4 | 34,9 → 34,8 |
| Anchura del equipo con posesión | 36,7 → 46,4 m | 36,9 → 48,8 m | 36,6 → 45,1 m |
| Posesión medida | 50,0% → 49,9% | 50,6% → 47,1% | 50,6% → 45,8% |

La posesión cuenta ticks con poseedor. Los pases hacia atrás incluyen devoluciones útiles; su porcentaje no mide por sí solo malas decisiones. Los pases son decisiones del partido comprimido, no un equivalente directo a estadísticas de 90 minutos reales.

`tests/_diag_goles_motores.gd`: semilla 4400, cuarenta partidos por división, equipos equivalentes entre motores.

| División | Espacial antes | Espacial después | Abstracto |
|---|---:|---:|---:|
| 10 | 2,20 | 2,13 | 3,08 |
| 5 | 2,15 | 2,25 | 2,73 |
| 1 | 3,52 | 2,35 | 2,88 |

La diferencia con el abstracto persiste, especialmente en división 10. Esta muestra no demuestra paridad ni un balance definitivo. No se modificaron las probabilidades de remate para compensar los movimientos.

## Verificación y límites

`tests/test_identidad_tactica.gd` comprueba transiciones, carriles, elección de pases, cambios de frente, devolución al área, desdoble, llegada al segundo palo en ambos sentidos, aceleración y presión coordinada. También compara eventos y estadísticas con y sin fotogramas usando la misma semilla.

Se revisaron capturas de un partido generado en la vista real de Godot, en PC. Las capturas permiten revisar posiciones y dibujo; no reemplazan una sesión de juego ni una evaluación de fluidez en Android.

Pendientes de calibración: ampliar la muestra entre divisiones y formaciones, mejorar la posesión efectiva del Tiki taka y medir pases atrás sin presión separadamente de las devoluciones útiles. La presión alta cambia la organización, pero estas muestras no demuestran más recuperaciones altas que antes.

Una muestra adicional de noventa partidos produjo cuatro rojas. Conviene seguir también la frecuencia de faltas y tarjetas al calibrar la menor cantidad de choques.

La partida guardada del usuario no intervino en las pruebas.

La regresión inicial pasó 104 archivos existentes. La siguiente tanda pasó 105 archivos, incluyendo la nueva prueba táctica. Tras el último ajuste se repitieron los veinte archivos que usan directamente el motor o su vista: diecinueve pasaron, y expulsados pasó al corregir su preparación y ejecutarlo nuevamente. La prueba de expulsiones se convirtió a doce casos del laboratorio: mantiene las comprobaciones de salida, pausa y desaparición, y deja de depender de obtener rojas al azar.

`test_guardado` quedó excluido porque escribe en `user://`, fuera de los permisos del entorno. Por eso esta revisión no equivale a ejecutar la suite completa de persistencia.
