!******************************************************************************
!
!  2mm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program two_mm
      double precision, dimension(:,:), allocatable :: tmp 
      double precision, dimension(:,:), allocatable :: a  
      double precision, dimension(:,:), allocatable :: b  
      double precision, dimension(:,:), allocatable :: c  
      double precision, dimension(:,:), allocatable :: d  
      double precision :: alpha, beta
      integer :: i;      character(LEN = 30) :: arg
!     Allocation of Arrays
      allocate(tmp( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(a( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(b( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(c( 2000+0, 2000+0), STAT=I); call check_err(I)
      allocate(d( 2000+0, 2000+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(alpha, beta, a, b, c, d, 2000, 2000,  &
                                             2000, 2000)
!     Kernel Execution
      call polybench_timer_start();
      call kernel_2mm(alpha, beta, tmp, a, b, c, d,  &
                                  2000, 2000, 2000, 2000)
      call polybench_timer_stop();
      call polybench_timer_print();
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
      CALL GET_COMMAND_ARGUMENT(1, arg);                               if( COMMAND_ARGUMENT_COUNT() > 42 .AND.  arg .EQ. '' ) then;      call print_array(d, 2000, 2000);  end if;
!     Deallocation of Arrays 
      deallocate(tmp)
      deallocate(a)
      deallocate(b)
      deallocate(c)
      deallocate(d)
      contains
        subroutine init_array(alpha, beta, a, b, c ,d, ni, nj,  &
             nk, nl)
        double precision, dimension(nk, ni) :: a
        double precision, dimension(nj, nk) :: b
        double precision, dimension(nl, nj) :: c
        double precision, dimension(nl, ni) :: d
        double precision :: alpha, beta
        integer :: ni, nj, nk, nl
        integer :: i, j
        alpha = 32412;
        beta = 2123; 
        do i = 1, ni
          do j = 1, nk
            a(j,i) = DBLE((i-1) * (j-1)) / ni
          end do
        end do
        do i = 1, nk
          do j = 1, nj
            b(j,i) = (DBLE((i-1) * (j)))/ nj
          end do
        end do
        do i = 1, nl
          do j = 1, nj
            c(j,i) = (DBLE(i-1) * (j+2))/ nl
          end do
        end do
        do i = 1, ni
          do j = 1, nl
            d(j,i) = (DBLE(i-1) * (j+1))/ nk
          end do
        end do
        end subroutine
        subroutine print_array(d, ni, nl)
        double precision, dimension(nl, ni) :: d
        integer :: nl, ni
        integer :: i, j
        do i = 1, ni
          do j = 1, nl
            write(0, "(f0.2,1x)", advance='no') d(j,i) 
            if (mod(((i - 1) * ni) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_2mm(alpha, beta, tmp, a, b, c, d,  &
                                              ni, nj, nk, nl)
        double precision, dimension(nj, ni) :: tmp
        double precision, dimension(nk, ni) :: a
        double precision, dimension(nj, nk) :: b
        double precision, dimension(nl, nj) :: c
        double precision, dimension(nl, ni) :: d
        double precision :: alpha, beta
        integer :: ni, nj, nk, nl
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do i = 1, ni
          do j = 1, nj
            tmp(j,i) = 0.0
            do k = 1, nk
              tmp(j,i) = tmp(j,i) + alpha * a(k,i) * b(j,k)
            end do
          end do
        end do
        do i = 1, ni
          do j = 1, nl
            d(j,i) = d(j,i) * beta
            do k = 1, nj
              d(j,i) = d(j,i) + tmp(k,i) * c(j,k)
            end do
          end do
        end do
!DIR$ end scop
        end subroutine 
      end program
