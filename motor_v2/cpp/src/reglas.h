#pragma once

// Reglas y pelota parada del Motor V2 (docs/motor_v2.md, etapa 6): el reloj
// de dos tiempos, las reanudaciones (saque del medio, lateral, saque de arco,
// córner, tiro libre y penal), el offside, las faltas por contacto, las
// tarjetas, las lesiones, los cambios y la tanda de penales.
//
// Nadie adjudica. Una reanudación pone la pelota quieta en su lugar (no es
// una corrección: es un saque) y la ejecuta un jugador que llega corriendo
// hasta ahí: nadie aparece encima de la pelota. Una falta sale del contacto
// del pie de la entrada con las piernas del rival, no de una tirada. La
// tarjeta y la lesión sí se sortean, con la gravedad del contacto.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include <cstdint>

namespace motor_v2 {

enum TipoParada : int {
	PARADA_NADA = 0,
	SAQUE_MEDIO = 1,
	LATERAL = 2,
	SAQUE_ARCO = 3,
	CORNER = 4,
	TIRO_LIBRE = 5,
	PENAL = 6,
	PARADAS = 7,
};

// En qué se convierte un tiro libre (MotorEspacial.tipo_de_falta).
enum TipoLibre : int {
	LIBRE_CORTO = 0,
	LIBRE_CENTRO = 1,
	LIBRE_DIRECTO = 2,
};

enum Periodo : int {
	PRIMER_TIEMPO = 0,
	SEGUNDO_TIEMPO = 1,
	// Etapa 8: el alargue de un cruce empatado (dos tiempos de
	// minutos_alargue), antes de la tanda.
	ALARGUE_1 = 2,
	ALARGUE_2 = 3,
	TANDA = 4,
	TERMINADO = 5,
};

// Lo que el partido registra para el relato y las estadísticas.
enum TipoEvento : int {
	// Se ejecutó una reanudación: `detalle` es la TipoParada.
	EV_SAQUE = 0,
	EV_GOL = 1,
	// `jugador` hizo la falta sobre `otro`; `detalle` 1 si fue penal.
	EV_FALTA = 2,
	EV_AMARILLA = 3,
	// `detalle` 1 si fue por doble amarilla.
	EV_ROJA = 4,
	EV_OFFSIDE = 5,
	EV_LESION = 6,
	// Sale `jugador`, entra `otro`; `detalle` 1 si fue por lesión.
	EV_CAMBIO = 7,
	// Terminó un tiempo: `detalle` es el Periodo que terminó.
	EV_FIN_TIEMPO = 8,
	// Un penal de la tanda: `detalle` 1 si fue gol.
	EV_PENAL_TANDA = 9,
	// Etapa 8: `jugador` le sacó la pelota a `otro`, que la tenía dominada
	// (venía de un control o de una conducción). `detalle` 1 si fue con una
	// entrada al piso.
	EV_QUITE = 10,
	// Etapa 8: salió una jugada preparada (core/jugadas.gd). `detalle` es la
	// Jugada; `jugador`, el que saca o el que recupera; `otro`, el socio.
	EV_JUGADA = 11,
	EVENTOS = 12,
};

// Las jugadas preparadas que se ven en la cancha (core/jugadas.gd). Paredes y
// Contragolpe entran por el plan del cerebro y no dejan evento.
enum Jugada : int {
	JUGADA_NADA = 0,
	JUGADA_CORNER_CORTO = 1,
	JUGADA_CORNER_BLOQUE = 2,
	JUGADA_AMAGUE = 3,
	JUGADA_DEFENSA_ADELANTADA = 4,
	JUGADA_CONTRAPRESION = 5,
};

struct EventoPartido {
	int64_t paso = 0;
	// El minuto del reloj mostrado (Canchita::minuto).
	double minuto = 0.0;
	int tipo = EV_SAQUE;
	int equipo = 0;
	// Ids de Player (FichaReglas.id); -1 si no aplica.
	int jugador = -1;
	int otro = -1;
	int detalle = 0;
	double x = 0.0, z = 0.0;
};

// Salen de data/fisica_v2.json ("reglas"; ahí está el porqué de cada uno) y,
// los que ya existían, de data/utility_pesos.json y de las constantes del
// motor espacial: FisicaV2.parametros_reglas() los junta.
// tests/test_reglas_v2.gd falla si se separan.
struct ParametrosReglas {
	// --- Reloj ---
	// Lo que MUESTRA el reloj por tiempo. El partido dura de verdad
	// segundos_tiempo por tiempo (MotorEspacial.SEGUNDOS_POR_MITAD): el reloj
	// 0-90 es ficción, como en el motor espacial. Con 45 minutos de verdad
	// (etapa 6) salían 35 goles, 115 remates y 1.146 pases por partido; los
	// mismos 4 minutos del motor espacial dan 1,6, 5 y 51 (él: 1,5, 7 y 45).
	// El reloj corre solo con la pelota en juego: en una pelota parada espera.
	// Todo lo que está en minutos o en segundos de adición es del reloj
	// mostrado.
	double minutos_tiempo = 45.0;
	double segundos_tiempo = 120.0;
	// Segundos de verdad que sigue un tiempo cumplido si la jugada no está
	// tranquila. TICKS_DE_DESCUENTO del motor espacial son 22,5 s.
	double cierre_max_seg = 22.5;
	// El tiempo agregado de cada tiempo: un mínimo, más lo que suma cada
	// interrupción, hasta un tope.
	double adicion_min_seg = 60.0;
	double adicion_max_seg = 300.0;
	double adicion_gol_seg = 30.0;
	double adicion_cambio_seg = 30.0;
	double adicion_lesion_seg = 30.0;
	double adicion_tarjeta_seg = 15.0;
	// Después de una tarjeta el saque espera esto: el árbitro corre hasta el
	// jugador y se la muestra (Tarjeta_Completa dura 2,5 s).
	double tarjeta_seg = 4.5;
	// Entretiempo (MotorEspacial._recuperar_entretiempo): recupera esta
	// fracción de lo perdido, hasta el tope.
	double recuperacion_entretiempo = 0.25;
	double tope_entretiempo = 0.03;

