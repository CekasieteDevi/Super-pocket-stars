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
- **Balance:** al que conduce se la quitan menos (7,2 → 4,0 veces por partido en quinta). `reglas.entrada_prob` pasa de 0,5 a 0,75. El favorito pasaba a hacer de más (quinta contra octava, 3,95 goles contra 3,38 del motor espacial): lo corrige BUG-010. Con los dos arreglos, `tests/_diag_calibracion_v2.gd` da 16 medidas fuera de rango en los 16 escenarios (antes 19). Quinta: goles 2,06 → 2,15 (motor espacial 2,26), remates 6,28 → 6,74 (7,29), faltas 2,54 → 2,29 (2,44). Primera: goles 1,99 → 2,20 (2,31), remates 7,05 → 7,45 (8,15), faltas 2,09 → 1,99 (2,24).
- **Pendiente:** los episodios que quedan salen de controles, quites y giros contra una raya. La pelota conducida a más de 2,5 m pasa de 0,6% a 0,9% del tiempo en quinta, y de 2,1% a 1,3% en primera.
- **Prueba de regresión:** `tests/test_pelota_atras_v2.gd`.
- **Observado:** el jugador se va solo, la pelota queda quieta atrás y el jugador tiene que volver a buscarla.
- **Caso para reproducir:** Mco Romero, minuto 23 del partido de referencia.
- **Relacionado:** BUG-018.

### BUG-010 — Pregunta: qué velocidad tiene un jugador de 99

- **Estado:** respondido y corregido el 2026-10-04. Falta la revisión visual.
- **Respuesta:** la punta de un jugador de velocidad 99 es 9,1 m/s (32,8 km/h); la de uno de 41, 5,9 m/s (21 km/h). Los futbolistas más rápidos del mundo llegan a unos 10 m/s (36 km/h). El problema era el multiplicador por nivel del equipo (`FisicaV2.ventaja_de_nivel`): multiplicaba la punta hasta ±42% en tercera.
- **Caso medido:** partido de referencia en la PC, Racing Arroyo Seco (media 80,7) contra Umbrella (75,8). Racing corría con ×1,31 y Umbrella con ×0,69: el jugador de velocidad 99 de Racing llegaba a 12,0 m/s (43 km/h) y el de Umbrella a 6,3 m/s (23 km/h). El primer gol: un jugador de velocidad 72 lleva la pelota 40 m en 5,5 s, a 27–34 km/h, y nadie de Umbrella pasa de 5,3 m/s.
- **Corrección:** `nivel.punta_tope` 0,05 (`FisicaV2.punta_de_nivel`): la punta cambia a lo sumo ±5% por el nivel del equipo. `nivel.rapidez_tope` baja de 0,25 a 0,09 (aceleración, ±15% en tercera) y `nivel.tecnica_por_punto` sube de 6 a 9. En el mismo partido: 9,6 m/s (34,6 km/h) y 8,7 m/s.
- **Medición:** `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000. Puntos por partido del equipo A (motor espacial entre paréntesis): primera contra cuarta 2,66 (2,96), quinta contra octava 2,86 (2,84), décima contra séptima 0,15 (0,10), primera contra segunda 2,12 (2,00), quinta contra sexta 2,38 (2,14), décima contra novena 0,79 (0,70).
- **Pendiente:** con tres divisiones de diferencia la goleada queda más chica: primera le saca 2,02 goles a cuarta (motor espacial 3,82) y quinta 2,35 a octava (3,15).
- **Observado:** algunos jugadores corren más rápido que un caballo.
- **Pedido del usuario:** informar la velocidad máxima, en metros por segundo y en kilómetros por hora, de un jugador con velocidad 99. Compararla con la de un futbolista real.

### BUG-011 — En el córner van demasiados jugadores a la pelota y nadie salta

- **Estado:** corregido el 2026-10-05 en el motor y en la vista. Falta la revisión visual en el teléfono.
- **Causa del amontonamiento:** al centro iban todos los que lo podían cabecear moviéndose 3 m, de los dos equipos (`Canchita::_pensar_jugador`). Con el centro que cae de alto todos tienen el mismo punto: quedaban encimados.
- **Causa de "sin saltar":** el modelo sí subía (0,7 a 0,9 m, `VistaV2._ajustar_cuerpo`). Cuatro o cinco saltaban a la vez, uno adentro del otro, y el salto no se distinguía. Además el gesto terminaba con el modelo a 0,3-0,5 m del piso y bajaba de golpe en un cuadro.
- **Corrección en el motor:** al centro va el que llega primero de cada equipo y un compañero más, el que lo tiene más a tiro (`Canchita::_analizar`, `motor_v2/cpp/src/canchita.cpp`). Los demás siguen en su lugar.
- **Corrección en la vista:** el modelo vuelve al piso antes de que termine el clip (`VistaV2._ajustar_cuerpo`, `motor_v2/vista_v2.gd`).
- **Medición:** 400 córners forzados de quinta, semilla 97000, en el primer toque del centro. Córners con tres o más compañeros a 1,5 m de la pelota: 36% → 10%. Córners con más de cinco jugadores a 2,5 m: 24% → 6%. Pares de jugadores a menos de 1 m: 3,77 → 1,95 por córner. Gestos de cabeza: 1,90 → 1,42 por córner.
- **Balance:** cabezazos al arco, 40% → 38% de los córners; goles, 2,8% → 2,5%; lo toca primero el que ataca, 48% → 49% (`tests/_diag_corners_v2.gd`). `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000: 16 → 19 medidas fuera de rango; goles y remates se mueven menos que el error de la media. Las tres medidas nuevas son de posesión y de puntos del favorito. Con la semilla 20261001 y 200 partidos, los seis escenarios desparejos dan los mismos puntos y las mismas medidas fuera de rango antes y después.
- **Probado y descartado:** que el segundo no vaya al mismo punto que el primero. El amontonamiento baja al 2%, pero los cabezazos al arco bajan al 25% de los córners y los goles suben al 4,8%.
- **Prueba de regresión:** `tests/test_corner_monton_v2.gd`. `tests/test_alargue_y_penales.gd` buscaba un empate en 20 partidos de liga y ahora busca en 40: con el cambio no hay ninguno en los primeros 20 (12 en 60).
- **Pendiente:** en el 10% de los córners quedan tres compañeros a 1,5 m: el tercero no va a la pelota, estaba en su marca. `Cabecear` dura 0,5 s: el modelo baja 0,9 m en 0,21 s, más rápido que una caída real.
- **Observado:** cuando cobran el córner, todos van adonde cae la pelota y se amontonan. Además los jugadores cabecean parados, sin saltar.

