PROGRAM TRMM
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   INTEGER :: ni = 2000, i
   CHARACTER(LEN = 30) :: arg
   allocate(a(ni + 0, ni + 0), STAT=i)
   call check_err(i)
   allocate(b(ni + 0, ni + 0), STAT=i)
   call check_err(i)
   call init_array(ni, alpha, a, b)
   call polybench_timer_start()
   call kernel_trmm(ni, alpha, a, b)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(ni, b)
   END IF
   deallocate(a)
   deallocate(b)
   contains
   SUBROUTINE init_array(n, alpha, a, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      DOUBLE PRECISION :: alpha
      INTEGER :: n
      INTEGER :: i, j
      alpha = 32412d0
      DO i = 1, n
      DO j = 1, n
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
      b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, b)
      DOUBLE PRECISION, DIMENSION(n, n) :: b
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      DO j = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") b(j, i)
      IF (mod(((i - 1) * n) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_trmm(ni, alpha, a, b)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: a
      DOUBLE PRECISION, DIMENSION(ni, ni) :: b
      DOUBLE PRECISION :: alpha
      INTEGER :: ni
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO i = 2, ni
      DO jj = 1, ni, 32
      DO kk = 1, i - 1, 32
      DO j = jj, MIN(jj + 32 - 1, ni)
      DO k = kk, MIN(kk + 32 - 1, i - 1)
      b(j, i) = b(j, i) + (alpha * a(k, i) * b(k, j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_trmm
END PROGRAM TRMM
