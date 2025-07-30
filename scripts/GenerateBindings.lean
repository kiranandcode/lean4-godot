import Lean
import Bindings
import LeanGodot
import ExtensionAPI.Json

open Lean
open IO

def valueGodotTypes := ["int", "float", "bool"] |>.toSSet

def GodotTypeToInternal : String -> String
| "int" => "uint32_t"
| "float" => "double"
| "bool" => "uint8_t"
| name => s!"struct GD{name}"


def GodotTypeToRetTyAndValue : String -> String × Bool
| "int" => ("uint32_t ", true)
| "float" => ("double ", true)
| "bool" => ("uint8_t ", true)
| _ => ("lean_object *", false)


def generateUtilityFunctionDecl (name: String) (fn: ExtensionAPI.Types.Function) : String := Id.run do
   let mut body := ""
   let (ret_ty, _) := match fn.return_type with
     | .none => ("lean_object *", true)
     | .some "int" => ("uint64_t", false)
     | .some "float" => ("double", false)
     | .some "bool" => ("uint8_t", false)
     | .some _ => ("lean_object *", true)
   let is_array := not (fn.arguments.length <= 10 && not (fn.is_vararg && fn.arguments.length == 1))
   let arguments := if is_array then "lean_object *args_raw" else
         fn.arguments.map (fun v => match v.type with
         | "int" => s!"uint64_t {v.name}_raw"
         | "float" => s!"double {v.name}_raw"
         | "bool" => s!"uint8_t {v.name}_raw"
         | _ => s!"lean_object *{v.name}_raw"
         )
         |>.intersperse ","
         |> String.join
   let arguments := if arguments.isEmpty then "lean_object *_unused" else arguments

   body := body ++ s!"\n"

   let (local_ret_ty, ret_vl) := match fn.return_type with
      | .none => ("void *", "lean_io_result_mk_ok(lean_box(0))")
      | .some "int" => ("uint32_t ", "ret_vl")
      | .some "bool" => ("uint8_t ", "ret_vl")
      | .some "float" => ("double ", "ret_vl")
      | .some cls => ("void *", s!"lean_alloc_external(get_lean_godot_{cls}_class(), ret_vl)")

   /- return vl -/
   body := body ++ s!"\n{local_ret_ty}ret_vl;"
   let mut no_args := s!"{fn.arguments.length}"

   /- args -/
   if is_array then
      body := body ++ s!"\nsize_t no_args = lean_array_size(args_raw);" 
      body := body ++ s!"\nvoid *args[no_args];"
      no_args := "no_args"
      let vlTy := fn.arguments[0]?.map (·.type) |>.get!
      let derefExpr := "lean_array_cptr(args_raw)[i]"

      let (additional_array_stmt, updateStmt, assignStmt) := match vlTy with
         | "int" => ("int args_vl[no_args]", s!"args_vl[i] = lean_unbox({derefExpr})", "args[i] = &args_vl[i]")
         | "bool" => ("int args_vl[no_args]", s!"args_vl[i] = lean_unbox({derefExpr})", "args[i] = &args_vl[i]")
         | "float" => ("float args_vl[no_args]", s!"args_vl[i] = lean_unbox_float({derefExpr})", "args[i] = &args_vl[i]")
         | _ => ("", "", s!"args[i] = lean_get_external_data({derefExpr})")
      if not additional_array_stmt.isEmpty then
         body := body ++ s!"{additional_array_stmt}"

      body := body ++ "\nfor(size_t i = 0; i < no_args; i++) {"
      if not updateStmt.isEmpty then
        body := body ++ s!"\n{updateStmt};"
      body := body ++ s!"\n{assignStmt};"
      body := body ++ "\n}"
   else
      let mut unwrapped_arg_ptrs := #[]
      for arg in fn.arguments do
         let (uty, unwrap) := match arg.type with
         | "int" => ("uint64_t ", "")
         | "float" => ("double ", "")
         | "bool" => ("uint8_t ", "")
         | _ => ("lean_object *", "lean_get_external_data")
         body := body ++ s!"\n{uty}{arg.name} = {unwrap}({arg.name}_raw);"
         unwrapped_arg_ptrs := unwrapped_arg_ptrs.push s!"&{arg.name}"

      let unwrapped_arg_ptrs_final := unwrapped_arg_ptrs.toList.intersperse ", " |> String.join
      body := body ++ s!"\nvoid *args[] = \{{unwrapped_arg_ptrs_final}};"

   /- function call -/
   body := body ++ s!"\nutil_{name}(&ret_vl, (const GDExtensionConstTypePtr *)args, {no_args});"

   /- return -/
   body := body ++ s!"\nreturn {ret_vl};"

   s!"\n{ret_ty} lean4_utility_{name}({arguments}) \{{body}\n}\n"

