# Bugs pendientes

Registro iniciado el 10 de septiembre de 2026. Cada entrada indica su estado actual.

Las referencias de línea corresponden al código revisado en esa fecha. Los nombres de función permiten localizarlo después de futuros cambios.

El registro se contrastó con [Manual del vestuario](manual_del_vestuario.pdf). Las diferencias entre versiones y los pendientes históricos están en [revisión del manual](revision_manual.md). Los números históricos del PDF no se consideran mediciones del código actual.

## BUG-001 — Guardado sin protección frente a errores de escritura

- **Prioridad:** alta.
- **Estado:** pendiente; confirmado por revisión de código. No se provocó una interrupción sobre una partida real.
- **Ubicación:** `game/game_state.gd:1979`, `guardar_partida`; `ui/main.gd:7234`, `_on_guardar_partida`.
- **Problema:** el guardado abre directamente `user://partida.json` en modo escritura. No comprueba si la apertura devuelve `null`, no conserva un respaldo y no escribe primero un archivo temporal. El método tampoco devuelve un resultado que permita a la interfaz confirmar el éxito.
- **Consecuencia:** una apertura fallida produce un error de ejecución. Una interrupción durante la escritura puede dejar la partida incompleta. La interfaz no dispone de una confirmación real para informar que guardó correctamente.
- **Corrección propuesta:** escribir en un temporal, comprobar errores, conservar un respaldo y reemplazar el archivo definitivo solamente al completar la escritura. Devolver éxito o error a la interfaz.
- **Verificación pendiente:** usar rutas de prueba para simular apertura fallida y escritura interrumpida. Comprobar que el guardado anterior sigue disponible y que la interfaz informa el fallo.

## BUG-002 — Carga sin validación suficiente del archivo

- **Prioridad:** alta.
- **Estado:** pendiente; confirmado por revisión de código. Falta ejecutar casos de archivos incompatibles sobre una ruta de prueba.
- **Ubicación:** `game/game_state.gd:2039`, `cargar_partida`.
- **Problema:** después de interpretar el JSON, la carga presupone un diccionario y accede directamente a claves e índices. El archivo incluye `version`, pero la carga no valida su valor. Además, sustituye parte del estado activo antes de terminar de reconstruir todos los componentes.
- **Consecuencia:** un JSON sintácticamente válido pero incompleto, incompatible o con índices inválidos puede producir errores. Un fallo tardío puede dejar parte del estado activo reemplazado.
- **Corrección propuesta:** validar tipo raíz, versión, campos obligatorios e índices. Reconstruir todos los componentes en variables temporales y sustituir el estado activo solamente cuando la carga completa sea válida. Definir migraciones por versión.
- **Verificación pendiente:** cargar una lista JSON, un diccionario vacío, una versión futura, una división inexistente y un archivo con componentes internos inválidos. Cada caso debe devolver un fallo sin alterar la partida activa.

## BUG-003 — El historial lleno oculta novedades al avance automático

- **Prioridad:** alta.
- **Estado:** pendiente; mecanismo reproducido con los métodos reales de `GameState`.
- **Ubicación:** `game/game_state.gd:661`, `avanzar_un_dia`; `:778`, `avanzar_hasta_el_partido`; `:1936`, `_recortar_noticias`.
- **Problema:** las novedades se detectan restando el tamaño anterior del historial al tamaño posterior. El historial elimina noticias antiguas cuando alcanza 60 por categoría o 400 en total. Por eso, agregar noticias no siempre aumenta su tamaño.
- **Reproducción realizada:** agregar 60 noticias de categoría `fichajes`; guardar el tamaño; agregar una noticia más de esa categoría; calcular la diferencia de tamaños.
- **Resultado observado:** tamaño anterior 60, tamaño posterior 60, noticia nueva presente y cero novedades calculadas.
- **Consecuencia:** si no hay otra novedad que detenga ese día, «Ir al próximo partido» puede seguir avanzando ante una noticia que requiere una decisión. También puede devolver una lista incompleta si solo parte de las entradas aumenta el historial.
- **Corrección propuesta:** mantener una lista independiente de eventos generados durante el día, o identificar las entradas con un contador creciente. No utilizar el tamaño de un historial recortado para detectar eventos nuevos.
- **Verificación pendiente:** ejecutar el avance real con historial lleno y una oferta que requiera respuesta. Debe detenerse y mostrar la novedad. Repetir con varias noticias y con rumores, que no deben detenerlo por sí solos.

