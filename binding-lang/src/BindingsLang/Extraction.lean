import Lean
import BindingsLang.Types
open Lean Meta Elab Command

def extractGodotType [Monad m] [MonadError m] (e: Expr) : m GodotType :=
  match e with
  | .const `Unit _ => return GodotType.Unit
  | .const `String _ => return GodotType.String
  | .const `Bool _ =>  return GodotType.Bool
  | .const name _ =>
     let tyName := name.toString
     -- handling of Int_ and UInt_
     if let .some sz := tyName.dropPrefix? "Int" |>.bind fun n => n.toNat? then
        return GodotType.Int true sz
     else if let .some sz := tyName.dropPrefix? "UInt" |>.bind fun n => n.toNat? then
        return GodotType.Int false sz       
     else
     -- default case
        return GodotType.Extern (name.toString)
  | _ => throwError "[extractGodotType] unsupported type {repr e}"

def extractGodotBinderType [Monad m] [MonadError m] (ty: Expr) : m (GodotType × GodotBindingArgSpecifier) := do
  match ty with
  | .mdata { entries := [(`borrowed, .ofBool true)]} exp => 
     let ty <- extractGodotType exp
     return (ty, .Borrowed)
  | ty => 
     let ty <- extractGodotType ty
     return (ty, .Owned)

def extractGodotReturnType [Monad m] [MonadError m] (ty: Expr) : m (GodotType × Bool) := do
  match ty with
  | .mdata { entries := [(`out, .ofBool true)]} exp => 
     let ty <- extractGodotType exp
     return (ty, true)
  | ty => 
     let ty <- extractGodotType ty
     return (ty, false)
   

def extractGodotBindingType [Monad m] [MonadError m] (e: Expr) (id: Option String) : m GodotBindingType :=
  let rec loop id acc (ty: Expr) : m GodotBindingType :=
      match ty with
      | .forallE name ty body _info => do
         let (.str .anonymous name) := name
           | throwError "[extractGodotBindingType] all bindings must be named"
         let ty <- extractGodotBinderType ty
         loop id (acc.cons (name, ty)) body
      | .app (.const `IO []) ty => do
         let (retTy, isOut) <- extractGodotReturnType ty
         return GodotBindingType.Function (acc.reverse) retTy isOut (.IO) id
      | .const _ _ | .mdata _ _ => do
         let (retTy, isOut) <- extractGodotReturnType ty
         return GodotBindingType.Function (acc.reverse) retTy isOut (.None) id
      | _ => throwError "[loop] invalid binding type {repr ty} (acc:={repr acc})"
  match e with
  | .sort 1 => pure GodotBindingType.Type
  | .forallE (name: Name) ty body _info => do
      let (.str .anonymous name) := name
         | throwError "[extractGodotBindingType] all bindings must be named"
      let .some id := id
         | throwError "[extractGodotBindingType] functionPointerName required for function bindings"
      let ty <- extractGodotBinderType ty
      loop id [(name, ty)] body
  | _ => throwError "[extractGodotBindingType] invalid binding type {e}"


def GodotBinding.make (decl: Name) (cname: String) (type: Expr) (id: Option String) : AttrM GodotBinding := do
   let type <- extractGodotBindingType type id
   return ⟨decl, cname, type⟩

