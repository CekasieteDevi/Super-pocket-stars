# Etapa 9.3: integración del contexto

Fecha: 2026-09-11. Alcance: unificar la lectura del contexto y auditar
la aplicación de factores existentes. No recalibra el motor.

## Responsabilidad de cada factor

| Factor | Dónde interviene | Qué representa |
| --- | --- | --- |
| Defensor en trayectoria | Un candidato y un duelo de bloqueo | Interrumpir el remate antes de que llegue al arco |
| Presión cercana | Descripción de la ocasión | No agrega otro castigo al tiro después del bloqueo |
| Geometría común y técnica | Distribución del destino | Puntería: arco, palo o afuera |
| Geometría del rematador | Fuerza en el duelo contra el arquero | Potencia restante de un remate que fue al arco |
| Distancia en bloqueo | Tiempo de reacción del bloqueador | Conserva el alivio existente para el remate a quemarropa |
| Posición del arquero | Trayectoria y alcance en `_lanzar_remate` | Representación espacial de la atajada o gol ya resuelto |

No había una penalización triple del mismo defensor. `_bloques_equipo`
no conoce posiciones ni añade presión espacial. El bloqueo antecede a
la puntería; si prospera, la función retorna y no hay duelo con el arquero.
Si falla, ese defensor no vuelve a restar en puntería o atajada.

Distancia y ángulo influyen en puntería y fuerza. Se conserva esa combinación:
representa dos resultados distintos (errar el arco y llegar sin potencia).
Eliminar uno de los factores alteraría el balance calibrado de BUG-007.
No se introduce otro multiplicador de distancia, presión u obstrucción.

## Implementación

`_resolver_tiro` toma una única descripción antes de las tiradas.
La misma instantánea suministra geometría común, candidato al bloqueo
y registro de diagnóstico. Antes el diagnóstico y la resolución buscaban
por separado el bloqueador y calculaban la geometría común.

`modelo_destino_remate` devuelve también `factor_fuerza`, que el duelo
consume una sola vez. El diagnóstico expone ese factor junto a la técnica.
Los desenlaces forzados del laboratorio siguen omitiendo el bloqueo.
Cabezazos y libres conservan sus rutas. Los penales no usan esta función.

## Límites

La posición del arquero todavía no modifica su probabilidad de atajada:
solo interviene al construir la trayectoria. El ángulo visible entre postes
y la presión quedan descritos, sin agregar coeficientes nuevos. La etapa 9
completa sigue pendiente, incluida una valoración que distinga esas situaciones.
Este punto no se presenta como calibración de xG ni como revisión visual.

## Verificación reproducible

`tests/_diag_integracion_ocasion.gd` carga una copia previa del motor sin
registrar otro `class_name`. Compara ambos motores dentro del mismo proceso,
con equipos nuevos, divisiones 1/5/10, semillas 9300–9309, con y sin fotogramas.
Compara el resultado completo y el estado final del RNG. Solo excluye el
tiempo de ejecución y el nuevo campo diagnóstico `factor_fuerza`.

La copia previa tiene SHA256
`8fa5809f9945eb05468f5e1a7d9854ef481f1e3e644556069e7c31876cf0e464`.
El informe JSON conserva hashes, pesos, semillas y resultados por partido.

Resultado: **60 pares idénticos**. Cada modalidad suma 51 goles y 204
remates en 30 partidos. No cambian eventos, estadísticas, XP, fotogramas
ni estado final del RNG.

| Modalidad | Antes, ms/partido | Después, ms/partido |
| --- | ---: | ---: |
| Sin fotogramas | 348,3 | 345,6 |
| Con fotogramas | 380,1 | 381,1 |

Es una sola corrida pareada, siempre antes/después; no prueba una mejora
de rendimiento. Las diferencias observadas son menores al 1%.

Evidencia: [comparación JSON](ocasion_etapa93/comparacion.json) y
[motor previo](ocasion_etapa93/motor_antes.gd). La carpeta tiene `.gdignore`
para que Godot no importe la copia como código de producción.

Reproducir desde la raíz del proyecto:

```powershell
& '..\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/_diag_integracion_ocasion.gd -- antes=docs/mediciones/ocasion_etapa93/motor_antes.gd salida=../comparacion_ocasion.json
```

`test_barrera_tiro_libre.gd` pasa sus tres comprobaciones: defensa ubicada
correctamente en 263 casos y 21 bloqueos en 60 tiros libres.

Regresión completa: `ARCHIVOS_CON_FALLAS=0 de 118 en 337s con 8 en paralelo`.
Ejecutada con `bash tests/correr_regresion.sh 8` sobre el estado de trabajo,
que también contiene cambios de otras tareas. No se realizó commit.
