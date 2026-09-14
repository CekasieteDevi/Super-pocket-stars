# Plan de implementación: más realismo en la simulación

Fecha: 2026-09-10. Destinatario: Opus 5 Medium.
Estado: propuesta técnica; ninguna de estas ampliaciones está implementada por este documento.

## Encargo para el agente

Implementar las nueve mejoras de este documento, por etapas. Leer primero el código vigente y las instrucciones del repositorio. Extender los mecanismos existentes. Mantener el partido compacto y legible. Completar implementación, pruebas, mediciones y documentación. No limitarse a proponer otro plan.

Antes de editar, revisar `git status` y conservar cambios ajenos. Actualizar la lista de avance al terminar cada etapa. Si una sesión termina, dejar archivos tocados, verificaciones realizadas y siguiente paso concreto en este documento. No marcar una etapa terminada sin evidencia.

## Base existente y archivos

- `core/motor_espacial.gd`: simulación espacial, decisiones, movimiento, pelota, remates y reanudaciones.
- `data/utility_pesos.json`: parámetros del motor. Agregar aquí los ajustes calibrables, con valores por defecto compatibles en el lector.
- `core/team.gd`: jugadores, resistencia, cambios y contexto del equipo.
- `core/estilos.gd`: identidad de los estilos. Inspeccionar también los sistemas de roles y personalidad antes de añadir perfiles.
- `core/match_engine.gd`: motor abstracto definitivo para otros partidos; referencia de balance y proveedor de modificadores compartidos.
- `docs/motor_espacial.md` y `docs/identidad_tactica.md`: arquitectura e implementación táctica previa.
- `ui/cancha.gd` y `ui/partido_visual.gd`: representación de fotogramas. Verificar sus contratos antes de extenderlos.

Ya existen paredes, pases al hueco, apoyos triangulares, desdobles, segundo palo, transiciones, presión con varios jugadores, control con demora según atributo, rebotes, salidas del arquero y remates sensibles a geometría. Las nueve etapas deben profundizarlos; no agregar versiones paralelas del mismo comportamiento.

Los nombres de funciones citados existen al redactar el plan. Los nuevos nombres y campos son propuestas. Confirmar firmas, unidades y convenciones antes de implementar.

## Invariantes

1. Mantener los dos motores. No reescribir el abstracto ni ajustar sus constantes para esconder cambios de balance del espacial.
2. Misma semilla y equipos equivalentes deben producir mismos eventos y estadísticas con y sin fotogramas. El render no decide ni consume azar de simulación.
3. Usar exclusivamente el RNG del estado. Orden estable por clave de jugador para desempates y asignaciones.
4. Usar `TICK_SEG` para movimiento y tiempos breves. El minuto de partido sirve para el contexto del marcador. No confundir cuatro minutos de simulación con noventa minutos de esfuerzo físico.
5. No teletransportar jugadores. Respetar velocidad, aceleración, límites, expulsiones, lesiones, cambios y reanudaciones.
6. Mantener contratos de goles, eventos, asistencias, XP y estadísticas. Los campos nuevos deben ser opcionales para consumidores y fotogramas antiguos.
7. No leer resultados futuros, destino secreto de la próxima decisión ni usar resultados forzados del laboratorio en partidos normales.
8. No introducir nuevos datos persistidos si pueden derivarse de atributos, roles y estado del partido.

## Etapa 0: línea de base y observabilidad

- Ejecutar primero las pruebas existentes relacionadas con el motor. Registrar fallos previos por separado.
- Reutilizar `tests/_diag_identidad_tactica.gd` y `tests/_diag_goles_motores.gd`. Preparar `tests/_diag_realismo.gd` con semillas fijas y salida CSV o JSON.
- Comparar divisiones 1, 5 y 10; equipos parejos y desparejos; ambos lados; estilos diferentes. Usar equipos nuevos para cada corrida: la simulación modifica `Team`.
- Medir goles, remates, posesión, pases, pérdidas, duración de posesiones, recuperaciones altas, faltas, tarjetas, cansancio y tiempo de ejecución. Registrar definición y denominador de cada métrica.
- Separar juego abierto de pelota parada. Medir posesión controlada y tiempo de pelota libre por separado.
- Agregar contadores opcionales de diagnóstico al estado; activarlos no debe cambiar decisiones ni RNG. No guardar trazas grandes en cada fotograma de producción.
- Guardar configuración, semillas, cantidad de partidos y revisión de código con cada informe.

## Etapa 1: juego sin pelota

Puntos de integración: `_objetivo_sin_pelota`, `_buscar_apoyo`, `_punto_al_hueco`, `_punto_retorno_pared`, `_actualizar_transicion`, `_ponderar_plan`.

Implementación:

1. Agregar a cada jugador una intención temporal: tipo, destino, compañero relacionado y tick de vencimiento. Tipos iniciales: apoyo, ruptura diagonal, arrastre y llegada desde atrás. Usar las paredes existentes.
2. Cada cuatro ticks de juego abierto, calcular candidatos desde la misma instantánea de posiciones. Evaluar línea de pase libre, distancia útil al poseedor, progresión, espacio al llegar, rol y posición legal.
3. Asignar candidatos en orden estable. Penalizar destinos a menos de cuatro metros de otro apoyo ya asignado. Reservar al menos un apoyo de seguridad y evitar que todos rompan al mismo tiempo.
4. Mantener intención durante cuatro a doce ticks como punto de partida. Cancelar por pérdida, interrupción, sustitución, expulsión o destino inviable. Revalidar legalidad cada tick.
5. El arrastre mueve al atacante; el defensor decide si acompaña según su marca y zona. Nunca mover artificialmente al defensor para que la combinación funcione.
6. El pasador de una pared corre hacia el retorno existente. La devolución vuelve a evaluarse: un rival puede cerrar el pase.
7. La segunda línea llega cuando un compañero fija la última línea y existe un carril libre. No abandonar simultáneamente todas las coberturas.

Verificación: escenas en ambos sentidos con defensor que tapa el apoyo inicial; dos receptores no convergen al mismo punto; una pared puede abortarse; una pérdida cancela rupturas; respetar offside al ejecutar el pase. Extender `test_movimiento_sin_pelota.gd` y `test_identidad_tactica.gd`.

## Etapa 2: defensa coordinada

Puntos de integración: `_perseguidores`, `_objetivo_de_presion`, `_punto_de_presion`, `_objetivo_sin_pelota`, `_calcular_linea_offside`.

Implementación:

1. Calcular una asignación defensiva compartida por equipo: presionante, cobertura, cierre de línea y bloque. No volver a elegir responsabilidades independientemente por jugador.
2. Elegir presionante por tiempo estimado de llegada: distancia / velocidad disponible, más penalización por abandonar zona y cansancio. Excluir jugadores no disponibles y en tránsito.
3. Elegir cobertura entre quienes quedan; ubicarla detrás del presionante hacia el arco propio. Un tercero cierra una línea de pase distinta si el estilo lo permite.
4. Mantener asignaciones al menos cuatro ticks salvo pérdida de validez. Cambiar presionante si el nuevo candidato mejora el tiempo de llegada al menos un 20%; valores iniciales calibrables.
5. El bloque restante bascula lateralmente, mantiene separación entre líneas y protege el centro. Limitar cuánto puede alejarse cada rol de su zona.
6. Añadir disparadores de presión: control largo observado, receptor de espaldas y pelota junto a banda. No conocer qué acción elegirá el rival.
7. Tras pérdida, usar la transición existente: jugadores cercanos pueden presionar brevemente; si no hay cobertura o se supera la presión, replegar.

Verificación: un presionante principal, cobertura distinta y carriles separados; estabilidad sin intercambio constante; pase que supera presión provoca repliegue; funcionamiento con diez jugadores. Medir recuperaciones altas y distancia entre líneas, sin exigir que presión alta gane más partidos.

## Etapa 3: control y orientación corporal

Puntos de integración: `_mover_hacia`, `_avanzar_pelota`, `_entregar_pelota`, `_decidir_y_ejecutar`, `_lanzar_pase`.

Implementación:

1. Agregar orientación corporal normalizada, control pendiente y tick de habilitación de acción. Inicializar también al entrar suplentes y reiniciar jugadas.
2. Girar con velocidad angular limitada por agilidad. Si está quieto, conservar orientación o girar deliberadamente hacia pelota/objetivo; evitar normalizar vectores nulos.
3. Al llegar un pase, capturar velocidad y dirección de llegada antes de sobrescribir el estado de pelota. Calcular dificultad con velocidad, altura disponible, presión y ángulo corporal.
4. Reemplazar la demora equivalente ya existente por una sola demora de control; no sumar ambas penalizaciones. Más control reduce demora y dispersión.
5. Resolver una vez por recepción la calidad del toque con RNG del partido. Un control malo deja pelota libre con trayectoria corta; no adjudicar automáticamente la posesión al rival.
6. Reutilizar movimiento e intercepción de pelota libre. El receptor puede recuperar su toque largo. Evitar repetir la tirada en cada tick de contacto.
7. Pase de primera permitido si recepción y dirección son compatibles; girar 180 grados exige tiempo. Preservar remates de primera y cabezazos como rutas específicas.
8. Si la vista admite orientación, incluir campo opcional en fotograma y fallback para fotogramas anteriores.

Verificación: recepción frontal frente a recepción de espaldas con la misma situación; pase fuerte frente a suave; control alto mejora distribución de resultados en muchas semillas; pelota mal controlada sigue disputable; no aparecen posesiones duplicadas ni bloqueos permanentes.

## Etapa 4: ritmo variable

Puntos de integración: `_ponderar_plan`, `_decidir_y_ejecutar`, `_actualizar_transicion` y evaluación de opciones existente.

1. Añadir fase por equipo: circulación, aceleración o transición. Estimarla por espacio, presión, apoyos y oportunidad; conservar unos ticks para evitar oscilaciones.
2. Circulación aumenta utilidad de apoyos seguros y cambios de frente cuando progresar está cerrado. Aceleración favorece pase progresivo, conducción y ruptura cuando aparece ventaja.
3. Usar bonificaciones acotadas en las utilidades actuales. No imponer una secuencia ni bloquear opciones legales.
4. Pausar significa proteger/conducir con poca velocidad mientras siguen existiendo presión y robos; no congelar el partido.
5. Registrar progreso reciente de posesión. Si hay varias devoluciones sin presión ni ganancia, reducir utilidad de repetir la misma pareja de pases. Conservar una salida segura cuando avanzar sea inviable.

Verificación: rival cerrado produce circulación; carril liberado produce aceleración; no hay bucles eternos entre dos jugadores. Medir pases atrás sin presión aparte de devoluciones útiles.

## Etapa 5: cansancio por esfuerzo

Puntos de integración: `_mover_hacia`, `_cerrar_tick`, llamadas a `desgastar`, `Team.resistencia_pct` y procesamiento de cambios.

1. Inventariar primero todo el desgaste actual de duelos, tiros y tiempo. Elegir un único responsable por coste para evitar cobro duplicado.
2. Acumular distancia real recorrida y esfuerzo por jugador. Intensidad inicial: cuadrado de velocidad / velocidad máxima, más aceleración positiva normalizada. Integrar con `TICK_SEG`.
3. Agregar reserva breve de sprint, entre cero y uno. Se consume a intensidad alta y recupera caminando o parado. La fatiga acumulada sigue en el sistema actual de resistencia.
4. Aplicar desgaste acumulado mediante la API actual de `Team`; si hace falta ampliarla, conservar comportamiento de sus consumidores. Ajustar escala a la duración comprimida del partido.
5. Reserva baja reduce capacidad de sprint de forma gradual. Resistencia general sigue afectando ejecución por `Duel.atributo_efectivo`; no volver a aplicar idéntico multiplicador al resultado del duelo.
6. No gastar por animaciones, festejos ni pausas. Recuperación de entretiempo separada y acotada. Inicializar suplentes con su condición real, sin heredar la del sustituido.

Verificación: mismo jugador sprintando termina con menos reserva que caminando; caminar recupera reserva sin borrar fatiga acumulada; pausas no desgastan; cambios por cansancio siguen funcionando; ninguna resistencia sale de rango.

## Etapa 6: arqueros con decisiones

Puntos de integración: objetivo del ARQ en `_objetivo_sin_pelota`, `_resolver_centro`, `_resolver_tiro`, `_resolver_rebote`, `_dar_pelota_al_arquero`.

1. Comparar tiempo del arquero a un punto interceptable con tiempo de pelota y atacante. Añadir margen de reacción según atributos existentes. Salir solo si la ventaja compensa dejar el arco.
2. Introducir intención breve: sostener posición, achicar, interceptar o volver. Mover físicamente; no entregar pelota solo por haber decidido salir.
3. En centros, evaluar trayectoria visible y llegada posible antes del duelo existente. Estar dentro de un radio no basta para alcanzar un balón lejano en un tick.
4. En uno contra uno, avanzar sobre bisectriz entre pelota y postes, con distancia acotada. Usar posición efectiva al resolver el remate.
5. Para rechazos, evaluar direcciones hacia laterales y zonas menos amenazadas. Añadir dispersión por habilidad y dificultad, permitiendo rebotes peligrosos ocasionales.
6. Con pelota, elegir distribución usando el sistema existente de pases, presión y estilo. Respetar restricciones actuales del área y reanudaciones.

Verificación: alcanza una pelota favorable; no sale si llega después del atacante; salida fallida deja arco expuesto; recuperación de posición gradual. Extender `test_posicion_del_arquero.gd` y `test_salida_del_arquero.gd`.

## Etapa 7: contexto del marcador

Puntos de integración: `_ponderar_plan`, objetivos sin pelota y configuración defensiva compartida. Revisar modificadores del DT en `MatchEngine._bloques_equipo`.

1. Derivar urgencia continua del minuto, diferencia de goles y perfil del DT ya existente. Inicio: efecto pequeño; últimos minutos: efecto creciente. Definir también comportamiento en alargue.
2. Aplicarla a altura del bloque, cantidad de apoyos adelantados y tolerancia al riesgo. Topes para conservar identidad de estilo y formación.
3. Ganando al final: más apoyos seguros y coberturas. Perdiendo: más llegadas y presión, aceptando espacios detrás.
4. No dar bonificaciones artificiales a precisión, goles ni remontadas. El marcador cambia decisiones; los duelos conservan su resolución.
5. Evitar doble aplicación del efecto del DT: separar sus modificadores existentes de ejecución de estos cambios de comportamiento.

Verificación: comparar la misma escena en minuto temprano y tardío, ganando/empatando/perdiendo; medir altura y opciones arriesgadas; no exigir un ganador concreto.

## Etapa 8: identidad individual

Puntos de integración: evaluación de opciones, `_ponderar_plan`, `_objetivo_sin_pelota`, sistemas existentes de roles, habilidades y personalidad.

1. Construir al inicio del partido un perfil derivado: asociación, ruptura, regate, apoyo de espaldas y llegada. Reutilizar atributos/roles; evitar crear otro selector de puesto.
2. Normalizar preferencias a cero–uno y convertirlas en ajustes acotados de utilidad y candidatos de movimiento.
3. Extremo encarador favorece uno contra uno con espacio; nueve de apoyo ofrece descarga; volante llegador arranca detrás de la jugada. Un mal contexto puede hacerlos elegir otra acción.
4. Mantener separación entre preferencia y capacidad: preferir regate no concede éxito. Conservar personalidad y habilidades existentes sin sumar dos veces el mismo efecto.
5. Recalcular perfil al cambiar rol o entrar un suplente. No generar azar nuevo cada tick para construir identidad.

Verificación: cambiar solo un perfil/rol en escenarios equivalentes modifica frecuencias de elección en muchas semillas. Cada perfil conserva variedad y puede fallar.

## Etapa 9: calidad de ocasiones

Puntos de integración: `_resolver_tiro`, `_bloqueador_de_tiro`, `_lanzar_remate`, `_aplicar_remate` y estadísticas de salida.

1. Extraer una función pura que describa la ocasión antes de resolverla: distancia, ángulo visible entre postes, presión cercana, obstrucción, posición del arquero y tipo de remate. Reutilizar factores existentes.
2. Separar contexto de ocasión de habilidad del rematador. Si se registra una probabilidad que incluye habilidad, llamarla probabilidad del modelo; no presentarla como xG real validado.
3. Integrar el contexto una sola vez en destino/bloqueo/atajada. Auditar el orden actual: evitar penalizar al mismo defensor como presión, bloqueo y penalización adicional sin justificarlo.
4. Guardar valor previo al resultado en el evento o registro de remate. Registrar goles y tiros a partir del mismo identificador para evitar duplicados al animar/aplicar el remate.
5. Respetar rutas de penales, cabezazos, tiros libres y arcos vacíos. No cambiar probabilidades de toda la liga hasta medir el efecto.
6. Añadir al diagnóstico ocasiones por intervalos de calidad y conversión observada. Si se desea xG comparable con fútbol real, conseguir después una fuente documentada de eventos y calibrar; no inventar coeficientes supuestamente empíricos.

Verificación: en contextos controlados, ángulo abierto mejora calidad, presión la reduce y arquero fuera de posición deja mayor oportunidad. Misma ocasión conserva valor previo aunque el resultado aleatorio cambie. Estadísticas coinciden con remates registrados.

### Observado jugando, 2026-09-10: el tiro de lejos se abusa

**BUG-007 corregido el 2026-09-11.** El alcance solo habilita; la utilidad usa geometría común y la precisión depende de la dificultad y la técnica. Ver [implementación, pruebas y mediciones](mediciones/bug007_resultados.md). La etapa 9 completa sigue pendiente.

Reporte del usuario después de la etapa 1, mirando el partido animado:

- Lo bueno: se ven más jugadas.
- El problema: los jugadores con `tiro` alto le pegan de lejos todo el
  tiempo y entra. Tres goles así con Ocampo en 19 minutos.

