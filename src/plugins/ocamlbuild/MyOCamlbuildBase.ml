(******************************************************************************)
(* OASIS: architecture for building OCaml libraries and applications          *)
(*                                                                            *)
(* Copyright (C) 2008-2010, OCamlCore SARL                                    *)
(*                                                                            *)
(* This library is free software; you can redistribute it and/or modify it    *)
(* under the terms of the GNU Lesser General Public License as published by   *)
(* the Free Software Foundation; either version 2.1 of the License, or (at    *)
(* your option) any later version, with the OCaml static compilation          *)
(* exception.                                                                 *)
(*                                                                            *)
(* This library is distributed in the hope that it will be useful, but        *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *)
(* or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more         *)
(* details.                                                                   *)
(*                                                                            *)
(* You should have received a copy of the GNU Lesser General Public License   *)
(* along with this library; if not, write to the Free Software Foundation,    *)
(* Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA              *)
(******************************************************************************)

(** Base functions for writing myocamlbuild.ml
    @author Sylvain Le Gall
  *)

TYPE_CONV_PATH "MyOCamlbuildBase"

open Ocamlbuild_plugin

type dir = string with odn
type file = string with odn
type name = string with odn
type tag = string with odn

(* END EXPORT *)
let rec odn_of_spec =
  let vrt nm lst = 
    ODN.VRT ("Ocamlbuild_plugin."^nm, lst)
  in
  let vrt_str nm str =
    vrt nm [ODN.STR str]
  in
    function
      | N     -> vrt "N" []
      | S lst -> vrt "S" [ODN.of_list odn_of_spec lst]
      | A s   -> vrt_str "A" s
      | P s   -> vrt_str "P" s
      | Px s  -> vrt_str "Px" s
      | Sh s  -> vrt_str "Sh" s
      | V s   -> vrt_str "V" s
      | Quote spc -> vrt "Quote" [odn_of_spec spc]
      | T _ -> 
          assert false
(* START EXPORT *)

type t =
    {
      lib_ocaml: (name * dir list) list;
      lib_c:     (name * dir * file list) list; 
      flags:     (tag list * (spec OASISExpr.choices)) list;
    } with odn

let env_filename =
  Pathname.basename 
    BaseEnvLight.default_filename

let dispatch_combine lst =
  fun e ->
    List.iter 
      (fun dispatch -> dispatch e)
      lst 

let dispatch t e = 
  let env = 
    BaseEnvLight.load 
      ~filename:env_filename 
      ~allow_empty:true
      ()
  in
    match e with 
      | Before_options ->
          let no_trailing_dot s =
            if String.length s >= 1 && s.[0] = '.' then
              String.sub s 1 ((String.length s) - 1)
            else
              s
          in
            List.iter
              (fun (opt, var) ->
                 try 
                   opt := no_trailing_dot (BaseEnvLight.var_get var env)
                 with Not_found ->
                   Printf.eprintf "W: Cannot get variable %s" var)
              [
                Options.ext_obj, "ext_obj";
                Options.ext_lib, "ext_lib";
                Options.ext_dll, "ext_dll";
              ]

      | After_rules -> 
          (* Declare OCaml libraries *)
          List.iter 
            (function
               | lib, [] ->
                   ocaml_lib lib;
               | lib, dir :: tl ->
                   ocaml_lib ~dir:dir lib;
                   List.iter 
                     (fun dir -> 
                        flag 
                          ["ocaml"; "use_"^lib; "compile"] 
                          (S[A"-I"; P dir]))
                     tl)
            t.lib_ocaml;

          (* Declare C libraries *)
          List.iter
            (fun (lib, dir, headers) ->
                 (* Handle C part of library *)
                 flag ["link"; "library"; "ocaml"; "byte"; "use_lib"^lib]
                   (S[A"-dllib"; A("-l"^lib); A"-cclib"; A("-l"^lib)]);

                 flag ["link"; "library"; "ocaml"; "native"; "use_lib"^lib]
                   (S[A"-cclib"; A("-l"^lib)]);
                      
                 flag ["link"; "program"; "ocaml"; "byte"; "use_lib"^lib]
                   (S[A"-dllib"; A("dll"^lib)]);

                 (* When ocaml link something that use the C library, then one
                    need that file to be up to date.
                  *)
                 dep  ["link"; "ocaml"; "use_lib"^lib] 
                   [dir/"lib"^lib^"."^(!Options.ext_lib)];

                 (* TODO: be more specific about what depends on headers *)
                 (* Depends on .h files *)
                 dep ["compile"; "c"] 
                   headers;

                 (* Setup search path for lib *)
                 flag ["link"; "ocaml"; "use_"^lib] 
                   (S[A"-I"; P(dir)]);
            )
            t.lib_c;

            (* Add flags *)
            List.iter
            (fun (tags, cond_specs) ->
               let spec = 
                 BaseEnvLight.var_choose cond_specs env
               in
                 flag tags & spec)
            t.flags
      | _ -> 
          ()

let dispatch_default t =
  dispatch_combine 
    [
      dispatch t;
      MyOCamlbuildFindlib.dispatch;
    ]

(* END EXPORT *)
