import Lean.Elab
import Bindings

namespace Godot

structure Version where
  major: UInt32
  minor: UInt32
  patch: UInt32
  string: String
deriving Repr, Ord, BEq

@[extern "lean4_get_version"]
opaque version : Unit -> IO Version
end Godot
