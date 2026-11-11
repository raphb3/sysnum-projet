open Netlist_ast
open Graph

exception Combinational_cycle

let vars_of_arg a =
  match a with
  | Avar x -> [x]
  | Aconst _ -> []

let read_exp eq =
  let (_, e) = eq in
  match e with
  | Earg a -> vars_of_arg a
  | Ereg _ -> []
  | Enot a -> vars_of_arg a
  | Ebinop (_, a1, a2) -> vars_of_arg a1 @ vars_of_arg a2
  | Emux (a1, a2, a3) -> vars_of_arg a1 @ vars_of_arg a2 @ vars_of_arg a3
  | Erom (_, _, ra) -> vars_of_arg ra
  | Eram (_, _, ra, _, _, _) -> vars_of_arg ra
  | Econcat (a1, a2) -> vars_of_arg a1 @ vars_of_arg a2
  | Eslice (_, _, a) -> vars_of_arg a
  | Eselect (_, a) -> vars_of_arg a



let schedule p =
  let g = mk_graph () in
  List.iter (fun x -> add_node g x) p.p_inputs;
  List.iter (fun (x, _) -> add_node g x) p.p_eqs;
  List.iter (fun eq ->
    let (x, _) = eq in
    List.iter (fun a -> add_edge g a x) (read_exp eq)
  ) p.p_eqs;
  let ordre =
    try topological g
    with Cycle -> raise Combinational_cycle
  in
  let liste = ref [] in
  List.iter (fun x ->
    try
      let e = List.assoc x p.p_eqs in
      liste := (x, e) :: !liste
    with Not_found -> ()
  ) ordre;
  { p with p_eqs = List.rev !liste }