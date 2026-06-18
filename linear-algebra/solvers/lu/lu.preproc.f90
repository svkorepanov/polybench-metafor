!******************************************************************************
!
!  lu.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 1024. 
      program lu
      double precision, dimension(:,:), allocatable :: a
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(a( 2000+0, 2000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(2000, a)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_lu(2000, a)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(2000, a);  end if;
!     Deallocation of Arrays 
      deallocate(a)
      contains
        subroutine init_array(n, a)
        double precision, dimension(n, n) :: a
        integer :: n
        integer :: i, j
        do i = 1, n
          do j = 1, n
            a(j, i) = (DBLE(i) * DBLE(j)) / DBLE(n)
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
        write(0, *)
        end subroutine
        subroutine kernel_lu(n, a)
        double precision, dimension(n, n) :: a
        integer :: n
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do k = 1, n
          do j = k + 1, n
            a(j, k) = a(j, k) / a(k, k)
          end do
          do i = k + 1, n
            do j = k + 1, n
              a(j, i) = a(j, i) - (a(k, i) * a(j, k))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
