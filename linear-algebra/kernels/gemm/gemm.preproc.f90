!******************************************************************************
!
!  gemm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program gemm
      double precision :: alpha
      double precision :: beta
      double precision, dimension(:,:), allocatable :: c
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: b
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(c( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(a( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(b( 2000+0, 2000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(2000, 2000, 2000,  &
                           alpha, beta, c, a, b)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_gemm(2000, 2000, 2000, alpha, beta,  &
                              c, a, b)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(2000, 2000, c);  end if;
!     Deallocation of Arrays 
      deallocate(c)
      deallocate(a)
      deallocate(b)
      contains
        subroutine init_array(ni, nj, nk, alpha, beta, c, a, b)
        double precision, dimension(nk, ni) :: a
        double precision, dimension(nj, nk) :: b
        double precision, dimension(nj, ni) :: c
        double precision :: alpha, beta
        integer :: ni, nj, nk
        integer :: i, j
        alpha = 32412
        beta = 2123
        do i = 1, ni
          do j = 1, nj
            c(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(ni)
          end do
        end do
        do i = 1, ni
          do j = 1, nk
            a(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(ni)
          end do
        end do
        do i = 1, nk
          do j = 1, nj
            b(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(ni)
          end do
        end do
        end subroutine
        subroutine print_array(ni, nj, c)
        double precision, dimension(nj, ni) :: c
        integer :: ni, nj
        integer :: i, j
        do i = 1, ni
          do j = 1, nj
            write(0, "(f0.2,1x)", advance='no') c(j, i)
            if (mod(((i - 1) * ni) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_gemm(ni, nj, nk, alpha, beta, c, a, b)
        double precision, dimension(nk, ni) :: a
        double precision, dimension(nj, nk) :: b
        double precision, dimension(nj, ni) :: c
        double precision :: alpha, beta
        integer :: ni, nj, nk
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do i = 1, ni
          do j = 1, nj
            c(j, i) = c(j, i) * beta
            do k  = 1, nk
              c(j, i) = c(j, i) + (alpha * a(k, i) * b(j, k))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
