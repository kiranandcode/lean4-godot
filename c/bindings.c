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


#define LEAN_UNWRAP_STRINGNAME(DEST, LEAN_OBJ) string_name_new_with_utf8_chars_and_len(DEST, lean_string_cstr(LEAN_OBJ), lean_string_len(LEAN_OBJ))
#define LEAN_UNWRAP_STRING(DEST, LEAN_OBJ) string_new_with_utf8_chars_and_len(DEST, lean_string_cstr(LEAN_OBJ), lean_string_len(LEAN_OBJ))
     
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

GDExtensionInterfaceClassdbRegisterExtensionClass2 classdb_register_extension_class2 = NULL;
GDExtensionInterfaceClassdbRegisterExtensionClassMethod classdb_register_extension_class_method = NULL;
GDExtensionInterfaceClassdbRegisterExtensionClassProperty classdb_register_extension_class_property = NULL;
GDExtensionInterfaceClassdbConstructObject classdb_construct_object = NULL;

GDExtensionInterfaceObjectSetInstance object_set_instance = NULL;
GDExtensionInterfaceObjectSetInstanceBinding object_set_instance_binding = NULL;

GDExtensionInterfaceVariantGetPtrUtilityFunction variant_get_ptr_utility_function = NULL;
GDExtensionInterfaceGlobalGetSingleton global_get_singleton = NULL;

typedef void (*GDInt32FromVariantFunc)(int32_t *, struct GDVariant *);
typedef void (*GDInt32ToVariantFunc)(struct GDVariant *, int32_t *);
GDInt32ToVariantFunc gd_int32_to_variant_raw = NULL;
GDInt32FromVariantFunc gd_int32_from_variant_raw = NULL;

typedef void (*GDBoolFromVariantFunc)(bool *, struct GDVariant *);
typedef void (*GDBoolToVariantFunc)(struct GDVariant *, bool *);
GDBoolToVariantFunc gd_bool_to_variant_raw = NULL;
GDBoolFromVariantFunc gd_bool_from_variant_raw = NULL;


typedef void (*GDFloatFromVariantFunc)(double *, struct GDVariant *);
typedef void (*GDFloatToVariantFunc)(struct GDVariant *, double *);
GDFloatToVariantFunc gd_double_to_variant_raw = NULL;
GDFloatFromVariantFunc gd_double_from_variant_raw = NULL;


GDExtensionInterfaceGetVariantFromTypeConstructor get_variant_from_type_constructor = NULL;
GDExtensionInterfaceGetVariantToTypeConstructor get_variant_to_type_constructor = NULL;
GDExtensionInterfaceStringNameNewWithLatin1Chars string_name_new_with_latin1_chars = NULL;



/* ** Lean Generated Files */
/* *** builtin type enum helpers */
#include "builtin_type_enum_helpers.h"

/* *** Destructors */
#include "builtin_type_destructor_decl.h"

/* *** Conversions */
#include "builtin_type_conversion_decl.h"

typedef void (*GDObjectFromVariantFunc)(struct GDObject *, struct GDVariant *);
typedef void (*GDObjectToVariantFunc)(struct GDVariant *, struct GDObject *);
GDObjectToVariantFunc gd_object_to_variant = NULL;
GDObjectFromVariantFunc gd_object_from_variant = NULL;

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

inline static void lean_godot_Object_finalizer(void *obj) {}
REGISTER_LEAN_CLASS(lean_godot_Object, lean_godot_Object_finalizer, noop_foreach)


/* *** Class Declarations */
#include "builtin_type_class_decl.h"

  
/* *** declarations? */
#include "declarations.h"

/* *** Utility Functions */
#include "utility_func_decl.h"

/* *** builtin type conversion functions  */

#include "builtin_type_conversion_bindings.h"

lean_object *lean4_object_to_variant(lean_object *obj) {
  LEAN4_CHECK_FP_INIT_PURE(gd_object_to_variant);
  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);
  printf("convering obj to variant~\n");
  struct GDVariant *res = (struct GDVariant *)mem_alloc(sizeof(*res));
  struct GDObject *rawData = lean_get_external_data(obj);
  gd_object_to_variant(res, rawData);
  lean_object *resObj = lean_alloc_external(get_lean_godot_Variant_class(), (void *) res);
  return resObj;
}

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

/* lean_object *lean4_register_extension_class */
/*   ( */
/*    lean_object *class_name, */
/*    lean_object *parent_class_name, */
/*    uint8_t is_virtual, */
/*    uint8_t is_abstract, */
/*    uint8_t is_exposed, */
 
                                            
/* ) { */
/*   LEAN4_CHECK_FP_INIT(classdb_register_extension_class2); */
/*   LEAN4_CHECK_FP_INIT(string_name_new_with_latin1_chars); */
/*   LEAN4_CHECK_FP_INIT(library_token); */

/*   GDStringName class_name_str; */
/*   string_name_new_with_latin1_chars(&class_name_str, lean_string_cstr(class_name), false); */
/*   GDStringName parent_class_name_str; */
/*   string_name_new_with_latin1_chars(&parent_class_name_str, lean_string_cstr(parent_class_name), false); */