## BUG-004 — El foco individual acredita tiempo que no registra

- **Prioridad:** media.
- **Estado:** pendiente; falta de seguimiento temporal confirmada en código y operación de actualización reproducida. Falta medir el efecto mediante una temporada completa.
- **Referencia del manual:** página 9, requisito de dos temporadas seguidas de foco individual para aprender una habilidad. El seguimiento de temporadas completas se describe con más precisión en los comentarios de `Entrenamiento.actualizar_racha`.
- **Ubicación:** `core/entrenamiento.gd:30`, `asignar`; `:49`, `actualizar_racha`; `core/liga.gd:521` y `:561`, aplicación de progreso al plantel y a la cantera.
- **Problema:** el cierre anual aplica el foco individual vigente e incrementa su racha de temporadas. No registra los días efectivos por atributo ni interrumpe la racha al cambiar o quitar el foco durante el año. Esto contradice el requisito documentado de temporadas completas consecutivas.
- **Reproducción parcial realizada:** asignar un foco y llamar a la actualización de racha usada al cierre, sin avanzar días. La operación acredita una temporada.
- **Consecuencia:** asignar un foco cerca del cierre puede recibir el tratamiento anual. Cambiarlo durante la temporada y restituirlo antes del cierre puede aparentar continuidad.
- **Corrección propuesta:** registrar tiempo efectivo por jugador y atributo. Ponderar el beneficio y definir cómo se acredita una temporada completa, incluyendo cambios, fichajes y cesiones.
- **Verificación pendiente:** comparar con la misma semilla un foco mantenido todo el año, uno asignado al final y uno interrumpido. Revisar también cantera y conservación del seguimiento al guardar/cargar.

## BUG-005 — La simulación bloquea la respuesta de la interfaz

- **Prioridad:** media.
- **Estado:** pendiente; ejecución síncrona confirmada en código. Duración y gravedad pendientes de medir en el dispositivo objetivo.
- **Referencia del manual:** página 2, mediciones históricas de 1,5–2,2 segundos por partido y unos 57 segundos por temporada. El manual considera descartado su riesgo de rendimiento original. Esas mediciones no prueban la respuesta de la interfaz actual; este pendiente requiere comprobar si el bloqueo tiene un impacto que justifique cambiarlo.
- **Ubicación:** `ui/main.gd:7546`, `_jugar_el_partido_de_hoy`; `:7630`, `_on_simular_temporada`.
- **Problema:** la interfaz espera dos fotogramas para dibujar un aviso y después ejecuta la simulación completa en el mismo hilo. Durante ese cálculo no procesa normalmente dibujo ni entrada.
- **Consecuencia:** la pantalla deja de responder durante el partido calculado o la simulación anual. El aviso explica la espera, pero no elimina el bloqueo.
- **Corrección propuesta:** medir primero los tiempos de partido y cierre anual. Dividir el cálculo en etapas que cedan control a la interfaz, o ejecutarlo fuera del hilo visual sobre un estado aislado.
- **Verificación pendiente:** medir en Android y escritorio. Comprobar respuesta visual durante el cálculo, ausencia de acciones duplicadas y resultados idénticos con la misma semilla.

## BUG-006 — El ejecutor de regresión puede omitir fallos de proceso

- **Prioridad:** media.
- **Estado:** pendiente; confirmado por revisión del script. No se ejecutó una prueba de fallo artificial del ejecutor.
- **Ubicación:** `tests/correr_regresion.sh:62`, espera y consolidación de resultados.
- **Problema:** el script no consolida los códigos de salida individuales. Busca únicamente `FALLA` o `SCRIPT ERROR`, omite registros inexistentes y no exige una señal de finalización. Tampoco limita el tiempo de cada proceso.
- **Consecuencia:** un proceso abortado o que termine con error sin esos textos puede no contarse como fallo. Un proceso colgado puede impedir que la regresión termine.
- **Corrección propuesta:** registrar el código de salida de cada prueba, detectar registros ausentes y establecer una señal consistente de finalización. Incorporar límites de tiempo adecuados para los casos largos.
- **Verificación pendiente:** ejecutar pruebas artificiales que terminen correctamente, salgan con código distinto de cero sin mensajes, generen `SCRIPT ERROR` o excedan el tiempo permitido. El resultado global debe reflejar cada fallo.

