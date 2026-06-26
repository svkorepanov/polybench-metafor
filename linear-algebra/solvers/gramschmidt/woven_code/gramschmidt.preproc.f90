PROGRAM GRAMSCHMIDT
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: r
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: q
   INTEGER :: i
   allocate(a(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(r(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   allocate(q(128 + 0, 128 + 0), STAT=i)
   call check_err(i)
   call init_array(128, 128, a, r, q)
   call kernel_gramschmidt(128, 128, a, r, q)
   call print_array(128, 128, a, r, q)
   deallocate(a)
   deallocate(r)
   deallocate(q)
   contains
   SUBROUTINE init_array(ni, nj, a, r, q)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nj) :: r
      DOUBLE PRECISION, DIMENSION(nj, ni) :: q
      INTEGER :: ni, nj
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, nj
      a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(ni)
      q(j, i) = (dble(i - 1) * dble(j)) / dble(nj)
      
      END DO
      
      END DO
      DO i = 1, ni
      DO j = 1, nj
      r(j, i) = (dble(i - 1) * dble(j + 1)) / dble(nj)
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(ni, nj, a, r, q)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nj) :: r
      DOUBLE PRECISION, DIMENSION(nj, ni) :: q
      INTEGER :: ni, nj
      INTEGER :: i, j
      DO i = 1, ni
      DO j = 1, nj
      WRITE(0, "(f0.2,1x)", advance="no") a(j, i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
      DO i = 1, nj
      DO j = 1, nj
      WRITE(0, "(f0.2,1x)", advance="no") r(j, i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
      DO i = 1, ni
      DO j = 1, nj
      WRITE(0, "(f0.2,1x)", advance="no") q(j, i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_gramschmidt(ni, nj, a, r, q)
      DOUBLE PRECISION, DIMENSION(nj, ni) :: a
      DOUBLE PRECISION, DIMENSION(nj, nj) :: r
      DOUBLE PRECISION, DIMENSION(nj, ni) :: q
      DOUBLE PRECISION :: nrm
      INTEGER :: ni, nj
      INTEGER :: i, j, k
      continue
      !DIR$ scop
      DO k = 1, nj
      nrm = 0.0d0
      DO i = 1, ni
      nrm = nrm + (a(k, i) * a(k, i))
      
      END DO
      r(k, k) = sqrt(nrm)
      DO i = 1, ni
      q(k, i) = a(k, i) / r(k, k)
      
      END DO
      DO j = k + 1, nj
      r(j, k) = 0.0d0
      DO i = 1, ni
      r(j, k) = r(j, k) + (q(k, i) * a(j, i))
      
      END DO
      DO i = 1, ni
      a(j, i) = a(j, i) - (q(k, i) * r(j, k))
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_gramschmidt
END PROGRAM GRAMSCHMIDT
