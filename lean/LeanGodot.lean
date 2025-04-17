import Lean.Elab
import Bindings

namespace Godot
structure Version where
  major: UInt32
  minor: UInt32
  patch: UInt32
  string: String
deriving Repr, Ord, BEq

@[extern "lean4_get_version"]
opaque version : Unit -> IO Version

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

@[godot "GDExtensionStringPtr"]
opaque GDString : Type
godot_inhabited_type GDString

namespace GDString
@[godot "string_new_with_utf8_chars" GDExtensionInterfaceStringNewWithUtf8Chars]
opaque mk: (p_contents: @& String) -> @out GDString

@[extern "lean4_string_to_utf8_chars"]
opaque to_string: (p_name: @& GDString) -> String
end GDString

@[godot "GDExtensionStringNamePtr"]
opaque GDStringName : Type
godot_inhabited_type GDStringName

namespace GDStringName
@[godot "string_name_new_with_utf8_chars" GDExtensionInterfaceStringNameNewWithUtf8Chars]
opaque mk: (p_contents: @& String) -> @out GDString
end GDStringName

@[godot "GDExtensionVariantPtr"]
opaque GDVariant : Type
godot_inhabited_type GDVariant

namespace GDVariant

@[godot "variant_new_nil" GDExtensionInterfaceVariantNewNil]
opaque mkNil: (_unused: Unit) -> IO (@out GDVariant)

@[godot "variant_destroy" GDExtensionInterfaceVariantDestroy]
opaque destroy: (self: GDVariant) -> IO Unit

@[godot "variant_stringify" GDExtensionInterfaceVariantStringify]
private opaque stringify_internal:
   (p_self: @& GDVariant) ->
   (r_ret: @& GDString) ->
   IO Unit
def to_string (variant: GDVariant) : IO String := do
   println! "to string reached!"
   let str := GDString.mk ""
   stringify_internal variant str
   return (GDString.to_string str)

end GDVariant


@[godot "get_native_struct_size" GDExtensionInterfaceGetNativeStructSize]
opaque get_native_struct_size: (p_name: @& GDStringName) -> UInt64


@[export lean_godot_on_initialization]
def on_initialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_initialisation called!"
  let cversion <- version ()
  println! "[lean4-godot] on_initialization called with {repr lvl} ({repr cversion})"
  gd_print_error! "error from Lean"
  let _str := GDString.mk "random"
  gd_print_error! s!"retrieved {_str.to_string}"
  gd_print_warning! "warning from Lean"
  gd_eprint! "script error from Lean"
  let v <- GDVariant.mkNil ()
  -- let _v_str <- v.to_string
  gd_eprint! "retrieved okay"
  -- -- let g_str <- GDString.of_string "hello"
  -- gd_eprint! "converted to gdstring object"
  -- -- let v_str := GDString.to_string g_str
  -- gd_eprint! "converted back to lean"

  -- gd_eprint! "{v_str}"

@[export lean_godot_on_deinitialization]
def on_deinitialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_deinitialization called with {repr lvl}"

end Godot
