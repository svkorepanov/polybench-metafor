!******************************************************************************
!
!  mvt.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program mvt
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:), allocatable :: x1
      double precision, dimension(:), allocatable :: y1
      double precision, dimension(:), allocatable :: x2
      double precision, dimension(:), allocatable :: y2
      integer :: i
!     Allocation of Arrays
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(x1( 500+0), STAT=I); call check_err(I)
      allocate(y1( 500+0), STAT=I); call check_err(I)
      allocate(x2( 500+0), STAT=I); call check_err(I)
      allocate(y2( 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, x1, x2, y1, y2, a)
!     Kernel Execution
      call kernel_mvt(500, x1, x2, &
                              y1, y2, a)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, x1, x2);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(x1)
      deallocate(y1)
      deallocate(x2)
      deallocate(y2)
      contains
        subroutine init_array(n, x1, x2, y1, y2, a)
        double precision, dimension(n, n) :: a
        double precision, dimension(n) :: x1
        double precision, dimension(n) :: y1
        double precision, dimension(n) :: x2
        double precision, dimension(n) :: y2
        integer :: n
        integer :: i, j
        do i = 1, n
          x1(i) = DBLE(i - 1) / DBLE(n)
          x2(i) = (DBLE(i - 1) + 1.0D0) / DBLE(n)
          y1(i) = (DBLE(i - 1) + 3.0D0) / DBLE(n)
          y2(i) = (DBLE(i - 1) + 4.0D0) / DBLE(n)
          do j = 1, n
            a(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, x1, x2)
        double precision, dimension(n) :: x1
        double precision, dimension(n) :: x2
        integer :: n
        integer :: i
        do i = 1, n
          write(0, "(f0.2,1x)", advance='no') x1(i)
          write(0, "(f0.2,1x)", advance='no') x2(i)
          if (mod((i - 1), 20) == 0) then
            write(0, *)
          end if
        end do
        write(0, *)
        end subroutine
        subroutine kernel_mvt(n, x1, x2, y1, y2, a)
        double precision, dimension(n, n) :: a
        double precision, dimension(n) :: x1
        double precision, dimension(n) :: y1
        double precision, dimension(n) :: x2
        double precision, dimension(n) :: y2
        integer :: n
        integer :: i, j
      CONTINUE
      !DIR$ scop
        !$omp unroll factor(4)
        do i = 1, n
          do j = 1, n
            x1(i) = x1(i) + (a(j, i) * y1(j))
          end do
        end do
        !$omp unroll factor(4)
        do i = 1, n
          do j = 1, n 
            x2(i) = x2(i) + (a(i, j) * y2(j))
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
