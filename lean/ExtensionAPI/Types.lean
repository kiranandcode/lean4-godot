import Lean

namespace ExtensionAPI.Types

structure MemberOffset where
   offset: Int
   meta: String
deriving Repr, BEq

structure Enum where
  is_bitfield: Bool
  values: Std.HashMap String Int
deriving Repr

structure Constant where
  type: String
  value: String
deriving Repr


structure FunctionArgument where
   name: String
   type: String
deriving Repr, BEq

structure Function where
  return_type: Option String
  category: String
  is_vararg: Bool
  is_const: Bool
  is_static: Bool
  is_virtual: Bool
  hash: Nat
  arguments: List FunctionArgument
deriving Repr, BEq

structure Operator where
  right_type: String
  return_type: String
deriving Repr, BEq

structure Constructor where
  index: Nat
  arguments: List FunctionArgument
deriving Repr, BEq

structure BuiltinClass where
  indexing_return_type: Option String
  is_keyed: Bool
  members: Std.HashMap String String
  constants: Std.HashMap String Constant
  enums: Std.HashMap String Enum

  operators: Std.HashMap String Operator
  constructors: List Constructor
  methods: Std.HashMap String Function
  has_destructor: Bool
deriving Repr

structure Property where
   type: String
   setter: String
   getter: String
deriving Repr

structure Class where
  is_refcounted: Bool
  is_instantiable: Bool
  inherits: String
  api_type: String
  constants: Std.HashMap String String
  enums: Std.HashMap String Enum
  methods: Std.HashMap String Function
  signals: Std.HashMap String (List FunctionArgument)
  properties: Std.HashMap String Property
deriving Repr



end ExtensionAPI.Types
