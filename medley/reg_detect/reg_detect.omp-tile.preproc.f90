PROGRAM REGDETECT
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: sumtang
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: mean
   INTEGER, DIMENSION(:, :, :), ALLOCATABLE :: diff
   INTEGER, DIMENSION(:, :, :), ALLOCATABLE :: sumdiff
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: path
   INTEGER :: niter = 1000, length = 500, maxgrid = 12, i
   CHARACTER(LEN = 30) :: arg
   allocate(sumtang(maxgrid + 0, maxgrid + 0), STAT=i)
   call check_err(i)
   allocate(mean(maxgrid + 0, maxgrid + 0), STAT=i)
   call check_err(i)
   allocate(diff(length + 0, maxgrid + 0, maxgrid + 0), STAT=i)
   call check_err(i)
   allocate(sumdiff(length + 0, maxgrid + 0, maxgrid + 0), STAT=i)
   call check_err(i)
   allocate(path(maxgrid + 0, maxgrid + 0), STAT=i)
   call check_err(i)
   call init_array(maxgrid, sumtang, mean, path)
   call polybench_timer_start()
   call kernel_reg_detect(niter, maxgrid, length, sumtang, mean, path, diff, sumdiff)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(maxgrid, path)
   END IF
   deallocate(sumtang)
   deallocate(mean)
   deallocate(diff)
   deallocate(sumdiff)
   deallocate(path)
   contains
   SUBROUTINE init_array(maxgrid, sumtang, mean, path)
      INTEGER :: maxgrid
      INTEGER, DIMENSION(maxgrid, maxgrid) :: sumtang, mean, path
      INTEGER :: i, j
      DO i = 1, maxgrid
      DO j = 1, maxgrid
      sumtang(j, i) = i * j
      mean(j, i) = (i - j) / (maxgrid)
      path(j, i) = ((i - 1) * (j - 2)) / (maxgrid)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(maxgrid, path)
      INTEGER :: i, j, maxgrid
      INTEGER, DIMENSION(maxgrid, maxgrid) :: path
      DO i = 1, maxgrid
      DO j = 1, maxgrid
      WRITE(0, "(i0,1x)", advance="no") path(j, i)
      IF (mod(((i - 1) * maxgrid) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_reg_detect(niter, maxgrid, length, sumtang, mean, path, diff, sumdiff)
      INTEGER :: maxgrid, niter, length
      INTEGER, DIMENSION(maxgrid, maxgrid) :: sumtang, mean, path
      INTEGER, DIMENSION(length, maxgrid, maxgrid) :: sumdiff, diff
      INTEGER :: i, j, t, cnt
      continue
      !DIR$ scop
      DO t = 1, niter
      DO jj = 1, maxgrid, 32
      DO ii = j, maxgrid, 32
      DO j = jj, MIN(jj + 32 - 1, maxgrid)
      DO i = ii, MIN(ii + 32 - 1, maxgrid)
      DO cnt = 1, length
      diff(cnt, i, j) = sumtang(i, j)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO jj = 1, maxgrid, 32
      DO ii = j, maxgrid, 32
      DO j = jj, MIN(jj + 32 - 1, maxgrid)
      DO i = ii, MIN(ii + 32 - 1, maxgrid)
      sumdiff(1, i, j) = diff(1, i, j)
      DO cnt = 2, length
      sumdiff(cnt, i, j) = sumdiff(cnt - 1, i, j) + diff(cnt, i, j)
      
      END DO
      mean(i, j) = sumdiff(length, i, j)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i = 1, maxgrid
      path(i, 1) = mean(i, 1)
      
      END DO
      DO jj = 2, maxgrid, 32
      DO ii = j, maxgrid, 32
      DO j = jj, MIN(jj + 32 - 1, maxgrid)
      DO i = ii, MIN(ii + 32 - 1, maxgrid)
      path(i, j) = path(i - 1, j - 1) + mean(i, j)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_reg_detect
END PROGRAM REGDETECT
