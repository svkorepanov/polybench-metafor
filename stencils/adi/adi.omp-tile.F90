!*****************************************************************************
!
!  adi.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!*****************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 10x1024x1024.
#include "adi.h"

program adi
   implicit none

   polybench_2d_array_decl(x, data_type, n, n)
   polybench_2d_array_decl(a, data_type, n, n)
   polybench_2d_array_decl(b, data_type, n, n)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(x, n, n)
   polybench_alloc_2d_array(a, n, n)
   polybench_alloc_2d_array(b, n, n)

   !     Initialization
   call init_array(n, x, a, b)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_adi(tsteps, n, x, a, b)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(n, x)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(x)
   polybench_dealloc_array(a)
   polybench_dealloc_array(b)

   contains

   subroutine init_array(n, x, a, b)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n, n) :: x
      data_type, dimension(n, n) :: b
      integer :: n
      integer :: i, j

      do i = 1, n
         do j = 1, n
            x(j, i) = (dble((i - 1) * (j)) + 1.0d0) / dble(n)
            a(j, i) = (dble((i - 1) * (j + 1)) + 2.0d0) / dble(n)
            b(j, i) = (dble((i - 1) * (j + 2)) + 3.0d0) / dble(n)
         end do
      end do
   end subroutine


   subroutine print_array(n, x)
      implicit none

      data_type, dimension(n, n) :: x
      integer :: n
      integer :: i, j

      do i = 1, n
         do j = 1, n
            write(0, data_printf_modifier) x(j, i)
            if (mod(((i - 1) * n) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_adi(tsteps, n, x, a, b)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n, n) :: x
      data_type, dimension(n, n) :: b
      integer :: n, tsteps
      integer :: i1, i2, t

      !$pragma scop
      do t = 1, _pb_tsteps
        !$omp tile sizes(32,32)
         do i1 = 1, _pb_n
            do i2 = 2, _pb_n
               x(i2, i1) = x(i2, i1) - ((x(i2 - 1, i1) * a(i2, i1)) / &
               b(i2 - 1, i1))
               b(i2, i1) = b(i2, i1) - ((a(i2, i1) * a(i2, i1)) / &
               b(i2 - 1, i1))
            end do
         end do

         do i1 = 1, _pb_n
            x(_pb_n, i1) = x(_pb_n, i1) / b(_pb_n, i1)
         end do

        !$omp tile sizes(32,32)
         do i1 = 1, _pb_n
            do i2 = 1, _pb_n - 2
               x(_pb_n - i2, i1) = (x(_pb_n - i2, i1) - &
               (x(_pb_n - i2 - 1, i1) * &
               a(_pb_n - i2 - 1, i1))) / &
               b(_pb_n - i2 - 1, i1)
            end do
         end do

        !$omp tile sizes(32,32)
         do i1 = 2, _pb_n
            do i2 = 1, _pb_n
               x(i2, i1) = x(i2, i1) - x(i2, i1 - 1) * a(i2, i1) / &
               b(i2, i1 - 1)
               b(i2, i1) = b(i2, i1) - a(i2, i1) * a(i2, i1) / &
               b(i2, i1 - 1)

            end do
         end do

         do i2 = 1, _pb_n
            x(i2, _pb_n) = x(i2, _pb_n) / b(i2, _pb_n)
         end do

        !$omp tile sizes(32,32)
         do i1 = 1, _pb_n - 2
            do i2 = 1, _pb_n
               x(i2, _pb_n - i1) = (x(i2, _pb_n - i1) - &
               x(i2, _pb_n - i1 - 1) * &
               a(i2, _pb_n - i1 - 1)) / &
               b(i2, _pb_n - i1)
            end do
         end do
      end do
      !$pragma endscop
   end subroutine

end program
