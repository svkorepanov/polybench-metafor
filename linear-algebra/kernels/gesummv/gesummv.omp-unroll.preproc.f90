!******************************************************************************
!
!  gesummv.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program gesummv
      double precision :: alpha
      double precision :: beta
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: b
      double precision, dimension(:), allocatable :: x
      double precision, dimension(:), allocatable :: y
      double precision, dimension(:), allocatable :: tmp
      integer :: i
!     Allocation of Arrays
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(b( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(x( 500+0), STAT=I); call check_err(I)
      allocate(y( 500+0), STAT=I); call check_err(I)
      allocate(tmp( 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, alpha, beta, a, b, x)
!     Kernel Execution
      call kernel_gesummv(500, alpha, beta, &
                              a, b, tmp, x, y)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, y);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(b)
      deallocate(x)
      deallocate(y)
      deallocate(tmp)
      contains
        subroutine init_array(n, alpha, beta, a, b, x)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: b
        double precision, dimension(n) :: x
        double precision :: alpha, beta
        integer :: n
        integer :: i, j
        alpha = 43532.0D0
        beta = 12313.0D0
        do i = 1, n
          x(i) = DBLE(i - 1) / DBLE(n)
          do j = 1, n
            a(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(n)
            b(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, y)
        double precision, dimension(n) :: y
        integer :: n
        integer :: i
        do i = 1, n
          write(0, "(f0.2,1x)", advance='no') y(i)
          if (mod(i - 1, 20) == 0) then
            write(0, *)
          end if
        end do
        end subroutine
        subroutine kernel_gesummv(n, alpha, beta, &
                                a, b, tmp, x, y)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: b
        double precision, dimension(n) :: x, y, tmp
        double precision :: alpha, beta
        integer :: n
        integer :: i, j
      CONTINUE
      !DIR$ scop
        !$omp unroll factor(4)
        do i = 1, n
          tmp(i) = 0.0D0
          y(i) = 0.0D0
          do j = 1, n
            tmp(i) = (a(j, i) * x(j)) + tmp(i)
            y(i) = (b(j, i) * x(j)) + y(i)
          end do
          y(i) = (alpha * tmp(i)) + (beta * y(i))
        end do
!DIR$ end scop
        end subroutine
      end program
