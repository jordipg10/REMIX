        !COMPILER-GENERATED INTERFACE MODULE: Mon Sep  2 18:22:28 2024
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE ID_MATRIX__genmod
          INTERFACE 
            FUNCTION ID_MATRIX(N)
              INTEGER(KIND=4), INTENT(IN) :: N
              REAL(KIND=8) :: ID_MATRIX(N,N)
            END FUNCTION ID_MATRIX
          END INTERFACE 
        END MODULE ID_MATRIX__genmod
