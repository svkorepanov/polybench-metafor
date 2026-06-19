!******************************************************************************
!
!  3mm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "3mm.h"

program three_mm
   implicit none

   polybench_2d_array_decl(a, data_type, nk, ni)
   polybench_2d_array_decl(b, data_type, nj, nk)
   polybench_2d_array_decl(c, data_type, nm, nj)
   polybench_2d_array_decl(d, data_type, nl, nm)
   polybench_2d_array_decl(e, data_type, nj, ni)
   polybench_2d_array_decl(f, data_type, nl, nj)
   polybench_2d_array_decl(g, data_type, nl, ni)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(a, nk, ni)
   polybench_alloc_2d_array(b, nj, nk)
   polybench_alloc_2d_array(c, nm, nj)
   polybench_alloc_2d_array(d, nl, nm)
   polybench_alloc_2d_array(e, nj, ni)
   polybench_alloc_2d_array(f, nl, nj)
   polybench_alloc_2d_array(g, nl, ni)

   !     Initialization
   call init_array(ni, nj, nk, nl, nm, &
   a, b, c, d)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_3mm(ni, nj, nk, nl, nm, &
   e, a, b, f, c, d, g)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(ni, nl, g)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(b)
   polybench_dealloc_array(c)
   polybench_dealloc_array(d)
   polybench_dealloc_array(e)
   polybench_dealloc_array(f)
   polybench_dealloc_array(g)

   contains

   subroutine init_array(ni, nj, nk, nl, nm, a, b, c, d)
      implicit none

      data_type, dimension(nk, ni) :: a
      data_type, dimension(nj, nk) :: b
      data_type, dimension(nm, nj) :: c
      data_type, dimension(nl, nm) :: d
      integer :: ni, nj, nk, nl, nm
      integer :: i, j

      do i = 1, ni
         do j = 1, nk
            a(j, i) = dble(i - 1) * dble(j - 1) / ni
         end do
      end do

      do i = 1, nk
         do j = 1, nj
            b(j, i) = (dble(i - 1) * dble(j))/ nj
         end do
      end do

      do i = 1, nj
         do j = 1, nm
            c(j, i) = (dble(i - 1) * dble(j + 2))/ nl
         end do
      end do

      do i = 1, nm
         do j = 1, nl
            d(j, i) = (dble(i - 1) * dble(j + 1))/ nk
         end do
      end do
   end subroutine


   subroutine print_array(ni, nl, g)
      implicit none

      data_type, dimension(nl, ni) :: g
      integer :: ni, nl
      integer :: i, j
      do i = 1, ni
         do j = 1, nl
            write(0, data_printf_modifier) g(j, i)
            if (mod(((i - 1) * ni) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_3mm(ni, nj, nk, nl, nm, e, a, b, f, c, d, g)
      implicit none

      data_type, dimension(nk, ni) :: a
      data_type, dimension(nj, nk) :: b
      data_type, dimension(nm, nj) :: c
      data_type, dimension(nl, nm) :: d
      data_type, dimension(nj, ni) :: e
      data_type, dimension(nl, nj) :: f
      data_type, dimension(nl, ni) :: g
      integer :: ni, nj, nk, nl, nm
      integer :: i, j, k

      !$pragma scop
      ! E := A*B
      !$omp tile sizes(32,32)
      do i = 1, _pb_ni
         do j = 1, _pb_nj
            e(j, i) = 0.0
            do k = 1, _pb_nk
               e(j, i) = e(j, i) + a(k, i) * b(j, k)
            end do
         end do
      end do

      ! F := C*D
      !$omp tile sizes(32,32)
      do i = 1, _pb_nj
         do j = 1, _pb_nl
            f(j, i) = 0.0
            do k = 1, _pb_nm
               f(j, i) = f(j, i) + c(k, i) * d(j, k)
            end do
         end do
      end do

      ! G := E*F
      !$omp tile sizes(32,32)
      do i = 1, _pb_ni
         do j = 1, _pb_nl
            g(j, i) = 0.0
            do k = 1, _pb_nj
               g(j, i) = g(j, i) + e(k, i) * f(j, k)
            end do
         end do
      end do
      !$pragma endscop

   end subroutine

end program
