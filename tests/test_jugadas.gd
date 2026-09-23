extends SceneTree

## Jugadas preparadas (core/jugadas.gd): se aprenden de a una, quedan para
## siempre, se guardan, la IA de arriba las sabe y en el partido se ven.

const SEED := 4410
const PARTIDOS := 20

var fallos := 0


func _init() -> void:
	_aprendizaje()
	_guardado()
	_ia_por_division()
	_bonus_abstracto()
	_en_la_cancha()
	print("FALLOS=%d" % fallos)
	quit(1 if fallos else 0)


func _equipo(nombre: String, id_inicial: int, semilla: int) -> Team:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	return Team.generar(nombre, rng, id_inicial, NivelDivision.potencial(4),
		"Uruguay", NivelDivision.realizacion(4))


func _aprendizaje() -> void:
	var t := _equipo("A", 0, SEED)
	t.jugadas_aprendidas = []
	t.carga_entrenamiento = "normal"
	t.ejercicio_tactico = "libre"
	_ok(Jugadas.empezar(t, Jugadas.CORNER_CORTO), "se empieza una jugada")
	_ok(not Jugadas.empezar(t, Jugadas.PAREDES), "con una en curso no se puede empezar otra")
	var semanas := int(ceil(Jugadas.semanas_de(Jugadas.CORNER_CORTO)))
	for i in range(semanas - 1):
		t.avanzar_dias(7)
	_ok(t.jugada_en_curso == Jugadas.CORNER_CORTO and t.jugada_terminada == "",
		"una semana antes de terminar sigue en curso (%.1f de %.0f)" % [
			t.jugada_semanas, Jugadas.semanas_de(Jugadas.CORNER_CORTO)])
	t.avanzar_dias(7)
	_ok(Jugadas.sabe(t, Jugadas.CORNER_CORTO) and t.jugada_en_curso == "",
		"al completar las semanas queda aprendida y libera la ranura")
	_ok(t.jugada_terminada == Jugadas.CORNER_CORTO, "el tramo que la termina la avisa")
	t.avanzar_dias(1)
	_ok(t.jugada_terminada == "", "el aviso dura un solo tramo")
	_ok(not Jugadas.empezar(t, Jugadas.CORNER_CORTO), "una aprendida no se vuelve a empezar")

	# El ejercicio "Jugadas armadas" acelera.
	var lento := _equipo("L", 0, SEED)
	var rapido := _equipo("R", 0, SEED)
	for e in [lento, rapido]:
		e.jugadas_aprendidas = []
		e.carga_entrenamiento = "normal"
		Jugadas.empezar(e, Jugadas.CORNER_BLOQUE)
	lento.ejercicio_tactico = "libre"
	rapido.ejercicio_tactico = "jugadas_armadas"
	for i in range(10):
		lento.avanzar_dias(7)
		rapido.avanzar_dias(7)
	_ok(is_equal_approx(rapido.jugada_semanas, lento.jugada_semanas * Jugadas.RITMO_CON_JUGADAS_ARMADAS),
		"con Jugadas armadas se aprende %.1f veces más rápido" % Jugadas.RITMO_CON_JUGADAS_ARMADAS)


func _guardado() -> void:
	var t := _equipo("G", 0, SEED + 1)
	t.jugadas_aprendidas = [Jugadas.PAREDES, Jugadas.AMAGUE]
	t.jugada_en_curso = Jugadas.CONTRAPRESION
	t.jugada_semanas = 4.5
	var vuelta := Team.cargar(JSON.parse_string(JSON.stringify(t.guardar())))
	_ok(vuelta.jugadas_aprendidas == [Jugadas.PAREDES, Jugadas.AMAGUE], "las aprendidas se guardan")
	_ok(vuelta.jugada_en_curso == Jugadas.CONTRAPRESION and is_equal_approx(vuelta.jugada_semanas, 4.5),
		"la jugada en curso y su avance se guardan")

	var datos: Dictionary = t.guardar()
	datos.erase("jugadas_aprendidas")
	datos.erase("jugada_en_curso")
	datos.erase("jugada_semanas")
	datos["jugadas_aprendidas"] = ["no_existe", Jugadas.PAREDES]
	var viejo := Team.cargar(datos)
	_ok(viejo.jugadas_aprendidas == [Jugadas.PAREDES] and viejo.jugada_en_curso == "",
		"una partida vieja o con ids desconocidos carga limpia")


