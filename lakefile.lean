import Lake
open System Lake DSL

package LeanGodot where
  version := v!"0.0.1"
  description := "random"
  license := "MIT"
  keywords := #["gamedev"]


@[default_target]
lean_lib LeanGodot where
  srcDir := "lean"
  defaultFacets := #[LeanLib.sharedFacet]
  buildType := .release
  platformIndependent := true

target bindings.c (_pkg : NPackage _package.name) : FilePath := do
  inputFile "c/bindings.c" true

target gdextension_interface.h (_pkg : NPackage _package.name) : FilePath := do
  inputFile "godot-headers/godot/gdextension_interface.h" true

target bindings.o (pkg : NPackage _package.name) : FilePath := do
  let bindings_c <- fetch <| pkg.target ``bindings.c
  let gdextension_h <- fetch <| pkg.target ``gdextension_interface.h
  let lean_dir := (<- getLeanIncludeDir).toString

  let bindings_o := pkg.buildDir / "bindings.o"
  buildFileAfterDep bindings_o (.collectList [bindings_c, gdextension_h]) fun deps =>
     let bindings_c := deps[0]!
     let gdextension_h := deps[1]!.parent.get!.parent.get!.toString
     compileO
        bindings_o
        bindings_c #["-I", gdextension_h, "-I", lean_dir, "-fPIC"]

extern_lib bindings (pkg: NPackage _package.name) := do
  let name := nameToStaticLib "bindings"
  let bindings_o <- fetch <| pkg.target ``bindings.o
  buildStaticLib
    (pkg.buildDir / "lib" / name)
    #[bindings_o]
