PROGRAM BICG
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: r
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: s
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: p
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: q
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(a(8000 + 0, 8000 + 0), STAT=i)
   call check_err(i)
   allocate(r(8000 + 0), STAT=i)
   call check_err(i)
   allocate(s(8000 + 0), STAT=i)
   call check_err(i)
   allocate(p(8000 + 0), STAT=i)
   call check_err(i)
   allocate(q(8000 + 0), STAT=i)
   call check_err(i)
   call init_array(8000, 8000, a, r, p)
   call polybench_timer_start()
   call kernel_bicg(8000, 8000, a, s, q, p, r)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(8000, 8000, s, q)
   END IF
   deallocate(a)
   deallocate(r)
   deallocate(s)
   deallocate(p)
   deallocate(q)
   contains
   SUBROUTINE init_array(nx, ny, a, r, p)
      DOUBLE PRECISION :: m_pi
      PARAMETER (m_pi = 3.14159265358979323846d0)
      DOUBLE PRECISION, DIMENSION(ny, nx) :: a
      DOUBLE PRECISION, DIMENSION(nx) :: r
      DOUBLE PRECISION, DIMENSION(ny) :: p
      INTEGER :: nx, ny
      INTEGER :: i, j
      DO i = 1, ny
      p(i) = dble(i - 1) * m_pi
      
      END DO
      DO i = 1, nx
      r(i) = dble(i - 1) * m_pi
      DO j = 1, ny
      a(j, i) = (dble(i - 1) * dble(j)) / nx
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(nx, ny, s, q)
      DOUBLE PRECISION, DIMENSION(ny) :: s
      DOUBLE PRECISION, DIMENSION(nx) :: q
      INTEGER :: nx, ny
      INTEGER :: i
      DO i = 1, ny
      WRITE(0, "(f0.2,1x)", advance="no") s(i)
      IF (mod(i - 1, 80) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      DO i = 1, nx
      WRITE(0, "(f0.2,1x)", advance="no") q(i)
      IF (mod(i - 1, 80) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_bicg(nx, ny, a, s, q, p, r)
      DOUBLE PRECISION, DIMENSION(ny, nx) :: a
      DOUBLE PRECISION, DIMENSION(nx) :: r
      DOUBLE PRECISION, DIMENSION(nx) :: q
      DOUBLE PRECISION, DIMENSION(ny) :: p
      DOUBLE PRECISION, DIMENSION(ny) :: s
      INTEGER :: nx, ny
      INTEGER :: i, j
      continue
      !DIR$ scop
      DO i = 1, ny
      s(i) = 0.0d0
      
      END DO
      DO i = 1, nx
      q(i) = 0.0d0
      DO j = 1, ny
      s(j) = s(j) + (r(i) * a(j, i))
      q(i) = q(i) + (a(j, i) * p(j))
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_bicg
END PROGRAM BICG
