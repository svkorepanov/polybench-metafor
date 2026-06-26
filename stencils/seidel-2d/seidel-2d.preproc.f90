!******************************************************************************
!
!  seidel-2d.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 20x1000. 
      program seidel
      double precision, dimension(:,:), allocatable :: a
      integer :: i
!     Allocation of Arrays
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, a)
!     Kernel Execution
      call kernel_seidel(10, 500, a)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, a);  ;
!     Deallocation of Arrays 
      deallocate(a)
      contains
        subroutine init_array(n, a)
        double precision, dimension(n, n) :: a
        integer :: n
        integer :: i,j
        do i = 1, n
          do j = 1, n
            a(j, i) = ((DBLE(i - 1) * DBLE(j + 1)) + 2.0D0) / n
          end do
        end do
        end subroutine
        subroutine print_array(n, a)
        double precision, dimension(n, n) :: a
        integer :: n
        integer :: i,j
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
        subroutine kernel_seidel(tsteps, n, a)
        double precision, dimension(n, n) :: a
        integer :: n, tsteps
        integer :: i, t, j
      CONTINUE
      !DIR$ scop
        do t = 1, tsteps
          do i = 2, n - 1
            do j = 2, n - 1
            a(j, i) = (a(j - 1, i - 1) + a(j, i - 1) + a(j + 1, i - 1) + &
                       a(j - 1, i) + a(j, i) + a(j + 1, i) + &
                       a(j - 1, i + 1) + a(j, i + 1) + &
                       a(j + 1, i + 1))/9.0D0
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
