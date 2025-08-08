import Lean
import LeanGodot.String
import LeanGodot.BuiltinTypes
import LeanGodot.GlobalEnums

namespace Godot
inductive VariantType : Type -> Type where
| Nil : VariantType Unit
| Bool : VariantType Bool
| Int : VariantType Int32
| Float : VariantType Float
| String : VariantType String

| Vector2 : VariantType Vector2
| Vector2i : VariantType Vector2i
| Rect2 : VariantType Rect2
| Rect2i : VariantType Rect2i
| Vector3 : VariantType Vector3
| Vector3i : VariantType Vector3i
| Transform2D : VariantType Transform2D
| Vector4 : VariantType Vector4
| Vector4i : VariantType Vector4i
| Plane : VariantType Plane
| Quaternion : VariantType Quaternion
| AABB : VariantType AABB
| Basis : VariantType Basis
| Transform3D : VariantType Transform3D
| Projection : VariantType Projection

| Color : VariantType Color
| StringName : VariantType StringName
| NodePath : VariantType NodePath
| RID : VariantType RID
| Object : VariantType Godot.Variant
| Callable : VariantType Callable
| Signal : VariantType Signal
| Dictionary : VariantType Dictionary
| Array : VariantType Array
| PackedByteArray : VariantType PackedByteArray
| PackedInt32Array : VariantType PackedInt32Array
| PackedInt64Array : VariantType PackedInt64Array
| PackedFloat32Array : VariantType PackedFloat32Array
| PackedFloat64Array : VariantType PackedFloat64Array
| PackedStringArray : VariantType PackedStringArray
| PackedVector2Array : VariantType PackedVector2Array
| PackedVector3Array : VariantType PackedVector3Array
| PackedColorArray : VariantType PackedColorArray

structure OpaqueVariantType where
   ty: Type
   tag: VariantType ty

abbrev mkFuncTypeK : List OpaqueVariantType -> Type -> Type
| [] => fun ty => ty
| ⟨ ty, _ ⟩ :: rest => fun rty => ty -> (mkFuncTypeK rest) rty

abbrev mkMethodType (SelfType: Type) (retTy: OpaqueVariantType) (args: List OpaqueVariantType) : Type :=
   let ⟨ty, _⟩ := retTy
   SelfType -> mkFuncTypeK args (IO ty)
    
structure Method (SelfType: Type) where
  args: OArray OpaqueVariantType
  retTy : OpaqueVariantType
  func: mkMethodType SelfType retTy args.toList


structure PropertyInfo (T: Type) where
  type: VariantType T
  name: OString
  className: OString
  hint: Godot.Enums.PropertyHint
  hintString: OString
  usage: Godot.Enums.PropertyUsageFlags

structure OpaquePropertyInfo where
  ty: Type
  info: PropertyInfo ty

structure MethodInfo (SelfType: Type) where
  name: OString
  method: Method SelfType
  methodFlags: Godot.Enums.ClassMethodFlags
  returnValueInfo: Option (PropertyInfo method.retTy.ty)
  argInfo: OArray OpaquePropertyInfo

  

#check Godot.Enums.PropertyHint

def exampleMethodFunc (self: IO.Ref Int) (vl: Int32) (v1 v2 : Bool) : IO Unit := do
      let vl <- self.get
      self.set (vl + 1)
      println! "input was {vl} {v1} {v2}";
      return ()

def x := IO.Ref

def exampleMethod : Method (IO.Ref Int) :=
  Method.mk
   #[({ ty := Int32, tag := VariantType.Int  }),
     ({ ty := Bool, tag := VariantType.Bool  }),
     ({ ty := Bool, tag := VariantType.Bool  })]
     (⟨ Unit, VariantType.Nil ⟩)
   (exampleMethodFunc)


end Godot
  