El tiro de lejos tiene que ser UNA herramienta, no la jugada por
defecto. Y el que tiene tiro lejano bajo y lo intenta igual debe errar
mucho más que el que lo tiene alto.

**Causa, leída del código.** El atributo `tiro` hace dos trabajos que se
potencian en vez de compensarse:

1. Decide DESDE DÓNDE le da para patear. En `factor_geometria`
   (`core/motor_espacial.gd:546`) el rango sale de
   `_por_atributo(jugador, "tiro", rango_tiro_malo, rango_tiro_bueno)`:
   16 m para un `tiro` de 1 y 36 m para uno de 99. Ese `geo` entra
   directo en la utilidad de la opción `tiro`, así que más atributo es
   más CHANCES DE INTENTARLO de lejos. El comentario del peso lo dice:
   es la única palanca que mueve la distancia de remate.
2. Decide QUÉ TAN BIEN sale. El mismo `tiro` alimenta
   `chance_porteria` en `_resolver_tiro` y el duelo contra el arquero.

Un `tiro` alto entonces patea más seguido desde lejos Y convierte más.
No hay atributo separado de tiro lejano, ni de puntería: `punteria`
existe solo como peso del centro y `tiros_libres` solo para la pelota
parada.

Además, la caída de precisión con la distancia es IGUAL para todos.
`calidad = atributo_normalizado * peso_atributo + geo * peso_geometria`
suma los dos términos: la geometría le resta lo mismo al que sabe pegarle
y al que no.

Y nada penaliza la repetición: el mismo jugador puede intentarlo tiro
tras tiro sin que el motor lo note.

**Dirección propuesta.** Separar las dos cosas que hoy hace `tiro`:

- Alcance: hasta dónde LLEGA la pelota. Es físico y puede seguir
  saliendo de `tiro` o de `fuerza`.
- Puntería a esa distancia: cuánto se degrada la precisión con los
  metros. Debe depender del atributo, no ser una constante. O sea, que
  el término de geometría en `chance_porteria` escale con
  `(1 - atributo_normalizado)`: el que tiene tiro lejano bajo pierde
  precisión rápido al alejarse, el que lo tiene alto casi no.
- Revisar si el alcance tiene que seguir subiendo la UTILIDAD de
  intentarlo, o solo habilitarlo. Hoy sube las dos cosas.

**Antes de tocar nada, medir.** Con `tests/_diag_remates.gd` y la misma
semilla: remates y goles por tramo de distancia (0-11, 11-18, 18-25, 25+
m), cortados por tramo de atributo `tiro` del rematador. El síntoma a
mover es la conversión desde 25+ m de los jugadores de `tiro` alto. Los
goles totales por partido no deben moverse más del 15% (ver la línea de
base de la etapa 0).

Lo toma la etapa 9, que es la dueña de la calidad de ocasiones. El
punto 3 de esa etapa —«integrar el contexto una sola vez»— es
exactamente este problema visto desde el otro lado.

## Etapa 0: resultados (2026-09-10)

Estado: terminada. Archivos tocados:

- `tests/_diag_realismo.gd` (nuevo): el diagnostico de la linea de base.
- `core/motor_espacial.gd`: un campo nuevo en el fotograma, `detenido`.
  Es el unico cambio al motor de esta etapa. La vista lo ignora y los
  fotogramas viejos no lo traen, asi que se lee con `get()`.
- `docs/mediciones/base_realismo_etapa0.csv` (nuevo): la linea de base,
  un renglon por partido.

### Como se corre

```bash
<godot> --path . --headless --script tests/_diag_realismo.gd
<godot> --path . --headless --script tests/_diag_realismo.gd -- partidos=12 salida=user://base_etapa0
```

No es un test: no falla nunca, mide. Escribe CSV y JSON a `user://` y
el JSON guarda semilla, partidos por celda, revision de git, `TICK_SEG`
y los escenarios, como pide la etapa.

### Configuracion de la linea de base

- Semilla 77100; cada partido usa `77100 + indice * 13`.
- 12 partidos por celda, 14 celdas, 168 partidos. Cada uno se simula
  dos veces (sin fotogramas y con fotogramas): 336 simulaciones, 95 s.
- Siete escenarios: D1, D5 y D10 parejos, y desparejos para los dos
  lados (el local favorito y el local tapado).
- Dos cruces de estilos: Tiki taka/Juego directo y Presion alta/Contragolpe.
- El estilo se fija DESPUES de `Team.generar`, porque de ahi sale la
  formacion y pisarlo antes no cambiaria el plantel.
- Cada corrida arma planteles nuevos: la simulacion muta el `Team`.
- Revision medida: `b0b322c`, con el arbol de trabajo sucio (los cambios
  de vista, sprites y estadio que ya estaban sin commitear).

### Definicion y denominador de cada metrica

Todo es POR PARTIDO salvo donde el nombre dice `pct`.

| metrica | definicion | denominador |
| --- | --- | --- |
| `goles` | goles de los dos equipos | partido |
| `tiros` | `stats.tiros` de los dos | partido |
| `posesion_pct` | ticks con la pelota del local | ticks con dueño |
| `controlada_pct` | fotogramas de juego abierto con dueño | fotogramas de juego abierto |
| `pelota_parada_pct` | fotogramas con `detenido > 0` | fotogramas totales |
| `pases` | `stats.pases` de los dos | partido |
| `perdidas` | robos ganados + pases interceptados, alcanzados o afuera | partido |
| `posesiones` | cambios de equipo con la pelota, en juego abierto | partido |
| `duracion_posesion_seg` | ticks con dueño x `TICK_SEG` / posesiones | posesion |
| `recuperaciones_altas` | posesiones que arrancan en campo rival | partido |
| `faltas`, `penales`, `offsides` | los contadores de `stats` | partido |
| `amarillas`, `rojas` | `Team.amarillas_partido` y `expulsados_partido` | partido |
| `resistencia_final_pct` | media de `resistencia_pct` de los once iniciales | jugador |
| `recorrido_total_m` | `recorrido` de los 22 en el ultimo fotograma | partido |
| `ms_sin_fotogramas`, `ms_con_fotogramas` | reloj de pared de `simular` | partido |

Juego abierto y pelota parada se separan con el campo nuevo `detenido`.
Posesion controlada y pelota libre se separan con `poseedor_id`: sobre el
juego abierto, `controlada_pct` es la parte con dueño y el resto es
pelota libre, en vuelo o disputada.

### Linea de base medida

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas  falt  amar  roja resist     ms   msfg
D1 parejo      Tiki taka/Juego directo   1.67   8.6   49.9   53.0   17.2  42.9  15.5   3.24   6.92   2.1  1.08  0.00   94.5    399    453
D1 parejo      Presion alta/Contragolpe  1.58   8.9   52.2   52.5   15.5  41.0  14.1   3.56   5.42   1.5  0.83  0.00   93.2    365    428
D1 favorito    Tiki taka/Juego directo   5.08   9.4   56.5   54.1   26.5  43.6  16.9   3.11   6.58   2.8  1.08  0.17   91.8    332    372
D1 favorito    Presion alta/Contragolpe  5.00   9.8   58.4   55.8   26.6  36.0  16.2   3.41   5.75   3.1  1.75  0.25   90.2    327    378
D1 tapado      Tiki taka/Juego directo   3.42   9.2   47.5   51.9   23.5  41.0  15.2   3.02   6.83   2.7  1.00  0.00   92.9    343    380
D1 tapado      Presion alta/Contragolpe  4.17   9.8   50.7   55.7   26.3  36.5  19.4   3.04   8.08   3.2  1.67  0.17   90.4    325    368
D5 parejo      Tiki taka/Juego directo   1.83   7.8   49.2   54.2   21.3  45.4  17.8   3.08   8.08   1.9  0.75  0.00   91.2    351    403
D5 parejo      Presion alta/Contragolpe  2.83   7.4   53.4   59.2   22.4  38.8  19.9   3.46   6.42   2.9  0.75  0.00   87.9    345    389
D5 favorito    Tiki taka/Juego directo   4.50   8.9   55.6   59.2   28.7  44.3  22.2   2.96  10.58   3.1  1.00  0.00   87.3    333    370
D5 favorito    Presion alta/Contragolpe  5.00  10.2   57.3   61.2   30.2  33.0  20.8   3.11  10.50   3.3  1.33  0.17   86.7    323    370
D10 parejo     Tiki taka/Juego directo   1.50   7.2   51.8   62.1   24.0  42.9  23.0   3.34  10.33   2.7  1.17  0.00   84.1    346    392
D10 parejo     Presion alta/Contragolpe  2.25   7.0   52.8   66.8   24.6  33.6  23.0   3.78   8.50   3.0  1.08  0.00   80.8    331    385
D10 tapado     Tiki taka/Juego directo   3.00   7.8   47.4   61.5   25.7  40.8  23.0   3.25   9.00   2.7  1.17  0.00   86.1    350    406
D10 tapado     Presion alta/Contragolpe  2.17   7.9   49.7   62.5   27.0  31.7  23.2   3.32  10.17   2.9  1.50  0.00   83.6    331    370
```

Invariante 2: los 168 partidos dan el mismo marcador y los mismos
remates con y sin fotogramas. El render cuesta un 13% de tiempo extra
(332-453 ms contra 323-399 ms) y no cambia ninguna decision.

### Lo que ya muestra la base, antes de tocar nada

1. La pelota esta libre casi la mitad del juego abierto: `controlada_pct`
   va de 51,9% en D1 a 66,8% en D10. En primera la pelota pasa MAS tiempo
   sin dueño que en decima, al revas de lo que se esperaria. Es el numero
   que tiene que mover la etapa 3 (control y orientacion).
2. Una posesion dura 3,0-3,8 s. Son 12 a 15 ticks: alcanza para dos o tres
   acciones, no mas. Cualquier etapa que agregue pausa o circulacion se
   mide contra esto.
3. El desparejo pega en los goles, no en los remates. De D1 parejo a D1
   favorito los goles van de 1,6 a 5,1 (x3) y los remates de 8,6 a 9,4
   (+9%). La diferencia de nivel se cobra casi toda en la conversion. Es
   el sintoma que mira la etapa 9.
4. Los goles bajan con la division en los parejos (1,7 en D1 contra 1,5-2,3
   en D10) pero los remates tambien (8,6 a 7,1). Entre 1,5 y 2,8 goles por
   partido en parejos es un rango razonable; el problema esta en los
   desparejos, con 4,5-5,1.
5. La pelota parada se come del 15,5% al 30,2% del partido, y crece con el
   desparejo y con la division baja. Las faltas acompañan: 5,4 en D1 parejo
   contra 10,6 en D5 favorito.
6. El cansancio final va de 94,5% en D1 a 80,8% en D10, y solo depende de
   los duelos que se jugaron, no de cuanto corrio cada uno. Es lo que
   reemplaza la etapa 5.
7. Ningun partido corto una mitad con la jugada sin terminar
   (`mitades_cortadas` = 0 en los 168).

### Pendiente de esta etapa

- `test_movimiento_sin_pelota.gd` y `test_salida_del_arquero.gd` imprimen
  `OK:` pero no cierran con `FALLOS=n`. `correr_regresion.sh` gatea por
  `FALLA`, asi que hoy no pasa nada, pero se salen de la convencion de
  `CLAUDE.md` y conviene arreglarlos antes de extenderlos en la etapa 1.
- La falla previa de `test_laboratorio.gd` ("el clip del cabezazo tiene 0
  cabezazos") ya esta arreglada. La regla de cuando un centro ganado se
  remata de volea en vez de cabecearse estaba duplicada: el laboratorio
  elegia al mejor de arriba y el motor le hacia tirar una chilena. Ahora
  es una sola, `MotorEspacial.remata_de_acrobacia`, y el clip saltea a los
  acrobaticos al repartir el papel. La regresion completa queda en
  `ARCHIVOS_CON_FALLAS=0 de 111 en 339s`.
- `project.godot` perdio `window/size/viewport_width/height` y sus
  comentarios en un cambio sin commitear que no es de esta etapa. No lo
  toque; hay que decidir si se recupera.

## Etapa 1: resultados (2026-09-10)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Juego sin pelota: intenciones
  colectivas", el reparto enganchado al tick, `_objetivo_sin_pelota`
  partido en dos y la pared abortable.
- `data/utility_pesos.json`: seccion nueva `sin_pelota`.
- `tests/test_desmarques.gd` (nuevo): las diez comprobaciones de la etapa.
- `tests/test_movimiento_sin_pelota.gd`, `tests/test_salida_del_arquero.gd`:
  ahora cierran con `FALLOS=n`, que era el pendiente de la etapa 0.
- `docs/mediciones/realismo_etapa1.csv` (nuevo).

### Que hace ahora el motor

Cada jugador sin pelota lleva una INTENCION: tipo, destino, companero
relacionado y tick de vencimiento. Los cuatro tipos son `apoyo`,
`ruptura` (diagonal por detras de la ultima linea), `arrastre` (llevarse
al marcador fuera del carril) y `llegada` (segunda linea, solo si otro ya
fija la ultima linea y hay carril libre).

El reparto es del EQUIPO, no de cada uno:

- Corre una vez cada cuatro ticks, desde la misma instantanea de
  posiciones, antes de mover a nadie.
- Recorre las claves ordenadas. No toca el RNG del partido.
- Reserva primero un apoyo de seguridad; recien despues reparte corridas.
- Tope de dos corridas simultaneas (`MAX_RUPTURAS`).
- Penaliza un destino a menos de cuatro metros de otro ya asignado.
- Cada intencion dura entre 4 y 12 ticks, segun el tiempo de viaje.
- Se cancela por perdida, juego detenido, transito (cambio o expulsion),
  destino sin espacio o rol que cerro su objetivo. La legalidad se
  recorta contra la linea de offside en CADA tick.

Solo se le anotan intenciones al equipo que ataca. El arrastre mueve al
atacante y nada mas: al defensor no lo toca nadie, sigue decidiendo por
su marca.

La pared ya no se devuelve sola. Cuando el muro recibe, mira el carril de
retorno; si un rival lo cerro mientras viajaba el primer pase, la pared
se aborta y el muro decide como cualquier poseedor. En 60 partidos: 53
devueltas y 47 abortadas.

### Cambio estructural: `_ancla_de_rol`

`_objetivo_sin_pelota` se partio en dos. `_ancla_de_rol` devuelve donde lo
pone su ROL —casillero, pelota, estilo, repliegue, acompanamiento, hombro
del ultimo defensor— y `_objetivo_sin_pelota` le suma encima el desmarque
y el recorte de offside. El reparto necesita el ancla ANTES de elegirle
destino a cada uno, y llamar al objetivo completo seria circular.

El ancla devuelve tambien `listo`: el arquero y el delantero que baja a
recibir ya tienen objetivo final. A esos no se les reparte intencion —
anotarsela ocupaba el cupo del apoyo de seguridad sin que nadie la
leyera.

Esto costo una vuelta. La primera version armaba el apoyo como un anillo
a quince metros del poseedor y el equipo entero se derrumbaba sobre la
pelota: la posesion controlada subia (51,9% a 57,0% en D1) pero los
remates de D10 caian de 7,2 a 5,2 por partido, porque no quedaba nadie en
posicion de rematar. Anclado al rol, la profundidad se conserva.

### Medicion, contra la misma linea de base

Misma configuracion que la etapa 0: semilla 77100, 12 partidos por celda,
14 celdas, 168 partidos, cada uno simulado con y sin fotogramas.

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas  falt  amar  roja resist
D1 parejo      Tiki taka/Juego directo   2.92  10.1   49.4   53.6   20.2  45.2  14.7   3.14   6.00   2.6  1.00  0.17   93.9
D1 parejo      Presion alta/Contragolpe  1.58   9.4   53.2   54.9   17.9  40.3  15.1   3.47   5.00   2.3  1.08  0.00   93.0
D1 favorito    Tiki taka/Juego directo   5.58  11.1   58.3   56.3   29.2  45.7  17.0   3.03   7.67   3.1  1.17  0.17   90.9
D1 favorito    Presion alta/Contragolpe  5.08  10.4   55.9   57.9   27.8  35.5  18.2   3.10   7.75   3.3  2.08  0.25   89.7
D1 tapado      Tiki taka/Juego directo   3.67   8.9   44.6   55.4   21.8  41.3  17.9   3.08   6.17   2.3  1.08  0.00   91.5
D1 tapado      Presion alta/Contragolpe  4.25  10.3   50.7   57.8   25.2  36.8  19.5   3.05   7.58   3.0  1.75  0.08   89.3
D5 parejo      Tiki taka/Juego directo   2.75   7.6   51.6   56.5   21.6  46.0  20.6   3.07   8.08   2.5  1.00  0.00   89.6
D5 parejo      Presion alta/Contragolpe  2.50   7.1   53.1   58.2   21.3  39.9  19.3   3.46   6.58   2.3  1.50  0.08   88.2
D5 favorito    Tiki taka/Juego directo   5.42  10.7   58.0   60.0   31.0  46.7  19.7   3.11   9.50   3.1  1.42  0.08   87.3
D5 favorito    Presion alta/Contragolpe  4.92   9.8   57.9   62.2   28.6  34.1  21.5   3.26  10.25   2.7  1.08  0.00   85.6
D10 parejo     Tiki taka/Juego directo   2.08   6.8   51.9   63.8   22.8  46.5  25.9   3.19  12.00   2.5  1.33  0.08   83.6
D10 parejo     Presion alta/Contragolpe  2.17   6.5   55.2   67.3   26.1  34.4  25.0   3.61  10.08   3.5  1.67  0.00   81.8
D10 tapado     Tiki taka/Juego directo   2.75   7.5   47.9   61.7   24.1  42.6  20.7   3.43   7.83   2.8  1.50  0.17   85.2
D10 tapado     Presion alta/Contragolpe  3.50   6.9   47.0   64.7   26.8  35.3  24.1   3.26   9.67   3.8  1.50  0.17   82.2
```

