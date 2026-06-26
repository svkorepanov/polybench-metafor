PROGRAM GEMVER
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION :: beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: u1
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: u2
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: v1
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: v2
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: w
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: z
   INTEGER :: n = 500, i
   allocate(a(n + 0, n + 0), STAT=i)
   call check_err(i)
   allocate(u1(n + 0), STAT=i)
   call check_err(i)
   allocate(u2(n + 0), STAT=i)
   call check_err(i)
   allocate(v1(n + 0), STAT=i)
   call check_err(i)
   allocate(v2(n + 0), STAT=i)
   call check_err(i)
   allocate(w(n + 0), STAT=i)
   call check_err(i)
   allocate(x(n + 0), STAT=i)
   call check_err(i)
   allocate(y(n + 0), STAT=i)
   call check_err(i)
   allocate(z(n + 0), STAT=i)
   call check_err(i)
   call init_array(n, alpha, beta, a, u1, u2, v1, v2, w, x, y, z)
   call kernel_gemver(n, alpha, beta, a, u1, v1, u2, v2, w, x, y, z)
   call print_array(n, w)
   deallocate(a)
   deallocate(u1)
   deallocate(u2)
   deallocate(v1)
   deallocate(v2)
   deallocate(w)
   deallocate(x)
   deallocate(y)
   deallocate(z)
   contains
   SUBROUTINE init_array(n, alpha, beta, a, u1, u2, v1, v2, w, x, y, z)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: u1
      DOUBLE PRECISION, DIMENSION(n) :: u2
      DOUBLE PRECISION, DIMENSION(n) :: v1
      DOUBLE PRECISION, DIMENSION(n) :: v2
      DOUBLE PRECISION, DIMENSION(n) :: w
      DOUBLE PRECISION, DIMENSION(n) :: x
      DOUBLE PRECISION, DIMENSION(n) :: y
      DOUBLE PRECISION, DIMENSION(n) :: z
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: n
      INTEGER :: i, j
      alpha = 43532.0d0
      beta = 12313.0d0
      DO i = 1, n
      u1(i) = dble(i - 1)
      u2(i) = dble(i / n) / 2.0d0
      v1(i) = dble(i / n) / 4.0d0
      v2(i) = dble(i / n) / 6.0d0
      y(i) = dble(i / n) / 8.0d0
      z(i) = dble(i / n) / 9.0d0
      x(i) = 0.0d0
      w(i) = 0.0d0
      DO j = 1, n
      a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, w)
      DOUBLE PRECISION, DIMENSION(n) :: w
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") w(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_gemver(n, alpha, beta, a, u1, v1, u2, v2, w, x, y, z)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: u1
      DOUBLE PRECISION, DIMENSION(n) :: u2
      DOUBLE PRECISION, DIMENSION(n) :: v1
      DOUBLE PRECISION, DIMENSION(n) :: v2
      DOUBLE PRECISION, DIMENSION(n) :: w
      DOUBLE PRECISION, DIMENSION(n) :: x
      DOUBLE PRECISION, DIMENSION(n) :: y
      DOUBLE PRECISION, DIMENSION(n) :: z
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: n
      INTEGER :: i, j
      continue
      !DIR$ scop
      DO ii = 1, n, 32
      DO jj = 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      a(j, i) = a(j, i) + (u1(i) * v1(j)) + (u2(i) * v2(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, n, 32
      DO jj = 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      x(i) = x(i) + (beta * a(i, j) * y(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i = 1, n
      x(i) = x(i) + z(i)
      
      END DO
      DO ii = 1, n, 32
      DO jj = 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      w(i) = w(i) + (alpha * a(j, i) * x(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_gemver
END PROGRAM GEMVER
