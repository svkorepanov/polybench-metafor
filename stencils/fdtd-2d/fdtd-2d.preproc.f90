!******************************************************************************
!
!  fdtd-2d.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 50x1000x1000. 
      program fdtd2d
      double precision, dimension(:), allocatable :: fict
      double precision, dimension(:,:), allocatable :: ex
      double precision, dimension(:,:), allocatable :: ey
      double precision, dimension(:,:), allocatable :: hz
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(fict( 50+0), STAT=I); call check_err(I)
      allocate(ex( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(ey( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(hz( 2000+0, 2000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(50, 2000, 2000, ex, ey, hz, fict)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_fdtd_2d(50, 2000, 2000, ex, ey, hz, fict)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(2000, 2000, ex, ey, hz);  end if;
!     Deallocation of Arrays 
      deallocate(fict)
      deallocate(ex)
      deallocate(ey)
      deallocate(hz)
      contains
        subroutine init_array(tmax, nx, ny, ex, ey, hz, fict)
        integer :: nx, ny, tmax
        double precision, dimension(tmax) :: fict
        double precision, dimension(ny, nx) :: ex
        double precision, dimension(ny, nx) :: ey
        double precision, dimension(ny, nx) :: hz
        integer :: i, j
        do i = 1, tmax
          fict(i) = DBLE(i - 1)
        end do
        do i = 1, nx
          do j = 1, ny
            ex(j, i) = (DBLE((i - 1) * (j))) / DBLE(nx)
            ey(j, i) = (DBLE((i - 1) * (j + 1))) / DBLE(ny)
            hz(j, i) = (DBLE((i - 1) * (j + 2))) / DBLE(nx)
          end do
        end do
        end subroutine
        subroutine print_array(nx, ny, ex, ey, hz)
        double precision, dimension(ny, nx) :: ex
        double precision, dimension(ny, nx) :: ey
        double precision, dimension(ny, nx) :: hz
        integer :: nx, ny
        integer :: i, j
        do i = 1, nx
          do j = 1, ny
            write(0, "(f0.2,1x)", advance='no') ex(j, i)
            write(0, "(f0.2,1x)", advance='no') ey(j, i)
            write(0, "(f0.2,1x)", advance='no') hz(j, i)
            if (mod(((i - 1) * nx) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_fdtd_2d(tmax, nx, ny, ex, ey, hz, fict)
        integer :: tmax, nx, ny
        double precision, dimension(tmax) :: fict
        double precision, dimension(ny, nx) :: ex
        double precision, dimension(ny, nx) :: ey
        double precision, dimension(ny, nx) :: hz
        integer :: i, j, t
      CONTINUE
      !DIR$ scop
        do t = 1, tmax
          do j = 1, ny
            ey(j, 1) = fict(t)
          end do
          do i = 2, nx
            do j = 1, ny
              ey(j, i) = ey(j, i) - (0.5D0 * (hz(j, i) - hz(j, i - 1)))
            end do
          end do
          do i = 1, nx
            do j = 2, ny
              ex(j, i) = ex(j, i) - (0.5D0 * (hz(j, i) - hz(j - 1, i)))
            end do
          end do
          do i = 1, nx - 1
            do j = 1, ny - 1
              hz(j, i) = hz(j, i) - (0.7D0 * (ex(j + 1, i) - ex(j, i)  &
                                           + ey(j, i + 1) - ey(j, i)))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
