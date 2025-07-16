import Lean
import Lean.Meta
import Lean.Data.Json
import ExtensionAPI.Options
import ExtensionAPI.Types

def Lean.Json.getArrD (data: Lean.Json) : Array Lean.Json :=
  data.getArr?.toOption.getD #[]

def Lean.Json.getStrD (data: Lean.Json) : String :=
  data.getStr?.toOption.getD ""

def Lean.Json.getListD (data: Lean.Json) : List Lean.Json :=
  data.getArrD.toList

def Lean.Json.getBoolD (data: Lean.Json) : Bool :=
  data.getBool?.toOption.getD false

def Lean.Json.getIntD (data: Lean.Json) : Int :=
  data.getInt?.toOption.getD (-1)

def Lean.Syntax.mkBoolLit (bool: Bool) :=
   if bool
   then mkIdent `Bool.true
   else mkIdent `Bool.false

namespace ExtensionAPI.Json.private

scoped syntax "#extension_api.json" str : term
private partial def jsonToExpr : Lean.Json -> Lean.Meta.MetaM Lean.Expr := fun j =>
  open Lean in
  let LeanJson := (mkConst `Lean.Json)
  match j with
  | .null => pure $ mkConst `Lean.Json.null
  | .bool b => pure $ mkApp (mkConst `Lean.Json.bool) (mkConst (if b then `Bool.true else `Bool.false))
  | .num n =>
     pure $ mkApp (mkConst `Lean.Json.num) <|
        mkApp2 (mkConst `Lean.JsonNumber.mk)
          (mkIntLit n.mantissa)
          (mkNatLit n.exponent)
  | .str s => pure $ mkApp (mkConst `Lean.Json.str) (mkStrLit s)
  | .arr (elems : Array Json) => do
     let elems <- elems.toList.mapM jsonToExpr
     let args <- Meta.mkArrayLit LeanJson elems
     pure $ mkApp (mkConst `Lean.Json.arr) args
  | .obj (kvPairs : RBNode String (fun _ => Json)) => do
    let kvPairs : List (String × Lean.Json) :=
      Lean.RBNode.toArray kvPairs
      |>.toList
      |>.map (fun pair => (pair.fst, pair.snd))

    let StringTy := mkConst `String
    let stringLvl <- Meta.getDecLevel StringTy
    let jsonLvl <- Meta.getDecLevel LeanJson

    let kvPairs <- kvPairs.mapM (fun pair => do
       let snd <- jsonToExpr pair.snd
       pure $ mkApp4 (mkConst `Prod.mk [stringLvl, jsonLvl])
          StringTy LeanJson
          (mkStrLit pair.fst)
          snd
       )

    let StringxJson := mkApp2 (mkConst `Prod [stringLvl, jsonLvl]) StringTy LeanJson
    let elems <- (Meta.mkListLit StringxJson kvPairs)
    pure $ mkApp (mkConst `Lean.Json.mkObj) elems

def load_extension_api_data : Lean.Meta.MetaM Lean.Json := do 
   let contents <- IO.FS.readFile "godot-headers/extension_api.json"
   let res <- match Lean.Json.parse contents with
      | .ok res => pure res
      | .error e => throwError e

elab_rules : term
| `(term| #extension_api.json $field:str ) => do
   let x := godot.build_configuration.get (<- Lean.MonadOptions.getOptions)
   dbg_trace s!"{x.toString}"

   let res <- load_extension_api_data
   let res := Lean.Json.getObjValD res field.getString
   let expr := jsonToExpr res
   expr


def retrieve_matching_build (data: Lean.Json) : Lean.Meta.MetaM Lean.Json := do
     let buildConfig := godot.build_configuration.get (<- Lean.MonadOptions.getOptions)
     let buildConfig := Lean.Json.str buildConfig.toString
     data.getArr?.toOption.getD #[]
     |>.find? (fun v => v.getObjValD "build_configuration" == buildConfig)
     |>.getM

def make_static_hashmap (sizes: List (Lean.TSyntax `term × Lean.TSyntax `term)) : Lean.Meta.MetaM (Lean.TSyntax `term) := do
   let sizes <- sizes.mapM (fun ⟨name, size⟩ => `(($name,$size)))
   let sizes := Lean.Syntax.TSepArray.ofElems sizes.toArray
   `(term| Std.HashMap.ofList [$sizes,*])

abbrev ExtractionFunction := Lean.Json -> Lean.Meta.MetaM (Lean.TSyntax `term)

def extract_str_field (field: String) : ExtractionFunction := fun obj => do
    let term := obj.getObjValD field |>.getStrD |> Lean.Syntax.mkStrLit
    `(term| $term)

def extract_int_field (field: String) : ExtractionFunction := fun obj => do
    let term := obj.getObjValD field |>.getIntD |>.repr |> Lean.Syntax.mkNumLit
    `(term| $term)


def extract_keyed_map_using (extract: ExtractionFunction) : ExtractionFunction := fun obj => do
  let keyed_map <- obj |>.getListD
       |>.mapM (fun obj => do
          let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
          let operator <- extract obj
          pure (<- `(term| $name), <- `(term| $operator)))
  make_static_hashmap keyed_map

def extract_function : ExtractionFunction := fun obj => do
  let return_type <-
      if let .some rety := obj.getObjVal? "return_type" |>.toOption
      then rety |>.getStrD |> Lean.Syntax.mkStrLit |> (fun stx => `(term| Option.some $stx))
      else if let .some rety := obj.getObjVal? "return_value" |>.toOption
      then rety|>.getObjValD "type" |>.getStrD
           |> Lean.Syntax.mkStrLit |> (fun stx => `(term| Option.some $stx))
      else `(term| Option.none)
  let category := obj.getObjValD "category" |>.getStrD |> Lean.Syntax.mkStrLit
  let is_vararg := obj.getObjValD "is_vararg" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let is_const := obj.getObjValD "is_const" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let is_static := obj.getObjValD "is_static" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let is_virtual := obj.getObjValD "is_virtual" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let hash := obj.getObjValD "hash" |>.getIntD |>.toNat |> Lean.Syntax.mkNatLit
  let arguments <- obj.getObjValD "arguments" |>.getListD
      |>.mapM (fun obj => do
          let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
          let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
          `(term| ExtensionAPI.Types.FunctionArgument.mk $name $type)
      )
  let arguments := Lean.Syntax.TSepArray.ofElems arguments.toArray
  pure (
     <- `(term|
           ExtensionAPI.Types.Function.mk
             $return_type $category $is_vararg $is_const $is_static $is_virtual $hash [$arguments,*]
           ))

def extract_function_argument : ExtractionFunction := fun obj => do
  let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
  let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
  `(term| ExtensionAPI.Types.FunctionArgument.mk $name $type)

def extract_enum : ExtractionFunction := fun obj => do
  let is_bitfield := obj.getObjValD "is_bitfield" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let values <- obj.getObjValD "values" |>.getListD
     |>.mapM (fun obj => do
         let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
         let value := obj.getObjValD "value" |>.getIntD |>.toNat |> Lean.Syntax.mkNatLit
         pure (<- `(term| $name), <- `(term| $value))
     )
  let values <- make_static_hashmap values
  `(term| ExtensionAPI.Types.Enum.mk $is_bitfield $values)

def extract_member_offset_map : ExtractionFunction := fun obj => do
  let members <- obj.getObjValD "members" |>.getListD
      |>.mapM (fun obj => do
           let member := obj.getObjValD "member" |>.getStrD |> Lean.Syntax.mkStrLit
           let offset := obj.getObjValD "offset" |>.getIntD |>.repr |> Lean.Syntax.mkNumLit
           let meta := obj.getObjValD "meta" |>.getStrD |> Lean.Syntax.mkStrLit
           pure (<- `(term| $member), <- `(term| ExtensionAPI.Types.MemberOffset.mk $offset $meta))
      )
  let members <- make_static_hashmap members
  `(term| $members)

def extract_constant: ExtractionFunction := fun obj =>
  let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
  let value := obj.getObjValD "value" |>.getStrD |> Lean.Syntax.mkStrLit
  `(term| ExtensionAPI.Types.Constant.mk $type $value)

def extract_property: ExtractionFunction := fun obj =>
  let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
  let setter := obj.getObjValD "setter" |>.getStrD |> Lean.Syntax.mkStrLit
  let getter := obj.getObjValD "getter" |>.getStrD |> Lean.Syntax.mkStrLit
  `(term| ExtensionAPI.Types.Property.mk $type $setter $getter)

def extract_operator : ExtractionFunction := fun obj => do
  let right_type := obj.getObjValD "right_type" |>.getStrD |> Lean.Syntax.mkStrLit
  let return_type := obj.getObjValD "return_type" |>.getStrD |> Lean.Syntax.mkStrLit
  `(term| ExtensionAPI.Types.Operator.mk $right_type $return_type)

def extract_constructor : ExtractionFunction := fun obj => do
  let index := obj.getObjValD "index" |>.getIntD |>.toNat |> Lean.Syntax.mkNatLit
  let arguments <- obj.getObjValD "arguments" |>.getListD
     |>.mapM (fun obj => 
         let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
         let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
         `(term| ExtensionAPI.Types.FunctionArgument.mk $name $type)
     )
  let arguments := Lean.Syntax.TSepArray.ofElems arguments.toArray
  `(term| ExtensionAPI.Types.Constructor.mk $index [$arguments,*])

def extract_signal_arguments : ExtractionFunction := fun obj => do
  let arguments <- obj.getObjValD "arguments" |>.getListD
     |>.mapM (fun obj => 
         let name := obj.getObjValD "name" |>.getStrD |> Lean.Syntax.mkStrLit
         let type := obj.getObjValD "type" |>.getStrD |> Lean.Syntax.mkStrLit
         `(term| ExtensionAPI.Types.FunctionArgument.mk $name $type)
     )
  let arguments := Lean.Syntax.TSepArray.ofElems arguments.toArray
  `(term| [$arguments,*])

def extract_builtin_class (obj: Lean.Json) : Lean.Meta.MetaM (Lean.TSyntax `term) := do
  let indexing_return_type <-
     obj.getObjVal? "indexing_return_type" |>.toOption
     |>.map (·.getStrD |> Lean.Syntax.mkStrLit)
     |>.map (fun stx => `(term| Option.some $stx))
     |>.getD (`(term| Option.none))
  let is_keyed := obj.getObjValD "is_keyed" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let members <- obj.getObjValD "members" |> extract_keyed_map_using (extract_str_field "type")
  let constants <- obj.getObjValD "constants" |> extract_keyed_map_using extract_constant
  let enums <- obj.getObjValD "enums" |> extract_keyed_map_using extract_enum
  let operators <- obj.getObjValD "operators" |> extract_keyed_map_using extract_operator
  let constructors <- obj.getObjValD "constructors" |>.getListD
       |>.mapM extract_constructor
  let constructors := Lean.Syntax.TSepArray.ofElems constructors.toArray
  let methods <- obj.getObjValD "methods" |> extract_keyed_map_using extract_function
  let has_destructor := obj.getObjValD "has_destructor" |>.getBoolD |> Lean.Syntax.mkBoolLit

  `(term|
        ExtensionAPI.Types.BuiltinClass.mk
           $indexing_return_type $is_keyed $members $constants $enums $operators [$constructors,*] $methods $has_destructor
    )

def extract_class (obj: Lean.Json) : Lean.Meta.MetaM (Lean.TSyntax `term) := do
  let is_refcounted := obj.getObjValD "is_refcounted" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let is_instantiable := obj.getObjValD "is_instantiable" |>.getBoolD |> Lean.Syntax.mkBoolLit
  let inherits := obj.getObjValD "inherits" |>.getStrD |> Lean.Syntax.mkStrLit
  let api_type := obj.getObjValD "api_type" |>.getStrD |> Lean.Syntax.mkStrLit
  let constants <- obj.getObjValD "constants" |> extract_keyed_map_using (fun obj => do
     let value := obj.getObjValD "value" |>.getIntD |>.repr |> Lean.Syntax.mkStrLit
     `(term| $value)
  )
  let enums <-  obj.getObjValD "enums" |> extract_keyed_map_using extract_enum
  let methods <- obj.getObjValD "methods" |> extract_keyed_map_using extract_function
  let signals <- obj.getObjValD "signals" |> extract_keyed_map_using extract_signal_arguments
  let properties <- obj.getObjValD "properties" |> extract_keyed_map_using extract_property
  `(term|
        ExtensionAPI.Types.Class.mk
           $is_refcounted $is_instantiable $inherits $api_type $constants $enums $methods $signals $properties
    )



scoped syntax "def_godot_api" ident : command
open Lean.Elab.Command
elab_rules : command
| `(command| def_godot_api $id:ident ) => open Lean.Syntax in do
   match id.getId.toString with
   | "classes" =>
       let builtin_classes <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          return extension_api_data.getObjValD "classes"
       let classes <- liftTermElabM $ builtin_classes |> extract_keyed_map_using extract_class
       elabCommand (<- `(command| def $id : Std.HashMap String ExtensionAPI.Types.Class := $classes))
   | "builtin_classes" =>
       let builtin_classes <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          return extension_api_data.getObjValD "builtin_classes"
       let builtin_classes <- liftTermElabM $ builtin_classes |> extract_keyed_map_using extract_builtin_class
       elabCommand (<- `(command| def $id : Std.HashMap String ExtensionAPI.Types.BuiltinClass := $builtin_classes))
   | "utility_functions" =>
       let utility_functions <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          return extension_api_data.getObjValD "utility_functions"
       let utility_functions_map <- liftTermElabM $ utility_functions |> extract_keyed_map_using extract_function
       elabCommand (<- `(command| def $id : Std.HashMap String ExtensionAPI.Types.Function := $utility_functions_map))
   | "global_enums" =>
       let global_enums <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          return extension_api_data.getObjValD "global_enums"
       let enum_map <- liftTermElabM $ global_enums |> extract_keyed_map_using extract_enum
       elabCommand (<- `(command| def $id : Std.HashMap String ExtensionAPI.Types.Enum := $enum_map))
   | "builtin_class_sizes" =>
       let builtin_class_sizes <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          retrieve_matching_build (extension_api_data.getObjValD "builtin_class_sizes")
       let size_map <- liftTermElabM $ builtin_class_sizes.getObjValD "sizes" |> extract_keyed_map_using (extract_int_field "size")
       elabCommand (<- `(command| def $id : Std.HashMap String Int := $size_map))
   | "builtin_class_member_offsets" =>
       let builtin_class_member_offsets <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          retrieve_matching_build (extension_api_data.getObjValD "builtin_class_member_offsets")
       let member_offset_map <- liftTermElabM $
          builtin_class_member_offsets.getObjValD "classes"
          |> extract_keyed_map_using extract_member_offset_map
       elabCommand (<- `(command| def $id := $member_offset_map))
   | "singletons" =>
       let singletons <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          pure (extension_api_data.getObjValD "singletons")
       let singletons <- liftTermElabM $ singletons |> extract_keyed_map_using (extract_str_field "type")
       elabCommand (<- `(command| def $id : Std.HashMap String String := $singletons))
   | "native_structures" =>
       let native_structures <- liftTermElabM $ do
          let extension_api_data <- load_extension_api_data
          pure (extension_api_data.getObjValD "native_structures")
       let native_structures <- liftTermElabM $ native_structures |> extract_keyed_map_using (extract_str_field "format")
       elabCommand (<- `(command| def $id : Std.HashMap String String := $native_structures))

   | _ => throwError "unsupported {id}"

set_option maxHeartbeats 1000000
def_godot_api builtin_class_sizes
def_godot_api builtin_class_member_offsets
def_godot_api global_enums
def_godot_api utility_functions
-- def_godot_api builtin_classes
-- def_godot_api classes
def_godot_api singletons
def_godot_api native_structures

end ExtensionAPI.Json.private

namespace ExtensionAPI.Json
open ExtensionAPI.Json.private

def builtin_class_sizes := ExtensionAPI.Json.private.builtin_class_sizes
def builtin_class_member_offsets := ExtensionAPI.Json.private.builtin_class_member_offsets
def global_enums := ExtensionAPI.Json.private.global_enums
def utility_functions := ExtensionAPI.Json.private.utility_functions
-- def builtin_classes := ExtensionAPI.Json.private.builtin_classes
-- def classes := ExtensionAPI.Json.private.classes
def singletons := ExtensionAPI.Json.private.singletons
def native_structures := ExtensionAPI.Json.private.native_structures

end ExtensionAPI.Json
