(********************************************************************************)
(*  OASIS: architecture for building OCaml libraries and applications           *)
(*                                                                              *)
(*  Copyright (C) 2008-2010, OCamlCore SARL                                     *)
(*                                                                              *)
(*  This library is free software; you can redistribute it and/or modify it     *)
(*  under the terms of the GNU Lesser General Public License as published by    *)
(*  the Free Software Foundation; either version 2.1 of the License, or (at     *)
(*  your option) any later version, with the OCaml static compilation           *)
(*  exception.                                                                  *)
(*                                                                              *)
(*  This library is distributed in the hope that it will be useful, but         *)
(*  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY  *)
(*  or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more          *)
(*  details.                                                                    *)
(*                                                                              *)
(*  You should have received a copy of the GNU Lesser General Public License    *)
(*  along with this library; if not, write to the Free Software Foundation,     *)
(*  Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA               *)
(********************************************************************************)

(** Common utilities for testing
    @author Sylvain Le Gall
  *)

open OUnit;;

module MapString = Map.Make(String);;
module SetString = Set.Make(String);;

type context =
    {
      dbug:         bool;
      long:         bool;
      has_ocamlopt: bool;
      oasis:        string;
      oasis_args:   string list;
      oasis_ctxt:   OASISContext.t;
    }
;;

let in_data fn =
  Filename.concat "data" fn
;;

(* Create a temporary dir *)
let temp_dir () =
  let res = 
    Filename.temp_file "oasis-" ".dir"
  in
    FileUtil.rm [res];
    FileUtil.mkdir res;
    at_exit 
      (fun () -> 
         FileUtil.rm ~recurse:true [res]);
    res

(* Assert checking that command run well *)
let assert_command ?(exit_code=0) ?output ?(extra_env=[]) ctxt cmd args  =
  let cmdline =
    String.concat " " 
      (
        (if extra_env <> [] then
           "env" :: (List.map (fun (nm, vl) -> nm^"="^vl) extra_env)
         else
           [])
        @
        (cmd :: args)
      )
  in

  let env = 
    let extra_env_map = 
      (* Build a map of asked replacement *)
      List.fold_left
        (fun mp (k,v) ->
           MapString.add k v mp)
        MapString.empty
        extra_env
    in
    let split_variable e = 
      (* Extract variable from string of the form "k=v" *)
      try 
        let idx = 
          String.index e '='
        in
          String.sub e 0 idx,
          String.sub e (idx + 1) ((String.length e) - idx - 1)
      with Not_found ->
        e, ""
    in
    let rev_lst, extra_env_map =
      (* Go through current enviromnent and replace "k=v" 
       * when k is in extra_env, remove this key at the
       * same time to avoid duplication when re-creating
       * the environment, at the end 
       *)
      List.fold_left
        (fun (acc,mp) e ->
           let k,v =
             split_variable e
           in
           let v, mp =
             try 
               MapString.find k mp,
               MapString.remove k mp
             with Not_found ->
               v, mp
           in
             ((k, v) :: acc), mp)
        ([], extra_env_map)
        (Array.to_list (Unix.environment ()))
    in
    let rev_lst =
      (* Add key from extra_env that has not been replaced *)
      List.fold_left
        (fun acc ((k, _) as e) ->
           if MapString.mem k extra_env_map then
             e :: acc
           else
             acc)
        rev_lst
        extra_env
    in
      Array.of_list (List.rev_map (fun (k,v) -> k^"="^v) rev_lst)
  in

  let fn, chn_out =
    Filename.open_temp_file "oasis-" ".log"
  in
  let fd =
    Unix.descr_of_out_channel chn_out
  in
  let clean_fn () =
    FileUtil.rm [fn]
  in

  let load_stdout_stderr () = 
    let chn = open_in_bin fn in
    let str = String.make (in_channel_length chn) 'X' in
      really_input chn str 0 (String.length str);
      close_in chn;
      str
  in

  let dump_stdout_stderr () = 
      output_string stderr (load_stdout_stderr ());
      flush stderr
  in

  let err_stdout_stderr () = 
    dump_stdout_stderr ();
    Printf.eprintf "Error running command '%s'\n%!" cmdline
  in

    try 
      begin
        let pid =
          let res = 
            if ctxt.dbug then
              prerr_endline ("Running "^cmdline); 
            Unix.create_process_env 
              cmd 
              (Array.of_list (cmd :: args))
              env
              Unix.stdin
              fd
              fd
          in
            close_out chn_out;
            res
        in

          (* Check exit code *)
          begin
            match Unix.waitpid [] pid with
              | _, Unix.WEXITED i ->
                  if i <> exit_code then
                    err_stdout_stderr ()
                  else if ctxt.dbug then
                    begin
                    dump_stdout_stderr ();
                    end;
                  assert_equal
                    ~msg:(Printf.sprintf "'%s' exit code" cmdline)
                    ~printer:string_of_int
                    exit_code
                    i;
              | _, Unix.WSIGNALED i ->
                  err_stdout_stderr ();
                  failwith 
                    (Printf.sprintf
                       "Process '%s' has been killed by signal %d"
                       cmdline
                       i)
              | _, Unix.WSTOPPED i ->
                  err_stdout_stderr ();
                  failwith
                    (Printf.sprintf
                       "Process '%s' has been stopped by signal %d"
                       cmdline
                       i)
          end;

          (* Check output *)
          begin
            match output with 
              | Some str_exp ->
                  assert_equal 
                    ~msg:(Printf.sprintf "'%s' command output" cmdline)
                    ~printer:(Printf.sprintf "%S")
                    str_exp
                    (load_stdout_stderr ())
              | None ->
                  ()
          end;

          clean_fn ()
      end
    with e ->
      begin
        clean_fn ();
        raise e
      end


let assert_oasis_cli ?exit_code ?output ?extra_env ctxt args  =
  assert_command ?exit_code ?output ?extra_env 
    ctxt ctxt.oasis (ctxt.oasis_args @ args)
