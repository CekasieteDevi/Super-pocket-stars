# Validación cuantitativa final — 2026-09-13

Matriz ejecutada y verificada: 600 enfrentamientos, 2400 simulaciones.
Cero diferencias entre el resultado completo sin fotogramas y con fotogramas,
incluido el estado final del RNG. No se modificaron parámetros de producción.
La aceptación general sigue pendiente de calibración y revisión visual.

## Método y alcance

Cada combinación tiene 50 parejas de planteles, semillas 97000–97049,
con ida y vuelta: 100 partidos. Se alternan Tiki taka/Juego directo y
Presion alta/Contragolpe: 50 partidos por pareja de estilos en cada combinación.
Cada encuentro se regenera antes de correr el espacial actual sin fotogramas,
el actual con fotogramas, la base espacial y el abstracto.

La base es la fuente guardada en la medición 9.6 con sus pesos históricos.
No es la etapa 0 ni permite atribuir el efecto acumulado de las nueve etapas.
El motor actual y sus pesos se congelaron en `calibracion_final/instantanea`;
las demás dependencias son compartidas. Los cambios simultáneos del arquero
pertenecen a otra tarea. Se verificaron los hashes de las copias cargadas y
que las seis celdas usaran las mismas versiones. El hash del actual cargado
difiere del archivo original porque se retira `class_name MotorEspacial`
para cargar ambas versiones en un mismo proceso.

## Resultados por partido

| Divisiones A/B | Goles actual = base | Goles abstracto | Remates actual = base | Brecha de goles con abstracto | IC95 de diferencia de goles |
|---|---:|---:|---:|---:|---:|
| 1/1 | 1,58 | 2,89 | 7,40 | −45,3% | [−1,77; −0,88] |
| 1/4 | 3,62 | 4,52 | 8,39 | −19,9% | [−1,34; −0,47] |
| 5/5 | 1,76 | 2,61 | 6,96 | −32,6% | [−1,24; −0,47] |
| 5/8 | 3,32 | 4,06 | 7,86 | −18,2% | [−1,21; −0,24] |
| 10/10 | 1,51 | 3,02 | 6,02 | −50,0% | [−1,85; −1,16] |
| 10/7 | 3,32 | 4,20 | 7,50 | −21,0% | [−1,24; −0,50] |

Intervalos mediante bootstrap de 5000 remuestras de parejas completas de
ida/vuelta, semilla 97000. No se consideran ambas piernas independientes.
La diferencia emparejada de goles frente a la base tiene IC95 [0; 0] en
las seis celdas. El abstracto no expone el mismo contador de remates;
no se inventa una comparación de remates entre motores.

La brecha con el abstracto supera el umbral exploratorio del 15% en las
seis celdas y todos sus intervalos excluyen cero. Ya existe en la base 9.6;
no es una regresión de esta medición. Su origen exacto no queda identificado
por totales: falta separar generación de ocasiones, precisión y resolución
del arquero. No se ajustan probabilidades globales para igualar estos totales.
El abstracto resuelve oportunidades por ticks y normaliza atributos al nivel
del partido; la referencia no implica equivalencia de oportunidades físicas.

La desigualdad conserva su dirección: A/B promedian 3,42/0,20 goles en D1/D4,
3,20/0,12 en D5/D8 y 0,09/3,23 en D10/D7. Esto comprueba la tendencia de
la muestra, no valida por sí solo la magnitud de las goleadas.

## Coste y límites

Se ejecutaron seis procesos simultáneos. Promedios del actual sin fotogramas:
536–569 ms por partido; con fotogramas: 589–612 ms. La variación frente a
la base sin fotogramas va de −1,07% a +0,13%; ninguna celda supera +20%.
Estos tiempos incluyen diagnóstico de remates y comparten CPU. El orden
actual/visual/base/abstracto es fijo; no son un benchmark aislado ni evidencia
de una optimización. El abstracto tarda 26,7–27,5 ms en este entorno.

No se revisaron clips ni se repitió la regresión completa: esta tarea agrega
diagnósticos y documentación, sin cambios del motor. Los resultados cubren
las versiones congeladas, no cambios posteriores de otras tareas.

## Reproducción y evidencia

Desde la raíz del repositorio, crear una carpeta de salida y ejecutar por
cada `celda` de 0 a 5 (el ejemplo muestra la primera):

```powershell
& '..\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --script tests/_diag_calibracion_final.gd -- parejas=50 celda=0 instantanea=docs/mediciones/calibracion_final/instantanea salida=docs/mediciones/calibracion_final/celda_0
python tests/_analizar_calibracion.py docs/mediciones/calibracion_final
```

La reproducción requiere también la fuente y los pesos guardados en
`ocasion_etapa96/ocasiones.json` y `ocasion_etapa96/ocasiones.json.motor.gd`.
No usa la partida real del usuario.

- [Resumen verificable, intervalos y hashes](calibracion_final/resumen.json).
- Datos individuales, fuentes, pesos y logs: `calibracion_final/celda_0` a `celda_5`.
- [Diagnóstico](../../tests/_diag_calibracion_final.gd).
- [Análisis y comprobaciones de integridad](../../tests/_analizar_calibracion.py).

Siguiente trabajo: localizar la brecha de goles con un embudo comparable
de oportunidades/remates/destinos en ambos motores, antes de calibrar pesos.
La revisión visual continúa pendiente.
