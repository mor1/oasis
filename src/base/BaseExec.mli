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

(** Running commands
    @author Sylvain Le Gall
  *)

open OASISTypes

(** Run a command.
    @param f_exit_code if provided, run this command on the exit code
    (even when it is [0]).  Otherwise, a non-zero exit code raises
    [Failure]. *)
val run : ?f_exit_code:(int -> unit) -> prog -> args -> unit

(** Run a command and returns its output as a list of lines.
*)
val run_read_output : ?f_exit_code:(int -> unit) -> prog -> args -> string list

(** Run a command and returns only first line.
    @raise Failure if the output contains more than one line. *)
val run_read_one_line : ?f_exit_code:(int -> unit) -> prog -> args -> string
