PROGRAM CHOLESKY
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: p
   DOUBLE PRECISION :: x
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(p(2000 + 0), STAT=i)
   call check_err(i)
   call init_array(2000, p, a)
   call polybench_timer_start()
   call kernel_cholesky(2000, p, a)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(2000, a)
   END IF
   deallocate(a)
   deallocate(p)
   contains
   SUBROUTINE init_array(n, p, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: p
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      p(i) = 1.0d0 / n
      DO j = 1, n
      a(j, i) = 1.0d0 / n
      
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
      IF (mod(((i - 1) * n) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_cholesky(n, p, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: p
      DOUBLE PRECISION :: x
      INTEGER :: n
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO i = 1, n
      x = a(i, i)
      DO j = 1, i - 1
      x = x - a(j, i) * a(j, i)
      
      END DO
      p(i) = 1.0d0 / sqrt(x)
      DO j = i + 1, n
      x = a(j, i)
      DO k = 1, i - 1
      x = x - (a(k, j) * a(k, i))
      
      END DO
      a(i, j) = x * p(i)
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_cholesky
END PROGRAM CHOLESKY