### BUG-012 — Pregunta: hay regates

- **Estado:** respondido y corregido el 2026-10-05. Falta la revisión visual en el teléfono.
- **Respuesta:** el partido no tenía regates. El cerebro del Motor V2 no ofrecía la opción: su comentario decía "faltan los clips de regate". Los cinco clips `Regate_*` existían en el modelo, pero sin cuadro de contacto, y el motor no usaba ninguno. El relato solo contaba la gambeta perdida (el quite).
- **Corrección en el cerebro:** el poseedor puede encarar al rival que tiene delante a menos de 4 m (`DEC_REGATE`, `motor_v2/cpp/src/cerebro/cerebro.cpp`). Usa los pesos `gambeta` de `data/utility_pesos.json`, los mismos del motor espacial: pesa su control contra el quite de ese rival. Con menos de 50 de control la opción no aparece. El que corre no encara si la salida gira más de 1,4 rad de adonde corre.
- **Corrección en el motor:** el toque sale con el clip del regate, abierto 0,9 rad de la línea que va al rival (`Canchita::_decidir_partido`). Al arrancar el gesto el motor sortea si el rival se come el amague (`Canchita::_amagar`): pesan el control y la agilidad del que encara contra el quite y la agilidad del que marca. El rival que se lo come se tira al otro lado y no va a la pelota hasta 0,8 s después del toque. El que no se lo come sigue jugando y la puede sacar. Nadie adjudica la pelota.
- **Corrección en la vista:** el regate muestra el clip entero. Los demás gestos corriendo llevan las piernas de la carrera debajo (`VistaV2`, `motor_v2/vista_v2.gd`).
- **Regates habilitados:** elástica y croqueta. `tools/medir_clips_v2.gd` les pone el cuadro de contacto y `data/acciones_v2.json` se regeneró.
- **Relato:** el regate que deja la pelota en su equipo sale con su nombre: "¡Elástica de X! Deja atrás a Y" (`MotorV2`, evento `regate` del motor).
- **Medición:** `tests/_diag_regates_v2.gd`, 60 partidos de quinta, semilla 97000. Regates por partido: 0 → 7,2. El rival se come el amague en el 51%. El 45% deja la pelota en el equipo del que encaró.
- **Balance:** en esos 60 partidos, quites 12,0 → 13,2; faltas 2,40 → 2,43; goles 2,33 → 2,05; remates 6,87 → 6,95; pases 57,3 → 55,7. `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario: con la semilla 97000, 19 → 14 medidas fuera de rango; con la semilla 20261001, 16 → 20. Las medidas que cambian de lado se mueven menos que el error de la media. En las divisiones parejas, con la semilla 97000: goles 2,11 → 2,12; remates 6,66 → 6,42; pases completos 41,8 → 41,0 (el motor espacial: 36,0); faltas 2,45 → 2,47 (el motor espacial: 2,56).
- **Probado y descartado:** la salida a cualquier ángulo de lo que corre. Salían 11,8 regates por partido, pero con el rival al costado la pelota quedaba atrás del que encaraba: `tests/test_pelota_atras_v2.gd` pasaba de 3,00 a 5,25 episodios por partido (con el tope de 1,4 rad, 3,13).
- **Prueba de regresión:** `tests/test_regate_v2.gd`.
- **Pendiente:** la salida hacia la derecha y los regates que faltan (bicicleta, ruleta y sombrerito) están en BUG-020.
- **Pedido del usuario:** informar si el partido tiene regates. Si no los tiene, habilitarlos.

### BUG-013 — Pregunta: hay palomitas, voleas y chilenas

- **Estado:** respondido el 2026-10-05. La chilena entró al partido el 2026-10-05, por pedido del usuario. Falta la revisión visual en el teléfono.
- **Respuesta:** la volea y la palomita existían y se veían. La chilena tenía el clip (animación) hecho, pero el motor no la elegía nunca.
- **Volea:** el motor la elige cuando el que remata con el pie toca la pelota a la altura del muslo (`Canchita::_clip_de_parte`, `motor_v2/cpp/src/canchita.cpp`). La vista muestra `Volea_Costado` en su lugar si la pelota le cruza o el arco le queda al costado (`VARIANTES`, `motor_v2/vista_v2.gd`).
- **Palomita:** el motor la elige cuando el que remata de cabeza toca la pelota a la altura del pecho. A la altura de la cabeza usa `Cabecear`.
- **Chilena, antes:** el clip `Chilena` estaba en el modelo y en `data/acciones_v2.json`. `data/fisica_v2.json` no tenía un `clip_chilena` y `_clip_de_parte` no la devolvía en ningún caso.
- **Medición de la respuesta:** 40 partidos por división, semilla 97000, contando cada vez que un jugador empieza el clip. Volea: 0,55 por partido en quinta y 0,47 en primera. Palomita: 0,20 en quinta y 0,35 en primera. Chilena: 0 en las dos.
- **Corrección:** `Canchita::_de_chilena` (`motor_v2/cpp/src/canchita.cpp`) y `remate.clip_chilena` (`data/fisica_v2.json`). Le pega de chilena el que remata de primera de espaldas al arco, adentro del área grande, con la pelota desde 0,77 m hasta 1,8 m de alto. Solo el jugador con más `tiro` que `cabezazo`: el otro la sigue peinando de cabeza. El jugador se para de espaldas al arco, casi encima de la pelota. La chilena sale con el golpe fuerte.
- **Vista:** `VistaV2` sube el modelo entero hasta la pelota, igual que en el cabezazo. El relato dice "de chilena" (`MotorV2._tecnica`).
- **Medición de la corrección:** 120 partidos por división, semilla 97000. Chilenas que le pegan a la pelota: 0,125 por partido en quinta y en primera (una cada ocho partidos). El clip arranca 0,32 veces por partido en quinta y 0,28 en primera: en las demás el jugador no llega a la pelota. Goles de chilena: 3 en cada división. Goles por partido: 2,00 → 1,98 en quinta y 2,10 → 2,11 en primera. Remates por partido: 6,80 → 6,51 y 7,23 → 7,20. Remates de cabeza: 1,78 → 1,58 y 1,75 → 1,50.
- **Probado y descartado:** decidir la chilena solo con la pelota a 1,02 m (más o menos 0,25 m): ninguna chilena en 240 partidos, y 6 remates de cabeza menos en quinta y 19 en primera. Decidirla al arrancar el gesto: 2 chilenas en 240 partidos. El jugador ya estaba parado para cabecear, 0,6 m más lejos, y no llegaba.
- **Revisión visual:** hecha en la PC, en `motor_v2/laboratorio_partido.tscn` con `semilla=20261225 saltar=3380` (gol de chilena al minuto 17). El jugador gira en el aire y la pelota sale hacia el arco. Un compañero tapa el pie en esa toma: el contacto del pie con la pelota no se pudo confirmar.
- **Prueba de regresión:** `tests/test_chilena_v2.gd`. `tests/test_remate_de_espaldas_v2.gd` no cuenta las chilenas como remates de espaldas sin permiso.
- **Pedido del usuario:** informar cuáles de los tres remates existen y cuáles se ven en el partido.

### BUG-014 — El jugador entra corriendo al arco con la pelota y el arquero no hace nada

- **Estado:** corregido el 2026-10-05 en el motor. Falta la revisión visual en el teléfono.
- **Causa:** el arquero no tenía ninguna regla para la pelota que un rival lleva cerca de él.
  - `Canchita::_analizar` lo manda a la pelota solo si llega antes que el rival más rápido. A la pelota que lleva un rival no llega nunca antes.
  - `Canchita::_ubicar_arquero` lo para a 0,15 m de su línea por cada metro que la pelota está del arco. En el mano a mano achica, pero nunca a menos de 4 m de la pelota (`achique_margen_pelota`). El arquero volvía a su línea a medida que el rival se acercaba.
- **Corrección:** salida a los pies (`Canchita::_pensar_jugador`, `motor_v2/cpp/src/canchita.cpp`). El arquero va a la pelota que un rival lleva en su área a menos de `achique_margen_pelota` (4 m) de él. Se tira con `Atajar_Abajo` cuando las manos llegan a la pelota. La agarra, la da en rebote o no llega: nadie adjudica la pelota.
- **Corrección del gesto:** la atajada frena al arquero. `Canchita::_gatillo` contaba su velocidad entera: el arquero que salía corriendo se tiraba 0,4 a 0,6 m antes de llegar. Ahora cuenta la frenada. A los pies del que lleva la pelota el arquero no suma `salida_error_m`.
- **Medición:** 120 partidos por división, semilla 97000. Llegada: un rival lleva la pelota a menos de 8 m del medio del arco. Llegadas que terminan con la pelota en las manos del arquero o tocada por él: 16 de 174 → 34 de 167 en primera, 4 de 127 → 19 de 146 en quinta, 0 de 89 → 9 de 98 en décima.
- **Lo que no cambia:** goles por partido 2,23 → 2,19 en primera, 2,08 → 2,11 en quinta, 1,72 → 1,74 en décima. Salidas falladas por partido: 0,42 → 0,40, 0,28 → 0,29 y 0,17 → 0,18. Quites por partido: 15,35 → 15,20 y 13,17 → 12,81.
- **Calibración:** `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000. Goles por partido: primera 2,36 → 2,44, quinta 1,95 → 2,04, décima 1,77 → 1,78, primera contra cuarta 2,76 → 2,72, quinta contra octava 2,82 → 2,66. Con la semilla 20261001 y 200 partidos, quinta contra octava da 2,81 → 2,84.
- **Probado y descartado:** contar la frenada en todos los gestos que frenan al jugador (la barrida, el cabezazo). En quinta los quites pasaban de 13,2 a 14,9 por partido y los goles de 2,08 a 1,94.
- **No sigue al que se aleja (2026-10-05):** el arquero no sale a los pies del rival que se aleja del medio del arco (`Canchita::_pensar_jugador`). Vuelve a su lugar (`Canchita::_ubicar_arquero`). Antes lo seguía hasta el borde del área grande.
  - Medición: 300 partidos por división, semilla 97000. Episodio: el rival lleva la pelota en el área a menos de 4 m del arquero. Episodios en que el arquero y la pelota terminan 2 m más lejos del arco: 15 → 0 en primera, 7 → 0 en quinta, 3 → 1 en décima.
  - Tiempo con los dos alejándose del arco: 0,14 → 0,04 s por partido en primera, 0,11 → 0,03 en quinta. Lo que queda es lo que el arquero tarda en frenar.
  - Costo: el arquero corta menos llegadas. 75 de 422 → 65 de 424 en primera, 49 de 365 → 37 de 369 en quinta, 18 de 225 → 15 de 234 en décima. Las que pierde son del rival que ya se iba.
  - Lo que no cambia: goles por partido 2,26 → 2,28 en primera, 2,23 → 2,25 en quinta, 1,69 → 1,69 en décima. Salidas falladas: 0,41 → 0,39, 0,29 → 0,28 y 0,16 → 0,16.
  - Calibración: `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000. Goles por partido: primera 2,44 → 2,47, quinta 2,04 → 1,97, décima 1,78 → 1,77, primera contra cuarta 2,72 → 2,77, quinta contra octava 2,66 → 2,67.
  - Probado y descartado: seguirlo igual si la pelota está más cerca del arco que el arquero (66 llegadas cortadas en primera contra 65). Seguir al que se aleja a menos de 30 grados de la tangente: corta lo mismo (65) y el arquero se va con el rival 2 veces en primera y 5 en quinta.
  - Revisión visual: hecha en la PC, en `motor_v2/laboratorio_partido.tscn` con `semilla=20261307 saltar=3018`. El rival se lleva la pelota del área chica hacia el punto del penal. El arquero queda entre la pelota y el arco, cerca de su línea.
- **La falta del arquero (2026-10-05):** el arquero que se tira a los pies hace falta si las manos llegan al rival antes que a la pelota (`Canchita::_resolver_toques`). Es la misma regla de la barrida. La falta es penal: el arquero sale a los pies solo en su área.
  - Pedido del usuario: el penal sale más veces con el arquero malo; el arquero bueno quita mejor de los pies.
  - El atributo: `achique`. El radio de la falta es `falta_radio_m` × (1 + `falta_torpeza`) × (1 − `achique` / 100). El arquero de `achique` 100 no hace falta.
  - Medición: 300 partidos por división, semilla 97000. Faltas del arquero por partido: 0 → 0,060 en primera, 0 → 0,060 en quinta, 0 → 0,007 en décima. Penales por partido: 0,137 → 0,190, 0,157 → 0,210 y 0,137 → 0,140.
  - Lo que no cambia: goles por partido 2,28 → 2,31 en primera, 2,25 → 2,26 en quinta, 1,69 → 1,69 en décima. Llegadas cortadas: 65 → 62, 37 → 35 y 15 → 14. Rojas: 6 → 6, 7 → 7 y 15 → 15.
  - Según el atributo: 600 partidos por división, un arquero con 20 puntos de `achique` de más y el otro de menos. Faltas del mejor y del peor: 6 y 28 en primera, 2 y 18 en quinta, 1 y 5 en décima. Llegadas que corta el mejor y el peor: 65 de 423 y 27 de 397 en primera, 41 de 332 y 23 de 332 en quinta.
  - Calibración: `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000. Goles por partido: primera 2,47 → 2,48, quinta 1,97 → 1,96, décima 1,77 → 1,77, primera contra cuarta 2,77 → 2,81, quinta contra octava 2,67 → 2,68.
  - Probado y descartado: el radio de la barrida, `falta_radio_m` × (1 + `falta_torpeza` × torpeza). El `achique` casi no pesaba: en 1.800 partidos el mejor arquero del partido hacía 56 faltas y el peor 67. Las faltas eran 0,093 por partido en primera y los penales 0,220.
  - Tarjeta: el arquero puede ver una amarilla. No ve roja ni segunda amarilla (`Canchita::_tarjeta`): el equipo sin arquero no está resuelto.
  - Revisión visual: hecha en la PC, en `motor_v2/laboratorio_partido.tscn` con `semilla=20261346 saltar=7394`. El arquero sale al rival en el área chica y el rival patea el penal. Un jugador tapa al arquero en esa toma: el gesto de tirarse no se pudo confirmar.
