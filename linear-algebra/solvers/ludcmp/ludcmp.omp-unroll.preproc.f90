!******************************************************************************
!
!  ludcmp.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 1024. 
      program ludcmp
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:), allocatable :: x
      double precision, dimension(:), allocatable :: y
      double precision, dimension(:), allocatable :: b
      integer :: i
!     Allocation of Arrays
      allocate(a( 128 + 1+0, 128 + 1+0), STAT=I); call check_err(I)
      allocate(x( 128 + 1+0), STAT=I); call check_err(I)
      allocate(y( 128 + 1+0), STAT=I); call check_err(I)
      allocate(b( 128 + 1+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(128, a, b, x, y)
!     Kernel Execution
      call kernel_ludcmp(128, a, b, x, y)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(128, x);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(x)
      deallocate(y)
      deallocate(b)
      contains
        subroutine init_array(n, a, b, x, y)
        double precision, dimension(n + 1, n + 1) :: a
        double precision, dimension(n + 1) :: x
        double precision, dimension(n + 1) :: b
        double precision, dimension(n + 1) :: y
        integer :: n
        integer :: i, j
        do i = 1, n  + 1
          x(i) = DBLE(i)
          y(i) = (i/n/2.0D0) + 1.0D0
          b(i) = (i/n/2.0D0) + 42.0D0
          do j = 1, n + 1
            a(j, i) = (DBLE(i) * DBLE(j)) / DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, x)
        double precision, dimension(n + 1) :: x
        integer :: n
        integer :: i
        do i = 1, n + 1
          write(0, "(f0.2,1x)", advance='no') x(i)
          if (mod(i - 1, 20) == 0) then
            write(0, *)
          end if
        end do
        end subroutine
        subroutine kernel_ludcmp(n, a, b, x, y)
        double precision, dimension(n + 1, n + 1) :: a
        double precision, dimension(n + 1) :: x
        double precision, dimension(n + 1) :: b
        double precision, dimension(n + 1) :: y
        double precision :: w
        integer :: n
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        b(1) = 1.0D0
        !$omp unroll factor(4)
        do i = 1, n 
          do j = i + 1, n + 1
            w = a(i, j)
            do k = 1, i - 1
              w = w - (a(k, j) * a(i, k))
            end do
            a(i, j) = w / a(i, i)
          end do
          do j = i + 1, n + 1
            w = a(j, i + 1)
            do k = 1, i
              w = w - (a(k, i + 1) * a(j, k))
            end do
            a(j, i + 1) = w
          end do
        end do
        y(1) = b(1)
        do i = 2, n + 1
          w = b(i)
          do j = 1, i - 1
            w = w - (a(j, i) * y(j))
          end do
          y(i) = w
        end do
        x(n + 1) = y(n + 1) / a(n + 1, n + 1)
        do i = 1, n 
          w = y(n + 1 - i)
          do j = n + 2 - i, n + 1
            w = w - (a(j, n + 1 - i) * x(j))
          end do
          x(n + 1 - i) = w / a(n + 1 - i, n + 1 - i)
        end do
!DIR$ end scop
        end subroutine
      end program