partial def splitCamelCaseGodotInternal (acc: List String) (s: String) : List String := Id.run $ do
    if s.isEmpty then return acc.reverse
    if s.startsWith "3D" || s.startsWith "2D" then
        let acc := match acc with
           | [] => [s.take 2]
           | hd :: tl => (hd ++ s.take 2) :: tl
        let rest := s.drop 2
        return splitCamelCaseGodotInternal acc rest

    let firstChar := s.get! 0
    if firstChar |>.isUpper then
       let upPre := s.takeWhile Char.isUpper
       let rest := s.drop upPre.length |>.takeWhile (Char.isLower)
       let pre := upPre ++ rest
       let rest := s.drop (pre.length)
       return splitCamelCaseGodotInternal (acc.cons pre) rest
    if firstChar.isDigit then
        let num := s.takeWhile Char.isDigit
        let s := s.drop num.length
        let numSuff := s.takeWhile Char.isLower
        let s := s.drop numSuff.length
        let num := num ++ numSuff
        let acc := match acc with
          | [] => [num]
          | hd :: tl => (hd ++ num) :: tl
        return splitCamelCaseGodotInternal acc s
    return (acc.cons s).reverse

def splitCamelCaseGodot := splitCamelCaseGodotInternal []


def godotCNameToEnumName (s: String) := splitCamelCaseGodot s |>.map String.toUpper |>.intersperse "_" |> String.join
-- Define the available commands and options using `OptionParser`
def GenGodotInits : String := #GenGodotInits
def GenGodotDeclarations : String := #GenGodotDeclarations
def printHelp : IO Unit :=
  println "Usage: godotgen <command>\n\nAvailable commands:\n  Init           Generate initialization code\n  Declarations   Generate binding declarations\n  --help, -h     Show this message"

def wrap_c_header (tag s: String) :=
   let tag := tag.toUpper ++ "_H"
   s!"#ifndef {tag}\n#define {tag}\n{s}\n#endif // {tag}"

def GenGodotBuiltinSizes : String := Id.run $ do
  let mut result := ""
  for (name, sz) in ExtensionAPI.Json.builtin_class_sizes do
      result := result ++ s!"\nstruct GD{name} \{ uint8_t _buf[{sz}]; };"
  wrap_c_header "builtin_type_sizes" s!"#include <stdint.h>\n{result}"

def GenGodotBuiltinDestructorDecls : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      if cls.has_destructor then
          result := result ++ s!"\ntypedef void (*GD{name}DestructorFunc)(struct GD{name} *);"
          result := result ++ s!"\nGD{name}DestructorFunc gd_{name.toLower}_destructor = NULL;"
  wrap_c_header "builtin_type_destructor_decl" result

def GenGodotBuiltinConversionFuncDecls : String := Id.run $ do
  let mut result := ""
  for (name, _cls) in ExtensionAPI.Json.builtin_classes do
      if name.endsWith "Nil" then continue
      result := result ++ s!"\ntypedef void (*GD{name}FromVariantFunc)({GodotTypeToInternal name} *, struct GDVariant *);"
      result := result ++ s!"\ntypedef void (*GD{name}ToVariantFunc)(struct GDVariant *, {GodotTypeToInternal name} *);"
      result := result ++ s!"\nGD{name}ToVariantFunc gd_{name.toLower}_to_variant = NULL;"
      result := result ++ s!"\nGD{name}FromVariantFunc gd_{name.toLower}_from_variant = NULL;"
      for (member, ty) in _cls.members do
         -- typedef void (*GDExtensionPtrGetter)(GDExtensionConstTypePtr p_base, GDExtensionTypePtr r_value);
         result := result ++ s!"\ntypedef void (*GD{name}Getter{member})({GodotTypeToInternal name} *, {GodotTypeToInternal ty} *);"
         result := result ++ s!"\nGD{name}Getter{member} gd_{name.toLower}_{member}_getter = NULL;"

         -- typedef void (*GDExtensionPtrSetter)(GDExtensionTypePtr p_base, GDExtensionConstTypePtr p_value);
         result := result ++ s!"\ntypedef void (*GD{name}Setter{member})({GodotTypeToInternal name} *, {GodotTypeToInternal ty} *);"
         result := result ++ s!"\nGD{name}Setter{member} gd_{name.toLower}_{member}_setter = NULL;"

  wrap_c_header "builtin_type_conversion_decl" result

