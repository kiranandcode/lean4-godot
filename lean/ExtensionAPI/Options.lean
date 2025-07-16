import Lean
namespace ExtensionAPI.Option

inductive BuildFlag
| Float64
| Float32
| Double64
def BuildFlag.toString : BuildFlag -> String
| Float64 => "float_64"
| Float32 => "float_32"
| Double64 => "double_64"
def BuildFlag.ofString? : String -> Option BuildFlag
| "float_32" => .some .Float32
| "float_64" => .some .Float64
| "double_64" => .some .Double64
| _ => .none
instance : Lean.KVMap.Value BuildFlag where
   toDataValue v := .ofString (v.toString)
   ofDataValue? v := if let .ofString v := v then BuildFlag.ofString? v else .none
def BuildFlag.option :=
   Lean.Option.Decl.mk BuildFlag.Float64 "Godot" "Build Configuration for Godot"
instance : Inhabited (Lean.Option BuildFlag) where
   default := Lean.Option.mk `godot.build_configuration BuildFlag.Float64

end ExtensionAPI.Option

open ExtensionAPI.Option
register_option godot.build_configuration : BuildFlag := BuildFlag.option
