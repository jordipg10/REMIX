!> Computes chemical part of aqueous concentrations for a reactive mixing Euler explicit iteration assuming there are only kinetic reactions
subroutine reaction_iteration_EE_kin_aq_chem(this,porosity,Delta_t,conc_react)
    use aqueous_chemistry_m
    implicit none
!> Arguments
    class(aqueous_chemistry_c) :: this
    real(kind=8), intent(in) :: porosity !> porosity
    real(kind=8), intent(in) :: Delta_t !> time step
    real(kind=8), intent(out) :: conc_react(:) !> reaction part of concentrations (must be already allocated)
!> Process
    call this%compute_rk() !> we compute kinetic reactions rates
    conc_react=Delta_t*matmul(transpose(this%chem_syst%Sk),this%rk)/porosity
end subroutine