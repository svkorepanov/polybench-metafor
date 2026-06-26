!******************************************************************************
!
!  doitgen.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************
! Include polybench common header.
! Include benchmark-specific header.
! Default data type is double, default size is 4000.
program doitgen
    double precision, dimension(:,:,:), allocatable :: a
    double precision, dimension(:,:,:), allocatable :: suma
    double precision, dimension(:,:), allocatable :: cfour
   integer :: nr = 32, nq = 32, np = 32, i
   !     Allocation of Arrays
   allocate(a( np+0, nq+0, nr+0), STAT=I); call check_err(I)
   allocate(suma( np+0, nq+0, nr+0), STAT=I); call check_err(I)
   allocate(cfour( np+0, np+0), STAT=I); call check_err(I)
   !     Initialization
   call init_array(nr, nq, np, a, cfour)
   !     Kernel Execution
   call kernel_doitgen(nr, nq, np, &
   a, cfour, suma)
   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
         call print_array(a, nr, nq, np);   ;
   !     Deallocation of Arrays
   deallocate(a)
   deallocate(suma)
   deallocate(cfour)
   contains
   subroutine init_array(nr, nq, np, a, cfour)
      double precision, dimension(np, nq, nr) :: a
      double precision, dimension(np, np) :: cfour
      integer :: nr, nq, np
      integer :: i, j, k
      do i = 1, nr
         do j = 1, nq
            do k = 1, np
               a(k, j, i) = ((dble(i - 1) * dble(j - 1)) + dble(k - 1)) / &
               dble(np)
            end do
         end do
      end do
      do i = 1, np
         do j = 1, np
            cfour(j, i) = (dble(i - 1) * dble(j - 1)) / np
         end do
      end do
   end subroutine
   subroutine print_array(a, nr, nq, np)
      double precision, dimension(np, nq, nr) :: a
      integer :: nr, nq, np
      integer :: i, j, k
      do i = 1, nr
         do j = 1, nq
            do k = 1, np
               write(0, "(f0.2,1x)", advance='no') a(k, j, i)
               if (mod((i - 1), 20) &
                == 0) then
                  write(0, *)
               end if
            end do
         end do
      end do
      write(0, *)
   end subroutine
   subroutine kernel_doitgen(nr, nq, np, &
   a, cfour, suma)
      double precision, dimension(np, nq, nr) :: a
      double precision, dimension(np, nq, nr) :: suma
      double precision, dimension(np, np) :: cfour
      integer :: nr, nq, np
      integer :: r, s, p, q
            CONTINUE
      !DIR$ scop
      do r = 1, nr
         do q = 1, nq
            do p = 1, np
               suma(p, q, r) = 0.0d0
               do s = 1, np
                  suma(p, q, r) = suma(p, q, r) + (a(s, q, r) * &
                  cfour(p, s))
               end do
            end do
            do p = 1, np
               a(p, q, r) = suma(p, q, r)
            end do
         end do
      end do
      !DIR$ end scop
   end subroutine
end program
