import Lean.Elab
import LeanGodot.Version
import LeanGodot.Initialization
import LeanGodot.Printing
import LeanGodot.Variant
import LeanGodot.String
import LeanGodot.StringName
import LeanGodot.Utility
import LeanGodot.BuiltinTypes
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
  gd_eprint! "creating a stringname"
  let sstr <- pure (Godot.StringName.mk "epic")
  gd_eprint! "made a stringname!"
  gd_eprint! "tostring of stringname"
  let sstr_str <- pure (sstr.toString)
  gd_eprint! "got stringname: {sstr_str}"
  if let Initialization.Level.EDITOR := lvl then
     Godot.Utility.print #[var]
     Godot.Utility.push_warning #[g_str.toVariant]
  gd_eprint! "random value"
  let uvec <- Godot.Vector2.UP ()
  let x <- uvec.x
  let y <- uvec.y
  gd_eprint! "up vec initial is {uvec} ({x}, {y})"
  gd_eprint! "upvec x is {x}, upvec y is {y}"
  uvec.set_x y
  uvec.set_y x
  let x <- uvec.x
  let y <- uvec.y
  gd_eprint! "up vec final is {uvec} ({x}, {y})"

  let ival <- Godot.Projection.PLANE_FAR ()
  gd_print_error! "plane far is {ival}"
  let vec3 <- Godot.Vector3.mk3 0.0 1.0 2.0
  gd_print_error! "vec I made is {vec3}"
  let res <- Godot.Projection.create_perspective_hmd 0.0 0.0 0.0 0.0 true 1 2.0 3.0
  gd_print_error! "projection is {res}"
  let ex := Godot.Utility.cubic_interpolate_in_time #[0.0, 1.0, 2.0]
  gd_print_error! "cubic interpolate in time is {ex}"
  let basis <- Godot.Basis.from_scale vec3
  gd_print_error! "basis is {basis}"

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
