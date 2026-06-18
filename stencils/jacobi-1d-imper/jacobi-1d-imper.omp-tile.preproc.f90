PROGRAM JACOBI1D
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: b
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(100000 + 0), STAT=i)
   call check_err(i)
   allocate(b(100000 + 0), STAT=i)
   call check_err(i)
   call init_array(100000, a, b)
   call polybench_timer_start()
   call kernel_jacobi1d(1000, 100000, a, b)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(100000, a)
   END IF
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, a, b)
      DOUBLE PRECISION, DIMENSION(n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: b
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      a(i) = (dble(i - 1) + 2.0d0) / n
      b(i) = (dble(i - 1) + 3.0d0) / n
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, a)
      DOUBLE PRECISION, DIMENSION(n) :: a
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") a(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_jacobi1d(tsteps, n, a, b)
      DOUBLE PRECISION, DIMENSION(n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: b
      INTEGER :: n, tsteps
      INTEGER :: i, t, j
      continue
      !DIR$ scop
      DO t = 1, tsteps
      DO i = 2, n - 1
      b(i) = 0.33333d0 * (a(i - 1) + a(i) + a(i + 1))
      
      END DO
      DO j = 2, n - 1
      a(j) = b(j)
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_jacobi1d
END PROGRAM JACOBI1D
