!> Computes species concentrations with data from water type definition using Newton method
!> We assume the initial guess of primary aqueous species is already set in the aqueous chemistry object
!> This subroutine is only used to read water types and initial surface adsorption zones based in CHEPROO
subroutine initialise_conc_anal_exch(this,icon,n_icon,indices_constrains,ctot,surf_chem,niter,CV_flag)
    use metodos_sist_lin_m
    use aqueous_chemistry_m
    use vectors_m, only : inf_norm_vec_real
    implicit none
!> Arguments
    class(aqueous_chemistry_c) :: this
    integer(kind=4), intent(in) :: icon(:) !> initial condition type
    integer(kind=4), intent(in) :: n_icon(:) !> number of each icon
    integer(kind=4), intent(in) :: indices_constrains(:) !> indices of constrains in equilibrium stoichiometric matrix
    real(kind=8), intent(in) :: ctot(:) !> data given in water type
    !real(kind=8), intent(in) :: c1_surf !> chapuza
    !real(kind=8), intent(in) :: CEC
    !real(kind=8), intent(out) :: conc_exch(:) !> chapuza
    class(solid_chemistry_c), intent(inout) :: surf_chem !> surface chemistry
    integer(kind=4), intent(out) :: niter !> number of iterations Newton-Raphson
    logical, intent(out) :: CV_flag !> TRUE if converges, FALSE otherwise
!> Variables
    real(kind=8), allocatable :: c1(:),c2_old(:),c2_new(:),conc_comp(:),c2k(:),log_c2k(:),log_c2(:),dc2_dc1(:,:),out_prod(:,:),out_prod_aq(:,:)
    real(kind=8), allocatable :: res(:) !> residual in Newton-Raphson
    real(kind=8), allocatable :: Jac_res(:,:) !> Jacobian of residual in Newton-Raphson
    real(kind=8), allocatable :: Delta_c1(:) !> c1^(i+1)-c1^i (Newton)
    real(kind=8), allocatable :: tol_res(:) !> tolerance residues Newton-Raphson
    real(kind=8), allocatable :: mat_lin_syst(:,:),Se_aq_comp(:,:),K(:),u_aq(:),z2(:),d_log_gamma_d_I(:),log_Jacobian_act_coeffs(:,:)
    integer(kind=4) :: i,j,ind_eqn,niter_Picard,ind_cstr
    integer(kind=4), allocatable :: ind_aq_comp(:),cols(:),ind_aq_species(:),counters(:)
    logical :: flag_gas,flag_min,flag_wat
    type(int_array_c) :: indices_icon
    
!> Pre-process
    CV_flag=.false.
    if (size(icon)/=this%speciation_alg%num_aq_prim_species) error stop
    
    if (sum(n_icon)/=this%speciation_alg%num_aq_prim_species) error stop
    
    allocate(c2_old(this%speciation_alg%num_eq_reactions),c2_new(this%speciation_alg%num_eq_reactions))
    ind_cstr=0 !> index of phase constrain
    call indices_icon%allocate_matrix(4) !> number of icon options
    do i=1,indices_icon%num_cols
        call indices_icon%cols(i)%allocate_vector(n_icon(i))
    end do
    allocate(counters(4)) !> dim=n�icon options
    counters=0 !> initial counter for each icon option
    allocate(tol_res(this%speciation_alg%num_prim_species))
    tol_res=this%CV_params%abs_tol !> absolute tolerance (by default)
    do i=1,this%speciation_alg%num_aq_prim_species
        !tol_res(i)=this%CV_params%abs_tol
        !> Concentrations
        if (icon(i)==1) then
            counters(1)=counters(1)+1
            indices_icon%cols(1)%col_1(counters(1))=i
        !> Aqueous components
        else if (icon(i)==2) then
            counters(2)=counters(2)+1
            indices_icon%cols(2)%col_1(counters(2))=i
        !> Activities
        else if (icon(i)==3) then
            counters(3)=counters(3)+1
            indices_icon%cols(3)%col_1(counters(3))=i
        !> Phases
        else if (icon(i)==4) then
            counters(4)=counters(4)+1
            indices_icon%cols(4)%col_1(counters(4))=i
            tol_res(i)=this%CV_params%log_abs_tol !> logarithmic absolute tolerance
        else
            error stop "icon option not implemented"
        end if
    end do
