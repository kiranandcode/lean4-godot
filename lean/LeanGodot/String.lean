import Lean.Elab
import Bindings
import LeanGodot.Variant

abbrev OString := String
opaque Godot.String: Type
godot_inhabited_type Godot.String

namespace Godot.String
@[extern "lean4_string_new_with_utf_chars"]
opaque mk : OString -> String

@[extern "lean4_string_to_utf8_chars"]
opaque toString : String -> OString

@[extern "lean4_string_to_variant"]
opaque toVariant: String -> Godot.Variant

end Godot.String

instance : ToString Godot.String where
  toString := Godot.String.toString
