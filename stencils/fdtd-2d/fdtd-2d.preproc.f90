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
      integer :: i
!     Allocation of Arrays
      allocate(fict( 10+0), STAT=I); call check_err(I)
      allocate(ex( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(ey( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(hz( 500+0, 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(10, 500, 500, ex, ey, hz, fict)
!     Kernel Execution
      call kernel_fdtd_2d(10, 500, 500, ex, ey, hz, fict)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, 500, ex, ey, hz);  ;
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