/*   GDExtensionClassCreationInfo2 class_info = { */
/*     .is_virtual = is_virtual, */
/*     .is_abstract = is_abstract, */
/*     .is_exposed = is_exposed, */
/* 	GDExtensionClassSet set_func; */
/* 	GDExtensionClassGet get_func; */
/* 	GDExtensionClassGetPropertyList get_property_list_func; */
/* 	GDExtensionClassFreePropertyList free_property_list_func; */
/* 	GDExtensionClassPropertyCanRevert property_can_revert_func; */
/* 	GDExtensionClassPropertyGetRevert property_get_revert_func; */
/* 	GDExtensionClassValidateProperty validate_property_func; */
/* 	GDExtensionClassNotification2 notification_func; */
/* 	GDExtensionClassToString to_string_func; */
/* 	GDExtensionClassReference reference_func; */
/* 	GDExtensionClassUnreference unreference_func; */
/* 	GDExtensionClassCreateInstance create_instance_func; // (Default) constructor; mandatory. If the class is not instantiable, consider making it virtual or abstract. */
/* 	GDExtensionClassFreeInstance free_instance_func; // Destructor; mandatory. */
/* 	GDExtensionClassRecreateInstance recreate_instance_func; */
/* 	// Queries a virtual function by name and returns a callback to invoke the requested virtual function. */
/* 	GDExtensionClassGetVirtual get_virtual_func; */
/* 	// Paired with `call_virtual_with_data_func`, this is an alternative to `get_virtual_func` for extensions that */
/* 	// need or benefit from extra data when calling virtual functions. */
/* 	// Returns user data that will be passed to `call_virtual_with_data_func`. */
/* 	// Returning `NULL` from this function signals to Godot that the virtual function is not overridden. */
/* 	// Data returned from this function should be managed by the extension and must be valid until the extension is deinitialized. */
/* 	// You should supply either `get_virtual_func`, or `get_virtual_call_data_func` with `call_virtual_with_data_func`. */
/* 	GDExtensionClassGetVirtualCallData get_virtual_call_data_func; */
/* 	// Used to call virtual functions when `get_virtual_call_data_func` is not null. */
/* 	GDExtensionClassCallVirtualWithData call_virtual_with_data_func; */
/* 	GDExtensionClassGetRID get_rid_func; */
/* 	void *class_userdata; // Per-class user data, later accessible in instance bindings.   */
/*   }; */

/*   classdb_register_extension_class2( */
/*       library_token, */
/*       &class_name_str, */
/*       &parent_class_name_str, */
/*       &class_info */
/*   ); */
/*   string_name_destructor(&class_name_str); */
/*   string_name_destructor(&parent_class_name_str); */

/*   return lean_io_result_mk_ok(lean_box(0)); */
/* } */

/* *** Link my bindings */

void _link_my_bindings_clang_pls() {
  initialize_Bindings(1, lean_io_mk_world());
  initialize_ExtensionAPI(1, lean_io_mk_world());
}

/* * Helpers */
/* ** Lean Godot Variant Wrap/Unwrap */
/* *** Lean Godot Variant Wrap */

