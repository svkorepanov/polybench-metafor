PROGRAM FDTDAPML
   DOUBLE PRECISION :: ch
   DOUBLE PRECISION :: mui
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: ex
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: ey
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: bza
   DOUBLE PRECISION, DIMENSION(:, :, :), ALLOCATABLE :: hz
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: clf
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: tmp
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: ry
   DOUBLE PRECISION, DIMENSION(:, :), ALLOCATABLE :: ax
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: cymh
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: cyph
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: cxmh
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: cxph
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: czm
   DOUBLE PRECISION, DIMENSION(:), ALLOCATABLE :: czp
   INTEGER :: i
   allocate(ex(64 + 1 + 0, 64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(ey(64 + 1 + 0, 64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(bza(64 + 1 + 0, 64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(hz(64 + 1 + 0, 64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(clf(64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(tmp(64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(ry(64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(ax(64 + 1 + 0, 64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(cymh(64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(cyph(64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(cxmh(64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(cxph(64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(czm(64 + 1 + 0), STAT=i)
   call check_err(i)
   allocate(czp(64 + 1 + 0), STAT=i)
   call check_err(i)
   call init_array(64, 64, 64, mui, ch, ax, ry, ex, ey, hz, czm, czp, cxmh, cxph, cymh, cyph)
   call kernel_fdtd_apml(64, 64, 64, mui, ch, ax, ry, clf, tmp, bza, ex, ey, hz, czm, czp, cxmh, cxph, cymh, cyph)
   call print_array(64, 64, 64, bza, ex, ey, hz)
   deallocate(ex)
   deallocate(ey)
   deallocate(bza)
   deallocate(hz)
   deallocate(clf)
   deallocate(tmp)
   deallocate(ry)
   deallocate(ax)
   deallocate(cymh)
   deallocate(cyph)
   deallocate(cxmh)
   deallocate(cxph)
   deallocate(czm)
   deallocate(czp)
   contains
   SUBROUTINE init_array(cz, cxm, cym, mui, ch, ax, ry, ex, ey, hz, czm, czp, cxmh, cxph, cymh, cyph)
      INTEGER :: cz, cym, cxm
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ex
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ey
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: hz
      DOUBLE PRECISION, DIMENSION(cym + 1, cz + 1) :: ry
      DOUBLE PRECISION, DIMENSION(cym + 1, cz + 1) :: ax
      DOUBLE PRECISION, DIMENSION(cym + 1) :: cymh
      DOUBLE PRECISION, DIMENSION(cym + 1) :: cyph
      DOUBLE PRECISION, DIMENSION(cxm + 1) :: cxmh
      DOUBLE PRECISION, DIMENSION(cxm + 1) :: cxph
      DOUBLE PRECISION, DIMENSION(cz + 1) :: czm
      DOUBLE PRECISION, DIMENSION(cz + 1) :: czp
      DOUBLE PRECISION :: mui, ch
      INTEGER :: i, j, k
      mui = 2341
      ch = 42
      DO i = 1, cz + 1
      czm(i) = (dble(i - 1) + 1.0d0) / dble(cxm)
      czp(i) = (dble(i - 1) + 2.0d0) / dble(cxm)
      
      END DO
      DO i = 1, cxm + 1
      cxmh(i) = (dble(i - 1) + 3.0d0) / dble(cxm)
      cxph(i) = (dble(i - 1) + 4.0d0) / dble(cxm)
      
      END DO
      DO i = 1, cym + 1
      cymh(i) = (dble(i - 1) + 5.0d0) / dble(cxm)
      cyph(i) = (dble(i - 1) + 6.0d0) / dble(cxm)
      
      END DO
      DO i = 1, cz + 1
      DO j = 1, cym + 1
      ry(j, i) = ((dble(i - 1) * dble(j)) + 10.0d0) / dble(cym)
      ax(j, i) = ((dble(i - 1) * dble(j + 1)) + 11.0d0) / dble(cym)
      DO k = 1, cxm + 1
      ex(k, j, i) = ((dble(i - 1) * dble(j + 2)) + dble(k - 1) + 1.0d0) / dble(cxm)
      ey(k, j, i) = ((dble(i - 1) * dble(j + 3)) + dble(k - 1) + 2.0d0) / dble(cym)
      hz(k, j, i) = ((dble(i - 1) * dble(j + 4)) + dble(k - 1) + 3.0d0) / dble(cz)
      
      END DO
      
      END DO
      
      END DO
   END SUBROUTINE init_array
   
   SUBROUTINE print_array(cz, cxm, cym, bza, ex, ey, hz)
      INTEGER :: cz, cxm, cym
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: bza
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ex
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ey
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: hz
      INTEGER :: i, j, k
      DO i = 1, cz + 1
      DO j = 1, cym + 1
      DO k = 1, cxm + 1
      WRITE(0, "(f0.2,1x)", advance="no") bza(k, j, i)
      WRITE(0, "(f0.2,1x)", advance="no") ex(k, j, i)
      WRITE(0, "(f0.2,1x)", advance="no") ey(k, j, i)
      WRITE(0, "(f0.2,1x)", advance="no") hz(k, j, i)
      IF (mod(((i - 1) * cxm) + j - 1, 20) == 0) THEN
         WRITE(0, *) 
      END IF
      
      END DO
      
      END DO
      
      END DO
      WRITE(0, *) 
   END SUBROUTINE print_array
   
   SUBROUTINE kernel_fdtd_apml(cz, cxm, cym, mui, ch, ax, ry, clf, tmp, bza, ex, ey, hz, czm, czp, cxmh, cxph, cymh, cyph)
      INTEGER :: cz, cym, cxm
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ex
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: ey
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: hz
      DOUBLE PRECISION, DIMENSION(cym + 1, cz + 1) :: clf
      DOUBLE PRECISION, DIMENSION(cym + 1, cz + 1) :: ry
      DOUBLE PRECISION, DIMENSION(cym + 1, cz + 1) :: ax
      DOUBLE PRECISION, DIMENSION(cym + 1) :: cymh
      DOUBLE PRECISION, DIMENSION(cym + 1) :: cyph
      DOUBLE PRECISION, DIMENSION(cxm + 1) :: cxmh
      DOUBLE PRECISION, DIMENSION(cxm + 1) :: cxph
      DOUBLE PRECISION, DIMENSION(cz + 1) :: czm
      DOUBLE PRECISION, DIMENSION(cz + 1) :: czp
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1) :: tmp
      DOUBLE PRECISION, DIMENSION(cxm + 1, cym + 1, cz + 1) :: bza
      DOUBLE PRECISION :: mui, ch
      INTEGER :: ix, iy, iz
      continue
      !DIR$ scop
      DO iziz = 1, cz, 32
      DO iyiy = 1, cym, 32
      DO iz = iziz, MIN(iziz + 32 - 1, cz)
      DO iy = iyiy, MIN(iyiy + 32 - 1, cym)
      DO ix = 1, cxm
      clf(iy, iz) = ex(ix, iy, iz) - ex(ix, iy + 1, iz) + ey(ix + 1, iy, iz) - ey(ix, iy, iz)
      tmp(iy, iz) = ((cymh(iy) / cyph(iy)) * bza(ix, iy, iz)) - ((ch / cyph(iy)) * clf(iy, iz))
      hz(ix, iy, iz) = ((cxmh(ix) / cxph(ix)) * hz(ix, iy, iz)) + ((mui * czp(iz) / cxph(ix)) * tmp(iy, iz)) - ((mui * czm(iz) / cxph(ix)) * bza(ix, iy, iz))
      bza(ix, iy, iz) = tmp(iy, iz)
      
      END DO
      clf(iy, iz) = ex(cxm + 1, iy, iz) - ex(cxm + 1, iy + 1, iz) + ry(iy, iz) - ey(cxm + 1, iy, iz)
      tmp(iy, iz) = ((cymh(iy) / cyph(iy)) * bza(cxm + 1, iy, iz)) - ((ch / cyph(iy)) * clf(iy, iz))
      hz(cxm + 1, iy, iz) = ((cxmh(cxm + 1) / cxph(cxm + 1)) * hz(cxm + 1, iy, iz)) + ((mui * czp(iz) / cxph(cxm + 1)) * tmp(iy, iz)) - ((mui * czm(iz) / cxph(cxm + 1)) * bza(cxm + 1, iy, iz))
      bza(cxm + 1, iy, iz) = tmp(iy, iz)
      DO ix = 1, cxm
      clf(iy, iz) = ex(ix, cym + 1, iz) - ax(ix, iz) + ey(ix + 1, cym + 1, iz) - ey(ix, cym + 1, iz)
      tmp(iy, iz) = ((cymh(cym + 1) / cyph(iy)) * bza(ix, iy, iz)) - ((ch / cyph(iy)) * clf(iy, iz))
      hz(ix, cym + 1, iz) = ((cxmh(ix) / cxph(ix)) * hz(ix, cym + 1, iz)) + ((mui * czp(iz) / cxph(ix)) * tmp(iy, iz)) - ((mui * czm(iz) / cxph(ix)) * bza(ix, cym + 1, iz))
      bza(ix, cym + 1, iz) = tmp(iy, iz)
      
      END DO
      clf(iy, iz) = ex(cxm + 1, cym + 1, iz) - ax(cxm + 1, iz) + ry(cym + 1, iz) - ey(cxm + 1, cym + 1, iz)
      tmp(iy, iz) = ((cymh(cym + 1) / cyph(cym + 1)) * bza(cxm + 1, cym + 1, iz)) - ((ch / cyph(cym + 1)) * clf(iy, iz))
      hz(cxm + 1, cym + 1, iz) = ((cxmh(cxm + 1) / cxph(cxm + 1)) * hz(cxm + 1, cym + 1, iz)) + ((mui * czp(iz) / cxph(cxm + 1)) * tmp(iy, iz)) - ((mui * czm(iz) / cxph(cxm + 1)) * bza(cxm + 1, cym + 1, iz))
      bza(cxm + 1, cym + 1, iz) = tmp(iy, iz)
      
      END DO
      
      END DO
      
      END DO
      
      END DO
      !DIR$ end scop
   END SUBROUTINE kernel_fdtd_apml
END PROGRAM FDTDAPML
