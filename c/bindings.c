#include "lean/lean.h"
#include "godot/gdextension_interface.h"
#include <stdio.h>

lean_obj_res lean_godot_init(lean_obj_arg world) {
  printf("running code in C!");
  return lean_io_result_mk_ok(lean_box(0));
}
