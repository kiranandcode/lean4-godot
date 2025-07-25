#include "lean/lean.h"
#include "godot/gdextension_interface.h"
#include <stdio.h>
#include <stdint.h>
#include "utils.h"
#include "builtin_type_sizes.h"
/* #include "../godot-headers/godot/gdextension_interface.h" */
/* * Macros */

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

GDExtensionClassLibraryPtr library_token = NULL;
  
/* * External Functions */
/* ** Builtins */
GDExtensionInterfaceMemAlloc mem_alloc = NULL;
GDExtensionInterfaceMemFree mem_free = NULL;
GDExtensionInterfaceVariantDestroy variant_destroy = NULL;
GDExtensionInterfaceVariantNewCopy variant_new_copy = NULL;
GDExtensionInterfaceVariantGetPtrDestructor variant_get_ptr_destructor = NULL;
GDExtensionInterfaceVariantGetType variant_get_type = NULL;
GDExtensionInterfaceVariantDuplicate variant_duplicate = NULL;
GDExtensionInterfaceGetVariantFromTypeConstructor get_variant_from_type_constructor = NULL;
GDExtensionInterfaceGetVariantToTypeConstructor get_variant_to_type_constructor = NULL;
/* ** Destructors */
#include "builtin_type_destructor_decl.h"

/* ** Conversions */
#include "builtin_type_conversion_decl.h"

/* ** Utilities */
inline static void noop_foreach(void *mod, b_lean_obj_arg fn) {}

inline static void lean_godot_variant_finalizer(void *obj) {
  if(obj == NULL) return;
  struct GDVariant *variant = (struct GDVariant *)obj;
  if(variant_destroy != NULL) { variant_destroy(variant); }
  if(mem_free != NULL) { mem_free(obj); }
}
REGISTER_LEAN_CLASS(lean_godot_variant, lean_godot_variant_finalizer, noop_foreach)

/* ** Class Declarations */
#include "builtin_type_class_decl.h"

#include "declarations.h"

/* ** Runtime setup */
extern void lean_initialize_runtime_module();
extern void lean_initialize();
extern void lean_io_mark_end_initialization();

extern lean_object *initialize_Bindings(uint8_t builtin, lean_object *);
extern lean_object *initialize_ExtensionAPI(uint8_t builtin, lean_object *);
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

GDExtensionInterfaceStringToUtf8Chars string_to_utf8_chars = NULL;
lean_object *lean4_string_to_utf8_chars(lean_object *string) {
  LEAN4_CHECK_FP_INIT_PURE(string_to_utf8_chars);
  GDExtensionStringPtr gstring = lean_get_external_data(string);
  GDExtensionInt len = string_to_utf8_chars(gstring,NULL,0);
  char buf[len];
  string_to_utf8_chars(gstring,buf,len);
  lean_object *res = lean_mk_string_from_bytes(buf, len);
  return res;
}

GDExtensionInterfaceStringNewWithUtf8CharsAndLen string_new_with_utf8_chars_and_len = NULL;
lean_object *lean4_string_new_with_utf_chars(lean_object *string) {
  LEAN4_CHECK_FP_INIT_PURE(string_new_with_utf8_chars_and_len);
  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
  LEAN4_CHECK_FP_INIT_PURE(mem_free);
  char const *cstr = lean_string_cstr(string);
  size_t len = lean_string_len(string);
  // we're allocing here, but mem_free will be called in the finaliser for the lean_godot_class
  struct GDString *gd_string = (struct GDString *)mem_alloc(sizeof(*gd_string));
  // create a godot string object, the destructor will be called byt he string_class finalizer
  string_new_with_utf8_chars_and_len(gd_string, cstr, len);
  // wrap it in a lean_object, and send it off chief
  lean_object *res = lean_alloc_external(get_lean_godot_String_class(), (void *) gd_string);
  return res;
}

lean_object *lean4_string_to_variant(lean_object *obj) {
   LEAN4_CHECK_FP_INIT_PURE(gd_string_to_variant);
   LEAN4_CHECK_FP_INIT_PURE(variant_new_copy);
   LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
   
   // doing a little jig here to avoid double frees
   struct GDString *gdString = lean_get_external_data(obj);
   struct GDVariant tmpRes;
   gd_string_to_variant(&tmpRes, gdString);
   struct GDVariant *res = (struct GDVariant *)mem_alloc(sizeof(*res));
   variant_new_copy(res, &tmpRes);

   lean_object *resObj = lean_alloc_external(get_lean_godot_variant_class(), (void *) res);
  
   return resObj;
}

