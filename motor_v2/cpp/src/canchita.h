#pragma once

// Banco de la etapa 3 del Motor V2 (docs/motor_v2.md): una canchita sin
// arcos con pelota, cuerpos y cerebros sencillos. Dos juegos:
// - RONDO: 4 contra 2 en un cuadrado de RONDO_LADO m. Los cuatro de afuera
//   se la pasan; si un defensor la toca, es corte y se vuelve a empezar.
// - PARTIDITO: 5 contra 5 en una cancha de PARTIDITO_LARGO × PARTIDITO_ANCHO
//   m. El que la gana se la queda.
//
// Lo que prueba es tocar la pelota: conducción por toques, recepción según la
// altura (pie, muslo, pecho, cabeza), pase al punto de encuentro con los
// tiempos de llegada de cada rival, e intercepción = el primero que la
// alcanza. Nadie corrige la pelota: el cuerpo arranca un gesto, y si en la
// ventana de contacto su pie (o su pecho, o su frente) está en la pelota, la
// toca. Los cerebros son del banco: los de verdad llegan en la etapa 4.
//
// Etapa 4 suma un tercer juego:
// - PARTIDO: 11 contra 11 en la cancha entera, sin arqueros que atajen ni
//   reglas (etapa 5 y 6). Los cerebros son los de verdad (cerebro/cerebro.h):
//   el poseedor decide con la utility AI del motor espacial y los demás van
//   adonde el cerebro les pide. Si un equipo controla la pelota en el área
//   rival, cuenta como llegada y el otro saca del arco.
//
// Etapa 5 suma el arco (docs/motor_v2.md, "Etapa 5 — Remates y arqueros"):
// en el PARTIDO el poseedor puede rematar (el cerebro elige punto y golpe) y
// cada equipo tiene un arquero que lee la trayectoria, elige parado o
// estirada y la agarra, la da en rebote o no llega. El gol lo decide la
// pelota al cruzar la línea: nadie lo adjudica. Después del gol se saca del
// medio. Las demás reglas siguen siendo las del banco (etapa 6). La llegada
// ya no termina la jugada: se cuenta una por posesión.
//
// Etapa 6 suma las reglas (reglas.h, docs/motor_v2.md "Etapa 6 — Reglas y
// pelota parada"), solo si se activan (activar_reglas): sin ellas el PARTIDO
// sigue con las reanudaciones del banco y los tests de las etapas 4 y 5 dan
// lo mismo. Con reglas hay dos tiempos y entretiempo, cada reanudación la
// ejecuta alguien que llega corriendo, el offside se cobra, las entradas
// hacen faltas, hay tarjetas, penales, lesiones, cambios y tanda.
//
// Sin Godot: solo C++ y matematica_fija.h.

#include "azar.h"
#include "cerebro/cerebro.h"
#include "cuerpo.h"
#include "pelota.h"
#include "reglas.h"
#include "remate.h"
#include "toque.h"

#include <cstdint>
#include <vector>

