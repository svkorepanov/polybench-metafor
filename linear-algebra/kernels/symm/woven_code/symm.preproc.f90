PROGRAM SYMM
   DOUBLE PRECISION :: alpha, beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: c
   INTEGER :: i
   allocate(a(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(b(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(c(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   call init_array(128, 128, alpha, beta, c, a, b)
   call kernel_symm(128, 128, alpha, beta, c, a, b)
   call print_array(128, 128, c)
   deallocate(a)
   deallocate(b)
   deallocate(c)
   contains
   SUBROUTINE init_array(ni, nj, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nj, nj) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: b
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj
      INTEGER :: i, j
      alpha = 32412d0
      beta = 2123d0
      DO i = 1, ni
      DO j = 1, nj
      c(j, i) = ((dble((i - 1) * (j - 1)))) / dble(ni)
      b(j, i) = ((dble((i - 1) * (j - 1)))) / dble(ni)
      
      END DO
      
      END DO
      DO i = 1, nj
      DO j = 1, nj
      a(j, i) = (dble((i - 1) * (j - 1))) / dble(ni)
      
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
   
   SUBROUTINE kernel_symm(ni, nj, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nj, nj) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: b
      DOUBLE PRECISION, DIMENSION(nj, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      DOUBLE PRECISION :: acc
      INTEGER :: ni, nj
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 1, ni, 32
      DO jj = 1, nj, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, nj)
      acc = 0.0d0
      DO k = 1, j - 2
      c(j, k) = c(j, k) + (alpha * a(i, k) * b(j, i))
      
      END DO
      DO k = 1, j - 2
      acc = acc + (b(j, k) * a(i, k))
      
      END DO
      c(j, i) = (beta * c(j, i)) + (alpha * a(i, i) * b(j, i)) + (alpha * acc)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_symm
END PROGRAM SYMM