	// --- Reanudaciones ---
	// La pelota que salió se repone en su lugar después de esto.
	double reponer_seg = 1.0;
	// El ejecutor llegó cuando está a esto de su lugar.
	double llegada_m = 0.6;
	// Lo mínimo que dura cada parada desde que se cortó el juego, y lo más
	// que se espera a que los demás lleguen a su lugar (por TipoParada).
	double pausa_seg[PARADAS] = { 0.0, 2.0, 1.5, 2.5, 4.0, 3.0, 5.0 };
	double espera_max_seg[PARADAS] = { 0.0, 6.0, 3.0, 5.0, 8.0, 8.0, 8.0 };
	// El que llega a su lugar a esto o menos ya está.
	double ubicado_m = 2.0;
	// Distancias reglamentarias.
	double distancia_libre_m = 9.15;
	double distancia_lateral_m = 2.0;
	double distancia_penal_m = 11.0;
	double saque_arco_m = 5.5;
	double radio_circulo_m = 9.15;
	// Lateral: rapidez del lanzamiento con fuerza 0 y 100, a qué ángulo sale
	// y hasta qué distancia busca un compañero. Sale de donde las manos la
	// sueltan en el clip Lateral; lateral_alto_m (el alto de ese punto) solo
	// se usa si falta el clip.
	double lateral_min_ms = 9.0, lateral_max_ms = 15.0;
	double lateral_elevacion_rad = 0.5;
	double lateral_alto_m = 0.71;
	// Con la pelota ya en las manos, cuánto espera antes de lanzarla.
	double lateral_espera_seg = 1.5;
	double lateral_alcance_m = 22.0;
	// Ejecutores: el mejor de los que están a esto de la pelota
	// (MotorEspacial.DIST_MAX_AL_EJECUTOR); si no, el más cercano.
	double ejecutor_max_m = 22.0;
	// Tiro libre (data/utility_pesos.json, "fisica"; MotorEspacial.tipo_de_falta).
	double rango_libre_malo = 16.5, rango_libre_bueno = 30.0;
	double angulo_minimo_tiro_libre = 0.35;
	double dist_libre_al_area = 38.0;
	double dist_para_colgar_lejos = 52.0;
	// Al córner suben (Estilos.suben_al_corner); en un centro de tiro libre,
	// dos menos; en un directo, cuatro menos (MotorEspacial._marcar_posiciones).
	int menos_en_centro = 2;
	int menos_en_directo = 4;
	// Los que suben se reparten entre el punto penal y el área chica: a esto
	// del arco, con este ancho.
	double area_desde_m = 5.0, area_hasta_m = 13.0, area_ancho_m = 14.0;