Medias de las 14 celdas, contra la etapa 0:

| metrica | base | etapa 1 | cambio |
| --- | --- | --- | --- |
| goles | 3.14 | 3.51 | +11.8% |
| tiros | 8.56 | 8.79 | +2.7% |
| controlada_pct | 58.0 | 59.3 | +1.3 pts |
| pases | 39.4 | 40.7 | +3.3% |
| perdidas | 20.7 | 19.9 | -3.9% |
| duracion_posesion_seg | 3.26 | 3.23 | -0.9% |
| recuperaciones_altas | 8.08 | 8.29 | +2.6% |
| resistencia_final_pct | 88.9 | 88.0 | -0.9 pts |

Ninguna metrica cruza el 15% que el plan marca como señal para
investigar. Los goles son lo que mas se mueve y suben donde ya eran
altos: D1 favorito 5,08 a 5,58 y D5 favorito 4,50 a 5,42. Es el mismo
sintoma que ya traia la base —el desparejo se cobra en la conversion, no
en los remates— y lo mira la etapa 9. Esta etapa no lo empeora
estructuralmente: le da mas ocasiones limpias al que ya convertia mejor.

Invariante 2 se mantiene: los 168 partidos dan el mismo marcador y los
mismos remates con y sin fotogramas.

### Verificaciones

`tests/test_desmarques.gd`, diez comprobaciones, `FALLOS=0`:

- El reparto funciona atacando para los dos lados, y solo al que ataca.
- Dos destinos nunca quedan a menos de 3,6 m (564 pares medidos).
- Los plazos caen entre 4 y 12 ticks y el destino no se mueve mientras
  corre el plazo, aunque los 22 se muevan.
- Una perdida borra las intenciones del que atacaba.
- Las 24 escenas dejaron un apoyo al pie.
- Nunca mas de dos corridas simultaneas.
- Los 155 destinos quedaron del lado habilitado de la linea de offside.
- Un rival parado en la linea de pase corre el apoyo 12 m.
- La misma escena repartida dos veces da el mismo reparto.
- En 60 partidos, 53 paredes devueltas y 47 abortadas.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 112 en 338s con 8 en
paralelo`. `test_identidad_tactica.gd` y `test_movimiento_sin_pelota.gd`
pasan sin cambiarles ninguna expectativa: el desdoble, la llegada al
segundo palo y la linea por estilo siguen midiendo lo mismo.

### Pendiente de esta etapa

- **Costo por partido: +16,5% sin fotogramas, +14,6% con fotogramas.**
  Medido el 2026-09-10 con corridas PAREADAS y alternadas en la misma
  sesion, que es lo que faltaba. Se copio el proyecto a un directorio
  aparte y en la copia se apago el reparto de desmarques y se restituyo
  la devolucion automatica de la pared: esa copia reproduce la linea de
  base de la etapa 0 celda por celda, asi que es el "antes" fiel. Seis
  corridas del diagnostico, alternando antes/despues tres veces:

  | corrida | antes | etapa 1 |
  | --- | --- | --- |
  | 1 | 236,0 ms | 273,7 ms |
  | 2 | 235,6 ms | 273,3 ms |
  | 3 | 233,8 ms | 274,4 ms |
  | media | 235,1 ms | 273,8 ms |

  Con fotogramas: 266,2 ms contra 305,0 ms. La dispersion dentro de cada
  build queda por debajo del 1%, o sea que el ruido de reloj que impedia
  medirlo era la comparacion ENTRE sesiones, no el reloj en si. El +16,5%
  queda por debajo del 20% que el plan marca como señal para investigar.
- **Revision visual: no hecha.** Las escenas que pide el plan —salida
  bajo presion, pared, ruptura diagonal, perdida y repliegue— no se
  miraron animadas.
- Que casi la mitad de las paredes se aborten (47 de 100) puede ser
  mucho. `pared_riesgo_max` esta en 0,55 y es calibrable; no se barrio.
- `project.godot` sigue sin `window/size/viewport_width/height`, del
  cambio ajeno sin commitear que ya anotaba la etapa 0. No lo toque.

## Etapa 2: resultados (2026-09-11)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Defensa coordinada (etapa 2)",
  que reemplaza a `_perseguidores` y `_objetivo_de_presion`, y la correa
  de zona enganchada al final de `_ancla_de_rol`.
- `data/utility_pesos.json`: seccion nueva `defensa`.
- `tests/test_defensa_coordinada.gd` (nuevo): las once comprobaciones.
- `tests/_diag_realismo.gd`: metrica nueva `separacion_lineas_m`.
- `docs/mediciones/realismo_etapa2.csv` y
  `docs/mediciones/realismo_etapa2_antes.csv` (nuevos).

### Que hace ahora el motor

El equipo que no tiene la pelota reparte TRES papeles, una vez por tick y
desde la misma instantanea. Antes cada uno decidia solo: salian los dos
mas cercanos a la pelota y el segundo corria al mismo lugar que el
primero.

- `presionante`: va a la pelota. Lo elige el TIEMPO DE LLEGADA, no la
  distancia. El tiempo es distancia sobre velocidad disponible, mas una
  penalizacion en segundos por alejarse de su zona y otra por cansancio
  (`_tiempo_de_llegada`). Un jugador tres metros mas cerca pero al 30% de
  resistencia pierde el puesto.
- `cobertura`: se para detras del presionante, sobre la recta hacia el
  arco propio. Contragolpe y Defensivo la ponen 1,6 veces mas atras: el
  segundo sostiene la linea en vez de acompañar la presion.
- `cierre`: tapa una linea de pase distinta a la de la cobertura. Sale
  solo con estilo Presion alta o con los disparadores activos, y nunca
  sin cobertura ni con la presion ya superada.

El reparto se sostiene cuatro ticks. El presionante solo cambia si otro
le mejora el tiempo de llegada un 20% (`mejora_presionante`). El cierre
se recalcula cada tick porque depende del estilo y de los disparadores.

**Disparadores de presion** (`_intensidad_de_presion`, 0 a 1). Cuatro
señales, todas visibles en la escena: pelota suelta o recien controlada,
poseedor moviendose hacia su propio arco, pelota a menos de ocho metros
de la banda, y la ventana de transicion que ya existia tras una perdida.
La intensidad acerca la cobertura y habilita el cierre en estilos de
bloque.

**Presion superada.** Pide dos cosas: que el presionante se haya
ENGANCHADO alguna vez —haber llegado a 3,5 m de la pelota, el plan lo
recuerda— y que ahora la pelota este del lado de su arco. Sin la primera
condicion cualquier delantero que presiona de frente daba "superado" en
el primer tick, porque la pelota siempre esta mas cerca del arco que el.

**Correa de zona** (`_recortar_a_la_zona`). El que defiende y no tiene
papel asignado no se va detras de la pelota hasta la otra punta: bascula
y se adelanta hasta el radio de su rol (12 m la linea de atras, 16 el
medio, 20 los de arriba). Hacia atras no hay correa — un central siempre
puede bajar a su area.

### Medicion, con corridas pareadas

Los numeros de la etapa 1 que estan mas arriba NO sirven de "antes": el
arbol de trabajo cambio desde entonces por trabajo ajeno (BUG-007 movio
`tiro.geometria` y `castigo_distancia`, entre otras cosas). Asi que el
"antes" se midio de nuevo, en la misma sesion: se copio el proyecto a un
directorio aparte y en la copia se restituyeron `_perseguidores` y
`_objetivo_de_presion` viejos y se saco la correa de zona. Las dos builds
dan el mismo resultado corrida tras corrida.

Misma configuracion que las etapas 0 y 1: semilla 77100, 12 partidos por
celda, 14 celdas, 168 partidos, cada uno con y sin fotogramas.

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas lineas  falt  amar  roja resist
D1 parejo      Tiki taka/Juego directo   1.75   7.7   53.5   57.4   18.0  47.9  14.5   3.75   5.92   39.4   2.3  1.25  0.00   94.0
D1 parejo      Presion alta/Contragolpe  2.42   9.3   52.6   57.6   22.9  37.6  15.5   3.59   5.08   39.9   3.0  1.42  0.08   92.9
D1 favorito    Tiki taka/Juego directo   4.58   9.9   58.1   59.5   24.3  48.2  17.8   3.58   7.42   38.4   2.3  1.25  0.08   92.0
D1 favorito    Presion alta/Contragolpe  4.75  10.3   57.1   61.5   27.8  33.8  18.4   3.41   7.67   39.3   2.9  1.42  0.17   90.3
D1 tapado      Tiki taka/Juego directo   3.25   8.1   48.8   60.6   23.6  42.9  18.5   3.34   7.08   38.8   3.4  1.67  0.08   91.9
D1 tapado      Presion alta/Contragolpe  2.75   9.6   49.3   60.4   23.9  37.0  20.0   3.39   8.33   40.4   2.7  1.50  0.08   90.3
D5 parejo      Tiki taka/Juego directo   1.83   7.5   52.6   60.3   21.0  48.3  18.3   3.57   7.58   39.2   3.0  1.17  0.00   90.5
D5 parejo      Presion alta/Contragolpe  2.50   6.6   54.4   61.6   21.2  38.1  18.3   3.69   6.42   40.0   3.3  1.67  0.08   88.6
D5 favorito    Tiki taka/Juego directo   4.83  10.3   57.6   62.0   29.4  45.3  22.1   3.06  10.33   38.9   3.1  1.25  0.17   87.8
D5 favorito    Presion alta/Contragolpe  4.33   9.4   56.9   65.6   28.0  34.1  20.3   3.58   9.92   39.2   3.3  1.58  0.33   86.1
D10 parejo     Tiki taka/Juego directo   1.83   8.1   51.9   64.6   23.8  44.5  24.3   3.43  10.50   38.8   2.6  0.92  0.00   84.2
D10 parejo     Presion alta/Contragolpe  1.92   7.0   52.7   69.0   23.2  33.9  23.8   3.93   8.42   39.9   2.5  1.67  0.08   81.7
D10 tapado     Tiki taka/Juego directo   3.17   9.2   45.8   64.4   23.8  44.4  22.0   3.57   9.33   38.4   2.0  1.33  0.17   86.3
D10 tapado     Presion alta/Contragolpe  2.92   9.1   46.7   64.0   28.3  34.7  22.8   3.61   9.33   38.9   3.2  1.50  0.00   84.1
```

Medias de las 14 celdas, contra la copia "antes" medida el mismo dia:

| metrica | antes | etapa 2 | cambio |
| --- | --- | --- | --- |
| goles | 2.86 | 3.06 | +6.8% |
| tiros | 8.01 | 8.72 | +8.8% |
| controlada_pct | 60.0 | 62.0 | +2.1 pts |
| pelota_parada_pct | 23.4 | 24.2 | +0.8 pts |
| pases | 41.9 | 40.8 | -2.6% |
| perdidas | 21.0 | 19.8 | -6.0% |
| duracion_posesion_seg | 3.31 | 3.54 | +7.0% |
| recuperaciones_altas | 8.50 | 8.10 | -4.7% |
| separacion_lineas_m | 39.1 | 39.2 | +0.1 m |
| faltas | 2.82 | 2.83 | +0.4% |
| resistencia_final_pct | 88.3 | 88.6 | +0.3 pts |

Ninguna metrica cruza el 15% que el plan marca como señal. Lo que se
mueve cuenta una sola historia: la pelota se pierde menos (-6%), la
posesion dura mas (+7%) y esta controlada mas tiempo (+2,1 pts). El
segundo defensor ya no corre a la misma pelota que el primero, asi que
tapa menos por accidente. Los remates suben 8,8% y los goles 6,8% por el
mismo motivo: el que ataca conserva mas la pelota. Las recuperaciones
altas BAJAN 4,7%, que es lo esperable — el bloque aprieta ordenado en vez
de perseguir de a dos, y eso recupera menos arriba.

Invariante 2 se mantiene: los 168 partidos dan el mismo marcador y los
mismos remates con y sin fotogramas.

### Costo

Medido con corridas pareadas y alternadas en la misma sesion, tres pares
de seis partidos por celda:

| corrida | antes | etapa 2 |
| --- | --- | --- |
| 1 | 280 ms | 308 ms |
| 2 | 277 ms | 306 ms |
| 3 | 278 ms | 304 ms |
| media | 278 ms | 306 ms |

**+10,2% sin fotogramas y +9,2% con fotogramas** (309 ms contra 337 ms).
La dispersion dentro de cada build queda por debajo del 1%. Esta debajo
del 20% que el plan marca como señal.

El primer intento media +48% (613 ms contra 416 ms). La causa era
`pesos_defensa()`: armaba un diccionario de quince entradas una vez por
candidato y por tick. Ahora el resultado queda cacheado en
`_pesos_defensa_cache`, igual que `pesos()`. `pesos_sin_pelota()` de la
etapa 1 tiene el mismo problema y no se toco: cachearla probablemente
recupere parte del +16,5% que quedo anotado alli.

### Verificaciones

`tests/test_defensa_coordinada.gd`, once comprobaciones, `FALLOS=0`:

- Hay un presionante y una cobertura distinta, atacando para los dos
  lados, y ninguno es arquero ni del equipo que ataca.
- La cobertura queda entre el presionante y su propio arco, y no va al
  mismo punto que el.
- Presion alta cierra un carril separado de la cobertura; Contragolpe
  conserva el bloque mientras no haya disparadores.
- El presionante no se intercambia cada fotograma: cero cambios en 24
  ticks con los 22 en movimiento.
- El cansancio le saca el puesto al que esta tres metros mas cerca.
- Con la presion superada no sale un tercero a cerrar.
- Banda, control largo y recepcion de espaldas suben la intensidad.
- Con diez jugadores sigue habiendo presionante y cobertura, y ninguno es
  el que salio.
- Ocho escenas repartidas dos veces dan el mismo reparto.
- La correa limita basculacion y adelantamiento, y deja retroceder.
- En 12 partidos completos: 10,8 recuperaciones altas por partido y 39,3
  m entre lineas del bloque.

