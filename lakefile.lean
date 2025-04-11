import Lake
open System Lake DSL

package LeanGodot where
  version := v!"0.0.1"
  description := "Lean4 bindings to the Godot Game Engine"
  license := "MIT"
  keywords := #["gamedev", "c-bindings"]

lean_lib LeanGodot where
  srcDir := "lean"
  defaultFacets := #[LeanLib.sharedFacet]
  buildType := .release
  platformIndependent := true

lean_lib Bindings where
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

@[default_target]
extern_lib extension (pkg: NPackage _package.name) := do
  let name := nameToSharedLib "leangodot"
  let outDir := pkg.buildDir / "lib"

  let bindings_o <- fetch <| pkg.target ``bindings.o
  let some lean_godot_lib := pkg.findLeanLib? ``LeanGodot
     | error "cannot find lean_lib target"
  let lean_godot_lib <- lean_godot_lib.recBuildStatic false

  let leanLibDir := (<- getLeanLibDir)
  let leanStaticLibs :=
      (<- leanLibDir.readDir)
      |>.filter (fun file => file.path.extension.isEqSome "so")
      |>.map (fun file => file.path.toString)

  buildFileAfterDep (outDir / name) (.collectList [
       bindings_o,
       lean_godot_lib
   ]) fun data =>
       let bindings_o := data[0]!
       let lean_godot_lib := data[1]!
       compileSharedLib
         (outDir / name)
         <|
          #[bindings_o.toString, lean_godot_lib.toString]
          |>.append leanStaticLibs