	// --- Faltas ---
	// El que contiene a esto o menos de la pelota del rival se puede tirar a
	// quitarla: chance por cada vez que piensa, por quite (0..100).
	double entrada_dist_m = 2.0;
	double entrada_prob = 0.55;
	// El que ya tiene amarilla se tira con esta fracción de la chance.
	double entrada_amonestado = 0.4;
	// El pie de la entrada que pasa a esto del medio del rival le pega en
	// las piernas: falta.
	double falta_radio_m = 0.42;
	// Gravedad: la rapidez del que entra sobre esta, por 1 + desde_atras
	// si entra de atrás.
	// La gravedad del que entra a su punta (a media carrera, la mitad).
	double gravedad_a_fondo = 1.2;
	double gravedad_desde_atras = 1.0;
	// Cuánto baja la chance de tirarse por cada 100% de punta que le saca al
	// que lleva la pelota.
	double entrada_sobrado = 0.0;
	// La entrada que saca la pelota tumba al que la llevaba (sin falta) con
	// esta chance, si está a menos de entrada_tumba_m de la pelota.
	double entrada_tumba = 0.8;
	double entrada_por_quite = -0.5;
	// Hasta dónde llega la pierna de la entrada a la pelota (el control llega
	// a toque.tolerancia_m).
	double entrada_alcance_m = 0.45;
	double entrada_tumba_m = 1.5;
	// Por cuánto se multiplica la chance de tirarse en el área propia.
	double entrada_en_area = 0.35;
	// El radio de la falta crece con la torpeza del que entra: × (1 +
	// falta_torpeza × (1 − (quite + barrida) / 200)).
	double falta_torpeza = 1.5;
	// Cuánto baja la chance de tirarse el que llega de atrás (1 = nunca).
	double entrada_de_atras = 1.0;
	// Dos que llegan a la misma pelota en el mismo paso: el que pierde le pega
	// al otro con esta chance si su pie pasa por las piernas del rival.
	double cruce_falta_prob = 0.3;
	// El que recibe la falta queda en el piso esto.
	double caido_seg = 2.5;

	// --- Tarjetas ---
	// Chance de amarilla y de roja directa por falta, con gravedad 1. Cada
	// jugador la multiplica por su FichaReglas (árbitro, clásico,
	// personalidad); la gravedad multiplica la amarilla y, al cuadrado, la roja.
	double amarilla_por_falta = 0.48;
	double roja_por_falta = 0.0092;

	// --- Lesiones ---
	// La chance de lesión del que recibe la falta: FichaReglas.riesgo_lesion
	// por esto, por la gravedad y por el cansancio.
	double lesion_por_contacto = 8.0;
	// Cansancio.RIESGO_LESION_POR_FRANJA: lo que suma cada franja.
	double riesgo_franja[4] = { 1.0, 1.0, 1.0, 1.5 };
	// El lesionado queda en el piso esto antes de salir caminando.
	double lesionado_seg = 4.0;