`test_identidad_tactica.gd` pasa sin cambiarle ninguna expectativa: sigue
midiendo tres jugadores fuera del bloque con Presion alta, dos con
Contragolpe, y objetivos distintos para el primero y el segundo.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 114 en 418s con 8 en
paralelo`.

### Pendiente de esta etapa

- **Revision visual: no hecha.** Las escenas que pide el plan —presion
  con cobertura, pase que supera la presion y repliegue— no se miraron
  animadas. Queda pendiente junto con la de la etapa 1.
- **La correa de zona casi no muerde.** `separacion_lineas_m` se movio
  0,1 m, o sea que los radios (12/16/20 m) casi nunca recortan nada.
  Estan puestos generosos a proposito, para no mover el balance sin
  medir. Barrerlos es lo primero si se quiere un bloque mas compacto.
- `pesos_sin_pelota()` de la etapa 1 sigue sin cache (ver Costo).
- `project.godot` sigue sin `window/size/viewport_width/height`, del
  cambio ajeno sin commitear que ya anotaban las etapas 0 y 1. No lo
  toque.

## Etapa 3: resultados (2026-09-13)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Control y orientacion corporal
  (etapa 3)" despues de `_mover_hacia`; el giro en `_mover_hacia` y en
  `_conducir`; `_mirar_la_pelota` en el paso 3 de `_tick` y en el juego
  detenido; la llegada capturada en `_avanzar_pelota`; el control en
  `_resolver_recepcion`; la demora y el filtro de orientacion en
  `_decidir_y_ejecutar`; `orientacion` y `giro` en el dict de titulares y
  suplentes; `ox`/`oy` en el fotograma; `stats.control` en `simular`.
- `match/vista_partido.gd`: el jugador quieto se dibuja mirando hacia su
  orientacion.
- `data/utility_pesos.json`: seccion nueva `control`.
- `tests/test_control_orientacion.gd` (nuevo): treinta comprobaciones.
- `tests/_diag_control.gd` (nuevo): barrido de los pesos. Mide, no falla.
- `tests/_diag_realismo.gd`: metricas nuevas de control.
- `docs/mediciones/realismo_etapa3.csv` y `realismo_etapa3_antes.csv`.

### Que hace ahora el motor

**Orientacion** (puntos 1 y 2). Cada jugador tiene `orientacion`, un vector
normalizado, y `giro`, en radianes por segundo segun `agilidad` leida
absoluta (4,0 con 0 y 9,0 con 100). Arranca mirando al arco que ataca, y
lo mismo en el saque del medio y al entrar un suplente.

- Por encima de 2 m/s el cuerpo sigue a la carrera (`_mover_hacia`).
- Por debajo mira la pelota (`_mirar_la_pelota`, despues de mover a todos).
- El poseedor que arranca despacio se perfila hacia donde conduce.
- El arquero que espera con la pelota gira hacia el arco rival.
- Un vector nulo no cambia la orientacion.

**Dificultad de la recepcion** (punto 3). `_avanzar_pelota` guarda la
velocidad y la altura del pase en `pelota.llegada` ANTES de que
`_dirigir_pelota_a` le baje la altura y la pelota frene. La dificultad
suma cuatro terminos:

| termino | 0 | 1 | peso |
| --- | --- | --- | --- |
| velocidad | `vel_pase_min` | `vel_pase_max` | 0,3 |
| altura del vuelo | raso | `altura_centro` | 0,2 |
| presion | `presion_normalizada` 0 | 1 | 0,3 |
| angulo | pelota de frente al cuerpo | por la espalda | 0,2 |

**Una sola demora** (punto 4). La espera vieja era `ticks_control`: el
poseedor decidia cada 2 a 9 ticks segun `control` y estilo. Ahora:

- `cadencia_de_decision` conserva esa cuenta tal cual.
- `demora_de_control` la multiplica por 0,8 con dificultad 0 y por 1,8 con
  dificultad 1. Con factor 1 da exactamente la cadencia (198 de 198 casos
  en el test).
- La primera decision despues de un pase espera la demora; despues
  reconsidera cada `cadencia` ticks, como antes.
- Una posesion que no empieza con un pase (quite, rebote, arquero, saque)
  no tiene control pendiente y decide en los mismos ticks que antes.

**Calidad del toque** (puntos 5 y 6). `_controlar_recepcion` corre UNA vez
por pase recibido por un jugador de campo, despues del offside y del
evento del pase. Tira una vez el RNG del partido. La chance de toque largo
es `malo_max` × dificultad × (1 − 0,8 × `control`), con `control` mezclado
mitad relativo y mitad absoluto.

- El toque largo sale en la direccion en que venia la pelota, desviado
  hasta 0,9 rad, a 2-6 m segun la dificultad, y rueda dos ticks.
- La pelota queda suelta. Nadie la recibe por decreto: el receptor sale a
  buscarla (`destino_id`) y el rival tambien.
- La recupera la intercepcion y el contacto de siempre. La pelota suelta
  no vuelve a tirar control, asi que no hay tirada por tick de contacto.
- El arquero y el muro de la pared quedan afuera: el primero la toma con
  su rama, el segundo la devuelve de primera.

**Pase de primera y giro** (punto 7). `_opciones_orientadas` saca las
opciones que mandan la pelota a mas de 2,5 rad (143°) del cuerpo. Vuelven
cuando el cuerpo gira. Conducir, gambeta y despeje no tienen destino y
quedan siempre. Si no queda ninguna opcion, el poseedor gira ese tick y
vuelve a decidir en el siguiente: el giro avanza cada tick, asi que la
espera termina. Un control facil de un buen tecnico da demora 1 o 2, que
es el pase de primera cuando la direccion es compatible. El remate de
primera y el cabezazo siguen por `_resolver_centro`.

**Vista** (punto 8). El fotograma trae `ox`/`oy`. Quieto, el sprite mira
hacia la orientacion; corriendo manda el avance, como siempre. Un
fotograma viejo sin el campo se dibuja igual que antes.

### Calibracion

`tests/_diag_control.gd`, 200 partidos por configuracion (D1 parejo, D1
favorito, D5 y D10 parejos, dos cruces de estilos), mismas semillas. La
"neutra" apaga toque largo, demora y cono.

| config | goles | remates | pases | toques largos | demora / cadencia | decisiones con giro |
| --- | --- | --- | --- | --- | --- | --- |
| neutra | 2,17 | 7,00 | 40,1 | 0 | 1,00 | 0% |
| demora 0,6/1,6, cono 2,0, malo 0,3 | 2,38 | 7,42 | 38,3 | 1,78 | 0,80 | 88% |
| demora 0,8/1,8, sin cono | 2,21 | 6,97 | 39,7 | 1,82 | 0,98 | 0% |
| demora 0,8/1,8, cono 2,5, malo 0,3 | 2,39 | 7,24 | 38,3 | 1,83 | 0,98 | 78% |
| **demora 0,8/1,8, cono 2,5, malo 0,5** | 2,35 | 7,17 | 37,8 | 2,92 | 0,98 | 77% |

- La dificultad media de una recepcion es 0,24: velocidad 0,47, presion
  0,09, angulo 0,18. Con demora 0,6/1,6 la primera decision salia al 80%
  de la espera vieja; con 0,8/1,8 sale al 98%. El ritmo medio no cambia.
- El cono es lo que mueve goles y pases. Con 2,0 rad le sacaba opciones al
  88% de las decisiones; con 2,5 al 78%, casi siempre el pase al arquero o
  al central que quedo a la espalda.
- `malo_max` 0,5 lleva los toques largos al 7% de las recepciones sin mover
  los goles.

### Medicion, contra la copia "antes"

La copia del proyecto se hizo antes de tocar nada (`etapa3_antes`), con los
cambios de la etapa 5 sin commitear incluidos. Misma configuracion que las
etapas anteriores: semilla 77100, 12 partidos por celda, 14 celdas, 168
partidos.

| metrica | antes | etapa 3 | cambio |
| --- | --- | --- | --- |
| goles | 2,607 | 2,911 | +11,6% |
| tiros | 7,82 | 7,91 | +1,1% |
| posesion_pct | 53,2 | 53,1 | -0,1 pts |
| controlada_pct | 56,9 | 56,9 | 0,0 pts |
| pelota_parada_pct | 21,9 | 22,3 | +0,4 pts |
| pases | 40,26 | 37,81 | -6,1% |
| perdidas | 18,88 | 19,88 | +5,3% |
| duracion_posesion_seg | 3,56 | 3,40 | -4,6% |
| recuperaciones_altas | 7,38 | 7,80 | +5,7% |
| faltas | 3,08 | 3,01 | -2,1% |
| resistencia_final_pct | 88,9 | 88,7 | -0,2 pts |
| recepciones de pase | - | 40,8 | |
| toques largos | - | 2,48 | |
| dificultad media | - | 0,237 | |
| demora / cadencia | - | 0,979 | |

Por division: `controlada_pct` 54,4 → 55,0 en D1, 57,1 → 56,4 en D5 y
60,4 → 60,2 en D10. Toques largos por partido: 2,25 en D1, 2,33 en D5 y
2,96 en D10.

Ninguna metrica cruza el 15%. Lo que se mueve cuenta una historia: el pase
a la espalda sale menos (-6,1% de pases), la pelota se pierde un 5,3% mas
por los toques largos y la posesion dura un 4,6% menos. Los remates no se
mueven y los goles suben 11,6%, o sea que sube la conversion (33% → 37%).
El barrido lo atribuye al cono, no al toque ni a la demora. La diferencia
entre dos corridas con distinto RNG tiene un error estandar de unos 0,18
goles, asi que el +0,30 son 1,7 errores: la direccion coincide con el
barrido, el tamaño no es preciso.

Paridad: la validacion final (`mediciones/calibracion_final.md`) medía el
espacial entre 18% y 50% por debajo del abstracto en goles. Esta etapa
acerca los dos motores; no los cruza.

Invariante 2 se mantiene: los 168 partidos dan el mismo resultado con y sin
fotogramas, y el test compara ademas `stats.control`.

### Costo

Tres pares alternados en la misma sesion, 6 partidos por celda:

| par | antes | etapa 3 |
| --- | --- | --- |
| 1 | 408,2 ms | 428,9 ms |
| 2 | 406,6 ms | 433,4 ms |
| 3 | 409,9 ms | 424,8 ms |

**+5,1% sin fotogramas y +7,5% con fotogramas** (443,3 contra 476,4 ms).
Debajo del 20%. El gasto es el giro de los 22 por tick y, con fotogramas,
`ox`/`oy`. Despues de medir se saco una llamada doble a `orientacion_de` en
el fotograma; no cambia resultados y no se volvio a medir.

### Verificaciones

`tests/test_control_orientacion.gd`, `FALLOS=0`:

- Media vuelta: 3 ticks con agilidad 5 y 2 con 95; ningun tick gira mas que
  `giro` × `TICK_SEG`. El vector nulo no cambia nada ni da NaN.
- Quieto mira la pelota; corriendo sigue su carrera. Para los dos lados.
- Misma escena, pase de 18 m/s: dificultad 0,16 de frente y 0,36 de
  espaldas; demora 7 y 9 ticks; toque largo 0,074 y 0,166. Para los dos
  lados.
- Dificultad 0,00 con el pase mas suave, 0,30 con el mas fuerte, 0,20 con
  el suave que viene alto, 0,14 con un rival a 1,5 m. Dificultad cero no
  hace toque largo.
- Con factor 1 la demora da la cadencia en 198 de 198 casos; con los pesos
  reales, cadencia 6 da demora 5 facil y 10 dificil.
- Sin control pendiente decide en el tick de la cadencia; con demora 5, en
  el tick 5.
- 600 recepciones de espaldas: control 15 hace 109 toques largos y demora
  9,0 ticks; control 95, 39 y 2,0. El control alto tambien falla.
- Un control limpio consume exactamente una tirada del RNG. Un pase que
  rueda 8 ticks hasta el receptor cuenta una recepcion.
- 60 toques largos: ninguno queda en los pies de nadie, el mas largo va a
  5,1 m. La pelota suelta la recupera el equipo del receptor 43 veces y el
  rival 17.
- De espaldas al arco no juega al 9 pero si al central y conduce; gira en
  los ticks estimados y el pase al 9 vuelve. Para los dos lados.
- El arquero de espaldas con todos adelante no juega en el primer tick,
  gira y la juega en el segundo.
- Saque del medio: 22 de 22 miran al arco que atacan. El suplente entra
  orientado y con su propia agilidad.
- La vista dibuja igual un fotograma viejo; quieto mira hacia `ox`/`oy`.
- 6 partidos: mismo resultado y mismo `stats.control` con y sin fotogramas;
  orientaciones normalizadas; 217 recepciones y 11 toques largos; la
  posesion mas larga de un jugador dura 29 ticks.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 123 en 413s con 8 en
paralelo`. No se hizo commit.

### Pendiente de esta etapa

- **`controlada_pct` no se movio (56,9% contra 56,9%).** La etapa 0 lo
  marcaba como el numero de esta etapa. El control agrega toques largos,
  que restan tiempo con dueño; ningun mecanismo de la etapa suma. En D1 subio
  0,6 puntos y en D10 bajo 0,2, que es la direccion buscada pero dentro del
  ruido. La pelota libre sigue siendo casi la mitad del juego abierto.
- **Goles +11,6%, por la conversion.** El barrido lo atribuye al cono de
  giro. No se midio que remates cambiaron; es de la etapa 9.
- **Revision visual: no hecha.** Control largo, recepcion de espaldas y el
  sprite quieto orientado son justamente lo que hay que mirar animado.
- **Pie preferido sigue midiendo contra el eje de la cancha.** Su
  comentario dice que el motor no modela hacia donde mira el cuerpo; ahora
  lo modela. Pasarlo a la orientacion es un cambio de balance aparte.
- **La presion pesa poco en la dificultad** (0,09 de media): la mayoria de
  los pases llegan sin nadie encima. `peso_presion` no se barrio.
- `giro_lento`, `giro_rapido`, `rapidez_para_girar` y `toque_desvio` no se
  barrieron: se eligieron por fisica y se midio que no rompen nada.

## Etapa 4: resultados (2026-09-11)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Ritmo variable (etapa 4)", el
  enganche al principio de `_tick`, los ajustes de ritmo dentro de
  `_ponderar_plan`, la pausa en `_conducir` y el conteo de parejas en
  `_entregar_pelota`.
- `data/utility_pesos.json`: seccion nueva `ritmo`.
- `tests/test_ritmo_variable.gd` (nuevo): las catorce comprobaciones.
- `tests/_diag_ritmo_umbral.gd` (nuevo): el barrido del umbral. Mide, no
  falla.
- `docs/mediciones/realismo_etapa4.csv` y
  `docs/mediciones/realismo_etapa4_antes.csv` (nuevos).

### Que hace ahora el motor

El equipo que ataca tiene una FASE. Se estima una vez por tick, antes de
que nadie decida ni se mueva, y se sostiene seis ticks.

- `transicion`: la ventana corta que se abre despues de una recuperacion.
- `aceleracion`: hay carril libre por delante del poseedor, o hay un
  companero adelantado, libre y CON CARRIL para llegarle.
- `circulacion`: no hay ninguna de las dos cosas. El rival esta cerrado.

La fase no bloquea ninguna opcion legal. Solo suma o resta utilidad, con
un tope de 0,50 (`ritmo.tope`), sobre las utilidades que ya existian:

- Circulacion premia el apoyo corto y libre (hasta 22 m) y el cambio de
  frente. Los dos premios se multiplican por `1 - camino`, asi que se
  apagan solos cuando progresar SI es posible.
- Aceleracion premia la conduccion, el pase al hueco y el pase que gana
  metros. Un pase hacia atras no cobra nada.
- Transicion devuelve CERO a proposito. Esa fase ya la bonifica el
  termino `transicion` de `_ponderar_plan`, que existe desde la etapa 1;
  sumarle otro premio seria cobrar dos veces lo mismo.

**Pausar es conducir despacio, no congelarse.** En circulacion el avance
de `_conducir` se multiplica por 0,75. Medido en el test: ocho ticks
conduciendo dan 5,48 m en circulacion contra 6,70 m fuera de ella. El
poseedor sigue moviendose, y la presion y el robo del rival siguen
corriendo igual — son los pasos 3 y 4 del tick y no los toca nadie.

**La pareja que se devuelve la pelota.** El motor anota que companero le
paso a cual, al COMPLETARSE el pase. Si la posesion lleva doce ticks sin
ganar un metro hacia el arco rival y nadie le esta encima al poseedor
(presion por debajo de 0,35), devolversela al que acaba de darsela pierde
0,30 de utilidad por vez, hasta tres veces. Ganar cuatro metros borra el
conteo. Con presion no se castiga nada: devolverla ahi es la jugada
correcta. Y el castigo tiene tope y no toca al resto de los pases, asi
que la salida segura siempre queda.

### Calibracion del umbral, medida

La primera version dejaba la circulacion en el 5% de los ticks. Dos
causas, las dos medidas con `tests/_diag_ritmo_umbral.gd` sobre 8
partidos:

1. **Cualquier companero despejado contaba como ventaja.** En campo
   abierto siempre hay alguien sin presion encima, asi que el equipo
   estaba siempre en aceleracion. Se agrego `carril_libre`: el apoyo
   tiene que tener ademas un carril de pase con riesgo por debajo de
   0,40. Un companero libre al que no se le puede llegar no es una
   ventaja.
2. **La ventana de transicion es mas larga que una posesion.** Dura 6 s y
   una posesion dura 3,5 s (etapa 0), asi que con el umbral en 0,35 casi
   toda posesion era transicion entera.

Barrido del umbral, ya con la comprobacion del carril:

| umbral_transicion | circulacion | aceleracion | transicion |
| --- | --- | --- | --- |
| 0,35 | 17% | 20% | 63% |
| 0,55 | 27% | 20% | 54% |
| 0,70 | 27% | 25% | 48% |
| 0,80 | 33% | 26% | 40% |
| 0,90 | 43% | 34% | 23% |

Queda en **0,70**: son los primeros 1,8 s despues de la recuperacion, mas
o menos una posesion. No se toco `SEGUNDOS_TRANSICION`, que es de la
etapa 1 y alimenta el termino de utilidad viejo.

### Medicion, con corridas pareadas

El "antes" se midio en la misma sesion: se copio el proyecto a un
directorio aparte y en la copia se apagaron `_planificar_ritmo`,
`fase_de_ritmo`, `_ajuste_de_ritmo` y `_posesion_estancada`. Esa copia
reproduce la tabla de la etapa 2 celda por celda, asi que es el "antes"
fiel.

