#include "lean/lean.h"
#include "godot/gdextension_interface.h"
#include <stdio.h>
#include <stdint.h>
/* #include "../godot-headers/godot/gdextension_interface.h" */

#define LEAN4_CALL_IO(res,expr) \
  do { \
  res = expr; \
  if (lean_io_result_is_ok(res)) { \
    lean_dec_ref(res); \
  } else { \
    lean_io_result_show_error(res); \
    lean_dec(res); \
  } \
  } while(0)

#define LEAN4_CHECK_FP_INIT(fp) \
  do {\
  if(fp == NULL) { \
    return lean_mk_io_user_error(\
         lean_mk_string("godot binding " #fp " has not been initialised") \
    );             \
  } \
  } while(0)

#define LEAN4_CHECK_FP_INIT_PURE(fp) \
  do {\
  if(fp == NULL) { \
    lean_panic("godot binding " #fp " has not been initialised", true); \
  } \
  } while(0)


#define REGISTER_LEAN_CLASS(NAME, FINALISER, FOREACH) \
  static lean_external_class * g_ ## NAME ## _class; \
  static lean_external_class * get_ ## NAME ## _class() { \
     if(g_ ## NAME ## _class == NULL) { g_ ## NAME ## _class = lean_register_external_class(&FINALISER,&FOREACH); } \
     return g_ ## NAME ## _class; \
  }

/* * External Functions */
/* ** Utilities */
inline static void noop_foreach(void *mod, b_lean_obj_arg fn) {}

/* ** Class Declarations */
static void lean4_GDExtensionVariantPtr_finalizer(void * _obj) {}
REGISTER_LEAN_CLASS(GDExtensionVariantPtr, lean4_GDExtensionVariantPtr_finalizer, noop_foreach)


/* static void lean4_GDExtensionStringPtr_finalizer(void * _obj) {} */
/* REGISTER_LEAN_CLASS(GDExtensionStringPtr, lean4_GDExtensionStringPtr_finalizer, noop_foreach) */

#include "declarations.h"

/* ** Runtime setup */
extern void lean_initialize_runtime_module();
extern void lean_initialize();
extern void lean_io_mark_end_initialization();

extern lean_object *initialize_LeanGodot(uint8_t builtin, lean_object *);
/* ** Lean4->C bindings */
extern lean_object *lean_godot_on_initialization(GDExtensionInitializationLevel);
extern lean_object *lean_godot_on_deinitialization(GDExtensionInitializationLevel);

/* ** C->Lean4 bindings */

/* *** Get Godot Version */
GDExtensionInterfaceGetGodotVersion get_godot_version = NULL;
lean_object *lean4_get_version() {
  GDExtensionGodotVersion version;
  LEAN4_CHECK_FP_INIT(get_godot_version);
  get_godot_version(&version);

  lean_object *obj = lean_alloc_ctor(0,1,sizeof(uint32_t) * 3);
  lean_ctor_set(obj, 0, lean_mk_string(version.string));
  lean_ctor_set_uint32(obj, sizeof(void *), version.major);
  lean_ctor_set_uint32(obj, sizeof(void *) + sizeof(uint32_t), version.minor);
  lean_ctor_set_uint32(obj, sizeof(void *) + sizeof(uint32_t)*2, version.patch);

  return lean_io_result_mk_ok(obj);
}


/* *** Print Error */
GDExtensionInterfacePrintError print_error;
lean_object *lean4_print_error(lean_object *p_description,
                               lean_object *p_function,
                               lean_object *p_file,
                               int32_t p_line,
                               int8_t p_editor_notify) {
  LEAN4_CHECK_FP_INIT(print_error);
  print_error(
              lean_string_cstr(p_description),
              lean_string_cstr(p_function),
              lean_string_cstr(p_file),
              p_line,
              p_editor_notify
  );

  return lean_io_result_mk_ok(lean_box(0));
}

/* *** Print Warning */
GDExtensionInterfacePrintWarning print_warning;
lean_object *lean4_print_warning(lean_object *p_description,
                               lean_object *p_function,
                               lean_object *p_file,
                               int32_t p_line,
                               int8_t p_editor_notify) {
  LEAN4_CHECK_FP_INIT(print_warning);
  print_warning(
              lean_string_cstr(p_description),
              lean_string_cstr(p_function),
              lean_string_cstr(p_file),
              p_line,
              p_editor_notify
  );

  return lean_io_result_mk_ok(lean_box(0));
}

/* *** Print Script Error */
GDExtensionInterfacePrintScriptError print_script_error;
lean_object *lean4_print_script_error(lean_object *p_description,
                               lean_object *p_function,
                               lean_object *p_file,
                               int32_t p_line,
                               int8_t p_editor_notify) {
  LEAN4_CHECK_FP_INIT(print_script_error);
  print_script_error(
              lean_string_cstr(p_description),
              lean_string_cstr(p_function),
              lean_string_cstr(p_file),
              p_line,
              p_editor_notify
  );

  return lean_io_result_mk_ok(lean_box(0));
}

/* *** Get native struct size */
GDExtensionInterfaceGetNativeStructSize get_native_struct_size = NULL;
uint64_t lean4_get_native_struct_size(lean_object *string) {
  LEAN4_CHECK_FP_INIT_PURE(get_native_struct_size);
  GDExtensionStringPtr gstring = lean_get_external_data(string);
  uint64_t res = get_native_struct_size(gstring);
  return res;
}

/* ** Variant */
GDExtensionInterfaceVariantNewNil variant_new_nil = NULL;
lean_object *lean4_variant_new_nil(GDExtensionUninitializedVariantPtr r_dest) {
  LEAN4_CHECK_FP_INIT(variant_new_nil);
  void *res = NULL;
  variant_new_nil(&res);
  lean_object *variantObj = lean_alloc_external(get_GDExtensionVariantPtr_class(), (void *)res);
  return lean_io_result_mk_ok(variantObj);
}

/* ** String */

/* *** String_new_with_latin1_chars */
GDExtensionInterfaceStringNewWithLatin1Chars string_new_with_latin1_chars = NULL;
lean_object *lean4_string_new_with_latin1_chars(lean_object *string) {
  LEAN4_CHECK_FP_INIT(string_new_with_latin1_chars);
  void *res = NULL;
  string_new_with_latin1_chars(&res, lean_string_cstr(string));
  lean_object *strObject = lean_alloc_external(get_GDExtensionStringPtr_class(), (void *)res);
  return lean_io_result_mk_ok(strObject);
}

/* GDExtensionInterfaceStringNewWithUtf8Chars string_new_with_utf8_chars = NULL; */
/* lean_object *lean4_string_new_with_utf8_chars(lean_object *string) { */
/*   LEAN4_CHECK_FP_INIT(string_new_with_utf8_chars); */
/*   GDExtensionStringPtr res = NULL; */
/*   string_new_with_utf8_chars(&res, lean_string_cstr(string)); */
/*   lean_object *strObject = lean_alloc_external(get_GDExtensionStringPtr_class(), (void *)res); */
/*   return lean_io_result_mk_ok(strObject); */
/* } */

GDExtensionInterfaceStringToLatin1Chars string_to_latin1_chars = NULL;
lean_object *lean4_string_to_latin1_chars(lean_object *string) {
  LEAN4_CHECK_FP_INIT(string_to_latin1_chars);
  GDExtensionStringPtr gstring = lean_get_external_data(string);
  GDExtensionInt len = string_to_latin1_chars(&gstring,NULL,0);
  char buf[len];
  string_to_latin1_chars(&gstring,buf,len);
  lean_object *res = lean_mk_string_from_bytes(buf, len);
  return lean_io_result_mk_ok(res);
}

/* GDExtensionInterfaceStringToUtf8Chars string_to_utf8_chars = NULL; */
/* lean_object *lean4_string_to_utf8_chars(lean_object *string) { */
/*   LEAN4_CHECK_FP_INIT(string_to_utf8_chars); */
/*   GDExtensionStringPtr gstring = lean_get_external_data(string); */
/*   GDExtensionInt len = string_to_utf8_chars(&gstring,NULL,0); */
/*   char buf[len]; */
/*   string_to_utf8_chars(&gstring,buf,len); */
/*   lean_object *res = lean_mk_string_from_bytes(buf, len); */
/*   return lean_io_result_mk_ok(res); */
/* } */

/* * Helpers */
int _initialise_lean_state() {
  printf("[lean4-godot] calling initialise_lean_state\n");
  lean_initialize();
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
  printf("[lean4-godot] finished initialisation\n");
  return 0;
}


void lean4_godot_initialize_callback(void *userdata, GDExtensionInitializationLevel p_level) {
  /* printf("[lean4-godot] initialisation level %d\n", p_level); */
  lean_object *res;
  LEAN4_CALL_IO(res,lean_godot_on_initialization(p_level));
}
void lean4_godot_deinitialize_callback(void *userdata, GDExtensionInitializationLevel p_level) {
  /* printf("[lean4-godot] deinitialisation level %d\n", p_level); */
  lean_object *res;
  LEAN4_CALL_IO(res,lean_godot_on_deinitialization(p_level));
}

/* * Main entry point  */
GDExtensionBool lean_godot_gdnative_init(
   GDExtensionInterfaceGetProcAddress p_get_proc_address,
   GDExtensionClassLibraryPtr p_library,
   GDExtensionInitialization *r_initialization
) {
  get_godot_version = (GDExtensionInterfaceGetGodotVersion)p_get_proc_address("get_godot_version");
  print_error = (GDExtensionInterfacePrintError)p_get_proc_address("print_error");
  print_warning = (GDExtensionInterfacePrintWarning)p_get_proc_address("print_warning");
  print_script_error = (GDExtensionInterfacePrintScriptError)p_get_proc_address("print_script_error");
  
  variant_new_nil = (GDExtensionInterfaceVariantNewNil)p_get_proc_address("variant_new_nil");

  string_new_with_latin1_chars = (GDExtensionInterfaceStringNewWithLatin1Chars)p_get_proc_address("string_new_with_latin1_chars");
  /* string_new_with_utf8_chars = (GDExtensionInterfaceStringNewWithUtf8Chars)p_get_proc_address("string_new_with_utf8_chars"); */
  string_to_latin1_chars = (GDExtensionInterfaceStringToLatin1Chars)p_get_proc_address("string_to_latin1_chars");

  #include "init.h"


  // initialise lean
  if(_initialise_lean_state()) {
    printf("[lean4-godot] could not initialise lean4 state\n");
    return false;
  }
  printf("[lean4-godot] finished lean initialisation");

  r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_CORE;
  r_initialization->userdata = NULL;
  r_initialization->initialize = lean4_godot_initialize_callback;
  r_initialization->deinitialize = lean4_godot_deinitialize_callback;
  
  return true;
}
