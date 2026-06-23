!******************************************************************************
!
!  floyd-warshall.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 1024. 
      program floyd_warshall
      double precision, dimension(:,:), allocatable :: path
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(path( 2000+0, 2000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(2000, path)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_floyd_warshall(2000, path)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(2000, path);  end if;
!     Deallocation of Arrays 
      deallocate(path)
      contains
        subroutine init_array(n, path)
        double precision, dimension(n,n) :: path
        integer :: i, j, n 
        do i=1, n
          do j=1, n
            path(j, i) = (DBLE(i * j))/ DBLE(n)
          end do
        end do
        end subroutine
        subroutine print_array(n, path)
        double precision, dimension(n, n) :: path
        integer :: i, j, n
        do i=1, n
          do j=1, n
             write(0, "(f0.2,1x)", advance='no') path(j,i) 
             if (mod(((i - 1) * n) + j - 1, 20) == 0) then
               write(0, *)
             end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_floyd_warshall(n, path)
        double precision, dimension(n,n) :: path
        integer :: n
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do k=1, n
          do i=1, n
            do j=1, n
               if( path(j, i) .GE. path(k, i) + path(j, k) ) then
                 path(j, i) = path(k, i) + path(j, k)
               end if
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
