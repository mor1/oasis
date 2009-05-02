
(** Install using ocaml-autobuild internal scheme
    @author Sylvain Le Gall
  *)

type library =
    {
      lib_name:      string;
      lib_buildable: bool BaseExpr.choices;
      lib_modules:   string list;
      lib_path:      string;
    }
;;

type executable =
    {
      exec_name:      string;
      exec_buildable: bool BaseExpr.choices;
      exec_path:      string;
    }
;;

let install libs execs env argv =
  
  let srcdir = 
    (* TODO: don't hardcode this *)
    "."
  in

  let builddir =
    (* TODO: don't hardcode this *)
    Filename.concat srcdir "_build"
  in

  let exec_ext =
    (* TODO: don't hardcode this *)
    ""
  in

  let bindir =
    (* TODO: don't hardcode this *)
    "/usr/bin"
  in

  let rootdirs =
    [srcdir; builddir]
  in

  let ( * ) lst1 lst2 = 
    List.flatten 
      (List.map 
         (fun a -> 
            List.map 
              (fun b -> a,b) 
              lst2) 
         lst1)
  in

  let make_filename =
    function
      | [] -> "" 
      | hd :: tl  -> List.fold_left Filename.concat hd tl
  in

  let make_module nm = 
    [String.capitalize nm; String.uncapitalize nm]
  in

  let find_file f lst = 
    let alternatives =
      List.map (fun e -> make_filename (f e)) lst
    in
      try 
        List.find Sys.file_exists alternatives
      with Not_found ->
        failwith 
          (Printf.sprintf 
             "Cannot find any of the files: %s"
             (String.concat ", " 
                (List.map 
                   (Printf.sprintf "%S")
                   alternatives)))
  in

  let find_build_file dir fn =
    find_file
      (fun rootdir -> [rootdir; dir; fn])
      rootdirs
  in

  let install_lib env lib = 
    let (buildable, env) =
      BaseExpr.choose lib.lib_buildable env
    in
      if buildable then
        (
          let find_build_file =
            find_build_file lib.lib_path
          in

          let module_to_cmi modul =
            find_file 
               (fun (rootdir, fn) -> [rootdir; lib.lib_path; (fn^".cmi")])
               (rootdirs * (make_module modul))
          in

          let module_to_header modul =
            assert(modul <> "");
            find_file 
               (fun ((rootdir, fn), ext) -> [rootdir; lib.lib_path; fn^ext])
               (rootdirs * (make_module modul) * [".mli"; ".ml"])
          in
            
          let cmdline =
            List.flatten
              (
                [
                  "ocamlfind"; "install"; lib.lib_name; 
                  find_build_file "META";
                  find_build_file (lib.lib_name^".cma");
                ]
                :: 
                (
                  try 
                    [find_build_file (lib.lib_name^".cmxa")]
                  with Not_found ->
                    []
                )
                ::
                (
                  List.rev_map
                    (fun modul -> [module_to_cmi modul; module_to_header modul])
                    lib.lib_modules
                )
              )
          in
            prerr_endline (String.concat " " cmdline)
        );
      env
  in

  let install_exec env exec =
    let (buildable, env) = 
      BaseExpr.choose exec.exec_buildable env
    in
      if buildable then
        (
          let exec_file =
            find_file
              (fun (rootdir, name) -> [rootdir; name^exec_ext])
              (rootdirs * [exec.exec_name])
          in
          let cmdline =
            [
              "cp"; 
              exec_file; 
              Filename.concat 
                bindir
                exec.exec_name
            ]
          in
            prerr_endline (String.concat " " cmdline)
        );
      env
  in

  let env =
    List.fold_left 
      install_lib
      env
      libs
  in

  let _env = 
    List.fold_left
      install_exec
      env
      execs
  in

    ()
;;

