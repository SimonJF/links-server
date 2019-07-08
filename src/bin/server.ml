open Lwt
open Links_core
open Webserver


let listen_address = Unix.inet_addr_loopback
let port = 9000
let backlog = 10
let (globals, init_envs) = Eval_links.init ()

exception Timeout of string

type page = {
  page_result : Driver.evaluation_result;
  page_path : string
}

(* eval created from result of Eval_links.evaluate *)
type eval =
  | Expression of Driver.evaluation_result
  | Exception of exn
  | Page of page

let jsonify out =
  match out with
  | Page p ->
    let response = `Assoc [ ("response", `String "page");
           ("content", `String p.page_path); ] in
  Yojson.to_string response
  | Expression ex ->
    let response = `Assoc [ ("response", `String "expression");
             ("content", `String (Value.string_of_value ex.result_value)); ] in
    Yojson.to_string response
  | Exception e ->
    let response = `Assoc [ ("response", `String "exception");
             ("content", `String (Errors.format_exception e)); ] in
    Yojson.to_string response

let json_to_string json =
  let open Yojson.Basic.Util in
  Yojson.Basic.from_string json |> member "input" |> to_string

let attempt_execution timeout msg env =
  Lwt_main.run (Lwt.pick [
    (Eval_links.evaluate msg env >>= fun x ->
    match x.result_type with
    | `Alias (("Page", _), _) -> let (path, _) =
      Webserver.add_dynamic_route x.result_env x.result_value in
      Lwt.return (Page { page_result = x; page_path = path })
    | _ -> Lwt.return (Expression x));
    (timeout >|= fun () -> Exception (Timeout "Program Timed out"));])

let handle_message msg env =
  let out =
    try
      let timeout = Lwt_unix.sleep 4. in
      attempt_execution timeout msg env
    with
      | ex -> Exception ex in
  match out with
    | Expression ex ->
      ((jsonify out), ex.result_env)
    | _ -> ((jsonify out), env)

let rec handle_connection ic oc env () =
  let read = Lwt_io.read_line_opt ic in (* Type: Lwt.t (string option)  *)
  let write data = Lwt_io.write_line oc data in

  read >>=
  (fun msg ->
      match msg with
      | Some json ->
        let msg = json_to_string json in
          let reply, new_env = handle_message msg env in
          write reply >>= handle_connection ic oc new_env
      | None -> Logs_lwt.info (fun m -> m "Connection closed") >>= return)

let accept_connection conn =
    let fd, _ = conn in
    let ic = Lwt_io.of_fd ~mode:Lwt_io.Input fd in
    let oc = Lwt_io.of_fd ~mode:Lwt_io.Output fd in
    Lwt.on_failure (handle_connection ic oc init_envs ()) (fun e -> Logs.err (fun m -> m "%s"  (Printexc.to_string e) ));
    Logs_lwt.info (fun m -> m "New connection") >>= return

let create_socket () =
    let open Lwt_unix in
    let sock = socket PF_INET SOCK_STREAM 0 in
    bind sock @@ ADDR_INET(listen_address, port) >>= fun _ ->
    listen sock backlog;
    Logs.info (fun m -> m "Listening");
    return sock

let create_server sock =
    let rec serve () =
        Lwt_unix.accept sock >>= accept_connection >>= serve
    in serve

let () =
    let () = Logs.set_reporter (Logs.format_reporter ()) in
    let () = Logs.set_level (Some Logs.Info) in
    let (venv, _, _) = init_envs in
    Webserver.init init_envs globals [];
    Proc.Proc.run
      (fun () ->
       let () = async (fun () -> Webserver.start venv) in
       create_socket () >>= fun sock ->
       let serve = create_server sock in
       serve ())
