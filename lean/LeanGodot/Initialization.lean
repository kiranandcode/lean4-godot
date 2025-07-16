import Lean.Elab
import Bindings

namespace Godot
namespace Initialization
-- GDExtensionInitializationLevel
inductive Level where
| CORE
| SERVERS
| SCENE
| EDITOR
| LEVEL
deriving Repr, Ord, BEq
end Initialization 
end Godot
