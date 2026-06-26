!******************************************************************************
!
!  gramschmidt.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
! 
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header. 
! Include benchmark-specific header. 
! Default data type is double, default size is 512. 
      program gramschmidt
      double precision, dimension(:,:), allocatable :: a 
      double precision, dimension(:,:), allocatable :: r 
      double precision, dimension(:,:), allocatable :: q 
      integer :: i
!     Allocation of Arrays
      allocate(a( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(r( 128+0, 128+0), STAT=I); call check_err(I)
      allocate(q( 128+0, 128+0), STAT=I); call check_err(I)
!     Initialization
      call init_array(128, 128, a, r, q)
!     Kernel Execution
      call kernel_gramschmidt(128, 128, a, r, q)
!     Prevent dead-code elimination. All live-out data must be printed
!     by the function call in argument. 
            call print_array(128, 128, a, r, q);  ;
!     Deallocation of Arrays 
      deallocate(a)
      deallocate(r)
      deallocate(q)
      contains
        subroutine init_array(ni, nj, a, r, q)
        double precision, dimension(nj, ni) :: a
        double precision, dimension(nj, nj) :: r
        double precision, dimension(nj, ni) :: q
        integer :: ni, nj
        integer :: i, j
        do i = 1, ni 
          do j = 1, nj
            a(j, i) = (DBLE(i - 1) * DBLE(j - 1)) / DBLE(ni)
            q(j, i) = (DBLE(i - 1) * DBLE(j)) / DBLE(nj)
          end do
        end do
        do i = 1, ni 
          do j = 1, nj
            r(j, i) = (DBLE(i - 1) * DBLE(j + 1)) / DBLE(nj)
          end do
        end do
        end subroutine
        subroutine print_array(ni, nj, a, r, q)
        double precision, dimension(nj, ni) :: a
        double precision, dimension(nj, nj) :: r
        double precision, dimension(nj, ni) :: q
        integer :: ni, nj
        integer :: i, j
        do i = 1, ni 
          do j = 1, nj
            write(0, "(f0.2,1x)", advance='no') a(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        do i = 1, nj 
          do j = 1, nj
            write(0, "(f0.2,1x)", advance='no') r(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        do i = 1, ni 
          do j = 1, nj
            write(0, "(f0.2,1x)", advance='no') q(j, i)
            if (mod((i - 1), 20) == 0) then
              write(0, *)
            end if
          end do
        end do
        write(0, *)
        end subroutine
        subroutine kernel_gramschmidt(ni, nj, a, r, q) 
        double precision, dimension(nj, ni) :: a
        double precision, dimension(nj, nj) :: r
        double precision, dimension(nj, ni) :: q
        double precision :: nrm
        integer :: ni, nj
        integer :: i, j, k
      CONTINUE
      !DIR$ scop
        do k = 1, nj
          nrm = 0.0D0
          do i = 1, ni
            nrm = nrm + (a(k, i) * a(k, i))
          end do
          r(k, k) = sqrt(nrm)
          do i = 1, ni
            q(k, i) = a(k, i) / r(k, k)
          end do
          do j = k + 1, nj
            r(j, k) = 0.0D0
            do i = 1, ni
              r(j, k) = r(j, k) + (q(k, i) * a(j, i))
            end do
            do i = 1, ni
              a(j, i) = a(j, i) - (q(k, i) * r(j, k))
            end do
          end do
        end do
!DIR$ end scop
        end subroutine
      end program
