import Lean.Elab
import Bindings
import LeanGodot.Variant

opaque Godot.StringName: Type
godot_inhabited_type Godot.StringName

namespace Godot.StringName
@[extern "lean4_string_name_new_with_utf_chars"]
opaque mk : String -> StringName

@[extern "lean4_string_name_to_variant"]
opaque toVariant: StringName -> Godot.Variant

def toString (v: StringName) := v.toVariant.toString

end Godot.StringName

instance : ToString Godot.StringName where
  toString := Godot.StringName.toString
