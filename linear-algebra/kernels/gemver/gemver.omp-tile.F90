!******************************************************************************
!
!  gemver.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "gemver.h"

program gemver
   implicit none

   data_type :: alpha
   data_type :: beta
   polybench_2d_array_decl(a, data_type, n, n)
   polybench_1d_array_decl(u1, data_type, n)
   polybench_1d_array_decl(u2, data_type, n)
   polybench_1d_array_decl(v1, data_type, n)
   polybench_1d_array_decl(v2, data_type, n)
   polybench_1d_array_decl(w, data_type, n)
   polybench_1d_array_decl(x, data_type, n)
   polybench_1d_array_decl(y, data_type, n)
   polybench_1d_array_decl(z, data_type, n)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(a, n, n)
   polybench_alloc_1d_array(u1, n)
   polybench_alloc_1d_array(u2, n)
   polybench_alloc_1d_array(v1, n)
   polybench_alloc_1d_array(v2, n)
   polybench_alloc_1d_array(w, n)
   polybench_alloc_1d_array(x, n)
   polybench_alloc_1d_array(y, n)
   polybench_alloc_1d_array(z, n)

   !     Initialization
   call init_array(n, &
   alpha, beta, a, u1, u2, v1, v2, w, x, y, z)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_gemver(n, alpha, beta, &
   a, u1, v1, u2, v2, &
   w, x, y, z)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(n, w)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(u1)
   polybench_dealloc_array(u2)
   polybench_dealloc_array(v1)
   polybench_dealloc_array(v2)
   polybench_dealloc_array(w)
   polybench_dealloc_array(x)
   polybench_dealloc_array(y)
   polybench_dealloc_array(z)

   contains

   subroutine init_array(n, alpha, beta, &
   a, u1, u2, v1, v2, w, x, y, z)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n) :: u1
      data_type, dimension(n) :: u2
      data_type, dimension(n) :: v1
      data_type, dimension(n) :: v2
      data_type, dimension(n) :: w
      data_type, dimension(n) :: x
      data_type, dimension(n) :: y
      data_type, dimension(n) :: z
      data_type :: alpha, beta
      integer :: n
      integer :: i, j
      alpha = 43532.0d0
      beta = 12313.0d0

      do i = 1, n
         u1(i) = dble(i - 1)
         u2(i) = dble(i / n) / 2.0d0
         v1(i) = dble(i / n) / 4.0d0
         v2(i) = dble(i / n) / 6.0d0
         y(i) = dble(i / n) / 8.0d0
         z(i) = dble(i / n) / 9.0d0
         x(i) = 0.0d0
         w(i) = 0.0d0
         do j = 1, n
            a(j, i) = ((dble(i - 1) * dble(j - 1))) / dble(n)
         end do
      end do
   end subroutine


   subroutine print_array(n, w)
      implicit none

      data_type, dimension(n) :: w
      integer :: n
      integer :: i, j
      do i = 1, n
         write(0, data_printf_modifier) w(i)
         if (mod(i - 1, 20) == 0) then
            write(0, *)
         end if
      end do
      write(0, *)
   end subroutine


   subroutine kernel_gemver(n, alpha, beta, &
   a, u1, v1, u2, v2, &
   w, x, y, z)
      implicit none

      data_type, dimension(n, n) :: a
      data_type, dimension(n) :: u1
      data_type, dimension(n) :: u2
      data_type, dimension(n) :: v1
      data_type, dimension(n) :: v2
      data_type, dimension(n) :: w
      data_type, dimension(n) :: x
      data_type, dimension(n) :: y
      data_type, dimension(n) :: z
      data_type :: alpha, beta
      integer :: n
      integer :: i, j

      !$pragma scop
      !$omp tile sizes(32,32)
      do i = 1, _pb_n
         do j = 1, _pb_n
            a(j, i) = a(j, i) + (u1(i) * v1(j)) + (u2(i) * v2(j))
         end do
      end do
      !$omp tile sizes(32,32)
      do i = 1, _pb_n
         do j = 1, _pb_n
            x(i) = x(i) + (beta * a(i, j) * y(j))
         end do
      end do
      do i = 1, _pb_n
         x(i) = x(i) + z(i)
      end do
      !$omp tile sizes(32,32)
      do i = 1, _pb_n
         do j = 1, _pb_n
            w(i) = w(i) + (alpha * a(j, i) * x(j))
         end do
      end do
      !$pragma endscop
   end subroutine

end program