GDExtensionInterfaceStringNewWithUtf8Chars string_new_with_utf8_chars = NULL;
GDExtensionInterfaceVariantStringify variant_stringify = NULL;
lean_object *lean4_variant_stringify(lean_object *variant) {
  fprintf(stderr,"variant_stringify called!\n");
  LEAN4_CHECK_FP_INIT_PURE(variant_stringify);
  LEAN4_CHECK_FP_INIT_PURE(string_new_with_utf8_chars);
  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
  LEAN4_CHECK_FP_INIT_PURE(mem_free);

  GDExtensionVariantPtr p_self_internal = (GDExtensionVariantPtr)lean_get_external_data(variant);
  struct GDString r_ret_internal;  
  
  string_new_with_utf8_chars(&r_ret_internal, "");
  variant_stringify(p_self_internal, &r_ret_internal);

  GDExtensionInt len = string_to_utf8_chars(&r_ret_internal,NULL,0);
  char buf[len];
  string_to_utf8_chars(&r_ret_internal,buf,len);

  if(gd_string_destructor != NULL) gd_string_destructor(&r_ret_internal);  

  lean_object *res = lean_mk_string_from_bytes(buf, len);
  return res;  
}

void _link_my_bindings_clang_pls() {
  initialize_Bindings(1, lean_io_mk_world());
  initialize_ExtensionAPI(1, lean_io_mk_world());
}

/* * Helpers */
int _initialise_lean_state() {
  /* printf("[lean4-godot] calling initialise_lean_state\n"); */
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
  /* printf("[lean4-godot] finished initialisation!\n"); */
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
  library_token = p_library;

  get_godot_version = (GDExtensionInterfaceGetGodotVersion)p_get_proc_address("get_godot_version");

  string_to_utf8_chars = (GDExtensionInterfaceStringToUtf8Chars)p_get_proc_address("string_to_utf8_chars");
  string_new_with_utf8_chars_and_len = (GDExtensionInterfaceStringNewWithUtf8CharsAndLen)p_get_proc_address("string_new_with_utf8_chars_and_len");
  string_new_with_utf8_chars = (GDExtensionInterfaceStringNameNewWithUtf8Chars)p_get_proc_address("string_new_with_utf8_chars");
  mem_alloc = (GDExtensionInterfaceMemAlloc)p_get_proc_address("mem_alloc");
  mem_free = (GDExtensionInterfaceMemFree)p_get_proc_address("mem_free");
  variant_get_type = (GDExtensionInterfaceVariantGetType)p_get_proc_address("variant_get_type");
  variant_get_ptr_destructor = (GDExtensionInterfaceVariantGetPtrDestructor)p_get_proc_address("variant_get_ptr_destructor");
  variant_stringify = (GDExtensionInterfaceVariantStringify)p_get_proc_address("variant_stringify");
  variant_new_copy = (GDExtensionInterfaceVariantNewCopy)p_get_proc_address("variant_new_copy");
  variant_duplicate = (GDExtensionInterfaceVariantDuplicate)p_get_proc_address("variant_duplicate");
  variant_destroy = (GDExtensionInterfaceVariantDestroy)p_get_proc_address("variant_destroy");
  get_variant_from_type_constructor = (GDExtensionInterfaceGetVariantFromTypeConstructor)p_get_proc_address("get_variant_from_type_constructor");
  get_variant_to_type_constructor = (GDExtensionInterfaceGetVariantToTypeConstructor)p_get_proc_address("get_variant_to_type_constructor");


  #include "init.h"

  // initialise lean
  if(_initialise_lean_state()) {
    printf("[lean4-godot] could not initialise lean4 state\n");
    return false;
  }
  printf("[lean4-godot] finished lean initialisation!!\n");

  r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_CORE;
  r_initialization->userdata = NULL;
  r_initialization->initialize = lean4_godot_initialize_callback;
  r_initialization->deinitialize = lean4_godot_deinitialize_callback;
  
  return true;
}
