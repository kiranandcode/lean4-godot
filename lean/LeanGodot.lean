@[extern "lean_godot_init"]
opaque godot_init: IO Unit

@[export lean_godot_init]
def lean_init : IO Unit := do
  println! "[lean_init] calling code from Lean"
  godot_init
  println! "[lean_init] back in Lean"
