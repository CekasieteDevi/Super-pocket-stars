#include "cuerpos_v2_nativos.h"
#include "mundo_v2_nativo.h"
#include "pelota_v2_nativa.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void iniciar_modulo(ModuleInitializationLevel nivel) {
	if (nivel != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(MundoV2Nativo);
	GDREGISTER_CLASS(PelotaV2Nativa);
	GDREGISTER_CLASS(CuerposV2Nativos);
}

void terminar_modulo(ModuleInitializationLevel nivel) {
}

extern "C" {
GDExtensionBool GDE_EXPORT motor_v2_iniciar(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(iniciar_modulo);
	init_obj.register_terminator(terminar_modulo);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