namespace motor_v2 {

enum ModoCanchita : int {
	RONDO = 0,
	PARTIDITO = 1,
	// Para los tests: cada uno se queda en su lugar (poner_jugador) y solo va
	// a la pelota que se lanza (lanzar). El que la controla no sigue.
	PRUEBA = 2,
	PARTIDO = 3,
	// Etapa 5, para los tests y el laboratorio de remates: como PRUEBA pero en
	// la cancha entera, con los arcos y el arquero (rematar()).
	ARCO = 4,
};

enum TipoToque : int {
	TOQUE_NADA = 0,
	TOQUE_PASE = 1,
	TOQUE_CONDUCE = 2,
	TOQUE_CONTROL = 3,
	// Etapa 5: al arco, y el arquero con las manos.
	TOQUE_REMATE = 4,
	TOQUE_ATAJADA = 5,
	// Etapa 6: entrada a la pelota del rival. Si el pie llega primero a la
	// pelota, la saca; si llega a las piernas del rival, es falta.
	TOQUE_ENTRADA = 6,
};

// Cómo terminó un remate (el mundo lo decide, ver Canchita::_cerrar_remate).
enum ResultadoRemate : int {
	REMATE_GOL = 0,
	REMATE_ATAJADO = 1,
	REMATE_PALO = 2,
	REMATE_BLOQUEADO = 3,
	REMATE_AFUERA = 4,
	// Se quedó corto o lo desvió un compañero.
	REMATE_OTRO = 5,
	RESULTADOS_REMATE = 6,
};

// Lo que miden los detectores de la etapa 3 (docs/motor_v2.md, "Pasa si").
struct ContadoresCanchita {
	int64_t pases = 0;
	int64_t pases_globo = 0;
	// Los pases que son un despeje (no buscan a nadie). El motor espacial no
	// los cuenta como pases intentados.
	int64_t pases_despeje = 0;
	// La pelota que sale de la cancha, según lo último que le pasó: un pase,
	// una conducción, un control, un remate, un rebote en un cuerpo u otra cosa.
	int64_t salidas_pase = 0, salidas_conduce = 0, salidas_control = 0, salidas_remate = 0, salidas_rebote = 0,
			salidas_otra = 0;
	// Conducción: pasos con la pelota conducida, metros del que la lleva a la
	// pelota (suma), pasos con la pelota a más de CONDUCE_LEJOS_M y lo que
	// corre contra su punta (suma).
	int64_t conduce_pasos = 0, conduce_lejos = 0;
	double conduce_metros = 0.0, conduce_corre = 0.0, conduce_max_m = 0.0;
	// Lo más lejos que se le va la pelota al que la tiene después de cada
	// toque suyo, hasta el toque siguiente: [control, conducción] por franja
	// (menos de 1 m, 1 a 2, 2 a 3, 3 a 5, más de 5). `separa_pierde`: los que
	// terminan con la pelota del rival o afuera. `lleva_a_fondo`: pasos del
	// que la tiene a más del 90% de su punta.
	int64_t separa[2][5] = {};
	int64_t separa_pierde[2][5] = {};
	int64_t lleva_pasos = 0, lleva_a_fondo = 0;
	// Qué decide el que tiene la pelota sin ningún rival de campo entre él y
	// el arco (_via_libre), según la distancia al arco: menos de 16,5 m, hasta
	// 25, hasta 35.
	int64_t via_libre[3][DECISIONES] = {};
	int64_t completados = 0;
	// Lo recibió un compañero que no era el buscado.
	int64_t completados_otro = 0;
	// Pases que el receptor mandó de primera, sin pararla.
	int64_t de_primera = 0;
	int64_t cortes = 0;
	int64_t desvios = 0;
	int64_t quites = 0;
	int64_t pases_afuera = 0;
	int64_t salidas = 0;
	int64_t reinicios = 0;
	int64_t conducciones = 0;
	int64_t controles = 0;
	int64_t recepciones[4] = { 0, 0, 0, 0 };
	// Gestos que abrieron la ventana y no llegaron a la pelota.
	int64_t fallos = 0;
	// Gestos de recibir o rematar que empezaron y los que erraron, por parte;
	// de los que erraron, los que quedaron lejos en el piso y los que quedaron
	// a otra altura.
	int64_t gestos_parte[4] = { 0, 0, 0, 0 };
	int64_t fallos_parte[4] = { 0, 0, 0, 0 };
	int64_t fallos_lejos[4] = { 0, 0, 0, 0 };
	int64_t fallos_altura[4] = { 0, 0, 0, 0 };
	double fallos_metros[4] = { 0.0, 0.0, 0.0, 0.0 };
	// Tenía la ventana abierta pero otro la tocó primero.
	int64_t cruces_perdidos = 0;
	int64_t rebotes_cuerpo = 0;
	// La pelota cambió de velocidad sin que la tocara nadie ni la física:
	// tiene que dar 0 siempre (docs/motor_v2.md, "Pasa si").
	int64_t correcciones = 0;
	// El corte más lejano: distancia en el piso del pie del defensor a la
	// pelota en el toque. Un pase solo se corta si un defensor llega.
	double corte_mas_lejos_m = 0.0;
	// Receptores: segundos quietos (< RAPIDEZ_QUIETO) con el pase viniendo,
	// desde que reaccionan hasta que la tocan.
	int64_t recepciones_medidas = 0;
	double espera_suma = 0.0;
	double espera_max = 0.0;
	int64_t esperas_largas = 0;
	// Algún cuerpo bajó su rapidez más que la frenada en un paso.
	int64_t frenadas_en_seco = 0;
	// Peor paso de un cuerpo más allá de lo que da su velocidad (lo empujan
	// los choques entre cuerpos).
	double peor_salto_cuerpo_m = 0.0;
	double posesion_seg[2] = { 0.0, 0.0 };

	// PARTIDO (etapa 4, docs/motor_v2.md "Pasa si").
	// Posesiones: cada vez que la pelota cambia de equipo. Los pases son los
	// completados entre compañeros durante esa posesión.
	int64_t posesiones = 0;
	int64_t pases_en_posesiones = 0;
	int64_t posesiones_3_pases = 0;
	int64_t posesiones_5_pases = 0;
	int64_t max_pases_posesion = 0;
	// Pases a un punto por delante del receptor (al hueco o al desmarque).
	int64_t pases_al_espacio = 0;
	int64_t pases_al_espacio_completos = 0;
	// Salieron hacia la corrida que el cerebro ya había preparado.
	int64_t pases_a_corrida = 0;
	int64_t offsides = 0;
	int64_t llegadas[2] = { 0, 0 };
	int64_t saques_de_arco = 0;
	int64_t laterales = 0;
	int64_t corners = 0;
	int64_t paredes_devueltas = 0;
	// De dónde salen los quites: la pelota venía de una conducción, de un
	// control, o suelta (rebote, pelota que nadie tenía).
	int64_t quites_conduccion = 0;
	int64_t quites_control = 0;
	int64_t quites_suelta = 0;
	// Regates: los gestos que arrancaron, los que el rival se comió
	// (_amagar) y los que terminaron con la pelota en su equipo.
	int64_t regates = 0, regates_amague = 0, regates_ganados = 0;

	// Etapa 5 (docs/motor_v2.md, "Pasa si"): el embudo de remates, con los
	// mismos cortes que tests/_diag_embudo_remates.gd. Al arco = gol + atajado.
	int64_t remates = 0;
	int64_t remates_equipo[2] = { 0, 0 };
	int64_t remates_cabeza = 0;
	int64_t remates_primera = 0;
	// Las veces que no remató por quedar de espaldas al arco (_remate_de_espaldas).
	int64_t giros_al_arco = 0;
	int64_t resultados[RESULTADOS_REMATE] = {};
	int64_t goles[2] = { 0, 0 };
	int64_t goles_cabeza = 0;
	int64_t golpes[TIPOS_REMATE] = {};
	double distancia_remates = 0.0;
	// Remates que salen de un rebote del arquero (hasta 3 s después).
	int64_t remates_tras_rebote = 0;
	int64_t goles_tras_rebote = 0;
	// Lo que hizo el arquero con la pelota que tocó.
	int64_t agarres = 0;
	int64_t rebotes_arquero = 0;
	int64_t roces_arquero = 0;
	int64_t estiradas = 0;
	int64_t paradas = 0;
	// Pelotas sueltas que salió a agarrar (no remates).
	int64_t salidas_arquero = 0;
	// Gestos de atajada que no llegaron a la pelota.
	int64_t atajadas_falladas = 0;
	// Las que fallan saliendo a una pelota que no es un remate (un centro).
	int64_t salidas_falladas = 0;
	// De esas, las que le pasaron por arriba de las manos y las que no
	// alcanzó a tocar (lejos).
	int64_t salidas_por_arriba = 0, salidas_lejos = 0;

