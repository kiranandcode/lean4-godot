import BindingsLang

@[godot "GDString"]
opaque GDString: Type

@[godot "get_native_struct_size" GDExtensionInterfaceGetNativeStructSize]
opaque NativeStruct.size : (p_name: @& GDString) -> UInt64


@[godot "lean4_string_new_with_utf8_chars" GDExtensionInterfaceStringNewWithUtf8Chars]
opaque of_string: (p_contents: @& String) -> IO (@out GDString)
-- 
-- @[godot "lean4_string_to_utf8"]
-- opaque to_string: @& GDString -> IO String

