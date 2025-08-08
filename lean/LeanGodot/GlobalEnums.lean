import Lean
import ExtensionAPI.Json

open Lean Meta Elab

namespace Godot.Enums
scoped syntax "#declare_global_enums" : command

elab_rules : command
| `(command| #declare_global_enums) => open Lean.Parser.Command in do
   for (name, enum) in ExtensionAPI.Json.global_enums do
       if enum.is_bitfield then
          let godot_enum_name := mkIdent (Name.str .anonymous name)
          let godot_enum_name_mk := mkIdent ((Name.str .anonymous name).str "mk")

          Lean.Elab.Command.elabCommand (<- `(command|
              structure $godot_enum_name where val: Int32 deriving DecidableEq
          ))

          for (const_name,value) in enum.values do
             let const_name := mkIdent $ (Name.str .anonymous name).str const_name
             let value := Syntax.mkNumLit s!"{value}"
             Lean.Elab.Command.elabCommand (<- `(command|
                 @[inline]def $const_name : $godot_enum_name := $godot_enum_name_mk ($value)
             ))             
          Lean.Elab.Command.elabCommand (<- `(command|
              instance : HAdd $godot_enum_name $godot_enum_name $godot_enum_name where
                hAdd := fun l r => $godot_enum_name_mk (Int32.lor l.val r.val)
          ))             


       else
          let godot_enum_name := mkIdent (Name.str .anonymous name)
          let enumValues := enum.values.toList.mergeSort (le := fun (_, a) (_, b) => a <= b)
          let fields <- enumValues
             |>.map (fun (name, _) => mkIdent (Name.str .anonymous name))
             |>.mapM (fun name => `(ctor| | $name:ident))
          let fields := TSyntaxArray.mk fields.toArray
          Lean.Elab.Command.elabCommand (<- `(command| inductive $godot_enum_name where $fields*))

   return ()

#declare_global_enums


structure ClassMethodFlags where private val: Int32  deriving DecidableEq, Repr 
namespace ClassMethodFlags
def NORMAL : ClassMethodFlags := mk 1
def EDITOR : ClassMethodFlags := mk 2
def CONST : ClassMethodFlags := mk 4
def VIRTUAL : ClassMethodFlags := mk 8
def VARARG : ClassMethodFlags := mk 16
def STATIC : ClassMethodFlags := mk 32
def DEFAULT : ClassMethodFlags := mk 1
end ClassMethodFlags
instance : HAdd ClassMethodFlags ClassMethodFlags ClassMethodFlags where
  hAdd := fun l r => .mk $ Int32.lor l.val r.val

end Godot.Enums

#print Godot.Enums.VerticalAlignment
