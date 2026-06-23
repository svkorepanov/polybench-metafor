!******************************************************************************
!
!  reg_detect.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 50.
#include "reg_detect.h"

program regdetect
   implicit none

   polybench_2d_array_decl(sumtang, data_type, maxgrid, maxgrid)
   polybench_2d_array_decl(mean, data_type, maxgrid, maxgrid)
   polybench_3d_array_decl(diff, data_type, length, maxgrid, maxgrid)
   polybench_3d_array_decl(sumdiff, data_type, length, maxgrid, maxgrid)
   polybench_2d_array_decl(path, data_type, maxgrid, maxgrid)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(sumtang, maxgrid, maxgrid)
   polybench_alloc_2d_array(mean, maxgrid, maxgrid)
   polybench_alloc_3d_array(diff, length, maxgrid, maxgrid)
   polybench_alloc_3d_array(sumdiff, length, maxgrid, maxgrid)
   polybench_alloc_2d_array(path, maxgrid, maxgrid)

   !     Initialization
   call init_array(maxgrid, sumtang, mean, path)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_reg_detect(niter, maxgrid, length, &
   sumtang, mean, path, diff, sumdiff)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(maxgrid, path)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(sumtang)
   polybench_dealloc_array(mean)
   polybench_dealloc_array(diff)
   polybench_dealloc_array(sumdiff)
   polybench_dealloc_array(path)

   contains

   subroutine init_array(maxgrid, sumtang, mean, path)
      implicit none

      integer :: maxgrid
      data_type, dimension (maxgrid, maxgrid) :: sumtang, mean, path
      integer :: i, j
      do i = 1, maxgrid
         do j = 1, maxgrid
            sumtang(j, i) = i * j
            mean(j, i) = (i - j) / (maxgrid)
            path(j, i) = ((i - 1) * (j - 2)) / (maxgrid)
         end do
      end do
   end subroutine


   subroutine print_array(maxgrid, path)
      implicit none

      integer :: i, j, maxgrid
      data_type, dimension (maxgrid, maxgrid) :: path
      do i = 1, maxgrid
         do j = 1, maxgrid
            write(0, data_printf_modifier) path(j, i)
            if (mod(((i - 1) * maxgrid) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_reg_detect(niter, maxgrid, length, &
   sumtang, mean, path, diff, sumdiff)
      implicit none

      integer :: maxgrid, niter, length
      data_type, dimension (maxgrid, maxgrid) :: sumtang, mean, path
      data_type, dimension (length, maxgrid, maxgrid) :: sumdiff, diff
      integer :: i, j, t, cnt

      !$pragma scop
      do t = 1, _pb_niter
        !$omp tile sizes(32,32)
         do j = 1, _pb_maxgrid
            do i = j, _pb_maxgrid
               do cnt = 1, _pb_length
                  diff(cnt, i, j) = sumtang(i, j)
               end do
            end do
         end do

        !$omp tile sizes(32,32)
         do j = 1, _pb_maxgrid
            do i = j, _pb_maxgrid
               sumdiff(1, i, j) = diff(1, i, j)
               do cnt = 2, _pb_length
                  sumdiff(cnt, i, j) = sumdiff(cnt - 1, i, j) + &
                  diff(cnt, i, j)
               end do
               mean(i, j) = sumdiff(_pb_length, i, j)
            end do
         end do

         do i = 1, _pb_maxgrid
            path(i, 1) = mean(i, 1)
         end do

        !$omp tile sizes(32,32)
         do j = 2, _pb_maxgrid
            do i = j, _pb_maxgrid
               path(i, j) = path(i - 1, j - 1) + mean(i, j)
            end do
         end do
      end do
      !$pragma endscop
   end subroutine

end program
