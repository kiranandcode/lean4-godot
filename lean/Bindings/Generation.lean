import Lean
import Bindings.Types
import Bindings.Utils
import Bindings.Extraction

abbrev TypeMap := Std.HashMap String (String × Int)

private def lean4_string_with_utf8_chars : GodotBindingType :=
  GodotBindingType.Function
   [("p_contents", GodotType.String, GodotBindingArgSpecifier.Borrowed)]
   (GodotType.Extern "GDString")
   true
   (GodotReturnTypeWrapper.IO)
   "GDExtensionInterfaceStringNewWithUtf8Chars"

private def lean4_get_native_struct_size : GodotBindingType :=
  GodotBindingType.Function
   [("p_name", GodotType.Extern "GDExtensionStringNamePtr", GodotBindingArgSpecifier.Borrowed)]
   (GodotType.Int false 64)
   false
   (GodotReturnTypeWrapper.None)
   "GDExtensionInterfaceGetNativeStructSize"


private def godot_ty_to_ctype : GodotType -> String
| .Unit => "void "
| .Extern _ => "lean_object *"
| .Bool => "int8_t "
| .Int .false sz => s!"uint{sz}_t "
| .Int .true sz => s!"int{sz}_t "
| .String => s!"lean_object *"

private def construct_out_ty : GodotType -> String
| .Unit => "void "
| .Extern _ => "void *"
| .Bool => "int8_t "
| .Int .false sz => s!"uint{sz}_t "
| .Int .true sz => s!"int{sz}_t "
| .String => s!"char *"


private def construct_binding_arg (params: String × GodotType × GodotBindingArgSpecifier) : Option String :=
   let ⟨name, ty, _⟩ := params
   if let .Unit := ty
   then .some s!"lean_object *{name}"
   else
     .some s!"{godot_ty_to_ctype ty}{name}"

private partial def gen_fresh_arg : String -> List String -> String :=
  fun param bound =>
    let rec loop cnt :=
       let param := s!"{param}{cnt}"
       if bound.contains param
       then loop (cnt + 1)
       else param
    if bound.contains param
    then loop 0
    else param

private def construct_return_arg_wrapper
   (ret_ty: GodotType) (wrapper: GodotReturnTypeWrapper) (resArg: String) : String :=
-- return values have to be wrapped before returning to match the 
-- return type if IO
   match wrapper with
-- if no wrapper, return as is
   | .None => resArg
   | .IO =>
-- first, box any scalars with a lean_box if needed
     let resExpr := match ret_ty with
        | .String | .Extern _ => resArg
        | .Int _ _ | .Bool => s!"lean_box({resArg})"
        | .Unit => "lean_box(0)"
-- then wrap in io
     s!"lean_io_result_mk_ok({resExpr})"

private def construct_function_binding
   (tyMap: TypeMap) (declName: Lean.Name) (cname: String) : GodotBindingType -> String
