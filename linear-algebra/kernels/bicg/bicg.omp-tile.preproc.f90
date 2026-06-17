!******************************************************************************
!
!  bicg.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program bicg
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:), allocatable :: r
      double precision, dimension(:), allocatable :: s
      double precision, dimension(:), allocatable :: p
      double precision, dimension(:), allocatable :: q
      integer :: i
!     Allocation of Arrays
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(r( 500+0), STAT=I); call check_err(I)
      allocate(s( 500+0), STAT=I); call check_err(I)
      allocate(p( 500+0), STAT=I); call check_err(I)
      allocate(q( 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, 500, a, r, p)
!     Kernel Execution
      call kernel_bicg(500, 500,  &
                              a, s, q, p, r)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, 500, s, q);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(r)
      deallocate(s)
      deallocate(p)
      deallocate(q)
      contains
        subroutine init_array(nx, ny, a, r, p)
        double precision :: M_PI
        parameter(M_PI = 3.14159265358979323846D0)
        double precision, dimension(ny, nx) :: a
        double precision, dimension(nx) :: r
        double precision, dimension(ny) :: p
        integer :: nx, ny
        integer :: i, j
        do i = 1, ny
          p(i) = DBLE(i - 1) * M_PI
        end do
        do i = 1, nx
          r(i) = DBLE(i - 1) * M_PI
          do j = 1, ny
            a(j, i) = (DBLE(i - 1) * DBLE(j)) / nx
          end do
        end do
        end subroutine
        subroutine print_array(nx, ny, s, q)
        double precision, dimension(ny) :: s
        double precision, dimension(nx) :: q
        integer :: nx,ny
        integer :: i
        do i = 1, ny
          write(0, "(f0.2,1x)", advance='no') s(i)
          if (mod(i - 1, 80) == 0) then
            write(0, *)
          end if
        end do
        do i = 1, nx
          write(0, "(f0.2,1x)", advance='no') q(i)
          if (mod(i - 1, 80) == 0) then
            write(0, *)
          end if
        end do
        write(0, *)
        end subroutine
        subroutine kernel_bicg(nx, ny, a, s, q, p, r)
        double precision, dimension(ny, nx) :: a
        double precision, dimension(nx) :: r
        double precision, dimension(nx) :: q
        double precision, dimension(ny) :: p
        double precision, dimension(ny) :: s
        integer :: nx,ny
        integer :: i,j
      CONTINUE
      !DIR$ scop
        !$omp tile sizes(32)
        do i = 1, ny
          s(i) = 0.0D0
        end do
        !$omp tile sizes(32)
        do i = 1, nx
          q(i) = 0.0D0
          do j = 1, ny
            s(j) = s(j) + (r(i) * a(j, i))
            q(i) = q(i) + (a(j, i) * p(j))
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
