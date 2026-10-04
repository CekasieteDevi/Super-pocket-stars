#!/usr/bin/env bash
# Corre TODA la regresion en paralelo y devuelve 1 si algo fallo.
#
# En serie tarda mas de diez minutos, y casi todo ese tiempo son dos o
# tres tests que simulan temporadas enteras de las diez divisiones.
# Los 81 tests son procesos independientes: cada uno arma su propio mundo
# con su propia semilla y el unico que toca el disco (test_guardado) usa
# su archivo aparte, user://partida_test.json. O sea que se pueden correr
# todos a la vez sin pisarse.
#
#   bash tests/correr_regresion.sh [trabajos]
#
# `trabajos` por defecto = la mitad de los nucleos, para no dejar la
# maquina sin aire mientras corre.

set -u
cd "$(dirname "$0")/.."

# El hook del changelog vive en el repo, pero git solo lo usa si esta
# configurado. Como la regresion gatea el commit, lo activa aca.
git config core.hooksPath .githooks 2>/dev/null

GODOT="${GODOT:-E:/IntelliJ/Super Pocket Stars/Godot_v4.7.2-stable_win64_console.exe}"
if [ ! -f "$GODOT" ]; then
	echo "No encuentro Godot en: $GODOT"
	echo "Pasalo con GODOT=/ruta/al/godot bash tests/correr_regresion.sh"
	exit 2
fi

NUCLEOS="$(nproc 2>/dev/null || echo 4)"
TRABAJOS="${1:-$(( NUCLEOS / 2 ))}"
[ "$TRABAJOS" -lt 1 ] && TRABAJOS=1

SALIDA="$(mktemp -d)"
trap 'rm -rf "$SALIDA"' EXIT

# Los mas lentos primero: con los pesados al final, los ultimos minutos
# quedan con un solo proceso corriendo y el resto de los nucleos parados.
#
# Medidos en serie (894s la regresion entera): gradiente_persiste 245s,
# libro_de_pases 203s, calendario 88s, gamestate_flujo 74s, noticias 74s.
# Esos cinco son 684 de los 894 — los otros 76 tests juntos son 210s. Si
# se agrega uno pesado, va aca.
LENTOS="test_gradiente_persiste test_libro_de_pases test_calendario"
LENTOS="$LENTOS test_gamestate_flujo test_noticias test_phase2"
LENTOS="$LENTOS test_phase7_internacional test_copas_por_temporada"
# Medidos el 2026-09-23 con 12 en paralelo: copa_jugable 215s,
# playoff_ascenso 203s, fin_de_mitad 142s.
LENTOS="$LENTOS test_copa_jugable test_playoff_ascenso test_fin_de_mitad"
# Una temporada a mano y otra simulada con el V2: ~6 min en la nube.
LENTOS="$LENTOS test_flujo_partidos_v2"
ORDEN=""
for n in $LENTOS; do
	[ -f "tests/$n.gd" ] && ORDEN="$ORDEN tests/$n.gd"
done
for f in tests/test_*.gd; do
	case " $ORDEN " in *" $f "*) continue ;; esac
	ORDEN="$ORDEN $f"
done

# Un test que tira SCRIPT ERROR antes de su quit() no termina nunca:
# Godot queda con el SceneTree vivo. Sin tope, la regresion esperaba
# para siempre — el 2026-09-23 nueve tests colgados por texturas sin
# importar la estiraron de ~5 a 40 minutos. Dos topes:
# - con SCRIPT ERROR en el log y el log quieto CUELGUE_TRAS_ERROR
#   segundos, se da por colgado (un test sano sigue imprimiendo o sale);
# - ninguno pasa de TOPE_TEST segundos. El mas lento medido en serie
#   tarda 245s (ver LENTOS), asi que 900 deja margen con 8 en paralelo.
CUELGUE_TRAS_ERROR="${CUELGUE_TRAS_ERROR:-30}"
TOPE_TEST="${TOPE_TEST:-900}"

