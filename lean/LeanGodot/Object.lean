import Lean.Elab
import LeanGodot.Variant
import Bindings

namespace Godot

opaque Object: Type
godot_inhabited_type Object

@[extern "lean4_object_to_variant"]
opaque Object.toVariant: Object -> Variant
def Object.toString (v: Object) : String := v.toVariant.toString
instance : ToString Object where toString := Object.toString

end Godot
