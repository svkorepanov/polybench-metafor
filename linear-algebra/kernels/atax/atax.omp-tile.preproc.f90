!******************************************************************************
!
!  atax.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program atax
    double precision, dimension(:,:), allocatable :: a
    double precision, dimension(:), allocatable :: x
    double precision, dimension(:), allocatable :: y
    double precision, dimension(:), allocatable :: tmp
   integer :: nx = 500, ny = 500, i
   !     Allocation of Arrays
   allocate(a( ny+0, nx+0), STAT=I); call check_err(I)
   allocate(x( ny+0), STAT=I); call check_err(I)
   allocate(y( nx+0), STAT=I); call check_err(I)
   allocate(tmp( ny+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(a, x, nx, ny)
   !     Kernel Execution
   call kernel_atax(nx, ny, a, x, y, tmp)
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
         call print_array(y, ny);   ;
   !     Deallocation of Arrays
   deallocate(a)
   deallocate(x)
   deallocate(y)
   deallocate(tmp)
   contains
   subroutine init_array(a, x, nx, ny)
      double precision :: m_pi
      parameter(m_pi = 3.14159265358979323846d0)
      double precision, dimension(ny, nx) :: a
      double precision, dimension(ny) :: x
      integer :: nx, ny
      integer :: i, j
      do i = 1, ny
         x(i) = dble(i - 1) * m_pi
         do j = 1, ny
            a(j, i) = (dble((i - 1) * (j))) / nx
         end do
      end do
   end subroutine
   subroutine print_array(y, ny)
      double precision, dimension(ny) :: y
      integer :: ny
      integer :: i
      do i = 1, ny
         write(0, "(f0.2,1x)", advance='no') y(i)
         if (mod(i - 1, 20) == 0) then
            write(0, *)
         end if
      end do
      write(0, *)
   end subroutine
   subroutine kernel_atax(nx, ny, a, x, y, tmp)
      double precision, dimension(ny, nx) :: a
      double precision, dimension(ny) :: x
      double precision, dimension(ny) :: y
      double precision, dimension(nx) :: tmp
      integer nx, ny, i, j
            CONTINUE
      !DIR$ scop
      !$omp tile sizes(32)
      do i = 1, ny
         y(i) = 0.0d0
      end do
      !$omp tile sizes(32)
      do i = 1, nx
         tmp(i) = 0.0d0
         do j = 1, ny
            tmp(i) = tmp(i) + (a(j, i) * x(j))
         end do
         do j = 1, ny
            y(j) = y(j) + a(j, i) * tmp(i)
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
