open Lwt
open Links_core
open Webserver


let listen_address = Unix.inet_addr_loopback
let port = 9000
let backlog = 10
let (globals, init_envs) = Eval_links.init ()

exception Timeout of string

(* eval created from result of Eval_links.evaluate *)
type eval =
  | Expression of Eval_links.value_result
  | Exception of exn
  | Page of string

let jsonify out =
  match out with
  | Page path ->
    let response = `Assoc [ ("response", `String "page");
           ("content", `String path); ] in
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

let attempt_execution msg env =
  Lwt.pick [
    (Eval_links.evaluate msg env >>= fun x ->
    match x with
      | PageResult path->
          Lwt.return (Page path)
      | ValueResult x -> Lwt.return (Expression x));
    (Lwt_unix.sleep 4. >>= fun () -> Lwt.return (Exception (Timeout "Program Timed out")));]

let handle_message msg env =
  let out =
    Lwt.catch
      (fun () -> attempt_execution msg env)
      (fun e -> Lwt.return (Exception e)) in
  out >>= fun x ->
  match x with
    | Expression ex ->
      Lwt.return ((jsonify x), ex.result_env)
    | Page _ -> Lwt.return ((jsonify x), env)
    | _ -> Lwt.return ((jsonify x), env)

let rec handle_connection ic oc env () =
  let read = Lwt_io.read_line_opt ic in (* Type: Lwt.t (string option)  *)
  let write data = Lwt_io.write_line oc data in

  read >>=
  (fun msg ->
      match msg with
      | Some json ->
        let msg = json_to_string json in
          let reply = handle_message msg env in
          reply >>= fun (res, new_env) ->
          write res >>= handle_connection ic oc new_env
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