	// Etapa 6 (docs/motor_v2.md, "Pasa si"). Paradas por TipoParada: cuántas,
	// cuántas se ejecutaron y los segundos desde que se cortó el juego hasta
	// el saque (suma y la más larga).
	int64_t paradas_tipo[PARADAS] = {};
	int64_t saques[PARADAS] = {};
	double espera_parada_suma[PARADAS] = {};
	double espera_parada_max[PARADAS] = {};
	// El ejecutor que tocó la pelota estando a más de llegada_m de ella al
	// arrancar el saque: tiene que dar 0 (nadie aparece encima de la pelota).
	int64_t saques_de_lejos = 0;
	// Las veces que el ejecutor camina (medio segundo seguido) hacia su lugar
	// estando lejos, por TipoParada: el pasa-si de la etapa es que en el
	// lateral dé 0. Y los
	// laterales que tardaron más de 17 ticks del motor espacial (4,25 s).
	int64_t ejecutor_camina[PARADAS] = {};
	int64_t laterales_lentos = 0;
	int64_t entradas = 0;
	int64_t entradas_limpias = 0;
	// Después de una entrada que saca la pelota: el toque siguiente es del
	// equipo del que entró, del otro, o la pelota sale.
	int64_t entrada_gana = 0, entrada_pierde = 0, entrada_afuera = 0;
	int64_t entradas_tumban = 0;
	int64_t faltas[2] = { 0, 0 };
	int64_t faltas_entrada = 0;
	int64_t faltas_cruce = 0;
	// Las del arquero que sale a los pies (van también en faltas_entrada).
	int64_t faltas_arquero = 0;
	int64_t amarillas[2] = { 0, 0 };
	int64_t rojas[2] = { 0, 0 };
	int64_t rojas_directas = 0;
	// La gravedad de las faltas: suma y la mayor.
	double gravedad_suma = 0.0;
	double gravedad_max = 0.0;
	int64_t offsides_cobrados[2] = { 0, 0 };
	int64_t penales = 0;
	int64_t penales_gol = 0;
	int64_t lesiones = 0;
	int64_t cambios[2] = { 0, 0 };
	int64_t tiros_libres[3] = { 0, 0, 0 };
	// El arquero con la pelota en las manos: con la mano, de voleo o la
	// suelta y la juega con el pie.
	int64_t arquero_mano = 0;
	int64_t arquero_voleo = 0;
	int64_t arquero_pie = 0;
};

// Un pase, para el diagnóstico (tests/_diag_pases_v2.gd): quién, a quién, de
// qué tipo y cómo terminó.
enum ResultadoPase {
	PASE_ABIERTO = -1,
	PASE_COMPLETO = 0, // lo toca el receptor
	PASE_OTRO, // lo toca otro compañero
	PASE_PROPIO, // lo vuelve a tocar el que lo dio
	PASE_CORTE, // lo toca un rival
	PASE_SUELTO, // nadie lo toca: sale o se para el juego
	PASE_ARQUERO, // lo agarra o lo rechaza el arquero rival con las manos
	RESULTADOS_PASE,
};

struct RegistroPase {
	int64_t paso = 0, paso_fin = 0;
	int equipo = 0;
	int pateador = -1, receptor = -1;
	// Ids de Player (FichaReglas.id) del que lo da y del que lo termina
	// tocando (-1 si nadie): los índices cambian cuando alguien sale.
	int pateador_id = -1, toca_id = -1;
	// DEC_* del cerebro (DEC_NADA: de primera, sin decisión).
	int tipo = 0;
	// Minuto del reloj mostrado en que salió.
	double minuto = 0.0;
	bool globo = false, al_espacio = false, de_primera = false;
	double x = 0.0, z = 0.0, meta_x = 0.0, meta_z = 0.0;
	// 0 = hacia donde mira el que la da, 1 = de espaldas.
	double de_lado = 0.0;
	// Rival más cercano al que la da y metros del receptor al punto, al patear.
	double presion_m = 0.0, receptor_al_punto_m = 0.0;
	// El margen que le da el planeador al patear (segundos; < 0 = un rival
	// llega antes).
	double margen = 0.0;
	int resultado = PASE_ABIERTO;
	// Al terminar: metros del receptor a la pelota y si iba a buscarla.
	double receptor_a_pelota_m = 0.0;
	bool receptor_iba = false;
	// Salió de la cancha sin que la toque nadie.
	bool afuera = false;
	// El toque que lo terminó: qué iba a hacer (TOQUE_*), con qué parte y a
	// qué altura estaba la pelota. -1 si no lo tocó nadie.
	int toque_fin = -1, parte_fin = -1;
	double alto_fin = 0.0;
	// Al terminar: metros del punto pedido a donde quedó la pelota.
	double error_m = 0.0;
	// Pasos del pase en los que el receptor iba a la pelota y los que duró.
	int64_t pasos_receptor_iba = 0;
};

// Un remate, para el diagnóstico (tests/_diag_remates_v2.gd): de dónde salió,
// adónde apuntaba, dónde estaba el arquero y cómo terminó.
struct RegistroRemate {
	int equipo = 0;
	int pateador = -1;
	// Id de Player del que remata y minuto del reloj mostrado.
	int pateador_id = -1;
	double minuto = 0.0;
	int golpe = 0;
	bool de_primera = false;
	bool chilena = false;
	// 0 = hacia donde mira el que remata, 1 = de espaldas.
	double de_lado = 0.0;
	double desde_x = 0.0, desde_z = 0.0;
	double alto = 0.0, lateral = 0.0;
	double rapidez = 0.0;
	// El rival más cerca de la pelota al patear (m).
	double presion_m = 0.0;
	// El arquero al patear (NAN si no hay).
	double arquero_x = 0.0, arquero_z = 0.0;
	// El clip de atajada que arrancó (ClipArquero), -1 si no se tiró.
	int clip_arquero = -1;
	// El arquero estaba en medio de otro gesto al patear, y en qué paso
	// planeó la atajada (-1 si nunca).
	bool arquero_ocupado = false;
	int64_t paso_remate = 0;
	int64_t paso_plan = -1;
	int resultado = -1;
};

struct JugadorCanchita {
	Cuerpo cuerpo;
	int equipo = 0;
	// Lugar dentro del equipo (0..4): el lado del rondo o el ancla del partidito.
	int puesto = 0;
	// Atributos de Player (0..100).
	double pases = 50.0;
	double control = 50.0;
	// Etapa 5, relativos al nivel del partido (MatchEngine.relativo_al_nivel),
	// como la puntería del motor espacial.
	double tiro = 50.0;
	double golpe = 50.0;
	double cabezazo = 50.0;
	double reflejos = 50.0;
	double estirada = 50.0;
	double agarre = 50.0;
	double achique = 50.0;
	// Pie preferido: 0 sin el rasgo; +1 derecho, -1 zurdo.
	int pie_malo_lado = 0;
	bool arquero = false;