!> Newton-Raphson
    allocate(res(this%speciation_alg%num_prim_species),Jac_res(this%speciation_alg%num_prim_species,this%speciation_alg%num_prim_species))
    allocate(c1(this%speciation_alg%num_prim_species),Delta_c1(this%speciation_alg%num_prim_species))
    allocate(d_log_gamma_d_I(this%speciation_alg%num_species))
    allocate(log_Jacobian_act_coeffs(this%speciation_alg%num_species,this%speciation_alg%num_species))
    allocate(dc2_dc1(this%speciation_alg%num_eq_reactions,this%speciation_alg%num_prim_species)) !> chapuza
    allocate(out_prod_aq(this%chem_syst%aq_phase%num_species,this%chem_syst%aq_phase%num_species))
    
    c1(this%speciation_alg%num_prim_species)=surf_chem%concentrations(1)
    c1(1:this%speciation_alg%num_aq_prim_species)=this%concentrations(1:this%speciation_alg%num_aq_prim_species) !> chapuza
    
    c2_old=1d-16 !> chapuza
    if (indices_icon%cols(4)%dim>0) then
        c2_old(this%speciation_alg%num_sec_aq_species+1:this%speciation_alg%num_eq_reactions)=ctot(indices_icon%cols(4)%col_1)
    end if
    
    call this%set_conc_sec_aq_species(c2_old(1:this%speciation_alg%num_sec_aq_species)) !> initial guess c2aq

    niter=0
    this%log_act_coeffs=0d0 !> chapuza
    d_log_gamma_d_I=0d0 !> chapuza
    !> Squared charges species
    !allocate(z2(this%speciation_alg%num_species))
    !z2=0d0 !> chapuza
    !z2(this%speciation_alg%num_prim_species)=1 !> autentica chapuza
    !z2(1:this%speciation_alg%num_aq_prim_species)=this%chem_syst%aq_phase%z2(1:this%speciation_alg%num_aq_prim_species)
    !z2(this%speciation_alg%num_prim_species+1:this%chem_syst%aq_phase%num_species)=this%chem_syst%aq_phase%z2(this%speciation_alg%num_aq_prim_species+1:this%chem_syst%aq_phase%num_species)
    Delta_c1=0d0 !> chapuza
    do
    !> We update number of iterations
        niter=niter+1
        if (niter>this%CV_params%niter_max) then
            print *, "Too many Newton iterations in initialisation"
            error stop
        end if
        !call this%compute_ionic_act()
        !call this%chem_syst%aq_phase%compute_log_act_coeffs_aq_phase(this%ionic_act,this%params_aq_sol,this%log_act_coeffs)
        call this%compute_c2_from_c1_Picard(c1,c2_old,c2_new,niter_Picard,CV_flag)
        !call this%compute_ionic_act() !> we compute ionic activity
        !call this%chem_syst%aq_phase%compute_log_act_coeffs_aq_phase(this%ionic_act,this%params_aq_sol,this%log_act_coeffs) !> we compute log activity coefficients aqueous species
        !call this%compute_activities()
        !call this%compute_log_act_coeff_wat()
        
        !print *, 10**this%log_act_coeffs
        !print *, c2_new
        !print *, this%activities
    !> Chapuza
        !c2(1:this%speciation_alg%num_sec_aq_species)=this%concentrations(this%speciation_alg%num_aq_prim_species+1:this%chem_syst%aq_phase%num_species)
    !> We compute residue and Jacobian analytically
        !> First we compute d_log_gamma_d_I
        call this%compute_d_log_gamma_d_I_aq_chem(d_log_gamma_d_I)
        !> Outer product d_log_gamma_d_I and z^2
        out_prod=outer_prod_vec(d_log_gamma_d_I,this%chem_syst%z2)
        !out_prod_aq(1:this%speciation_alg%num_aq_prim_species)=out_prod(1:this%speciation_alg%num_aq_prim_species) !> chapuza
        !out_prod_aq(this%speciation_alg%num_aq_prim_species+1:this%chem_syst%aq_phase%num_species)=out_prod(1:this%speciation_alg%num_prim_species+1:this%chem_syst%aq_phase%num_species) !> chapuza
        !> We compute Jacobian secondary-primary concentrations
        call this%compute_dc2_dc1(out_prod,c1,c2_new,dc2_dc1)
        !> We compute log-Jacobian activity coefficients-concentrations
        call this%chem_syst%aq_phase%compute_log_Jacobian_act_coeffs_aq_phase(out_prod,[c1,c2_new],log_Jacobian_act_coeffs)
        !> We check dc2_dc1
        call this%check_dc2_dc1(c1,c2_new,dc2_dc1,log_Jacobian_act_coeffs)
        conc_comp=this%compute_conc_comp_cst_act([c1,c2_new])
        call this%compute_res_Jac_res_anal_exch([c1,c2_new],indices_icon,n_icon,indices_constrains,ctot,dc2_dc1,log_Jacobian_act_coeffs,conc_comp(this%speciation_alg%num_prim_species),res,Jac_res)
    !> We check convergence
        if (inf_norm_vec_real(res)<inf_norm_vec_real(tol_res)) then !> CV reached
            CV_flag=.true.
            exit
        end if
    !> We solve linear system aqueous primary concentartions
        call LU_lin_syst(Jac_res,-res,this%CV_params%zero,Delta_c1)
        !> c1^(i+1)=c1^i+Delta_c1^i
        if (inf_norm_vec_real(Delta_c1/c1)<this%CV_params%rel_tol) then
            print *, inf_norm_vec_real(Delta_c1/c1)
            print *, "Newton method not accurate enough in initialisation"
            error stop
        end if
    !> We update primary concentrations
        call this%update_conc_prim_species(c1,Delta_c1)
    end do
    surf_chem%concentrations(1)=c1(this%speciation_alg%num_prim_species)
    surf_chem%concentrations(2:surf_chem%reactive_zone%num_solids)=c2_new(this%speciation_alg%num_sec_aq_species+1:this%speciation_alg%num_eq_reactions)
    call this%compute_pH()
    call this%compute_salinity()
    call this%compute_alkalinity()

end subroutine