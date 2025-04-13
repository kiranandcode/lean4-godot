import Lake
open System Lake DSL

package LeanGodot where
  version := v!"0.0.1"
  description := "Lean4 bindings to the Godot Game Engine"
  license := "MIT"
  keywords := #["gamedev", "c-bindings"]

lean_lib LeanGodot where
  srcDir := "lean"
  roots := #[`LeanGodot]
  buildType := .release
  defaultFacets := #[LeanLib.sharedFacet]
  platformIndependent := true

lean_lib Bindings where
  srcDir := "lean"
  roots := #[`Bindings]
  buildType := .release
  defaultFacets := #[LeanLib.sharedFacet]
  platformIndependent := true


def GenerateBindings (pkg: NPackage _package.name) (cmd: String) : FetchM (Job String) := do
-- first build lean
  let lib <- LeanGodot.get
  let dep <- lib.recBuildLean
  dep.await
  let genBindingsSrc <- inputTextFile (pkg.srcDir / "scripts" / "GenerateBindings.lean")
  let fp <- genBindingsSrc.await
  let args := #["--run", fp.toString, "--", cmd]
  let output <-
      IO.Process.output {
         cmd := "lean", args,
         env := ← getAugmentedEnv,
         stdout := .piped,
         stderr := .inherit
      }
  if output.exitCode != 0 then
     error s! "GenerateBindings failed: {output.stderr}"
  return (pure output.stdout)

-- lean_lib GenerateBindings where
--    srcDir := "scripts"
--    roots := #[`GenerateBindings]

target initHeader (pkg : NPackage _package.name) : FilePath := do
  let cDir := pkg.buildDir / "c"
  IO.FS.createDirAll cDir -- ensure output dir exists
  let outFile := cDir / "init.h"
  let output <- GenerateBindings pkg "Init"
  buildFileAfterDep outFile output fun output =>
    IO.FS.writeFile outFile output

target declarationsHeader (pkg : NPackage _package.name) : FilePath := do
  -- let exe ← GenerateBindings.fetch -- build and get the path to the executable
  let cDir := pkg.buildDir / "c"
  IO.FS.createDirAll cDir -- ensure output dir exists
  let outFile := cDir / "declarations.h"
  let output <- GenerateBindings pkg "Declarations"
  buildFileAfterDep outFile output fun output =>
    IO.FS.writeFile outFile output

target utils.h (_pkg : NPackage _package.name) : FilePath := do
  inputFile "c/utils.h" true


target bindings.c (_pkg : NPackage _package.name) : FilePath := do
  let declarationsHeader <- declarationsHeader.fetch
  let initHeader <- initHeader.fetch
  let _ <- declarationsHeader.await
  let _ <- initHeader.await
  let utils <- utils.h.fetch
  let _ <- utils.await
  inputFile "c/bindings.c" true

target gdextension_interface.h (_pkg : NPackage _package.name) : FilePath := do
  inputFile "godot-headers/godot/gdextension_interface.h" true

target bindings.o (pkg : NPackage _package.name) : FilePath := do
  let bindings_c <- fetch <| pkg.target ``bindings.c
  let gdextension_h <- fetch <| pkg.target ``gdextension_interface.h
  let lean_dir := (<- getLeanIncludeDir).toString

  let c_dir := pkg.buildDir / "c"
  let bindings_o := pkg.buildDir / "bindings.o"
  buildFileAfterDep bindings_o (.collectList [bindings_c, gdextension_h]) fun deps =>
     let bindings_c := deps[0]!
     let gdextension_h := deps[1]!.parent.get!.parent.get!.toString
     compileO
        bindings_o
        bindings_c #["-I", gdextension_h, "-I", c_dir.toString, "-I", lean_dir, "-fPIC"]

@[default_target]
extern_lib extension (pkg: NPackage _package.name) := do
  let name := nameToSharedLib "leangodot"
  let outDir := pkg.buildDir / "lib"

  let bindings_o <- fetch <| pkg.target ``bindings.o
  let LeanGodotDep <- LeanGodot.get
  let LeanGodotDep <- LeanGodotDep.recBuildStatic false
  let BindingsDep <- Bindings.get
  let BindingsDep <- BindingsDep.recBuildStatic false


  let leanLibDir := (<- getLeanLibDir)
  let leanStaticLibs :=
      (<- leanLibDir.readDir)
      |>.filter (fun file => file.path.extension.isEqSome "so")
      |>.map (fun file => file.path.toString)

  buildFileAfterDep (outDir / name) (.collectList [
       bindings_o,
       LeanGodotDep,
       BindingsDep
   ]) fun data =>
       let bindings_o := data[0]!
       let lean_godot_lib := data[1]!
       let bindings_lib := data[2]!
       compileSharedLib
         (outDir / name)
         <|
          #[bindings_o.toString, bindings_lib.toString, lean_godot_lib.toString]
          |>.append leanStaticLibs