	// El plan: ir a tocar la pelota en el paso `paso_meta` y hacer `toque`.
	bool persigue = false;
	int paso_meta = -1;
	int toque = TOQUE_NADA;
	// El gesto que arrancó para tocarla y si su ventana todavía la puede tocar.
	int clip_toque = -1;
	int parte = PIE;
	bool toque_pendiente = false;
	// Con la ventana abierta: lo más cerca que pasó la pelota de su punto de
	// contacto (en el piso) y si alguna vez estuvo a la altura.
	double toque_d_min = 1e9;
	bool toque_alto_ok = false;
	// Si el gesto que arrancó va a llegar a la pelota según lo que calculó al
	// arrancarlo (_gatillo). Solo lo lee la vista: el arquero se tira a tiempo
	// aunque no llegue, y la vista le llevaba las manos a la pelota igual
	// (la pelota le pasaba por las manos sin que la tocara).
	bool alcanza = true;
	// Pase: al punto (meta_x, meta_z), a `receptor`, raso o globo.
	double meta_x = 0.0, meta_z = 0.0;
	int receptor = -1;
	bool globo = false;
	// Conduce y control: hacia dónde sale la pelota y a qué rapidez.
	double dir_x = 1.0, dir_z = 0.0;
	double rapidez_toque = 0.0;
	// No rebota contra el que la acaba de tocar.
	int64_t inmune_hasta = 0;
	int64_t pateo_en = -1000;
	bool pensar_ya = false;
	// Lo que el equipo le pide cuando no va a la pelota.
	int marca = -1;
	// Su lugar en el modo PRUEBA.
	double casa_x = 0.0, casa_z = 0.0;
	double quieto_seg = 0.0;
	double rapidez_previa = 0.0;
	// PARTIDO: lo que decidió el cerebro y hasta qué paso vale.
	Decision decision;
	bool hay_decision = false;
	int64_t decision_hasta = 0;
	// Rapidez planeada del pase (al espacio); 0 = la calcula el toque.
	double rapidez_pase = 0.0;
	// La decisión del cerebro que armó el pase de este toque (DEC_NADA si no
	// salió del cerebro).
	int tipo_pase = DEC_NADA;
	// Remate: al punto (meta_x, meta_alto, meta_z) con el golpe `golpe_remate`.
	double meta_alto = 0.0;
	int golpe_remate = REMATE_COLOCADO;
	// Este remate de primera va de chilena (_de_chilena).
	bool chilena = false;
	// Atajada: el clip del arquero (ClipArquero de remate.h).
	int clip_arquero = -1;
	// Modo ARCO: le pega al arco la próxima pelota (rematar()).
	bool remata_prueba = false;

	// Etapa 6.
	FichaReglas reglas;
	double energia = 1.0;
	int amarillas = 0;
	bool lesionado = false;
	// En el piso (falta o lesión) hasta este paso: no juega.
	int64_t en_el_piso_hasta = -1;
	// Se tira a quitarla (_plan_entrada): el gesto es el de la entrada, y
	// sigue en eso hasta este paso.
	bool entra = false;
	int64_t entrada_hasta = -1;
	// Cuánto de su rapidez de conducción usa (la decisión de conducir del
	// cerebro; 1 si la última no fue conducir).
	double ritmo_conduce = 1.0;
	// El regate (TipoRegate) que sorteó al decidir DEC_REGATE y el del toque
	// de conducción que está planeando; -1 = ninguno.
	int regate_elegido = -1;
	int regate = -1;
	// Se comió un amague: hasta este paso sigue de largo (_amagar).
	int64_t amagado_hasta = -1;
};

// Etapa 6: el que se va de la cancha (expulsado, cambiado o lesionado). Ya no
// juega: camina hasta afuera y la vista lo dibuja hasta que sale.
struct Saliente {
	Cuerpo cuerpo;
	int equipo = 0;
	int id = -1;
	double x = 0.0, z = 0.0;
	bool expulsado = false;
	// El expulsado espera parado a que el árbitro le muestre la roja y recién
	// después sale (NUNCA no: sale enseguida).
	int64_t espera_hasta = -1;
	double factor = 1.0;
	bool saliendo = false;
	// Ya llegó al medio de la banda: va al punto de afuera.
	bool cruza = false;
};

// Etapa 6: un suplente, con todo lo que necesita para entrar.
struct Suplente {
	JugadorCanchita jugador;
	FichaCerebro ficha;
};

class Canchita : public Planeador {
public:
	static constexpr double PASO_SEG = 1.0 / 60.0;
	// Cuánto adelanta la pelota el que planea: 5 s.
	static constexpr int HORIZONTE = 300;
	// Cerebro a 10 Hz, escalonado: cada jugador piensa uno de cada 6 pasos.
	static constexpr int PASOS_POR_TURNO = 6;
	static constexpr double RONDO_LADO = 12.0;
	static constexpr double PARTIDITO_LARGO = 40.0;
	static constexpr double PARTIDITO_ANCHO = 30.0;
	static constexpr double RAPIDEZ_QUIETO = 0.5;
	// Partido: la cancha entera (la misma del motor espacial).
	static constexpr double PARTIDO_LARGO = Cerebro::LARGO;
	static constexpr double PARTIDO_ANCHO = Cerebro::ANCHO;
	// Partido: en el saque del medio la formación se comprime hacia el arco
	// propio para caber en su mitad (MotorEspacial.COMPRESION_SAQUE).
	static constexpr double COMPRESION_SAQUE = 0.775;
	// Etapa 5. Festejo: la pelota queda en la red y cada uno vuelve a su mitad
	// antes del saque del medio.
	static constexpr int FESTEJO_PASOS = 180;

