!******************************************************************************
!
!  atax.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "atax.h"

program atax
   implicit none

   polybench_2d_array_decl(a, data_type, ny, nx)
   polybench_1d_array_decl(x, data_type, ny)
   polybench_1d_array_decl(y, data_type, ny)
   polybench_1d_array_decl(tmp, data_type, nx)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(a, ny, nx)
   polybench_alloc_1d_array(x, ny)
   polybench_alloc_1d_array(y, nx)
   polybench_alloc_1d_array(tmp, ny)

   !     Initialization
   call init_array(a, x, nx, ny)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_atax(nx, ny, a, x, y, tmp)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(y, ny)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(x)
   polybench_dealloc_array(y)
   polybench_dealloc_array(tmp)

   contains

   subroutine init_array(a, x, nx, ny)
      implicit none

      double precision :: m_pi
      parameter(m_pi = 3.14159265358979323846d0)
      data_type, dimension(ny, nx) :: a
      data_type, dimension(ny) :: x
      integer :: nx, ny
      integer :: i, j
      do i = 1, ny
         x(i) = dble(i - 1) * m_pi
         do j = 1, ny
            a(j, i) = (dble((i - 1) * (j))) / nx
         end do
      end do
   end subroutine


   subroutine print_array(y, ny)
      implicit none

      data_type, dimension(ny) :: y
      integer :: ny
      integer :: i
      do i = 1, ny
         write(0, data_printf_modifier) y(i)
         if (mod(i - 1, 20) == 0) then
            write(0, *)
         end if
      end do
      write(0, *)
   end subroutine


   subroutine kernel_atax(nx, ny, a, x, y, tmp)
      implicit none

      data_type, dimension(ny, nx) :: a
      data_type, dimension(ny) :: x
      data_type, dimension(ny) :: y
      data_type, dimension(nx) :: tmp
      integer nx, ny, i, j

      !$pragma scop
      do i = 1, _pb_ny
         y(i) = 0.0d0
      end do

      do i = 1, _pb_nx
         tmp(i) = 0.0d0
         do j = 1, _pb_ny
            tmp(i) = tmp(i) + (a(j, i) * x(j))
         end do
         do j = 1, _pb_ny
            y(j) = y(j) + a(j, i) * tmp(i)
         end do
      end do
      !$pragma endscop
   end subroutine

end program
