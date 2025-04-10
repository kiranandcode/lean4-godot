import Lean.Meta
open Lean System IO Elab 

initialize godotDefs : IO.Ref (Array String) ← IO.mkRef #[]

initialize godotAttr : ParametricAttribute Unit ←
  registerParametricAttribute {
    name := `godot
    descr := "Marks a function to export as a Godot binding"
    getParam := fun _ stx =>
       match stx with
       | `(attr| godot) => return ()
       | _ => throwUnsupportedSyntax
  }
