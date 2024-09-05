!> Species class: encapsulates attributes of species
module species_m
    use params_act_coeff_m
    use params_spec_vol_m
    implicit none
    save
    type, public :: element_c !> element superclass
        character(len=256)  :: name !> name of species (including valence)
        integer(kind=4) :: valence !> valence
        real(kind=8) :: molecular_weight !> [kg/mol]
        real(kind=8) :: mol_vol !> molar volume [L/mol]
    contains
    !> Set
        procedure, public :: set_name
        procedure, public :: set_valence
        procedure, public :: set_molecular_weight
        procedure, public :: set_mol_vol
    end type
    
    type, public, extends(element_c) :: species_c !> species subclass
        class(element_c), pointer  :: element !> PHREEQC
        logical :: cst_act_flag !> TRUE if species has constant activity, FALSE otherwise
        type(params_act_coeff_c) :: params_act_coeff !> parameters to compute activity coefficient
        type(params_spec_vol_Redlich_c) :: params_spec_vol_Redlich !> parameters to compute conventional specific volume using Redlich (PHREEQC)
    contains
    !> Set
        procedure, public :: set_cst_act_flag
        procedure, public :: set_element
        procedure, public :: set_params_act_coeff
        procedure, public :: set_params_spec_vol_Redlich
    !> Assign
        procedure, public :: assign_species
    !> Read
        procedure, public :: read_species
    end type

!> PFLOTRAN:    
    
  !type, public :: species_type
  !>  character(len=MAXWORDLENGTH) :: name
  !>  PetscInt :: id
  !>  PetscReal :: molar_weight
  !>  PetscReal :: mnrl_molar_density  !> [mol/m^3-mnrl]
  !>  PetscReal :: solubility_limit    !> [mol/m^3-liq]
  !>  PetscReal :: ele_kd              !> [m^3-water/m^3-bulk
  !>  PetscBool :: radioactive
  !>  PetscBool :: print_me
  !>  type(species_type), pointer :: next
  !end type species_type
    
    interface
        
        subroutine compare_species_arrays(species_array_1,species_array_2,flag)
            import species_c
            implicit none
            class(species_c), intent(in) :: species_array_1(:)
            class(species_c), intent(in) :: species_array_2(:)
            logical, intent(out) :: flag
        end subroutine
        
        subroutine read_species(this,str)
            import species_c
            implicit none
            class(species_c) :: this
            character(len=*), intent(in) :: str
        end subroutine
    end interface
    
    contains
        subroutine set_name(this,name)
            implicit none
            class(element_c) :: this
            character(len=*), intent(in) :: name
            this%name=name
        end subroutine
        
        subroutine set_valence(this,valence)
            implicit none
            class(element_c) :: this
            integer(kind=4), intent(in) :: valence
            this%valence=valence
        end subroutine
        
        
        subroutine set_element(this,element)
            implicit none
            class(species_c) :: this
            class(element_c), intent(in), target :: element
            this%element=>element
        end subroutine
        
        subroutine set_molecular_weight(this,molecular_weight)
            implicit none
            class(element_c) :: this
            real(kind=8), intent(in) :: molecular_weight
            this%molecular_weight=molecular_weight
        end subroutine
        
        subroutine set_cst_act_flag(this,cst_act_flag)
            implicit none
            class(species_c) :: this
            logical, intent(in) :: cst_act_flag
            this%cst_act_flag=cst_act_flag
        end subroutine
        
       
        
        subroutine set_params_act_coeff(this,params_act_coeff)
            implicit none
            class(species_c) :: this
            type(params_act_coeff_c) :: params_act_coeff
            this%params_act_coeff=params_act_coeff
        end subroutine
        
        subroutine set_params_spec_vol_Redlich(this,params_spec_vol_Redlich)
            implicit none
            class(species_c) :: this
            type(params_spec_vol_Redlich_c) :: params_spec_vol_Redlich
            this%params_spec_vol_Redlich=params_spec_vol_Redlich
        end subroutine
        
        subroutine assign_species(this,species)
            implicit none
            class(species_c) :: this
            class(species_c), intent(in) :: species
            this%name=species%name
            this%cst_act_flag=species%cst_act_flag
            this%valence=species%valence
            this%params_act_coeff=species%params_act_coeff
            this%params_spec_vol_Redlich=species%params_spec_vol_Redlich
            this%element=>species%element
            this%molecular_weight=species%molecular_weight
            this%mol_vol=species%mol_vol
        end subroutine
        
        subroutine append_species(this,species_array)
            implicit none
            class(species_c), intent(in) :: this
            type(species_c), intent(inout), allocatable :: species_array(:)
            
            integer(kind=4) :: i
            type(species_c), allocatable :: aux_array(:)
            
            aux_array=species_array
            deallocate(species_array)
            if (size(aux_array)>0) then
                allocate(species_array(size(aux_array)+1))
                do i=1,size(species_array)-1
                    call species_array(i)%assign_species(aux_array(i))
                end do
                call species_array(size(species_array))%assign_species(this)
            else
                allocate(species_array(1))
                call species_array(1)%assign_species(this)
            end if
        end subroutine
        

        
        subroutine set_mol_vol(this,mol_vol)
            implicit none
            class(element_c) :: this
            real(kind=8), intent(in) :: mol_vol
            if (mol_vol<0d0) error stop "Molar volume cannot be negative"
            this%mol_vol=mol_vol
        end subroutine
end module