import Lean
import BindingsLang.Types
import BindingsLang.Utils
import BindingsLang.Extraction

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


private def construct_binding_arg (params: String × GodotType × GodotBindingArgSpecifier) : String :=
   let ⟨name, ty, _⟩ := params
   s!"{godot_ty_to_ctype ty}{name}"

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
   match wrapper with
   | .None => resArg
   | .IO =>
     let resExpr := match ret_ty with
        | .String | .Extern _ => resArg
        | .Int _ _ | .Bool => s!"lean_box({resArg})"
        | .Unit => "lean_box(0)"
     s!"lean_io_result_mk_ok({resExpr})"

private def construct_function_binding (declName: Lean.Name) (cname: String) : GodotBindingType -> String
| .Type => ""
| .Function args ret_ty is_out wrapper fp_name => Id.run $ do
  let ret_ty_str := match wrapper with
     | .IO => "lean_object *"
     | .None => godot_ty_to_ctype ret_ty
  let fn_name := LeanGodot.generateExternName declName
  let argsStr :=
    ",".intercalate (args.map construct_binding_arg)
  let mut stmts := #[]
  let mut boundArgs := args.map (·.fst)
  stmts := stmts.push s!"LEAN4_CHECK_FP_INIT({cname});"

  let resArg := gen_fresh_arg "res" <| boundArgs
  boundArgs := boundArgs.cons resArg

  let callParams <- do
     let mut callParams := #[]
     for params in args do
        let ⟨name, ty, _⟩ := params
        match ty with
        | .Extern tyName =>
           let tmpName := gen_fresh_arg s!"{name}_internal" <| boundArgs
           boundArgs := boundArgs.cons tmpName
           callParams := callParams.push tmpName
           stmts := stmts.push s!"{tyName} {tmpName} = ({tyName})lean_get_external_data({name});"
        | .String =>
           let tmpName := gen_fresh_arg s!"{name}_internal" <| boundArgs
           boundArgs := boundArgs.cons tmpName
           callParams := callParams.push tmpName
           stmts := stmts.push s!"char *{tmpName} = lean_string_cstr({name});"
        | .Bool | .Int _ _ | .Unit =>
          callParams := callParams.push name
     pure callParams
        
  let outArgs <- do
     if is_out
     then
       let outPty := construct_out_ty ret_ty
       stmts := stmts.push s!"{outPty}{resArg};";
       pure [s!"&{resArg}"]
     else
       pure []

  let outArgs := ", ".intercalate (outArgs.append callParams.toList)
  if is_out then
    stmts := stmts.push  s!"{cname}({outArgs});"
  else
    if let .Unit := ret_ty then
      stmts := stmts.push  s!"{cname}({outArgs});"
    else
      let outPty := construct_out_ty ret_ty
      stmts := stmts.push  s!"{outPty}{resArg} = {cname}({outArgs});"
  if let .Unit := ret_ty then pure ()
  else
     let resArg <- do
        match ret_ty with
        | .Extern ty =>
           let resArg' := gen_fresh_arg "res" boundArgs
           boundArgs := boundArgs.cons resArg'
           stmts :=
             stmts.push s!"lean_object *{resArg'} = lean_alloc_external(get_{ty}_class(), (void *){resArg});"
           pure resArg'
        | .String =>
           let resArg' := gen_fresh_arg "res" boundArgs
           boundArgs := boundArgs.cons resArg'
           stmts :=
             stmts.push s!"lean_object *{resArg'} = lean_mk_string({resArg});"
           pure resArg'
        | .Unit | .Bool | .Int _ _ => pure resArg

     let retExpr := construct_return_arg_wrapper ret_ty wrapper resArg
     stmts := stmts.push s!"return {retExpr};"

  let bodyStr := "\n\t".intercalate stmts.toList
  return s!"{fp_name} {cname} = NULL;
{ret_ty_str}{fn_name}({argsStr}) \{
\t{bodyStr}
}"

private def construct_function_binding_init (name: String) (ty: GodotBindingType) : String :=
  match ty with
  | .Type => ""
  | .Function _args _ret_ty _is_out _wrapper fp_name =>
    s!"{name} = ({fp_name})p_get_proc_address(\"{name}\");"

private def construct_extern_type_init (name: String) (ty: GodotBindingType) : String :=
  match ty with
  | .Function _args _ret_ty _is_out _wrapper _fp_name => ""
  | .Type =>
    s!"static void lean_godot_{name}_finalizer(void *_obj) \{};
REGISTER_LEAN_CLASS({name}, lean_godot_{name}_finalizer, noop_foreach)"

def LeanGodot.constructTypeDeclarations (bindingData: Array GodotBinding) : String :=
   bindingData.map (fun binding =>
     construct_extern_type_init binding.cname binding.type
   )
   |>.toList
   |> "\n".intercalate

def LeanGodot.constructFunctionDeclarations (bindingData: Array GodotBinding) : String :=
   bindingData.map (fun binding =>
     construct_function_binding binding.declName binding.cname binding.type
   )
   |>.toList
   |> "\n".intercalate

def LeanGodot.constructDeclarations (bindingData: Array GodotBinding) : String :=
  LeanGodot.constructTypeDeclarations bindingData ++ "\n" ++
  LeanGodot.constructFunctionDeclarations bindingData


def LeanGodot.constructFunctionInits (bindingData: Array GodotBinding) : String :=
   bindingData.map (fun binding =>
     construct_function_binding_init binding.cname binding.type
   )
   |>.toList
   |> "\n".intercalate


-- #eval println! (construct_function_binding `of_string "string_new_with_utf8_chars" lean4_string_with_utf8_chars)

-- #eval println! (construct_function_binding `NativeStruct.size "get_native_struct_size" lean4_get_native_struct_size)

