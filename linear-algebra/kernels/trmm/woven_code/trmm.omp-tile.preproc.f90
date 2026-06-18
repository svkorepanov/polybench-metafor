PROGRAM TRMM
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   INTEGER :: ni = 128, i
   allocate(a(ni + 0, ni + 0), STAT=i)
   call check_err(i)
   allocate(b(ni + 0, ni + 0), STAT=i)
   call check_err(i)
   call init_array(ni, alpha, a, b)
   call kernel_trmm(ni, alpha, a, b)
   call print_array(ni, b)
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, alpha, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      DOUBLE PRECISION :: alpha
      INTEGER :: n
      INTEGER :: i, j
      alpha = 32412d0
      DO i = 1, n
      DO j = 1, n
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
      b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") b(j, i)
      IF (mod(((i - 1) * n) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_trmm(ni, alpha, a, b)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: a
      DOUBLE PRECISION, DIMENSION(ni, ni) :: b
      DOUBLE PRECISION :: alpha
      INTEGER :: ni
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 2, ni, 32
      DO jj = 1, ni, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, ni)
      DO k = 1, i - 1
      b(j, i) = b(j, i) + (alpha * a(k, i) * b(k, j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_trmm
END PROGRAM TRMM
