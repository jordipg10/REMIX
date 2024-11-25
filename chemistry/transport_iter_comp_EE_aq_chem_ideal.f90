!> Computes component and variable activity concentrations after iteration of WMA method for equilibrium chemical system
!> We assume all primary species are aqueous
subroutine transport_iter_comp_ideal(this,c1_old,c2nc_ig,c_tilde,conc_nc,porosity,Delta_t)
    use aqueous_chemistry_m
    implicit none
!> Arguments
    class(aqueous_chemistry_c) :: this !> aqueous chemistry object at current time step
    !class(aqueous_chemistry_c), intent(in) :: this_old !> aqueous chemistry object at previous time step (nombre muy malo)
    real(kind=8), intent(in) :: c1_old(:)
    real(kind=8), intent(in) :: c2nc_ig(:)
    real(kind=8), intent(in) :: c_tilde(:)
    real(kind=8), intent(out) :: conc_nc(:)
    !real(kind=8), intent(out) :: conc_comp(:) !> concentration components
    real(kind=8), intent(in), optional :: porosity
    real(kind=8), intent(in), optional :: Delta_t !> time step
!> Variables
    integer(kind=4) :: niter !> number of iterations in Newton speciation
    logical :: CV_flag !> convergence flag
    real(kind=8) :: mu=0d0 !> Newton initialistaion parameter
    real(kind=8), allocatable :: c1(:) !> concentration primary species
    real(kind=8), allocatable :: conc_comp(:) !> concentration components
!> Pre-process
    !print *, this%solid_chemistry%reactive_zone%speciation_alg%num_prim_species
    c1=this%concentrations(1:this%solid_chemistry%reactive_zone%speciation_alg%num_prim_species)
    !allocate(conc_nc(1:this%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species))
!> Process  
    !> We compute component concentrations after mixing
        conc_comp=MATMUL(THIS%solid_chemistry%reactive_zone%speciation_alg%comp_mat,c_tilde)
        if (inf_norm_vec_real(c_tilde(1:this%solid_chemistry%reactive_zone%speciation_alg%num_prim_species)-c1)<this%solid_chemistry%reactive_zone%CV_params%zero) then !> chapuza
            conc_nc=this%get_conc_nc()
        else
            !> Loop until speciation converges
            do
            !> We initialise primary concentrations for Newton speciation
                call initialise_iterative_method(c1_old,c1,mu,this%concentrations(1:this%solid_chemistry%reactive_zone%speciation_alg%num_prim_species))
            !> We compute variable activity concentrations from component concentrations
                call this%compute_c_nc_from_u_aq_Newton_ideal(conc_comp,conc_nc,niter,CV_flag)
            !> Analytical solution gypsum+calcite ideal    
                !if (abs(conc_comp(1)-this%solid_chemistry%reactive_zone%eq_reactions(3)%eq_cst/(this%solid_chemistry%reactive_zone%eq_reactions(2)%eq_cst*conc_nc(5))+(this%solid_chemistry%reactive_zone%eq_reactions(2)%eq_cst*conc_nc(5))/(this%solid_chemistry%reactive_zone%eq_reactions(1)%eq_cst*this%solid_chemistry%reactive_zone%eq_reactions(3)%eq_cst)+(conc_comp(2)*conc_nc(5))/(this%solid_chemistry%reactive_zone%eq_reactions(3)%eq_cst+conc_nc(5))+conc_nc(5))>this%solid_chemistry%reactive_zone%CV_params%abs_tol) then
                !    error stop
                !end if
            !> We check convergence
                if (CV_flag==.false.) then !> NO CV
                    if (mu<1d0) then
                        mu=mu+0.25
                    else
                        error stop "Newton speciation does not converge"
                    end if
                else
                    exit
                end if
            end do
        end if
!> Post-process
    !> We check concentrations
        !call this%check_conc_aq_var_act_species(conc_comp)
        !call this%check_act_aq_species()
end subroutine