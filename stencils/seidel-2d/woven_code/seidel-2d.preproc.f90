PROGRAM SEIDEL
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   INTEGER :: i
   allocate(a(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   call init_array(500, a)
   call kernel_seidel(10, 500, a)
   call print_array(500, a)
   deallocate(a)
   contains
   SUBROUTINE init_array(n, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      a(j, i) = ((dble(i - 1) * dble(j + 1)) + 2.0d0) / n
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") a(j, i)
      IF (mod((i - 1) * n + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_seidel(tsteps, n, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      INTEGER :: n, tsteps
      INTEGER :: i, t, j
      continue
      !DIR$ scop
      DO tt = 1, tsteps, 32
      DO ii = 2, n - 1, 32
      DO t = tt, MIN(tt + 32 - 1, tsteps)
      DO i = ii, MIN(ii + 32 - 1, n - 1)
      DO j = 2, n - 1
      a(j, i) = (a(j - 1, i - 1) + a(j, i - 1) + a(j + 1, i - 1) + a(j - 1, i) + a(j, i) + a(j + 1, i) + a(j - 1, i + 1) + a(j, i + 1) + a(j + 1, i + 1)) / 9.0d0
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_seidel
END PROGRAM SEIDEL
