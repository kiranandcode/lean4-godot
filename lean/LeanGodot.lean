import Lean.Elab
import LeanGodot.Version
import LeanGodot.Initialization
import LeanGodot.Printing
import LeanGodot.Variant
import LeanGodot.String
import Bindings

namespace Godot



@[export lean_godot_on_initialization]
def on_initialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_initialisation called!"
  let cversion <- version ()
  println! "[lean4-godot] on_initialization called with {repr lvl} ({repr cversion})"

  gd_eprint! "making a string"
  let ostr := "hello"
  let g_str <- pure (Godot.String.mk ostr)
  gd_eprint! "no segfaults omg!"
  gd_eprint! "converting back to lean"
  let str <- pure (g_str.toString)
  gd_eprint! "converted went from \"{ostr}\" \"{str}\""
  gd_eprint! "converting to a variant"
  let var <- pure (g_str.toVariant)
  gd_eprint! "converted to a variant"
  gd_eprint! "converting variant to string..."
  let var_str <- pure (var.toString)
  gd_eprint! "converted back to a string {var_str}!"
  /- gd_eprint! "printing!!! {var_str}"
 -/

  -- gd_eprint! "converted to gdstring object"
  -- -- let v_str := GDString.to_string g_str
  -- gd_eprint! "converted back to lean"

  -- gd_eprint! "{v_str}"

@[export lean_godot_on_deinitialization]
def on_deinitialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_deinitialization called with {repr lvl}"

end Godot