Misma configuracion que las etapas 0, 1 y 2: semilla 77100, 12 partidos
por celda, 14 celdas, 168 partidos, cada uno con y sin fotogramas.

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas lineas  falt  amar  roja resist
D1 parejo      Tiki taka/Juego directo   2.00   7.3   53.3   57.6   17.2  49.8  15.7   3.68   5.75   39.5   2.6  1.08  0.08   94.0
D1 parejo      Presion alta/Contragolpe  2.00   7.3   53.3   58.2   18.7  37.4  18.5   3.49   6.08   40.5   2.9  1.58  0.00   92.2
D1 favorito    Tiki taka/Juego directo   4.25   8.9   57.7   58.3   24.8  49.1  18.6   3.28   7.33   38.9   2.8  0.75  0.00   90.7
D1 favorito    Presion alta/Contragolpe  4.42   8.3   57.7   59.5   27.5  34.0  19.3   3.30   6.00   39.7   3.1  1.58  0.00   89.7
D1 tapado      Tiki taka/Juego directo   2.75   7.6   45.7   59.0   22.5  40.8  18.8   3.30   7.83   39.0   2.5  1.08  0.08   91.7
D1 tapado      Presion alta/Contragolpe  3.58   8.0   50.4   59.6   23.3  37.3  20.8   3.37   7.42   39.9   2.9  1.00  0.17   89.8
D5 parejo      Tiki taka/Juego directo   2.08   7.2   54.5   60.3   22.2  47.5  20.7   3.48   8.25   39.7   3.3  1.67  0.00   90.0
D5 parejo      Presion alta/Contragolpe  1.92   7.3   55.0   61.3   21.1  38.4  20.3   3.62   7.67   40.0   3.0  1.42  0.00   88.3
D5 favorito    Tiki taka/Juego directo   4.17   8.8   56.6   62.5   28.9  45.2  22.0   3.11  11.25   38.6   3.7  1.58  0.17   86.9
D5 favorito    Presion alta/Contragolpe  4.92   9.7   58.4   63.8   29.4  35.0  20.6   3.46   9.50   38.8   3.0  1.17  0.17   85.5
D10 parejo     Tiki taka/Juego directo   2.00   6.0   54.0   66.3   21.3  48.8  23.3   3.91   9.75   39.3   2.8  1.58  0.17   83.5
D10 parejo     Presion alta/Contragolpe  1.58   7.6   54.3   67.8   25.8  33.8  22.8   3.81   9.42   39.4   3.9  1.92  0.08   81.5
D10 tapado     Tiki taka/Juego directo   3.50   8.8   48.1   63.9   26.1  42.3  22.2   3.45  10.08   38.5   2.7  1.42  0.08   86.0
D10 tapado     Presion alta/Contragolpe  2.67   7.6   50.3   65.9   25.1  35.8  23.1   3.77   9.50   40.0   2.4  0.92  0.17   83.6
```

Medias de las 14 celdas, contra la copia "antes" medida el mismo dia:

| metrica | antes | etapa 4 | cambio |
| --- | --- | --- | --- |
| goles | 3.06 | 2.99 | -2.3% |
| tiros | 8.71 | 7.88 | -9.6% |
| posesion_pct | 52.7 | 53.5 | +0.8 pts |
| controlada_pct | 62.0 | 61.7 | -0.3 pts |
| pelota_parada_pct | 24.2 | 23.9 | -0.4 pts |
| pases | 40.8 | 41.1 | +0.8% |
| perdidas | 19.8 | 20.5 | +3.6% |
| duracion_posesion_seg | 3.54 | 3.50 | -0.9% |
| recuperaciones_altas | 8.10 | 8.27 | +2.2% |
| separacion_lineas_m | 39.3 | 39.4 | +0.1 m |
| faltas | 2.81 | 2.97 | +5.7% |
| resistencia_final_pct | 88.6 | 88.1 | -0.5 pts |

Ninguna metrica cruza el 15% que el plan marca como señal. **Lo que mas
se mueve son los remates: -9,6%.** Es el efecto buscado y esta en la
direccion correcta — con el rival cerrado el equipo circula en vez de
apurar el remate, y la etapa 0 ya anotaba que 8,6 remates por partido con
posesiones de 3,3 s eran muchos para lo que se ve en pantalla. Los goles
casi no se mueven (-2,3%), o sea que lo que se perdio fueron remates de
baja calidad. Confirmarlo es de la etapa 9, que es la dueña de la calidad
de ocasiones.

Invariante 2 se mantiene: los 168 partidos dan el mismo marcador y los
mismos remates con y sin fotogramas.

### Costo

Tres pares alternados en la misma sesion, con la maquina libre, seis
partidos por celda:

| corrida | antes | etapa 4 |
| --- | --- | --- |
| 1 | 305 ms | 313 ms |
| 2 | 304 ms | 312 ms |
| 3 | 305 ms | 313 ms |
| media | 304,7 ms | 312,7 ms |

**+2,6% sin fotogramas y +2,6% con fotogramas** (335,0 ms contra
343,7 ms). La dispersion dentro de cada build queda por debajo del 0,5%.
Muy por debajo del 20% que el plan marca como señal. El reparto de ritmo
corre una vez por tick y por partido, no una vez por jugador, y
`pesos_ritmo()` esta cacheada desde el principio.

### Verificaciones

`tests/test_ritmo_variable.gd`, catorce comprobaciones, `FALLOS=0`:

- El frente tapado da circulacion y el carril libre da aceleracion,
  atacando para los dos lados.
- La fase se sostiene los seis ticks aunque el frente se abra de golpe, y
  cambia recien al vencer el plazo.
- La ventana de transicion corta el plazo de la fase anterior.
- El cambio de manos borra fase, progreso y parejas.
- Circulacion premia el apoyo corto y libre solo con el camino cerrado
  (+0,284 con camino 0,1 contra +0,016 con camino 0,95), no premia un
  pase de 40 m, y premia el cambio de frente.
- Aceleracion premia hueco (+0,350), pase que gana metros (+0,189) y
  conduccion (+0,225), y no premia el pase hacia atras.
- En transicion el ajuste de ritmo es exactamente cero.
- El peor ajuste de 1296 combinaciones es 0,500, que es el tope.
- Tres devoluciones sin avanzar bajan la utilidad del pase de -0,214 a
  -1,114; con presion por encima de 0,35 no se castiga nada; avanzar 6 m
  borra el conteo.
- Pausar conduce 5,48 m en ocho ticks contra 6,70 m fuera de circulacion,
  y nunca 0 m.
- Cuatro escenas repartidas dos veces dan la misma fase.
- En 8 partidos completos aparecen las tres fases y ninguna se come el
  partido: 27% circulacion, 25% aceleracion, 48% transicion sobre 6043
  ticks con dueño.

Pases atras, medidos por separado como pide el plan: 3,5 por partido sin
presion, 2,1 devoluciones al que acaba de darsela y 2,8 hacia atras con
presion encima.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 115 en 396s con 8 en
paralelo`.

### Pendiente de esta etapa

- **Revision visual: no hecha.** Las escenas que pide el plan —rival
  cerrado circulando y carril liberado acelerando— no se miraron
  animadas. Se acumula con las pendientes de las etapas 1 y 2.
- **Los remates bajaron 9,6% y no se comprobo QUE remates se perdieron.**
  La hipotesis es que son los de baja calidad, porque los goles casi no
  se movieron, pero medirlo por tramo de distancia y calidad es de la
  etapa 9.
- **La etapa 3 sigue sin hacer.** Esta etapa se implemento salteandola, a
  pedido. `_decidir_y_ejecutar` sigue con la demora de control vieja y sin
  orientacion corporal, asi que el punto 4 de la etapa 3 —"una sola
  demora de control"— todavia hay que resolverlo cuando se la encare.
- `pesos_sin_pelota()` de la etapa 1 sigue sin cache.
- `project.godot` sigue sin `window/size/viewport_width/height`, del
  cambio ajeno sin commitear que ya anotaban las etapas 0, 1 y 2. No lo
  toque.

## Etapa 7: resultados (2026-09-11)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Contexto del marcador (etapa
  7)", el enganche al principio de `_tick`, la altura del bloque dentro
  de `_ancla_de_rol`, el cupo de corridas en `_planificar_desmarques`,
  los ajustes de utilidad en `_ponderar_plan` y el umbral del cierre y la
  profundidad de la cobertura en la defensa coordinada.
- `data/utility_pesos.json`: seccion nueva `marcador`.
- `core/fase_liga.gd`: desempate por nombre en `tabla_ordenada`. No es de
  esta etapa; ver "Un arreglo ajeno que hubo que hacer".
- `tests/test_contexto_marcador.gd` (nuevo): las catorce comprobaciones.
- `docs/mediciones/realismo_etapa7.csv` y
  `docs/mediciones/realismo_etapa7_antes.csv` (nuevos).

### Que hace ahora el motor

Cada equipo tiene una URGENCIA: un solo numero entre -1 y 1 que dice
cuanto necesita que el partido cambie. Se calcula una vez por tick para
los dos equipos, antes de que nadie decida ni se mueva.

- Positiva: pierde, o el empate no le alcanza.
- Negativa: gana y quiere que el partido termine.

Sale de tres cosas que ya existian: el minuto, la diferencia de goles y
el rasgo del DT.

- El minuto pesa con exponente 3. Al 5' la urgencia vale 0,000; al 45',
  0,125; al 75', 0,579; al 89', 0,967. El efecto arranca chico y crece
  sobre el final, como pide el punto 1.
- El empate da urgencia POSITIVA y chica (0,25 antes del peso del
  minuto): sobre la hora los dos lo quieren ganar.
- Cada gol de diferencia despues del primero suma menos (`dif_extra`
  0,35) y se corta en 1,35.
- El rasgo del DT amplifica un 35% la reaccion QUE YA LE CORRESPONDE: el
  Loco cuando pierde, el Conservador cuando gana. Ninguno inventa una
  reaccion que el marcador no pide.
- **Alargue**: los dos tiempos extra valen 1,0 completos. Medirlos como
  minuto/120 daria un salto hacia atras al empezar el alargue —el 91'
  pesaria menos que el 90'— y el que gana se adelantaria justo cuando
  tiene que cuidar el resultado. El empate en el alargue sigue dando
  urgencia positiva: lleva a los penales y tampoco le sirve a nadie.

La urgencia mueve cuatro cosas, todas con tope:

1. **Altura del bloque** (`_ancla_de_rol`). Corre la linea del que
   defiende sobre el mismo eje y en los mismos metros que el
   desplazamiento por estilo: 6 m por cada punto de urgencia. Son la
   mitad de los doce metros que separan a Presion alta de Defensivo, asi
   que el marcador inclina la identidad del equipo y no la reemplaza.
   Medido en la misma escena: el local defiende a -15,8 m temprano,
   -21,8 m ganando 2-0 al 88' y -9,8 m perdiendo 0-2.
2. **Cupo de corridas simultaneas** (`_planificar_desmarques`). Son dos
   (`MAX_RUPTURAS`) hasta que la urgencia llega a 0,45: ahi pasa a tres
   perdiendo y baja a una ganando. Nunca baja de una — un equipo que gana
   igual ataca. El apoyo de seguridad de la etapa 1 se reserva igual que
   siempre.
3. **Tolerancia al riesgo** (`_ponderar_plan`). El que persigue el
   partido premia el pase al hueco, el centro, la gambeta y el pase que
   gana metros, y castiga el pase atras; el que lo cuida hace lo
   contrario y premia el apoyo corto y libre. Tope de 0,35 por opcion.
4. **Reparto defensivo**. Perdiendo, el umbral de intensidad para que
   salga un tercero a cerrar una linea de pase baja; ganando por encima
   de 0,45 de urgencia no sale ninguno, ni con estilo Presion alta. Y la
   cobertura se para hasta un 50% mas atras con el partido ganado, que es
   la contracara de la altura del bloque.

**El remate queda afuera a proposito.** Premiarlo con el partido cerrado
es exactamente el abuso del tiro de lejos que arreglo BUG-007. El
marcador decide desde donde se ataca, no cuantos remates lejanos se
intentan; la calidad de la ocasion es de la etapa 9.

**Punto 5 del plan, la doble aplicacion.** El DT ya tiene su modificador
de EJECUCION en el bloque C (`DT.modificador_partido`, que llama
`MatchEngine._bloques_equipo` y usan los dos motores) y sigue siendo el
unico: pasado el minuto 60 le mueve atributos al duelo segun el rasgo y
el marcador. Lo de esta etapa es COMPORTAMIENTO y no toca ninguna
probabilidad. Las dos cosas se tocan solo en el rasgo del DT, y cada una
lo lee para algo distinto.

### Medicion, con corridas pareadas

El "antes" se midio en la misma sesion: se copio el proyecto a un
directorio aparte y en la copia `_urgencia_de` devuelve cero siempre, con
lo que la altura, el cupo, los ajustes y el reparto defensivo vuelven a
lo de la etapa 4. Esa copia reproduce la tabla de la etapa 4 celda por
celda, asi que es el "antes" fiel.

Misma configuracion que las etapas 0, 1, 2 y 4: semilla 77100, 12
partidos por celda, 14 celdas, 168 partidos, cada uno con y sin
fotogramas.

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas lineas  falt  amar  roja resist
D1 parejo      Tiki taka/Juego directo   1.75   7.1   52.4   58.2   16.3  51.8  16.2   3.89   5.83   39.2   2.5  1.25  0.17   93.8
D1 parejo      Presion alta/Contragolpe  2.25   8.3   52.9   58.6   19.9  38.3  17.7   3.59   6.08   40.0   2.7  1.08  0.00   91.9
D1 favorito    Tiki taka/Juego directo   4.50   9.4   59.1   58.7   26.1  47.0  18.6   3.34   7.75   38.4   2.8  1.17  0.08   91.2
D1 favorito    Presion alta/Contragolpe  4.67   7.8   60.4   61.2   26.6  36.6  20.1   3.54   6.25   39.6   3.3  1.75  0.25   89.8
D1 tapado      Tiki taka/Juego directo   2.75   7.7   49.7   57.6   22.7  44.1  16.8   3.48   6.42   39.1   3.1  1.75  0.25   91.9
D1 tapado      Presion alta/Contragolpe  3.17   7.5   48.2   60.7   22.2  38.6  21.3   3.47   7.50   39.9   2.7  0.92  0.17   90.0
D5 parejo      Tiki taka/Juego directo   1.83   7.0   55.5   59.1   21.6  49.8  18.8   3.68   8.00   39.5   3.3  1.83  0.00   90.3
D5 parejo      Presion alta/Contragolpe  1.75   7.2   55.4   60.0   20.4  38.3  20.9   3.61   7.92   39.6   2.0  1.25  0.08   88.6
D5 favorito    Tiki taka/Juego directo   3.75   8.7   57.8   61.0   27.1  49.1  22.5   3.11  12.33   38.9   3.1  1.50  0.17   86.8
D5 favorito    Presion alta/Contragolpe  4.25   8.6   58.1   64.3   26.1  38.2  20.7   3.55   9.33   39.6   2.8  1.08  0.08   85.3
D10 parejo     Tiki taka/Juego directo   1.67   6.7   54.1   66.9   22.8  46.0  26.8   3.52  12.00   39.6   2.6  1.00  0.00   82.7
D10 parejo     Presion alta/Contragolpe  1.75   6.7   53.0   68.3   27.2  33.5  25.8   3.50  10.67   39.4   4.3  1.92  0.33   81.4
D10 tapado     Tiki taka/Juego directo   3.33   7.6   48.6   64.6   24.0  43.2  26.2   3.39  10.00   39.0   2.2  1.25  0.00   85.7
D10 tapado     Presion alta/Contragolpe  2.67   7.5   50.3   66.5   25.7  35.8  24.0   3.57  10.00   39.9   3.1  1.25  0.08   82.8
```

Medias de los 168 partidos, contra la copia "antes" medida el mismo dia:

| metrica | antes | etapa 7 | cambio |
| --- | --- | --- | --- |
| goles | 2.99 | 2.86 | -4.2% |
| tiros | 7.88 | 7.69 | -2.3% |
| posesion_pct | 53.5 | 54.0 | +0.4 pts |
| controlada_pct | 61.7 | 61.8 | +0.1 pts |
| pelota_parada_pct | 23.9 | 23.5 | -0.4 pts |
| pases | 41.1 | 42.2 | +2.6% |
| perdidas | 20.5 | 21.2 | +3.3% |
| duracion_posesion_seg | 3.50 | 3.52 | +0.4% |
| recuperaciones_altas | 8.27 | 8.58 | +3.7% |
| separacion_lineas_m | 39.4 | 39.4 | +0.0 m |
| faltas | 2.97 | 2.87 | -3.4% |
| resistencia_final_pct | 88.1 | 88.0 | -0.1 pts |
| recorrido_total_m | 16076 | 16230 | +1.0% |

Ninguna metrica cruza el 15% que el plan marca como señal. Lo que se
mueve cuenta una historia consistente: se corre un 1% mas y se pierde un
3,3% mas la pelota, porque el que persigue el partido manda una corrida
mas y acepta el pase que puede salir mal; y se recupera un 3,7% mas
arriba, que es el mismo equipo apretando con el bloque adelantado. Los
goles bajan 4,2%: el que gana cierra mejor, y el plan pide justamente que
no haya bonificacion de remontada.

Invariante 2 se mantiene: los 168 partidos dan el mismo marcador y los
mismos remates con y sin fotogramas.

### Costo

Tres pares alternados en la misma sesion, seis partidos por celda:

| corrida | antes | etapa 7 |
| --- | --- | --- |
| 1 | 317,0 ms | 327,5 ms |
| 2 | 318,2 ms | 327,4 ms |
| 3 | 317,1 ms | 327,8 ms |
| media | 317,4 ms | 327,6 ms |

**+3,2% sin fotogramas y +2,9% con fotogramas** (348,8 ms contra
359,0 ms). La dispersion dentro de cada build queda por debajo del 0,5%.
Muy por debajo del 20% que el plan marca como señal: la urgencia se
calcula dos veces por tick y por partido, no una vez por jugador, y
`pesos_marcador()` esta cacheada desde el principio.

### Verificaciones

`tests/test_contexto_marcador.gd`, catorce comprobaciones, `FALLOS=0`:

- La urgencia crece con el minuto: 0,000 al 5', 0,125 al 45', 0,579 al
  75' y 0,967 al 89' perdiendo 0-1.
- El signo sigue al marcador para los dos lados: ganando -1,000,
  empatando +0,234 y perdiendo +1,000 al 88'.
- El 91' del alargue no vale menos que el 90'.
- El Loco amplifica solo cuando pierde (0,935 a 1,000) y el Conservador
  solo cuando gana (-0,935 a -1,000).
- La misma escena defendiendo: -15,8 m temprano, -21,8 m ganando y
  -9,8 m perdiendo (local); -13,4 / -19,4 / -7,4 la visita. La diferencia
  entre ganar y perder no pasa el doble de `altura_bloque`.
- El cupo de corridas: 2 temprano, 1 ganando sobre la hora, 3 perdiendo.
- Perdiendo, el hueco suma +0,315 y el pase atras -0,315.
- Ganando, el apoyo corto y el pase atras suman +0,243, y el pase largo
  (-0,108) y el hueco (-0,162) restan.
- El peor ajuste de 2205 combinaciones es 0,350, que es el tope.
- El remate y la conduccion reciben CERO en todo el rango.
- Con el partido ganado no sale un tercero a cerrar, ni con Presion alta,
  y si sale temprano y perdiendo, para los dos lados.
- Calcular la urgencia no mueve el estado del RNG y da lo mismo dos
  veces.
- En 40 escenas al 89', la ventaja de arriesgar (mejor opcion arriesgada
  menos mejor opcion segura) pasa de -0,916 ganando 2-0 a -0,484
  perdiendo 0-2: 0,433 de corrimiento. Sigue siendo negativa, o sea que
  el marcador inclina la balanza y no obliga a nada.
- 8 partidos completos cierran, con 2,38 goles por partido.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 116 en 377s con 8 en
paralelo`.

### Un arreglo ajeno que hubo que hacer

`test_internacional_jugable.gd` empezo a fallar con esta etapa, en
"vuelven la fecha, la tabla y los equipos de cada fase de liga". No era
la etapa: `FaseLiga.tabla_ordenada` no tenia ultimo desempate, asi que
dos equipos con los mismos puntos, la misma diferencia y los mismos goles
quedaban en el orden en que el diccionario devolvia sus claves — y ese
orden lo fija el ORDEN DE CARGA. La misma tabla guardada y recargada
salia distinta. La etapa 7 cambio los resultados simulados y el empate
exacto aparecio; el bug estaba desde antes. Se agrego el nombre como
ultimo criterio. Con eso el test pasa y la regresion queda limpia.

