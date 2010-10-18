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


(** Test quickstart subcommand
    @author Sylvain Le Gall
  *)

open TestCommon
open Expect
open ExpectPcre
open OUnit
open OASISTypes

module MapString = Map.Make(String)

let tests = 
  let run_quickstart args qa = 
    let args = 
      !oasis_args @ ["-quiet"; "quickstart"; "-machine"] @ args
    in
    let () = 
      if !dbug then
        Printf.eprintf 
          "Quickstart command line: %s\n%!" 
          (String.concat " " (oasis () :: args))
    in
    let _, exit_code = 
      try 
        with_spawn
          ~verbose:!dbug
          ~timeout:(Some 0.1)
          (oasis ())
          (Array.of_list args)
          (fun t () ->
             let rec continue = 
               function
                 | [] ->
                     begin
                       ()
                     end

                 | qa -> 
                     begin
                       let expectations = 
                         let rec expectations' prev next = 
                           match next with 
                             | (q, a) :: tl ->
                                 (* next QA if we chose this answer *)
                                 let qa' = 
                                   List.rev_append prev tl
                                 in
                                 let q_pat = 
                                   match q with 
                                     | "create_section" ->
                                         "create a(nother)? section\\? "
                                     | "end" ->
                                         "What do you want to do now\\?"
                                     | "name" ->
                                         "'?name'?\\? "
                                     | q ->
                                         Printf.sprintf 
                                           "value for field '%s'\\? "
                                           q
                                 in
                                 let q_rex = 
                                   Pcre.regexp ~flags:[`CASELESS] q_pat
                                 in
                                   (`Rex q_rex, Some (a, qa'))
                                   ::
                                   (`Prefix ("???"^q^" "), Some (a, qa'))
                                   ::
                                   (expectations' ((q, a) :: prev) tl)
                             | [] ->
                                 []
                         in
                           expectations' [] qa
                       in
                       let exp_q = 
                         expect t expectations None
                       in

                         match exp_q with 
                           | Some (a, qa) -> 
                               send t (a^"\n");
                               continue qa
                           | None -> 
                               let assert_msg = 
                                 Printf.sprintf "expecting questions: %s"
                                   (String.concat ", "
                                      (List.map 
                                         (fun (q, _) -> Printf.sprintf "%S" q)
                                         qa))
                               in
                                 assert_failure assert_msg
                     end
             in
              continue qa;
              assert_bool
                "wait for eof"
                (expect t [`Eof, true] false);
          ) ()

      with e ->
        Printexc.print_backtrace stderr;
        raise e
    in
      assert_equal 
        ~msg:"exit code"
        ~printer:(function 
                    | Unix.WEXITED i 
                    | Unix.WSIGNALED i 
                    | Unix.WSTOPPED i -> 
                        string_of_int i)
        (Unix.WEXITED 0)
        exit_code
  in
  let test_of_vector (nm, args, qa, post) = 
    nm >::
    bracket 
      (fun () ->
         let pwd = FileUtil.pwd () in
         let tmp = temp_dir () in
           Sys.chdir tmp;
           pwd, tmp)
      (fun _ ->
         run_quickstart args qa;
         if !dbug then 
           begin
             let chn = open_in "_oasis" in
             let () = 
               try 
                 while true do 
                   prerr_endline (input_line chn)
                 done
               with End_of_file ->
                 ()
             in
               close_in chn
           end;
         assert_oasis_cli ["check"];
         begin
           try 
             assert_oasis_cli ["setup"];
           with e ->
             failwith "'oasis setup' failed but 'oasis check' succeed"
         end;
         let pkg = 
           OASISParse.from_file ~ctxt:!oasis_ctxt "_oasis"
         in
           post pkg)
      (fun (pwd, tmp) ->
         Sys.chdir pwd;
         FileUtil.rm ~recurse:true [tmp])
  in
    "Quickstart" >:::
    (List.map test_of_vector 
       [
         "simple",
         [],
         [
           "name",           "test";
           "version",        "0.0.1";
           "synopsis",       "test";
           "authors",        "me";
           "license",        "GPL-2+";
           "plugins",        "";
           "create_section", "e";
           "name",           "test";
           "path",           "./";
           "mainis",         "test.ml";
           "create_section", "n";
           "end",            "w";
         ],
         (fun pkg ->
            let () = 
              assert_equal 
                ~msg:"field name"
                ~printer:(fun s -> s)
                "test" pkg.name
            in

            let sct = 
              try 
                OASISSection.section_find 
                  (OASISSection.KExecutable,
                   "test")
                  pkg.sections
              with Not_found ->
                 failwith "Cannot find executable section 'test'"
            in
              match sct with 
                | Executable (cs, bs, exec) ->
                    assert_equal 
                      ~msg:"mainis of test"
                      ~printer:(fun s -> s)
                      "test.ml" exec.exec_main_is 
                | _ ->
                    assert false);

         "custom",
         ["-level"; "expert"],
         [
           "name", "test";
           "version", "0.1";
           "synopsis", "test";
           "description", "test";
           "licensefile", "";
           "authors", "me";
           "copyrights", "(C) 2010 Me";
           "maintainers", "";
           "license", "GPL-3";
           "ocamlversion", "";
           "findlibversion", "";
           "conftype", "custom";
           "preconfcommand", "";
           "postconfcommand", "";
           "buildtype", "custom";
           "prebuildcommand", "";
           "postbuildcommand", "";
           "installtype", "";
           "preinstallcommand", "";
           "postinstallcommand", "";
           "preuninstallcommand", "";
           "postuninstallcommand", "";
           "precleancommand", "";
           "postcleancommand", "";
           "predistcleancommand", "";
           "postdistcleancommand", "";
           "homepage", "";
           "categories", "";
           "filesab", "";
           "plugins", "stdfiles, devfiles, meta";
           "builddepends", "";
           "buildtools", "";
           "create_section", "n";
           "end", "w";
           "xcustomconf", "./configure";
           "xcustomconfclean", "";
           "xcustomconfdistclean", "$rm config.log";
           "xcustombuild", "make all";
           "xcustombuildclean", "make clean";
           "xcustombuilddistclean", "make distclean";
           "xstdfilesreadme", "";
           "xstdfilesreadmefilename", "";
           "xstdfilesinstallfilename", "";
           "xstdfilesinstall", "";
           "xstdfilesauthorsfilename", "";
           "xstdfilesauthors", "";
           "xdevfilesmakefilenotargets", "";
           "xdevfilesenablemakefile", "";
           "xdevfilesenableconfigure", "";
         ],
         (fun pkg ->
            assert_equal 
              ~msg:"field name"
              ~printer:(fun s -> s)
              "test" pkg.name);
       ])