| .Type _ => ""
| .Function args ret_ty is_out wrapper fp_name => Id.run $ do
  let ret_ty_str := match wrapper with
     | .IO => "lean_object *"
     | .None => godot_ty_to_ctype ret_ty
  -- create a unique name for the c wrapper
  let fn_name := LeanGodot.generateExternName declName
  -- construct a string representing the parameters of the wrapper
  let argsStr :=
    ",".intercalate (args.filterMap construct_binding_arg)

  let mut stmts := #[]
  let mut boundArgs := args.map (·.fst)
  -- wrapper functions require the associated godot function pointer to have been retrieved
  -- start body with a sanity check:
  match wrapper with
  | .None => stmts := stmts.push s!"LEAN4_CHECK_FP_INIT_PURE({cname});"
  | .IO => stmts := stmts.push s!"LEAN4_CHECK_FP_INIT({cname});"

  -- generate an argument for the return value
  let resArg := gen_fresh_arg "res" <| boundArgs
  boundArgs := boundArgs.cons resArg

  -- for each argument in argument, need to unwrap from lean to C
  let callParams <- do
     let mut callParams := #[]
     for params in args do
        let ⟨name, ty, _⟩ := params
        match ty with
        | .Extern tyName =>
           let (tyName, _) := match tyMap.get? tyName with | .some v => v | .none => panic! s!"use of non-godot-declared type {tyName}"
           let tmpName := gen_fresh_arg s!"{name}_internal" <| boundArgs
           boundArgs := boundArgs.cons tmpName
           callParams := callParams.push tmpName
           -- extern class data retrieved by using lean_get_external_data
           stmts := stmts.push s!"{tyName} {tmpName} = ({tyName})lean_get_external_data({name});"
        | .String =>
           -- string parameters are extracted to cstrings
           let tmpName := gen_fresh_arg s!"{name}_internal" <| boundArgs
           boundArgs := boundArgs.cons tmpName
           callParams := callParams.push tmpName
           stmts := stmts.push s!"char *{tmpName} = (char *)lean_string_cstr({name});"
        | .Bool | .Int _ _ =>
          -- scalar parameters don't need to be unwrapped
          callParams := callParams.push name
        | .Unit => pure ()
     pure callParams
  -- now callParams are a new set of parameters which have been unwrapped
  -- emit a variable to represent the output
  let outArgs <- do
     -- if the output is returned via an &out parameter of the function, we assume it returns void
     if is_out
     then
     -- TODO: modify this to alloc memory void *{resArg} = malloc({sz})
       let outPty := construct_out_ty ret_ty
       let ⟨init,param⟩ <-
          match ret_ty with
          | .Extern name =>
            if let .some (_, sz) <- pure $ tyMap.get? name
            then
              pure (if sz > 0 then s!" = mem_alloc({sz})" else " = NULL", resArg)
            else panic! s!"use of unknown type {name}"
          | _ => pure ("", s!"&{resArg}")
       stmts := stmts.push s!"{outPty}{resArg}{init};";
       -- modify this to 
       pure [param]
     else
       pure []
  -- construct the function call
  let outArgs := ", ".intercalate (outArgs.append callParams.toList)
  if is_out then
    -- no need to ind the return value
    stmts := stmts.push  s!"{cname}({outArgs});"
  else
    -- same holds if return type is unit
    if let .Unit := ret_ty then
      stmts := stmts.push  s!"{cname}({outArgs});"
    else
      -- we want to construct a binding for the return type
      let outPty := construct_out_ty ret_ty
      stmts := stmts.push  s!"{outPty}{resArg} = {cname}({outArgs});"
   -- final component is the return:
  if let .Unit := ret_ty then
     -- if unit, our C function can just not have a return,
     match wrapper with
     | .None =>
        -- but only if it's not wrapped
        pure ()
     | .IO =>
        -- if it's an IO, then need a wrapper
        let retExpr := construct_return_arg_wrapper ret_ty wrapper resArg
        stmts := stmts.push s!"return {retExpr};"
  else
     -- otherwise, need to return something
     let resArg <- do
        match ret_ty with
        | .Extern ty =>
           -- if it's an opaque class, then good, just wrap in alloc external,
           -- introduce a new binding
           let (ty, _) := match tyMap.get? ty with | .some v => v | .none => panic! "use of non-godot-declared type {tyName}"
           let resArg' := gen_fresh_arg "res" boundArgs
           boundArgs := boundArgs.cons resArg'
           stmts :=
             stmts.push s!"lean_object *{resArg'} = lean_alloc_external(get_{ty}_class(), (void *){resArg});"
           pure resArg'
        | .String =>
            -- if it's a string, wrap appropriately
           let resArg' := gen_fresh_arg "res" boundArgs
           boundArgs := boundArgs.cons resArg'
           stmts :=
             stmts.push s!"lean_object *{resArg'} = lean_mk_string({resArg});"
           pure resArg'
        | .Unit | .Bool | .Int _ _ => pure resArg
     -- construct the final wrapper
     let retExpr := construct_return_arg_wrapper ret_ty wrapper resArg
     -- return
     stmts := stmts.push s!"return {retExpr};"

  let bodyStr := "\n\t".intercalate stmts.toList
  return s!"{fp_name} {cname} = NULL;
{ret_ty_str}{fn_name}({argsStr}) \{
\t{bodyStr}
}"

private def construct_function_binding_init (name: String) (ty: GodotBindingType) : String :=
  match ty with
  | .Type _ => ""
  | .Function _args _ret_ty _is_out _wrapper fp_name =>
    s!"{name} = ({fp_name})p_get_proc_address(\"{name}\");"

private def construct_extern_type_init (name: String) (ty: GodotBindingType) : String :=
  match ty with
  | .Function _args _ret_ty _is_out _wrapper _fp_name => ""
  | .Type _ =>
    s!"REGISTER_LEAN_CLASS({name}, generic_variant_finalizer, noop_foreach)
lean_object * lean_godot_{name}_default() \{
  return lean_mk_option_some(lean_alloc_external(get_{name}_class(), (void *)NULL));
}"


def buildTyMap (bindingData: Array GodotBinding) : TypeMap :=
   bindingData.filterMap (fun
   | .Binding decl cname (.Type sz) => .some (decl.toString, (cname, sz))
   | _ => .none
   )
   |>.toList
   |> Std.HashMap.ofList

def LeanGodot.constructTypeDeclarations (bindingData: Array GodotBinding) : String :=
   bindingData.filterMap (fun
   | .Binding _ cname type =>
     .some (construct_extern_type_init cname type)
   | _ => .none)
   |>.toList
   |> "\n".intercalate

def LeanGodot.constructFunctionDeclarations (tyMap: TypeMap) (bindingData: Array GodotBinding) : String :=
   bindingData.filterMap (fun
   | .Binding declName cname type =>
     .some (construct_function_binding tyMap declName cname type)
   | _ => .none
   )
   |>.toList
   |> "\n".intercalate

def LeanGodot.constructDeclarations (bindingData: Array GodotBinding) : String :=
  let tyMap := buildTyMap bindingData
  LeanGodot.constructTypeDeclarations bindingData ++ "\n" ++
  LeanGodot.constructFunctionDeclarations tyMap bindingData


def LeanGodot.constructFunctionInits (bindingData: Array GodotBinding) : String :=
   bindingData.filterMap (fun
     | .Binding _ cname type =>
       .some (construct_function_binding_init cname type)
     | _ => .none
   )
   |>.toList
   |> "\n".intercalate


-- #eval println! (construct_function_binding `of_string "string_new_with_utf8_chars" lean4_string_with_utf8_chars)

-- #eval println! (construct_function_binding `NativeStruct.size "get_native_struct_size" lean4_get_native_struct_size)

