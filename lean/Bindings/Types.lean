import Lean
open Lean Meta Elab Command

inductive GodotType where
| Extern (name: String)
| String
| Int (signed: Bool) (sz: Nat)
| Bool
| Unit
deriving Inhabited, Repr

inductive GodotReturnTypeWrapper where
| None
| IO
deriving Inhabited, Repr

inductive GodotBindingArgSpecifier where
| Owned
| Borrowed
deriving Inhabited, Repr

inductive GodotBindingType where
| Type
| Function
   (args: List (String × GodotType × GodotBindingArgSpecifier))
   (retTy: GodotType)
   (isOut: Bool)
   (wrapper: GodotReturnTypeWrapper)
   (fpType: String)

deriving Inhabited, Repr

structure GodotBinding where
  declName : Name
  cname    : String
  type: GodotBindingType
deriving Inhabited, Repr

instance : ToString GodotBinding where
   toString := fun ⟨declName, cname, type⟩ => s!"GodotBinding({declName}->{cname} : {repr type})"

