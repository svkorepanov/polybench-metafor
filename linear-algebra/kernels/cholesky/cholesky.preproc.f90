!******************************************************************************
!
!  cholesky.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program cholesky
      double precision, dimension(:,:), allocatable :: a 
      double precision, dimension(:), allocatable :: p 
      double precision x
      integer :: i
!     Allocation of Arrays
      allocate(a( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(p( 128+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(128, p, a)
!     Kernel Execution
      call kernel_cholesky(128, p, a)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(128, a);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(p)
      contains
        subroutine init_array(n, p, a)
        double precision, dimension(n, n) :: a
        double precision, dimension(n) :: p
        integer :: n
        integer :: i, j
        do i = 1, n
          p(i) = 1.0D0  / n
          do j = 1, n
            a(j, i) =  1.0D0 / n
          end do
        end do
        end subroutine
        subroutine print_array(n, a)
        double precision, dimension(n, n) :: a
        integer :: n
        integer :: i, j
        do i = 1, n
          do j = 1, n
            write(0, "(f0.2,1x)", advance='no') a(j, i)
            if (mod(((i - 1) * n) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        end subroutine
        subroutine kernel_cholesky(n, p, a)
        double precision, dimension(n, n) :: a
        double precision, dimension(n) :: p
        double precision :: x
        integer :: n
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do i = 1, n
          x = a(i, i)
          do j = 1, i - 1
            x = x - a(j, i) * a(j, i)
          end do
          p(i) = 1.0D0 / sqrt(x)
          do j = i + 1, n
            x = a(j, i)
            do k = 1, i - 1
              x = x - (a(k, j) * a(k, i))
            end do
            a(i, j) = x * p(i)
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
