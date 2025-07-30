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

struct GDStringName _static_utility_load_fn;

#define LEAN4_LOAD_UTILITY_FN(NAME, CSTR, HASH) \
     do { \
       string_name_new_with_latin1_chars(&_static_utility_load_fn, CSTR, true); \
       NAME = variant_get_ptr_utility_function(&_static_utility_load_fn, HASH); \
     } while (0)

struct GDStringName _static_singleton_load_name;

#define LEAN4_LOAD_SINGLETON(NAME, CSTR) \
     do { \
       string_name_new_with_latin1_chars(&_static_singleton_load_name, CSTR, true); \
       NAME = global_get_singleton(&_static_singleton_load_name); \
     } while (0)

struct GDStringName _static_name_for_getter_setter;

#define LEAN4_LOAD_GETTER(NAME, ITY, TY, CSTR) \
     do { \
       string_name_new_with_latin1_chars(&_static_name_for_getter_setter, CSTR, true); \
       NAME = (ITY)variant_get_ptr_getter(TY, &_static_name_for_getter_setter); \
     } while (0)

#define LEAN4_LOAD_SETTER(NAME, ITY, TY, CSTR) \
     do { \
       string_name_new_with_latin1_chars(&_static_name_for_getter_setter, CSTR, true); \
       NAME = (ITY)variant_get_ptr_setter(TY, &_static_name_for_getter_setter); \
     } while (0)

struct GDStringName _static_name_for_method;

#define LEAN4_LOAD_METHOD_FN(NAME, ITY, TY, CSTR, HASH) \
  do { \
    string_name_new_with_latin1_chars(&_static_name_for_method, CSTR, true); \
    NAME = (ITY) variant_get_ptr_builtin_method(TY, &_static_name_for_method, HASH); \
  } while (0)



     
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
GDExtensionInterfaceVariantGetConstantValue variant_get_constant_value = NULL;
GDExtensionInterfaceVariantGetPtrSetter variant_get_ptr_setter = NULL;
GDExtensionInterfaceVariantGetPtrGetter variant_get_ptr_getter = NULL;
GDExtensionInterfaceVariantGetPtrConstructor variant_get_ptr_constructor = NULL;
GDExtensionInterfaceVariantGetPtrBuiltinMethod variant_get_ptr_builtin_method = NULL;

GDExtensionInterfaceVariantGetPtrUtilityFunction variant_get_ptr_utility_function = NULL;
GDExtensionInterfaceGlobalGetSingleton global_get_singleton = NULL;


GDExtensionInterfaceGetVariantFromTypeConstructor get_variant_from_type_constructor = NULL;
GDExtensionInterfaceGetVariantToTypeConstructor get_variant_to_type_constructor = NULL;
GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new_with_latin1_chars = NULL;

GDExtensionInterfaceClassdbRegisterExtensionClass2 classdb_register_extension_class2 = NULL;


/* ** Lean Generated Files */
/* *** builtin type enum helpers */
#include "builtin_type_enum_helpers.h"

/* *** Destructors */
#include "builtin_type_destructor_decl.h"

/* *** Conversions */
#include "builtin_type_conversion_decl.h"

/* *** Singletons */
#include "singleton_decl.h"

/* *** Utilities */
inline static void noop_foreach(void *mod, b_lean_obj_arg fn) {}

inline static void lean_godot_variant_finalizer(void *obj) {
  if(obj == NULL) return;
  struct GDVariant *variant = (struct GDVariant *)obj;
  if(variant_destroy != NULL) { variant_destroy(variant); }
  if(mem_free != NULL) { mem_free(obj); }
}
REGISTER_LEAN_CLASS(lean_godot_Variant, lean_godot_variant_finalizer, noop_foreach)

inline static void lean_godot_Object_finalizer(void *obj) {

}
REGISTER_LEAN_CLASS(lean_godot_Object, lean_godot_Object_finalizer, noop_foreach)


/* *** Class Declarations */
#include "builtin_type_class_decl.h"

/* *** declarations? */
#include "declarations.h"

/* *** Utility Functions */
#include "utility_func_decl.h"

/* *** builtin type conversion functions  */

#include "builtin_type_conversion_bindings.h"

/* *** builtin type constant functions */

#include "builtin_type_constant_bindings.h"

/* *** builtin type member funs */

#include "builtin_type_member_funs.h"

/* *** builtin type constructors */
#include "builtin_type_constructors.h"

/* *** builtin type methods */

#include "builtin_type_methods.h"

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

/* *** String utils */
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
   LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
   
   struct GDString *gdString = lean_get_external_data(obj);
   struct GDVariant *res = (struct GDVariant *)mem_alloc(sizeof(*res));
   gd_string_to_variant(res, gdString);

   lean_object *resObj = lean_alloc_external(get_lean_godot_Variant_class(), (void *) res);
  
   return resObj;
}
/* *** String Name Utils */

GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen string_name_new_with_utf8_chars_and_len = NULL;
lean_object *lean4_string_name_new_with_utf_chars(lean_object *string) {
  LEAN4_CHECK_FP_INIT_PURE(string_name_new_with_utf8_chars_and_len);
  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
  LEAN4_CHECK_FP_INIT_PURE(mem_free);
  char const *cstr = lean_string_cstr(string);
  size_t len = lean_string_len(string);
  // we're allocing here, but mem_free will be called in the finaliser for the lean_godot_class
  struct GDStringName *gd_string = (struct GDStringName *)mem_alloc(sizeof(*gd_string));
  // create a godot string object, the destructor will be called byt he string_class finalizer
  string_name_new_with_utf8_chars_and_len(gd_string, cstr, len);
  // wrap it in a lean_object, and send it off chief
  lean_object *res = lean_alloc_external(get_lean_godot_StringName_class(), (void *) gd_string);
  return res;
}

lean_object *lean4_string_name_to_variant(lean_object *obj) {
   LEAN4_CHECK_FP_INIT_PURE(gd_stringname_to_variant);
   LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
   
   struct GDStringName *gdString = lean_get_external_data(obj);
   struct GDVariant *res = (struct GDVariant *)mem_alloc(sizeof(*res));
   gd_stringname_to_variant(res, gdString);

   lean_object *resObj = lean_alloc_external(get_lean_godot_Variant_class(), (void *) res);
  
   return resObj;
}

/* *** Variant Utils */

GDExtensionInterfaceStringNewWithUtf8Chars string_new_with_utf8_chars = NULL;
GDExtensionInterfaceVariantStringify variant_stringify = NULL;
lean_object *lean4_variant_stringify(lean_object *variant) {
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

/* *** Class utils */



/* *** Link my bindings */

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
  if(p_level == GDEXTENSION_INITIALIZATION_EDITOR) {
    #include "init_after.h"
  }
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
  string_name_new_with_utf8_chars_and_len = (GDExtensionInterfaceStringNameNewWithUtf8CharsAndLen)p_get_proc_address("string_name_new_with_utf8_chars_and_len");
  string_name_new_with_latin1_chars = (GDExtensionInterfaceStringNameNewWithLatin1Chars)p_get_proc_address("string_name_new_with_latin1_chars");
  
  mem_alloc = (GDExtensionInterfaceMemAlloc)p_get_proc_address("mem_alloc");
  mem_free = (GDExtensionInterfaceMemFree)p_get_proc_address("mem_free");

  variant_get_type = (GDExtensionInterfaceVariantGetType)p_get_proc_address("variant_get_type");
  variant_get_ptr_destructor = (GDExtensionInterfaceVariantGetPtrDestructor)p_get_proc_address("variant_get_ptr_destructor");
  variant_stringify = (GDExtensionInterfaceVariantStringify)p_get_proc_address("variant_stringify");
  variant_new_copy = (GDExtensionInterfaceVariantNewCopy)p_get_proc_address("variant_new_copy");
  variant_duplicate = (GDExtensionInterfaceVariantDuplicate)p_get_proc_address("variant_duplicate");
  variant_destroy = (GDExtensionInterfaceVariantDestroy)p_get_proc_address("variant_destroy");
  variant_get_constant_value = (GDExtensionInterfaceVariantGetConstantValue)p_get_proc_address("variant_get_constant_value");

  variant_get_ptr_setter = (GDExtensionInterfaceVariantGetPtrSetter)p_get_proc_address("variant_get_ptr_setter");
  variant_get_ptr_getter = (GDExtensionInterfaceVariantGetPtrGetter)p_get_proc_address("variant_get_ptr_getter");

  variant_get_ptr_constructor = (GDExtensionInterfaceVariantGetPtrConstructor)p_get_proc_address("variant_get_ptr_constructor");

  variant_get_ptr_builtin_method = (GDExtensionInterfaceVariantGetPtrBuiltinMethod)p_get_proc_address("variant_get_ptr_builtin_method");



  get_variant_from_type_constructor = (GDExtensionInterfaceGetVariantFromTypeConstructor)p_get_proc_address("get_variant_from_type_constructor");
  get_variant_to_type_constructor = (GDExtensionInterfaceGetVariantToTypeConstructor)p_get_proc_address("get_variant_to_type_constructor");

  variant_get_ptr_utility_function = (GDExtensionInterfaceVariantGetPtrUtilityFunction)p_get_proc_address("variant_get_ptr_utility_function");
  global_get_singleton = (GDExtensionInterfaceGlobalGetSingleton)p_get_proc_address("global_get_singleton");

  classdb_register_extension_class2 = (GDExtensionInterfaceClassdbRegisterExtensionClass2)p_get_proc_address("classdb_register_extension_class2");
  

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
