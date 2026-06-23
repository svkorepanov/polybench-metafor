PROGRAM ADI
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(x(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(a(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(b(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   call init_array(2000, x, a, b)
   call polybench_timer_start()
   call kernel_adi(50, 2000, x, a, b)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(2000, x)
   END IF
   deallocate(x)
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, x, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: x
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      x(j, i) = (dble((i - 1) * (j)) + 1.0d0) / dble(n)
      a(j, i) = (dble((i - 1) * (j + 1)) + 2.0d0) / dble(n)
      b(j, i) = (dble((i - 1) * (j + 2)) + 3.0d0) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, x)
      DOUBLE PRECISION, DIMENSION(n, n) :: x
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") x(j, i)
      IF (mod(((i - 1) * n) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_adi(tsteps, n, x, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: x
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n, tsteps
      INTEGER :: i1, i2, t
      continue
      !DIR$ scop
      DO t = 1, tsteps
      DO i1i1 = 1, n, 32
      DO i2i2 = 2, n, 32
      DO i1 = i1i1, MIN(i1i1 + 32 - 1, n)
      DO i2 = i2i2, MIN(i2i2 + 32 - 1, n)
      x(i2, i1) = x(i2, i1) - ((x(i2 - 1, i1) * a(i2, i1)) / b(i2 - 1, i1))
      b(i2, i1) = b(i2, i1) - ((a(i2, i1) * a(i2, i1)) / b(i2 - 1, i1))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i1 = 1, n
      x(n, i1) = x(n, i1) / b(n, i1)
      
      END DO
      DO i1i1 = 1, n, 32
      DO i2i2 = 1, n - 2, 32
      DO i1 = i1i1, MIN(i1i1 + 32 - 1, n)
      DO i2 = i2i2, MIN(i2i2 + 32 - 1, n - 2)
      x(n - i2, i1) = (x(n - i2, i1) - (x(n - i2 - 1, i1) * a(n - i2 - 1, i1))) / b(n - i2 - 1, i1)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i1i1 = 2, n, 32
      DO i2i2 = 1, n, 32
      DO i1 = i1i1, MIN(i1i1 + 32 - 1, n)
      DO i2 = i2i2, MIN(i2i2 + 32 - 1, n)
      x(i2, i1) = x(i2, i1) - x(i2, i1 - 1) * a(i2, i1) / b(i2, i1 - 1)
      b(i2, i1) = b(i2, i1) - a(i2, i1) * a(i2, i1) / b(i2, i1 - 1)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i2 = 1, n
      x(i2, n) = x(i2, n) / b(i2, n)
      
      END DO
      DO i1i1 = 1, n - 2, 32
      DO i2i2 = 1, n, 32
      DO i1 = i1i1, MIN(i1i1 + 32 - 1, n - 2)
      DO i2 = i2i2, MIN(i2i2 + 32 - 1, n)
      x(i2, n - i1) = (x(i2, n - i1) - x(i2, n - i1 - 1) * a(i2, n - i1 - 1)) / b(i2, n - i1)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_adi
END PROGRAM ADI
