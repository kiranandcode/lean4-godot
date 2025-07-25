import Lean
import Bindings
import LeanGodot
import ExtensionAPI.Json

open Lean
open IO

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


-- CLI Command enumeration
inductive CLICommand
| init
| declarations
| builtinTypeSizes
| builtinTypeDestructorDecls
| builtinTypeConversionDecls
| builtinTypeClassDecls
| help


-- Define the CLI arguments parser
def parseArgs : CLICommand → IO Unit
| .init         => println (GenGodotInits ++ "\n" ++ GenGodotBuiltinDestructorInits ++ "\n" ++ GenGodotBuiltinConversionFuncInits)
| .declarations => println GenGodotDeclarations
| .builtinTypeSizes => println GenGodotBuiltinSizes
| .builtinTypeDestructorDecls => println GenGodotBuiltinDestructorDecls
| .builtinTypeConversionDecls => println GenGodotBuiltinConversionFuncDecls
| .builtinTypeClassDecls => println GenGodotBuiltinClassDecls
| .help         => printHelp



-- Parse the argument into the appropriate command type
def Command.ofString? (s : String) : Option CLICommand :=
  match s with
  | "Init"         => some .init
  | "Declarations" => some .declarations
  | "BuiltinTypesSizes" => some .builtinTypeSizes
  | "BuiltinTypesDestructorDecls" => some .builtinTypeDestructorDecls
  | "BuiltinTypesConversionDecls" => some .builtinTypeConversionDecls
  | "BuiltinTypesClassDecls" => some .builtinTypeClassDecls
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
