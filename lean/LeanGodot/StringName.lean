import Lean.Elab
import Bindings
import LeanGodot.Variant
import LeanGodot.BuiltinTypes

namespace Godot.StringName
@[extern "lean4_string_name_new_with_utf_chars"]
opaque mk : String -> StringName
end Godot.StringName
