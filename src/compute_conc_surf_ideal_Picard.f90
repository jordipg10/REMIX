!> Computes concentration of secondary species from concentration of primary species explicitly using mass action law
!! We assume ideal activity coefficients of aqueous species
subroutine compute_conc_surf_ideal_Picard(this,conc_cats,act_ads_cats_ig,niter,CV_flag)
    use solid_chemistry_m, only: solid_chemistry_c, inf_norm_vec_real, LU_lin_syst
    implicit none
    class(solid_chemistry_c) :: this
    real(kind=8), intent(in) :: conc_cats(:) !> chapuza (dim=n� cation exchange half reactions)
    real(kind=8), intent(in) :: act_ads_cats_ig(:) !> surface complex concentrations (must be already allocated)
    integer(kind=4), intent(out) :: niter !> number of iterations
    logical, intent(out) :: CV_flag !> TRUE if converges, FALSE otherwise
    
    integer(kind=4) :: n_ads_cats,n_eq,n_sec_aq,n_nc_aq,i,j
    real(kind=8), allocatable :: act_ads_cats_old(:),log_act_ads_cats_new(:),act_ads_cats_new(:)
!> Pre-processing
    !n_p_aq=this%reactive_zone%speciation_alg%num_aq_prim_species
    n_eq=this%reactive_zone%speciation_alg%num_eq_reactions
    n_ads_cats=this%reactive_zone%cat_exch_zone%num_exch_cats
    !allocate(Delta_act_ads_cats(n_ads_cats),residual(n_ads_cats),Jacobian(n_ads_cats,n_ads_cats))
    allocate(log_act_ads_cats_new(n_ads_cats))
!!> Process
!    act_ads_cats=act_ads_cats_ig
!    niter=0
!    CV_flag=.false.
!    do !> Newton loop
!        niter=niter+1 !> we update number of iterations
!        if (niter>this%reactive_zone%CV_params%niter_max) then
!            print *, "Residual: ", inf_norm_vec_real(residual)
!            print *, "Too many Newton iterations in compute_conc_surf_ideal_Newton"
!            error stop
!        end if
!        do i=1,n_ads_cats
!            residual(i)=act_ads_cats(i)/(conc_cats(i)*(1d0-SUM(act_ads_cats))) - this%reactive_zone%eq_reactions(n_eq-n_ads_cats+i)%eq_cst
!            do j=1,n_ads_cats
!                Jacobian(i,j)=act_ads_cats(i)/(conc_cats(i)*(1d0-SUM(act_ads_cats))**2)
!            end do
!            Jacobian(i,i)=(1d0-SUM(act_ads_cats)+act_ads_cats(i))/(conc_cats(i)*(1d0-SUM(act_ads_cats))**2)
!        end do
!        if (inf_norm_vec_real(residual)<this%reactive_zone%CV_params%abs_tol) then !> CV reached
!            CV_flag=.true.
!            exit
!        else
!        !> We solve linear system
!            call LU_lin_syst(Jacobian,-residual,this%reactive_zone%CV_params%zero,Delta_act_ads_cats)
!            if (inf_norm_vec_real(Delta_act_ads_cats/act_ads_cats)<this%reactive_zone%CV_params%abs_tol**2) then !> chapuza
!                print *, "Relative error: ", inf_norm_vec_real(Delta_act_ads_cats/act_ads_cats)
!                print *, "Newton speciation not accurate enough in compute_conc_surf_ideal_Newton" 
!                exit
!            else
!                call this%update_conc_ads_cats(act_ads_cats,Delta_act_ads_cats)
!            end if
!        end if
!    end do
!> Process
    act_ads_cats_old=act_ads_cats_ig
    niter=0
    CV_flag=.false.
    do !> Picard loop
        niter=niter+1 !> we update number of iterations
        if (niter>this%reactive_zone%CV_params%niter_max) then
            print *, "Relative error: ", inf_norm_vec_real(act_ads_cats_new-act_ads_cats_old/act_ads_cats_old)
            error stop "Too many Picard iterations in compute_conc_surf_ideal_Picard"
        end if
        do i=1,n_ads_cats
            log_act_ads_cats_new(i)=log(this%reactive_zone%chem_syst%eq_reacts(&
                this%reactive_zone%ind_eq_reacts(n_eq-n_ads_cats+i))%eq_cst)+LOG(conc_cats(i))+&
                LOG(1d0-SUM(act_ads_cats_old))
        end do
        act_ads_cats_new=EXP(log_act_ads_cats_new)
        if (SUM(act_ads_cats_new)>=1d0) then
            error stop "Sum of surface complex activities greater than 1 in compute_conc_surf_ideal_Picard"
        end if
        if (inf_norm_vec_real(act_ads_cats_new-act_ads_cats_old/act_ads_cats_old)<this%reactive_zone%CV_params%rel_tol) then
            CV_flag=.true.
            exit
        else
            act_ads_cats_old=act_ads_cats_new
        end if
    end do
!> Post-processing
    call this%set_act_surf_compl(act_ads_cats_new)
    call this%compute_conc_ads_cats()
 end subroutine