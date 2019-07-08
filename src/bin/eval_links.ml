open Links_core
open Links_core.Utility
open Links_core.Sugartypes
open Lwt

(* Parses a string and returns a Links expression *)
(* TODO: Exception handling *)
let parse str =
  Parse.parse_string Parse.program str

(* Takes a REPL string and produces a pair of perhaps a Links value (in the case of an expression)
 * and updated environments. *)
(* Mostly lifted from bin/repl.ml *)
let evaluate str envs : Driver.evaluation_result Lwt.t =
  let open Driver in
  (* Begin by parsing the string *)
  let expr, pos_context = parse str in
  (* Split initial environments *)
  let (_, nenv, tyenv) = envs in
  (* Put the program through the frontend *)
  let (program, program_ty, tyenv'), _ =
    Frontend.Pipeline.program tyenv pos_context expr in
  (* Do... some magic? *)
  let tenv = Var.varify_env (nenv, tyenv.Types.var_env) in
  (* Desugar the program into an IR program*)
  let globals, (locals, main), nenv' =
    Sugartoir.desugar_program (nenv, tenv, tyenv.Types.effect_row) program in

  let program = (globals @ locals, main) in
  Driver.process_program true envs program [] >>= fun (valenv, v) ->
  Lwt.return
  {
    result_env = (valenv,
      Env.String.extend nenv nenv',
      Types.extend_typing_environment tyenv tyenv');
    result_value = v;
    result_type = program_ty
  }

let init () =
  let (globals, envs) = Driver.NonInteractive.load_prelude () in
  (globals, envs)
