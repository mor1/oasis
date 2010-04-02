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

(** Library schema and generator 
    @author Sylvain Le Gall
  *)

open OASISTypes
open OASISUtils
open OASISGettext

(** Compute all files expected by a build of the library
  *)
let generated_unix_files (cs, bs, lib) 
      source_file_exists is_native ext_lib ext_dll =  
  (* The headers that should be compiled along *)
  let headers = 
    List.fold_left
      (fun hdrs modul ->
         try 
           let base_fn = 
             List.find
               (fun fn -> 
                  source_file_exists (fn^".ml") ||
                  source_file_exists (fn^".mli") ||
                  source_file_exists (fn^".mll") ||
                  source_file_exists (fn^".mly")) 
               (List.map
                  (OASISUnixPath.concat bs.bs_path)
                  [modul;
                   String.uncapitalize modul;
                   String.capitalize modul])
           in
             (base_fn^".cmi") :: hdrs
         with Not_found ->
           OASISMessage.warning
             (f_ "Cannot find source file matching \
                  module '%s' in library %s")
             modul cs.cs_name;
             (OASISUnixPath.concat bs.bs_path (modul^".cmi")) 
             :: hdrs)
      []
      lib.lib_modules
  in

  let acc_nopath =
    []
  in

  (* Compute what libraries should be built *)
  let acc_nopath =
    let byte acc =
      (cs.cs_name^".cma") :: acc
    in
    let native acc =
      (cs.cs_name^".cmxa") :: (cs.cs_name^(ext_lib ())) :: acc
    in
      match bs.bs_compiled_object with 
        | Native ->
            byte (native acc_nopath)
        | Best when is_native () ->
            byte (native acc_nopath)
        | Byte | Best ->
            byte acc_nopath
  in

  (* Add C library to be built *)
  let acc_nopath = 
    if bs.bs_c_sources <> [] then
      begin
        ("lib"^cs.cs_name^(ext_lib ()))
        ::
        ("dll"^cs.cs_name^(ext_dll ()))
        ::
        acc_nopath
      end
    else
      acc_nopath
  in

    (* All the files generated *)
    List.rev_append
      (List.rev_map
         (OASISUnixPath.concat bs.bs_path)
         acc_nopath)
      headers


(** Library group are organized in trees
  *)
type group_t = 
  | Container of findlib_name * (group_t list)
  | Package of (findlib_name * 
                common_section *
                build_section * 
                library * 
                (group_t list))

(** Compute groups of libraries, associate root libraries with 
    a tree of its children. A group of libraries is defined by 
    the fact that these libraries has a parental relationship 
    and must be isntalled together, with the same META file.
  *)
let group_libs pkg =
  (** Associate a name with its children *)
  let children =
    List.fold_left
      (fun mp ->
         function
           | Library (cs, bs, lib) ->
               begin
                 match lib.lib_findlib_parent with 
                   | Some p_nm ->
                       begin
                         let children =
                           try 
                             MapString.find p_nm mp
                           with Not_found ->
                             []
                         in
                           MapString.add p_nm ((cs, bs, lib) :: children) mp
                       end
                   | None ->
                       mp
               end
           | _ ->
               mp)
      MapString.empty
      pkg.sections
  in

  (* Compute findlib name of a single node *)
  let findlib_name (cs, _, lib) =
    match lib.lib_findlib_name with 
      | Some nm -> nm
      | None -> cs.cs_name
  in

  (** Build a package tree *)
  let rec tree_of_library containers ((cs, bs, lib) as acc) =
    match containers with
      | hd :: tl ->
          Container (hd, [tree_of_library tl acc])
      | [] ->
          (* TODO: allow merging containers with the same 
           * name 
           *)
          Package 
            (findlib_name acc, cs, bs, lib,
             (try 
                List.rev_map 
                  (fun ((_, _, child_lib) as child_acc) ->
                     tree_of_library 
                       child_lib.lib_findlib_containers
                       child_acc)
                  (MapString.find cs.cs_name children)
              with Not_found ->
                []))
  in

    (* TODO: check that libraries are unique *)
    List.fold_left
      (fun acc ->
         function
           | Library (cs, bs, lib) when lib.lib_findlib_parent = None -> 
               (tree_of_library lib.lib_findlib_containers (cs, bs, lib)) :: acc
           | _ ->
               acc)
      []
      pkg.sections

