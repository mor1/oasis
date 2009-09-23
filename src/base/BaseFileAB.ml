
(** File .ab which content will be replaced by environment variable
   
    This is the same kind of file as .in file for autoconf, except we
    use the variable definition of ${!Buffer.add_substitute}. This is 
    the default file to be generated by configure step (even for 
    autoconf, except that it produce a master file before).

    @author Sylvain Le Gall
  *)

open BaseEnvironment;;

let to_filename fn =
  if not (Filename.check_suffix fn ".ab") then
    BaseMessage.warning 
      (Printf.sprintf 
         "File '%s' doesn't have '.ab' extension"
         fn);
  Filename.chop_extension fn
;;

(** Replace variable in file %.ab to generate %
  *)
let replace fn_lst env =
  let renv =
    ref env
  in
  let buff =
    Buffer.create 13
  in
    List.iter
      (fun fn ->
         let chn_in =
           open_in fn
         in
         let chn_out =
           open_out (to_filename fn)
         in
           (
             try
               while true do
                Buffer.add_string buff (var_expand renv (input_line chn_in));
                Buffer.add_char buff '\n'
               done
             with End_of_file ->
               ()
           );
           Buffer.output_buffer chn_out buff;
           Buffer.clear buff;
           close_in chn_in;
           close_out chn_out)
      fn_lst;
    !renv
;;
