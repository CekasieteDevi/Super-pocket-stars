# Etapa 9.4: trazabilidad de remates

Fecha: 2026-09-11.

Cada intento tiene un `remate_id` local al partido. El mismo identificador
enlaza registro, vuelo, evento y gol. El valor de la ocasión y la evaluación
del modelo se conservan antes de resolver el resultado. La protección por
identificador impide repetir lanzamientos o aplicaciones, incluso usando
una copia del diccionario. No consume RNG al rechazar duplicados.

Penales y tandas usan la misma secuencia, conservando sus contadores y
eventos específicos. Los penales siguen fuera de `registro_remates`.
Las llamadas anteriores sin identificador reciben uno automáticamente.
Dos copias independientes de datos antiguos sin identificador no permiten
deducir que representan el mismo tiro; deben pasar por el lanzamiento común.

## Remates perdidos tras centros

La prueba encontró registros sin evento de tiro. El centro asignaba una
entrega con `dirigida_a` y luego lanzaba el remate. El avance de pelota
atendía la entrega anterior antes del remate y podía cancelar su recorrido.
Ahora lanzar un remate limpia esa entrega pendiente.

La corrección cambia algunos partidos porque se completa la jugada que
antes se perdía. No se ajustan atributos, probabilidades ni pesos de balance.

## Medición pareada

`tests/_diag_trazabilidad_remate.gd` crea una variante del mismo código
sin limpiar la entrega al lanzar. Ambos motores corren en el mismo proceso,
con equipos nuevos, semillas 9400–9429, 30 partidos por división: 90 pares.
La variante elimina exactamente una llamada; no modifica otros factores.

| División | Goles antes/después | Remates antes/después | Sin evento antes/después |
| --- | ---: | ---: | ---: |
| 1 | 48 / 48 | 222 / 216 | 3 / 0 |
| 5 | 54 / 54 | 209 / 209 | 1 / 0 |
| 10 | 51 / 52 | 172 / 168 | 0 / 0 |
| Total | 153 / 154 | 603 / 593 | 4 / 0 |

Goles: +0,65%. Remates: −1,66%. Es una muestra de integración, no una
calibración final de liga. La corrección puede cambiar una entrega y el
desarrollo posterior aunque ese partido antes no tuviera un evento faltante.

[Evidencia JSON](ocasion_etapa94/balance.json): semillas, pesos, hash del
motor y resultados por partido. Hash del motor medido:
`c520171ff4def113147641d2e60a2690576c1fdb683005028a77e495759f9e98`.

## Pruebas

`test_identificador_remate.gd`: 45 comprobaciones, `FALLOS=0`.
Incluye seis desenlaces/rutas en ambos sentidos, relanzamientos, aplicación
duplicada, centros pendientes, instantánea previa y 12 partidos completos.
Sus 79 intentos, incluidos 8 bloqueos, enlazan registro y evento.

`test_tiro_lejano.gd` y `test_laboratorio.gd`: `FALLOS=0` sobre la versión final.
La primera conserva igualdad con/sin diagnóstico y fotogramas, incluidos XP y RNG.
No se realizó revisión visual ni commit en este punto.

Regresión: `ARCHIVOS_CON_FALLAS=0 de 119 en 437s con 8 en paralelo`.
Durante esa corrida se añadió la guarda de relanzamiento. Sobre esa versión
final se repitieron identificador, tiro lejano, laboratorio y alargue/penales:
todos terminaron con `FALLOS=0`. La medición de 90 pares también corresponde
a la versión final, cuyo hash queda registrado arriba.
