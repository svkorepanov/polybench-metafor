!******************************************************************************
!
!  durbin.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program durbin
      double precision, dimension(:,:), allocatable :: y
      double precision, dimension(:,:), allocatable :: sumArray
      double precision, dimension(:), allocatable :: beta
      double precision, dimension(:), allocatable :: alpha
      double precision, dimension(:), allocatable :: r
      double precision, dimension(:), allocatable :: outArray
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(y( 8000+0, 8000+0), STAT=I); call check_err(I)
      allocate(sumArray( 8000+0, 8000+0), STAT=I); call check_err(I)
      allocate(beta( 8000+0), STAT=I); call check_err(I)
      allocate(alpha( 8000+0), STAT=I); call check_err(I)
      allocate(r( 8000+0), STAT=I); call check_err(I)
      allocate(outArray( 8000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(8000, y, sumArray, alpha, beta, r)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_durbin(8000, y, sumArray, alpha, beta, r, outArray)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(8000, outArray);  end if;
!     Deallocation of Arrays 
      deallocate(y)
      deallocate(sumArray)
      deallocate(beta)
      deallocate(alpha)
      deallocate(r)
      deallocate(outArray)
      contains
        subroutine init_array(n, y, sumArray, alpha, beta, r)
        double precision, dimension(n, n) :: y
        double precision, dimension(n, n) :: sumArray
        double precision, dimension(n) :: beta
        double precision, dimension(n) :: alpha
        double precision, dimension(n) :: r
        integer :: i, j
        integer :: n
        do i = 1, n
          alpha(i) = i
          beta(i) = (i/n)/DBLE(2.0)
          r(i)  = (i/n)/DBLE(4.0)
          do j = 1, n
            y(j,i) = DBLE(i*j)/DBLE(n)
            sumArray(j,i) = DBLE(i*j)/DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, outArray)
        double precision, dimension(n) :: outArray
        integer :: n
        integer :: i
        do i = 1, n
          write(0, "(f0.2,1x)", advance='no') outArray(i)
          if (mod(i - 1, 20) == 0) then
            write(0, *)
          end if
        end do
        end subroutine
        subroutine kernel_durbin(n, y, sumArray, alpha, beta, r,  &
                                                        outArray)
        double precision, dimension(n, n) :: y
        double precision, dimension(n, n) :: sumArray
        double precision, dimension(n) :: beta
        double precision, dimension(n) :: alpha
        double precision, dimension(n) :: r
        double precision, dimension(n) :: outArray
        integer :: i, k, n
      CONTINUE
      !DIR$ scop
        y(1, 1) = r(1)
        beta(1) = 1
        alpha(1) = r(1)
        do k = 2, n
          beta(k) = beta(k - 1) - (alpha(k - 1) * alpha(k - 1) * &
                                   beta(k -1))
          sumArray(k, 1) = r(k)
          do i = 1, k - 1 
            sumArray(k, i + 1) = sumArray(k, i) + &
                                 (r(k - i) * y(k - 1, i))
          end do
          alpha(k) = alpha(k) - (sumArray(k, k) * beta(k))
          do i = 1, k - 1
            y(k, i) = y(k - 1, i) + (alpha(k) * y(k - 1, k - i))
          end do
          y(k, k) = alpha(k)
        end do
        do i = 1, n
          outArray(i) = y(n, i)
        end do
!DIR$ end scop
        end subroutine
      end program