def GenGodotBuiltinConversionFuncInits : String := Id.run $ do
  let mut result := ""
  for (name, _cls) in ExtensionAPI.Json.builtin_classes do
      if name.endsWith "Nil" then continue
      let gd_extension_type := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName name}"
      result := result ++ s!"\ngd_{name.toLower}_to_variant = (GD{name}ToVariantFunc)get_variant_from_type_constructor({gd_extension_type});"
      result := result ++ s!"\ngd_{name.toLower}_from_variant = (GD{name}FromVariantFunc)get_variant_to_type_constructor({gd_extension_type});"
      for (member, _ty) in _cls.members do
         result := result ++ s!"\nLEAN4_LOAD_GETTER(gd_{name.toLower}_{member}_getter, GD{name}Getter{member}, {gd_extension_type}, \"{member}\");"
         result := result ++ s!"\nLEAN4_LOAD_SETTER(gd_{name.toLower}_{member}_setter, GD{name}Setter{member}, {gd_extension_type}, \"{member}\");"
  result

def GenGodotBuiltinConversionFuncBindings : String := Id.run $ do
  let mut result := ""
  for (name, _) in ExtensionAPI.Json.builtin_classes do
      if name.endsWith "Nil" then continue
      let (ret_ty, is_value) := GodotTypeToRetTyAndValue name

      result := result ++ s!"\nlean_object *lean4_{name}_to_variant({ret_ty}obj) \{"
      result := result ++ s!"\n  LEAN4_CHECK_FP_INIT_PURE(gd_{name.toLower}_to_variant);"
      result := result ++ s!"\n  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);"

      result := result ++ s!"\n  struct GDVariant *res = (struct GDVariant *)mem_alloc(sizeof(*res));"

      if is_value then
          result := result ++ s!"\n  {ret_ty}rawData = obj;"
          result := result ++ s!"\n  gd_{name.toLower}_to_variant(res, &rawData);"
      else
          result := result ++ s!"\n  struct GD{name} *rawData = lean_get_external_data(obj);"      
          result := result ++ s!"\n  gd_{name.toLower}_to_variant(res, rawData);"

      result := result ++ s!"\n  lean_object *resObj = lean_alloc_external(get_lean_godot_Variant_class(), (void *) res);"
      result := result ++ s!"\n  return resObj;"
      result := result ++ s!"\n}"
  result

def GenGodotBuiltinConstantBindings : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      for (const_name, cnst) in cls.constants do
         let (_retTy, isValue) := GodotTypeToRetTyAndValue cnst.type
         let variant_ty := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName cnst.type}"
         result := result ++ s!"\nlean_object *lean4_{name}_const_{const_name}(lean_object *obj) \{"
         result := result ++ s!"\n  LEAN4_CHECK_FP_INIT_PURE(variant_get_constant_value);"
         result := result ++ s!"\n  LEAN4_CHECK_FP_INIT_PURE(gd_{cnst.type.toLower}_from_variant);"
         result := result ++ s!"\n  LEAN4_CHECK_FP_INIT_PURE(mem_alloc);"
         result := result ++ s!"\n  struct GDStringName const_name;"
         result := result ++ s!"\n  string_name_new_with_latin1_chars(&const_name, \"{const_name}\", true);"
         result := result ++ s!"\n  struct GDVariant tmpRes;"
         result := result ++ s!"\n  variant_get_constant_value({variant_ty}, &const_name, &tmpRes);"
         if isValue then
            result := result ++ s!"\n  {GodotTypeToInternal cnst.type} res;"
            result := result ++ s!"\n  gd_{cnst.type.toLower}_from_variant(&res, &tmpRes);"
            result := result ++ s!"\n  return lean_io_result_mk_ok(lean_box{if cnst.type == "float" then "_float" else ""}(res));"
         else
            result := result ++ s!"\n  struct GD{cnst.type} *res = (struct GD{cnst.type} *)mem_alloc(sizeof(*res));"
            result := result ++ s!"\n  gd_{cnst.type.toLower}_from_variant(res, &tmpRes);"
            result := result ++ s!"\n  lean_object *resObj = lean_alloc_external(get_lean_godot_{cnst.type}_class(), (void *) res);"
            result := result ++ s!"\n  return lean_io_result_mk_ok(resObj);"
         result := result ++ s!"\n}"
  result