- **Prueba de regresión:** `tests/test_arquero_a_los_pies_v2.gd`. En 120 partidos de primera con 40 puntos de `achique` de diferencia, el arquero peor hace 7 faltas y el mejor ninguna; las 7 son penal. En 60 partidos de quinta el arquero corta 6 llegadas (10 cuando seguía al que se aleja); con la biblioteca anterior a BUG-014, 2. Cuenta también las muestras con el arquero y la pelota alejándose del arco: 34 (119 cuando lo seguía).
- **Revisión visual:** hecha en la PC, en `motor_v2/laboratorio_partido.tscn` con `semilla=20261236 saltar=10600`. El arquero sale del arco y sigue al que lleva la pelota. Las capturas no muestran el gesto de tirarse: no se pudo confirmar.
- **Caso de referencia:** no se pudo reproducir. El partido de referencia en la PC ya no tiene un gol al minuto 32: el motor cambió desde que el usuario lo miró.
- **Pendiente:**
  - Los remates desde menos de 6 m casi no cambian: 0,54 → 0,50 por partido en quinta, y 6 de cada 10 son gol. La llegada dura menos de 1 s y el rival remata antes de que el arquero llegue.
  - El arquero no se va expulsado. Falta resolver quién ataja cuando el equipo queda sin arquero.
