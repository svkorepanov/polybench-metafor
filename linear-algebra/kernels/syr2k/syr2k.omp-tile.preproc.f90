PROGRAM SYR2K
   DOUBLE PRECISION :: alpha
   DOUBLE PRECISION :: beta
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: c
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(b(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(c(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   call init_array(2000, 2000, alpha, beta, c, a, b)
   call polybench_timer_start()
   call kernel_syr2k(2000, 2000, alpha, beta, c, a, b)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(2000, c)
   END IF
   deallocate(a)
   deallocate(b)
   deallocate(c)
   contains
   SUBROUTINE init_array(ni, nj, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: b
      DOUBLE PRECISION, DIMENSION(ni, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj
      INTEGER :: i, j
      alpha = 32412.0d0
      beta = 2123.0d0
      DO i = 1, ni
      DO j = 1, nj
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(ni)
      b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
      DO i = 1, ni
      DO j = 1, ni
      c(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(ni)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(ni, c)
      DOUBLE PRECISION, DIMENSION(ni, ni) :: c
      INTEGER :: ni
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, ni
      WRITE(0, "(f0.2,1x)", advance="no") c(j, i)
      IF (mod(((i - 1) * ni) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_syr2k(ni, nj, alpha, beta, c, a, b)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, ni) :: b
      DOUBLE PRECISION, DIMENSION(ni, ni) :: c
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 1, ni, 32
      DO jj = 1, ni, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, ni)
      c(j, i) = c(j, i) * beta
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, ni, 32
      DO jj = 1, ni, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, ni)
      DO k = 1, ni
      c(j, i) = c(j, i) + (alpha * a(k, i) * b(k, j))
      c(j, i) = c(j, i) + (alpha * b(k, i) * a(k, j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_syr2k
END PROGRAM SYR2K
