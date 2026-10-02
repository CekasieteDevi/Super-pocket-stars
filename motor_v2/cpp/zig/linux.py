# Arma la biblioteca de Linux del Motor V2 desde Windows, con Zig como
# compilador cruzado (docs/motor_v2.md, "Cómo se arma la extensión").
#
# godot-cpp carga este archivo en lugar de su tools/linux.py cuando se le pasa
# custom_tools=zig. En una PC con Linux no hace falta: ahí va el compilador
# del sistema.
#
#   python -m SCons api_version=4.7 target=template_release platform=linux custom_tools=zig ZIG=D:/dev-tools/zig-x86_64-windows-0.16.0/zig.exe
import os
import sys

import common_compiler_flags
import my_spawn
from SCons.Variables import BoolVariable

# La glibc contra la que se enlaza. 2.31 es la de Ubuntu 20.04: la biblioteca
# carga en esa y en cualquiera más nueva.
OBJETIVO = "x86_64-linux-gnu.2.31"


def options(opts):
    opts.Add("ZIG", "Ruta a zig.exe", os.environ.get("ZIG", "zig"))
    # Las mismas opciones que tools/linux.py: el SConstruct de godot-cpp las lee.
    opts.Add(BoolVariable("use_llvm", "No se usa con Zig", False))
    opts.Add(BoolVariable("use_static_cpp", "No se usa con Zig: enlaza libc++ adentro", True))


def exists(env):
    return True


def generate(env):
    if env["arch"] != "x86_64":
        print("Con Zig solo está preparado x86_64.")
        env.Exit(1)
    if sys.platform == "win32" or sys.platform == "msys":
        # Líneas de comando largas en Windows (lo mismo que tools/android.py).
        my_spawn.configure(env)
    # SCons le pasa al compilador un entorno casi vacío, y Zig busca su caché
    # en LOCALAPPDATA: sin esto falla con "AppDataDirUnavailable". Va al lado
    # de zig.exe, fuera del repo.
    cache = os.path.join(os.path.dirname(os.path.abspath(env["ZIG"])), "cache")
    env["ENV"]["ZIG_GLOBAL_CACHE_DIR"] = cache
    env["ENV"]["ZIG_LOCAL_CACHE_DIR"] = cache
    zig = '"%s"' % env["ZIG"].replace("\\", "/")
    env["CC"] = zig + " cc -target " + OBJETIVO
    env["CXX"] = zig + " c++ -target " + OBJETIVO
    env["LINK"] = zig + " c++ -target " + OBJETIVO
    env["AR"] = zig + " ar"
    env["RANLIB"] = zig + " ranlib"
    # godot-cpp son 900 objetos: la línea de `ar` no entra en lo que acepta
    # Windows. SCons la pasa en un archivo de respuesta (@archivo).
    # TEMPFILE deja afuera del archivo la primera palabra (para él, el
    # programa): acá es el primer objeto, y `zig ar rcs` queda en la línea.
    env["ARCOM"] = "$AR rcs $TARGET ${TEMPFILE('$SOURCES', '$ARCOMSTR')}"
    env["TEMPFILEARGJOIN"] = os.linesep
    env["RANLIBCOM"] = ""
    env["SHLIBSUFFIX"] = ".so"
    # Zig no reconoce la extensión .os que usa SCons para los objetos de una
    # biblioteca compartida.
    env["SHOBJSUFFIX"] = ".o"
    env["OBJSUFFIX"] = ".o"
    env["LIBPREFIX"] = "lib"
    env["LIBSUFFIX"] = ".a"
    env["SHLIBPREFIX"] = "lib"

    # zig cc agrega el sanitizador de comportamiento indefinido si no se le
    # dice lo contrario: mete llamadas que la biblioteca no trae.
    # Sin -march: Zig no entiende "x86-64" y el objetivo ya fija el x86_64 base
    # (el mismo que pide tools/linux.py).
    env.Append(CCFLAGS=["-fPIC", "-Wwrite-strings", "-fno-sanitize=undefined"])
    env.Append(CPPDEFINES=["LINUX_ENABLED", "UNIX_ENABLED"])

    # Sin optimización al enlazar: con Zig cruzado no está probada y la de
    # Windows y Android tampoco la usan igual. El motor es chico.
    if env["lto"] == "auto":
        env["lto"] = "none"

    common_compiler_flags.generate(env)
