PROGRAM JACOBI2D
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   INTEGER :: i
   allocate(a(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(b(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   call init_array(500, a, b)
   call kernel_jacobi_2d_imper(10, 500, a, b)
   call print_array(500, a)
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      a(j, i) = (dble(i - 1) * dble(j + 1) + 2.0d0) / n
      b(j, i) = (dble(i - 1) * dble(j + 2) + 3.0d0) / n
      
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
   
   SUBROUTINE kernel_jacobi_2d_imper(tsteps, n, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n, tsteps
      INTEGER :: i, j, t
      continue
      !DIR$ scop
      DO t = 1, tsteps
      DO ii = 2, n - 1, 32
      DO jj = 2, n - 1, 32
      DO i = ii, MIN(ii + 32 - 1, n - 1)
      DO j = jj, MIN(jj + 32 - 1, n - 1)
      b(j, i) = 0.2d0 * (a(j, i) + a(j - 1, i) + a(1 + j, i) + a(j, 1 + i) + a(j, i - 1))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 2, n - 1, 32
      DO jj = 2, n - 1, 32
      DO i = ii, MIN(ii + 32 - 1, n - 1)
      DO j = jj, MIN(jj + 32 - 1, n - 1)
      a(j, i) = b(j, i)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_jacobi_2d_imper
END PROGRAM JACOBI2D
