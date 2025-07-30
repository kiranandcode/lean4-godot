import Lean
import ExtensionAPI.Json
import LeanGodot.Variant
import LeanGodot.String
import LeanGodot.Object
import LeanGodot.RID
import LeanGodot.PackedByteArray
import LeanGodot.BuiltinTypes

open Lean Meta Elab



namespace Godot.Utility
scoped syntax "#declare_utility_functions" : command


def buildType (ty: OString) : Command.CommandElabM (TSyntax `term) := match ty with
  | "Variant" => `(term| Godot.Variant)
  | "int" => `(term| Int64)
  | "bool" => `(term| Bool)
  | "float" => `(term| Float)
  | name =>
      let name := mkIdent (Name.anonymous.str "Godot" |>.str name)
      `(term| $name:ident)


elab_rules : command
| `(command| #declare_utility_functions) => do
    for (name, fn) in ExtensionAPI.Json.utility_functions do
        let extern_name := (s!"lean4_utility_{name}")
        let extern_name := Syntax.mkStrLit extern_name
        let name := mkIdent (Name.str .anonymous name)
        let retTy <- match fn.return_type with | .none => `(term| IO Unit) | .some ty => buildType ty


        let type <-
          if fn.arguments.isEmpty
          then `(term| Unit -> $retTy)
          else if fn.arguments.length <= 7 && not (fn.is_vararg && fn.arguments.length == 1) then
            fn.arguments.foldrM (init:=retTy) (fun farg ret => do
              let ty <- buildType farg.type
              `(term| (@& $ty) -> $ret)
            )
          else
              let firstType := fn.arguments[0]?.map (·.type) |>.get!
              if not $ fn.arguments.all (·.type == firstType) then
                  throwError s!"function {name} had too many arguments {repr fn.arguments}"
              let ty <- buildType firstType
              `(term| (@& OArray (@& $ty)) -> $retTy)

        Command.elabCommand (← `(command|
        @[extern $extern_name:str]
        opaque $name : $type
        ))
    return ()

#declare_utility_functions
end Godot.Utility
