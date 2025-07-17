import Lean.Elab
import LeanGodot.Version
import LeanGodot.Initialization
import LeanGodot.Printing
import Bindings

namespace Godot

@[godot "GDExtensionStringPtr" String]
opaque GDString : Type
godot_inhabited_type GDString

namespace GDString
@[godot "string_new_with_utf8_chars" GDExtensionInterfaceStringNewWithUtf8Chars]
opaque mk: (p_contents: @& String) -> @out GDString

@[extern "lean4_string_to_utf8_chars"]
opaque to_string: (p_name: @& GDString) -> String

end GDString
instance : ToString GDString where
   toString := GDString.to_string

@[godot "GDExtensionStringNamePtr" StringName]
opaque GDStringName : Type
godot_inhabited_type GDStringName
namespace GDStringName

@[godot "string_name_new_with_utf8_chars" GDExtensionInterfaceStringNameNewWithUtf8Chars]
opaque mk: (p_contents: @& String) -> @out GDString
end GDStringName

@[godot "GDExtensionVariantPtr" Variant]
opaque GDVariant : Type
godot_inhabited_type GDVariant

namespace GDVariant

namespace Nil
@[godot "variant_new_nil" GDExtensionInterfaceVariantNewNil]
opaque mk: (_unused: Unit) -> IO (@out GDVariant)
end Nil

@[extern "lean4_variant_stringify"]
opaque to_string: (p_variant: @& GDVariant) -> String

instance : ToString GDVariant where
   toString := to_string
end GDVariant

@[export lean_godot_on_initialization]
def on_initialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_initialisation called!"
  let cversion <- version ()
  println! "[lean4-godot] on_initialization called with {repr lvl} ({repr cversion})"
  gd_print_error! "error from Lean"
  let str := GDString.mk "random"
  gd_eprint! "retrieved {str}"
  gd_eprint! "creating a nil:"
  let v <- GDVariant.Nil.mk ()
  gd_eprint! "converting to string"
  gd_eprint! "nil as string is  \"{v}\""

  -- -- let g_str <- GDString.of_string "hello"
  -- gd_eprint! "converted to gdstring object"
  -- -- let v_str := GDString.to_string g_str
  -- gd_eprint! "converted back to lean"

  -- gd_eprint! "{v_str}"

@[export lean_godot_on_deinitialization]
def on_deinitialization (lvl: Initialization.Level) : IO Unit := do
  println! "[lean4-godot] on_deinitialization called with {repr lvl}"

end Godot




-- end GDString

-- @[godot "GDExtensionStringNamePtr"]
-- opaque GDStringName : Type
-- godot_inhabited_type GDStringName

-- namespace GDStringName
-- @[godot "string_name_new_with_utf8_chars" GDExtensionInterfaceStringNameNewWithUtf8Chars]
-- opaque mk: (p_contents: @& String) -> @out GDString
-- end GDStringName

-- @[godot "GDExtensionVariantPtr"]
-- opaque GDVariant : Type
-- godot_inhabited_type GDVariant

-- namespace GDVariant

-- @[godot "variant_new_nil" GDExtensionInterfaceVariantNewNil]
-- opaque mkNil: (_unused: Unit) -> IO (@out GDVariant)

-- @[godot "variant_destroy" GDExtensionInterfaceVariantDestroy]
-- opaque destroy: (self: GDVariant) -> IO Unit

-- @[godot "variant_stringify" GDExtensionInterfaceVariantStringify]
-- private opaque stringify_internal:
--    (p_self: @& GDVariant) ->
--    (r_ret: @& GDString) ->
--    IO Unit
-- def to_string (variant: GDVariant) : IO String := do
--    println! "to string reached!"
--    let str := GDString.mk ""
--    println! "made a gdstring"
--    stringify_internal variant str
--    return (GDString.to_string str)

-- end GDVariant


-- @[godot "get_native_struct_size" GDExtensionInterfaceGetNativeStructSize]
-- opaque get_native_struct_size: (p_name: @& GDStringName) -> UInt64

