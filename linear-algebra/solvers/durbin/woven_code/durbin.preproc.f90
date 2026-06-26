PROGRAM DURBIN
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: y
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: sumarray
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: beta
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: alpha
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: r
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: outarray
   INTEGER :: i
   allocate(y(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(sumarray(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(beta(500 + 0), STAT=i)
   call check_err(i)
   allocate(alpha(500 + 0), STAT=i)
   call check_err(i)
   allocate(r(500 + 0), STAT=i)
   call check_err(i)
   allocate(outarray(500 + 0), STAT=i)
   call check_err(i)
   call init_array(500, y, sumarray, alpha, beta, r)
   call kernel_durbin(500, y, sumarray, alpha, beta, r, outarray)
   call print_array(500, outarray)
   deallocate(y)
   deallocate(sumarray)
   deallocate(beta)
   deallocate(alpha)
   deallocate(r)
   deallocate(outarray)
   contains
   SUBROUTINE init_array(n, y, sumarray, alpha, beta, r)
      DOUBLE PRECISION, DIMENSION(n, n) :: y
      DOUBLE PRECISION, DIMENSION(n, n) :: sumarray
      DOUBLE PRECISION, DIMENSION(n) :: beta
      DOUBLE PRECISION, DIMENSION(n) :: alpha
      DOUBLE PRECISION, DIMENSION(n) :: r
      INTEGER :: i, j
      INTEGER :: n
      DO i = 1, n
      alpha(i) = i
      beta(i) = (i / n) / dble(2.0)
      r(i) = (i / n) / dble(4.0)
      DO j = 1, n
      y(j, i) = dble(i * j) / dble(n)
      sumarray(j, i) = dble(i * j) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, outarray)
      DOUBLE PRECISION, DIMENSION(n) :: outarray
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") outarray(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_durbin(n, y, sumarray, alpha, beta, r, outarray)
      DOUBLE PRECISION, DIMENSION(n, n) :: y
      DOUBLE PRECISION, DIMENSION(n, n) :: sumarray
      DOUBLE PRECISION, DIMENSION(n) :: beta
      DOUBLE PRECISION, DIMENSION(n) :: alpha
      DOUBLE PRECISION, DIMENSION(n) :: r
      DOUBLE PRECISION, DIMENSION(n) :: outarray
      INTEGER :: i, k, n
      continue
      !DIR$ scop
      y(1, 1) = r(1)
      beta(1) = 1
      alpha(1) = r(1)
      DO k = 2, n
      beta(k) = beta(k - 1) - (alpha(k - 1) * alpha(k - 1) * beta(k - 1))
      sumarray(k, 1) = r(k)
      DO i = 1, k - 1
      sumarray(k, i + 1) = sumarray(k, i) + (r(k - i) * y(k - 1, i))
      
      END DO
      alpha(k) = alpha(k) - (sumarray(k, k) * beta(k))
      DO i = 1, k - 1
      y(k, i) = y(k - 1, i) + (alpha(k) * y(k - 1, k - i))
      
      END DO
      y(k, k) = alpha(k)
      
      END DO
      DO i = 1, n
      outarray(i) = y(n, i)
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_durbin
END PROGRAM DURBIN
