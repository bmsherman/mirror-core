(* PolyQuantPullRtac.v
 * Rtac implementation of existential quantifier puller, which can "pull"
 * quantifiers out of and'd expressions to the front.
 * Testbed for the second-class polymorphism mechanism.
 *)

Require Import ExtLib.Core.RelDec.
Require Import ExtLib.Tactics.
Require Import MirrorCore.Util.Compat.
Require Import MirrorCore.Views.Ptrns.
Require Import MirrorCore.Lambda.ExprCore.
Require Import MirrorCore.Lambda.ExprD.
Require Import MirrorCore.Lambda.RedAll.
Require Import MirrorCore.Lambda.RewriteRelations.
Require Import MirrorCore.Lambda.RewriteStrat.
Require Import MirrorCore.Lambda.Red.
Require Import MirrorCore.Lambda.Ptrns.
Require Import MirrorCore.Lambda.Rewrite.HintDbs.
Require Import MirrorCore.Reify.Reify.
Require Import MirrorCore.RTac.IdtacK.
Require Import MirrorCore.MTypes.ModularTypes.
Require Import McExamples.PolyRewrite.MSimple.
Require Import McExamples.PolyRewrite.MSimpleReify.

Set Implicit Arguments.
Set Strict Implicit.

Let Rbase := expr typ func.

Reify Declare Patterns patterns_concl : (rw_concl typ func Rbase).

Reify Declare Syntax reify_concl_base :=
  (CPatterns patterns_concl).

(* Pattern language notations *)
Local Notation "x @ y" := (@RApp x y) (only parsing, at level 30).
Local Notation "'!!' x" := (@RExact _ x) (only parsing, at level 25).
Local Notation "'?' n" := (@RGet n RIgnore) (only parsing, at level 25).
Local Notation "'?!' n" := (@RGet n RConst) (only parsing, at level 25).
Local Notation "'#'" := RIgnore (only parsing, at level 0).

Reify Pattern patterns_concl += (?0 @ ?1 @ ?2) =>
  (fun (a b c : function reify_simple) =>
     @Build_rw_concl typ func Rbase b (@Rinj typ Rbase a) c).

Reify Pattern patterns_concl += (!!Basics.impl @ ?0 @ ?1) =>
  (fun (a b : function reify_simple) =>
     @Build_rw_concl typ func Rbase a (@Rinj typ Rbase (Inj Impl)) b).
Reify Pattern patterns_concl += (!!(@Basics.flip Prop Prop Prop) @ !!Basics.impl @ ?0 @ ?1) =>
  (fun (a b : function reify_simple) =>
     @Build_rw_concl typ func Rbase a (Rflip (@Rinj typ Rbase (Inj Impl))) b).

Existing Instance RType_typ.
Existing Instance Expr.Expr_expr.
Existing Instance Typ2_Fun.
Existing Instance Typ2Ok_Fun.

Definition RbaseD (e : expr typ func) (t : typ)
  : option (TypesI.typD t -> TypesI.typD t -> Prop) :=
  env_exprD nil nil (tyArr t (tyArr t tyProp)) e.

Theorem RbaseD_single_type
: forall (r : expr typ func) (t1 t2 : typ)
         (rD1 : TypesI.typD t1 -> TypesI.typD t1 -> Prop)
         (rD2 : TypesI.typD t2 -> TypesI.typD t2 -> Prop),
    RbaseD r t1 = Some rD1 -> RbaseD r t2 = Some rD2 -> t1 = t2.
Proof.
  unfold RbaseD, env_exprD. simpl; intros.
  forward.
  generalize (lambda_exprD_deterministic _ _ _ H0 H). unfold Rty.
  intros. inversion H3. reflexivity.
Qed.

Theorem pull_ex_and_left
: forall T P Q, Basics.flip Basics.impl ((@ex T P) /\ Q) (exists n, P n /\ Q).
Proof.
  do 2 red. intros.
  destruct H. destruct H. split; eauto.
Qed.

Reify BuildLemma < reify_simple_typ reify_simple reify_concl_base >
lem_pull_ex_nat_and_left : @pull_ex_and_left nat.

