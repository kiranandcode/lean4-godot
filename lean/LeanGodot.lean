import Lean.Elab

namespace Godot
structure Version where
  major: UInt32
  minor: UInt32
  patch: UInt32
  string: String
deriving Repr, Ord, BEq

@[extern "lean4_get_version"]
opaque version : IO Version

namespace Initialization
-- GDExtensionInitializationLevel
inductive Level where
| CORE
| SERVERS
| SCENE
| EDITOR
| LEVEL
deriving Repr, Ord, BEq
end Initialization 

@[extern "lean4_print_error"]
private opaque raw_print_error: @& String -> @& String -> @& String -> Int32 -> Bool -> IO Unit
def gd_print_error (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_error description function file (Int.toInt32 line) notify_editor

@[extern "lean4_print_warning"]
private opaque raw_print_warning: @& String -> @& String -> @& String -> Int32 -> Bool -> IO Unit
def gd_print_warning (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_warning description function file (Int.toInt32 line) notify_editor

@[extern "lean4_print_script_error"]
private opaque raw_print_script_error: @& String -> @& String -> @& String -> Int32 -> Bool -> IO Unit
def gd_print_script_error (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_script_error description function file (Int.toInt32 line) notify_editor


section Macro
open Lean Elab Meta
syntax "gd_print_error! " (interpolatedStr(term) <|> term): term
syntax "gd_print_warning! " (interpolatedStr(term) <|> term): term
syntax "gd_eprint! " (interpolatedStr(term) <|> term): term
syntax "gd_print_generic " ident term (term)?: term

macro_rules
| `(gd_print_error! $term:interpolatedStr) => `(gd_print_generic Godot.gd_print_error (s! $term))
| `(gd_print_error! $term:term) => `(gd_print_generic Godot.gd_print_error $term)
| `(gd_print_warning! $term:interpolatedStr) => `(gd_print_generic Godot.gd_print_warning (s! $term))
| `(gd_print_warning! $term:term) => `(gd_print_generic Godot.gd_print_warning $term)
| `(gd_eprint! $term:interpolatedStr) => `(gd_print_generic Godot.gd_print_script_error (s! $term))
| `(gd_eprint! $term:term) => `(gd_print_generic Godot.gd_print_script_error $term)




def build_fn_stx (stx: Syntax) (id: Ident) (msg: TSyntax `term) (notify: TSyntax `term) : TermElabM (TSyntax `term) := do
   let filename <- getFileName
   let fileMap <- getFileMap
   let info := SourceInfo.fromRef stx
   let pos := info.getPos?.getD 0
   let pos := fileMap.toPosition $ pos
   let func := (<- Term.getDeclName?).map (·.toString) |>.getD "<unknown>"
   `(($id:ident
               $msg
               $(Syntax.mkStrLit func)
               $(Syntax.mkStrLit filename)
               $(Syntax.mkNumLit s!"{pos.line}")
               $notify : IO Unit))

elab_rules : term
| `(term| gd_print_generic%$stx $id:ident $msg:term) => do
   let stx <-
      build_fn_stx stx id msg (TSyntax.mk (mkCIdent ``false))
   Term.elabTerm stx none



end Macro


@[export lean_godot_on_initialization]
def on_initialization (lvl: Initialization.Level) : IO Unit := do
  let cversion <- version
  println! "[lean4-godot] on_initialization called with {repr lvl} ({repr cversion})"
  gd_print_error! "error from Lean"
  gd_print_warning! "warning from Lean"
  gd_eprint! "script error from Lean"

@[export lean_godot_on_deinitialization]
def on_deinitialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_deinitialization called with {repr lvl}"

end Godot

@[export lean_godot_init]
def lean_init : IO Unit := do
println! "[lean_init] calling code from Lean"

println! "[lean_init] back in Lean"