- **Observado:** el jugador entra corriendo al arco con la pelota y el arquero no hace nada.
- **Caso para reproducir:** gol del minuto 32 del partido de referencia.

### BUG-015 — Pregunta: el rival domina más de lo que el plantel justifica

- **Estado:** respondido el 2026-10-04; la causa se corrige en BUG-010.
- **Respuesta:** no estaba justificado. En el partido de referencia el rival tiene 4,9 puntos más de media (80,7 contra 75,8) y 7,6 puntos más de modificadores de equipo (localía y otros). Con eso el motor le daba 31% más de punta y de aceleración, y al equipo del usuario 31% menos: corría al doble.
- **Observado:** el usuario no tiene un equipo malo y siente que el rival lo pasa por arriba.
- **Pedido del usuario:** comparar los dos planteles del partido de referencia y decir si el dominio del rival está justificado por los atributos.

### BUG-016 — El arquero hace el pase con las manos de espaldas

- **Estado:** corregido el 2026-10-05 en el motor. Falta la revisión visual en el teléfono.
- **Causa:** `Canchita::_decidir_saque_de_manos` arrancaba `Arquero_Lanza` o `Arquero_Voleo` con el arquero mirando hacia donde había agarrado la pelota. El gesto traba el rumbo del cuerpo. La pelota salía hacia el receptor y el cuerpo quedaba para otro lado.
- **Corrección:** el arquero elige adónde la manda, mira hacia ahí (`Cuerpo::mira`) y el gesto arranca cuando le faltan menos de 3° (`MANO_DE_FRENTE_RAD`, `Canchita::avanzar` en `motor_v2/cpp/src/canchita.cpp`). El tope de espera es lo que tarda en dar media vuelta con su `giro`.
- **Medición:** 120 partidos por división, semilla 97000. Ángulo entre el rumbo del arquero y la salida de la pelota, mediana: 71° → 2° en primera, 71° → 3° en quinta, 72° → 5° en décima. Saques a más de 90°: 19 de 68 → 0 de 68, 22 de 72 → 0 de 82 y 18 de 50 → 0 de 48. Lo que queda es el error del pase; el peor es 21°.
- **Lo que cambia:** el arquero tiene la pelota 0,1 a 0,2 s más: 2,03 → 2,15 s en primera, 1,98 → 2,20 en quinta, 1,94 → 2,14 en décima.
- **Lo que no cambia:** goles por partido 2,37 → 2,47 en primera, 2,28 → 2,23 en quinta, 1,63 → 1,69 en décima. Saques con la mano por partido: 0,57 → 0,57, 0,58 → 0,67 y 0,42 → 0,40.
- **Prueba de regresión:** `tests/test_arquero_saca_de_frente_v2.gd`. En 15 partidos de quinta ningún saque sale a más de 30° del rumbo del arquero (el peor, 7°). Con la biblioteca anterior, 5 de 7.
- **Revisión visual:** hecha en la PC, en `motor_v2/laboratorio_partido.tscn` con `semilla=20261218 saltar=6890`. El arquero agarra de frente a la cámara, gira 159° y saca de espaldas a la cámara, hacia donde va la pelota.
- **Observado:** la animación del saque con las manos se ve con el arquero de espaldas a la dirección del pase.

