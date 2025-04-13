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

inductive GodotBinding where
| Binding  (declName : Name) (cname: String) (type: GodotBindingType)
| Opaque (declName: Name) (cname: String)
deriving Inhabited, Repr


def GodotBinding.declName : GodotBinding -> Name
| .Binding declname _ _ => declname
| .Opaque declname _ => declname

def GodotBinding.cname : GodotBinding -> String
| .Binding _ cname _ => cname
| .Opaque _ cname => cname

instance : ToString GodotBinding where
   toString := fun
        | .Binding declName cname type => s!"GodotBinding({declName}->{cname} : {repr type})"
        | .Opaque declName _ => s!"GodotBindingOpaque({declName})"

