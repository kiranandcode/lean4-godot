import Lean.Elab
import Bindings

namespace Godot


@[godot "print_error" GDExtensionInterfacePrintError]
private opaque raw_print_error:
    (p_description: @& String) ->
    (p_function: @& String) ->
    (p_file: @& String) ->
    (p_line: Int32) ->
    (p_editor_notify: Bool) -> IO Unit
@[godot "print_error_with_message" GDExtensionInterfacePrintErrorWithMessage]
private opaque raw_print_error_with_message:
    (p_description: @& String) ->
    (p_message: @& String) ->
    (p_function: @& String) ->
    (p_file: @& String) ->
    (p_line: Int32) ->
    (p_editor_notify: Bool) -> IO Unit


def gd_print_error (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_error_with_message "LeanGodot:Error" description function file (Int.toInt32 line) notify_editor

@[godot "print_warning" GDExtensionInterfacePrintWarning]
private opaque raw_print_warning:
   (p_description: @& String) ->
   (p_function: @& String) ->
   (p_file: @& String) ->
   (p_line: Int32) ->
   (p_editor_notify: Bool) -> IO Unit
@[godot "print_warning_with_message" GDExtensionInterfacePrintWarningWithMessage]
private opaque raw_print_warning_with_message:
   (p_description: @& String) ->
   (p_message: @& String) ->
   (p_function: @& String) ->
   (p_file: @& String) ->
   (p_line: Int32) ->
   (p_editor_notify: Bool) -> IO Unit

def gd_print_warning (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_warning_with_message "LeanGodot:Warning" description function file (Int.toInt32 line) notify_editor

@[godot "print_script_error" GDExtensionInterfacePrintScriptError]
private opaque raw_print_script_error:
   (p_description: @& String) ->
   (p_function: @& String) ->
   (p_file: @& String) ->
   (p_line: Int32) ->
   (p_editor_notify: Bool) -> IO Unit
@[godot "print_script_error_with_message" GDExtensionInterfacePrintScriptErrorWithMessage]
private opaque raw_print_script_error_with_message:
   (p_description: @& String) ->
   (p_message: @& String) ->
   (p_function: @& String) ->
   (p_file: @& String) ->
   (p_line: Int32) ->
   (p_editor_notify: Bool) -> IO Unit

def gd_print_script_error (description : String) (function: String) (file: String) (line: Int) (notify_editor: Bool) := raw_print_script_error_with_message "LeanGodot:ScriptError" description function file (Int.toInt32 line) notify_editor

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

end Godot
