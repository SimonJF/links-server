open Links_core
open Webserver

module BS = Basicsettings
module Eval = Evalir.Eval(Webserver)
module Webif = Webif.WebIf(Webserver)

type evaluation_env =   Value.env (* maps int identifiers to their values *)
                      * Ir.var Env.String.t (* map string identifiers to int identifiers *)
                      * Types.typing_environment (* typing info, using string identifiers *)

(** optimise and evaluate a program *)
let process_program
      (interacting : bool)
      (envs : evaluation_env)
      (program : Ir.program)
          : (Value.env * Value.t) Lwt.t =
  let (valenv, nenv, tyenv) = envs in
  let tenv = (Var.varify_env (nenv, tyenv.Types.var_env)) in

  let perform_optimisations = Settings.get_value BS.optimise && not interacting in

  let post_backend_pipeline_program =
    Backend.transform_program perform_optimisations tenv program in

  (if Settings.get_value BS.typecheck_only then exit 0);

 (*  Webserver.init (valenv, nenv, tyenv) globals external_files; *)
  Eval.run_program_as_thread valenv post_backend_pipeline_program

let die_on_exception f x =
  Errors.display ~default:(fun _ -> exit 1) (lazy (f x))

let die_on_exception_unless_interacting is_interacting f x =
  let handle exc =
    if is_interacting then
      raise exc
    else
      exit 1 in
  Errors.display ~default:handle (lazy (f x))


(* For non-REPL use only *)
module NonInteractive =
struct

  (* TODO: Remove special handling of prelude once module processing is in place *)
  let load_prelude () =
    let load_prelude_inner () =
      let open Loader in
      let source =
        (die_on_exception_unless_interacting false
          (Loader.load_file (Lib.nenv, Lib.typing_env)) (Settings.get_value BS.prelude_file))
      in
      let (nenv, tyenv) = source.envs in
      let (globals, _, _) = source.program in

      let tenv = (Var.varify_env (Lib.nenv, Lib.typing_env.Types.var_env)) in

      let globals = Backend.transform_prelude tenv globals in

      let valenv = Eval.run_defs Value.Env.empty globals in
      let envs =
        (valenv,
        Env.String.extend Lib.nenv nenv,
        Types.extend_typing_environment Lib.typing_env tyenv)
      in
        globals, envs
   in
   die_on_exception load_prelude_inner ()
end
