import Lean
open Lean Meta Elab Command

structure GodotBinding where
  declName : Name
  cname    : String
  type: Expr
deriving Inhabited, Repr
instance : ToString GodotBinding where
   toString := fun ⟨declName, cname, type⟩ => s!"GodotBinding({declName}->{cname} : {type})"

initialize godotRegistryExt : SimplePersistentEnvExtension GodotBinding (List GodotBinding) ←
  registerSimplePersistentEnvExtension {
    name := `godotRegistryExt
    addEntryFn := (·.cons)
    addImportedFn := fun arr => arr.toList.flatMap (·.toList)
    toArrayFn := fun es => es.toArray
  }

def getGodotBindings (env : Environment) : List GodotBinding :=
  godotRegistryExt.getState env

syntax (name := godot) "godot " str : attr

def godotAttrImpl : AttributeImpl where
  name := `godot
  descr := "Marks a function as a godot binding"
  add := fun declName stx kind => do
     match stx with
     | `(attr| godot $cname:str) =>
        let env <- getEnv
        let some decl := env.find? declName
          | throwError "[godot] could not find declaration {declName}"
        let type := decl.type
        modifyEnv (fun env => 
           godotRegistryExt.addEntry env
             (GodotBinding.mk declName cname.getString type)
        )
        let env <- getEnv
        logInfo m!"[godotAttr] registering {declName} => {getGodotBindings env}"
     | _ =>
       throwError "invalid godot attribute syntax, expected @[godot \"c_name\"]"
  applicationTime := .afterTypeChecking

initialize
  registerBuiltinAttribute godotAttrImpl


syntax (name := godotBindingsCmd) "#godotBindings" : command

@[command_elab godotBindingsCmd]
def elabGodotBindingsCmd : CommandElab
| `(#godotBindings) => do
    let env ← getEnv
    let entries := getGodotBindings env
    for ⟨leanName, cname, type⟩ in entries.reverse do
      logInfo m!"godot binding: {leanName} => {cname} : {type}"
| _ => throwUnsupportedSyntax
