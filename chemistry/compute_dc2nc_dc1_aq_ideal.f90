 !> Computes Jacobian of secondary species concentrations assuming constant activity coefficients
!> \f$\partial c_{2} / \partial c_1\f$ with \f$gamma\f$ constant
!! We assume all primary species are aqueous
subroutine compute_dc2nc_dc1_aq_ideal(this,c2nc,dc2nc_dc1)
    use aqueous_chemistry_m
    implicit none
!> Arguments
    class(aqueous_chemistry_c), intent(in) :: this
    real(kind=8), intent(in) :: c2nc(:) !> chapuza (dim=n_eq)
    real(kind=8), intent(out) :: dc2nc_dc1(:,:)
!> Variables
    integer(kind=4) :: i,j    
!> Process
    !print *, this%speciation_alg%Se_nc_1_star
    do i=1,this%speciation_alg%num_eq_reactions
        do j=1,this%speciation_alg%num_prim_species
            dc2nc_dc1(i,j)=c2nc(i)*this%speciation_alg%Se_nc_1_star(i,j)/this%concentrations(j)
        end do
    end do
end subroutine