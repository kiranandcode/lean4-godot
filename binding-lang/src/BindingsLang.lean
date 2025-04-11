import Lean
import BindingsLang.Types
import BindingsLang.Utils
import BindingsLang.Extraction
open Lean Meta Elab Command

initialize godotRegistryExt : SimplePersistentEnvExtension GodotBinding (List GodotBinding) ←
  registerSimplePersistentEnvExtension {
    name := `godotRegistryExt
    addEntryFn := (·.cons)
    addImportedFn := fun arr => arr.toList.flatMap (·.toList)
    toArrayFn := fun es => es.toArray
  }

def getGodotBindings (env : Environment) : List GodotBinding :=
  godotRegistryExt.getState env

syntax (name := godot) "godot " str (ident)? : attr
syntax (name := lean_godot_out) "@" "out" term : term

-- Define the custom elaboration for the `@out` attribute
def addOutMetadata (e : Expr) : Expr := 
  -- First, elaborate the term (this will give us the term that `@out` is applied to)
  -- Add the 'out' metadata (same structure as @&'s borrowed metadata)
  mkMData {entries := [(`out, .ofBool true)] } e

@[term_elab lean_godot_out]
def elabLeanGodotOut : Term.TermElab := fun stx oty => match stx with
| `(term| @out $stx:term) => do
  let expr ← Term.elabTerm stx oty
  return (addOutMetadata expr)
| _ => throwUnsupportedSyntax


def godotAttrImpl : AttributeImpl where
  name := `godot
  descr := "Marks an opaque definition as a godot binding"
  add := fun declName stx kind => do
     match stx with
     | `(attr| godot $cname:str $[$id:ident]?) =>
        let env <- getEnv
        let some decl := env.find? declName
          | throwError "[godot] could not find declaration {declName}"
        let type := decl.type
        let id := id.map (·.getId.toString)

        let isType := match type with | .sort 1 => true | _ => false

        -- first, add extern bindings if it is not a type
        -- we will be generating a C file to implement these eventually
        if !isType then
            let externRes := externAttr.setParam (<- getEnv) declName ⟨
                  .none,
                  [.standard `all (LeanGodot.generateExternName declName)]
                ⟩
            let _ <- match externRes with
               | .ok env => setEnv env
               | .error s => throwError s
            -- if it is a type, then we expect an identifier  
            let .some _ := id
                | throwError "[godot] for declaration {declName} user did not provide a GodotFunctionType"

        -- second, extract binding metadata to track across the project
        let binding <- GodotBinding.make declName cname.getString type id
        modifyEnv (fun env => godotRegistryExt.addEntry env binding)
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
      logInfo m!"godot binding: {leanName} => {cname} : {repr type}"
| _ => throwUnsupportedSyntax

