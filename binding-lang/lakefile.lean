import Lake
open System Lake DSL

package BindingsLang where
  version := v!"0.0.1"
  description := "Language for declaring bindings"
  license := "MIT"
  keywords := #["gamedev", "c-bindings"]

lean_lib BindingsLang where
  srcDir := "./src"
  defaultFacets := #[LeanLib.sharedFacet]
  buildType := .release
  platformIndependent := true

lean_lib Example where
   srcDir := "./example"

@[default_target]
lean_exe Helper where
   srcDir := "./example"
   root := `Main