def GenGodotBuiltinMemberFuns : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      for (member_name, member_ty) in cls.members do
         let (retTy, isValue) := GodotTypeToRetTyAndValue member_ty
         result := result ++ s!"\nlean_object *lean4_{name}_get_{member_name}(lean_object *obj) \{"
         result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(mem_alloc);"
         result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(gd_{name.toLower}_{member_name}_getter);"
         result := result ++ s!"\n  struct GD{name} *rawObj = lean_get_external_data(obj);"
         if isValue then
            result := result ++ s!"\n  {GodotTypeToInternal member_ty} tmpRet;"
            result := result ++ s!"\n  gd_{name.toLower}_{member_name}_getter(rawObj, &tmpRet);"
            result := result ++ s!"\n  return lean_io_result_mk_ok(lean_box{if member_ty == "float" then "_float" else ""}(tmpRet));"
         else
            result := result ++ s!"\n  {GodotTypeToInternal member_ty} *tmpRet = ({GodotTypeToInternal member_ty} *)mem_alloc(sizeof(*tmpRet));"
            result := result ++ s!"\n  lean_object *res = lean_alloc_external(get_lean_godot_{member_ty}_class(), (void *)tmpRet);"
            result := result ++ s!"\n  return lean_io_result_mk_ok((res));"
         result := result ++ s!"\n}"

         result := result ++ s!"\nlean_object *lean4_{name}_set_{member_name}(lean_object *obj, {retTy} vl) \{"
         -- first argument is ptr to object, snd argument is ptr to value to be placed into object
         result := result ++ s!"\n  struct GD{name} *rawObj = lean_get_external_data(obj);"
         if isValue then
            result := result ++ s!"\n  {retTy} *rawVl = &vl;"
         else
            result := result ++ s!"\n  {GodotTypeToInternal member_ty} *rawVl = lean_get_external_data(vl);"
         result := result ++ s!"\n  gd_{name.toLower}_{member_name}_setter(rawObj, rawVl);"
         result := result ++ s!"\n return lean_io_result_mk_ok(lean_box(0));"
         result := result ++ s!"\n}"
  result

def isSequential : List Int -> Bool
| [] => true
| ls => Id.run $ do
  let ls := ls.mergeSort
  let mut lastElt := ls.head!
  for elt in ls.tail do
    if elt != lastElt + 1 then
      return false
    lastElt := elt
  true

def getEnumLeanReprType (sz: Nat) :=
   if sz >= 2 ^ 32
   then panic! "enum with too many constructors aaaaah"
   else if sz >= 2 ^ 16
   then "uint32_t"
   else if sz >= 2 ^ 8
   then "uint16_t"
   else "uint8_t"

