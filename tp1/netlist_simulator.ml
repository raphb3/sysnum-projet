open Netlist_ast

let print_only = ref false
let number_steps = ref (-1)

let valeur_arg a env =
  match a with
  | Avar x -> Env.find x env
  | Aconst x -> x

let vbitarray_convert value =
  match value with
  | VBitArray arr -> arr
  | VBit a -> Array.make 1 a 

let convert_read_addr addr =
  let str = ref "" in
  begin match addr with
  | VBitArray arr -> Array.iter (fun b -> if b then str := !str ^ "1" else str := !str ^ "0") arr
  | VBit a -> if a then str := "1" else str := "0" end;
  let n = ref ((String.length !str)-1) in 
  let result = ref 0 in
  String.iter (fun c -> begin if c = '1' then
    result := !result + (int_of_float (2. ** float_of_int (!n))) end;
    n := (!n)-1 ) !str;
  !result

let create_memory addr_size word_size =
  Array.init (int_of_float (2. ** float_of_int (addr_size))) (fun _ -> Array.make word_size false)

let write_ram env_mem env program =
  List.iter (fun (id, e) -> 
    match e with
    | Eram (_, _, _, write_enable, write_addr, data) -> begin if (valeur_arg write_enable env) = (VBit true) then 
      let addr = (convert_read_addr (valeur_arg write_addr env)) in
      (Env.find id env_mem).(addr) <- (vbitarray_convert (valeur_arg data env)) end
    | _ -> ()) program.p_eqs

let env_mem_init program =
  let env_mem = ref Env.empty in
  List.iter (fun (id, e) -> 
    match e with  
    | Eram (addr_size, word_size, _, _, _, _) -> env_mem := Env.add id (create_memory addr_size word_size) !env_mem
    | Erom (addr_size, word_size, _) -> env_mem := Env.add id (create_memory addr_size word_size) !env_mem
    | _ -> ()) program.p_eqs;
  !env_mem

let env_prec_init program =
  let env_prec = ref Env.empty in
  Env.iter (fun id ty -> 
    match ty with 
    | TBit -> env_prec := Env.add id (VBit false) !env_prec
    | TBitArray n -> env_prec := Env.add id (VBitArray (Array.make n false)) !env_prec) program.p_vars;
  !env_prec

let read_entries program env_prec =
  let env = ref env_prec in
  List.iter (fun id -> 
    match Env.find id program.p_vars with
    | TBit -> 
        Printf.printf "%s ? (veuillez entrer un bit, 1 ou 0) %!" id;
        let input = read_line () in
        if input = "1" then
          env := Env.add id (VBit true) !env
        else
          env := Env.add id (VBit false) !env
    | TBitArray n ->
        Printf.printf "%s ? (veuillez entrer une nappe de taille %d 1 ou 0) %!" id n;
        let input = read_line () in
        let nappe = Array.init n (fun i -> 
          if input.[i] = '1' then
            true
          else
            false) in
        env := Env.add id (VBitArray nappe) !env) program.p_inputs;
  !env

let print_outputs program env =
  List.iter (fun id -> 
    match Env.find id program.p_vars with
    | TBit -> 
      if (Env.find id env) = (VBit true) then
        Printf.printf "%s = 1\n" id
      else
        Printf.printf "%s = 0\n" id 
    | TBitArray n ->
      let bus = vbitarray_convert (Env.find id env) in
      let array = Array.init n (fun i -> if bus.(i) = true then 1 else 0) in
      Printf.printf "%s = " id;
      Array.iter (fun b -> Printf.printf "%d" b) array;
      print_newline () ) program.p_outputs

let binop_eval bin =
  match bin with
  | Or -> (fun (b1, b2) -> b1 || b2)
  | And -> (fun (b1, b2) -> b1 && b2)
  | Xor -> (fun (b1, b2) -> (b1 || b2) && not (b1 && b2))
  | Nand -> (fun (b1, b2) -> not (b1 && b2))

let evaluer eq env env_prec env_mem =
  let (ident, e) = eq in
  match e with
  | Earg a -> valeur_arg a env
  | Enot a -> begin match valeur_arg a env with
    | VBit x -> VBit (not x)
    | VBitArray arr -> VBitArray (Array.init (Array.length arr) (fun i -> not arr.(i))) end
  | Ereg a -> Env.find a env_prec
  | Ebinop (bi, a1, a2) -> begin match valeur_arg a1 env, valeur_arg a2 env with 
    | VBit b1, VBit b2 -> 
      VBit (((binop_eval bi) (b1, b2)))
    | VBitArray arr1, VBitArray arr2 -> 
      VBitArray (Array.init (Array.length arr1) (fun i -> (binop_eval bi) (arr1.(i), arr2.(i)))) 
    | VBit _, VBitArray _ -> failwith "mauvaise netlist"
    | VBitArray _, VBit _ -> failwith "mauvaise netlist" end
  | Emux (c, a1, a2) ->
    let select = valeur_arg c env in
    if select = VBit true then 
      valeur_arg a2 env
    else 
      valeur_arg a1 env 
  | Erom (_, _, ra) -> 
    let addr = convert_read_addr (valeur_arg ra env) in
    VBitArray (Env.find ident env_mem).(addr)
  | Eram (_, _, ra, _, _, _) -> 
    let addr = convert_read_addr (valeur_arg ra env) in
    VBitArray (Env.find ident env_mem).(addr)
  | Econcat (a1, a2) ->
    let bus1 = valeur_arg a1 env in
    let bus2 = valeur_arg a2 env in 
    VBitArray (Array.append (vbitarray_convert bus1) (vbitarray_convert bus2))
  | Eslice (i1, i2, a) ->
    let bus = vbitarray_convert (valeur_arg a env) in 
    VBitArray (Array.sub bus i1 (i2-i1+1))
  | Eselect (i, a) -> 
    let bus = vbitarray_convert (valeur_arg a env) in
    VBit bus.(i)
  
let simulator program number_steps = 
  let env_prec = ref (env_prec_init program) in
  let env_mem = (env_mem_init program) in 
  for i = 1 to number_steps do
    Printf.printf "Step %d:\n" i;
    let env = ref (read_entries program !env_prec) in
    List.iter (fun (id, e) -> 
      env := Env.add id (evaluer (id, e) !env !env_prec env_mem) !env) program.p_eqs;
    write_ram env_mem !env program;
    print_outputs program !env;
    env_prec := !env
    done

let compile filename =
  try
    let p = Netlist.read_file filename in
    begin try
        let p = Scheduler.schedule p in
        simulator p !number_steps
      with
        | Scheduler.Combinational_cycle ->
            Format.eprintf "The netlist has a combinatory cycle.@.";
    end;
  with
    | Netlist.Parse_error s -> Format.eprintf "An error accurred: %s@." s; exit 2

let main () =
  Arg.parse
    ["-n", Arg.Set_int number_steps, "Number of steps to simulate"]
    compile
    ""
;;

main ()