(** Compute internal library findlib names, including subpackage
    and return a map of it.
  *)
let findlib_name_map pkg = 

  (* Compute names in a tree *)
  let rec findlib_names_aux path mp grp =
    let fndlb_nm, children, mp =
      match grp with
        | Container (fndlb_nm, children) ->
            fndlb_nm, children, mp
                                  
        | Package (fndlb_nm, {cs_name = nm}, _, _, children) ->
            fndlb_nm, children, (MapString.add nm (path, fndlb_nm) mp)
    in
    let fndlb_nm_full =
      (match path with
         | Some pth -> pth^"."
         | None -> "")^
      fndlb_nm
    in
      List.fold_left
        (findlib_names_aux (Some fndlb_nm_full))
        mp
        children
  in

    List.fold_left
      (findlib_names_aux None)
      MapString.empty
      (group_libs pkg)


(** Return the findlib name of the library without parents *)
let findlib_of_name ?(recurse=false) map nm =
  try 
    let (path, fndlb_nm) = 
      MapString.find nm map
    in
      match path with 
        | Some pth when recurse -> pth^"."^fndlb_nm
        | _ -> fndlb_nm

  with Not_found ->
    failwithf1
      (f_ "Unable to translate internal library '%s' to findlib name")
      nm

(** Return the findlib root name of a group, it takes into account
    containers. So the return group name is the toplevel name
    for both libraries and theirs containers.
  *)
let findlib_of_group = 
  function
    | Container (fndlb_nm, _) 
    | Package (fndlb_nm, _, _, _, _) -> fndlb_nm

(** Return the root library, i.e. the first found into the group tree
    that has no parent.
  *)
let root_of_group grp =
  let rec root_lib_aux =
    function 
      | Container (_, children) ->
          root_lib_lst children        
      | Package (_, cs, bs, lib, children) ->
          if lib.lib_findlib_parent = None then 
            cs, bs, lib
          else
            root_lib_lst children
  and root_lib_lst =
    function
      | [] ->
          raise Not_found
      | hd :: tl ->
          try
            root_lib_aux hd
          with Not_found ->
            root_lib_lst tl
  in
    try
      root_lib_aux grp
    with Not_found ->
      failwithf1
        (f_ "Unable to determine root library of findlib library '%s'")
        (findlib_of_group grp)

(* END EXPORT *)

open OASISSchema
open OASISValues
open OASISGettext
open PropList.Field

let schema, generator =
  let schm =
    schema "Library"
  in
  let cmn_section_gen =
    OASISSection.section_fields (s_ "library") schm
  in
  let build_section_gen =
    OASISBuildSection.section_fields (s_ "library") Best schm
  in
  let external_modules =
    new_field schm "Modules" 
      ~default:[]
      ~quickstart_level:Beginner
      modules
      (fun () ->
         s_ "List of modules to compile.") 
  in
  let internal_modules = 
    new_field schm "InternalModules"
      ~default:[]
      ~quickstart_level:Beginner
      modules
      (fun () ->
         s_ "List of modules to compile which are not exported.")
  in
  let findlib_parent =
    new_field schm "FindlibParent"
      ~default:None
      (opt internal_library)
      (fun () ->
         s_ "Library which includes the current library. The current library \
             will be built as its parents and installed along it.")
  in
  let findlib_name = 
    new_field schm "FindlibName"
      ~default:None
      (* TODO: Check that the name is correct if this value is None, the
               package name must be correct 
       *)
      (opt pkgname)
      (fun () ->
         s_ "Name used by findlib.")
  in
  let findlib_containers =
    new_field schm "FindlibContainers"
      ~default:[]
      (* TODO: check that a container doesn't overwrite a real package 
       *)
      (dot_separated string_not_empty)
      (fun () ->
         s_ "Virtual containers for sub-package, dot-separated")
  in
    schm,
    (fun nm data ->
       Library
         (cmn_section_gen nm data,
          (build_section_gen nm data),
          {
            lib_modules            = external_modules data;
            lib_internal_modules   = internal_modules data;
            lib_findlib_parent     = findlib_parent data;
            lib_findlib_name       = findlib_name data;
            lib_findlib_containers = findlib_containers data;
          }))
