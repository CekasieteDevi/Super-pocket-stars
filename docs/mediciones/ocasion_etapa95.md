# Etapa 9.5: rutas especiales y arcos desprotegidos

Fecha: 2026-09-11.

## Problema y corrección

La resolución consultaba los atributos del arquero del equipo aunque
estuviera lejos de la trayectoria o ausente del estado espacial. En escenas
de 300 intentos, atajaba entre 110 y 154 veces sin poder llegar.

`_arquero_puede_intervenir` comprueba si existe un arquero activo que pueda
alcanzar alguna trayectoria entre rematador y postes. Usa velocidad,
aceleración, estirada y velocidad del remate ya existentes. No añade pesos.

La comprobación favorece al arquero: usa todo el triángulo de trayectorias
posibles y el tiempo hasta el poste más lejano. No castiga orientación
ni reacción. Si ni siquiera con esa cota llega, el arco queda desprotegido.
Estar adelantado dentro del triángulo no se considera dejar el arco vacío.

`describir_ocasion` conserva `arco_desprotegido` antes del resultado.
Un remate a ese arco todavía atraviesa bloqueo y puntería. Si los supera,
entra: no inventa un duelo contra el arquero ausente, ni le asigna desgaste,
XP o animación de atajada. El rematador conserva su desgaste y el gol
mantiene vuelo, identificador y aplicación diferida.

## Rutas conservadas

- Penales y tandas: mantienen su resolución independiente.
- Cabezazos: mantienen atributo y puntería específicos, sin bloqueo corporal.
- Tiros libres: mantienen atributo y barrera, incluida distancia de bloqueo.
- Laboratorio: los desenlaces forzados siguen disponibles para sus clips.
- Arco cubierto: mantiene el duelo y las probabilidades anteriores.

La prueba de BUG-007 colocaba también al arquero lejos del arco para aislar
puntería. Sus frecuencias de ir al arco no cambian; ahora esos tiros al arco
son goles. La comparación con arquero ubicado se hace en la nueva prueba.

## Escenas controladas

`test_arco_desprotegido.gd`: 34 comprobaciones, `FALLOS=0`. Usa 6600
resoluciones con 300 semillas por combinación, ambos sentidos, tres tipos
de remate y escenarios adicionales con bloqueo.

| Local, 300 intentos | Gol cubierto | Gol desprotegido | Atajada desprotegido | Afuera | Palo |
| --- | ---: | ---: | ---: | ---: | ---: |
| Pie | 95 | 205 | 0 | 84 | 11 |
| Cabeza | 100 | 218 | 0 | 68 | 14 |
| Libre | 100 | 218 | 0 | 68 | 14 |

Con arquero cubierto estos resultados coinciden con los medidos antes de
integrar la corrección. Ausente o imposibilitado de llegar producen la misma
distribución; afuera y palos se conservan. El bloqueo sigue resolviéndose.
También se prueban arquero adelantado, inmóvil, con velocidad y saliendo
de la cancha. Antes del arreglo, la prueba tenía 12 fallas.

`test_contexto_ocasion.gd`: 30 pares con/sin diagnóstico conservan eventos,
estadísticas, XP y RNG; 182 ocasiones registradas, `FALLOS=0`.
Pasan además BUG-007, laboratorio, barrera de tiro libre y penal espacial.

## Límites

Es una clasificación física conservadora, no una probabilidad calibrada
de cobertura parcial. Un arquero alcanzable todavía usa su duelo anterior.
No implementa decisiones nuevas de salida: pertenecen a la etapa 6.
No se realizó revisión visual ni commit en este punto.

Regresión completa confirmada el 2026-09-13:
`ARCHIVOS_CON_FALLAS=0 de 120 en 325s con 8 en paralelo`.
[Salida guardada](ocasion_etapa95/regresion.log). El hash del motor coincide
con la versión medida. Se repitió la corrida porque la sesión anterior
se perdió antes de entregar su resumen; no se asumió que hubiera pasado.

## Comparación contra el motor previo

90 pares, divisiones 1/5/10, semillas 9500–9529. Equipos nuevos en cada
corrida, ambos motores dentro del mismo proceso. Los 90 resultados completos
y estados finales del RNG coinciden, excluyendo el nuevo campo diagnóstico.

| División | Goles antes/después | Remates antes/después |
| --- | ---: | ---: |
| 1 | 47 / 47 | 210 / 210 |
| 5 | 62 / 62 | 195 / 195 |
| 10 | 53 / 53 | 176 / 176 |
| Total | 162 / 162 | 581 / 581 |

La muestra no contiene arcos desprotegidos; verifica conservación del
comportamiento habitual. Las escenas controladas anteriores verifican
la corrección cuando el arquero sí está fuera de la jugada.

[Mediciones JSON](ocasion_etapa95/balance.json) y
[motor anterior](ocasion_etapa95/motor_antes.gd), excluido de importación
por `.gdignore`. Motor medido después:
`aa5b62c36c8c035d8021b758073db8468754bd357c42309ec6b056d09c283094`.

Reproducir desde la raíz del proyecto:

```powershell
& '..\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/_diag_arcos_desprotegidos.gd -- antes=docs/mediciones/ocasion_etapa95/motor_antes.gd salida=../balance_arcos.json
```
