        !COMPILER-GENERATED INTERFACE MODULE: Thu Jun 12 16:51:49 2025
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE READ_SPECIES__genmod
          INTERFACE 
            SUBROUTINE READ_SPECIES(THIS,STR)
              USE SPECIES_M, ONLY :                                     &
     &          SPECIES_C
              CLASS (SPECIES_C) :: THIS
              CHARACTER(*), INTENT(IN) :: STR
            END SUBROUTINE READ_SPECIES
          END INTERFACE 
        END MODULE READ_SPECIES__genmod
