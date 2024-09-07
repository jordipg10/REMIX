program main
    use RT_1D_m
    implicit none
!> Objects
    type(RT_1D_transient_c) :: my_RT_trans !> 1D transient reactive transport class
    type(transport_1D_transient_c) :: my_tpt_trans !> 1D transient transport class
    type(chemistry_c) :: my_chem !> chemistry class
!> Variables
    integer(kind=4) :: example
    integer(kind=4) :: option_chem !> chemical input option (1: CHEPROO-based)
    integer(kind=4) :: opc_Jac !> Jacobian model (0: incremental coefficient, 1: analytically)
    integer(kind=4) :: option_tpt !> transport option (0: compute lambdas, 1: read lambdas)
    integer(kind=4) :: unit_tpt !> transport file unit
    integer(kind=4) :: unit_out !> output file unit
    integer(kind=4) :: unit_discr !> temporal discretisation file unit
    integer(kind=4) :: int_method_chem !> integration method for chemical reactions (1: Euler explicit, 2: Euler fully implicit)
    integer(kind=4) :: unit_chem_syst !> chemical system file unit
    integer(kind=4) :: unit_loc_chem !> local chemistry file unit
    integer(kind=4) :: unit_tw !> target waters file unit
    character(len=256) :: path !> path for reading files
    character(len=256) :: path_py !> path for Python
    character(len=256) :: file_out !> output file name
    character(len=256) :: file_chem_syst !> chemical system file name
    character(len=256) :: file_loc_chem !> local chemistry file name
    character(len=256) :: file_BCs !> file name with boundary conditions to solve transport
    character(len=256) :: file_tw !> target waters file name
    character(len=256) :: file_tpt !> file name with transport data (lambdas, etc) for reactive mixing with WMA
    character(len=256) :: file_tpt_props !> file name with transport properties (dispersion, flow, porosity, etc)
    character(len=256) :: file_discr !> temporal discretisation file name for reactive mixing with WMA
    character(len=256) :: file_space !> file name with spatial discretisation to solve transport
    character(len=256) :: file_time !> file name with temporal discretisation to solve transport
!**************************************************************************************************
!> Name of path containing chemical and transport information
    path = 'C:\Users\Jordi\source\repos\jordipg10\RT_Lagr_borr\input\' !> must be written by the user
    path_py='C:\Users\Jordi\OneDrive\Documentos\trabajo\python\' !> path for unit tests in Python (optional)
!> File units (arbitrary)
    unit_chem_syst=1
    unit_loc_chem=2
    unit_tw=3
    unit_discr=10
    unit_tpt=11
    unit_out=6
!> Names of files with transport and chemical data
    file_discr='WMA_discr.dat' 
    file_tpt='WMA_lambdas.dat'
    file_BCs='BCs.dat' 
    file_space='discr_esp.dat' 
    file_time='discr_temp.dat' 
    file_tpt_props='tpt_props.dat' 
!> Choose example
    example=0
    if (example==0) then
    !> Gypsum in equilibrium
        file_chem_syst='gypsum_eq_sist_quim.dat'
        file_loc_chem='gypsum_eq_quim_loc.dat'
        file_tw='gypsum_eq_tar_wat.dat'
        file_tpt_props='tpt_props_gypsum_eq.dat'
        file_BCs='BCs_gypsum_eq.dat'
        file_space='discr_esp_gypsum_eq.dat' 
        file_time='discr_temp_gypsum_eq.dat'
        file_discr='WMA_discr_gypsum_eq.dat' 
        file_tpt='WMA_lambdas_gypsum_eq.dat'
        file_out='gypsum_eq.out'
    else if (example==1) then
    !> Gypsum & calcite in equilibrium
        file_chem_syst='yeso_calcita_eq_sist_quim.dat'
        file_loc_chem='yeso_calcita_eq_quim_loc.dat'
        file_tw='yeso_calcita_eq_tar_wat.dat'
        file_out='yeso_calcita_eq.out'
    else if (example==6) then
    !> Saltwater intrusion (Rezaei et al, 2005)
        file_chem_syst='rezaei_sist_quim.dat'
        file_loc_chem='rezaei_quim_loc.dat'
        file_tw='rezaei_tar_wat.dat'
        file_tpt_props='tpt_props_rezaei.dat'
        file_BCs='BCs_rezaei.dat'
        file_time='discr_temp_rezaei.dat' 
        file_out='rezaei.out'
    else if (example==7) then
    !> Sodium-potassium exchnage
        file_chem_syst='intercambio_sist_quim.dat'
        file_loc_chem='intercambio_quim_loc.dat'
        file_tw='intercambio_tar_wat.dat'
        file_out='intercambio.out'
    else if (example==9) then
    !> Redox (using half-reactions)
        file_chem_syst='redox_SR_sist_quim.dat'
        file_loc_chem='redox_SR_quim_loc.dat'
        file_tw='redox_SR_tar_wat.dat'
        file_out='redox_SR.out'
    else
        error stop "Example not implemented yet"
    end if
!> Initialise transport
    option_tpt=1
    if (option_tpt==0) then
    !> we read transport data, BCs and discretisations
        !> in the explicit case, we also compute stability parameters
            call my_tpt_trans%initialise_transport_1D_transient_RT(path,file_BCs,file_space,file_time,file_tpt_props)
        !> we allocate transport arrays
            call my_tpt_trans%allocate_arrays_PDE_1D()
        !> we compute transport arrays, including mixing ratios, and we impose BCs
            call my_tpt_trans%compute_mixing_ratios_Delta_t_homog()
        !> we set transport attribute in reactive transport object
            call my_RT_trans%set_transport(my_tpt_trans)
        !> we choose and set integration method for chemical reactions
            int_method_chem=2
            call my_RT_trans%set_int_method_chem_reacts(int_method_chem)
    else if (option_tpt==1) then
    !> we read temporal discretisation
        call my_RT_trans%read_discretisation(path,unit_discr,file_discr)
    !> we read transport data for WMA
        call my_RT_trans%transport%read_transport_data_WMA(path,unit_tpt,file_tpt)
    else
        error stop "This option is not implemented yet"
    end if
!> Initialise chemistry
    option_chem=1 
    call my_chem%set_option(option_chem)
    opc_Jac=1
    call my_chem%set_Jac_flag(opc_Jac) 
    !> we read chemistry
    call my_chem%initialise_chemistry(path,unit_chem_syst,file_chem_syst,unit_loc_chem,file_loc_chem,unit_tw,file_tw)
    !> we set chemistry attribute in reactive transport object
    call my_RT_trans%set_chemistry(my_chem) 
!> We call the main solver
    call my_RT_trans%chemistry%solve_reactive_mixing(my_RT_trans%transport%mixing_ratios,my_RT_trans%transport%mixing_waters_indices,my_RT_trans%transport%F_mat,my_RT_trans%transport%time_discr,my_RT_trans%int_method_chem_reacts)
!> We write data and results
    call my_RT_trans%write_RT_1D(unit_out,file_out,path_py)
end program