# Mata el Godot de un test. El _console.exe lanza otro proceso Godot
# hijo, y matar solo el de bash deja al hijo vivo; por eso se busca por
# linea de comando en Windows. En Linux (la nube) no hay powershell y el
# proceso es uno solo: alcanza con su pid.
matar_test() {
	if command -v powershell.exe >/dev/null 2>&1; then
		powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | Where-Object { \$_.CommandLine -like '*$1*' } | ForEach-Object { Stop-Process -Id \$_.ProcessId -Force }" >/dev/null 2>&1
	fi
	kill -9 "$2" 2>/dev/null
}

correr_test() {
	local f="$1" nombre log pid inicio tam_prev tam quieto
	nombre="$(basename "$f" .gd)"
	log="$SALIDA/$nombre.log"
	inicio="$(date +%s)"
	"$GODOT" --path . --headless --script "$f" >"$log" 2>&1 &
	pid=$!
	tam_prev=-1
	quieto=0
	while kill -0 "$pid" 2>/dev/null; do
		sleep 2
		if [ $(( $(date +%s) - inicio )) -ge "$TOPE_TEST" ]; then
			echo "FALLA: colgado, supero ${TOPE_TEST}s" >>"$log"
			matar_test "$f" "$pid"
			break
		fi
		grep -q "SCRIPT ERROR" "$log" || continue
		tam="$(wc -c <"$log")"
		if [ "$tam" = "$tam_prev" ]; then
			quieto=$(( quieto + 2 ))
		else
			quieto=0
			tam_prev="$tam"
		fi
		if [ "$quieto" -ge "$CUELGUE_TRAS_ERROR" ]; then
			echo "FALLA: colgado tras SCRIPT ERROR" >>"$log"
			matar_test "$f" "$pid"
			break
		fi
	done
	wait "$pid" 2>/dev/null
	# El codigo de salida cuenta aparte del texto: un Godot que se cae
	# (crash, falta de memoria) no llega a imprimir FALLA (BUG-006).
	echo "$?" >"$SALIDA/$nombre.codigo"
	echo "$(( $(date +%s) - inicio )) $nombre" >"$SALIDA/$nombre.tiempo"
}

INICIO="$(date +%s)"
for f in $ORDEN; do
	while [ "$(jobs -rp | wc -l)" -ge "$TRABAJOS" ]; do
		wait -n 2>/dev/null || sleep 0.2
	done
	correr_test "$f" &
done
wait

FALLOS=0
for f in $ORDEN; do
	nombre="$(basename "$f" .gd)"
	log="$SALIDA/$nombre.log"
	# Un test sin registro o sin codigo no corrio: antes se salteaba y
	# contaba como pasado (BUG-006).
	if [ ! -f "$log" ] || [ ! -f "$SALIDA/$nombre.codigo" ]; then
		echo "### $f"
		echo "FALLA: el test no dejo registro o no termino"
		FALLOS=$(( FALLOS + 1 ))
		continue
	fi
	codigo="$(cat "$SALIDA/$nombre.codigo")"
	if grep -q "FALLA\|SCRIPT ERROR" "$log" || [ "$codigo" != "0" ]; then
		echo "### $f"
		grep "FALLA\|SCRIPT ERROR" "$log" | head -5
		[ "$codigo" != "0" ] && echo "FALLA: Godot salio con codigo $codigo"
		FALLOS=$(( FALLOS + 1 ))
	fi
done

# Los mas lentos de esta corrida, para mantener LENTOS al dia.
echo "Mas lentos:"
cat "$SALIDA"/*.tiempo 2>/dev/null | sort -rn | head -8 | sed 's/^/  /'

TOTAL="$(ls tests/test_*.gd | wc -l)"
echo "ARCHIVOS_CON_FALLAS=$FALLOS de $TOTAL en $(( $(date +%s) - INICIO ))s con $TRABAJOS en paralelo"
[ "$FALLOS" -eq 0 ] || exit 1
