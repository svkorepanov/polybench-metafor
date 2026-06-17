!******************************************************************************
!
!  trisolv.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program trisolv
    double precision, dimension(:,:), allocatable :: a
    double precision, dimension(:), allocatable :: x
    double precision, dimension(:), allocatable :: c
   integer :: n = 500, i
   !     Allocation of Arrays
   allocate(a( n+0, n+0), STAT=I); call check_err(I)
   allocate(x( n+0), STAT=I); call check_err(I)
   allocate(c( n+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(n, a, x, c)
   !     Kernel Execution
   call kernel_trisolv(n, &
   a, x, c)
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
         call print_array(n, x);   ;
   !     Deallocation of Arrays
   deallocate(a)
   deallocate(x)
   deallocate(c)
   contains
   subroutine init_array(n, a, x, c)
      double precision, dimension(n, n) :: a
      double precision, dimension(n) :: c
      double precision, dimension(n) :: x
      integer :: n
      integer :: i, j
      do i = 1, n
         c(i) = dble(i - 1) / dble(n)
         x(i) = dble(i - 1) / dble(n)
         do j = 1, n
            a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
         end do
      end do
   end subroutine
   subroutine print_array(n, x)
      double precision, dimension(n) :: x
      integer :: n
      integer :: i
      do i = 1, n
         write(0, "(f0.2,1x)", advance='no') x(i)
         if (mod((i - 1), 20) == 0) then
            write(0, *)
         end if
      end do
   end subroutine
   subroutine kernel_trisolv(n, a, x, c)
      double precision, dimension(n, n) :: a
      double precision, dimension(n) :: c
      double precision, dimension(n) :: x
      integer :: n
      integer :: i, j
            CONTINUE
      !DIR$ scop
      !$omp unroll factor(4)
      do i = 1, n
         x(i) = c(i)
         do j = 1, i - 1
            x(i) = x(i) - (a(j, i) * x(j))
         end do
         x(i) = x(i) / a(i, i)
      end do
      !DIR$ end scop
   end subroutine
end program
