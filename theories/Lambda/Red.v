Require Import Coq.Arith.Compare_dec.
Require Import ExtLib.Data.Option.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Data.ListNth.
Require Import ExtLib.Data.Eq.
Require Import ExtLib.Tactics.
Require Import MirrorCore.SymI.
Require Import MirrorCore.EnvI.
Require Import MirrorCore.TypesI.
Require Import MirrorCore.Lambda.Expr.
Require Import MirrorCore.Lambda.ExprLift.

Require Import FunctionalExtensionality.

Set Implicit Arguments.
Set Strict Implicit.

Section substitute.
  Context {typ : Type}.
  Context {sym : Type}.
  Context {RT : RType typ}
          {T2 : Typ2 _ PreFun.Fun}
          {RS : RSym sym}.

  Context {RTOk : RTypeOk}
          {T2Ok : Typ2Ok T2}
          {RSOk : RSymOk RS}.

  Context {ED_typ : EqDec _ (@eq typ)}.

  Section substitute_all.
    Variable lookup : var -> option (expr typ sym).

    Fixpoint remainder (a b : nat) : option nat :=
      match a , b with
        | 0 , S _ => None
        | a , 0 => Some a
        | S a , S b => remainder a b
      end.

    Theorem remainder_ok : forall a b c,
                             remainder a b = Some c ->
                             a >= b /\ a - b = c.
    Proof.
      clear.
      induction a; destruct b; simpl; intros; inv_all; subst; auto; try congruence.
      split; auto. omega.
      eapply IHa in H. intuition.
    Qed.

    Fixpoint substitute_all (under : nat) (e : expr typ sym) : expr typ sym :=
      match e with
        | Var v' =>
          match remainder v' under with
            | None => Var v'
            | Some v =>
              match lookup v with
                | None => Var v'
                | Some e =>
                  lift 0 under e
              end
          end
        | UVar u => UVar u
        | Inj i => Inj i
        | App l' r' => App (substitute_all under l') (substitute_all under r')
        | Abs t e => Abs t (substitute_all (S under) e)
      end.
  End substitute_all.

  Fixpoint substitute_one (v : var) (w : expr typ sym) (e : expr typ sym)
  : expr typ sym :=
    match e with
      | Var v' =>
        match nat_compare v v' with
          | Eq => w
          | Lt => Var (v' - 1)
          | Gt => Var v'
        end
      | UVar u => UVar u
      | Inj i => Inj i
      | App l' r' => App (substitute_one v w l') (substitute_one v w r')
      | Abs t e => Abs t (substitute_one (S v) (lift 0 1 w) e)
    end.

  Theorem substitute_one_typed
  : forall ts tus t e w tvs' tvs t',
      typeof_expr ts tus (tvs ++ tvs') w = Some t ->
      typeof_expr ts tus (tvs ++ t :: tvs') e = Some t' ->
      typeof_expr ts tus (tvs ++ tvs') (substitute_one (length tvs) w e) = Some t'.
  Proof.
    induction e; simpl; intros;
    forward; inv_all; subst; Cases.rewrite_all_goal; auto.
    { consider (nat_compare (length tvs) v).
      { intros. apply nat_compare_eq in H1.
        subst. rewrite nth_error_app_R in H0.
        replace (length tvs - length tvs) with 0 in H0 by omega.
        simpl in *. inversion H0. subst; auto.
        omega. }
      { intros. apply nat_compare_lt in H1.
        simpl.
        rewrite nth_error_app_R in H0 by omega.
        rewrite nth_error_app_R by omega.
        change (t :: tvs') with ((t :: nil) ++ tvs') in H0.
        rewrite nth_error_app_R in H0. 2: simpl; omega.
        simpl in *. rewrite <- H0. f_equal. omega. }
      { intros. apply nat_compare_gt in H1.
        simpl. rewrite nth_error_app_L in * by omega. assumption. } }
    { eapply (IHe (lift 0 1 w) tvs' (t0 :: tvs)) in H0; eauto.
      simpl in *. rewrite H0. reflexivity.
      simpl.
      generalize (typeof_expr_lift ts tus w nil (t0 :: nil) (tvs ++ tvs')).
      simpl.
      intro. rewrite H1. assumption. }
  Qed.

  Theorem substitute_one_sound
  : forall ts tus e tvs w e',
      substitute_one (length tvs) w e = e' ->
      forall tvs' (t t' : typ),
        match exprD' ts tus (tvs ++ tvs') t w
            , exprD' ts tus (tvs ++ t :: tvs') t' e
        with
          | Some wval , Some eval =>
            match exprD' ts tus (tvs ++ tvs') t' e' with
              | None => False
              | Some val' =>
                forall (us : hlist _ tus) (gs : hlist (typD ts) tvs) (gs' : hlist (typD ts) tvs'),
                  eval us (hlist_app gs (Hcons (wval us (hlist_app gs gs')) gs')) =
                  val' us (hlist_app gs gs')
            end
          | _ , _ => True
        end.
  Proof.
    induction e; simpl; intros; autorewrite with exprD_rw; simpl;
    forward; inv_all; subst.
    { simpl. consider (nat_compare (length tvs) v); intros.
      { apply nat_compare_eq in H. subst.
        eapply nth_error_get_hlist_nth_Some in H2.
        destruct H2. simpl in *.
        generalize x0.
        rewrite nth_error_app_R by omega.
        replace (length tvs - length tvs) with 0 by omega.
        simpl. inversion 1. subst. clear x1.
        destruct r. rewrite H0. intros.
        rewrite H. unfold Rcast_val, Rcast, Relim. simpl.
        rewrite hlist_nth_hlist_app; eauto.
        generalize (cast1 tvs (x :: tvs') (length tvs)).
        generalize (cast2 tvs (x :: tvs') (length tvs)).
        clear - ED_typ.
        rewrite x0.
        replace (length tvs - length tvs) with 0 by omega.
        simpl in *.
        generalize dependent (o us (hlist_app gs gs')).
        generalize dependent (hlist_nth gs (length tvs)).
        gen_refl.
        cutrewrite (nth_error tvs (length tvs) = None).
        { intros. generalize (e0 e). unfold value. uip_all'. reflexivity. }
        { rewrite nth_error_past_end; auto. } }
      { apply nat_compare_lt in H.
        autorewrite with exprD_rw; simpl.
        eapply nth_error_get_hlist_nth_appR in H2; simpl in *; [ | omega ].
        destruct H2.
        consider (v - length tvs).
        { intro. exfalso. omega. }
        { intros. assert (n = (v - 1) - length tvs) by omega; subst.
          forward.
          assert (v - 1 >= length tvs) by omega.

          eapply (@nth_error_get_hlist_nth_rwR _ (typD ts) tvs tvs') in H6.
          rewrite H4 in *. forward_reason.
          rewrite H6. subst. inv_all; subst. subst.
          destruct r. rewrite type_cast_refl; eauto.
          intros. f_equal. rewrite H8. apply H7. } }
      { apply nat_compare_gt in H.
        autorewrite with exprD_rw; simpl.
        assert (v < length tvs) by omega.
        generalize H1.
        eapply (@nth_error_get_hlist_nth_appL _ (typD ts) (t :: tvs')) in H1.
        intro.
        eapply (@nth_error_get_hlist_nth_appL _ (typD ts) tvs') in H4.
        forward_reason. Cases.rewrite_all_goal.
        destruct x0; simpl in *.
        rewrite H7 in H5. inv_all; subst. destruct r.
        repeat match goal with
                 | H : _ |- _ => eapply nth_error_get_hlist_nth_Some in H
               end; simpl in *; forward_reason.
        unfold Rcast_val, Rcast in *; simpl in *.
        consider (type_cast ts (projT1 x1) x).
        { intros. red in r. subst. simpl.
          rewrite H2; clear H2.
          rewrite H4; clear H4.
          clear - ED_typ H.
          rewrite hlist_nth_hlist_app; eauto. symmetry.
          rewrite hlist_nth_hlist_app; eauto.
          gen_refl.
          generalize dependent (hlist_nth gs v).
          generalize (hlist_nth gs' (v - length tvs)).
          generalize (hlist_nth (Hcons (o us (hlist_app gs gs')) gs')
                                (v - length tvs)).
          generalize (cast1 tvs (t :: tvs') v).
          generalize (cast2 tvs (t :: tvs') v).
          generalize (cast2 tvs tvs' v).
          generalize (cast1 tvs tvs' v).
          consider (nth_error tvs v).
          { intros. generalize (e t0 e3).
            generalize (e2 t0 e3). uip_all'.
            clear - ED_typ. assert (t0 = projT1 x1) by congruence. subst.
            uip_all'. reflexivity. }
          { intros.
            eapply nth_error_length_ge in H0. exfalso. omega. } }
        { intros. eapply type_cast_total in H7; eauto.
          apply H7. clear - x3 x5 H.
          rewrite nth_error_app_L in * by omega.
          rewrite x5 in x3. congruence. } } }
    { simpl. autorewrite with exprD_rw.
      unfold funcAs in *.
      generalize dependent (symD ts f).
      destruct (typeof_sym f).
      { intros.
        forward. destruct r.
        simpl in *. unfold Rcast in H1. simpl in *. inv_all; subst; auto. }
      { congruence. } }
    { autorewrite with exprD_rw. simpl.
      erewrite substitute_one_typed; eauto.
      { specialize (IHe2 tvs w _ eq_refl tvs' t t0).
        specialize (IHe1 tvs w _ eq_refl tvs' t (typ2 t0 t')).
        revert IHe1 IHe2.
        Cases.rewrite_all_goal. intros; forward.
        unfold Open_App, OpenT, ResType.OpenT.
        repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
        rewrite IHe1. rewrite IHe2. reflexivity. }
      { eapply exprD'_typeof_expr.
        left. eauto. } }
    { autorewrite with exprD_rw. simpl.
      destruct (typ2_match_case ts t').
      { destruct H as [ ? [ ? [ ? ? ] ] ].
        rewrite H in *; clear H.
        red in x1. subst. simpl in *.
        destruct (eq_sym (typ2_cast ts x x0)).
        forward. inv_all; subst.
        specialize (IHe (t :: tvs) (lift 0 1 w) _ eq_refl tvs' t0 x0).
        revert IHe. simpl.
        generalize (exprD'_lift ts tus w nil (t :: nil) (tvs ++ tvs') t0).
        simpl. Cases.rewrite_all_goal.
        intros. forward.
        eapply functional_extensionality. intros.
        unfold Rcast_val, Rcast; simpl.
        inv_all; subst.
        specialize (IHe us (Hcons x1 gs)). simpl in *.
        specialize (H3 us Hnil). simpl in *.
        erewrite H3. instantiate (1 := Hcons x1 Hnil).
        eapply IHe. }
      { rewrite H in *. congruence. } }
    { autorewrite with exprD_rw. simpl.
      rewrite H2. rewrite H3. auto. }
  Qed.

End substitute.

Section beta.
  Context {typ : Type}.
  Context {sym : Type}.
  Context {RT : RType typ}
          {T2 : Typ2 _ PreFun.Fun}
          {RS : RSym sym}
          {TD : EqDec _ (@eq typ)}.

  Context {RTOk : RTypeOk}
          {T2Ok : Typ2Ok T2}
          {RSOk : RSymOk RS}.

  (** This only beta-reduces the head term, i.e.
   ** (\ x . x) F ~> F
   ** F ((\ x . x) G) ~> F ((\ x . x) G)
   **)
  Fixpoint beta (e : expr typ sym) : expr typ sym :=
    match e with
      | App (Abs t e') e'' =>
        substitute_one 0 e'' e'
      | App a x =>
        App (beta a) x
      | e => e
    end.

  Theorem beta_sound
  : forall ts tus tvs e t,
      match exprD' ts tus tvs t e with
        | None => True
        | Some val =>
          match exprD' ts tus tvs t (beta e) with
            | None => False
            | Some val' =>
              forall us vs, val us vs = val' us vs
          end
      end.
  Proof.
    intros ts tus tvs e t.
    match goal with
      | |- ?G =>
        cut (exprD' ts tus tvs t e = exprD' ts tus tvs t e /\ G);
          [ intuition | ]
    end.
    revert tvs e t.
    refine (@ExprFacts.exprD'_ind _ _ _ _ _ _ _ _
                                      (fun ts tus tvs e t val =>
                                         exprD' ts tus tvs t e = val /\
                                      match val with
                                        | Some val =>
                                          match exprD' ts tus tvs t (beta e) with
                                            | Some val' =>
                                              forall (us : hlist (typD ts) tus) (vs : hlist (typD ts) tvs),
                                                val us vs = val' us vs
                                            | None => False
                                          end
                                        | None => True
                                      end) _ _ _ _ _ _ _ _).
    { auto. }
    { simpl; intros; autorewrite with exprD_rw; Cases.rewrite_all_goal; simpl.
      rewrite type_cast_refl; eauto. }
    { simpl; intros; autorewrite with exprD_rw; Cases.rewrite_all_goal; simpl.
      rewrite type_cast_refl; eauto. }
    { simpl; intros; autorewrite with exprD_rw; Cases.rewrite_all_goal; simpl.
      unfold funcAs. generalize (symD ts i).
      Cases.rewrite_all_goal.
      rewrite type_cast_refl; eauto. simpl. auto. }
    { simpl. destruct f;
      simpl; intros; forward_reason;
      autorewrite with exprD_rw; Cases.rewrite_all_goal; simpl;
      forward; inv_all; subst.
      { split; auto. unfold Open_App.
        intros.
        unfold OpenT, ResType.OpenT.
        repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
        rewrite H5. reflexivity. }
      { split; auto.
        clear H5. unfold Open_App.
        repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
        generalize (@substitute_one_sound _ _ _ _ _ _ _ _ _ ts tus f nil x _ eq_refl tvs d r).
        autorewrite with exprD_rw in H0. simpl in H0.
        rewrite typ2_match_zeta in H0; eauto.
        rewrite eq_option_eq in H0.
        forward. inv_all; subst.
        simpl in *. destruct r0.
        rewrite H1 in H5. rewrite H6 in H5.
        forward.
        unfold OpenT, ResType.OpenT, Rcast_val, Rcast, Relim.
        repeat first [ rewrite eq_Const_eq | rewrite eq_Arr_eq ].
        simpl. specialize (H5 us Hnil vs).
        simpl in *. etransitivity; [ | eassumption ].
        rewrite match_eq_sym_eq'.
        reflexivity. } }
    { intros. forward_reason.
      forward. simpl.
      cutrewrite (exprD' ts tus tvs (typ2 d r) (Abs d e) = Some (Open_Abs fval)); auto.
      autorewrite with exprD_rw.
      rewrite typ2_match_zeta; auto.
      rewrite type_cast_refl; auto. simpl.
      rewrite H. unfold Open_Abs.
      rewrite eq_Arr_eq. rewrite eq_Const_eq.
      rewrite eq_option_eq. reflexivity. }
  Qed.

End beta.