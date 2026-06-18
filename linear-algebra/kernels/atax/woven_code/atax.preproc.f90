PROGRAM ATAX
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: tmp
   INTEGER :: nx = 8000, ny = 8000, i
   CHARACTER(LEN = 30) :: arg
   allocate(a(ny + 0, nx + 0), STAT=i)
   call check_err(i)
   allocate(x(ny + 0), STAT=i)
   call check_err(i)
   allocate(y(nx + 0), STAT=i)
   call check_err(i)
   allocate(tmp(ny + 0), STAT=i)
   call check_err(i)
   call init_array(a, x, nx, ny)
   call polybench_timer_start()
   call kernel_atax(nx, ny, a, x, y, tmp)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(y, ny)
   END IF
   deallocate(a)
   deallocate(x)
   deallocate(y)
   deallocate(tmp)
   contains
   SUBROUTINE init_array(a, x, nx, ny)
      DOUBLE PRECISION :: m_pi
      PARAMETER (m_pi = 3.14159265358979323846d0)
      DOUBLE PRECISION, DIMENSION(ny, nx) :: a
      DOUBLE PRECISION, DIMENSION(ny) :: x
      INTEGER :: nx, ny
      INTEGER :: i, j
      DO i = 1, ny
      x(i) = dble(i - 1) * m_pi
      DO j = 1, ny
      a(j, i) = (dble((i - 1) * (j))) / nx
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(y, ny)
      DOUBLE PRECISION, DIMENSION(ny) :: y
      INTEGER :: ny
      INTEGER :: i
      DO i = 1, ny
      WRITE(0, "(f0.2,1x)", advance="no") y(i)
      IF (mod(i - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_atax(nx, ny, a, x, y, tmp)
      DOUBLE PRECISION, DIMENSION(ny, nx) :: a
      DOUBLE PRECISION, DIMENSION(ny) :: x
      DOUBLE PRECISION, DIMENSION(ny) :: y
      DOUBLE PRECISION, DIMENSION(nx) :: tmp
      INTEGER :: nx, ny, i, j
      continue
      !DIR$ scop
      DO i = 1, ny
      y(i) = 0.0d0
      
      END DO
      DO i = 1, nx
      tmp(i) = 0.0d0
      DO j = 1, ny
      tmp(i) = tmp(i) + (a(j, i) * x(j))
      
      END DO
      DO j = 1, ny
      y(j) = y(j) + a(j, i) * tmp(i)
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_atax
END PROGRAM ATAX