(* TODO - update reifier plugin so that we can produce polymorphic lemmas
   and don't have to input them manually *)
Definition lem_pull_ex_and_left : typ -> Lemma.lemma typ (expr typ func) (rw_concl typ func Rbase) :=
  fun ty : typ =>
{|
Lemma.vars := tyProp :: tyArr ty tyProp :: nil;
Lemma.premises := nil;
Lemma.concl := {|
               lhs := App
                        (App (Inj And)
                           (App (Inj (Ex ty)) (ExprCore.Var 1)))
                        (ExprCore.Var 0);
               rel := Rflip (Rinj (Inj Impl));
               rhs := App (Inj (Ex ty))
                        (Abs ty
                           (App
                              (App (Inj And)
                                 (App (ExprCore.Var 2) (ExprCore.Var 0)))
                              (ExprCore.Var 1))) |} |}.

(* Lemmas used by the quantifier puller *)
Lemma lem_pull_ex_and_left_sound
  : forall t : typ,
    Lemma.lemmaD (rw_conclD RbaseD) nil nil (lem_pull_ex_and_left t).
Proof.
  intros.
  repeat progress (red; simpl; try rewrite mtyp_cast_refl).
  intros.
  repeat progress (red in H; simpl in H).
  forward_reason.
  repeat progress (red in H; simpl in H).
  split; auto.
  eexists; eauto.
Qed.

Definition lem_pull_ex_nat_and_left_sound
: Lemma.lemmaD (rw_conclD RbaseD) nil nil lem_pull_ex_nat_and_left :=
  @pull_ex_and_left nat.

Theorem pull_ex_and_right
: forall T P Q, Basics.flip Basics.impl (Q /\ (@ex T P)) (exists n, Q /\ P n).
Proof.
  destruct 1. destruct H.
  split; eauto.
Qed.


Reify BuildLemma < reify_simple_typ reify_simple reify_concl_base >
lem_pull_ex_nat_and_right : @pull_ex_and_right nat.

Definition lem_pull_ex_and_right : typ -> Lemma.lemma typ (expr typ func) (rw_concl typ func Rbase) :=
  fun ty : typ =>
    {|
      Lemma.vars := tyProp :: tyArr ty tyProp :: nil;
      Lemma.premises := nil;
      Lemma.concl := {|
                      lhs := App (App (Inj And) (ExprCore.Var 0))
                                 (App (Inj (Ex ty)) (ExprCore.Var 1));
                      rel := Rflip (Rinj (Inj Impl));
                      rhs := App (Inj (Ex ty))
                                 (Abs ty
                                      (App (App (Inj And) (ExprCore.Var 1))
                                           (App (ExprCore.Var 2) (ExprCore.Var 0)))) |} |}.

Lemma lem_pull_ex_and_right_sound
  : forall t : typ,
    Lemma.lemmaD (rw_conclD RbaseD) nil nil (lem_pull_ex_and_right t).
Proof.
  intros.
  repeat progress (red; simpl; try rewrite mtyp_cast_refl).
  intros.
  repeat progress (red in H; simpl in H).
  forward_reason.
  repeat progress (red in H0; simpl in H0).
  split; eauto.
Qed.

Definition is_refl : refl_dec Rbase :=
  fun (r : Rbase) =>
    match r with
    | Inj (Eq _)
    | Inj Impl => true
    | _ => false
    end.

(* TODO(gmalecha): The majority the complexity of this file comes from
 * simplifying the denotation function. A few tactics should improve this
 * dramatically.
 *)
Theorem is_refl_ok : refl_dec_ok RbaseD is_refl.
Proof.
  red.
  destruct r; simpl; try congruence.
  destruct f; simpl; try congruence.
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst. simpl.
    clear. red in r. inversion r.
    subst.
    rewrite (UIP_refl r). compute. reflexivity. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst. simpl.
    clear. red in r. inversion r.
    subst.
    rewrite (UIP_refl r). compute. intros; tauto. }
Qed.

Definition is_trans : trans_dec Rbase :=
  fun r =>
    match r with
    | Inj (Eq _)
    | Inj Lt
    | Inj Impl => true
    | _ => false
    end.

Theorem is_trans_ok : trans_dec_ok RbaseD is_trans.
Proof.
  red.
  destruct r; simpl; try congruence.
  destruct f; simpl; try congruence.
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst.
    simpl. clear. inversion r.
    subst. rewrite (UIP_refl r). compute. congruence. }
  { unfold RbaseD; simpl.
    unfold env_exprD. simpl. intros.
    autorewrite with exprD_rw in H0.
    forward. inv_all; subst.
    unfold symAs in H0. unfold typeof_sym in H0.
    unfold RSym_func in H0.
    unfold typeof_func in H0.
    forward. inv_all. subst.
    clear. inversion r. subst.
    rewrite (UIP_refl r).
    compute. tauto. }
