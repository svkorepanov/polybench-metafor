!******************************************************************************
!
!  syrk.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program syrk
      double precision :: alpha
      double precision :: beta
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: c
      integer :: i
!     Allocation of Arrays
      allocate(a( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(c( 128+0, 128+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(128, 128, alpha, beta, c, a)
!     Kernel Execution
      call kernel_syrk(128, 128, alpha, beta,  &
                              c, a)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(128, c);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(c)
      contains
        subroutine init_array(ni, nj, alpha, beta, c, a)
        double precision, dimension(ni, ni) :: a
        double precision, dimension(nj, ni) :: c
        double precision :: alpha , beta
        integer :: nj, ni
        integer :: i, j
        alpha = 32412
        beta = 2123
        do i = 1, ni
          do j = 1, nj
            a(j, i) = (DBLE(i - 1) * DBLE(j - 1)) / DBLE(ni)
          end do
          do j = 1, ni
            c(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(ni)
          end do
        end do
        end subroutine
        subroutine print_array(ni, c)
        double precision, dimension(ni, ni) :: c
        integer :: ni
        integer :: i, j
        do i = 1, ni
          do j = 1, ni
            write(0, "(f0.2,1x)", advance='no') c(j, i)
            if (mod(((i - 1) * ni) + j - 1, 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_syrk(ni, nj, alpha, beta, c, a)
        double precision, dimension(ni, ni) :: a
        double precision, dimension(nj, ni) :: c
        double precision :: alpha , beta
        integer :: nj, ni
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        !$omp tile sizes(32,32)
        do i = 1, ni
          do j = 1, ni
            c(j, i) = c(j, i) * beta
          end do
        end do
        !$omp tile sizes(32,32)
        do i = 1, ni
          do j = 1, ni
            do k = 1, nj
              c(j, i) = c(j, i) + (alpha * a(k, i) * a(k, j))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
