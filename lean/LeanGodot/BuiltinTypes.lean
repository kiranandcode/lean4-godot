import Lean
import Bindings
import ExtensionAPI.Json
import LeanGodot.Variant


open Lean Meta Elab
local syntax "#declare_builtin_types" : command

def godot_type_to_internal_ty: String -> String
| "int" => "Int32"
| "float" => "Float"
| "bool" => "Bool"
| s => s

abbrev OArray := Array
namespace Godot.BuiltinTypes

def skippedBuiltinTypes: SSet String := ["String", "int", "float", "bool", "Nil"] |>.toSSet

elab_rules : command
| `(command| #declare_builtin_types) => do
  for (name, _fn) in ExtensionAPI.Json.builtin_classes do
      if skippedBuiltinTypes.contains name then continue
      let nameStx := mkIdent (Name.str .anonymous name)
      let toVariantStx := mkIdent ((Name.str .anonymous name).str "toVariant")
      let toStringStx := mkIdent ((Name.str .anonymous name).str "toString")

      let toVariantExternal := (s!"lean4_{name}_to_variant")
      let toVariantExternalStx := Syntax.mkStrLit toVariantExternal
      Command.elabCommand (<- `(command| opaque $nameStx : Type))
      Command.elabCommand (<- `(command| godot_inhabited_type $nameStx))
      Command.elabCommand (<- `(command| @[extern $toVariantExternalStx:str] opaque $toVariantStx:ident : (@& $nameStx) -> Godot.Variant))
      Command.elabCommand (<- `(command| def $toStringStx (v: $nameStx) := v.toVariant.toString))
      Command.elabCommand (<- `(command| instance : ToString $nameStx where toString := $toStringStx))

   -- do the following on a separate loop to avoid like missing refs
   -- TODO: enums
   for (name, cls) in ExtensionAPI.Json.builtin_classes do
     for (enum_name, enum_vl) in cls.enums do
        let enumVls := enum_vl.values.toList.mergeSort (le := fun (_, a) (_, b) => a <= b)
        let nameStx := mkIdent $ Name.anonymous |>.str name |>.str enum_name
        let fieldsStx <- enumVls
           |>.map (fun (name, _) => mkIdent (Name.str .anonymous name))
           |>.mapM (fun name => open Lean.Parser.Command in `(ctor| | $name:ident))
        let fieldsStx := TSyntaxArray.mk fieldsStx.toArray
        Command.elabCommand (<- `(command| inductive $nameStx where $fieldsStx*))

   -- TODO: methods
   for (name, cls) in ExtensionAPI.Json.builtin_classes do
     if skippedBuiltinTypes.contains name then continue
     for (method_name, method) in cls.methods do
       let nameStx := mkIdent $ Name.anonymous |>.str name |>.str method_name

       let retTy <-
          method.return_type
          |>.map (fun v => mkIdent $ Name.anonymous |>.str (godot_type_to_internal_ty v))
          |>.map (fun v => `(term| IO $v:ident))
          |>.getD (`(term| IO Unit))
-- typedef void (*GDExtensionPtrBuiltInMethod)(GDExtensionTypePtr p_base, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_return, int p_argument_count);
       let arguments :=
         (if method.is_static then [] else [ExtensionAPI.Types.FunctionArgument.mk "self" name]) ++ method.arguments
       let retTy <- if method.is_vararg then `(term| (@& OArray (@& Variant)) -> $retTy) else pure retTy
       let tyStx <-
             arguments.foldrM (init := retTy) (fun arg retTy => do
                 let ty := mkIdent $ Name.anonymous |>.str (godot_type_to_internal_ty arg.type)
                 `(term| (@& $ty) -> $retTy)
               )
       let externStx := Syntax.mkStrLit s!"lean4_{name}_method_{method_name}"
       Command.elabCommand (<- `(command| @[extern $externStx:str] opaque $nameStx:ident : $tyStx:term))

   -- TODO: properties
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
     for (prop, ty) in cls.members do
       let getterStx := mkIdent <| (Name.str .anonymous name).str s!"{prop}"
       let setterStx := mkIdent <| (Name.str .anonymous name).str s!"set_{prop}"
       let baseStx := mkIdent <| Name.str .anonymous name
       let retTyStx := mkIdent (Name.str .anonymous (godot_type_to_internal_ty ty))
       let getterExt := s!"lean4_{name}_get_{prop}"
       let getterExtStx := Syntax.mkStrLit getterExt
       let setterExt := s!"lean4_{name}_set_{prop}"
       let setterExtStx := Syntax.mkStrLit setterExt
       Command.elabCommand (<- `(command| @[extern $getterExtStx:str] opaque $getterStx:ident : (@& $baseStx) -> IO $retTyStx))
       Command.elabCommand (<- `(command| @[extern $setterExtStx:str] opaque $setterStx:ident : (@& $baseStx) -> (@& $retTyStx) -> IO Unit))

   -- TODO: constructors
   for (name, cls) in ExtensionAPI.Json.builtin_classes do
     if skippedBuiltinTypes.contains name then continue
     for cstr in cls.constructors do
       let nameStx := mkIdent $ Name.anonymous |>.str name |>.str ("mk" ++ if cstr.index == 0 && (name != "StringName") then "" else s!"{cstr.index}")
       let tyStx := mkIdent $ Name.anonymous |>.str name
       let retTy <- `(term| IO $tyStx:ident)
       let ty <- if cstr.arguments.isEmpty then `(term| Unit -> $retTy)
         else cstr.arguments.foldrM (init := retTy) (fun arg retTy => do
           let ty := mkIdent $ Name.anonymous |>.str (godot_type_to_internal_ty arg.type)
           `(term| (@& $ty) -> $retTy)
         )
       let extStx := Syntax.mkStrLit s!"lean4_{name}_constructor_{cstr.index}"
       Command.elabCommand (<- `(command| @[extern $extStx:str] opaque $nameStx:ident : $ty:term))

   -- TODO: constants
  for (name, cls) in ExtensionAPI.Json.builtin_classes do
     for (const_name, const) in cls.constants do
       let nameStx := mkIdent <| (Name.str .anonymous name).str const_name
       let retTyStx := mkIdent (Name.str .anonymous (godot_type_to_internal_ty const.type))
       let external := s!"lean4_{name}_const_{const_name}"
       let externalStx := Syntax.mkStrLit external
       Command.elabCommand (<- `(command| @[extern $externalStx:str] opaque $nameStx:ident : Unit -> IO $retTyStx))
       pure ()

end Godot.BuiltinTypes

namespace Godot
#declare_builtin_types
end Godot


-- #check Godot.Signal.emit
-- #check Godot.Vector2.Axis.toCtorIdx
