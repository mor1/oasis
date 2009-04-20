
(** Configure using OCaml-autobuild
    @author Sylvain Le Gall
  *)

module Msg = BaseMessage;;
module Env = BaseEnvironment;;

(** Build environment using provided series of check to be done
  * and then output corresponding file.
  *)
let configure pkg_name pkg_version args checks ab_files argv =

  (* Build initial environment *)
  let env_org =
    Env.load ~allow_empty:true ()
  in
  let env = 
    List.fold_left
      (fun env (nm, vl) -> Env.var_define nm (fun env -> vl, env) env)
      env_org
      [
        "pkg_name", pkg_name;
        "pkg_version", pkg_version;
      ]
  in
  (* Parse command line *)
  let env =
    BaseArgExt.parse argv (BaseArgExt.default :: args) env
  in

  (* Do some check *)
  let env =
    BaseCheck.run checks env
  in

  (* Replace data in file *)
  let env =
    BaseFileAB.replace
      ab_files
      env
  in

    if not (Env.equal env_org env) then
      (
        Env.dump env;
        Env.print env
      )
;;
