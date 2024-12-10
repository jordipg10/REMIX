!> Solves reactive mixing problem
!> Computes concentrations, activities, activity coefficients, reaction rates and volumetric fractions of minerals (if present)
subroutine solve_reactive_mixing_BCs_dep_t(this,root,unit,mixing_ratios,mixing_waters_indices,time_discr_tpt,int_method_chem_reacts,spatial_discr_tpt,D,q,phi,anal_sol_comp)
    use chemistry_Lagr_m
    use spatial_discr_1D_m
    implicit none
!> Arguments
    class(chemistry_c) :: this !> chemistry object
    character(len=*), intent(in) :: root
    integer(kind=4), intent(in) :: unit
    class(real_array_c), intent(in) :: mixing_ratios !> mixing ratios matrix
    class(int_array_c), intent(in) :: mixing_waters_indices !> matrix that contains indices of target waters that mix with each target water
    class(time_discr_c), intent(in) :: time_discr_tpt !> time discretisation object (used to solve transport)
    integer(kind=4), intent(in) :: int_method_chem_reacts !> integration method for chemical reactions
    class(spatial_discr_c), intent(in) :: spatial_discr_tpt !> spatial discretisation object (used to solve transport)
    real(kind=8), intent(in) :: D
    real(kind=8), intent(in) :: q
    real(kind=8), intent(in) :: phi
    real(kind=8), external :: anal_sol_comp
    !real(kind=8), external :: anal_sol_conc
!> Variables
    integer(kind=4) :: i !> counter target waters
    integer(kind=4) :: j !> counter target solids 
    integer(kind=4) :: l !> counter reactive zones
    integer(kind=4) :: k !> counter time steps
    integer(kind=4) :: kk !> counter time steps chem_out_options
    integer(kind=4) :: ii !> counter target waters chem_out_options
    integer(kind=4) :: num_tar_wat !> number of target waters
    integer(kind=4) :: num_tar_sol !> number of target solids
    integer(kind=4) :: niter !> number of iterations
    integer(kind=4), allocatable :: tar_gas_indices(:) !> indices target gases in each reactive zone
    integer(kind=4), allocatable :: tar_sol_indices(:) !> indices target solids in each reactive zone
    integer(kind=4), allocatable :: tar_wat_indices(:) !> indices target waters in each reactive zone
    REAL(KIND=8) :: time !> time
    REAL(KIND=8) :: Delta_t !> time step
    REAL(KIND=8), allocatable :: c_tilde(:) !> concentrations after mixing
    REAL(KIND=8), allocatable :: conc_old(:,:) !> concentrations before mixing
    REAL(KIND=8), allocatable :: conc_nc(:) !> concentrations variable activity species
    REAL(KIND=8), allocatable :: conc_comp(:,:) !> concentrations components boundary
    REAL(KIND=8), allocatable :: conc_comp_init(:,:) !> initial concentrations components boundary
    type(aqueous_chemistry_c), allocatable :: target_waters_new(:) !> target waters time step k+1
    type(aqueous_chemistry_c), allocatable :: target_waters_old(:) !> target waters time step k
    type(aqueous_chemistry_c), allocatable :: target_waters_old_old(:) !> target waters time step k-1
    type(reactive_zone_c) :: react_zone
    type(aq_phase_c), target :: aq_phase
    logical :: CV_flag
!> Procedure pointers
    !> primary concentrations
    procedure(get_c1_aq), pointer :: p_prim=>NULL()
    !> reactive mixing subroutines
    procedure(mixing_iter_comp_ideal), pointer :: p_solver=>null()
    !> mobile species mixing
    procedure(compute_c_tilde), pointer :: p_c_tilde=>null()
    p_c_tilde=>compute_c_tilde !> by default
