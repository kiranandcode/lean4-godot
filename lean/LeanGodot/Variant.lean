import Lean.Elab
import Bindings

namespace Godot

opaque Variant: Type
godot_inhabited_type Variant

namespace Variant
@[extern "lean4_variant_stringify"]
opaque toString: Variant -> String

end Variant

instance : ToString Variant where
  toString := Variant.toString

end Godot
