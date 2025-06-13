!> 1D reactive transport module (Lagrangian version)
module RT_1D_m
    use chemistry_Lagr_m, only: chemistry_c
    use transport_transient_m, only: transport_1D_transient_c, time_discr_homog_c, norm_mat_inf, tridiag_matrix_c
    use transport_m, only: transport_1D_c
    implicit none
    save
    type, public :: RT_1D_c !> 1D reactive transport superclass
        type(chemistry_c) :: chemistry                          !> chemistry object
    contains
        !procedure, public :: set_transport
        procedure, public :: set_chemistry
        procedure, public :: solve_RT_1D
        procedure, public :: write_RT_1D
        procedure, public :: write_python
        procedure, public :: compute_Delta_t_crit_RT
        procedure, public :: check_Delta_t_RT
        !procedure, public :: write_transport_data
        procedure, public :: read_time_discretisation
    end type
!***************************************************************************************************************************************************!
    type,public,extends(RT_1D_c) :: RT_1D_stat_c !> 1D stationary reactive transport subclass
        type(transport_1D_c) :: transport                       !> stationary transport object
    contains
        procedure, public :: set_transport_stat
    end type
!***************************************************************************************************************************************************!
    type,public,extends(RT_1D_c) :: RT_1D_transient_c !> 1D transient reactive transport subclass
        type(transport_1D_transient_c) :: transport             !> transient transport object
        real(kind=8) :: Delta_t_crit                            !> critical time step
        integer(kind=4) :: int_method_chem_reacts               !> integration method chemical reactions
    contains
        procedure, public :: set_int_method_chem_reacts
        procedure, public :: set_transport_trans
    end type
!***************************************************************************************************************************************************!
    interface
        
        subroutine solve_RT_1D(this)
            import RT_1D_c
            implicit none
            class(RT_1D_c) :: this
        end subroutine
        
        subroutine write_RT_1D(this,root,path_py)
            import RT_1D_c
            implicit none
            class(RT_1D_c), intent(in) :: this
            !integer(kind=4), intent(in) :: unit
            character(len=*), intent(in) :: root
            character(len=*), intent(in), optional :: path_py
        end subroutine
        
        subroutine write_python(this,path)
            import RT_1D_c
            implicit none
            class(RT_1D_c), intent(in) :: this
            character(len=*), intent(in) :: path !> path output files
        end subroutine
       
        
        subroutine compute_Delta_t_crit_RT(this)
            import RT_1D_c
            implicit none
            class(RT_1D_c) :: this
        end subroutine
        
       subroutine read_time_discretisation(this,root)
            import RT_1D_c
            class(RT_1D_c) :: this
            !integer(kind=4), intent(in) :: unit
            character(len=*), intent(in) :: root
        end subroutine
        
       subroutine read_transport_data(this,unit,file_tpt,mixing_ratios)
            import RT_1D_c
            class(RT_1D_c) :: this
            integer(kind=4), intent(in) :: unit
            character(len=*), intent(in) :: file_tpt
        end subroutine
        
        !subroutine write_transport_data(this,unit)
        !    import RT_1D_c
        !    class(RT_1D_c) :: this
        !    integer(kind=4), intent(in) :: unit
        !end subroutine

    end interface
    
    contains
        subroutine set_transport_stat(this,transport_obj)
            implicit none
            class(RT_1D_stat_c) :: this
            class(transport_1D_c), intent(in) :: transport_obj
            this%transport=transport_obj
        end subroutine
        
        subroutine set_transport_trans(this,transport_obj)
            implicit none
            class(RT_1D_transient_c) :: this
            class(transport_1D_transient_c), intent(in) :: transport_obj
            this%transport=transport_obj
        end subroutine
        
        subroutine set_chemistry(this,chemistry_obj)
            implicit none
            class(RT_1D_c) :: this
            class(chemistry_c), intent(in) :: chemistry_obj
            this%chemistry=chemistry_obj
        end subroutine
        
      
        
        subroutine check_Delta_t_RT(this)
            implicit none
            class(RT_1D_c) :: this    
            
            real(kind=8), parameter :: eps=1d-16
            
            select type (this)
            class is (RT_1D_transient_c)
                if (this%transport%time_discr%int_method.eq.1) then
                    call this%compute_Delta_t_crit_RT()
                    if (abs(this%Delta_t_crit)<eps) then
                        continue
                    else
                        select type (time=>this%transport%time_discr)
                        type is (time_discr_homog_c)
                            if (time%Delta_t>this%Delta_t_crit) then
                                print *, this%Delta_t_crit
                                error stop "Delta_t is larger than Delta_t_crit"
                            end if
                        end select
                    end if
                end if
            end select
        end subroutine
        
        subroutine set_int_method_chem_reacts(this,int_method)
            implicit none
            class(RT_1D_transient_c) :: this
            integer(kind=4), intent(in) :: int_method
            if (int_method<1 .or. int_method>3) error stop "Integration method for chemical reactions not implemented yet"
            this%int_method_chem_reacts=int_method
        end subroutine
end module