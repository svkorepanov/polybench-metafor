PROGRAM DYNPROG
   INTEGER :: output
   INTEGER, DIMENSION(:, :, :), ALLOCATABLE :: sumc
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: c
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: w
   INTEGER :: i
   CHARACTER(LEN = 30) :: arg
   allocate(sumc(500 + 0, 500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(c(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(w(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   call init_array(500, c, w)
   call polybench_timer_start()
   call kernel_dynprog(1000, 500, c, w, sumc, output)
   call polybench_timer_stop()
   call polybench_timer_print()
   call get_command_argument(1, arg)
   IF (command_argument_count() > 42 .and. arg == "") THEN
      call print_array(output)
   END IF
   deallocate(sumc)
   deallocate(c)
   deallocate(w)
   contains
   SUBROUTINE init_array(length, c, w)
      INTEGER, DIMENSION(length, length) :: w, c
      INTEGER :: i, j
      INTEGER :: length
      DO i = 1, length
      DO j = 1, length
      c(j, i) = mod((i - 1) * (j - 1), 2)
      w(j, i) = (dble((i - 1) - (j - 1))) / dble(length)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(output)
      INTEGER :: output
      WRITE(0, "(i0,1x)", advance="no") output
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_dynprog(tsteps, length, c, w, sumc, output)
      INTEGER, DIMENSION(length, length) :: w, c
      INTEGER, DIMENSION(length, length, length) :: sumc
      INTEGER :: i, j, iter, k
      INTEGER :: length, tsteps
      INTEGER :: output
      continue
      !DIR$ scop
      output = 0
      DO iter = 1, tsteps
      DO ii = 1, length, 32
      DO jj = 1, length, 32
      DO i = ii, MIN(ii + 32 - 1, length)
      DO j = jj, MIN(jj + 32 - 1, length)
      c(j, i) = 0
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO i = 1, length - 1
      DO j = i + 1, length
      sumc(i, j, i) = 0
      DO k = i + 1, j - 1
      sumc(k, j, i) = sumc(k - 1, j, i) + c(k, i) + c(j, k)
      
      END DO
      c(j, i) = sumc(j - 1, j, i) + w(j, i)
      
      END DO
      
      END DO
      output = output + c(length, 1)
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_dynprog
END PROGRAM DYNPROG