def GenGodotBuiltinEnumHelpers : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      for (enum_name, enum) in cls.enums do
      -- if sequential and positive, do nothing!
         if enum.values.values.all (· >= 0) && isSequential enum.values.values
         then
            result := result ++ s!"\n#define lean4_enum_lean_to_godot_{name}_{enum_name}(x) x"
            result := result ++ s!"\n#define lean4_enum_godot_to_lean_{name}_{enum_name}(x) x"
         else
            let enumVls := enum.values.toList.mergeSort (le := fun (_, a) (_, b) => a <= b) |>.zipIdx
            -- define mapping
            let reprType := getEnumLeanReprType enum.values.size
            result := result ++ s!"\nint32_t lean4_enum_lean_to_godot_{name}_{enum_name}({reprType} vl) \{"
            result := result ++ s!"\n  switch(vl) \{"
            for ((_, godotVl), constructorId) in enumVls do
               result := result ++ s!"\n    case {constructorId}: return {godotVl};"
            result := result ++ s!"\n    default: return -1;"
            result := result ++ s!"\n  }"
            result := result ++ s!"\n}"

            result := result ++ s!"\n{reprType} lean4_enum_godot_to_lean_{name}_{enum_name}(int32_t vl) \{"
            result := result ++ s!"\n  switch(vl) \{"
            for ((_, godotVl), constructorId) in enumVls do
               result := result ++ s!"\n    case {godotVl}: return {constructorId};"
            result := result ++ s!"\n    default: return -1;"
            result := result ++ s!"\n  }"
            result := result ++ s!"\n}\n"
  result


def GenGodotBuiltinConstructorsInit : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
    let (_variantTy, variantIsVl) := GodotTypeToRetTyAndValue name
    if variantIsVl then continue
    for cstr in cls.constructors do
-- typedef GDExtensionPtrConstructor (*GDExtensionInterfaceVariantGetPtrConstructor)(GDExtensionVariantType p_type, int32_t p_constructor);
      let gd_extension_type := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName name}"
      result := result ++ s!"\ngodot_{name}_constructor_{cstr.index} = (GD{name}Constructor{cstr.index})variant_get_ptr_constructor({gd_extension_type}, {cstr.index});"
  result
       
-- typedef void (*GDExtensionPtrBuiltInMethod)(GDExtensionTypePtr p_base, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_return, int p_argument_count);


def GenGodotBuiltinConstructors : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
    let (_variantTy, variantIsVl) := GodotTypeToRetTyAndValue name
    if variantIsVl then continue
    let variantCType := GodotTypeToInternal name
    for cstr in cls.constructors do
      let leanArguments := cstr.arguments.map (fun arg =>
           let (retTy, _) := GodotTypeToRetTyAndValue arg.type
           s!"{retTy}{arg.name}_raw"
        ) |>.intersperse ", " |> String.join
      let leanArguments := if cstr.arguments.isEmpty then "lean_object *_unit" else leanArguments
-- typedef void (*GDExtensionPtrConstructor)(GDExtensionUninitializedTypePtr p_base, const GDExtensionConstTypePtr *p_args);
      result := result ++ s!"\ntypedef void (*GD{name}Constructor{cstr.index})({variantCType}*, void **args);"
      result := result ++ s!"\nGD{name}Constructor{cstr.index} godot_{name}_constructor_{cstr.index} = NULL;"

      result := result ++ s!"\nlean_object *lean4_{name}_constructor_{cstr.index}({leanArguments}) \{"
      result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(mem_alloc);"
      result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(godot_{name}_constructor_{cstr.index});"

      result := result ++ s!"\n  {variantCType} *tmpRes = ({variantCType} *)mem_alloc(sizeof(*tmpRes));"
      let mut cstrArgsMut := #[]
      for arg in cstr.arguments do
         let getTyUnwrapper := if valueGodotTypes.contains arg.type then "&" else "lean_get_external_data"
         result := result ++ s!"\n  {GodotTypeToInternal arg.type} *{arg.name} = {getTyUnwrapper}({arg.name}_raw);"
         cstrArgsMut := cstrArgsMut.push s!"{arg.name}"

      let cstrArgs := cstrArgsMut.toList.intersperse ", " |> String.join
      result := result ++ s!"\n  void *args[] = \{{cstrArgs}};"

      result := result ++ s!"\n  godot_{name}_constructor_{cstr.index}(tmpRes, args);"

      result := result ++ s!"\n  lean_object *res = lean_alloc_external(get_lean_godot_{name}_class(), (void *)tmpRes);"
      result := result ++ s!"\n  return lean_io_result_mk_ok(res);"
      result := result ++ s!"\n}"

  result
       
def GenGodotBuiltinMethodInits : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
    let (_variantTy, variantIsVl) := GodotTypeToRetTyAndValue name
    if variantIsVl then continue
    let gd_extension_type := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName name}"
    for (method_name, method) in cls.methods do
      result := result ++ s!"\nLEAN4_LOAD_METHOD_FN(godot_{name}_{method_name}, GD{name}{method_name}Fn, {gd_extension_type}, \"{method_name}\", {method.hash});"
  result

