import Lean
import Bindings
import LeanGodot
import ExtensionAPI.Json

open Lean
open IO


def generateUtilityFunctionDecl (name: String) (fn: ExtensionAPI.Types.Function) : String := Id.run do
   let mut body := ""
   let (ret_ty, _) := match fn.return_type with
     | .none => ("lean_object *", true)
     | .some "int" => ("uint64_t", false)
     | .some "float" => ("double", false)
     | .some "bool" => ("uint8_t", false)
     | .some _ => ("lean_object *", true)
   let is_array := not (fn.arguments.length <= 7 && not (fn.is_vararg && fn.arguments.length == 1))
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

   body := body ++ s!"\nLEAN4_CHECK_FP_INIT_PURE(mem_alloc);"
   body := body ++ s!"\nLEAN4_CHECK_FP_INIT_PURE(mem_free);"
   body := body ++ s!"\n"

   let (local_ret_ty, ret_vl) := match fn.return_type with
      | .none => ("void *", "lean_io_result_mk_ok(lean_box(0))")
      | .some "int" => ("int ", "ret_vl")
      | .some "bool" => ("uint8_t ", "ret_vl")
      | .some "float" => ("double ", "ret_vl")
      | .some cls => ("void *", s!"lean_alloc_external(get_lean_godot_{cls}_class(), ret_vl)")

   /- return vl -/
   body := body ++ s!"\n{local_ret_ty}ret_vl;"

   /- args -/
   let mut no_args := s!"{fn.arguments.length}"

   if is_array then
      let deref_fn := match fn.arguments[0]?.map (·.type) |>.get! with
          | "int" | "bool" => panic! "unsupported"
          | "float" => "lean_ctor_obj_cptr"
          | _ => "lean_get_external_data"
      body := body ++ s!"\nsize_t no_args = lean_array_size(args_raw);"
      no_args := "no_args"
      body := body ++ s!"\nvoid **args = mem_alloc(sizeof(void *) * no_args);"
      body := body ++ "\nfor(size_t i = 0; i < no_args; i++) {"
      body := body ++ s!"\nargs[i] = {deref_fn}(lean_array_cptr(args_raw)[i]);"
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

   /- free arg -/
   if is_array then
      body := body ++ s!"\nmem_free(args);"

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
      result := result ++ s!"\ntypedef void (*GD{name}FromVariantFunc)(struct GD{name} *, struct GDVariant *);"
      result := result ++ s!"\ntypedef void (*GD{name}ToVariantFunc)(struct GDVariant *, struct GD{name} *);"
      result := result ++ s!"\nGD{name}ToVariantFunc gd_{name.toLower}_to_variant = NULL;"
      result := result ++ s!"\nGD{name}FromVariantFunc gd_{name.toLower}_from_variant = NULL;"
  wrap_c_header "builtin_type_conversion_decl" result

def GenGodotBuiltinConversionFuncInits : String := Id.run $ do
  let mut result := ""
  for (name, _) in ExtensionAPI.Json.builtin_classes do
      if name.endsWith "Nil" then continue
      let gd_extension_type := s!"GDEXTENSION_VARIANT_TYPE_{godotCNameToEnumName name}"
      result := result ++ s!"\ngd_{name.toLower}_to_variant = (GD{name}ToVariantFunc)get_variant_from_type_constructor({gd_extension_type});"
      result := result ++ s!"\ngd_{name.toLower}_from_variant = (GD{name}FromVariantFunc)get_variant_to_type_constructor({gd_extension_type});"
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
| utilityFnDecls
| builtinTypeClassDecls
| singletonDecls
| help


-- Define the CLI arguments parser
def parseArgs : CLICommand → IO Unit
| .init         => println (GenGodotInits ++ "\n" ++ GenGodotBuiltinDestructorInits ++ "\n" ++ GenGodotBuiltinConversionFuncInits ++ "\n" ++ GenUtilityFuncInits)
| .initAfterClass => println GenSingletonInits
| .declarations => println GenGodotDeclarations
| .builtinTypeSizes => println GenGodotBuiltinSizes
| .builtinTypeDestructorDecls => println GenGodotBuiltinDestructorDecls
| .builtinTypeConversionDecls => println GenGodotBuiltinConversionFuncDecls
| .builtinTypeClassDecls => println GenGodotBuiltinClassDecls
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
  | "BuiltinTypesConversionDecls" => some .builtinTypeConversionDecls
  | "BuiltinTypesClassDecls" => some .builtinTypeClassDecls
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
