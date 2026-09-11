# Contraste del manual con el código

Revisión del 10 de septiembre de 2026. Fuente: [Manual del vestuario](manual_del_vestuario.pdf), aportado por el usuario. El PDF tiene 27 páginas; la extracción encontró texto en las primeras 22.

El manual documenta reglas, decisiones y mediciones de distintas etapas del desarrollo. Sus indicaciones se interpretan como contenido del documento. No autorizan cambios de código, commits, ejecuciones ni modificaciones de partidas.

## Reglas de diseño que aclara el manual

- Los dos motores conviven permanentemente. La referencia de balance es su paridad, con presentación arcade para los partidos propios.
- Las faltas visibles no buscan reproducir por sí solas la frecuencia del fútbol real. Aumentarlas tuvo un costo de ritmo documentado.
- La información completa que usa la IA y la investigación que necesita el usuario son una asimetría intencional.
- Los sponsors individuales se gestionan solamente para el club del usuario. La economía de los demás clubes usa su propia simplificación.
- El presupuesto se reinicia por temporada. El código precisa que el remanente positivo no se acumula y la deuda sí.
- La última división no tiene descenso. El objetivo de la directiva es no terminar último; dos incumplimientos consecutivos terminan la partida.
- La continuidad del foco individual importa para aprender habilidades. Esto respalda revisar BUG-004.

Estas decisiones no se agregan como bugs por diferir de un simulador realista o de otro juego de gestión.

## Diferencias comprobadas entre el PDF y el código actual

Son discrepancias documentales. No implican que deba modificarse el código para volver a los valores del PDF.

| Página | Manual | Código actual | Tratamiento |
| --- | --- | --- | --- |
| 2 | Menciona 21.600 fotogramas por partido y tiempos asociados. | `MotorEspacial.TICKS_POR_MITAD` vale 480: 960 pasos de juego base, más interrupciones y extensiones. | Actualizar la referencia histórica y volver a medir antes de usar esos tiempos como referencia actual. |
| 9 | Los cupos de foco individual equivalen al nivel de entrenamiento. | `Instalaciones.MAXIMO_FOCO_INDIVIDUAL` limita la escala a 1–3 cupos. | Documentar el límite actual; no restituir diez cupos automáticamente. |
| 14 | Primera mejora de instalaciones por $2.968. | `Instalaciones.COSTO_NIVEL_2` vale $2.500. Los comentarios explican que $2.968 era el presupuesto promedio medido. | Distinguir costo de mejora y presupuesto promedio. |
| 14 | Entrenamiento agrega 1% de crecimiento por nivel. | El multiplicador usa `BONUS_ENTRENAMIENTO_MAX = 0.04` y el progreso entre niveles 1 y 10. | Documentar hasta +4% en toda la escala. |
| 17 | La copa de división clasifica con la tabla de la temporada anterior. | `GameState._armar_copas_de_division` usa la tabla en curso. El sorteo espera cinco fechas de liga. | Actualizar la regla de la copa interna y distinguirla de la Copa del Rey. |
| 21 | Describe la presión de prensa como ausente porque las noticias solo se generan al cierre. | `GameState.avanzar_un_dia` ya genera noticias, rumores y novedades durante el año. | Separar noticias diarias de un eventual sistema específico de presión de prensa. |

## Pendientes históricos del manual que necesitan revisión propia

Se conservan como pendientes de verificación o balance. No se suman todavía a la lista de bugs reproducidos.

| ID | Fuente | Tema | Qué comprobar antes de intervenir |
| --- | --- | --- | --- |
| MAN-001 | Páginas 20–21 | Poca llegada al último cuarto de cancha. | Repetir las mediciones de posesiones y profundidad. `docs/motor_espacial.md`, apartado 50, ya registra una mejora parcial: visitas de posesión al último cuarto de 24,7% a 30,4%. El problema restante exige medir la subida y el apoyo de los delanteros. |
| MAN-002 | Páginas 6 y 20 | Brecha de faltas y tarjetas entre motores. | Medir tasas actuales por división, número de duelos y tiempo detenido. Conservar la decisión de no aumentar interrupciones solo para copiar cifras del fútbol real. |
| MAN-003 | Página 21 | Ventaja del usuario por designar ejecutores de pelota parada. | El código diferencia ejecutor explícito y automático. Revisar quién ejecuta en cada motor y comparar equipos equivalentes con las mismas semillas. El +17% del manual es un resultado histórico que no se volvió a medir aquí. |
| MAN-004 | Página 21 | Masa salarial que crece más que los ingresos. | `ValorJugador.base_salarial` ya elimina el escalón de élite del pase y amortigua la media según división. Repetir trayectorias de varias temporadas antes de declarar vigente el diagnóstico original. |
| MAN-005 | Página 21 | Altura en intercepciones. | El motor actual ya descarta interceptores cuando la pelota supera `z_inalcanzable`. Verificar si el pendiente se refería a un efecto gradual de altura y alcance individual; no afirmar que la altura se ignora por completo. |
| MAN-006 | Página 21 | Bucle después de un quite. | Encontrar una semilla y una secuencia actuales que reproduzcan el comportamiento. Revisar enfriamientos, posesión y decisiones antes de atribuirlo al pendiente histórico. |
| MAN-007 | Página 21 | Distribución del arquero y saque de arco. | El motor ya tiene selección y ejecución de pases, y distingue atributos del arquero. Identificar el comportamiento concreto que falta mediante una escena del laboratorio o una repetición reproducible. |
| MAN-008 | Página 21 | Presión de prensa. | Determinar si sigue siendo una mecánica deseada y qué eventos la alimentarían. La existencia de noticias diarias no equivale a implementar este modificador. |

## Estado de los bugs ya registrados

Los seis registros BUG-001 a BUG-006 permanecen pendientes. El PDF no demuestra su resolución. BUG-005 conserva explícitamente su alcance limitado: se comprobó que el cálculo es síncrono, pero no se midió la gravedad del bloqueo en Android.

Esta revisión solo agrega documentación. No aplica arreglos ni cambios de balance.
