import Lean
import LeanGodot.FunctionWrapper
open Lean Elab Command Meta

initialize Godot.initialisers : IO.Ref (OArray (IO Unit)) <- IO.mkRef #[]

def Godot.registerInitialiser (init : IO Unit) : IO Unit := do
  let arr <- Godot.initialisers.get
  Godot.initialisers.set (arr.push init)

def Godot.initialise_classes : IO Unit := do
  let inits <- Godot.initialisers.get
  for init in inits do
    init

syntax godotField := ident ":" term
syntax godotPropertyField := "get" ":=" term <|> "set" ":=" term
syntax godotProperty := "property" ident ":" term "where" (colGt godotPropertyField ppLine)*
syntax godotMethod := "method" ident "(" sepBy(godotField, ",") ")" ":" term ":=" term
syntax godotConstructor := "constructor" term
syntax "godot_extension_class" ident ":" term "where" ppLine (godotField <|> godotProperty <|> godotMethod <|> godotConstructor)* : command