lean_object *lean4_godot_wrap(GDExtensionVariantType tag, GDExtensionVariantPtr variant) {
  lean_object *res = lean_box(0);
  switch (tag) {
  GDEXTENSION_VARIANT_TYPE_NIL: break;
  GDEXTENSION_VARIANT_TYPE_BOOL:
  GDEXTENSION_VARIANT_TYPE_INT:
    res = lean_box(*(int32_t *)variant);
    break;

  GDEXTENSION_VARIANT_TYPE_FLOAT:
    res = lean_box_float(*(double *)variant);
    break;

  GDEXTENSION_VARIANT_TYPE_STRING:
    res = lean_alloc_external(get_lean_godot_String_class(), variant);
    break;
    /* math types */
  GDEXTENSION_VARIANT_TYPE_VECTOR2:
    res = lean_alloc_external(get_lean_godot_Vector2_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VECTOR2I:
    res = lean_alloc_external(get_lean_godot_Vector2i_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_RECT2:
    res = lean_alloc_external(get_lean_godot_Rect2_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_RECT2I:
    res = lean_alloc_external(get_lean_godot_Rect2i_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VECTOR3:
    res = lean_alloc_external(get_lean_godot_Vector3_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VECTOR3I:
    res = lean_alloc_external(get_lean_godot_Vector3i_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_TRANSFORM2D:
    res = lean_alloc_external(get_lean_godot_Transform2D_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VECTOR4:
    res = lean_alloc_external(get_lean_godot_Vector4_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VECTOR4I:
    res = lean_alloc_external(get_lean_godot_Vector4i_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PLANE:
    res = lean_alloc_external(get_lean_godot_Plane_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_QUATERNION:
    res = lean_alloc_external(get_lean_godot_Quaternion_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_AABB:
    res = lean_alloc_external(get_lean_godot_AABB_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_BASIS:
    res = lean_alloc_external(get_lean_godot_Basis_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_TRANSFORM3D:
    res = lean_alloc_external(get_lean_godot_Transform3D_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PROJECTION:
    res = lean_alloc_external(get_lean_godot_Projection_class(), variant);
    break;

    /* misc types */
  GDEXTENSION_VARIANT_TYPE_COLOR:
    res = lean_alloc_external(get_lean_godot_Color_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_STRING_NAME:
    res = lean_alloc_external(get_lean_godot_StringName_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_NODE_PATH:
    res = lean_alloc_external(get_lean_godot_NodePath_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_RID:
    res = lean_alloc_external(get_lean_godot_RID_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_OBJECT:
    res = lean_alloc_external(get_lean_godot_Object_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_CALLABLE:
    res = lean_alloc_external(get_lean_godot_Callable_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_SIGNAL:
    res = lean_alloc_external(get_lean_godot_Signal_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_DICTIONARY:
    res = lean_alloc_external(get_lean_godot_Dictionary_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_ARRAY:
    res = lean_alloc_external(get_lean_godot_Array_class(), variant);
    break;

    /* typed arrays */
  GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedByteArray_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedInt32Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedInt64Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedFloat32Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedFloat64Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedStringArray_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedVector2Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedVector3Array_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY:
    res = lean_alloc_external(get_lean_godot_PackedColorArray_class(), variant);
    break;
  GDEXTENSION_VARIANT_TYPE_VARIANT_MAX:
  default:
    break;
  }
  return res;
}

lean_object *lean4_godot_wrap_variant(GDExtensionVariantType tag, GDExtensionVariantPtr variant) {
  lean_object *res = lean_box(0);
  switch (tag) {
  GDEXTENSION_VARIANT_TYPE_NIL: break;
  GDEXTENSION_VARIANT_TYPE_BOOL: {
      bool out;
      gd_bool_from_variant_raw(&out, variant);
      res = lean_box(out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_INT: {
      int32_t out;
      gd_int32_from_variant_raw(&out, variant);
      res = lean_box(out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_FLOAT: {
      double out;
      gd_double_from_variant_raw(&out, variant);
      res = lean_box_float(out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_STRING: {
      struct GDString *out = (struct GDString *) mem_alloc(sizeof(*out));
      gd_string_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_String_class(), out);
      break;
    }
    /* math types */
  GDEXTENSION_VARIANT_TYPE_VECTOR2: {
      struct GDVector2 *out = (struct GDVector2 *) mem_alloc(sizeof(*out));
      gd_vector2_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector2_class(), out);
      break;
    }
  GDEXTENSION_VARIANT_TYPE_VECTOR2I: {
      struct GDVector2i *out = (struct GDVector2i *) mem_alloc(sizeof(*out)); 
      gd_vector2i_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector2i_class(), out);
      break;
    }
  GDEXTENSION_VARIANT_TYPE_RECT2: {
      struct GDRect2 *out = (struct GDRect2 *) mem_alloc(sizeof(*out));
      gd_rect2_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Rect2_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_RECT2I: {
      struct GDRect2i *out = (struct GDRect2i *) mem_alloc(sizeof(*out));
      gd_rect2i_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Rect2i_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_VECTOR3: {
      struct GDVector3 *out = (struct GDVector3 *) mem_alloc(sizeof(*out));
      gd_vector3_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector3_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_VECTOR3I: {
      struct GDVector3i *out = (struct GDVector3i *) mem_alloc(sizeof(*out));
      gd_vector3i_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector3i_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_TRANSFORM2D: {
      struct GDTransform2D *out = (struct GDTransform2D *) mem_alloc(sizeof(*out));
      gd_transform2d_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Transform2D_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_VECTOR4: {
      struct GDVector4 *out = (struct GDVector4 *) mem_alloc(sizeof(*out));
      gd_vector4_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector4_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_VECTOR4I: {
      struct GDVector4i *out = (struct GDVector4i *) mem_alloc(sizeof(*out));
      gd_vector4i_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Vector4i_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PLANE: {
      struct GDPlane *out = (struct GDPlane *) mem_alloc(sizeof(*out));
      gd_plane_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Plane_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_QUATERNION: {
      struct GDQuaternion *out = (struct GDQuaternion *) mem_alloc(sizeof(*out));
      gd_quaternion_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Quaternion_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_AABB: {
      struct GDAABB *out = (struct GDAABB *) mem_alloc(sizeof(*out));
      gd_aabb_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_AABB_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_BASIS: {
      struct GDBasis *out = (struct GDBasis *) mem_alloc(sizeof(*out));
      gd_basis_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Basis_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_TRANSFORM3D: {
      struct GDTransform3D *out = (struct GDTransform3D *) mem_alloc(sizeof(*out));
      gd_transform3d_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Transform3D_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PROJECTION: {
      struct GDProjection *out = (struct GDProjection *) mem_alloc(sizeof(*out));
      gd_projection_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Projection_class(), out);
      break;
    }


    /* misc types */
  GDEXTENSION_VARIANT_TYPE_COLOR: {
      struct GDColor *out = (struct GDColor *) mem_alloc(sizeof(*out));
      gd_color_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Color_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_STRING_NAME: {
      struct GDStringName *out = (struct GDStringName *) mem_alloc(sizeof(*out));
      gd_stringname_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_StringName_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_NODE_PATH: {
      struct GDNodePath *out = (struct GDNodePath *) mem_alloc(sizeof(*out));
      gd_nodepath_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_NodePath_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_RID: {
      struct GDRID *out = (struct GDRID *) mem_alloc(sizeof(*out));
      gd_rid_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_RID_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_OBJECT: {
      res = (lean_object *)variant;
      break;
    }

  GDEXTENSION_VARIANT_TYPE_CALLABLE: {
      struct GDCallable *out = (struct GDCallable *) mem_alloc(sizeof(*out));
      gd_callable_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Callable_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_SIGNAL: {
      struct GDSignal *out = (struct GDSignal *) mem_alloc(sizeof(*out));
      gd_signal_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Signal_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_DICTIONARY: {
      struct GDDictionary *out = (struct GDDictionary *) mem_alloc(sizeof(*out));
      gd_dictionary_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Dictionary_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_ARRAY: {
      struct GDArray *out = (struct GDArray *) mem_alloc(sizeof(*out));
      gd_array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_Array_class(), out);
      break;
    }


    /* typed arrays */
  GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY: {
      struct GDPackedByteArray *out = (struct GDPackedByteArray *) mem_alloc(sizeof(*out));
      gd_packedbytearray_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedByteArray_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY: {
      struct GDPackedInt32Array *out = (struct GDPackedInt32Array *) mem_alloc(sizeof(*out));
      gd_packedint32array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedInt32Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY: {
      struct GDPackedInt64Array *out = (struct GDPackedInt64Array *) mem_alloc(sizeof(*out));
      gd_packedint64array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedInt64Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY: {
      struct GDPackedFloat32Array *out = (struct GDPackedFloat32Array *) mem_alloc(sizeof(*out));
      gd_packedfloat32array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedFloat32Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY: {
      struct GDPackedFloat64Array *out = (struct GDPackedFloat64Array *) mem_alloc(sizeof(*out));
      gd_packedfloat64array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedFloat64Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY: {
      struct GDPackedStringArray *out = (struct GDPackedStringArray *) mem_alloc(sizeof(*out));
      gd_packedstringarray_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedStringArray_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY: {
      struct GDPackedVector2Array *out = (struct GDPackedVector2Array *) mem_alloc(sizeof(*out));
      gd_packedvector2array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedVector2Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY: {
      struct GDPackedVector3Array *out = (struct GDPackedVector3Array *) mem_alloc(sizeof(*out));
      gd_packedvector3array_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedVector3Array_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY: { 
      struct GDPackedColorArray *out = (struct GDPackedColorArray *) mem_alloc(sizeof(*out));
      gd_packedcolorarray_from_variant(out, variant);
      res = lean_alloc_external(get_lean_godot_PackedColorArray_class(), out);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_VARIANT_MAX:
  default:
    break;
  }
  return res;
}

/* *** Lean Godot Variant Unwrap */
void lean4_godot_unwrap(GDExtensionVariantType tag, lean_object *res, GDExtensionVariantPtr out) {
  switch (tag) {
  GDEXTENSION_VARIANT_TYPE_NIL: break;
  GDEXTENSION_VARIANT_TYPE_BOOL:
  GDEXTENSION_VARIANT_TYPE_INT:
    *(int32_t *)out = (int32_t)lean_unbox(res);
    break;

  GDEXTENSION_VARIANT_TYPE_FLOAT:
    *(double *)out = lean_unbox_float(res);
    break;

  GDEXTENSION_VARIANT_TYPE_STRING:
  GDEXTENSION_VARIANT_TYPE_VECTOR2:
  GDEXTENSION_VARIANT_TYPE_VECTOR2I:
  GDEXTENSION_VARIANT_TYPE_RECT2:
  GDEXTENSION_VARIANT_TYPE_RECT2I:
  GDEXTENSION_VARIANT_TYPE_VECTOR3:
  GDEXTENSION_VARIANT_TYPE_VECTOR3I:
  GDEXTENSION_VARIANT_TYPE_TRANSFORM2D:
  GDEXTENSION_VARIANT_TYPE_VECTOR4:
  GDEXTENSION_VARIANT_TYPE_VECTOR4I:
  GDEXTENSION_VARIANT_TYPE_PLANE:
  GDEXTENSION_VARIANT_TYPE_QUATERNION:
  GDEXTENSION_VARIANT_TYPE_AABB:
  GDEXTENSION_VARIANT_TYPE_BASIS:
  GDEXTENSION_VARIANT_TYPE_TRANSFORM3D:
  GDEXTENSION_VARIANT_TYPE_PROJECTION:

    /* misc types */
  GDEXTENSION_VARIANT_TYPE_COLOR:
  GDEXTENSION_VARIANT_TYPE_STRING_NAME:
  GDEXTENSION_VARIANT_TYPE_NODE_PATH:
  GDEXTENSION_VARIANT_TYPE_RID:
  GDEXTENSION_VARIANT_TYPE_OBJECT:
  GDEXTENSION_VARIANT_TYPE_CALLABLE:
  GDEXTENSION_VARIANT_TYPE_SIGNAL:
  GDEXTENSION_VARIANT_TYPE_DICTIONARY:
  GDEXTENSION_VARIANT_TYPE_ARRAY:

    /* typed arrays */
  GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY:
  GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY:
    *(void **)out = lean_get_external_data(res);
    break;
  GDEXTENSION_VARIANT_TYPE_VARIANT_MAX:
  default:
    break;
  }
}

void lean4_godot_unwrap_variant(GDExtensionVariantType tag, lean_object *res, GDExtensionVariantPtr out) {
  // obj contains the raw value, need to extract, and write into variant
  switch (tag) {
  GDEXTENSION_VARIANT_TYPE_NIL: break;
  GDEXTENSION_VARIANT_TYPE_BOOL: {
      bool outTmp = (bool)lean_unbox(res);
      gd_bool_to_variant_raw(out, &outTmp);
      break;
    }

  GDEXTENSION_VARIANT_TYPE_INT: {
      int32_t outTmp = (int32_t)lean_unbox(res);
      gd_int32_to_variant_raw(out, &outTmp);

      break;
    }


  GDEXTENSION_VARIANT_TYPE_FLOAT: {
      double outTmp = (double)lean_unbox_float(res);
      gd_double_to_variant_raw(out, &outTmp);

      break;
    }


  GDEXTENSION_VARIANT_TYPE_STRING:
    gd_string_to_variant(out, (struct GDString *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR2:
    gd_vector2_to_variant(out, (struct GDVector2 *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR2I:
    gd_vector2i_to_variant(out, (struct GDVector2i *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_RECT2:
    gd_rect2_to_variant(out, (struct GDRect2 *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_RECT2I:
    gd_rect2i_to_variant(out, (struct GDRect2i *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR3:
    gd_vector3_to_variant(out, (struct GDVector3 *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR3I:
    gd_vector3i_to_variant(out, (struct GDVector3i *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_TRANSFORM2D:
    gd_transform2d_to_variant(out, (struct GDTransform2D *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR4:
    gd_vector4_to_variant(out, (struct GDVector4 *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VECTOR4I:
    gd_vector4i_to_variant(out, (struct GDVector4i *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PLANE:
    gd_plane_to_variant(out, (struct GDPlane *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_QUATERNION:
    gd_quaternion_to_variant(out, (struct GDQuaternion *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_AABB:
    gd_aabb_to_variant(out, (struct GDAABB *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_BASIS:
    gd_basis_to_variant(out, (struct GDBasis *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_TRANSFORM3D:
    gd_transform3d_to_variant(out, (struct GDTransform3D *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PROJECTION:
    gd_projection_to_variant(out, (struct GDProjection *)lean_get_external_data(res));
    break;


    /* misc types */
  GDEXTENSION_VARIANT_TYPE_COLOR:
    gd_color_to_variant(out, (struct GDColor *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_STRING_NAME:
    gd_stringname_to_variant(out, (struct GDStringName *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_NODE_PATH:
    gd_nodepath_to_variant(out, (struct GDNodePath *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_RID:
    gd_rid_to_variant(out, (struct GDRID *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_OBJECT:
    *(void **)out = res;
    break;

  GDEXTENSION_VARIANT_TYPE_CALLABLE:
    gd_callable_to_variant(out, (struct GDCallable *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_SIGNAL:
    gd_signal_to_variant(out, (struct GDSignal *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_DICTIONARY:
    gd_dictionary_to_variant(out, (struct GDDictionary *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_ARRAY:
    gd_array_to_variant(out, (struct GDArray *)lean_get_external_data(res));
    break;


    /* typed arrays */
  GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY:
    gd_packedbytearray_to_variant(out, (struct GDPackedByteArray *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY:
    gd_packedint32array_to_variant(out, (struct GDPackedInt32Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY:
    gd_packedint64array_to_variant(out, (struct GDPackedInt64Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY:
    gd_packedfloat32array_to_variant(out, (struct GDPackedFloat32Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY:
    gd_packedfloat64array_to_variant(out, (struct GDPackedFloat64Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY:
    gd_packedstringarray_to_variant(out, (struct GDPackedStringArray *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY:
    gd_packedvector2array_to_variant(out, (struct GDPackedVector2Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY:
    gd_packedvector3array_to_variant(out, (struct GDPackedVector3Array *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY:
    gd_packedcolorarray_to_variant(out, (struct GDPackedColorArray *)lean_get_external_data(res));
    break;

  GDEXTENSION_VARIANT_TYPE_VARIANT_MAX:
  default:
    break;
  }
}


/* ** Lean Godot Function call */
/* *** Lean Godot Method Call */
void lean4_godot_method_call(
     void *method_object_raw, void *self_raw,
     const GDExtensionConstVariantPtr *p_args,
     GDExtensionInt p_argument_count,
     GDExtensionVariantPtr r_return,
     GDExtensionCallError *r_error) {
  lean_object *method_object = (lean_object *)method_object_raw;
  lean_object *self = (lean_object *)self_raw;

  lean_object *args_array = lean_ctor_get(method_object, 0);
  GDExtensionVariantType ret_ty = lean_unbox(lean_ctor_get(method_object, 1));
  lean_object *func_obj = lean_ctor_get(method_object, 2);

  size_t expected_args = lean_array_size(args_array);
  if(p_argument_count != expected_args) {
    r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
    r_error->expected = (int32_t)expected_args;
    return;
  }
  
  lean_object *lean_args[p_argument_count + 1 + 1] = {}; // 1 for self, 1 for world parameter
  lean_inc(self);
  lean_args[0] = self;
  lean_args[p_argument_count + 1] = lean_box(0);
  bool failed = false;

  for(size_t i = 0; i < p_argument_count; i++) {
    GDExtensionVariantType expt_tag = lean_unbox(lean_array_cptr(args_array)[i]);
    GDExtensionVariantType actual_tag = lean_unbox(lean_array_cptr(args_array)[i]);
      if (expt_tag != actual_tag) {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
        r_error->expected = expt_tag;
        r_error->argument = i;
        failed = true;
        break;
      }

    
    lean_args[i + 1] = lean4_godot_wrap_variant(expt_tag, (struct GDVariant *)(void *)p_args[i]);
  }
  if(failed) {
    for(size_t i = 0; i < r_error->argument; i++) {
      lean_dec(lean_args[i + 1]);
    };
    lean_dec(lean_args[0]);
    return;
  }
  
  lean_object *res = lean_apply_n(func_obj, p_argument_count + 1 + 1, lean_args);
  if(!lean_io_result_is_ok(res)) {
    r_error->error  = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
    lean_io_result_show_error(res);
    lean_dec(res);
    return;
  }

  lean_object *ok_val = lean_io_result_get_value(res);
  lean4_godot_unwrap_variant(ret_ty, ok_val, r_return);
  r_error->error = GDEXTENSION_CALL_OK;

  lean_dec(ok_val);
  lean_dec(res);
}

/* *** Lean Godot Method PtrCall */
void lean4_godot_method_ptrcall(
     void *method_object_raw, void *self_raw,
     const GDExtensionConstVariantPtr *p_args,
     GDExtensionVariantPtr r_return) {
  lean_object *method_object = (lean_object *)method_object_raw;
  lean_object *self = (lean_object *)self_raw;

  lean_object *args_array = lean_ctor_get(method_object, 0);
  GDExtensionVariantType ret_ty = lean_unbox(lean_ctor_get(method_object, 1));
  lean_object *func_obj = lean_ctor_get(method_object, 2);

  size_t p_argument_count = lean_array_size(args_array);
  
  lean_object *lean_args[p_argument_count + 1 + 1] = {}; // 1 for self, 1 for world parameter
  lean_inc(self);
  lean_args[0] = self;
  lean_args[p_argument_count + 1] = lean_box(0);

  for(size_t i = 0; i < p_argument_count; i++) {
    // based on type from function object, wrap argument into lean object for call
    // p_args[i]
    GDExtensionVariantType tag = lean_unbox(lean_array_cptr(args_array)[i]);
    lean_args[i + 1] = lean4_godot_wrap(tag, (void *)p_args[i]);
  }
  lean_object *res = lean_apply_n(func_obj, p_argument_count + 1 + 1, lean_args);
  if(!lean_io_result_is_ok(res)) {
    lean_io_result_show_error(res);
    lean_dec(res);
    return;
  }

  lean_object *ok_val = lean_io_result_get_value(res);
  lean4_godot_unwrap(ret_ty, ok_val, r_return);

  lean_dec(ok_val);
  lean_dec(res);
}

/* *** Lean Godot Bind */
lean_object *lean4_register_extension_class_method(lean_object *class_name, lean_object *class_method_object) {
  // gd_class_name
  struct GDStringName gd_class_name;
  LEAN_UNWRAP_STRINGNAME(&gd_class_name,class_name);

  GDExtensionClassMethodInfo method_info;

  // StringNamePtr
  struct GDStringName method_name;
  lean_object *method_name_obj = lean_ctor_get(class_method_object, 0);
  LEAN_UNWRAP_STRINGNAME(&method_name,method_name_obj);

  method_info.name = &method_name;
  method_info.method_userdata = lean_ctor_get(class_method_object, 1);//

  method_info.call_func = lean4_godot_method_call;
  method_info.ptrcall_func = lean4_godot_method_ptrcall;
  method_info.method_flags = lean_unbox(lean_ctor_get(class_method_object, 2)); //
  

  lean_object *return_value_info_obj = lean_ctor_get(class_method_object, 3);
  GDExtensionPropertyInfo returnValuePropertyInfo;
  struct GDStringName returnValuePropertyName;
  struct GDStringName returnValuePropertyClassName;
  struct GDString returnValuePropertyHintString;
  /* GDExtensionBool */
  method_info.has_return_value = lean_option_is_some(return_value_info_obj); //

  if(method_info.has_return_value) {
    /* GDExtensionPropertyInfo * */
    method_info.return_value_info = &returnValuePropertyInfo; //
    return_value_info_obj = lean_ctor_get(return_value_info_obj, 0);

    returnValuePropertyInfo.type = lean_unbox(lean_ctor_get(return_value_info_obj, 0));

    lean_object *return_value_name_obj = lean_ctor_get(return_value_info_obj, 1);
    returnValuePropertyInfo.name = &returnValuePropertyName;
    LEAN_UNWRAP_STRINGNAME(&returnValuePropertyName,return_value_name_obj);

    lean_object *return_value_class_name_obj = lean_ctor_get(return_value_info_obj, 2);
    returnValuePropertyInfo.class_name = &returnValuePropertyClassName;
    LEAN_UNWRAP_STRINGNAME(&returnValuePropertyClassName, return_value_class_name_obj);

    returnValuePropertyInfo.hint = lean_unbox(lean_ctor_get(return_value_info_obj, 3));

    lean_object *return_value_hint_string = lean_ctor_get(return_value_info_obj, 4);
    returnValuePropertyInfo.hint_string = &returnValuePropertyHintString;
    LEAN_UNWRAP_STRING(&returnValuePropertyHintString,return_value_hint_string);

    returnValuePropertyInfo.usage = lean_unbox(lean_ctor_get(return_value_info_obj,5));

  } else {
    /* GDExtensionPropertyInfo * */
    method_info.return_value_info = NULL; //
  }
  method_info.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE; //

  lean_object *method_arginfo_array = lean_ctor_get(class_method_object, 4);
  method_info.argument_count = lean_array_size(method_arginfo_array);

  GDExtensionPropertyInfo arginfo_array[method_info.argument_count] = {};
  struct GDStringName arginfo_name_array[method_info.argument_count] = {};
  struct GDStringName arginfo_class_name_array[method_info.argument_count] = {};
  struct GDString arginfo_hint_string_array[method_info.argument_count] = {};

  method_info.arguments_info = arginfo_array; //

  GDExtensionClassMethodArgumentMetadata argmetadata_array[method_info.argument_count] = {};
  method_info.arguments_metadata = argmetadata_array; //

  for(size_t i = 0; i < method_info.argument_count; i++) {
    lean_object *property_info = lean_array_cptr(method_arginfo_array)[i];

    arginfo_array[i].name = &arginfo_name_array[i];
    LEAN_UNWRAP_STRINGNAME(arginfo_array[i].name,lean_ctor_get(property_info, 0));

    arginfo_array[i].class_name = &arginfo_class_name_array[i];
    LEAN_UNWRAP_STRINGNAME(arginfo_array[i].class_name,lean_ctor_get(property_info, 1));

    arginfo_array[i].hint_string = &arginfo_hint_string_array[i];
    LEAN_UNWRAP_STRING(arginfo_array[i].hint_string,lean_ctor_get(property_info, 2));
    arginfo_array[i].usage = lean_unbox(lean_ctor_get(property_info, 3));

    arginfo_array[i].type = (lean_ctor_get_uint8(property_info, sizeof(void *) * 4));
    arginfo_array[i].hint = (lean_ctor_get_uint8(property_info, sizeof(void *) * 4 + 1));

    argmetadata_array[i] = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
  }

  // don't support default arguments
  method_info.default_argument_count = 0;
  method_info.default_arguments = NULL;


  classdb_register_extension_class_method(
        library_token,
        &gd_class_name,
        &method_info
  );

  // cleanup
  for(size_t i = 0; i < method_info.argument_count; i++) {
    gd_stringname_destructor(arginfo_array[i].name);
    gd_stringname_destructor(arginfo_array[i].class_name);
    gd_string_destructor(arginfo_array[i].hint_string);
  }
  if(method_info.return_value_info != NULL) {
    gd_stringname_destructor(&returnValuePropertyName);
    gd_stringname_destructor(&returnValuePropertyClassName);
    gd_string_destructor(&returnValuePropertyHintString);
  }

  gd_stringname_destructor(&gd_class_name);
  gd_stringname_destructor(&method_name);

  return lean_io_result_mk_ok(lean_box(0));
}

/* *** Register Extension Class Property */
lean_object *lean4_register_extension_class_property(lean_object *class_name, lean_object *property_info, lean_object *setter_name, lean_object *getter_name) {
  struct GDStringName gd_class_name;
  struct GDStringName gd_setter_name;
  struct GDStringName gd_getter_name;
  GDExtensionPropertyInfo propertyInfo;
  struct GDStringName propertyInfoName;
  struct GDStringName propertyInfoClassName;
  struct GDStringName propertyInfoHintString;

  LEAN_UNWRAP_STRINGNAME(&gd_class_name, class_name);
  LEAN_UNWRAP_STRINGNAME(&gd_setter_name, setter_name);
  LEAN_UNWRAP_STRINGNAME(&gd_getter_name, getter_name);

    propertyInfo.name = &propertyInfoName;
    LEAN_UNWRAP_STRINGNAME(propertyInfo.name,lean_ctor_get(property_info, 0));

    propertyInfo.class_name = &propertyInfoClassName;
    LEAN_UNWRAP_STRINGNAME(propertyInfo.class_name,lean_ctor_get(property_info, 1));

    propertyInfo.hint_string = &propertyInfoHintString;
    LEAN_UNWRAP_STRING(propertyInfo.hint_string,lean_ctor_get(property_info, 2));
    propertyInfo.usage = lean_unbox(lean_ctor_get(property_info, 3));

    propertyInfo.type = (lean_ctor_get_uint8(property_info, sizeof(void *) * 4));
    propertyInfo.hint = (lean_ctor_get_uint8(property_info, sizeof(void *) * 4 + 1));


  classdb_register_extension_class_property(
    library_token,
    &gd_class_name,
    &propertyInfo,
    &gd_setter_name,
    &gd_getter_name
  );

 gd_stringname_destructor(&gd_class_name);
 gd_stringname_destructor(&gd_setter_name);
 gd_stringname_destructor(&gd_getter_name);
 gd_stringname_destructor(propertyInfo.name);
 gd_stringname_destructor(propertyInfo.class_name);
 gd_stringname_destructor(propertyInfo.hint_string);

  return lean_io_result_mk_ok(lean_box(0));
}
/* *** Register Extension Class Helpers */
GDExtensionInstanceBindingCallbacks lean4_extension_binding_callbacks = {
  .create_callback = NULL,
  .free_callback=NULL,
  .reference_callback=NULL
};

GDExtensionObjectPtr lean4_create_instance(void *class_userdata_raw) {
  lean_object *class_userdata = class_userdata_raw;
  struct GDStringName class_name;

  LEAN_UNWRAP_STRINGNAME(&class_name, lean_ctor_get(class_userdata, 1));
  GDExtensionObjectPtr parent_object_raw = classdb_construct_object(&class_name);
  gd_stringname_destructor(&class_name);

  lean_object *parent_object = lean_alloc_external(get_lean_godot_Object_class(), parent_object_raw);
  lean_object *constructor = lean_ctor_get(class_userdata, 2);
  lean_object *res = lean_apply_2(constructor, parent_object, lean_box(0));
  lean_object *self = lean_io_result_take_value(res);

  LEAN_UNWRAP_STRINGNAME(&class_name, lean_ctor_get(class_userdata, 0));
  object_set_instance(parent_object_raw, &class_name, self);
  object_set_instance_binding(
   parent_object_raw, library_token, self, &lean4_extension_binding_callbacks
  );
  gd_stringname_destructor(&class_name);

  return parent_object_raw;
}

void lean4_free_instance(void *class_userdata_raw, GDExtensionClassInstancePtr p_instance) {
  printf("freeing instance?\n");
    if (p_instance == NULL)
    {
        return;
    }
    lean_object *class_userdata = class_userdata_raw;
    lean_object *self = p_instance;
    lean_object *destructor = lean_ctor_get(class_userdata, 3);
    lean_object *res = lean_apply_2(destructor, self, lean_box(0));
    if(!lean_io_result_is_ok(res)) {
      lean_io_result_show_error(res);
    }
    lean_dec(res);
}

/* *** Register Extension Class */
lean_object *lean4_register_extension_class(lean_object *class_info_data) {

  struct GDStringName gd_class_name;
  LEAN_UNWRAP_STRINGNAME(&gd_class_name, lean_ctor_get(class_info_data, 0));
  
  struct GDStringName gd_parent_class_name;
  LEAN_UNWRAP_STRINGNAME(&gd_parent_class_name, lean_ctor_get(class_info_data, 1));

  GDExtensionClassCreationInfo2 class_info = {
    .is_virtual = false,
    .is_abstract = false,
    .is_exposed = true,
    .set_func = NULL, .get_func = NULL,
    .get_property_list_func = NULL, .free_property_list_func = NULL,
    .property_can_revert_func = NULL, .property_get_revert_func = NULL,
    .validate_property_func = NULL,
    .notification_func = NULL,
    .to_string_func = NULL,
    .reference_func = NULL, .unreference_func = NULL,
    .create_instance_func = lean4_create_instance, .free_instance_func = lean4_free_instance,
    .recreate_instance_func = NULL,
    .get_virtual_func = NULL,
    .get_virtual_call_data_func = NULL,
    .get_rid_func = NULL,
    .class_userdata = class_info_data
  };

  classdb_register_extension_class2(
      library_token, &gd_class_name,
      &gd_parent_class_name,
      &class_info
  );


  gd_stringname_destructor(&gd_parent_class_name);
  gd_stringname_destructor(&gd_class_name);
  
  return lean_io_result_mk_ok(lean_box(0));
}




/* ** Lean state */
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

/* ** Godot->Lean init callback  */
void lean4_godot_initialize_callback(void *userdata, GDExtensionInitializationLevel p_level) {
  if(p_level == GDEXTENSION_INITIALIZATION_EDITOR) {
    #include "init_after.h"
  }
  /* printf("[lean4-godot] initialisation level %d\n", p_level); */
  lean_object *res;
  LEAN4_CALL_IO(res,lean_godot_on_initialization(p_level));
}

/* ** Godot->Lean de-init callback  */
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

  classdb_register_extension_class_method = (GDExtensionInterfaceClassdbRegisterExtensionClassMethod)p_get_proc_address("classdb_register_extension_class_method");
  classdb_register_extension_class_property = (GDExtensionInterfaceClassdbRegisterExtensionClassProperty)p_get_proc_address("classdb_register_extension_class_property");

  classdb_construct_object = (GDExtensionInterfaceClassdbConstructObject)p_get_proc_address("classdb_construct_object");
  
  gd_int32_to_variant_raw = (GDInt32ToVariantFunc)get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);
  gd_int32_from_variant_raw = (GDInt32FromVariantFunc)get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_INT);

  gd_bool_to_variant_raw = (GDBoolToVariantFunc)get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_BOOL);
  gd_bool_from_variant_raw = (GDBoolFromVariantFunc)get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_BOOL);

  gd_double_to_variant_raw = (GDFloatToVariantFunc)get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
  gd_double_from_variant_raw = (GDFloatFromVariantFunc)get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);

  gd_double_to_variant_raw = (GDFloatToVariantFunc)get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);
  gd_double_from_variant_raw = (GDFloatFromVariantFunc)get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_FLOAT);

  gd_object_to_variant = (GDObjectToVariantFunc)get_variant_from_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT);
  gd_object_from_variant = (GDObjectFromVariantFunc)get_variant_to_type_constructor(GDEXTENSION_VARIANT_TYPE_OBJECT);

  object_set_instance = (GDExtensionInterfaceObjectSetInstance)p_get_proc_address("object_set_instance");
  object_set_instance_binding = (GDExtensionInterfaceObjectSetInstanceBinding)p_get_proc_address("object_set_instance_binding");

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
