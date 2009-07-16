signature powserTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val diffs : thm
  
  (*  Theorems  *)
    val DIFFS_EQUIV : thm
    val DIFFS_LEMMA : thm
    val DIFFS_LEMMA2 : thm
    val DIFFS_NEG : thm
    val POWDIFF : thm
    val POWDIFF_LEMMA : thm
    val POWREV : thm
    val POWSER_INSIDE : thm
    val POWSER_INSIDEA : thm
    val TERMDIFF : thm
    val TERMDIFF_LEMMA1 : thm
    val TERMDIFF_LEMMA2 : thm
    val TERMDIFF_LEMMA3 : thm
    val TERMDIFF_LEMMA4 : thm
    val TERMDIFF_LEMMA5 : thm
  
  val powser_grammars : type_grammar.grammar * term_grammar.grammar
  
  
(*
   [lim] Parent theory of "powser"
   
   [diffs]  Definition
      
      |- !c. diffs c = (\n. &SUC n * c (SUC n))
   
   [DIFFS_EQUIV]  Theorem
      
      |- !c x.
           summable (\n. diffs c n * x pow n) ==>
           (\n. &n * (c n * x pow (n - 1))) sums
           suminf (\n. diffs c n * x pow n)
   
   [DIFFS_LEMMA]  Theorem
      
      |- !n c x.
           sum (0,n) (\n. diffs c n * x pow n) =
           sum (0,n) (\n. &n * (c n * x pow (n - 1))) +
           &n * (c n * x pow (n - 1))
   
   [DIFFS_LEMMA2]  Theorem
      
      |- !n c x.
           sum (0,n) (\n. &n * (c n * x pow (n - 1))) =
           sum (0,n) (\n. diffs c n * x pow n) - &n * (c n * x pow (n - 1))
   
   [DIFFS_NEG]  Theorem
      
      |- !c. diffs (\n. -c n) = (\n. -diffs c n)
   
   [POWDIFF]  Theorem
      
      |- !n x y.
           x pow SUC n - y pow SUC n =
           (x - y) * sum (0,SUC n) (\p. x pow p * y pow (n - p))
   
   [POWDIFF_LEMMA]  Theorem
      
      |- !n x y.
           sum (0,SUC n) (\p. x pow p * y pow (SUC n - p)) =
           y * sum (0,SUC n) (\p. x pow p * y pow (n - p))
   
   [POWREV]  Theorem
      
      |- !n x y.
           sum (0,SUC n) (\p. x pow p * y pow (n - p)) =
           sum (0,SUC n) (\p. x pow (n - p) * y pow p)
   
   [POWSER_INSIDE]  Theorem
      
      |- !f x z.
           summable (\n. f n * x pow n) /\ abs z < abs x ==>
           summable (\n. f n * z pow n)
   
   [POWSER_INSIDEA]  Theorem
      
      |- !f x z.
           summable (\n. f n * x pow n) /\ abs z < abs x ==>
           summable (\n. abs (f n) * z pow n)
   
   [TERMDIFF]  Theorem
      
      |- !c k' x.
           summable (\n. c n * k' pow n) /\
           summable (\n. diffs c n * k' pow n) /\
           summable (\n. diffs (diffs c) n * k' pow n) /\
           abs x < abs k' ==>
           ((\x. suminf (\n. c n * x pow n)) diffl
            suminf (\n. diffs c n * x pow n)) x
   
   [TERMDIFF_LEMMA1]  Theorem
      
      |- !m z h.
           sum (0,m) (\p. (z + h) pow (m - p) * z pow p - z pow m) =
           sum (0,m) (\p. z pow p * ((z + h) pow (m - p) - z pow (m - p)))
   
   [TERMDIFF_LEMMA2]  Theorem
      
      |- !z h n.
           h <> 0 ==>
           (((z + h) pow n - z pow n) / h - &n * z pow (n - 1) =
            h *
            sum (0,n - 1)
              (\p.
                 z pow p *
                 sum (0,n - 1 - p)
                   (\q. (z + h) pow q * z pow (n - 2 - p - q))))
   
   [TERMDIFF_LEMMA3]  Theorem
      
      |- !z h n k'.
           h <> 0 /\ abs z <= k' /\ abs (z + h) <= k' ==>
           abs (((z + h) pow n - z pow n) / h - &n * z pow (n - 1)) <=
           &n * (&(n - 1) * (k' pow (n - 2) * abs h))
   
   [TERMDIFF_LEMMA4]  Theorem
      
      |- !f k' k.
           0 < k /\
           (!h. 0 < abs h /\ abs h < k ==> abs (f h) <= k' * abs h) ==>
           (f -> 0) 0
   
   [TERMDIFF_LEMMA5]  Theorem
      
      |- !f g k.
           0 < k /\ summable f /\
           (!h.
              0 < abs h /\ abs h < k ==>
              !n. abs (g h n) <= f n * abs h) ==>
           ((\h. suminf (g h)) -> 0) 0
   
   
*)
end