### Pendiente de esta etapa

- **Revision visual: no hecha.** El cierre de partido que pide el plan
  —el que gana replegando y el que pierde volcandose— no se miro animado.
  Se acumula con las pendientes de las etapas 1, 2 y 4.
- **La urgencia se satura con dos goles de diferencia.** Al 88', un 2-0
  da 1,000 clavado en los dos sentidos, porque 1,35 por (88/90)^3 pasa de
  uno. O sea que un 2-0 y un 4-0 se juegan igual. `dif_tope` y el clamp
  son calibrables y no se barrieron.
- **No se midio el efecto POR SITUACION dentro de partidos reales.** Las
  alturas y las opciones arriesgadas se midieron en escenas controladas;
  cuanto tiempo pasa un partido con urgencia alta, y que hace ahi, no se
  instrumento.
- La etapa 3 sigue sin hacer; la 5 y la 6 tambien.
- `pesos_sin_pelota()` de la etapa 1 sigue sin cache.
- `project.godot` sigue sin `window/size/viewport_width/height`, del
  cambio ajeno sin commitear que ya anotaban las etapas 0, 1, 2 y 4. No
  lo toque.

## Etapa 8: resultados (2026-09-11)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Identidad individual (etapa
  8)", el armado de perfiles al final de `crear_estado`, los ajustes de
  perfil dentro de `_ponderar_plan` y el sesgo del jugador en
  `_valor_de_desmarque`.
- `data/utility_pesos.json`: seccion nueva `perfil`.
- `tests/test_identidad_individual.gd` (nuevo): las dieciseis
  comprobaciones.
- `docs/mediciones/realismo_etapa8.csv` y
  `docs/mediciones/realismo_etapa8_antes.csv` (nuevos).

### Que hace ahora el motor

Cada jugador de campo tiene un PERFIL: cinco preferencias entre cero y
uno que dicen a que juega.

- `asociacion`: la toca y se mueve. Pase corto, pared, hueco.
- `ruptura`: ataca el espacio por detras de la ultima linea.
- `regate`: se la lleva y encara al que tiene enfrente.
- `descarga`: recibe de espaldas y aguanta con el marcador encima.
- `llegada`: entra desde atras cuando la jugada ya paso.

Cada una sale de una mezcla de tres atributos que el motor ya usaba para
EJECUTAR esa accion (`asociacion` de pases/vision/inteligencia,
`regate` de control/agilidad/aceleracion, y asi), mas un sesgo del ROL —
el rol que trae el slot de la formacion, sin selector de puesto nuevo.
Los atributos van normalizados contra el nivel del partido, igual que en
`_por_atributo`: sin eso un plantel de decima quedaba con las cinco
preferencias planchadas contra cero.

**El perfil es la FORMA del jugador, no su nivel.** Las cinco
preferencias se centran contra la media del propio jugador antes de
salir. Sin ese centrado un crack tendria las cinco altas y cobraria
bonificacion en todas las opciones, que es regalarle utilidad por ser
bueno — y eso ya lo hacen sus atributos adentro de cada utilidad.
Medido: la media de las cinco preferencias da 0,500 tanto en primera
como en decima, y aun asi los 20 jugadores de campo separan su
preferencia fuerte de la debil al menos 0,15.

El arquero queda neutro a proposito: sus decisiones ya van por su rama
propia en `evaluar_opciones` y son de la etapa 6.

El perfil se arma una vez por partido y queda guardado en el dict del
jugador. Se rehace solo si le cambia el rol o si entra un suplente, que
es el punto 5 del plan; es una cuenta pura y no toca el RNG.

**Preferir no es saber**, que es el punto 4. El perfil mueve la utilidad
de la opcion y el valor del desmarque, y nada mas. Medido: 40 gambetas
resueltas con la misma semilla dan 18 ganadas con el perfil de regate al
maximo y 18 con el perfil al minimo. Tampoco lee personalidad ni
habilidades: esos dos sistemas ya empujan donde les toca (Egoista el
remate, Creador el hueco, Metodico la temperatura, Pie preferido el lado
malo) y sumarlos aca seria cobrar dos veces lo mismo.

El perfil mueve dos cosas, las dos con tope:

1. **Utilidad de la opcion** (`_ponderar_plan`, tope 0,30). La
   asociacion premia el pase corto y libre, la pared y el hueco; el
   regate premia la conduccion y la gambeta; la descarga la pide el
   RECEPTOR, no el pasador — el nueve de apoyo se ofrece de espaldas y
   por eso vale darsela aunque lo esten marcando.
2. **Valor del desmarque** (`_valor_de_desmarque`, 0,35). Es el sesgo
   del JUGADOR, al lado del sesgo del EQUIPO por tipo que ya traia la
   etapa 1. El llegador arranca desde atras y el extremo veloz ataca el
   espacio, pero la geometria sigue mandando: en 40 escenas, 67 rupturas
   repartidas con la preferencia al maximo contra 37 al minimo.

**El contexto apaga la preferencia**, que es el punto 3. Cada
bonificacion va multiplicada por lo que la jugada necesita: el extremo
encarador cobra 0,285 por la gambeta con espacio y 0,015 encerrado; el
asociador cobra 0,187 por el pase corto y libre y 0,000 por el largo y
tapado. El perfil inclina, no obliga.

**El remate queda afuera**, igual que en la etapa 7. Darle mas ganas de
patear al que tiene tiro alto es exactamente el abuso que arreglo
BUG-007.

### Medicion, con corridas pareadas

El "antes" se midio en la misma sesion. Se copio el proyecto a un
directorio aparte y en la copia se puso `perfil.reparto` en cero: con
eso las cinco preferencias de todos quedan en 0,5 clavado, el ajuste de
utilidad y el sesgo de desmarque dan cero, y el motor decide como en la
etapa 7. Esa copia reproduce la tabla de la etapa 7 CELDA POR CELDA, asi
que es el "antes" fiel — y de paso comprueba que la seccion nueva del
json se puede apagar entera sin romper nada.

Misma configuracion que las etapas 0, 1, 2, 4 y 7: semilla 77100, 12
partidos por celda, 14 celdas, 168 partidos, cada uno con y sin
fotogramas.

```
escenario      estilos                  goles tiros   pos% contr% parad% pases  perd posdur  altas lineas  falt  amar  roja resist
D1 parejo      Tiki taka/Juego directo   1.92   8.3   51.9   56.5   18.5  46.3  17.3   3.36   7.58   39.3   2.4  0.83  0.00   93.7
D1 parejo      Presion alta/Contragolpe  1.58   8.0   54.1   58.1   20.6  37.7  18.0   3.47   7.33   40.3   3.8  1.92  0.00   92.3
D1 favorito    Tiki taka/Juego directo   4.00   9.4   58.1   57.4   26.1  49.0  16.9   3.35   6.92   38.4   3.4  1.42  0.00   91.8
D1 favorito    Presion alta/Contragolpe  4.58   9.1   59.2   61.3   27.9  34.3  19.0   3.48   6.75   39.2   3.6  1.58  0.33   89.5
D1 tapado      Tiki taka/Juego directo   2.83   8.1   47.1   57.9   21.7  45.3  17.0   3.58   6.58   38.7   2.2  1.25  0.00   92.1
D1 tapado      Presion alta/Contragolpe  3.58   8.3   47.8   60.8   23.9  37.5  21.8   3.25   8.33   39.6   3.1  1.50  0.25   89.1
D5 parejo      Tiki taka/Juego directo   2.33   7.6   53.0   61.2   20.7  47.4  20.6   3.40   8.92   39.1   2.3  0.75  0.17   89.0
D5 parejo      Presion alta/Contragolpe  1.92   7.1   53.1   62.2   22.1  39.9  21.8   3.66   8.58   40.5   3.2  1.67  0.08   87.7
D5 favorito    Tiki taka/Juego directo   4.58   8.9   59.0   61.2   28.2  48.0  21.8   3.29   8.67   38.5   3.2  1.33  0.08   88.0
D5 favorito    Presion alta/Contragolpe  3.92  10.0   60.0   66.0   30.1  34.3  22.1   3.49  10.25   38.9   4.3  1.67  0.00   85.1
D10 parejo     Tiki taka/Juego directo   1.58   6.2   52.6   66.5   22.5  47.5  26.3   3.56  11.17   38.0   2.9  1.67  0.17   84.5
D10 parejo     Presion alta/Contragolpe  2.67   6.3   54.0   68.1   25.5  35.3  22.8   4.01   8.42   38.9   3.2  1.50  0.08   82.0
D10 tapado     Tiki taka/Juego directo   3.25   7.8   46.5   62.3   26.3  40.3  21.1   3.31   9.42   37.8   2.9  1.17  0.17   86.3
D10 tapado     Presion alta/Contragolpe  2.33   7.5   49.4   67.0   25.9  35.1  25.6   3.70   9.58   39.8   2.8  1.25  0.08   83.6
```

Medias de los 168 partidos, contra la copia "antes" medida el mismo dia:

| metrica | antes | etapa 8 | cambio |
| --- | --- | --- | --- |
| goles | 2.86 | 2.93 | +2.5% |
| tiros | 7.69 | 8.03 | +4.4% |
| posesion_pct | 54.0 | 53.3 | -0.7 pts |
| controlada_pct | 61.8 | 61.9 | +0.1 pts |
| pelota_parada_pct | 23.5 | 24.3 | +0.8 pts |
| pases | 42.15 | 41.26 | -2.1% |
| perdidas | 21.15 | 20.86 | -1.4% |
| duracion_posesion_seg | 3.52 | 3.49 | -0.6% |
| recuperaciones_altas | 8.58 | 8.46 | -1.3% |
| separacion_lineas_m | 39.4 | 39.1 | -0.3 m |
| faltas | 2.87 | 3.08 | +7.3% |
| amarillas | 1.36 | 1.39 | +2.6% |
| resistencia_final_pct | 88.0 | 88.2 | +0.2 pts |
| recorrido_total_m | 16230 | 16133 | -0.6% |

Ninguna metrica cruza el 15% que el plan marca como señal. Lo que se
mueve cuenta una sola historia: el que sabe encarar encara mas y el que
sabe tocarla la toca mas, asi que hay 2,1% menos de pases y 4,4% mas de
remates, y se pierde un 1,4% menos la pelota porque cada uno elige la
jugada que le sale. Las faltas suben 7,3%, que es la metrica que mas se
movio: cada gambeta trae su propia tirada de falta (`prob_falta_por_duelo`
en `_resolver_gambeta`), asi que mas uno contra uno es mas faltas, y las
amarillas la acompañan de lejos (+2,6%). Los goles suben 2,5%, dentro de
lo que mueve el ruido de 168 partidos.

Invariante 2 se mantiene: los 168 partidos dan el mismo marcador y los
mismos remates con y sin fotogramas.

### Costo

Tres pares alternados en la misma sesion, seis partidos por celda:

| corrida | antes | etapa 8 |
| --- | --- | --- |
| 1 | 339,2 ms | 331,4 ms |
| 2 | 335,6 ms | 333,9 ms |
| 3 | 335,3 ms | 333,9 ms |
| media | 336,7 ms | 333,1 ms |

**-1,1% sin fotogramas y -0,8% con fotogramas** (368,0 ms contra
365,2 ms). O sea, cero medible: el perfil se arma una vez por jugador y
por partido, queda guardado en su dict y despues solo se lee, y
`pesos_perfil()` esta cacheada desde el principio. Los signos negativos
son ruido de reloj, no una mejora — la corrida de 12 partidos por celda
dio -0,7% y -0,5%, del mismo orden.

### Verificaciones

`tests/test_identidad_individual.gd`, dieciseis comprobaciones,
`FALLOS=0`:

- Los 22 arrancan con perfil y los dos arqueros quedan en 0,5 parejo.
- La media de las cinco preferencias da 0,500 en primera y en decima, y
  los 20 de campo separan su fuerte de su debil al menos 0,15.
- El mismo jugador de extremo prefiere el regate 0,69 y de central 0,23.
- Dos construcciones dan el mismo perfil y el RNG no se mueve.
- Pasado de central a nueve, la descarga le sube de 0,81 a 0,88.
- El suplente que entra sin perfil en su dict se lo arma solo.
- El peor ajuste de 3888 combinaciones es 0,300, que es el tope.
- El remate recibe CERO en todo el rango.
- El encarador cobra 0,285 con espacio y 0,015 encerrado; el asociador
  0,187 por el pase corto y libre y 0,000 por el largo y tapado.
- Pasarle al nueve de apoyo marcado suma 0,221 contra 0,000, y hacia
  atras no cobra nada.
- Con el regate al maximo elige gambeta o conduccion 111 de 120 veces,
  contra 99 de 120 con el regate al minimo.
- Con la asociacion al maximo elige pase o pared 32 de 120, contra 25 de
  120 al minimo.
- Los dos perfiles extremos conservan la variedad de la escena: 4 y 5
  tipos distintos, y el mas elegido no se lleva mas de lo que ya se
  llevaba con el perfil del monton.
- 40 gambetas resueltas con la misma semilla dan 18 ganadas con el
  perfil al maximo y 18 al minimo.
- El sesgo de desmarque del monton es 0,000 y el del rompedor 0,350; en
  40 escenas, 67 rupturas repartidas al maximo contra 37 al minimo.
