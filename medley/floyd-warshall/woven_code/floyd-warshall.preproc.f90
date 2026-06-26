PROGRAM FLOYD_WARSHALL
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: path
   INTEGER :: i
   allocate(path(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   call init_array(128, path)
   call kernel_floyd_warshall(128, path)
   call print_array(128, path)
   deallocate(path)
   contains
   SUBROUTINE init_array(n, path)
      DOUBLE PRECISION, DIMENSION(n, n) :: path
      INTEGER :: i, j, n
      DO i = 1, n
      DO j = 1, n
      path(j, i) = (dble(i * j)) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, path)
      DOUBLE PRECISION, DIMENSION(n, n) :: path
      INTEGER :: i, j, n
      DO i = 1, n
      DO j = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") path(j, i)
      IF (mod(((i - 1) * n) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_floyd_warshall(n, path)
      DOUBLE PRECISION, DIMENSION(n, n) :: path
      INTEGER :: n
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO kk = 1, n, 32
      DO ii = 1, n, 32
      DO k = kk, MIN(kk + 32 - 1, n)
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = 1, n
      IF (path(j, i) >= path(k, i) + path(j, k)) THEN
         path(j, i) = path(k, i) + path(j, k)
      END IF
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_floyd_warshall
END PROGRAM FLOYD_WARSHALL
