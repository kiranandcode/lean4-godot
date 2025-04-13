import Lean
import Bindings.Types
import Bindings.Utils
import Bindings.Extraction
import Bindings.Generation
open Lean Meta Elab Command

-- private def LeanGodot.onlyBindings := `godot.onlyBindings
-- def LeanGodot.onlyBindings? [Monad m] [MonadOptions m] : m Bool := do
--    let opts <- getOptions
--    return opts.getBool LeanGodot.onlyBindings

-- initialize registerOption LeanGodot.onlyBindings {
--     defValue := false
--   }

initialize godotRegistryExt : SimplePersistentEnvExtension GodotBinding (List GodotBinding) ←
  registerSimplePersistentEnvExtension {
    name := `godotRegistryExt
    addEntryFn := (·.cons)
    addImportedFn := fun arr => arr.toList.flatMap (·.toList)
    toArrayFn := fun es => es.toArray
  }

def getGodotBindings (env : Environment) : List GodotBinding :=
  godotRegistryExt.getState env

def findGodotType [Monad m] [MonadEnv m] [MonadError m] (decl: Name) : m String := do
  let env <- getEnv
  let res := godotRegistryExt.getState env
         |>.toArray
         |> buildTyMap
         |>.get? decl.toString
  match res with
  | .some res => return res
  | .none => throwError s!"reference to {decl.toString} which was not declared as a GodotType"



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


def GodotBinding.declareExtern [Monad m] [MonadError m] [MonadEnv m] (binding : GodotBinding) : m Unit := do
  let (declName, cname) :=
       match binding with
       | .Opaque declName cname => (declName, cname)
       | .Binding declName _ _ => (declName, LeanGodot.generateExternName declName)
  let externRes := externAttr.setParam (<- getEnv) declName ⟨
        .none,
        [.standard `all cname]
      ⟩
  let _ <- match externRes with
     | .ok env => setEnv env
     | .error s => throwError s

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

        -- first extract binding metadata to track across the project
        let binding <- GodotBinding.make declName cname.getString type id

        -- second, add extern bindings if it is not a type
        if !isType then
            binding.declareExtern
        -- we will be generating a C file to implement these eventually
        -- update env with binding
        modifyEnv (fun env => godotRegistryExt.addEntry env binding)
        let env <- getEnv
        -- logInfo m!"[godotAttr] registering {declName} => {getGodotBindings env}"
     | _ =>
       throwError "invalid godot attribute syntax, expected @[godot \"c_name\"]"
  applicationTime := .afterTypeChecking
initialize registerBuiltinAttribute godotAttrImpl

syntax (name := godotInhabited) "godot_inhabited_type " ident : command
@[command_elab godotInhabited]
elab_rules : command
| `(command| godot_inhabited_type $tyNameRaw:ident) => do
    let bindings <- resolveGlobalName tyNameRaw.getId
    if bindings.isEmpty then
       throwError s!"reference to undefined type ${tyNameRaw}"
    let (tyName, _) <- pure bindings.head!
    let mkDefault := Name.str tyName "mkDefault"
    let name <- findGodotType tyName
    let binding := TSyntax.mk (Syntax.mkStrLit s!"lean_godot_{name}_default")
    let mkDefault := mkIdent mkDefault
    elabCommand (<- `(command|
       @[extern $binding:str]
       opaque $mkDefault:ident : Unit -> Option $tyNameRaw
    ))
    elabCommand (<- `(command|
       instance : Inhabited $tyNameRaw where
          default := match $mkDefault:ident () with | .some v => v | .none => sorry
    ))

syntax (name := godotOpaque) (Parser.Command.visibility)? "godot_opaque" ident " : " term " := " str : command

private def evalCommandAndBindOpaque (declName: TSyntax `ident) (cmd: TSyntax `str) (stx: TSyntax `command) : CommandElabM Unit := do
   elabCommand stx
   let expr <- liftTermElabM (Term.elabIdent declName .none)
   let declName := expr.constName!
   let binding := GodotBinding.makeOpaque declName cmd.getString
   binding.declareExtern
   modifyEnv (fun env => godotRegistryExt.addEntry env binding)


@[command_elab godotOpaque]
elab_rules : command
| `(command| godot_opaque $expr:ident : $ty:term := $cmd:str) => do
   let stx <- `(command| opaque $expr : $ty)
   evalCommandAndBindOpaque expr cmd stx
| `(command| private godot_opaque $expr:ident : $ty:term := $cmd:str) => do
   let stx <- `(command| private opaque $expr : $ty)
   evalCommandAndBindOpaque expr cmd stx
| `(command| protected godot_opaque $expr:ident : $ty:term := $cmd:str) => do
   let stx <- `(command| protected opaque $expr : $ty)
   evalCommandAndBindOpaque expr cmd stx

open Term

syntax (name := godotDeclareExterns) "#declareGodotExterns" : command
@[command_elab godotDeclareExterns]
elab_rules : command
| `(command| #declareGodotExterns) => do
   let env <- getEnv
   let entries := getGodotBindings env
   for entry in entries do
      GodotBinding.declareExtern entry

syntax (name := godotDeclarations) "#GenGodotDeclarations" : term
@[term_elab godotDeclarations]
def elabGodotDeclarations : TermElab
| `(#GenGodotDeclarations) => fun _ => do
    let env ← getEnv
    let entries := getGodotBindings env
    return mkStrLit (LeanGodot.constructDeclarations entries.toArray)
| _ => fun _ => throwUnsupportedSyntax

syntax (name := godotFunctionInits) "#GenGodotInits" : term
@[term_elab godotFunctionInits]
def elabGodotInits : TermElab
| `(#GenGodotInits) => fun _ => do
    let env ← getEnv
    let entries := getGodotBindings env
    return mkStrLit (LeanGodot.constructFunctionInits entries.toArray)
| _ => fun _ => throwUnsupportedSyntax