## SIM-001 — Diferencia de goles entre motores

- **Prioridad:** media; calibración pendiente.
- **Estado:** medido después de incorporar identidad táctica, el 10 de septiembre de 2026.
- **Reproducción:** `tests/_diag_goles_motores.gd`, semilla 4400, cuarenta partidos por división.
- **Resultado:** espacial / abstracto: división 10, 2,13 / 3,08; división 5, 2,25 / 2,73; división 1, 2,35 / 2,88 goles por partido.
- **Consecuencia:** el partido visible y los encuentros del resto de la liga mantienen distinta producción de goles en esta muestra.
- **Siguiente paso:** ampliar semillas y medir remates, calidad de ocasiones y pérdidas por estilo. Revisar creación de ocasiones antes de cambiar probabilidades de gol.
- **Detalle:** [implementación y comparación táctica](identidad_tactica.md).

## Límites de la revisión inicial

- Se ejecutaron 12 pruebas seleccionadas sin `FALLA` ni `SCRIPT ERROR` y con código de salida 0.
- `test_guardado` superó sus comprobaciones en memoria, pero el entorno restringido bloqueó la escritura de su archivo temporal. Ese bloqueo de permisos no se registra como un bug del juego.
- La ejecución ampliada de la regresión fue rechazada; la suite completa de 105 archivos quedó pendiente.
- Godot emitió un error de acceso al almacén de certificados del sistema. No se atribuyó ese mensaje a la lógica del juego.
- No se realizó una sesión visual ni una medición de rendimiento en Android.
- La partida real del usuario no se modificó. Toda futura reproducción de persistencia debe utilizar archivos de prueba separados.

La división de archivos grandes, los identificadores estables de clubes, la actualización de documentación y las mejoras de tutorial o presentación son propuestas de mantenimiento y diseño. No forman parte de este registro de bugs.

## BUG-007 — El tiro de lejos se abusa: un solo atributo decide cuanto se intenta y cuanto entra

- **Prioridad:** media.
- **Estado:** corregido y verificado el 2026-09-11. Observado jugando el 2026-09-10, después de la etapa 1 del plan de realismo.
- **Ubicacion:** `core/motor_espacial.gd:546`, `factor_geometria`; `core/motor_espacial.gd:2576`, `_resolver_tiro`; pesos `rango_tiro_malo`/`rango_tiro_bueno` y `tiro_resolucion` en `data/utility_pesos.json`.
- **Observado:** los jugadores con `tiro` alto le pegan de lejos todo el tiempo y entra. Tres goles asi con Ocampo en 19 minutos de un partido animado.
- **Problema:** el atributo `tiro` hace dos trabajos que se potencian. Define el ALCANCE (16 m con `tiro` 1, 36 m con 99) y ese alcance entra en la utilidad de la opcion, o sea que mas atributo es intentarlo mas seguido desde lejos. El mismo atributo define despues la punteria y el duelo contra el arquero. Ademas la caida de precision con la distancia es igual para todos: `calidad` suma atributo y geometria en vez de que la geometria pese mas sobre el que no sabe pegarle.
- **Consecuencia:** el tiro de lejos deja de ser un recurso y pasa a ser la jugada por defecto de cualquier jugador con el atributo alto. No hay diferencia de riesgo entre el que tiene tiro lejano alto y el que lo tiene bajo.
- **Corrección aplicada:** el alcance solo habilita el intento. La utilidad usa geometría común; la precisión pierde más con la dificultad y la falta de técnica. El tiro lejano sigue disponible. Cabeceos, libres, penales y duelo contra el arquero conservan sus rutas.
- **Verificación:** comparación aislada de 300 partidos, mismas semillas. Para tiro 70–99 desde 25+ metros: 367 → 86 intentos; 72 → 13 goles. Conversión: 19,6% → 15,1%. La versión medida con defensa coordinada da 3,060 goles por partido en los 168 casos del diagnóstico amplio, frente a 3,143 de la etapa 0: −2,7%, dentro del 15%. Los 168 resultados coinciden con y sin fotogramas. Esa versión completa 114 scripts sin fallas pendientes tras reverificaciones. La prueba específica de BUG-007 también pasa después de los cambios simultáneos de etapas 4, 7 y 8; su calibración global pertenece a esas etapas.
- **Prueba de regresión:** `tests/test_tiro_lejano.gd`, mil semillas por escena en ambos sentidos. Falla con el comportamiento anterior y pasa con la corrección. Verifica también diagnóstico, estadísticas, eventos, XP y RNG.
- **Resultados y límites:** [informe de BUG-007](mediciones/bug007_resultados.md). La diferencia entre motores sigue registrada en SIM-001. No se realizó revisión visual.
- **Detalle completo:** [plan de realismo](plan_realismo_simulacion.md), "Observado jugando, 2026-09-10: el tiro de lejos se abusa".

