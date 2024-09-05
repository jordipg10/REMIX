!!> Performs Newton method for Euler fully implicit in rk
!
!!! Computes concentration of variable activity species in target j at time step k+1
!
!!! Newton function: \f$ fk(c1_j^(k+1))=U*c_j^(k+1)-u_tilde_j^k-Delta_t*U*S_k,nc^T*r_k(c_j^(k+1))/phi_j \f$
!
!subroutine Newton_EfI_rk_eq_kin_aq(this,mixing_ratios,porosity,Delta_t,mixing_waters,niter,CV_flag)
!    use aqueous_chemistry_Lagr_m
!    use metodos_sist_lin_m
!    use vectors_m
!    implicit none
!    class(aqueous_chemistry_c) :: this
!    !integer(kind=4), intent(in) :: ind                              !> index of object "this" in mixing ratios array
!    real(kind=8), intent(in) :: mixing_ratios(:)
!    real(kind=8), intent(in) :: porosity !> phi_j
!    real(kind=8), intent(in) :: Delta_t !> time step
!    class(aqueous_chemistry_c), intent(in) :: mixing_waters(:)
!    integer(kind=4), intent(out) :: niter !> number of iterations
!    logical, intent(out) :: CV_flag !> FALSE: no CV, TRUE: CV
!            
!    real(kind=8), allocatable :: c1(:),c2(:),c2nc(:),c2nc_init(:),c1_new(:),drk_dc(:,:),rk(:),fk(:),dfk_dc1(:,:),dfk_dc(:,:),u_tilde(:),Delta_c1(:),Delta_c(:),conc_kin(:),gamma_1(:),gamma_2(:),conc_Sk(:),c_tilde(:),conc(:)
!    integer(kind=4) :: i,n_p,n_nc,err,rk_ind,l,niter_spec
!    integer(kind=4), allocatable :: kin_ind(:)
!    real(kind=8) :: eta_old,eta_new !> eta=inf_norm(dfk_dc1)*inf_norm(Delta_c1)
!    
!    niter=0
!    CV_flag=.false.
!    n_p=this%speciation_alg%num_prim_species
!    n_nc=this%speciation_alg%num_var_act_species
!
!    allocate(dfk_dc1(n_p,n_p),Delta_c1(n_p),drk_dc(this%chem_syst%num_kin_reacts,n_nc))
!    !eta_old=0d0
!    u_tilde=this%compute_u_tilde_aq_chem(mixing_ratios,mixing_waters)
!    do 
!        niter=niter+1 !> we update number of iterations
!        if (niter>this%CV_params%niter_max) then
!            print *, "Too many Newton iterations"
!            exit
!        end if
!        call this%compute_c2nc_from_c1_aq_Picard(niter_spec,CV_flag) !> computes concentration of secondary non constant activity species from concentration of primary species using mass action law
!        call this%compute_rk_Jac_rk_anal(drk_dc) !> we compute kinetic reaction rate and Jacobian
!        !call this%compute_rk_Jac_rk_incr_coeff(drk_dc) !> we compute kinetic reaction rate and Jacobian
!        !print *, this%rk
!        !print *, drk_dc
!        fk=matmul(this%speciation_alg%comp_mat,this%concentrations(1:n_nc))-u_tilde-(Delta_t/porosity)*matmul(this%U_SkT_prod,this%rk) !> Newton residual
!        if (inf_norm_vec_real(fk)<this%CV_params%abs_tol) then !> CV reached
!            CV_flag=.true.
!            exit
!        else
!            call this%compute_dfk_dc1_aq_EfI(drk_dc,porosity,Delta_t,dfk_dc1) !> computes Jacobian of Newton function
!            call LU_lin_syst(dfk_dc1,-fk,this%CV_params%zero,Delta_c1) !> solves linear system dfk_dc1*Delta_c1=-fk
!            !c1_new=c1_old+Delta_c1
!            if (inf_norm_vec_real(Delta_c1/this%concentrations(1:n_p))<this%CV_params%rel_tol) then !> arbitrary
!                print *, "Newton solution not accurate enough"
!                exit
!            else
!                call this%update_conc_aq_prim_species(Delta_c1) !> updates c1 and Delta_c1
!                !eta_new=norm_mat_inf(dfk_dc1)*inf_norm_vec_real(Delta_c1)
!                !if (niter>this%CV_params%niter_max/2 .and. eta_new>=eta_old) then
!                !    print *, "Newton no CV in reactive mixing iteration"
!                !    exit
!                !else
!                !    eta_old=eta_new
!                !end if
!            end if
!        end if
!    end do
!    call this%compute_pH()
!    call this%compute_salinity()
!    call this%compute_alkalinity()
!end subroutine