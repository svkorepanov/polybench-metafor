PROGRAM TRISOLV
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: c
   INTEGER :: n = 8000, i
   CHARACTER(LEN = 30) :: arg
   allocate(a(n + 0, n + 0), STAT=i)
   call check_err(i)
   allocate(x(n + 0), STAT=i)
   call check_err(i)
   allocate(c(n + 0), STAT=i)
   call check_err(i)
   call init_array(n, a, x, c)
   call polybench_timer_start()
   call kernel_trisolv(n, a, x, c)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(n, x)
   END IF
   deallocate(a)
   deallocate(x)
   deallocate(c)
   contains
   SUBROUTINE init_array(n, a, x, c)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: c
      DOUBLE PRECISION, DIMENSION(n) :: x
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      c(i) = dble(i - 1) / dble(n)
      x(i) = dble(i - 1) / dble(n)
      DO j = 1, n
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, x)
      DOUBLE PRECISION, DIMENSION(n) :: x
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") x(i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_trisolv(n, a, x, c)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: c
      DOUBLE PRECISION, DIMENSION(n) :: x
      INTEGER :: n
      INTEGER :: i, j
      continue
      !DIR$ scop
      DO i = 1, n
      x(i) = c(i)
      DO j = 1, i - 1
      x(i) = x(i) - (a(j, i) * x(j))
      
      END DO
      x(i) = x(i) / a(i, i)
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_trisolv
END PROGRAM TRISOLV
