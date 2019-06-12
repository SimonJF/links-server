open Links_core
open Links_core.Utility
open Links_core.Sugartypes

(* Parses a string and returns a Links expression *)
(* TODO: Exception handling *)
let parse str =
  Parse.parse_string Parse.interactive str

(* Takes a REPL string and produces a pair of perhaps a Links value (in the case of an expression)
 * and updated environments. *)
(* Mostly lifted from bin/repl.ml *)
let evaluate str envs : (Value.t option * Driver.evaluation_env) =

  (* Evaluates a parse result, returning a Links value if
   * an expression, and updated environments. *)
  let evaluate_parse_result envs parse_result =
    let _, nenv, tyenv = envs in
    match parse_result with
      | `Definitions (defs, nenv'), tyenv' ->
          (* Process each definition in turn. *)
          let valenv, _ =
            Driver.process_program true envs
              (defs, Ir.Return (Ir.Extend (StringMap.empty, None)))
              [] in
          let updated_envs =
            (valenv,
             Env.String.extend nenv nenv',
             Types.extend_typing_environment tyenv tyenv') in
          (None, updated_envs)
      | `Expression (e, _t), _ ->
          let valenv, v = Driver.process_program true envs e [] in
          let (_, nenv, tenv) = envs in
          let updated_envs = (valenv, nenv, tenv) in
          (Some v, updated_envs) in

  let expr, pos_context = parse str in
  let (_, nenv, tyenv) = envs in
  (* Begin by parsing the input string. *)
  let sentence, sentence_ty, tyenv' =
    Frontend.Pipeline.interactive tyenv pos_context expr in
  let sentence = match sentence with
    | Definitions defs ->
        let tenv = Var.varify_env (nenv, tyenv.Types.var_env) in
        let defs, nenv' = Sugartoir.desugar_definitions (nenv, tenv, tyenv.Types.effect_row) defs in
        `Definitions (defs, nenv')
    | Expression e     ->
        let tenv = Var.varify_env (nenv, tyenv.Types.var_env) in
        let e = Sugartoir.desugar_expression (nenv, tenv, tyenv.Types.effect_row) e in
        `Expression (e, sentence_ty)
    (* SJF: The Links REPL allows "directives" which do things like loading files and such.
     * A lot of these could be used to do insecure things. I'm disabling them all for now,
     * but it might make sense to whitelist some useful-yet-safe ones later. *)
    | Directive _      -> raise (Failure ("Directives not allowed.")) in
  evaluate_parse_result envs (sentence, tyenv')

let init () =
  let (_prelude, envs) = Driver.NonInteractive.load_prelude () in
  envs

(* Main entry point *)
let () =
  let links_string_1 = "var z = \"Hello!\";" in
  let links_string_2 = "z;" in
  let envs = init () in
  let (_, envs) = evaluate links_string_1 envs in
  let (res_opt, _) = evaluate links_string_2 envs in
  match res_opt with
    | Some v -> print_endline ("Some " ^ (Value.string_of_value v))
    | None -> print_endline "None"
