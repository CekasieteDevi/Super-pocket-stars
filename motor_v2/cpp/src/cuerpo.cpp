#include "cuerpo.h"
#include "matematica_fija.h"

#include <algorithm>
#include <cmath>

using namespace motor_v2;

double Cuerpo::rapidez() const {
	return std::sqrt(vx * vx + vz * vz);
}

void Cuerpo::ir_a(double px, double pz, double factor_, bool frenar_) {
	tiene_objetivo = true;
	objetivo_x = px;
	objetivo_z = pz;
	factor = factor_;
	frenar = frenar_;
}

bool Cuerpo::empezar(int indice_clip) {
	if (clip >= 0 || indice_clip < 0) {
		return false;
	}
	clip = indice_clip;
	tiempo_accion = 0.0;
	fase = SIN_ACCION;
	return true;
}

void Cuerpo::paso(const ParametrosCuerpo &p, const std::vector<Clip> &clips, double dt) {
	eventos = 0;
	previa_x = x;
	previa_z = z;
	double rapidez_previa = rapidez();
	// Un gesto que no se hace corriendo (cabecear, barrerse, atajar) no deja
	// acelerar ni cambiar de rumbo: el cuerpo frena y mira adonde miraba.
	bool trabado = clip >= 0 && !clips[size_t(clip)].mueve;
	_moverse(p, trabado, dt);
	_girar(p, trabado, dt);
	_gastar(p, rapidez_previa, dt);
	if (clip >= 0) {
		_avanzar_accion(p, clips, dt);
	}
}

// MotorEspacial.capacidad_de_sprint: con la reserva por encima de
// reserva_para_frenar no pierde nada; debajo baja suave hasta piso_sprint.
double Cuerpo::_capacidad_de_sprint(const ParametrosCuerpo &p) const {
	if (reserva >= 1.0) {
		return 1.0;
	}
	double t = std::clamp(reserva / std::max(p.reserva_para_frenar, 0.01), 0.0, 1.0);
	double suave = t * t * (3.0 - 2.0 * t);
	return p.piso_sprint + (1.0 - p.piso_sprint) * suave;
}

// MotorEspacial._mover_hacia a 60 Hz. Dos cambios contra el original, los dos
// para que ningún paso mueva a nadie más de lo que da su velocidad:
// - la rapidez baja como mucho `frenada` por segundo (antes el tope la
//   cortaba en un tick);
// - al pasar por el objetivo sin `frenar` sigue con su velocidad (antes se
//   clavaba en el punto) y, sin objetivo, frena.
void Cuerpo::_moverse(const ParametrosCuerpo &p, bool trabado, double dt) {
	double r = rapidez();
	if (!tiene_objetivo || trabado) {
		if (r > 0.0) {
			double f = std::max(0.0, r - p.frenada * dt) / r;
			vx *= f;
			vz *= f;
		}
		x += vx * dt;
		z += vz * dt;
		recorrido += rapidez() * dt;
		return;
	}
	double dx = objetivo_x - x, dz = objetivo_z - z;
	double dist = std::sqrt(dx * dx + dz * dz);
	if (dist < 1e-9) {
		tiene_objetivo = false;
		eventos |= LLEGO;
		return;
	}
	double ux = dx / dist, uz = dz / dist;
	double tope = rapidez_buscada(p);
	if (frenar) {
		// La velocidad con la que todavía se frena a tiempo: v² = 2·a·d.
		tope = std::min(tope, std::sqrt(2.0 * p.frenada * dist));
	}
	double acel = aceleracion * cansancio;
	// Parado acelera más que cerca de su punta, como un velocista.
	acel *= 1.0 + p.arranque_extra * std::clamp(1.0 - r / std::max(vel_max, 0.1), 0.0, 1.0);
	double deseada = std::clamp(tope, std::max(0.0, r - p.frenada * dt), r + acel * dt);
	// Giro con inercia: la velocidad cambia hacia la deseada como mucho
	// giro_acel por segundo. A 9 m/s dar la vuelta obliga a frenar hasta casi
	// parar: nadie gira 180° en el lugar corriendo.
	double cx = ux * deseada - vx, cz = uz * deseada - vz;
	double cambio = std::sqrt(cx * cx + cz * cz);
	double maximo = p.giro_acel * dt;
	if (cambio > maximo) {
		cx *= maximo / cambio;
		cz *= maximo / cambio;
	}
	vx += cx;
	vz += cz;
	double avance = rapidez() * dt;
	if (avance >= dist && vx * ux + vz * uz > 0.0) {
		// Llega en este paso: se para en el punto si venía frenando (ya viene
		// a menos de frenada·dt) o lo cruza con su velocidad.
		x = objetivo_x;
		z = objetivo_z;
		recorrido += dist;
		tiene_objetivo = false;
		eventos |= LLEGO;
		if (frenar) {
			vx = vz = 0.0;
		}
		return;
	}
	x += vx * dt;
	z += vz * dt;
	recorrido += avance;
}

