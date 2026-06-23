!******************************************************************************
!
!  jacobi-1d-imper.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 100x10000. 
      program jacobi1d
      double precision, dimension(:), allocatable :: a
      double precision, dimension(:), allocatable :: b
      integer :: i
!     Allocation of Arrays
      allocate(a( 1000+0), STAT=I); call check_err(I)
      allocate(b( 1000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(1000, a, b)
!     Kernel Execution
      call kernel_jacobi1d(10, 1000, a, b)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(1000, a);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(b)
      contains
        subroutine init_array(n, a, b)
        double precision, dimension(n) :: a
        double precision, dimension(n) :: b
        integer :: n
        integer :: i
        do i = 1, n
          a(i) = (DBLE(i-1) + 2.0D0) / n
          b(i) = (DBLE(i-1) + 3.0D0) / n
        end do
        end subroutine
        subroutine print_array(n, a)
        double precision, dimension(n) :: a
        integer :: n
        integer :: i
        do i = 1, n
          write(0, "(f0.2,1x)", advance='no') a(i)
          if (mod(i - 1, 20) == 0) then
            write(0, *)
          end if
        end do
        write(0, *)
        end subroutine
        subroutine kernel_jacobi1d(tsteps, n, a, b)
        double precision, dimension(n) :: a
        double precision, dimension(n) :: b
        integer :: n, tsteps
        integer :: i, t, j
      CONTINUE
      !DIR$ scop
        !$omp unroll factor(4)
        do t = 1, tsteps
          do i = 2, n - 1
            b(i) = 0.33333D0 * (a(i - 1) + a(i) + a(i + 1))
          end do
          do j = 2, n -1
            a(j) = b(j)
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
