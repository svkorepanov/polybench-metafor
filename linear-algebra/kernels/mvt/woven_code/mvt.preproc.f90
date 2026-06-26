PROGRAM MVT
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x1
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y1
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: x2
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: y2
   INTEGER :: i
   allocate(a(500 + 0, 500 + 0), STAT=i)
   call check_err(i)
   allocate(x1(500 + 0), STAT=i)
   call check_err(i)
   allocate(y1(500 + 0), STAT=i)
   call check_err(i)
   allocate(x2(500 + 0), STAT=i)
   call check_err(i)
   allocate(y2(500 + 0), STAT=i)
   call check_err(i)
   call init_array(500, x1, x2, y1, y2, a)
   call kernel_mvt(500, x1, x2, y1, y2, a)
   call print_array(500, x1, x2)
   deallocate(a)
   deallocate(x1)
   deallocate(y1)
   deallocate(x2)
   deallocate(y2)
   contains
   SUBROUTINE init_array(n, x1, x2, y1, y2, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: x1
      DOUBLE PRECISION, DIMENSION(n) :: y1
      DOUBLE PRECISION, DIMENSION(n) :: x2
      DOUBLE PRECISION, DIMENSION(n) :: y2
      INTEGER :: n
      INTEGER :: i, j
      DO i = 1, n
      x1(i) = dble(i - 1) / dble(n)
      x2(i) = (dble(i - 1) + 1.0d0) / dble(n)
      y1(i) = (dble(i - 1) + 3.0d0) / dble(n)
      y2(i) = (dble(i - 1) + 4.0d0) / dble(n)
      DO j = 1, n
      a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(n, x1, x2)
      DOUBLE PRECISION, DIMENSION(n) :: x1
      DOUBLE PRECISION, DIMENSION(n) :: x2
      INTEGER :: n
      INTEGER :: i
      DO i = 1, n
      WRITE(0, "(f0.2,1x)", advance="no") x1(i)
      WRITE(0, "(f0.2,1x)", advance="no") x2(i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_mvt(n, x1, x2, y1, y2, a)
      DOUBLE PRECISION, DIMENSION(n, n) :: a
      DOUBLE PRECISION, DIMENSION(n) :: x1
      DOUBLE PRECISION, DIMENSION(n) :: y1
      DOUBLE PRECISION, DIMENSION(n) :: x2
      DOUBLE PRECISION, DIMENSION(n) :: y2
      INTEGER :: n
      INTEGER :: i, j
      continue
      !DIR$ scop
      DO ii = 1, n, 32
      DO jj = 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      x1(i) = x1(i) + (a(j, i) * y1(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      DO ii = 1, n, 32
      DO jj = 1, n, 32
      DO i = ii, MIN(ii + 32 - 1, n)
      DO j = jj, MIN(jj + 32 - 1, n)
      x2(i) = x2(i) + (a(i, j) * y2(j))
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_mvt
END PROGRAM MVT
