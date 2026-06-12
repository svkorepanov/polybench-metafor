!******************************************************************************
!
!  covariance.F90: This file is part of the PolyBench/Fortran 1.0 test suite.
!
!  Contact: Louis-Noel Pouchet <pouchet@cse.ohio-state.edu>
!  Web address: http://polybench.sourceforge.net
!
!******************************************************************************

! Include polybench common header.
#include <fpolybench.h>

! Include benchmark-specific header.
! Default data type is double, default size is 4000.
#include "covariance.h"

program covariance
   implicit none

   data_type :: float_n
   polybench_2d_array_decl(dat, data_type, n, m)
   polybench_2d_array_decl(symmat, data_type, m, m)
   polybench_1d_array_decl(mean, data_type, m)
   polybench_declare_prevent_dce_vars
   polybench_declare_instruments

   !     Allocation of Arrays
   polybench_alloc_2d_array(dat, n, m)
   polybench_alloc_2d_array(symmat, m, m)
   polybench_alloc_1d_array(mean, m)

   !     Initialization
   call init_array(m, n, float_n, dat)

   !     Kernel Execution
   polybench_start_instruments

   call kernel_covariance(m, n, float_n, dat, symmat, mean)

   polybench_stop_instruments
   polybench_print_instruments

   !     Prevent dead-code elimination. All live-out data must be printed
   !     by the function call in argument.
   polybench_prevent_dce(print_array(m, symmat)) ;

   !     Deallocation of Arrays
   polybench_dealloc_array(dat)
   polybench_dealloc_array(symmat)
   polybench_dealloc_array(mean)

   contains

   subroutine init_array(m, n, float_n, dat)
      implicit none

      data_type, dimension(n, m) :: dat
      data_type :: float_n
      integer :: m, n
      integer :: i, j

      float_n = 1.2d0
      do i = 1, m
         do j = 1, n
            dat(j, i) = (dble((i - 1) * (j - 1))) / dble(m)
         end do
      end do
   end subroutine


   subroutine print_array(m, symmat)
      implicit none

      data_type, dimension(m, m) :: symmat
      integer :: m
      integer :: i, j
      do i = 1, m
         do j = 1, m
            write(0, data_printf_modifier) symmat(j, i)
            if (mod(((i - 1) * m) + j - 1, 20) == 0) then
               write(0, *)
            end if
         end do
      end do
      write(0, *)
   end subroutine


   subroutine kernel_covariance(m, n, float_n, dat, symmat, mean)
      implicit none

      data_type, dimension(m, m) :: symmat
      data_type, dimension(n, m) :: dat
      data_type, dimension(m) :: mean
      data_type :: float_n
      integer :: m, n
      integer :: i, j, j1, j2
      !$pragma scop
      !       Determine mean of column vectors of input data matrix
      do j = 1, _pb_m
         mean(j) = 0.0d0
         do i = 1, _pb_n
            mean(j) = mean(j) + dat(j, i)
         end do
         mean(j) = mean(j) / float_n
      end do

      !       Center the column vectors.
      do i = 1, _pb_n
         do j = 1, _pb_m
            dat(j, i) = dat(j, i) - mean(j)
         end do
      end do

      !       Calculate the m * m covariance matrix.
      do j1 = 1, _pb_m
         do j2 = j1, _pb_m
            symmat(j2, j1) = 0.0d0
            do i = 1, _pb_n
               symmat(j2, j1) = symmat(j2, j1) + (dat(j1, i) * dat(j2, i))
            end do
            symmat(j1, j2) = symmat(j2, j1)
         end do
      end do
      !$pragma endscop
   end subroutine

end program
