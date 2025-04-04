#include <stdio.h>
#include "godot-headers/godot/gdextension_interface.h"
#include <dlfcn.h>

typedef int (*init_fn)();

int main () {
  void *handle = dlopen(".lake/build/lib/libleangodot.so", RTLD_LAZY);
  printf("loading lean_godot_gdnative_init\n");
  GDExtensionInitializationFunction f =
    (GDExtensionInitializationFunction)dlsym(handle, "lean_godot_gdnative_init");
  printf("loaded?\n");
  printf("%p\n", dlsym(handle, "_initialise_lean_state"));
  init_fn g = (init_fn)dlsym(handle, "_initialise_lean_state");
  g();
}