- 8 partidos completos cierran, con 2,38 goles por partido.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 117 en 319s con 8 en
paralelo`.

### Pendiente de esta etapa

- **Revision visual: no hecha.** Ver un extremo encarador y un nueve de
  apoyo jugando distinto en el partido animado es justamente lo que esta
  etapa promete y lo que no se miro. Se acumula con las pendientes de
  las etapas 1, 2, 4 y 7.
- **El abanico no se barrio.** `reparto` esta en 1,6 y decide cuanto se
  separan las preferencias de un mismo jugador; los pesos de utilidad
  (0,28 / 0,30 / 0,26) se pusieron por debajo del tope del marcador para
  que el perfil incline menos que el contexto del partido. Ninguno de
  los dos se barrio: se eligieron para mover poco y se midio que mueven
  poco.
- **Las faltas son lo unico que se movio de verdad (+7,3%).** Es efecto
  del uno contra uno y no del perfil en si —cada gambeta tira falta— pero
  si el numero molesta, la palanca es `prob_falta_por_duelo`, no
  `perfil.regate`.
- **Las cinco preferencias no las ve el usuario.** El perfil es
  derivado y no persistido, como pide el invariante 8, pero tampoco hay
  forma de mirarlo desde la ficha del jugador. Si se quiere que el
  jugador entienda por que su extremo encara, hay que mostrarlo.
- La etapa 3 sigue sin hacer; la 5 y la 6 tambien.
- `pesos_sin_pelota()` de la etapa 1 sigue sin cache.
- `project.godot` sigue sin `window/size/viewport_width/height`, del
  cambio ajeno sin commitear que ya anotaban las etapas 0, 1, 2, 4 y 7.
  No lo toque.

## Etapa 5: resultados (2026-09-13)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Cansancio por esfuerzo (etapa
  5)" despues de `_mover_hacia`; el techo de sprint en `_mover_hacia`; la
  marca `esfuerzo_en_juego` al principio de `_tick`; el cobro en
  `_cerrar_tick`; `energia` y `reserva` en el dict espacial de titulares y
  suplentes; el entretiempo y la reserva llena en `_jugar_periodo`;
  `stats.esfuerzo` en `simular`.
- `core/team.gd`: `recuperar`, la contracara de `desgastar`.
- `data/utility_pesos.json`: seccion nueva `esfuerzo`;
  `fisica.multiplicador_desgaste` baja de 12 a 5.
- `tests/test_cansancio_esfuerzo.gd` (nuevo): diecinueve comprobaciones.
- `tests/_diag_cansancio.gd` y `tests/_diag_esfuerzo_barrido.gd` (nuevos):
  mediciones.
- `docs/mediciones/realismo_etapa5.csv`, `realismo_etapa5_antes.csv` y
  `cansancio_etapa5.txt` (nuevos).

### Inventario del desgaste previo (punto 1)

- `_duelo_simple`: los dos jugadores, `multiplicador_desgaste` 12. Lo
  usan el robo, la gambeta y los duelos fisicos.
- Duelo del remate en `_resolver_tiro`: rematador y arquero, mismo
  multiplicador.
- Arco desprotegido en `_resolver_tiro`: solo el rematador.
- Bloqueo (`_gana_bloqueo`) e intercepcion (`_gana_intercepcion`): leen la
  resistencia y no cobran.
- Tiempo y carrera: nada. El motor espacial no cobraba el partido jugado.

No habia cobro duplicado. El problema era el contrario: un solo
responsable (el duelo) pagaba todo el partido.

### Que hace ahora el motor

Dos costos, cada uno con un solo responsable:

- **Correr**: `_contabilizar_esfuerzo`, una vez por tick y por jugador, al
  cerrar el tick. La intensidad es `(rapidez / vel_max)^2` mas `0,5` por
  el arranque (lo que acelero sobre lo mas que puede acelerar en un tick).
  La carga es intensidad por `TICK_SEG` y se cobra con `Team.desgastar`.
- **El contacto**: los mismos duelos de antes, con `multiplicador_desgaste`
  5. El duelo no lee la rapidez: el test comprueba que cobra lo mismo
  quieto que lanzado.

Dos depositos distintos:

- **Reserva de sprint** (0 a 1, en el dict espacial). Por encima de
  intensidad 0,55 se gasta (`consumo_sprint` 0,06 por segundo a pleno);
  por debajo se recupera (`recuperacion_reserva` 0,07 por segundo
  parado). Corre en segundos reales de `TICK_SEG`.
- **Resistencia** de `Team`, la de siempre. Caminar no la devuelve.

Con la reserva debajo de 0,5, la velocidad punta cae con curva suave hasta
el 85% (`piso_sprint`). Es un techo, no un multiplicador: el trote a la
marca no se entera. La resistencia sigue pesando en la ejecucion solo por
`Duel.atributo_efectivo`.

**Lo que no cobra** (punto 6): el tick que empieza con el juego detenido
(falta, gol, festejo, cambio), el que entra o sale de la cancha, y la tanda
de penales. En esas pausas la reserva si se recupera.

**Entretiempo**: devuelve el 25% de lo perdido en el primer tiempo, con
tope de 0,03, y nunca pasa de la energia con la que el jugador arranco el
partido. El corte antes del alargue no devuelve resistencia. Todo periodo
arranca con la reserva llena.

**Suplentes**: entran con su propia resistencia de `Team`, su `energia` y
la reserva llena.

### Calibracion

- `consumo_sprint`: barrido con `_diag_esfuerzo_barrido.gd`, 12 partidos.
  Con 0,10 el 33% de los ticks de jugador quedaban con la reserva baja,
  o sea medio equipo trotando todo el partido. Con 0,06 queda en 6%.
- `desgaste_por_segundo` y `multiplicador_desgaste`: elegidos para que la
  resistencia final media del espacial no se mueva. El duelo pasa de 12 a
  5 y correr cubre el resto. Con 0,16 la media daba 87,7%; con 0,15,
  88,1%, contra 88,3% antes.

### Medicion: cansancio por motor

`tests/_diag_cansancio.gd`, 20 partidos por division (1, 5 y 10), semilla
55100, contra la copia "antes" del mismo commit (`5291883`). Media de los
22 titulares con arqueros; desvio entre los de campo.

| metrica | antes | etapa 5 | abstracto |
| --- | --- | --- | --- |
| resistencia final media | 88,3% | 88,1% | 93,3% |
| desvio entre jugadores de campo | 11,15 | 5,73 | 5,61 |
| correlacion metros / energia perdida | 0,37 | 0,58 | - |
| cambios por cansancio por partido | 1,22 | 0,90 | 0,28 |

Por rol, en decima: DC 63,0% → 70,1%; MC 74,0% → 77,9%; DFC 95,0% →
88,6%; LAT 94,2% → 87,4%; ARQ 88,7% → 93,4%.

Lo que cuenta: el nueve ya no termina fundido por recibir todas las
patadas, y el central que corre la linea ya no termina fresco. La
dispersion se parte a la mitad y queda igual a la del abstracto. El
arquero sube porque ya no paga cada remate como un partido entero.

### Medicion: realismo, contra la copia "antes"

`tests/_diag_realismo.gd`, misma configuracion que las etapas anteriores:
semilla 77100, 12 partidos por celda, 14 celdas, 168 partidos.

| metrica | antes | etapa 5 | cambio |
| --- | --- | --- | --- |
| goles | 2,613 | 2,607 | -0,2% |
| tiros | 7,86 | 7,82 | -0,5% |
| posesion_pct | 54,2 | 53,2 | -1,0 pts |
| controlada_pct | 57,0 | 56,9 | -0,1 pts |
| pases | 40,05 | 40,26 | +0,5% |
| perdidas | 19,02 | 18,88 | -0,8% |
| recuperaciones_altas | 7,45 | 7,38 | -1,0% |
| faltas | 2,77 | 3,08 | +11,2% |
| amarillas | 1,30 | 1,52 | +17,4% |
| resistencia_final_pct | 88,6 | 88,9 | +0,3 pts |
| recorrido_total_m | 16656 | 16785 | +0,8% |

Goles y remates no se mueven. Diferencia pareada de goles: -0,006 por
partido con error estandar 0,125.

**Faltas y amarillas**: se investigo si era efecto de la etapa. Con otra
semilla (55900, 90 partidos, `_diag_esfuerzo_barrido.gd`) el modelo viejo
da 2,90 faltas y el nuevo 2,94 (+1,4%), con los mismos robos intentados
(24,7 contra 25,2). La diferencia de la tabla es ruido de muestra: 465
contra 517 faltas es 1,7 desvios, y las amarillas cuelgan de las faltas.

Invariante 2 se mantiene: los 168 partidos dan el mismo resultado con y sin
fotogramas, y el test compara ademas la resistencia final de los 22.

### Costo

Tres pares alternados en la misma sesion, 6 partidos por celda:

| par | antes | etapa 5 |
| --- | --- | --- |
| 1 | 361,1 ms | 399,0 ms |
| 2 | 367,5 ms | 402,0 ms |
| 3 | 367,2 ms | 398,5 ms |

**+9,5% sin fotogramas y +8,7% con fotogramas** (399,3 contra 434,1 ms).
Debajo del 20% que el plan marca como señal.

La primera version costaba +17,4%. El cobro llamaba dos funciones por
jugador, leia los pesos y escribia los contadores en cada vuelta: 34,7 ms
por cada mil ticks. Con la cuenta en linea, los pesos leidos una vez y los
contadores escritos al final, 22,9 ms. El resultado de los 84 partidos es
identico entre las dos versiones. Lo que queda es sobre todo
`Team.desgastar`, 22 llamadas por tick.

### Verificaciones

`tests/test_cansancio_esfuerzo.gd`, `FALLOS=0`:

- 20 s sprintando dejan la reserva en 0,45 y cuestan 0,0175 de resistencia;
  caminando, 1,00 y 0,0017. Para los dos lados.
- Caminar 40 s sube la reserva de 0,22 a 1,00 y la resistencia no vuelve.
- Juego detenido, festejo y tanda no cobran resistencia ni carga; la
  reserva si se mueve.
- El que sale hacia el lateral no paga la caminata.
- La capacidad sube sin escalones de 0,85 a 1; mayor salto 0,0045 por
  centesimo de reserva.
- Con la reserva vacia la punta cae de 6,85 a 5,82 m/s; el trote queda en
  3,08 m/s con reserva llena o vacia.
- 4000 ticks alternando piques y descanso: reserva en [0,1] y ninguna
  resistencia de los 22 fuera de [0,55; 1].
- El entretiempo devuelve 0,030 con tope, una fraccion de lo poco perdido
  y nada al que no perdio; cada periodo llena la reserva.
- El suplente entra con reserva llena, su `energia` y su resistencia, no
  la del que sale.
- El duelo cobra 0,0309 quieto y 0,0309 lanzado.
- Cobrar el esfuerzo y el entretiempo no mueven el RNG.
- 8 partidos de decima: mismo marcador y misma energia de los 22 con y sin
  fotogramas; 27 cambios por cansancio con config descanso; correlacion
  0,40 entre metros y energia perdida; reserva baja en el 7,4% de los
  ticks de jugador.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 122 en 342s con 8 en
paralelo`. No se hizo commit.

### Pendiente de esta etapa

- **Revision visual: no hecha.** El pique que se apaga con la reserva baja
  es justamente lo que hay que mirar animado.
- **La paridad de cansancio con `MatchEngine` ya estaba rota y sigue
  igual.** El espacial termina en 88,1% y el abstracto en 93,3%, y el
  espacial saca 0,90 cambios por cansancio contra 0,28. La brecha es
  previa a la etapa (88,3% contra 93,3%). Como `fatiga_acumulada` arranca
  del final del partido, el club del jugador llega a cada fecha mas
  cansado que la IA. Cerrarla es una decision de balance: se hace bajando
  `desgaste_por_segundo`, no tocando el abstracto.
- **La reserva no entra en las estimaciones de llegada.**
  `_tiempo_de_llegada` (defensa) sigue usando la resistencia y
  `_alcance_en` (arquero) la punta completa. Un presionante con la reserva
  vacia se estima un poco mas rapido de lo que corre.
- **El entretiempo se aplica despues de la ventana de cambios del 45'**:
  el que sale en el entretiempo se evalua con la resistencia del final del
  primer tiempo, sin la recuperacion.
- `consumo_sprint`, `piso_sprint` y la recuperacion del entretiempo no se
  barrieron a fondo: se eligieron para mover poco y se midio que mueven
  poco.

## Etapa 6: resultados (2026-09-13)

Estado: terminada. Archivos tocados:

- `core/motor_espacial.gd`: seccion nueva "Arqueros con decisiones (etapa
  6)"; la llamada a `_planificar_arqueros` en el paso 3 de `_tick`; el
  arquero en `_objetivo_sin_pelota`; el alcance real en `_resolver_centro`;
  la cobertura en `describir_ocasion` y en el duelo de `_resolver_tiro`;
  el rechazo en `_aplicar_remate`; la lectura con manos en
  `_gana_intercepcion`; `_soltar_pelota` sale de `_resolver_rebote`; el
  contador `stats.arqueros` en `simular`.
- `data/utility_pesos.json`: seccion nueva `arquero`. Sale `radio_achique`.
- `tests/test_salida_del_arquero.gd` y `tests/test_posicion_del_arquero.gd`:
  extendidos.
- `tests/_diag_arquero_decisiones.gd` (nuevo): la medicion de la etapa.
- `docs/mediciones/realismo_etapa6.csv` y `realismo_etapa6_antes.csv`.

### Que hace ahora el motor

El arquero sin la pelota tiene una INTENCION por tick. Se reparte desde
la misma foto que los desmarques y la defensa, en orden estable por clave,
y no consume RNG.

1. `interceptar` (puntos 1 y 2). Mira la trayectoria visible de una pelota
   rival o suelta que cae en su area. Compara su tiempo al punto, con
   rampa de aceleracion y reaccion por `achique`, contra la pelota, el
   atacante mas rapido y su companero mas rapido. Sale solo si le gana al
   atacante por `ventaja_base` mas `ventaja_por_metro` por metro fuera de
   la linea. Corre al punto con la fisica de todos. La pelota la toma el
   contacto de siempre; adentro del area el corte usa `achique` y
   `agarre`, no `quite`.
2. `achicar` (punto 4). Rival con pelota a menos de 24 m, sin companero
   en su camino al arco. Sale sobre la bisectriz entre pelota y postes,
   de 2,5 a 6,5 m segun `achique`, nunca a menos de 4 m de la pelota.
3. `volver`. Terminada la salida, vuelve a su ancla corriendo.
4. `sostener`. El ancla de antes, sin cambios.

**Centros** (punto 3). Antes descolgaba si estaba a 7 m al caer. Ahora
tiene que estar a su alcance (`ALCANCE_ESTIRADA` + 1 m) y adentro del
area. Sale al centro mientras vuela si llega plantado con margen.

**Posicion efectiva** (punto 4). `cobertura_arquero` mide que parte del
angulo entre postes tapa el arquero, visto desde la pelota. Entra al
duelo como factor `1 + 0,3 * (cobertura - 0,648)`, con tope ±30%. El
0,648 es la cobertura media de los duelos ANTES de la etapa, medida con
el planificador apagado: el promedio de la liga no se mueve por
construccion. Tambien queda en la instantanea de la ocasion (etapa 9).

**Rechazos** (punto 5). La atajada no retenida iba siempre al corner.
Ahora elige entre los dos corners —si la linea le queda a tiro— y cuatro
direcciones laterales, por menor amenaza: atacantes cerca y remate de
frente desde ahi. La amenaza del costado desempata el corner. Despues la
ejecucion se desvia hasta 1,6 rad, menos con buena `estirada` y menos si
el remate vino de lejos. Para atras sale por el fondo; nunca adentro del
arco propio. El penal manoteado sigue yendo al corner.

**Distribucion** (punto 6). No hizo falta codigo nuevo: la salida ya
pasaba por `evaluar_opciones`, `arquero_apurado` y `_ponderar_plan`. Se
agrego la prueba del estilo.

### Calibracion

- `rechazo_amenaza_corner`: barrido con 84 partidos. Con el corner como
  opcion fija 0,3, 0,6 y 1,0 daban 0 corners por rechazo: el costado
  siempre ganaba. Con el modelo final, 0,40 manda todo al corner y 0,60
  todo al costado. Quedo 0,45 con `rechazo_amenaza_suelta` 0,5: apunta al
  corner y la dispersion decide cuanto queda en juego.
- `rechazo_dispersion`: 1,2 y 1,6 dan corners casi iguales (1,065 y 1,054
  por partido). Quedo 1,6 porque separa mas al buen arquero del malo.
- `valor_posicion` como centralidad del rechazo daba ~0,90 a todos los
  puntos candidatos: 0 rechazos en juego en 168 partidos. Se cambio por
  `factor_angulo`.
- `cobertura_peso` 0,3: comparado contra 0 con una version intermedia
  del rechazo (168 partidos), goles 2,75 → 2,69 y conversion 52,0% →
  51,0%.

### Medicion, contra la copia "antes"

La copia del proyecto se hizo antes de tocar nada, con los cambios ajenos
de la etapa 9 incluidos. Misma configuracion que las etapas anteriores:
semilla 77100, 12 partidos por celda, 14 celdas, 168 partidos.

`tests/_diag_realismo.gd`, medias de los 168 partidos:

| metrica | antes | etapa 6 | cambio |
| --- | --- | --- | --- |
| goles | 2.685 | 2.613 | -2.7% |
| tiros | 7.63 | 7.86 | +3.0% |
| posesion_pct | 53.5 | 54.2 | +0.7 pts |
| controlada_pct | 57.2 | 57.0 | -0.2 pts |
| pelota_parada_pct | 22.5 | 22.0 | -0.5 pts |
| pases | 39.21 | 40.05 | +2.1% |
| perdidas | 19.79 | 19.02 | -3.9% |
| duracion_posesion_seg | 3.50 | 3.57 | +2.1% |
| recuperaciones_altas | 7.47 | 7.45 | -0.2% |
| separacion_lineas_m | 39.3 | 39.4 | +0.1 m |
| faltas | 2.80 | 2.77 | -1.3% |
| resistencia_final_pct | 88.7 | 88.6 | -0.1 pts |

`tests/_diag_arquero_decisiones.gd`, por partido:

| metrica | antes | etapa 6 |
| --- | --- | --- |
| tiros al arco | 4.70 | 4.92 (+4.7%) |
| atajadas | 2.14 | 2.46 (+15.0%) |
| goles de juego | 2.56 | 2.46 (-4.0%) |
| conversion al arco | 54.5% | 50.0% |
| corners | 1.25 | 1.05 (-15.7%) |
| rechazos afuera / en juego | todos afuera | 0.55 / 0.30 |
| remates tras rechazo | - | 0.024 |
| goles tras rechazo | - | 0.006 |
| achiques iniciados | - | 5.9 |
| salidas a cortar | - | 0.13 |
| cobertura media en el duelo | 0.648 | 0.704 |
| distancia a su linea | 2.79 m | 2.85 m |
| centros descolgados | 0 | 0 |

Goles y tiros no cruzan el 15%. Lo que se mueve cuenta una historia: el
arquero achica en el uno contra uno, tapa mas arco (0,648 → 0,704) y ataja
mas (+15%). Los corners bajan porque un tercio de los rechazos queda en
juego. Invariante 2 se mantiene: los 168 partidos dan el mismo resultado
con y sin fotogramas.

### Costo

Tres pares alternados, 6 partidos por celda, en la misma sesion:

| par | antes | etapa 6 |
| --- | --- | --- |
| 1 | 343,1 ms | 358,8 ms |
| 2 | 341,4 ms | 355,7 ms |
| 3 | 345,6 ms | 356,5 ms |

**+4,0% sin fotogramas y +3,4% con fotogramas** (377,1 contra 389,8 ms).
El gasto es el ancla del arquero y la busqueda del punto de corte, que
solo recorre a los 21 cuando algun punto de la trayectoria cae en el area.

### Verificaciones

`tests/test_salida_del_arquero.gd`, `FALLOS=0`, los casos nuevos en los
dos sentidos de la cancha:

- Pase al hueco con el atacante a 24 m: sale a `interceptar`, llega
  corriendo (paso maximo 0,94 m por tick) y se queda con la pelota.
- Mismo pase con el atacante a 3 m: nunca `interceptar` y no la toma.
- 200 remates desde 14 m: 24 y 44 goles con el arquero en su lugar
  (tapa 0,75); 138 con el arquero salido a cortar al otro lado (tapa 0).
- Desde 13,2 m vuelve a 0,8 m en 6 s, con pasos de 1,47 m como maximo;
  13 ticks `volver` y despues `sostener`.
- La misma foto da la misma intencion y el RNG no se mueve.
- Sin presion, sacarla larga le rinde 0,40 a Juego directo y -0,62 a
  Tiki taka.

`tests/test_posicion_del_arquero.gd`, `FALLOS=0`:

- Las dos pruebas anteriores siguen: 2,72 y 2,84 m de su linea.
- Rival solo a 18 m: achica a 5,74 m con `achique` 90 y a 2,74 m con 10,
  igual angulo a cada palo; tapa 0,87 contra 0,63 en la linea; el primer
  tick lo acerca con un paso fisico.
- Con un central en el camino del rival se queda en `sostener`.
- 120 centros: 0 descuelgues parado a 6 m (adentro del radio viejo) y 57
  debajo de la pelota. Sale al centro que cae a 6 m, no al que cae a 14 m.
- 300 rechazos con dos atacantes de un lado: ninguno al lado ocupado ni
  adentro del arco; estirada 95 deja 31 y 27 en juego, estirada 10 deja
  116 y 100.

Regresion completa: `ARCHIVOS_CON_FALLAS=0 de 121 en 394s con 8 en
paralelo`. No se hizo commit: el arbol tiene sin commitear los cambios de
la etapa 9 (puntos 9.3 a 9.5).

### Pendiente de esta etapa

- **Revision visual: no hecha.** La salida al hueco, el achique y el
  rechazo en juego son justamente lo que hay que mirar animado.
