extends SceneTree

## Profundidad de plantel y lesiones: el escalon once/banco, la
## convocatoria de emergencia desde la cantera, y la fuga de expulsados
## que dejaba a un equipo con un jugador menos para siempre.

const SEED := 90210


func _init() -> void:
	_test_banco_es_peor_que_el_once()
	_test_convocatoria_cubre_el_minimo()
	_test_convocado_vuelve_a_la_cantera()
	_test_convocado_lesionado_no_se_cura_al_volver()
	_test_forfeit_limpia_expulsados()
	quit()


func _test_banco_es_peor_que_el_once() -> void:
	print("
=== Hay escalon real entre el once y el banco ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var once := 0.0
	var suplentes := 0.0
	var n := 0.0
	for k in range(30):
		var t := Team.generar("Club %d" % k, rng, k * 1000)
		for j in t.jugadores:
			once += float(j["media"])
		for j in t.banco:
			suplentes += float(j["media"])
		n += 1.0
	var m_once: float = once / n / float(Team.FORMACION.size())
	var m_banco: float = suplentes / n / float(Team.BANCO_FORMACION.size())
	var escalon: float = m_once - m_banco
	# Sin escalon, una lesion no cuesta nada: entra alguien identico al
	# lesionado y el sistema de lesiones no se siente por mas alta que sea
	# la tasa. Ese era el bug, no la tasa.
	if escalon >= 5.0:
		print("OK: once %.1f, banco %.1f, escalon %.1f de media." % [m_once, m_banco, escalon])
	else:
		print("FALLA: escalon de solo %.1f (once %.1f, banco %.1f) -- una lesion no cuesta nada." % [
			escalon, m_once, m_banco])
	# El banco baja por techo realizado, no por techo: un suplente tiene
	# que poder crecer y quedarse con el puesto (§7.2/§7.3).
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = SEED
	var t2 := Team.generar("Techos", rng2)
	var pot_once := 0.0
	var pot_banco := 0.0
	for j in t2.jugadores:
		pot_once += float(j["potencial"])
	for j in t2.banco:
		pot_banco += float(j["potencial"])
	pot_once /= float(t2.jugadores.size())
	pot_banco /= float(t2.banco.size())
	if abs(pot_once - pot_banco) < 8.0:
		print("OK: el potencial del banco (%.1f) es comparable al del once (%.1f): puede crecer." % [
			pot_banco, pot_once])
	else:
		print("FALLA: el banco nace con %.1f de potencial contra %.1f del once, no es un suplente sino un descarte." % [
			pot_banco, pot_once])


func _test_convocatoria_cubre_el_minimo() -> void:
	print("\n=== Con la cantera se llega al minimo en vez de perder 0-3 ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var t := Team.generar("Diezmado", rng)
	t.generar_camada(rng, 5)
	# Cuatro bajas: el plantel de 18 cae a 14, por debajo de los 15.
	for i in range(4):
		t.lesionar(t.jugadores[i]["id"], "Desgarro grave", 40)
	if t.jugadores_sanos_count() >= Liga.MINIMO_DISPONIBLES:
		print("FALLA: el escenario no deja al equipo corto, el test no prueba nada.")
		return
	var r := t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	if t.jugadores_sanos_count() >= Liga.MINIMO_DISPONIBLES:
		print("OK: subieron %d juveniles y el equipo llega a %d disponibles." % [
			r["subidos"].size(), t.jugadores_sanos_count()])
	else:
		print("FALLA: sigue corto (%d disponibles) tras convocar %d." % [
			t.jugadores_sanos_count(), r["subidos"].size()])
	var sin_alta := 0
	for j in r["subidos"]:
		if not t.sueldos.has(j["id"]) or not t.contratos.has(j["id"]) or not t.animo.has(j["id"]):
			sin_alta += 1
	if sin_alta == 0:
		print("OK: los convocados quedan dados de alta (sueldo, contrato, animo).")
	else:
		print("FALLA: %d convocados sin dar de alta." % sin_alta)


func _test_convocado_vuelve_a_la_cantera() -> void:
	print("\n=== El convocado vuelve solo cuando el plantel se recupera ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var t := Team.generar("Diezmado 2", rng)
	t.generar_camada(rng, 5)
	var lesionados := []
	for i in range(4):
		lesionados.append(t.jugadores[i]["id"])
		t.lesionar(t.jugadores[i]["id"], "Desgarro grave", 40)
	t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	var banco_con_pibes := t.banco.size()
	var cantera_baja := t.cantera.size()

	for id in lesionados:
		t.lesiones.erase(id)
	var r := t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	if t.banco.size() < banco_con_pibes and t.cantera.size() > cantera_baja:
		print("OK: volvieron %d a la cantera (banco %d -> %d)." % [
			r["bajados"].size(), banco_con_pibes, t.banco.size()])
	else:
		print("FALLA: los convocados no volvieron (banco %d, cantera %d)." % [
			t.banco.size(), t.cantera.size()])
	var con_sueldo := 0
	for j in r["bajados"]:
		if t.sueldos.has(j["id"]):
			con_sueldo += 1
	if con_sueldo == 0:
		print("OK: al volver dejan de cobrar sueldo.")
	else:
		print("FALLA: %d siguen cobrando desde la cantera." % con_sueldo)


func _test_convocado_lesionado_no_se_cura_al_volver() -> void:
	print("\n=== Volver a la cantera no cura una lesion ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var t := Team.generar("Diezmado 3", rng)
	t.generar_camada(rng, 6)
	for i in range(4):
		t.lesionar(t.jugadores[i]["id"], "Desgarro grave", 40)
	var r := t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	if r["subidos"].is_empty():
		print("FALLA: no subio nadie, el test no prueba nada.")
		return
	var pibe: int = r["subidos"][0]["id"]
	t.lesionar(pibe, "Esguince de tobillo", 20)
	# Un convocado lesionado no aporta: se devuelve apenas se pueda.
	for i in range(4):
		t.lesiones.erase(t.jugadores[i]["id"])
	t.ajustar_convocatorias_de_emergencia(Liga.MINIMO_DISPONIBLES)
	if t.esta_lesionado(pibe):
		print("OK: el juvenil vuelve a la cantera y sigue lesionado.")
	else:
		print("FALLA: la lesion se borro al devolverlo a la cantera.")


func _test_forfeit_limpia_expulsados() -> void:
	print("\n=== Un 0-3 por no presentarse limpia expulsados_partido ===")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var liga := Liga.new()
	var nombres := []
	for i in range(4):
		nombres.append("Club %d" % i)
	liga.inicializar(nombres, rng, 0)
	var a: Team = liga.equipos[0]
	var b: Team = liga.equipos[1]
	# Rojo del partido anterior + bajas suficientes para no presentarse.
	var rojo: int = a.jugadores[0]["id"]
	a.expulsados_partido[rojo] = true
	for i in range(1, 5):
		a.lesionar(a.jugadores[i]["id"], "Desgarro grave", 40)
	liga._resolver_forfeit(a, b, true, false)
	if a.expulsados_partido.is_empty() and b.expulsados_partido.is_empty():
		print("OK: expulsados_partido queda limpio tras el forfeit.")
	else:
		print("FALLA: el expulsado sobrevive al forfeit y arrastra una baja fantasma.")