	ParametrosPelota param_pelota;
	ParametrosCuerpo param_cuerpo;
	ParametrosToque param_toque;
	ParametrosRemate param_remate;
	ParametrosArquero param_arquero;
	std::vector<Clip> clips;

	std::vector<JugadorCanchita> jugadores;
	// PARTIDO: una ficha por jugador, en el mismo orden (ver cerebro.fichas).
	Cerebro cerebro;
	Pelota pelota;
	Trayectoria trayectoria;
	ContadoresCanchita cuenta;
	// Etapa 5: cada remate del partido.
	std::vector<RegistroRemate> registro;
	std::vector<RegistroPase> registro_pases;
	int modo = RONDO;
	int64_t paso = 0;
	int equipo_con_pelota = 0;
	int poseedor = -1;
	int ultimo_toque = -1;
	int ultimo_tipo = TOQUE_NADA;

	// Antes de empezar: los jugadores, con su físico ya pasado a unidades.
	void agregar(int equipo, const Cuerpo &fisico, double pases, double control);
	void empezar(int modo_, int64_t semilla);
	// Modo PRUEBA: dónde está cada uno, y una pelota que sale de `p` a `v` con
	// `giro` para que la juegue el equipo `equipo` (la ven todos enseguida).
	void poner_jugador(int i, double x, double z, double rumbo);
	void lanzar(V3 p, V3 v, V3 giro, int equipo);
	// Modo PRUEBA: el jugador `i` le va a pegar al arco a la pelota que viene
	// (la próxima que se lance), al punto (alto, lateral) con el golpe `golpe`.
	void rematar(int i, int golpe, double alto, double lateral);
	// El arquero de `equipo` (-1 si no tiene).
	int arquero_de(int equipo) const;
	// El que tiene la pelota en las manos (-1 si nadie).
	int en_manos() const {
		return _en_manos;
	}
	// El resultado del último remate que terminó (ResultadoRemate), -1 si no hubo.
	int ultimo_resultado() const {
		return _ultimo_resultado;
	}
	void avanzar();
	uint64_t huella() const;

	// Etapa 6: reglas del partido (reglas.h). Se activan antes de empezar.
	ParametrosReglas param_reglas;
	bool reglas = false;
	std::vector<EventoPartido> eventos;
	std::vector<Suplente> banco;
	// Etapa 8: la energía con la que se fue cada uno que salió de la cancha
	// (cambiado, lesionado o expulsado): id de Player y energía.
	std::vector<std::pair<int, double>> energia_al_salir;
	std::vector<Saliente> afuera;
	// Los que entraron por un cambio y todavía no pisaron la cancha.
	const std::vector<int> &entrando() const {
		return _entrando;
	}
	int periodo = PRIMER_TIEMPO;
	int goles_tanda[2] = { 0, 0 };
	int pateados_tanda[2] = { 0, 0 };
	// Un suplente de `equipo`: puede entrar en un cambio.
	void agregar_suplente(int equipo, const JugadorCanchita &j, const FichaCerebro &f);
	// Segundos de juego del tiempo que se está jugando y su agregado.
	double reloj_seg() const;
	double escala_reloj() const;
	double adicion_seg() const;
	double minuto() const;
	// 0 en el primer tiempo (y en el primero del alargue), 1 en el segundo: la
	// vista gira la cancha 180° (el motor sigue con el equipo 0 atacando
	// hacia +x).
	int lado() const {
		return periodo == PRIMER_TIEMPO || periodo == ALARGUE_1 ? 0 : 1;
	}
	// Segundos de verdad que dura el periodo en curso, sin el agregado.
	double segundos_periodo() const;
	bool terminado() const {
		return periodo == TERMINADO;
	}
	bool suspendido() const {
		return _suspendido;
	}
	// La parada en curso (PARADA_NADA si se juega).
	int parada_tipo() const {
		return _parada.activa ? _parada.tipo : PARADA_NADA;
	}
	int parada_equipo() const {
		return _parada.activa ? _parada.equipo : -1;
	}
	// El índice del que festeja el gol, -1 si no hay festejo.
	int festeja() const;
	int parada_ejecutor() const {
		return _parada.activa ? _parada.ejecutor : -1;
	}
	// Paso del último corte al saque después de una tarjeta (-1 si no hubo):
	// la vista corta la cámara en ese paso.
	int64_t corte_paso = -1;
	// El que tiene el lateral en las manos (-1 si nadie).
	int lateral_en_manos() const {
		return _parada.activa && _parada.en_manos ? _parada.ejecutor : -1;
	}
	V3 parada_punto() const {
		return { _parada.x, 0.0, _parada.z };
	}
	// Laboratorio de reanudaciones: el partido nunca las llama. Cortan el juego
	// con las mismas funciones que el partido (_parar, _falta, _fin_de_tiempo),
	// así lo que se ve es lo que haría el partido. Devuelven false si no se
	// puede (sin reglas, en la tanda o terminado).
	// Córner, tiro libre, penal o lateral para `equipo`. El córner y el lateral
	// salen del lado de `z`; el tiro libre, desde (x, z); el penal, de su punto.
	bool forzar_parada(int tipo, int equipo, double x, double z);
	// Falta del rival más cercano sobre el que lleva la pelota. Solo con el
	// rival a la distancia de una entrada: si no, devuelve false y el
	// laboratorio prueba en el paso siguiente. `tarjeta`: 0 ninguna, 1
	// amarilla, 2 roja. Con `lesion`, el que la recibe sale lesionado y entra
	// su cambio.
	bool forzar_falta(int tarjeta, bool lesion);
	bool forzar_fin_de_tiempo();