## Observado jugando, 2026-10-04

El usuario anotó estos puntos mirando un partido en el teléfono. Ninguno está investigado: falta ubicar el código y medir. Las entradas marcadas como **pregunta** piden primero una respuesta, no un arreglo.

El partido de referencia es el que le toca al usuario en la partida guardada del teléfono. No modificar esa partida: copiala a una ruta de prueba antes de reproducir.

### BUG-008 — Cualquier jugador remata de taco de espaldas al arco

- **Estado:** corregido el 2026-10-04 en el motor. Falta la revisión visual en el teléfono.
- **Causa:** el que patea va derecho a la pelota y la manda adonde sea (`Canchita::_perseguir`). El remate salía también para atrás de adonde miraba: el 27% de los remates de pie.
- **Corrección:** `Canchita::_remate_de_espaldas` (`motor_v2/cpp/src/canchita.cpp`). El que queda a más de `remate.taco_desde_rad` (80 grados) del punto del arco lleva la pelota hacia el arco con un toque corto y remata de frente. Si la pelota le llegaba de primera, la controla. El que tiene `tiro` 90 o más (`remate.taco_tiro`) y está adentro del área grande le pega igual. El cabezazo no cambia.
- **Medición:** 120 partidos por división, semilla 97000. Remates de pie de espaldas sin permiso: 162 → 3 en quinta, 121 → 3 en primera. Goles por partido: 2,02 → 1,97 en quinta, 2,19 → 2,00 en primera. Remates por partido: 7,13 → 6,10 en quinta, 7,61 → 7,18 en primera. Quites por partido: 14,63 → 15,13 en quinta, 17,17 → 18,33 en primera.
- **Prueba de regresión:** `tests/test_remate_de_espaldas_v2.gd`. `tests/test_motor_v2_puente.gd` pedía un tiro en cada partido y ahora pide tiros en el total: 1 de 100 partidos termina sin remates.
- **Pendiente:** el jugador con `tiro` 90 o más usa el clip de remate común (`Patear_Corriendo`), no el clip `Taco`. El clip `Taco` toca con el talón detrás del cuerpo: usarlo cambia por dónde llega el jugador a la pelota.
- **Observado:** los jugadores le pegan de taco hacia el arco estando de espaldas al arco.
- **Pedido del usuario:** el remate de taco queda solo para los jugadores con `tiro` de 90 o más, y solo desde adentro del área grande. Los demás jugadores se dan vuelta y rematan de frente al arco.

### BUG-009 — El que conduce sigue corriendo y deja la pelota atrás