	// --- Energía y cambios ---
	// Desgaste por segundo: desgaste_minuto / 60 × (base + carrera ×
	// (rapidez / punta)²).
	double esfuerzo_base = 0.6;
	double esfuerzo_carrera = 1.2;
	// Cansancio.ENERGIA_MINIMA.
	double energia_minima = 0.1;
	// Cansancio.FRANJA_PISO_PCT (en fracción) y FACTOR_FRANJA.
	double franja_piso[4] = { 0.76, 0.51, 0.26, 0.0 };
	double factor_franja[4] = { 1.0, 0.9, 0.8, 0.65 };
	int cambios_max = 5;
	// Desde qué minuto se cambia por cansancio (por lesión, siempre).
	double cambio_desde_min = 55.0;
	// Por club: Cansancio.umbral_cambio, Estilos.suben_al_corner y
	// Estilos.cuelga_de_lejos.
	double umbral_cambio[2] = { 0.75, 0.75 };
	int suben_corner[2] = { 5, 5 };
	bool cuelga_lejos[2] = { false, false };

	// --- El arquero con la pelota en las manos ---
	// La saca con la mano (Arquero_Lanza) a un compañero libre (sin rival a
	// mano_libre_m) hasta mano_alcance_m; si no hay, de voleo (Arquero_Voleo)
	// hacia voleo_m adelante; con los rivales lejos (a más de juega_m), la
	// suelta y la juega con el pie como en la etapa 5.
	double mano_alcance_m = 30.0;
	double mano_libre_m = 5.0;
	double voleo_m = 45.0;
	double juega_m = 15.0;

	// --- Penales ---
	// El arquero no espera a leer el penal: se tira en la patada, al lado que
	// adivina con esta chance (si no, al otro).
	double penal_adivina = 0.55;
	bool tanda = false;
	// Etapa 8: si el partido empatado juega antes dos tiempos de alargue, y
	// cuántos minutos del reloj mostrado dura cada uno (MotorEspacial.
	// MINUTOS_MOSTRADOS_POR_TIEMPO_ALARGUE).
	bool alargue = false;
	double minutos_alargue = 15.0;
	int tanda_pateadores = 5;
	// Etapa 8, el festejo: después del gol el que lo hizo y los festejo_grupo
	// - 1 compañeros más cercanos corren al banderín de ese lado y festejan
	// hasta festejo_seg; después, corte al saque del medio. 0 = sin festejo
	// (los 3 s de FESTEJO_PASOS caminando al medio).
	double festejo_seg = 7.0;
	double festejo_grupo = 4.0;

	// Clips (índices en los clips del cuerpo); los pone quien configura.
	int clip_lateral = -1;
	int clip_lateral_prepara = -1;
	int clip_entrada = -1;
	int clip_caer = -1;
	int clip_levantarse = -1;
	int clip_lesionado = -1;
	int clip_saque_arco = -1;
	int clip_arquero_lanza = -1;
	int clip_arquero_voleo = -1;
	int clip_festejar = -1;
};

// Lo que las reglas necesitan de cada jugador y no cambia en el partido.
// GDScript lo arma con lo que ya existe (Arbitro, Rivalidad, Personalidad,
// Lesiones, Cansancio): el C++ solo sortea.
struct FichaReglas {
	int id = -1;
	// Arbitro.factor_tarjetas × Rivalidad.factor_tarjetas ×
	// Personalidad.factor_amarilla (y factor_roja).
	double factor_amarilla = 1.0;
	double factor_roja = 1.0;
	// Lesiones.evaluar_riesgo con el jugador descansado: el C++ suma el
	// cansancio del partido.
	double riesgo_lesion = 0.0025;
	// Cansancio.desgaste_por_minuto × factor_atributo_energia.
	double desgaste_minuto = 0.0055;
	// Team.resistencia_pct al empezar.
	double energia = 1.0;
	// Atributos 0..100 que solo usan las reglas.
	double quite = 50.0;
	double barrida = 50.0;
	double tiros_libres = 50.0;
	double centros = 50.0;
	double fuerza = 50.0;
	double salto = 50.0;
	// Al córner sube por amenaza aérea (cabezazo + salto, +40 si es de ataque).
	double amenaza = 100.0;
	// Al banco: con qué rol (Rol de cerebro.h) puede entrar.
	int rol = 3;
	// Para el cambio: la media del jugador (MatchEngine._mejor_suplente_para).
	double media = 50.0;
};

} // namespace motor_v2
