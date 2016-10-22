Require Import Coq.Lists.List.
Require Import ExtLib.Tactics.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.ListNth.
Require Import MirrorCore.TypesI.

Set Implicit Arguments.
Set Strict Implicit.
Set Printing Universes.

Polymorphic Lemma f_eq@{A B}
: forall {T : Type@{A}} {U : Type@{B}} (f : T -> U) (a b : T), a = b -> f a = f b.
Proof. intros. destruct H. reflexivity. Defined.

Section Env.
  Variable typ : Set.
  Context {RType_typ : RType typ}.

  (** Environments **)
  Definition tenv : Set := list typ.
  Definition env : Type@{Urefl} := list (sigT (@typD _ _)).

  Definition typeof_env (e : env) : tenv :=
    map (@projT1 _ _) e.

  Fixpoint valof_env (e : env) : hlist typD (typeof_env e) :=
    match e as e return hlist typD (typeof_env e) with
    | nil => Hnil
    | t :: ts => Hcons (projT2 t) (valof_env ts)
    end.

  Definition lookupAs (e : env) (n : nat) (ty : typ) : option (typD ty) :=
    match nth_error e n with
      | None => None
      | Some (existT _ t v) =>
        match type_cast ty t with
          | Some pf => Some (Relim (fun x => x) pf v)
          | None => None
        end
    end.

  Theorem lookupAs_weaken : forall (a b : env) n t x,
    lookupAs a n t = Some x ->
    lookupAs (a ++ b) n t = Some x.
  Proof.
    clear. unfold lookupAs. intros.
    consider (nth_error a n); intros.
    { erewrite nth_error_weaken by eassumption. auto. }
    { exfalso.
      refine match H0 in _ = x return match x return Prop with
                                      | None => True
                                      | Some _ => False
                                      end
             with
             | eq_refl => I
             end. }
  Qed.

  Fixpoint join_env@{} (gs : list typ) (hgs : hlist@{Set Urefl} (@typD _ _) gs) : env :=
    match hgs with
    | Hnil => nil
    | Hcons c d => existT _ _ c :: join_env d
    end.

  Fixpoint split_env@{} (gs : env) : sigT (hlist@{Set Urefl} (@typD _ _)) :=
    match gs with
    | nil => existT _ nil Hnil
    | g :: gs =>
      let res := split_env gs in
      existT _ (projT1 g :: projT1 res) (Hcons (projT2 g) (projT2 res))
    end.

  Theorem split_env_app : forall (gs gs' : env),
    split_env (gs ++ gs') =
    let (a,b) := split_env gs in
    let (c,d) := split_env gs' in
    existT _ ((a ++ c) : list (typ : Set)) (hlist_app b d).
  Proof.
    induction gs; simpl; intros.
    { destruct (split_env gs'); reflexivity. }
    { destruct a. rewrite IHgs.
      destruct (split_env gs).
      destruct (split_env gs'). reflexivity. }
  Qed.

  Theorem split_env_projT1@{} : forall (x : env),
    projT1 (split_env x) = map (@projT1 _ _) x.
  Proof.
    induction x; simpl; intros; auto.
    f_equal. auto.
  Qed.

  Theorem split_env_typeof_env@{} : forall (x : env),
    projT1 (split_env x) = typeof_env x.
  Proof.
    exact split_env_projT1.
  Qed.

  Lemma join_env_app
  : forall a b (ax : hlist _ a) (bx : hlist _ b),
      join_env ax ++ join_env bx = join_env (hlist_app ax bx).
  Proof.
    refine (fix rec (a b : list typ) (ax : hlist@{Set Urefl} _ _) {struct ax} :=
              match ax with
              | Hnil => _
              | Hcons _ _ => _
              end).
    reflexivity.
    simpl. intro. rewrite rec. reflexivity.
  Qed.

  Theorem split_env_nth_error : forall (ve : env) v tv,
    nth_error ve v = Some tv <->
    match nth_error (projT1 (split_env ve)) v as t
          return match t return Type@{Urefl} with
                   | Some v => typD v
                   | None => unit
                 end -> Prop
    with
      | None => fun _ => False
      | Some v => fun res => tv = existT _ v res
    end (hlist_nth (projT2 (split_env ve)) v).
  Proof.
    clear.
    induction ve; simpl; intros.
    { destruct v; simpl in *; intuition; inversion H. }
    { destruct v; simpl in *.
      { intuition.
        { inversion H; subst. destruct tv; reflexivity. }
        { subst. destruct a. reflexivity. } }
      { eapply IHve. } }
  Qed.

  Lemma split_env_nth_error_None
  : forall (ve : env) (v : nat),
      nth_error ve v = None <->
      nth_error (projT1 (split_env ve)) v = None.
  Proof.
    clear.
    induction ve; simpl; intros.
    { destruct v; simpl; intuition. }
    { destruct v; simpl.
      { unfold value. intuition congruence. }
      { rewrite IHve; auto. reflexivity. } }
  Qed.

  Lemma split_env_length : forall (a : env),
    length a = length (projT1 (split_env a)).
  Proof.
    induction a; simpl; auto.
  Qed.

  Theorem split_env_join_env : forall (a : tenv) b,
    split_env (@join_env a b) = existT _ a b.
  Proof.
    induction b; simpl; auto.
    rewrite IHb. eauto.
  Qed.

  Theorem join_env_split_env : forall x,
    join_env (projT2 (split_env x)) = x.
  Proof.
    induction x; simpl; auto.
    rewrite IHx. destruct a; reflexivity.
  Qed.

  Lemma split_env_projT2_join_env : forall x h vs,
    split_env vs = @existT _ _ x h ->
    vs = join_env h.
  Proof.
    induction h; destruct vs; simpl; intros; inversion H; auto.
    subst.
    rewrite join_env_split_env. destruct s; auto.

(*
    induction h; destruct vs; simpl; intros; auto.
    { apply (@f_eq _ _ (@projT1 _ _)) in H. simpl in H. exfalso.
      discriminate H. }
    { apply (@f_eq _ _ (@projT1 _ _)) in H. simpl in H. exfalso.
      discriminate H. }
    { 
*)
  Qed. (** TOO MANY UNIVERSES *)
  Print split_env_projT2_join_env.

  Lemma typeof_env_join_env : forall a (b : HList.hlist _ a),
    typeof_env (join_env b) = a.
  Proof.
    induction a; simpl; intros.
    { rewrite (HList.hlist_eta b). reflexivity. }
    { rewrite (HList.hlist_eta b). simpl. rewrite IHa.
      reflexivity. }
  Qed.

  Lemma map_projT1_split_env
  : forall vs x h,
      split_env vs = existT (HList.hlist _) x h ->
      map (@projT1 _ _) vs = x.
  Proof.
    intros. change x with (projT1 (existT _ x h)).
    rewrite <- H.
    rewrite split_env_projT1. reflexivity.
  Qed.

  Lemma nth_error_join_env
  : forall ls (hls : HList.hlist _ ls) v t,
      nth_error ls v = Some t ->
      exists val,
        nth_error (join_env hls) v = Some (@existT _ _ t val).
  Proof.
    clear.
    induction hls; simpl; intros.
    { destruct v; inversion H. }
    { destruct v; simpl in *; eauto.
      inversion H; clear H; subst. eauto. }
  Qed.

  Theorem split_env_eta : forall vs,
      split_env vs = existT _ (typeof_env vs) (valof_env vs).
  Proof.
    induction vs; simpl; auto.
    rewrite IHvs. simpl. reflexivity.
  Qed.

End Env.

Arguments env {typ _} : rename.
Arguments join_env {typ _ _} _ : rename.
Arguments split_env {typ _} _ : rename.