- **Estado:** corregido el 2026-10-04 en el motor. Falta la revisión visual en el teléfono.
- **Causa:** el toque de conducción contaba solo lo que el jugador corría hacia donde mandaba la pelota (`Canchita::_decidir_partido`). El que corría a 6,6 m/s y giraba 110 grados dejaba la pelota casi quieta. El cuerpo tarda medio segundo en frenar: seguía 1,8 m y volvía. El arreglo anterior (`toque.frena_giro_*`) solo cubría los giros de más de 100 grados sin un rival cerca.
- **Corrección:** el toque suma lo que el cuerpo sigue corriendo para otro lado hasta el toque siguiente. La pelota sale hacia donde va a estar el cuerpo y llega con él. El jugador termina el giro en el toque siguiente. `toque.conduce_inercia` (1 es todo, 0 lo apaga) reemplaza a `toque.frena_giro_*`.
- **Medición:** 60 partidos por división, semilla 97000. Episodio: el último que la tocó corre a más de 2 m/s alejándose, la pelota va a menos de 2,5 m/s y queda a más de 0,9 m detrás, 0,15 s o más. Después de un toque de conducción: 4,63 → 1,37 por partido en quinta, 7,02 → 2,07 en primera. Contando todos los toques: 6,05 → 2,72 en quinta, 9,97 → 4,23 en primera.
- **Balance:** al que conduce se la quitan menos (7,2 → 4,0 veces por partido en quinta). `reglas.entrada_prob` pasa de 0,5 a 0,75 y `nivel.tecnica_por_punto` de 6 a 3. `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario: 18 medidas fuera de rango en los 16 escenarios (antes 19). Quinta: goles 2,06 → 1,99 (motor espacial 2,26), remates 6,28 → 6,89 (7,29), faltas 2,54 → 2,48 (2,44). Primera: goles 1,99 → 2,45 (2,31), remates 7,05 → 7,54 (8,15), faltas 2,09 → 2,11 (2,24).
- **Pendiente:** quinta contra octava queda en 3,95 goles (antes 3,32; motor espacial 3,38). Los episodios que quedan salen de controles, quites y giros contra una raya. La pelota conducida a más de 2,5 m pasa de 0,6% a 0,9% del tiempo en quinta, y de 2,1% a 1,3% en primera.
- **Prueba de regresión:** `tests/test_pelota_atras_v2.gd`.
- **Observado:** el jugador se va solo, la pelota queda quieta atrás y el jugador tiene que volver a buscarla.
- **Caso para reproducir:** Mco Romero, minuto 23 del partido de referencia.
- **Relacionado:** BUG-018.

### BUG-010 — Pregunta: qué velocidad tiene un jugador de 99

- **Estado:** pregunta sin responder.
- **Observado:** algunos jugadores corren más rápido que un caballo.
- **Pedido del usuario:** informar la velocidad máxima, en metros por segundo y en kilómetros por hora, de un jugador con velocidad 99. Compararla con la de un futbolista real.

### BUG-011 — En el córner van demasiados jugadores a la pelota y nadie salta

- **Estado:** anotado, sin investigar.
- **Observado:** cuando cobran el córner, todos van adonde cae la pelota y se amontonan. Además los jugadores cabecean parados, sin saltar.

### BUG-012 — Pregunta: hay regates

- **Estado:** pregunta sin responder.
- **Pedido del usuario:** informar si el partido tiene regates. Si no los tiene, habilitarlos.

### BUG-013 — Pregunta: hay palomitas, voleas y chilenas

- **Estado:** pregunta sin responder.
- **Pedido del usuario:** informar cuáles de los tres remates existen y cuáles se ven en el partido.

### BUG-014 — El jugador entra corriendo al arco con la pelota y el arquero no hace nada

- **Estado:** anotado, sin investigar.
- **Caso para reproducir:** gol del minuto 32 del partido de referencia.

### BUG-015 — Pregunta: el rival domina más de lo que el plantel justifica

- **Estado:** pregunta sin responder.
- **Observado:** el usuario no tiene un equipo malo y siente que el rival lo pasa por arriba.
- **Pedido del usuario:** comparar los dos planteles del partido de referencia y decir si el dominio del rival está justificado por los atributos.

### BUG-016 — El arquero hace el pase con las manos de espaldas

- **Estado:** anotado, sin investigar.
- **Observado:** la animación del saque con las manos se ve con el arquero de espaldas a la dirección del pase.

### BUG-017 — El sustituido y el lesionado salen lento y por el lugar equivocado

- **Estado:** anotado, sin investigar. El usuario lo pidió varias veces antes.
- **Pedido del usuario:** el jugador que sale por cambio o por lesión se va más rápido. Sale por el medio de la banda de abajo, donde va el cuarto árbitro con los cambios.

### BUG-018 — El que corre rápido pasa de largo y no se lleva la pelota

- **Estado:** anotado, sin investigar.
- **Observado:** algunos jugadores llegan a la pelota tan rápido que la pasan de largo sin tomarla.
- **Relacionado:** BUG-009 y BUG-010.

### BUG-019 — Pregunta: hay tiros con efecto

- **Estado:** pregunta sin responder.
- **Pedido del usuario:** informar si los remates tienen efecto (curva de la pelota en el aire).
