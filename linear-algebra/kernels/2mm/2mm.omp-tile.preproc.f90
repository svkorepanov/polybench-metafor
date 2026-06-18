PROGRAM TWO_MM
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: tmp
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: b
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: c
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: d
   DOUBLE PRECISION :: alpha, beta
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(tmp(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(a(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(b(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(c(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   allocate(d(2000 + 0, 2000 + 0), STAT=i)
   call check_err(i)
   call init_array(alpha, beta, a, b, c, d, 2000, 2000, 2000, 2000)
   call polybench_timer_start()
   call kernel_2mm(alpha, beta, tmp, a, b, c, d, 2000, 2000, 2000, 2000)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(d, 2000, 2000)
   END IF
   deallocate(tmp)
   deallocate(a)
   deallocate(b)
   deallocate(c)
   deallocate(d)
   contains
   SUBROUTINE init_array(alpha, beta, a, b, c, d, ni, nj, nk, nl)
      DOUBLE PRECISION, DIMENSION(nk, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nk) :: b
      DOUBLE PRECISION, DIMENSION(nl, nj) :: c
      DOUBLE PRECISION, DIMENSION(nl, ni) :: d
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj, nk, nl
      INTEGER :: i, j
      alpha = 32412
      beta = 2123
      DO i = 1, ni
      DO j = 1, nk
      a(j, i) = dble((i - 1) * (j - 1)) / ni
      
      END DO
      
      END DO
      DO i = 1, nk
      DO j = 1, nj
      b(j, i) = (dble((i - 1) * (j))) / nj
      
      END DO
      
      END DO
      DO i = 1, nl
      DO j = 1, nj
      c(j, i) = (dble(i - 1) * (j + 2)) / nl
      
      END DO
      
      END DO
      DO i = 1, ni
      DO j = 1, nl
      d(j, i) = (dble(i - 1) * (j + 1)) / nk
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(d, ni, nl)
      DOUBLE PRECISION, DIMENSION(nl, ni) :: d
      INTEGER :: nl, ni
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, nl
      WRITE(0, "(f0.2,1x)", advance="no") d(j, i)
      IF (mod(((i - 1) * ni) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_2mm(alpha, beta, tmp, a, b, c, d, ni, nj, nk, nl)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: tmp
      DOUBLE PRECISION, DIMENSION(nk, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nk) :: b
      DOUBLE PRECISION, DIMENSION(nl, nj) :: c
      DOUBLE PRECISION, DIMENSION(nl, ni) :: d
      DOUBLE PRECISION :: alpha, beta
      INTEGER :: ni, nj, nk, nl
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO ii = 1, ni, 32
      DO jj = 1, nj, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, nj)
      tmp(j, i) = 0.0
      DO k = 1, nk
      tmp(j, i) = tmp(j, i) + alpha * a(k, i) * b(j, k)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, ni, 32
      DO jj = 1, nl, 32
      DO i = ii, MIN(ii + 32 - 1, ni)
      DO j = jj, MIN(jj + 32 - 1, nl)
      d(j, i) = d(j, i) * beta
      DO k = 1, nj
      d(j, i) = d(j, i) + tmp(k, i) * c(j, k)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_2mm
END PROGRAM TWO_MM
