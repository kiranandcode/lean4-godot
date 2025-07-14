# Lean-Godot Lean Bindings to Godot 4

## Structure
The way this project works is through a mishmash of interactions
between Lean compile time and link time code.

The high level pipeline for compilation is as follows:

1) Build `lean/Bindings.lean`. Defines DSL and annotations for declaring bindings

2) Build `lean/LeanGodot.lean`. Uses `Bindings` DSL to define Godot functions:

   ```lean
   @[godot "print_error" GDExtensionInterfacePrintError]
   private opaque raw_print_error:
       (p_description: @& String) ->
       (p_function: @& String) ->
       (p_file: @& String) ->
       (p_line: Int32) ->
       (p_editor_notify: Bool) -> IO Unit
   ```
   This, a) declares an opaque function with the types as given, b) registers some compilation metadata that a binding to the libgodot function `print_error` should be generated.

3) Run `scripts/GenerateBindings.lean` which links in `Bindings` and
`LeanGodot`, and in particular has access to the metadata that was
stored with each binding. This script then iterates through each
binding and pragmatically constructs a C function implementing the
wrapper.

4) Compile a Godot dynamic library `leangodot.dll` which links
together the generated bindings with the lean library and produces a
dynamic library that can be loaded into Godot as a dll.


