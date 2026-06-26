PROGRAM LUDCMP
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: b
   INTEGER :: i
   allocate(a(128 + 1 + 0, 128 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(x(128 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(y(128 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(b(128 + 1 + 0), STAT=i)
   call check_err(i)
   call init_array(128, a, b, x, y)
   call kernel_ludcmp(128, a, b, x, y)
   call print_array(128, x)
   deallocate(a)
   deallocate(x)
   deallocate(y)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, a, b, x, y)
      DOUBLE PRECISION, DIMENSION(n + 1, n + 1) :: a
      DOUBLE PRECISION, DIMENSION(n + 1) :: x
      DOUBLE PRECISION, DIMENSION(n + 1) :: b
      DOUBLE PRECISION, DIMENSION(n + 1) :: y
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n + 1
      x(i) = dble(i)
      y(i) = (i / n / 2.0d0) + 1.0d0
      b(i) = (i / n / 2.0d0) + 42.0d0
      DO j = 1, n + 1
      a(j, i) = (dble(i) * dble(j)) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, x)
      DOUBLE PRECISION, DIMENSION(n + 1) :: x
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n + 1
      WRITE(0, "(f0.2,1x)", advance="no") x(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_ludcmp(n, a, b, x, y)
      DOUBLE PRECISION, DIMENSION(n + 1, n + 1) :: a
      DOUBLE PRECISION, DIMENSION(n + 1) :: x
      DOUBLE PRECISION, DIMENSION(n + 1) :: b
      DOUBLE PRECISION, DIMENSION(n + 1) :: y
      DOUBLE PRECISION :: w
      INTEGER :: n
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      b(1) = 1.0d0
      DO i = 1, n
      DO j = i + 1, n + 1
      w = a(i, j)
      DO k = 1, i - 1
      w = w - (a(k, j) * a(i, k))
      
      END DO
      a(i, j) = w / a(i, i)
      
      END DO
      DO j = i + 1, n + 1
      w = a(j, i + 1)
      DO k = 1, i
      w = w - (a(k, i + 1) * a(j, k))
      
      END DO
      a(j, i + 1) = w
      
      END DO
      
      END DO
      y(1) = b(1)
      DO i = 2, n + 1
      w = b(i)
      DO j = 1, i - 1
      w = w - (a(j, i) * y(j))
      
      END DO
      y(i) = w
      
      END DO
      x(n + 1) = y(n + 1) / a(n + 1, n + 1)
      DO i = 1, n
      w = y(n + 1 - i)
      DO j = n + 2 - i, n + 1
      w = w - (a(j, n + 1 - i) * x(j))
      
      END DO
      x(n + 1 - i) = w / a(n + 1 - i, n + 1 - i)
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_ludcmp
END PROGRAM LUDCMP