double Cuerpo::rapidez_buscada(const ParametrosCuerpo &p) const {
	if (!tiene_objetivo) {
		return 0.0;
	}
	// La reserva baja el techo de la corrida, no el trote (por eso es un
	// mínimo contra el factor). Un factor mayor que 1 es el que entra o sale
	// de la cancha, que no juega la jugada.
	double techo = factor > 1.0 ? factor : std::min(factor, _capacidad_de_sprint(p));
	return vel_max * techo * cansancio;
}

double Cuerpo::metros_para_parar(const ParametrosCuerpo &p) const {
	if (!tiene_objetivo) {
		double r = rapidez();
		return r * r / (2.0 * std::max(p.frenada, 0.01));
	}
	if (!frenar) {
		return -1.0;
	}
	double dx = objetivo_x - x, dz = objetivo_z - z;
	return std::sqrt(dx * dx + dz * dz);
}

double Cuerpo::giro_pendiente(const ParametrosCuerpo &p) const {
	return mate::envolver(_hacia(p) - rumbo);
}

double Cuerpo::rumbo_buscado() const {
	if (!tiene_objetivo) {
		return rumbo;
	}
	double dx = objetivo_x - x, dz = objetivo_z - z;
	return dx * dx + dz * dz > 1e-12 ? mate::arcotangente2(dx, dz) : rumbo;
}

// Corriendo, el cuerpo mira hacia donde corre; despacio mira la jugada (o
// sigue como estaba).
double Cuerpo::_hacia(const ParametrosCuerpo &p) const {
	if (rapidez() >= p.rapidez_para_girar) {
		return mate::arcotangente2(vx, vz);
	}
	if (mira) {
		double dx = mira_x - x, dz = mira_z - z;
		if (dx * dx + dz * dz > 1e-6) {
			return mate::arcotangente2(dx, dz);
		}
	}
	return rumbo;
}

// Gira hacia _hacia como mucho `giro` por segundo: la agilidad.
void Cuerpo::_girar(const ParametrosCuerpo &p, bool trabado, double dt) {
	if (trabado) {
		return;
	}
	double dif = giro_pendiente(p);
	double maximo = giro * dt;
	rumbo = mate::envolver(rumbo + std::clamp(dif, -maximo, maximo));
}

// MotorEspacial.intensidad_de_esfuerzo y actualizar_reserva, por paso.
void Cuerpo::_gastar(const ParametrosCuerpo &p, double rapidez_previa, double dt) {
	double r = rapidez();
	double v = std::clamp(r / std::max(vel_max, 0.1), 0.0, 1.0);
	double arranque = std::clamp(std::max(r - rapidez_previa, 0.0) / std::max(aceleracion * dt, 0.0001), 0.0, 1.0);
	double intensidad = v * v + p.peso_aceleracion * arranque;
	if (intensidad > p.umbral_sprint) {
		double tope = 1.0 + p.peso_aceleracion;
		reserva -= p.consumo_sprint * (intensidad - p.umbral_sprint) / std::max(tope - p.umbral_sprint, 0.01) * dt;
	} else if (reserva < 1.0) {
		reserva += p.recuperacion_reserva * (1.0 - intensidad / std::max(p.umbral_sprint, 0.01)) * dt;
	}
	reserva = std::clamp(reserva, 0.0, 1.0);
}

// Preparación → ventana de contacto → recuperación. La ventana va centrada en
// el cuadro de contacto del clip; un clip sin contacto es todo preparación.
void Cuerpo::_avanzar_accion(const ParametrosCuerpo &p, const std::vector<Clip> &clips, double dt) {
	const Clip &c = clips[size_t(clip)];
	FaseAccion antes = fase;
	tiempo_accion += dt;
	FaseAccion ahora = PREPARACION;
	if (c.contacto_seg >= 0.0) {
		double medio = p.ventana_contacto_seg * 0.5;
		if (tiempo_accion > c.contacto_seg + medio) {
			ahora = RECUPERACION;
		} else if (tiempo_accion >= c.contacto_seg - medio) {
			ahora = CONTACTO;
		}
	}
	bool termina = tiempo_accion >= c.duracion;
	if (ahora == CONTACTO && antes != CONTACTO) {
		eventos |= ABRE_CONTACTO;
	}
	if (antes == CONTACTO && (ahora != CONTACTO || termina)) {
		eventos |= CIERRA_CONTACTO;
	}
	fase = ahora;
	if (termina) {
		if (ahora == CONTACTO && antes != CONTACTO) {
			// Ventana más corta que un paso al final del clip: abre y cierra.
			eventos |= CIERRA_CONTACTO;
		}
		eventos |= TERMINA_ACCION;
		clip = -1;
		fase = SIN_ACCION;
		tiempo_accion = 0.0;
	}
}