### BUG-017 — El sustituido y el lesionado salen lento y por el lugar equivocado

- **Estado:** corregido el 2026-10-05 en el motor. Falta la revisión visual en el teléfono.
- **Causa:** el que salía iba a la banda más cercana (`Canchita::_cambiar` y `Canchita::_quitar`, `motor_v2/cpp/src/canchita_reglas.cpp`). La mitad de las veces salía por la banda de arriba. El cambiado corría a 0,7 de su punta y el lesionado a 0,5, los dos con el cansancio del partido.
- **Corrección:** `Canchita::_saliente` arma al que se va. El cambiado, el lesionado y el expulsado salen por el medio de la banda de la cámara (`Canchita::_banda_cambios`). Primero van al medio de la banda, sobre la raya, y ahí cruzan. El que entra espera en la misma banda: antes entraba siempre por -z, que en el primer tiempo es la banda de arriba.
- **Velocidad:** el cambiado sale a `reglas.salir_ms` (9 m/s) y el lesionado a `reglas.salir_lesionado_ms` (7,5 m/s), de `data/fisica_v2.json`. La velocidad es fija: no depende de la velocidad ni de la energía del jugador. El expulsado no cambia.
- **Medición:** 40 partidos por división, semilla 97000. Cambiados que salen por la banda de abajo: 60 de 130 → 132 de 132 en quinta, 66 de 133 → 133 de 133 en primera. Distancia del medio al cruzar la raya: 25,6 → 1,4 m en quinta, 26,7 → 1,4 m en primera.
  - Velocidad media del cambiado: 3,9 → 7,8 m/s en quinta, 4,7 → 7,9 m/s en primera.
  - Tiempo hasta cruzar la raya: 6,3 → 5,9 s en quinta, 4,9 → 6,0 s en primera. El jugador corre el doble de rápido y recorre el doble: 24,6 → 46,0 m en quinta, 23,0 → 47,4 m en primera.
  - El más lento: 10,0 → 9,2 s en quinta, 8,6 → 9,1 s en primera.
  - Lesionados (2 antes y 1 después en quinta, 2 y 3 en primera): 12,6 → 10,0 s y 9,8 → 9,0 s, contando el tiempo en el piso. Son pocos casos: el número es una guía.
