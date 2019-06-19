open Links_core
open Links_core.Utility
open Links_core.Sugartypes

(* Parses a string and returns a Links expression *)
(* TODO: Exception handling *)
let parse str =
  Parse.parse_string Parse.program str

(* Takes a REPL string and produces a pair of perhaps a Links value (in the case of an expression)
 * and updated environments. *)
(* Mostly lifted from bin/repl.ml *)
let evaluate str envs : Driver.evaluation_result =
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
  let valenv, v = Driver.process_program true envs program [] in
  {
    result_env = (valenv,
      Env.String.extend nenv nenv',
      Types.extend_typing_environment tyenv tyenv');
    result_value = v;
    result_type = program_ty
  }

  (*
      Error: This expression has type
         ((Ir.binding list * Ir.tail_computation) * Types.typ) *
         (int Env.String.t * Types.typ Env.Int.t) * 'a list
       but an expression was expected of type
         Driver.evaluation_env =
           Value.env * int Env.String.t * Types.typing_environment
       Type (Ir.binding list * Ir.tail_computation) * Types.typ
       is not compatible with type Value.env = Value.t Value.Env.t
   *
   *)
    (*
    | Definitions defs ->
        let tenv = Var.varify_env (nenv, tyenv.Types.var_env) in
        let defs, nenv' = Sugartoir.desugar_definitions (nenv, tenv, tyenv.Types.effect_row) defs in
        `Definitions (defs, nenv')
    | Expression e     ->
        let tenv = Var.varify_env (nenv, tyenv.Types.var_env) in
        let e = Sugartoir.desugar_expression (nenv, tenv, tyenv.Types.effect_row) e in
        `Expression (e, program_ty)
    (* SJF: The Links REPL allows "directives" which do things like loading files and such.
     * A lot of these could be used to do insecure things. I'm disabling them all for now,
     * but it might make sense to whitelist some useful-yet-safe ones later. *)
    | Directive _      -> raise (Failure ("Directives not allowed.")) in
    *)
  (* evaluate_parse_result envs (program, tyenv') *)

let init () =
  let (_prelude, envs) = Driver.NonInteractive.load_prelude () in
  envs
