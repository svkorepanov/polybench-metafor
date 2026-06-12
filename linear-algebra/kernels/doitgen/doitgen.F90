!******************************************************************************
!
!  doitgen.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "doitgen.h"

program doitgen
   implicit none

   polybench_3d_array_decl(a, data_type, np, nq, nr)
   polybench_3d_array_decl(suma, data_type, np, nq, nr)
   polybench_2d_array_decl(cfour, data_type, np, np)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_3d_array(a, np, nq, nr)
   polybench_alloc_3d_array(suma, np, nq, nr)
   polybench_alloc_2d_array(cfour, np, np)

   !     Initialization
   call init_array(nr, nq, np, a, cfour)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_doitgen(nr, nq, np, &
   a, cfour, suma)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(a, nr, nq, np)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(a)
   polybench_dealloc_array(suma)
   polybench_dealloc_array(cfour)

   contains

   subroutine init_array(nr, nq, np, a, cfour)
      implicit none

      data_type, dimension(np, nq, nr) :: a
      data_type, dimension(np, np) :: cfour
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
      implicit none

      data_type, dimension(np, nq, nr) :: a
      integer :: nr, nq, np
      integer :: i, j, k
      do i = 1, nr
         do j = 1, nq
            do k = 1, np
               write(0, data_printf_modifier) a(k, j, i)
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
      implicit none

      data_type, dimension(np, nq, nr) :: a
      data_type, dimension(np, nq, nr) :: suma
      data_type, dimension(np, np) :: cfour
      integer :: nr, nq, np
      integer :: r, s, p, q

      !$pragma scop
      do r = 1, _pb_nr
         do q = 1, _pb_nq
            do p = 1, _pb_np
               suma(p, q, r) = 0.0d0
               do s = 1, _pb_np
                  suma(p, q, r) = suma(p, q, r) + (a(s, q, r) * &
                  cfour(p, s))
               end do
            end do
            do p = 1, _pb_np
               a(p, q, r) = suma(p, q, r)
            end do
         end do
      end do
      !$pragma endscop
   end subroutine

end program
