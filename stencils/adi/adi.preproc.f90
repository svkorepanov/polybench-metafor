!*****************************************************************************
!                                                                             
!  adi.F90: This file is part of the PolyBench/Fortran 1.0 test suite.          
!                                                                             
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>                   
!  Web address: http://polybench.sourceforge.net                              
!                                                                             
!*****************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 10x1024x1024. 
      program adi
      double precision, dimension(:,:), allocatable :: x
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: b
      integer :: i
!     Allocation of Arrays
      allocate(x( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(a( 500+0, 500+0), STAT=I); call check_err(I)
      allocate(b( 500+0, 500+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(500, x, a, b)
!     Kernel Execution
      call kernel_adi(10, 500, x, a, b)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(500, x);  ;
!     Deallocation of Arrays 
      deallocate(x)
      deallocate(a)
      deallocate(b)
      contains
        subroutine init_array(n, x, a, b)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: x
        double precision, dimension(n, n) :: b
        integer :: n
        integer :: i, j
        do i = 1, n
          do j = 1, n
            x(j, i) = (DBLE((i - 1) * (j)) + 1.0D0) / DBLE(n)
            a(j, i) = (DBLE((i - 1) * (j + 1)) + 2.0D0) / DBLE(n)
            b(j, i) = (DBLE((i - 1) * (j + 2)) + 3.0D0) / DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, x)
        double precision, dimension(n, n) :: x
        integer :: n
        integer :: i, j
        do i = 1, n
          do j = 1, n
            write(0, "(f0.2,1x)", advance='no') x(j, i)
            if (mod(((i - 1) * n) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_adi(tsteps, n, x, a, b)
        double precision, dimension(n, n) :: a
        double precision, dimension(n, n) :: x
        double precision, dimension(n, n) :: b
        integer :: n, tsteps
        integer :: i1, i2, t
      CONTINUE
      !DIR$ scop
        do t = 1, tsteps
          do i1 = 1, n
            do i2 = 2, n
              x(i2, i1) = x(i2, i1) - ((x(i2 - 1, i1) * a(i2, i1)) / &
                          b(i2 - 1, i1))
              b(i2, i1) = b(i2, i1) - ((a(i2, i1) * a(i2, i1)) / &
                          b(i2 - 1, i1))
            end do
          end do
          do i1 = 1, n
            x(n, i1) = x(n, i1) / b(n, i1)
          end do
          do i1 = 1, n 
            do i2 = 1, n - 2
              x(n - i2, i1) = (x(n - i2, i1) - &
                                    (x(n - i2 - 1, i1) * &
                                    a(n - i2 - 1, i1))) / &
                                    b(n - i2 - 1, i1)
            end do
          end do
          do i1 = 2, n 
            do i2 = 1, n 
              x(i2, i1) = x(i2, i1) - x(i2, i1 - 1) * a(i2, i1) / &
                          b(i2, i1 - 1)
              b(i2, i1) = b(i2, i1) - a(i2, i1) * a(i2, i1) / &
                          b(i2, i1 - 1)
            end do
          end do
          do i2 = 1, n
            x(i2, n) = x(i2, n) / b(i2, n)
          end do
          do i1 = 1, n - 2
            do i2 = 1, n
              x(i2, n - i1) = (x(i2, n - i1) - &
                                    x(i2, n - i1 - 1) * &
                                    a(i2, n - i1 - 1)) / &
                                    b(i2, n - i1)
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
