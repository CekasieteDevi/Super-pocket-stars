class_name DisparosPelotaV2
extends RefCounted

## Los disparos del laboratorio de la pelota (etapa 1 de docs/motor_v2.md).
## Los usan la escena laboratorio_pelota.tscn, para mirarlos, y
## tests/test_pelota_v2.gd, para medirlos: los dos ven la misma pelota.
##
## Cada uno es la pelota recién pateada: dónde está, con qué velocidad
## (m/s) y con qué giro (rad/s, el eje por la regla de la mano derecha).
## Nadie la corrige después: lo que pasa sale de la física. Ejes del motor:
## x a lo largo (el arco de la derecha en x = +52,5), y hacia arriba, z a lo
## ancho. Las miras se buscaron a mano en el banco hasta que cada disparo
## hiciera lo que dice su nombre.


static func lista() -> Array[Dictionary]:
	return [
		{
			# 30 m/s a 32°, con algo de giro hacia atrás (eje +z yendo hacia +x).
			"nombre": "Saque de arco",
			"pos": Vector3(-47.0, 0.11, -5.0),
			"vel": Vector3(25.4, 16.0, 0.0),
			"giro": Vector3(0.0, 0.0, 8.0),
			"segundos": 10.0,
		},
		{
			# Giro negativo en y yendo hacia +x curva hacia +z. Sin giro, la
			# misma patada pasa 3 m afuera del palo.
			"nombre": "Tiro con efecto",
			"pos": Vector3(30.0, 0.11, -10.0),
			"vel": Vector3(25.0, 6.5, 3.6),
			"giro": Vector3(0.0, -55.0, 0.0),
			"segundos": 3.0,
		},
		{
			# Rasante a la cara de afuera del palo derecho.
			"nombre": "Tiro al palo",
			"pos": Vector3(40.0, 0.11, 0.0),
			"vel": Vector3(22.0, 0.0, 6.7),
			"giro": Vector3.ZERO,
			"segundos": 3.0,
		},
		{
			"nombre": "Tiro al travesaño",
			"pos": Vector3(38.0, 0.11, 0.0),
			"vel": Vector3(20.0, 7.3, 0.0),
			"giro": Vector3.ZERO,
			"segundos": 3.0,
		},
		{
			"nombre": "Remate a la red",
			"pos": Vector3(40.0, 0.11, 0.0),
			"vel": Vector3(22.0, 3.0, 1.0),
			"giro": Vector3.ZERO,
			"segundos": 3.0,
		},
		{
			# Desde la banda de arriba hacia el punto penal, cerrándose al arco.
			"nombre": "Centro",
			"pos": Vector3(45.0, 0.11, -32.0),
			"vel": Vector3(-6.0, 11.0, 20.0),
			"giro": Vector3(0.0, 6.0, 0.0),
			"segundos": 4.0,
		},
		{
			"nombre": "Globo",
			"pos": Vector3(20.0, 0.11, 0.0),
			"vel": Vector3(16.0, 16.0, 0.0),
			"giro": Vector3.ZERO,
			"segundos": 6.0,
		},
	]


static func buscar(nombre: String) -> Dictionary:
	for d in lista():
		if d["nombre"] == nombre:
			return d
	return {}


## Simula un disparo entero con `pelota` (PelotaV2Nativa) y devuelve lo que
## mide el laboratorio.
## - `desvio_m`: lo más que se separó a lo ancho de la recta de la patada,
##   hasta el primer choque con el arco.
## - `rodo_m`: metros rodados desde que dejó de picar hasta pararse.
## - `volvio`: la velocidad a lo largo cambió de signo (rebotó para atrás).
static func medir(pelota: Object, parametros: Dictionary, d: Dictionary) -> Dictionary:
	pelota.configurar(parametros)
	pelota.poner(d["pos"], d["vel"], d["giro"])
	var inicio: Vector3 = d["pos"]
	var vel: Vector3 = d["vel"]
	var plano := Vector2(vel.x, vel.z).normalized()
	var altura_max := 0.0
	var primer_pique_x := NAN
	var empezo_a_rodar := Vector3.INF
	var desvio := 0.0
	var volvio := false
	var tocado := false
	var pasos := int(float(d["segundos"]) * 60.0)
	for k in pasos:
		var e: int = pelota.avanzar()
		var p: Vector3 = pelota.get_pos()
		altura_max = maxf(altura_max, p.y)
		if e & PelotaV2Nativa.PIQUE and is_nan(primer_pique_x):
			primer_pique_x = p.x
		if e & PelotaV2Nativa.EMPIEZA_A_RODAR:
			empezo_a_rodar = p
		if e & (PelotaV2Nativa.PALO | PelotaV2Nativa.TRAVESANO | PelotaV2Nativa.RED):
			tocado = true
		if not tocado:
			var rel := Vector2(p.x - inicio.x, p.z - inicio.z)
			desvio = maxf(desvio, absf(rel.x * plano.y - rel.y * plano.x))
		if signf(pelota.get_vel().x) == -signf(vel.x) and absf(pelota.get_vel().x) > 0.5:
			volvio = true
	var c: Dictionary = pelota.contadores()
	var fin: Vector3 = pelota.get_pos()
	c["altura_max"] = altura_max
	c["primer_pique_x"] = primer_pique_x
	c["rodo_m"] = 0.0 if empezo_a_rodar == Vector3.INF else Vector2(fin.x - empezo_a_rodar.x,
		fin.z - empezo_a_rodar.z).length()
	c["desvio_m"] = desvio
	c["volvio"] = volvio
	c["fin"] = fin
	c["quieta"] = pelota.get_vel() == Vector3.ZERO
	c["huella"] = pelota.huella()
	return c
