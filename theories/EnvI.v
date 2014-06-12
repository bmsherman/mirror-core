Require Import Coq.Lists.List.
Require Import ExtLib.Tactics.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.ListNth.
Require Import MirrorCore.TypesI.

Set Implicit Arguments.
Set Strict Implicit.

Section Env.
  Context {RType_typ : RType}.

  (** Environments **)
  Definition tenv : Type := list typ.
  Definition env : Type := list (sigT (typD nil)).

  Definition typeof_env (e : env) : tenv :=
    map (@projT1 _ _) e.

  Variable ts : list Type.

  Definition lookupAs (e : env) (n : nat) (ty : typ) : option (typD ts ty) :=
    match nth_error e n with
      | None => None
      | Some (existT t v) =>
        match type_cast ts ty t with
          | Some pf => Some (Relim (fun x => x) pf (type_weaken ts t v))
          | None => None
        end
    end.

  Theorem lookupAs_weaken : forall (a b : env) n t x,
    lookupAs a n t = Some x ->
    lookupAs (a ++ b) n t = Some x.
  Proof.
    clear. unfold lookupAs. intros.
    consider (nth_error a n); intros; try congruence.
    erewrite nth_error_weaken by eassumption. auto.
  Qed.

  Fixpoint join_env (gs : list typ) (hgs : hlist (typD nil) gs) : env :=
    match hgs with
      | Hnil => nil
      | Hcons a b c d => existT _ _ c :: join_env d
    end.

  Fixpoint split_env (gs : env) : sigT (hlist (typD nil)) :=
    match gs with
      | nil => existT _ nil Hnil
      | g :: gs =>
        let res := split_env gs in
        existT _ (projT1 g :: projT1 res) (Hcons (projT2 g) (projT2 res))
    end.

  Theorem split_env_app : forall gs gs',
    split_env (gs ++ gs') =
    let (a,b) := split_env gs in
    let (c,d) := split_env gs' in
    existT _ (a ++ c) (hlist_app b d).
  Proof.
    induction gs; simpl; intros.
    { destruct (split_env gs'); reflexivity. }
    { destruct a. rewrite IHgs.
      destruct (split_env gs).
      destruct (split_env gs'). reflexivity. }
  Qed.

  Theorem split_env_projT1 : forall x,
    projT1 (split_env x) = map (@projT1 _ _) x.
  Proof.
    induction x; simpl; intros; auto.
    f_equal. auto.
  Qed.

  Theorem split_env_typeof_env : forall x,
    projT1 (split_env x) = typeof_env x.
  Proof.
    exact split_env_projT1.
  Qed.

  Theorem split_env_nth_error : forall (ve : env) v tv,
    nth_error ve v = Some tv <->
    match nth_error (projT1 (split_env ve)) v as t
          return match t with
                   | Some v => typD nil v
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

  Theorem split_env_join_env : forall a b,
    split_env (@join_env a b) = existT _ a b.
  Proof.
    induction b; simpl; auto.
    rewrite IHb. eauto.
  Qed.

  Theorem join_env_split_env : forall x,
    join_env (projT2 (split_env x)) = x.
  Proof.
    induction x; simpl; auto.
    f_equal; eauto. destruct a; reflexivity.
  Qed.

  Lemma split_env_projT2_join_env : forall x h vs,
    split_env vs = @existT _ _ x h ->
    vs = join_env h.
  Proof.
    induction h; destruct vs; simpl; intros; inversion H; auto.
    subst.
    rewrite join_env_split_env. destruct s; auto.
  Qed.

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

End Env.


Section nth_error_get_hlist_nth.
  Context (iT : Type) (F : iT -> Type).

  Fixpoint nth_error_get_hlist_nth (ls : list iT) (n : nat) {struct ls} :
    option {t : iT & hlist F ls -> F t} :=
    match
      ls as ls0
      return option {t : iT & hlist F ls0 -> F t}
    with
      | nil => None
      | l :: ls0 =>
        match
          n as n0
          return option {t : iT & hlist F (l :: ls0) -> F t}
        with
          | 0 =>
            Some (@existT _ (fun t => hlist F (l :: ls0) -> F t)
                          l (@hlist_hd _ _ _ _))
          | S n0 =>
            match nth_error_get_hlist_nth ls0 n0 with
              | Some (existT x f) =>
                Some (@existT _ (fun t => hlist F _ -> F t)
                              x (fun h : hlist F (l :: ls0) => f (hlist_tl h)))
              | None => None
            end
        end
    end.

  Theorem nth_error_get_hlist_nth_Some
  : forall ls n s,
      nth_error_get_hlist_nth ls n = Some s ->
      exists pf : nth_error ls n = Some (projT1 s),
        forall h, projT2 s h = match pf in _ = t
                                     return match t with
                                              | Some t => F t
                                              | None => unit
                                            end
                               with
                                 | eq_refl => hlist_nth h n
                               end.
  Proof.
    induction ls; simpl; intros; try congruence.
    { destruct n.
      { inv_all; subst; simpl.
        exists (eq_refl).
        intros. rewrite (hlist_eta h). reflexivity. }
      { forward. inv_all; subst.
        destruct (IHls _ _ H0); clear IHls.
        simpl in *. exists x0.
        intros.
        rewrite (hlist_eta h). simpl. auto. } }
  Qed.

  Theorem nth_error_get_hlist_nth_None
  : forall ls n,
      nth_error_get_hlist_nth ls n = None <->
      nth_error ls n = None.
  Proof.
    induction ls; simpl; intros; try congruence.
    { destruct n; intuition. }
    { destruct n; simpl; try solve [ intuition congruence ].
      { unfold value. intuition congruence. }
      { specialize (IHls n).
        forward. } }
  Qed.

  Lemma nth_error_get_hlist_nth_weaken
  : forall ls ls' n x,
      nth_error_get_hlist_nth ls n = Some x ->
      exists z,
        nth_error_get_hlist_nth (ls ++ ls') n =
        Some (@existT iT (fun t => hlist F (ls ++ ls') -> F t) (projT1 x) z)
        /\ forall h h', projT2 x h = z (hlist_app h h').
  Proof.
    intros ls ls'. revert ls.
    induction ls; simpl; intros; try congruence.
    { destruct n; inv_all; subst.
      { simpl. eexists; split; eauto.
        intros. rewrite (hlist_eta h). reflexivity. }
      { forward. inv_all; subst. simpl.
        apply IHls in H0. forward_reason.
        rewrite H. eexists; split; eauto.
        intros. rewrite (hlist_eta h). simpl in *.
        auto. } }
  Qed.

  Lemma nth_error_get_hlist_nth_appL
  : forall tvs' tvs n,
      n < length tvs ->
      exists x,
        nth_error_get_hlist_nth (tvs ++ tvs') n = Some x /\
        exists y,
          nth_error_get_hlist_nth tvs n = Some (@existT _ _ (projT1 x) y) /\
          forall vs vs',
            (projT2 x) (hlist_app vs vs') = y vs.
  Proof.
    clear. induction tvs; simpl; intros.
    { exfalso; inversion H. }
    { destruct n.
      { clear H IHtvs.
        eexists; split; eauto. eexists; split; eauto.
        simpl. intros. rewrite (hlist_eta vs). reflexivity. }
      { apply Lt.lt_S_n in H.
        { specialize (IHtvs _ H).
          forward_reason.
          rewrite H0. rewrite H1.
          forward. subst. simpl in *.
          eexists; split; eauto.
          eexists; split; eauto. simpl.
          intros. rewrite (hlist_eta vs). simpl. auto. } } }
  Qed.

  Lemma nth_error_get_hlist_nth_appR
  : forall tvs' tvs n x,
      n >= length tvs ->
      nth_error_get_hlist_nth (tvs ++ tvs') n = Some x ->
      exists y,
        nth_error_get_hlist_nth tvs' (n - length tvs) = Some (@existT _ _ (projT1 x) y) /\
        forall vs vs',
          (projT2 x) (hlist_app vs vs') = y vs'.
  Proof.
    clear. induction tvs; simpl; intros.
    { cutrewrite (n - 0 = n); [ | omega ].
      rewrite H0. destruct x. simpl.
      eexists; split; eauto. intros.
      rewrite (hlist_eta vs). reflexivity. }
    { destruct n.
      { inversion H. }
      { assert (n >= length tvs) by omega. clear H.
        { forward. inv_all; subst. simpl in *.
          specialize (IHtvs _ _ H1 H0).
          simpl in *.
          forward_reason.
          rewrite H.
          eexists; split; eauto.
          intros. rewrite (hlist_eta vs). simpl. auto. } } }
  Qed.


End nth_error_get_hlist_nth.

Arguments join_env {_ _} _.