def GenGodotBuiltinMethods : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
    let (_variantTy, variantIsVl) := GodotTypeToRetTyAndValue name
    if variantIsVl then continue
    let _variantCType := GodotTypeToInternal name
    for (method_name, method) in cls.methods do
-- typedef void (*GDExtensionPtrBuiltInMethod)(GDExtensionTypePtr p_base, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_return, int p_argument_count);
       let declRetTy := match method.return_type with
          | .none => "void *"
          | .some ty => s!"{GodotTypeToInternal ty} *"
       result := result ++ s!"\ntypedef void (*GD{name}{method_name}Fn)(struct GD{name} *, void **, {declRetTy}, int);"
       result := result ++ s!"\nGD{name}{method_name}Fn godot_{name}_{method_name} = NULL;"

       let arguments := (if method.is_static then [] else [ExtensionAPI.Types.FunctionArgument.mk "self" name]) ++ method.arguments
       let no_arguments := arguments.length + (if method.is_vararg then 1 else 0)
       let is_array := if no_arguments > 8 then true else false

       let mut cArgumentsMut := #[]
       if is_array then
          cArgumentsMut := cArgumentsMut.push s!"lean_object *args_raw"
       else
          for argument in arguments do
             let (argRetTy, _) := GodotTypeToRetTyAndValue argument.type
             cArgumentsMut := cArgumentsMut.push s!"{argRetTy}{argument.name}_raw"
          if method.is_vararg then
             cArgumentsMut := cArgumentsMut.push s!"lean_object *varargs"

       let cArguments := cArgumentsMut.toList.intersperse ", " |> String.join
       result := result ++ s!"\n"
       result := result ++ s!"\nlean_object *lean4_{name}_method_{method_name}({cArguments}) \{"
       result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(godot_{name}_{method_name});"
       result := result ++ s!"\n  LEAN4_CHECK_FP_INIT(mem_alloc);"

-- extract self_raw (if is_static then null)
       result :=
          let selfRawExpr := if is_array then "lean_array_cptr(args_raw)[0]" else "self_raw"
          let extractExpr := if method.is_static then "NULL" else s!"lean_get_external_data({selfRawExpr})"
          result ++ s!"\n  {_variantCType} *receiver = {extractExpr};"

-- calculate no arguments
       result := result ++ s!"\n  int no_arguments = {method.arguments.length};"
       -- if is_vararg then need to add on dynamic no arguments
       if method.is_vararg then
           let varargsExpr := if is_array then s!"lean_array_cptr(args_raw)[{arguments.length}]" else "varargs"
           result := result ++ s!"\n  no_arguments += lean_array_size({varargsExpr});"

       let no_num_args := method.arguments.countP (fun v => match v.type with | "int" => is_array | "bool" => is_array | _ => false)
       let no_float_args := method.arguments.countP (fun v => match v.type with | "float" => is_array | _ => false)
       if no_num_args > 0 then
         result := result ++ s!"\n  int local_int_vls[{no_num_args}] = \{0};"
         result := result ++ s!"\n  int local_int_vls_pos = 0;"
       if no_float_args > 0 then
         result := result ++ s!"\n  double local_float_vls[{no_float_args}] = \{0.0};"
         result := result ++ s!"\n  int local_float_vls_pos = 0;"

