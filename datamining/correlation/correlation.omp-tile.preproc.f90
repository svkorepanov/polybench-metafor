PROGRAM CORRELATION
   DOUBLE PRECISION :: float_n
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: dat
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: symmat
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: stddev
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: mean
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(dat(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(symmat(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(stddev(2000 + 0), STAT=i)
   call check_err(i)
   allocate(mean(2000 + 0), STAT=i)
   call check_err(i)
   call init_array(2000, 2000, float_n, dat)
   call polybench_timer_start()
   call kernel_correlation(2000, 2000, float_n, dat, symmat, mean, stddev)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(2000, symmat)
   END IF
   deallocate(dat)
   deallocate(symmat)
   deallocate(stddev)
   deallocate(mean)
   contains
   SUBROUTINE init_array(m, n, float_n, dat)
      DOUBLE PRECISION, DIMENSION(2000, 2000) :: dat
      DOUBLE PRECISION :: float_n
      INTEGER :: m, n
      INTEGER :: i, j
      float_n = 1.2d0
      DO i = 1, m
      DO j = 1, n
      dat(j, i) = (dble(i - 1) * dble(j - 1)) / dble(m)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(m, symmat)
      DOUBLE PRECISION, DIMENSION(2000, 2000) :: symmat
      INTEGER :: m
      INTEGER :: i, j
      DO i = 1, m
      DO j = 1, m
      WRITE(0, "(f0.2,1x)", advance="no") symmat(j, i)
      IF (mod(((i - 1) * m) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_correlation(m, n, float_n, dat, symmat, mean, stddev)
      DOUBLE PRECISION, DIMENSION(n, m) :: dat
      DOUBLE PRECISION, DIMENSION(m, m) :: symmat
      DOUBLE PRECISION, DIMENSION(m) :: stddev
      DOUBLE PRECISION, DIMENSION(m) :: mean
      DOUBLE PRECISION :: float_n, eps
      INTEGER :: m, n
      INTEGER :: i, j, j1, j2
      eps = 0.1d0
      continue
      !DIR$ scop
      DO j = 1, m
      mean(j) = 0.0d0
      DO i = 1, n
      mean(j) = mean(j) + dat(j, i)
      
      END DO
      mean(j) = mean(j) / float_n
      
      END DO
      DO j = 1, m
      stddev(j) = 0.0d0
      DO i = 1, n
      stddev(j) = stddev(j) + (dat(j, i) - mean(j)) * (dat(j, i) - mean(j))
      
      END DO
      stddev(j) = stddev(j) / float_n
      stddev(j) = sqrt(stddev(j))
      IF (stddev(j) <= eps) THEN
         stddev(j) = 1.0d0
      END IF
      
      END DO
      DO ii = 1, n, 32
      DO jj = 1, m, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, m)
      dat(j, i) = dat(j, i) - mean(j)
      dat(j, i) = dat(j, i) / (sqrt(float_n) * stddev(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO j1 = 1, m - 1
      symmat(j1, j1) = 1.0d0
      DO j2 = j1 + 1, m
      symmat(j2, j1) = 0.0d0
      DO i = 1, n
      symmat(j2, j1) = symmat(j2, j1) + (dat(j1, i) * dat(j2, i))
      
      END DO
      symmat(j1, j2) = symmat(j2, j1)
      
      END DO
      
      END DO
      symmat(m, m) = 1.0d0
      !DIR$ end scop
   END SUBROUTINE kernel_correlation
END PROGRAM CORRELATION
