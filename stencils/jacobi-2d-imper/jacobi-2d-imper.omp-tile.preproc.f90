!******************************************************************************
!
!  jacobi-2d-imper.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 20x1000. 
      program jacobi2d
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: b
      integer :: i
!     Allocation of Arrays
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(b( 500+0, 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, a, b)
!     Kernel Execution
      call kernel_jacobi_2d_imper(10, 500, a, b)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, a);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(b)
      contains
        subroutine init_array(n, a, b)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: b
        integer :: n
        integer :: i, j
        do i = 1, n
          do j = 1, n
            a(j, i) = (DBLE(i - 1) * DBLE(j + 1) + 2.0D0) / n
            b(j, i) = (DBLE(i - 1) * DBLE(j + 2) + 3.0D0) / n
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
            if (mod((i - 1) * n + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_jacobi_2d_imper(tsteps, n, a, b)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: b
        integer :: n, tsteps
        integer :: i, j, t
      CONTINUE
      !DIR$ scop
        !$omp tile sizes(32,32)
        do t = 1, tsteps
          do i = 2, n - 1
            do j = 2, n - 1
              b(j, i) = 0.2D0 * (a(j, i) + a(j - 1, i) + a(1 + j, i) + &
                                 a(j, 1 + i) + a(j, i - 1))
            end do
          end do
          do i = 2, n - 1
            do j = 2, n - 1
              a(j, i) = b(j, i)
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
