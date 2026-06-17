!******************************************************************************
!
!  syr2k.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 4000. 
      program syr2k
      double precision :: alpha
      double precision :: beta
      double precision, dimension(:,:), allocatable :: a
      double precision, dimension(:,:), allocatable :: b
      double precision, dimension(:,:), allocatable :: c
      integer :: i
!     Allocation of Arrays
      allocate(a( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(b( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(c( 128+0, 128+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(128, 128, alpha, beta, c, a, b)
!     Kernel Execution
      call kernel_syr2k(128, 128, alpha, beta,  &
                              c, a, b)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(128, c);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(b)
      deallocate(c)
      contains
        subroutine init_array(ni, nj, alpha, beta, c, a, b)
        double precision, dimension(nj, ni) :: a
        double precision, dimension(nj, ni) :: b
        double precision, dimension(ni, ni) :: c
        double precision :: alpha, beta
        integer :: ni, nj
        integer :: i, j
        alpha = 32412.0D0
        beta = 2123.0D0
        do i = 1, ni
          do j = 1, nj
            a(j, i) = (DBLE(i - 1) * DBLE(j - 1)) / DBLE(ni)
            b(j, i) = ((DBLE(i - 1) * DBLE(j - 1))) / DBLE(ni)
          end do
        end do
        do i = 1, ni
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
        subroutine kernel_syr2k(ni, nj, alpha, beta, c, a, b)
        double precision, dimension(nj, ni) :: a
        double precision, dimension(nj, ni) :: b
        double precision, dimension(ni, ni) :: c
        double precision :: alpha, beta
        integer :: ni, nj
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        !$omp unroll factor(4)
        do i = 1, ni
          do j = 1, ni
            c(j, i) = c(j, i) * beta
          end do
        end do
        do i = 1, ni
          do j = 1, ni
            do k = 1, ni
              c(j, i) = c(j, i) + (alpha * a(k, i) * b(k, j))
              c(j, i) = c(j, i) + (alpha * b(k, i) * a(k, j))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