	// Planeador (cerebro.h): el margen de un pase con la física del toque,
	// desde la pelota y el momento de la patada del que está decidiendo.
	double margen_pase(int de, int a) override;
	double margen_al_punto(int de, int a, double x, double z) override;
	double margen_globo(int de, int a, double x, double z) override;
	double _margen_destino(int de, double x, double z, double t_juntos) const;
	double valor_remate(int de, int tipo, double alto, double lateral) override;
	// El receptor del pase que viaja (-1 si no hay pase).
	int receptor() const {
		return _pase_activo ? _receptor : -1;
	}
	// La foto que lee el cerebro (se arma en cada paso del PARTIDO).
	const Mundo &mundo() const {
		return _mundo;
	}

private:
	Azar _azar;
	Perfiles _perfiles;
	// Paso en que se calculó la trayectoria (la pelota cambió).
	int64_t _tray_paso = 0;
	// Desde qué paso los demás ya vieron la pelota nueva (reacción).
	int64_t _visto_paso = 0;
	// El equipo del último que la pelota le rebotó en el cuerpo después del
	// último toque (-1 si nadie): cuenta para saber quién saca si sale.
	int _rebote_equipo = -1;
	// Paso de la última tarjeta: la parada de esa falta espera al árbitro.
	int64_t _tarjeta_paso = -1;
	int _reaccion_pasos = 12;
	std::vector<int> _k_llega;
	std::vector<double> _t_llega;
	int _perseguidor[2] = { -1, -1 };
	// El segundo que va a la pelota que tiene el rival: el que la tiene al lado.
	int _segundo[2] = { -1, -1 };
	bool _pase_activo = false;
	int _pateador = -1;
	int _receptor = -1;
	int64_t _desde_control = 0;
	int64_t _reinicio_en = -1;
	int64_t _reinicio_hasta = -1;
	bool _cambio = false;
	// PARTIDO.
	Mundo _mundo;
	int _pases_posesion = 0;
	bool _pase_al_espacio = false;
	// Desde dónde y en cuántos segundos patea el que decide (Planeador).
	V3 _plan_bola;
	// Etapa 5.
	// Dónde cruza la trayectoria la línea de cada arco (índice en la
	// trayectoria, -1 si no va al arco). _k_cruce[e] es el arco que defiende e.
	int _k_cruce[2] = { -1, -1 };
	int _en_manos = -1;
	int64_t _suelta_en = -1;
	// Saque del medio después de un gol: cuándo y quién.
	int64_t _saque_medio_en = -1;
	int _saca_medio = 0;
	bool _llegada_contada = false;
	int _ultimo_resultado = -1;
	// El rebote del arquero, para contar el remate que sale de ahí.
	int64_t _rebote_arquero_en = -1000;
	struct Remate {
		bool activo = false;
		int equipo = 0;
		int pateador = -1;
		int64_t paso = 0;
		bool palo = false;
		bool toco_arquero = false;
		bool cabeza = false;
		bool tras_rebote = false;
		// Etapa 6: un penal (para contar los convertidos y la tanda), y si el
		// arquero ya eligió lado y si adivinó.
		bool penal = false;
		bool lado_elegido = false;
		bool adivina = false;
		// Su lugar en `registro`.
		size_t indice = 0;
	};
	Remate _remate;

	double _plan_t = 0.0;

