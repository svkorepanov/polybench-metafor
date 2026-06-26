PROGRAM DOITGEN
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: a
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: suma
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: cfour
   INTEGER :: nr = 32, nq = 32, np = 32, i
   allocate(a(np + 0, nq + 0, nr + 0), STAT=i)
   call check_err(i)
   allocate(suma(np + 0, nq + 0, nr + 0), STAT=i)
   call check_err(i)
   allocate(cfour(np + 0, np + 0), STAT=i)
   call check_err(i)
   call init_array(nr, nq, np, a, cfour)
   call kernel_doitgen(nr, nq, np, a, cfour, suma)
   call print_array(a, nr, nq, np)
   deallocate(a)
   deallocate(suma)
   deallocate(cfour)
   contains
   SUBROUTINE init_array(nr, nq, np, a, cfour)
      DOUBLE PRECISION, DIMENSION(np, nq, nr) :: a
      DOUBLE PRECISION, DIMENSION(np, np) :: cfour
      INTEGER :: nr, nq, np
      INTEGER :: i, j, k
      DO i = 1, nr
      DO j = 1, nq
      DO k = 1, np
      a(k, j, i) = ((dble(i - 1) * dble(j - 1)) + dble(k - 1)) / dble(np)
      
      END DO
      
      END DO
      
      END DO
      DO i = 1, np
      DO j = 1, np
      cfour(j, i) = (dble(i - 1) * dble(j - 1)) / np
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(a, nr, nq, np)
      DOUBLE PRECISION, DIMENSION(np, nq, nr) :: a
      INTEGER :: nr, nq, np
      INTEGER :: i, j, k
      DO i = 1, nr
      DO j = 1, nq
      DO k = 1, np
      WRITE(0, "(f0.2,1x)", advance="no") a(k, j, i)
      IF (mod((i - 1), 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_doitgen(nr, nq, np, a, cfour, suma)
      DOUBLE PRECISION, DIMENSION(np, nq, nr) :: a
      DOUBLE PRECISION, DIMENSION(np, nq, nr) :: suma
      DOUBLE PRECISION, DIMENSION(np, np) :: cfour
      INTEGER :: nr, nq, np
      INTEGER :: r, s, p, q
      continue
      !DIR$ scop
      DO rr = 1, nr, 32
      DO qq = 1, nq, 32
      DO r = rr, MIN(rr + 32 - 1, nr)
      DO q = qq, MIN(qq + 32 - 1, nq)
      DO p = 1, np
      suma(p, q, r) = 0.0d0
      
      END DO
      DO p = 1, np
      DO s = 1, np
      suma(p, q, r) = suma(p, q, r) + (a(s, q, r) * cfour(p, s))
      
      END DO
      
      END DO
      DO p = 1, np
      a(p, q, r) = suma(p, q, r)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_doitgen
END PROGRAM DOITGEN
