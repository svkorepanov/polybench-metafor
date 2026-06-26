PROGRAM FDTD2D
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: fict
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: ex
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: ey
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: hz
   INTEGER :: i
   allocate(fict(10 + 0), STAT=i)
   call check_err(i)
   allocate(ex(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(ey(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(hz(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   call init_array(10, 500, 500, ex, ey, hz, fict)
   call kernel_fdtd_2d(10, 500, 500, ex, ey, hz, fict)
   call print_array(500, 500, ex, ey, hz)
   deallocate(fict)
   deallocate(ex)
   deallocate(ey)
   deallocate(hz)
   contains
   SUBROUTINE init_array(tmax, nx, ny, ex, ey, hz, fict)
      INTEGER :: nx, ny, tmax
      DOUBLE PRECISION, DIMENSION(tmax) :: fict
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ex
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ey
      DOUBLE PRECISION, DIMENSION(ny, nx) :: hz
      INTEGER :: i, j
      DO i = 1, tmax
      fict(i) = dble(i - 1)
      
      END DO
      DO i = 1, nx
      DO j = 1, ny
      ex(j, i) = (dble((i - 1) * (j))) / dble(nx)
      ey(j, i) = (dble((i - 1) * (j + 1))) / dble(ny)
      hz(j, i) = (dble((i - 1) * (j + 2))) / dble(nx)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(nx, ny, ex, ey, hz)
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ex
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ey
      DOUBLE PRECISION, DIMENSION(ny, nx) :: hz
      INTEGER :: nx, ny
      INTEGER :: i, j
      DO i = 1, nx
      DO j = 1, ny
      WRITE(0, "(f0.2,1x)", advance="no") ex(j, i)
      WRITE(0, "(f0.2,1x)", advance="no") ey(j, i)
      WRITE(0, "(f0.2,1x)", advance="no") hz(j, i)
      IF (mod(((i - 1) * nx) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_fdtd_2d(tmax, nx, ny, ex, ey, hz, fict)
      INTEGER :: tmax, nx, ny
      DOUBLE PRECISION, DIMENSION(tmax) :: fict
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ex
      DOUBLE PRECISION, DIMENSION(ny, nx) :: ey
      DOUBLE PRECISION, DIMENSION(ny, nx) :: hz
      INTEGER :: i, j, t
      continue
      !DIR$ scop
      DO t = 1, tmax
      DO j = 1, ny
      ey(j, 1) = fict(t)
      
      END DO
      DO ii = 2, nx, 32
      DO jj = 1, ny, 32
      DO i = ii, MIN(ii + 32 - 1, nx)
      DO j = jj, MIN(jj + 32 - 1, ny)
      ey(j, i) = ey(j, i) - (0.5d0 * (hz(j, i) - hz(j, i - 1)))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, nx, 32
      DO jj = 2, ny, 32
      DO i = ii, MIN(ii + 32 - 1, nx)
      DO j = jj, MIN(jj + 32 - 1, ny)
      ex(j, i) = ex(j, i) - (0.5d0 * (hz(j, i) - hz(j - 1, i)))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, nx - 1, 32
      DO jj = 1, ny - 1, 32
      DO i = ii, MIN(ii + 32 - 1, nx - 1)
      DO j = jj, MIN(jj + 32 - 1, ny - 1)
      hz(j, i) = hz(j, i) - (0.7d0 * (ex(j + 1, i) - ex(j, i) + ey(j, i + 1) - ey(j, i)))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_fdtd_2d
END PROGRAM FDTD2D
