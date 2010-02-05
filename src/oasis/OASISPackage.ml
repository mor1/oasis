
(** Package schema and generator 
    @author Sylvain Le Gall
  *)

open OASISTypes

(* END EXPORT *)

open OASISValues
open OASISUtils
open OASISSchema
open CommonGettext

let add_build_depend build_depend pkg =
  {pkg with
       libraries =
         List.map
           (fun (nm, lib) ->
              nm,
              {lib with 
                   lib_build_depends = 
                     build_depend :: lib.lib_build_depends})
           pkg.libraries;
     
       executables =
         List.map
           (fun (nm, exec) ->
              nm,
              {exec with 
                   exec_build_depends = 
                     build_depend :: exec.exec_build_depends})
           pkg.executables}

let add_build_tool ?(condition=[EBool true, true]) build_tool pkg =
  {pkg with
       libraries =
         List.map
           (fun (nm, lib) ->
              nm,
              {lib with 
                   lib_build_tools = 
                     build_tool :: lib.lib_build_tools})
           pkg.libraries;
     
       executables =
         List.map
           (fun (nm, exec) ->
              nm,
              {exec with 
                   exec_build_tools = 
                     build_tool :: exec.exec_build_tools})
           pkg.executables}

let schema, generator =
  let schm =
    schema "Package"
  in
  let oasis_version = 
    let current_version =
      OASISVersion.version_of_string "1.0"
    in
    let extra_supported_versions =
      []
    in
      new_field schm "OASISFormat" 
        ~quickstart_level:(NoChoice current_version)
        {
          parse = 
            (fun str ->
               let v = 
                 version.parse str
               in
                 if not 
                      (List.mem 
                         v 
                         (current_version :: extra_supported_versions)) then
                   failwith 
                     (Printf.sprintf 
                        "OASIS format version '%s' is not supported"
                        str);
                 v);
          print = version.print;
        }
        (fun () ->
           s_ "OASIS format version used to write file _oasis.")
  in
  let name = 
    new_field schm "Name" string_not_empty 
      (fun () ->
         s_ "Name of the package.")
  in
  let version = 
    new_field schm "Version" version
      (fun () ->
         s_ "Version of the package.")
  in
  let synopsis =
    new_field schm "Synopsis" string_not_empty
      (fun () ->
         s_ "Short description of the purpose of this package.")
  in
  let description =
    new_field schm "Description"
      ~default:None
      (opt string_not_empty)
      (fun () -> 
         s_ "Long description of the package purpose.")
  in
  let license_file =
    new_field schm "LicenseFile" 
      ~default:None
      (opt file)
      (fun () -> 
         s_ "File containing license.");
  in
  let authors =
    new_field schm "Authors" 
      (comma_separated string_not_empty)
      (fun () ->
         s_ "Real person that has contributed to the package.")
  in
  let copyrights =
    new_field schm "Copyrights" 
      ~default:[]
      (comma_separated copyright)
      (fun () ->
         s_ "Copyright owners.")
  in
  let maintainers =
    new_field schm "Maintainers"
      ~default:[]
      (comma_separated string_not_empty)
      (fun () -> 
         s_ "Current maintainers of the package")
  in
  let license =
    new_field schm "License"
      (
        let std_licenses = 
          [
            "GPL", GPL;
            "LGPL", LGPL;
            "BSD3", BSD3;
            "BSD4", BSD4;
            "PUBLICDOMAIN", PublicDomain;
            "LGPL-LINK-EXN", LGPL_link_exn;
          ]
        in
        let base_value = 
          choices (fun () -> s_ "license") std_licenses
        in
          {
            parse =
              (fun str ->
                 try 
                   base_value.parse str
                 with _ ->
                   begin
                     try
                       OtherLicense (url.parse str)
                     with _ ->
                       failwith 
                         (Printf.sprintf 
                            (f_ "'%s' is not an URL or a common license name (%s)")
                            str
                            (String.concat ", " (List.map fst std_licenses)))
                   end);
            print = 
              (function
                 | OtherLicense v -> url.print v
                 | v -> base_value.print v);
          })
      (fun () ->
         s_ "License type of the package.")
  in
  let ocaml_version =
    new_field schm "OCamlVersion"
      ~default:None
      (opt version_comparator)
      (fun () -> 
         s_ "Version constraint on OCaml.")
  in
  let conf_type =
    new_field schm "ConfType" 
      ~default:"internal"
      string_not_empty
      (fun () -> 
         s_ "Configuration system.")
  in
  let build_type =
    new_field schm "BuildType" 
      ~default:"ocamlbuild"
      string_not_empty
      (fun () -> 
         s_ "Build system.")
  in
  let install_type =
    new_field schm "InstallType"
      ~default:"internal"
      string_not_empty
      (fun () -> 
         s_ "Install/uninstall system.")
  in
  let homepage =
    new_field schm "Homepage" 
      ~default:None
      (opt url)
      (fun () -> 
         s_ "URL of the package homepage.")
  in
  let categories =
    new_field schm "Categories"
      ~default:[]
      categories
      (fun () ->
         s_ "URL(s) describing categories of the package.")
  in
  let files_ab =
    new_field schm "FilesAB"
      ~default:[]
      (* TODO: check that filenames end with .ab *)
      (comma_separated file)
      (fun () -> 
         s_ "Files to generate using environment variable substitution.")
  in
  let plugins =
    new_field schm "Plugins"
      ~default:[]
      (* TODO: check that plugin exists and activate plugins for further
       * processing/check
       *)
      (comma_separated string_not_empty)
      (fun () -> 
         s_ "Extra plugins to use")
  in
  let build_depends, build_tools =
    depends_field schm
  in
    schm,
    (fun data libs execs flags src_repos tests ->
       List.fold_right
         add_build_depend 
         (build_depends data)
         (List.fold_right
            add_build_tool
            (build_tools data)
            {
              oasis_version = oasis_version data;
              ocaml_version = ocaml_version data;
              name          = name data;
              version       = version data;
              license       = license data;
              license_file  = license_file data;
              copyrights    = copyrights data;
              maintainers   = maintainers data;
              authors       = authors data;
              homepage      = homepage data;
              synopsis      = synopsis data;
              description   = description data;
              categories    = categories data;
              conf_type     = conf_type data;
              build_type    = build_type data;
              install_type  = install_type data;
              files_ab      = files_ab data;
              plugins       = plugins data;
              libraries     = libs;
              executables   = execs;
              flags         = flags;
              src_repos     = src_repos;
              tests         = tests;
              schema_data   = data;
            }))
