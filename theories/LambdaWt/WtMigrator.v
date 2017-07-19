Require Import Coq.Lists.List.
Require Import ExtLib.Structures.Applicative.
Require Import ExtLib.Data.Member.
Require Import ExtLib.Data.HList.
Require Import ExtLib.Tactics.
Require Import MirrorCore.Util.DepUtil.
Require Import MirrorCore.LambdaWt.WtType.
Require Import MirrorCore.LambdaWt.WtExpr.

Set Implicit Arguments.
Set Strict Implicit.

(* This is the universe of the reified language *)
Universe Urefl.

Section simple_dep_types.
  Variable Tsymbol : Type.
  Variable TsymbolD : Tsymbol -> Type@{Urefl}.

  Variable Esymbol : type Tsymbol -> Type.
  Variable EsymbolD : forall t, Esymbol t -> typeD TsymbolD t.

  (** Instantiation **)
  Definition migrator (tus tus' : list (Tuvar Tsymbol)) : Type :=
    hlist (fun tst => wtexpr Esymbol tus' (fst tst) (snd tst)) tus.

  Definition migrator_tl
  : forall {a b c} (mig : migrator (b :: c) a),
      migrator c a := fun _ => @hlist_tl _ _.

  Section class.
    Variable T : list (Tuvar Tsymbol) -> list (type Tsymbol) -> Type.
    Class Migrate : Type :=
    { migrate : forall {tus tus'}, migrator tus tus' ->
                                   forall tvs, T tus tvs -> T tus'  tvs }.
  End class.

  Definition migrate_env {tus tus'}
             (mig : migrator tus' tus) (e : Uenv TsymbolD tus)
  : Uenv TsymbolD tus' := Eval cbv beta in
    hlist_map (fun _ val => wtexprD EsymbolD val e) mig.

  Section migrate_expr.
    Context {tus tus'} (mig : migrator tus tus').

    Fixpoint migrate_expr {tvs t}
             (e : wtexpr Esymbol tus tvs t)
    : wtexpr Esymbol tus' tvs t :=
      match e in wtexpr _ _ _ t
            return wtexpr _ tus' tvs t
      with
      | wtVar v => wtVar v
      | wtInj v => wtInj v
      | wtApp f x => wtApp (migrate_expr f) (migrate_expr x)
      | wtAbs e => wtAbs (migrate_expr e)
      | wtUVar u vs => subst (hlist_map (@migrate_expr tvs) vs) (hlist_get u mig)
      end.
  End migrate_expr.

  Global Instance Migrate_wtexpr t
  : Migrate (fun tus tvs => wtexpr Esymbol tus tvs t) :=
  { migrate := fun tus tus' mig tvs => @migrate_expr _ _ mig _ t }.

  Definition migrator_compose {tus tus' tus''}
           (mig : migrator tus tus')
           (mig' : migrator tus' tus'')
  : migrator tus tus'' :=
    hlist_map (fun t e => migrate_expr mig' e) mig.



  Lemma wtexpr_lift_migrate_expr'
  : forall (tus' tus'' : list (Tuvar Tsymbol)) (mig' : migrator tus' tus'')
           (d tvs0 d' : list (type Tsymbol))
           (x : type Tsymbol) (e : wtexpr Esymbol tus' (d' ++ tvs0) x),
      wtexpr_lift d d' (migrate_expr mig' e) =
      migrate_expr mig' (wtexpr_lift d d' e).
  Proof using.
    do 5 intro.
    eapply wtexpr_ind_app; simpl; intros; eauto.
    { rewrite H. rewrite H0. reflexivity. }
    { rewrite H. reflexivity. }
    { generalize (hlist_get u mig'); simpl; intros.
      rewrite hlist_map_hlist_map.

      SearchAbout wtexpr_lift.
      admit. }
  Admitted.


  Lemma wtexpr_lift_migrate_expr
  : forall (tus' tus'' : list (Tuvar Tsymbol)) (mig' : migrator tus' tus'')
           (d tvs0 d' : list (type Tsymbol))
           (x : type Tsymbol) (t : wtexpr Esymbol tus' (d' ++ tvs0) x),
      wtexpr_lift d d' (migrate_expr mig' t) =
      migrate_expr mig' (wtexpr_lift d d' t).
  Proof using.
    do 5 intro.
    eapply wtexpr_ind_app; simpl; intros; eauto.
    { rewrite H. rewrite H0. reflexivity. }
    { rewrite H. reflexivity. }
    { (** TODO(gmalecha): Here I need to have some information about the result
       ** of looking up any unification variable in mig'. In particular, I need
       ** to know that subst commutes with wtexpr_lift.
       ** If tus'' is smaller than tus', then i can do induction on the number
       ** of unification variables, but if not, then I'm in trouble.
       ** An alternative could be induction on the number of instantiations since
       ** I know that these variables do not exist in the result, but I guess that
       ** is not captured in the above types. In particular, I need a acyclic
       ** property to justify structural recursion.
       **)

 generalize (hlist_get u mig'); simpl; intros.
      rewrite hlist_map_hlist_map.

          Lemma member_lift_nil:
            forall (T : Type) (tvs' tvs : list T) (t : T) (m : member t (tvs ++ tvs')),
              member_lift tvs' nil tvs m = m.
          Proof.
            clear.
            induction tvs; simpl.
            { reflexivity. }
            { intros. destruct (member_case m) as [ [ ? ? ] | [ ? ? ] ].
              { subst. reflexivity. }
              { subst. f_equal; auto. } }
          Defined.
          Lemma wtexpr_lift_nil:
            forall (tus : list (Tuvar Tsymbol)) (tvs' ts : list (type Tsymbol))
                   (x : type Tsymbol) (t : wtexpr Esymbol tus (ts ++ tvs') x),
              @wtexpr_lift _ _ tus tvs' x nil ts t = t.
          Proof.
            do 2 intro.
            refine (@wtexpr_ind_app _ _ _ _ _ _ _ _ _ _); simpl; intros; eauto.
            { f_equal.
              apply member_lift_nil. }
            { f_equal; assumption. }
            { f_equal; auto. }
            { f_equal. clear - H.
              induction H; simpl; auto.
              f_equal; auto. }
          Defined.


      Check wtexpr_lift.
      Lemma wtexpr_lift_subst:
        forall (tus : list (Tuvar Tsymbol))
          (tvs tvs' tvs'' ts : list (type Tsymbol)) (t : type Tsymbol)
          (w : wtexpr Esymbol tus (ts ++ tvs) t)
          (xs : hlist (wtexpr Esymbol tus (ts ++ tvs')) (ts ++ tvs)),
          @wtexpr_lift _ _ tus _ t _ _ (subst xs w) =
          subst
            (hlist_map
               (fun (t : type Tsymbol) (e : wtexpr Esymbol tus _ t) =>
                  @wtexpr_lift _ _ tus _ t tvs'' _ e) xs) w.
      Proof.
        do 4 intro.
        refine (@wtexpr_ind_app _ _ _ _ _ _ _ _ _ _); simpl; intros; eauto.
        { rewrite hlist_get_hlist_map. reflexivity. }
        { f_equal; eauto. }
        { f_equal. rewrite hlist_map_hlist_map.
          specialize (fun xs => H (Hcons (wtVar (MZ d (tvs0 ++ tvs'))) xs)).
          simpl in H. rewrite H. f_equal. f_equal.
          rewrite hlist_map_hlist_map. eapply hlist_map_ext. intros.
          clear.
          Check (wtexpr_lift (d :: nil) nil t).
          Check (wtexpr_lift tvs'' tvs0 t).
           Print subst.


          revert t. revert x. revert tvs0.
          refine (@wtexpr_ind_app _ _ _ _ _ _ _ _ _ _); simpl; intros; try f_equal; eauto.
          { SearchAbout wtexpr_lift.


          Lemma wtexpr_lift_wtexpr_lift:
            forall (tus : list (Tuvar Tsymbol)) (tvs' tvs'' tvs0 : list (type Tsymbol))
                   d (x : type Tsymbol) (t : wtexpr Esymbol tus (tvs0 ++ tvs') x),
              wtexpr_lift tvs'' (d :: tvs0) (wtexpr_lift (d :: nil) nil t) =
              wtexpr_lift (d :: nil) nil (wtexpr_lift tvs'' tvs0 t).
          Proof.

            intros.
            Set Printing Implicit.
            Print wtexpr_lift.
            Check wtexpr_lift tvs'' (d :: tvs0) (wtexpr_lift (d :: nil) nil t).
            Check wtexpr_lift (d :: nil) nil (wtexpr_lift tvs'' tvs0 t).




      Print migrate_expr.
      SearchAbout subst wtexpr_lift.
      admit. }
  Admitted.

  Lemma subst_subst'
  : forall tus tvs' tvs'' tvs Z t (e : wtexpr Esymbol tus (Z ++ tvs) t)
           (X : hlist (fun t => wtexpr Esymbol tus (Z ++ tvs'') t) tvs')
           (Y : hlist (fun t => wtexpr Esymbol tus (Z ++ tvs') t) tvs)
           P Q,
      subst (hlist_app Q X) (subst (hlist_app P Y) e) =
      subst (hlist_map (fun t e => subst (hlist_app Q X) e) (hlist_app P Y)) e.
  Proof using.
    clear.
    do 7 intro.
    eapply wtexpr_ind_app with (tus:=tus) (tvs:=tvs) (e:=e);
      try solve [ simpl; intros; auto ].
    { simpl; intros. rewrite hlist_get_hlist_map. reflexivity. }
    { simpl; intros; rewrite <- H. rewrite <- H0. reflexivity. }
    { intros.
      simpl.
      specialize (H (hlist_map (fun t e => wtexpr_lift (d::nil) nil e) X)
                    (hlist_map (fun t e => wtexpr_lift (d::nil) nil e) Y)
                    (Hcons (wtVar (MZ d _))
                           (hlist_map (fun t e => wtexpr_lift (d::nil) nil e) P))
                    (Hcons (wtVar (MZ d _))
                           (hlist_map (fun t e => wtexpr_lift (d::nil) nil e) Q))).
      simpl in H.
      f_equal.
      repeat rewrite hlist_app_hlist_map in H.
      repeat rewrite hlist_app_hlist_map.
      etransitivity; [ eapply H | clear H ].
      f_equal. f_equal.
      f_equal.
      { repeat rewrite hlist_map_hlist_map.
        eapply hlist_map_ext. intros.
        SearchAbout subst wtexpr_lift.


        admit. }
      admit. }
  Admitted.

  Lemma migrate_expr_migrator_compose
  : forall tus tus' tus'' tvs t
           (mig : migrator tus tus') (mig' : migrator tus' tus'')
           (e : wtexpr Esymbol _ tvs t),
      migrate_expr (migrator_compose mig mig') e =
      migrate_expr mig' (migrate_expr mig e).
  Proof.
    induction e; simpl; auto.
    { rewrite IHe1. rewrite IHe2. reflexivity. }
    { rewrite IHe. reflexivity. }
    { unfold migrator_compose at 2.
      rewrite hlist_get_hlist_map.
      transitivity (subst
                      (hlist_map (fun t e => migrate_expr mig' e) (hlist_map (@migrate_expr _ _ mig _) xs))
                      (migrate_expr mig' (hlist_get u mig))).
      { f_equal. clear - H.
        induction H; simpl; auto.
        { rewrite H. rewrite IHhlist_Forall. reflexivity. } }
      { clear H.
        generalize (hlist_map (@migrate_expr tus tus' mig tvs) xs).
        clear. generalize dependent tvs.
        generalize (hlist_get u mig).
        simpl; clear.
        (** LEMMA **)
        induction w; intros; simpl; auto.
        { repeat rewrite hlist_get_hlist_map.
          reflexivity. }
        { rewrite IHw1. rewrite IHw2. reflexivity. }
        { specialize (fun h => IHw (d::tvs0) (@Hcons _ _ _ _ (wtVar (MZ d tvs0)) h)).
          specialize (IHw (hlist_map (fun t e => wtexpr_lift (d::nil) nil e) h)).
          simpl in IHw.
          revert IHw.
          match goal with
          | |- _ = ?X -> _ = wtAbs ?Y =>
            change X with Y; generalize Y
          end; intros; subst.
          repeat rewrite hlist_map_hlist_map.
          f_equal.
          f_equal. f_equal.
          eapply hlist_map_ext.
          intros. rewrite wtexpr_lift_migrate_expr. reflexivity. }
        { rewrite hlist_map_hlist_map.
          intros.
          admit. }
  Admitted.

  Theorem migrate_env_migrate_expr
  : forall tus tus' tvs t (mig : migrator tus tus')
           (e : wtexpr Esymbol tus tvs t),
      forall us vs,
        wtexprD EsymbolD (migrate_expr mig e) us vs =
        wtexprD EsymbolD e (migrate_env mig us) vs.
  Proof.
    induction e.
    { simpl. unfold Var_exprT. reflexivity. }
    { simpl. unfold Pure_exprT. reflexivity. }
    { simpl. unfold Ap_exprT. intros.
      rewrite IHe1. rewrite IHe2. reflexivity. }
    { simpl. unfold Abs_exprT. intros.
      eapply FunctionalExtensionality.functional_extensionality.
      intros. eapply IHe. }
    { simpl. intros. unfold UVar_exprT.
      unfold migrate_env at 1.
      rewrite hlist_get_hlist_map.
      generalize (hlist_get u mig); simpl.
      rewrite hlist_map_hlist_map.
      intros. rewrite wtexprD_subst.
      rewrite hlist_map_hlist_map.
      f_equal.
      clear - H.
      induction H; simpl.
      - reflexivity.
      - f_equal; eauto. }
  Qed.

  Section mid.
    Variable T : Tuvar Tsymbol -> Type.

    Local Fixpoint migrator_id' (tus : list (Tuvar Tsymbol)) {struct tus}
    : (forall ts t, member (ts,t) tus -> T (ts,t)) ->
      hlist T tus :=
      match tus as tus
            return (forall ts t, member (ts,t) tus -> T (ts,t)) ->
                   hlist T tus
      with
      | nil => fun _ => Hnil
      | (ts,t) :: tus => fun mk =>
                           Hcons (@mk _ _ (@MZ _ _ _))
                                 (migrator_id' (fun ts t z => @mk ts t (MN _ z)))
      end.
  End mid.

  Local Fixpoint vars_id {tus} tvs
  : hlist (wtexpr Esymbol tus tvs) tvs :=
    match tvs as tvs
          return hlist (wtexpr Esymbol tus tvs) tvs
    with
    | nil => Hnil
    | t :: ts =>
      Hcons (wtVar (MZ t ts))
            (hlist_map
               (fun t' : type Tsymbol => wtexpr_lift (t :: nil) nil)
               (vars_id ts))
    end.

  Definition migrator_id tus : migrator tus tus :=
    @migrator_id' _ tus (fun ts t x => wtUVar x (vars_id ts)).
  Arguments migrator_id {tus} : rename.

  Lemma hlist_get_migrator_id'
  : forall T ts t tus mk (m : member (ts,t) tus),
      hlist_get m (@migrator_id' T tus mk) = mk _ _ m.
  Proof.
    induction m; simpl; auto.
    destruct l. simpl. rewrite IHm. reflexivity.
  Qed.

  Lemma hlist_get_migrator_id
  : forall ts t tus (m : member (ts,t) tus),
      hlist_get m (migrator_id (tus:=tus)) = wtUVar m (vars_id _).
  Proof.
    intros. unfold migrator_id.
    rewrite hlist_get_migrator_id'. reflexivity.
  Qed.

  Theorem migrate_expr_migrator_id
  : forall tus tvs t (e : wtexpr _ tus tvs t),
      migrate_expr migrator_id e = e.
  Proof.
    induction e; simpl; intros; auto.
    { rewrite IHe1. rewrite IHe2. reflexivity. }
    { rewrite IHe. reflexivity. }
    { rewrite hlist_get_migrator_id. simpl.
      f_equal.
      clear - H.
      induction H; simpl; auto.
      f_equal; eauto.
      etransitivity; [ | eassumption ].
      rewrite hlist_map_hlist_map.
      eapply hlist_map_ext.
      intros.
      rewrite <- IHhlist_Forall.
      rewrite hlist_map_hlist_map.
      eapply (fun Z => @subst_wtexpr_lift _ _ tus nil _ _ t0 (t :: nil) _
                                          Hnil (Hcons Z Hnil)). }
  Qed.

  Lemma hlist_map_vars_id_id
  : forall (p : _) (x : Venv TsymbolD p)
           (l : list (Tuvar Tsymbol))
           (h : hlist
                  (fun tst : Tuvar Tsymbol =>
                     hlist (typeD TsymbolD) (fst tst) ->
                     typeD TsymbolD (snd tst)) l),
      hlist_map
        (fun (x0 : type Tsymbol) (x1 : wtexpr Esymbol l p x0) =>
           wtexprD EsymbolD x1 h x) (vars_id p) = x.
  Proof.
    induction x; simpl; auto.
    { intros. f_equal. rewrite hlist_map_hlist_map.
      etransitivity; [ | eapply IHx ].
      eapply hlist_map_ext.
      intros.
      erewrite wtexprD_wtexpr_lift
      with (vs'':=Hnil) (vs':=Hcons f Hnil) (vs:=x).
      reflexivity. }
  Qed.

  (** TODO(gmalecha): Move to ExtLib.Data.HList *)
  Lemma hlist_ext : forall T (F : T -> Type) (ls : list T)
                           (a b : hlist F ls),
      (forall t (m : member t ls), hlist_get m a = hlist_get m b) ->
      a = b.
  Proof using.
    clear.
    induction a; intros.
    { rewrite (hlist_eta b). reflexivity. }
    { rewrite (hlist_eta b).
      f_equal.
      { eapply (H _ (MZ _ _)). }
      { eapply IHa.
        intros. eapply (H _ (MN _ _)). } }
  Defined.

  Lemma migrate_env_migrator_id
  : forall tus (e : Uenv TsymbolD tus),
      migrate_env migrator_id e = e.
  Proof using.
    intros.
    eapply hlist_ext; intros.
    unfold migrate_env.
    rewrite hlist_get_hlist_map.
    destruct t.
    rewrite hlist_get_migrator_id with (m:=m).
    simpl. unfold UVar_exprT.
    eapply FunctionalExtensionality.functional_extensionality; intros.
    rewrite hlist_map_hlist_map.
    rewrite hlist_map_vars_id_id.
    reflexivity.
  Qed.

  Definition migrator_fresh t tus
  : migrator tus (tus ++ t :: nil) :=
    Eval simpl in
    migrator_id'
      (fun tst : Tuvar Tsymbol =>
         wtexpr Esymbol (tus ++ t :: nil) (fst tst) (snd tst))
      (fun (ts : list (type Tsymbol)) (t0 : type Tsymbol)
           (X : member (ts, t0) tus) =>
         wtUVar
           (member_lift nil (t :: nil) tus
                        (match eq_sym (app_nil_r_trans tus) in _ = X
                               return member _ X
                         with
                         | eq_refl => X
                         end)) (vars_id _)).

End simple_dep_types.

Arguments migrator {_} _ _ _.
Arguments migrator_id {_ _ tus}.
Arguments migrator_fresh {_ _} _ _.