-- construct args
       result := result ++ s!"\n  void *args[no_arguments];"
       for (arg, index) in method.arguments.zipIdx do
          let args_raw_index := if method.is_static then index else index + 1
          let (eltExpr, isBoxed) := if is_array then (s!"lean_array_cptr(args_raw)[{args_raw_index}]", true) else (s!"{arg.name}_raw", false)
          let (argExpr, updateStmt, updateAfterStmt) :=
             match arg.type with
             | "int" | "bool" =>
                if isBoxed
                then ("&local_int_vls[local_int_vls_pos]", s!"local_int_vls[local_int_vls_pos] = lean_unbox({eltExpr})", "local_int_vls_pos++")
                else (s!"&{eltExpr}", "", "")
             | "float" =>
                 if isBoxed
                 then ("&local_float_vls[local_float_vls_pos]", s!"local_float_vls[local_float_vls_pos] = lean_unbox_float({eltExpr})", "local_float_vls_pos++")
                 else (s!"&{eltExpr}", "", "")
             | _ => (s!"lean_get_external_data({eltExpr})", "", "")

          if not updateStmt.isEmpty then result := result ++ s!"\n  {updateStmt};"
          result := result ++ s!"\n  args[{index}] = (void *){argExpr};"
          if not updateAfterStmt.isEmpty then result := result ++ s!"\n  {updateAfterStmt};"
       if method.is_vararg then
           let varargsExpr := if is_array then s!"lean_array_cptr(args_raw)[{arguments.length}]" else "varargs"
           result := result ++ s!"\n  lean_object *vararg_ptr = {varargsExpr};"
           result := result ++ s!"\n  size_t vararg_sz = lean_array_size(vararg_ptr);"
           result := result ++ s!"\n  for(size_t i = 0; i < vararg_sz; i++) \{"
           result := result ++ s!"\n    args[{method.arguments.length} + i] = lean_get_external_data(lean_array_cptr(vararg_ptr)[i]);"
           result := result ++ s!"\n  }"

--   if vararg, or is_array, work out length of args and alloc
--   otherwise static alloc array

-- alloc retvl
       let (stmt, retExpr, boxExpr) := match method.return_type with
          | .none => ("void *retVl = NULL", "retVl", "lean_box(0)")
          | .some ty =>
             if valueGodotTypes.contains ty
             then (s!"{GodotTypeToInternal ty} retVl", "&retVl", if ty == "float" then "lean_box_float(retVl)" else "lean_box(retVl)")
             else (s!"{GodotTypeToInternal ty} *retVl = mem_alloc(sizeof(*retVl))", "retVl", s!"lean_alloc_external(get_lean_godot_{ty}_class(), (void *)retVl);")

       result := result ++ s!"\n  {stmt};"


-- call method
       result := result ++ s!"\n  godot_{name}_{method_name}(receiver, args, {retExpr}, no_arguments);"

       result := result ++ s!"\n lean_object *rawResult = {boxExpr};"
       result := result ++ s!"\n  return lean_io_result_mk_ok(rawResult);"
       result := result ++ s!"\n}\n"

  result
       



def GenGodotBuiltinClassDecls : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      let ty_name := s!"struct GD{name}"
      let finalizer_name := s!"lean_godot_{name}_finalizer"
      if cls.has_destructor then
          let destructor_name := s!"gd_{name.toLower}_destructor"
          result := result ++ s!"\nvoid {finalizer_name}(void *obj) \{ {ty_name} *data = obj; if({destructor_name} != NULL) {destructor_name}(data); if(mem_free != NULL) mem_free(data);}"
       else
          result := result ++ s!"\nvoid {finalizer_name}(void *_obj) \{}"
       result := result ++ s!"\nREGISTER_LEAN_CLASS(lean_godot_{name}, {finalizer_name}, noop_foreach)"

  wrap_c_header "builtin_type_class_decl" result

def GenGodotBuiltinDestructorInits : String := Id.run $ do
  let mut result := ""
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
      if cls.has_destructor then
          let gd_extension_type := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName name}"
          result := result ++ s!"\ngd_{name.toLower}_destructor = (GD{name}DestructorFunc)variant_get_ptr_destructor({gd_extension_type});"
  result

def GenUtilityFuncDecls : String := Id.run $ do
   let mut result := ""
   for (name,fn) in ExtensionAPI.Json.utility_functions do
      result := result ++ s!"\nGDExtensionPtrUtilityFunction util_{name} = NULL;"
      result := result ++ "\n" ++ generateUtilityFunctionDecl name fn
   wrap_c_header "utility_func_decl" result

def GenUtilityFuncInits : String := Id.run $ do
   let mut result := ""
   for (name,fn) in ExtensionAPI.Json.utility_functions do
      result := result ++ s!"\nLEAN4_LOAD_UTILITY_FN(util_{name}, \"{name}\", {fn.hash});"
   result

def invalidSingleton (name: String) : Bool :=
   name.endsWith "Server" || name.endsWith "Server2D" || name.endsWith "Server3D" || name.endsWith "Bridge" || name.endsWith "ClassWrapper"