- **Centros descolgados siguen en 0 en partido.** El centro cae en
  promedio a 16 m del arquero (medido antes: 5 de 123 a menos de 7 m). La
  regla ya es fisica; si se quieren descuelgues, lo que falta es que los
  centros caigan mas cerca del arco, no agrandar el alcance.
- **Los corners bajan 15,7%** y ya eran pocos (1,25 por partido). Si
  molesta, la palanca es `rechazo_dispersion` o `rechazo_amenaza_corner`.
- **La paridad con `MatchEngine` no se midio.** Goles -2,7% contra la
  copia; el abstracto tiene su propio rebote por `agarre`.
- `rechazo_amenaza_suelta` y `rechazo_amenaza_corner` casi empatan: con
  estos valores el arquero apunta siempre al corner cuando la linea le
  queda a tiro, y el costado solo gana lejos del arco.

## Etapa 9: inicio por Codex (2026-09-11)

Punto 9.1 implementado: `MotorEspacial.describir_ocasion` devuelve una
instantánea previa al desenlace. Incluye distancia en metros, ángulo entre
postes en radianes, presión normalizada, bloqueador, obstrucción, posición
del arquero y tipo de remate. Reutiliza presión y detección de bloqueo
existentes. No consulta habilidad, no consume RNG ni modifica jugadores.

El diagnóstico opcional de BUG-007 incorpora esta instantánea en cada
registro de remate. La posición del arquero se copia como coordenadas
escalares; un arquero ausente queda como `null`. Cabecear y patear penales
excluye el bloqueo corporal en la descripción, como sus rutas actuales.
El registro actual sigue excluyendo los penales.

La descripción no asigna una probabilidad ni modifica la resolución.
El punto 9.6 agrega el diagnóstico por calidad geométrica. La calibración final debe valorar los factores
observados que todavía no intervienen en la probabilidad de conversión.
La etapa completa permanece abierta.

Archivos: `core/motor_espacial.gd`, `tests/test_contexto_ocasion.gd` y este plan.
Pruebas: escenarios en ambos sentidos; frente y banda; presión y bloqueo;
cabezazo y penal; instantánea del arquero; arco vacío y posición en poste.
`test_tiro_lejano.gd` pasa, incluida igualdad con/sin fotogramas y diagnóstico.

Las primeras mediciones en procesos separados (30 partidos cada una,
semilla 4400) no reprodujeron los resultados. No se usan para atribuir
cambios de balance. La comprobación pareada se realiza dentro de un mismo
proceso con diagnóstico apagado y encendido, comparando también el RNG final.
Resultado: 30 pares (divisiones 1, 5 y 10; semillas 9001–9010), 180
ocasiones registradas, eventos/estadísticas/XP/RNG idénticos. Las 21
comprobaciones de `test_contexto_ocasion.gd` terminan con `FALLOS=0`.
No se realizó revisión visual ni medición de rendimiento para este punto.

### Punto 9.2: contexto y ejecución separados (2026-09-11)

Implementado. `ocasion.geometria_comun` usa la geometría sin jugador.
`ejecucion` conserva aparte técnica normalizada, geometría del rematador
y `probabilidad_modelo_porteria_sin_bloqueo`. Este último valor incluye
habilidad y expresa la probabilidad de ir al arco **si supera el bloqueo**.
No expresa probabilidad de gol ni xG. El registro identifica además los
desenlaces forzados del laboratorio para no confundirlos con muestras naturales.

`modelo_destino_remate` concentra las fórmulas vigentes de destino.
La resolución usa esos mismos valores; el diagnóstico no recalcula otra
probabilidad. Se calculan antes de la tirada de bloqueo, por lo que también
los intentos bloqueados conservan su evaluación previa. Cabecear y patear
libres mantiene la mezcla anterior; los penales siguen su ruta independiente.
No se ajustaron pesos ni se agregaron penalizaciones por presión u obstrucción.

Verificación: `test_contexto_ocasion.gd`, 25 comprobaciones sin fallas.
Incluye 30 pares en divisiones 1, 5 y 10 (semillas 9001–9010), 180 remates:
diagnóstico apagado/encendido conserva eventos, estadísticas, XP y RNG final.
`test_tiro_lejano.gd` y `test_laboratorio.gd` terminan con `FALLOS=0`.
`test_penal_espacial.gd` completa sus cinco comprobaciones con `OK`.
La prueba de BUG-007 conserva las frecuencias controladas medidas antes
de esta extracción, con 1000 semillas por escenario y ambos sentidos.
No se ejecutó regresión completa ni se hizo commit para este punto.
La integración posterior se documenta en el punto 9.3.

### Punto 9.3: integración y auditoría (2026-09-11)

Implementado sobre las fórmulas vigentes. La resolución y el diagnóstico
comparten una sola instantánea de ocasión. El candidato al bloqueo sale
de esa instantánea; la geometría alimenta el modelo de destino y el
factor de fuerza se calcula allí y se aplica una vez en el duelo.

No se encontró castigo triple al defensor: el bloqueo se resuelve primero,
la presión no vuelve a penalizar puntería y el defensor no interviene
en el duelo con el arquero. Se conserva distancia en puntería y potencia
porque representan fallos distintos; no se añaden multiplicadores.

Ver [auditoría y mediciones](mediciones/ocasion_etapa93.md).
60 pares contra una copia previa: resultado completo y RNG idénticos,
incluidos fotogramas. Divisiones 1/5/10, semillas 9300–9309, con y sin
fotogramas. Cada modalidad suma 51 goles y 204 remates en 30 partidos.
Regresión completa: `ARCHIVOS_CON_FALLAS=0 de 118 en 337s con 8 en paralelo`.

Al cerrar 9.3, la posición del arquero todavía no modificaba la probabilidad
de atajada. El punto 9.5 agrega la comprobación de alcance imposible.
Sigue pendiente un valor global de calidad calibrado.
La trazabilidad posterior se documenta en el punto 9.4.

### Punto 9.4: identificador y aplicación única (2026-09-11)

Cada intento recibe `remate_id`, secuencial dentro del partido, sin RNG.
El identificador enlaza registro opcional, remate en vuelo, evento final
y `goles_log`. Los bloqueados también reciben identificador. Los penales
y las tandas comparten la secuencia, conservando sus estadísticas separadas.

La ocasión y la evaluación del modelo permanecen en el registro previo
a las tiradas. Aplicar el desenlace no las recalcula. Repetir el lanzamiento
o aplicar una copia del mismo remate no duplica goles, eventos ni consumo
de RNG. Las llamadas antiguas sin identificador lo adquieren automáticamente.
Los identificadores son locales al partido; no identifican partidos distintos.

La comprobación detectó una pérdida previa de remates tras centros:
`_entregar_rodando` dejaba `dirigida_a`, que prevalecía sobre `es_remate`
en el avance de pelota. El vuelo podía terminar como entrega y perder
su evento. `_lanzar_remate` limpia ahora esa entrega anterior.

`tests/test_identificador_remate.gd`: 45 comprobaciones sin fallas.
Incluye goles, atajadas, afuera, palos, penales y tandas en ambos sentidos;
relanzamiento; aplicación duplicada de una copia; conservación del valor
previo y 12 partidos completos. Los 79 intentos de esa muestra, incluidos
8 bloqueos, enlazan registro y evento sin duplicados.

[Medición pareada](mediciones/ocasion_etapa94.md): 90 pares, divisiones
1/5/10, semillas 9400–9429. Eventos faltantes: 4→0; goles: 153→154;
remates: 603→593. La variante anterior solo omite limpiar la entrega.
Regresión: 119 archivos, cero fallas (437 s, 8 procesos). Tras añadir la
guarda final de relanzamiento, identificador, tiro lejano, laboratorio y
alargue/penales se verificaron nuevamente sin fallas.

La etapa completa sigue abierta. Las rutas especiales se revisan en 9.5.
No se hizo commit ni revisión visual en 9.4.

### Punto 9.5: rutas especiales y arcos desprotegidos (2026-09-13)

Implementado. La ocasión registra si el arquero puede alcanzar alguna
trayectoria al arco con su velocidad, aceleración y estirada. La comprobación
usa una cota favorable al arquero; solo descarta intervenciones imposibles.
Un arquero ausente o en tránsito tampoco puede atajar.

Con arco desprotegido se mantienen bloqueo, puntería y palos. Si el remate
los supera, entra sin inventar un duelo, desgaste ni XP del arquero.
Con arquero alcanzable se conserva la resolución anterior. Penales y tandas
mantienen su ruta; cabezazos y libres conservan atributos y bloqueo específicos.
No se ajustan pesos ni probabilidades generales de la liga.

[Informe y evidencia](mediciones/ocasion_etapa95.md): 34 comprobaciones,
6600 resoluciones controladas. Antes había 12 fallas por atajadas imposibles;
ahora ninguna. 90 pares de partidos conservan resultado completo y RNG:
162 goles y 581 remates en cada versión. Esa muestra no contiene arcos
desprotegidos; el efecto excepcional se comprueba en las escenas controladas.
Regresión completa: 120 archivos, cero fallas, 325 s con 8 procesos.
Resultado confirmado y guardado el 2026-09-13.

La cobertura parcial no se calibra aquí. El diagnóstico por intervalos se
documenta en 9.6. Sin commit ni revisión visual en este punto.

### Punto 9.6: intervalos y conversión observada (2026-09-13)

Implementado en `tests/_diag_remates.gd` y `tests/resumen_ocasiones.gd`.
El indicador es geometría común sin habilidad: cinco intervalos entre 0 y 1.
Separa tiros, cabezazos y libres, con intentos, goles, bloqueos y conversión.
Cada intervalo conserva subgrupos por presión y posibilidad de intervención
del arquero. No se presenta el indicador geométrico como xG ni probabilidad.

Solo cuentan resultados confirmados mediante el evento del mismo `remate_id`.
Se informan exclusiones por resultado sin confirmar, dato inválido, falta de
contexto, laboratorio forzado y duplicados. Los penales siguen separados.
La agregación no modifica los registros ni interviene en la simulación.

`test_resumen_ocasiones.gd`: diez comprobaciones sin fallas. Ver
[informe y mediciones](mediciones/ocasion_etapa96.md).
La medición usa 100 partidos por división (1/5/10), semillas 4400–4499.
Los cambios simultáneos del arquero pertenecen a otra tarea; el diagnóstico
guarda una copia de la fuente del motor cargada y su hash.
Corrida final: 300 partidos, 2019 intentos, 464 goles confirmados; cero
exclusiones. Intervalos y subgrupos cuadran con los registros. El motor
permaneció estable y la copia guardada coincide con el hash del informe.

Los seis puntos tienen implementación. La etapa completa sigue abierta
hasta calibración final, comparación con el abstracto y revisión visual.
Esta medición descriptiva no sustituye la matriz con equipos desparejos e ida/vuelta.

### Aceptación final (2026-09-14)

Calibrada y comparada con el abstracto. Ver [informe completo](mediciones/aceptacion_etapa9.md).

Un embudo nuevo (`tests/_diag_embudo_remates.gd`) corre los dos motores con
los mismos planteles, 600 partidos con ida y vuelta. Encontró tres causas
de la brecha de goles:

1. La fuerza del remate y la cobertura del arquero multiplicaban el
   atributo absoluto. El arquero de primera atajaba 63% contra 47% en
   décima; el abstracto, 46% y 45%.
2. El remate medio llegaba al arquero con 4,6 puntos menos (factor de
   fuerza medio 0,90).
3. Los partidos parejos generan 13% a 28% menos remates.

Cambios en `core/motor_espacial.gd` y `tiro_resolucion`:

- `puntos_de_contexto`: fuerza, cobertura y bloqueo a quemarropa cuentan
  en puntos al nivel de referencia.
- `fuerza_referencia` 0,90: la fuerza se centra en su media.
- `castigo_presion` 0,25 centrado en `presion_referencia` 0,37: la presión
  de los rivales que no son el candidato al bloqueo resta puntería al
  remate de pie.

Brecha de goles con el abstracto, antes → después: 1/1 −38% → −11%; 1/4
−19% → −4%; 5/5 −30% → −13%; 5/8 −17% → −11%; 10/10 −36% → −29%; 10/7
−16% → −10%. Décima pareja sigue fuera del 15% por volumen de remates
(5,9 contra 8,2), que es generación de juego y no calidad de ocasión.

Remate lejano: los intentos de 25 m o más con tiro 70-99 pasan de 66 a 74
en 300 partidos y convierten 16,7% → 16,2%. La conversión por calidad
geométrica ahora crece con la calidad. Realismo (168 partidos): goles
+11,5%, remates −1,9%; mismo resultado con y sin fotogramas.

`tests/test_aceptacion_ocasion.gd` (nuevo) cubre ángulo, presión, bloqueador,
arquero corrido y la misma ocasión en 40 y en 85, para los dos lados.
Pendiente: revisión visual.

### Validación cuantitativa de la etapa 9 (2026-09-13)

Matriz terminada: 600 enfrentamientos, 100 por combinación de división y
desigualdad, con ida/vuelta; 2400 simulaciones. Cero diferencias del resultado
completo y RNG entre ejecución con y sin fotogramas. Goles y remates sin
variación frente a la base 9.6; coste entre −1,07% y +0,13% por celda.

El espacial produce entre 18,2% y 50% menos goles que el abstracto. La brecha
ya está en la base y los intervalos emparejados excluyen cero. No se ajustaron
pesos. Falta identificar la causa mediante un embudo comparable de ocasiones,
remates y destinos; la revisión visual sigue pendiente. La medición no cierra
la aceptación general ni representa una comparación contra la etapa 0.
Ver [informe, método y evidencia](mediciones/calibracion_final.md).

## Orden de integración por tick

Adaptarlo a las interrupciones y orden real del motor; preservar primero las rutas de pelota parada y cambios:

1. Resolver validez de jugadores, fase y contexto.
2. Tomar instantánea; actualizar planes colectivos cuando corresponda.
3. Calcular objetivos desde esa instantánea y mover jugadores con límites físicos.
4. Avanzar pelota; resolver contacto, recepción y disputas una sola vez.
5. Ejecutar decisión si existe poseedor habilitado; conservar prioridades actuales de gol/falta/fin de período.
6. Contabilizar esfuerzo y métricas; producir fotograma opcional.

No reorganizar todo el bucle de una vez. Incorporar cada etapa en el orden existente y comprobar regresiones antes de pasar a la siguiente.

## Pruebas, medición y aceptación final

Usar el ejecutable Godot disponible en el entorno. Ejemplo desde la raíz del repositorio, sustituyendo la ruta del ejecutable:

```powershell
& $godotExe --headless --path .\super-pocket-stars --script res://tests/test_identidad_tactica.gd
```

Revisar cómo reportan fallos las pruebas: no asumir que exit code cero implica éxito si el script imprime errores sin propagarlos. No tocar la partida del usuario; usar datos sintéticos y directorio de usuario aislado para pruebas que escriban.

- Por etapa: pruebas deterministas de situaciones controladas y regresiones de los subsistemas afectados. Añadir tests de comportamiento, no copias de la fórmula implementada.
- Antes de cerrar: ejecutar identidad táctica, movimiento sin pelota, roles, personalidad, formaciones, pases, arqueros, reanudación, saque del medio, barrera, penal, expulsados, cambios, fin de mitad, alargue y laboratorio. Localizar nombres vigentes bajo `tests/`.
- Para tendencias probabilísticas: varias semillas, diferencias emparejadas y dispersión. No exigir que cada partido individual siga la tendencia.
- Calibración final: al menos 100 partidos por combinación elegida de división y desigualdad, con enfrentamientos de ida/vuelta. Informar coste y tamaño real de muestra.
- Comparar contra la línea de base espacial y el abstracto como referencia. Los pases de cuatro minutos no equivalen a los de noventa: no forzar conteos profesionales completos dentro del partido comprimido.
- Señales para investigar, no objetivos futbolísticos: variación de goles/remates mayor al 15% frente a base o coste por partido mayor al 20%. Examinar causa y dispersión antes de ajustar parámetros.
- Revisar visualmente clips reproducibles: salida bajo presión, pared, ruptura diagonal, pérdida y repliegue, control largo, uno contra uno del arquero y cierre de partido. Las capturas estáticas no prueban fluidez.
- Medir ejecución sin fotogramas y con fotogramas por separado. Evitar búsqueda combinatoria de asignaciones; con 22 jugadores basta asignación voraz estable y caché por tick.
- Terminar con informe de resultados, límites y parámetros ajustados. Si no hubo revisión visual o prueba de rendimiento, declararlo pendiente.

## Avance

- [x] 0. Línea de base y diagnóstico reproducible. Ver "Etapa 0: resultados".
- [x] 1. Juego sin pelota. Ver "Etapa 1: resultados".
- [x] 2. Defensa coordinada. Ver "Etapa 2: resultados".
- [x] 3. Control y orientación corporal. Ver "Etapa 3: resultados".
- [x] 4. Ritmo variable. Ver "Etapa 4: resultados".
- [x] 5. Cansancio por esfuerzo. Ver "Etapa 5: resultados".
- [x] 6. Decisiones del arquero. Ver "Etapa 6: resultados".
- [x] 7. Contexto del marcador. Ver "Etapa 7: resultados".
- [x] 8. Identidad individual. Ver "Etapa 8: resultados".
- [x] 9. Calidad de ocasiones. Puntos 9.1–9.6 y calibración final. Ver "Aceptación final"; revisión visual pendiente.
- [ ] Regresión, calibración, revisión visual y documentación final.

## Texto para iniciar la implementación

> Leé `super-pocket-stars/docs/plan_realismo_simulacion.md` e implementá todas sus etapas. Revisá las instrucciones del repositorio y el código actual. Extendé lo existente, conservá cambios ajenos y mantené los dos motores. Trabajá por etapas con pruebas y mediciones. Actualizá el avance del documento con evidencia. No te quedes en planificación: implementá, verificá y documentá los resultados y pendientes reales.
