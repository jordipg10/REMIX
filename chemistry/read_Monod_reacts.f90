!> Reads Monod reactions from database 'reacciones_monod.dat' (created by me)
subroutine read_Monod_reacts(this,path,unit)
    use chem_system_m
    implicit none
    class(chem_system_c) :: this
    character(len=*), intent(in) :: path
    integer(kind=4), intent(in) :: unit
            
    integer(kind=4) :: i,j,k,react_ind,n_sp,ind,num_inh,num_TEAs
    integer(kind=4), allocatable :: n_inh(:),n_TEAs(:)
    real(kind=8) :: rate_cst,logK
    character(len=256) :: label,filename,str
    logical :: flag
    type(aq_species_c) :: DOC    
    type(aq_species_c), allocatable :: inhibitors(:),redox_couple(:)
!> Pre-process    
    filename=trim(path)//'\reacciones_monod.dat'
    allocate(n_inh(this%num_redox_kin_reacts))
    allocate(redox_couple(2))
    call DOC%set_name('ch2o(aq)')
!> Process
    open(unit,file=filename,status='old',action='read')
!> First iteration
    !react_ind=1 !> counter redox kinetic reactions chemcial system
    do
        read(unit,*) label
        if (label=='end') then
            rewind(unit)
            exit
        else
            call this%is_redox_kin_reaction_in_chem_syst(label,flag,react_ind)
            if (flag==.true.) then
                read(unit,*) n_inh(react_ind)
                call this%redox_kin_reacts(react_ind)%params%allocate_k_inh(n_inh(react_ind))
                call this%redox_kin_reacts(react_ind)%params%allocate_k_M()
                call this%redox_kin_reacts(react_ind)%params%compute_num_terms()
                allocate(this%redox_kin_reacts(react_ind)%indices_aq_phase(this%redox_kin_reacts(react_ind)%params%num_terms))
                read(unit,*) (redox_couple(j)%name, this%redox_kin_reacts(react_ind)%params%k_M(j), j=1,2)
                do j=1,2
                    call this%aq_phase%is_species_in_aq_phase(redox_couple(j),flag,ind) !> chapuza (puede haber especies no acuosas)
                    if (flag==.false.) then
                        error stop
                    else
                        this%redox_kin_reacts(react_ind)%indices_aq_phase(this%redox_kin_reacts(react_ind)%params%n_inh+j)=ind
                    end if
                end do
                read(unit,*) n_sp
                call this%redox_kin_reacts(react_ind)%allocate_reaction(n_sp)
                !if (react_ind<this%num_redox_kin_reacts) then
                !    react_ind=react_ind+1
                !else
                !    rewind(unit)
                !    exit
                !end if
            else
                call this%is_eq_reaction_in_chem_syst(label,flag,react_ind)
                if (flag==.true.) then
                    read(unit,*) num_inh
                    read(unit,*) num_TEAs
                    read(unit,*) n_sp
                    call this%eq_reacts(react_ind)%allocate_reaction(n_sp)
                else
                    continue
                end if
            end if
        end if
    end do
!> Second iteration
    !ind_redox_kin=1 !> counter Monod reactions chemcial system
    do
        read(unit,*) label
        if (label=='end') then
            exit
        else
            call this%is_redox_kin_reaction_in_chem_syst(label,flag,react_ind)
            if (flag==.true.) then
                if (n_inh(react_ind)>0) then
                    allocate(inhibitors(n_inh(react_ind)))
                    read(unit,*) this%redox_kin_reacts(react_ind)%params%n_inh, (inhibitors(j)%name, this%redox_kin_reacts(react_ind)%params%k_inh(j), j=1,this%redox_kin_reacts(react_ind)%params%n_inh)
                    do j=1,this%redox_kin_reacts(react_ind)%params%n_inh
                        call this%aq_phase%is_species_in_aq_phase(inhibitors(j),flag,ind) !> chapuza (puede haber especies no acuosas)
                        if (flag==.false.) then
                            error stop
                        else
                            this%redox_kin_reacts(react_ind)%indices_aq_phase(j)=ind
                        end if
                    end do
                    deallocate(inhibitors)
                else
                    read(unit,*) this%redox_kin_reacts(react_ind)%params%n_inh
                end if
                read(unit,*) str
                read(unit,*) this%redox_kin_reacts(react_ind)%num_species, (this%redox_kin_reacts(react_ind)%species(j)%name, this%redox_kin_reacts(react_ind)%stoichiometry(j), j=1,this%redox_kin_reacts(react_ind)%num_species), this%redox_kin_reacts(react_ind)%params%rate_cst!, this%redox_kin_reacts(react_ind)%eq_cst
                !call this%chem_syst%aq_phase%is_species_in_aq_phase(DOC,flag,ind)
                !if (flag==.false.) then
                !    error stop
                !else
                !    this%redox_kin_reacts(react_ind)%indices_aq_phase(this%redox_kin_reacts(react_ind)%params%num_terms+1)=ind
                !end if
            else
                call this%is_eq_reaction_in_chem_syst(label,flag,react_ind)
                if (flag==.true.) then
                    read(unit,*) num_inh
                    read(unit,*) num_TEAs
                    read(unit,*) this%eq_reacts(react_ind)%num_species, (this%eq_reacts(react_ind)%species(j)%name, this%eq_reacts(react_ind)%stoichiometry(j), j=1,this%eq_reacts(react_ind)%num_species), rate_cst, logK
                    call this%eq_reacts(react_ind)%set_eq_cst(10**logK)
                else
                    continue
                end if
            end if
        end if
    end do
    close(unit)
end subroutine