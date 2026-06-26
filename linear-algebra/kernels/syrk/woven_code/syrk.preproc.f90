PROGRAM SYRK
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION :: beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: c
   INTEGER :: i
   allocate(a(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(c(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   call init_array(128, 128, alpha, beta, c, a)
   call kernel_syrk(128, 128, alpha, beta, c, a)
   call print_array(128, c)
   deallocate(a)
   deallocate(c)
   contains
   SUBROUTINE init_array(ni, nj, alpha, beta, c, a)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: nj, ni
      INTEGER :: i, j
      alpha = 32412
      beta = 2123
      DO i = 1, ni
      DO j = 1, nj
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(ni)
      
      END DO
      DO j = 1, ni
      c(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(ni, c)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: c
      INTEGER :: ni
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, ni
      WRITE(0, "(f0.2,1x)", advance="no") c(j, i)
      IF (mod(((i - 1) * ni) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_syrk(ni, nj, alpha, beta, c, a)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: nj, ni
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 1, ni, 32
      DO jj = 1, ni, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, ni)
      c(j, i) = c(j, i) * beta
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, ni, 32
      DO jj = 1, ni, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, ni)
      DO k = 1, nj
      c(j, i) = c(j, i) + (alpha * a(k, i) * a(k, j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_syrk
END PROGRAM SYRK
