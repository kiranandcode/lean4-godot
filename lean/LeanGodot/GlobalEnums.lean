import Lean
import ExtensionAPI.Json

open Lean Meta Elab

namespace Godot.Enums
scoped syntax "#declare_global_enums" : command

elab_rules : command
| `(command| #declare_global_enums) => open Lean.Parser.Command in do
   for (name, enum) in ExtensionAPI.Json.global_enums do
       if enum.is_bitfield then continue

       let godot_enum_name := mkIdent (Name.str .anonymous name)
       let enumValues := enum.values.toList.mergeSort (le := fun (_, a) (_, b) => a <= b)
       let fields <- enumValues
          |>.map (fun (name, _) => mkIdent (Name.str .anonymous name))
          |>.mapM (fun name => `(ctor| | $name:ident))
       let fields := TSyntaxArray.mk fields.toArray
       Lean.Elab.Command.elabCommand (<- `(command| inductive $godot_enum_name where $fields*))

   return ()

#declare_global_enums
end Godot.Enums

#print Godot.Enums.VerticalAlignment
