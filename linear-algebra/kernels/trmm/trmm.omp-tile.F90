!******************************************************************************
!
!  trmm.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "trmm.h"

program trmm
   implicit none

   data_type :: alpha
   polybench_2d_array_decl(a, data_type, ni, ni)
   polybench_2d_array_decl(b, data_type, ni, ni)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(a, ni, ni)
   polybench_alloc_2d_array(b, ni, ni)

   !     Initialization
   call init_array(ni, alpha, a, b)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_trmm(ni, alpha, a, b)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(ni, b)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(b)

   contains

   subroutine init_array(n, alpha, a, b)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n, n) :: b
      data_type :: alpha
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
      implicit none

      data_type, dimension(n, n) :: b
      integer :: n
      integer :: i, j
      do i = 1, n
         do j = 1, n
            write(0, data_printf_modifier) b(j, i)
            if (mod(((i - 1) * n) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_trmm(ni, alpha, a, b)
      implicit none

      data_type, dimension(ni, ni) :: a
      data_type, dimension(ni, ni) :: b
      data_type :: alpha
      integer :: ni
      integer :: i, j, k

      !$pragma scop
      !$omp tile sizes(32,32)
      do i = 2, _pb_ni
         do j = 1, _pb_ni
            do k = 1, i - 1
               b(j, i) = b(j, i) + (alpha * a(k, i) * b(k, j))
            end do
         end do
      end do
      !$pragma endscop
   end subroutine

end program

