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

open OASISGettext

TYPE_CONV_PATH "OASISVersion"

type s = string

type t =
  | VInt of int * t
  | VNonInt of string * t
  | VEnd with odn

type comparator = 
  | VGreater of t
  | VGreaterEqual of t
  | VEqual of t
  | VLesser of t
  | VLesserEqual of t
  | VOr of  comparator * comparator
  | VAnd of comparator * comparator
  with odn

let rec version_compare v1 v2 =
  compare v1 v2

let version_of_string str =
  let is_digit c =
    '0' <= c && c <= '9'
  in

  let str_len =
    String.length str
  in

  let buff =
    Buffer.create str_len
  in

  let rec extract_filter test start = 
    if start < str_len && test str.[start] then
      (
        Buffer.add_char buff str.[start];
        extract_filter test (start + 1)
      )
    else
      (
        let res =
          Buffer.contents buff
        in
          Buffer.clear buff;
          res, start
      )
  in

  let extract_int vpos =
    let str, vpos =
      extract_filter is_digit vpos
    in
      int_of_string str, vpos
  in

  let extract_non_int vpos =
    extract_filter 
      (fun c -> not (is_digit c)) 
      vpos
  in

  let rec parse_aux pos =
    if pos < str_len then
      begin
        if is_digit str.[pos] then
          begin
            let vl, end_pos =
              extract_int pos
            in
              VInt (vl, parse_aux end_pos)
          end
        else
          begin
            let vl, end_pos =
              extract_non_int pos
            in
              VNonInt (vl, parse_aux end_pos)
          end
      end
    else
      VEnd 
  in

  let rec compress =
    function
      | VInt (i, VNonInt(".", (VInt _ as tl))) ->
          VInt (i, compress tl)
      | VInt (i, tl) ->
          VInt (i, compress tl)
      | VNonInt (i, tl) ->
          VNonInt (i, compress tl)
      | VEnd ->
          VEnd
  in

    compress (parse_aux 0)

let rec string_of_version =
  function
    | VInt (i, (VInt _ as tl)) ->
        (string_of_int i)^"."^(string_of_version tl)
    | VInt (i, tl) -> 
        (string_of_int i)^(string_of_version tl)
    | VNonInt (s, tl) -> 
        s^(string_of_version tl)
    | VEnd -> ""

let rec comparator_apply v op =
  match op with
    | VGreater cv ->
        (version_compare v cv) > 0
    | VGreaterEqual cv ->
        (version_compare v cv) >= 0
    | VLesser cv ->
        (version_compare v cv) < 0
    | VLesserEqual cv ->
        (version_compare v cv) <= 0
    | VEqual cv ->
        (version_compare v cv) = 0
    | VOr (op1, op2) ->
        (comparator_apply v op1) || (comparator_apply v op2)
    | VAnd (op1, op2) ->
        (comparator_apply v op1) && (comparator_apply v op2)

let rec string_of_comparator =
  function 
    | VGreater v  -> "> "^(string_of_version v)
    | VEqual v    -> "= "^(string_of_version v)
    | VLesser v   -> "< "^(string_of_version v)
    | VGreaterEqual v -> ">= "^(string_of_version v)
    | VLesserEqual v  -> "<= "^(string_of_version v)
    | VOr (c1, c2)  -> 
        (string_of_comparator c1)^" || "^(string_of_comparator c2)
    | VAnd (c1, c2) -> 
        (string_of_comparator c1)^" && "^(string_of_comparator c2)

let rec varname_of_comparator =
  let concat p v = 
    OASISUtils.varname_concat
      p 
      (OASISUtils.varname_of_string 
         (string_of_version v))
  in
    function 
      | VGreater v -> concat "gt" v
      | VLesser v  -> concat "lt" v
      | VEqual v   -> concat "eq" v
      | VGreaterEqual v -> concat "ge" v
      | VLesserEqual v  -> concat "le" v
      | VOr (c1, c2) ->
          (varname_of_comparator c1)^"_or_"^(varname_of_comparator c2)
      | VAnd (c1, c2) ->
          (varname_of_comparator c1)^"_and_"^(varname_of_comparator c2)

(* END EXPORT *)

open OASISUtils
open OASISVersion_types

let comparator_of_string str =
  let lexbuf =
    Lexing.from_string str
  in
  let rec parse_aux =
    function
      | VCAnd (c1, c2) -> VAnd (parse_aux c1, parse_aux c2)
      | VCOr (c1, c2)  -> VOr (parse_aux c1, parse_aux c2)
      | VCGt s -> VGreater (version_of_string s)
      | VCGe s -> VGreaterEqual (version_of_string s)
      | VCEq s -> VEqual (version_of_string s)
      | VCLt s -> VLesser (version_of_string s)
      | VCLe s -> VLesserEqual (version_of_string s)
  in
    try 
      parse_aux 
        (OASISVersion_parser.main 
           OASISVersion_lexer.token lexbuf)
    with e ->
      failwithf2
        (f_ "Error while parsing '%s': %s")
        str
        (Printexc.to_string e)

let rec comparator_reduce =
  function
    | VAnd (v1, v2) ->
        (* TODO: this can be improved to reduce more *)
        let v1 = 
          comparator_reduce v1
        in
        let v2 = 
          comparator_reduce v2
        in
          if v1 = v2 then
            v1
          else
            VAnd (v1, v2) 
    | cmp ->
        cmp

open OASISValues

let value =
  {
    parse  = (fun ~ctxt s -> version_of_string s);
    update = update_fail;
    print  = string_of_version;
  }

let comparator_value = 
  {
    parse  = (fun ~ctxt s -> comparator_of_string s);
    update = update_fail;
    print  = string_of_comparator;
  }

