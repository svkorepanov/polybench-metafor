PROGRAM GESUMMV
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION :: beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: tmp
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(8000 + 0, 8000 + 0), STAT=i)
   call check_err(i)
   allocate(b(8000 + 0, 8000 + 0), STAT=i)
   call check_err(i)
   allocate(x(8000 + 0), STAT=i)
   call check_err(i)
   allocate(y(8000 + 0), STAT=i)
   call check_err(i)
   allocate(tmp(8000 + 0), STAT=i)
   call check_err(i)
   call init_array(8000, alpha, beta, a, b, x)
   call polybench_timer_start()
   call kernel_gesummv(8000, alpha, beta, a, b, tmp, x, y)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(8000, y)
   END IF
   deallocate(a)
   deallocate(b)
   deallocate(x)
   deallocate(y)
   deallocate(tmp)
   contains
   SUBROUTINE init_array(n, alpha, beta, a, b, x)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      DOUBLE PRECISION, DIMENSION(n) :: x
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: n
      INTEGER :: i, j
      alpha = 43532.0d0
      beta = 12313.0d0
      DO i = 1, n
      x(i) = dble(i - 1) / dble(n)
      DO j = 1, n
      a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, y)
      DOUBLE PRECISION, DIMENSION(n) :: y
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") y(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_gesummv(n, alpha, beta, a, b, tmp, x, y)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      DOUBLE PRECISION, DIMENSION(n) :: x, y, tmp
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: n
      INTEGER :: i, j
      continue
      !DIR$ scop
      DO i = 1, n
      tmp(i) = 0.0d0
      y(i) = 0.0d0
      DO j = 1, n
      tmp(i) = (a(j, i) * x(j)) + tmp(i)
      y(i) = (b(j, i) * x(j)) + y(i)
      
      END DO
      y(i) = (alpha * tmp(i)) + (beta * y(i))
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_gesummv
END PROGRAM GESUMMV