func _ia_por_division() -> void:
	var arriba := _equipo("Club Arriba", 0, SEED + 2)
	arriba.jugadas_aprendidas = []
	Jugadas.completar_ia(arriba, 0)
	_ok(arriba.jugadas_aprendidas.size() == Jugadas.CANTIDAD_IA[0],
		"un club de primera sabe %d jugadas" % Jugadas.CANTIDAD_IA[0])
	var abajo := _equipo("Club Abajo", 0, SEED + 3)
	abajo.jugadas_aprendidas = []
	Jugadas.completar_ia(abajo, 9)
	_ok(abajo.jugadas_aprendidas.is_empty(), "un club de décima no sabe ninguna")
	var copia := _equipo("Club Arriba", 0, SEED + 2)
	copia.jugadas_aprendidas = []
	Jugadas.completar_ia(copia, 0)
	_ok(copia.jugadas_aprendidas == arriba.jugadas_aprendidas, "el reparto de la IA es estable por club")
	var preferida: String = Jugadas.PREFERIDAS[arriba.estilo][0]
	_ok(arriba.jugadas_aprendidas.has(preferida), "empieza por la que le sirve a su estilo")
	Jugadas.completar_ia(arriba, 8)
	_ok(arriba.jugadas_aprendidas.size() == Jugadas.CANTIDAD_IA[0], "descender no le borra jugadas")

	var liga := Liga.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var nombres := []
	for i in range(4):
		nombres.append("Club %d" % i)
	liga.inicializar(nombres, rng, 0, 1)
	var todos := true
	for e in liga.equipos:
		todos = todos and e.jugadas_aprendidas.size() == Jugadas.CANTIDAD_IA[1]
	_ok(todos, "la liga de segunda nace con %d jugadas por club" % Jugadas.CANTIDAD_IA[1])


func _bonus_abstracto() -> void:
	var a := _equipo("A", 0, SEED)
	var b := _equipo("B", 400, SEED)
	a.jugadas_aprendidas = [Jugadas.CONTRAPRESION]
	b.jugadas_aprendidas = []
	var solo := Jugadas.bonus_abstracto(a, b, "quite")
	_ok(solo > 0.0 and Jugadas.bonus_abstracto(a, b, "tiro") == 0.0,
		"la presión tras pérdida suma solo en el quite del MatchEngine")
	b.jugadas_aprendidas = [Jugadas.CONTRAPRESION]
	_ok(is_equal_approx(Jugadas.bonus_abstracto(a, b, "quite"), solo * Jugadas.LECTURA_DEL_RIVAL),
		"si el rival también la sabe, la ventaja se achica")


## Cada jugada, puesta a usarse siempre, aparece en el partido: el equipo
## que la sabe la ejecuta y el relato la cuenta. La defensa adelantada se
## mide contra los mismos partidos sin ella.
func _en_la_cancha() -> void:
	var uso_original: Dictionary = Jugadas.USO.duplicate()
	for id in Jugadas.USO:
		Jugadas.USO[id] = 1.0
	var con_trampa := 0
	var sin_trampa := 0
	for id in Jugadas.LISTA:
		var usos := 0
		var relatadas := 0
		# El tiro libre directo a favor sale ~0,1 veces por partido: con 20
		# partidos el amague aparecía 2 veces y un cambio de azar lo bajaba
		# a 0 sin que la jugada se rompiera.
		var partidos := PARTIDOS * 3 if id == Jugadas.AMAGUE else PARTIDOS
		for i in range(partidos):
			var res := _jugar(id, i)
			var st: Dictionary = res["stats"]["jugadas"]
			usos += int((st.get("local", {}) as Dictionary).get(id, 0))
			for ev in res["eventos"]:
				if str(ev.get("tipo", "")) == "jugada" and str(ev.get("jugada", "")) == id \
						and RelatoPartido.linea(ev, {}) != "":
					relatadas += 1
			if id == Jugadas.DEFENSA_ADELANTADA:
				con_trampa += int((st.get("offsides", {}) as Dictionary).get("visitante", 0))
				sin_trampa += int((_jugar("", i)["stats"]["jugadas"].get("offsides", {}) as Dictionary).get("visitante", 0))
		# Paredes y contragolpe pasan cada pocos segundos: se cuentan pero
		# no se relatan.
		var sin_relato: bool = id in [Jugadas.PAREDES, Jugadas.CONTRAGOLPE]
		_ok(usos > 0 and (relatadas > 0 or sin_relato), "%s se usa en el partido (%d veces en %d partidos, %d relatadas)" % [
			Jugadas.NOMBRE[id], usos, partidos, relatadas])
	_ok(con_trampa > sin_trampa, "la defensa adelantada deja más rivales en offside (%d contra %d)" % [
		con_trampa, sin_trampa])
	for id in uso_original:
		Jugadas.USO[id] = uso_original[id]


func _jugar(id: String, i: int) -> Dictionary:
	var a := _equipo("A", 0, SEED + 100 + i)
	var b := _equipo("B", 400, SEED + 100 + i)
	a.jugadas_aprendidas = [] if id == "" else [id]
	b.jugadas_aprendidas = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 3 + i
	return MotorEspacial.simular(a, b, rng, false)


func _ok(condicion: bool, mensaje: String) -> void:
	print(("OK: " if condicion else "FALLA: ") + mensaje)
	if not condicion:
		fallos += 1