	// Etapa 6.
	struct Parada {
		bool activa = false;
		int tipo = PARADA_NADA;
		int equipo = 0;
		double x = 0.0, z = 0.0;
		int ejecutor = -1;
		int tipo_libre = LIBRE_CORTO;
		// Sin offside: el lateral, el saque de arco y el córner.
		bool sin_offside = false;
		int64_t desde = 0;
		// Cuándo se repone la pelota, y lo mínimo y lo máximo que dura.
		int64_t reponer_en = 0;
		int64_t minimo = 0;
		int64_t tope = 0;
		bool repuesta = false;
		// Lateral: la tiene en las manos (desde qué paso) y arrancó el lanzamiento.
		bool en_manos = false;
		int64_t en_manos_desde = 0;
		bool lanzando = false;
		// Saque con el pie: ya es el poseedor y va a patear (desde este paso).
		bool sacando = false;
		int64_t sacando_desde = 0;
		// Dónde se para el ejecutor.
		double lugar_x = 0.0, lugar_z = 0.0;
		// Distancia que respetan los rivales.
		double distancia = 0.0;
		// En la tanda.
		bool tanda = false;
		// Pasos seguidos que el ejecutor va caminando (detector).
		int64_t lento_pasos = 0;
		// El paso en que el ejecutor llegó a su lugar (-1 si todavía no).
		int64_t llego_en = -1;
		// Con tarjeta: el paso del corte al saque (-1 si no hay).
		int64_t corte_en = -1;
		// Etapa 8: la jugada preparada de esta pelota parada (Jugada) y el
		// socio: el que recibe el córner corto o le pega en el amague (-1 si
		// no hay).
		int jugada = JUGADA_NADA;
		int socio = -1;
		// Etapa 8: hay festejo en el banderín (hasta reponer_en) y dónde.
		bool festeja = false;
		double festejo_x = 0.0, festejo_z = 0.0;
	};
	Parada _parada;
	// Córner en bloque: los que se juntan en el segundo palo (índices).
	std::vector<int> _bloque;
	// Amague de tiro libre: el que le pega de primera (id) y hasta qué paso.
	int _amague_id = -1;
	int64_t _amague_hasta = -1;
	// Córner corto: el socio (id) centra apenas la controla, hasta este paso.
	int _corto_id = -1;
	int64_t _corto_hasta = -1;
	void _elegir_jugada();
	bool _socio_valido() const;
	// Los que festejan (ids de Player): primero el que hizo el gol.
	std::vector<int> _festejan;
	void _empezar_festejo(int autor);
	int _puesto_en_festejo(int i) const;
	// Adónde va cada uno en la parada (si tiene_marca).
	std::vector<double> _marca_x, _marca_z;
	std::vector<char> _tiene_marca;
	// Los que estaban en offside en el cuadro del último pase.
	std::vector<int> _adelantados;
	// El pase en vuelo es un centro: lo va a buscar el que antes llega, no el
	// que lo esperaba.
	bool _pase_centro = false;
	// El pase abierto en registro_pases (-1 si no hay).
	int _pase_reg = -1;
	int _separa_tipo = -1, _separa_de = -1;
	// Etapa 8, la asistencia: el último pase entre compañeros, por id (quién
	// lo dio y quién lo recibió). Se borra cuando la toca el rival.
	int _asistente_id = -1, _asistido_id = -1;
	// El último remate: quién (id), de qué equipo y en qué paso.
	int _gol_de_id = -1, _gol_de_equipo = -1;
	int64_t _gol_de_paso = -1000000;
	int _entrada_de = -1;
	// El regate que el rival se comió: quién (id), a quién (id), cuál, de qué
	// equipo y en qué paso se mira si sirvió (_cerrar_regate). -1 = ninguno.
	int _regate_de_id = -1, _regate_rival_id = -1, _regate_tipo = 0, _regate_equipo = 0;
	int64_t _regate_hasta = -1;
	int _clip_conduce_de(const JugadorCanchita &j) const;
	void _amagar(int i, int clip);
	void _cerrar_regate();
	double _separa_max = 0.0;
	void _cerrar_separacion(int equipo_que_sigue);
	void _cerrar_pase(int resultado);
	bool _salio_remate = false;
	bool _remate_reciente() const;
	int64_t _inicio_periodo = 0;
	// Pasos de este tiempo con el reloj parado (una pelota parada).
	int64_t _pasos_parados = 0;
	double _adicion[2] = { 0.0, 0.0 };
	int _saco_primero = 0;
	// La tanda: el orden de cada equipo y por dónde va.
	std::vector<int> _orden_tanda[2];
	int _turno_tanda = 0;
	bool _tanda_pateo = false;
	// Etapa 8: el id del que pateó el penal de la tanda en curso (para el
	// evento y la lista de la tanda).
	int _tanda_id = -1;
	// Los que entraron y todavía no pisaron la cancha.
	std::vector<int> _entrando;
	// El arquero que saca con la mano o de voleo: ya eligió adónde (activo),
	// gira hacia ahí hasta gira_hasta como mucho y arranca el gesto (lanzando).
	struct SaqueMano {
		bool activo = false;
		bool lanzando = false;
		int64_t gira_hasta = 0;
		bool voleo = false;
		int receptor = -1;
		double x = 0.0, z = 0.0;
	};
	SaqueMano _mano;
	// Un equipo quedó con menos de siete: el partido se suspende.
	bool _suspendido = false;
	// El minuto del reloj mostrado en que terminó el último periodo jugado.
	double _minuto_final = 0.0;

	double _medio_x() const;
	double _medio_z() const;
	bool _adentro(double x, double z, double margen) const;
	double _ataca(int equipo) const;
	V3 _bola_en(int64_t paso_) const;
	int _indice_tray(int64_t paso_) const;

	void _pensar();
	void _analizar();
	void _alcance(int i, double factor, int &k, double &t, int no_antes = 0) const;
	void _pensar_jugador(int i);
	void _plan_tocar(int i);
	void _decidir(int i, V3 bola, double t_patada);
	void _ubicar(int i);
	void _contener(int i);
	void _avisar_receptor(int pateador);
	void _gatillo(int i);
	int _clip_para(const JugadorCanchita &j, double alto) const;
	int _clip_de_parte(const JugadorCanchita &j, Parte parte) const;
	void _franja(Parte parte, double &desde, double &hasta, bool control = false) const;
	Parte _parte_de(const JugadorCanchita &j, double alto) const;
	double _rumbo_al_tocar(const Cuerpo &c, double rumbo, double x, double z) const;
	void _orientar(int i, V3 bola);

	struct Pase {
		bool hay = false;
		int receptor = -1;
		double x = 0.0, z = 0.0;
		bool globo = false;
		double margen = -1e9;
		double puntaje = -1e9;
		// Rapidez planeada (pase al espacio); 0 = la del toque.
		double rapidez = 0.0;
	};
	// `solo`: solo a ese receptor (el que eligió el cerebro).
	Pase _planear_pase(int i, V3 bola, double t_patada, int solo = -1);
	double _margen(int i, V3 bola, double dx, double dz, const Perfil &perfil, int k_fin, double t_patada) const;
	double _rapidez_raso(double d, int &k);
	double _rapidez_globo(double d, int &k, bool centro = false);
	bool _centro_tendido(double d);
	double _rapidez_conduce(double corre, double largo, double alcanza_m = 0.0, double alcanza_seg = 0.0);
	double _espacio_adelante(int i, V3 bola, double dx, double dz) const;
	double _rival_mas_cerca(int i, double x, double z) const;
	double _claridad(V3 bola, double x, double z, int equipo) const;

