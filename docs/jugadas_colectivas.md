# Jugadas colectivas

Objetivo: ataques coordinados, con decisiones y movimientos sin pelota.

1. **Pared y tercer hombre — implementado.** A pasa a B; B habilita la ruptura de C. Se revisa el segundo carril al recibir; si se cierra, B conserva la pelota.
2. **Desborde y pase atrás — implementado.** Con pelota abierta cerca del fondo, un compañero prepara la llegada al punto penal. El extremo busca ese espacio cuando el corredor puede llegar y el carril está libre.
3. **Cambio de frente — implementado.** Detecta defensa volcada hacia la pelota, prepara amplitud contraria y prioriza cambiar hacia el receptor libre, incluso sin ganar metros.
4. **Lateral por sorpresa — implementado.** Extremo marcado baja el ritmo cuando el lateral del mismo costado prepara una corrida por fuera. Pase al espacio cuando puede llegar.
5. **Diagonal del extremo — implementado.** Extremo abierto busca el intervalo real entre lateral y central del mismo costado; el pasador puede habilitar ese destino.
6. **Delantero que baja — implementado.** El nueve ofrece descarga y sostiene el apoyo; un extremo o volante ataca su posición cuando la deja libre.
7. **Amague de centro y enganche — lógica implementada.** Con amenaza de centro y espacio interior, la gambeta puede preparar un recorte hacia adentro. Animación específica del amague pendiente.
8. **Circular y acelerar — pendiente ampliar.** Mover la defensa antes de buscar el pase vertical.

## Primer cambio: tercer hombre

Reutiliza la pared y su corrida coordinada. Busca un tercer compañero con ruptura o llegada preparada, dos carriles seguros y alcance suficiente del apoyo. El apoyo necesita técnica de pase. La combinación compite con las demás decisiones; no garantiza recepción ni gol. Conserva controles de intercepción y fuera de juego.

Prueba: `tests/test_tercer_hombre.gd`. Falta calibrar frecuencia viendo partidos completos.

## Segundo cambio: desborde y pase atrás

Llegadas de MC, MCO, DC y EXT a tres carriles alrededor del punto penal. Comparten cupo de corridas, separación de destinos y control de posición legal con los demás desmarques. El pase busca el destino de la llegada, con límite de alcance, riesgo y tiempo de llegada del receptor. No fuerza remate ni gol.

Prueba: `tests/test_desborde_pase_atras.gd`, ambos sentidos y ambas bandas; descarta corredor lejano, carril cerrado y ausencia de desborde. Frecuencia visual pendiente de calibración.

## Tercer cambio: cambio de frente

Detecta al menos tres rivales en la banda de la pelota y una diferencia de dos frente a la opuesta, dentro de una franja longitudinal de 25 metros. EXT y LAT del lado contrario pueden sostener amplitud. Premia el cambio si el receptor está libre; conserva alcance físico y riesgo del pase. Reacciona a la defensa atraída: no impone una secuencia previa de pases.

Prueba: `tests/test_cambio_frente.gd`, ambas bandas y sentidos, receptor marcado y defensa equilibrada. Frecuencia visual pendiente de calibración.

## Cuarto cambio: lateral por sorpresa

LAT cercano y por detrás de un EXT con marca ofrece ruptura ocho metros adelante y seis por fuera. Respeta línea legal, espacio disponible y cupo de corridas. El extremo reduce su conducción mientras dura el plan. El pase preparado espera a que el lateral pueda alcanzar el envío; las demás decisiones siguen disponibles.

Prueba: `tests/test_doblamiento.gd`, ambas bandas y sentidos, ausencia de marca, lateral lejano a la recepción, banda opuesta y salida cubierta. Frecuencia visual pendiente de calibración.

## Quinto cambio: diagonal del extremo

Busca un LAT y un DFC rivales del mismo costado, separados entre 7 y 20 metros de ancho y hasta 10 de profundidad. El EXT parte abierto y ataca hacia dentro un destino legal entre ambos. Descarta trayectos largos, carriles tapados y destinos cubiertos. Comparte cupo de rupturas y pase al espacio con el sistema existente; no fuerza el envío ni el resultado.

Prueba: `tests/test_diagonal_extremo.gd`, ambas bandas y sentidos, posición legal, pase al intervalo, cierre de defensores, cobertura y extremo ya centrado. Frecuencia visual pendiente de calibración.

## Sexto cambio: delantero que baja

DC adelantado respecto al poseedor ofrece un apoyo siete metros hacia la pelota, si tiene espacio y línea de pase. Guarda la posición que deja y sostiene la descarga durante un reparto adicional. EXT, MCO o MC pueden atacar esa posición cuando el nueve retrocedió al menos tres metros y la defensa no la cubre. Comparte cupos, posiciones legales y pases al espacio existentes. No obliga al central a seguir al nueve ni garantiza un pase.

Prueba: `tests/test_nueve_baja.gd`, ambos sentidos, descarga, espera de espacio libre, relevo, habilitación, cobertura defensiva y plan vencido. Frecuencia visual pendiente de calibración.

## Séptimo cambio: amague de centro y enganche

Desde banda, a 6–24 metros de la línea de fondo, un jugador capaz de centrar y con compañero en el área puede elegir enganche en su gambeta. Requiere carril y destino interiores libres. Si gana el duelo, orienta y sostiene un corredor hacia dentro; se desplaza con la conducción normal, sin salto de posición. Mantiene faltas y pérdidas. No añade todavía una animación específica de amague de centro.

Prueba: `tests/test_enganche_banda.gd`, ambas bandas y sentidos, amenaza de centro, selección, cobertura interior, éxito y pérdida del duelo. Frecuencia visual pendiente de calibración.
