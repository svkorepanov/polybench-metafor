PROGRAM GEMM
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION :: beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: c
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   INTEGER :: i
   allocate(c(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(a(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(b(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   call init_array(128, 128, 128, alpha, beta, c, a, b)
   call kernel_gemm(128, 128, 128, alpha, beta, c, a, b)
   call print_array(128, 128, c)
   deallocate(c)
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(ni, nj, nk, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nk, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nk) :: b
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj, nk
      INTEGER :: i, j
      alpha = 32412
      beta = 2123
      DO i = 1, ni
      DO j = 1, nj
      c(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
      DO i = 1, ni
      DO j = 1, nk
      a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
      DO i = 1, nk
      DO j = 1, nj
      b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(ni, nj, c)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      INTEGER :: ni, nj
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, nj
      WRITE(0, "(f0.2,1x)", advance="no") c(j, i)
      IF (mod(((i - 1) * ni) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_gemm(ni, nj, nk, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nk, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nk) :: b
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj, nk
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 1, ni, 32
      DO jj = 1, nj, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, nj)
      c(j, i) = c(j, i) * beta
      DO k = 1, nk
      c(j, i) = c(j, i) + (alpha * a(k, i) * b(j, k))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_gemm
END PROGRAM GEMM
