import Lean
open Lean Meta

def LeanGodot.generateExternName (declName: Name) : String :=
   "lean_godot_" ++ declName.toString.replace "." "_"
