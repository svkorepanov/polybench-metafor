!******************************************************************************
!
!  trmm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program trmm
   double precision :: alpha
    double precision, dimension(:,:), allocatable :: a
    double precision, dimension(:,:), allocatable :: b
   integer :: ni = 2000, i;       character(LEN = 30) :: arg
   !     Allocation of Arrays
   allocate(a( ni+0, ni+0), STAT=I); call check_err(I)
   allocate(b( ni+0, ni+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(ni, alpha, a, b)
   !     Kernel Execution
   call polybench_timer_start();
   call kernel_trmm(ni, alpha, a, b)
   call polybench_timer_stop();
   call polybench_timer_print();
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(ni, b);  end if ;
   !     Deallocation of Arrays
   deallocate(a)
   deallocate(b)
   contains
   subroutine init_array(n, alpha, a, b)
      double precision, dimension(n, n) :: a
      double precision, dimension(n, n) :: b
      double precision :: alpha
      integer :: n
      integer :: i, j
      alpha = 32412d0
      do i = 1, n
         do j = 1, n
            a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
            b(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
         end do
      end do
   end subroutine
   subroutine print_array(n, b)
      double precision, dimension(n, n) :: b
      integer :: n
      integer :: i, j
      do i = 1, n
         do j = 1, n
            write(0, "(f0.2,1x)", advance='no') b(j, i)
            if (mod(((i - 1) * n) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine
   subroutine kernel_trmm(ni, alpha, a, b)
      double precision, dimension(ni, ni) :: a
      double precision, dimension(ni, ni) :: b
      double precision :: alpha
      integer :: ni
      integer :: i, j, k
            CONTINUE
      !DIR$ scop
      do i = 2, ni
         do j = 1, ni
            do k = 1, i - 1
               b(j, i) = b(j, i) + (alpha * a(k, i) * b(k, j))
            end do
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
