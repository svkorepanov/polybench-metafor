!******************************************************************************
!
!  floyd-warshall.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 256x256x256. 
      program fdtdapml
      double precision :: ch
      double precision :: mui
      double precision, dimension(:,:,:), allocatable :: ex
      double precision, dimension(:,:,:), allocatable :: ey
      double precision, dimension(:,:,:), allocatable :: bza
      double precision, dimension(:,:,:), allocatable :: hz
      double precision, dimension(:,:), allocatable :: clf 
      double precision, dimension(:,:), allocatable :: tmp 
      double precision, dimension(:,:), allocatable :: ry 
      double precision, dimension(:,:), allocatable :: ax 
      double precision, dimension(:), allocatable :: cymh 
      double precision, dimension(:), allocatable :: cyph 
      double precision, dimension(:), allocatable :: cxmh 
      double precision, dimension(:), allocatable :: cxph 
      double precision, dimension(:), allocatable :: czm 
      double precision, dimension(:), allocatable :: czp 
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(ex(512+1+0,512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(ey(512+1+0,512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(bza(512+1+0,512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(hz(512+1+0,512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(clf(512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(tmp(512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(ry(512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(ax(512+1+0,512+1+0), STAT=I); call check_err(I)
      allocate(cymh(512+1+0), STAT=I); call check_err(I)
      allocate(cyph(512+1+0), STAT=I); call check_err(I)
      allocate(cxmh(512+1+0), STAT=I); call check_err(I)
      allocate(cxph(512+1+0), STAT=I); call check_err(I)
      allocate(czm(512+1+0), STAT=I); call check_err(I)
      allocate(czp(512+1+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(512, 512, 512, &
                          mui, ch, ax, ry, ex, ey, &
                          hz, czm, czp, cxmh, cxph, &
                          cymh, cyph)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_fdtd_apml(512, 512, 512, mui, ch, &
                       ax, ry, clf, tmp, bza, ex, ey,  &
                       hz, czm, czp, cxmh, cxph, cymh, cyph)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(512, 512, 512 , Bza, Ex, Ey, Hz);  end if
!     Deallocation of Arrays 
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
        subroutine init_array(cz, cxm, cym, mui, ch, ax, ry, ex, ey, hz, &
                                       czm, czp, cxmh, cxph, cymh, cyph)
        integer :: cz, cym, cxm
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ex
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ey
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: hz
        double precision, dimension(cym + 1, cz + 1) :: ry
        double precision, dimension(cym + 1, cz + 1) :: ax
        double precision, dimension(cym + 1) :: cymh
        double precision, dimension(cym + 1) :: cyph
        double precision, dimension(cxm + 1) :: cxmh
        double precision, dimension(cxm + 1) :: cxph
        double precision, dimension(cz + 1) :: czm
        double precision, dimension(cz + 1) :: czp
        double precision :: mui, ch
        integer :: i, j, k
        mui = 2341
        ch = 42
        do i = 1, cz + 1
          czm(i) = (DBLE(i - 1) + 1.0D0) / DBLE(cxm)
          czp(i) = (DBLE(i - 1) + 2.0D0) / DBLE(cxm)
        end do
        do i = 1, cxm + 1
          cxmh(i) = (DBLE(i - 1) + 3.0D0) / DBLE(cxm)
          cxph(i) = (DBLE(i - 1) + 4.0D0) / DBLE(cxm)
        end do
        do i = 1, cym + 1
          cymh(i) = (DBLE(i - 1) + 5.0D0) / DBLE(cxm)
          cyph(i) = (DBLE(i - 1) + 6.0D0) / DBLE(cxm)
        end do
        do i = 1, cz + 1
          do j = 1, cym + 1
            ry(j, i) = ((DBLE(i - 1) * DBLE(j)) + 10.0D0) / &
                       DBLE(cym)
            ax(j, i) = ((DBLE(i - 1) * DBLE(j + 1)) + 11.0D0) / &
                       DBLE(cym)
            do k = 1, cxm + 1
              ex(k, j, i) = ((DBLE(i - 1) * DBLE(j + 2)) + DBLE(k - 1) + &
                             1.0D0) / DBLE(cxm)
              ey(k, j, i) = ((DBLE(i - 1) * DBLE(j + 3)) + DBLE(k - 1) + &
                             2.0D0) / DBLE(cym)
              hz(k, j, i) = ((DBLE(i - 1) * DBLE(j + 4)) + DBLE(k - 1) + &
                             3.0D0) / DBLE(cz)
            end do
          end do
        end do
        end subroutine
        subroutine print_array(cz, cxm, cym, bza, ex, ey, hz)
        integer :: cz, cxm, cym
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: bza
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ex
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ey
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: hz
        integer :: i, j, k
        do i = 1, cz + 1
          do j = 1, cym + 1
            do k = 1, cxm + 1
              write(0, "(f0.2,1x)", advance='no') bza(k, j, i)
              write(0, "(f0.2,1x)", advance='no') ex(k, j, i)
              write(0, "(f0.2,1x)", advance='no') ey(k, j, i)
              write(0, "(f0.2,1x)", advance='no') hz(k, j, i)
              if (mod(((i - 1) * cxm) + j - 1, 20) == 0) then
                write(0, *)
              end if
            end do
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_fdtd_apml(cz, cxm, cym, mui, ch, &
                               ax, ry, clf, tmp, bza, ex, ey, &
                               hz, czm, czp, cxmh, cxph, cymh, cyph)
        integer :: cz, cym, cxm
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ex
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: ey
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: hz
        double precision, dimension(cym + 1, cz + 1) :: clf
        double precision, dimension(cym + 1, cz + 1) :: ry
        double precision, dimension(cym + 1, cz + 1) :: ax
        double precision, dimension(cym + 1) :: cymh
        double precision, dimension(cym + 1) :: cyph
        double precision, dimension(cxm + 1) :: cxmh
        double precision, dimension(cxm + 1) :: cxph
        double precision, dimension(cz + 1) :: czm
        double precision, dimension(cz + 1) :: czp
        double precision, dimension(cxm + 1, cym + 1) :: tmp
        double precision, dimension(cxm + 1, cym + 1, cz + 1) :: bza
        double precision :: mui, ch
        integer :: ix, iy, iz
      CONTINUE
      !DIR$ scop
        do iz = 1, cz
          do iy = 1, cym 
            do ix = 1, cxm 
              clf(iy, iz) = ex(ix, iy, iz) - ex(ix, iy + 1, iz) + &
                            ey(ix + 1, iy, iz) - ey(ix, iy, iz)
              tmp(iy, iz) = ((cymh(iy) / cyph(iy)) * bza(ix, iy, iz)) - &
                            ((ch / cyph(iy)) * clf(iy, iz))
              hz(ix, iy, iz) = ((cxmh(ix) / cxph(ix)) * hz(ix, iy, iz)) &
                            + ((mui * czp(iz) / cxph(ix)) * tmp(iy, iz)) &
                               - ((mui * czm(iz) / cxph(ix)) * &
                                  bza(ix, iy, iz))
              bza(ix, iy, iz) = tmp(iy, iz)
            end do
            clf(iy, iz) = ex(cxm + 1, iy, iz) - &
                          ex(cxm + 1, iy + 1, iz) + &
                          ry(iy, iz) - ey(cxm + 1, iy, iz)
            tmp(iy, iz) = ((cymh(iy) / cyph(iy)) * &
                           bza(cxm + 1, iy, iz)) - ((ch / cyph(iy))  &
                           * clf(iy, iz))
            hz(cxm + 1, iy, iz) = ((cxmh(cxm + 1) / &
                                         cxph(cxm + 1)) * &
                                        hz(cxm + 1, iy, iz)) + &
                                       ((mui * czp(iz) / &
                                        cxph(cxm + 1)) * &
                                        tmp(iy, iz)) - &
                                       ((mui * czm(iz) / &
                                        cxph(cxm + 1)) * &
                                        bza(cxm + 1, iy, iz))
            bza(cxm + 1, iy, iz) = tmp(iy, iz)
          do ix = 1, cxm 
            clf(iy, iz) = ex(ix, cym + 1, iz) - ax(ix, iz) + &
                          ey(ix + 1, cym + 1, iz) - &
                          ey(ix, cym + 1, iz)
            tmp(iy, iz) = ((cymh(cym + 1) / cyph(iy)) * &
                           bza(ix, iy, iz)) - ((ch / cyph(iy)) * &
                           clf(iy, iz))
            hz(ix, cym + 1, iz) = ((cxmh(ix) / cxph(ix)) * &
                                        hz(ix, cym + 1, iz)) + &
                                       ((mui * czp(iz) / cxph(ix)) * &
                                        tmp(iy, iz)) - &
                                       ((mui * czm(iz) / cxph(ix)) * &
                                        bza(ix, cym + 1, iz))
            bza(ix, cym + 1, iz) = tmp(iy, iz)
          end do
          clf(iy, iz) = ex(cxm + 1, cym + 1, iz) - &
                        ax(cxm + 1, iz) + ry(cym + 1, iz) - &
                        ey(cxm + 1, cym + 1, iz)
          tmp(iy, iz) = ((cymh(cym + 1) / cyph(cym + 1)) * &
                         bza(cxm + 1, cym + 1, iz)) - &
                         ((ch / cyph(cym + 1)) * clf(iy, iz))
          hz(cxm + 1, cym + 1, iz) = &
            ((cxmh(cxm + 1) / cxph(cxm + 1)) * &
             hz(cxm + 1, cym + 1, iz)) + &
             ((mui * czp(iz) / cxph(cxm + 1)) * tmp(iy, iz)) - &
             ((mui * czm(iz) / cxph(cxm + 1)) * &
              bza(cxm + 1, cym + 1, iz))
          bza(cxm + 1, cym + 1, iz) = tmp(iy, iz)
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
