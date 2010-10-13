(*=====================================================================  *)
(* FILE          : quantHeuristicsLib.sml                                *)
(* DESCRIPTION   : some code to find instantations for quantified        *)
(*                 variables                                             *)
(*                                                                       *)
(* AUTHORS       : Thomas Tuerk                                          *)
(* DATE          : December 2008                                         *)
(* ===================================================================== *)


structure quantHeuristicsLib :> quantHeuristicsLib =
struct

(*
quietdec := true;
loadPath :=
            (concat [Globals.HOLDIR, "/src/quantHeuristics"])::
            !loadPath;

map load ["quantHeuristicsTheory"];
load "ConseqConv"
show_assums := true;
quietdec := true;
*)

open HolKernel Parse boolLib Drule ConseqConv

(*
quietdec := false;
*)


(*******************************************************
 * Some general auxiliary functions
 *******************************************************)

fun mapPartial f = ((map valOf) o (filter isSome) o (map f));

fun say_HOL_WARNING funname warning =
    Feedback.HOL_WARNING "quantHeuristicsBasicLib" funname warning


(*---------------------------------------------------------
 *      A |-  t1 = t2
 * ---------------------------- (v not free in A)
 *  A |- (?v. t1)  =  (?v. t2)
 *---------------------------------------------------------*)

fun EQ_EXISTS_INTRO (v,thm) =
  AP_TERM (inst [alpha |-> (type_of v)] (boolSyntax.existential)) (ABS v thm);

(*---------------------------------------------------------
 *      A |-  t1 = t2
 * ---------------------------- (v not free in A)
 *  A |- (!v. t1) = (!v. t2)
 *---------------------------------------------------------*)
fun EQ_FORALL_INTRO (v,thm) =
  AP_TERM (inst [alpha |-> (type_of v)] (boolSyntax.universal)) (ABS v thm);


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ---------------------------- (v not free in A)
 *  A |- (?v. t1) ==> (?v. t2)
 *---------------------------------------------------------*)

fun IMP_EXISTS_INTRO (v,thm) =
   HO_MATCH_MP boolTheory.MONO_EXISTS (GEN v thm)


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ---------------------------- (v not free in A)
 *  A |- (!v. t1) ==> (!v. t2)
 *---------------------------------------------------------*)
fun IMP_FORALL_INTRO (v,thm) =
   HO_MATCH_MP boolTheory.MONO_ALL (GEN v thm)


(*---------------------------------------------------------
 *   t1 ==> t2 ==> t3
 * ------------------------
 *    t1 /\ t2 ==> t3
 *---------------------------------------------------------*)
fun AND_IMP_INTRO_CONV t =
let
   val (t1, t23) = dest_imp t
   val (t2, t3) = dest_imp t23
in
   SPECL [t1,t2,t3] AND_IMP_INTRO
end;


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ------------------------------
 *  A |- (x /\ t1) ==> (x /\ t2)
 *---------------------------------------------------------*)
fun LEFT_IMP_AND_INTRO_RULE x thm =
let
   val (t1, t2) = dest_imp (concl thm)
   val thm2 = SPECL [x,t1,t2] quantHeuristicsTheory.LEFT_IMP_AND_INTRO
in
   MP thm2 thm
end;


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ------------------------------
 *  A |- (t1 /\ x) ==> (t2 /\ x)
 *---------------------------------------------------------*)
fun RIGHT_IMP_AND_INTRO_RULE x thm =
let
   val (t1, t2) = dest_imp (concl thm)
   val thm2 = SPECL [x,t1,t2] quantHeuristicsTheory.RIGHT_IMP_AND_INTRO
in
   MP thm2 thm
end;


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ------------------------------
 *  A |- (x \/ t1) ==> (x \/ t2)
 *---------------------------------------------------------*)
fun LEFT_IMP_OR_INTRO_RULE x thm =
let
   val (t1, t2) = dest_imp (concl thm)
   val thm2 = SPECL [x,t1,t2] quantHeuristicsTheory.LEFT_IMP_OR_INTRO
in
   MP thm2 thm
end;


(*---------------------------------------------------------
 *      A |-  t1 ==> t2
 * ------------------------------
 *  A |- (t1 \/ x) ==> (t2 \/ x)
 *---------------------------------------------------------*)
fun RIGHT_IMP_OR_INTRO_RULE x thm =
let
   val (t1, t2) = dest_imp (concl thm)
   val thm2 = SPECL [x,t1,t2] quantHeuristicsTheory.RIGHT_IMP_OR_INTRO
in
   MP thm2 thm
end;



(*---------------------------------------------------------
 *   t
 * -----
 *  ~~t
 *---------------------------------------------------------*)
fun NEG_NEG_INTRO_CONV t = ISPEC t (GSYM satTheory.NOT_NOT);

(*---------------------------------------------------------
 *  ~~t
 * -----
 *   t
 *---------------------------------------------------------*)
fun NEG_NEG_ELIM_CONV t =
    (ISPEC (dest_neg (dest_neg t)) satTheory.NOT_NOT) handle HOL_ERR _ => raise UNCHANGED;


(*---------------------------------------------------------
 *  ~(!x1 ... xn. P)
 * ------------------
 *   ?x1 ... xn. ~P
 *---------------------------------------------------------*)
fun NOT_FORALL_LIST_CONV tm =
  (NOT_FORALL_CONV THENC TRY_CONV (QUANT_CONV NOT_FORALL_LIST_CONV)) tm

(*---------------------------------------------------------
 *  ~(?x1 ... xn. P)
 * ------------------
 *   !x1 ... xn. ~P
 *---------------------------------------------------------*)
fun NOT_EXISTS_LIST_CONV tm =
  (NOT_EXISTS_CONV THENC TRY_CONV (QUANT_CONV NOT_EXISTS_LIST_CONV)) tm;


(*---------------------------------------------------------
 * Strips n leading quantifiers and applies conv underneath
 *---------------------------------------------------------*)
fun STRIP_NUM_QUANT_CONV 0 conv = conv
  | STRIP_NUM_QUANT_CONV n conv =
    QUANT_CONV (STRIP_NUM_QUANT_CONV (n-1) conv)


(*---------------------------------------------------------
 *  ~(?x1 ... xn xn+1... xm. P)
 * -----------------------------
 *   !x1 ... xn ~?xn+1 ...xm. P
 *---------------------------------------------------------*)
fun BOUNDED_NOT_EXISTS_LIST_CONV 0 tm = ALL_CONV tm
  | BOUNDED_NOT_EXISTS_LIST_CONV n tm =
  (NOT_EXISTS_CONV THENC (QUANT_CONV
                         (BOUNDED_NOT_EXISTS_LIST_CONV (n-1)))) tm;


(*repeats a conversion up to a given number of times*)
fun BOUNDED_REPEATC 0 conv tm = ALL_CONV tm
  | BOUNDED_REPEATC n conv tm =
    ((QCHANGED_CONV conv THENC (BOUNDED_REPEATC (n-1) conv)) ORELSEC ALL_CONV) tm;


(*---------------------------------------------------------
 *  ?x1 ... xn. ~P
 * ----------------
 *  ~!x1 ... xn. P
 *---------------------------------------------------------*)
fun EXISTS_NOT_LIST_CONV tm =
  (TRY_CONV (QUANT_CONV EXISTS_NOT_LIST_CONV) THENC
   EXISTS_NOT_CONV) tm;

(*---------------------------------------------------------
 *  !x1 ... xn. ~P
 * ----------------
 *  ~?x1 ... xn. P
 *---------------------------------------------------------*)
fun FORALL_NOT_LIST_CONV tm =
  (TRY_CONV (QUANT_CONV FORALL_NOT_LIST_CONV) THENC
   FORALL_NOT_CONV) tm;



(*---------------------------------------------------------
 *  !x. P x   ?x. P x
 * --------- ---------  for x not free in P
 *     P         P
 *---------------------------------------------------------*)
fun QUANT_SIMP_CONV t =
    if (is_exists t) then
       let
          val (v,b) = dest_exists t;
          val _ = if mem v (free_vars b) then raise UNCHANGED else ();
       in
          HO_PART_MATCH lhs boolTheory.EXISTS_SIMP t
       end
    else if (is_forall t) then
       let
          val (v,b) = dest_forall t;
          val _ = if mem v (free_vars b) then raise UNCHANGED else ();
       in
          HO_PART_MATCH lhs boolTheory.FORALL_SIMP t
       end
    else raise UNCHANGED;



(*---------------------------------------------------------
 *  ~(A \/ B)    ~(A /\ B)    ~A /\ ~B     ~A \/ ~B
 * -----------  -----------  -----------  -----------
 *  ~A /\ ~B     ~A \/ ~B     ~(A \/ B)    ~(A /\ B)
 *---------------------------------------------------------*)
local
   val thmL = CONJUNCTS (SPEC_ALL DE_MORGAN_THM)
   val thm_and = GEN_ALL (el 1 thmL)
   val thm_or = GEN_ALL (el 2 thmL)
in
    fun NOT_OR_CONV t =
    let
       val (t1,t2) = dest_disj (dest_neg t);
    in
       SPECL [t2,t1] thm_or
    end;

    fun NOT_AND_CONV t =
    let
       val (t1,t2) = dest_conj (dest_neg t);
    in
       SPECL [t2,t1] thm_and
    end;


    fun AND_NOT_CONV t =
    let
       val (t1,t2) = dest_conj t;
    in
       SPECL [dest_neg t2,dest_neg t1] (GSYM thm_or)
    end;

    fun OR_NOT_CONV t =
    let
       val (t1,t2) = dest_disj t;
    in
       SPECL [dest_neg t2,dest_neg t1] (GSYM thm_and)
    end;

end;




(*Renames the bound variables in a term to make them distinct*)