- **Calibración:** `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000. Goles por partido: primera 2,46 → 2,53, quinta 2,03 → 2,04, décima 1,66 → 1,76, primera contra cuarta 2,79 → 2,69, quinta contra octava 2,66 → 2,83. El error de cada número es 0,11 a 0,17.
- **Revisión visual:** hecha en la PC, en `motor_v2/laboratorio_reglas.tscn` con `solo=lesión`. El lesionado cruza la cancha corriendo y sale por el medio de la banda de abajo. El cambio por cansancio no se revisó en capturas.
- **Prueba de regresión:** `tests/test_reglas_v2.gd`. Los que se van cruzan la raya por la banda de la cámara, a menos de 10 m del medio, y llegan a 7 m/s.
- **Test de BUG-014 corregido:** `tests/test_arquero_a_los_pies_v2.gd` falló después de este cambio. Pedía 5 llegadas cortadas en 60 partidos y dieron 4 (antes 6). Era ruido: en 300 partidos son 28 antes y 29 después. El test pasa a 600 partidos.
  - Con 600 partidos el arquero corta 68 de 682 llegadas. Sin la salida a los pies corta 43 de 682. El test pedía menos de la mitad: con 60 partidos daba 2 y 6. Ahora pide menos llegadas cortadas sin la salida.
- **Pendiente:**
  - El cuarto árbitro no existe en la vista. Nadie espera en el medio de la banda con el tablero (`Utileria3D.tablero`).
  - El saque espera lo mismo que antes. Para bajar la espera, subí `reglas.salir_ms`: no hace falta rearmar las bibliotecas.
- **Pedido del usuario:** el jugador que sale por cambio o por lesión se va más rápido. Sale por el medio de la banda de abajo, donde va el cuarto árbitro con los cambios.

### BUG-018 — El que corre rápido pasa de largo y no se lleva la pelota

- **Estado:** corregido el 2026-10-06 en el motor. Falta la revisión visual en el teléfono. Falta recalibrar el balance (ver "Balance").
- **Regla que pidió el usuario:** la pelota no queda atrás del que la lleva ni del que llega a buscarla, salvo por un mal control atado a los atributos. Los goles y las estadísticas se ajustan después.
- **Episodio que se mide:** el de BUG-009 (`tests/test_pelota_atras_v2.gd`). El último que la tocó corre a más de 2 m/s alejándose, la pelota va a menos de 2,5 m/s y queda a más de 0,9 m detrás, 0,15 s o más.
- **Causa 1, el control:** el toque de control mandaba la pelota hacia donde el jugador la quería (`Canchita::_orientar`) y la rapidez contaba solo lo que corría hacia ahí. El que llegaba a 8 m/s y la paraba a 60 grados la dejaba casi quieta. **Corrección:** el control suma lo que el cuerpo sigue corriendo, con la misma cuenta del toque de conducción (`acompanar`, `motor_v2/cpp/src/canchita.cpp`). El error del control se aplica después: el que controla mal la sigue mandando lejos. `toque.control_inercia` 1.
- **Causa 2, el ritmo:** la pelota salía al ritmo de conducción que pide el cerebro (hasta 75% de la punta, a veces 35%). El que venía a 8 m/s la tocaba a 3,6 m/s y seguía 2 m de largo. **Corrección:** `acompanar` también suma lo que el cuerpo corre de más hacia adelante mientras frena.
- **Causa 3, la raya:** el que lleva la pelota llegaba a la raya a 6 u 8 m/s. A menos de 2 m de la raya el toque manda la pelota de vuelta a la cancha: salía casi quieta y él seguía de largo. La mitad era contra la línea de fondo: el que corría solo hacia el arco. **Corrección:** el que lleva la pelota frena antes de la raya, el cuerpo y el toque (`Canchita::_tope_de_raya`).
- **Causa 4, el plan:** el plan del que la lleva buscaba el punto de encuentro a su ritmo de conducción. Con la pelota a sus pies pero más rápida que ese ritmo, el punto quedaba 4 s después, a 15 m. El gesto salía igual, porque tenía la pelota al pie, con el toque planeado para ese punto: hacia atrás y casi quieto. **Corrección:** el que la lleva planea tocarla apenas puede y llega a tiempo, no antes (`Canchita::_plan_tocar`). `Canchita::_alcance` informa si la alcanza.
- **Causa 5, pecho y muslo:** el control de pecho o de muslo salía 30% más lento. **Corrección:** el que viene corriendo se la lleva a la rapidez entera.
- **Causa 6, el regate:** el regate no acompaña al cuerpo. El que encaraba a 8 m/s con la salida a 50 grados seguía 1,5 a 3 m. **Corrección:** el que corre mucho para el costado abre menos la salida (`Cerebro::_salida_de_regate`, `REGATE_COSTADO_MS` 5).
- **Medición:** 200 partidos por división, semilla 97000, episodios por partido. Todos los toques: 3,21 → 0,87 en quinta y 4,63 → 0,80 en primera. Después de un toque de conducción: 1,72 → 0,27 y 2,31 → 0,33. Después de un control: 0,83 → 0,01 y 1,60 → 0,07.
- **Lo que queda en esa cuenta:** la pelota que rebota en las piernas de un rival, la barrida (el que barre sigue deslizando) y el que da un pase corto y sigue corriendo. Sin esos tres casos quedan 0,17 por partido en quinta y 0,11 en primera; la mitad son regates.
- **Balance:** `tests/_diag_calibracion_v2.gd`, 100 partidos por escenario, semilla 97000, media de las diez divisiones parejas (motor espacial entre paréntesis). Goles 2,05 → 1,82 (1,99). Remates 6,25 → 5,22 (6,80). Faltas 2,53 → 1,81 (2,56). Amarillas 0,98 → 0,66 (1,11). Pases 50,7 → 53,2 (45,3). Ningún escenario pasa la calibración; antes pasaban 5 de 16. Los regates bajan de 6,2 a 5,9 por partido.
- **Pendiente:** recalibrar goles, remates y faltas. Los regates que quedan (unos 10 en 200 partidos): el cuerpo cambia de rumbo entre la decisión y el toque.
- **Otro caso medido, sin corregir:** el defensor que va a quitarla y sigue de largo sin hacer ningún gesto. Pasa 0,16 veces por partido en quinta y 0,32 en primera (200 partidos, semilla 97000; una de cada cuatro es un compañero que cruza por casualidad). Casi todas son entradas ya decididas: el que lleva la pelota la mueve y el defensor pasa. Mandarlo a contener (`Canchita::_contener`) no lo arregla: pasa igual por al lado de la pelota para ponerse del lado de su arco.
- **Probado y descartado:** `toque.control_inercia` 0,5 (quedaban 0,28 y 0,77 episodios después de un control). Aplicar el error del control antes de la cuenta: el mal control deja de pesar. Acompañar solo sin un rival cerca: los episodios casi no bajan, porque pasan con el rival a 2-6 m. `REGATE_COSTADO_MS` 3,5 sin achicar la salida: quedan la mitad de los regates.
- **Pruebas:** `tests/test_pelota_atras_v2.gd`. `CanchitaV2Nativa.get_ultimo_tipo` informa el tipo del último toque. `tests/test_arquero_a_los_pies_v2.gd` cuenta las faltas del arquero en 360 partidos (antes 120): el que lleva la pelota llega más despacio y hay menos. `tests/test_chilena_v2.gd` lee también los atributos del banco. `tests/test_motor_v2_puente.gd` suma los goles de penal a los tiros.
- **Observado:** algunos jugadores llegan a la pelota tan rápido que la pasan de largo sin tomarla. Jugadores que corren solos al arco y la pelota les queda seca atrás.
- **Relacionado:** BUG-009 y BUG-010.

### BUG-019 — Pregunta: hay tiros con efecto

- **Estado:** pregunta sin responder.
- **Pedido del usuario:** informar si los remates tienen efecto (curva de la pelota en el aire).

### BUG-020 — Faltan tres regates y la salida hacia la derecha

- **Estado:** anotado el 2026-10-05, sin empezar. Sale de BUG-012.
- **Pedido del usuario:** agregar la bicicleta, la ruleta y el sombrerito.
- **Qué hay hoy:** elástica y croqueta (`toque.clips_regate` de `data/fisica_v2.json`, `TipoRegate` de `motor_v2/cpp/src/toque.h`). Los clips `Regate_Bicicleta`, `Regate_Ruleta` y `Regate_Globito` existen en el modelo, sin cuadro de contacto. El relato ya conoce los cinco nombres (`RelatoPartido._nombre_regate`).
- **Por qué no entraron:** en el Motor V2 un gesto toca la pelota una sola vez, en el cuadro de contacto del clip. Ninguno de los tres se probó: la causa sale de leer los clips en `tools/blender/animaciones_jugador.py`.
- **Bicicleta:** las piernas pasan alrededor de la pelota sin tocarla. El único toque es la salida, a los 1,17 s de un clip de 1,5 s. Con el rival a menos de 4 m la pelota rueda suelta todo ese tiempo. Hace falta que el amague empiece antes del toque: el rival se lo come al arrancar el gesto y la pelota sigue con el que encara hasta la salida.
- **Ruleta:** el jugador pisa la pelota con un pie, gira 360° y la pisa con el otro. Hacen falta dos contactos en un gesto y que el cuerpo del motor gire con el clip. Hoy gira solo el modelo.
- **Sombrerito:** la pelota pasa por arriba del rival. Hace falta un toque de regate con elevación y que el mismo jugador la reciba en el aire del otro lado. El toque de conducción solo la manda por el piso.
- **Salida hacia la derecha:** la elástica y la croqueta cruzan la pelota del pie derecho al izquierdo y el modelo no se espeja. La pelota sale siempre hacia la izquierda del que encara (`Cerebro::_salida_de_regate`). Hacen falta los clips espejados en Blender.
- **Al agregar cada uno:** poner el cuadro de contacto en `tools/medir_clips_v2.gd` y regenerar `data/acciones_v2.json`; sumar el tipo en `TipoRegate`, en `toque.clips_regate` y en `MotorV2.REGATES`; medir con `tests/_diag_regates_v2.gd` y `tests/_diag_calibracion_v2.gd` antes y después; ampliar `tests/test_regate_v2.gd`.