Qed.

Definition flip_impl : R typ Rbase := Rflip (Rinj (Inj Impl)).

Existing Instance RelDec_eq_mtyp.

Let tyBNat := tyBase0 tyNat.

Check do_respectful.
(* list (expr typ func * R typ Rbase) *)
Print Polymorphic.polymorphic.

(* Polymorphic wrapper for do_respectful *)
Print PRw.
Print Proper_concl.

Inductive HintProper : Type :=
| PPr_tc : forall n : nat,
    Polymorphic.polymorphic (mtyp typ') n (@Proper_concl typ func Rbase) ->
    (* typeclass constraints *)
    Polymorphic.polymorphic (mtyp typ') n bool ->
    HintProper
.

Definition ProperDb := list HintProper.

Print HintRewrite.

Inductive HintRewrite : Type :=
    | PRw_tc : forall n : nat,
        Polymorphic.polymorphic (mtyp typ') n (rw_lemma (mtyp typ') func Rbase) ->
        Polymorphic.polymorphic (mtyp typ') n bool ->
        CoreK.rtacK (mtyp typ') (expr (mtyp typ') func) ->
        HintRewrite.

Definition RewriteDb := list HintRewrite.

(* TODO: rewrite hints-compile in such a way as to use map *)
Arguments fail_respectful {_ _ _} _ _ _ _ _ _ _ _ _.

Require Import ExtLib.Data.Vector.

(* copied from HintDbs.v *)
Require Import MirrorCore.Lib.TypeVar.
Universe X.

Let local_view : (PartialView@{X} typ (VType 0)) :=
  {| f_insert := fun x => match x with
                       | tVar p => tyVar p
                       end
     ; f_view := fun x => match x with
                       | tyVar x => POption.pSome (tVar x)
                       | _ => POption.pNone
                       end |}.

Arguments term {_ _ _} _.

Definition PolymorphicD {T} (TD : T -> Prop) n x : Prop :=
  forall (v : Vector.vector typ n),
    TD (Polymorphic.inst x v).

Arguments Build_Proper_concl {_ _ _} _ _.
Require Import MirrorCore.Lambda.Polymorphic.
Require Import MirrorCore.Util.Forwardy.

(* TODO - pass instantiation functions *)
Definition get_proper (n : nat)
           (p : Polymorphic.polymorphic (mtyp typ') n (Proper_concl Rbase))
           (tc : Polymorphic.polymorphic (mtyp typ') n bool)
           (e : expr typ func)
  : option (Proper_concl Rbase) :=
  let p' :=
      Functor.fmap term p in
  match @PolyInst.get_inst _ _ _ _ local_view HintDbs.view_update n p' e with
  | Some args =>
    if (Polymorphic.inst tc args)
    then Some (Polymorphic.inst p args)
    else None
  | None => None
  end.

(* *)
Definition properD (pc : Proper_concl Rbase) : Prop :=
  match pc with
  | Build_Proper_concl r e =>
    match typeof_expr nil nil e with
    | Some t =>
      match RD RbaseD r t with
      | Some rD =>
        match lambda_exprD nil nil t e with
        | Some eD =>
          Morphisms.Proper rD (eD HList.Hnil HList.Hnil)
        | None => False
        end
      | None => False
      end
    | None => False
    end
  end.

(* build a make_polymorphic function that takes a vector of types *)

Print polymorphic.

Fixpoint make_polymorphic T U n {struct n} : (vector T n -> U) -> polymorphic T n U :=
  match n as n return (vector T n -> U) -> polymorphic T n U with
          | 0 => fun P => P (Vnil _)
          | S n' => fun P => fun v => (make_polymorphic (fun V => P (Vcons v V)))
  end.  

Definition tc_properD {T : Type} (TD : T -> Prop) n (tc : Polymorphic.polymorphic (mtyp typ') n bool) pc : polymorphic (mtyp typ') n Prop :=
  make_polymorphic (fun args =>
                      if Polymorphic.inst tc args
                      then TD (Polymorphic.inst pc args)
                      else True).

Lemma inst_sound :
  forall {T} n (y: polymorphic typ n T) (P : T -> Prop) v,
    PolymorphicD P n y ->
    P (inst y v).
Proof.
  unfold PolymorphicD.
  intros.
  auto.
Qed.

Lemma make_polymorphic_inst :
  forall T n f v,
    @inst (mtyp typ') T n (make_polymorphic f) v = f v.
Proof.
  induction v; simpl; try rewrite IHv; reflexivity.
Qed.

(* need with_typeclass_lemmaD *)
(* this probably means we need some kind of abstraction *)
Lemma get_proper_sound :
  forall n (p : polymorphic _ _ _) (tc : polymorphic _ _ _) e x,
      get_proper n p tc e  = Some x ->
      PolymorphicD (fun x => x) n (tc_properD properD n tc p) ->
      properD x.
Proof.
  unfold get_proper. simpl. intros.
  forwardy.
  destruct (inst tc y) eqn:Hitc; [|congruence].
  inversion H1. subst. clear H1.
  eapply inst_sound with (v := y) in H0.
  unfold tc_properD in H0.
  rewrite make_polymorphic_inst in H0.
  rewrite Hitc in H0.
  assumption.
Qed.

Check get_proper.

Definition do_one_prespectful (h : HintProper) : respectful_dec typ func Rbase :=
  match h with
  | PPr_tc n pc tc =>
    (fun (e : expr typ func) =>
       match get_proper n pc tc e with
       | Some lem =>
         apply_respectful rel_dec {| Lemma.vars := nil;
                                     Lemma.premises := nil;
                                     Lemma.concl := lem |} IDTACK e
       | None => fail_respectful e
         end)
  end.

Existing Instance Polymorphic.Functor_polymorphic.

Fixpoint do_prespectful (pdb : ProperDb) : respectful_dec typ func Rbase :=
  match pdb with
  | nil => fail_respectful
  | p :: pdb' =>
    or_respectful
      (do_one_prespectful p)
      (fun (e : expr typ func) => do_prespectful pdb' e)
  end.

(*Require Import MirrorCore.Lambda.Rewrite.HintDbs.*)

Definition ProperHintOk (hp : HintProper) : Prop :=
  match hp with
  | PPr_tc n pc tc =>
    PolymorphicD (fun x => x) n (tc_properD properD n tc pc)
  end.

Definition ProperDb_sound (pdb : ProperDb) : Prop :=
  Forall ProperHintOk pdb.

Lemma Proper_conclD_properD :
  forall x,
    properD x -> Proper_conclD RbaseD nil nil x = Some (fun _ _ => properD x).
Proof.
  destruct x; simpl.
  unfold Proper_conclD. simpl.
  forward.
  f_equal.
  Locate functional_extensionality.
  Require Import Coq.Logic.FunctionalExtensionality.
  do 2 (apply functional_extensionality; intros).
  Require Import ExtLib.Data.HList.
  rewrite (hlist_eta x). rewrite (hlist_eta x0).
  reflexivity.
Qed.

Lemma do_one_prespectful_sound :
  forall hp : HintProper,
    ProperHintOk hp ->
    respectful_spec RbaseD (do_one_prespectful hp).
Proof.
  intros.
  unfold do_one_prespectful.
  destruct hp.
  red. intros.
  generalize (@get_proper_sound n p p0 e).
  destruct (get_proper n p p0 e).
  {
    intros.
    eapply apply_respectful_sound; eauto using IDTACK_sound.
    apply RelDecCorrect_eq_expr; eauto with typeclass_instances.
    red. simpl.
    red. simpl.
    specialize (H2 _ eq_refl H).
    rewrite Proper_conclD_properD; assumption.
  }
  {
    intros.
    apply fail_respectful_sound; auto.
  }
Qed.

Lemma do_prespectful_sound :
  forall pdb,
    ProperDb_sound pdb ->
    respectful_spec RbaseD (do_prespectful pdb).
Proof.
  induction 1.
  { apply fail_respectful_sound. }
  { apply or_respectful_sound.
    { apply do_one_prespectful_sound; assumption. }
    { assumption. } }
Qed.

(* should make monomorphic wrapper for properness
   make rewrites have 1 constructor (and mono. wrapper)
   comment and clean up
   move everything into mirror-core
   type classes (possibly before move)
 *)

(* no-op typeclass, used to construct polymorphic types without constraints *)
Definition tc_any (n : nat) : polymorphic (mtyp typ') n bool :=
  make_polymorphic (fun _ => true).

(* Polymorphic rewrite hints support *)
Definition hints_sound (hints : expr typ func -> R typ Rbase ->
                     list (rw_lemma typ func Rbase * CoreK.rtacK typ (expr typ func))) : Prop :=
        (forall r e,
            Forall (fun lt =>
                      (forall tus tvs t eD,
                          lambda_exprD tus tvs t e = Some eD ->
                          Lemma.lemmaD (rw_conclD RbaseD) nil nil (fst lt)) /\
                      CoreK.rtacK_sound (snd lt)) (hints e r)).

(* Soundness for individual lemmas in a hint database *)
Definition prewrite_Rw_sound (lem : rw_lemma typ func Rbase) (rts : CoreK.rtacK typ (expr typ func)) : Prop :=
  Lemma.lemmaD (rw_conclD RbaseD) nil nil lem /\
  CoreK.rtacK_sound rts.

(* TODO (Mario) - write a convencience function to make this easier to use than working
   directly with the vector. *)
Definition prewrite_Prw_tc_sound (n : nat) (plem : Polymorphic.polymorphic typ n (rw_lemma typ func Rbase))
           (tc : polymorphic typ n bool)
           (rts : CoreK.rtacK typ (expr typ func)) : Prop :=
  (forall (v : Vector.vector typ n),
      (inst tc v = true) ->
      Lemma.lemmaD (rw_conclD RbaseD) nil nil (Polymorphic.inst plem v)) /\
  CoreK.rtacK_sound rts.

Check PRw_tc.
Print RewriteHintDb.

Check RewriteDb.
Check PRw_tc.

Definition RewriteHintDb_sound (db : RewriteHintDb Rbase) : Prop :=
  Forall (fun h : HintRewrite =>
            match h with
            | PRw_tc n plem tc rts => prewrite_Prw_tc_sound n plem tc rts
            end) db.

Lemma CompileHints_sound :
  forall db,
    RewriteHintDb_sound db ->
    hints_sound (CompileHints db).
Proof.
  induction db; intros; simpl.
  { unfold hints_sound. intros. constructor. }
  { inversion H; subst; clear H.
    specialize (IHdb H3). clear H3.
    unfold hints_sound. intros.
    destruct a.
    (* PRw case *)
    { destruct (HintDbs.get_lemma Rbase p e) eqn:Hgl; [|eapply IHdb].
      constructor; [|eauto].
      unfold prewrite_Prw_sound in *. forward_reason.
      split; [|eauto]. intros.
      simpl.
      unfold HintDbs.get_lemma in *.
      Require Import MirrorCore.Util.Forwardy.
      forwardy.
      inversion H3; subst; clear H3.
      eauto. }

    (* Rw case *)
    { constructor; [|eauto].
      unfold prewrite_Rw_sound in H2. forward_reason.
      simpl. split; auto. } }
Qed.


(* Convenience constructors for building lemmas that do not leverage full polymorphism *)
(* non polymorphic rewrite hint *)
Print HintRewrite.
Definition Rw (rw : rw_lemma (mtyp typ') func Rbase) :
  (CoreK.rtacK (mtyp typ') (expr (mtyp typ') func)) -> HintRewrite :=
  PRw_tc 0 rw true.

SearchAbout rw_lemma.

Definition RwOk (rw : rw_lemma (mtyp typ') func Rbase) :=
  lemmaD.

(* polymorphic rewrite hint without typeclass constraints *)
Definition PRw

(* non polymorphic proper hint *)
Definition Pr (pc : Proper_concl Rbase) :=
  PPr_tc 0 pc true.

Definition PrOk (pc : Proper_concl Rbase) :=
  properD pc.

(* polymorphic proper hint without typeclass constraints *)
Definition PPr (n : nat) (pc : polymorphic (mtyp typ') n (Proper_concl Rbase)) :=
  PPr_tc n pc (tc_any n).

Definition PPrOk (n : nat) (pc : polymorphic (mtyp typ') n (Proper_concl Rbase)) :=
  PolymorphicD properD n pc.

Definition get_respectful_only_all_ex : respectful_dec typ func Rbase :=
  do_prespectful
  (PPr 1 (fun T => {|term := Inj (Ex T); relation := Rrespects (Rpointwise T flip_impl) flip_impl |}) ::
       PPr 1 (fun T => {|term := Inj (All T); relation := Rrespects (Rpointwise T flip_impl) flip_impl |}) ::
     nil).

Definition get_respectful : respectful_dec typ func Rbase :=
  do_prespectful
    (PPr 1 (fun T => {|term := Inj (Ex T); relation := Rrespects (Rpointwise T flip_impl) flip_impl |}) ::
         PPr 1 (fun T => {|term := Inj (All T); relation := Rrespects (Rpointwise T flip_impl) flip_impl |}) ::
         Pr {| term := Inj And; relation := Rrespects flip_impl (Rrespects flip_impl flip_impl) |} ::
         Pr {| term := Inj Or; relation := Rrespects flip_impl (Rrespects flip_impl flip_impl) |} ::
         Pr {| term := Inj Plus;
               relation := Rrespects (Rinj (Inj (Eq tyBNat)))
                                     (Rrespects (Rinj (Inj (Eq tyBNat))) (Rinj (Inj (Eq tyBNat)))) |} :: nil).

Lemma RelDec_semidec {T} (rT : T -> T -> Prop)
      (RDT : RelDec rT) (RDOT : RelDec_Correct RDT)
: forall a b : T, a ?[ rT ] b = true -> rT a b.
Proof. intros. consider (a ?[ rT ] b); auto. Qed.

Ltac prove_prespectful :=
  repeat match goal with
         | |- _ -> _ => intros
         | |- context[mtyp_cast _ _ _ _] => rewrite mtyp_cast_refl
         | _ => red; simpl
         end; firstorder.

Theorem get_respectful_only_all_ex_sound
: respectful_spec RbaseD get_respectful_only_all_ex.
Proof.
  eapply do_prespectful_sound.
  repeat first [ eapply Forall_cons | eapply Forall_nil ]; simpl; prove_prespectful.
Qed.

Theorem get_respectful_sound : respectful_spec RbaseD get_respectful.
Proof.
  eapply do_prespectful_sound.
  repeat first [eapply Forall_cons | eapply Forall_nil]; prove_prespectful.
Qed.


Require Import MirrorCore.Views.Ptrns.

Definition simple_reduce (e : expr typ func) : expr typ func :=
  run_ptrn
    (pmap (fun abcd => let '(a,(b,(c,d),e)) := abcd in
                       App a (Abs c (App (App b d) e)))
          (app get (abs get (fun t =>
                               app (app get
                                        (pmap (fun x => (t,Red.beta x)) get))
                                   (pmap Red.beta get)))))
    e e.

(* build hint database from provided lemmas list *)
(*
Definition build_hint_db (lems : list (rw_lemma typ func (expr typ func) *
                                     CoreK.rtacK typ (expr typ func))) : RewriteHintDb Rbase :=
  List.map (fun l => let '(rwl, rtc) := l in
                  Rw rwl rtc
           ) lems.
*)

Definition the_rewrites (lems : RewriteHintDb Rbase)
  : lem_rewriter typ func Rbase :=
  (*rw_post_simplify simple_reduce (rw_simplify Red.beta (using_rewrite_db rel_dec lems)).*)
  rw_post_simplify simple_reduce (rw_simplify Red.beta (using_prewrite_db rel_dec (CompileHints lems))).

Lemma simple_reduce_sound :
  forall (tus tvs : tenv typ) (t : typ) (e : expr typ func)
         (eD : exprT tus tvs (TypesI.typD t)),
    ExprDsimul.ExprDenote.lambda_exprD tus tvs t e = Some eD ->
    exists eD' : exprT tus tvs (TypesI.typD t),
      ExprDsimul.ExprDenote.lambda_exprD tus tvs t (simple_reduce e) = Some eD' /\
      (forall (us : HList.hlist TypesI.typD tus)
              (vs : HList.hlist TypesI.typD tvs), eD us vs = eD' us vs).
Proof.
  unfold simple_reduce.
  intros.
  revert H.
  eapply Ptrns.run_ptrn_sound.
  { repeat first [ simple eapply ptrn_ok_pmap
                 | simple eapply ptrn_ok_app
                 | simple eapply ptrn_ok_abs; intros
                 | simple eapply ptrn_ok_get
                 ]. }
  { do 3 red. intros; subst.
    reflexivity. }
  { intros. ptrnE.
    eapply lambda_exprD_Abs_prem in H; forward_reason; subst.
    inv_all. subst.
    generalize (Red.beta_sound tus (x4 :: tvs) x10 x6).
    generalize (Red.beta_sound tus (x4 :: tvs) x7 x).
    simpl.
    change_rewrite H1. change_rewrite H2.
    intros; forward.
    erewrite lambda_exprD_App; try eassumption.
    2: erewrite lambda_exprD_Abs; try eauto with typeclass_instances.
    2: rewrite typ2_match_iota; eauto with typeclass_instances.
    2: rewrite type_cast_refl; eauto with typeclass_instances.
    2: erewrite lambda_exprD_App; try eassumption.
    3: erewrite lambda_exprD_App; try eassumption; eauto.
    2: autorewrite_with_eq_rw; reflexivity.
    simpl. eexists; split; eauto.
    unfold AbsAppI.exprT_App, AbsAppI.exprT_Abs. simpl.
    intros. unfold Rrefl, Rcast_val, Rcast, Relim; simpl.
    f_equal.
    apply FunctionalExtensionality.functional_extensionality.
    intros. rewrite H5. rewrite H6. reflexivity. }
  { eauto. }
Qed.

Theorem the_rewrites_sound
: forall hints, RewriteHintDb_sound hints ->
    setoid_rewrite_spec RbaseD (the_rewrites hints).
Proof.
  unfold the_rewrites. intros.
  eapply rw_post_simplify_sound.
  { eapply simple_reduce_sound. }
  eapply rw_simplify_sound.
  { intros.
    generalize (Red.beta_sound tus tvs e t). rewrite H0.
    intros; forward. eauto. }
  eapply using_prewrite_db_sound; eauto with typeclass_instances.
  { eapply RelDec_semidec; eauto with typeclass_instances. }
  { eapply RbaseD_single_type. }
  { eapply CompileHints_sound.
    auto. }
Qed.

Definition the_lemmas
  : RewriteHintDb Rbase :=
  PRw _ 1 lem_pull_ex_and_left IDTACK ::
     PRw _ 1 lem_pull_ex_and_right IDTACK ::
     nil.

(* check Polymorphic.v or PolyInst.v  - move the stuff into there. *)

(* need a more convenient interface than raw vectors *)
(* go from poly n to the actual thing with quantifiers as actual quantifiers *)
Theorem the_lemmas_sound : RewriteHintDb_sound the_lemmas.
Proof.
  repeat first [ apply Forall_cons | apply Forall_nil ]; split; try apply IDTACK_sound.
  { intros. unfold Polymorphic.inst. apply lem_pull_ex_and_left_sound. }
  { intros. unfold Polymorphic.inst. apply lem_pull_ex_and_right_sound. }
Qed.

Definition pull_all_quant : lem_rewriter typ func Rbase :=
  repeat_rewrite (fun e r =>
                    bottom_up (is_reflR is_refl) (is_transR is_trans) (the_rewrites the_lemmas)
                              get_respectful_only_all_ex e r)
                 (is_reflR is_refl) (is_transR is_trans) false 300.

Theorem pull_all_quant_sound : setoid_rewrite_spec RbaseD pull_all_quant.
Proof.
  eapply repeat_rewrite_sound.
  + eapply bottom_up_sound.
    - eapply RbaseD_single_type.
    - eapply is_reflROk. eapply is_refl_ok.
    - eapply is_transROk. eapply is_trans_ok.
    - eapply the_rewrites_sound. eapply the_lemmas_sound.
    - eapply get_respectful_only_all_ex_sound.
  + eapply is_reflROk. eapply is_refl_ok.
  + eapply is_transROk. eapply is_trans_ok.
Qed.

Definition quant_pull : lem_rewriter _ _ _ :=
  bottom_up (is_reflR is_refl) (is_transR is_trans) pull_all_quant get_respectful.

Theorem quant_pull_sound : setoid_rewrite_spec RbaseD quant_pull.
Proof.
  eapply bottom_up_sound.
  - eapply RbaseD_single_type.
  - eapply is_reflROk. eapply is_refl_ok.
  - eapply is_transROk. eapply is_trans_ok.
  - eapply pull_all_quant_sound.
  - eapply get_respectful_sound.
Qed.
