!> Computes variable activity species concentrations from component concentrations using Newton method
!! We assume primary species are aqueous & solid
!! We assume the initial guess for the primary concentrations is already set in the aqueous & solid chemistry objects
subroutine compute_c_nc_from_u_Newton(this,c2nc_ig,conc_comp,conc_nc,niter,CV_flag)
    use metodos_sist_lin_m
    use aqueous_chemistry_m
    use vectors_m, only : inf_norm_vec_real
    implicit none
!> Arguments
    class(aqueous_chemistry_c) :: this
    real(kind=8), intent(in) :: c2nc_ig(:) !> initial guess secondary variable activity concentrations
    real(kind=8), intent(in) :: conc_comp(:) !> component concentrations
    real(kind=8), intent(out) :: conc_nc(:) !> variable activity concentrations (already allocated)
    integer(kind=4), intent(out) :: niter !> number of iterations
    logical, intent(out) :: CV_flag !> TRUE if converges, FALSE otherwise
!> Variables
    real(kind=8), allocatable :: c1(:),c2nc_old(:),c2nc_new(:),c2k(:),log_c2k(:),log_c2(:), dc2nc_dc1(:,:)
    real(kind=8), allocatable :: residual(:) !> c1+U2*c2nc-u
    real(kind=8), allocatable :: Delta_c1(:) !> c1^(i+1)-c1^i (Newton)
    real(kind=8), allocatable :: mat_lin_syst(:,:)
    real(kind=8), allocatable :: out_prod(:,:),out_prod_aq(:,:),d_log_gamma_d_I(:),log_Jacobian_act_coeffs(:,:),log_Jacobian_act_coeffs_aq(:,:)
    integer(kind=4) :: i,n_e,n_p,n_p_aq,niter_Picard,n_nc,n_nc_aq
    logical :: CV_flag_Picard
    
!> Pre-Process
    CV_flag=.false.
    n_e=this%speciation_alg%num_eq_reactions
    n_p=this%speciation_alg%num_prim_species
    n_p_aq=this%speciation_alg%num_aq_prim_species
    n_nc_aq=this%speciation_alg%num_aq_var_act_species
    n_nc=this%speciation_alg%num_var_act_species
        
    allocate(c2nc_new(n_e),residual(n_p),dc2nc_dc1(n_e,n_p),Delta_c1(n_p),d_log_gamma_d_I(n_nc),out_prod_aq(n_nc_aq,n_nc_aq),log_Jacobian_act_coeffs_aq(n_nc_aq,n_nc_aq),log_Jacobian_act_coeffs(n_nc,n_nc))
    niter=0
    log_Jacobian_act_coeffs=0d0 !> chapuza
    d_log_gamma_d_I=0d0 !> chapuza
    conc_nc(1:n_p_aq)=this%concentrations(1:n_p_aq) !> chapuza
    conc_nc(n_p)=this%solid_chemistry%concentrations(this%solid_chemistry%reactive_zone%num_minerals+1) !> chapuza
    c2nc_old=c2nc_ig !> chapuza
!> Process
        do
            niter=niter+1 !> we update number of iterations
            if (niter>this%CV_params%niter_max) then
                print *, "Residual: ", inf_norm_vec_real(residual)
                print *, "Too many Newton iterations in speciation"
                exit
            end if
            call this%compute_c2nc_from_c1_Picard(c2nc_old,c2nc_new,niter_Picard,CV_flag_Picard)
            conc_nc(n_p+1:n_nc)=c2nc_new !> chapuza
            call this%compute_residual(conc_comp,conc_nc,residual)
            if (inf_norm_vec_real(residual)<this%CV_params%abs_tol) then !> CV reached
                CV_flag=.true.
                exit
            end if
        !> First we compute d_log_gamma_d_I
            call this%compute_d_log_gamma_d_I_aq_chem(d_log_gamma_d_I)
        !> Outer product d_log_gamma_nc_d_I and z_nc^2
            out_prod=outer_prod_vec(d_log_gamma_d_I,this%chem_syst%z2(1:n_nc))
        !> We compute Jacobian secondary variable activity-primary concentrations
            call this%compute_dc2nc_dc1_aq(conc_nc(n_p+1:n_nc),out_prod,dc2nc_dc1)
        !> We compute log-Jacobian variable activity coefficients-variable activity concentrations
            out_prod_aq(1:n_p_aq,1:n_p_aq)=out_prod(1:n_p_aq,1:n_p_aq)
            out_prod_aq(n_p_aq+1:n_nc_aq,n_p_aq+1:n_nc_aq)=out_prod(n_p+1:n_nc_aq+1,n_p+1:n_nc_aq+1)
            call this%aq_phase%compute_log_Jacobian_act_coeffs_aq_phase(out_prod_aq,THIS%concentrations(1:n_nc_aq),log_Jacobian_act_coeffs_aq)
            log_Jacobian_act_coeffs(1:n_p_aq,1:n_p_aq)=log_Jacobian_act_coeffs_aq(1:n_p_aq,1:n_p_aq)
            log_Jacobian_act_coeffs(n_p+1:n_nc_aq+1,n_p+1:n_nc_aq+1)=log_Jacobian_act_coeffs_aq(n_p_aq+1:n_nc_aq,n_p_aq+1:n_nc_aq)            
        !> We check Jacobain secondary variable activity-primary concentrations
             call this%check_dc2nc_dc1(conc_nc(1:n_p),conc_nc(n_p+1:n_nc),dc2nc_dc1,log_Jacobian_act_coeffs)
        !> We solve linear system
            mat_lin_syst=this%speciation_alg%comp_mat(:,1:n_p)+matmul(this%speciation_alg%comp_mat(:,n_p+1:n_nc),dc2nc_dc1) !> U_1 + U_2_nc*dc2nc_dc1
            call LU_lin_syst(mat_lin_syst,-residual,this%CV_params%zero,Delta_c1)
            !> c1^(i+1)=c1^i+Delta_c1^i
            if (inf_norm_vec_real(Delta_c1/conc_nc(1:n_p))<this%CV_params%abs_tol**2) then !> chapuza
                print *, "Relative error: ", inf_norm_vec_real(Delta_c1/conc_nc(1:n_p))
                print *, "Newton speciation not accurate enough"
                exit
            else
                call this%update_conc_prim_species(conc_nc(1:n_p),Delta_c1)
                c2nc_old=c2nc_new
            end if
            !call this%compute_salinity()
            !call this%compute_molarities()
        end do
        call this%compute_pH()
end subroutine