local
fun vc vL t =
   case dest_term t of
       VAR  _        => (vL, NONE)
     | CONST _       => (vL, NONE)
     | COMB (t1, t2) =>
       let
          val (vL' , thm1_opt) = vc vL t1;
          val (vL'', thm2_opt) = vc vL' t2;
          val thm_opt = if not (isSome thm1_opt orelse isSome thm2_opt) then NONE else
              let
                 val thm1 = if (isSome thm1_opt) then valOf thm1_opt else REFL t1;
                 val thm2 = if (isSome thm2_opt) then valOf thm2_opt else REFL t2;
              in
                 SOME (MK_COMB (thm1, thm2))
              end;
       in
          (vL'', thm_opt)
       end
     | LAMB (v, _) =>
       let
          val v' = variant vL v;
          val (thm_v_opt,b) =
              if aconv v v' then (NONE,body t) else
              let
                 val thm_v = ALPHA_CONV v' t;
                 val b = body (rhs (concl thm_v))
              in
                 (SOME thm_v, b)
              end;
          val (vL' , thm_b_opt) = vc (v'::vL) b;
          val thm_opt = if not (isSome thm_v_opt orelse isSome thm_b_opt) then NONE else
              let
                 val thm_v = if (isSome thm_v_opt) then valOf thm_v_opt else REFL t;
                 val thm_b = if (isSome thm_b_opt) then valOf thm_b_opt else REFL b;
              in
                 SOME (TRANS thm_v (ABS v' thm_b))
              end;
       in
         (v'::vL', thm_opt)
       end;
in
   fun VARIANT_CONV fvL t =
   let
       val (_, thm_opt) = vc (append fvL (free_vars t)) t;
   in
      if isSome thm_opt then valOf thm_opt else raise UNCHANGED
   end;



   fun VARIANT_TAC fvL (asm, t) =
   let
       val fvL0 = append fvL (flatten (map free_vars (t::asm)));

       fun vc_asms fvL [] = ([],[])
         | vc_asms fvL (asm::L) =
             let
                val (fvL', thm_opt) = (vc fvL asm);
                val thm = if isSome thm_opt then valOf thm_opt else REFL asm;
                val t' = rhs (concl thm);
                val (tL, thmL) = vc_asms fvL' L;
             in
                ((t'::tL),(thm::thmL))
             end
       val (t'::asm', t_thm::asm_thms) = vc_asms fvL0 (t::(rev asm))

       val new_goal = (rev asm', t');
       (*val goal_thm = mk_thm new_goal*)

       fun valid goal_thm =
           let
              val thm0 = EQ_MP (GSYM t_thm) goal_thm
              fun asm_mp (a_thm,thm0) =
                let
                  val a_imp_thm = (fst (EQ_IMP_RULE a_thm))
                  val thm1 = DISCH (snd (dest_imp (concl a_imp_thm))) thm0
                  val thm2 = MP thm1 (UNDISCH a_imp_thm)
                in
                  thm2
                end;
           in
              foldl asm_mp thm0 asm_thms
           end;
   in
      ([new_goal], fn thmL => (valid (hd thmL)))
   end;
end



(*******************************************************
 * Contextual rewriting
 * Before trying to find guesses for a variable, it
 * is useful to minimize occurences of this variable.
 * Consider for example
 *
 * ?x. P /\ (f x = f 2) /\ Q (f x) /\ Z
 *
 * This is equivalent to
 *
 * ?x. P /\ (f x = f 2) /\ Q (f 2) /\ Z
 * and therefore x can savely be instantiated by 2
 *     P /\ (f 2 = f 2) /\ Q (f 2) /\ Z
 *
 * however that's difficult to see, before the
 * contextual rewriting took place.
 *******************************************************)

datatype context_rw_type =
 crw_conj | crw_disj | crw_unknown;

fun crw_negate crw_conj = crw_disj
  | crw_negate crw_disj = crw_conj
  | crw_negate crw_unknown = crw_unknown;


fun dest_disj_imp t =
   dest_disj t handle HOL_ERR _ =>
   let val (a,b) = dest_imp_only t in
       (mk_neg a, b) end

val is_disj_imp = can dest_disj_imp;


fun crw_strip rwt t =
  if (is_conj t andalso not (rwt = crw_disj)) then
     let
        val (t1,t2) = dest_conj t;
        val (l1,_) = crw_strip crw_conj t1;
        val (l2,_) = crw_strip crw_conj t2;
     in
        (append l1 l2, crw_conj)
     end
  else if (is_disj_imp t andalso not (rwt = crw_conj)) then
     let
        val (t1,t2) = dest_disj_imp t;
        val (l1,_) = crw_strip crw_disj t1;
        val (l2,_) = crw_strip crw_disj t2;
     in
        (append l1 l2, crw_disj)
     end
  else if (is_neg t) then
     let
        val t1 = dest_neg t;
        val rwt1 = crw_negate rwt;
        val (l1,rwt2) = crw_strip rwt1 t1;
        val rwt3 = crw_negate rwt2;
     in
        (l1, rwt3)
     end
  else (if is_eq t andalso (rwt = crw_conj) then [t] else
        if type_of t = bool then [mk_eq(t,
             if rwt = crw_conj then T else F)] else [], rwt)


(*
   val t = ``~~((a \/ P) /\ (f x = f 2) /\ Q (f x) /\ Z)``
   val t = ``~~((a \/ P) /\ (f 2 = f x) /\ Q (f x) /\ Z)``
   val t = ``(P /\ (f x = f 2)) ==> Q (f x)``
   val t = ``~(P x) /\ (f x = f 2) /\ ((P x) \/ A)``
   val t = ``(P \/ ~(f x = f 2)) \/ ~(x = 5)``

val v = ``x:num``
min_var_occur_CONV v t
*)

fun crw_SINGLE_STEP_CONV (rw, turned) t =
let
   val (l,r) = dest_eq rw;

   val dummy_var = genvar bool;
   val org_rw_term = if same_const r T orelse same_const r F then l else
       if turned then mk_eq (r,l) else rw;

   val t1 = subst_occs [[1]] [org_rw_term |-> dummy_var] t
   val t2 = subst [l |-> r] t1
   val t3 = subst [dummy_var |-> org_rw_term] t2;

   val eq_t = mk_eq (t, t3);

   val thm_t = EQT_ELIM (REWRITE_CONV [ASSUME org_rw_term] eq_t)
   val thm_f = EQT_ELIM (REWRITE_CONV (
        let val athm = ASSUME (mk_neg org_rw_term) in
        [athm, GSYM athm] end) eq_t);

   val thm = DISJ_CASES (ISPEC org_rw_term boolTheory.EXCLUDED_MIDDLE) thm_t thm_f
in
   thm
end handle HOL_ERR _ => raise UNCHANGED;

fun crw_TOP_CONV P t =
let
   val (eql, rwt) = crw_strip crw_unknown t;
   val _ = if (rwt = crw_unknown) then raise UNCHANGED else ();

   fun turn_eq rw =
      let val (l,r) = dest_eq rw in mk_eq (r,l) end;

   fun check_rw P rw =
      case P rw of
         NONE => NONE
       | SOME false => SOME (rw,false)
       | SOME true  => SOME (turn_eq rw, true)

   val eql' = map valOf (filter isSome (map (check_rw P) eql));
   val convL = map crw_SINGLE_STEP_CONV eql';
   val _ = if null convL then raise UNCHANGED else ();
in
   EVERY_CONV convL t
end;


fun crw_CONV P = TOP_SWEEP_CONV (CHANGED_CONV (crw_TOP_CONV P));

val min_var_occur_CONV =
let
   fun P v rw =
   let
      val (l,r) = dest_eq rw;
      val lf = free_in v l;
      val rf = free_in v r;
   in
      if (is_conj l) orelse (is_disj_imp l) then NONE else
      if lf andalso (not rf) then SOME false else
      if (not lf) andalso rf then SOME true else
      NONE
   end;
in
   fn v => (crw_CONV (P v))
end;




(*******************************************************
 * Datatype for guesses and some general functions on
 * these guesses
 *******************************************************)


(*Heuristics can come up with guessed instantiations
  of a universal or existential quantifier for different reasons.
  The datatype guess captures these guesses and the reason.

  Let us consider terms of the form
  ?v. P v and !v. P v.

  A heuristic tries to guess an instatiation for uv / ev based on
  the body for the following reasons. All guesses consist of
  a instatiation, a list of free variables in this instatiation and
  perhaps a theorem justifying the guess.
  Let in the following i denote the guess and [fv1, ..., fvn] be the free variables in i.
  Then there are the following types of guesses:
*)

datatype guess =
    guess_general of term * term list
  | guess_false of term * term list * (unit -> thm) option
  | guess_true of term * term list * (unit -> thm) option
  | guess_only_not_possible of term * term list * (unit -> thm) option
  | guess_only_possible of term * term list * (unit -> thm) option
  | guess_others_not_possible of term * term list * (unit -> thm) option
  | guess_others_satisfied of term * term list * (unit -> thm) option;




fun is_guess_general (guess_general _) = true
  | is_guess_general _ = false;


fun is_guess_true proof (guess_true (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_true _ _ = false;


fun is_guess_false proof (guess_false (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_false _ _ = false;

fun is_guess_only_possible proof (guess_only_possible (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_only_possible _ _ = false;

fun is_guess_only_not_possible proof (guess_only_not_possible (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_only_not_possible _ _ = false;

fun is_guess_others_not_possible proof (guess_others_not_possible (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_others_not_possible _ _ = false;

fun is_guess_others_satisfied proof (guess_others_satisfied (_,_,thm_opt)) =
       ((not proof) orelse (isSome thm_opt))
  | is_guess_others_satisfied _ _ = false;



type guess_collection =
   {rewrites            : thm list,
    general             : guess list,
    true                : guess list,
    false               : guess list,
    only_possible       : guess list,
    only_not_possible   : guess list,
    others_not_possible : guess list,
    others_satisfied    : guess list}


val empty_guess_collection =
   {rewrites            = [],
    general             = [],
    true                = [],
    false               = [],
    only_possible       = [],
    only_not_possible   = [],
    others_not_possible = [],
    others_satisfied    = []}:guess_collection



fun is_empty_guess_collection (gc:guess_collection) =
   (null (#rewrites gc)) andalso
   (null (#general gc)) andalso
   (null (#true gc)) andalso
   (null (#false gc)) andalso
   (null (#only_possible gc)) andalso
   (null (#only_not_possible gc)) andalso
   (null (#others_not_possible gc)) andalso
   (null (#others_satisfied gc))


fun guess_collection_append (c1:guess_collection) (c2:guess_collection) =
   {rewrites            = append (#rewrites c1) (#rewrites c2),
    general             = append (#general c1) (#general c2),
    true                = append (#true c1) (#true c2),
    false               = append (#false c1) (#false c2),
    only_possible       = append (#only_possible c1) (#only_possible c2),
    only_not_possible   = append (#only_not_possible c1) (#only_not_possible c2),
    others_not_possible = append (#others_not_possible c1) (#others_not_possible c2),
    others_satisfied    = append (#others_satisfied c1) (#others_satisfied c2)}:guess_collection


fun guess_collection_flatten [] = empty_guess_collection
  | guess_collection_flatten (NONE::L) = guess_collection_flatten L
  | guess_collection_flatten ((SOME gc)::L) =
    guess_collection_append gc (guess_collection_flatten L);


local
fun guess_list2collection___int gp [] = gp
  | guess_list2collection___int (g1,g3,g4,g5,g6,g7,g8) (guess::gL) =
      let
         val g1 = if (is_guess_general guess) then guess::g1 else g1;
         val g3 = if (is_guess_true false guess) then guess::g3 else g3;
         val g4 = if (is_guess_false false guess) then guess::g4 else g4;
         val g5 = if (is_guess_only_possible false guess) then guess::g5 else g5;
         val g6 = if (is_guess_only_not_possible false guess) then guess::g6 else g6;
         val g7 = if (is_guess_others_not_possible false guess) then guess::g7 else g7;
         val g8 = if (is_guess_others_satisfied false guess) then guess::g8 else g8;
      in
         guess_list2collection___int (g1,g3,g4,g5,g6,g7,g8) gL
      end;
in
   fun guess_list2collection (rewL, gL) =
   let
      val (g1,g3,g4,g5,g6,g7,g8) = guess_list2collection___int ([],[],[],[],[],[],[]) gL;
   in
      {rewrites = rewL, general = g1, true = g3, false = g4, only_possible = g5,
       only_not_possible = g6, others_not_possible = g7, others_satisfied = g8}:guess_collection
   end;

end;


fun guess_collection2list (gc:guess_collection) =
  (#rewrites gc,
   flatten [#general gc, #true gc, #false gc, #only_not_possible gc,
            #only_possible gc, #others_satisfied gc, #others_not_possible gc]);




fun guess_set_thm_opt thm_opt (guess_general (i,fvL)) = guess_general (i,fvL)
  | guess_set_thm_opt thm_opt (guess_true (i,fvL,_)) = guess_true (i,fvL,thm_opt)
  | guess_set_thm_opt thm_opt (guess_false (i,fvL,_)) = guess_false (i,fvL,thm_opt)
  | guess_set_thm_opt thm_opt (guess_only_not_possible (i,fvL,_)) = guess_only_not_possible (i,fvL,thm_opt)
  | guess_set_thm_opt thm_opt (guess_only_possible (i,fvL,_)) = guess_only_possible (i,fvL,thm_opt)
  | guess_set_thm_opt thm_opt (guess_others_not_possible (i,fvL,_)) = guess_others_not_possible (i,fvL,thm_opt)
  | guess_set_thm_opt thm_opt (guess_others_satisfied (i,fvL,_)) = guess_others_satisfied (i,fvL,thm_opt)



val guess_remove_thm = guess_set_thm_opt NONE



(*
val v = ``x:num``
val t = ``(P (x:num)):bool``
val i = ``SUC y + z``
val fvL = [``y:num``, ``z:num``]
*)


fun make_guess_thm_term v t (guess_general _) = NONE
  | make_guess_thm_term v t (guess_true (i,fvL,_)) =
    SOME (list_mk_forall(fvL, subst [v |-> i] t))
  | make_guess_thm_term v t (guess_false (i,fvL,_)) =
    SOME (list_mk_forall(fvL, mk_neg (subst [v |-> i] t)))
  | make_guess_thm_term v t (guess_only_not_possible (i,fvL,_)) =
    SOME (mk_imp (
       list_mk_forall(fvL, subst [v |-> i] t),
       mk_forall (v, t)))
  | make_guess_thm_term v t (guess_only_possible (i,fvL,_)) =
    SOME (mk_imp (
       list_mk_forall(fvL, subst [v |-> i] (mk_neg t)),
       mk_forall (v, mk_neg t)))
  | make_guess_thm_term v t (guess_others_satisfied (i,fvL,_)) =
    SOME (mk_forall (v, mk_imp (list_mk_forall(fvL, mk_neg (mk_eq (v,i))), t)))
  | make_guess_thm_term v t (guess_others_not_possible (i,fvL,_)) =
    SOME (mk_forall (v, mk_imp (list_mk_forall(fvL, mk_neg (mk_eq (v,i))), (mk_neg t))))



fun make_guess_thm_opt v t guess (proofConv:term->thm) =
    let
       val guess_thm_term_opt = make_guess_thm_term v t guess;
    in
       if (isSome (guess_thm_term_opt)) then
       SOME (fn () => proofConv (valOf guess_thm_term_opt)) else NONE
    end;

fun make_set_guess_thm_opt v t guess proofConv =
    guess_set_thm_opt (make_guess_thm_opt v t guess proofConv) guess;

fun make_guess_thm_opt___dummy v t guess =
    ((say_HOL_WARNING "make_guess_thm_opt___dummy"
		    "mk_thm was used to create a guess");
     make_guess_thm_opt v t guess (fn x => mk_thm ([], x)));

fun make_set_guess_thm_opt___dummy v t guess =
    ((say_HOL_WARNING "make_set_guess_thm_opt___dummy"
		    "mk_thm was used to create a guess");
    make_set_guess_thm_opt v t guess (fn x => mk_thm ([], x)));




fun guess_extract (guess_general (i,fvL)) = (i,fvL,NONE)
  | guess_extract (guess_true (i,fvL,thm_opt)) = (i,fvL,thm_opt)
  | guess_extract (guess_false (i,fvL,thm_opt)) = (i,fvL,thm_opt)
  | guess_extract (guess_only_not_possible (i,fvL,thm_opt)) = (i,fvL,thm_opt)
  | guess_extract (guess_only_possible (i,fvL,thm_opt)) = (i,fvL,thm_opt)
  | guess_extract (guess_others_not_possible (i,fvL,thm_opt)) = (i,fvL,thm_opt)
  | guess_extract (guess_others_satisfied (i,fvL,thm_opt)) = (i,fvL,thm_opt);


fun guess_has_argument guess =
    isSome (#3 (guess_extract guess));



(*_
val tref = ref NONE

val (v,t,thmL,guess) = valOf (!tref)
val fvL = [``x:num``, ``y:num``]
val rewrite_thm = GSYM (HO_PART_MATCH lhs (hd thmL) ((fst o dest_imp) (concl thm_org)))
val fv = []

val v = ``x:num``
val t = ``!t. (P (x:num) /\ Z t):bool``
val t' = ``!t. X t \/ (Q (x:num))``
val i = ``(i (y:num) (z:num)):num``
val fvL = [``y:num``, ``z:num``]

val rew_thm = mk_thm ([], mk_eq(t,t'))

val guess = make_set_guess_thm_opt___dummy v t' (guess_only_not_possible (i,fvL,NONE));
correct_guess fv v t (guess_rewrite_thm_opt v t rew_thm guess)
*)

fun guess_rewrite_thm_opt v rew_thm guess =
let
   val (i, fvL, thm_opt) = guess_extract guess;
in
   if not(isSome thm_opt) then guess else
   let
      val thm_org = valOf thm_opt;

      val t'v_conv = (K (GSYM rew_thm)):term->thm
      val t'i_conv = (K (GSYM (INST [v |-> i] rew_thm))):term->thm

      val new_thm =
        case guess of
	   guess_true _ =>
             (fn () => (CONV_RULE (STRIP_NUM_QUANT_CONV (length fvL) t'i_conv) (thm_org ())))
	 | guess_false _ =>
             (fn () => CONV_RULE (STRIP_NUM_QUANT_CONV (length fvL) (RAND_CONV t'i_conv)) (thm_org ()))
	 | guess_only_not_possible _ =>
             (fn () => CONV_RULE ((RAND_CONV (QUANT_CONV t'v_conv)) THENC
                        (RATOR_CONV (RAND_CONV (STRIP_NUM_QUANT_CONV (length fvL) t'i_conv)))) (thm_org ()))
	 | guess_only_possible _ =>
             (fn () => CONV_RULE ((RAND_CONV (QUANT_CONV (RAND_CONV t'v_conv))) THENC
                        (RATOR_CONV (RAND_CONV (STRIP_NUM_QUANT_CONV (length fvL) (RAND_CONV t'i_conv))))) (thm_org ()))
	 | guess_others_satisfied _ =>
             (fn () => CONV_RULE (QUANT_CONV (RAND_CONV t'v_conv)) (thm_org ()))
	 | guess_others_not_possible _ =>
             (fn () => CONV_RULE (QUANT_CONV (RAND_CONV (RAND_CONV t'v_conv))) (thm_org ()))
         | _ => Feedback.fail ()

   in
     guess_set_thm_opt (SOME new_thm) guess
   end handle HOL_ERR _ =>
       (say_HOL_WARNING "guess_rewrite_thm_opt"
        "Rewriting went wrong!";guess_remove_thm guess)
end;





fun term_list_to_string [] = ""
  | term_list_to_string [t] = (term_to_string t)
  | term_list_to_string (t1::t2::ts) =
    (term_to_string t1)^", "^(term_list_to_string (t2::ts))

fun thm_opt_to_string _ NONE = "-"
  | thm_opt_to_string false (SOME _) = "X"
  | thm_opt_to_string true (SOME thm) = (thm_to_string (thm ()));


fun guess_to_string show_thm (guess_general (i,fvL)) =
    "guess_general (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"])"
  | guess_to_string show_thm (guess_true (i,fvL,thm_opt)) =
    "guess_true (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")"
  | guess_to_string show_thm (guess_false (i,fvL,thm_opt)) =
    "guess_false (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")"
  | guess_to_string show_thm (guess_only_not_possible (i,fvL,thm_opt)) =
    "guess_only_not_possible (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")"
  | guess_to_string show_thm (guess_only_possible (i,fvL,thm_opt)) =
    "guess_only_possible (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")"
  | guess_to_string show_thm (guess_others_not_possible (i,fvL,thm_opt)) =
    "guess_others_not_possible (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")"
  | guess_to_string show_thm (guess_others_satisfied (i,fvL,thm_opt)) =
    "guess_others_satisfied (``"^(term_to_string i)^"``, ["^(term_list_to_string fvL)^"], "^
    (thm_opt_to_string show_thm thm_opt)^")";



fun eval_guess_thm_opt guess =
let
   val (i,fvL,thm_opt) = guess_extract guess;
in
   if not (isSome thm_opt) then guess else
   let
      val thm = (valOf thm_opt)();
   in
      guess_set_thm_opt (SOME (fn () => thm)) guess
   end
end;



fun check_guess v t guess =
   let
      val (i,fvL,thm_opt) = guess_extract guess;
      val fvL_t = free_vars t;
      val fvL_i = free_vars i;
      val thm_term_opt = make_guess_thm_term v t guess
   in
      (type_of v = type_of i) andalso
      (all (fn x => (mem x fvL_i) andalso not (mem x fvL_t)) fvL) andalso
      (not (isSome thm_opt) orelse
       let
          val thm = (valOf thm_opt) ();
          val thm_term = valOf thm_term_opt;
       in
          (hyp thm = []) andalso (concl thm = thm_term)
       end)
   end;



fun correct_guess v t guess =
let val guess' = eval_guess_thm_opt guess in
   if (check_guess v t guess') then SOME guess' else
   let
      val guess2 = guess_remove_thm guess;
      val still_error = not (check_guess v t guess2);

      val error_msg = if still_error then
                         ("Error in guess: "^(guess_to_string true guess)) else
                         ("Malformed theorem in guess:\n"^(guess_to_string true guess)^
                          "\nTheorem should be of form ``"^
                          (term_to_string (valOf (make_guess_thm_term v t guess2))) ^"``.")
      val _ = say_HOL_WARNING "correct_guess" error_msg
   in
      if still_error then NONE else SOME guess2
   end
end;


local
  fun correct_guess_list___int acc v t [] = acc
    | correct_guess_list___int acc v t (guess::gL) =
    let
       val guess_opt = correct_guess v t guess;
       val acc' = if isSome (guess_opt) then (valOf guess_opt)::acc else acc
    in
       correct_guess_list___int acc' v t gL
    end;
in
  val correct_guess_list = correct_guess_list___int []
end;


val QUANT_INSTANTIATE_HEURISTIC___max_rec_depth = ref 250;
val QUANT_INSTANTIATE_HEURISTIC___debug = ref 0;
val _ = register_trace("QUANT_INSTANTIATE_HEURISTIC", QUANT_INSTANTIATE_HEURISTIC___debug, 3);

fun correct_guess_collection v t (gc:guess_collection) =
  if (!QUANT_INSTANTIATE_HEURISTIC___debug > 0) then
  let
     val gc =
     {rewrites            = #rewrites gc,
   general             = correct_guess_list v t (#general gc),
   true                = correct_guess_list v t (#true gc),
   false               = correct_guess_list v t (#false gc),
   only_not_possible   = correct_guess_list v t (#only_not_possible gc),
   only_possible       = correct_guess_list v t (#only_possible gc),
   others_satisfied    = correct_guess_list v t (#others_satisfied gc),
   others_not_possible = correct_guess_list v t (#others_not_possible gc)}:guess_collection;

     val _ = if (all (is_guess_true false) (#true gc)) andalso
                        (all (is_guess_false false) (#false gc)) andalso
                        (all is_guess_general (#general gc)) andalso
                        (all (is_guess_only_not_possible false) (#only_not_possible gc)) andalso
                        (all (is_guess_only_possible false) (#only_possible gc)) andalso
                        (all (is_guess_others_satisfied false) (#others_satisfied gc)) andalso
                        (all (is_guess_others_not_possible false) (#others_not_possible gc)) then () else
                         say_HOL_WARNING "correct_guess_collection" "Guess-collection-invariant violated!"
  in
     gc
  end else gc;





(*
val t = ``(P (x:num)):bool``
val i = ``(XXX (y:num) (z:num)):num``;
val fvL = [``y:num``,``z:num``]
val v = ``x:num``;

val guess = make_set_guess_thm_opt___dummy v t (guess_others_satisfied (i, fvL, NONE));
val (_,_,thm_opt) = guess_extract guess;

val term_opt = make_guess_thm_term v t (guess_only_not_possible (i,fvL, NONE))

val guess = guess_others_satisfied___weaken v t (guess_others_satisfied (i, fvL, thm_opt))
correct_guess v t guess
*)


fun guess_others_satisfied___weaken v t (guess_others_satisfied (i, fvL, thm_opt)) =
let
   val thm_opt' = if not (isSome thm_opt) then NONE else
                  SOME (fn () =>
		  let
		     val v_eq_i_term = mk_eq (v,i);
		     val thm0 = UNDISCH (EQT_ELIM (REWRITE_CONV [ASSUME v_eq_i_term]
                      (mk_imp (mk_neg t, subst [v |-> i] (mk_neg t)))));
		     val thm1 = foldr (fn (v,th) => SIMPLE_EXISTS v th) thm0 fvL

		     val thm2 = DISCH v_eq_i_term thm1
                     val thm3 = foldr (fn (v,th) => CONV_RULE FORALL_IMP_CONV (GEN v th)) thm2 fvL

                     val thm4 = CONTRAPOS thm3
		     val fvl_not_exists_conv = (TRY_CONV (BOUNDED_NOT_EXISTS_LIST_CONV (length fvL)))
                     val thm5 = CONV_RULE (RAND_CONV fvl_not_exists_conv) thm4
                     val thm6 = CONV_RULE (RATOR_CONV (RAND_CONV
				(fvl_not_exists_conv THENC
                                 (STRIP_QUANT_CONV NEG_NEG_ELIM_CONV)))) thm5


                     val thm7 = IMP_TRANS thm6 (SPEC v ((valOf thm_opt) ()))


                     val thm8 = ASSUME t
                     val precond = (fst o dest_imp o concl) thm7;
		     val thm9 = DISCH precond (ADD_ASSUM precond thm8);

                     val thm10 = DISJ_CASES (SPEC t EXCLUDED_MIDDLE) thm9 thm7;

                     val thm11 = CONV_RULE FORALL_IMP_CONV (GEN v thm10)
                  in
                     thm11
                  end) handle HOL_ERR _ =>
   ((say_HOL_WARNING "guess_others_satisfied___weaken"
     ("Weakening ``"^(term_to_string v)^"``, ``"^(term_to_string t)^"``, "^(guess_to_string true
      (guess_others_satisfied (i, fvL, thm_opt)))^" failed!"));NONE)
in
  guess_only_not_possible (i,fvL, thm_opt')
end
| guess_others_satisfied___weaken v t guess = guess;





(*
val t = ``(P (x:num)):bool``
val i = ``(XXX (y:num) (z:num)):num``;
val fvL = [``y:num``,``z:num``]
val v = ``x:num``;

val thm_opt = make_guess_thm_opt___dummy v t (guess_others_not_possible (i, fvL, NONE));

val term_opt = make_guess_thm_term v t (guess_only_possible (i,fvL, NONE))

val guess = guess_false___weaken v t (guess_others_not_possible (i, fvL, thm_opt))
correct_guess v t guess
*)

fun guess_others_not_possible___weaken v t (guess_others_not_possible (i, fvL, thm_opt)) =
let
   val thm_opt' = if not (isSome thm_opt) then NONE else
                  SOME (fn () =>
		  let
		     val v_eq_i_term = (mk_eq (v,i));
		     val thm0 = UNDISCH (EQT_ELIM (REWRITE_CONV [ASSUME v_eq_i_term]
                      (mk_imp (t, subst [v |-> i] t))));
		     val thm1 = foldr (fn (v,th) => SIMPLE_EXISTS v th) thm0 fvL

		     val thm2 = DISCH v_eq_i_term thm1
                     val thm3 = foldr (fn (v,th) => CONV_RULE FORALL_IMP_CONV (GEN v th)) thm2 fvL

                     val thm4 = CONTRAPOS thm3
		     val fvl_not_exists_conv = (TRY_CONV (BOUNDED_NOT_EXISTS_LIST_CONV (length fvL)))
                     val thm5 = CONV_RULE (RAND_CONV fvl_not_exists_conv) thm4
                     val thm6 = CONV_RULE (RATOR_CONV (RAND_CONV fvl_not_exists_conv)) thm5


                     val thm7 = IMP_TRANS thm6 (SPEC v ((valOf thm_opt) ()))


                     val thm8 = ASSUME (mk_neg t)
                     val precond = (fst o dest_imp o concl) thm7;
		     val thm9 = DISCH precond (ADD_ASSUM precond thm8);


                     val thm10 = DISJ_CASES (SPEC t EXCLUDED_MIDDLE) thm7 thm9;

                     val thm11 = CONV_RULE FORALL_IMP_CONV (GEN v thm10)
                  in
                     thm11
                  end) handle HOL_ERR _ =>
   ((say_HOL_WARNING "guess_others_not_possible___weaken"
     ("Weakening ``"^(term_to_string v)^"``, ``"^(term_to_string t)^"``, "^(guess_to_string true
      (guess_others_not_possible (i, fvL, thm_opt)))^" failed!"));NONE)

in
  guess_only_possible (i,fvL, thm_opt')
end
| guess_others_not_possible___weaken v t guess = guess;



(*
val t = ``(P (x:num)):bool``
val i = ``(XXX (y:num) (z:num)):num``;
val fvL = [``y:num``,``z:num``]
val v = ``x:num``;

val thm_opt = SOME (mk_thm ([], valOf (make_guess_thm_term v t (guess_false (i, fvL, NONE)))));

make_guess_thm_term v t (guess_only_not_possible (i,fvL, NONE))

val guess = guess_false___weaken v t (guess_false (i, fvL, thm_opt))

*)


fun guess_false___weaken v t (guess_false (i, fvL, thm_opt)) =
let
   val thm_opt' = if not (isSome thm_opt) then NONE else
		  SOME (fn () =>
		  let

                     val thm0 = SPECL fvL ((valOf thm_opt) ());
                     val thm1 = foldr (fn (v,th) => SIMPLE_EXISTS v th) thm0 fvL
                     val thm2 = CONV_RULE (TRY_CONV EXISTS_NOT_LIST_CONV) thm1;

		     val thm3 = UNDISCH thm2;
                     val thm4 = CCONTR (mk_forall (v, t)) thm3
	             val thm5 = DISCH_ALL thm4
                  in
                     thm5
                  end) handle HOL_ERR _ =>
   ((say_HOL_WARNING "guess_false___weaken"
     ("Weakening ``"^(term_to_string v)^"``, ``"^(term_to_string t)^"``, "^(guess_to_string true
      (guess_false (i, fvL, thm_opt)))^" failed!"));NONE)
in
  guess_only_not_possible (i,fvL, thm_opt')
end |
guess_false___weaken v t guess = guess;


(*
val t = ``(P (x:num)):bool``
val i = ``(XXX (y:num) (z:num)):num``;
val fvL = [``y:num``,``z:num``]
val v = ``x:num``;


val guess = hd gL3
val (i,fvL,thm_opt) = guess_extract guess

val thm_opt = SOME (mk_thm ([], valOf (make_guess_thm_term v t (guess_true (i, fvL, NONE)))));

make_guess_thm_term v t (guess_only_possible (i,fvL, NONE))

val guess = guess_false___weaken v t (guess_true (i, fvL, thm_opt))
correct_guess v t guess
*)

fun guess_true___weaken v t (guess_true (i, fvL, thm_opt)) =
let
   val thm_opt' = if not (isSome thm_opt) then NONE else
                  SOME (fn () =>
		  let
                     val thm0 = SPECL fvL ((valOf thm_opt) ());
                     val thm1 = foldr (fn (v,th) => SIMPLE_EXISTS v th) thm0 fvL
                     val thm2 = CONV_RULE NEG_NEG_INTRO_CONV thm1;
                     val thm3 = CONV_RULE (TRY_CONV (RAND_CONV (BOUNDED_NOT_EXISTS_LIST_CONV (length fvL)))) thm2;

		     val thm4 = UNDISCH thm3;
                     val thm5 = CCONTR (mk_forall (v, mk_neg t)) thm4
	             val thm6 = DISCH_ALL thm5
                  in
                     thm6
                  end) handle HOL_ERR _ =>
   ((say_HOL_WARNING "guess_true___weaken"
     ("Weakening ``"^(term_to_string v)^"``, ``"^(term_to_string t)^"``, "^(guess_to_string true
      (guess_true (i, fvL, thm_opt)))^" failed!"));NONE)
in
  guess_only_possible (i,fvL, thm_opt')
end |
guess_true___weaken v t guess = guess;



fun guess_weaken v t (guess_false (i, fvL, thm_opt)) =
    guess_false___weaken v t (guess_false (i, fvL, thm_opt))
  | guess_weaken v t (guess_true (i, fvL, thm_opt)) =
    guess_true___weaken v t (guess_true (i, fvL, thm_opt))
  | guess_weaken v t (guess_others_not_possible (i, fvL, thm_opt)) =
    guess_others_not_possible___weaken v t (guess_others_not_possible (i, fvL, thm_opt))
  | guess_weaken v t (guess_others_satisfied (i, fvL, thm_opt)) =
    guess_others_satisfied___weaken v t (guess_others_satisfied (i, fvL, thm_opt))
  | guess_weaken v t guess = guess;




fun guess_collection___get_only_possible_weaken (c:guess_collection) =
    append (#true c)
   (append (#only_possible c)
	   (#others_not_possible c));

fun guess_collection___get_only_not_possible_weaken (c:guess_collection) =
    append (#false c)
   (append (#only_not_possible c)
	   (#others_satisfied c));







(*******************************************************
 *
 * Heuristics for the common boolean operations
 *
 *******************************************************)
(*
   val t = ``!l. ~(l = []) /\ P l /\ (l_hd = 5)``
   val fvL = [``l_hd:'a``, ``l_tl:'a list``]
   val i = ``l_hd::l_tl``
*)

(*renames the variables in fvL in such a way
  that they are distinct to the ones in vL. Moreover,
  the resulting substitution is applied to the
  term i *)
fun term_variant vL fvL i =
let
   val (_,sub,fvL') =
      foldl (fn (fv, (vL,sub,fvL)) =>
	  let
             val fv' = variant vL fv;
             val vL' = fv'::vL;
             val fvL' = fv'::fvL;
             val sub' = if (fv = fv') then sub else
			(fv |-> fv')::sub;
          in
             (vL',sub',fvL')
          end) (vL,[],[]) fvL;
  val i' = subst sub i
in
  (i', rev fvL')
end;


(*
   val t = ``?x:num. (P x):bool``
   val i = ``(f (x:'a) (y:'a) (z:'a)):num``
   val fvL = [``x:'a``, ``y:'a``, ``z:'a``]

Expected result:
|- (?x y z. P (f x y z)) ==> ?x. P x

*)
fun make_exists_imp_thm t i fvL =
let
   val vL = free_vars t
   val (i', fvL') = term_variant vL fvL i

   val (v,b) = dest_exists t;
   val ib = subst [v |-> i'] b;
   val ib_thm = ASSUME ib

   val thm0 = EXISTS (t,i') ib_thm
   val thm1 = foldr (fn (v,th) => SIMPLE_CHOOSE v th)
				 thm0 fvL;

   val thm2 = DISCH_ALL thm1
in
   thm2
end;




exception QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;

fun match_term_var v t1 t2 =
let
    val (s,t) = match_term t1 t2;
    val _ = if (t = []) then () else Feedback.fail ();
    val _ = if (s = []) then Feedback.fail () else ();
    val i = hd s;
    val _ = if (s = [i]) then () else Feedback.fail ();

    val _ = if (#redex i = v) then () else Feedback.fail ();
in
    #residue i
end;


(*
val t = ``7 + y + z = (x:num)``;

val t = ``x = 7``;

val t = ``x + y = x + z``;
val neg_heuL = [num_neg_heuristic]


val fv = [];
val v = ``x:num``
val sys = NONE
val neg_heuL = []
*)


type quant_heuristic = term list -> term -> term -> guess_collection;
type quant_param =
{distinct_thms      : thm list,
 cases_thms         : thm list,
 rewrite_thms       : thm list,
 convs              : conv list,
 heuristics         : (quant_heuristic -> quant_heuristic) list,
 final_rewrite_thms : thm list};


fun QUANT_INSTANTIATE_HEURISTIC___EQUATION sys (fv:term list) v t =
let
   val _ = if (is_eq t) then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;
   val (l,r) = dest_eq t;


   val (turn,top,i,s) = if (l = v) then (false, true, r,r) else
		        if (r = v) then (true,  true, l,l) else
		      (false, false, match_term_var v l r, r) handle HOL_ERR _ =>
		      (true,  false, match_term_var v r l, l) handle HOL_ERR _ =>
		      raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;


   val g_trueL = [guess_true (i, [], SOME (fn () => (REFL s)))];
   val g_others_not_possibleL = if not top then [] else
	    [guess_others_not_possible(i,[], SOME (fn () =>
               let
                  val precond = mk_neg (mk_eq (v, i));
                  val thm0 = ASSUME precond;
                  val thm1 = if turn then GSYM thm0 else thm0;
		  val thm2 = DISCH precond thm1
                  val thm3 = GEN v thm2
               in
                  thm3
               end))];

in
  {rewrites            = [],
   general             = [],
   true                = g_trueL,
   false               = [],
   only_not_possible   = [],
   only_possible       = [],
   others_satisfied    = [],
   others_not_possible = g_others_not_possibleL}:guess_collection
end;


(*not used any more


(*MK_EXISTS_SUBST t [v1 |-> t1, ... vn |-> tn] tries
  to prove a theorem of the form
  t [v1/t1, ... vn/tn] ==> ?v1 ... vn. t *)

fun MK_EXISTS_SUBST t [] = snd (EQ_IMP_RULE (REFL t))
  | MK_EXISTS_SUBST t (hs::sub) =
    let
       val x = #redex hs
       val x' = #residue hs

       val th0 = MK_EXISTS_SUBST t sub;
       val th1 = INST [hs] th0;

       val t' = (snd o dest_imp o concl) th0
       val precond = (fst o dest_imp o concl) th1

       val th2 = EXISTS (mk_exists (x, t'), x')
                        (UNDISCH th1)
       val th3 = DISCH precond th2
    in
       th3
    end;



(*Given a terms v, i and a term eeq of the form
  (?x1 ... xn. v = X x1 ... xn), this function tries to
  prove the theorem ((v = i) ==> t).
*)



fun match_exists_eq v i eeq =
let
   val (vL, b) = strip_exists eeq;
   val (v',i') = dest_eq b;
   val _ = if (v = v') then () else Feedback.fail();

   val (sub,ins) = match_term i' i;

   val _ = if (all (fn x => mem (#redex x) vL) sub) then () else Feedback.fail();
   val _ = if (ins = []) then () else Feedback.fail();

   val witnessL = map (fn v => (first (fn x => (#redex x = v)) sub handle HOL_ERR _ => (v |-> v))) vL

   val thm = MK_EXISTS_SUBST b witnessL
in
   thm
end;



*)

local
   val guess_false_thm = prove (``~F``, REWRITE_TAC[])
   val guess_others_not_possible_thm = 
          prove (``(!x. ~(x = T) ==> ~x)``, REWRITE_TAC[])
   val guess_others_satisfied_thm = 
          prove (``(!x. ~(x = F) ==> x)``, REWRITE_TAC[])
in

fun QUANT_INSTANTIATE_HEURISTIC___BOOL sys (fv:term list) v t =
let
   val _ = if (aconv v t) then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;

   val g_trueL = [guess_true (T, [], SOME (fn () => TRUTH))];
   val g_falseL = [guess_false (F, [], SOME (fn () => guess_false_thm))];

   val g_trueL = [guess_true (T, [], SOME (fn () => TRUTH))];
   val g_falseL = [guess_false (F, [], SOME (fn () => guess_false_thm))];


   val (v_name, _) = dest_var v;
   val g_others_not_possibleL = 
	    [guess_others_not_possible(T,[], SOME (fn () =>
               CONV_RULE (RENAME_VARS_CONV [v_name]) guess_others_not_possible_thm))]
   val g_others_satisfiedL = 
	    [guess_others_satisfied (F,[], SOME (fn () =>
               CONV_RULE (RENAME_VARS_CONV [v_name]) guess_others_satisfied_thm))]

in
  {rewrites            = [],
   general             = [],
   true                = g_trueL,
   false               = g_falseL,
   only_not_possible   = [],
   only_possible       = [],
   others_satisfied    = g_others_satisfiedL,
   others_not_possible = g_others_not_possibleL}:guess_collection
end;

end


(*
   val t = ``l:'a list = []``;
   val v = ``l:'a list``;
   val fv = [];
   val sys = NONE;
   val thm = TypeBase.nchotomy_of ``:'a list``
*)


fun QUANT_INSTANTIATE_HEURISTIC___EQUATION_cases thm (sys:quant_heuristic) fv v t =
let
   val _ = if is_eq t then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;
   val (l,r) = dest_eq t;

   val (i,turn) = if (l = v) then (r,false) else
                  if (r = v) then (l,true) else
	          raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;

   val thm' = ISPEC v thm;
   val (eeq1,eeq2) = dest_disj (concl thm');
   val left_right_flag = if ((is_eq eeq1) andalso (lhs eeq1 = v) andalso (rhs eeq1 = i)) then false else
                         if ((is_eq eeq2) andalso (lhs eeq2 = v) andalso (rhs eeq2 = i)) then true else
                         Feedback.fail ();
   val (eeq1,eeq2,thm2) = if left_right_flag then
			     (eeq2, eeq1, thm') else
                             (eeq1, eeq2, CONV_RULE (PART_MATCH lhs DISJ_COMM) thm')

   val (fvL, eeq2b) = strip_exists eeq2;
   val (v',ni) = dest_eq eeq2b;
   val _ = if (v = v') then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;



   val v_name = (fst o dest_var) v
   val fvL' = map (fn x => let
     val (x_name, x_ty) = dest_var x;
     val x'_name = v_name ^ "_"^x_name;
     in
        (mk_var (x'_name, x_ty))
     end) fvL

   val ni' = subst (map (fn (x,x') => (x |-> x')) (zip fvL fvL')) ni;
   val (ni,fvL) = term_variant fv fvL' ni'

   val thm_opt = SOME (fn () => let
          val thm3 = DISJ_IMP thm2;
          val thm4 = CONV_RULE (RATOR_CONV (RAND_CONV NOT_EXISTS_LIST_CONV)) thm3;
          val thm5 = CONV_RULE (RATOR_CONV (RAND_CONV (RENAME_VARS_CONV
                  (map (fst o dest_var) fvL)))) thm4
          val thm6 = GEN v thm5
       in
          thm6
       end);

   val guess = guess_others_satisfied (ni, fvL, thm_opt);
in
  {rewrites            = [],
   general             = [],
   true                = [],
   false               = [],
   only_not_possible   = [],
   only_possible       = [],
   others_satisfied    = [guess],
   others_not_possible = []}:guess_collection
end handle UNCHANGED => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp
         | HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp


fun QUANT_INSTANTIATE_GUESSES___one_case thm t =
let
   val (vars, v_eq_i) = (strip_exists o concl) thm;
   val (v,i) = dest_eq v_eq_i

   val neg_precond_thm = CONV_RULE (NEG_NEG_INTRO_CONV THENC
                         RAND_CONV (NOT_EXISTS_LIST_CONV)) thm
   val precond = rand (concl neg_precond_thm);

   val thm0 = UNDISCH neg_precond_thm
   val thm1 = GEN v (DISCH precond (CCONTR t thm0))
   val thm2 = GEN v (DISCH precond (CCONTR (mk_neg t) thm0))

   val g1 = guess_others_satisfied (i,vars, SOME (fn () => thm1));
   val g2 = guess_others_not_possible (i,vars, SOME (fn () => thm2));
   
in
   ((vars, v, i), [g1,g2])
end

fun QUANT_INSTANTIATE_HEURISTIC___one_case thm (sys:quant_heuristic) fv v t =
   guess_list2collection ([],
     snd (QUANT_INSTANTIATE_GUESSES___one_case (ISPEC v thm) t))
  handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;


local
   fun QUANT_INSTANTIATE_HEURISTIC___FAIL sys fv v t =
       raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;

   fun dest_ex_eq tt =
     let
        val (vars, eq) = strip_exists tt;
        val (l, r) = dest_eq eq;
     in
        (vars, l, r)
     end;     

   fun is_sing_case_thm thm =
     let
        val (v, b) = dest_forall (concl thm);
        val (_, l, _) = dest_ex_eq b;
        val _ = (if (aconv v l) then () else Feedback.fail())
     in
        true
     end handle HOL_ERR _ => false;

   fun is_double_case_thm thm =
     let
        val (v, b) = dest_forall (concl thm);
        val (b1, b2) = dest_disj b;
        val (_, l1, _) = dest_ex_eq b1;
        val (_, l2, _) = dest_ex_eq b2;
        val _ = (if (aconv v l1) then () else Feedback.fail())
        val _ = (if (aconv v l2) then () else Feedback.fail())
     in
        true
     end handle HOL_ERR _ => false;
in
   fun QUANT_INSTANTIATE_HEURISTIC___cases thm = 
   let
   in
      if is_sing_case_thm thm then 
         QUANT_INSTANTIATE_HEURISTIC___one_case thm
      else if is_double_case_thm thm then
         QUANT_INSTANTIATE_HEURISTIC___EQUATION_cases thm
      else
         QUANT_INSTANTIATE_HEURISTIC___FAIL         
   end;
end;



fun QUANT_INSTANTIATE_HEURISTIC___TypeBase_cases sys fv v t =
if not (is_eq t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
(let
   val thm = TypeBase.nchotomy_of (type_of v)
in
   QUANT_INSTANTIATE_HEURISTIC___cases thm sys fv v t
end handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp);

fun QUANT_INSTANTIATE_HEURISTIC___cases_list thmL =
let
   val hL = map QUANT_INSTANTIATE_HEURISTIC___cases thmL
in
fn (sys:quant_heuristic) => fn fv => fn v => fn t =>
      guess_collection_flatten
      (map (fn h => total (h sys fv v) t) hL)
end;


(*
   val t = ``n = x:num``;
   val v = ``x:num``;
   val fv = [``x_n``];
   val sys = NONE;
   val thmL = [prim_recTheory.SUC_ID]
*)



fun QUANT_INSTANTIATE_HEURISTIC___EQUATION_distinct thmL (sys:quant_heuristic) fv v t =
let
   val _ = if is_eq t then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;
   val (l,r) = dest_eq t;

   val (i,turn) = if (l = v) then (r,false) else
                  if (r = v) then (l,true) else
	          raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;

   val thmL' = flatten (map BODY_CONJUNCTS thmL)
   val thmL'' = append thmL' (map GSYM thmL');

   val ni_thm = tryfind (fn thm => PART_MATCH (rhs o dest_neg) thm i) thmL'';

   val ni = (lhs o dest_neg o concl) ni_thm;
   val ni_thm = if turn then GSYM ni_thm else ni_thm;

   val fvL_set = HOLset.difference (FVL [ni] empty_tmset, FVL [t] empty_tmset)
   val fvL_org = HOLset.listItems fvL_set

   val v_name = (fst o dest_var) v;
   val fvL' = map (fn x => let
     val (x_name, x_ty) = dest_var x;
     val x'_name = v_name ^ "_"^x_name;
     in
        (mk_var (x'_name, x_ty))
     end) fvL_org

   val ni' = subst (map (fn (x,x') => (x |-> x')) (zip fvL_org fvL')) ni;
   val (ni,fvL) = term_variant fv fvL' ni'

   val thm0 = INST (map (fn (x,x') => (x |-> x')) (zip fvL_org fvL)) ni_thm
   val thm1 = GENL fvL thm0
   val guess = guess_false (ni, fvL, SOME (fn () => thm1));
in
  {rewrites            = [thm1],
   general             = [],
   true                = [],
   false               = [guess],
   only_not_possible   = [],
   only_possible       = [],
   others_satisfied    = [],
   others_not_possible = []}:guess_collection

end handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;


fun QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_distinct sys fv v t =
let
   val _ = if is_eq t then () else raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;
   val thm = TypeBase.distinct_of (type_of v);
in
   QUANT_INSTANTIATE_HEURISTIC___EQUATION_distinct [thm] sys fv v t
end handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;



(*
val t = ``~(uf (x:'a) = uf y) \/ (P y /\ Q y)``
val v = ``x:'a``
val fv = [v]

QUANT_INSTANTIATE_HEURISTIC___debug :=

val t = ``~(uf (x:'a) = uf (SND s)) \/ (IS_SOME (e (FST s)) /\
   s IN var_res_prop___PROP f (wpb,rpb) sfb)``

val heuristic = QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE ([],[],[],[],[]) NONE;
val sys = heuristic;
QUANT_INSTANTIATE_HEURISTIC___print_term_length := 2000
*)

fun QUANT_INSTANTIATE_HEURISTIC___DISJ sys fv v t =
if not (is_disj t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (t1,t2) = dest_disj t;
   val (gc1,c1) = (sys fv v t1,false)
      handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp =>
	     (empty_guess_collection,true)

   val (gc2,c2) = (sys fv v t2,false)
      handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp =>
	     (empty_guess_collection,true);
   val _ = if (c1 andalso c2) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else ();


   (*Guesses that make either the left or right disjunct true, can be kept*)
(*
val v = ``x:num``
val t2 = ``~(x = 0)``
val i = ``SUC n``
val fvL = [``n:num``]
val t1 = ``(P (x:num)):bool``
val t = mk_disj (t1,t2)

val guess = make_set_guess_thm_opt___dummy v t2 (guess_true (i,fvL,NONE))
*)

   val trueL = map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
		     val thm_opt' = if not (isSome thm_opt) then NONE else
                                    SOME (fn () =>
				    let
				       val thm0 = SPECL fvL ((valOf thm_opt) ())
				       val thm1 = DISJ1 thm0 (subst [v |-> i] t2);
				       val thm2 = GENL fvL thm1
                                    in
				       thm2
                                    end)
                  in
		     guess_true (i,fvL, thm_opt')
                  end) (#true gc1);
   val trueL = append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
		     val thm_opt' = if not (isSome thm_opt) then NONE else
				    SOME (fn () =>
				    let
				       val thm0 = SPECL fvL ((valOf thm_opt) ())
				       val thm1 = DISJ2 (subst [v |-> i] t1) thm0;
				       val thm2 = GENL fvL thm1
                                    in
				       thm2
                                    end)
                  in
		     guess_true (i,fvL, thm_opt')
                  end) (#true gc2)) trueL;

   (*Guesses that make both, the left or right disjunct false, can be kept*)
   val falseL = mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess

                     val guess2_opt = SOME (first (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i = i') andalso (fvL = fvL') end) (#false gc2))  handle HOL_ERR _ => NONE
                     val thm2_opt = if isSome guess2_opt then #3 (guess_extract (valOf guess2_opt)) else NONE
                  in
		     if (not (isSome guess2_opt)) then
                        NONE
                     else if not ((isSome thm_opt) andalso
                                   (isSome thm2_opt)) then
                        SOME (guess_false (i,fvL,NONE))
                     else
                     let
                        val thm_opt = SOME (fn () =>
                        let
	                   val thm1 = (valOf thm_opt) ();
		           val thm2 = (valOf thm2_opt) ();
			   val thm3 = CONJ (SPECL fvL thm1) (SPECL fvL thm2);
			   val thm4 = CONV_RULE AND_NOT_CONV thm3
		           val thm5 = GENL fvL thm4
                        in
                           thm5
                        end)
                     in
                        SOME (guess_false (i,fvL,thm_opt))
                     end
                  end) (#false gc1);

   (*false guesses in gc2 are handeled already*)


   (*if i is the only possibility for t1 and t2 then it is the only possibility for
     t1 \/ t2*)


   (*if necessary weaken other guesses, guess true can be preserved on it's own,
     so just handle only_possible*)
   val org_only_possibleL = append (#only_possible gc1)
    (map (guess_weaken v t1) (flatten (map (fn guess =>
                     let val (i'',fvL'',_) = guess_extract guess in
		     filter (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i'' = i') andalso (fvL'' = fvL') end)
	                  (#others_not_possible gc1) end)
                     (#only_possible gc2))))

   val only_possibleL = mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                     val guess2_opt = SOME (first (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i = i') andalso (fvL = fvL') end)
                          (append (#only_possible gc2)
	                          (#others_not_possible gc2)))
                          handle HOL_ERR _ => NONE

                     val thm2_opt = if isSome guess2_opt then #3 (guess_extract (guess_weaken v t2 (valOf guess2_opt))) else NONE
                  in
		     if (not (isSome guess2_opt)) then
                        NONE
                     else if not ((isSome thm_opt) andalso
                                   (isSome thm2_opt)) then
                        SOME (guess_only_possible (i,fvL,NONE))
                     else let
                        val thm_opt = SOME (fn () =>
                            let
                               val thm1 = (valOf thm_opt) ();
		               val thm2 = (valOf thm2_opt) ();
(*
val i = ``(XXX (x:num) (y:num)):num``
val fvL = [``x:num``, ``y:num``]
val thm1 = mk_thm ([], valOf (make_guess_thm_term v t1 (guess_only_possible (i,fvL,NONE))))
val thm2 = mk_thm ([], valOf (make_guess_thm_term v t2 (guess_only_possible (i,fvL,NONE))))
*)


                              val pre_t = list_mk_forall(fvL, subst [v |-> i] (mk_neg t))
                              val pre_thm0 = ASSUME pre_t;
                              val pre_thm1 = CONV_RULE ((STRIP_QUANT_CONV NOT_OR_CONV) THENC
                                             (BOUNDED_REPEATC (length fvL) (LAST_FORALL_CONV FORALL_AND_CONV))) pre_thm0;


			      val thm1_1 = MP thm1 (CONJUNCT1 pre_thm1)
			      val thm2_1 = MP thm2 (CONJUNCT2 pre_thm1)

			      val thm12_1 = CONJ (SPEC v thm1_1) (SPEC v thm2_1);

                              val thm3 = CONV_RULE AND_NOT_CONV thm12_1
		              val thm4 = GEN v thm3
			      val thm5 = DISCH pre_t thm4
			    in
                              thm5
                            end)
                     in
                        SOME (guess_only_possible (i,fvL,thm_opt))
                     end
                  end) (org_only_possibleL);

   (*already handled by the ones in gc1*)




   (*if i the the only possibility for t1 and v does not occur in t2 then
     i the the only possibility for (t1 \/ t2)*)

(*
   val t2 = ``XXXXX:bool``;
   val t = mk_disj (t1,t2)

   val i = ``(XXX (x:num) (y:num)):num``
   val fvL = [``x:num``, ``y:num``]
   val thm1 = mk_thm ([], valOf (make_guess_thm_term v t1 (guess_only_possible (i,fvL,NONE))));

   make_guess_thm_term v t (guess_only_possible (i,fvL,NONE))
   val guess = hd gL51
*)

   val only_possibleL = if (mem v (free_vars t2)) then only_possibleL else
              append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract (guess_weaken v t1 guess);
                  in
                     if not (isSome thm_opt) then
                        guess_only_possible (i,fvL,NONE)
                     else
                     let
                        val thm_opt = SOME (fn () => let
		           val thm1 = (valOf thm_opt) ();
			   val thm2 = RIGHT_IMP_AND_INTRO_RULE (mk_neg t2) thm1

                           val thm3 = CONV_RULE (RAND_CONV LEFT_AND_FORALL_CONV) thm2
                           val thm4 = CONV_RULE (RATOR_CONV (RAND_CONV (BOUNDED_REPEATC (length fvL) (
                                      STRIP_QUANT_CONV LEFT_AND_FORALL_CONV)))) thm3

                           val thm5 = CONV_RULE (RAND_CONV (
				      STRIP_QUANT_CONV AND_NOT_CONV)) thm4
                           val thm6 = CONV_RULE (RATOR_CONV (RAND_CONV (
	                              STRIP_QUANT_CONV AND_NOT_CONV))) thm5
                        in thm6 end);
                     in
                        guess_only_possible (i,fvL,thm_opt)
                     end
                  end) (guess_collection___get_only_possible_weaken gc1)) only_possibleL;

   (*if i the the only possibility for t2 and v does not occur in t1 then
     i the the only possibility for (t1 \/ t2)*)
   val only_possibleL = if (mem v (free_vars t1)) then only_possibleL else
              append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract  (guess_weaken v t2 guess)
                  in
                     if not (isSome thm_opt) then
                        guess_only_possible (i,fvL,NONE)
                     else
                     let
                        val thm_opt = SOME (fn () => let
                           val thm1 = (valOf thm_opt) ();
			   val thm2 = LEFT_IMP_AND_INTRO_RULE (mk_neg t1) thm1

                           val thm3 = CONV_RULE (RAND_CONV RIGHT_AND_FORALL_CONV) thm2
                           val thm4 = CONV_RULE (RATOR_CONV (RAND_CONV (REPEATC (
                                      STRIP_QUANT_CONV RIGHT_AND_FORALL_CONV)))) thm3

                           val thm5 = CONV_RULE (RAND_CONV (
	   	                      STRIP_QUANT_CONV AND_NOT_CONV)) thm4
                           val thm6 = CONV_RULE (RATOR_CONV (RAND_CONV (
				      STRIP_QUANT_CONV AND_NOT_CONV))) thm5
                        in thm6 end);
                     in
                        guess_only_possible (i,fvL,thm_opt)
                     end
                  end) (guess_collection___get_only_possible_weaken gc2)) only_possibleL;











   (*if i is the only one not possibile for t1 and t2
     and fvL = [], then it is the only one not possibile for
     t1 \/ t2*)
   val org_only_not_possibleL = append (#only_not_possible gc1)
    (map (guess_weaken v t1) (append (flatten (map (fn guess =>
                     let val (i'',fvL'',_) = guess_extract guess in
		     filter (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i'' = i') andalso (fvL'' = fvL') end)
	                  (#others_satisfied gc1) end)
                     (#only_not_possible gc2))) (#false gc1)))

   val only_not_possibleL = mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                     val guess2_opt = SOME (first (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i = i') andalso (fvL = fvL') end)
                          (append (#only_not_possible gc2)
	                          (#false gc2)))
                          handle HOL_ERR _ => NONE

                     val thm2_opt = if isSome guess2_opt then
                         #3 (guess_extract (guess_weaken v t2 (valOf guess2_opt))) else NONE
                  in
		     if (not ((fvL = []) andalso (isSome guess2_opt))) then
                        NONE
                     else if not ((isSome thm_opt) andalso
                                   (isSome thm2_opt)) then
                        SOME (guess_only_not_possible (i,fvL,NONE))
                     else let
			val thm_opt = SOME (fn () =>
                        let
                           val thm1 = (valOf thm_opt) ();
		           val thm2 = (valOf thm2_opt) ();
(*
make_guess_thm_term v t (guess_only_not_possible (i,fvL,NONE))
*)

                           val pre1 = (fst o dest_imp o concl) thm1
                           val pre2 = (fst o dest_imp o concl) thm2
                           val thm1_0 = SPEC v (UNDISCH thm1)
                           val thm2_0 = SPEC v (UNDISCH thm2)

                           val thm1_1 = GEN v (DISJ1 thm1_0 (concl thm2_0))
                           val thm2_1 = GEN v (DISJ2 (concl thm1_0) thm2_0)

                           val precond_disj = mk_disj(pre1, pre2);
                           val thm_disj = ASSUME precond_disj;

			   val thm3 = DISJ_CASES thm_disj thm1_1 thm2_1
		           val thm4 = DISCH precond_disj thm3
                        in
			   thm4
                        end);
                     in
                        SOME (guess_only_not_possible (i,fvL,thm_opt))
                     end
                  end) org_only_not_possibleL;

   (*already handled by the ones in gc1*)





   (*if i the the only not possible for t1 and v does not occur in t2 then
     i the the only not possibile for (t1 \/ t2)*)
(*
   val t2 = ``XXXXX:bool``;
   val t = mk_disj (t1,t2)

   val i = ``(XXX (x:num) (y:num)):num``
   val fvL = [``x:num``, ``y:num``]
   val thm1 = mk_thm ([], valOf (make_guess_thm_term v t1 (guess_only_not_possible (i,fvL,NONE))));

   make_guess_thm_term v t (guess_only_not_possible (i,fvL,NONE))
   val guess = hd gL61
*)

   val only_not_possibleL = if (mem v (free_vars t2)) then only_not_possibleL else
              append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                  in
                     if not (isSome thm_opt) then
                        guess_only_not_possible (i,fvL,NONE)
                     else let
                        val thm_opt = SOME (fn () => let
                           val thm1 = (valOf thm_opt) ();
	                   val thm2 = RIGHT_IMP_OR_INTRO_RULE t2 thm1

                           val thm3 = CONV_RULE (RAND_CONV LEFT_OR_FORALL_CONV) thm2
                           val thm4 = CONV_RULE (RATOR_CONV (RAND_CONV (BOUNDED_REPEATC (length fvL) (
                                      STRIP_QUANT_CONV LEFT_OR_FORALL_CONV)))) thm3
                           in thm4 end);
                     in
                        guess_only_not_possible (i,fvL,thm_opt)
                     end
                  end) (append (#only_not_possible gc1)
                               (map (guess_weaken v t1) (#false gc1))))
               only_not_possibleL;

   (*if i the the only not possibile for t2 and v does not occur in t1 then
     i the the only not possible for (t1 \/ t2)*)
   val only_not_possibleL = if (mem v (free_vars t1)) then only_not_possibleL else
              append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                  in
                     if not (isSome thm_opt) then
                        guess_only_not_possible (i,fvL,NONE)
                     else let
                        val thm_opt = SOME (fn () => let
                           val thm1 = (valOf thm_opt) ();
                           val thm2 = LEFT_IMP_OR_INTRO_RULE t1 thm1

                           val thm3 = CONV_RULE (RAND_CONV RIGHT_OR_FORALL_CONV) thm2
                           val thm4 = CONV_RULE (RATOR_CONV (RAND_CONV (BOUNDED_REPEATC (length fvL) (
                                      STRIP_QUANT_CONV RIGHT_OR_FORALL_CONV)))) thm3
                           in thm4 end);
                     in
                        guess_only_not_possible (i,fvL,thm_opt)
                     end
                  end) (append (#only_not_possible gc2)
                               (map (guess_weaken v t2) (#false gc2))))
                  only_not_possibleL;



(* If all values except i make t1 and t2 false, then all
   all values except i make (t1 \/ t2) false.
*)
   val others_not_possibleL = mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess

                     val guess2_opt = SOME (first (fn guess' => let val (i',fvL',_) = guess_extract guess' in
						 (i = i') andalso (fvL = fvL') end)
						 (#others_not_possible gc2))  handle HOL_ERR _ => NONE
                     val thm2_opt = if isSome guess2_opt then #3 (guess_extract (valOf guess2_opt)) else NONE
                  in
		     if (not (isSome guess2_opt)) then
                        NONE
                     else if not ((isSome thm_opt) andalso
                                   (isSome thm2_opt)) then
                        SOME (guess_others_not_possible (i,fvL,NONE))
                     else let
                        val thm_opt = SOME (fn () => let
                            val thm1_0 = ((valOf thm_opt) ());
                            val thm1 = UNDISCH (SPEC v thm1_0);
                            val thm2 = UNDISCH (SPEC v ((valOf thm2_opt) ()));

                            val precond = (fst o dest_imp o snd o dest_forall o concl) thm1_0
                            val thm3 = CONJ thm1 thm2
			    val thm4 = CONV_RULE AND_NOT_CONV thm3
                            val thm5 = DISCH precond thm4
                            val thm6 = GEN v thm5
                            in thm6 end);
                     in
                        SOME (guess_others_not_possible (i,fvL,thm_opt))
                     end
                  end) (#others_not_possible gc1);



(* If all values except i make t1 true, then all
   all values except i make (t1 \/ t2) true.

val t1 = ``~ ~(l = []:num list)``
val t2 = ``LENGTH (l:num list) > 0``
val i = ``[]:num list``
val fvL = []
val v = ``l:num list``

val t = mk_disj (t1,t2)

val guess = make_set_guess_thm_opt___dummy v t1 (guess_others_satisfied (i,fvL,NONE))
check_guess [] [] v t1 guess
*)

   val others_satisfiedL = map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                  in
                     if not (isSome thm_opt) then
                        guess_others_satisfied (i,fvL,NONE)
                     else let
                        val thm_opt = SOME (fn () => let
                           val thm1_0 = (valOf thm_opt) ();
                           val thm1 = UNDISCH (SPEC v thm1_0);

                           val precond = (fst o dest_imp o snd o dest_forall o concl) thm1_0
                           val thm2 = DISJ1 thm1 t2
                           val thm3 = DISCH precond thm2
                           val thm4 = GEN v thm3
                        in thm4 end);
                     in
                        guess_others_satisfied (i,fvL,thm_opt)
                     end
                  end) (#others_satisfied gc1);

(* If all values except i make t2 true, then all
   all values except i make (t1 \/ t2) true.
*)
   val others_satisfiedL = append (map (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                  in
                     if not (isSome thm_opt) then
                        guess_others_satisfied (i,fvL,NONE)
                     else let
			val thm_opt = SOME (fn () => let
                           val thm1_0 = (valOf thm_opt) ();
                           val thm1 = UNDISCH (SPEC v thm1_0);

                           val precond = (fst o dest_imp o snd o dest_forall o concl) thm1_0;

                           val thm2 = DISJ2 t1 thm1
                           val thm3 = DISCH precond thm2
                           val thm4 = GEN v thm3
                        in thm4 end);
                     in
                        guess_others_satisfied (i,fvL,thm_opt)
                     end
                  end) (#others_satisfied gc2)) others_satisfiedL;
in
  {rewrites            = append (#rewrites gc1) (#rewrites gc2),
   general             = [],
   true                = trueL,
   false               = falseL,
   only_not_possible   = only_not_possibleL,
   only_possible       = only_possibleL,
   others_satisfied    = others_satisfiedL,
   others_not_possible = others_not_possibleL}:guess_collection
end;




(*
val v = ``x:num``
val t = ``x = y + 2``
val i = ``y' + 2``
val fvL = [``y':num``]
val guess = make_set_guess_thm_opt___dummy v t (guess_others_not_possible (i,fvL,NONE))

val (i,fvL,thm_opt) = guess_extract guess
val thm = valOf thm_opt
val g2 =  it
correct_guess [] [] v (mk_neg t) g2

*)

fun QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_true (i,fvL,NONE)) =
   (guess_false (i,fvL,NONE))
| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_true (i,fvL,SOME thm)) =
   guess_false (i,fvL, SOME (fn () =>
      (CONV_RULE  (STRIP_NUM_QUANT_CONV (length fvL) NEG_NEG_INTRO_CONV) (thm ()))))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_false (i,fvL,thm_opt)) =
   (guess_true (i,fvL,thm_opt))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_only_possible (i,fvL,thm_opt)) =
   (guess_only_not_possible (i,fvL,thm_opt))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_only_not_possible (i,fvL,NONE)) =
   (guess_only_possible (i,fvL,NONE))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_only_not_possible (i,fvL,SOME thm)) =
   (guess_only_possible (i,fvL,	SOME (fn () => (CONV_RULE
((RATOR_CONV (RAND_CONV (STRIP_NUM_QUANT_CONV (length fvL) (NEG_NEG_INTRO_CONV)))) THENC
 (RAND_CONV (QUANT_CONV NEG_NEG_INTRO_CONV))) (thm ())))))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_others_not_possible (i,fvL,thm_opt)) =
   (guess_others_satisfied (i,fvL,thm_opt))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_others_satisfied (i,fvL,SOME thm)) =
   (guess_others_not_possible (i,fvL, SOME (fn () => CONV_RULE
      (QUANT_CONV (RAND_CONV (NEG_NEG_INTRO_CONV))) (thm ()))))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (guess_others_satisfied (i,fvL,NONE)) =
   (guess_others_not_possible (i,fvL,NONE))

| QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS guess = guess



fun QUANT_INSTANTIATE_HEURISTIC___NEG sys (fv:term list) (v:term) t =
if not (is_neg t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val gc:guess_collection = sys fv v (dest_neg t);
in
  {rewrites            = #rewrites gc,
   general             = [],
   true                = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#false gc),
   false               = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#true gc),
   only_not_possible   = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#only_possible gc),
   only_possible       = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#only_not_possible gc),
   others_satisfied    = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#others_not_possible gc),
   others_not_possible = map QUANT_INSTANTIATE_HEURISTIC___NEG_GUESS (#others_satisfied gc)}:guess_collection
end;




(*
val t = ``?x. (y = SOME x)``
val v = ``y:'a option``
val fv = [v, ``x:'a``]

val heuristic = QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE empty_qp NONE;
val sys = heuristic;
correct_guess_list v t (sys fv v t)


val t = ``!y1 y2 y3. P (x:'a) y1 y2``
val v = ``x:'a``
val fv = [v]

QUANT_INSTANTIATE_HEURISTIC___debug := 2
sys fv v t

*)


fun QUANT_INSTANTIATE_HEURISTIC___FORALL sys (fv:term list) v t =

if not (is_forall t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (x, tx) = dest_forall t;
   val _ = if (x = v) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else ();
   val gc:guess_collection = sys fv v tx;


(*
val i = ``(f (tt:num) (y:num) (z:num)):num``


val i = ``(f (t:num) (y:num) (z:num)):num``
val fvL = [``y:num``, ``z:num``]
val guess = make_set_guess_thm_opt___dummy v tx (guess_others_not_possible (i,fvL,NONE))
val (_,i,_,fvL) = update_fvL (i,fvL)
val guess2 = make_set_guess_thm_opt___dummy v t (guess_others_not_possible (i,fvL,NONE))

val guess_thm_opt = make_guess_thm_opt___dummy v t guess;
val term_opt = make_guess_thm_term v t guess
val resL = [];

prove (valOf term_opt, METIS_TAC[valOf (guess_thm_opt)])


val gL8 = [guess];
correct_guess_list v t resL
*)
   fun update_fvL (i, fvL) =
   if not (mem x (free_vars i)) then (false,i,x,fvL) else
   let
      val x' = variant (append (free_vars i) fv) x;
      val i' = subst [x |-> x'] i;
   in
      (true,i',x',x'::fvL)
   end;

   val trueL = mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess;
                  in
                     if mem x (free_vars i) then
                        NONE
                     else let
                         val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
				       let
                                          val thm0 = SPECL fvL ((valOf thm_opt) ());
					  val thm1 = GEN x thm0
                                          val thm2 = GENL fvL thm1
                                       in
                                          thm2
                                       end)
                     in
	       	        SOME (guess_true (i,fvL, thm_opt'))
                     end
                  end) (#true gc);

   val falseL = map (fn guess =>
		  let
		     val (i',fvL,thm_opt) = guess_extract guess;
                     val (_, i, x_new, fvL_new) = update_fvL (i',fvL);
                     val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
				       let
                                          val thm0 = SPECL fvL ((valOf thm_opt) ());
					  val thm1 = EXISTS (mk_exists(x, subst [v |-> i] (mk_neg tx)),x_new) (INST [x |-> x_new] thm0)
                                          val thm2 = CONV_RULE EXISTS_NOT_CONV thm1
                                          val thm3 = GENL fvL_new thm2
                                       in
                                          thm3
                                       end)
                  in
                     guess_false (i,fvL_new, thm_opt')
                  end) (#false gc);


   val only_possibleL = if mem x (free_vars tx) then [] else
               mapPartial (fn guess =>
		  let
		     val (i,fvL,thm_opt) = guess_extract guess
                  in
                     if (mem x (free_vars i)) then
                        NONE
                     else let
		     val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
                       let
                          val thm = (valOf thm_opt) ();
                          val precond = (snd o strip_forall o fst o dest_imp o concl) thm;
                          val precond_thm0 = ISPEC precond EXISTS_SIMP
		          val precond_thm1 = CONV_RULE (LHS_CONV (RENAME_VARS_CONV [fst (dest_var x)])) precond_thm0
		          val precond_thm2 = CONV_RULE (LHS_CONV EXISTS_NOT_CONV) precond_thm1
                          val precond_thm3 = foldr EQ_FORALL_INTRO precond_thm2 fvL
			  val precond_imp_thm = fst (EQ_IMP_RULE precond_thm3)

                          val thm0 = IMP_TRANS precond_imp_thm thm
			  val precond2 = (fst o dest_imp o concl) thm0;
			  val thm1 = SPEC v (UNDISCH thm0)
			  val thm2 = SIMPLE_EXISTS x thm1
                          val thm3 = CONV_RULE EXISTS_NOT_CONV thm2
                          val thm4 = GEN v thm3;
			  val thm5 = DISCH precond2 thm4
                       in
                          thm5
                       end)
                     in
                       SOME (guess_only_possible (i,fvL, thm_opt'))
                     end
                  end) (#only_possible gc);



   val only_not_possibleL = map (fn guess =>
		  let
		     val (i',fvL,thm_opt) = guess_extract guess
                     val (new_flag, i, x_new, fvL_new) = update_fvL (i',fvL);
		     val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
                       let
                          val precond = list_mk_forall (fvL_new, mk_forall (x, subst [v |-> i] tx))

                          val precond_thm0 = ASSUME precond
                          val precond_thm1a = if new_flag then SPEC x precond_thm0 else precond_thm0;
                          val precond_thm1 = SPECL fvL precond_thm1a
                          val precond_thm2 = SPEC x precond_thm1
                          val precond_thm3 = GENL fvL precond_thm2


                          val thm0 = MP ((valOf thm_opt) ()) precond_thm3
			  val thm1 = GEN v (GEN x (SPEC v thm0))
			  val thm2 = DISCH precond thm1
                       in
                          thm2
                       end)
                  in
		     guess_only_not_possible (i,fvL_new, thm_opt')
                  end) (#only_not_possible gc);



   val others_not_possibleL = map (fn guess =>
		  let
		     val (i',fvL,thm_opt) = guess_extract guess
                     val (new_flag, i, x_new, fvL_new) = update_fvL (i',fvL);
		     val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
                       let
			  val thm0 = SPEC v ((valOf thm_opt) ());
                          val precond = (fst o dest_imp o concl) thm0;

                          val thm1 = UNDISCH thm0;
                          val thm2 = SIMPLE_EXISTS x thm1;
			  val thm3 = CONV_RULE EXISTS_NOT_CONV thm2;
			  val thm4 = DISCH precond thm3

                          val thm5 = if not new_flag then thm4 else
				     let
					val new_precond = mk_forall (x_new, subst [x |-> x_new] precond)
                                        val precond_thm0 = ASSUME new_precond;
                                        val precond_thm1 = SPEC x precond_thm0
                                        val precond_thm2 = DISCH new_precond precond_thm1
			             in
                                        IMP_TRANS precond_thm2 thm4
                                     end;
		          val thm6 = GEN v thm5;
                       in
                          thm6
                       end)
                  in
		     guess_others_not_possible (i,fvL_new, thm_opt')
                  end) (#others_not_possible gc);

   val others_satisfiedL = map (fn guess =>
		  let
		     val (i',fvL,thm_opt) = guess_extract guess
                     val (new_flag, i, x_new, fvL_new) = update_fvL (i',fvL);
		     val thm_opt' = if not (isSome thm_opt) then NONE else SOME (fn () =>
                       let
			  val thm0 = SPEC v ((valOf thm_opt) ());

                          val thm1 = if not new_flag then thm0 else
				     let
                                        val precond = (fst o dest_imp o concl) thm0;
					val new_precond = mk_forall (x_new, subst [x |-> x_new] precond)
                                        val precond_thm0 = ASSUME new_precond;
                                        val precond_thm1 = SPEC x precond_thm0
                                        val precond_thm2 = DISCH new_precond precond_thm1
			             in
                                        IMP_TRANS precond_thm2 thm0
                                     end;

                          val precond = (fst o dest_imp o concl) thm1;
                          val thm2 = UNDISCH thm1;
                          val thm3 = GEN x thm2;
			  val thm4 = DISCH precond thm3
		          val thm5 = GEN v thm4;
                       in
                          thm5
                       end)
                  in
		     guess_others_satisfied (i,fvL_new, thm_opt')
                  end) (#others_satisfied gc);
in
  {rewrites            = #rewrites gc,
   general             = [],
   true                = trueL,
   false               = falseL,
   only_not_possible   = only_not_possibleL,
   only_possible       = only_possibleL,
   others_satisfied    = others_satisfiedL,
   others_not_possible = others_not_possibleL}:guess_collection
end;


(*
correct_guess_list v t
(QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm)

rew_thm
*)



fun QUANT_INSTANTIATE_HEURISTIC___REWRITE sys (fv:term list) (v:term) rew_thm =
let
   val (lt,rt) = dest_eq (concl rew_thm);
   val gc0:guess_collection = sys fv v rt
   val gc1 = correct_guess_collection v rt gc0

   val f = guess_rewrite_thm_opt v rew_thm;
   val gc2 =
  {rewrites            = #rewrites gc1,
   general             = [],
   true                = map f (#true gc1),
   false               = map f (#false gc1),
   only_not_possible   = map f (#only_not_possible gc1),
   only_possible       = map f (#only_possible gc1),
   others_satisfied    = map f (#others_satisfied gc1),
   others_not_possible = map f (#others_not_possible gc1)}:guess_collection

   val gc3 = correct_guess_collection v lt gc2
in
   gc3
end;



fun QUANT_INSTANTIATE_HEURISTIC___CONV conv sys fv v t =
let
   val thm_opt = SOME (QCHANGED_CONV (CHANGED_CONV conv) t) handle HOL_ERR _ =>  NONE
in
   if not (isSome thm_opt) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v (valOf thm_opt)
end;



fun TOP_ONCE_REWRITE_CONV thmL =
   let
      val thmL' = flatten (map BODY_CONJUNCTS thmL)
   in
      fn t => (tryfind (fn thm => REWR_CONV thm t) thmL')
   end handle HOL_ERR _ => raise UNCHANGED;





fun QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_one_one sys fv v t =
(let
   val (l,_) = dest_eq t;
   val thm = TOP_ONCE_REWRITE_CONV [TypeBase.one_one_of (type_of l)] t
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v thm
end handle UNCHANGED => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp)
handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;





(*
val t = ``(~(x:num = 7)) ==> (x = 7)``;
val fv = []
val v = ``x:num``
val sys = heuristic
*)

fun QUANT_INSTANTIATE_HEURISTIC___IMP sys fv v t =
if not (is_imp_only t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (t1,t2) = dest_imp_only t;
   val rew_thm = SPECL [t1,t2] IMP_DISJ_THM
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm
end;




(*
val t = ``(~(x:num = 7)) /\ (x = 7)``;
val fv = []
val v = ``x:num``
val sys = heuristic
*)

fun QUANT_INSTANTIATE_HEURISTIC___CONJ sys fv v t =
if not (is_conj t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (t1,t2) = dest_conj t;
   val rew_thm = SPECL [t1,t2] quantHeuristicsTheory.CONJ_NOT_OR_THM
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm
end;

(*
val t = ``((x:num = 7)) = (x = 7)``;
val fv = []
val v = ``x:num``
val sys = heuristic
*)

fun QUANT_INSTANTIATE_HEURISTIC___EQUIV sys fv v t =
if not (is_eq t) orelse
   not (type_of (lhs t) = bool) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (t1,t2) = dest_eq t;
   val rew_thm = SPECL [t1,t2] EQ_EXPAND;
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm
end;



(*
val t = ``?z. (x:num = 7) /\ P k``;
val v = ``x:num``

val t = ``?x. (y = SOME x)``
val fv = []

correct_guess_list v t (QUANT_INSTANTIATE_HEURISTIC___EXISTS sys fv v t)



val t = ``?y1 y2 y3. P (x:'a) y1 y2``

*)


fun QUANT_INSTANTIATE_HEURISTIC___EXISTS sys fv v t =
if not (is_exists t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val rew_thm = HO_PART_MATCH lhs quantHeuristicsTheory.EXISTS_NOT_FORALL_THM t
   val rew_thm2 = (CONV_RULE (RHS_CONV (RAND_CONV (QUANT_CONV (
			     NOT_EXISTS_LIST_CONV
		  )))) rew_thm handle HOL_ERR _ => rew_thm) handle UNCHANGED => rew_thm
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm2
end;



(*
val t = ``?!z. (x:num = 7)``;
val v = ``x:num``
*)


fun QUANT_INSTANTIATE_HEURISTIC___EXISTS_UNIQUE sys fv v t =
if not (is_exists1 t) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val rew_thm = HO_PART_MATCH lhs EXISTS_UNIQUE_THM t
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm
end;


(*
val t = ``(if c then b1 else (x = 8:num)):bool``;
val v = ``x:num``
*)


fun QUANT_INSTANTIATE_HEURISTIC___COND sys fv v t =
if not (is_cond t) orelse not (type_of t = bool) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else
let
   val (c,t1,t2) = dest_cond t;
   val rew_thm = SPECL [c,t1,t2] COND_EXPAND;
in
   QUANT_INSTANTIATE_HEURISTIC___REWRITE sys fv v rew_thm
end;



(*
   val heuristicL = [QUANT_INSTANTIATE_HEURISTIC___EQUATION];
   val v = ``x:num``
   val t = ``x:num = 9``
*)



val QUANT_INSTANTIATE_HEURISTIC___print_term_length = ref 20;
val _ = register_trace("QUANT_INSTANTIATE_HEURISTIC___print_term_length", QUANT_INSTANTIATE_HEURISTIC___print_term_length, 20);

fun cut_term_to_string t =
    let
       val n = !QUANT_INSTANTIATE_HEURISTIC___print_term_length;
       val st = term_to_string t;
       val st' = if (String.size st > n) then
		     (substring (st,0,n)^"...") else st
    in
       st'
    end;


fun COMBINE_HEURISTIC_FUNS L =
let
   val gcL = map (fn h =>
	    ((SOME (h ())
              handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp => NONE
	      handle HOL_ERR _ => raise UNCHANGED)
                                  handle UNCHANGED =>
              (say_HOL_WARNING "QUANT_INSTANTIATE_HEURISTIC___COMBINE"
			      ("Some heuristic produced an error!"); NONE)
            )) L;
   val gc = guess_collection_flatten gcL;
in
   gc
end;


type quant_heuristic_cache =  (Term.term, (Term.term, (term list * guess_collection) list) Redblackmap.dict) Redblackmap.dict
fun mk_quant_heuristic_cache () = (Redblackmap.mkDict Term.compare):quant_heuristic_cache

(*
val cache = mk_quant_heuristic_cache ()
val t = T
val v = T
val fv = [T]
val gc = SOME empty_guess_collection
*)

fun quant_heuristic_cache___insert (cache:quant_heuristic_cache) (fv:term list) (v:term) (t:term) (gc:guess_collection) =
let
   val t_cache_opt = Redblackmap.peek (cache,t)
   val t_cache = if isSome t_cache_opt then valOf t_cache_opt else
		 (Redblackmap.mkDict Term.compare);

   val v_cache_opt = Redblackmap.peek (t_cache,v);
   val v_cache = if isSome v_cache_opt then valOf v_cache_opt else [];

   val v_cache' = snd (pluck (fn (fv', _) => (fv' = fv)) v_cache)
		       handle HOL_ERR _ => v_cache;

   val t_cache' = Redblackmap.insert (t_cache, v, (fv, gc)::v_cache')
   val cache' = Redblackmap.insert (cache, t, t_cache')
in
   cache':quant_heuristic_cache
end;



fun quant_heuristic_cache___peek (cache:quant_heuristic_cache) (fv:term list) (v:term) (t:term) =
let
   val t_cache = Redblackmap.find (cache,t)
   val v_cache = Redblackmap.find (t_cache,v);
   val gc = (snd (fst (pluck (fn (fv', _) => (fv' = fv)) v_cache)))
		       handle HOL_ERR _ => raise Redblackmap.NotFound;

in
   SOME gc
end handle Redblackmap.NotFound => NONE;



(*

val heuristic = QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE ([],[],[],[],[]);
val sys = heuristic;

val heuristicL =      [QUANT_INSTANTIATE_HEURISTIC___EQUATION,
             QUANT_INSTANTIATE_HEURISTIC___BOOL,
     	     QUANT_INSTANTIATE_HEURISTIC___NEG,
       	     QUANT_INSTANTIATE_HEURISTIC___DISJ,
       	     QUANT_INSTANTIATE_HEURISTIC___FORALL,

       	     QUANT_INSTANTIATE_HEURISTIC___CONJ,
       	     QUANT_INSTANTIATE_HEURISTIC___EXISTS,
       	     QUANT_INSTANTIATE_HEURISTIC___EXISTS_UNIQUE,
       	     QUANT_INSTANTIATE_HEURISTIC___IMP,
       	     QUANT_INSTANTIATE_HEURISTIC___EQUIV,
       	     QUANT_INSTANTIATE_HEURISTIC___COND,

	     QUANT_INSTANTIATE_HEURISTIC___EQUATION_cases_list [],
       	     QUANT_INSTANTIATE_HEURISTIC___EQUATION_distinct []]
val t = ``!x y. P x y (z:'a)``
val v = ``z:'a``
val fv = [v]

val n = 0;
val cache_ref_opt = SOME (ref (mk_quant_heuristic_cache ()))
*)

fun prefix_string 0 = ""
  | prefix_string n = "  "^(prefix_string (n-1));

fun BOUNDED_QUANT_INSTANTIATE_HEURISTIC___COMBINE n
    heuristicL cache_ref_opt (fv:term list) (v:term) (t:term) =
if (n >= !QUANT_INSTANTIATE_HEURISTIC___max_rec_depth) then
   ((say_HOL_WARNING "BOUNDED_QUANT_INSTANTIATE_HEURISTIC___COMBINE" "Maximal recursion depth reached!");
   empty_guess_collection)
else let
   val _ = if (!QUANT_INSTANTIATE_HEURISTIC___debug > 0) then
	       say ((prefix_string n)^"searching guesses for ``"^
	           (term_to_string v)^"`` in ``"^(cut_term_to_string t)^"`` (fv: ["^
                   (term_list_to_string fv)^"])\n")
           else ();

   val gc_opt = if not (isSome cache_ref_opt) then NONE else
		  quant_heuristic_cache___peek (!(valOf cache_ref_opt)) fv v t

   val gc = if (isSome gc_opt) then valOf gc_opt else
	    let
               val sys = BOUNDED_QUANT_INSTANTIATE_HEURISTIC___COMBINE (n+1) heuristicL cache_ref_opt;
               val hL = (map (fn h => (fn () => (h sys fv v t))) heuristicL);
               val gc = COMBINE_HEURISTIC_FUNS hL;
               val gc = correct_guess_collection v t gc;
	       val _ = if not (isSome cache_ref_opt) then () else
                          let
			      val r = valOf cache_ref_opt;
                 	      val c = quant_heuristic_cache___insert (!r) fv v t gc;
		              val _ = r := c
			  in
			      ()
			  end;
	    in
	       gc
	    end;

   val _ = if (!QUANT_INSTANTIATE_HEURISTIC___debug > 0) then
               let
		  val prefix = prefix_string n;
                  val _ = say (prefix^"found guesses for ``"^
	           (term_to_string v)^"`` in ``"^(cut_term_to_string t)^"``\n")

	          val show_thm = (!QUANT_INSTANTIATE_HEURISTIC___debug > 1);
                  fun say_guess guess = say (prefix^" - "^
	           (guess_to_string show_thm guess)^"\n")
		  val _ = foldl (fn (guess,_) => say_guess guess) () (snd (guess_collection2list gc))
               in
                  ()
               end
           else ()
   val _ = if (is_empty_guess_collection gc) then raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp else ();
in
   gc
end;

(*
             QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_cases,
             QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_distinct,
             QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_one_one,
*)

val QUANT_INSTANTIATE_HEURISTIC___COMBINE =
    BOUNDED_QUANT_INSTANTIATE_HEURISTIC___COMBINE 0;

fun QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE
    ({distinct_thms = distinct_thmL,
     cases_thms = cases_thmL,
     rewrite_thms = rewrite_thmL,
     convs = convL,
     heuristics = heuristicL,
     final_rewrite_thms = final_rewrite_thmL}:quant_param) =
    QUANT_INSTANTIATE_HEURISTIC___COMBINE
    (append [QUANT_INSTANTIATE_HEURISTIC___EQUATION,
             QUANT_INSTANTIATE_HEURISTIC___BOOL,
     	     QUANT_INSTANTIATE_HEURISTIC___NEG,
       	     QUANT_INSTANTIATE_HEURISTIC___DISJ,
       	     QUANT_INSTANTIATE_HEURISTIC___FORALL,

       	     QUANT_INSTANTIATE_HEURISTIC___CONJ,
       	     QUANT_INSTANTIATE_HEURISTIC___EXISTS,
       	     QUANT_INSTANTIATE_HEURISTIC___EXISTS_UNIQUE,
       	     QUANT_INSTANTIATE_HEURISTIC___IMP,
       	     QUANT_INSTANTIATE_HEURISTIC___EQUIV,
       	     QUANT_INSTANTIATE_HEURISTIC___COND,

	     QUANT_INSTANTIATE_HEURISTIC___cases_list cases_thmL,
       	     QUANT_INSTANTIATE_HEURISTIC___EQUATION_distinct distinct_thmL]
    (append (map QUANT_INSTANTIATE_HEURISTIC___CONV (
       (TOP_ONCE_REWRITE_CONV rewrite_thmL)::(markerLib.DEST_LABEL_CONV)::
            asm_marker_ELIM_CONV::convL))
	    heuristicL));








(*
val only_eq = false;
val try_eq = true;
val expand_eq = false;
val heuristic = QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE neg_heuL [];
val dir = CONSEQ_CONV_UNKNOWN_direction;
val t = ``!t:num. (t = 5) ==> X``
val t = ``!z t q. ((t = z2) ==> X z) /\ (z = 8 + t)``
*)


fun move_exists_to_end t =
let
   val thm1 = SWAP_EXISTS_CONV t;

   val (top_var, r_term) = dest_exists (rhs (concl thm1));
   val thm2 = move_exists_to_end r_term;
   val thm3 = EQ_EXISTS_INTRO (top_var, thm2);
in
   TRANS thm1 thm3
end handle HOL_ERR _ => REFL t;


(*
val BOOL_SIMP_CONV_cs = (computeLib.bool_compset());
val _ = computeLib.add_conv (boolSyntax.universal,1,QCONV QUANT_SIMP_CONV) BOOL_SIMP_CONV_cs;
val _ = computeLib.add_conv (boolSyntax.existential,1,QCONV QUANT_SIMP_CONV) BOOL_SIMP_CONV_cs;
val BOOL_SIMP_CONV = WEAK_CBV_CONV BOOL_SIMP_CONV_cs;
*)

fun BOOL_SIMP_CONV rwL (gc:guess_collection) =
let
   val conv = REWRITE_CONV (append rwL (#rewrites gc));
in
   fn t => conv t handle UNCHANGED => REFL t
end;


(*
val t = ``?!x. (7 + z = x) /\ P x``;

val t = ``?x. !z. ~(~(7 = x) \/ P x z)``;
val t = ``?l. ~(l = [])``

val t = ``?x a b. P /\ (f x = f 2) /\ Q (f x)``

val only_eq = true;
val try_eq = true;
val expand_eq = false;
fun varfilter x = true
val heuristic = QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE empty_qp NONE
val sys = heuristic;
val dir = CONSEQ_CONV_UNKNOWN_direction


val t = snd (top_goal ())

*)



fun QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (only_eq,try_eq,expand_eq) varfilter min_var_occs heuristic rwL dir t =
if (not (is_exists t)) andalso (not (is_forall t)) andalso (not (is_exists1 t)) then raise UNCHANGED else
let
   val (v,b) = dest_abs (rand t);
   val _ = if varfilter v then () else raise UNCHANGED;
in
  (if not (free_in v b) then
     ((if is_exists t then EXISTS_SIMP_CONV else
         if is_forall t then FORALL_SIMP_CONV else 
            (HO_PART_MATCH lhs UEXISTS_SIMP)) t)
   else
   if is_exists t then
   let
      val (v,qb) = dest_exists t;
      val (qvL, b0) = strip_exists qb;


      val b_thm = if min_var_occs then 
                      min_var_occur_CONV v b0 handle UNCHANGED => REFL b0
                  else REFL b0;
      val b = rhs (concl b_thm);

      val guessC = correct_guess_collection v b
		       (heuristic (free_vars t) v b)
                   handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp => raise UNCHANGED;


      val trueL = #true guessC;
      val only_possibleL = append (#only_possible guessC)
                                  (map (guess_weaken v b) (#others_not_possible guessC))

      val guess = first guess_has_argument trueL handle HOL_ERR _ =>
                  first guess_has_argument only_possibleL handle HOL_ERR _ =>
                  first (K true) trueL handle HOL_ERR _ =>
                  first (K true) only_possibleL handle HOL_ERR _ =>
                  first (K true) (#general guessC) handle HOL_ERR _ =>
                  raise UNCHANGED;

      val (i,fvL,proof_opt) = guess_extract guess
      val need_eq = (only_eq orelse (dir = CONSEQ_CONV_WEAKEN_direction));
      val try_proof_eq = isSome proof_opt andalso try_eq andalso need_eq;

      val thm_opt = if not try_proof_eq then NONE else
          if (is_guess_true true guess) then
             let
                val proof = SPEC_ALL ((valOf proof_opt) ());
		val proof_body_thm = ASSUME (concl proof);

                val thm0 = EXISTS (mk_exists(v,b),i) proof_body_thm
                val thm1 = MP (DISCH (concl proof) thm0) proof
             in
                SOME (EQT_INTRO thm1)
  	     end
          else (*only_possible*)
             let
                val proof = (valOf proof_opt) ();

                val r_thm = make_exists_imp_thm (mk_exists(v,b)) i fvL

                val thm0 = CONTRAPOS proof
                val thm1 = CONV_RULE (RAND_CONV (TRY_CONV NOT_FORALL_LIST_CONV THENC
				                 STRIP_QUANT_CONV NEG_NEG_ELIM_CONV)) thm0
                val l_thm = CONV_RULE (RATOR_CONV (RAND_CONV (NOT_FORALL_LIST_CONV THENC
				                 STRIP_QUANT_CONV NEG_NEG_ELIM_CONV))) thm1

                val thm = IMP_ANTISYM_RULE l_thm r_thm
             in
                SOME thm
             end;
      val thm = if isSome thm_opt then valOf thm_opt else
                if need_eq then
                   if not expand_eq then raise UNCHANGED else
		   let
                      val thm0 = HO_PART_MATCH lhs (ISPEC i quantHeuristicsTheory.UNWIND_EXISTS_THM) (mk_exists (v,b))

                      val thm1 = foldl (fn (fv,th) =>
                          let
                             val thm2 = AP_TERM (inst [alpha |-> type_of fv] boolSyntax.existential) (ABS fv th);
		             val thm3 = CONV_RULE (LHS_CONV QUANT_SIMP_CONV) thm2
    		             val thm4 = CONV_RULE (RHS_CONV (HO_PART_MATCH lhs quantHeuristicsTheory.MOVE_EXISTS_IMP_THM)) thm3
                          in
                             thm4
			  end) thm0 fvL;
                   in
                      thm1
                   end
                else
                   make_exists_imp_thm (mk_exists (v,b)) i fvL

      val b_thm_conv = QUANT_CONV (REWR_CONV (GSYM b_thm))
      val thm2 = if is_eq (concl thm) then
                   CONV_RULE (LHS_CONV b_thm_conv) thm
                 else
                   CONV_RULE (RAND_CONV b_thm_conv) thm

      val thm3 = if (qvL = []) then thm2 else
		 let
		    val EXISTS_INTRO_FUN =
                       if is_eq (concl thm2) then
                          EQ_EXISTS_INTRO else IMP_EXISTS_INTRO;
		    val thm3 = foldr EXISTS_INTRO_FUN thm2 qvL;
	            val ex_move_thm = move_exists_to_end t;
		 in
		    THEN_CONSEQ_CONV___combine ex_move_thm thm3 t
		 end;

      val thm4 = CONSEQ_CONV___APPLY_CONV_RULE thm3 t (BOOL_SIMP_CONV rwL guessC)
   in
      thm4
   end else if is_forall t then
   let
      val neg_t = let
          val (vL, body) = strip_forall t;
          val n_body = mk_neg body
          in
             list_mk_exists (vL, n_body) end

      val thm = QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (only_eq,try_eq,expand_eq) varfilter min_var_occs heuristic rwL (CONSEQ_CONV_DIRECTION_NEGATE dir) (neg_t)

      val neg_t_thm = NOT_FORALL_LIST_CONV (mk_neg t)
      val new_conv = TRY_CONV NOT_EXISTS_LIST_CONV THENC (BOOL_SIMP_CONV rwL empty_guess_collection)

      val thm2 = if is_eq (concl thm) then
                    let
                       val thm3 = TRANS neg_t_thm thm;
		       val thm4 = AP_TERM boolSyntax.negation thm3;
                       val thm5 = CONV_RULE (LHS_CONV NEG_NEG_ELIM_CONV) thm4
		       val thm6 = CONV_RULE (RHS_CONV new_conv) thm5;
                    in
                       thm6
                    end
		 else if (rand (rator (concl thm))) = neg_t then
                    let
                       val thm3 = IMP_TRANS (fst (EQ_IMP_RULE neg_t_thm)) thm;
		       val thm4 = CONTRAPOS thm3;
                       val thm5 = CONV_RULE (RAND_CONV NEG_NEG_ELIM_CONV) thm4
		       val thm6 = CONV_RULE (RATOR_CONV (RAND_CONV new_conv)) thm5
                    in
                       thm6
                    end
                 else if (rand (concl thm)) = neg_t then
                    let
                       val thm3 = IMP_TRANS thm (snd (EQ_IMP_RULE neg_t_thm));
		       val thm4 = CONTRAPOS thm3;
                       val thm5 = CONV_RULE (RATOR_CONV (RAND_CONV NEG_NEG_ELIM_CONV)) thm4
		       val thm6 = CONV_RULE (RAND_CONV new_conv) thm5
                    in
                       thm6
                    end
                 else raise UNCHANGED;
   in
      thm2
   end else if is_exists1 t then
   let
      val (v,qb) = dest_exists1 t;

      val guessC = correct_guess_collection v qb
		       (heuristic (all_vars t) v qb);

      val guess = first guess_has_argument (#others_not_possible guessC) handle HOL_ERR _ =>
                  raise UNCHANGED;

      val (i,fvL,proof_opt) = guess_extract guess
      val _ = if (fvL = []) then () else raise UNCHANGED;

      val thm = HO_MATCH_MP quantHeuristicsTheory.EXISTS_UNIQUE_INSTANTIATE_THM ((valOf proof_opt) ())
      val thm2 = CONV_RULE (RHS_CONV (BOOL_SIMP_CONV rwL guessC)) thm
   in
      thm2
   end else raise UNCHANGED)
     handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp =>
            raise UNCHANGED
end;



fun HEURISTIC_QUANT_INSTANTIATE_CONV re filter min_occs heuristic expand_eq rwL =
    (if re then REDEPTH_CONV else DEPTH_CONV)
(CHANGED_CONV (QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (true,true,expand_eq) filter min_occs heuristic rwL CONSEQ_CONV_UNKNOWN_direction)) THENC
REWRITE_CONV rwL;



(*******************************************************
 * Combine this basic operations to high level ones
 *******************************************************)

fun combine_qp
   ({distinct_thms      = l11,
     rewrite_thms       = l12,
     cases_thms         = l13,
     convs              = l14,
     heuristics         = l15,
     final_rewrite_thms = l16}:quant_param)
   ({distinct_thms      = l21,
     rewrite_thms       = l22,
     cases_thms         = l23,
     convs              = l24,
     heuristics         = l25,
     final_rewrite_thms = l26}:quant_param) =

   ({distinct_thms      = (append l11 l21),
     rewrite_thms       = (append l12 l22),
     cases_thms         = (append l13 l23),
     convs              = (append l14 l24),
     heuristics         = (append l15 l25),
     final_rewrite_thms = (append l16 l26)}:quant_param)


val empty_qp =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    convs=[],heuristics=[],final_rewrite_thms=[]}:quant_param;

fun combine_qps L =
    foldl (fn (a1,a2) => combine_qp a1 a2) empty_qp L;


fun distinct_qp thmL =
   {distinct_thms=thmL,
    rewrite_thms=[],
    cases_thms=[],
    convs=[],heuristics=[],
    final_rewrite_thms=[]}:quant_param;


fun rewrite_qp thmL =
   {distinct_thms=[],
    rewrite_thms=thmL,
    cases_thms=[],
    convs=[],heuristics=[],
    final_rewrite_thms=[]}:quant_param;

fun final_rewrite_qp thmL =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    convs=[],heuristics=[],
    final_rewrite_thms=thmL}:quant_param;


fun cases_qp thmL =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=thmL,
    convs=[],heuristics=[],
    final_rewrite_thms=[]}:quant_param;

fun convs_qp cL =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    convs=cL,heuristics=[],
    final_rewrite_thms=[]}:quant_param;

fun heuristics_qp hL =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    convs=[],heuristics=hL,
    final_rewrite_thms=[]}:quant_param;


(*****************************************************
 * One of the most basic conversions.
 *
 * It get's the following arguments:
 *
 * - cache_ref_opt
 *     a possible reference to a cache which stores
 *     previously found guesses. A new cache can be
 *     created using mk_quant_heuristic_cache
 *
 * - re : bool
 *     redescent into a term some intantiation has been found?
 *     similar to DEPTH_CONV and REDEPTH_CONV
 *
 * - filter : term -> bool
 *     the conversion just tries to instantiate variables,
 *     for which this function returns true
 *
 * - expand_eq : bool
 *     all build in heuristics provide proofs with all guesses
 *     if no proof is provided by user defined heuristics this
 *     argument can be set to true to do a case split instead
 *
 * - args
 *     a list of quant_params
 *****************************************************)

fun EXTENSIBLE_QUANT_INSTANTIATE_CONV cache_ref_opt re filter min_occs expand_eq args =
    let val arg = (combine_qps args) in
    HEURISTIC_QUANT_INSTANTIATE_CONV re filter min_occs (QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE arg cache_ref_opt) expand_eq (#final_rewrite_thms arg)
    end

(*A simpler interface, here just the
  quant_params list is needed*)
val QUANT_INSTANTIATE_CONV =
    EXTENSIBLE_QUANT_INSTANTIATE_CONV NONE true (K true) true false

val FAST_QUANT_INSTANTIATE_CONV =
    EXTENSIBLE_QUANT_INSTANTIATE_CONV NONE true (K true) false false


(*a stateful heuristic and
    quant_param*)

val quant_param_ref =
   ref empty_qp;

fun clear_stateful_qp () =
    (quant_param_ref := empty_qp);


fun stateful_qp___add_combine_arguments args =
   (quant_param_ref :=
     combine_qps ((!quant_param_ref)::args));



fun QUANT_INSTANTIATE_HEURISTIC___STATEFUL sys fv v t =
  let
    val {distinct_thms = distinct_thmL,
         cases_thms = cases_thmL,
         rewrite_thms = rewrite_thmL,
         convs = convL,
         heuristics = heuristicL,
         final_rewrite_thms = final_rewrite_thmL} = !quant_param_ref;

    val hL = (QUANT_INSTANTIATE_HEURISTIC___cases_list cases_thmL)::
       	     (QUANT_INSTANTIATE_HEURISTIC___EQUATION_distinct distinct_thmL)::
             (append (map QUANT_INSTANTIATE_HEURISTIC___CONV ((TOP_ONCE_REWRITE_CONV rewrite_thmL)::convL))
	      heuristicL);
    val gc = guess_collection_flatten (map (fn h => SOME (h sys fv v t) handle QUANT_INSTANTIATE_HEURISTIC___no_guess_exp => NONE) hL)
in
   gc
end;



val TypeBase_qp =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    final_rewrite_thms = [],
    convs=[],heuristics=[
       QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_one_one,
       QUANT_INSTANTIATE_HEURISTIC___EQUATION___TypeBase_distinct,
       QUANT_INSTANTIATE_HEURISTIC___TypeBase_cases]}:quant_param;


val pure_stateful_qp =
   {distinct_thms=[],
    rewrite_thms=[],
    cases_thms=[],
    final_rewrite_thms = [],
    convs=[],heuristics=[
       QUANT_INSTANTIATE_HEURISTIC___STATEFUL]}:quant_param;

val stateful_qp = combine_qp TypeBase_qp pure_stateful_qp;



fun get_qp___for_types typeL =
       {distinct_thms = map TypeBase.distinct_of typeL,
        cases_thms = map TypeBase.nchotomy_of typeL,
        rewrite_thms = map TypeBase.one_one_of typeL,
        final_rewrite_thms = [],
        convs=[],heuristics=[]}:quant_param;

fun QUANT_INSTANTIATE_TAC L =
    CONV_TAC (QUANT_INSTANTIATE_CONV L);


fun ASM_QUANT_INSTANTIATE_TAC L =
    DISCH_ASM_CONV_TAC (QUANT_INSTANTIATE_CONV L);


fun FAST_QUANT_INSTANTIATE_TAC L =
    CONV_TAC (FAST_QUANT_INSTANTIATE_CONV L);

fun ASM_FAST_QUANT_INSTANTIATE_TAC L =
    DISCH_ASM_CONV_TAC (FAST_QUANT_INSTANTIATE_CONV L);







(***********************************************
 * Instantiate quantifiers by explicitly given
 * guesses
 ***********************************************)

fun REWRITE_PROVE t =
let
   open metisLib
   val thm = REWRITE_CONV [] t handle UNCHANGED => REFL t;
   val t2 = rhs (concl thm)
   val thm2 = if t2 = T then TRUTH else METIS_PROVE [] t2;
in
   EQ_MP (GSYM thm) thm2
end;




(*
val t = ``t = 0``
val v = ``t:num``
val ctxt = []
val try_proof = false;
val L = [("x", `0`, []), ("t", `xxx n`:term frag list, ["n"])]
val L = [("pdata'", `idata_h::pdata22`:term frag list, [`pdata22`]),
	   ("idata'", `idata_t`, [])]
*)


fun QUANT_INSTANTIATE_HEURISTIC___LIST ctxt try_proof L fv v t =
let
   val (v_name, v_type) = dest_var v
   val (_,i_quot,free_vars_quot) = first (fn (p,_,_) => (p = v_name)) L;

   val i_quot' = QUOTE "(" :: (i_quot @ [QUOTE "):", ANTIQUOTE(ty_antiq v_type), QUOTE ""]);

   val ctxt = append (Term.free_vars t) ctxt;
   val i' = Parse.parse_in_context ctxt i_quot';
   val ctxt = append (Term.free_vars i') ctxt;

   val fvL' = map (fn s => Parse.parse_in_context ctxt s) free_vars_quot;

   val (i,fvL) = term_variant fv fvL' i';

   fun add_thm guess = make_set_guess_thm_opt v t guess REWRITE_PROVE


in
  if not try_proof then
  {rewrites            = [],
   general             = [guess_general (i,fvL)],
   true                = [],
   false               = [],
   only_not_possible   = [],
   only_possible       = [],
   others_satisfied    = [],
   others_not_possible = []}
  else
  {rewrites            = [],
   general             = [],
   true                = [],
   false               = [],
   only_not_possible   = [add_thm (guess_only_not_possible (i,fvL,NONE))],
   only_possible       = [add_thm (guess_only_possible (i,fvL,NONE))],
   others_satisfied    = [add_thm (guess_others_satisfied (i,fvL,NONE))],
   others_not_possible = [add_thm (guess_others_not_possible (i,fvL,NONE))]}:guess_collection
end handle HOL_ERR _ => raise QUANT_INSTANTIATE_HEURISTIC___no_guess_exp;



fun QUANT_INST_TAC L (asm,t) =
  let
     val ctxt = HOLset.listItems (FVL (t::asm) empty_tmset);
  in
    REDEPTH_CONSEQ_CONV_TAC
      (QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (false,false,false)
         (K true) false (QUANT_INSTANTIATE_HEURISTIC___LIST ctxt false L) [])
    (asm,t)
  end;




fun QUANT_INST_CONV L t =
  let
     val ctxt = HOLset.listItems (FVL [t] empty_tmset);
  in
    DEPTH_CONV
      (QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (true,true,false)
         (K true) false (QUANT_INSTANTIATE_HEURISTIC___LIST ctxt true L) [] CONSEQ_CONV_UNKNOWN_direction)
    t
  end;



fun HEURISTIC_QUANT_INSTANTIATE_CONSEQ_CONV re filter min_occs heuristic rwL dir =
THEN_CONSEQ_CONV
((if re then REDEPTH_CONSEQ_CONV else DEPTH_CONSEQ_CONV)
   (QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (false,true,false) filter min_occs heuristic rwL) dir)
(REWRITE_CONV rwL);


fun EXTENSIBLE_QUANT_INSTANTIATE_CONSEQ_CONV cache_ref_opt re filter min_occs args =
    let val arg = (combine_qps args) in
    HEURISTIC_QUANT_INSTANTIATE_CONSEQ_CONV re filter min_occs (QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE
       arg cache_ref_opt) (#final_rewrite_thms arg) end;

val QUANT_INSTANTIATE_CONSEQ_CONV =
    EXTENSIBLE_QUANT_INSTANTIATE_CONSEQ_CONV NONE true (K true) true

val FAST_QUANT_INSTANTIATE_CONSEQ_CONV =
    EXTENSIBLE_QUANT_INSTANTIATE_CONSEQ_CONV NONE true (K true) false

fun EXTENSIBLE_QUANT_INSTANTIATE_STEP_CONSEQ_CONV cache_ref_opt filter min_occs args =
    let val arg = (combine_qps args) in
    (QUANT_INSTANTIATE_HEURISTIC_STEP_CONSEQ_CONV (false,true,false) filter min_occs
          (QUANT_INSTANTIATE_HEURISTIC___PURE_COMBINE arg cache_ref_opt)
            (#final_rewrite_thms arg)) end;


(*******************************************************************
 * Simpset frags
 *******************************************************************)

fun QUANT_INST_ss qpL = simpLib.conv_ss
   {name = "QUANT_INSTANTIATE_CONV",
    trace = 2,
    key = NONE,
    conv = K (K (QUANT_INSTANTIATE_CONV qpL))}




end