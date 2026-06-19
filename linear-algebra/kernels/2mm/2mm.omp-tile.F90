!******************************************************************************
!
!  2mm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "2mm.h"

program two_mm
   implicit none

   polybench_2d_array_decl(tmp, data_type, nj, ni)
   polybench_2d_array_decl(a, data_type, nk, ni)
   polybench_2d_array_decl(b, data_type, nj, nk)
   polybench_2d_array_decl(c, data_type, nl, nj)
   polybench_2d_array_decl(d, data_type, nl, ni)
   data_type :: alpha, beta
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(tmp, nj, ni)
   polybench_alloc_2d_array(a, nk, ni)
   polybench_alloc_2d_array(b, nj, nk)
   polybench_alloc_2d_array(c, nl, nj)
   polybench_alloc_2d_array(d, nl, ni)

   !     Initialization
   call init_array(alpha, beta, a, b, c, d, ni, nj, &
   nk, nl)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_2mm(alpha, beta, tmp, a, b, c, d, &
   ni, nj, nk, nl)


   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(d, ni, nl)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(tmp)
   polybench_dealloc_array(a)
   polybench_dealloc_array(b)
   polybench_dealloc_array(c)
   polybench_dealloc_array(d)

   contains

   subroutine init_array(alpha, beta, a, b, c, d, ni, nj, &
   nk, nl)
      implicit none

      data_type, dimension(nk, ni) :: a
      data_type, dimension(nj, nk) :: b
      data_type, dimension(nl, nj) :: c
      data_type, dimension(nl, ni) :: d
      data_type :: alpha, beta
      integer :: ni, nj, nk, nl
      integer :: i, j

      alpha = 32412;
      beta = 2123;

      do i = 1, ni
         do j = 1, nk
            a(j, i) = dble((i - 1) * (j - 1)) / ni
         end do
      end do

      do i = 1, nk
         do j = 1, nj
            b(j, i) = (dble((i - 1) * (j)))/ nj
         end do
      end do

      do i = 1, nl
         do j = 1, nj
            c(j, i) = (dble(i - 1) * (j + 2))/ nl
         end do
      end do

      do i = 1, ni
         do j = 1, nl
            d(j, i) = (dble(i - 1) * (j + 1))/ nk
         end do
      end do
   end subroutine


   subroutine print_array(d, ni, nl)
      implicit none

      data_type, dimension(nl, ni) :: d
      integer :: nl, ni
      integer :: i, j
      do i = 1, ni
         do j = 1, nl
            write(0, data_printf_modifier) d(j, i)

            if (mod(((i - 1) * ni) + j - 1, 20) == 0) then
               write(0, *)
            end if

         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_2mm(alpha, beta, tmp, a, b, c, d, &
   ni, nj, nk, nl)
      implicit none

      data_type, dimension(nj, ni) :: tmp
      data_type, dimension(nk, ni) :: a
      data_type, dimension(nj, nk) :: b
      data_type, dimension(nl, nj) :: c
      data_type, dimension(nl, ni) :: d
      data_type :: alpha, beta
      integer :: ni, nj, nk, nl
      integer :: i, j, k

      !$pragma scop
      !$omp tile sizes(32,32)
      do i = 1, _pb_ni
         do j = 1, _pb_nj
            tmp(j, i) = 0.0
            do k = 1, _pb_nk
               tmp(j, i) = tmp(j, i) + alpha * a(k, i) * b(j, k)
            end do
         end do
      end do
      
      !$omp tile sizes(32,32)
      do i = 1, _pb_ni
         do j = 1, _pb_nl
            d(j, i) = d(j, i) * beta
            do k = 1, _pb_nj
               d(j, i) = d(j, i) + tmp(k, i) * c(j, k)
            end do
         end do
      end do
      !$pragma endscop
   end subroutine

end program
