#pragma once

// Trigonometría que da el mismo double en la PC y en Android.
//
// std::sin, std::cos y std::atan2 los pone cada sistema (el CRT de Windows,
// bionic en Android) y no coinciden en el último bit: en la etapa 0 el mismo
// partido de 90 minutos terminaba distinto (8 goles en la PC, 18 en el
// teléfono) aun sin FMA (-ffp-contract=off). Acá solo se usan +, -, *, / y
// sqrt, que IEEE 754 obliga a redondear igual en todos lados. Contra las del
// sistema el error máximo es 8e-16 (200.000 ángulos al azar).

#include <cmath>
#include <cstdint>
#include <cstring>

namespace mate {

constexpr double PI = 3.14159265358979323846;
constexpr double DOS_PI = 6.28318530717958647692;
constexpr double MEDIO_PI = 1.57079632679489661923;
constexpr double CUARTO_PI = 0.78539816339744830962;

// Redondeo al entero más cercano sin std::round (que puede ser del sistema).
inline double redondear(double x) {
	double t = double(static_cast<long long>(x));
	double resto = x - t;
	if (resto >= 0.5) {
		return t + 1.0;
	}
	if (resto <= -0.5) {
		return t - 1.0;
	}
	return t;
}

// El ángulo llevado a [-π, π].
inline double envolver(double a) {
	return a - DOS_PI * redondear(a / DOS_PI);
}

// Series de Taylor en [-π/4, π/4] (hasta x^17 y x^16): el término que se
// corta es menor que 1e-17 en ese intervalo.
inline double _seno_corto(double x) {
	double x2 = x * x;
	double s = 1.0 / 355687428096000.0;
	s = s * x2 - 1.0 / 1307674368000.0;
	s = s * x2 + 1.0 / 6227020800.0;
	s = s * x2 - 1.0 / 39916800.0;
	s = s * x2 + 1.0 / 362880.0;
	s = s * x2 - 1.0 / 5040.0;
	s = s * x2 + 1.0 / 120.0;
	s = s * x2 - 1.0 / 6.0;
	return x + x * x2 * s;
}

inline double _coseno_corto(double x) {
	double x2 = x * x;
	double c = 1.0 / 20922789888000.0;
	c = c * x2 - 1.0 / 87178291200.0;
	c = c * x2 + 1.0 / 479001600.0;
	c = c * x2 - 1.0 / 3628800.0;
	c = c * x2 + 1.0 / 40320.0;
	c = c * x2 - 1.0 / 720.0;
	c = c * x2 + 1.0 / 24.0;
	c = c * x2 - 0.5;
	return 1.0 + x2 * c;
}

// Seno y coseno a la vez: se reduce a un cuarto de vuelta y se elige el cuadrante.
inline void seno_coseno(double a, double &seno, double &coseno) {
	a = envolver(a);
	double k = redondear(a / MEDIO_PI);
	double x = a - k * MEDIO_PI;
	double s = _seno_corto(x);
	double c = _coseno_corto(x);
	int cuadrante = static_cast<int>(k) & 3;
	switch (cuadrante) {
		case 0:
			seno = s;
			coseno = c;
			break;
		case 1:
			seno = c;
			coseno = -s;
			break;
		case 2:
			seno = -s;
			coseno = -c;
			break;
		default:
			seno = -c;
			coseno = s;
			break;
	}
}

inline double seno(double a) {
	double s, c;
	seno_coseno(a, s, c);
	return s;
}

inline double coseno(double a) {
	double s, c;
	seno_coseno(a, s, c);
	return c;
}

// atan en [-1, 1]: dos medias tangentes (atan x = 2 atan(x / (1 + √(1 + x²))))
// la dejan en |x| < 0.2 y ahí alcanza la serie hasta x^21.
inline double _arcotangente_corta(double x) {
	x = x / (1.0 + std::sqrt(1.0 + x * x));
	x = x / (1.0 + std::sqrt(1.0 + x * x));
	double x2 = x * x;
	double s = -1.0 / 21.0;
	s = s * x2 + 1.0 / 19.0;
	s = s * x2 - 1.0 / 17.0;
	s = s * x2 + 1.0 / 15.0;
	s = s * x2 - 1.0 / 13.0;
	s = s * x2 + 1.0 / 11.0;
	s = s * x2 - 1.0 / 9.0;
	s = s * x2 + 1.0 / 7.0;
	s = s * x2 - 1.0 / 5.0;
	s = s * x2 + 1.0 / 3.0;
	return 4.0 * (x - x * x2 * s);
}

constexpr double LN2 = 0.69314718055994530942;

// 2^k exacto, armando los bits del double (sin ldexp, que es del sistema).
inline double _potencia_de_dos(int k) {
	if (k < -1022) {
		return 0.0;
	}
	if (k > 1023) {
		k = 1023;
	}
	uint64_t bits = uint64_t(k + 1023) << 52;
	double r;
	std::memcpy(&r, &bits, sizeof(r));
	return r;
}

// e^x, para el softmax del cerebro (etapa 4). x = k·ln 2 + r con |r| ≤ ln 2 / 2
// y la serie de Taylor de e^r hasta r^14 (el término que se corta es menor
// que 1e-17). Contra std::exp, error relativo < 4e-16 en [-700, 700].
inline double exponencial(double x) {
	if (x < -708.0) {
		return 0.0;
	}
	if (x > 709.0) {
		x = 709.0;
	}
	double k = redondear(x / LN2);
	double r = x - k * LN2;
	double s = 1.0 / 87178291200.0;
	s = s * r + 1.0 / 6227020800.0;
	s = s * r + 1.0 / 479001600.0;
	s = s * r + 1.0 / 39916800.0;
	s = s * r + 1.0 / 3628800.0;
	s = s * r + 1.0 / 362880.0;
	s = s * r + 1.0 / 40320.0;
	s = s * r + 1.0 / 5040.0;
	s = s * r + 1.0 / 720.0;
	s = s * r + 1.0 / 120.0;
	s = s * r + 1.0 / 24.0;
	s = s * r + 1.0 / 6.0;
	s = s * r + 0.5;
	s = s * r + 1.0;
	s = s * r + 1.0;
	return s * _potencia_de_dos(static_cast<int>(k));
}

// ln x (x > 0). x = m·2^e con m en [√½, √2) sacado de los bits, y
// ln m = 2·atanh(s), s = (m − 1)/(m + 1), |s| < 0,172: la serie hasta s^23
// corta menos de 1e-18. Contra std::log, error < 3e-16.
inline double logaritmo(double x) {
	if (!(x > 0.0)) {
		return -1e300;
	}
	uint64_t bits;
	std::memcpy(&bits, &x, sizeof(bits));
	int e = int((bits >> 52) & 0x7ff) - 1023;
	uint64_t mantisa = (bits & 0x000fffffffffffffULL) | 0x3ff0000000000000ULL;
	double m;
	std::memcpy(&m, &mantisa, sizeof(m));
	if (m > 1.41421356237309504880) {
		m *= 0.5;
		e += 1;
	}
	double s = (m - 1.0) / (m + 1.0);
	double s2 = s * s;
	double t = 1.0 / 23.0;
	t = t * s2 + 1.0 / 21.0;
	t = t * s2 + 1.0 / 19.0;
	t = t * s2 + 1.0 / 17.0;
	t = t * s2 + 1.0 / 15.0;
	t = t * s2 + 1.0 / 13.0;
	t = t * s2 + 1.0 / 11.0;
	t = t * s2 + 1.0 / 9.0;
	t = t * s2 + 1.0 / 7.0;
	t = t * s2 + 1.0 / 5.0;
	t = t * s2 + 1.0 / 3.0;
	t = t * s2 + 1.0;
	return 2.0 * s * t + double(e) * LN2;
}

// Mismo contrato que std::atan2(y, x).
inline double arcotangente2(double y, double x) {
	if (x == 0.0 && y == 0.0) {
		return 0.0;
	}
	double ay = y < 0.0 ? -y : y;
	double ax = x < 0.0 ? -x : x;
	double r;
	if (ay <= ax) {
		r = _arcotangente_corta(ay / ax);
	} else {
		r = MEDIO_PI - _arcotangente_corta(ax / ay);
	}
	if (x < 0.0) {
		r = PI - r;
	}
	return y < 0.0 ? -r : r;
}

} // namespace mate