	bool _resolver_toques();
	void _tocar(int i, double distancia);
	bool _rebotes();
	void _reglas();
	void _reiniciar(int equipo, double x, double z);
	void _asignar_marcas();
	void _separar_cuerpos();
	void _medir();

	// PARTIDO.
	void _armar_mundo();
	void _ubicar_partido(int i, double &qx, double &qz, double &factor, bool &frenar);
	void _decidir_partido(int i, V3 bola, double t_patada);
	Pase _pase_a(int i, V3 bola, double t_patada, const Decision &d);
	double _rapidez_al_espacio(double d, double t_receptor, double t_patada);
	bool _reglas_partido();
	void _cerrar_posesion();

	// Etapa 5.
	void _nueva_trayectoria();
	void _buscar_cruces();
	bool _es_mi_area(int i, double x, double z) const;
	double _reaccion_arquero(int i) const;
	double _tolerancia(int i, int clip) const;
	double _tolerancia_alto(int clip, bool arriba) const;
	bool _es_estirada(int clip_arquero) const;
	void _levantarse(int i, int clip_terminado);
	double _alto_que_cree_alcanzar(int i) const;
	double _alto_minimo(int clip_arquero, const Clip &k) const;
	double _distancia_al_brazo(const JugadorCanchita &j, const Cuerpo &c, V3 mano, V3 a, V3 b) const;
	// De su punta, lo que corre para acomodarse sin darse vuelta.
	double _factor_acomodarse(const Cuerpo &c) const;
	double _rumbo_contacto(const JugadorCanchita &j, const Cuerpo &c, int clip, double rumbo, double x, double z) const;
	bool _plan_atajar(int i);
	bool _prueba() const {
		return modo == PRUEBA || modo == ARCO;
	}
	bool _con_arcos() const {
		return modo == PARTIDO || modo == ARCO;
	}
	void _ubicar_arquero(int i, double &qx, double &qz, double &factor);
	void _atajar(int i, double distancia);
	void _llevar_en_manos();
	void _soltar();
	bool _decidir_remate_de_primera(int i, V3 bola, double t);
	bool _remate_de_espaldas(int i, V3 bola, double meta_x, double meta_z) const;
	bool _da_la_espalda(int i, V3 bola, double meta_x, double meta_z) const;
	bool _en_area_rival(const JugadorCanchita &j, V3 bola) const;
	bool _de_chilena(int i, V3 bola) const;
	double _alto_desde(int clip) const;
	double _rapidez_remate(const JugadorCanchita &j, int golpe) const;
	double _error_remate(const JugadorCanchita &j, int golpe, double de_lado, double alto_pelota, double llega_ms,
			double apretado, double cruce_pie_malo) const;
	void _patear_al_arco(int i, bool de_primera, double apretado);
	void _cerrar_remate(int resultado);
	void _gol(int marca);
	void _sacar_del_medio();

	// Etapa 6 (canchita_reglas.cpp).
	void _empezar_reglas();
	void _parar(int tipo, int equipo, double x, double z, int64_t demora = 0);
	int _elegir_ejecutor(int tipo, int equipo, double x, double z, int tipo_libre, int excluir = -1) const;
	int _tipo_de_libre(int equipo, double x, double z) const;
	void _lugar_del_ejecutor();
	void _marcar_parada();
	void _marcar_area(int ataca, int suben);
	bool _pensar_en_parada(int i);
	bool _avanzar_parada();
	void _cortar_al_saque();
	void _ejecutar_parada();
	void _lanzar_lateral();
	void _llevar_lateral();
	// Lanza la pelota con las manos (o de voleo) desde `desde` hacia (tx, tz),
	// en una parábola a `elevacion` que llega a la cintura; como un pase a
	// `receptor`.
	void _lanzar_a(int i, V3 desde, double tx, double tz, double elevacion, double rapidez_max, int receptor);
	bool _decidir_saque_de_manos();
	void _sacar_de_manos();
	void _termina_saque(int i);
	void _decidir_saque(int i, V3 bola, double t_patada);
	bool _reloj();
	void _fin_de_tiempo();
	void _ubicar_saque_del_medio(int i, double &x, double &z) const;
	void _desgastar();
	double _distancia_parada(int i) const;
	bool _plan_entrada(int i);
	// `tarjeta` y `lesion`: -1 las sortea (el partido); el laboratorio las elige
	// (tarjeta 0 ninguna, 1 amarilla, 2 roja; lesion 0 o 1).
	void _falta(int infractor, int victima, double gravedad, bool de_entrada, int tarjeta = -1, int lesion = -1);
	void _tarjeta(int i, double gravedad);
	void _sacar_tarjeta(int i, bool roja);
	void _lesion(int i, double factor);
	void _lesionar(int i);
	void _caer(int i, int clip, double segundos);
	void _quitar(int i, bool expulsado);
	double _banda_cambios() const;
	Saliente _saliente(const JugadorCanchita &j, bool expulsado) const;
	void _hacer_cambios(bool entretiempo);
	void _cambiar(int sale, size_t entra);
	void _anotar(int tipo, int equipo, int jugador, int otro, int detalle, double x, double z);
	void _offside_al_patear(int pateador);
	bool _offside_al_tocar(int i);
	void _empezar_tanda();
	void _siguiente_penal();
	bool _avanzar_tanda();
	int _id(int i) const {
		return i >= 0 && i < int(jugadores.size()) ? jugadores[size_t(i)].reglas.id : -1;
	}
};

} // namespace motor_v2