!> We initialise target waters
    target_waters_old=this%target_waters
    target_waters_old_old=target_waters_old
    target_waters_new=target_waters_old

    time=0d0
    kk=2 !> counter time steps chem_out_options
    ii=1 !> counter target waters chem_out_options
    this%chem_out_options%time_steps(this%chem_out_options%num_time_steps)=time_discr_tpt%Num_time !> chapuza
        
    
    open(unit,file=root//'.out',form="formatted",access="sequential",status="unknown")
!> We select reactive mixing subroutine depending on the nature of the chemical system and the methods to compute Jacobians and integrate in time
    if (this%num_reactive_zones>0) then !> there are reactive zones
        allocate(conc_comp_init(this%reactive_zones(1)%speciation_alg%num_aq_prim_species,2))
        conc_comp_init(:,1)=this%target_waters(this%dom_tar_wat_indices(1))%compute_conc_comp(this%target_waters(this%dom_tar_wat_indices(1))%get_conc_nc())
        conc_comp_init(:,2)=this%target_waters(this%dom_tar_wat_indices(this%num_target_waters_dom))%compute_conc_comp(this%target_waters(this%dom_tar_wat_indices(this%num_target_waters_dom))%get_conc_nc())
        conc_comp=conc_comp_init
        !> Time loop
            do k=1,time_discr_tpt%Num_time
                Delta_t=time_discr_tpt%get_Delta_t(k)
                time=time+Delta_t
                if (k==this%chem_out_options%time_steps(kk)) then
                    write(unit,"(2x,'t = ',*(ES15.5))") time
                    write(unit,"(20x,*(A15))") (this%chem_syst%aq_phase%aq_species(this%chem_out_options%ind_aq_species(j))%name, j=1,this%chem_out_options%num_aq_species)
                end if
            !> Target waters loop
                do j=1,target_waters_new(this%num_ext_waters+1)%solid_chemistry%reactive_zone%speciation_alg%num_aq_prim_species
                    conc_comp(j,1)=anal_sol_comp(conc_comp_init(j,1),1d0,spatial_discr_tpt%get_mesh_size(),spatial_discr_tpt%init_point,spatial_discr_tpt%get_mesh_size()*10,time,phi,D,q)
                end do
                call target_waters_new(this%num_ext_waters+1)%compute_c_from_u_bin_syst(conc_comp(1,1),target_waters_new(this%num_ext_waters+1)%solid_chemistry%reactive_zone%eq_reactions(1)%eq_cst)
                target_waters_new(this%num_ext_waters+1)%concentrations(2)=conc_comp(2,1)
                do i=this%num_ext_waters+2,this%num_target_waters-1
                    !if (abs(mixing_ratios%cols(i-this%num_ext_waters)%col_1(1)-1d0)<this%target_waters(i)%solid_chemistry%reactive_zone%CV_params%abs_tol .and. inf_norm_vec_real(mixing_ratios%cols(i-this%num_ext_waters)%col_1(2:mixing_ratios%cols(i-this%num_ext_waters)%dim))<this%target_waters(i)%solid_chemistry%reactive_zone%CV_params%abs_tol) then
                    !    continue
                    !else
                        if (this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_aq_prim_species==this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species) then
                            p_prim=>get_c1_aq !> chapuza
                        else
                            p_prim=>get_c1
                        end if
                        if (this%chem_syst%num_kin_reacts>0) then !> equilibrium and kinetic reactions
                            if (int_method_chem_reacts==1) then !> Euler explicit
                                !if (this%act_coeffs_model==0) then !> ideal
                                    p_solver=>water_mixing_iter_EE_eq_kin_ideal
                                !else
                                !    p_solver=>water_mixing_iter_EE_eq_kin
                                !end if
                            else if (int_method_chem_reacts==2 .and. this%Jac_flag==1) then !> Euler fully implicit, analytical Jacobian
                                !if (this%act_coeffs_model==0) then !> ideal
                                    p_solver=>water_mixing_iter_EfI_eq_kin_anal_ideal
                                !else
                                !    p_solver=>water_mixing_iter_EfI_eq_kin_anal
                                !end if
                            else
                                error stop "Integration method for chemical reactions not implemented yet"
                            end if
                        else if (this%target_waters(i)%solid_chemistry%reactive_zone%cat_exch_zone%num_surf_compl>0) then !> variable activity species are aqueous and solid
                            p_solver=>mixing_iter_comp_exch_ideal !> only equilibrium reactions
                        else !> faltan los gases en equilibrio
                            !if (this%act_coeffs_model==0) then !> ideal
                                p_solver=>mixing_iter_comp_ideal !> only equilibrium reactions
                            !else
                            !    p_solver=>mixing_iter_comp !> only equilibrium reactions
                            !end if
                        end if
                        allocate(conc_nc(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species))
                        !allocate(conc_comp(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species))
                        allocate(conc_old(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species,mixing_ratios%cols(i-this%num_ext_waters)%dim)) !> chapuza
                        conc_old(:,1)=target_waters_old(i)%get_conc_nc() !> chapuza
                        do j=1,mixing_waters_indices%cols(i-this%num_ext_waters)%dim
                            conc_old(:,1+j)=target_waters_old(mixing_waters_indices%cols(i-this%num_ext_waters)%col_1(j))%get_conc_nc() !> chapuza
                        end do
                    !> We solve mixing caused by transport
                        c_tilde=p_c_tilde(target_waters_old(i),mixing_ratios%cols(i-this%num_ext_waters)%col_1,conc_old)
                    !> We solve reactive mixing iteration
                        call p_solver(target_waters_new(i),p_prim(target_waters_old_old(i)),c_tilde,conc_nc,phi,Delta_t)
                    !> We compute equilibrium reaction rates from mass balance equation
                        call target_waters_new(i)%compute_r_eq(c_tilde(target_waters_new(i)%indices_aq_phase(target_waters_new(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species+1:target_waters_new(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species)),Delta_t,phi)
                    !> Chapuza
                        if (associated(target_waters_new(i)%solid_chemistry)) then
                        !> We compute mass volumetric fractions of minerals from mass balance equation
                            call target_waters_new(i)%solid_chemistry%compute_mass_bal_mins(Delta_t)
                        !> We compute concentrations of minerals
                            call target_waters_new(i)%solid_chemistry%compute_conc_minerals_iter(Delta_t)
                        end if
                        if (associated(target_waters_new(i)%gas_chemistry)) then
                        !> We compute concentrations of gases
                            call target_waters_new(i)%gas_chemistry%compute_conc_gases_iter(Delta_t,phi,target_waters_new(i)%volume,[target_waters_new(i)%r_eq,target_waters_new(i)%rk])
                        !> We compute volume of gas   
                            call target_waters_new(i)%gas_chemistry%compute_vol_gas_conc()
                        !> We compute activity coefficients of gases    
                            call target_waters_new(i)%gas_chemistry%compute_log_act_coeffs_gases()
                        end if
                    !> We write output
                        if (k==this%chem_out_options%time_steps(kk) .and. i==this%chem_out_options%ind_target_waters(ii)) then
                            !do j=1,this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species
                                write(unit,"(I10,*(ES15.5))") i, (conc_nc(j), j=1,this%chem_out_options%num_aq_species)
                            !end do
                            if (ii<this%chem_out_options%num_target_waters) then
                                ii=ii+1
                            else if (kk<this%chem_out_options%num_time_steps) then
                                kk=kk+1
                                ii=1
                            else
                                exit
                            end if
                        end if
                    !> Deallocate
                        deallocate(c_tilde,conc_old,conc_nc)
                    !end if
                end do
                do j=1,target_waters_new(this%num_target_waters)%solid_chemistry%reactive_zone%speciation_alg%num_aq_prim_species
                    conc_comp(j,2)=anal_sol_comp(conc_comp_init(j,2),1d0,spatial_discr_tpt%get_mesh_size(),spatial_discr_tpt%init_point+spatial_discr_tpt%measure,spatial_discr_tpt%get_mesh_size()*10,time,phi,D,q)
                end do
                call target_waters_new(this%num_target_waters)%compute_c_from_u_bin_syst(conc_comp(1,2),target_waters_new(this%num_target_waters)%solid_chemistry%reactive_zone%eq_reactions(1)%eq_cst)
                target_waters_new(this%num_target_waters)%concentrations(2)=conc_comp(2,2)
            !> We update target waters
                target_waters_old_old=target_waters_old
                target_waters_old=target_waters_new
            end do
    !else !> there are NO reactive zones
    !    p_c_tilde=>compute_c_tilde
    !    if (this%chem_syst%num_eq_reacts>0) then 
    !        if (this%chem_syst%num_kin_reacts>0) then !> equilibrium and kinetic reactions
    !            if (int_method_chem_reacts==1) then !> Euler explicit
    !                p_solver=>water_mixing_iter_EE_eq_kin
    !            else if (int_method_chem_reacts==2 .and. this%Jac_flag==1) then !> Euler fully implicit
    !                p_solver=>water_mixing_iter_EfI_eq_kin_anal
    !            else
    !                error stop "Integration method for chemical reactions not implemented yet"
    !            end if
    !        else
    !            p_solver=>mixing_iter_comp !> only equilibrium reactions
    !        end if
    !    else if (this%chem_syst%num_kin_reacts>0) then !> only kinetic reactions
    !        if (int_method_chem_reacts==1) then !> Euler explicit
    !            !p_solver=>water_mixing_iter_EE_kin 
    !        else if (int_method_chem_reacts==2 .and. this%Jac_flag==1) then !> Euler fully implicit
    !            !p_solver=>water_mixing_iter_EfI_kin_anal
    !        else
    !            error stop "Integration method for chemical reactions not implemented yet"
    !        end if
    !    else !> no chemical reactions
    !        !p_solver=>mixing_iter_species !> conservative transport
    !    end if
    !    allocate(tar_wat_indices(this%num_target_waters))
    !!> Time loop
    !    do k=1,time_discr_tpt%Num_time
    !    !> Target waters loop
    !        do i=1,this%num_ext_waters+1,this%num_target_waters
    !            if (this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_aq_prim_species==this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species) then
    !                p_prim=>get_c1_aq !> chapuza
    !            else
    !                p_prim=>get_c1
    !            end if
    !            allocate(conc_nc(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species))
    !            !allocate(conc_comp(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species))
    !            allocate(conc_old(this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species,mixing_ratios%cols(i-this%num_ext_waters)%dim)) !> chapuza
    !            conc_old(:,1)=target_waters_old(i)%get_conc_nc() !> chapuza
    !            do j=1,mixing_waters_indices%cols(i-this%num_ext_waters)%dim
    !                conc_old(:,1+j)=target_waters_old(mixing_waters_indices%cols(i-this%num_ext_waters)%col_1(j))%get_conc_nc() !> chapuza
    !            end do
    !        !> We solve mixing caused by transport
    !            c_tilde=p_c_tilde(target_waters_old(i),mixing_ratios%cols(i)%col_1,conc_old)
    !        !> We solve reactive mixing iteration
    !            call p_solver(target_waters_new(i),p_prim(target_waters_old_old(i)),target_waters_old(i)%get_c2nc(),c_tilde,conc_nc,phi,time_discr_tpt%get_Delta_t(k))
    !        !> We compute equilibrium reaction rates from mass balance equation
    !            call target_waters_new(i)%compute_r_eq(c_tilde(target_waters_new(i)%solid_chemistry%reactive_zone%speciation_alg%num_prim_species+1:target_waters_new(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species),Delta_t,phi)
    !        !> Chapuza
    !            if (associated(target_waters_new(i)%solid_chemistry)) then
    !            !> We compute mass volumetric fractions of minerals from mass balance equation
    !                call target_waters_new(i)%solid_chemistry%compute_mass_bal_mins(Delta_t)
    !            !> We compute concentrations of minerals
    !                call target_waters_new(i)%solid_chemistry%compute_conc_minerals_iter(Delta_t)
    !            end if
    !            if (associated(target_waters_new(i)%gas_chemistry)) then
    !            !> We compute concentrations of gases
    !                call target_waters_new(i)%gas_chemistry%compute_conc_gases_iter(Delta_t,phi,target_waters_new(i)%volume,[target_waters_new(i)%r_eq,target_waters_new(i)%rk])
    !            !> We compute volume of gas   
    !                call target_waters_new(i)%gas_chemistry%compute_vol_gas_conc()
    !            !> We compute activity coefficients of gases    
    !                call target_waters_new(i)%gas_chemistry%compute_log_act_coeffs_gases()
    !            end if
    !        !> We write output
    !            if (k==this%chem_out_options%time_steps(kk) .and. i==this%chem_out_options%ind_target_waters(ii)) then
    !                !do j=1,this%target_waters(i)%solid_chemistry%reactive_zone%speciation_alg%num_var_act_species
    !                    write(unit,"(I10,*(ES15.5))") i, (conc_nc(j), j=1,this%chem_out_options%num_aq_species)
    !                !end do
    !                if (ii<this%chem_out_options%num_target_waters) then
    !                    ii=ii+1
    !                else if (kk<this%chem_out_options%num_time_steps) then
    !                    kk=kk+1
    !                    ii=1
    !                else
    !                    exit
    !                end if
    !            end if
    !        !> Deallocate
    !            deallocate(c_tilde,conc_old,conc_nc,conc_comp)
    !        end do
    !    !> We update target waters
    !        target_waters_old_old=target_waters_old
    !        target_waters_old=target_waters_new
    !    end do
    !!> Deallocate indices
    !    deallocate(tar_wat_indices)
    end if
!> We set the new target waters to the chemistry object
    this%target_waters=target_waters_new
    close(unit)
end subroutine