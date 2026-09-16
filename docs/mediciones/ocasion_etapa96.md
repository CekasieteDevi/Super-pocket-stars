# Etapa 9.6: diagnóstico por intervalos

Fecha: 2026-09-13.

`tests/_diag_remates.gd` imprime y exporta `calidad_ocasiones`. Agrupa la
geometría común sin habilidad en [0,0.2), [0.2,0.4), [0.4,0.6), [0.6,0.8)
y [0.8,1]. Separa tiro, cabezazo y tiro libre.

Es **calidad geométrica del modelo**, no xG ni probabilidad de gol.
No combina arbitrariamente presión y arquero en un coeficiente nuevo.
Cada intervalo conserva subgrupos por presión ([0,0.33), [0.33,0.66),
[0.66,1]) y por posibilidad de intervención del arquero. Un dato ausente
forma su propio subgrupo. El diagnóstico no cambia decisiones ni balance.

## Denominadores y exclusiones

Conversión observada = goles confirmados / intentos con evento final.
Incluye bloqueados. El evento se enlaza mediante `remate_id`; el desenlace
previsto durante el vuelo no basta para contar un gol.

El resumen informa exclusiones: laboratorio forzado, contexto ausente,
geometría inválida, resultado sin confirmar e identificador duplicado.
La deduplicación es por partido: dos partidos pueden usar el mismo ID.
Los penales siguen fuera del registro. Los intervalos vacíos se omiten;
no se les atribuye conversión cero.

`tests/resumen_ocasiones.gd` realiza la agregación sin modificar los datos
originales. Puede reutilizarse sobre registros que incluyan contexto y
`resultado_observado`. Cada subgrupo conserva sus propios conteos y tasa.

## Verificación

`tests/test_resumen_ocasiones.gd`: diez comprobaciones, `FALLOS=0`.
Verifica extremos, denominadores con bloqueos, IDs repetidos entre partidos,
duplicados dentro del partido, exclusiones, datos vacíos, tipos de remate,
subgrupos, conservación de los registros y prioridad del resultado observado.

No se modificó el motor ni sus pesos en este punto. La medición incorpora
el estado de trabajo vigente, incluidos cambios del arquero de otra tarea.
Su hash y estabilidad durante la corrida quedan en el JSON.

## Reproducir

```powershell
& '..\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/_diag_remates.gd -- partidos=100 salida=docs/mediciones/ocasion_etapa96/ocasiones.json
```

Son 100 partidos por división, divisiones 1/5/10, semillas 4400–4499:
300 partidos en total. Es una medición descriptiva; no la calibración final
con desigualdad de equipos e ida/vuelta prevista por el plan.

La revisión visual y la aceptación final de la etapa completa quedan pendientes.

## Resultado

300 partidos, **2019 intentos y 464 goles confirmados**, sin exclusiones.
Los conteos de intervalos y subgrupos cuadran con los registros originales.
El motor permaneció estable durante la corrida final. Se descartó una
corrida preliminar cuyo archivo de motor cambió por trabajo simultáneo.

| Remate de pie: geometría | Intentos | Goles | Conversión |
| --- | ---: | ---: | ---: |
| [0,0.2) | 360 | 58 | 16,1% |
| [0.2,0.4) | 695 | 130 | 18,7% |
| [0.4,0.6) | 357 | 91 | 25,5% |
| [0.6,0.8) | 113 | 32 | 28,3% |
| [0.8,1] | 35 | 4 | 11,4% |

El indicador geométrico no produce una conversión monótona. El último
intervalo tiene solo 35 intentos; geometría sola no explica el resultado.
La habilidad y los contextos de presión/arquero permanecen separados.
Estos números no validan un modelo de xG ni demuestran efectos causales.

Los cabezazos suman 415 intentos y 142 goles; los libres, 44 y 7.
El [JSON completo](ocasion_etapa96/ocasiones.json) conserva todas las
filas, intervalos, subgrupos, parámetros y hashes. También se guardan la
[salida de consola](ocasion_etapa96/medicion.log), el
[motor cargado](ocasion_etapa96/ocasiones.json.motor.gd) y el
[diagnóstico medido](ocasion_etapa96/diagnostico_medido.gd).

El hash de la copia del motor coincide con el declarado en el JSON:
`988931384f7589d011452cec41dc71eec93820455fd66f78126c945fb9059315`.
La carpeta tiene `.gdignore` para evitar importar las copias como código activo.
Después de medir solo se quitó una línea vacía final del diagnóstico activo.

No se repitió la regresión completa: el cambio está limitado al diagnóstico.
Se verificaron el agregador y la ejecución real de 300 partidos. Sin commit.
