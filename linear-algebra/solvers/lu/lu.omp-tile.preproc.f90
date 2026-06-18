PROGRAM LU
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   call init_array(2000, a)
   call polybench_timer_start()
   call kernel_lu(2000, a)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(2000, a)
   END IF
   deallocate(a)
   contains
   SUBROUTINE init_array(n, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      a(j, i) = (dble(i) * dble(j)) / dble(n)
      
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
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_lu(n, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      INTEGER :: n
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO k = 1, n
      DO j = k + 1, n
      a(j, k) = a(j, k) / a(k, k)
      
      END DO
      DO ii = k + 1, n, 32
      DO jj = k + 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      a(j, i) = a(j, i) - (a(k, i) * a(j, k))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_lu
END PROGRAM LU