def GenSingletonInits : String := Id.run $ do
   let mut result := ""
   for (name,api_name) in ExtensionAPI.Json.singletons do
      if invalidSingleton name then
         continue
      result := result ++ s!"\nLEAN4_LOAD_SINGLETON(singleton_{name}, \"{api_name}\");"
   result

def GenSingletonDecls : String := Id.run $ do
   let mut result := ""
   for (name,_) in ExtensionAPI.Json.singletons do
      if invalidSingleton name then
         continue
      result := result ++ s!"\nGDExtensionObjectPtr singleton_{name} = NULL;"
   wrap_c_header "singleton_decl" result


-- CLI Command enumeration
inductive CLICommand
| init
| initAfterClass
| declarations
| builtinTypeSizes
| builtinTypeDestructorDecls
| builtinTypeConversionDecls
| builtinTypeConversionBindings
| builtinTypeConstantBindings
| builtinTypeConstructors
| builtinTypeMemberFuns
| builtinTypeEnums
| builtinTypeMethods
| utilityFnDecls
| builtinTypeClassDecls
| singletonDecls
| help


-- Define the CLI arguments parser
def parseArgs : CLICommand → IO Unit
| .init         =>
   println (
      [GenGodotInits, GenGodotBuiltinDestructorInits, GenGodotBuiltinConversionFuncInits, GenUtilityFuncInits, GenGodotBuiltinConstructorsInit, GenGodotBuiltinMethodInits]
      |>.intersperse "\n"
      |> String.join)
| .initAfterClass => println GenSingletonInits
| .declarations => println GenGodotDeclarations
| .builtinTypeSizes => println GenGodotBuiltinSizes
| .builtinTypeDestructorDecls => println GenGodotBuiltinDestructorDecls
| .builtinTypeConversionBindings => println GenGodotBuiltinConversionFuncBindings
| .builtinTypeConversionDecls => println GenGodotBuiltinConversionFuncDecls
| .builtinTypeClassDecls => println GenGodotBuiltinClassDecls
| .builtinTypeConstantBindings => println GenGodotBuiltinConstantBindings
| .builtinTypeMemberFuns => println GenGodotBuiltinMemberFuns
| .builtinTypeEnums => println GenGodotBuiltinEnumHelpers
| .builtinTypeConstructors => println GenGodotBuiltinConstructors
| .builtinTypeMethods => println GenGodotBuiltinMethods
| .utilityFnDecls => println GenUtilityFuncDecls
| .singletonDecls => println GenSingletonDecls
| .help         => printHelp



-- Parse the argument into the appropriate command type
def Command.ofString? (s : String) : Option CLICommand :=
  match s with
  | "Init"         => some .init
  | "InitAfterClass" => some .initAfterClass
  | "Declarations" => some .declarations
  | "BuiltinTypesSizes" => some .builtinTypeSizes
  | "BuiltinTypesDestructorDecls" => some .builtinTypeDestructorDecls
  | "BuiltinTypeConstantBindings" => some .builtinTypeConstantBindings
  | "BuiltinTypesConversionDecls" => some .builtinTypeConversionDecls
  | "BuiltinTypesClassDecls" => some .builtinTypeClassDecls
  | "BuiltinTypeClassBindings" => some .builtinTypeConversionBindings
  | "BuiltinTypeEnumHelpers" => some .builtinTypeEnums
  | "BuiltinTypeMemberFuns" => some .builtinTypeMemberFuns
  | "BuiltinTypeMethodFuns" => some .builtinTypeMethods
  | "BuiltinTypeConstructorFuns" => some .builtinTypeConstructors
  | "UtilityFuncDecls" => some .utilityFnDecls
  | "SingletonDecls" => some .singletonDecls
  | "--help" | "-h"=> some .help
  | _              => none

-- Main CLI entry point
def main (args : List String) : IO Unit := do
  match args with
  | [] =>
    eprintln "Error: no command provided.\n"
    printHelp
  | [arg] =>
    match Command.ofString? arg with
    | some cmd => parseArgs cmd
    | none     =>
      eprintln s!"Error: unknown command '{arg}'.\n"
      printHelp
  | _ =>
    eprintln "Error: too many arguments.\n"
    printHelp
