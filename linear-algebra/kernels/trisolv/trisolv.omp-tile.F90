!******************************************************************************
!
!  trisolv.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "trisolv.h"

program trisolv
   implicit none

   polybench_2d_array_decl(a, data_type, n, n)
   polybench_1d_array_decl(x, data_type, n)
   polybench_1d_array_decl(c, data_type, n)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(a, n, n)
   polybench_alloc_1d_array(x, n)
   polybench_alloc_1d_array(c, n)

   !     Initialization
   call init_array(n, a, x, c)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_trisolv(n, &
   a, x, c)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(n, x)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(x)
   polybench_dealloc_array(c)

   contains

   subroutine init_array(n, a, x, c)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n) :: c
      data_type, dimension(n) :: x
      integer :: n
      integer :: i, j
      do i = 1, n
         c(i) = dble(i - 1) / dble(n)
         x(i) = dble(i - 1) / dble(n)
         do j = 1, n
            a(j, i) = (dble(i - 1) * dble(j - 1)) / dble(n)
         end do
      end do
   end subroutine


   subroutine print_array(n, x)
      implicit none

      data_type, dimension(n) :: x
      integer :: n
      integer :: i
      do i = 1, n
         write(0, data_printf_modifier) x(i)
         if (mod((i - 1), 20) == 0) then
            write(0, *)
         end if
      end do
   end subroutine


   subroutine kernel_trisolv(n, a, x, c)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n) :: c
      data_type, dimension(n) :: x
      integer :: n
      integer :: i, j

      !$pragma scop
      !$omp tile sizes(32)
      do i = 1, _pb_n
         x(i) = c(i)
         do j = 1, i - 1
            x(i) = x(i) - (a(j, i) * x(j))
         end do
         x(i) = x(i) / a(i, i)
      end do
      !$pragma endscop
   end subroutine

end program
