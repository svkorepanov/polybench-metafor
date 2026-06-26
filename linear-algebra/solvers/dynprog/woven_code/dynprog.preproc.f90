PROGRAM DYNPROG
   INTEGER :: output
   INTEGER, DIMENSION(:, :, :), ALLOCATABLE :: sumc
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: c
   INTEGER, DIMENSION(:, :), ALLOCATABLE :: w
   INTEGER :: i
   allocate(sumc(50 + 0, 50 + 0, 50 + 0), STAT=i)
   call check_err(i)
   allocate(c(50 + 0, 50 + 0), STAT=i)
   call check_err(i)
   allocate(w(50 + 0, 50 + 0), STAT=i)
   call check_err(i)
   call init_array(50, c, w)
   call kernel_dynprog(100, 50, c, w, sumc, output)
   call print_array(output)
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
      DO iteriter = 1, tsteps, 32
      DO ii = 1, length, 32
      DO iter = iteriter, MIN(iteriter + 32 - 1, tsteps)
      DO i = ii, MIN(ii + 32 - 1, length)
      DO j = 1, length
      c(j, i) = 0
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO iteriter = 1, tsteps, 32
      DO ii = 1, length - 1, 32
      DO iter = iteriter, MIN(iteriter + 32 - 1, tsteps)
      DO i = ii, MIN(ii + 32 - 1, length - 1)
      DO j = i + 1, length
      sumc(i, j, i) = 0
      DO k = i + 1, j - 1
      sumc(k, j, i) = sumc(k - 1, j, i) + c(k, i) + c(j, k)
      
      END DO
      c(j, i) = sumc(j - 1, j, i) + w(j, i)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO iter = 1, tsteps
      output = output + c(length, 1)
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_dynprog
END PROGRAM DYNPROG
