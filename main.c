#include <stdio.h>
#include <lean/lean.h>


extern void lean_initialize_runtime_module();
extern void lean_initialize();
extern void lean_io_mark_end_initialization();
extern lean_object * initialize_LeanGodot(uint8_t builtin, lean_object *);
extern lean_object *lean_godot_init();


int main () {
  printf("[main] running C code!");
  lean_initialize_runtime_module();
  lean_object *res;

  uint8_t builtin = 1;
  res = initialize_LeanGodot(builtin, lean_io_mk_world());
  if (lean_io_result_is_ok(res)) {
    lean_dec_ref(res);
  } else {
    lean_io_result_show_error(res);
    lean_dec(res);
    return 1;
  }
  lean_io_mark_end_initialization();

  lean_godot_init();
  
  
}
