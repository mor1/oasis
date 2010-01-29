
(** OASIS types and exceptions
   @author Sylvain Le Gall
  *)

TYPE_CONV_PATH "OASISTypes"

(** Alias type
  *)
type name         = string with odn
type package_name = string with odn
type url          = string with odn
type dirname      = string with odn
type filename     = string with odn
type prog         = string with odn

(** Version 
  *)
type version =
  | VInt of int * version
  | VNonInt of string * version
  | VEnd
  with odn

(** Version comparator
  *)
type version_comparator = 
  | VGreater of version
  | VGreaterEqual of version
  | VEqual of version
  | VLesser of version
  | VLesserEqual of version
  | VOr of  version_comparator * version_comparator
  | VAnd of version_comparator * version_comparator
  with odn

(** Valid licenses
  *)
type license =
  | AllRightsReserved
  | BSD3
  | BSD4
  | GPL
  | LGPL
  | LGPL_link_exn
  | PublicDomain
  | OtherLicense of url
  with odn

(** Compilation type
  *)
type compiled_object =
  | Byte
  | Native
  | Best
  with odn

(** Package dependency
  *)
type dependency = 
  | FindlibPackage of package_name * version_comparator option
  | InternalLibrary of name
  with odn

(** Possible VCS 
  *)
type vcs = 
  | Darcs 
  | Git 
  | Svn 
  | Cvs 
  | Hg 
  | Bzr 
  | Arch 
  | Monotone
  with odn

(** Available test 
  *)
type expr_test = 
  | TOs_type
  | TSystem
  | TArchitecture
  | TCcomp_type
  | TOCaml_version
  with odn

(** Boolean expression to express condition on values
  *)
type expr =
  | EBool of bool
  | ENot of expr
  | EAnd of expr * expr
  | EOr of expr * expr
  | EFlag of string
  | ETest of expr_test * string
  with odn

(** Conditional value
  *)
type 'a conditional = (expr * 'a) list with odn

(** Library definition 
  *)
type library = 
    {
      lib_build:           bool conditional;
      lib_install:         bool conditional;
      lib_path:            dirname;
      lib_modules:         string list;
      lib_compiled_object: compiled_object;
      lib_build_depends:   dependency list;
      lib_build_tools:     prog list;
      lib_c_sources:       filename list;
      lib_data_files:      (filename * filename option) list;
      lib_parent:          name option;
      lib_findlib_name:    name option;
      lib_schema_data:     PropList.Data.t;
    } with odn

(** Executable definition 
  *)
type executable = 
    {
      exec_build:           bool conditional;
      exec_install:         bool conditional;
      exec_main_is:         filename;
      exec_compiled_object: compiled_object;
      exec_build_depends:   dependency list;
      exec_build_tools:     prog list;
      exec_c_sources:       filename list;
      exec_custom:          bool;
      exec_data_files:      (filename * filename option) list;
      (* TODO: this should be computed *)
      exec_is:              filename; (* Real executable *)
      exec_schema_data:     PropList.Data.t;
    } with odn

(** Command line flag defintion 
  *)
type flag = 
    {
      flag_description:  string option;
      flag_default:      bool conditional;
      flag_schema_data:  PropList.Data.t;
    } with odn

(** Source repository definition
  *)
type source_repository = 
    {
      src_repo_type:        vcs;
      src_repo_location:    url;
      src_repo_browser:     url option;
      src_repo_module:      string option;
      src_repo_branch:      string option;
      src_repo_tag:         string option;
      src_repo_subdir:      filename option;
      src_repo_schema_data: PropList.Data.t;
    } with odn

(** Test definition
  *)
type test = 
    {
      test_type:               string;
      test_command:            string * string list;
      test_working_directory:  filename option;
      test_run:                bool conditional;
      test_build_tools:        prog list;
      test_schema_data:        PropList.Data.t;
    } with odn

(** OASIS file whole content
  *)
type package = 
    {
      oasis_version:  version;
      ocaml_version:  version_comparator option;
      name:           package_name;
      version:        version;
      license:        license;
      license_file:   filename option;
      copyrights:     string list;
      maintainers:    string list;
      authors:        string list;
      homepage:       url option;
      synopsis:       string;
      description:    string option;
      categories:     url list;
      (* TODO: the two following fields should be propagated
       * to libraries/executables/... and not stored
       * there
       *)
      build_depends:  dependency list;
      build_tools:    prog list;
      conf_type:      string;
      build_type:     string;
      install_type:   string;
      files_ab:       filename list;
      plugins:        string list;
      libraries:      (name * library) list;
      executables:    (name * executable) list;
      flags:          (name * flag) list;
      src_repos:      (name * source_repository) list;
      tests:          (name * test) list;
      schema_data:    PropList.Data.t;
    } with odn

(* END EXPORT *)

(** Definition of a value in OASIS file
  *)
type 'a value =
    {
      parse: string -> 'a;
      print: 'a -> string;
    }

(** Quickstart level
  *)
type 'a quickstart_level =
  | NoChoice of 'a (* Don't ask question, use provided value *)
  | Beginner
  | Intermediate
  | Expert

(** Howto ask questions in quickstart 
  *)
type 'a quickstart_question =
  | YesNo
  | Field
  | Text
  | Choices of 'a list
  | ExclusiveChoices of 'a list
